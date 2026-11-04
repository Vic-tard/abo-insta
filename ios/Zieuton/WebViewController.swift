import UIKit
import WebKit
import UserNotifications
import BackgroundTasks
import StoreKit

/// Affiche l'app web Zieuton et lui transmet les fichiers partagés.
final class WebViewController: UIViewController {
    /// L'écran Zieuton ouvert (pour les notifications touchées).
    static weak var current: WebViewController?
    /// Une notification a été touchée avant que la page soit prête : on ouvre Instagram dès qu'elle l'est.
    private var openWhenReady = false
    static let home = URL(string: "https://vic-tard.github.io/abo-insta/")!
    private static let chunkSize = 512 * 1024

    private var webView: WKWebView!
    private var pageReady = false
    private var sending = false
    /// Fichiers reçus, gardés jusqu'à ce que la page confirme les avoir reçus.
    private var pending: [(name: String, data: Data)] = []
    private var downloads: [ObjectIdentifier: URL] = [:]
    private let splash = UIView()
    private var splashShownAt = Date()
    /// Version de la page affichée (sa ligne « const BUILD »).
    private var loadedBuild = ""
    private var checkingUpdate = false
    /// Dernière version de la page téléchargée (plus récente que celle rangée dans l'app).
    private static var savedPage: URL {
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
            source: "window.ZYEUTO_APP = { version: 5, embedded: true };",
            injectionTime: .atDocumentStart, forMainFrameOnly: true))
        // Les images de la page (guide d'export, logo) sont rangées dans l'app : elles s'affichent sans internet.
        content.addUserScript(WKUserScript(source: Self.assetsScript, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        content.addUserScript(WKUserScript(source: Self.fixImages, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
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

        buildSplash()
        loadPage()
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification,
                                               object: nil, queue: .main) { _ in
            ExportWatcher.shared.appBecameActive()
        }
        Self.current = self
        // Fichier Instagram repéré prêt : la carte « Mettre à jour » passe à « Ton export est prêt ».
        ExportWatcher.shared.onReady = { [weak self] in
            self?.webView.evaluateJavaScript("window.zyeutoMeta && window.zyeutoMeta('ready'); true")
        }
        ExportWatcher.shared.appBecameActive()
        // Zieuton Plus : la page apprend tout de suite si c'est acheté, et les prix du magasin.
        PlusStore.shared.onChange = { [weak self] in self?.sendPlus(nil) }
        PlusStore.shared.start()
    }

    /// Envoie l'état de Zieuton Plus à la page (et le résultat d'un achat, s'il y en a un).
    func sendPlus(_ result: String?) {
        guard pageReady else { return }
        let js = "window.zyeutoPlus && window.zyeutoPlus(\(PlusStore.shared.json(result: result))); true"
        webView.evaluateJavaScript(js)
    }

    /// Notification touchée : on ouvre Instagram sur « Télécharger » (ou dès que la page est prête).
    func openExport() {
        guard pageReady else { openWhenReady = true; return }
        openWhenReady = false
        guard presentedViewController == nil else { return }
        webView.evaluateJavaScript("window.zyeutoMeta && window.zyeutoMeta('open'); true")
    }

    /// Notification « C'est demandé » touchée : retour à l'accueil, sur la carte « En préparation ».
    func showHome() {
        guard pageReady, presentedViewController == nil else { return }
        webView.evaluateJavaScript("window.zyeutoMeta && window.zyeutoMeta('home'); true")
    }

    // MARK: Écran d'ouverture (le bonhomme)

    private func buildSplash() {
        splash.frame = view.bounds
        splash.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        splash.backgroundColor = view.backgroundColor

        // L'icône dessinée en morceaux (même dessin que icon.svg, 100 unités = 120 points) :
        // le fond rose, le bonhomme caché derrière le mur, le mur, puis les mains.
        let size: CGFloat = 120, u = size / 100
        func rgb(_ hex: UInt32) -> UIColor {
            UIColor(red: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: 1)
        }
        func shape(_ path: UIBezierPath, _ color: UInt32) -> CAShapeLayer {
            let l = CAShapeLayer(); l.path = path.cgPath; l.fillColor = rgb(color).cgColor; return l
        }
        func oval(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> UIBezierPath {
            UIBezierPath(ovalIn: CGRect(x: (cx - rx) * u, y: (cy - ry) * u, width: rx * 2 * u, height: ry * 2 * u))
        }
        func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat = 0) -> UIBezierPath {
            UIBezierPath(roundedRect: CGRect(x: x * u, y: y * u, width: w * u, height: h * u), cornerRadius: r * u)
        }

        // Ombre douce autour de l'icône (dans une vue à part, car l'icône coupe ce qui dépasse).
        let holder = UIView()
        holder.translatesAutoresizingMaskIntoConstraints = false
        holder.layer.shadowColor = rgb(0xd4919b).cgColor
        holder.layer.shadowOpacity = 0.35
        holder.layer.shadowRadius = 15
        holder.layer.shadowOffset = CGSize(width: 0, height: 10)
        splash.addSubview(holder)

        let icon = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
        icon.backgroundColor = rgb(0xd4919b)
        icon.layer.cornerRadius = 27
        icon.layer.cornerCurve = .continuous
        icon.clipsToBounds = true
        holder.addSubview(icon)

        let head = UIView(frame: icon.bounds)
        head.layer.addSublayer(shape(oval(50, 58, 30, 30), 0xffffff))
        var eyes: [CAShapeLayer] = []
        for cx: CGFloat in [39.5, 60.5] {
            let eye = shape(UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 10.8 * u, height: 12.8 * u)), 0x2e2328)
            eye.bounds = CGRect(x: 0, y: 0, width: 10.8 * u, height: 12.8 * u)
            eye.position = CGPoint(x: cx * u, y: 48 * u)
            head.layer.addSublayer(eye); eyes.append(eye)
        }
        for cx: CGFloat in [41.4, 62.4] { head.layer.addSublayer(shape(oval(cx, 45.6, 1.9, 1.9), 0xffffff)) }
        for cx: CGFloat in [30, 70] { head.layer.addSublayer(shape(oval(cx, 57, 4.6, 2.8), 0xf2b3bc)) }
        icon.addSubview(head)

        let wall = UIView(frame: icon.bounds)
        wall.layer.addSublayer(shape(rect(0, 64, 100, 36), 0x2e2328))
        icon.addSubview(wall)

        let hands = UIView(frame: icon.bounds)
        hands.layer.addSublayer(shape(rect(17, 57, 16, 12, 6), 0xffffff))
        hands.layer.addSublayer(shape(rect(67, 57, 16, 12, 6), 0xffffff))
        let fingers = UIBezierPath()
        for x: CGFloat in [23, 27.5, 72.5, 77] { fingers.move(to: CGPoint(x: x * u, y: 60 * u)); fingers.addLine(to: CGPoint(x: x * u, y: 65 * u)) }
        let lines = CAShapeLayer(); lines.path = fingers.cgPath; lines.strokeColor = rgb(0xe7d6d9).cgColor
        lines.lineWidth = 1.4 * u; lines.lineCap = .round; lines.fillColor = nil
        hands.layer.addSublayer(lines)
        icon.addSubview(hands)

        NSLayoutConstraint.activate([
            holder.centerXAnchor.constraint(equalTo: splash.centerXAnchor),
            holder.centerYAnchor.constraint(equalTo: splash.centerYAnchor),
            holder.widthAnchor.constraint(equalToConstant: size),
            holder.heightAnchor.constraint(equalToConstant: size),
        ])
        view.addSubview(splash)
        splashShownAt = Date()

        // 1. L'icône arrive (le bonhomme est encore caché derrière le mur).
        holder.alpha = 0
        holder.transform = CGAffineTransform(scaleX: 0.86, y: 0.86)
        head.transform = CGAffineTransform(translationX: 0, y: 40 * u)
        hands.transform = CGAffineTransform(translationX: 0, y: -14 * u)
        hands.alpha = 0
        UIView.animate(withDuration: 0.55, delay: 0.1, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8) {
            holder.alpha = 1; holder.transform = .identity
        }
        // 2. Il sort de derrière le mur.
        UIView.animate(withDuration: 0.6, delay: 0.45, usingSpringWithDamping: 0.62, initialSpringVelocity: 0.6) {
            head.transform = .identity
        }
        // 3. Il pose les mains sur le mur.
        UIView.animate(withDuration: 0.35, delay: 0.9, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.8) {
            hands.alpha = 1; hands.transform = .identity
        }
        // 4. Il cligne deux fois des yeux.
        let blink = CABasicAnimation(keyPath: "transform.scale.y")
        blink.fromValue = 1; blink.toValue = 0.1
        blink.duration = 0.11; blink.autoreverses = true; blink.repeatCount = 2
        blink.beginTime = CACurrentMediaTime() + 1.35
        for eye in eyes { eye.add(blink, forKey: "blink") }

        // Au cas où la page tarde : on n'attend pas plus de 6 secondes.
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in self?.hideSplash() }
    }

    private func hideSplash() {
        guard splash.superview != nil, splash.alpha == 1 else { return }
        let wait = max(0, 1.9 - Date().timeIntervalSince(splashShownAt)) // le temps que le bonhomme sorte et cligne des yeux
        UIView.animate(withDuration: 0.35, delay: wait, options: .curveEaseOut) {
            self.splash.alpha = 0
            self.splash.transform = CGAffineTransform(scaleX: 1.04, y: 1.04)
        } completion: { _ in self.splash.removeFromSuperview() }
    }

    // MARK: Page rangée dans l'app (+ mises à jour)

    /// La page est rangée dans l'app : elle s'ouvre tout de suite, même sans internet.
    /// Quand une version plus récente est en ligne, l'app la télécharge et la garde sur le téléphone.
    /// La page s'affiche toujours à l'adresse du site, donc avec les mêmes données qu'avant.
    private func loadPage() {
        let bundled = Bundle.main.url(forResource: "index", withExtension: "html")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) }
        let saved = try? String(contentsOf: Self.savedPage, encoding: .utf8)
        let candidates = [bundled, saved].compactMap { $0 }.filter { Self.build(of: $0) != nil }
        guard let html = candidates.max(by: { Self.build(of: $0)! < Self.build(of: $1)! }) else {
            webView.load(URLRequest(url: Self.home)) // ne devrait pas arriver : la page est toujours dans l'app
            return
        }
        loadedBuild = Self.build(of: html)!
        webView.loadHTMLString(html, baseURL: Self.home)
    }

    /// Numéro de version d'une page (ex. « 2026-11-04-1210 »), qui se compare comme du texte.
    private static func build(of html: String) -> String? {
        guard let r = html.range(of: #"const BUILD = "([^"]+)""#, options: .regularExpression) else { return nil }
        return String(html[r].dropFirst(15).dropLast())
    }

    /// La page demande s'il y a du nouveau (à l'ouverture et à chaque retour dans l'app).
    private func checkForUpdate() {
        guard !checkingUpdate else { return }
        checkingUpdate = true
        let current = loadedBuild
        var comps = URLComponents(url: Self.home, resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "v", value: String(Int(Date().timeIntervalSince1970)))]
        var request = URLRequest(url: comps.url!, timeoutInterval: 15)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
            var newer = false
            if (response as? HTTPURLResponse)?.statusCode == 200, let data,
               let html = String(data: data, encoding: .utf8), html.contains("</html>"),
               let build = Self.build(of: html), build > current {
                newer = (try? data.write(to: Self.savedPage, options: .atomic)) != nil
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.checkingUpdate = false
                // On recharge seulement si rien n'est en cours (fichier reçu, Instagram ouvert…).
                if newer, !self.sending, self.pending.isEmpty, self.presentedViewController == nil { self.loadPage() }
            }
        }.resume()
    }

    /// Les images rangées dans l'app, prêtes à être affichées par la page (« guide/ig-01.jpg » → image).
    private static let assetsScript: String = {
        guard let root = Bundle.main.resourceURL else { return "" }
        var names = ["icone-v5-180.png"]
        let guide = root.appendingPathComponent("guide")
        let files = (try? FileManager.default.contentsOfDirectory(atPath: guide.path)) ?? []
        names += files.filter { $0.hasSuffix(".jpg") || $0.hasSuffix(".png") }.sorted().map { "guide/" + $0 }
        var map: [String: String] = [:]
        for name in names {
            guard let data = try? Data(contentsOf: root.appendingPathComponent(name)) else { continue }
            let type = name.hasSuffix(".png") ? "image/png" : "image/jpeg"
            map[name] = "data:\(type);base64,\(data.base64EncodedString())"
        }
        guard let json = try? JSONSerialization.data(withJSONObject: map),
              let text = String(data: json, encoding: .utf8) else { return "" }
        return "window.ZYEUTO_ASSETS = \(text);"
    }()

    /// Les images écrites directement dans la page (le logo) prennent la version rangée dans l'app.
    private static let fixImages = """
    (function () {
      var a = window.ZYEUTO_ASSETS || {};
      document.querySelectorAll('img[src]').forEach(function (img) {
        var src = img.getAttribute('src');
        if (a[src]) img.src = a[src];
      });
    })();
    """

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
            if ExportWatcher.shared.isReady {
                webView.evaluateJavaScript("window.zyeutoMeta && window.zyeutoMeta('ready'); true")
            }
            if openWhenReady { openExport() }
            sendPlus(nil)
        case "plus":
            handlePlus(body)
        case "received":
            if !pending.isEmpty { pending.removeFirst() }
            sending = false
            flush()
        case "update":
            checkForUpdate()
        case "haptic":
            switch body["kind"] as? String {
            case "success": UINotificationFeedbackGenerator().notificationOccurred(.success)
            case "error": UINotificationFeedbackGenerator().notificationOccurred(.error)
            case "medium": UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            case "selection": UISelectionFeedbackGenerator().selectionChanged()
            default: UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        case "meta":
            openMeta(body)
        case "exportState":
            // La page n'attend plus d'export (fichier importé, demande annulée) : on arrête de guetter.
            if body["pending"] as? Bool == false { ExportWatcher.shared.clear() }
        default:
            break
        }
    }

    /// Zieuton Plus : acheter, restaurer, gérer l'abonnement, ou juste redemander l'état.
    private func handlePlus(_ body: [String: Any]) {
        Task { @MainActor [weak self] in
            let store = PlusStore.shared
            switch body["action"] as? String {
            case "buy":
                let result = await store.buy(body["id"] as? String ?? "")
                self?.sendPlus(result)
            case "restore":
                let found = await store.restore()
                self?.sendPlus(found ? "restored" : "none")
            case "manage":
                if let scene = self?.view.window?.windowScene {
                    try? await AppStore.showManageSubscriptions(in: scene)
                }
                await store.refresh()
                self?.sendPlus(nil)
            default:
                await store.load()
                self?.sendPlus(nil)
            }
        }
    }

    /// Bouton « Mettre à jour » : la page d'export d'Instagram s'ouvre dans Zieuton, avec un bandeau guide.
    private func openMeta(_ body: [String: Any]) {
        guard presentedViewController == nil,
              let url = URL(string: body["url"] as? String ?? "https://accountscenter.instagram.com/info_and_permissions/dyi/")
        else { return }
        let steps = (body["steps"] as? [[String: Any]] ?? []).map { d in
            MetaViewController.Step(
                verb: d["verb"] as? String ?? "", target: d["target"] as? String ?? "",
                after: d["after"] as? String ?? "", tip: d["tip"] as? String ?? "",
                look: d["look"] as? String ?? "",
                wait: d["wait"] as? [String] ?? [], final: d["final"] as? Bool ?? false,
                ok: d["ok"] as? [String], bad: d["bad"] as? [String] ?? [],
                free: d["free"] as? Bool ?? false, pick: d["pick"] as? Bool ?? false,
                redo: d["redo"] as? Int ?? -1, oops: d["oops"] as? String ?? "", redoOops: d["redoOops"] as? String ?? "",
                screen: d["screen"] as? String ?? "")
        }
        let meta = MetaViewController(url: url, requesting: (body["mode"] as? String) != "get", steps: steps)
        meta.onRequested = { [weak self] downloadsBefore in
            self?.webView.evaluateJavaScript("window.zyeutoMeta && window.zyeutoMeta('requested'); true")
            ExportWatcher.shared.requested(downloadsBefore: downloadsBefore)
        }
        meta.onFile = { [weak self] url in self?.receive(fileAt: url) }
        meta.modalPresentationStyle = .fullScreen
        present(meta, animated: true)
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
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        // Une page du site demandée sans internet : on revient à la page rangée dans l'app.
        guard Self.isNetworkError(error) else { return } // ex. lien ouvert dans Safari : rien à faire
        loadPage()
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        pageReady = false
        loadPage()
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

// MARK: Instagram dans Zieuton (bouton « Mettre à jour »)

/// Affiche la page officielle d'export d'Instagram, avec un petit bandeau Zieuton qui dit où toucher.
/// Le bandeau suit ce qui se passe : il regarde quel bouton tu viens de toucher (son texte seulement)
/// et passe tout seul à l'étape suivante ; la demande n'est notée « faite » que quand tu as vraiment
/// touché « Commencer l'exportation ». Zieuton ne clique jamais à ta place et ne lit jamais ton mot de passe.
/// Quand le fichier est téléchargé, il est transmis à Zieuton, qui l'importe tout seul.
final class MetaViewController: UIViewController {
    struct Step {
        var verb = ""      // « Touche », « Choisis »…
        var target = ""    // le nom exact du bouton d'Instagram
        var after = ""     // la suite (« puis « Enregistrer » »)
        var tip = ""
        var look = ""      // à quoi ressemble le bouton chez Instagram : button, row, link, radio, check
        var wait: [String] = [] // textes de bouton qui terminent l'étape quand on les touche
        var final = false  // l'étape qui envoie la demande
        // Pour repérer un mauvais bouton :
        var ok: [String]? = nil  // touches normales pendant l'étape (sans ça, aucune alerte : ancienne page)
        var bad: [String] = []   // mauvais choix connus (« Année dernière », « HTML », « Facebook »…)
        var free = false         // page à cases à cocher : les autres touches sont permises
        var pick = false         // il faut avoir choisi la bonne option avant « Enregistrer »
        var redo = -1            // étape où revenir si on a enregistré sans le bon choix
        var oops = ""            // conseil quand on touche un mauvais choix
        var redoOops = ""        // conseil quand on a enregistré sans le bon choix
        var screen = ""          // l'écran d'Instagram de cette étape (home, profile, dest, summary:info, pick, period…)
    }

    /// Alerte « mauvais bouton » affichée dans le bandeau.
    private struct Warning: Equatable { var title: String; var text: String }
    private var warning: Warning?
    private var warningAt = Date.distantPast
    /// Étape où la bonne option a été choisie (« Depuis le début », « JSON »).
    private var pickedAt = -1
    private var lastTapAt = Date.distantPast
    private var createSince: Date?
    /// Les alertes ne s'allument que si la page est bien en français ou en anglais (bouton « Créer une exportation » reconnu).
    private var guarded: Bool { steps.contains { $0.ok != nil } && seenCreate != .distantPast }

    /// La demande est partie (avec le nombre d'exports déjà téléchargeables avant elle).
    var onRequested: ((Int) -> Void)?
    var onFile: ((URL) -> Void)?
    /// Nombre de boutons « Télécharger » vus sur la page (exports déjà prêts avant la nouvelle demande).
    private(set) var downloadsSeen = 0

    private let url: URL
    private let requesting: Bool
    private let steps: [Step]
    private var index = 0
    private var loginShown = false
    /// Écran « tape le code de sécurité » d'Instagram : par où le code est arrivé (whatsapp, sms, email, app), vide sinon.
    private var codeShown = ""
    private var seenCode = Date.distantPast
    private var codeKind = ""
    /// Écran d'Instagram vu en dernier, depuis quand, et la dernière fois qu'un cadre l'a signalé.
    private var screenKey = ""
    private var screenSince = Date.distantPast
    private var seenScreen = Date.distantPast
    /// Hors du parcours d'export (Espace Comptes, autre rubrique…) : le bandeau propose d'y revenir.
    private var lostShown = false
    private var offSince: Date?
    private var lostCheckFrom = Date()
    private var seenFlow = Date.distantPast
    /// Cases à cocher : nombre de cases cochées, et « Followers et suivi(e)s » cochée ou non.
    private var pickChecked = 0
    private var pickFollowers = false
    private var seenPick = Date.distantPast
    /// « Enregistrer » touché avec de mauvaises cases : on reste sur « Personnaliser les informations » jusqu'au retour sur les cases.
    private var pickRedo = false
    private var pickFresh: Bool { Date().timeIntervalSince(seenPick) < 1.6 }
    /// Bon réglage : une seule case cochée, et c'est « Followers et suivi(e)s ».
    private var pickGood: Bool { pickFollowers && pickChecked == 1 }
    private var downloading = false
    /// « Commencer l'exportation » touché : on attend qu'Instagram ait bien pris la demande.
    private var sentAt: Date?
    private var finished = false
    /// Tant qu'Instagram n'a pas dit sur quel écran il est, le bandeau patiente (évite d'afficher l'étape 1 sur la page de connexion).
    private var pageKnown = false
    /// Derniers moments où chaque cadre de la page a vu : la connexion, « Commencer l'exportation », « Créer une exportation ».
    private var seenLogin = Date.distantPast
    private var seenStart = Date.distantPast
    private var seenCreate = Date.distantPast
    private var sawStart = false
    private var webView: WKWebView!
    private let banner = UIView()
    private let gradient = CAGradientLayer()
    private let avatar = UIImageView()
    private let sayLabel = UILabel()
    private let tipLabel = UILabel()
    private let replica = UIView()
    private let replicaBox = UIView()
    private let progress = UIProgressView(progressViewStyle: .bar)
    private let prevButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
    private let loading = UIActivityIndicatorView(style: .medium)
    private var downloads: [ObjectIdentifier: URL] = [:]
    private var loadingObservation: NSKeyValueObservation?
    private var watchTimer: Timer?

    // Couleurs Zieuton, les mêmes en clair et en sombre (le bandeau reprend la carte « Mettre à jour »).
    private static let ink = UIColor(red: 0x2e / 255, green: 0x23 / 255, blue: 0x28 / 255, alpha: 1)
    private static let coral = UIColor(red: 0xef / 255, green: 0x7f / 255, blue: 0x6a / 255, alpha: 1)
    private static let peachTop = UIColor(red: 0xff / 255, green: 0xe9 / 255, blue: 0xcf / 255, alpha: 1)
    private static let peachBottom = UIColor(red: 0xfb / 255, green: 0xc4 / 255, blue: 0x93 / 255, alpha: 1)
    private static let warnTop = UIColor(red: 0xff / 255, green: 0xdd / 255, blue: 0xd6 / 255, alpha: 1)
    private static let warnBottom = UIColor(red: 0xf7 / 255, green: 0xa4 / 255, blue: 0x94 / 255, alpha: 1)
    private static let alarm = UIColor(red: 0xd9 / 255, green: 0x3f / 255, blue: 0x2e / 255, alpha: 1)
    private static let metaBlue = UIColor(red: 0x00 / 255, green: 0x64 / 255, blue: 0xe0 / 255, alpha: 1)

    private static func rounded(_ size: CGFloat, _ weight: UIFont.Weight) -> UIFont {
        let font = UIFont.systemFont(ofSize: size, weight: weight)
        guard let d = font.fontDescriptor.withDesign(.rounded) else { return font }
        return UIFont(descriptor: d, size: size)
    }

    /// Écoute les touches sur la page d'Instagram et envoie seulement le texte du bouton touché.
    /// Et toutes les 0,7 s, chaque cadre de la page dit ce qu'il affiche : écran de connexion,
    /// bouton « Commencer l'exportation », bouton « Créer une exportation » (rien d'autre n'est lu).
    private func watcherScript() -> String {
        let json: ([String]) -> String = { list in
            (try? JSONSerialization.data(withJSONObject: list.map { $0.replacingOccurrences(of: "’", with: "'").lowercased() }))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        }
        let start = json(steps.last(where: { $0.final })?.wait ?? [])
        let create = json(steps.first?.wait ?? [])
        return """
        (function () {
          document.addEventListener('click', function (e) {
            var el = e.target && e.target.closest ? e.target.closest('button,a,label,[role=button],[role=link],[role=radio],[role=checkbox],[role=menuitem],[role=option],[tabindex]') : null;
            var n = el || e.target;
            var t = (n.innerText || (n.getAttribute && n.getAttribute('aria-label')) || '').trim();
            // Touche hors d'un bouton (texte, fond) : marquée « ~ », elle ne déclenche jamais d'alerte.
            if (t) window.webkit.messageHandlers.zyeutoTap.postMessage((el ? '' : '~') + t.slice(0, 300));
          }, true);
          var START = \(start), CREATE = \(create);
          var vis = function (el) {
            var r = el.getBoundingClientRect();
            if (r.width <= 0 || r.height <= 0) return false;
            var x = r.left + r.width / 2, y = r.top + r.height / 2;
            if (x < 0 || y < 0 || x > innerWidth || y > innerHeight) return false;
            var top = document.elementFromPoint(x, y);
            return !!top && (top === el || el.contains(top) || top.contains(el));
          };
          var has = function (names) {
            if (!names.length) return false;
            return Array.prototype.some.call(document.querySelectorAll('button,a,[role=button],[tabindex]'), function (el) {
              var t = (el.innerText || '').trim().replace(/’/g, "'").toLowerCase();
              return names.indexOf(t) >= 0 && vis(el);
            });
          };
          // Quel écran d'Instagram est affiché ? On lit seulement les titres et les libellés visibles.
          var low = function (el) { return (el.innerText || '').trim().replace(/’/g, "'").toLowerCase(); };
          var seeAny = function (names) {
            var els = document.querySelectorAll('h1,h2,h3,[role=heading],span,div,label,button,a,[role=button],[role=radio],[role=checkbox]');
            for (var i = 0; i < els.length; i++) {
              var el = els[i];
              if (el.childElementCount > 3) continue;
              var t = low(el);
              if (t.length > 60 || names.indexOf(t) < 0) continue;
              if (vis(el)) return true;
            }
            return false;
          };
          // Ligne du résumé (« Période », « Format »…) avec la valeur choisie en dessous : le plus petit bloc visible qui commence par le libellé.
          var rowVal = function (labels) {
            var best = null, els = document.querySelectorAll('div,a,button,[role=button],[role=link]');
            for (var i = 0; i < els.length; i++) {
              var t = low(els[i]);
              if (t.length > 120) continue;
              for (var k = 0; k < labels.length; k++) {
                if (t.indexOf(labels[k]) === 0 && t.length > labels[k].length + 2 && (!best || t.length < best.length) && vis(els[i])) best = t;
              }
            }
            return best;
          };
          // Un libellé du parcours d'export est-il dans la page, même plus bas (hors de l'écran) ? Sert à savoir si on est « perdu ».
          var FLOW = ['créer une exportation', 'create export', 'choisissez un profil', 'choose a profile', 'choisir où exporter', 'choose where to export',
            'exporter sur mon appareil', 'export to device', 'tout effacer', 'clear all', 'depuis le début', 'all time', "commencer l'exportation", 'start export',
            'télécharger', 'download', 'personnaliser les informations', 'customize information'];
          var inFlow = function () {
            var els = document.querySelectorAll('h1,h2,h3,[role=heading],span,div,label,button,a,[role=button]');
            for (var i = 0; i < els.length; i++) {
              if (els[i].childElementCount > 3) continue;
              var t = low(els[i]);
              if (t.length <= 60 && FLOW.indexOf(t) >= 0 && els[i].getBoundingClientRect().width > 0) return true;
            }
            return false;
          };
          // Page des cases à cocher : combien sont cochées, et « Followers et suivi(e)s » l'est-elle ? (aucun autre contenu lu)
          var pickState = function () {
            var boxes = document.querySelectorAll('input[type=checkbox],[role=checkbox]');
            var n = 0, f = false, seen = 0;
            for (var i = 0; i < boxes.length; i++) {
              var el = boxes[i];
              var row = el.closest('label,[role=listitem],[role=row],li') || el.parentElement;
              // Case sans texte autour : on remonte (4 niveaux max) jusqu'au libellé de la ligne.
              for (var up = 0; up < 4 && row && !low(row) && row.parentElement; up++) row = row.parentElement;
              if (!row || row.getClientRects().length === 0) continue;
              seen++;
              var on = el.checked === true || el.getAttribute('aria-checked') === 'true';
              if (!on) continue;
              n++;
              var t = low(row);
              if (t.indexOf('followers et suivi') >= 0 || t.indexOf('followers and following') >= 0) f = true;
            }
            return seen ? { n: n, f: f } : null;
          };
          var hasWord = function (t, words) { return words.some(function (w) { return t.indexOf(w) >= 0; }); };
          var screen = function () {
            if (has(START)) {
              var info = rowVal(['personnaliser les informations', 'customize information']);
              var per = rowVal(['période', 'date range']);
              var fmt = rowVal(['format']);
              if (info === null || per === null || fmt === null) return 'summary';
              if (hasWord(info, ['toutes les informations', 'all available', 'all information'])) return 'summary:info';
              if (hasWord(per, ['dernière', 'dernier', 'derniers', 'last '])) return 'summary:period';
              if (hasWord(fmt, ['html'])) return 'summary:format';
              return 'summary:start';
            }
            if (seeAny(['choisissez un profil', 'choose a profile'])) return 'profile';
            if (seeAny(['exporter vers un service externe', 'export to external service', 'choisir où exporter', 'choose where to export'])) return 'dest';
            if (seeAny(['depuis le début', 'all time'])) return 'period';
            if (seeAny(['json']) && seeAny(['html'])) return 'format';
            if (seeAny(['tout effacer', 'clear all', 'tout sélectionner', 'select all'])) return 'pick';
            if (has(CREATE)) return 'home';
            return '';
          };
          setInterval(function () {
            var login = Array.prototype.some.call(document.querySelectorAll('input[type=password],input[name=username],input[name=email],input[autocomplete=username]'), vis);
            // Code de sécurité : on regarde seulement s'il y a une case pour un code, et si la page parle de WhatsApp, SMS ou e-mail.
            var codeIn = Array.prototype.some.call(document.querySelectorAll('input[autocomplete="one-time-code"],input[name*="code" i],input[aria-label*="code" i],input[placeholder*="code" i]'), vis);
            var code = '';
            if (codeIn && !login) {
              var txt = (document.body.innerText || '').toLowerCase();
              code = txt.indexOf('whatsapp') >= 0 ? 'whatsapp'
                : (txt.indexOf('sms') >= 0 || txt.indexOf('texto') >= 0 || txt.indexOf('text message') >= 0) ? 'sms'
                : (txt.indexOf('e-mail') >= 0 || txt.indexOf('email') >= 0) ? 'email' : 'app';
            }
            window.webkit.messageHandlers.zyeutoState.postMessage({ login: login, code: code, screen: login || code ? '' : screen(), flow: inFlow(), pick: login || code ? null : pickState(), start: has(START), create: has(CREATE), dl: \(ExportWatcher.countScript) });
          }, 700);
        })();
        """
    }

    static let autoDownloadScript = """
    (function () {
      var taps = 0, last = 0;
      setInterval(function () {
        if (taps >= 2 || Date.now() - last < 5000) return;
        if (document.querySelector('input[type=password], input[autocomplete=one-time-code]')) return;
        var btn = Array.prototype.find.call(document.querySelectorAll('button,a,[role=button]'), function (el) {
          var t = (el.innerText || '').trim().toLowerCase(); var r = el.getBoundingClientRect();
          return (t === 'télécharger' || t === 'download') && r.width > 0 && r.height > 0 && !el.disabled
            && el.getAttribute('aria-disabled') !== 'true';
        });
        if (!btn) return;
        taps++; last = Date.now();
        btn.scrollIntoView({ block: 'center' });
        setTimeout(function () { btn.click(); }, 600);
      }, 1200);
    })();
    """

    init(url: URL, requesting: Bool, steps: [Step]) {
        self.url = url
        self.requesting = requesting
        self.steps = steps.isEmpty ? [Step(target: "Suis les étapes d'Instagram")] : steps
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) non utilisé") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        // Barre du haut : bouton retour en pastille, et l'adresse officielle d'Instagram bien visible.
        var backConfig = UIButton.Configuration.filled()
        backConfig.image = UIImage(systemName: "chevron.left", withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .bold))
        backConfig.imagePadding = 6
        backConfig.title = "Zieuton"
        backConfig.baseBackgroundColor = Self.peachTop
        backConfig.baseForegroundColor = Self.ink
        backConfig.cornerStyle = .capsule
        backConfig.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 11, bottom: 7, trailing: 14)
        backConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { a in
            var a = a; a.font = MetaViewController.rounded(15, .bold); return a
        }
        let back = UIButton(configuration: backConfig, primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) })
        let title = UILabel()
        title.numberOfLines = 2
        title.textAlignment = .center
        let t = NSMutableAttributedString(string: "Instagram\n", attributes: [.font: Self.rounded(15, .semibold), .foregroundColor: UIColor.label])
        t.append(NSAttributedString(string: "🔒 accountscenter.instagram.com", attributes: [.font: UIFont.systemFont(ofSize: 10.5), .foregroundColor: UIColor.secondaryLabel]))
        title.attributedText = t
        let top = UIView()
        loading.hidesWhenStopped = true
        for v in [back, title, loading] as [UIView] { v.translatesAutoresizingMaskIntoConstraints = false; top.addSubview(v) }

        buildBanner()

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default() // on reste connecté à Instagram d'une fois sur l'autre
        let content = WKUserContentController()
        content.addUserScript(WKUserScript(source: watcherScript(), injectionTime: .atDocumentEnd, forMainFrameOnly: false))
        // Ouvert pour récupérer le fichier (notification « prêt ») : Zieuton touche lui-même « Télécharger »,
        // le fichier s'importe tout seul ensuite. Deux essais au plus (Instagram redemande parfois une confirmation),
        // jamais pendant un mot de passe ou un code.
        if !requesting {
            content.addUserScript(WKUserScript(source: Self.autoDownloadScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false))
        }
        content.add(WeakHandler(self), name: "zyeutoTap")
        content.add(WeakHandler(self), name: "zyeutoState")
        config.userContentController = content
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        loadingObservation = webView.observe(\.isLoading, options: [.new]) { [weak self] web, _ in
            let busy = web.isLoading
            DispatchQueue.main.async {
                if busy { self?.loading.startAnimating() } else { self?.loading.stopAnimating() }
            }
        }

        for v in [top, webView as UIView, banner] { v.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(v) }
        let g = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            top.topAnchor.constraint(equalTo: g.topAnchor),
            top.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            top.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            top.heightAnchor.constraint(equalToConstant: 48),
            back.leadingAnchor.constraint(equalTo: top.leadingAnchor, constant: 12),
            back.centerYAnchor.constraint(equalTo: top.centerYAnchor),
            title.centerXAnchor.constraint(equalTo: top.centerXAnchor),
            title.centerYAnchor.constraint(equalTo: top.centerYAnchor),
            loading.trailingAnchor.constraint(equalTo: top.trailingAnchor, constant: -16),
            loading.centerYAnchor.constraint(equalTo: top.centerYAnchor),
            banner.topAnchor.constraint(equalTo: top.bottomAnchor, constant: 2),
            banner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            banner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            webView.topAnchor.constraint(equalTo: banner.bottomAnchor, constant: 6),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        showStep(animated: false)
        webView.load(URLRequest(url: url))
        // Toutes les 0,5 s : on fait le point avec ce que les cadres de la page ont signalé.
        watchTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.watch() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradient.frame = banner.bounds
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        watchTimer?.invalidate()
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "zyeutoTap")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "zyeutoState")
    }

    // MARK: Bandeau (compact : la page d'Instagram garde la place)

    private func buildBanner() {
        banner.layer.cornerRadius = 18
        banner.layer.cornerCurve = .continuous
        banner.layer.shadowColor = UIColor.black.cgColor
        banner.layer.shadowOpacity = 0.12
        banner.layer.shadowRadius = 8
        banner.layer.shadowOffset = CGSize(width: 0, height: 3)
        gradient.colors = [Self.peachTop.cgColor, Self.peachBottom.cgColor]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        gradient.cornerRadius = 18
        gradient.cornerCurve = .continuous
        banner.layer.insertSublayer(gradient, at: 0)

        avatar.image = Data(base64Encoded: WebViewController.logoPNG).flatMap { UIImage(data: $0, scale: 3) }
        avatar.layer.cornerRadius = 10
        avatar.layer.cornerCurve = .continuous
        avatar.clipsToBounds = true
        avatar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([avatar.widthAnchor.constraint(equalToConstant: 34), avatar.heightAnchor.constraint(equalToConstant: 34)])

        sayLabel.numberOfLines = 2
        sayLabel.adjustsFontSizeToFitWidth = true
        sayLabel.minimumScaleFactor = 0.8
        tipLabel.font = Self.rounded(13, .regular)
        tipLabel.textColor = Self.ink.withAlphaComponent(0.75)
        tipLabel.numberOfLines = 2

        // Précédent / Suivant en petites pastilles : le bandeau avance tout seul, elles servent seulement en secours.
        for (b, name) in [(prevButton, "chevron.left"), (nextButton, "chevron.right")] {
            var c = UIButton.Configuration.filled()
            c.image = UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .bold))
            c.baseBackgroundColor = UIColor.white.withAlphaComponent(0.6)
            c.baseForegroundColor = Self.ink
            c.cornerStyle = .capsule
            c.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 9, bottom: 8, trailing: 9)
            b.configuration = c
        }
        prevButton.addAction(UIAction { [weak self] _ in self?.go(-1) }, for: .touchUpInside)
        nextButton.addAction(UIAction { [weak self] _ in self?.go(1) }, for: .touchUpInside)
        prevButton.accessibilityLabel = "Étape précédente"
        nextButton.accessibilityLabel = "Étape suivante"

        let head = UIStackView(arrangedSubviews: [avatar, sayLabel, prevButton, nextButton])
        head.spacing = 8
        head.setCustomSpacing(10, after: avatar)
        head.alignment = .center
        sayLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        // Le texte prend toute la place libre ; les flèches gardent leur taille de petite pastille ronde.
        sayLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        for b in [prevButton, nextButton] {
            b.setContentHuggingPriority(.required, for: .horizontal)
            b.setContentCompressionResistancePriority(.required, for: .horizontal)
            b.translatesAutoresizingMaskIntoConstraints = false
            b.widthAnchor.constraint(equalToConstant: 34).isActive = true
            b.heightAnchor.constraint(equalToConstant: 34).isActive = true
        }

        // Le bouton à chercher, redessiné comme chez Instagram et entouré comme dans le guide.
        replicaBox.layer.cornerRadius = 13
        replicaBox.layer.cornerCurve = .continuous
        replicaBox.layer.borderWidth = 2.5
        replicaBox.layer.borderColor = Self.coral.cgColor
        replicaBox.backgroundColor = UIColor.white.withAlphaComponent(0.5)
        replica.translatesAutoresizingMaskIntoConstraints = false
        replicaBox.addSubview(replica)
        NSLayoutConstraint.activate([
            replica.topAnchor.constraint(equalTo: replicaBox.topAnchor, constant: 4),
            replica.bottomAnchor.constraint(equalTo: replicaBox.bottomAnchor, constant: -4),
            replica.leadingAnchor.constraint(equalTo: replicaBox.leadingAnchor, constant: 4),
            replica.trailingAnchor.constraint(equalTo: replicaBox.trailingAnchor, constant: -4),
        ])

        progress.progressTintColor = Self.ink
        progress.trackTintColor = Self.ink.withAlphaComponent(0.12)
        progress.layer.cornerRadius = 2
        progress.clipsToBounds = true
        progress.translatesAutoresizingMaskIntoConstraints = false
        progress.heightAnchor.constraint(equalToConstant: 4).isActive = true

        let all = UIStackView(arrangedSubviews: [progress, head, replicaBox, tipLabel])
        all.axis = .vertical
        all.spacing = 8
        all.translatesAutoresizingMaskIntoConstraints = false
        banner.addSubview(all)
        NSLayoutConstraint.activate([
            all.topAnchor.constraint(equalTo: banner.topAnchor, constant: 10),
            all.bottomAnchor.constraint(equalTo: banner.bottomAnchor, constant: -10),
            all.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 12),
            all.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -12),
        ])
        // Toucher le bandeau ferme l'alerte.
        banner.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(bannerTapped)))
    }

    @objc private func bannerTapped() {
        // Hors du parcours d'export : on ramène sur la page d'export d'Instagram, et le bandeau repart de là.
        if lostShown {
            lostShown = false
            index = 0
            pickedAt = -1
            warning = nil
            seenScreen = .distantPast
            lostCheckFrom = Date()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            webView.load(URLRequest(url: url))
            showStep()
            return
        }
        guard warning != nil else { return }
        warning = nil
        showStep()
    }

    /// Redessine le bouton d'Instagram : bouton bleu, ligne avec flèche, lien bleu, bouton radio ou case à cocher.
    private func drawReplica(_ step: Step) {
        replica.subviews.forEach { $0.removeFromSuperview() }
        let label = UILabel()
        label.text = step.target.prefix(1).uppercased() + step.target.dropFirst()
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        let row = UIView()
        row.layer.cornerRadius = step.look == "button" ? 17 : 9
        row.layer.cornerCurve = .continuous
        var parts: [UIView] = [label]
        switch step.look {
        case "button":
            row.backgroundColor = Self.metaBlue
            label.textColor = .white
            label.font = .systemFont(ofSize: 15, weight: .semibold)
            label.textAlignment = .center
        case "link":
            row.backgroundColor = .white
            let left = UILabel()
            left.text = "Rubrique"
            left.font = .systemFont(ofSize: 14)
            left.textColor = .systemGray
            label.textColor = Self.metaBlue
            label.font = .systemFont(ofSize: 15, weight: .semibold)
            label.textAlignment = .right
            parts = [left, label]
        default:
            row.backgroundColor = .white
            label.textColor = .black
            label.font = .systemFont(ofSize: 15, weight: .medium)
            let mark = UIImageView(image: UIImage(systemName:
                step.look == "radio" ? "largecircle.fill.circle" : step.look == "check" ? "checkmark.square.fill" : "chevron.right"))
            mark.tintColor = step.look == "row" ? .systemGray2 : Self.metaBlue
            mark.contentMode = .scaleAspectFit
            mark.setContentHuggingPriority(.required, for: .horizontal)
            parts = [label, mark]
        }
        let line = UIStackView(arrangedSubviews: parts)
        line.spacing = 10
        line.alignment = .center
        line.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(line)
        row.translatesAutoresizingMaskIntoConstraints = false
        replica.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: replica.topAnchor),
            row.bottomAnchor.constraint(equalTo: replica.bottomAnchor),
            row.leadingAnchor.constraint(equalTo: replica.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: replica.trailingAnchor),
            row.heightAnchor.constraint(equalToConstant: 34),
            line.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
            line.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -14),
            line.centerYAnchor.constraint(equalTo: row.centerYAnchor),
        ])
    }

    // MARK: Étapes

    private var currentStep: Step {
        if !pageKnown {
            return Step(verb: "Un instant,", target: "Instagram s'ouvre…")
        }
        if downloading {
            return Step(verb: "Presque fini :", target: "Zieuton récupère ton fichier…", tip: "Ne ferme pas cet écran.")
        }
        if !codeShown.isEmpty {
            let place: (String, String) = {
                switch codeShown {
                case "whatsapp": return ("va chercher le code sur WhatsApp", "Instagram vient de te l'envoyer sur WhatsApp. Ouvre WhatsApp, note le code, puis reviens ici le taper.")
                case "sms": return ("regarde tes SMS", "Instagram vient de t'envoyer un code par SMS. Tape-le ici : souvent, ton iPhone te le propose tout seul au-dessus du clavier.")
                case "email": return ("regarde tes e-mails", "Instagram vient de t'envoyer un code par e-mail. Ouvre ta boîte mail, note le code, puis reviens ici le taper.")
                default: return ("tape le code de sécurité", "Instagram vérifie que c'est bien toi. Le code arrive par WhatsApp, SMS ou e-mail, selon ton compte.")
                }
            }()
            return Step(verb: "Petite vérif d'Instagram :", target: place.0,
                        tip: place.1 + " Zieuton ne voit jamais ce code. En général, Instagram ne le demande qu'à la première connexion.")
        }
        if loginShown {
            return index == 0 && sentAt == nil
                ? Step(verb: "D'abord,", target: "connecte-toi à Instagram",
                       tip: "Ton mot de passe se tape chez Instagram : Zieuton ne le voit jamais. Tu ne le feras qu'une fois.")
                : Step(verb: "Instagram vérifie que c'est toi :", target: "tape ton mot de passe",
                       tip: "Chez Instagram, comme d'habitude. Zieuton ne le voit jamais.")
        }
        if let sent = sentAt {
            return Step(verb: "Bien joué !", target: "Instagram enregistre ta demande…",
                        tip: Date().timeIntervalSince(sent) > 15
                            ? "Rien ne bouge ? Touche encore « Commencer l'exportation » sur la page."
                            : "Zieuton vérifie que c'est bien parti.")
        }
        if lostShown {
            return Step(verb: "Tu t'es un peu éloigné :", target: "Revenir à l'export",
                        tip: "Touche ici, je te ramène sur la bonne page d'Instagram.", look: "button")
        }
        if let w = warning {
            return Step(verb: "", target: w.title, tip: w.text, look: steps[index].look)
        }
        // Page des cases : le bandeau dit exactement ce qu'il reste à faire, et n'avance pas tant que ce n'est pas bon.
        if steps[index].screen == "pick", pickFresh {
            if !pickFollowers {
                return Step(verb: "Coche", target: "Followers et suivi(e)s",
                            tip: "Dans la rubrique Contacts. C'est la seule case qui compte.", look: "check", screen: "pick")
            }
            if pickChecked > 1 {
                let more = pickChecked - 1
                return Step(verb: "Encore \(more) case\(more > 1 ? "s" : "") à décocher :", target: "garde seulement Followers et suivi(e)s",
                            tip: "Le plus rapide : « Tout effacer » dans chaque rubrique, puis recoche « Followers et suivi(e)s ».", look: "check", screen: "pick")
            }
            return Step(verb: "Parfait ! Maintenant,", target: "Enregistrer", tip: "Tout en bas de la liste.", look: "button", screen: "pick")
        }
        return steps[index]
    }

    /// Ce que le bandeau affiche en ce moment : on ne le redessine que si ça change vraiment.
    private var shownKey = ""

    private func showStep(animated: Bool = true) {
        let step = currentStep
        let normal = pageKnown && codeShown.isEmpty && !(loginShown || downloading || sentAt != nil)
        let key = [step.verb, step.target, step.after, step.tip, step.look, normal ? "1" : "0", String(index), warning == nil ? "" : "!", lostShown ? "L" : ""].joined(separator: "|")
        guard key != shownKey else { return }
        shownKey = key
        let apply = {
            let say = NSMutableAttributedString()
            if !step.verb.isEmpty {
                say.append(NSAttributedString(string: step.verb + " ", attributes: [.font: Self.rounded(15, .medium), .foregroundColor: Self.ink.withAlphaComponent(0.7)]))
            }
            say.append(NSAttributedString(string: step.target, attributes: [.font: Self.rounded(18, .heavy), .foregroundColor: Self.ink]))
            if !step.after.isEmpty {
                say.append(NSAttributedString(string: ", " + step.after, attributes: [.font: Self.rounded(15, .semibold), .foregroundColor: Self.ink]))
            }
            self.sayLabel.attributedText = say
            // Alerte : le bandeau passe au rouge doux, et garde le bouton à chercher bien visible.
            let warn = self.warning != nil && normal
            CATransaction.begin()
            CATransaction.setAnimationDuration(animated ? 0.25 : 0)
            self.gradient.colors = warn ? [Self.warnTop.cgColor, Self.warnBottom.cgColor] : [Self.peachTop.cgColor, Self.peachBottom.cgColor]
            CATransaction.commit()
            self.replicaBox.layer.borderColor = (warn ? Self.alarm : Self.coral).cgColor
            self.tipLabel.text = step.tip
            self.tipLabel.isHidden = step.tip.isEmpty
            self.replicaBox.isHidden = step.look.isEmpty || !normal
            if normal && !step.look.isEmpty { self.drawReplica(self.warning == nil ? step : self.steps[self.index]) }
            self.progress.isHidden = !normal || self.steps.count < 2
            // À la première étape, pas de flèche « précédent » grisée : elle n'apparaît qu'à partir de l'étape 2.
            self.prevButton.isHidden = !normal || self.lostShown || self.steps.count < 2 || self.index == 0
            self.nextButton.isHidden = !normal || self.lostShown || self.steps.count < 2
            self.prevButton.isEnabled = self.index > 0
            // Pas de « Suivant » sur la dernière étape : c'est le vrai bouton d'Instagram qui valide.
            self.nextButton.isEnabled = self.index < self.steps.count - 1
                && !(self.steps[self.index].screen == "pick" && self.pickFresh && !self.pickGood)
        }
        // Pas de fondu sur tout le bandeau (l'ancien texte restait visible derrière le nouveau) :
        // on remplace le contenu d'un coup, seul le texte apparaît en fondu, et la taille du bandeau suit en douceur.
        banner.layer.removeAllAnimations()
        if animated {
            for v in [sayLabel, tipLabel, replica] as [UIView] {
                v.layer.removeAllAnimations()
                let fade = CATransition()
                fade.type = .fade
                fade.duration = 0.2
                v.layer.add(fade, forKey: "zyFade")
            }
        }
        apply()
        if animated, warning != nil, normal {
            let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
            shake.values = [0, -9, 9, -6, 6, -3, 0]
            shake.duration = 0.4
            banner.layer.add(shake, forKey: "zyShake")
        }
        progress.setProgress(Float(index + 1) / Float(steps.count + 1), animated: animated)
        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
                self.view.layoutIfNeeded()
            }
        }
    }

    private func go(_ delta: Int) {
        if delta > 0, steps[index].screen == "pick", pickFresh, !pickGood { UINotificationFeedbackGenerator().notificationOccurred(.warning); return }
        let n = max(0, min(steps.count - 1, index + delta))
        guard n != index || warning != nil else { return }
        index = n
        warning = nil
        UISelectionFeedbackGenerator().selectionChanged()
        showStep()
    }

    private static func norm(_ s: String) -> String {
        s.replacingOccurrences(of: "’", with: "'").folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    /// Un bouton vient d'être touché sur la page d'Instagram : on regarde s'il termine l'étape en cours
    /// (ou l'une des deux suivantes, si on a été plus vite que le bandeau). Sinon, si ce n'est pas
    /// une touche normale de l'étape, le bandeau prévient tout de suite : « Oups, pas le bon bouton ! ».
    private func tapped(_ text: String) {
        guard !finished, !downloading else { return }
        let loose = text.hasPrefix("~")
        let t = Self.norm(loose ? String(text.dropFirst()) : text)
        let has: ([String]) -> Bool = { list in list.contains { !$0.isEmpty && t.contains(Self.norm($0)) } }
        lastTapAt = Date()
        let last = min(steps.count - 1, index + 2)
        guard index <= last else { return }
        let checking = guarded && pageKnown && !loginShown && codeShown.isEmpty && !lostShown && sentAt == nil
        for i in index...last {
            let step = steps[i]
            guard has(step.wait) else { continue }
            // « Enregistrer » sur la page des cases sans le bon réglage : on n'avance pas, on renvoie à « Personnaliser les informations ».
            if checking, step.screen == "pick", steps[index].screen == "pick", pickFresh, !pickGood {
                index = steps.firstIndex(where: { $0.screen == "summary:info" }) ?? index
                pickRedo = true
                warn("Attention, pas les bonnes cases !", pickFollowers
                     ? "Il restait d'autres cases cochées. Touche encore « Personnaliser les informations » et garde seulement « Followers et suivi(e)s »."
                     : "« Followers et suivi(e)s » n'était pas cochée. Touche encore « Personnaliser les informations » et coche-la.")
                return
            }
            // « Enregistrer » sans avoir choisi la bonne option : Instagram a gardé son réglage par défaut.
            if checking, step.pick, pickedAt != i, step.redo >= 0, step.redo < steps.count {
                index = step.redo
                pickedAt = -1
                warn("Attention, pas le bon réglage !", step.redoOops.isEmpty ? step.oops : step.redoOops)
                return
            }
            if step.final, requesting {
                index = i
                sentAt = Date()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } else {
                index = min(steps.count - 1, i + 1)
                UISelectionFeedbackGenerator().selectionChanged()
            }
            warning = nil
            showStep()
            return
        }
        guard checking else { return }
        // Une bonne touche pendant l'étape (« Tout effacer », « Depuis le début », « JSON »…).
        for i in index...last where has(steps[i].ok ?? []) {
            index = i
            if steps[i].pick { pickedAt = i }
            if warning != nil { warning = nil }
            showStep()
            return
        }
        // Un mauvais choix connu (« Année dernière », « HTML », compte Facebook…).
        for i in index...last where !loose && has(steps[i].bad) {
            index = i
            if steps[i].pick { pickedAt = -1 }
            warn("Oups, pas le bon choix !", steps[i].oops.isEmpty ? Self.backHint : steps[i].oops)
            return
        }
        // « Créer une exportation » retouché plus tard : on reprend au début, sans gronder.
        if index > 0, has(steps[0].wait) { index = 1; warning = nil; showStep(); return }
        // Flèche retour, croix, Annuler : la personne revient en arrière, très bien.
        if ["retour", "back", "fermer", "close", "annuler", "cancel", "precedent", "previous"].contains(t.trimmingCharacters(in: .whitespacesAndNewlines)) {
            if warning != nil { warning = nil; showStep() }
            return
        }
        // Cases à cocher libres, ou grand bloc de texte (une zone vide de la page) : rien à dire.
        if loose || steps[index].free || t.count > 120 { return }
        warn("Oups, pas le bon bouton !", Self.backHint)
    }

    private static let backHint = "Reviens en arrière avec la flèche ‹ ou la croix ✕ d'Instagram, puis touche le bouton entouré ici. Sinon, tu risques de te perdre."

    private func warn(_ title: String, _ text: String) {
        warning = Warning(title: title, text: text)
        warningAt = Date()
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        shownKey = "" // redessine même si c'était déjà la même alerte (on secoue encore)
        showStep()
    }

    /// Un cadre de la page dit ce qu'il affiche.
    private func received(state: [String: Any], mainFrame: Bool) {
        let now = Date()
        if state["login"] as? Bool == true { seenLogin = now }
        if let code = state["code"] as? String, !code.isEmpty { seenCode = now; codeKind = code }
        if state["flow"] as? Bool == true { seenFlow = now }
        if let pick = state["pick"] as? [String: Any], let n = pick["n"] as? Int {
            let before = (pickChecked, pickFollowers)
            pickChecked = n
            pickFollowers = pick["f"] as? Bool == true
            seenPick = now
            if before != (pickChecked, pickFollowers), steps[index].screen == "pick" { showStep() }
        }
        if let scr = state["screen"] as? String, !scr.isEmpty {
            if scr != screenKey { screenKey = scr; screenSince = now }
            if scr == "pick" || scr == "home" { pickRedo = false }
            seenScreen = now
        }
        if state["start"] as? Bool == true { seenStart = now; sawStart = true }
        if state["create"] as? Bool == true { seenCreate = now }
        if !finished, let dl = state["dl"] as? Int { downloadsSeen = max(downloadsSeen, dl) }
        if mainFrame && !pageKnown {
            pageKnown = true
            loginShown = state["login"] as? Bool == true || (webView.url?.absoluteString.lowercased() ?? "").contains("login")
            showStep()
        }
    }

    /// Fait le point : écran de connexion ? demande bien partie ?
    private func watch() {
        guard pageKnown, !downloading, !finished else { return }
        let now = Date()
        let onLoginURL = (webView.url?.absoluteString.lowercased() ?? "").contains("login")
        let login = now.timeIntervalSince(seenLogin) < 1.6 || onLoginURL
        let startVisible = now.timeIntervalSince(seenStart) < 1.6
        let createVisible = now.timeIntervalSince(seenCreate) < 1.6
        if login != loginShown { loginShown = login; showStep() }
        let code = now.timeIntervalSince(seenCode) < 1.6 ? codeKind : ""
        if code != codeShown { codeShown = code; warning = nil; showStep() }
        // Perdu ? Aucun écran du parcours reconnu depuis 2 s, et l'adresse n'est plus celle de l'export (ou rien de reconnu depuis 6 s).
        let urlNow = webView.url?.absoluteString.lowercased() ?? ""
        let offPath = !urlNow.isEmpty && !urlNow.contains("/dyi") && !onLoginURL
        if offPath { if offSince == nil { offSince = now } } else { offSince = nil }
        let unknownFor = now.timeIntervalSince(max(seenScreen, seenFlow, lostCheckFrom))
        let lost = !login && code.isEmpty && sentAt == nil && !webView.isLoading && unknownFor > 2
            && ((offSince.map { now.timeIntervalSince($0) > 1.5 } ?? false) || unknownFor > 6)
        if lost != lostShown { lostShown = lost; warning = nil; showStep() }
        // L'alerte s'efface toute seule au bout de 10 s : le bandeau remontre l'étape à faire.
        if warning != nil, now.timeIntervalSince(warningAt) > 10 { warning = nil; showStep() }
        guard requesting, !login else { return }
        // Revenu sur la page d'accueil de l'export (« Créer une exportation » bien visible depuis un moment) :
        // le bandeau reprend à la première étape.
        if createVisible { if createSince == nil { createSince = now } } else { createSince = nil }
        if sentAt == nil, index > 0, !(sawStart && index >= steps.count - 1), let since = createSince,
           now.timeIntervalSince(since) > 2.5, now.timeIntervalSince(lastTapAt) > 2.5 {
            index = 0
            pickedAt = -1
            warning = nil
            createSince = nil
            showStep()
            return
        }
        // Le bandeau suit l'écran d'Instagram : si l'écran affiché correspond à une autre étape, on s'y cale.
        syncToScreen(now)
        // « Commencer l'exportation » a été touché, et Instagram a quitté cet écran (retour à « Créer une exportation »,
        // ou le bouton a disparu) : la demande est partie. Si la touche n'a pas été vue, le retour à l'accueil
        // d'Instagram juste après l'écran final suffit aussi.
        if let sent = sentAt {
            if now.timeIntervalSince(sent) > 1.5, createVisible || !startVisible { finishRequest() }
            else if now.timeIntervalSince(sent) > 15 { showStep(animated: false) }
        } else if sawStart, index >= steps.count - 1, createVisible, !startVisible {
            finishRequest()
        }
    }

    /// Cale le bandeau sur l'étape qui correspond à l'écran d'Instagram (vu depuis au moins 1 s, sans touche récente).
    private func syncToScreen(_ now: Date) {
        guard sentAt == nil, codeShown.isEmpty, !loginShown,
              now.timeIntervalSince(seenScreen) < 1.6, now.timeIntervalSince(screenSince) > 1.0,
              now.timeIntervalSince(lastTapAt) > 0.8,
              !(sawStart && index >= steps.count - 1) else { return }
        // Une alerte toute fraîche reste lisible 3 s avant que le bandeau ne bouge.
        if warning != nil, now.timeIntervalSince(warningAt) < 3 { return }
        let scr = screenKey
        if pickRedo, scr.hasPrefix("summary") { return }
        guard !steps[index].screen.isEmpty, steps[index].screen != scr,
              let target = steps.firstIndex(where: { $0.screen == scr }) else { return }
        index = target
        if !steps[target].pick { pickedAt = -1 }
        warning = nil
        createSince = nil
        UISelectionFeedbackGenerator().selectionChanged()
        showStep()
    }

    private func finishRequest() {
        guard !finished else { return }
        finished = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let done = onRequested
        let before = downloadsSeen
        // On laisse une seconde pour voir la confirmation d'Instagram.
        sayLabel.attributedText = NSAttributedString(string: "C'est parti ! Instagram prépare ta liste.",
                                                     attributes: [.font: Self.rounded(18, .heavy), .foregroundColor: Self.ink])
        tipLabel.text = "Zieuton te prévient dès que ton fichier est prêt."
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            self?.dismiss(animated: true) { done?(before) }
        }
    }

    private func failed(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension MetaViewController: WKScriptMessageHandler {
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "zyeutoState", let state = message.body as? [String: Any] {
            received(state: state, mainFrame: message.frameInfo.isMainFrame)
        } else if message.name == "zyeutoTap", let text = message.body as? String {
            tapped(text)
        }
    }
}

