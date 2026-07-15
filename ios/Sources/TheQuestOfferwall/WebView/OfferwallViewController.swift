import PhotosUI
import UIKit
import WebKit

/// Full-screen host for the Quest offerwall: a native header (close button + optional
/// title) above a `WKWebView` that renders the offerwall and talks to the native layer
/// through the `theQuestNative` bridge.
///
/// Memory safety: the `WKScriptMessageHandler` is registered through a weak proxy so the
/// view controller is **not** retained by `WKUserContentController`. That lets `deinit`
/// run, where the handler is removed explicitly.
final class OfferwallViewController: UIViewController {

    // MARK: Inputs

    /// Resolves the launch URL. In standard mode this returns a pre-built URL; in secure
    /// mode it awaits the launch provider, then builds the signed URL. Re-invoked on retry.
    private let resolveURL: @Sendable () async throws -> URL
    private let headerTitle: String?
    private let onClose: (() -> Void)?

    /// Host the offerwall may freely navigate within; any other host opens externally.
    private let allowedHost: String?

    // MARK: State

    private var didFireOnClose = false
    private var didHideSpinner = false

    /// requestId of the in-flight `pickImages` bridge call, if a picker is presented.
    private var pendingPickRequestId: String?

    // MARK: Views

    private var webView: WKWebView!
    private let spinner = UIActivityIndicatorView(style: .large)
    private lazy var errorView: UIView = makeErrorView()

    // MARK: Init

    init(
        baseURL: URL,
        headerTitle: String?,
        onClose: (() -> Void)?,
        resolveURL: @escaping @Sendable () async throws -> URL
    ) {
        self.resolveURL = resolveURL
        self.headerTitle = headerTitle
        self.onClose = onClose
        self.allowedHost = baseURL.host
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    deinit {
        // Break the WKUserContentController -> handler retain and stop loading.
        webView?.configuration.userContentController
            .removeScriptMessageHandler(forName: BridgeScript.messageHandlerName)
        webView?.stopLoading()
    }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        presentationController?.delegate = self
        setupWebView()
        setupSpinner()
        setupErrorView()
        applyUserAgentThenStart()
    }

    // MARK: Setup

