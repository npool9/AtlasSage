import SwiftUI
import WebKit

// Serves WebContent bundle files over a custom app:// scheme.
// This avoids the file:// restrictions that prevent complex React apps from mounting.
private class AppSchemeHandler: NSObject, WKURLSchemeHandler {
    private let baseURL: URL
    private let mimeTypes: [String: String] = [
        "html": "text/html; charset=utf-8",
        "js": "application/javascript; charset=utf-8",
        "css": "text/css; charset=utf-8",
        "json": "application/json; charset=utf-8",
        "png": "image/png",
        "jpg": "image/jpeg",
        "jpeg": "image/jpeg",
        "svg": "image/svg+xml",
        "ico": "image/x-icon",
        "woff": "font/woff",
        "woff2": "font/woff2",
        "ttf": "font/ttf",
    ]

    init(baseURL: URL) { self.baseURL = baseURL }

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let requestURL = task.request.url else { return }
        var path = requestURL.path
        if path.isEmpty || path == "/" { path = "/index.html" }
        let clean = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let fileURL = baseURL.appendingPathComponent(clean)
        do {
            let data = try Data(contentsOf: fileURL)
            let mime = mimeTypes[fileURL.pathExtension.lowercased()] ?? "application/octet-stream"
            let headers = ["Content-Type": mime, "Content-Length": "\(data.count)"]
            let response = HTTPURLResponse(url: requestURL, statusCode: 200,
                                           httpVersion: "HTTP/1.1", headerFields: headers)!
            task.didReceive(response)
            task.didReceive(data)
            task.didFinish()
        } catch {
            task.didFailWithError(error)
        }
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}

struct WebView: UIViewRepresentable {

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        if let baseURL = Bundle.main.url(forResource: "WebContent", withExtension: nil) {
            config.setURLSchemeHandler(AppSchemeHandler(baseURL: baseURL), forURLScheme: "app")
        }

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.scrollView.bounces = false
        webView.scrollView.bouncesZoom = false
        webView.isOpaque = true
        webView.backgroundColor = UIColor(red: 22/255, green: 35/255, blue: 59/255, alpha: 1)

        webView.load(URLRequest(url: URL(string: "app://localhost/index.html")!))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(
            _ webView: WKWebView,
            decidePolicyFor action: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = action.request.url else { decisionHandler(.allow); return }
            if url.scheme == "app" || url.scheme == "about" || url.scheme == "blob" {
                decisionHandler(.allow)
            } else if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}
