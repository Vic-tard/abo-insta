import UIKit
import WebKit

/// Affiche l'app web Zyeuto et lui transmet les fichiers partagés.
final class WebViewController: UIViewController {
    static let home = URL(string: "https://vic-tard.github.io/abo-insta/")!
    private static let chunkSize = 512 * 1024

    private var webView: WKWebView!
    private let offline = UIView()
    private var pageReady = false
    private var sending = false
    /// Fichiers reçus, gardés jusqu'à ce que la page confirme les avoir reçus.
    private var pending: [(name: String, data: Data)] = []
    private var downloads: [ObjectIdentifier: URL] = [:]
    private let splash = UIView()
    private var splashShownAt = Date()
    /// Vrai quand on affiche la copie gardée sur le téléphone (pas d'internet).
    private var offlineMode = false
    private static var offlineCopy: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("zyeuto-hors-ligne.html")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Même fond que la page, en clair comme en sombre : pas de flash à l'ouverture.
        let bg = UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 0x16 / 255, green: 0x11 / 255, blue: 0x12 / 255, alpha: 1)
            : UIColor(red: 0xfa / 255, green: 0xf5 / 255, blue: 0xf5 / 255, alpha: 1) }
        view.backgroundColor = bg

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        let content = WKUserContentController()
        // Dit à la page qu'elle tourne dans l'app (pas de Drive, pas de bandeau « installer »).
        content.addUserScript(WKUserScript(
            source: "window.ZYEUTO_APP = { version: 1 };",
            injectionTime: .atDocumentStart, forMainFrameOnly: true))
        // Ressenti d'app : pas de zoom, pas de sélection de texte ni de menu « Copier » à l'appui long
        // (sauf dans les champs de saisie), pas de surlignage gris au toucher.
        content.addUserScript(WKUserScript(source: Self.nativeFeel, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        content.add(WeakHandler(self), name: "zyeuto")
        config.userContentController = content

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.isOpaque = false
        webView.backgroundColor = bg
        webView.scrollView.backgroundColor = bg
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsBackForwardNavigationGestures = false
        webView.allowsLinkPreview = false
        webView.scrollView.bounces = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.pinchGestureRecognizer?.isEnabled = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        view.addSubview(webView)

        buildOfflineView()
        buildSplash()
        webView.load(URLRequest(url: Self.home))
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification,
                                               object: nil, queue: .main) { [weak self] _ in self?.retryOnline() }
    }

    // MARK: Écran d'ouverture (le bonhomme)

    private func buildSplash() {
        splash.frame = view.bounds
        splash.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        splash.backgroundColor = view.backgroundColor
        let logo = UIImageView(image: Data(base64Encoded: Self.logoPNG).flatMap { UIImage(data: $0, scale: 3) })
        logo.translatesAutoresizingMaskIntoConstraints = false
        logo.layer.cornerCurve = .continuous
        splash.addSubview(logo)
        NSLayoutConstraint.activate([
            logo.centerXAnchor.constraint(equalTo: splash.centerXAnchor),
            logo.centerYAnchor.constraint(equalTo: splash.centerYAnchor),
            logo.widthAnchor.constraint(equalToConstant: 120),
            logo.heightAnchor.constraint(equalToConstant: 120),
        ])
        view.addSubview(splash)
        splashShownAt = Date()
        // Petit rebond d'arrivée.
        logo.transform = CGAffineTransform(scaleX: 0.86, y: 0.86)
        UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.55, initialSpringVelocity: 0.8) {
            logo.transform = .identity
        }
        // Au cas où la page tarde : on n'attend pas plus de 6 secondes.
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in self?.hideSplash() }
    }

    private func hideSplash() {
        guard splash.superview != nil, splash.alpha == 1 else { return }
        let wait = max(0, 0.7 - Date().timeIntervalSince(splashShownAt)) // jamais un simple flash
        UIView.animate(withDuration: 0.35, delay: wait, options: .curveEaseOut) {
            self.splash.alpha = 0
            self.splash.transform = CGAffineTransform(scaleX: 1.04, y: 1.04)
        } completion: { _ in self.splash.removeFromSuperview() }
    }

    // MARK: Sans internet : copie gardée sur le téléphone

    /// Garde la dernière version de la page pour pouvoir s'ouvrir sans réseau.
    private func saveOfflineCopy() {
        var request = URLRequest(url: Self.home)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        URLSession.shared.dataTask(with: request) { data, response, _ in
            guard (response as? HTTPURLResponse)?.statusCode == 200, let data,
                  let html = String(data: data, encoding: .utf8), html.contains("const BUILD") else { return }
            try? data.write(to: Self.offlineCopy, options: .atomic)
        }.resume()
    }

    /// Pas de réseau : on ouvre la copie, à la même adresse (donc avec les mêmes données).
    private func openOfflineCopy() -> Bool {
        guard !offlineMode, let html = try? String(contentsOf: Self.offlineCopy, encoding: .utf8) else { return false }
        offlineMode = true
        offline.isHidden = true
        webView.loadHTMLString(html, baseURL: Self.home)
        return true
    }

    /// De retour dans l'app : si on était sans réseau, on retente la version en ligne.
    private func retryOnline() {
        guard offlineMode, !sending, pending.isEmpty else { return }
        offlineMode = false
        webView.load(URLRequest(url: Self.home))
    }

    private static func isNetworkError(_ error: Error) -> Bool {
        let e = error as NSError
        guard e.domain == NSURLErrorDomain else { return false }
        return [NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost, NSURLErrorTimedOut,
                NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost, NSURLErrorDNSLookupFailed,
                NSURLErrorDataNotAllowed, NSURLErrorInternationalRoamingOff, NSURLErrorSecureConnectionFailed]
            .contains(e.code)
    }

    private static let nativeFeel = """
    (function () {
      var m = document.querySelector('meta[name=viewport]');
      if (m) m.content = 'width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no,viewport-fit=cover';
      var st = document.createElement('style');
      st.textContent = '*{-webkit-user-select:none;user-select:none;-webkit-touch-callout:none;-webkit-tap-highlight-color:transparent}' +
        'input,textarea,[contenteditable]{-webkit-user-select:text;user-select:text}' +
        '*{overscroll-behavior:none;scrollbar-width:none}' +
        '::-webkit-scrollbar{display:none;width:0;height:0}';
      document.head.appendChild(st);
    })();
    """

    // MARK: Fichier partagé

    func receive(fileAt url: URL) {
        guard url.isFileURL else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return }
        pending.append((url.lastPathComponent, data))
        // La copie déposée dans « Inbox » ne sert plus.
        if url.path.contains("/Inbox/") { try? FileManager.default.removeItem(at: url) }
        flush()
    }

    private func flush() {
        guard pageReady, !sending, let file = pending.first else { return }
        sending = true
        let name = jsString(file.name)
        var calls = ["window.zyeutoFile.begin(\(name), \(file.data.count))"]
        var offset = 0
        while offset < file.data.count {
            let end = min(offset + Self.chunkSize, file.data.count)
            calls.append("window.zyeutoFile.add(\"\(file.data.subdata(in: offset..<end).base64EncodedString())\")")
            offset = end
        }
        calls.append("window.zyeutoFile.end()")
        run(calls, index: 0)
    }

    private func run(_ calls: [String], index: Int) {
        guard index < calls.count else { return }
        webView.evaluateJavaScript(calls[index] + "; true") { [weak self] _, error in
            guard let self else { return }
            if error != nil { self.sending = false; return } // la page a rechargé : renvoi au prochain « ready »
            self.run(calls, index: index + 1)
        }
    }

    private func jsString(_ s: String) -> String {
        let data = try? JSONSerialization.data(withJSONObject: [s])
        let json = data.flatMap { String(data: $0, encoding: .utf8) } ?? "[\"export.zip\"]"
        return String(json.dropFirst().dropLast())
    }

    // MARK: Hors ligne

    private func buildOfflineView() {
        offline.frame = view.bounds
        offline.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        offline.backgroundColor = view.backgroundColor
        offline.isHidden = true
        let label = UILabel()
        label.text = "Pas de connexion internet.\nZyeuto en a besoin pour s'ouvrir."
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .label
        var button = UIButton.Configuration.filled()
        button.title = "Réessayer"
        button.baseBackgroundColor = UIColor(red: 0xd4 / 255, green: 0x91 / 255, blue: 0x9b / 255, alpha: 1)
        button.cornerStyle = .capsule
        let retry = UIButton(configuration: button, primaryAction: UIAction { [weak self] _ in
            self?.offline.isHidden = true
            self?.webView.load(URLRequest(url: WebViewController.home))
        })
        let stack = UIStackView(arrangedSubviews: [label, retry])
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        offline.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: offline.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: offline.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: offline.leadingAnchor, constant: 32),
        ])
        view.addSubview(offline)
    }

    private func isHome(_ url: URL?) -> Bool {
        guard let url else { return false }
        return url.host == Self.home.host && url.path.hasPrefix(Self.home.path)
    }
}

