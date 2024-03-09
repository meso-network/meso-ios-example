//
//  Meso.swift
//  MesoSwift
//

import SwiftUI
import WebKit
import Foundation

/// The hardcoded handler name for the injected `postMessage` communication. This value is hardcoded inside the Meso application so cannot be changed.
private let messageHandlerName = "meso"

/// A [CAIP-2](https://chainagnostic.org/CAIPs/caip-2) network identifier.
public enum Network: String {
    case ethereumMainnet = "eip155:1"
    case solanaMainnet = "solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp"
    case polygonMainnet = "eip155:137"
}

/// Symbol representing a crypto/fiat currency.
public enum Asset: String {
    case sol = "SOL"
    case eth = "ETH"
    case usdc = "USDC"
}

public enum Environment: String {
    /// In this environment, no crypto assets are transferred and no fiat assets are moved.
    case sandbox = "SANDBOX"
    /// In this environment, production networks will be used to transfer real crypto assets. Fiat assets are moved.
    case production = "PRODUCTION"
    
    var origin: String {
        switch self {
        case .sandbox:
            return "https://api.sandbox.meso.network"
        case .production:
            return "https://api.meso.network"
        }
    }
}

/// Used to determine the type of authentication the user will need to perform for a transfer.
public enum AuthenticationStrategy: String {
    /// Verify wallet by signing a message.
    ///
    /// New users and returning users with new wallets will still need to perform 2FA and login with email/password.
    case walletVerification = "wallet_verification"
    /// Verify a wallet by signing a message in the background _without_ prompting the user. This is useful for scenarios such as embedded wallets.
    /// New users and returning users with new wallets will still need to perform login and 2FA.
    case headlessWalletVerification = "headless_wallet_verification"
    /// Bypass wallet signing altogether and rely only on email/password and 2FA.
    /// This is useful for cases where pre-deployment smart contract wallets are being used and wallet verification cannot be performed.
    case bypassWalletVerification = "bypass_wallet_verification"
}

public struct MesoTransferConfiguration {
    /// Unique ID for your partner account.
    var partnerId: String;
    /// The network to be used for the transfer.
    var network: Network;
    /// The wallet address for the user. This address must be compatible with the selected `network` and `destinationAsset`.
    var walletAddress: String;
    /// A  number including decimals (if needed) representing the fiat amount to be used for the transfer.
    var sourceAmount: Float;
    /// The asset to be transferred.
    var destinationAsset: Asset;
    /// The Meso environment to use. (`.sandbox` | `.production`).
    var environment: Environment;
    /// Determines the authentication mechanism for users to perform a transfer.
    ///
    /// In all scenarios, the user will still be required to perform two-factor authentication (2FA) and, in some cases provide email/password.
    /// If omitted, this will default to `.walletVerification`.
    var authenticationStrategy: AuthenticationStrategy?
}

enum MessageKind: String, Codable {
    /// Request from Meso experience to parent window to initiate signing.
    case requestSignedMessage = "REQUEST_SIGNED_MESSAGE"
    /// Dispatch the result of a signature request from the parent window to the Meso experience.
    case returnSignedMessageResult = "RETURN_SIGNED_MESSAGE_RESULT"
    /// Dispatch a message from the Meso experience to the parent window to close the experience.
    case close = "CLOSE"
    /// Dispatch a message from the Meso experience to the parent window when the transfer has been updated.
    case transferUpdate = "TRANSFER_UPDATE"
    /// Dispatch an error message from the Meso experience to the parent window.
    case error = "ERROR"
    /// Dispatch a configuration error when the Meso experience cannot be initialized.
    case configurationError = "CONFIGURATION_ERROR"
    /// Dispatch an unsupported network error when the `network` passed to initialize the Meso experience is not supported.
    case unsupportedNetworkError = "UNSUPPORTED_NETWORK_ERROR"
    /// Dispatch an unsupported asset error when the `destinationAsset` passed to initialize the Meso experience is not supported.
    case unsupportedAssetError = "UNSUPPORTED_ASSET_ERROR"
    
}

enum TransferStatus: String, Codable {
    /// The transfer has been approved and is pending completion. At this point, funds have _not_ yet been moved.
    case approved = "APPROVED"
    /// The transfer is complete and the user's funds are available.
    case complete = "COMPLETE"
    /// The transfer has failed.
    case declined = "DECLINED"
    /// The transfer is in flight.
    case executing = "EXECUTING"
    case unknown = "UNKNOWN"
}

/// Details of a Meso transfer.
struct Transfer: Codable {
    /// The Meso `id` for this `transfer`.
    var id: String
    var status: TransferStatus
    /// An [ISO-8601](https://en.wikipedia.org/wiki/ISO_8601) date string.
    var updatedAt: String
    /// The on-chain identifier for the transfer.
    ///
    /// **Note:** This will only be available for transfers that are `COMPLETE`.
    var networkTransactionId: String?
}

