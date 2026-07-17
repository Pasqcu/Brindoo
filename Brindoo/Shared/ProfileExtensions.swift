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

    /// True se manca (o è vecchia) l'accettazione dei Termini registrata sul server.
    var needsTermsAcceptance: Bool {
        termsAcceptedAt == nil || termsVersion != LegalVersion.current
    }

    /// True se il professionista non ha ancora confermato la dichiarazione.
    var needsProfessionalDeclaration: Bool {
        role == .organizer && professionalDeclarationAt == nil
    }

    /// Iniziali coerenti per avatar.
    var initials: String {
        let parts = displayName.split(separator: " ").prefix(2)
        return parts.compactMap { $0.first?.uppercased() }.joined()
    }
}
