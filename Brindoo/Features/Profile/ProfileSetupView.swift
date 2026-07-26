//
//  ProfileSetupView.swift
//  Brindoo
//
//  Schermata mostrata dopo il login se il profilo non è completo.
//  In 2 step l'utente sceglie il ruolo (cliente/organizzatore) e
//  inserisce i dati base (nome e città).
//

import SwiftUI

struct ProfileSetupView: View {

    @Environment(SessionStore.self) private var session

    @State private var currentStep: SetupStep = .role
    @State private var selectedRole: UserRole = .client
    @State private var fullName: String = ""
    @State private var city: String = ""
    @State private var selectedProvince: LazioProvince? = nil
    @State private var phone: String = ""

    @State private var fullNameError: String?
    @State private var cityError: String?
    @State private var provinceError: String?
    @State private var generalError: String?
    @State private var isLoading: Bool = false

    enum SetupStep: Int {
        case role = 0
        case info = 1
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brindooBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    progressBar
                        .padding(.top, BrindooSpacing.md)
                        .padding(.horizontal, BrindooSpacing.lg)

                    ScrollView {
                        Group {
                            switch currentStep {
                            case .role:
                                roleStepView
                            case .info:
                                infoStepView
                            }
                        }
                        .padding(.horizontal, BrindooSpacing.lg)
                        .padding(.top, BrindooSpacing.xl)
                    }
                    .scrollDismissesKeyboard(.interactively)

