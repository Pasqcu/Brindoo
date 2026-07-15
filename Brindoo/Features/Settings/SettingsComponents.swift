//
//  SettingsComponents.swift
//  Brindoo
//
//  Mattoncini riusabili della schermata Impostazioni:
//  sezione con titolo, righe (semplice e con toggle), card promo e card vacanza.
//

import SwiftUI

// MARK: - Sezione con titolo maiuscolo

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
            Text(title)
                .font(BrindooFont.bodySmall.weight(.semibold))
                .foregroundStyle(Color.brindooTextSecondary)
                .textCase(.uppercase)
                .padding(.leading, BrindooSpacing.xs)
            content
        }
    }
}

// MARK: - Riga generica (icona, titolo, sottotitolo, chevron)

struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var subtitle: String? = nil
    var titleColor: Color = .brindooTextPrimary

    var body: some View {
        HStack(spacing: BrindooSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(iconColor)
                .frame(width: 32, height: 32)
                .background(iconColor.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BrindooFont.bodyMedium)
                    .foregroundStyle(titleColor)
                if let subtitle {
                    Text(subtitle)
                        .font(BrindooFont.caption)
                        .foregroundStyle(Color.brindooTextSecondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(Color.brindooTextSecondary)
        }
        .padding(.horizontal, BrindooSpacing.md)
        .padding(.vertical, BrindooSpacing.sm)
        .contentShape(Rectangle())
    }
}

// MARK: - Riga con toggle

struct SettingsToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: BrindooSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(iconColor)
                .frame(width: 32, height: 32)
                .background(iconColor.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BrindooFont.bodyMedium)
                if let subtitle {
                    Text(subtitle)
                        .font(BrindooFont.caption)
                        .foregroundStyle(Color.brindooTextSecondary)
                }
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Color.brindooCoral)
        }
        .padding(.horizontal, BrindooSpacing.md)
        .padding(.vertical, BrindooSpacing.sm)
    }
}

// MARK: - Card promo (Pro, Boost, Diventa Professionista)

struct SettingsPromoCard: View {
    enum IconStyle {
        /// Cerchio con gradiente pieno e simbolo bianco.
        case gradient([Color])
        /// Cerchio tinta chiara e simbolo colorato.
        case tinted(Color)
    }

    let icon: String
    let iconStyle: IconStyle
    let title: String
    /// Etichetta tipo "ATTIVO" accanto al titolo (facoltativa).
    var badgeText: String? = nil
    let subtitle: String

    var body: some View {
        HStack(spacing: BrindooSpacing.sm) {
            ZStack {
                switch iconStyle {
                case .gradient(let colors):
                    LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                case .tinted(let color):
                    color.opacity(0.15)
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundStyle(color)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(BrindooFont.bodyMedium.weight(.semibold))
                    if let badgeText {
                        Text(badgeText)
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.brindooSuccess)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }
                Text(subtitle)
                    .font(BrindooFont.caption)
                    .foregroundStyle(Color.brindooTextSecondary)
                    .lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundStyle(Color.brindooTextSecondary)
        }
        .padding(BrindooSpacing.sm)
        .background(Color.brindooSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
    }
}

// MARK: - Card modalità vacanza (organizzatori, Pro-only)

struct SettingsVacationCard: View {
    let isPro: Bool
    let saving: Bool
    @Binding var vacationOn: Bool
    @Binding var vacationUntil: Date
    /// Chiamata quando cambia toggle o data di ritorno.
    var onChange: (Bool) -> Void
    /// Chiamata dal bottone "Passa a Pro" (utenti non Pro).
    var onUpgradeTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
            // Riga principale con toggle (o lock se non Pro)
            HStack(spacing: BrindooSpacing.sm) {
                ZStack {
                    Color.brindooCoral.opacity(0.15)
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                    Image(systemName: "beach.umbrella.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.brindooCoral)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Sono in vacanza")
                            .font(BrindooFont.bodyMedium.weight(.semibold))
                        if !isPro {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.brindooTextSecondary)
                        }
                    }
                    Text(isPro
                        ? "Le tue offerte saranno nascoste ai clienti"
                        : "Disponibile con Brindoo Pro")
                        .font(BrindooFont.caption)
                        .foregroundStyle(Color.brindooTextSecondary)
                }
                Spacer()

                if isPro {
                    Toggle("", isOn: $vacationOn)
                        .labelsHidden()
                        .tint(Color.brindooCoral)
                        .disabled(saving)
                        .onChange(of: vacationOn) { _, on in
                            onChange(on)
                        }
                } else {
                    Button {
                        onUpgradeTap()
                    } label: {
                        Text("Passa a Pro")
                            .font(BrindooFont.bodySmall.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, BrindooSpacing.sm)
                            .padding(.vertical, 6)
                            .background(Color.brindooCoral)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(BrindooSpacing.md)
            .background(Color.brindooSurface)
            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))

            // DatePicker per la data di ritorno (visibile solo se attiva)
            if isPro && vacationOn {
                HStack {
                    Text("Torno il")
                        .font(BrindooFont.bodyMedium)
                    Spacer()
                    DatePicker(
                        "",
                        selection: $vacationUntil,
                        in: Date()...,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "it_IT"))
                    .onChange(of: vacationUntil) { _, _ in
                        onChange(true)
                    }
                }
                .padding(BrindooSpacing.md)
                .background(Color.brindooSurface)
                .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
            }
        }
    }
}