/// A wrapper for a generic Meso-scoped error.
struct ErrorPayload: Codable {
    /// A client-friendly error message.
    var message: String
}

/// A wrapped result of a transfer status update to be sent to the partner application.
struct TransferPayload: Codable {
    var transfer: Transfer
}

/// The payload we will receive when the `webView` prompts for a wallet signature.
struct RequestSignedMessagePayload: Codable {
    /// An opaque message to be signed via an action in the Meso window.
    var messageToSign: String
}

/// The payload to be sent to the webView when a message is signed.
struct ReturnSignedMessagePayload: Codable {
    var kind = MessageKind.returnSignedMessageResult.rawValue
    var payload: SignedMessage
    
    struct SignedMessage: Codable {
        /// Signed message from parent window to Meso experience for blockchain address verification.
        ///
        /// This value should be set to `nil` if the user cancels or rejects the signing or if there is a failure while negotiating the verification.
        var signedMessage: String?
    }
}

/// Structured messages sent between the Meso window and this library
enum PostMessageBodyPayload: Codable {
    /// The Meso window has requested a message be signed to verify ownership of the wallet.
    case requestSignedMessage(payload: RequestSignedMessagePayload)
    /// The Meso window is unable to parse your configuration. Some values may need to be updated.
    case configurationError(payload: ErrorPayload)
    /// The asset provided is currently not supported by Meso.
    case unsupportedAssetError(payload: ErrorPayload)
    /// The network provided is currently not supported by Meso.
    case unsupportedNetworkError(payload: ErrorPayload)
    /// Details of a Transfer.
    case transferUpdate(payload: TransferPayload)
}

/// The message body received from the Meso window.
struct ReceivedPostMessageBody: Codable {
    let kind: MessageKind
    let payload: PostMessageBodyPayload?
    
    enum CodingKeys: String, CodingKey {
        case kind, payload
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decode(MessageKind.self, forKey: .kind)
        
        
        // Based on kind, decode the payload
        switch kind {
        case .requestSignedMessage:
            let payloadData = try container.decode(RequestSignedMessagePayload.self, forKey: .payload)
            payload = .requestSignedMessage(payload: payloadData)
        case .close:
            payload = nil
        case .configurationError:
            let payloadData = try container.decode(ErrorPayload.self, forKey: .payload)
            payload = .configurationError(payload: payloadData)
        case .unsupportedAssetError:
            let payloadData = try container.decode(ErrorPayload.self, forKey: .payload)
            payload = .unsupportedAssetError(payload: payloadData)
        case .unsupportedNetworkError:
            let payloadData = try container.decode(ErrorPayload.self, forKey: .payload)
            payload = .unsupportedNetworkError(payload: payloadData)
        case .transferUpdate:
            let payloadData = try container.decode(Transfer.self, forKey: .payload)
            payload = .transferUpdate(payload: TransferPayload(transfer: payloadData))
        default:
            // If the kind does not match any case or requires no payload
            throw DecodingError.dataCorruptedError(forKey: .payload, in: container, debugDescription: "Invalid or missing payload for message kind: \(kind)")
        }
    }
}

/// Structured messages sent between this library and the partner application
enum MesoEvent {
    /// The Transfer has been approved and will have a status of `TransferStatus.approved`
    case transferApproved(payload: TransferPayload)
    /// The Transfer is complete, funds have moved, and will have a status of `TransferStatus.complete`
    case transferComplete(payload: TransferPayload)
    /// An error occurred in the application. A client-friendly error will be surfaced.
    case error(payload: ErrorPayload)
    /// The configuration is malformed and values may need to be updated.
    case configurationError(payload: ErrorPayload)
    /// The provided network is not currently supported by Meso.
    case unsupportedNetworkError(payload: ErrorPayload)
    /// The provided asset is not currently supported by Meso.
    case unsupportedAssetError(payload: ErrorPayload)
    /// The Meso window has requested a message to be signed to prove ownership of a wallet. Upon signing, this callback can be used to return the signed message.
    case requestSignedMessage(
        payload: RequestSignedMessagePayload,
        /// A callback to return the signed message. If no `String` is returned, it is assumed the user canceled or rejected the message signing.
        callback: (_ signedMessage: String?) -> Void
    )
    /// The user has manually opted to close the Meso window.
    case close
}

/// A function registered to call when a Meso-specific event is dispatched.
typealias MesoEventHandler = (MesoEvent) -> Void
/// An internal action to emit a Meso-specific event.
typealias DispatchMesoEvent = (_ event: MesoEvent) -> Void

public class Meso {
    private let configuration: MesoTransferConfiguration
    private var eventHandlers: [MesoEventHandler] = []
    
    public init(configuration: MesoTransferConfiguration) {
        self.configuration = configuration
    }
    