                    footerButtons
                        .padding(.horizontal, BrindooSpacing.lg)
                        .padding(.bottom, BrindooSpacing.lg)
                        .padding(.top, BrindooSpacing.sm)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await session.signOut() }
                    } label: {
                        Text("Esci")
                            .font(BrindooFont.bodyMedium.weight(.medium))
                            .foregroundStyle(Color.brindooTextSecondary)
                    }
                }
            }
        }
    }

    // MARK: - Progress bar

    @ViewBuilder
    private var progressBar: some View {
        HStack(spacing: BrindooSpacing.xs) {
            ForEach(0..<2, id: \.self) { index in
                Capsule()
                    .fill(index <= currentStep.rawValue ? Color.brindooCoral : Color.brindooBorder)
                    .frame(height: 4)
                    .animation(.easeInOut(duration: 0.3), value: currentStep)
            }
        }
    }

    // MARK: - Step 1: Scelta ruolo

    @ViewBuilder
    private var roleStepView: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.lg) {

            VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
                Text("Come usi Brindoo?")
                    .font(BrindooFont.displayMedium)
                    .foregroundStyle(Color.brindooTextPrimary)

                Text("Potrai cambiare scelta in qualsiasi momento dalle impostazioni")
                    .font(BrindooFont.bodyLarge)
                    .foregroundStyle(Color.brindooTextSecondary)
            }

            VStack(spacing: BrindooSpacing.md) {
                ForEach(UserRole.allCases) { role in
                    roleCard(role)
                }
            }
            .padding(.top, BrindooSpacing.sm)
        }
    }

    @ViewBuilder
    private func roleCard(_ role: UserRole) -> some View {
        let isSelected = selectedRole == role

        Button {
            withAnimation(.spring(response: 0.3)) {
                selectedRole = role
            }
        } label: {
            HStack(spacing: BrindooSpacing.md) {

                ZStack {
                    Circle()
                        .fill(isSelected ? Color.brindooCoral : Color.brindooSurface)
                        .frame(width: 52, height: 52)

                    Image(systemName: role.iconName)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(isSelected ? .white : Color.brindooCoral)
                }

                VStack(alignment: .leading, spacing: BrindooSpacing.xxs) {
                    Text(role.displayName)
                        .font(BrindooFont.titleMedium)
                        .foregroundStyle(Color.brindooTextPrimary)

                    Text(role.description)
                        .font(BrindooFont.bodySmall)
                        .foregroundStyle(Color.brindooTextSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? Color.brindooCoral : Color.brindooBorder)
            }
            .padding(BrindooSpacing.md)
            .background(Color.brindooSurface)
            .overlay(
                RoundedRectangle(cornerRadius: BrindooRadius.lg)
                    .strokeBorder(
                        isSelected ? Color.brindooCoral : Color.clear,
                        lineWidth: 2
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.lg))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 2: Info personali

    @ViewBuilder
    private var infoStepView: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.lg) {

            VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
                Text(selectedRole == .organizer ? "Presentati" : "Parlaci di te")
                    .font(BrindooFont.displayMedium)
                    .foregroundStyle(Color.brindooTextPrimary)

                Text(selectedRole == .organizer
                     ? "I clienti vedranno questi dati sul tuo profilo pubblico"
                     : "Ci aiuta a personalizzare la tua esperienza")
                    .font(BrindooFont.bodyLarge)
                    .foregroundStyle(Color.brindooTextSecondary)
            }

            VStack(spacing: BrindooSpacing.md) {
                BrindooTextField(
                    title: selectedRole == .organizer ? "Nome o nome dell'attività" : "Nome e cognome",
                    placeholder: selectedRole == .organizer ? "Es. Mario Rossi Eventi" : "Es. Mario Rossi",
                    text: $fullName,
                    icon: "person",
                    textContentType: .name,
                    autocapitalization: .words,
                    errorMessage: fullNameError,
                    isDisabled: isLoading
                )

                ComuneField(
                    city: $city,
                    province: $selectedProvince,
                    error: cityError,
                    isDisabled: isLoading
                )

                provincePickerSection

                BrindooTextField(
                    title: "Telefono (opzionale)",
                    placeholder: "Es. 333 1234567",
                    text: $phone,
                    icon: "phone",
                    keyboardType: .phonePad,
                    textContentType: .telephoneNumber,
                    autocapitalization: .never,
                    isDisabled: isLoading
                )
            }

            if let generalError {
                HStack(spacing: BrindooSpacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(generalError)
                        .font(BrindooFont.bodySmall)
                }
                .foregroundStyle(Color.brindooError)
                .padding(BrindooSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.brindooError.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
            }
        }
    }

    // MARK: - Province picker

    @ViewBuilder
    private var provincePickerSection: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
            Text("Provincia")
                .font(BrindooFont.bodySmall.weight(.medium))
                .foregroundStyle(Color.brindooTextSecondary)

            HStack(spacing: BrindooSpacing.xs) {
                ForEach(LazioProvince.allCases) { province in
                    let isSelected = selectedProvince == province
                    Button {
                        selectedProvince = province
                        provinceError = nil
                    } label: {
                        VStack(spacing: 2) {
                            Text(province.rawValue)
                                .font(BrindooFont.bodySmall.weight(.bold))
                            Text(province.displayName)
                                .font(.system(size: 10))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, BrindooSpacing.xs)
                        .foregroundStyle(isSelected ? .white : Color.brindooCoral)
                        .background(isSelected ? Color.brindooCoral : Color.brindooCoral.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
                    }
                    .disabled(isLoading)
                }
            }

            if let provinceError {
                Text(provinceError)
                    .font(BrindooFont.caption)
                    .foregroundStyle(Color.brindooError)
            } else {
                Text("Brindoo è disponibile in tutto il \(CityValidator.allowedRegionDisplay).")
                    .font(BrindooFont.caption)
                    .foregroundStyle(Color.brindooTextSecondary)
            }
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var footerButtons: some View {
        HStack(spacing: BrindooSpacing.sm) {

            if currentStep == .info {
                BrindooButton(
                    "Indietro",
                    style: .secondary,
                    size: .large
                ) {
                    withAnimation { currentStep = .role }
                }
                .frame(maxWidth: 120)
            }

            BrindooButton(
                currentStep == .role ? "Continua" : "Completa",
                style: .primary,
                size: .large,
                icon: currentStep == .role ? "arrow.right" : nil,
                isLoading: isLoading
            ) {
                handleNext()
            }
        }
    }

    // MARK: - Logica

    private func handleNext() {
        switch currentStep {
        case .role:
            withAnimation { currentStep = .info }
        case .info:
            Task { await saveProfile() }
        }
    }

    private func saveProfile() async {
        fullNameError = nil
        cityError = nil
        provinceError = nil
        generalError = nil

        var hasError = false
        let trimmedName = fullName.trimmingCharacters(in: .whitespaces)
        let trimmedCity = city.trimmingCharacters(in: .whitespaces)

        if trimmedName.isEmpty {
            fullNameError = "Inserisci il tuo nome"
            hasError = true
        } else if trimmedName.count < 2 {
            fullNameError = "Il nome è troppo corto"
            hasError = true
        }

        if trimmedCity.isEmpty {
            cityError = "Inserisci la tua città"
            hasError = true
        }

        guard let province = selectedProvince else {
            provinceError = "Seleziona la tua provincia"
            if !hasError { hasError = true }
            return
        }

        if let validationError = CityValidator.validate(city: trimmedCity, province: province) {
            cityError = validationError
            hasError = true
        }

        if hasError { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let trimmedPhone = phone.trimmingCharacters(in: .whitespaces)
            let update = ProfileUpdate(
                role: selectedRole,
                fullName: trimmedName,
                phone: trimmedPhone.isEmpty ? nil : trimmedPhone,
                city: CityValidator.normalizedCity(trimmedCity),
                province: province,
                bio: nil
            )

            let updatedProfile = try await ProfileService.shared.updateCurrentProfile(update)

            // Aggiorna il SessionStore (cambia authState a .signedIn → MainTabView)
            session.updateLocalProfile(updatedProfile)

        } catch {
            generalError = "Impossibile salvare il profilo. Controlla la connessione e riprova."
            BrindooLog.error("Errore salvataggio profilo: \(error)")
        }
    }
}

#Preview {
    ProfileSetupView()
        .environment(SessionStore())
}