// MARK: Messages de la page

extension WebViewController: WKScriptMessageHandler {
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        switch type {
        case "ready":
            hideSplash()
            pageReady = true
            sending = false
            flush()
        case "received":
            if !pending.isEmpty { pending.removeFirst() }
            sending = false
            flush()
        case "haptic":
            switch body["kind"] as? String {
            case "success": UINotificationFeedbackGenerator().notificationOccurred(.success)
            case "error": UINotificationFeedbackGenerator().notificationOccurred(.error)
            case "medium": UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            case "selection": UISelectionFeedbackGenerator().selectionChanged()
            default: UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        default:
            break
        }
    }
}

/// Évite que WebKit garde le contrôleur en mémoire pour toujours.
private final class WeakHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) { self.target = target }
    func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {
        target?.userContentController(c, didReceive: m)
    }
}

// MARK: Navigation

extension WebViewController: WKNavigationDelegate, WKUIDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if action.shouldPerformDownload { decisionHandler(.download); return }
        guard let url = action.request.url, action.targetFrame?.isMainFrame == true,
              !isHome(url), !["blob", "data", "about"].contains(url.scheme ?? "") else {
            decisionHandler(.allow)
            return
        }
        // Instagram, profils, etc. : ouverts dans Safari ou l'app Instagram.
        UIApplication.shared.open(url)
        decisionHandler(.cancel)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        pageReady = false // la page recharge (mise à jour) : on attendra son prochain « ready »
    }

    func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(response.canShowMIMEType ? .allow : .download)
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
    }

    // Liens target="_blank" : même règle que les autres liens.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = action.request.url {
            if isHome(url) { webView.load(action.request) } else { UIApplication.shared.open(url) }
        }
        return nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        hideSplash()
        if !offlineMode, isHome(webView.url) { saveOfflineCopy() }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard Self.isNetworkError(error) else { return } // ex. lien ouvert dans Safari : rien à faire
        if !openOfflineCopy() {
            offline.isHidden = false
            hideSplash()
        }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        pageReady = false
        webView.reload()
    }

    // alert / confirm de la page.
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        present(alert, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Annuler", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        present(alert, animated: true)
    }
}

// MARK: Téléchargements (copie de sauvegarde)

extension WebViewController: WKDownloadDelegate {
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse,
                  suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(suggestedFilename)
        downloads[ObjectIdentifier(download)] = url
        completionHandler(url)
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let url = downloads.removeValue(forKey: ObjectIdentifier(download)) else { return }
        let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = view
        present(sheet, animated: true)
    }
}

// MARK: Logo de l'écran d'ouverture (icône Zyeuto, PNG 360 × 360)

private extension WebViewController {
    static let logoPNG = "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"
}
