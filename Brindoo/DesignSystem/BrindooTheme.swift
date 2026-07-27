//
//  BrindooTheme.swift
//  Brindoo
//
//  Sistema di design centrale: colori, spaziature, font, raggi.
//
//  ℹ️ I colori del brand (BrindooCoral, BrindooCoralLight, BrindooCoralDark)
//  sono generati automaticamente da Xcode dagli Asset Catalog.
//  Quindi puoi usare direttamente: Color.brindooCoral, Color.brindooCoralLight, ecc.
//

import SwiftUI
import UIKit

// MARK: - Colori di sistema (helper semantici)

extension Color {

    /// Sfondo principale dell'app
    static let brindooBackground = Color(.systemBackground)
    
    /// Sfondo secondario (card, sezioni)
    static let brindooSurface = Color(.secondarySystemBackground)
    
    /// Sfondo terziario (campi input)
    static let brindooSurfaceElevated = Color(.tertiarySystemBackground)
    
    /// Testo principale
    static let brindooTextPrimary = Color(.label)
    
    /// Testo secondario (descrizioni, hint)
    static let brindooTextSecondary = Color(.secondaryLabel)
    
    /// Testo terziario (placeholder)
    static let brindooTextTertiary = Color(.tertiaryLabel)
    
    /// Bordi e separatori
    static let brindooBorder = Color(.separator)
    
    /// Verde successo (prenotazione confermata). Più luminoso in modalità scura.
    static let brindooSuccess = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.30, green: 0.80, blue: 0.55, alpha: 1)
            : UIColor(red: 0.20, green: 0.70, blue: 0.45, alpha: 1)
    })

    /// Rosso errore (rifiuto, cancellazione). Più luminoso in modalità scura.
    static let brindooError = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 1.00, green: 0.45, blue: 0.45, alpha: 1)
            : UIColor(red: 0.90, green: 0.30, blue: 0.30, alpha: 1)
    })

    /// Oro/arancio del piano Pro (corona e accenti premium).
    static let brindooProGold = Color(red: 0.93, green: 0.55, blue: 0.20)

    /// Estremi del gradiente Pro. Erano ricopiati a mano in cinque schermate:
    /// bastava sbagliare una cifra per avere due ori diversi nella stessa app.
    static let brindooProGoldLight = Color(red: 0.95, green: 0.74, blue: 0.30)
    static let brindooProGoldDeep = Color(red: 0.93, green: 0.50, blue: 0.20)

    /// Testo/icona su fondo oro chiaro (contrasto sufficiente sul badge Pro).
    static let brindooProGoldInk = Color(red: 0.78, green: 0.45, blue: 0.10)

    /// Giallo warning (in attesa, pending). Più luminoso in modalità scura.
    static let brindooWarning = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 1.00, green: 0.78, blue: 0.35, alpha: 1)
            : UIColor(red: 0.95, green: 0.70, blue: 0.20, alpha: 1)
    })

    /// Colore distintivo per una categoria di servizio (in base allo slug).
    /// Aiuta a orientare l'occhio nella bacheca senza appiattire tutto sul corallo.
    static func brindooCategory(_ slug: String) -> Color {
        switch slug.lowercased() {
        case "animation", "animazione":            return Color(red: 0.95, green: 0.45, blue: 0.35) // corallo caldo
        case "photo", "foto", "video", "foto-video": return Color(red: 0.40, green: 0.50, blue: 0.85) // blu/indaco
        case "catering", "food":                    return Color(red: 0.90, green: 0.60, blue: 0.20) // ambra
        case "music", "musica", "dj", "music-dj":   return Color(red: 0.55, green: 0.40, blue: 0.80) // viola
        case "location", "venue", "sale":           return Color(red: 0.20, green: 0.65, blue: 0.55) // verde acqua
        case "decor", "decorazioni", "allestimenti": return Color(red: 0.85, green: 0.40, blue: 0.60) // rosa
        case "cake", "torte", "pasticceria":        return Color(red: 0.80, green: 0.50, blue: 0.45) // terracotta
        case "transport", "trasporti", "noleggio":  return Color(red: 0.35, green: 0.55, blue: 0.70) // azzurro
        default:                                     return .brindooCoral
        }
    }
}

// MARK: - Spaziature

enum BrindooSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48
}

// MARK: - Raggi

enum BrindooRadius {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let pill: CGFloat = 999
}

// MARK: - Font
//
// I font sono "scalabili": rispettano la dimensione del testo scelta dall'utente
// nelle impostazioni di sistema (Dynamic Type / accessibilità). Vengono ancorati
// allo stile di testo più vicino tramite UIFontMetrics, mantenendo design e peso.