extension MetaViewController: WKNavigationDelegate, WKUIDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if action.shouldPerformDownload { decisionHandler(.download); return }
        // Liens vers une autre app (instagram://, App Store…) : on reste ici.
        let scheme = action.request.url?.scheme ?? ""
        decisionHandler(["http", "https", "blob", "data", "about"].contains(scheme) ? .allow : .cancel)
    }

    func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        let disposition = (response.response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Disposition") ?? ""
        let isFile = disposition.lowercased().contains("attachment") || !response.canShowMIMEType
            || ["application/zip", "application/x-zip-compressed", "application/octet-stream"].contains(response.response.mimeType ?? "")
        decisionHandler(isFile && response.isForMainFrame ? .download : .allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Au cas où la page ne dit rien (page d'erreur…), le bandeau n'attend pas indéfiniment.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self, !self.pageKnown else { return }
            self.pageKnown = true
            self.showStep()
        }
        watch()
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
    }

    // « Télécharger » ouvre parfois un nouvel onglet : on le charge ici.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        webView.load(action.request)
        return nil
    }

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

extension MetaViewController: WKDownloadDelegate {
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse,
                  suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent(suggestedFilename.isEmpty ? "instagram.zip" : suggestedFilename)
        downloads[ObjectIdentifier(download)] = file
        DispatchQueue.main.async {
            self.downloading = true
            self.showStep()
        }
        completionHandler(file)
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let file = downloads.removeValue(forKey: ObjectIdentifier(download)) else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        ExportWatcher.shared.downloaded()
        let deliver = onFile
        dismiss(animated: true) { deliver?(file) }
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        downloads.removeValue(forKey: ObjectIdentifier(download))
        downloading = false
        showStep(animated: false)
        failed("Le téléchargement n'a pas abouti. Vérifie ta connexion et touche encore « Télécharger ».")
    }
}

