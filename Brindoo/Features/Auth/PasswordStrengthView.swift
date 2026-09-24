//
//  PasswordStrengthView.swift
//  Brindoo
//
//  Barra di robustezza e lista dei requisiti della password, uguale in
//  registrazione e nella scelta della nuova password dopo il reset.
//

import SwiftUI

struct PasswordStrengthView: View {
    let validation: PasswordValidation

    var body: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
            HStack(spacing: 4) {
                ForEach(0..<PasswordValidation.criteriaCount, id: \.self) { index in
                    Rectangle()
                        .fill(index < validation.strengthLevel ? strengthColor : Color.brindooBorder)
                        .frame(height: 4)
                        .clipShape(Capsule())
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                requirementRow("Almeno 8 caratteri", met: validation.hasMinLength)
                requirementRow("Almeno una lettera maiuscola", met: validation.hasUppercase)
                requirementRow("Almeno una lettera minuscola", met: validation.hasLowercase)
                requirementRow("Almeno un numero", met: validation.hasNumber)
                requirementRow("Almeno un carattere speciale (es. !@#$)", met: validation.hasSpecialChar)
            }
        }
        .padding(BrindooSpacing.sm)
        .brindooSurfaceBackground(radius: BrindooRadius.sm)
    }

    private var strengthColor: Color {
        switch validation.strengthLevel {
        case 0...2: return .brindooError
        case PasswordValidation.criteriaCount: return .brindooSuccess
        default: return .brindooWarning
        }
    }

    private func requirementRow(_ text: String, met: Bool) -> some View {
        HStack(spacing: BrindooSpacing.xxs) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 12))
                .foregroundStyle(met ? Color.brindooSuccess : Color.brindooTextSecondary)
            Text(text)
                .font(BrindooFont.caption)
                .foregroundStyle(met ? Color.brindooTextPrimary : Color.brindooTextSecondary)
        }
    }
}