    public func transfer() -> some View {
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "partnerId", value: configuration.partnerId),
            URLQueryItem(name: "network", value: configuration.network.rawValue),
            URLQueryItem(name: "walletAddress", value: configuration.walletAddress),
            URLQueryItem(name: "sourceAmount", value: String(configuration.sourceAmount)),
            URLQueryItem(name: "destinationAsset", value: configuration.destinationAsset.rawValue),
            URLQueryItem(name: "environment", value: configuration.environment.rawValue),
            URLQueryItem(
                name: "authenticationStrategy",
                value: configuration.authenticationStrategy?.rawValue ?? AuthenticationStrategy.walletVerification.rawValue
            ),
            URLQueryItem(name: "version", value: "ios_preview_01"),
            URLQueryItem(name: "mode", value: "webview")
        ]
        
        let currentEnvironment = configuration.environment
        let origin = currentEnvironment.origin
        let url = URL(string: "\(origin)/app?\(components.url?.query ?? "")")!
        
        return MesoWebView(origin: origin, url: url, dispatchEvent: self.dispatch)
    }
    
    @discardableResult
    func on(_ handler: @escaping MesoEventHandler) -> Self {
        eventHandlers.append(handler)
        return self
    }
    
    func dispatch(event: MesoEvent) {
        eventHandlers.forEach { $0(event) }
    }
}

internal struct MesoWebView: UIViewRepresentable {
    public let origin: String
    public let url: URL
    public let dispatchEvent: DispatchMesoEvent
    
    public func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        configuration.userContentController = contentController
        contentController.add(context.coordinator, name: messageHandlerName)
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        
        webView.allowsBackForwardNavigationGestures = false
        webView.allowsLinkPreview = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        // Allow debugging with Safari DevTools (only available in iOS 17+)
        if #available(iOS 17, *) {
            webView.isInspectable = true
        }
        
        return webView
    }
    
    public func updateUIView(_ uiView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        uiView.load(request)
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self, origin: origin, dispatchEvent: dispatchEvent)
    }
    
    public class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var origin: String
        var parent: MesoWebView
        var dispatchEvent: DispatchMesoEvent
        weak var webView: WKWebView? // Keep a weak reference to the WKWebView
        
        init(_ webView: MesoWebView, origin: String, dispatchEvent: @escaping DispatchMesoEvent) {
            self.parent = webView
            self.origin = origin
            self.dispatchEvent = dispatchEvent
        }
        
        public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            // Ignore messages from unknown sources.
            if message.name != messageHandlerName {
                return
            }
            
            guard let body = message.body as? String else {
                print("[Error]: message.body is not a String. \(message.body)")
                return
            }
            
            do {
                let messageData: Data = body.data(using: .utf8)!
                let decoder = JSONDecoder()
                let decodedMessage = try decoder.decode(ReceivedPostMessageBody.self, from: messageData)
                let encoder = JSONEncoder()
                
                // Dispatch events based on the structure of the `payload` or the `kind`.
                switch decodedMessage.payload  {
                case .configurationError(let payload):
                    self.dispatchEvent(.configurationError(payload: payload))
                case .unsupportedAssetError(let payload):
                    self.dispatchEvent(.unsupportedAssetError(payload: payload))
                case .unsupportedNetworkError(let payload):
                    self.dispatchEvent(.unsupportedNetworkError(payload: payload))
                case .requestSignedMessage(let payload):
                    self.dispatchEvent(.requestSignedMessage(payload: payload, callback: { signedMessageResult in
                        do {
                            let rawMessage = try encoder.encode(
                                ReturnSignedMessagePayload(payload: ReturnSignedMessagePayload.SignedMessage(signedMessage: signedMessageResult))
                            )
                            
                            if let stringifiedMessage = String(data: rawMessage, encoding: .utf8) {
                                self.sendMessageToMesoWindow(message: stringifiedMessage)
                            } else {
                                print("[Error]: Unable to build JSON payload for `ReturnSignedMessage`.")
                            }
                        } catch {
                            print("[Error]: Unable to return signed message.")
                        }
                    }))
                case .transferUpdate(let payload):
                    if payload.transfer.status == TransferStatus.approved {
                        self.dispatchEvent(.transferApproved(payload: payload))
                    } else if payload.transfer.status == TransferStatus.complete {
                        self.dispatchEvent(.transferComplete(payload: payload))
                    } else {
                        print("[Error]: Unexpected transfer status \(payload.transfer.status)")
                    }
                case .none:
                    if decodedMessage.kind == MessageKind.close {
                        self.dispatchEvent(MesoEvent.close)
                    }
                }
            } catch {
                print("[Error]: Unable to decode message body: \(error)")
            }
        }
        
        /// Sends a stringified JSON object to the webView. It is the responsibility of the caller to ensure the message conforms to Meso specifications.
        func sendMessageToMesoWindow(message: String) {
            guard let webView = webView else { return }
            
            // Construct the JavaScript code to post the message
            let script = "window.postMessage('\(message)', '\(origin)');"
            webView.evaluateJavaScript(script) { result, error in
                if let error = error {
                    print("[Error]: Unable to post message to Meso window. \(error)")
                } else {
                    print("Message posted to Meso WebView.")
                }
            }
        }
    }
}
