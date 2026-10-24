import SafariServices
import os.log
import AppKit

public class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {

    private static let logger = Logger(subsystem: "com.nekotrans.mac", category: "safari-extension")

    public func beginRequest(with context: NSExtensionContext) {
        let request = context.inputItems.first as? NSExtensionItem

        let message: Any?
        if #available(iOS 15.0, macOS 11.0, *) {
            message = request?.userInfo?[SFExtensionMessageKey]
        } else {
            message = request?.userInfo?["message"]
        }

        Self.logger.debug("Received Safari native message: \(String(describing: message), privacy: .public)")

        var responsePayload: [String: Any] = [
            "status": "ok",
            "app": "NekoTrans",
            "version": "1.0.0"
        ]

        if let dict = message as? [String: Any], let action = dict["action"] as? String {
            switch action {
            case "ping", "status":
                responsePayload["pong"] = true
                responsePayload["connected"] = true

            case "saveWord":
                let word = (dict["word"] as? String) ?? ""
                let meaning = (dict["translation"] as? String) ?? ""
                let phonetic = (dict["phonetic"] as? String) ?? ""
                var components = URLComponents()
                components.scheme = "nekotrans"
                components.host = "save-word"
                components.queryItems = [
                    URLQueryItem(name: "text", value: word),
                    URLQueryItem(name: "meaning", value: meaning),
                    URLQueryItem(name: "phonetic", value: phonetic)
                ]
                if let url = components.url {
                    DispatchQueue.main.async {
                        NSWorkspace.shared.open(url)
                    }
                    responsePayload["saved"] = true
                }

            case "openApp":
                let urlString = (dict["url"] as? String) ?? "nekotrans://"
                if let url = URL(string: urlString) {
                    DispatchQueue.main.async {
                        NSWorkspace.shared.open(url)
                    }
                    responsePayload["opened"] = true
                }

            default:
                responsePayload["echo"] = message
            }
        }

        let response = NSExtensionItem()
        if #available(iOS 15.0, macOS 11.0, *) {
            response.userInfo = [SFExtensionMessageKey: responsePayload]
        } else {
            response.userInfo = ["message": responsePayload]
        }

        context.completeRequest(returningItems: [response], completionHandler: nil)
    }
}
