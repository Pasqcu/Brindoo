//
//  AppleSignInHelper.swift
//  Brindoo
//
//  Helper per Sign in with Apple. Genera nonce sicuri e
//  gestisce la conversione delle credenziali in token JWT
//  da inviare a Supabase.
//

import Foundation
import AuthenticationServices
import CryptoKit

enum AppleSignInHelper {
    
    /// Genera una stringa random sicura usata come "nonce" per la sicurezza del flusso OAuth.
    /// Il nonce hashato viene inviato ad Apple, e Apple lo include nel JWT firmato.
    /// Supabase verifica che il nonce nel token corrisponda a quello che inviamo, prevenendo replay attack.
    static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 { return }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    /// SHA256 del nonce, da inviare ad Apple
    static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        return hashString
    }
}

// MARK: - Errori

enum AppleSignInError: LocalizedError {
    case noTokenFromApple
    case invalidTokenEncoding
    case userCancelled
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .noTokenFromApple:
            return "Apple non ha fornito il token di accesso"
        case .invalidTokenEncoding:
            return "Token Apple non valido"
        case .userCancelled:
            return "Accesso annullato"
        case .unknown(let msg):
            return msg
        }
    }
}
