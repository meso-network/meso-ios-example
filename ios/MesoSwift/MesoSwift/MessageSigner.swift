//
//  MessageSigner.swift
//  MesoSwift
//
//  An example message signing implementation for Solana wallets.
//

import Foundation

let base58Alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

func base58Encode(_ bytes: [UInt8]) -> String {
    var zeroes = 0
    var length = 0
    
    // Count leading zeroes
    for byte in bytes {
        if byte == 0 {
            zeroes += 1
        } else {
            break
        }
    }
    
    // Allocate enough space in big-endian base58 representation
    let size = bytes.count * 138 / 100 + 1 // log(256) / log(58), rounded up
    var bigEndianBase58: [UInt8] = Array(repeating: 0, count: size)
    
    // Process the bytes
    for byte in bytes {
        var carry = Int(byte)
        var i = 0
        
        // Apply "bignum" conversion algorithm
        for j in 0...bigEndianBase58.count where carry != 0 || i < length {
            carry += 256 * Int(bigEndianBase58[j])
            bigEndianBase58[j] = UInt8(carry % 58)
            carry /= 58
            i += 1
        }
        
        assert(carry == 0)
        
        length = i
    }
    
    // Skip leading zeroes in base58 result
    var zeroCount = 0
    while zeroCount < bigEndianBase58.count && bigEndianBase58[zeroCount] == 0 {
        zeroCount += 1
    }
    
    // Translate the result into a string
    var result = String(repeating: "1", count: zeroes)
    for p in bigEndianBase58[zeroCount...] {
        result.append(base58Alphabet[String.Index(utf16Offset: Int(p), in: base58Alphabet)])
    }
    
    return result
}

// Extension to encode data to a Base58 string
extension Data {
    func base58EncodedString() -> String {
        return base58Encode([UInt8](self))
    }
}

extension String {
    func base58EncodedString() -> String {
        guard let data = self.data(using: .utf8) else {
            return ""
        }
        return data.base58EncodedString()
    }
}

/// A "simple" implementation of signing a message for a Solana wallet.
public func signMessage(messageToSign: String) -> String {
    return messageToSign.base58EncodedString()
}
