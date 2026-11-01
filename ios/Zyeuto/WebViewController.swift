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

    override func viewDidLoad() {
        super.viewDidLoad()
        let bg = UIColor(red: 0xfa / 255, green: 0xf5 / 255, blue: 0xf5 / 255, alpha: 1)
        view.backgroundColor = bg

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        let content = WKUserContentController()
        // Dit à la page qu'elle tourne dans l'app (pas de Drive, pas de bandeau « installer »).
        content.addUserScript(WKUserScript(
            source: "window.ZYEUTO_APP = { version: 1 };",
            injectionTime: .atDocumentStart, forMainFrameOnly: true))
        content.add(WeakHandler(self), name: "zyeuto")
        config.userContentController = content

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.isOpaque = false
        webView.backgroundColor = bg
        webView.scrollView.backgroundColor = bg
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsBackForwardNavigationGestures = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        view.addSubview(webView)

        buildOfflineView()
        webView.load(URLRequest(url: Self.home))
    }

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
        label.textColor = UIColor(red: 0x2e / 255, green: 0x23 / 255, blue: 0x28 / 255, alpha: 1)
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
            pageReady = true
            sending = false
            flush()
        case "received":
            if !pending.isEmpty { pending.removeFirst() }
            sending = false
            flush()
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

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        offline.isHidden = false
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
