# Meso iOS Example

A reference implementation for integrating Meso's on/off ramps into iOS applications.

> For more details on the Meso integration, view the [meso-js docs](https://github.com/meso-network/meso-js/blob/main/packages/meso-js/README.md).

Meso does not have an official iOS SDK. However, this repo demonstrates the steps required to use Meso in an iOS application. Instead of rendering the Meso experience inside an iframe, this uses a WebView. The example helper library does two things:

- Manages the lifecycle a WebView ([WKWebView](https://developer.apple.com/documentation/webkit/wkwebview)) that renders the Meso transfer experience.
- Configures `postMessage` capabilities between the Meso window and your application. See [`Events`](#events) for more.

> 📓 Currently, the SDK is in private beta. To request access, contact
> [support@meso.network](mailto:support@meso.network).

<details>
  <summary><strong>Contents</strong></summary>
  
- [Meso iOS Example](#meso-ios-example)
  - [Requirements](#requirements)
    - [Account setup](#account-setup)
  - [Usage](#usage)
  - [Reference](#reference)
    - [`MesoTransferConfiguration`](#mesotransferconfiguration)
      - [`Network`](#network)
      - [`Asset`](#asset)
      - [`Environment`](#environment)
      - [`AuthenticationStrategy`](#authenticationstrategy)
    - [Events](#events)
      - [`TransferPayload`](#transferpayload)
      - [`Transfer`](#transfer)
      - [`TransferStatus`](#transferstatus)
      - [`ErrorPayload`](#errorpayload)
      - [`RequestSignedMessagePayload`](#requestsignedmessagepayload)
    - [Testing values](#testing-values)
    - [Supported versions](#supported-versions)
    - [Caveats](#caveats)

</details>

## Requirements

### Account setup

To use Meso, you must have a [Meso](https://meso.network) partner
account. You can reach out to
[support@meso.network](mailto:support@meso.network) to sign up. During the
onboarding process, you will need to specify the
[origin](https://developer.mozilla.org/en-US/docs/Glossary/Origin) of your dApp
or web application to ensure the Meso window operates within your application. Meso
will then provide you with a `partnerId` for use with the SDK.

## Usage

The demo application is built in Swift and uses SwiftUI. Using SwiftUI _is not_ a requirement.

The logic for initializing and managing the Meso window lives in [Meso.swift](./ios/MesoSwift/Meso.swift). This library is used inside of the main [`ContentView`](./ios/MesoSwift/MesoSwift/ContentView.swift).

To initialize Meso, you will need to configure the transfer (see [reference](#reference) for details).

```swift
// This is an example static configuration. Typically, this will by dynamically populated in your application at runtime.
let mesoTransferConfiguration = MesoTransferConfiguration(
    partnerId: "<YOUR_PARTNER_ID>",
    network: Network.solanaMainnet,
    // This is just an example Solana address. You will need to input your own wallet.
    walletAddress: walletAddress,
    sourceAmount: transferAmount,
    destinationAsset: Asset.sol,
    environment: Environment.sandbox
)
let meso = Meso(configuration: mesoTransferConfiguration)

meso.on { event in
    switch event {
    case .configurationError(let payload):
        print("[Configuration Error]: \(payload)")
    case .unsupportedAssetError(let payload):
        print("[Unsupported Asset Error]: \(payload)")
    case .unsupportedNetworkError(let payload):
        print("[Unsupported Network Error]: \(payload)")
    case .requestSignedMessage(let payload, let callback):
        // This demonstrates a generic method of signing messages with Solana wallets. In the real world, you would
        // typically use a library or your own signing implementation.
        // If the user cancels or rejects signing, or there is a failure, return nil – `callback(nil)`
        callback(signMessage(messageToSign: payload.messageToSign))
    case .close:
        showMeso = false
    case .transferApproved(let payload):
        print("Handling `transferApproved` \(payload.transfer.id), \(payload.transfer.status)")
    case .transferComplete(let payload):
        let networkTransactionId = payload.transfer.networkTransactionId ?? "unknown"
        print("Transfer complete! mesoId: \(payload.transfer.id), networkTransactionId: \(networkTransactionId)")
        showMeso = false
    default:
        print("Unknown or discarded event")
    }
}
```

You can then call `meso.transfer()` when you want to render Meso in a WebView.

**Example:**

For example, in a SwiftUI View, you can do something like this:

```swift
let meso = Meso(...) // Your Meso configuration

meso.on { event in
  // Handle events from Meso
}

struct ContentView: View {
    @State private var showMeso = false

    var body: some View {
        ZStack {
            VStack {
                Button("Buy Crypto") {
                    if !showMeso {
                        showMeso.toggle()
                    }
                }
            }

            if showMeso {
                // Calling `meso.transfer` will render the WebView
                meso.transfer()
            }
        }
    }
}
```

You can close the Meso WebView at any time by calling `meso.destroy()`.

## Reference

For a detailed reference, view the [`meso-js` docs](https://github.com/meso-network/meso-js/blob/main/packages/meso-js/README.md#reference).

### `MesoTransferConfiguration`

The `MesoTransferConfiguration` struct is located in [Meso.swift](./ios/MesoSwift/Meso.swift).

| Property                 | Type                                                | Description                                                                                                                                                                                                                                                              |
| ------------------------ | --------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `partnerId`              | `String`                                            | Unique ID for your partner account. (See [Account setup](#account-setup))                                                                                                                                                                                                |
| `network`                | [`Network`](#network)                               | The [network](#network) to be used for the transfer.                                                                                                                                                                                                                     |
| `walletAddress`          | `String`                                            | The wallet address for the user. This address must be compatible with the selected `network` and `destinationAsset`.                                                                                                                                                     |
| `sourceAmount`           | `Float`                                             | A JSON-string-serializable amount for the Transfer.                                                                                                                                                                                                                      |
| `destinationAsset`       | [`Asset`](#asset)                                   | The [asset](#asset) to be transferred.                                                                                                                                                                                                                                   |
| `environment`            | [`Environment`](#environment)                       | The Meso [environment](#environment) to use. Typically you will use `sandbox` during development and `production` when you release your application.                                                                                                                     |
| `authenticationStrategy` | [`AuthenticationStrategy`](#authenticationstrategy) | Determines the authentication mechanism for users to perform a transfer. In all scenarios, the user will still be required to perform two-factor authentication (2FA) and, in some cases provide email/password. If omitted, this will default to `.walletVerification`. |

#### `Network`

A [CAIP-2](https://chainagnostic.org/CAIPs/caip-2) network identifier.

<sub>kind: `enum`</sub>

- `ethereumMainnet`: `"eip155:1"`
- `solanaMainnet`: `"solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp"`
- `polygonMainnet`: `"eip155:137"`

#### `Asset`

<sub>kind: `enum`</sub>

- `sol`: Solana
- `eth`: Ethereum
- `usdc`: USDC

#### `Environment`

<sub>kind: `enum`</sub>

|              | Description                                                                                                 |
| ------------ | ----------------------------------------------------------------------------------------------------------- |
| `sandbox`    | In this environment, no crypto assets are transferred and no fiat assets are moved.                         |
| `production` | In this environment, production networks will be used to transfer real crypto assets. Fiat assets are moved |

#### `AuthenticationStrategy`

<sub>kind: `enum`</sub>

|                              | Description                                                                                                                                                                                                                          |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `walletVerification`         | Verify wallet by signing a message. New users and returning users with new wallets will still need to perform 2FA and login with email/password.                                                                                     |
| `headlessWalletVerification` | Verify a wallet by signing a message in the background _without_ prompting the user. This is useful for scenarios such as embedded wallets. New users and returning users with new wallets will still need to perform login and 2FA. |
| `bypassWalletVerification`   | Bypass wallet signing altogether and rely only on email/password and 2FA. This is useful for cases where pre-deployment smart contract wallets are being used and wallet verification cannot be performed.                           |

### Events

The `meso` instance will dispatch events at various points in the lifecycle of a Transfer session.

You can handle these events like so:

```swift
meso.on { event in
    switch event {
    case .configurationError(let payload):
        print("[Configuration Error]: \(payload)")
    case .unsupportedAssetError(let payload):
        print("[Unsupported Asset Error]: \(payload)")
    case .unsupportedNetworkError(let payload):
        print("[Unsupported Network Error]: \(payload)")
    case .requestSignedMessage(let payload, let callback):
        // This demonstrates a generic method of signing messages with Solana wallets. In the real world, you would
        // typically use a library or your own signing implementation.
        // If the user cancels or rejects signing, or there is a failure, return nil – `callback(nil)`
        callback(signMessage(messageToSign: payload.messageToSign))
    case .close:
        showMeso = false
    case .transferApproved(let payload):
        print("Handling `transferApproved` \(payload.transfer.id), \(payload.transfer.status)")
    case .transferComplete(let payload):
        let networkTransactionId = payload.transfer.networkTransactionId ?? "unknown"
        print("Transfer complete! mesoId: \(payload.transfer.id), networkTransactionId: \(networkTransactionId)")
        showMeso = false
    default:
        print("Unknown or discarded event")
    }
}
```

Each `event` is a `MesoEvent` and will provide one of the following payloads:

|                                                                                                            | Description                                                                                                                                                                                                                                                                                              |
| ---------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `transferApproved(payload: TransferPayload)`                                                               | The Transfer has been approved and will have a status of `TransferStatus.approved`                                                                                                                                                                                                                       |
| `transferComplete(payload: TransferPayload)`                                                               | The Transfer is complete, funds have moved, and will have a status of `TransferStatus.complete`                                                                                                                                                                                                          |
| `error(payload: ErrorPayload)`                                                                             | An error occurred in the application. A client-friendly error will be surfaced.                                                                                                                                                                                                                          |
| `configurationError(payload: ErrorPayload)`                                                                | The configuration is malformed and values may need to be updated. See [`ErrorPayload`](#errorpayload)                                                                                                                                                                                                    |
| `unsupportedNetworkError(payload: ErrorPayload)`                                                           | The provided [network](#network) is not currently supported by Meso. See [`ErrorPayload`](#errorpayload)                                                                                                                                                                                                 |
| `unsupportedAssetError(payload: ErrorPayload)`                                                             | The provided [asset](#asset) is not currently supported by Meso. See [`ErrorPayload`](#errorpayload)                                                                                                                                                                                                     |
| `requestSignedMessage(payload: RequestSignedMessagePayload, callback: (_ signedMessage: String?) -> Void)` | The Meso window has requested a message to be signed to prove ownership of a wallet. Upon signing, this callback can be used to return the signed message.<br /><br />If no `String` is returned in the callback, it is assumed the user canceled or rejected the message signing or there was an error. |
| `close`                                                                                                    | The user has manually opted to close the Meso window.                                                                                                                                                                                                                                                    |

#### `TransferPayload`

A wrapped result of a transfer status update to be sent to the partner application.

| Properties | Description |
| `transfer` | Transfer |

#### `Transfer`

Details of a Meso transfer.

| Property               | Type                                | Description                                                                                                                                    |
| ---------------------- | ----------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `id`                   | `String`                            | The Meso `id` for this `transfer`.                                                                                                             |
| `status`               | [`TransferStatus`](#transferstatus) | The status of the `transfer`.                                                                                                                  |
| `updatedAt`            | `String`                            | An [ISO-8601](https://en.wikipedia.org/wiki/ISO_8601) date string.                                                                             |
| `networkTransactionId` | `String?`                           | The on-chain identifier for the transfer.<br/><br/>**Note:** This will only be available for transfers that are [`complete`](#transferstatus). |

#### `TransferStatus`

<sub>kind: `enum`</sub>

|             | Description                                                                                                            |
| ----------- | ---------------------------------------------------------------------------------------------------------------------- |
| `approved`  | The [transfer](#transfer) has been approved and is pending completion. At this point, funds have _not_ yet been moved. |
| `complete`  | The [transfer](#transfer) is complete and the user's funds are available.                                              |
| `declined`  | The [transfer](#transfer) has failed.                                                                                  |
| `executing` | The [transfer](#transfer) is in flight.                                                                                |

#### `ErrorPayload`

|           | Type     | Description                      |
| --------- | -------- | -------------------------------- |
| `message` | `String` | A client-friendly error message. |

#### `RequestSignedMessagePayload`

The payload received when the `webView` prompts for a wallet signature.

|                 | Type     | Description                                                      |
| --------------- | -------- | ---------------------------------------------------------------- |
| `messageToSign` | `String` | An opaque message to be signed via an action in the Meso window. |

### Testing values

In sandbox, you can use the following values for testing:

- [`transfer`](#transfer) configuration
  - [`sourceAmount`](#transfer)
    - `"666.66"` will cause onboarding to fail due to risk checks and the user
      will be frozen
    - `"666.06"` will fail the transfer with the payment being declined
- 2FA (SMS)
  - `000000` will succeed
- Onboarding values
  - Debit Card
    - Number: `5305484748800098`
    - CVV: `435`
    - Expiration Date: `12/2025`
  - Taxpayer ID (last 4 digits of SSN)
    - `0000` will require the user enter a fully valid SSN (you can use `123345432`).
    - Any other 4-digit combination will pass

### Supported versions

While the example application targets iOS 15+, Meso should work with iOS 13-14.

### Caveats

- You will have to implement your own message signing mechanism. For this demo, we have roughed one in for Solana.
- The demo code contains print statements, which you can remove according to your requirements.
