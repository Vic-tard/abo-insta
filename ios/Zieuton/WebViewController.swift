import UIKit
import WebKit
import UserNotifications
import BackgroundTasks
import StoreKit
import PhotosUI
import CryptoKit

/// Affiche l'app web Zieuton et lui transmet les fichiers partagés.
final class WebViewController: UIViewController {
    /// L'écran Zieuton ouvert (pour les notifications touchées).
    static weak var current: WebViewController?
    /// Une notification a été touchée avant que la page soit prête : on ouvre Instagram dès qu'elle l'est.
    private var openWhenReady = false
    /// Adresse de base de la page affichée. Les données (IndexedDB, localStorage) sont rangées sous cette adresse :
    /// NE PAS LA CHANGER, sinon les utilisateurs ne retrouvent plus leurs données.
    static let home = URL(string: "https://vic-tard.github.io/abo-insta/")!
    /// Où l'app télécharge ses mises à jour (page, channel.json, signatures), FOU-92 : zieuton.com (Cloudflare),
    /// puis GitHub Pages en secours si zieuton.com ne répond pas.
    static let updateBase = URL(string: "https://zieuton.com/")!
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
    /// D'où vient la page affichée (rangée dans l'app, dernière bonne, ou tout juste téléchargée).
    private var loadedSource: PageGuard.Source = .bundled
    /// Le texte de la page affichée (recopié en « dernière bonne page » quand elle a bien démarré).
    private var loadedHTML: String?
    /// La page affichée a dit « je suis bien démarrée ».
    private var started = false
    /// Chronomètre du démarrage : sans signal à temps, la page est déclarée mauvaise.
    private var startTimer: DispatchWorkItem?
    /// Dernière version de la page téléchargée (plus récente que celle rangée dans l'app).
    private static var savedPage: URL { supportFile("zyeuto-hors-ligne.html") }
    /// Dernière version téléchargée qui a bien démarré : le repli si la suivante est cassée.
    private static var lastGoodPage: URL { supportFile("zyeuto-derniere-bonne.html") }
    private static func supportFile(_ name: String) -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(name)
    }
    /// Petit fichier en ligne qui dit quelle version est « stable », et l'interrupteur d'urgence.
    private static let channelURL = URL(string: "channel.json", relativeTo: updateBase)!.absoluteURL
    /// Signatures publiées à côté de la page et de channel.json (FOU-29).
    private static let pageSignatureURL = URL(string: "index.html.sig", relativeTo: updateBase)!.absoluteURL
    private static let channelSignatureURL = URL(string: "channel.json.sig", relativeTo: updateBase)!.absoluteURL

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
            source: "window.ZYEUTO_APP = { version: 10, embedded: true, icloud: true, channels: true, signed: true };",
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
                                               object: nil, queue: .main) { [weak self] _ in
            ExportWatcher.shared.appBecameActive()
            self?.pageCameBack()
        }
        Self.current = self
        // Fichier Instagram repéré prêt : la carte « Mettre à jour » passe à « Ton export est prêt ».
        ExportWatcher.shared.onReady = { [weak self] in
            self?.webView.evaluateJavaScript("window.zyeutoMeta && window.zyeutoMeta('ready'); true")
        }
        ExportWatcher.shared.onNotif = { [weak self] auth in self?.sendNotif(auth) }
        ExportWatcher.shared.onState = { [weak self] state, at in self?.sendWatch(state, at) }
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
    ///
    /// Sécurité (FOU-28) : une page téléchargée doit dire « je suis bien démarrée » (message « started »)
    /// dans les secondes qui suivent. Sinon, ou si elle plante deux fois de suite, sa version est notée
    /// mauvaise : l'app revient à la dernière page qui a démarré (ou à celle rangée dans l'app) et ne la
    /// retélécharge plus. Les règles elles-mêmes sont dans `PageGuard`, en bas de ce fichier.
    ///
    /// Signature (FOU-29) : une page téléchargée n'est enregistrée que si elle est signée par la clé de Victor
    /// (`PageSignature`). Sinon l'app garde la page qu'elle a déjà.
    private func loadPage() {
        // Une page qui a raté ses derniers démarrages (l'app ou la page a planté avant le signal) est écartée.
        if let trying = guardStore.trying, PageGuard.tooManyFailedStarts(guardStore.tries) {
            markBad(trying)
        }
        startTimer?.cancel()
        startTimer = nil
        started = false
        guard let chosen = choosePage() else {
            webView.load(URLRequest(url: Self.home)) // ne devrait pas arriver : la page est toujours dans l'app
            return
        }
        let (page, html) = chosen
        loadedBuild = page.build
        loadedSource = page.source
        loadedHTML = html
        if page.source != .bundled {
            // Tentative notée AVANT d'afficher : si tout plante pendant le démarrage, on le saura au prochain lancement.
            guardStore.countTry(page.build)
            armStartTimer(for: page.build)
        }
        webView.loadHTMLString(html, baseURL: Self.home)
    }

    /// Les pages présentes sur le téléphone, et celle qu'il faut afficher selon les règles.
    private func choosePage() -> (PageGuard.Page, String)? {
        let bundled = Bundle.main.url(forResource: "index", withExtension: "html")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) }
        let texts: [(PageGuard.Source, String?)] = [
            (.bundled, bundled),
            (.lastGood, try? String(contentsOf: Self.lastGoodPage, encoding: .utf8)),
            (.downloaded, try? String(contentsOf: Self.savedPage, encoding: .utf8)),
        ]
        var html: [PageGuard.Source: String] = [:]
        var pages: [PageGuard.Page] = []
        for (source, text) in texts {
            guard let text, let build = Self.build(of: text) else { continue }
            html[source] = text
            pages.append(PageGuard.Page(source: source, build: build))
        }
        guard let page = PageGuard.choose(pages, bad: Set(guardStore.bad), channel: guardStore.channel,
                                          config: guardStore.config),
              let text = html[page.source] else { return nil }
        return (page, text)
    }

    /// Numéro de version d'une page (ex. « 2026-11-04-1210 »), qui se compare comme du texte.
    private static func build(of html: String) -> String? {
        guard let r = html.range(of: #"const BUILD = "([^"]+)""#, options: .regularExpression) else { return nil }
        return String(html[r].dropFirst(15).dropLast())
    }

    // MARK: Démarrage surveillé (FOU-28)

    private let guardStore = PageGuardStore()

    private func armStartTimer(for build: String) {
        startTimer?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.startTimedOut(build) }
        startTimer = item
        DispatchQueue.main.asyncAfter(deadline: .now() + PageGuard.startTimeout, execute: item)
    }

    /// Pas de signal « je suis bien démarrée » à temps : cette version est cassée, on revient en arrière.
    private func startTimedOut(_ build: String) {
        guard !started, loadedBuild == build, loadedSource != .bundled else { return }
        // App en arrière-plan : la page est en pause, ce n'est pas sa faute (on rechronomètre au retour).
        guard UIApplication.shared.applicationState == .active else { return }
        markBad(build)
        loadPage()
    }

    /// Retour dans l'app pendant le démarrage d'une page : on lui redonne tout son temps.
    private func pageCameBack() {
        guard !started, loadedSource != .bundled, !loadedBuild.isEmpty else { return }
        armStartTimer(for: loadedBuild)
    }

    /// La page a bien démarré (accueil affiché).
    private func pageStarted(_ build: String) {
        guard build == loadedBuild else { return }
        started = true
        startTimer?.cancel()
        startTimer = nil
        if loadedSource != .bundled {
            guardStore.clearTries()
            // Elle devient le repli si une version suivante est cassée.
            if loadedSource == .downloaded, let html = loadedHTML {
                do { try Data(html.utf8).write(to: Self.lastGoodPage, options: .atomic) }
                catch { NSLog("Zieuton : dernière bonne page non enregistrée (%@)", error.localizedDescription) }
            }
        }
        sendChannel(toggled: false)
    }

    private func markBad(_ build: String) {
        NSLog("Zieuton : la page %@ n'a pas démarré, retour à la version d'avant", build)
        guardStore.markBad(build)
    }

    /// Réglage caché (5 touches sur la version) : canal « test » ⇄ canal normal.
    private func toggleChannel() {
        guardStore.channel = guardStore.channel == "test" ? "stable" : "test"
        sendChannel(toggled: true)
        checkForUpdate() // le nouveau canal s'applique tout de suite (ou au prochain retour si rien ne charge)
    }

    private func sendChannel(toggled: Bool) {
        let js = "window.zyeutoChannel && window.zyeutoChannel({channel:\"\(guardStore.channel)\",toggled:\(toggled)}); true"
        webView.evaluateJavaScript(js)
    }

    // MARK: Mises à jour

    private static func fresh(_ url: URL) -> URLRequest {
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "v", value: String(Int(Date().timeIntervalSince1970)))]
        var request = URLRequest(url: comps.url!, timeoutInterval: 15)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        return request
    }

    /// Télécharge un petit fichier en ligne (nil si absent, erreur ou pas d'internet).
    /// Un fichier de zieuton.com qui ne répond pas est redemandé à GitHub Pages (même fichier, même signature).
    private static func fetch(_ url: URL, _ done: @escaping (Data?) -> Void) {
        URLSession.shared.dataTask(with: fresh(url)) { data, response, _ in
            if (response as? HTTPURLResponse)?.statusCode == 200, let data { return done(data) }
            guard let mirror = mirrorURL(url) else { return done(nil) }
            NSLog("Zieuton : %@ injoignable, essai sur GitHub Pages", url.absoluteString)
            URLSession.shared.dataTask(with: fresh(mirror)) { data, response, _ in
                done((response as? HTTPURLResponse)?.statusCode == 200 ? data : nil)
            }.resume()
        }.resume()
    }

    /// Le même fichier sur GitHub Pages, pour une adresse de zieuton.com (nil sinon).
    static func mirrorURL(_ url: URL) -> URL? {
        let base = updateBase.absoluteString, text = url.absoluteString
        guard text.hasPrefix(base) else { return nil }
        return URL(string: home.absoluteString + String(text.dropFirst(base.count)))
    }

    /// Télécharge un fichier et sa signature : renvoie le fichier seulement s'il est bien signé par Victor (FOU-29).
    private static func fetchSigned(_ url: URL, signature: URL, _ done: @escaping (Data?) -> Void) {
        fetch(url) { data in
            guard let data else { return done(nil) }
            fetch(signature) { sig in
                if PageSignature.isValid(data, signatureFile: sig) { return done(data) }
                NSLog("Zieuton : %@ refusé, signature absente ou invalide", url.lastPathComponent)
                done(nil)
            }
        }
    }

    /// La page demande s'il y a du nouveau (à l'ouverture et à chaque retour dans l'app).
    /// 1. channel.json : version stable et interrupteur d'urgence. 2. la page en ligne, si elle est permise.
    private func checkForUpdate() {
        guard !checkingUpdate else { return }
        checkingUpdate = true
        Self.fetchSigned(Self.channelURL, signature: Self.channelSignatureURL) { [weak self] data in
            // Fichier absent, illisible, mal signé ou pas d'internet : on garde les dernières consignes connues.
            let config = data.flatMap(PageGuard.parseChannel)
            DispatchQueue.main.async {
                guard let self else { return }
                if let config { self.guardStore.config = config }
                self.downloadPage()
            }
        }
    }

    private func downloadPage() {
        let current = loadedBuild, bad = Set(guardStore.bad), channel = guardStore.channel, config = guardStore.config
        guard config?.emergency != true else { return finishUpdate() } // urgence : on ne télécharge rien
        Self.fetch(Self.updateBase) { [weak self] data in
            guard let data, let html = String(data: data, encoding: .utf8), html.contains("</html>"),
                  let build = Self.build(of: html),
                  PageGuard.shouldKeep(downloaded: build, current: current, bad: bad, channel: channel, config: config)
            else { return DispatchQueue.main.async { self?.finishUpdate() } }
            // Nouvelle version permise : on ne l'enregistre que si sa signature est bonne (sinon on garde la page actuelle).
            Self.fetch(Self.pageSignatureURL) { sig in
                if PageSignature.isValid(data, signatureFile: sig) {
                    do { try data.write(to: Self.savedPage, options: .atomic) }
                    catch { NSLog("Zieuton : nouvelle page non enregistrée (%@)", error.localizedDescription) }
                } else {
                    NSLog("Zieuton : page %@ refusée, signature absente ou invalide", build)
                }
                DispatchQueue.main.async { self?.finishUpdate() }
            }
        }
    }

    /// Nouvelle version, canal changé ou interrupteur d'urgence : on affiche ce que les règles demandent.
    private func finishUpdate() {
        checkingUpdate = false
        guard let wanted = choosePage()?.0, wanted.build != loadedBuild else { return }
        // On recharge seulement si rien n'est en cours (fichier reçu, Instagram ouvert…) ; sinon au prochain retour.
        if !sending, pending.isEmpty, presentedViewController == nil { loadPage() }
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
        if url.host == Self.updateBase.host { return true } // pages du site sur zieuton.com (FOU-93)
        return url.host == Self.home.host && url.path.hasPrefix(Self.home.path)
    }

    enum SitePage: Equatable { case app, moved(URL), other }

    /// Où ouvrir un lien vers le site (FOU-93) :
    /// - `.app` : la page d'accueil de zieuton.com → on réaffiche la page de l'app ;
    /// - `.moved` : une page .html de l'ancienne adresse GitHub → la même sur zieuton.com ;
    /// - `.other` : rien à changer (la page de l'app elle-même, un autre site…).
    static func sitePage(_ url: URL) -> SitePage {
        if url.host == updateBase.host {
            return (url.path.isEmpty || url.path == "/" || url.path == "/index.html") ? .app : .other
        }
        guard url.host == home.host, url.path.hasPrefix(home.path), url.pathExtension == "html",
              url.lastPathComponent != "index.html" else { return .other }
        let rest = String(url.path.dropFirst(home.path.count))
        guard var comps = URLComponents(url: updateBase.appendingPathComponent(rest), resolvingAgainstBaseURL: false)
        else { return .other }
        comps.fragment = url.fragment
        return comps.url.map { SitePage.moved($0) } ?? .other
    }
    private func sitePage(_ url: URL) -> SitePage { Self.sitePage(url) }
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
            // FOU-126 : état de l'autorisation et dernière vérification, pour l'écran d'attente (ZYEUTO_APP 10).
            ExportWatcher.shared.syncNotices()
            ExportWatcher.shared.sendLastState()
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
        case "started":
            pageStarted(body["build"] as? String ?? "")
        case "channel":
            toggleChannel()
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
        case "icloud":
            handleICloud(body)
        case "photo":
            pickPhoto()
        case "exportState":
            // La page n'attend plus d'export (fichier importé, demande annulée) : on arrête de guetter.
            // FOU-126 : la page n'envoie « plus en attente » que pour le compte de la demande (champ acct).
            // Protection en plus côté coque : un message d'un autre compte n'annule pas les rappels de la demande.
            if body["pending"] as? Bool == false { ExportWatcher.shared.pageEndedWait(acct: body["acct"] as? String) }
        case "notif":
            handleNotif(body)
        default:
            break
        }
    }

    /// FOU-126 : autorisation des notifications, demandée par la page (écran « Je te préviens ? », carte « Activer »).
    private func handleNotif(_ body: [String: Any]) {
        let watcher = ExportWatcher.shared
        // Une page qui parle de notifications sait demander l'autorisation elle-même avant Instagram.
        watcher.pageAsksPermission = true
        switch body["action"] as? String {
        case "ask":
            watcher.askPermission()
        case "settings":
            // Directement sur les notifications de Zieuton dans Réglages.
            if let url = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(url) }
        case "check":
            // « Regarder si c'est prêt » : une vérification tout de suite.
            watcher.checkNow()
        default:
            watcher.syncNotices()
        }
    }

    private func sendNotif(_ auth: NotifAuth) {
        guard pageReady else { return }
        webView.evaluateJavaScript("window.zyeutoNotif && window.zyeutoNotif({ status: '\(auth.rawValue)' }); true")
    }

    private func sendWatch(_ state: String, _ at: Date) {
        guard pageReady else { return }
        let iso = ISO8601DateFormatter().string(from: at)
        webView.evaluateJavaScript("window.zyeutoWatch && window.zyeutoWatch({ state: '\(state)', at: '\(iso)' }); true")
    }

    /// Sauvegarde iCloud : enregistrer, regarder s'il y en a une, ou la reprendre.
    private func handleICloud(_ body: [String: Any]) {
        switch body["action"] as? String {
        case "save":
            guard let text = body["data"] as? String else { return }
            let count = body["count"] as? Int ?? 0
            ICloudBackup.save(Data(text.utf8)) { [weak self] ok in
                self?.sendICloud("{\"action\":\"saved\",\"ok\":\(ok),\"count\":\(count)}")
            }
        case "check":
            ICloudBackup.find { [weak self] date in
                guard let self else { return }
                guard ICloudBackup.available else { return self.sendICloud("{\"action\":\"off\"}") }
                if let date {
                    let iso = ISO8601DateFormatter().string(from: date)
                    self.sendICloud("{\"action\":\"found\",\"found\":true,\"savedAt\":\"\(iso)\"}")
                } else {
                    self.sendICloud("{\"action\":\"found\",\"found\":false}")
                }
            }
        case "restore":
            ICloudBackup.read { [weak self] data in
                guard let self else { return }
                guard let data else { return self.sendICloud("{\"action\":\"restoreFail\"}") }
                // Même chemin qu'une sauvegarde partagée : la page vérifie le sceau puis reprend tout.
                self.pending.append((ICloudBackup.fileName, data))
                self.flush()
            }
        default:
            break
        }
    }

    private func sendICloud(_ json: String) {
        webView.evaluateJavaScript("window.zyeutoICloud && window.zyeutoICloud(\(json)); true")
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
        // FOU-126 : compte affiché quand la demande part (la page l'envoie depuis ZYEUTO_APP 10).
        let acct = body["acct"] as? String
        meta.onRequested = { [weak self] existing, today in
            // existing : demande déjà en cours chez Instagram ; today : elle est datée d'aujourd'hui (une page plus ancienne ignore ces champs).
            self?.webView.evaluateJavaScript("window.zyeutoMeta && window.zyeutoMeta('requested', { existing: \(existing), today: \(today) }); true")
            ExportWatcher.shared.requested(existing: existing, today: today, acct: acct)
        }
        // Relecture ChatGPT (18 nov.) : demande possible mais pas prouvée. La page passe sur « Demande à vérifier » (une page plus
        // ancienne ignore cet évènement). Pas de « C'est demandé », pas de guet ni de notification tant que ce n'est pas vérifié.
        meta.onLeftUnsure = { [weak self] today in
            self?.webView.evaluateJavaScript("window.zyeutoMeta && window.zyeutoMeta('unsure', { today: \(today) }); true")
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
        // Pages Aide, Confidentialité, Conditions, Mentions légales (FOU-93) : servies par zieuton.com.
        if let url = action.request.url, action.targetFrame?.isMainFrame == true {
            switch sitePage(url) {
            case .app:
                // Retour à Zieuton depuis une de ces pages : on réaffiche la page de l'app (même adresse de base,
                // donc mêmes données), jamais la version en ligne sous zieuton.com.
                decisionHandler(.cancel)
                loadPage()
                return
            case .moved(let target):
                decisionHandler(.cancel)
                webView.load(URLRequest(url: target))
                return
            case .other:
                break
            }
        }
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
        var tone = BannerTone.consigne // FOU-121 P4 : couleur du bandeau (voir BannerTone)
    }

    /// Alerte « mauvais bouton » affichée dans le bandeau.
    private struct Warning: Equatable { var title: String; var text: String }
    private var warning: Warning?
    private var warningAt = Date.distantPast
    /// FOU-121 P4 : depuis l'alerte, la page a quitté l'écran de l'étape (mauvais bouton touché).
    private var warningLeft = false
    /// Relecture ChatGPT (P4) : l'alerte « pas le bon compte » a déjà vibré pour cette visite de l'écran.
    private var wrongProfileWarned = false
    /// Étape où la bonne option a été choisie (« Depuis le début », « JSON »).
    private var pickedAt = -1
    private var lastTapAt = Date.distantPast
    private var createSince: Date?
    /// Vidéo du 18 nov. : depuis quand la liste des exports est lue (fenêtre par-dessus, « Créer une exportation » caché ou pas).
    private var listSince: Date?
    /// Vidéo du 18 nov. : avant toute touche, la liste montre déjà une demande « En attente » : on ne dit jamais « Touche Créer ».
    private var pendingSeen = false
    /// Vidéo du 18 nov. : « Commencer » touché, pas de preuve, mais une ligne « En attente » datée d'aujourd'hui est à l'écran.
    private var todayPendingShown = false
    /// L'utilisateur a confirmé lui-même la ligne : jamais « C'est demandé » (pas de preuve automatique), mais « une demande d'aujourd'hui ».
    private var manualConfirm = false
    /// Les alertes ne s'allument que si la page est bien en français ou en anglais (bouton « Créer une exportation » reconnu).
    private var guarded: Bool { steps.contains { $0.ok != nil } && seenCreate != .distantPast }

    /// La demande est prouvée chez Instagram (true : elle était déjà en cours).
    /// (existing, today) : demande déjà en cours chez Instagram ; et, dans ce cas, datée d'aujourd'hui (peut-être la sienne, sans preuve).
    var onRequested: ((Bool, Bool) -> Void)?
    /// Instagram fermé avec une demande possible mais pas prouvée (true : une ligne « En attente » d'aujourd'hui était visible).
    var onLeftUnsure: ((Bool) -> Void)?
    var onFile: ((URL) -> Void)?

    private let url: URL
    private let requesting: Bool
    private let steps: [Step]
    private var index = 0
    private var loginShown = false
    /// Fenêtre des cookies d'Instagram affichée (FOU-121) : le bandeau dit quel bouton toucher.
    private var cookiesShown = false
    private var seenCookies = Date.distantPast
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
    /// Nom de la première case cochée en trop (« Applications et sites Web »…).
    private var pickExtra = ""
    /// FOU-121 P5 (R2) : cases vues pendant cette visite de la page des cases, même sorties de la page en défilant.
    private var pickMemory = PickMemory()
    /// FOU-121 P5 : ce que dit la ligne « Personnaliser les informations » du résumé ('followers', 'one' ou '').
    private var summaryInfo = ""
    /// Instagram a dit « mot de passe incorrect ».
    private var badPassword = false
    /// FOU-121 P2 : Instagram dit que l'identifiant ne correspond à aucun compte.
    private var unknownUser = false
    /// FOU-121 P2 : Instagram dit que le code de sécurité est faux ou expiré.
    private var badCode = false
    /// FOU-121 P2 : compte les refus de mot de passe (conseil « Mot de passe oublié ? » au 2e).
    private var loginHelp = LoginHelp()
    /// FOU-121 P2 : page qui ne charge pas (« offline ») ou qui s'est fermée (« crashed »). Rien ne se recharge tout seul.
    private var pageProblem = ""
    /// FOU-121 P2 : téléchargement en cours depuis quand, pour ne pas afficher « récupère ton fichier » à l'infini.
    private var downloadSince: Date?
    private var activeDownloads: [WKDownload] = []
    private var downloadStuckShown = false
    /// Un cran trop haut (« Vos informations et autorisations ») : le bandeau montre « Exporter vos informations ».
    private var upShown = false
    private var pickFresh: Bool { Date().timeIntervalSince(seenPick) < 1.6 }
    /// Bon réglage : une seule case cochée, et c'est « Followers et suivi(e)s ».
    private var pickGood: Bool { pickFollowers && pickChecked == 1 }
    private var downloading = false
    /// Après la demande, la page d'Instagram reste ouverte : Zieuton la recharge toutes les 10 s
    /// et prévient dès que le fichier de la demande est prêt (FOU-100, preuve FOU-126). L'utilisateur touche « Télécharger » lui-même.
    private var guarding = false
    private var guardReady = false
    /// FOU-126 (tests iPhone du 17 nov.) : ouvert pour récupérer le fichier : dernier verdict de la preuve « prêt » (ReadyProof).
    /// Le bandeau et le cercle suivent ce verdict, jamais la seule présence d'un bouton « Télécharger ».
    private var getVerdict: ReadyProof.Verdict?
    private var guardSince = Date.distantPast
    private var guardTimer: Timer?
    /// On arrête de recharger au bout de 20 min : la notification prend le relais.
    private static let guardFor: TimeInterval = 20 * 60
    /// « Commencer l'exportation » touché : on attend qu'Instagram ait bien pris la demande.
    private var sentAt: Date?
    private var finished = false
    /// Tant qu'Instagram n'a pas dit sur quel écran il est, le bandeau patiente (évite d'afficher l'étape 1 sur la page de connexion).
    private var pageKnown = false
    /// Derniers moments où chaque cadre de la page a vu : la connexion, « Commencer l'exportation », « Créer une exportation ».
    private var seenLogin = Date.distantPast
    private var seenMainScreen = Date.distantPast
    private var seenCreate = Date.distantPast
    /// FOU-121 : preuve de la demande (lignes « En attente » avant / après), voir ExportProof.
    private var proof = ExportProof()
    /// Lignes « En attente » sur l'accueil de l'export (leur texte, avec la date), et quand elles ont été lues.
    private var lastRows: [String]?
    private var seenRows = Date.distantPast
    /// Dernier écran de résumé lu avec son réglage (« summary:period »…) : sert à dire si la demande est partie avec un mauvais réglage.
    private var lastSummary = ""
    /// Demande enregistrée, mais avec un mauvais réglage : ce qu'il faut dire.
    private var badSettings: ExportProof.Problem?
    /// Une demande était déjà en cours chez Instagram : on ne la refait pas, on guette le fichier.
    private var existingRequest = false
    /// Demande « déjà en cours » datée d'aujourd'hui (peut-être la sienne, sans preuve).
    private var existingToday = false
    /// L'utilisateur a choisi de refaire une demande (après un mauvais réglage) : pas de blocage « déjà en cours ».
    private var allowSecond = false
    /// « Vérifier l'état de ma demande » touché : Zieuton a rouvert la liste d'Instagram.
    private var verifiedAt: Date?
    /// Une ligne « En attente » de plus est apparue, mais sans preuve qu'elle est la nouvelle demande
    /// (touche « Commencer » pas vue, ou ligne sans date d'aujourd'hui) : l'utilisateur regarde et décide.
    private var toCheck = false
    /// Compte verrouillé, suspendu ou désactivé par Instagram : le parcours s'arrête (FOU-121).
    private var seenLocked = Date.distantPast
    private var lockKind = ""
    private var lockedShown = false
    private var webView: WKWebView!
    private let banner = UIView()
    private let gradient = CAGradientLayer()
    private let avatar = UIImageView()
    private let sayLabel = UILabel()
    private let tipLabel = UILabel()
    private let replica = UIView()
    private let replicaBox = UIView()
    /// Demande vérifiée : bouton qui ferme la fenêtre d'Instagram (même effet que « ‹ Zieuton » en haut à gauche).
    private let homeButton = UIButton(type: .system)
    /// FOU-121 P4 : 4 grandes phases (Connexion, Réglages, Demande, Fichier) au lieu d'une barre d'étapes.
    private let phaseRow = UIStackView()
    private var phaseLabels: [UILabel] = []
    /// FOU-121 P4 : clavier ouvert (petits iPhone) : la consigne se réduit, les alertes restent entières.
    private var keyboardUp = false
    private let prevButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
    private let loading = UIActivityIndicatorView(style: .medium)
    private var downloads: [ObjectIdentifier: URL] = [:]
    private var loadingObservation: NSKeyValueObservation?
    private var watchTimer: Timer?
    /// FOU-118 : le bouton à toucher est entouré en corail sur un calque de Zieuton posé AU-DESSUS de la page.
    /// La page d'Instagram n'est jamais modifiée : elle dit seulement où est le bouton (comme elle dit déjà quel écran est affiché).
    private let spot = UIView()
    private let dimLayer = CAShapeLayer()
    private let ringView = UIView()
    private let pointer = PointingArrow()
    private let moreLabel = UILabel()
    private var ringSentJSON = ""
    private var ringRect: CGRect?
    /// 0 : bouton à l'écran ; 1 : plus bas ; -1 : plus haut.
    private var ringAt = 0
    /// FOU-118 : après la connexion, Zieuton prévient lui-même de l'alerte « nouvelle connexion » d'Instagram.
    private var sawLogin = false
    private var loginAlertShown = false
    private var loginAlert: [UIView] = []

    // Couleurs Zieuton, les mêmes en clair et en sombre (le bandeau reprend la carte « Mettre à jour »).
    private static let ink = UIColor(red: 0x2e / 255, green: 0x23 / 255, blue: 0x28 / 255, alpha: 1)
    private static let coral = UIColor(red: 0xef / 255, green: 0x7f / 255, blue: 0x6a / 255, alpha: 1)
    // FOU-118 : bandeau rose poudré, bien distinct de la page blanche d'Instagram.
    private static let peachTop = UIColor(red: 0xf9 / 255, green: 0xdf / 255, blue: 0xe3 / 255, alpha: 1)
    private static let peachBottom = UIColor(red: 0xee / 255, green: 0xb0 / 255, blue: 0xb9 / 255, alpha: 1)
    // FOU-121 P4 (maquettes v2) : réussite lilas, réglage à corriger blanc cerclé de corail,
    // petit souci rose doux avec un trait corail, pause lilas pâle neutre. Jamais de rouge vif pour une erreur courante.
    private static let lilacTop = UIColor(red: 0xee / 255, green: 0xe8 / 255, blue: 0xfb / 255, alpha: 1)
    private static let lilacBottom = UIColor(red: 0xd6 / 255, green: 0xc9 / 255, blue: 0xf4 / 255, alpha: 1)
    private static let fixTop = UIColor.white
    private static let fixBottom = UIColor(red: 0xff / 255, green: 0xf3 / 255, blue: 0xf1 / 255, alpha: 1)
    private static let souciTop = UIColor(red: 0xfd / 255, green: 0xee / 255, blue: 0xec / 255, alpha: 1)
    private static let souciBottom = UIColor(red: 0xf7 / 255, green: 0xd2 / 255, blue: 0xcd / 255, alpha: 1)
    private static let pauseTop = UIColor(red: 0xf8 / 255, green: 0xf6 / 255, blue: 0xfd / 255, alpha: 1)
    private static let pauseBottom = UIColor(red: 0xec / 255, green: 0xe7 / 255, blue: 0xf8 / 255, alpha: 1)
    private static let lilac = UIColor(red: 0xa8 / 255, green: 0x94 / 255, blue: 0xe0 / 255, alpha: 1)
    private static let sheetBg = UIColor(red: 0xff / 255, green: 0xf7 / 255, blue: 0xf8 / 255, alpha: 1)
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
        return Self.readerJS
            .replacingOccurrences(of: "__START__", with: start)
            .replacingOccurrences(of: "__CREATE__", with: create)
            .replacingOccurrences(of: "__DL__", with: ExportWatcher.countScript)
    }

    /// FOU-126 : le même lecteur, pour la vérification cachée d'ExportWatcher (mots de la page d'export en français et en anglais).
    static func checkerScript() -> String {
        readerJS
            .replacingOccurrences(of: "__START__", with: #"["commencer l'exportation","start export"]"#)
            .replacingOccurrences(of: "__CREATE__", with: #"["créer une exportation","create export"]"#)
            .replacingOccurrences(of: "__DL__", with: ExportWatcher.countScript)
    }

    // LECTEUR-INSTAGRAM:BEGIN (FOU-121 : le script est aussi testé hors de l'app, voir tests/lecteur-instagram.test.mjs)
    /// Le script posé dans la page d'Instagram. Il lit seulement des libellés visibles ; il ne touche et ne change rien.
    /// __START__, __CREATE__ et __DL__ sont remplacés au moment de l'ouvrir.
    static let readerJS = #"""
        (function () {
          document.addEventListener('click', function (e) {
            var el = e.target && e.target.closest ? e.target.closest('button,a,label,[role=button],[role=link],[role=radio],[role=checkbox],[role=menuitem],[role=option],[tabindex]') : null;
            var n = el || e.target;
            var t = (n.innerText || (n.getAttribute && n.getAttribute('aria-label')) || '').trim();
            // Touche hors d'un bouton (texte, fond) : marquée « ~ », elle ne déclenche jamais d'alerte.
            if (t) window.webkit.messageHandlers.zyeutoTap.postMessage((el ? '' : '~') + t.slice(0, 300));
          }, true);
          var START = __START__, CREATE = __CREATE__;
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
            'télécharger', 'download', 'personnaliser les informations', 'customize information', 'exporter vos informations', 'export your information'];
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
            var n = 0, f = false, seen = 0, x = '', r = [];
            for (var i = 0; i < boxes.length; i++) {
              var el = boxes[i];
              var row = el.closest('label,[role=listitem],[role=row],li') || el.parentElement;
              // Case sans texte autour : on remonte (4 niveaux max) jusqu'au libellé de la ligne.
              for (var up = 0; up < 4 && row && !low(row) && row.parentElement; up++) row = row.parentElement;
              if (!row || row.getClientRects().length === 0) continue;
              seen++;
              var on = el.checked === true || el.getAttribute('aria-checked') === 'true';
              // FOU-121 P5 (R2) : chaque ligne présente, cochée ou non, pour que Zieuton se souvienne des cases qui sortent de la page en défilant.
              r.push([(row.innerText || '').trim().split('\n')[0].slice(0, 60), on]);
              if (!on) continue;
              n++;
              var t = low(row);
              if (t.indexOf('followers et suivi') >= 0 || t.indexOf('followers and following') >= 0) f = true;
              // La première case cochée en trop : son nom, pour que le bandeau dise laquelle décocher.
              else if (!x) x = (row.innerText || '').trim().split('\n')[0].slice(0, 40);
            }
            return seen ? { n: n, f: f, t: seen, x: x, r: r } : null;
          };
          var hasWord = function (t, words) { return words.some(function (w) { return t.indexOf(w) >= 0; }); };
          // FOU-121 P5 (R3) : la ligne « Personnaliser les informations » du résumé annonce-t-elle plus que « Followers et suivi(e)s » ?
          // Seulement sur un signe clair : un nombre d'éléments de 2 ou plus, ou un autre nom à côté de « Followers et suivi(e)s ».
          var moreThanFollowers = function (t) {
            var m = t.match(/(\d+)\s*(éléments|elements|items|catégories|categories|types d'informations|types of information)/);
            if (m && parseInt(m[1], 10) >= 2) return true;
            var rest = t.replace(/^(personnaliser les informations|customize information)\s*/, '')
              .replace(/followers et suivi\(e\)s|followers et suivis|followers and following/g, '');
            return /followers et suivi|followers and following/.test(t) && /[,+]|\bet\s+\d|\band\s+\d/.test(rest);
          };
          // FOU-121 P5 : la ligne « Personnaliser les informations » nomme-t-elle « Followers et suivi(e)s » seule ('followers'),
          // ou dit-elle seulement « 1 élément » ('one') ? Sinon : '' (rien de prouvé).
          var summaryInfo = function () {
            var t = rowVal(['personnaliser les informations', 'customize information']);
            if (t === null || moreThanFollowers(t)) return '';
            if (/followers et suivi|followers and following/.test(t)) return 'followers';
            if (/(^|\s)1\s*(élément|element|item)\b/.test(t)) return 'one';
            return '';
          };
          var screen = function () {
            // Résumé « Confirmer votre exportation » : reconnu par son titre aussi (le bouton « Commencer » est souvent plus bas, hors de l'écran).
            // … ou par ses lignes « Période » et « Format » visibles avec leur valeur (le titre n'est pas toujours affiché).
            if (has(START) || seeAny(['confirmer votre exportation', 'confirm your export'])
                || (rowVal(['période', 'date range']) !== null && rowVal(['format']) !== null)) {
              var info = rowVal(['personnaliser les informations', 'customize information']);
              var per = rowVal(['période', 'date range']);
              var fmt = rowVal(['format']);
              // On décide dans l'ordre du résumé : une ligne pas encore visible laisse la décision en attente.
              if (info === null) return 'summary';
              if (hasWord(info, ['toutes les informations', 'all available', 'all information'])) return 'summary:info';
              // FOU-121 P5 (R3) : « 4 éléments », ou « Followers et suivi(e)s, Messages… » : plus que les abonnés.
              if (moreThanFollowers(info)) return 'summary:info';
              if (per === null) return 'summary';
              if (hasWord(per, ['dernière', 'dernier', 'derniers', 'last '])) return 'summary:period';
              if (fmt === null) return 'summary';
              if (hasWord(fmt, ['html'])) return 'summary:format';
              return 'summary:start';
            }
            // « Choisir où exporter » pour le compte Facebook ou Threads (l'en-tête dit « Prénom Nom • Facebook ») : mauvais compte.
            if (seeAny(['choisir où exporter', 'choose where to export']) && Array.prototype.some.call(document.querySelectorAll('span,div,h2,h3'), function (el) {
              return el.childElementCount <= 3 && /[•·]\s*(facebook|threads)\s*$/.test(low(el)) && low(el).length < 80 && vis(el);
            })) return 'wrongprofile';
            if (seeAny(['choisissez un profil', 'choose a profile'])) return 'profile';
            if (seeAny(['exporter vers un service externe', 'export to external service', 'choisir où exporter', 'choose where to export'])) return 'dest';
            if (seeAny(['depuis le début', 'all time'])) return 'period';
            if (seeAny(['json']) && seeAny(['html'])) return 'format';
            if (seeAny(['tout effacer', 'clear all', 'tout sélectionner', 'select all'])) return 'pick';
            // Page des cases défilée (les « Tout effacer » sont plus haut) : beaucoup de cases à cocher, c'est elle.
            var ps = pickState();
            if (ps && ps.t >= 6) return 'pick';
            if (has(CREATE) || listShown()) return 'home';
            // Un cran trop haut : « Vos informations et autorisations », avec la ligne « Exporter vos informations ».
            if (seeAny(['vos informations et autorisations', 'your information and permissions']) && seeAny(['exporter vos informations', 'export your information'])) return 'up';
            return '';
          };
          // FOU-118 : où est le bouton à toucher ? On renvoie seulement sa position ; Zieuton dessine le cercle
          // sur son propre calque, au-dessus de la page (rien n'est ajouté ni changé dans la page d'Instagram).
          var RING = [];
          // Lecture stricte : on n'entoure que s'il y a UN SEUL bouton visible avec exactement ce nom.
          // Deux boutons possibles, ou un bouton à moitié caché : rien n'est entouré (mieux vaut rien qu'un mauvais endroit).
          var ringRect = function () {
            if (!RING.length || window.top !== window) return null;
            var els = document.querySelectorAll('button,a,label,span,div,[role=button],[role=radio],[role=checkbox],[role=link]');
            var hits = [], far = [];
            for (var i = 0; i < els.length; i++) {
              var el = els[i];
              if (el.childElementCount > 3) continue;
              var t = low(el);
              if (t.length > 60 || RING.indexOf(t) < 0) continue;
              var box = el.closest('button,a,label,[role=button],[role=radio],[role=checkbox],[role=link]') || el;
              var r = box.getBoundingClientRect();
              if (r.width <= 0 || r.height <= 0) continue;
              if (vis(el)) { if (hits.indexOf(box) < 0) hits.push(box); }
              else if ((r.top >= innerHeight || r.bottom <= 0) && far.indexOf(box) < 0) far.push(box);
            }
            // Un libellé et son bloc parent qui portent le même nom : c'est le même bouton, on garde le plus petit.
            var inner = function (list) { return list.filter(function (b) { return !list.some(function (o) { return o !== b && b.contains(o); }); }); };
            hits = inner(hits); far = inner(far);
            var pack = function (b, at) {
              var r = b.getBoundingClientRect();
              if (r.height < 14 || r.height > 140 || r.width > innerWidth + 4) return null;
              return { x: r.left, y: r.top, w: r.width, h: r.height, at: at };
            };
            if (hits.length === 1) return pack(hits[0], 0);
            if (hits.length > 1) return null;
            if (far.length === 1) return pack(far[0], far[0].getBoundingClientRect().top >= innerHeight ? 1 : -1);
            return null;
          };
          var ringSent = '';
          var sendRing = function () {
            if (window.top !== window) return;
            var r = ringRect();
            var s = r ? [Math.round(r.x), Math.round(r.y), Math.round(r.w), Math.round(r.h), r.at].join(',') : '';
            if (s === ringSent) return;
            ringSent = s;
            window.webkit.messageHandlers.zyeutoRing.postMessage(s);
          };
          window.__zyRing = function (names) { RING = names || []; ringSent = '?'; sendRing(); };
          var ringQueued = false;
          var ringSoon = function () {
            if (ringQueued) return;
            ringQueued = true;
            requestAnimationFrame(function () { ringQueued = false; sendRing(); });
          };
          addEventListener('scroll', ringSoon, true);
          addEventListener('resize', ringSoon);
          setInterval(sendRing, 300);
          // FOU-121 : lignes de la liste des exports dont le statut dit « en attente » ou « en cours ».
          // Zieuton compare ces lignes avant et après « Commencer l'exportation » : seule une ligne nouvelle confirme la demande.
          var STATUS = /^(en attente|en cours|en préparation|pending|in progress|preparing)\b/;
          // Tests iPhone du 17 nov. (FOU-126) : chez Instagram, « En attente » est le TITRE d'une section ; chaque demande est une
          // carte en dessous (nom du compte, « Followers et suivi(e)s », « Exporter vers Appareil · Une fois · JSON »,
          // « Demandée le 17/11/2026 », bouton « Annuler »). Une carte prête a en plus « Télécharger ». La liste peut s'afficher dans une
          // fenêtre par-dessus la page (croix en haut) : on lit alors cette fenêtre, sans exiger que « Créer une exportation » soit visible.
          // Vidéo iPhone du 18 nov. : une carte PRÊTE (section « Téléchargements disponibles ») ne dit pas « Demandée le » mais
          // « Expire le 22/11/2026 · Moins de 1 Mo » (Instagram garde le fichier 4 jours). Sa date est donc une date d'expiration.
          var DATED = /^(demandée le|demandé le|requested on|expire le|expires on|expires)\b/;
          var EXPIRES = /^(expire le|expires on|expires)\b/;
          var DLNAME = /^(télécharger|download)$/;
          var BTN = 'button,a,[role=button]';
          var lit = function (el) { var r = el.getBoundingClientRect(); return r.width > 0 && r.height > 0; };
          var dateLines = function (root) {
            var all = Array.prototype.filter.call(root.querySelectorAll('span,div,p,li'), function (el) {
              return el.childElementCount <= 2 && DATED.test(low(el)) && low(el).length <= 60 && lit(el);
            });
            // Une même ligne enveloppée dans plusieurs blocs ne compte qu'une fois : on garde le bloc le plus intérieur.
            return all.filter(function (el) { return !all.some(function (o) { return o !== el && el.contains(o); }); });
          };
          // La fenêtre du dessus, si elle montre la liste ; sinon la page.
          var listRoot = function () {
            var dlg = Array.prototype.filter.call(document.querySelectorAll('[role=dialog],[aria-modal=true]'), function (d) {
              return lit(d) && dateLines(d).length > 0;
            });
            return dlg.length ? dlg[dlg.length - 1] : document;
          };
          // Une carte = le plus petit bloc autour d'une ligne « Demandée le … » qui contient un bouton, sans autre ligne datée.
          var exportCards = function () {
            var root = listRoot(), lines = dateLines(root), cards = [];
            for (var i = 0; i < lines.length; i++) {
              var card = null;
              for (var el = lines[i].parentElement, up = 0; el && el !== root && up < 8; el = el.parentElement, up++) {
                if (dateLines(el).length > 1) break;
                if (Array.prototype.some.call(el.querySelectorAll(BTN), lit)) { card = el; break; }
              }
              if (!card || cards.some(function (c) { return c.el === card; })) continue;
              var ready = Array.prototype.some.call(card.querySelectorAll(BTN), function (b) { return DLNAME.test(low(b)) && lit(b); });
              // Une carte « Expire le … » sans « Télécharger » visible n'est jamais une demande en attente : on l'ignore.
              if (!ready && EXPIRES.test(low(lines[i]))) continue;
              // La date d'abord : le texte est coupé à 220 caractères, elle ne doit jamais tomber (ni « Télécharger », vidéo du 18 nov.).
              cards.push({ el: card, ready: ready, text: (low(lines[i]) + ' · ' + low(card)).replace(/\s+/g, ' ').slice(0, 220) });
            }
            return cards;
          };
          var inCard = function (el, cards) { return cards.some(function (c) { return c.el.contains(el) || el.contains(c.el); }); };
          var listShown = function () { return dateLines(listRoot()).length > 0; };
          var pendingRows = function () {
            var cards = exportCards();
            // Carte sans « Télécharger » : demande en attente. Le mot « en attente » est ajouté : la section le dit, pas la carte.
            var rows = [], out = cards.filter(function (c) { return !c.ready; }).map(function (c) { return 'en attente · ' + c.text; });
            var els = listRoot().querySelectorAll('span,div,p,a,li,[role=button],[role=link]');
            for (var i = 0; i < els.length; i++) {
              var el = els[i];
              if (el.childElementCount > 2) continue;
              var t = low(el);
              if (t.length > 40 || !STATUS.test(t)) continue;
              // On remonte jusqu'au bloc de la ligne (statut + date), 5 niveaux au plus.
              var row = el;
              for (var up = 0; up < 5 && row.parentElement && low(row).length <= t.length + 3; up++) row = row.parentElement;
              if (low(row).length > 200 || row.getClientRects().length === 0 || rows.indexOf(row) >= 0) continue;
              // Déjà lu comme carte, ou simple titre de section (« En attente », sans date) au-dessus des cartes.
              if (inCard(row, cards) || (cards.length && !/[0-9]/.test(low(row)))) continue;
              // Un bloc qui contient déjà une ligne trouvée (ou qui est dans l'une d'elles) : c'est la même ligne.
              if (rows.some(function (r) { return r.contains(row) || row.contains(r); })) continue;
              rows.push(row);
              out.push(low(row).replace(/\s+/g, ' ').slice(0, 160));
            }
            return out;
          };
          // FOU-126 : lignes de la liste des exports qui ont un vrai bouton « Télécharger » visible, avec leur texte (leur date).
          // Zieuton compare le nombre de lignes prêtes datées du jour de la demande : un ancien export ne compte jamais.
          // Rien n'est touché : on lit seulement.
          var DL = /^(télécharger|download)$/;
          var dlButtons = function (root) {
            return Array.prototype.filter.call(root.querySelectorAll('button,a,[role=button]'), function (el) {
              var r = el.getBoundingClientRect();
              return DL.test(low(el)) && r.width > 0 && r.height > 0;
            });
          };
          var readyRows = function () {
            var cards = exportCards();
            var rows = [], out = cards.filter(function (c) { return c.ready; }).map(function (c) { return c.text; });
            // Fenêtre ouverte par-dessus : seule elle compte (la page dessous est cachée).
            var btns = dlButtons(listRoot());
            for (var i = 0; i < btns.length; i++) {
              if (inCard(btns[i], cards)) continue;
              // Comme pour les lignes « En attente » : on remonte les enveloppes du bouton jusqu'au premier bloc qui a plus de texte
              // (la ligne : nom, date, bouton), sans jamais englober une autre ligne prête. 6 niveaux au plus.
              var row = btns[i], own = low(row).length;
              for (var up = 0; up < 6 && row.parentElement && low(row).length <= own + 3; up++) {
                if (dlButtons(row.parentElement).length > 1) break;
                row = row.parentElement;
              }
              if (low(row).length > 220) continue;
              if (rows.indexOf(row) >= 0) continue;
              rows.push(row);
              out.push(low(row).replace(/\s+/g, ' ').slice(0, 160));
            }
            return out;
          };
          // FOU-121 : compte verrouillé, suspendu ou désactivé par Instagram. Seulement une phrase claire et visible :
          // une demande de code de sécurité ou « Choisir un moyen de récupération » seuls ne suffisent jamais.
          var LOCK = /nous avons verrouillé votre compte|votre compte (a été|est) (verrouillé|suspendu|désactivé)|nous avons (suspendu|désactivé) votre compte|we('ve| have) (locked|suspended|disabled) your account|your account (has been|was|is) (locked|suspended|disabled)/;
          // FOU-121 P2 : erreurs de connexion écrites par Instagram (FR et EN).
          var BADPW = /mot de passe (que vous avez (saisi|entré) )?(est )?incorrect|incorrect password|password (you entered )?(was|is) incorrect/;
          var NOUSER = /n'appartient à aucun compte|ne correspond à aucun compte|aucun compte (ne correspond|trouvé)|doesn't belong to an account|does not belong to an account|can't find an account|couldn't find an account|no account found/;
          var BADCODE = /code (de sécurité |de confirmation )?(est |que vous avez saisi est )?(incorrect|invalide|n'est pas valide|a expiré|expiré)|(this|that|the) code (is |was |has )?(incorrect|invalid|not valid|expired)|code (isn't|is not) (valid|right)|invalid (security |confirmation )?code|code expired/;
          var APPROVE = /consultez (vos )?notifications sur un autre appareil|vérifiez (vos )?notifications sur un autre appareil|approuvez (cette connexion|la connexion) (depuis|sur) un autre appareil|check (your )?notifications on another device|approve (this login|the login) (from|on) another device|waiting for approval|en attente d'approbation/;
          // Explications d'Instagram (« Si le code a expiré… », « If you forgot your password… ») : jamais prises pour une erreur.
          var HINT = /(^|[\s(])(si|if|when|lorsque|quand) [^.!?\n]*/g;
          // Vraiment lisible : pas transparent, pas réduit à un point (texte réservé aux lecteurs d'écran).
          var shown = function (el) {
            var r = el.getBoundingClientRect();
            if (r.width < 4 || r.height < 4) return false;
            for (var e = el; e && e.nodeType === 1; e = e.parentElement) {
              var cs = getComputedStyle(e);
              if (parseFloat(cs.opacity) < 0.1 || cs.visibility === 'hidden') return false;
            }
            return true;
          };
          // Une phrase visible, dans un petit bloc de texte (pas toute la page, pas un texte caché ni hors de l'écran).
          var seeText = function (re) {
            var els = document.querySelectorAll('h1,h2,h3,[role=heading],[role=alert],span,div,p');
            for (var i = 0; i < els.length; i++) {
              var el = els[i];
              if (el.childElementCount > 4) continue;
              var t = low(el);
              if (t.length > 300 || !re.test(t.replace(HINT, ' '))) continue;
              if (vis(el) && shown(el)) return true;
            }
            return false;
          };
          // Réponse : '' (rien), 'suspended', 'disabled' ou 'locked'.
          var locked = function () {
            var els = document.querySelectorAll('h1,h2,h3,[role=heading],span,div,p');
            for (var i = 0; i < els.length; i++) {
              var el = els[i];
              if (el.childElementCount > 4) continue;
              var t = low(el);
              if (t.length > 400) continue;
              var m = t.match(LOCK);
              if (!m || !vis(el)) continue;
              return /suspend/.test(m[0]) ? 'suspended' : /désactiv|disabled/.test(m[0]) ? 'disabled' : 'locked';
            }
            return '';
          };
          setInterval(function () {
            // Champ du mot de passe, même quand l'œil l'affiche en clair (il n'est plus de type « password »).
            var login = Array.prototype.some.call(document.querySelectorAll('input[type=password],input[name=username],input[name=email],input[autocomplete=username],input[autocomplete=current-password],input[name*=pass i],input[aria-label*="mot de passe" i],input[aria-label*=password i]'), vis);
            // Page des cases bien visible (« Tout sélectionner », « Followers et suivi(e)s ») : ce n'est pas une demande de mot de passe,
            // même si Instagram garde un champ caché dans la page.
            if (login && seeAny(['tout sélectionner', 'select all', 'tout effacer', 'clear all', 'followers et suivi(e)s', 'followers and following'])) login = false;
            // FOU-121 P2 : une erreur n'est signalée que si Instagram l'affiche vraiment (phrase visible à l'écran, pas une explication).
            var badpw = login && seeText(BADPW);
            // FOU-121 P2 : identifiant inconnu (C5), seulement sur l'écran de connexion.
            var nouser = login && !badpw && seeText(NOUSER);
            // Code de sécurité : on regarde seulement s'il y a une case pour un code, et si la page parle de WhatsApp, SMS ou e-mail.
            var codeIn = Array.prototype.some.call(document.querySelectorAll('input[autocomplete="one-time-code"],input[name*="code" i],input[aria-label*="code" i],input[placeholder*="code" i]'), vis);
            var code = '';
            // FOU-121 P2 : code refusé ou expiré (C6), seulement quand une case pour le code est là.
            var codebad = codeIn && !login && seeText(BADCODE);
            if (codeIn && !login) {
              var txt = (document.body.innerText || '').toLowerCase();
              code = txt.indexOf('whatsapp') >= 0 ? 'whatsapp'
                : (txt.indexOf('sms') >= 0 || txt.indexOf('texto') >= 0 || txt.indexOf('text message') >= 0) ? 'sms'
                : (txt.indexOf('e-mail') >= 0 || txt.indexOf('email') >= 0) ? 'email' : 'app';
            }
            // FOU-121 P2 (C7) : validation sur un autre appareil, sans case à remplir. Phrase claire et visible seulement.
            if (!code && !login && seeText(APPROVE)) code = 'approve';
            // Export encore « En attente » chez Instagram (FOU-115) : vu sur la page d'accueil de l'export.
            var pending = !login && !code && /en attente|en préparation|pending|in progress|preparing/.test((document.body.innerText || '').toLowerCase());
            // Fenêtre des cookies d'Instagram (FOU-121) : reconnue à ses deux boutons.
            var cookies = seeAny(['refuser les cookies optionnels', 'autoriser tous les cookies', 'decline optional cookies', 'allow all cookies']);
            var create = has(CREATE);
            // La liste des exports est lue sur l'accueil, ou dans la fenêtre qui la montre par-dessus (17 nov.).
            var list = create || listShown();
            window.webkit.messageHandlers.zyeutoState.postMessage({ locked: locked(), rows: list ? pendingRows() : null, ready: list ? readyRows() : null, cookies: cookies, login: login, badpw: badpw, nouser: nouser, codebad: codebad, code: code, pending: pending, screen: login || code ? '' : screen(), flow: inFlow(), pick: login || code ? null : pickState(), info: login || code ? '' : summaryInfo(), start: has(START), create: create, dl: __DL__ });
          }, 700);
        })();
        """#
    // LECTEUR-INSTAGRAM:END


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
        // Ouvert pour récupérer le fichier : c'est toi qui touches « Télécharger » (Zieuton ne touche jamais rien sur Instagram).
        content.add(WeakHandler(self), name: "zyeutoTap")
        content.add(WeakHandler(self), name: "zyeutoState")
        content.add(WeakHandler(self), name: "zyeutoRing")
        config.userContentController = content
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        loadingObservation = webView.observe(\.isLoading, options: [.new]) { [weak self] web, _ in
            let busy = web.isLoading
            DispatchQueue.main.async {
                if busy { self?.loading.startAnimating() } else { self?.loading.stopAnimating() }
                self?.drawRing()
            }
        }

        for v in [top, webView as UIView, spot, banner] { v.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(v) }
        buildSpot()
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
            spot.topAnchor.constraint(equalTo: webView.topAnchor),
            spot.leadingAnchor.constraint(equalTo: webView.leadingAnchor),
            spot.trailingAnchor.constraint(equalTo: webView.trailingAnchor),
            spot.bottomAnchor.constraint(equalTo: webView.bottomAnchor),
        ])
        // FOU-121 P4 : petits iPhone, clavier ouvert (mot de passe, code) : la consigne se réduit pour laisser voir le champ.
        for (name, up) in [(UIResponder.keyboardWillShowNotification, true), (UIResponder.keyboardWillHideNotification, false)] {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                guard let self, self.keyboardUp != up else { return }
                self.keyboardUp = up
                self.showStep()
            }
        }
        showStep(animated: false)
        webView.load(URLRequest(url: url))
        // Toutes les 0,5 s : on fait le point avec ce que les cadres de la page ont signalé.
        watchTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.watch() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradient.frame = banner.bounds
        drawRing()
    }

    // MARK: Cercle autour du bouton (FOU-118)

    /// Le calque ne capte aucune touche : on touche toujours le vrai bouton d'Instagram, à travers.
    private func buildSpot() {
        spot.isUserInteractionEnabled = false
        spot.clipsToBounds = true
        dimLayer.fillRule = .evenOdd
        dimLayer.fillColor = UIColor.black.withAlphaComponent(0.2).cgColor
        spot.layer.addSublayer(dimLayer)
        ringView.layer.borderWidth = 3.5
        ringView.layer.borderColor = Self.coral.cgColor
        ringView.layer.cornerRadius = 12
        ringView.layer.cornerCurve = .continuous
        ringView.layer.shadowColor = Self.coral.cgColor
        ringView.layer.shadowOffset = .zero
        ringView.layer.shadowRadius = 10
        ringView.layer.shadowOpacity = 0.5
        let glow = CABasicAnimation(keyPath: "shadowOpacity")
        glow.fromValue = 0.25
        glow.toValue = 1
        glow.duration = 0.7
        glow.autoreverses = true
        glow.repeatCount = .infinity
        ringView.layer.add(glow, forKey: "zyGlow")
        pointer.frame = CGRect(x: 0, y: 0, width: 40, height: 46)
        let bob = CABasicAnimation(keyPath: "transform.translation.y")
        bob.fromValue = 0
        bob.toValue = -7
        bob.duration = 0.5
        bob.autoreverses = true
        bob.repeatCount = .infinity
        pointer.layer.add(bob, forKey: "zyBob")
        moreLabel.font = Self.rounded(15, .bold)
        moreLabel.textColor = .white
        moreLabel.backgroundColor = Self.coral
        moreLabel.textAlignment = .center
        moreLabel.layer.cornerRadius = 17
        moreLabel.clipsToBounds = true
        for v in [ringView, pointer, moreLabel] { spot.addSubview(v) }
        hideRing()
    }

    private func hideRing() {
        dimLayer.isHidden = true
        ringView.isHidden = true
        pointer.isHidden = true
        moreLabel.isHidden = true
    }

    /// Les noms possibles du bouton à toucher maintenant (vide : rien à entourer).
    private func ringNames() -> [String] {
        guard pageKnown, !lockedShown, !downloading, codeShown.isEmpty, !loginShown, sentAt == nil, !lostShown, !finished || guarding else { return [] }
        if guarding { return guardReady ? ["Télécharger", "Download"] : [] }
        // FOU-126 : pour récupérer le fichier, on n'entoure « Télécharger » que si la preuve dit « prêt ».
        if !requesting { return getBanner == .ready ? ["Télécharger", "Download"] : [] }
        // Une demande est déjà dans la liste : jamais de cercle sur « Créer une exportation ».
        if pendingSeen { return [] }
        // Lecture sûre seulement : l'écran d'Instagram reconnu est bien celui de l'étape, depuis un moment, sans touche récente
        // ni page qui charge. Au moindre doute, pas de cercle : le bandeau suffit.
        let now = Date()
        guard now.timeIntervalSince(seenScreen) < 1.6, now.timeIntervalSince(screenSince) > 0.8,
              now.timeIntervalSince(lastTapAt) > 0.8 else { return [] }
        if upShown { return screenKey == "up" ? ["Exporter vos informations", "Export your information"] : [] }
        let base = steps[index]
        guard !base.screen.isEmpty, screenKey == base.screen else { return [] }
        // Page des cases : le bandeau dit quoi toucher (« Followers et suivi(e)s », « Tout effacer », « Enregistrer »…).
        if base.screen == "pick", pickFresh, warning == nil { return [currentStep.target] }
        // Choix à faire (« Depuis le début », « JSON ») : on entoure l'option, puis « Enregistrer » une fois choisie.
        if base.pick { return pickedAt == index ? base.wait : (base.ok ?? []) }
        return [base.target] + base.wait
    }

    /// Dit à la page quels noms de bouton chercher (seulement quand ça change).
    private func sendRingNames() {
        guard webView != nil else { return }
        let list = ringNames().map { $0.replacingOccurrences(of: "’", with: "'").lowercased() }
        let json = (try? JSONSerialization.data(withJSONObject: list)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        if json != ringSentJSON {
            ringSentJSON = json
            if list.isEmpty { ringRect = nil }
            webView.evaluateJavaScript("window.__zyRing && window.__zyRing(\(json)); true", completionHandler: nil)
        }
        drawRing()
    }

    /// La page dit où est le bouton : « x,y,largeur,hauteur,où » (où : 0 à l'écran, 1 plus bas, -1 plus haut), ou rien.
    private func ringMoved(_ s: String) {
        let n = s.split(separator: ",").compactMap { Double($0) }
        if n.count == 5 {
            ringRect = CGRect(x: n[0], y: n[1], width: n[2], height: n[3])
            ringAt = Int(n[4])
        } else {
            ringRect = nil
            ringAt = 0
        }
        drawRing()
    }

    private func drawRing() {
        guard webView != nil, loginAlert.isEmpty, !webView.isLoading, !ringNames().isEmpty, let r = ringRect else { hideRing(); return }
        let bounds = spot.bounds
        if ringAt != 0 {
            // Bouton hors de l'écran : une pastille dit dans quel sens faire défiler.
            dimLayer.isHidden = true
            ringView.isHidden = true
            pointer.isHidden = true
            moreLabel.text = ringAt > 0 ? "↓  Plus bas : fais défiler" : "↑  Plus haut : remonte"
            let w = moreLabel.intrinsicContentSize.width + 32
            let y = ringAt > 0 ? bounds.height - view.safeAreaInsets.bottom - 50 : 12
            moreLabel.frame = CGRect(x: (bounds.width - w) / 2, y: y, width: w, height: 34)
            moreLabel.isHidden = false
            return
        }
        moreLabel.isHidden = true
        let box = r.insetBy(dx: -5, dy: -5)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let path = UIBezierPath(rect: bounds)
        path.append(UIBezierPath(roundedRect: box, cornerRadius: 12))
        dimLayer.frame = bounds
        dimLayer.path = path.cgPath
        CATransaction.commit()
        ringView.frame = box
        ringView.layer.borderColor = (warning != nil ? Self.alarm : Self.coral).cgColor
        // La flèche est juste sous le bouton et pointe vers lui.
        // Bouton tout en bas de l'écran : elle se met au-dessus et pointe vers le bas.
        let hand = pointer.bounds.size
        let below = box.maxY + hand.height + 4 < bounds.height
        if pointer.pointsUp != below { pointer.pointsUp = below; pointer.setNeedsDisplay() }
        let hx = box.midX
        pointer.frame.origin = CGPoint(x: max(0, min(bounds.width - hand.width, hx - hand.width / 2)),
                                         y: below ? box.maxY + 4 : box.minY - hand.height - 4)
        dimLayer.isHidden = false
        ringView.isHidden = false
        pointer.isHidden = false
    }

    // MARK: Alerte « nouvelle connexion » d'Instagram (FOU-118)

    /// Juste après la connexion, Zieuton prévient avant Instagram : l'alerte « nouvelle connexion près de… » c'est toi.
    private func showLoginAlert() {
        let veil = UIView()
        veil.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        veil.alpha = 0
        let card = UIView()
        card.backgroundColor = Self.sheetBg
        card.layer.cornerRadius = 28
        card.layer.cornerCurve = .continuous
        card.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.2
        card.layer.shadowRadius = 16

        let face = UIImageView(image: avatar.image)
        face.layer.cornerRadius = 13
        face.layer.cornerCurve = .continuous
        face.clipsToBounds = true
        face.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([face.widthAnchor.constraint(equalToConstant: 50), face.heightAnchor.constraint(equalToConstant: 50)])
        let title = UILabel()
        title.text = "Une alerte d'Instagram ? C'est normal"
        title.font = Self.rounded(21, .heavy)
        title.textColor = Self.ink
        title.numberOfLines = 0
        let head = UIStackView(arrangedSubviews: [face, title])
        head.spacing = 12
        head.alignment = .center

        // Exemple de l'alerte, pour la reconnaître (sans logo d'Instagram).
        let sample = UIView()
        sample.backgroundColor = .white
        sample.layer.cornerRadius = 14
        sample.layer.cornerCurve = .continuous
        sample.layer.borderWidth = 1
        sample.layer.borderColor = UIColor.black.withAlphaComponent(0.08).cgColor
        let from = UILabel()
        from.text = "INSTAGRAM"
        from.font = .systemFont(ofSize: 11, weight: .semibold)
        from.textColor = .systemGray
        let what = UILabel()
        what.text = "Nouvelle connexion à ton compte…"
        what.font = .systemFont(ofSize: 15, weight: .medium)
        what.textColor = .black
        what.numberOfLines = 0
        let pill: (String, UIColor, UIColor, Bool) -> UIView = { text, bg, fg, ringed in
            let l = UILabel()
            l.text = text
            l.font = .systemFont(ofSize: 13, weight: .semibold)
            l.textColor = fg
            l.textAlignment = .center
            l.backgroundColor = bg
            l.layer.cornerRadius = 8
            l.clipsToBounds = true
            l.translatesAutoresizingMaskIntoConstraints = false
            let w = l.intrinsicContentSize.width + 20
            let wrap = UIView()
            wrap.addSubview(l)
            if ringed {
                wrap.layer.borderWidth = 3
                wrap.layer.borderColor = Self.coral.cgColor
                wrap.layer.cornerRadius = 11
            }
            NSLayoutConstraint.activate([
                l.topAnchor.constraint(equalTo: wrap.topAnchor, constant: 3),
                l.bottomAnchor.constraint(equalTo: wrap.bottomAnchor, constant: -3),
                l.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: 3),
                l.trailingAnchor.constraint(equalTo: wrap.trailingAnchor, constant: -3),
                l.widthAnchor.constraint(equalToConstant: w),
                l.heightAnchor.constraint(equalToConstant: 28),
            ])
            return wrap
        }
        let pills = UIStackView(arrangedSubviews: [pill("C'était moi", Self.metaBlue, .white, true),
                                                   pill("Ce n'était pas moi", UIColor(white: 0.93, alpha: 1), .darkGray, false), UIView()])
        pills.spacing = 6
        pills.alignment = .center
        let inner = UIStackView(arrangedSubviews: [from, what, pills])
        inner.axis = .vertical
        inner.spacing = 6
        inner.translatesAutoresizingMaskIntoConstraints = false
        sample.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: sample.topAnchor, constant: 12),
            inner.bottomAnchor.constraint(equalTo: sample.bottomAnchor, constant: -12),
            inner.leadingAnchor.constraint(equalTo: sample.leadingAnchor, constant: 12),
            inner.trailingAnchor.constraint(equalTo: sample.trailingAnchor, constant: -12),
        ])

        let why = UILabel()
        why.text = "Tu viens de te connecter : Instagram vérifie juste que c'est toi, même si la ville n'est pas la bonne."
        why.font = Self.rounded(15, .regular)
        why.textColor = Self.ink.withAlphaComponent(0.75)
        why.numberOfLines = 0
        let doIt = UILabel()
        doIt.text = "Réponds « C'était moi » 👍"
        doIt.font = Self.rounded(19, .heavy)
        doIt.textColor = Self.ink
        doIt.numberOfLines = 0
        var okConfig = UIButton.Configuration.filled()
        okConfig.title = "J'ai compris"
        okConfig.baseBackgroundColor = Self.ink
        okConfig.baseForegroundColor = .white
        okConfig.cornerStyle = .large
        okConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { a in
            var a = a; a.font = MetaViewController.rounded(17, .bold); return a
        }
        let ok = UIButton(configuration: okConfig, primaryAction: UIAction { [weak self] _ in self?.closeLoginAlert() })
        ok.translatesAutoresizingMaskIntoConstraints = false
        ok.heightAnchor.constraint(equalToConstant: 52).isActive = true

        let all = UIStackView(arrangedSubviews: [head, sample, why, doIt, ok])
        all.axis = .vertical
        all.spacing = 14
        all.setCustomSpacing(4, after: why)
        all.setCustomSpacing(18, after: doIt)
        all.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(all)
        for v in [veil, card] { v.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(v) }
        NSLayoutConstraint.activate([
            veil.topAnchor.constraint(equalTo: view.topAnchor),
            veil.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            veil.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            veil.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            all.topAnchor.constraint(equalTo: card.topAnchor, constant: 22),
            all.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            all.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            all.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
        ])
        veil.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(loginAlertTapped)))
        loginAlert = [veil, card]
        hideRing()
        view.layoutIfNeeded()
        card.transform = CGAffineTransform(translationX: 0, y: card.bounds.height + 40)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.4, options: []) {
            veil.alpha = 1
            card.transform = .identity
        }
        UIAccessibility.post(notification: .screenChanged, argument: title)
    }

    @objc private func loginAlertTapped() { closeLoginAlert() }

    private func closeLoginAlert() {
        let views = loginAlert
        guard views.count == 2 else { return }
        loginAlert = []
        UISelectionFeedbackGenerator().selectionChanged()
        UIView.animate(withDuration: 0.25, animations: {
            views[0].alpha = 0
            views[1].transform = CGAffineTransform(translationX: 0, y: views[1].bounds.height + 40)
        }, completion: { _ in views.forEach { $0.removeFromSuperview() } })
        drawRing()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed, LeaveHint.leftUnsure(requesting: requesting, finished: finished, tapped: sentAt != nil, toCheck: toCheck,
                                                  todayShown: todayPendingShown, pendingSeen: pendingSeen) {
            onLeftUnsure?(todayPendingShown || proof.pendingToday)
        }
        watchTimer?.invalidate()
        guardTimer?.invalidate()
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "zyeutoTap")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "zyeutoState")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "zyeutoRing")
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
        avatar.layer.cornerRadius = 12
        avatar.layer.cornerCurve = .continuous
        avatar.clipsToBounds = true
        avatar.translatesAutoresizingMaskIntoConstraints = false
        // 18 nov. (Victor) : bandeau centré. Le zieuteur passe en haut à droite, à côté des étapes.
        NSLayoutConstraint.activate([avatar.widthAnchor.constraint(equalToConstant: 38), avatar.heightAnchor.constraint(equalToConstant: 38)])

        sayLabel.numberOfLines = 3
        sayLabel.textAlignment = .center
        sayLabel.adjustsFontSizeToFitWidth = true
        sayLabel.minimumScaleFactor = 0.8
        // La consigne, en petit sous le titre : le titre dit la situation, la consigne dit quoi faire.
        tipLabel.font = Self.rounded(13.5, .semibold)
        tipLabel.textColor = Self.ink.withAlphaComponent(0.7)
        tipLabel.textAlignment = .center
        tipLabel.numberOfLines = 0

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

        // FOU-121 : le zieuteur passe en bas à droite du bandeau ; le texte prend toute la largeur en haut.
        let head = UIStackView(arrangedSubviews: [prevButton, sayLabel, nextButton])
        head.spacing = 8
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

        // Les 4 grandes phases, en petites pastilles : ✓ faite, entourée = en cours.
        phaseRow.spacing = 5
        phaseRow.distribution = .fillEqually
        phaseLabels = BannerPhases.names.map { name in
            let l = PaddedLabel()
            l.inset = UIEdgeInsets(top: 4, left: 6, bottom: 4, right: 6)
            l.text = name
            l.font = Self.rounded(11.5, .bold)
            l.textAlignment = .center
            l.adjustsFontSizeToFitWidth = true
            l.minimumScaleFactor = 0.75
            l.layer.cornerRadius = 10
            l.layer.cornerCurve = .continuous
            l.clipsToBounds = true
            phaseRow.addArrangedSubview(l)
            return l
        }
        phaseRow.isAccessibilityElement = true

        // Sous le titre : le bouton à chercher et le conseil, avec une place à droite pour le zieuteur.
        var homeConfig = UIButton.Configuration.filled()
        homeConfig.title = "Revenir dans Zieuton"
        homeConfig.image = UIImage(systemName: "chevron.left", withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .bold))
        homeConfig.imagePadding = 6
        homeConfig.baseBackgroundColor = Self.ink
        homeConfig.baseForegroundColor = .white
        homeConfig.cornerStyle = .large
        homeConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { a in
            var a = a; a.font = MetaViewController.rounded(16, .bold); return a
        }
        homeButton.configuration = homeConfig
        homeButton.addAction(UIAction { [weak self] _ in self?.dismiss(animated: true) }, for: .primaryActionTriggered)
        homeButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        homeButton.isHidden = true
        let lower = UIStackView(arrangedSubviews: [replicaBox, tipLabel, homeButton])
        lower.axis = .vertical
        lower.spacing = 8
        // En haut : les étapes et le zieuteur. Au milieu, en gros : la situation. Dessous : le bouton, puis la consigne en petit.
        // L'espace libre va entre les étapes et le zieuteur (même quand les étapes sont cachées : le zieuteur garde sa taille).
        let gap = UIView()
        gap.setContentHuggingPriority(UILayoutPriority(1), for: .horizontal)
        avatar.setContentHuggingPriority(.required, for: .horizontal)
        avatar.setContentCompressionResistancePriority(.required, for: .horizontal)
        let top = UIStackView(arrangedSubviews: [phaseRow, gap, avatar])
        top.alignment = .center
        top.spacing = 8
        let all = UIStackView(arrangedSubviews: [top, head, lower])
        all.axis = .vertical
        all.spacing = 10
        all.translatesAutoresizingMaskIntoConstraints = false
        banner.addSubview(all)
        NSLayoutConstraint.activate([
            all.topAnchor.constraint(equalTo: banner.topAnchor, constant: 12),
            all.bottomAnchor.constraint(equalTo: banner.bottomAnchor, constant: -14),
            all.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 14),
            all.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -14),
        ])
        // Toucher le bandeau ferme l'alerte.
        // Relecture ChatGPT (FOU-124) : le geste du bandeau ne prend jamais une touche destinée à un bouton
        // (« Revenir dans Zieuton », précédent, suivant) : le bouton garde son action, et elle seule.
        let tap = UITapGestureRecognizer(target: self, action: #selector(bannerTapped))
        tap.delegate = self
        banner.addGestureRecognizer(tap)
    }

    @objc private func bannerTapped() {
        // FOU-121 P2 : téléchargement bloqué, arrêté seulement quand l'utilisateur touche le bandeau.
        if downloading, downloadStuckShown {
            activeDownloads.forEach { $0.cancel { _ in } }
            activeDownloads.removeAll()
            downloads.removeAll()
            downloading = false
            downloadSince = nil
            downloadStuckShown = false
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showStep()
            return
        }
        // FOU-121 P2 : page en panne. On ne recharge que sur la touche de l'utilisateur, jamais tout seul.
        if !pageProblem.isEmpty {
            let again = webView.url.flatMap { $0.scheme == "https" ? $0 : nil } ?? url
            pageProblem = ""
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            webView.load(URLRequest(url: again))
            showStep()
            return
        }
        // « À vérifier » : une simple touche ne valide rien, on demande une confirmation explicite (relecture ChatGPT).
        if ExportProof.bannerTap(requesting: requesting, finished: finished, toCheck: toCheck) == .askConfirm {
            askConfirmRequest()
            return
        }
        // Une ligne d'aujourd'hui sans preuve : l'utilisateur confirme lui-même, explicitement (jamais sur une simple touche).
        if requesting, !finished, todayPendingShown, let sent = sentAt, Date().timeIntervalSince(sent) > 6 {
            askConfirmRequest()
            return
        }
        // Demande pas encore vue au bout de 20 s : on rouvre la liste des exports pour vérifier (rien n'est envoyé).
        if requesting, !finished, let sent = sentAt, Date().timeIntervalSince(sent) > 20 {
            verifiedAt = Date()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            webView.load(URLRequest(url: url))
            showStep()
            return
        }
        // Demande partie avec un mauvais réglage : la refaire seulement si l'utilisateur le choisit (il touche le bandeau).
        if badSettings != nil, requesting {
            restartRequest()
            return
        }
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

    /// FOU-121 P4 : l'étape à afficher, avec sa couleur (consigne, réussite, réglage à corriger, petit souci, pause).
    /// Ce que le bandeau dit quand on vient récupérer le fichier (voir GetBanner).
    private var getBanner: GetBanner {
        let w = ExportWatcher.shared
        return GetBanner.of(waiting: w.isWaiting, proven: w.isReady || guardReady, verdict: getVerdict)
    }

    private func getStep(_ b: GetBanner) -> Step {
        let day = ExportWatcher.shared.requestDay.map { " du " + GetBanner.dayText($0) } ?? ""
        switch b {
        case .looking:
            return Step(verb: "Un instant :", target: "je cherche ta demande\(day)",
                        tip: "Ne touche rien pour l'instant.")
        case .notYet:
            return Step(verb: "Pas encore prêt :", target: "en attente",
                        tip: "Ta demande\(day) est en préparation. Tu peux revenir plus tard.")
        case .checkDate:
            return Step(verb: "Vérifie la date", target: "de ton export",
                        tip: "Le fichier le plus récent est celui dont la date est la plus lointaine.")
        case .unproven:
            // Relecture ChatGPT : sans demande prouvée, aucune consigne directe vers un bouton (il peut être celui d'un ancien export).
            return Step(verb: "Vérifie la date", target: "de ton export",
                        tip: "« En attente » : pas prêt. Le plus récent a la date la plus lointaine.")
        case .ready:
            return Step(verb: "C'est prêt ! Touche", target: "Télécharger",
                        tip: "Sur la ligne de ta demande\(day).", look: "button")
        }
    }

    private var currentStep: Step {
        var step = baseStep
        step.tone = BannerTone.of(verb: step.verb, isWarning: warning != nil && step.verb.isEmpty)
        return step
    }

    private var baseStep: Step {
        if !pageKnown {
            return Step(verb: "Un instant,", target: "Instagram s'ouvre…")
        }
        if lockedShown {
            return Step(verb: "Export en pause :", target: lockText.title,
                        tip: "Ouvre l'application Instagram officielle.")
        }
        if downloading {
            if downloadStuckShown {
                return Step(verb: "Petit souci :", target: "le téléchargement traîne",
                            tip: "Touche ce bandeau pour l'arrêter, puis touche encore « Télécharger » chez Instagram.")
            }
            return Step(verb: "Presque fini :", target: "Zieuton récupère ton fichier…", tip: "Ne ferme pas cet écran.")
        }
        if pageProblem == "offline", guarding, !guardReady {
            return Step(verb: "Oups :", target: "Instagram ne répond pas",
                        tip: "Vérifie ton Wi-Fi ou ta 4G. Ta demande n'est pas perdue : je réessaie toutes les 10 secondes.")
        }
        if pageProblem == "offline" {
            return Step(verb: "Oups :", target: "Instagram ne répond pas",
                        tip: "Vérifie ton Wi-Fi ou ta 4G, puis touche ce bandeau pour recharger la page.")
        }
        if pageProblem == "failed" {
            return Step(verb: "Oups :", target: "la page ne s'est pas ouverte",
                        tip: "Touche ce bandeau pour réessayer. Rien n'est envoyé à ta place.")
        }
        if pageProblem == "crashed" {
            return Step(verb: "Oups :", target: "la page s'est fermée",
                        tip: "Touche ce bandeau pour la rouvrir. Rien n'est envoyé à ta place.")
        }
        if let bad = badSettings, guarding, !guardReady {
            return Step(verb: "Demande enregistrée, mais", target: bad.title,
                        tip: bad.text + " Pour la refaire avec le bon réglage, touche ce bandeau.")
        }
        if guarding {
            if guardReady {
                return Step(verb: "C'est prêt ! Touche", target: "Télécharger",
                            tip: "Juste en dessous.", look: "button")
            }
            if Date().timeIntervalSince(guardSince) > Self.guardFor {
                return Step(verb: "Instagram prend son temps :", target: "tu peux fermer",
                            tip: "Je regarde à nouveau quand tu rouvres Zieuton.")
            }
            // Ouvert pour récupérer le fichier : la demande est encore « En attente » (ou à vérifier). Jamais « Touche Télécharger ».
            if !requesting { return getStep(GetBanner.of(waiting: true, proven: false, verdict: getVerdict)) }
            // Demande vérifiée (on n'arrive ici qu'après la preuve) : on dit clairement comment sortir d'Instagram.
            return Step(verb: LeaveHint.verb(existing: existingRequest, today: existingToday),
                        target: LeaveHint.title(existing: existingRequest, today: existingToday), tip: LeaveHint.tip)
        }
        if cookiesShown {
            return Step(verb: "Cookies : touche", target: "Refuser les cookies optionnels",
                        tip: "Instagram marche pareil, et Zieuton n'en a pas besoin.")
        }
        if !codeShown.isEmpty, badCode, codeShown != "approve" {
            return Step(verb: "Petit souci :", target: "code refusé",
                        tip: "Il est faux ou trop vieux. Demande un nouveau code chez Instagram et tape le plus récent. Zieuton ne voit jamais ce code.")
        }
        if !codeShown.isEmpty {
            let place: (String, String) = {
                switch codeShown {
                case "whatsapp": return ("va chercher le code sur WhatsApp", "Instagram vient de te l'envoyer sur WhatsApp. Ouvre WhatsApp, note le code, puis reviens ici le taper.")
                case "sms": return ("regarde tes SMS", "Instagram vient de t'envoyer un code par SMS. Tape-le ici : souvent, ton iPhone te le propose tout seul au-dessus du clavier.")
                case "approve": return ("valide sur ton autre appareil", "Instagram t'a envoyé une notification là où tu es déjà connecté (l'app Instagram, par exemple). Accepte-la, puis reviens ici.")
                case "email": return ("regarde tes e-mails", "Instagram vient de t'envoyer un code par e-mail. Ouvre ta boîte mail, note le code, puis reviens ici le taper.")
                default: return ("tape le code de sécurité", "Instagram vérifie que c'est bien toi. Le code arrive par WhatsApp, SMS ou e-mail, selon ton compte.")
                }
            }()
            return Step(verb: "Petite vérif d'Instagram :", target: place.0,
                        tip: place.1 + " Zieuton ne voit jamais ce code. En général, Instagram ne le demande qu'à la première connexion.")
        }
        if loginShown {
            // FOU-121 P2 : les refus d'Instagram passent avant tout le reste, même à la toute première connexion.
            if unknownUser {
                return Step(verb: "Petit souci :", target: "compte introuvable",
                            tip: "Instagram ne trouve pas ce compte. Vérifie ton nom d'utilisateur (sans @), ou essaie ton e-mail ou ton numéro.")
            }
            if badPassword {
                return loginHelp.manyBadPasswords
                    ? Step(verb: "Petit souci :", target: "mot de passe encore refusé",
                           tip: "Pour éviter un blocage, touche « Mot de passe oublié ? » chez Instagram plutôt que de réessayer.")
                    : Step(verb: "Petit souci :", target: "mot de passe incorrect",
                           tip: "Vérifie les majuscules et réessaie. Zieuton ne voit jamais ton mot de passe.")
            }
            return index == 0 && sentAt == nil
                ? Step(verb: "D'abord,", target: "connecte-toi à Instagram",
                       tip: "Ton mot de passe se tape chez Instagram : Zieuton ne le voit jamais. Tu ne le feras qu'une fois.")
                : Step(verb: "Instagram vérifie que c'est toi :", target: "tape ton mot de passe",
                       tip: "Puis touche « Continuer ». Chez Instagram, comme d'habitude : Zieuton ne le voit jamais.")
        }
        if pendingSeen, requesting, !finished {
            return Step(verb: "Un instant :", target: "une demande est déjà là",
                        tip: "N'en crée pas d'autre, je vérifie.")
        }
        if toCheck, requesting, !finished {
            // FOU-121 : une ligne de plus, mais sans preuve que c'est la nouvelle demande. Zieuton ne conclut pas à sa place.
            return Step(verb: "À vérifier :", target: "ta ligne « En attente »",
                        tip: "Datée d'aujourd'hui ? Touche ce bandeau. Sinon, ne refais rien.")
        }
        if let sent = sentAt {
            // FOU-121 : une demande pas encore vue n'est jamais un échec. On propose de vérifier, jamais de recommencer.
            // Vidéo du 18 nov. : une ligne « En attente » d'aujourd'hui est à l'écran : on ne dit pas « je ne vois pas de demande ».
            if todayPendingShown, Date().timeIntervalSince(sent) > 6 {
                return Step(verb: "Demande du jour trouvée :", target: "ne refais rien",
                            tip: "C'est la tienne ? Touche ce bandeau pour la suivre.")
            }
            if let v = verifiedAt, Date().timeIntervalSince(v) > 6 {
                return Step(verb: "Pas encore vue :", target: "regarde la liste",
                            tip: "Aucune ligne « En attente » d'aujourd'hui ? Tu peux recréer.")
            }
            if Date().timeIntervalSince(sent) > 20 {
                return Step(verb: "Pas encore vue :", target: "vérifie son état",
                            tip: "Ne la refais pas : touche ce bandeau, j'ouvre la liste.")
            }
            return Step(verb: "Bien joué !", target: "Instagram enregistre…",
                        tip: "Je vérifie qu'elle est dans la liste.")
        }
        if !requesting, !downloading { return getStep(getBanner) }
        if lostShown {
            // FOU-121 : écran inconnu = pas forcément une erreur (vérification, chargement, nouvelle interface). Rien ne se recharge tout seul.
            return Step(verb: "Je ne reconnais pas encore", target: "cet écran",
                        tip: "Instagram te demande peut-être une vérification : fais-la, je reprends dès que je reconnais la page. Pour revenir au début de l'export, touche ce bandeau.")
        }
        if let w = warning {
            // FOU-121 P4 (C12) : l'alerte ne s'efface plus toute seule ; elle part quand c'est réglé, ou si on touche le bandeau.
            return Step(verb: "", target: w.title, tip: w.text + " Touche ce bandeau pour fermer l'alerte.", look: steps[index].look)
        }
        if upShown {
            return Step(verb: "Presque :", target: "Exporter vos informations",
                        tip: "Tu es revenu un cran trop loin. Touche cette ligne sur la page.", look: "row")
        }
        // Page des cases : le bandeau dit exactement ce qu'il reste à faire, et n'avance pas tant que ce n'est pas bon.
        if steps[index].screen == "pick", pickFresh {
            if !pickFollowers {
                return Step(verb: "Coche", target: "Followers et suivi(e)s",
                            tip: "Dans la rubrique Contacts. C'est la seule case qui compte.", look: "check", screen: "pick")
            }
            if pickChecked == 2, !pickExtra.isEmpty {
                return Step(verb: "Encore 1 case en trop, décoche :", target: pickExtra,
                            tip: "Fais défiler la liste pour la trouver. Garde seulement « Followers et suivi(e)s ».", look: "check", screen: "pick")
            }
            if pickChecked > 1 {
                let more = pickChecked - 1
                return Step(verb: "Encore \(more) case\(more > 1 ? "s" : "") en trop :", target: "Tout effacer",
                            tip: "Touche « Tout effacer » dans chaque rubrique, puis recoche seulement « Followers et suivi(e)s ».", look: "link", screen: "pick")
            }
            return Step(verb: "✓ Bonne case cochée ! Maintenant,", target: "Enregistrer", tip: "Tout en bas de la liste.", look: "button", screen: "pick")
        }
        // FOU-121 P5 : le bon choix est confirmé (✓) dès qu'il est vu, avant « Enregistrer ».
        if steps[index].pick, pickedAt == index {
            return Step(verb: "✓ Bon choix ! Maintenant,", target: "Enregistrer",
                        tip: "Pour valider ton choix chez Instagram.", look: "button", screen: steps[index].screen)
        }
        // Résumé lu avec tous les bons réglages (une seule information, « Depuis le début », JSON) : ✓ avant la dernière touche.
        // Relecture ChatGPT (P5) : seulement si l'unique information est prouvée être « Followers et suivi(e)s ».
        if steps[index].final, sentAt == nil, screenKey == "summary:start", Date().timeIntervalSince(seenScreen) < 1.6,
           PickMemory.settingsVerified(summaryInfo: summaryInfo, followersAlone: pickMemory.followers && pickMemory.checked == 1) {
            var last = steps[index]
            last.verb = "✓ Tout est bien réglé ! " + last.verb
            return last
        }
        return steps[index]
    }

    /// Ce que le bandeau affiche en ce moment : on ne le redessine que si ça change vraiment.
    private var shownKey = ""

    /// Vidéo du 18 nov. : la liste est visible mais la preuve est incertaine (« Demande à vérifier », ou une ligne d'aujourd'hui
    /// sans preuve) : « Revenir dans Zieuton » est proposé aussi, pour sortir d'Instagram sans rien refaire.
    private var unsureShown: Bool {
        guard requesting, !finished else { return false }
        if toCheck { return true }
        if todayPendingShown, let sent = sentAt { return Date().timeIntervalSince(sent) > 6 }
        return false
    }

    private func showStep(animated: Bool = true) {
        let step = currentStep
        let normal = pageKnown && codeShown.isEmpty && !(loginShown || downloading || sentAt != nil)
        let phase = BannerPhases.current(login: loginShown, code: !codeShown.isEmpty, finalStep: steps[index].final,
                                         requested: sentAt != nil || toCheck, file: !requesting || guarding || finished || downloading)
        let reduced = keyboardUp && step.tone == .consigne
        let home = LeaveHint.showsButton(guarding: guarding, ready: guardReady, badSettings: badSettings != nil,
                                         pageProblem: !pageProblem.isEmpty, downloading: downloading, unsure: unsureShown)
        let key = [home ? "H" : "", step.verb, step.target, step.after, step.tip, step.look, normal ? "1" : "0", String(index), warning == nil ? "" : "!", lostShown ? "L" : "", upShown ? "U" : "", cookiesShown ? "C" : "", "\(step.tone)", String(phase), reduced ? "K" : ""].joined(separator: "|")
        guard key != shownKey else { return }
        shownKey = key
        let apply = {
            // FOU-121 P4 : texte toujours foncé ; c'est la couleur du bandeau qui dit s'il faut corriger quelque chose.
            let fg: UIColor = Self.ink
            let say = NSMutableAttributedString()
            // 18 nov. (Victor) : centré ; la situation en gros, sur sa propre ligne.
            let centered = NSMutableParagraphStyle()
            centered.alignment = .center
            if !step.verb.isEmpty {
                say.append(NSAttributedString(string: step.verb + "\n", attributes: [.font: Self.rounded(16, .semibold), .foregroundColor: fg.withAlphaComponent(0.75), .paragraphStyle: centered]))
            }
            say.append(NSAttributedString(string: step.target, attributes: [.font: Self.rounded(26, .heavy), .foregroundColor: fg, .paragraphStyle: centered]))
            if !step.after.isEmpty {
                say.append(NSAttributedString(string: ", " + step.after, attributes: [.font: Self.rounded(17, .semibold), .foregroundColor: fg, .paragraphStyle: centered]))
            }
            self.sayLabel.attributedText = say
            self.tipLabel.textColor = Self.ink.withAlphaComponent(0.8)
            // Consigne : 4 lignes au plus (réductible) ; alerte ou souci : jamais coupé (BUG-06).
            self.tipLabel.numberOfLines = step.tone == .consigne ? 4 : 0
            let (top, bottom, border, width): (UIColor, UIColor, UIColor, CGFloat) = {
                switch step.tone {
                case .consigne: return (Self.peachTop, Self.peachBottom, .clear, 0)
                case .success: return (Self.lilacTop, Self.lilacBottom, .clear, 0)
                case .fix: return (Self.fixTop, Self.fixBottom, Self.coral, 2.5)
                case .souci: return (Self.souciTop, Self.souciBottom, Self.coral, 1.5)
                case .pause: return (Self.pauseTop, Self.pauseBottom, Self.lilac, 1.5)
                }
            }()
            CATransaction.begin()
            CATransaction.setAnimationDuration(animated ? 0.25 : 0)
            self.gradient.colors = [top.cgColor, bottom.cgColor]
            CATransaction.commit()
            self.banner.layer.borderColor = border.cgColor
            self.banner.layer.borderWidth = width
            self.replicaBox.layer.borderColor = Self.coral.cgColor
            self.tipLabel.text = step.tip
            // Clavier ouvert : la consigne se réduit au titre ; une alerte reste entière (FOU-121 P4).
            self.tipLabel.isHidden = step.tip.isEmpty || reduced
            self.replicaBox.isHidden = step.look.isEmpty || !normal || reduced
            self.homeButton.isHidden = !home
            if normal && !step.look.isEmpty && !reduced { self.drawReplica(self.warning == nil ? step : self.steps[self.index]) }
            self.drawPhases(phase)
            self.phaseRow.isHidden = !self.pageKnown || self.lockedShown || reduced
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
        // Fondu d'entrée seulement : l'ancien texte disparaît d'un coup, on ne voit jamais deux textes superposés.
        let faded = [sayLabel, tipLabel, replica] as [UIView]
        if animated { faded.forEach { $0.layer.removeAllAnimations(); $0.alpha = 0 } }
        apply()
        if animated {
            UIView.animate(withDuration: 0.18, delay: 0, options: [.allowUserInteraction]) { faded.forEach { $0.alpha = 1 } }
        }
        if animated, warning != nil, normal {
            let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
            shake.values = [0, -9, 9, -6, 6, -3, 0]
            shake.duration = 0.4
            banner.layer.add(shake, forKey: "zyShake")
        }
        sendRingNames()
        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
                self.view.layoutIfNeeded()
            }
        }
    }

    /// Pastilles des phases : faite (✓, foncée), en cours (entourée), à venir (pâle).
    private func drawPhases(_ current: Int) {
        for (i, l) in phaseLabels.enumerated() {
            let name = BannerPhases.names[i]
            l.text = i < current ? "✓ " + name : name
            l.layer.borderWidth = i == current ? 1.5 : 0
            l.layer.borderColor = Self.ink.cgColor
            l.backgroundColor = i < current ? Self.ink : i == current ? UIColor.white.withAlphaComponent(0.85) : .clear
            l.textColor = i < current ? .white : Self.ink.withAlphaComponent(i == current ? 1 : 0.45)
        }
        phaseRow.accessibilityLabel = "Étape en cours : " + BannerPhases.names[current]
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
        // Bouton qui termine une étape : une ligne du bouton touché porte exactement ce nom (ou commence par lui).
        // Sinon « Personnaliser les informations » contenait « format » et le bandeau sautait à « Choisis JSON ».
        let lines = t.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
        let hit: ([String]) -> Bool = { list in list.contains { w in
            let n = Self.norm(w)
            return !n.isEmpty && (t.hasPrefix(n) || lines.contains(n))
        } }
        lastTapAt = Date()
        // Demande pas encore vue, et l'utilisateur retouche « Créer une exportation » : il refait le parcours (son choix).
        // La référence (lignes « En attente » d'avant) ne bouge pas : la première demande, si elle est passée, sera vue aussi.
        if requesting, !loose, hit(steps[0].wait),
           ExportProof.duplicateRisk(tappedStart: sentAt != nil, toCheck: toCheck, finished: finished) {
            sentAt = nil
            verifiedAt = nil
            index = min(1, steps.count - 1)
            warning = nil
            showStep()
            warnDuplicate()
            return
        }
        // « Commencer l'exportation » compte toujours, même si le bandeau s'est trompé d'étape avant :
        // sinon la demande n'est jamais notée et aucune notification ne part (vu par Victor le 4 novembre).
        if requesting, sentAt == nil, !loose, let f = steps.lastIndex(where: { $0.final }), index < f, hit(steps[f].wait) {
            index = f
            sentAt = Date()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            screenKey = ""
            screenSince = Date()
            warning = nil
            showStep()
            return
        }
        let last = min(steps.count - 1, index + 2)
        guard index <= last else { return }
        let checking = guarded && pageKnown && !loginShown && codeShown.isEmpty && !lostShown && sentAt == nil
        for i in index...last {
            let step = steps[i]
            guard hit(step.wait) else { continue }
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
            // L'écran vu avant la touche ne compte plus : pendant qu'Instagram charge le suivant,
            // le bandeau ne doit pas revenir en arrière (vu sur la vidéo de Victor du 4 novembre).
            screenKey = ""
            screenSince = Date()
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
        if index > 0, hit(steps[0].wait) { index = 1; warning = nil; showStep(); return }
        // « Exporter vos informations » (un cran trop haut) : c'est le bon chemin pour revenir.
        if has(["Exporter vos informations", "Export your information"]) { return }
        // Flèche retour, croix, Annuler : la personne revient en arrière, très bien.
        if ["retour", "back", "fermer", "close", "annuler", "cancel", "precedent", "previous"].contains(t.trimmingCharacters(in: .whitespacesAndNewlines)) {
            if warning != nil { warning = nil; showStep() }
            return
        }
        // Cases à cocher libres, ou grand bloc de texte (une zone vide de la page) : rien à dire.
        if loose || steps[index].free || t.count > 120 { return }
        // Vidéo du 18 nov. : sur la liste des exports, on regarde, on change d'onglet, on fait défiler : jamais « mauvais bouton ».
        if ExportProof.listIsCalm(screen: screenKey, rowsShown: Date().timeIntervalSince(seenRows) < 1.6) { return }
        warn("Oups, pas le bon bouton !", Self.backHint)
    }

    private static let backHint = "Reviens en arrière avec la flèche ‹ ou la croix ✕ d'Instagram, puis touche le bouton entouré ici. Sinon, tu risques de te perdre."

    private func warn(_ title: String, _ text: String) {
        warning = Warning(title: title, text: text)
        warningAt = Date()
        warningLeft = false
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
        shownKey = "" // redessine même si c'était déjà la même alerte (on secoue encore)
        showStep()
    }

    /// Un cadre de la page dit ce qu'il affiche.
    private func received(state: [String: Any], mainFrame: Bool) {
        let now = Date()
        // Le cadre principal montre un écran de l'export : il a raison contre un cadre caché (connexion Meta préchargée) qui croit voir un mot de passe.
        if mainFrame, state["login"] as? Bool != true, let scr = state["screen"] as? String, !scr.isEmpty { seenMainScreen = now }
        if state["login"] as? Bool == true, mainFrame || now.timeIntervalSince(seenMainScreen) > 1.6 {
            seenLogin = now
            let bad = state["badpw"] as? Bool == true
            loginHelp.saw(badPassword: bad)
            if bad != badPassword { badPassword = bad; showStep() }
            let nouser = state["nouser"] as? Bool == true
            if nouser != unknownUser { unknownUser = nouser; showStep() }
        }
        if let code = state["code"] as? String, !code.isEmpty {
            seenCode = now
            codeKind = code
            let wrong = state["codebad"] as? Bool == true
            if wrong != badCode { badCode = wrong; showStep() }
        }
        if state["cookies"] as? Bool == true { seenCookies = now }
        // Compte verrouillé : seulement le cadre principal, et seulement une phrase claire (voir le script).
        if mainFrame, let lock = state["locked"] as? String, !lock.isEmpty { seenLocked = now; lockKind = lock }
        // Lignes « En attente » de l'accueil de l'export : avant la demande, elles servent de référence.
        if mainFrame, let rows = state["rows"] as? [String] {
            lastRows = rows
            seenRows = now
            if sentAt == nil, !finished { proof.saw(rows, now: now) }
        }
        if state["flow"] as? Bool == true { seenFlow = now }
        if let pick = state["pick"] as? [String: Any], let n = pick["n"] as? Int {
            let before = (pickChecked, pickFollowers)
            if let rows = pick["r"] as? [[Any]] {
                pickMemory.saw(rows.compactMap { r -> (String, Bool)? in
                    guard r.count == 2, let name = r[0] as? String, let on = r[1] as? Bool else { return nil }
                    return (name, on)
                })
                pickChecked = pickMemory.checked
                pickFollowers = pickMemory.followers
                pickExtra = pickMemory.extra ?? ""
            } else {
                // Ancienne page (sans la liste des lignes) : comme avant.
                pickChecked = n
                pickFollowers = pick["f"] as? Bool == true
                pickExtra = pick["x"] as? String ?? ""
            }
            seenPick = now
            if before != (pickChecked, pickFollowers), steps[index].screen == "pick" { showStep() }
        }
        if mainFrame, let info = state["info"] as? String { summaryInfo = info }
        if let scr = state["screen"] as? String, !scr.isEmpty {
            if scr != screenKey { screenKey = scr; screenSince = now }
            if scr == "pick" || scr == "home" { pickRedo = false }
            // Relecture ChatGPT (P5) : la mémoire des cases ne repart de zéro qu'à une vraie nouvelle demande (accueil de l'export,
            // où Instagram remet ses cases par défaut). Jamais sur un délai, un chargement ou un défilement.
            if PickMemory.resets(onScreen: scr) { pickMemory = PickMemory() }
            // Arrivé au résumé : la référence des lignes « En attente » est figée (la nouvelle ligne ne doit pas devenir la référence).
            if scr.hasPrefix("summary") { proof.freeze() }
            if scr.hasPrefix("summary:") { lastSummary = scr }
            seenScreen = now
        }
        if state["create"] as? Bool == true { seenCreate = now }
        // FOU-126 : la liste des exports est lue pour la preuve « prêt » (ligne de la demande, jamais un simple décompte).
        let watcher = ExportWatcher.shared
        if mainFrame, watcher.isWaiting, !downloading {
            let verdict = watcher.observe(pending: state["rows"] as? [String], ready: state["ready"] as? [String],
                                          login: state["login"] as? Bool == true, now: now)
            if !requesting, verdict != getVerdict { getVerdict = verdict; showStep() }
            // Ouvert pour récupérer le fichier, mais Instagram le prépare encore : on guette ici (FOU-115).
            if !requesting, !guarding, verdict == .pending { startGuarding() }
            // La ligne de la demande a un « Télécharger » de plus qu'au moment de la preuve : le fichier est prêt.
            if guarding, !guardReady, verdict == .ready { guardIsReady() }
        }
        if mainFrame && !pageKnown {
            pageKnown = true
            // FOU-121 P2 : seulement si un vrai champ de connexion est vu (l'adresse seule ne suffit pas).
            loginShown = state["login"] as? Bool == true
            showStep()
        }
    }

    /// Fait le point : écran de connexion ? demande bien partie ?
    private func watch() {
        defer { sendRingNames() }
        guard pageKnown, !lockedShown else { return }
        // Compte verrouillé, suspendu ou désactivé : on arrête tout de suite le parcours (FOU-121).
        if Date().timeIntervalSince(seenLocked) < 1.6 { showLocked(); return }
        // Téléchargement qui ne finit pas : au bout de 90 s, le bandeau propose de l'arrêter (FOU-121 P2).
        if downloading, !downloadStuckShown, let since = downloadSince, LoginHelp.downloadStuck(since: since, now: Date()) {
            downloadStuckShown = true
            showStep()
        }
        guard !downloading, !finished else { return }
        let now = Date()
        let onLoginURL = (webView.url?.absoluteString.lowercased() ?? "").contains("login")
        // FOU-121 P2 : « tape ton mot de passe » seulement si un vrai champ est vu, jamais d'après l'adresse.
        let login = now.timeIntervalSince(seenLogin) < 1.6
        let createVisible = now.timeIntervalSince(seenCreate) < 1.6
        if login != loginShown { loginShown = login; showStep() }
        let code = now.timeIntervalSince(seenCode) < 1.6 ? codeKind : ""
        if code != codeShown { codeShown = code; if BannerPhases.clearsWarning(.codeChanged) { warning = nil }; showStep() }
        let cookies = now.timeIntervalSince(seenCookies) < 1.6
        if cookies != cookiesShown { cookiesShown = cookies; showStep() }
        // Connexion finie (mot de passe, puis code s'il y en a un) : Zieuton prévient de l'alerte d'Instagram avant qu'elle arrive.
        if login { sawLogin = true }
        if sawLogin, !loginAlertShown, !login, code.isEmpty, !webView.isLoading,
           now.timeIntervalSince(seenLogin) > 1.5, now.timeIntervalSince(seenCode) > 1.5 {
            loginAlertShown = true
            showLoginAlert()
        }
        // Perdu ? Aucun écran du parcours reconnu depuis 2 s, et l'adresse n'est plus celle de l'export (ou rien de reconnu depuis 6 s).
        let urlNow = webView.url?.absoluteString.lowercased() ?? ""
        let offPath = !urlNow.isEmpty && !urlNow.contains("/dyi") && !onLoginURL
        if offPath { if offSince == nil { offSince = now } } else { offSince = nil }
        let unknownFor = now.timeIntervalSince(max(seenScreen, seenFlow, lostCheckFrom))
        let lost = !login && code.isEmpty && sentAt == nil && pageProblem.isEmpty && !webView.isLoading && unknownFor > 2
            && ((offSince.map { now.timeIntervalSince($0) > 1.5 } ?? false) || unknownFor > 6)
        // Relecture ChatGPT (P4) : un écran pas reconnu ne retire pas une alerte de mauvais choix. Le bandeau montre la pause
        // par-dessus, et l'alerte revient avec la page ; elle part seulement si l'utilisateur revient sur l'écran de l'étape.
        if lost != lostShown {
            lostShown = lost
            if lost, warning != nil { warningLeft = true }
            if BannerPhases.clearsWarning(.lostChanged) { warning = nil }
            showStep()
        }
        let screenFresh = now.timeIntervalSince(seenScreen) < 1.6
        // Compte Facebook ou Threads choisi : l'alerte reste tant que cet écran est affiché.
        // Relecture ChatGPT (P4) : une seule vibration en arrivant sur cet écran, jamais relancée toute seule ;
        // elle ne part que quand un autre écran est vraiment reconnu (pas pendant un chargement).
        let wrongTitle = "Oups, ce n'est pas le bon compte !"
        let onWrongProfile = screenFresh && screenKey == "wrongprofile" && sentAt == nil && !login
        let otherScreen = screenFresh && screenKey != "wrongprofile"
        if BannerPhases.shouldWarnWrongProfile(onScreen: onWrongProfile, alreadyWarned: wrongProfileWarned) {
            wrongProfileWarned = true
            warn(wrongTitle, "C'est ton compte Facebook ou Threads. Touche la flèche ‹ en haut à gauche, puis ton compte marqué Instagram.")
        } else if otherScreen {
            wrongProfileWarned = false
            if warning?.title == wrongTitle { warning = nil; showStep() }
        }
        let up = screenFresh && screenKey == "up" && sentAt == nil && !login && code.isEmpty
        if up != upShown { upShown = up; showStep() }
        // FOU-121 P4 (C12) : une alerte ne s'efface jamais au bout d'un délai. Elle part quand c'est réglé :
        // bonne touche, retour sur l'écran de l'étape, ou l'utilisateur touche le bandeau.
        if warning != nil, warning?.title != wrongTitle, screenFresh, !screenKey.isEmpty, !steps[index].screen.isEmpty {
            let onStep = screenKey == steps[index].screen
            if !onStep { warningLeft = true }
            if BannerPhases.warningCleared(leftStepScreen: warningLeft, backOnStepScreen: onStep) { warning = nil; showStep() }
        }
        // Écran « code de sécurité » d'Instagram (après « Commencer l'exportation ») : rien n'est parti tant qu'il est là (FOU-115).
        guard requesting, !login, code.isEmpty else { return }
        let rowsFresh = now.timeIntervalSince(seenRows) < 1.6
        if createVisible { if createSince == nil { createSince = now } } else { createSince = nil }
        // Vidéo du 18 nov. : la liste peut être lue sans que « Créer une exportation » soit visible (fenêtre par-dessus, liste
        // défilée jusqu'à « En attente »). Une liste lue depuis 1,5 s suffit aussi pour reconnaître une demande déjà en cours.
        if rowsFresh { if listSince == nil { listSince = now } } else { listSince = nil }
        let homeSettled = [createSince, listSince].contains { d in d.map { now.timeIntervalSince($0) > 1.5 } ?? false }
        // FOU-121 : la demande n'est confirmée que par une preuve vue chez Instagram : la touche « Commencer l'exportation »
        // vue, puis une ligne « En attente » de plus qu'avant, datée d'aujourd'hui. Ni le bouton qui disparaît, ni un délai,
        // ni un retour en arrière ne suffisent. Une ligne de plus sans cette preuve (ancienne ligne arrivée en retard,
        // touche pas vue) : « à vérifier », l'utilisateur regarde la liste et décide.
        let verdict = rowsFresh ? proof.verdict(lastRows, tapped: sentAt != nil, now: now) : .none
        if verdict == .confirmed {
            finishRequest()
            return
        }
        if rowsFresh, (verdict == .toCheck) != toCheck { toCheck = verdict == .toCheck; showStep() }
        // Hors de la liste depuis un moment (il est reparti dans le parcours, par exemple) : on ne lui demande plus de vérifier.
        if toCheck, now.timeIntervalSince(seenRows) > 4 { toCheck = false; showStep() }
        if toCheck { return }
        // Une demande est déjà dans la liste, avant toute touche : le bandeau ne dit pas « Touche Créer une exportation »
        // le temps de la reconnaître (principe : une demande en attente visible n'encourage jamais une nouvelle demande).
        let seen = sentAt == nil && !allowSecond && rowsFresh && proof.alreadyPending
        if seen != pendingSeen { pendingSeen = seen; showStep() }
        // « Commencer » touché, sans preuve : une ligne « En attente » datée d'aujourd'hui à l'écran rassure, sans rien conclure.
        let todayRow = sentAt != nil && rowsFresh && (lastRows ?? []).contains { ExportProof.isDated($0, day: now, now: now) }
        if todayRow != todayPendingShown { todayPendingShown = todayRow; showStep() }
        // Une demande était déjà en cours avant de commencer : inutile d'en refaire une, on guette le fichier.
        if sentAt == nil, !allowSecond, homeSettled, rowsFresh, proof.alreadyPending {
            existingRequest = true
            existingToday = proof.pendingToday
            finishRequest()
            return
        }
        // Demande touchée mais pas encore vue : le bandeau passe à « Vérifier son état » au bout de 20 s (jamais « recommence »).
        if sentAt != nil {
            showStep(animated: false)
            return
        }
        // Revenu sur la page d'accueil de l'export (« Créer une exportation » bien visible depuis un moment) :
        // le bandeau reprend à la première étape.
        if index > 0, let since = createSince,
           now.timeIntervalSince(since) > 2.5, now.timeIntervalSince(lastTapAt) > 2.5 {
            index = 0
            pickedAt = -1
            warning = nil
            createSince = nil
            showStep()
            return
        }
        // Le bandeau suit l'écran d'Instagram : si l'écran affiché correspond à une autre étape, on s'y cale
        // (y compris en revenant en arrière depuis le résumé final : rien n'est considéré comme envoyé).
        syncToScreen(now)
    }

    /// Cale le bandeau sur l'étape qui correspond à l'écran d'Instagram (vu depuis au moins 1 s, sans touche récente).
    private func syncToScreen(_ now: Date) {
        guard sentAt == nil, codeShown.isEmpty, !loginShown,
              now.timeIntervalSince(seenScreen) < 1.6, now.timeIntervalSince(screenSince) > 1.0,
              now.timeIntervalSince(lastTapAt) > 0.8 else { return }
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

    /// L'utilisateur choisit de refaire sa demande (elle était partie avec un mauvais réglage) : on repart du début.
    private func restartRequest() {
        guardTimer?.invalidate(); guardTimer = nil
        guarding = false
        guardReady = false
        finished = false
        sentAt = nil
        verifiedAt = nil
        toCheck = false
        badSettings = nil
        existingRequest = false
        existingToday = false
        manualConfirm = false
        pendingSeen = false
        todayPendingShown = false
        listSince = nil
        // La demande d'avant est bien dans la liste : sans ça, Zieuton bloquerait sur « une demande est déjà en cours ».
        allowSecond = true
        proof.reset()
        lastSummary = ""
        index = 0
        pickedAt = -1
        warning = nil
        seenScreen = .distantPast
        lostCheckFrom = Date()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        webView.load(URLRequest(url: url))
        showStep()
    }

    /// Textes du compte verrouillé, suspendu ou désactivé (formulation neutre validée par Victor le 16 novembre).
    private var lockText: (title: String, text: String) {
        switch lockKind {
        case "suspended": return ("Instagram a suspendu ton compte",
                                  "Zieuton ne peut rien y changer. Ouvre l'application Instagram officielle pour voir ce qu'Instagram te propose.")
        case "disabled": return ("Instagram a désactivé ton compte",
                                 "Zieuton ne peut rien y changer. Ouvre l'application Instagram officielle pour voir ce qu'Instagram te propose.")
        default: return ("Instagram a verrouillé ton compte par sécurité",
                         "Zieuton ne peut pas le débloquer. Ouvre l'application Instagram officielle pour suivre les étapes de récupération.")
        }
    }

    /// FOU-121 : compte verrouillé par Instagram. Le parcours s'arrête net : plus de consigne, plus de cercle, plus de guet.
    /// Zieuton ne lit, ne demande et ne touche aucun code ni aucun choix de récupération : il renvoie vers l'app Instagram officielle.
    private func showLocked() {
        guard !lockedShown else { return }
        lockedShown = true
        guardTimer?.invalidate(); guardTimer = nil
        warning = nil
        if !loginAlert.isEmpty { loginAlert.forEach { $0.removeFromSuperview() }; loginAlert = [] }
        hideRing()
        showStep()

        let veil = UIView()
        veil.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        let card = UIView()
        card.backgroundColor = Self.sheetBg
        card.layer.cornerRadius = 28
        card.layer.cornerCurve = .continuous
        card.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]

        let face = UIImageView(image: avatar.image)
        face.layer.cornerRadius = 13
        face.layer.cornerCurve = .continuous
        face.clipsToBounds = true
        face.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([face.widthAnchor.constraint(equalToConstant: 50), face.heightAnchor.constraint(equalToConstant: 50)])
        let tag = UILabel()
        tag.text = "🔒  EXPORT EN PAUSE"
        tag.font = .systemFont(ofSize: 13, weight: .heavy)
        tag.textColor = Self.alarm
        let head = UIStackView(arrangedSubviews: [face, tag])
        head.spacing = 12
        head.alignment = .center
        let title = UILabel()
        title.text = lockText.title
        title.font = Self.rounded(23, .heavy)
        title.textColor = Self.ink
        title.numberOfLines = 0
        let body = UILabel()
        body.text = lockText.text
        body.font = Self.rounded(16, .regular)
        body.textColor = Self.ink.withAlphaComponent(0.8)
        body.numberOfLines = 0
        let safe = PaddedLabel()
        safe.text = "Ne donne jamais un code reçu à quelqu'un. Zieuton ne te le demandera jamais."
        safe.font = Self.rounded(14, .bold)
        safe.textColor = Self.alarm
        safe.numberOfLines = 0
        safe.backgroundColor = Self.alarm.withAlphaComponent(0.1)
        safe.layer.cornerRadius = 12
        safe.clipsToBounds = true

        var openConfig = UIButton.Configuration.filled()
        openConfig.title = "Ouvrir l'app Instagram"
        openConfig.baseBackgroundColor = Self.ink
        openConfig.baseForegroundColor = .white
        openConfig.cornerStyle = .large
        openConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { a in
            var a = a; a.font = MetaViewController.rounded(17, .bold); return a
        }
        let open = UIButton(configuration: openConfig, primaryAction: UIAction { _ in
            // L'app Instagram si elle est installée, sinon sa page sur l'App Store.
            guard let app = URL(string: "instagram://app"), let store = URL(string: "https://apps.apple.com/app/instagram/id389801252") else { return }
            UIApplication.shared.open(app) { ok in if !ok { UIApplication.shared.open(store) } }
        })
        open.translatesAutoresizingMaskIntoConstraints = false
        open.heightAnchor.constraint(equalToConstant: 52).isActive = true
        var laterConfig = UIButton.Configuration.plain()
        laterConfig.title = "Fermer, je reviendrai plus tard"
        laterConfig.baseForegroundColor = Self.ink
        laterConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { a in
            var a = a; a.font = MetaViewController.rounded(16, .semibold); return a
        }
        let later = UIButton(configuration: laterConfig, primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) })

        let all = UIStackView(arrangedSubviews: [head, title, body, safe, open, later])
        all.axis = .vertical
        all.spacing = 12
        all.setCustomSpacing(16, after: safe)
        all.setCustomSpacing(4, after: open)
        all.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(all)
        for v in [veil, card] { v.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(v) }
        NSLayoutConstraint.activate([
            veil.topAnchor.constraint(equalTo: view.topAnchor),
            veil.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            veil.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            veil.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            all.topAnchor.constraint(equalTo: card.topAnchor, constant: 22),
            all.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            all.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            all.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
        ])
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        UIAccessibility.post(notification: .screenChanged, argument: title)
    }

    /// « Demande à vérifier » : l'utilisateur confirme lui-même que la nouvelle ligne est sa demande (jamais sur une simple touche).
    private func askConfirmRequest() {
        guard presentedViewController == nil else { return }
        let alert = UIAlertController(title: "Cette ligne est-elle ta demande ?",
                                      message: "Confirme seulement si la nouvelle ligne « En attente » est datée d'aujourd'hui. Dans le doute, regarde encore la liste.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Pas sûr, je regarde encore", style: .cancel))
        alert.addAction(UIAlertAction(title: "Oui, c'est ma demande", style: .default) { [weak self] _ in
            guard let self, self.requesting, !self.finished, self.toCheck || self.todayPendingShown else { return }
            if self.sentAt == nil { self.sentAt = Date() }
            self.toCheck = false
            // Vidéo du 18 nov. (principe 2) : confirmée à la main, pas par une preuve. Textes « une demande d'aujourd'hui est en cours »,
            // jamais « C'est demandé ». Le réglage de la demande est quand même vérifié.
            self.manualConfirm = true
            self.existingRequest = true
            self.existingToday = true
            self.finishRequest()
        })
        present(alert, animated: true)
    }

    /// « Créer une exportation » retouché alors que la demande d'avant n'est pas confirmée : risque de doublon.
    /// Zieuton ne bloque pas Instagram (c'est le choix de l'utilisateur) : il prévient, et propose de revoir la liste d'abord.
    private func warnDuplicate() {
        guard presentedViewController == nil else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        let alert = UIAlertController(title: "Attention au doublon",
                                      message: "Ta demande d'avant est peut-être déjà enregistrée chez Instagram. Regarde d'abord la liste : une ligne « En attente » d'aujourd'hui, c'est bon, ne refais rien.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Revoir la liste", style: .cancel) { [weak self] _ in
            guard let self else { return }
            self.index = 0
            self.pickedAt = -1
            self.seenScreen = .distantPast
            self.webView.load(URLRequest(url: self.url))
            self.showStep()
        })
        alert.addAction(UIAlertAction(title: "Refaire quand même", style: .destructive))
        present(alert, animated: true)
    }

    /// La demande est vue dans la liste d'Instagram (ou une demande était déjà en cours) : on guette le fichier.
    private func finishRequest() {
        guard !finished else { return }
        finished = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let done = onRequested
        // Partie avec « Année dernière », HTML ou toutes les informations : on le dit, sans la refaire à sa place.
        if !existingRequest || manualConfirm { badSettings = ExportProof.problem(lastSummary) }
        sayLabel.attributedText = NSAttributedString(string: existingToday ? "Une demande d'aujourd'hui est en cours chez Instagram."
                                                        : existingRequest ? "Une demande est déjà en cours chez Instagram."
                                                        : "C'est confirmé ! Instagram prépare ta liste.",
                                                     attributes: [.font: Self.rounded(18, .heavy), .foregroundColor: Self.ink])
        tipLabel.text = "Tu n'as plus rien à faire ici."
        // La page passe tout de suite sur « Instagram prépare ta liste », derrière : pas d'ancien écran au retour.
        done?(existingRequest, existingToday)
        // Au lieu de fermer, on reste sur la page d'Instagram et on guette le fichier (FOU-100).
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            self?.startGuarding()
        }
    }

    private func startGuarding() {
        guard !guarding, !downloading else { return }
        guarding = true
        guardSince = Date()
        showStep()
        webView.load(URLRequest(url: ExportWatcher.exportURL))
        guardTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in self?.guardTick() }
    }

    private func guardTick() {
        guard guarding, !guardReady, !downloading else { return }
        if Date().timeIntervalSince(guardSince) > Self.guardFor {
            guardTimer?.invalidate(); guardTimer = nil
            showStep()
            return
        }
        // Zieuton en arrière-plan : rien à recharger, la notification de secours s'en occupe.
        guard UIApplication.shared.applicationState == .active, !webView.isLoading else { return }
        webView.load(URLRequest(url: ExportWatcher.exportURL))
    }

    private func guardIsReady() {
        guardReady = true
        guardTimer?.invalidate(); guardTimer = nil
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        ExportWatcher.shared.seenReady()
        showStep()
    }

    private func failed(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// EXPORT-PROOF:BEGIN
/// FOU-121 : preuve qu'une demande d'export est bien enregistrée chez Instagram.
/// Avant la demande, on note les lignes « En attente » de la liste des exports d'Instagram (combien, et combien datées d'aujourd'hui).
/// Après la demande, trois cas :
/// - confirmée : la touche « Commencer l'exportation » a été vue ET une ligne de plus est là ET elle est datée d'aujourd'hui
///   (ou « à l'instant », « il y a 2 min »…) ;
/// - à vérifier : une ligne de plus, mais sans touche vue ou sans date récente. Ça peut être une ancienne demande
///   qui s'affiche en retard : c'est l'utilisateur qui regarde et décide, Zieuton ne conclut pas à sa place ;
/// - rien : pas de ligne de plus. Ce n'est jamais un échec : la ligne peut arriver plus tard.
struct ExportProof: Equatable {
    /// Le plus grand nombre de lignes « En attente » vu sur l'accueil avant la demande (nil : liste jamais vue).
    private(set) var before: Int?
    /// Parmi elles, le plus grand nombre de lignes datées d'aujourd'hui.
    private(set) var recentBefore = 0
    /// Figée dès l'arrivée sur le résumé : la nouvelle ligne ne doit jamais devenir la référence.
    private(set) var frozen = false

    enum Verdict: Equatable { case none, confirmed, toCheck }

    /// L'accueil de l'export montre ces lignes « En attente » (texte de chaque ligne, en minuscules).
    /// On garde les plus grands nombres vus : la liste peut s'afficher en plusieurs fois.
    mutating func saw(_ rows: [String], now: Date, calendar: Calendar = .current) {
        guard !frozen else { return }
        before = max(before ?? 0, rows.count)
        recentBefore = max(recentBefore, rows.filter { Self.isRecent($0, now: now, calendar: calendar) }.count)
    }

    /// Le résumé (« Commencer l'exportation ») est atteint : la référence ne bouge plus.
    mutating func freeze() {
        if before != nil { frozen = true }
    }

    mutating func reset() { self = ExportProof() }

    /// Une demande était déjà en cours avant de commencer (et on n'a pas encore commencé).
    var alreadyPending: Bool { !frozen && (before ?? 0) > 0 }
    /// Tests iPhone du 17 nov. : cette demande « déjà en cours » est datée d'aujourd'hui. C'est peut-être celle que
    /// l'utilisateur vient de faire, vue en retard, mais une date ne le prouve pas (relecture ChatGPT du 18 nov.) :
    /// on dit « une demande d'aujourd'hui est en cours », jamais « ta demande » ni « une demande était déjà en cours ».
    var pendingToday: Bool { alreadyPending && recentBefore > 0 }

    /// Vidéo du 18 nov. : sur la liste des exports (« home », ou lignes lues à l'instant), une touche qui n'est pas celle de l'étape
    /// (onglet « Activité passée », une carte, faire défiler) n'est jamais un « mauvais bouton » : on y vient pour regarder.
    static func listIsCalm(screen: String, rowsShown: Bool) -> Bool { screen == "home" || rowsShown }

    /// Ce que prouve la liste lue maintenant. `tapped` : la touche « Commencer l'exportation » a été vue.
    func verdict(_ rows: [String]?, tapped: Bool, now: Date, calendar: Calendar = .current) -> Verdict {
        guard frozen, let before, let rows, rows.count > before else { return .none }
        let recent = rows.filter { Self.isRecent($0, now: now, calendar: calendar) }.count
        return tapped && recent > recentBefore ? .confirmed : .toCheck
    }

    /// La ligne dit qu'elle date d'aujourd'hui : « à l'instant », « il y a 3 min », « aujourd'hui », « 16 novembre », « nov 16 », « 16/11 »…
    /// Une autre année écrite en toutes lettres (« 16 novembre 2025 ») la rend ancienne.
    static func isRecent(_ row: String, now: Date, calendar: Calendar = .current) -> Bool {
        isDated(row, day: now, now: now, calendar: calendar)
    }

    /// FOU-126 : la ligne est datée du jour `day` (la date écrite, ou « aujourd'hui », « il y a 3 min », « hier » lus à l'heure `now`).
    /// Une autre année écrite en toutes lettres la rend étrangère à ce jour.
    static func isDated(_ row: String, day date: Date, now: Date, calendar: Calendar = .current) -> Bool {
        let t = row.lowercased().replacingOccurrences(of: "\u{00a0}", with: " ").replacingOccurrences(of: "’", with: "'")
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = c.year, let month = c.month, let day = c.day else { return false }
        // Une année écrite qui n'est pas celle de ce jour : ancienne ligne.
        for y in matches(t, "(?<![0-9])(?:19|20)[0-9]{2}(?![0-9])") where Int(y) != year { return false }
        // Mots relatifs : ils parlent du jour où la liste est lue (`now`), pas forcément du jour cherché.
        let today = calendar.isDate(date, inSameDayAs: now)
        if has(t, "à l'instant|a l'instant|just now|aujourd'hui|today") { return today }
        if has(t, "(?<![\\p{L}])(?:hier|yesterday)(?![\\p{L}])") {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else { return false }
            return calendar.isDate(date, inSameDayAs: yesterday)
        }
        // « il y a 3 min », « il y a 40 s », « 3 min ago », « 2m ago » : 30 minutes au plus.
        for n in matches(t, "il y a ([0-9]+) ?(?:s|sec|secondes?|min|minutes?)(?![\\p{L}])", group: 1)
            + matches(t, "(?<![0-9])([0-9]+) ?(?:s|sec|seconds?|m|min|mins|minutes?) ago", group: 1)
            where (Int(n) ?? 99) <= 30 { return today }
        let fr = ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre"]
        let frShort = ["janv", "févr", "mars", "avr", "mai", "juin", "juil", "août", "sept", "oct", "nov", "déc"]
        let en = ["january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december"]
        let enShort = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        var names = [fr[month - 1], frShort[month - 1], en[month - 1], enShort[month - 1]]
        if month == 9 { names.append("sept") }
        let m = "(?:" + Set(names).sorted().joined(separator: "|") + ")"
        let d = "0?\(day)"
        // « 16 novembre », « 1er nov. », « 16 nov 2026 » / « november 16 », « nov. 16th »
        if has(t, "(?<![0-9])\(d)(?:er|st|nd|rd|th)? (?:de )?\(m)\\.?(?![\\p{L}])") { return true }
        if has(t, "(?<![\\p{L}])\(m)\\.? \(d)(?:st|nd|rd|th)?(?![0-9])") { return true }
        // « 16/11 », « 16/11/2026 », « 2026-11-16 »
        if has(t, "(?<![0-9])\(d)/0?\(month)(?![0-9])") { return true }
        if has(t, "\(year)-\(String(format: "%02d", month))-\(String(format: "%02d", day))") { return true }
        return false
    }

    private static func has(_ text: String, _ pattern: String) -> Bool { !matches(text, pattern).isEmpty }

    private static func matches(_ text: String, _ pattern: String, group: Int = 0) -> [String] {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return re.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap {
            let r = $0.range(at: group)
            return r.location == NSNotFound ? nil : ns.substring(with: r)
        }
    }

    /// Toucher le bandeau en « à vérifier » ouvre une confirmation, jamais une validation directe.
    enum BannerTap: Equatable { case askConfirm, other }
    static func bannerTap(requesting: Bool, finished: Bool, toCheck: Bool) -> BannerTap {
        requesting && !finished && toCheck ? .askConfirm : .other
    }

    /// Retoucher « Créer une exportation » risque un doublon : demande touchée mais pas confirmée, ou ligne « à vérifier ».
    static func duplicateRisk(tappedStart: Bool, toCheck: Bool, finished: Bool) -> Bool {
        !finished && (tappedStart || toCheck)
    }

    /// Ce que le bandeau dit si la demande est partie avec un mauvais réglage (dernier résumé lu avant la demande).
    struct Problem: Equatable { let title: String; let text: String }
    static func problem(_ summary: String) -> Problem? {
        switch summary {
        case "summary:info": return Problem(title: "avec trop d'informations",
                                            text: "Instagram prépare plus que tes abonnés : ce sera plus long, et le fichier plus gros.")
        case "summary:period": return Problem(title: "avec « Année dernière »",
                                              text: "Il manquera tes plus anciens abonnés.")
        case "summary:format": return Problem(title: "en HTML",
                                              text: "Zieuton ne lit que le JSON : ce fichier ne pourra pas être importé.")
        default: return nil
        }
    }
}
/// FOU-121 P5 (R2) : les cases de « Personnaliser les informations », vues au fil du défilement.
/// Instagram peut retirer de la page les lignes sorties de l'écran : on garde le dernier état vu de chaque ligne.
/// Une case ne change que si on la touche, donc quand elle est visible : son dernier état vu est le bon.
struct PickMemory: Equatable {
    private(set) var rows: [String: Bool] = [:]

    static func isFollowers(_ name: String) -> Bool {
        let n = name.lowercased().replacingOccurrences(of: "’", with: "'")
        return n.contains("followers et suivi") || n.contains("followers and following")
    }

    mutating func saw(_ list: [(String, Bool)]) {
        for (name, on) in list {
            let key = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty { rows[key] = on }
        }
    }

    var checked: Int { rows.values.filter { $0 }.count }

    /// Relecture ChatGPT (P5) : nouvelle visite = retour à l'accueil de l'export (nouvelle demande, cases remises par défaut).
    /// Un délai, un chargement ou un écran pas reconnu ne remettent jamais la mémoire à zéro.
    static func resets(onScreen screen: String) -> Bool { screen == "home" }

    /// « ✓ Tout est bien réglé » seulement si le résumé nomme « Followers et suivi(e)s » seule, ou dit « 1 élément »
    /// alors que Zieuton a vu « Followers et suivi(e)s » cochée et aucune autre case. « 1 élément » seul ne prouve rien.
    static func settingsVerified(summaryInfo: String, followersAlone: Bool) -> Bool {
        summaryInfo == "followers" || (summaryInfo == "one" && followersAlone)
    }
    var followers: Bool { rows.contains { Self.isFollowers($0.key) && $0.value } }
    /// Première case cochée en trop (ordre alphabétique, pour un affichage stable).
    var extra: String? { rows.filter { $0.value && !Self.isFollowers($0.key) }.keys.sorted().first }
}

/// FOU-121 P4 : couleur du bandeau (maquettes v2).
enum BannerTone: Equatable {
    case consigne, success, fix, souci, pause

    /// Déduite du texte du bandeau : « Petit souci : » et « Oups : » = petit souci ; une alerte de mauvais bouton ou un réglage
    /// à refaire = réglage à corriger ; « Je ne reconnais pas encore » = pause ; « Parfait ! », « C'est prêt ! » = réussite.
    static func of(verb: String, isWarning: Bool) -> BannerTone {
        if isWarning { return .fix }
        if verb.hasPrefix("Petit souci") || verb.hasPrefix("Oups") { return .souci }
        if verb.hasPrefix("Demande enregistrée, mais") || verb.hasPrefix("Export en pause") { return .fix }
        if verb.hasPrefix("Je ne reconnais pas") { return .pause }
        if verb.hasPrefix("Parfait") || verb.hasPrefix("C'est prêt") || verb.hasPrefix("✓") { return .success }
        return .consigne
    }
}

/// FOU-124 : après une demande VÉRIFIÉE, on dit clairement que tout est fait chez Instagram et comment revenir.
/// Test réel : l'utilisateur restait sur Instagram sans voir « ‹ Zieuton » en haut à gauche.
enum LeaveHint {
    static func verb(existing: Bool, today: Bool = false) -> String {
        // 18 nov. (Victor) : bandeau court, compris d'un coup d'œil. Le bouton « Revenir dans Zieuton » est juste dessous.
        // Bandeau centré : la situation est le titre en gros (title), cette petite ligne au-dessus dit qu'il n'y a plus rien à faire.
        "✓ Rien d'autre à faire ici"
    }
    /// La situation, en gros au milieu du bandeau.
    static func title(existing: Bool, today: Bool = false) -> String {
        if existing && today { return "Demande du jour en cours" }
        return existing ? "Demande déjà en cours" : "C'est demandé"
    }
    static let tip = "Instagram prépare ton fichier. Tu peux revenir dans Zieuton."

    /// Le bouton « Revenir dans Zieuton » : seulement pendant le guet d'une demande vérifiée, fichier pas encore prêt,
    /// sans réglage à corriger, sans page en panne, sans téléchargement en cours.
    /// unsure (vidéo du 18 nov.) : liste visible, preuve incertaine. On peut sortir, rien n'est confirmé pour autant.
    static func showsButton(guarding: Bool, ready: Bool, badSettings: Bool, pageProblem: Bool, downloading: Bool, unsure: Bool = false) -> Bool {
        (guarding || unsure) && !ready && !badSettings && !pageProblem && !downloading
    }

    /// Relecture ChatGPT (18 nov., 14 h 09) : Instagram est fermé sans preuve automatique, mais avec un signe de demande
    /// (« Commencer » touché, ligne à vérifier, ligne « En attente » du jour vue). La page de Zieuton passe alors directement
    /// sur l'attente « Demande à vérifier », jamais sur « Zieuton en haut, Instagram en bas » (plus de boucle).
    /// Sans aucun signe de demande, rien n'est noté : rien n'a été demandé.
    static func leftUnsure(requesting: Bool, finished: Bool, tapped: Bool, toCheck: Bool, todayShown: Bool, pendingSeen: Bool) -> Bool {
        requesting && !finished && (tapped || toCheck || todayShown || pendingSeen)
    }
}

/// FOU-121 P4 : les 4 grandes phases du bandeau, au lieu de « étape 4 sur 9 ».
enum BannerPhases {
    static let names = ["Connexion", "Réglages", "Demande", "Fichier"]

    /// file : on récupère ou on guette le fichier ; requested : « Commencer l'exportation » touché (ou demande à vérifier).
    static func current(login: Bool, code: Bool, finalStep: Bool, requested: Bool, file: Bool) -> Int {
        if login || code { return 0 }
        if file { return 3 }
        if requested || finalStep { return 2 }
        return 1
    }

    /// Ce qui peut arriver pendant qu'une alerte de mauvais choix est affichée.
    enum WarningEvent { case lostChanged, codeChanged }

    /// Relecture ChatGPT (P4) : un écran pas reconnu (chargement, nouvelle interface) ne retire jamais l'alerte.
    /// Un code de sécurité d'Instagram, si : c'est une autre étape (Connexion), l'ancienne alerte n'a plus de sens.
    static func clearsWarning(_ event: WarningEvent) -> Bool {
        switch event {
        case .lostChanged: return false
        case .codeChanged: return true
        }
    }

    /// Relecture ChatGPT (P4) : l'alerte « pas le bon compte » vibre une fois en arrivant sur l'écran, jamais en boucle.
    static func shouldWarnWrongProfile(onScreen: Bool, alreadyWarned: Bool) -> Bool {
        onScreen && !alreadyWarned
    }

    /// Une alerte ne part jamais au bout d'un délai (C12). Elle part toute seule seulement si la page a quitté l'écran
    /// de l'étape (mauvais bouton) puis y est revenue. Sinon : bonne touche, ou l'utilisateur touche le bandeau.
    static func warningCleared(leftStepScreen: Bool, backOnStepScreen: Bool) -> Bool {
        leftStepScreen && backOnStepScreen
    }
}

/// FOU-121 P2 : aide à la connexion, sans jamais lire ce que l'utilisateur tape.
struct LoginHelp: Equatable {
    /// Nombre de fois où Instagram a affiché « mot de passe incorrect » (une apparition = un refus).
    private(set) var badPasswords = 0
    private var showing = false

    mutating func saw(badPassword: Bool) {
        if badPassword, !showing { badPasswords += 1 }
        showing = badPassword
    }

    /// Au 2e refus, on conseille « Mot de passe oublié ? » plutôt que de réessayer (évite un blocage du compte).
    var manyBadPasswords: Bool { badPasswords >= 2 }

    enum LoadFailure: Equatable { case none, network, other }

    /// Pourquoi la page n'a pas chargé ? « network » seulement pour une vraie erreur de réseau (relecture ChatGPT) :
    /// toute autre erreur reçoit un message neutre, sans parler de Wi-Fi.
    static func loadFailure(domain: String, code: Int) -> LoadFailure {
        // Navigation annulée (nouvelle page) ou remplacée par un téléchargement / un module : pas une panne.
        if domain == NSURLErrorDomain && code == NSURLErrorCancelled { return .none }
        if domain == "WebKitErrorDomain" && (code == 102 || code == 204) { return .none }
        let network: Set<Int> = [NSURLErrorNotConnectedToInternet, NSURLErrorTimedOut, NSURLErrorNetworkConnectionLost,
                                 NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost, NSURLErrorDNSLookupFailed,
                                 NSURLErrorInternationalRoamingOff, NSURLErrorDataNotAllowed, NSURLErrorCallIsActive]
        if domain == NSURLErrorDomain && network.contains(code) { return .network }
        return .other
    }

    /// Au-delà de 90 s sans fin, le téléchargement est considéré comme bloqué (un export de suivis pèse quelques Ko).
    static let downloadLimit: TimeInterval = 90

    static func downloadStuck(since: Date, now: Date) -> Bool {
        now.timeIntervalSince(since) > downloadLimit
    }
}
// MARK: FOU-126 : notifications fiables pendant l'attente de l'export

/// Preuve « fichier prêt ». On suit la ligne de la demande prouvée (son jour), jamais un simple nombre de boutons « Télécharger » :
/// un ancien export encore téléchargeable ne doit jamais passer pour le nouveau.
/// - référence : le nombre de lignes prêtes datées du jour de la demande, lu juste après la preuve, pendant que la demande est
///   encore « En attente », et seulement si deux lectures identiques à au moins 2 s d'écart le confirment ;
/// - « prêt » seulement si cette référence existe, que la liste est lue maintenant, et qu'il y a une ligne prête de plus à ce jour ;
/// - sans référence : jamais « prêt » automatique, au mieux « à vérifier » (l'utilisateur regarde la date lui-même) ;
/// - pas de réseau, écran de connexion, liste illisible : « hors ligne », « connexion » ou « inconnu », jamais « prêt ».
struct ReadyProof: Equatable {
    enum Verdict: String, Equatable { case pending, ready, toCheck, unknown, offline, login }

    /// Un jour de la demande (n'importe quelle heure de ce jour). nil : pas encore connu (demande déjà en cours, pas encore lue).
    private(set) var day: Date?
    /// Lignes prêtes qui ressemblent à la demande (même jour possible, même empreinte), vues au moment de la preuve.
    /// nil : référence pas (encore) vérifiée.
    private(set) var baseline: Int?
    /// Relecture ChatGPT (18 nov.) : empreinte de la carte de la demande (compte, catégorie, format), sans dates ni boutons.
    /// Un fichier d'un autre compte ou d'une autre catégorie n'est jamais compté. nil : référence d'un ancien build (pas d'empreinte).
    private(set) var signature: String?
    private var candidate: Int?
    private var candidateAt: Date?
    private var candidateSig: String?
    /// Relecture ChatGPT (18 nov.) : « prêt » doit être revu au moins 2 s plus tard. Une carte « En attente » qui disparaît
    /// un instant de la lecture ne suffit jamais.
    private var readySeenAt: Date?
    private(set) var readyStable = false

    /// Deux lectures identiques à au moins 2 s d'écart fixent la référence (et confirment « prêt »).
    static let stableFor: TimeInterval = 2
    /// Une demande d'export vit quelques jours chez Instagram : on ne date pas une demande déjà en cours au-delà.
    static let maxAgeDays = 4

    init(day: Date?, baseline: Int? = nil, signature: String? = nil) {
        self.day = day
        self.baseline = baseline
        self.signature = baseline == nil ? nil : signature
    }

    /// Une lecture de la liste des exports (lignes « En attente » et lignes avec un vrai « Télécharger », texte en minuscules).
    mutating func read(pending: [String], ready: [String], now: Date, calendar: Calendar = .current) {
        // Demande déjà en cours chez Instagram : son jour est celui de la ligne « En attente » la plus récente.
        if day == nil { day = Self.latestDay(of: pending, now: now, calendar: calendar) }
        guard let day else { return }
        guard let baseline else {
            // La demande doit encore être « En attente », et être la SEULE ligne en attente de ce jour : sinon on ne sait pas
            // laquelle suivre, et on ne fixe aucune référence (donc jamais « prêt » automatique).
            let mine = pending.filter { ExportProof.isDated($0, day: day, now: now, calendar: calendar) }
            guard mine.count == 1, let sig = Self.signature(of: mine[0]) else {
                candidate = nil; candidateAt = nil; candidateSig = nil
                return
            }
            let n = ready.filter { Self.matches($0, day: day, signature: sig, now: now, calendar: calendar) }.count
            if let c = candidate, let at = candidateAt, c == n, candidateSig == sig {
                if now.timeIntervalSince(at) >= Self.stableFor { self.baseline = n; signature = sig }
            } else {
                candidate = n
                candidateAt = now
                candidateSig = sig
            }
            return
        }
        // Référence fixée : « prêt » seulement s'il est revu, identique, au moins 2 s plus tard.
        if count(pending: pending, ready: ready, day: day, now: now, calendar: calendar) == (0, baseline + 1) {
            if let at = readySeenAt {
                if now.timeIntervalSince(at) >= Self.stableFor { readyStable = true }
            } else {
                readySeenAt = now
            }
        } else {
            readySeenAt = nil
            readyStable = false
        }
    }

    /// Lignes « En attente » du jour, et lignes prêtes qui peuvent être le fichier de la demande.
    private func count(pending: [String], ready: [String], day: Date, now: Date, calendar: Calendar) -> (Int, Int) {
        let p = pending.filter { ExportProof.isDated($0, day: day, now: now, calendar: calendar) }.count
        let r = ready.filter { Self.matches($0, day: day, signature: signature, now: now, calendar: calendar) }.count
        return (p, r)
    }

    /// Ce que dit la liste lue maintenant. `pending` et `ready` valent nil si la liste n'a pas été lue (pas l'accueil de l'export).
    func verdict(pending: [String]?, ready: [String]?, login: Bool, offline: Bool, now: Date, calendar: Calendar = .current) -> Verdict {
        if offline { return .offline }
        guard let pending, let ready else { return login ? .login : .unknown }
        guard let day else {
            // Jour de la demande inconnu : une ligne prête récente peut être la bonne, mais on ne conclut pas à sa place.
            // Une ligne « Expire le … » est un fichier encore disponible : à vérifier aussi.
            let recent = Self.latestDay(of: ready, now: now, calendar: calendar) != nil || ready.contains { Self.expiry($0, calendar: calendar) != nil }
            return recent ? .toCheck : .unknown
        }
        let (p, r) = count(pending: pending, ready: ready, day: day, now: now, calendar: calendar)
        // La demande encore « En attente » n'est jamais prête, même si un autre fichier vient d'arriver (deux demandes le même jour).
        if p > 0 { return .pending }
        // Relecture ChatGPT (18 nov.) : « prêt » seulement s'il y a EXACTEMENT un fichier de plus que la référence, revu 2 s plus tard.
        // Deux fichiers nouveaux ou plus (un autre export devenu prêt), ou un seul encore pas revu : à vérifier, jamais « prêt ».
        if let baseline, r == baseline + 1, readyStable { return .ready }
        // Plus de ligne « En attente » de ce jour, sans preuve nette (référence absente, ancien fichier expiré ou supprimé,
        // plusieurs fichiers nouveaux) : l'utilisateur vérifie la date lui-même.
        return r > 0 ? .toCheck : .unknown
    }

    /// Mots qui ne disent ni le compte, ni la catégorie, ni le format : dates, statuts, boutons, tailles.
    private static let noise: Set<String> = [
        "en", "attente", "demandée", "demandé", "demande", "le", "la", "requested", "on", "expire", "expires", "moins", "de", "mo", "ko", "go",
        "kb", "mb", "gb", "télécharger", "download", "annuler", "cancel", "pending", "in", "progress", "less", "than", "préparation",
        "preparing", "prête", "prêt", "ready", "aujourd", "hui", "hier", "today", "yesterday", "il", "y", "a", "à", "l", "instant", "just",
        "now", "min", "minutes", "minute", "s", "sec", "secondes", "ago", "er",
        "janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre",
        "janv", "févr", "avr", "juil", "sept", "oct", "nov", "déc", "january", "february", "march", "april", "may", "june", "july",
        "august", "september", "october", "november", "december", "jan", "feb", "mar", "apr", "jun", "jul", "aug", "sep", "dec",
    ]

    /// Empreinte d'une carte : ses mots (compte, catégorie, format), sans dates, statuts ni boutons. nil si trop peu de mots.
    static func signature(of row: String) -> String? {
        let words = Set(row.lowercased().components(separatedBy: CharacterSet.letters.inverted).filter { !$0.isEmpty && !noise.contains($0) })
        guard words.count >= 2 else { return nil }
        return words.sorted().joined(separator: " ")
    }

    /// Une ligne prête qui peut être le fichier de la demande : bon jour possible ET même empreinte (si elle est connue).
    static func matches(_ row: String, day: Date, signature: String?, now: Date, calendar: Calendar = .current) -> Bool {
        guard readyFor(row, day: day, now: now, calendar: calendar) else { return false }
        guard let signature else { return true }
        return Self.signature(of: row) == signature
    }

    /// Instagram garde un fichier prêt 4 jours (« Vous disposerez de 4 jours pour télécharger les fichiers »).
    static let keepDays = 4

    /// Vidéo iPhone du 18 nov. : une ligne prête dit « Expire le 22/11/2026 », jamais le jour de la demande.
    /// La date d'expiration écrite sur la ligne (jour/mois/année en chiffres seulement), nil sinon.
    static func expiry(_ row: String, calendar: Calendar = .current) -> Date? {
        let t = row.lowercased()
        guard let r = t.range(of: "(?:expire le|expires on|expires)\\s+([0-9]{1,2})/([0-9]{1,2})/([0-9]{4})", options: .regularExpression) else { return nil }
        let nums = t[r].split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        guard nums.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: nums[2], month: nums[1], day: nums[0], hour: 12))
    }

    /// Une ligne prête qui PEUT être le fichier de la demande du jour `day` :
    /// - ligne « Expire le … » : le fichier est devenu prêt ce jour-là ou après, donc il expire au plus tôt `day` + 4 jours.
    ///   Un fichier qui expire plus tôt est forcément un ancien export ;
    /// - autre ligne : sa date écrite est celle du jour de la demande (ancienne lecture).
    /// Un ancien fichier du même jour passe aussi ce filtre : c'est la référence (baseline) qui le met de côté.
    static func readyFor(_ row: String, day: Date, now: Date, calendar: Calendar = .current) -> Bool {
        if let exp = expiry(row, calendar: calendar) {
            guard let earliest = calendar.date(byAdding: .day, value: keepDays, to: calendar.startOfDay(for: day)) else { return false }
            return calendar.startOfDay(for: exp) >= earliest
        }
        return ExportProof.isDated(row, day: day, now: now, calendar: calendar)
    }

    /// Le jour le plus récent (aujourd'hui, hier… jusqu'à 4 jours) dont une ligne porte la date.
    static func latestDay(of rows: [String], now: Date, calendar: Calendar = .current) -> Date? {
        for back in 0...maxAgeDays {
            guard let d = calendar.date(byAdding: .day, value: -back, to: now) else { continue }
            if rows.contains(where: { ExportProof.isDated($0, day: d, now: now, calendar: calendar) }) { return d }
        }
        return nil
    }

    /// Pendant une vérification, plusieurs lectures arrivent : on garde la plus parlante.
    static func rank(_ v: Verdict) -> Int {
        switch v {
        case .ready: return 6
        case .pending: return 5
        case .toCheck: return 4
        case .offline: return 3
        case .login: return 2
        case .unknown: return 1
        }
    }
}

/// FOU-126 (tests iPhone du 17 nov.) : ce que dit le bandeau quand on ouvre Instagram pour récupérer le fichier.
/// Un bouton « Télécharger » visible ne suffit jamais : seul le verdict de ReadyProof (la ligne de la demande) compte.
enum GetBanner: Equatable {
    /// Demande prouvée, liste pas encore lue.
    case looking
    /// La ligne de la demande est encore « En attente ».
    case notYet
    /// Pas de preuve dans un sens ou dans l'autre (jour inconnu, liste illisible) : l'utilisateur regarde la date.
    case checkDate
    /// Aucune demande prouvée par Zieuton (par exemple faite dans l'app Instagram) : consigne générale, sans cercle.
    case unproven
    /// La preuve dit « prêt » : « Touche Télécharger », avec le cercle.
    case ready

    static func of(waiting: Bool, proven: Bool, verdict: ReadyProof.Verdict?) -> GetBanner {
        if proven || verdict == .ready { return .ready }
        guard waiting else { return .unproven }
        switch verdict {
        case nil: return .looking
        case .pending?: return .notYet
        case .ready?: return .ready
        case .toCheck?, .unknown?, .offline?, .login?: return .checkDate
        }
    }

    /// « 17/11 »
    static func dayText(_ d: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.day, .month], from: d)
        return String(format: "%02d/%02d", c.day ?? 0, c.month ?? 0)
    }
}

/// Autorisation des notifications, telle que la page la connaît.
enum NotifAuth: String, Equatable { case authorized, denied, notDetermined }

/// Quelles notifications programmer ou retirer. A (« C'est demandé »), B1 et B2 (rappels à 30 min et 24 h), C (« prêt »).
/// Aucune notification « expire » : Zieuton ne connaît pas la date d'expiration d'un fichier Instagram.
struct NoticePlan: Equatable {
    struct Item: Equatable { let id: String; let after: TimeInterval }
    var post: [Item] = []
    /// Retirées (programmées et déjà affichées).
    var cancel: [String] = []

    static let asked = "zy-asked", ready = "zy-ready", remind30 = "zy-reminder", remind24 = "zy-reminder-24h"
    static let reminders: [(id: String, after: TimeInterval)] = [(remind30, 30 * 60), (remind24, 24 * 3600)]
    static var reminderIds: [String] { reminders.map { $0.id } }
    /// Notifications des builds 15 et avant (« sûrement prêt », « expire bientôt »…) : toujours retirées.
    static let legacy = ["zy-likely", "zy-last-day", "zyeuto-export"]
    static var all: [String] { [asked, ready] + reminderIds + legacy }

    /// Met les notifications d'accord avec l'état de l'attente. Appelée à la preuve, quand le fichier est vu prêt,
    /// quand l'autorisation arrive plus tard et à chaque retour dans l'app : le résultat ne crée jamais de doublon.
    /// - askedShown / readyShown : A ou C ont déjà été envoyées pour cette demande.
    static func sync(requestedAt: Date, now: Date, auth: NotifAuth, ready: Bool, askedShown: Bool, readyShown: Bool) -> NoticePlan {
        var plan = NoticePlan()
        if ready {
            // Fichier vu prêt : les rappels n'ont plus de sens, ni « C'est demandé » encore affichée.
            plan.cancel = reminderIds + [asked] + legacy
            if auth == .authorized, !readyShown { plan.post.append(Item(id: Self.ready, after: 1)) }
            return plan
        }
        plan.cancel = legacy
        guard auth == .authorized else { return plan }
        if !askedShown { plan.post.append(Item(id: asked, after: 1)) }
        // Une échéance déjà passée (autorisation donnée tard) est sautée.
        for r in reminders {
            let left = requestedAt.addingTimeInterval(r.after).timeIntervalSince(now)
            if left > 5 { plan.post.append(Item(id: r.id, after: left)) }
        }
        return plan
    }

    /// Fin de l'attente (téléchargement, import réussi, demande refaite ou annulée) : tout est retiré.
    static func end() -> NoticePlan { NoticePlan(post: [], cancel: all) }

    /// Zieuton au premier plan : il vérifie déjà lui-même toutes les 30 s, les rappels B1 et B2 ne s'affichent pas.
    /// A et C s'affichent toujours.
    static func showsInForeground(_ id: String) -> Bool { !reminderIds.contains(id) }

    /// Multicompte : la page dit « plus en attente » (exportState) pour le compte `sender`. L'attente ne s'arrête que si
    /// c'est le compte de la demande. Demande sans compte connu (page ancienne, premier import) : comme avant, elle s'arrête.
    /// Demande d'un compte connu et message sans compte : elle continue (un autre compte ne peut pas annuler les rappels).
    static func endsWait(requestAcct: String?, sender: String?) -> Bool {
        let owner = requestAcct ?? "", from = sender ?? ""
        if owner.isEmpty { return true }
        return from == owner
    }
}

/// Textes des notifications décidés avec Victor (FOU-126). Aucune promesse de surveillance, jamais « prêt » sans preuve.
enum NoticeText {
    struct Text: Equatable { let title: String; let body: String; let subtitle: String? }

    /// hour : heure de la demande (« 14:32 »), nil si elle est inconnue (demande déjà en cours).
    /// today : demande « déjà en cours » datée d'aujourd'hui (peut-être la sienne, sans preuve) : ni « déjà en cours », ni « ta demande », ni heure inventée.
    static func of(_ id: String, existing: Bool, today: Bool = false, hour: String?) -> Text? {
        switch id {
        case NoticePlan.asked:
            if existing && today {
                return Text(title: "Une demande d'aujourd'hui est en cours ✓",
                            body: "Instagram prépare ton fichier. Tu pourras vérifier son état dans Zieuton.", subtitle: nil)
            }
            return Text(title: existing ? "Une demande est déjà en cours ✓" : "C'est demandé ✓",
                        body: "Instagram prépare ton fichier. Tu pourras vérifier son état dans Zieuton.",
                        subtitle: existing ? nil : hour.map { "Demandé à \($0)" })
        case NoticePlan.remind30, NoticePlan.remind24:
            return Text(title: "Des nouvelles de ton export ? 👀",
                        body: "Ouvre Zieuton pour vérifier où en est Instagram.", subtitle: nil)
        case NoticePlan.ready:
            return Text(title: "Ton fichier est prêt 🎉", body: "Touche pour le récupérer dans Zieuton.", subtitle: nil)
        default:
            return nil
        }
    }
}
// EXPORT-PROOF:END

/// Étiquette avec une marge intérieure (le rappel « ne donne jamais un code »).
final class PaddedLabel: UILabel {
    var inset = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
    override func drawText(in rect: CGRect) { super.drawText(in: rect.inset(by: inset)) }
    override var intrinsicContentSize: CGSize {
        let s = super.intrinsicContentSize
        return CGSize(width: s.width + inset.left + inset.right, height: s.height + inset.top + inset.bottom)
    }
    override func textRect(forBounds bounds: CGRect, limitedToNumberOfLines n: Int) -> CGRect {
        let r = super.textRect(forBounds: bounds.inset(by: inset), limitedToNumberOfLines: n)
        return r.inset(by: UIEdgeInsets(top: -inset.top, left: -inset.left, bottom: -inset.bottom, right: -inset.right))
    }
}

/// FOU-118 : la flèche corail qui montre le bouton à toucher (vers le haut si le bouton est au-dessus, vers le bas sinon).
final class PointingArrow: UIView {
    var pointsUp = true
    private static let coral = UIColor(red: 0xef / 255, green: 0x7f / 255, blue: 0x6a / 255, alpha: 1)

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowRadius = 3
        layer.shadowOffset = CGSize(width: 0, height: 1)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) non utilisé") }

    override func draw(_ rect: CGRect) {
        let w = bounds.width, h = bounds.height
        // Flèche pleine, bord blanc : lisible sur une page claire ou assombrie.
        let head = h * 0.48, shaft = w * 0.36
        let p = UIBezierPath()
        p.move(to: CGPoint(x: w / 2, y: 3))
        p.addLine(to: CGPoint(x: w - 3, y: head))
        p.addLine(to: CGPoint(x: (w + shaft) / 2, y: head))
        p.addLine(to: CGPoint(x: (w + shaft) / 2, y: h - 3))
        p.addLine(to: CGPoint(x: (w - shaft) / 2, y: h - 3))
        p.addLine(to: CGPoint(x: (w - shaft) / 2, y: head))
        p.addLine(to: CGPoint(x: 3, y: head))
        p.close()
        p.lineJoinStyle = .round
        if !pointsUp { p.apply(CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: h)) }
        Self.coral.setFill()
        p.fill()
        UIColor.white.setStroke()
        p.lineWidth = 2.5
        p.stroke()
    }
}

extension MetaViewController: WKScriptMessageHandler {
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "zyeutoState", let state = message.body as? [String: Any] {
            received(state: state, mainFrame: message.frameInfo.isMainFrame)
        } else if message.name == "zyeutoTap", let text = message.body as? String {
            tapped(text)
        } else if message.name == "zyeutoRing", let text = message.body as? String {
            ringMoved(text)
        }
    }
}

extension MetaViewController: UIGestureRecognizerDelegate {
    /// Une touche sur un bouton (UIControl) du bandeau va au bouton, pas au geste « toucher le bandeau ».
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var v = touch.view
        while let cur = v, cur !== gestureRecognizer.view {
            if cur is UIControl { return false }
            v = cur.superview
        }
        return true
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
        // Nouvelle page : elle ne sait pas encore quel bouton chercher (FOU-118).
        ringSentJSON = ""
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
        activeDownloads.append(download)
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
        activeDownloads.append(download)
    }

    // FOU-121 P2 : page qui ne charge pas (pas de réseau…) ou qui se ferme : le bandeau le dit au lieu d'une page blanche.
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        if !pageProblem.isEmpty { pageProblem = ""; showStep() }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        loadFailed(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loadFailed(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        pageProblem = "crashed"
        pageKnown = true
        showStep()
    }

    private func loadFailed(_ error: Error) {
        let e = error as NSError
        switch LoginHelp.loadFailure(domain: e.domain, code: e.code) {
        case .none: return
        case .network: pageProblem = "offline"
        case .other: pageProblem = "failed"
        }
        pageKnown = true
        showStep()
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
            self.downloadSince = Date()
            self.downloadStuckShown = false
            self.showStep()
        }
        completionHandler(file)
    }

    func downloadDidFinish(_ download: WKDownload) {
        activeDownloads.removeAll { $0 === download }
        downloadSince = nil
        guard let file = downloads.removeValue(forKey: ObjectIdentifier(download)) else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        ExportWatcher.shared.downloaded()
        let deliver = onFile
        dismiss(animated: true) { deliver?(file) }
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        activeDownloads.removeAll { $0 === download }
        downloads.removeValue(forKey: ObjectIdentifier(download))
        downloadSince = nil
        // Arrêté par l'utilisateur (bandeau « le téléchargement traîne ») : pas de deuxième message.
        let e = error as NSError
        if e.domain == NSURLErrorDomain, e.code == NSURLErrorCancelled { return }
        downloading = false
        showStep(animated: false)
        failed("Le téléchargement n'a pas abouti. Vérifie ta connexion et touche encore « Télécharger ».")
    }
}

// MARK: Notifications de l'export Instagram

/// Suit l'export Instagram après une demande prouvée et prévient par notification (FOU-126) :
/// A « C'est demandé ✓ » à la preuve, B1 et B2 « Des nouvelles de ton export ? » à 30 min et 24 h (annulés dès que l'attente
/// se termine), C « Ton fichier est prêt 🎉 » seulement quand Zieuton voit la ligne de la demande prête (ReadyProof).
///
/// Pour savoir si le fichier est prêt, Zieuton ouvre en cachette la page « Exporter vos informations »
/// (la même session Instagram que dans l'app, jamais le mot de passe) et la lit avec le lecteur de la fenêtre Instagram.
/// Il ne touche rien sur la page : il la lit, c'est tout.
/// Quand Zieuton est ouvert : vérification toutes les 30 s. Fermé ou suspendu, iOS le réveille quand il veut (parfois jamais) :
/// Zieuton ne promet donc jamais de surveiller, les rappels B invitent seulement à ouvrir l'app.
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
        static let requested = "zy.export.requestedAt", ready = "zy.export.readyAt"
        /// La demande était déjà en cours chez Instagram : son heure est inconnue (Key.requested = début du guet, pas la demande).
        static let existing = "zy.export.existing"
        /// Demande déjà en cours, mais datée d'aujourd'hui (tests du 17 nov.).
        static let today = "zy.export.today"
        /// FOU-126 : jour de la demande et référence des lignes prêtes de ce jour (ReadyProof).
        static let day = "zy.export.day", baseline = "zy.export.baseline"
        /// Relecture ChatGPT (18 nov.) : empreinte de la carte de la demande (compte, catégorie, format).
        static let signature = "zy.export.signature"
        /// FOU-126 : « C'est demandé » et « prêt » déjà envoyées pour cette demande (jamais de doublon).
        static let askedShown = "zy.export.askedShown", readyShown = "zy.export.readyShown"
        /// Dernier résultat de vérification, pour la page.
        static let lastState = "zy.export.lastState", lastAt = "zy.export.lastAt"
        /// Compte de la demande (multicompte) : seul ce compte peut dire que l'attente est finie.
        static let acct = "zy.export.acct"
        /// Clés des builds 15 et avant (décompte des « Télécharger ») : plus utilisées.
        static let legacy = ["zy.export.downloadsBefore", "zy.export.baselineChecked"]
        static var all: [String] { [requested, ready, existing, today, day, baseline, signature, askedShown, readyShown, lastState, lastAt, acct] + legacy }
    }
    /// Notification « prêt » avec un bouton « Mettre à jour » (appui long ou glisser vers le bas).
    static let readyCategory = "zy-ready-actions"

    override init() {
        super.init()
        let update = UNNotificationAction(identifier: "zy-update", title: "Mettre à jour maintenant", options: [.foreground],
                                          icon: UNNotificationActionIcon(systemImageName: "arrow.down.circle"))
        UNUserNotificationCenter.current().setNotificationCategories([
            UNNotificationCategory(identifier: Self.readyCategory, actions: [update], intentIdentifiers: [], options: []),
        ])
        let day = store.object(forKey: Key.day) as? Date
        proof = ReadyProof(day: day, baseline: day == nil ? nil : store.object(forKey: Key.baseline) as? Int,
                           signature: store.string(forKey: Key.signature))
    }

    /// « 14:47 »
    static func hour(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.setLocalizedDateFormatFromTemplate("Hm")
        return f.string(from: d)
    }

    /// Vignette du bonhomme (iOS déplace le fichier joint : on en écrit un nouveau à chaque fois).
    private static func mascot() -> UNNotificationAttachment? {
        guard let data = Data(base64Encoded: WebViewController.logoPNG) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("zieuton-\(UUID().uuidString).png")
        guard (try? data.write(to: url)) != nil else { return nil }
        return try? UNNotificationAttachment(identifier: "bonhomme", url: url, options: nil)
    }

    /// Fichier vu prêt : la page passe sur « Ta liste est prête ».
    var onReady: (() -> Void)?
    /// Résultat d'une vérification (pour window.zyeutoWatch).
    var onState: ((String, Date) -> Void)?
    /// État de l'autorisation (pour window.zyeutoNotif).
    var onNotif: ((NotifAuth) -> Void)?
    /// La page sait demander l'autorisation avant Instagram (ZYEUTO_APP 10). Sinon (page plus ancienne), la coque
    /// la demande à la preuve, comme le build 15, pour que « C'est demandé » ne soit jamais perdue.
    var pageAsksPermission = false

    private let store = UserDefaults.standard
    private var requestedAt: Date? { store.object(forKey: Key.requested) as? Date }
    private var readyAt: Date? { store.object(forKey: Key.ready) as? Date }
    /// Une demande est en cours (moins de 4 jours) et le fichier n'a pas encore été vu prêt.
    var isWaiting: Bool {
        guard let r = requestedAt, readyAt == nil else { return false }
        return Date().timeIntervalSince(r) < 4 * 86400
    }
    var isReady: Bool { requestedAt != nil && readyAt != nil }
    /// La demande guettée était déjà en cours chez Instagram : son heure est inconnue.
    private var isExisting: Bool { store.bool(forKey: Key.existing) }

    private var proof = ReadyProof(day: nil)
    /// Jour de la demande guettée (nil : inconnu, par exemple demande déjà en cours pas encore lue).
    var requestDay: Date? { isWaiting || isReady ? proof.day : nil }
    private var timer: Timer?
    private var checker: WKWebView?
    private var checkHandler: CheckHandler?
    private var finishCheck: ((ReadyProof.Verdict) -> Void)?
    private var best: ReadyProof.Verdict?

    // MARK: Étapes

    /// La demande est prouvée chez Instagram (FOU-121 P1). existing : elle était déjà en cours, à une heure inconnue.
    /// Rien n'est envoyé sur le seul toucher de « Commencer l'exportation » : cette fonction n'est appelée qu'après la preuve.
    func requested(existing: Bool = false, today: Bool = false, acct: String? = nil) {
        let now = Date()
        for k in Key.all { store.removeObject(forKey: k) }
        store.set(now, forKey: Key.requested)
        store.set(existing, forKey: Key.existing)
        store.set(existing && today, forKey: Key.today)
        if let acct, !acct.isEmpty { store.set(acct, forKey: Key.acct) }
        // Demande prouvée : sa ligne est datée d'aujourd'hui. Déjà en cours : le jour sera lu sur sa ligne « En attente ».
        proof = ReadyProof(day: existing && !today ? nil : now)
        saveProof()
        apply(NoticePlan.end())
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                guard let self else { return }
                if settings.authorizationStatus == .notDetermined, !self.pageAsksPermission {
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
                        DispatchQueue.main.async { self.syncNotices() }
                    }
                } else {
                    self.syncNotices()
                }
            }
        }
        startTimer()
        scheduleBackgroundCheck()
    }

    /// Le fichier a été téléchargé dans Zieuton : plus rien à guetter.
    func downloaded() { clear() }

    /// La page d'Instagram ouverte dans Zieuton vient de montrer le fichier prêt (preuve ReadyProof).
    func seenReady() { markReady() }

    /// La page dit que l'attente est finie pour le compte `acct` (exportState pending: false).
    /// Ignoré si la demande appartient à un autre compte (NoticePlan.endsWait).
    func pageEndedWait(acct: String?) {
        guard NoticePlan.endsWait(requestAcct: store.string(forKey: Key.acct), sender: acct) else { return }
        clear()
    }

    /// Fin de l'attente (téléchargement, import réussi, demande refaite ou annulée) : tout est retiré.
    func clear() {
        timer?.invalidate(); timer = nil
        guard requestedAt != nil else { return }
        for k in Key.all { store.removeObject(forKey: k) }
        proof = ReadyProof(day: nil)
        apply(NoticePlan.end())
        UNUserNotificationCenter.current().setBadgeCount(0, withCompletionHandler: nil)
    }

    private func markReady() {
        guard isWaiting else { return }
        let now = Date()
        store.set(now, forKey: Key.ready)
        timer?.invalidate(); timer = nil
        report(.ready, at: now)
        syncNotices()
        onReady?()
    }

    // MARK: Notifications

    /// Autorisation actuelle, sur le fil principal.
    func authorization(_ done: @escaping (NotifAuth) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let auth: NotifAuth
            switch settings.authorizationStatus {
            case .notDetermined: auth = .notDetermined
            case .denied: auth = .denied
            default: auth = .authorized // autorisée, provisoire ou éphémère : les notifications peuvent s'afficher.
            }
            DispatchQueue.main.async { done(auth) }
        }
    }

    /// La page demande l'autorisation (écran « Je te préviens ? » ou carte « Activer ») : vraie demande iOS, puis tout est remis d'accord.
    func askPermission() {
        pageAsksPermission = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.syncNotices() }
        }
    }

    /// Met les notifications d'accord avec l'attente (sans doublon) et donne l'autorisation à la page.
    /// Rattrapage : autorisation donnée plus tard → A une seule fois, B1/B2 si leur échéance n'est pas passée, C si déjà vu prêt.
    func syncNotices() {
        authorization { [weak self] auth in
            guard let self else { return }
            self.onNotif?(auth)
            guard let r = self.requestedAt, self.isWaiting || self.isReady else { return }
            self.apply(NoticePlan.sync(requestedAt: r, now: Date(), auth: auth, ready: self.isReady,
                                       askedShown: self.store.bool(forKey: Key.askedShown),
                                       readyShown: self.store.bool(forKey: Key.readyShown)))
        }
    }

    private func apply(_ plan: NoticePlan) {
        let center = UNUserNotificationCenter.current()
        if !plan.cancel.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: plan.cancel)
            center.removeDeliveredNotifications(withIdentifiers: plan.cancel)
        }
        for item in plan.post {
            let hour = isExisting ? nil : requestedAt.map { Self.hour($0) }
            guard let text = NoticeText.of(item.id, existing: isExisting, today: store.bool(forKey: Key.today), hour: hour) else { continue }
            if item.id == NoticePlan.asked { store.set(true, forKey: Key.askedShown) }
            if item.id == NoticePlan.ready { store.set(true, forKey: Key.readyShown) }
            let ready = item.id == NoticePlan.ready
            notify(item.id, text, after: item.after, badge: ready, category: ready ? Self.readyCategory : nil)
        }
    }

    private func notify(_ id: String, _ text: NoticeText.Text, after seconds: TimeInterval, badge: Bool, category: String?) {
        let content = UNMutableNotificationContent()
        content.title = text.title
        content.body = text.body
        if let subtitle = text.subtitle { content.subtitle = subtitle }
        content.sound = .default
        content.threadIdentifier = "zyeuto-export"
        if badge { content.badge = 1 }
        if let category { content.categoryIdentifier = category }
        // Le bonhomme de Zieuton en vignette, à droite de la notification.
        if let attachment = Self.mascot() { content.attachments = [attachment] }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger)) { error in
            if let error { NSLog("Zieuton : notification %@ refusée par iOS : %@", id, error.localizedDescription) }
        }
    }

    // MARK: Ce que la page affiche (window.zyeutoWatch)

    private func report(_ verdict: ReadyProof.Verdict, at date: Date = Date()) {
        store.set(verdict.rawValue, forKey: Key.lastState)
        store.set(date, forKey: Key.lastAt)
        onState?(verdict.rawValue, date)
    }

    /// Redonne à la page le dernier état connu (au démarrage de la page, au retour dans l'app).
    func sendLastState() {
        if isReady, let r = readyAt { onState?(ReadyProof.Verdict.ready.rawValue, r); return }
        guard isWaiting, let s = store.string(forKey: Key.lastState), let at = store.object(forKey: Key.lastAt) as? Date else { return }
        onState?(s, at)
    }

    // MARK: Lecture de la liste des exports

    private func saveProof() {
        if let d = proof.day { store.set(d, forKey: Key.day) } else { store.removeObject(forKey: Key.day) }
        if let b = proof.baseline { store.set(b, forKey: Key.baseline) } else { store.removeObject(forKey: Key.baseline) }
        if let sig = proof.signature { store.set(sig, forKey: Key.signature) } else { store.removeObject(forKey: Key.signature) }
    }

    /// Une lecture de la liste des exports d'Instagram (fenêtre Instagram de Zieuton ou vérification cachée).
    /// pending / ready : nil si la liste n'est pas lisible (pas l'accueil de l'export).
    @discardableResult
    func observe(pending: [String]?, ready: [String]?, login: Bool, now: Date = Date()) -> ReadyProof.Verdict {
        guard isWaiting else { return isReady ? .ready : .unknown }
        if let pending, let ready {
            let before = proof
            proof.read(pending: pending, ready: ready, now: now)
            if proof.day != before.day || proof.baseline != before.baseline { saveProof() }
        }
        return proof.verdict(pending: pending, ready: ready, login: login, offline: false, now: now)
    }

    // MARK: Vérifications (Zieuton ouvert)

    /// Zieuton revient au premier plan : on vérifie tout de suite, puis toutes les 30 s.
    func appBecameActive() {
        UNUserNotificationCenter.current().setBadgeCount(0, withCompletionHandler: nil)
        syncNotices()
        sendLastState()
        guard isWaiting else { return }
        startTimer()
        tick()
    }

    /// La page demande une vérification tout de suite (« Regarder si c'est prêt »).
    func checkNow() {
        guard isWaiting, UIApplication.shared.applicationState == .active,
              WebViewController.current?.presentedViewController == nil else { return }
        check { }
    }

    private func startTimer() {
        guard timer == nil, isWaiting else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in self?.tick() }
    }

    private func tick() {
        guard isWaiting else { timer?.invalidate(); timer = nil; return }
        guard UIApplication.shared.applicationState == .active, let r = requestedAt else { return }
        // La page d'Instagram est déjà ouverte dans Zieuton et la guette elle-même : pas de seconde vérification cachée.
        guard WebViewController.current?.presentedViewController == nil else { return }
        // Pas avant 30 s : la page d'Instagram doit avoir enregistré la demande.
        guard Date().timeIntervalSince(r) > 30 else { return }
        check { }
    }

    /// Ouvre la page des exports d'Instagram en cachette et la lit avec le même lecteur que la fenêtre Instagram.
    /// Elle ne touche rien. Sans fenêtre (iOS a relancé Zieuton sans écran), pas de page cachée : résultat « inconnu ».
    private func check(_ done: @escaping () -> Void) {
        guard checker == nil, isWaiting else { done(); return }
        guard let window = WebViewController.current?.view.window else { report(.unknown); done(); return }
        best = nil
        let handler = CheckHandler(self)
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let content = WKUserContentController()
        content.addUserScript(WKUserScript(source: MetaViewController.checkerScript(), injectionTime: .atDocumentEnd, forMainFrameOnly: false))
        for name in CheckHandler.names { content.add(handler, name: name) }
        config.userContentController = content
        let web = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 1400), configuration: config)
        web.isUserInteractionEnabled = false
        web.navigationDelegate = handler
        // Placée derrière l'écran de Zieuton (invisible) : la page d'Instagram s'affiche normalement.
        window.insertSubview(web, at: 0)
        checker = web
        checkHandler = handler
        finishCheck = { [weak self] verdict in
            guard let self else { return }
            self.checker?.stopLoading()
            self.checker?.navigationDelegate = nil
            self.checker?.removeFromSuperview()
            for name in CheckHandler.names { self.checker?.configuration.userContentController.removeScriptMessageHandler(forName: name) }
            self.checker = nil
            self.checkHandler = nil
            self.finishCheck = nil
            if verdict == .ready { self.markReady() } else { self.report(verdict) }
            done()
        }
        web.load(URLRequest(url: Self.exportURL))
        // La page met quelques secondes à afficher la liste : on conclut au bout de 12 s.
        DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in self?.conclude() }
    }

    fileprivate func received(_ body: [String: Any]) {
        guard finishCheck != nil else { return }
        let v = observe(pending: body["rows"] as? [String], ready: body["ready"] as? [String], login: body["login"] as? Bool == true)
        if best.map({ ReadyProof.rank(v) > ReadyProof.rank($0) }) ?? true { best = v }
        // Une ligne prête nouvelle, à la date de la demande : pas besoin d'attendre la fin.
        if v == .ready { conclude() }
    }

    fileprivate func loadFailed(_ error: Error) {
        let e = error as NSError
        switch LoginHelp.loadFailure(domain: e.domain, code: e.code) {
        case .none: return
        case .network: finishCheck?(.offline)
        case .other: finishCheck?(best ?? .unknown)
        }
    }

    private func conclude() {
        finishCheck?(best ?? .unknown)
    }

    // MARK: Zieuton en arrière-plan

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

    /// Zieuton passe en arrière-plan : on demande à iOS un peu de temps pour une dernière vérification (la fenêtre existe encore),
    /// puis on lui demande de nous réveiller plus tard. Rien n'est promis : iOS décide seul s'il réveille Zieuton.
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
            self?.finishCheck?(self?.best ?? .unknown)
            end()
        }
        check { end() }
    }

    /// Demande à iOS de réveiller Zieuton dans quelques minutes (iOS choisit le moment exact, parfois jamais).
    func scheduleBackgroundCheck() {
        guard isWaiting, Self.backgroundAllowed else { return }
        let request = BGAppRefreshTaskRequest(identifier: Self.taskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 60)
        do { try BGTaskScheduler.shared.submit(request) } catch { NSLog("Zieuton : réveil iOS non programmé : %@", error.localizedDescription) }
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
                self?.finishCheck?(self?.best ?? .unknown)
                complete(false)
            }
        }
        check { complete(true) }
    }
}

/// Reçoit ce que lit la vérification cachée, et ses erreurs de chargement. Retenu par ExportWatcher pendant la vérification.
private final class CheckHandler: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    /// Le lecteur de la fenêtre Instagram parle sur ces trois canaux : seul l'état compte ici.
    static let names = ["zyeutoState", "zyeutoTap", "zyeutoRing"]
    weak var watcher: ExportWatcher?
    init(_ watcher: ExportWatcher) { self.watcher = watcher }
    func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {
        guard m.name == "zyeutoState", m.frameInfo.isMainFrame, let body = m.body as? [String: Any] else { return }
        watcher?.received(body)
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        watcher?.loadFailed(error)
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        watcher?.loadFailed(error)
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

// MARK: Sauvegarde iCloud

/// Un seul fichier caché dans l'iCloud de l'utilisateur (Drive iCloud, conteneur de l'app) : tout l'historique du téléphone.
/// Rien ne passe par un serveur à nous. Il est réécrit après chaque changement et revient tout seul sur un nouvel iPhone.
enum ICloudBackup {
    static let container = "iCloud.fr.zyeuto.app"
    static let fileName = "zieuton-icloud.zieuton"
    private static let queue = DispatchQueue(label: "fr.zyeuto.icloud", qos: .utility)

    /// Connecté à iCloud sur cet iPhone (et Drive iCloud allumé pour Zieuton).
    static var available: Bool { FileManager.default.ubiquityIdentityToken != nil }

    /// À appeler hors du fil principal : la première fois, iOS peut mettre un moment à préparer le dossier.
    private static func fileURL() -> URL? {
        guard available, let root = FileManager.default.url(forUbiquityContainerIdentifier: container) else { return nil }
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.appendingPathComponent(fileName)
    }

    static func save(_ data: Data, done: @escaping (Bool) -> Void) {
        queue.async {
            var ok = false
            if let url = fileURL() {
                var err: NSError?
                NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &err) { target in
                    ok = (try? data.write(to: target, options: .atomic)) != nil
                }
                if err != nil { ok = false }
            }
            DispatchQueue.main.async { done(ok) }
        }
    }

    /// Date de la sauvegarde trouvée dans iCloud (nil s'il n'y en a pas). Attend jusqu'à 30 s qu'elle soit téléchargée.
    static func find(done: @escaping (Date?) -> Void) {
        queue.async {
            let date = download().flatMap { url in
                (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()
            }
            DispatchQueue.main.async { done(date) }
        }
    }

    static func read(done: @escaping (Data?) -> Void) {
        queue.async {
            var data: Data?
            if let url = download() {
                var err: NSError?
                NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &err) { target in
                    data = try? Data(contentsOf: target)
                }
            }
            DispatchQueue.main.async { done(data) }
        }
    }

    /// Le fichier, une fois présent sur le téléphone. Sur un nouvel iPhone, iCloud ne l'a souvent pas encore téléchargé.
    private static func download() -> URL? {
        guard let url = fileURL() else { return nil }
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path), isCurrent(url) { return url }
        // Pas encore là : on demande à iCloud de le descendre (s'il existe), puis on attend un peu.
        try? fm.startDownloadingUbiquitousItem(at: url)
        // Sur un iPhone tout neuf, la liste des fichiers iCloud peut mettre quelques secondes à arriver : on attend 30 s au plus.
        let placeholder = url.deletingLastPathComponent().appendingPathComponent("." + fileName + ".icloud")
        for i in 0..<60 {
            Thread.sleep(forTimeInterval: 0.5)
            if fm.fileExists(atPath: url.path), isCurrent(url) { return url }
            if i % 6 == 5, fm.fileExists(atPath: placeholder.path) || fm.isUbiquitousItem(at: url) {
                try? fm.startDownloadingUbiquitousItem(at: url)
            }
        }
        return nil
    }

    private static func isCurrent(_ url: URL) -> Bool {
        let status = (try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]))?.ubiquitousItemDownloadingStatus
        return status == nil || status == .current
    }
}

// MARK: Photo de profil

/// Menu de l'iPhone avec seulement « Photothèque » et « Prendre une photo » (pas de « Choisir le fichier »).
extension WebViewController: PHPickerViewControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func pickPhoto() {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Photothèque", style: .default) { [weak self] _ in
            var config = PHPickerConfiguration()
            config.filter = .images
            config.selectionLimit = 1
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = self
            self?.present(picker, animated: true)
        })
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            sheet.addAction(UIAlertAction(title: "Prendre une photo", style: .default) { [weak self] _ in
                let picker = UIImagePickerController()
                picker.sourceType = .camera
                picker.cameraDevice = .front
                picker.delegate = self
                self?.present(picker, animated: true)
            })
        }
        sheet.addAction(UIAlertAction(title: "Annuler", style: .cancel))
        // iPad : le menu s'accroche au milieu de l'écran.
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = view
            pop.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
            pop.permittedArrowDirections = []
        }
        present(sheet, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let image = object as? UIImage else { return }
            DispatchQueue.main.async { self?.sendPhoto(image) }
        }
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        if let image = info[.originalImage] as? UIImage { sendPhoto(image) }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

    /// Photo réduite (1024 px au plus) puis envoyée à la page, qui la recadre comme avant.
    private func sendPhoto(_ image: UIImage) {
        let side: CGFloat = 1024
        let scale = min(1, side / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let small = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        guard let data = small.jpegData(compressionQuality: 0.85) else { return }
        webView.evaluateJavaScript("window.zyeutoPhoto && window.zyeutoPhoto(\"data:image/jpeg;base64,\(data.base64EncodedString())\"); true")
    }
}

// MARK: Sécurité des mises à jour de la page (FOU-28)

/// Ce que le téléphone retient entre deux lancements (UserDefaults).
final class PageGuardStore {
    private let d = UserDefaults.standard

    /// Versions de la page qui n'ont pas démarré : jamais réaffichées, jamais retéléchargées.
    var bad: [String] { d.stringArray(forKey: "pg.bad") ?? [] }
    func markBad(_ build: String) {
        d.set(PageGuard.addBad(build, to: bad), forKey: "pg.bad")
        if trying == build { clearTries() }
    }

    /// « test » ou « stable » (le réglage caché).
    var channel: String {
        get { d.string(forKey: "pg.channel") == "test" ? "test" : "stable" }
        set { d.set(newValue, forKey: "pg.channel") }
    }

    /// Dernier channel.json lu (nil tant qu'aucun n'a été lu : comportement d'avant, la dernière version en ligne).
    var config: PageGuard.Channel? {
        get {
            guard d.bool(forKey: "pg.config") else { return nil }
            return PageGuard.Channel(stable: d.string(forKey: "pg.stable"), emergency: d.bool(forKey: "pg.urgence"))
        }
        set {
            d.set(newValue != nil, forKey: "pg.config")
            d.set(newValue?.stable, forKey: "pg.stable")
            d.set(newValue?.emergency ?? false, forKey: "pg.urgence")
        }
    }

    /// Version en cours d'essai et nombre de démarrages commencés sans le signal « started ».
    var trying: String? { d.string(forKey: "pg.trying") }
    var tries: Int { d.integer(forKey: "pg.tries") }
    func countTry(_ build: String) {
        if trying != build { d.set(build, forKey: "pg.trying"); d.set(0, forKey: "pg.tries") }
        d.set(tries + 1, forKey: "pg.tries")
    }
    func clearTries() {
        d.removeObject(forKey: "pg.trying")
        d.set(0, forKey: "pg.tries")
    }
}

// PAGE-GUARD:BEGIN
// Les règles, sans rien d'iPhone (Foundation et CryptoKit seulement) : testées hors de l'app par
// tests/ios/PageGuardTests.swift (scripts/test-page-guard.sh, lancé par les vérifications GitHub).
enum PageGuard {
    /// D'où vient une page.
    enum Source: String { case bundled, lastGood, downloaded }

    struct Page: Equatable {
        let source: Source
        let build: String
    }

    /// Le contenu de channel.json.
    struct Channel: Equatable {
        /// Version de la page validée pour tout le monde (nil : pas de limite).
        var stable: String?
        /// Interrupteur d'urgence : tout le monde revient à la page rangée dans l'app.
        var emergency: Bool
    }

    /// Secondes laissées à une page téléchargée pour dire « je suis bien démarrée ».
    static let startTimeout: TimeInterval = 10
    /// Démarrages commencés sans signal, d'affilée, avant de déclarer une page mauvaise.
    static let maxFailedStarts = 2

    /// Format d'un numéro de version : AAAA-MM-JJ-HHMM.
    static func isBuild(_ s: String) -> Bool {
        s.range(of: #"^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{4}$"#, options: .regularExpression) != nil
    }

    /// Lit channel.json. Renvoie nil si le fichier est mal écrit (on garde alors les consignes d'avant).
    /// Exemple : { "stable": "2026-11-06-1300", "urgence": false }
    static func parseChannel(_ data: Data) -> Channel? {
        guard let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        var stable: String?
        if let value = obj["stable"], !(value is NSNull) {
            guard let text = value as? String, isBuild(text) else { return nil }
            stable = text
        }
        var emergency = false
        if let value = obj["urgence"] {
            guard let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else { return nil }
            emergency = number.boolValue
        }
        return Channel(stable: stable, emergency: emergency)
    }

    /// Une page a-t-elle le droit d'être affichée sur ce téléphone ?
    static func allowed(_ page: Page, bad: Set<String>, channel: String, config: Channel?) -> Bool {
        if page.source == .bundled { return true } // la page rangée dans l'app : toujours le dernier recours
        if config?.emergency == true { return false }
        if bad.contains(page.build) { return false }
        if channel != "test", let stable = config?.stable, page.build > stable { return false }
        return true
    }

    /// La page à afficher : la plus récente permise (à égalité, celle rangée dans l'app).
    static func choose(_ pages: [Page], bad: Set<String>, channel: String, config: Channel?) -> Page? {
        let rank: [Source: Int] = [.bundled: 2, .lastGood: 1, .downloaded: 0]
        return pages
            .filter { allowed($0, bad: bad, channel: channel, config: config) }
            .max { a, b in a.build != b.build ? a.build < b.build : rank[a.source]! < rank[b.source]! }
    }

    /// Faut-il garder la page qu'on vient de télécharger ?
    static func shouldKeep(downloaded build: String, current: String, bad: Set<String>,
                           channel: String, config: Channel?) -> Bool {
        build > current && allowed(Page(source: .downloaded, build: build), bad: bad, channel: channel, config: config)
    }

    static func tooManyFailedStarts(_ count: Int) -> Bool { count >= maxFailedStarts }

    /// Ajoute une version mauvaise (on garde les 20 dernières).
    static func addBad(_ build: String, to list: [String]) -> [String] {
        Array((list.filter { $0 != build } + [build]).suffix(20))
    }
}

/// Signature des mises à jour (FOU-29) : une page (ou un channel.json) téléchargée n'est acceptée que si
/// elle est signée avec la clé secrète de Victor. Cette clé n'est jamais dans le dépôt : elle est dans le
/// secret GitHub PAGE_SIGNING_KEY, et le robot de mise en ligne (.github/workflows/publier.yml) publie
/// « index.html.sig » et « channel.json.sig » à côté des fichiers. Format Ed25519, en base64.
enum PageSignature {
    /// Clé publique de Victor (32 octets en base64). Elle n'est pas secrète. Créée par scripts/creer-cle.swift.
    /// Si elle était vide, aucune page téléchargée ne serait acceptée (l'app garderait celle rangée dedans).
    static let publicKey = "bSfAcWK6+uFYIFytbn2FV5hM14A1w9pDYtx0PNlRgY4="

    /// Lit un fichier .sig : une signature de 64 octets en base64 (espaces et retour à la ligne tolérés).
    static func decode(_ file: Data?) -> Data? {
        guard let file, let text = String(data: file, encoding: .utf8),
              let sig = Data(base64Encoded: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              sig.count == 64 else { return nil }
        return sig
    }

    /// Le fichier est-il bien signé par la clé dont `publicKey` est la partie publique ?
    static func isValid(_ data: Data, signatureFile: Data?, publicKey: String = PageSignature.publicKey) -> Bool {
        guard let sig = decode(signatureFile),
              let raw = Data(base64Encoded: publicKey), raw.count == 32,
              let key = try? Curve25519.Signing.PublicKey(rawRepresentation: raw) else { return false }
        return key.isValidSignature(sig, for: data)
    }
}
// PAGE-GUARD:END