    private func setupWebView() {
        let controller = WKUserContentController()
        let script = WKUserScript(
            source: BridgeScript.userScriptSource(version: SDKInfo.version),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        controller.addUserScript(script)
        // Weak proxy so this VC is not retained by the user content controller.
        controller.add(WeakScriptMessageHandler(self), name: BridgeScript.messageHandlerName)

        let config = WKWebViewConfiguration()
        config.userContentController = controller
        config.websiteDataStore = .default() // persistent — keeps the qs_session cookie
        config.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = false
        webView.translatesAutoresizingMaskIntoConstraints = false
        self.webView = webView
        view.addSubview(webView)

        // Full-bleed: the offerwall has no native header — the web renders its own header
        // (with a close button wired to the bridge) and handles the top safe-area inset via
        // CSS `env(safe-area-inset-top)`. Pin edge-to-edge so those insets are reported.
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func setupSpinner() {
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.hidesWhenStopped = true
        view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: webView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: webView.centerYAnchor)
        ])
        spinner.startAnimating()
    }

    private func setupErrorView() {
        errorView.translatesAutoresizingMaskIntoConstraints = false
        errorView.isHidden = true
        view.addSubview(errorView)
        NSLayoutConstraint.activate([
            errorView.leadingAnchor.constraint(
                greaterThanOrEqualTo: webView.leadingAnchor, constant: 24),
            errorView.trailingAnchor.constraint(
                lessThanOrEqualTo: webView.trailingAnchor, constant: -24),
            errorView.centerXAnchor.constraint(equalTo: webView.centerXAnchor),
            errorView.centerYAnchor.constraint(equalTo: webView.centerYAnchor)
        ])
    }

    private func makeErrorView() -> UIView {
        let label = UILabel()
        label.text = "Couldn’t load the offerwall. Check your connection and try again."
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.font = .systemFont(ofSize: 15)

        let retry = UIButton(type: .system)
        retry.setTitle("Retry", for: .normal)
        retry.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        retry.addTarget(self, action: #selector(handleRetryTapped), for: .touchUpInside)

        // With no native header, the error screen carries the only close affordance when the
        // web (which otherwise renders the close button) fails to load.
        let close = UIButton(type: .system)
        close.setTitle("Close", for: .normal)
        close.titleLabel?.font = .systemFont(ofSize: 15)
        close.tintColor = .secondaryLabel
        close.addTarget(self, action: #selector(handleCloseTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [label, retry, close])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        return stack
    }

    // MARK: Loading

    /// Reads the default WebView user agent, appends the SDK token, then starts the flow.
    private func applyUserAgentThenStart() {
        let token = " TheQuestSDK/\(SDKInfo.version) (ios)"
        webView.evaluateJavaScript("navigator.userAgent") { [weak self] result, _ in
            guard let self else { return }
            if let defaultUA = result as? String {
                self.webView.customUserAgent = defaultUA + token
            }
            self.startFlow()
        }
    }

    /// Resolves the launch URL (awaiting the provider in secure mode) and loads it,
    /// showing the error/retry screen on failure.
    private func startFlow() {
        errorView.isHidden = true
        if !didHideSpinner { spinner.startAnimating() }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let url = try await self.resolveURL()
                self.load(url)
            } catch {
                self.showError()
            }
        }
    }

    private func load(_ url: URL) {
        errorView.isHidden = true
        webView.load(URLRequest(url: url))
    }

    private func hideSpinner() {
        didHideSpinner = true
        spinner.stopAnimating()
    }

    private func showError() {
        hideSpinner()
        errorView.isHidden = false
    }

    // MARK: Actions

    @objc private func handleCloseTapped() {
        dismiss(animated: true) { [weak self] in self?.fireOnCloseOnce() }
    }

    @objc private func handleRetryTapped() {
        didHideSpinner = false
        startFlow()
    }

    private func fireOnCloseOnce() {
        guard !didFireOnClose else { return }
        didFireOnClose = true
        onClose?()
    }

    // MARK: Bridge

    fileprivate func handle(_ message: BridgeScript.Message) {
        switch message {
        case .openUrl(let url):
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        case .close:
            handleCloseTapped()
        case .ready:
            hideSpinner()
        case .pickImages(let requestId, let multiple):
            presentPhotoPicker(requestId: requestId, multiple: multiple)
        }
    }

    // MARK: Photo picker

    /// Present the system photo picker. `PHPickerViewController` runs out-of-process, so it
    /// needs **no** photo-library permission and never offers the camera — unlike the file
    /// panel WKWebView would show for `<input type="file">`, which can crash the host app.
    private func presentPhotoPicker(requestId: String, multiple: Bool) {
        // Supersede any in-flight request so its web promise is settled ([]).
        if let previous = pendingPickRequestId {
            deliverImages(requestId: previous, dataURLs: [])
        }
        pendingPickRequestId = requestId

        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = multiple ? 0 : 1 // 0 = unlimited
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    /// Load each picked image, downscale + JPEG-encode it (small bridge payload), and hand
    /// the resulting data URLs back to the web. Order is preserved.
    private func loadDataURLs(
        from results: [PHPickerResult],
        completion: @escaping ([String]) -> Void
    ) {
        let group = DispatchGroup()
        var byIndex = [Int: String]()
        let lock = NSLock()
        for (index, result) in results.enumerated() {
            let provider = result.itemProvider
            guard provider.canLoadObject(ofClass: UIImage.self) else { continue }
            group.enter()
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                defer { group.leave() }
                guard let image = object as? UIImage,
                      let dataURL = Self.jpegDataURL(from: image) else { return }
                lock.lock()
                byIndex[index] = dataURL
                lock.unlock()
            }
        }
        group.notify(queue: .main) {
            completion((0..<results.count).compactMap { byIndex[$0] })
        }
    }

    /// Downscale (longest edge ≤ `maxDimension`) and JPEG-encode to a `data:` URL.
    private static func jpegDataURL(
        from image: UIImage,
        maxDimension: CGFloat = 1600,
        quality: CGFloat = 0.85
    ) -> String? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let longest = max(size.width, size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        guard let data = resized.jpegData(compressionQuality: quality) else { return nil }
        return "data:image/jpeg;base64,\(data.base64EncodedString())"
    }

    /// Deliver the picked data URLs (empty on cancel) to the web, once per requestId.
    private func deliverImages(requestId: String, dataURLs: [String]) {
        guard pendingPickRequestId == requestId else { return }
        pendingPickRequestId = nil
        webView.evaluateJavaScript(
            BridgeScript.imagesPickedJS(requestId: requestId, dataURLs: dataURLs),
            completionHandler: nil
        )
    }
}

// MARK: - WKNavigationDelegate

extension OfferwallViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        hideSpinner()
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        showError()
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        showError()
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        // Same-origin navigation (or non-web schemes handled below) stays in the webview.
        if let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
            if url.host == allowedHost {
                decisionHandler(.allow)
            } else {
                // Never navigate the offerwall cross-origin — open externally instead.
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                decisionHandler(.cancel)
            }
        } else {
            // Custom schemes / deep links → hand off to the OS.
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            decisionHandler(.cancel)
        }
    }
}

// MARK: - WKUIDelegate

extension OfferwallViewController: WKUIDelegate {
    /// `target="_blank"` links have no frame to load into; open them externally.
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let url = navigationAction.request.url {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        return nil
    }
}

// MARK: - UIAdaptivePresentationControllerDelegate

extension OfferwallViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        // Interactive (swipe) dismissal of the offerwall itself. (The photo picker is a
        // separate presentation and reports its own cancel via didFinishPicking([]).)
        pendingPickRequestId = nil
        fireOnCloseOnce()
    }
}

// MARK: - PHPickerViewControllerDelegate

extension OfferwallViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let requestId = pendingPickRequestId else { return }
        if results.isEmpty {
            deliverImages(requestId: requestId, dataURLs: [])
            return
        }
        loadDataURLs(from: results) { [weak self] dataURLs in
            self?.deliverImages(requestId: requestId, dataURLs: dataURLs)
        }
    }
}

// MARK: - Weak message handler proxy

/// Bridges `WKScriptMessageHandler` to a weakly-held target so the user content
/// controller does not retain the view controller (avoids a leak / prevents `deinit`).
private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var target: OfferwallViewController?

    init(_ target: OfferwallViewController) {
        self.target = target
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == BridgeScript.messageHandlerName,
              let parsed = BridgeScript.Message.parse(message.body) else {
            return
        }
        target?.handle(parsed)
    }
}