private func brindooScaledFont(
    size: CGFloat,
    weight: UIFont.Weight,
    rounded: Bool,
    relativeTo textStyle: UIFont.TextStyle
) -> Font {
    let base: UIFont
    if rounded,
       let descriptor = UIFont.systemFont(ofSize: size, weight: weight)
        .fontDescriptor.withDesign(.rounded) {
        base = UIFont(descriptor: descriptor, size: size)
    } else {
        base = UIFont.systemFont(ofSize: size, weight: weight)
    }
    let scaled = UIFontMetrics(forTextStyle: textStyle).scaledFont(for: base)
    return Font(scaled as CTFont)
}

enum BrindooFont {
    static let displayLarge  = brindooScaledFont(size: 34, weight: .bold,     rounded: true,  relativeTo: .largeTitle)
    static let displayMedium = brindooScaledFont(size: 28, weight: .bold,     rounded: true,  relativeTo: .title1)
    static let titleLarge    = brindooScaledFont(size: 22, weight: .semibold, rounded: true,  relativeTo: .title2)
    static let titleMedium   = brindooScaledFont(size: 18, weight: .semibold, rounded: true,  relativeTo: .title3)
    static let titleSmall    = brindooScaledFont(size: 16, weight: .semibold, rounded: true,  relativeTo: .headline)
    static let bodyLarge     = brindooScaledFont(size: 17, weight: .regular,  rounded: false, relativeTo: .body)
    static let bodyMedium    = brindooScaledFont(size: 15, weight: .regular,  rounded: false, relativeTo: .subheadline)
    static let bodySmall     = brindooScaledFont(size: 13, weight: .regular,  rounded: false, relativeTo: .footnote)
    static let caption       = brindooScaledFont(size: 12, weight: .medium,   rounded: false, relativeTo: .caption1)
    static let button        = brindooScaledFont(size: 16, weight: .semibold, rounded: true,  relativeTo: .headline)
    static let buttonSmall   = brindooScaledFont(size: 14, weight: .semibold, rounded: true,  relativeTo: .subheadline)

    /// Font di dimensione libera che continua a rispettare la scelta di
    /// grandezza del testo fatta nelle impostazioni del telefono.
    /// Da preferire sempre a `.system(size:)` su un testo: quello resta fisso
    /// e per chi legge in grande diventa illeggibile.
    static func scaled(
        _ size: CGFloat,
        weight: UIFont.Weight = .regular,
        rounded: Bool = false,
        relativeTo textStyle: UIFont.TextStyle = .body
    ) -> Font {
        brindooScaledFont(size: size, weight: weight, rounded: rounded, relativeTo: textStyle)
    }
}

// MARK: - Ombre

// Tre livelli di profondità invece di uno solo: l'occhio capisce subito
// cosa sta "sopra" a cosa (card normale < card in evidenza < pannello).
enum BrindooElevation {
    case flat      // elementi a filo di sfondo
    case card      // card standard di lista
    case raised    // card in evidenza (Boost, vetrina, selezionata)
    case overlay   // pannelli, barre fluttuanti, menù

    var color: Color {
        switch self {
        case .flat:    return .clear
        case .card:    return Color.black.opacity(0.06)
        case .raised:  return Color.black.opacity(0.12)
        case .overlay: return Color.black.opacity(0.18)
        }
    }

    var radius: CGFloat {
        switch self {
        case .flat: return 0
        case .card: return 8
        case .raised: return 16
        case .overlay: return 24
        }
    }

    var y: CGFloat {
        switch self {
        case .flat: return 0
        case .card: return 2
        case .raised: return 6
        case .overlay: return 10
        }
    }
}

enum BrindooShadow {
    static let cardShadowColor = BrindooElevation.card.color
    static let cardShadowRadius = BrindooElevation.card.radius
    static let cardShadowY = BrindooElevation.card.y
}

// MARK: - Modifier helper

extension View {
    /// Applica l'ombra standard delle card
    func brindooCardShadow() -> some View {
        brindooElevation(.card)
    }

    /// Applica il livello di profondità scelto.
    func brindooElevation(_ level: BrindooElevation) -> some View {
        self.shadow(color: level.color, radius: level.radius, x: 0, y: level.y)
    }
    
    /// Padding orizzontale standard schermata
    func brindooScreenPadding() -> some View {
        self.padding(.horizontal, BrindooSpacing.md)
    }

    /// Limita la larghezza dei contenuti su schermi grandi (iPad), restando centrati.
    func brindooReadableWidth(_ maxWidth: CGFloat = 680) -> some View {
        self
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}
