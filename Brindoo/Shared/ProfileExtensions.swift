//
//  ProfileExtensions.swift
//  Brindoo
//
//  Helper di display sul modello Profile.
//

import Foundation

extension Profile {
    /// Nome da mostrare nella UI: fullName se presente, altrimenti placeholder.
    var displayName: String {
        if let fullName, !fullName.trimmingCharacters(in: .whitespaces).isEmpty {
            return fullName
        }
        return role == .organizer ? "Organizzatore" : "Cliente"
    }

    /// Iniziali coerenti per avatar.
    var initials: String {
        let parts = displayName.split(separator: " ").prefix(2)
        return parts.compactMap { $0.first?.uppercased() }.joined()
    }
}
