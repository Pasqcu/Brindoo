//
//  BrindooHaptics.swift
//  Brindoo
//
//  Wrapper sicuro per il feedback aptico (solo iOS, no-op altrove).
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum BrindooHaptics {
    enum Impact { case light, medium, heavy, soft, rigid }
    enum Notification { case success, warning, error }

    static func impact(_ style: Impact = .light) {
        #if canImport(UIKit)
        let generator: UIImpactFeedbackGenerator
        switch style {
        case .light:  generator = UIImpactFeedbackGenerator(style: .light)
        case .medium: generator = UIImpactFeedbackGenerator(style: .medium)
        case .heavy:  generator = UIImpactFeedbackGenerator(style: .heavy)
        case .soft:   generator = UIImpactFeedbackGenerator(style: .soft)
        case .rigid:  generator = UIImpactFeedbackGenerator(style: .rigid)
        }
        generator.prepare()
        generator.impactOccurred()
        #endif
    }

    static func notify(_ type: Notification) {
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        switch type {
        case .success: generator.notificationOccurred(.success)
        case .warning: generator.notificationOccurred(.warning)
        case .error:   generator.notificationOccurred(.error)
        }
        #endif
    }

    static func selection() {
        #if canImport(UIKit)
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
        #endif
    }
}