// MARK: Notifications de l'export Instagram

/// Suit l'export Instagram du début à la fin et prévient par notification, comme les e-mails d'Instagram :
/// 1. « C'est demandé » (l'e-mail « Votre demande de téléchargement Meta est en cours »),
/// 2. « Ton fichier est prêt » (l'e-mail « Votre téléchargement d'informations Meta est prêt »),
/// 3. « Dernier jour » (le fichier n'est téléchargeable que 4 jours).
///
/// Pour savoir si le fichier est prêt, Zieuton ouvre en cachette la page « Exporter vos informations »
/// (la même session Instagram que dans l'app, jamais le mot de passe) et compte les boutons « Télécharger ».
/// Il ne touche rien sur la page : il la lit, c'est tout.
/// Quand Zieuton est ouvert : vérification toutes les 30 s. Zieuton fermé : iOS le réveille de temps en temps
/// (quand il veut) ; sinon un rappel part au bout de 12 minutes (en vrai, Instagram met 4 à 8 minutes).
final class ExportWatcher: NSObject {
    static let shared = ExportWatcher()
    static let taskID = "fr.zyeuto.app.check"
    static let exportURL = URL(string: "https://accountscenter.instagram.com/info_and_permissions/dyi/")!

    /// Expression JS : nombre de boutons « Télécharger » affichés par la page (ou le cadre).
    static let countScript = """
    Array.prototype.filter.call(document.querySelectorAll('button,a,[role=button]'), function (el) { \
    var t = (el.innerText || '').trim().toLowerCase(); var r = el.getBoundingClientRect(); \
    return (t === 'télécharger' || t === 'download') && r.width > 0 && r.height > 0; }).length
    """

