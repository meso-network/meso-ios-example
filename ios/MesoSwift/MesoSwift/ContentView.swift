//
//  ContentView.swift
//  MesoSwift
//
//  Created by David Seeto on 11/9/23.
//

import SwiftUI
import WebKit
import Foundation

// Configure colors for the demo app
extension Color {
    // Default background color
    static let backgroundColor = Color("backgroundColor")
}

// "Componentized" style for demo app buttons
struct GridButton: ButtonStyle {
    public var active: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, 48)
            .background(active ? .blue :  .black)
            .foregroundStyle(.white)
            .cornerRadius(16)
    }
}

// This is just an example Solana address. You will need to input your own wallet.
let walletAddress = "EN9B5dFJSn78KMGMaP3CwshiRm6B82GnaDJrd7qEFig2"

struct ContentView: View {
    // State variable to control rendering of Meso
    @State private var showMeso = false
    @State private var transferAmount: Float = 50
    
    private var twoColumnGrid = [GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        ZStack {
            VStack(spacing: 24) {
                HStack {
                    VStack {
                        Text("Buy").font(.title2).foregroundColor(.white).fontWeight(.bold).frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 6)
                        HStack {
                            Image(systemName: "person.fill").foregroundColor(.white).font(.system(size: 12))
                            Text(walletAddress).font(Font
                                .system(size: 10)
                                .monospaced()
                            ).foregroundColor(.white).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    Spacer()
                    Image("MesoLogo")
                }
                
                LazyVGrid(columns: twoColumnGrid, content: {
                    Button("$50") {
                        transferAmount = 50
                    }.buttonStyle(GridButton(active: transferAmount == 50))
                    Button("$100") {
                        transferAmount = 100
                    }.buttonStyle(GridButton(active: transferAmount == 100))
                    Button("$200") {
                        transferAmount = 200
                    }.buttonStyle(GridButton(active: transferAmount == 200))
                    Button("$500") {
                        transferAmount = 500
                    }.buttonStyle(GridButton(active: transferAmount == 500))
                    Button("$1000") {
                        transferAmount = 1000
                    }.buttonStyle(GridButton(active: transferAmount == 1000))
                    Button("Other") {
                        print("Other is disabled.")
                    }.buttonStyle(GridButton(active: false)).disabled(true).opacity(0.5)
                })
                .frame(maxHeight: .infinity)
                
                VStack(alignment: .trailing, content: {
                    Button("Transfer $\(Int(transferAmount))") {
                        if !showMeso {
                            showMeso.toggle()
                        }
                    }
                    .disabled(showMeso)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(showMeso ? .gray : .white)
                    .clipShape(Capsule())
                    .opacity(showMeso ? 0.5 : 1)
                })
            }.frame(maxHeight: .infinity).padding().background(Color.backgroundColor)
            
            
            if showMeso {
                meso.transfer()
            }
        }
    }
    
    private var meso: Meso {
        // This is an example static configuration. Typically, this will by dynamically populated in your application at runtime.
        let mesoTransferConfiguration = MesoTransferConfiguration(
            partnerId: "meso-dev",
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
        
        return meso
    }
}

// Preview for ContentView
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
