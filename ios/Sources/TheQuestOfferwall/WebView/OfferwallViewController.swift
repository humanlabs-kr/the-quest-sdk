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

    // MARK: Views

    private var webView: WKWebView!
    private let headerBar = UIView()
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
        setupHeader()
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
    }

    private func setupHeader() {
        headerBar.translatesAutoresizingMaskIntoConstraints = false
        headerBar.backgroundColor = .systemBackground
        view.addSubview(headerBar)

        let separator = UIView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.backgroundColor = .separator
        headerBar.addSubview(separator)

        let closeButton = UIButton(type: .system)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setTitle("\u{2715}", for: .normal) // ✕
        closeButton.titleLabel?.font = .systemFont(ofSize: 20, weight: .medium)
        closeButton.accessibilityLabel = "Close"
        closeButton.tintColor = .label
        closeButton.addTarget(self, action: #selector(handleCloseTapped), for: .touchUpInside)
        headerBar.addSubview(closeButton)

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = headerTitle
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        headerBar.addSubview(titleLabel)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            headerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerBar.topAnchor.constraint(equalTo: guide.topAnchor),
            headerBar.heightAnchor.constraint(equalToConstant: 52),

            separator.leadingAnchor.constraint(equalTo: headerBar.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: headerBar.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: headerBar.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale),

            closeButton.leadingAnchor.constraint(equalTo: headerBar.leadingAnchor, constant: 8),
            closeButton.centerYAnchor.constraint(equalTo: headerBar.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),

            titleLabel.centerXAnchor.constraint(equalTo: headerBar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: headerBar.centerYAnchor),
            titleLabel.leadingAnchor.constraint(
                greaterThanOrEqualTo: closeButton.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: headerBar.trailingAnchor, constant: -52),

            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: headerBar.bottomAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
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

        let stack = UIStackView(arrangedSubviews: [label, retry])
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
        }
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
        // Interactive (swipe) dismissal.
        fireOnCloseOnce()
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