    private enum Key {
        static let requested = "zy.export.requestedAt", ready = "zy.export.readyAt", before = "zy.export.downloadsBefore"
        static let baselineChecked = "zy.export.baselineChecked"
    }
    private enum Id {
        static let asked = "zy-asked", ready = "zy-ready", reminder = "zy-reminder", lastDay = "zy-last-day"
        /// Filet de sécurité : iOS ne laisse pas Zieuton vérifier quand il est fermé, alors on prévient quand même.
        static let likely = "zy-likely"
        static let all = [asked, ready, likely, reminder, lastDay, "zyeuto-export"]
        /// Notifications avec un bouton « Mettre à jour » (appui long ou glisser vers le bas).
        static let readyCategory = "zy-ready-actions"
    }

    override init() {
        super.init()
        let update = UNNotificationAction(identifier: "zy-update", title: "Mettre à jour maintenant", options: [.foreground],
                                          icon: UNNotificationActionIcon(systemImageName: "arrow.down.circle"))
        UNUserNotificationCenter.current().setNotificationCategories([
            UNNotificationCategory(identifier: Id.readyCategory, actions: [update], intentIdentifiers: [], options: []),
        ])
    }

    // MARK: Textes précis (heures et durées en français)

    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.setLocalizedDateFormatFromTemplate(format)
        return f
    }
    /// « 14:47 »
    static func hour(_ d: Date) -> String { formatter("Hm").string(from: d) }
    /// « mercredi 5 novembre à 14:47 »
    static func day(_ d: Date) -> String { formatter("EEEEdMMMM").string(from: d) + " à " + hour(d) }
    /// « 1 min 12 s », « 7 min », « 1 h 05 »
    static func duration(_ t: TimeInterval) -> String {
        let s = Int(t.rounded())
        if s < 60 { return "\(s) s" }
        if s < 600 { return s % 60 == 0 ? "\(s / 60) min" : "\(s / 60) min \(s % 60) s" }
        if s < 3600 { return "\(s / 60) min" }
        return String(format: "%d h %02d", s / 3600, (s % 3600) / 60)
    }

    /// Vignette du bonhomme (iOS déplace le fichier joint : on en écrit un nouveau à chaque fois).
    private static func mascot() -> UNNotificationAttachment? {
        guard let data = Data(base64Encoded: WebViewController.logoPNG) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("zieuton-\(UUID().uuidString).png")
        guard (try? data.write(to: url)) != nil else { return nil }
        return try? UNNotificationAttachment(identifier: "bonhomme", url: url, options: nil)
    }

    var onReady: (() -> Void)?
    private let store = UserDefaults.standard
    private var requestedAt: Date? { store.object(forKey: Key.requested) as? Date }
    private var readyAt: Date? { store.object(forKey: Key.ready) as? Date }
    /// Une demande est en cours (moins de 4 jours) et le fichier n'a pas encore été vu prêt.
    var isWaiting: Bool {
        guard let r = requestedAt, readyAt == nil else { return false }
        return Date().timeIntervalSince(r) < 4 * 86400
    }
    var isReady: Bool { requestedAt != nil && readyAt != nil }

    private var timer: Timer?
    private var checker: WKWebView?
    private var finishCheck: ((Outcome) -> Void)?
    private var seen = (dl: 0, pending: false, login: false)
    private enum Outcome { case ready, pending, unknown }

    // MARK: Étapes

    /// Délai du filet de sécurité : le même que celui où la carte de l'accueil passe à « prêt ».
    static let likelyAfter: TimeInterval = 10 * 60

    /// La demande vient de partir dans Instagram.
    func requested(downloadsBefore: Int) {
        store.set(Date(), forKey: Key.requested)
        store.removeObject(forKey: Key.ready)
        store.set(downloadsBefore, forKey: Key.before)
        store.set(false, forKey: Key.baselineChecked)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: Id.all)
        center.removeDeliveredNotifications(withIdentifiers: Id.all)
        center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            guard granted, let self else { return }
            let now = Date()
            self.notify(Id.asked, "C'est demandé ✓", "Ton fichier arrive d'ici 10 minutes maximum. Je te préviens dès qu'il est là.",
                        subtitle: "Demande envoyée à Instagram à \(Self.hour(now))", after: 1)
            // Zieuton fermé, iOS décide seul quand le réveiller (parfois jamais) : sans ce filet, aucune notif ne partirait.
            // Si Zieuton voit le fichier avant, cette notification est remplacée par « Ton fichier Instagram est prêt ».
            self.notify(Id.likely, "Ton fichier Instagram est sûrement prêt 🎉", "Instagram met en général moins de 10 minutes. Touche pour le récupérer : Zieuton se met à jour tout seul.",
                        subtitle: "Demandé à \(Self.hour(now))", after: Self.likelyAfter, badge: true, category: Id.readyCategory)
            self.notify(Id.reminder, "Ton fichier t'attend 📥", "Demandé à \(Self.hour(now)). Touche pour le récupérer et voir enfin qui est parti et qui est arrivé.",
                        after: 40 * 60, category: Id.readyCategory)
            self.notify(Id.lastDay, "⏳ Dernier jour pour ton fichier", "Ta demande de \(Self.day(now)) expire bientôt. Touche pour mettre Zieuton à jour avant qu'elle disparaisse.",
                        after: 3 * 86400, category: Id.readyCategory)
        }
        DispatchQueue.main.async {
            self.startTimer()
            self.scheduleBackgroundCheck()
        }
    }

    /// Le fichier a été téléchargé dans Zieuton : plus rien à guetter.
    func downloaded() { clear() }

    func clear() {
        guard requestedAt != nil else { return }
        for k in [Key.requested, Key.ready, Key.before, Key.baselineChecked] { store.removeObject(forKey: k) }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: Id.all)
        center.removeDeliveredNotifications(withIdentifiers: Id.all)
        timer?.invalidate(); timer = nil
        UNUserNotificationCenter.current().setBadgeCount(0, withCompletionHandler: nil)
    }

    private func markReady() {
        guard isWaiting else { return }
        store.set(Date(), forKey: Key.ready)
        timer?.invalidate(); timer = nil
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Id.likely, Id.reminder, Id.lastDay])
        center.removeDeliveredNotifications(withIdentifiers: [Id.asked, Id.likely])
        let now = Date(), expires = now.addingTimeInterval(4 * 86400)
        let took = requestedAt.map { Self.duration(now.timeIntervalSince($0)) }
        notify(Id.ready, "Ton fichier Instagram est prêt 🎉", "Touche pour mettre Zieuton à jour : tu sauras qui est parti et qui est arrivé. Valable jusqu'au \(Self.day(expires)).",
               subtitle: took.map { "Instagram a mis \($0)" }, after: 1, badge: true, category: Id.readyCategory)
        notify(Id.lastDay, "⏳ Ton fichier expire demain à \(Self.hour(expires))", "Après, il faudra refaire une demande. Touche pour mettre Zieuton à jour maintenant.",
               after: 3 * 86400, badge: true, category: Id.readyCategory)
        DispatchQueue.main.async { self.onReady?() }
    }

    private func notify(_ id: String, _ title: String, _ body: String, subtitle: String? = nil, after seconds: TimeInterval,
                        badge: Bool = false, category: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if let subtitle { content.subtitle = subtitle }
        content.sound = .default
        content.threadIdentifier = "zyeuto-export"
        if badge { content.badge = 1 }
        if let category { content.categoryIdentifier = category }
        // Le bonhomme de Zieuton en vignette, à droite de la notification.
        if let attachment = Self.mascot() { content.attachments = [attachment] }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    // MARK: Vérifications

    /// Zieuton revient au premier plan : on vérifie tout de suite, puis toutes les 30 s.
    func appBecameActive() {
        UNUserNotificationCenter.current().setBadgeCount(0, withCompletionHandler: nil)
        guard isWaiting else { return }
        startTimer()
        tick()
    }

    private func startTimer() {
        guard timer == nil, isWaiting else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in self?.tick() }
    }

    private func tick() {
        guard isWaiting else { timer?.invalidate(); timer = nil; return }
        guard UIApplication.shared.applicationState == .active, let r = requestedAt else { return }
        // Pas avant 30 s : la page d'Instagram doit avoir enregistré la demande.
        guard Date().timeIntervalSince(r) > 30 else { return }
        check { _ in }
    }

    /// Ouvre la page d'Instagram en cachette et regarde si un nouveau « Télécharger » est apparu.
    private func check(_ done: @escaping (Bool) -> Void) {
        guard checker == nil, isWaiting else { done(false); return }
        seen = (0, false, false)
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let content = WKUserContentController()
        let script = """
        (function () { setInterval(function () {
          var txt = (document.body && document.body.innerText || '').toLowerCase();
          window.webkit.messageHandlers.zyeutoCheck.postMessage({
            dl: \(Self.countScript),
            pending: /en attente|pending|en préparation|in progress|preparing/.test(txt),
            login: !!document.querySelector('input[type=password]')
          });
        }, 800); })();
        """
        content.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: false))
        content.add(CheckHandler(self), name: "zyeutoCheck")
        config.userContentController = content
        let web = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 1400), configuration: config)
        web.isUserInteractionEnabled = false
        // Placée derrière l'écran de Zieuton (invisible) : la page d'Instagram s'affiche normalement.
        WebViewController.current?.view.window?.insertSubview(web, at: 0)
        checker = web
        finishCheck = { [weak self] outcome in
            guard let self else { return }
            self.checker?.stopLoading()
            self.checker?.removeFromSuperview()
            self.checker?.configuration.userContentController.removeScriptMessageHandler(forName: "zyeutoCheck")
            self.checker = nil
            self.finishCheck = nil
            if outcome == .ready { self.markReady() }
            if outcome == .pending, let r = self.requestedAt, Date().timeIntervalSince(r) > Self.likelyAfter - 2 * 60 {
                // Instagram prend son temps : on repousse le rappel au lieu d'annoncer un fichier pas encore là.
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Id.likely])
                self.notify(Id.reminder, "Instagram prépare encore ton fichier ⏳", "C'est plus long que d'habitude. Je regarde encore et je te préviens dès qu'il est là.",
                            subtitle: "Demandé à \(Self.hour(r))", after: 10 * 60)
            }
            done(outcome == .ready)
        }
        web.load(URLRequest(url: Self.exportURL))
        // La page met quelques secondes à afficher la liste : on conclut au bout de 12 s.
        DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in self?.conclude() }
    }

    fileprivate func received(_ body: [String: Any]) {
        if let dl = body["dl"] as? Int { seen.dl = max(seen.dl, dl) }
        if body["pending"] as? Bool == true { seen.pending = true }
        if body["login"] as? Bool == true { seen.login = true }
        // Nouveau bouton « Télécharger » : pas besoin d'attendre la fin.
        if seen.dl > store.integer(forKey: Key.before) { conclude() }
    }

    private func conclude() {
        guard let finish = finishCheck else { return }
        let before = store.integer(forKey: Key.before)
        // Point de départ : le nombre de « Télécharger » vus dans Instagram au moment de la demande
        // (exports plus anciens encore téléchargeables). Instagram peut finir en à peine une minute.
        if seen.login { finish(.unknown) }
        else if seen.dl > before { finish(.ready) }
        else { finish(seen.pending ? .pending : .unknown) }
    }

    // MARK: Zieuton fermé : réveil par iOS

    /// Vrai si l'Info.plist autorise le réveil par iOS (sinon iOS fermerait l'app : on s'en passe).
    private static var backgroundAllowed: Bool {
        (Bundle.main.object(forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers") as? [String])?.contains(taskID) == true
    }

    static func registerBackgroundTask() {
        guard backgroundAllowed else { return }
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskID, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            DispatchQueue.main.async { shared.handle(task) }
        }
    }

    /// Zieuton passe en arrière-plan : on demande à iOS un peu de temps pour vérifier une dernière fois tout de suite,
    /// puis on lui demande de nous réveiller plus tard.
    func enteredBackground() {
        scheduleBackgroundCheck()
        guard isWaiting, let r = requestedAt, Date().timeIntervalSince(r) > 30 else { return }
        var task = UIBackgroundTaskIdentifier.invalid
        let end = {
            guard task != .invalid else { return }
            UIApplication.shared.endBackgroundTask(task)
            task = .invalid
        }
        task = UIApplication.shared.beginBackgroundTask(withName: "zy-check") { [weak self] in
            self?.finishCheck?(.unknown)
            end()
        }
        check { _ in end() }
    }

    /// Demande à iOS de réveiller Zieuton dans quelques minutes (iOS choisit le moment exact).
    func scheduleBackgroundCheck() {
        guard isWaiting, Self.backgroundAllowed else { return }
        let request = BGAppRefreshTaskRequest(identifier: Self.taskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handle(_ task: BGAppRefreshTask) {
        scheduleBackgroundCheck()
        var completed = false
        let complete = { (ok: Bool) in
            guard !completed else { return }
            completed = true
            task.setTaskCompleted(success: ok)
        }
        task.expirationHandler = { [weak self] in
            DispatchQueue.main.async {
                self?.finishCheck?(.unknown)
                complete(false)
            }
        }
        check { _ in complete(true) }
    }
}

private final class CheckHandler: NSObject, WKScriptMessageHandler {
    weak var watcher: ExportWatcher?
    init(_ watcher: ExportWatcher) { self.watcher = watcher }
    func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {
        if let body = m.body as? [String: Any] { watcher?.received(body) }
    }
}

// MARK: Logo de l'écran d'ouverture (icône Zieuton, PNG 360 × 360)

private extension WebViewController {
    static let logoPNG = "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"
}

// MARK: Zieuton Plus (achats intégrés, StoreKit 2)

/// Les trois façons d'avoir Zieuton Plus : au mois, à l'année (abonnements du même groupe), ou à vie (achat unique).
/// Apple signe chaque achat : la vérification se fait sur le téléphone, sans serveur.
@MainActor
final class PlusStore {
    static let shared = PlusStore()
    /// Chaque compte Instagram du téléphone (1 à 3) a son propre Plus, dans son propre groupe d'abonnements :
    /// compte 1 = fr.zyeuto.plus.*, compte 2 = fr.zyeuto.plus2.*, etc. (un même identifiant Apple peut ainsi en payer plusieurs).
    static let slots = 1...3
    static func prefix(_ slot: Int) -> String { slot == 1 ? "fr.zyeuto.plus." : "fr.zyeuto.plus\(slot)." }
    static let ids = slots.flatMap { n in ["an", "mois", "avie"].map { prefix(n) + $0 } }
    static func slot(of id: String) -> Int? { slots.first { id.hasPrefix(prefix($0)) } }

    private(set) var products: [Product] = []
    /// L'achat en cours de validité pour le compte 1 (nil = version gratuite).
    private(set) var active: String?
    /// Plus de chaque compte : numéro du compte → produit acheté.
    private(set) var bySlot: [Int: String] = [:]
    var onChange: (() -> Void)?
    private var updates: Task<Void, Never>?

    func start() {
        guard updates == nil else { return }
        // Achats faits ailleurs (autre appareil, partage familial, renouvellement, remboursement).
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result { await transaction.finish() }
                await self?.refresh()
            }
        }
        Task { await load(); await refresh() }
    }

    func load() async {
        guard products.isEmpty else { return }
        if let found = try? await Product.products(for: Self.ids) {
            products = found.sorted { (Self.ids.firstIndex(of: $0.id) ?? 9) < (Self.ids.firstIndex(of: $1.id) ?? 9) }
            onChange?()
        }
    }

    func refresh() async {
        var found: [Int: String] = [:]
        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result, t.revocationDate == nil, let slot = Self.slot(of: t.productID) else { continue }
            // L'achat à vie l'emporte sur un abonnement encore en cours.
            if found[slot] == nil || t.productID.hasSuffix(".avie") { found[slot] = t.productID }
        }
        bySlot = found
        active = found[1]
        onChange?()
    }

    /// Renvoie "ok", "cancel", "pending" (en attente d'un parent) ou "error".
    func buy(_ id: String) async -> String {
        await load()
        guard let product = products.first(where: { $0.id == id }) else { return "error" }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else { return "error" }
                await transaction.finish()
                await refresh()
                return "ok"
            case .userCancelled: return "cancel"
            case .pending: return "pending"
            @unknown default: return "error"
            }
        } catch {
            return "error"
        }
    }

    func restore() async -> Bool {
        try? await AppStore.sync()
        await refresh()
        return !bySlot.isEmpty
    }

    /// L'état en JSON pour la page : acheté ou non, et les prix affichés par l'App Store.
    func json(result: String?) -> String {
        var dict: [String: Any] = [
            "active": active != nil,
            "plan": active ?? "",
            "plusSlots": Dictionary(uniqueKeysWithValues: bySlot.map { (String($0.key), $0.value) }),
            "products": products.map { p -> [String: Any] in
                var unit = ""
                if let period = p.subscription?.subscriptionPeriod.unit { unit = period == .year ? "year" : period == .month ? "month" : "" }
                return ["id": p.id, "price": p.displayPrice, "period": unit]
            },
        ]
        if let result { dict["result"] = result }
        let data = (try? JSONSerialization.data(withJSONObject: dict)) ?? Data("{}".utf8)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
