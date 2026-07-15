//
//  EditProfileView.swift
//  Brindoo
//
//  Sheet per modificare il proprio profilo (anche categorie e descrizioni
//  per gli organizzatori) e l'avatar.
//

import SwiftUI
import PhotosUI

struct EditProfileView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @EnvironmentObject private var toasts: BrindooToastCenter

    /// True quando la view è presentata subito dopo l'upgrade a Professionista.
    /// In questa modalità:
    /// - la chiusura libera è disabilitata
    /// - compare il bottone "Annulla operazione" che ripristina il ruolo Cliente
    /// - il titolo cambia in "Completa il tuo profilo"
    var isPostUpgrade: Bool = false

    /// Callback chiamato quando la view post-upgrade viene chiusa:
    /// `didCancel = true` se l'utente ha annullato l'operazione, altrimenti
    /// `false` (ha completato e salvato).
    var onPostUpgradeExit: ((Bool) -> Void)?

    @State private var fullName: String = ""
    @State private var city: String = ""
    @State private var selectedProvince: LazioProvince? = nil
    @State private var phone: String = ""
    @State private var bio: String = ""

    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var newAvatarImage: UIImage?
    @State private var isUploadingAvatar: Bool = false

    @State private var allCategories: [ServiceCategory] = []
    @State private var selectedCategoryIds: Set<UUID> = []
    @State private var categoryDescriptions: [UUID: String] = [:]
    @State private var initialCategoryIds: Set<UUID> = []
    @State private var initialCategoryDescriptions: [UUID: String] = [:]

    @State private var selectedAreaSlugs: Set<String> = []
    @State private var initialAreaSlugs: Set<String> = []

    @State private var fullNameError: String?
    @State private var cityError: String?
    @State private var provinceError: String?
    @State private var generalError: String?
    @State private var isLoading: Bool = false
    @State private var isLoadingInitial: Bool = true
    @State private var showSuccessToast: Bool = false
    @State private var expandedCategoryId: UUID? = nil
    @State private var showCancelUpgradeConfirm: Bool = false
    @State private var isCancellingUpgrade: Bool = false


    private var isOrganizer: Bool {
        session.currentProfile?.role == .organizer
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                if isLoadingInitial {
                    VStack {
                        Spacer()
                        ProgressView().tint(.brindooCoral)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    formContent
                }

                if showSuccessToast {
                    successToast
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, BrindooSpacing.md)
                        .zIndex(1)
                }
            }
            .background(Color.brindooBackground)
            .navigationTitle(isPostUpgrade ? "Completa il tuo profilo" : "Modifica profilo")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isPostUpgrade)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isPostUpgrade {
                        Button(role: .destructive) {
                            showCancelUpgradeConfirm = true
                        } label: {
                            Text("Annulla operazione")
                                .font(BrindooFont.bodyMedium.weight(.medium))
                        }
                        .disabled(isLoading || isCancellingUpgrade)
                    } else {
                        Button("Annulla") { dismiss() }
                            .disabled(isLoading)
                    }
                }
            }
            .confirmationDialog(
                "Annulla il passaggio a Professionista?",
                isPresented: $showCancelUpgradeConfirm,
                titleVisibility: .visible
            ) {
                Button("Sì, torna cliente", role: .destructive) {
                    Task { await cancelUpgrade() }
                }
                Button("No, continua", role: .cancel) {}
            } message: {
                Text("Tornerai a essere un cliente. Potrai ridiventare Professionista in futuro dalle Impostazioni.")
            }
            .safeAreaInset(edge: .bottom) {
                if !isLoadingInitial {
                    BrindooButton(
                        "Salva modifiche",
                        style: .primary,
                        size: .large,
                        isLoading: isLoading,
                        isDisabled: !hasChanges
                    ) {
                        Task { await save() }
                    }
                    .padding(.horizontal, BrindooSpacing.lg)
                    .padding(.vertical, BrindooSpacing.sm)
                    .background(
                        Color.brindooBackground
                            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: -2)
                    )
                }
            }
            .task { await loadInitialData() }
            .onChange(of: avatarPickerItem) { _, newItem in
                guard let newItem else { return }
                Task { await loadAvatarFromPicker(newItem) }
            }
        }
    }

    @ViewBuilder
    private var formContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrindooSpacing.lg) {
                if isPostUpgrade {
                    PostUpgradeBanner()
                }

                AvatarEditSection(
                    newAvatarImage: newAvatarImage,
                    avatarPickerItem: $avatarPickerItem,
                    currentAvatarUrl: session.currentProfile?.avatarUrl,
                    fallbackName: fullName.isEmpty ? session.currentProfile?.fullName : fullName,
                    isUploading: isUploadingAvatar,
                    isDisabled: isLoading
                )

                sectionHeader("Informazioni personali")

                BrindooTextField(
                    title: isOrganizer ? "Nome o nome dell'attività" : "Nome e cognome",
                    placeholder: isOrganizer ? "Es. Mario Rossi Eventi" : "Es. Mario Rossi",
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

                ProvincePickerSection(
                    selectedProvince: $selectedProvince,
                    error: $provinceError,
                    isDisabled: isLoading
                )

                BrindooPhoneTextField(
                    title: "Telefono (opzionale)",
                    text: $phone,
                    isDisabled: isLoading
                )

                bioField

                if isOrganizer {
                    sectionHeader("Servizi offerti")
                        .padding(.top, BrindooSpacing.md)

                    Text("Seleziona le categorie e aggiungi una breve descrizione (opzionale)")
                        .font(BrindooFont.bodySmall)
                        .foregroundStyle(Color.brindooTextSecondary)

                    VStack(spacing: BrindooSpacing.xs) {
                        ForEach(allCategories) { category in
                            EditCategoryRow(
                                category: category,
                                selectedIds: $selectedCategoryIds,
                                descriptions: $categoryDescriptions,
                                expandedId: $expandedCategoryId
                            )
                        }
                    }

                    SuggestCategoryButton()

                    sectionHeader("Aree di copertura")
                        .padding(.top, BrindooSpacing.md)

                    CoverageAreasField(
                        selectedAreaSlugs: $selectedAreaSlugs,
                        showsRomeHint: session.currentProfile?.isInRome == true
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
            .padding(.horizontal, BrindooSpacing.lg)
            .padding(.top, BrindooSpacing.md)
            .padding(.bottom, BrindooSpacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(BrindooFont.titleSmall)
            .foregroundStyle(Color.brindooTextPrimary)
    }

    private func loadAvatarFromPicker(_ item: PhotosPickerItem) async {
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                await MainActor.run {
                    newAvatarImage = uiImage
                    avatarPickerItem = nil
                }
            }
        } catch {
            await MainActor.run { avatarPickerItem = nil }
        }
    }

    @ViewBuilder
    private var bioField: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
            Text(isOrganizer ? "Bio (visibile ai clienti)" : "Bio (opzionale)")
                .font(BrindooFont.bodySmall.weight(.medium))
                .foregroundStyle(Color.brindooTextSecondary)

            TextField(
                isOrganizer ? "Presentati: anni di esperienza, stile..." : "Racconta qualcosa di te",
                text: $bio,
                axis: .vertical
            )
            .lineLimit(4...10)
            .font(BrindooFont.bodyLarge)
            .padding(BrindooSpacing.md)
            .background(Color.brindooSurface)
            .overlay(
                RoundedRectangle(cornerRadius: BrindooRadius.md)
                    .strokeBorder(Color.brindooBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
            .disabled(isLoading)

            HStack {
                Spacer()
                Text("\(bio.count)/500")
                    .font(BrindooFont.caption)
                    .foregroundStyle(bio.count > 500 ? Color.brindooError : Color.brindooTextSecondary)
            }
        }
    }

    @ViewBuilder
    private var successToast: some View {
        HStack(spacing: BrindooSpacing.xs) {
            Image(systemName: "checkmark.circle.fill")
            Text("Profilo aggiornato")
                .font(BrindooFont.bodyMedium.weight(.medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, BrindooSpacing.md)
        .padding(.vertical, BrindooSpacing.sm)
        .background(Color.brindooSuccess)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }

    private var hasChanges: Bool {
        guard let profile = session.currentProfile else { return false }

        let trimmedName = fullName.trimmingCharacters(in: .whitespaces)
        let trimmedCity = city.trimmingCharacters(in: .whitespaces)
        let trimmedPhone = phone.trimmingCharacters(in: .whitespaces)
        let trimmedBio = bio.trimmingCharacters(in: .whitespaces)
        let storedPhoneUI = (profile.phone ?? "").withoutItalianPrefix

        if trimmedName != (profile.fullName ?? "") { return true }
        if trimmedCity != (profile.city ?? "") { return true }
        if selectedProvince != profile.province { return true }
        if trimmedPhone != storedPhoneUI { return true }
        if trimmedBio != (profile.bio ?? "") { return true }
        if newAvatarImage != nil { return true }
        if isOrganizer {
            if selectedCategoryIds != initialCategoryIds { return true }
            for catId in selectedCategoryIds {
                let new = (categoryDescriptions[catId] ?? "").trimmingCharacters(in: .whitespaces)
                let old = (initialCategoryDescriptions[catId] ?? "").trimmingCharacters(in: .whitespaces)
                if new != old { return true }
            }
            if selectedAreaSlugs != initialAreaSlugs { return true }
        }
        return false
    }

    private func loadInitialData() async {
        isLoadingInitial = true
        defer { isLoadingInitial = false }

        if let profile = session.currentProfile {
            fullName = profile.fullName ?? ""
            city = profile.city ?? ""
            selectedProvince = profile.province
            phone = (profile.phone ?? "").withoutItalianPrefix
            bio = profile.bio ?? ""
            let areas = Set(profile.coverageAreas)
            selectedAreaSlugs = areas
            initialAreaSlugs = areas
        }

        if isOrganizer {
            do {
                allCategories = try await CategoryService.shared.fetchCategories()

                if let userId = session.userID {
                    let details = try await OrganizerCategoriesService.shared.fetchDetailed(organizerId: userId)
                    let ids = Set(details.map { $0.category.id })
                    selectedCategoryIds = ids
                    initialCategoryIds = ids

                    var descs: [UUID: String] = [:]
                    for d in details {
                        if let desc = d.description { descs[d.category.id] = desc }
                    }
                    categoryDescriptions = descs
                    initialCategoryDescriptions = descs
                }
            } catch {
                BrindooLog.error("Errore caricamento categorie: \(error)")
            }
        }
    }

    private func save() async {
        fullNameError = nil
        cityError = nil
        provinceError = nil
        generalError = nil

        let trimmedName = fullName.trimmingCharacters(in: .whitespaces)
        let trimmedCity = city.trimmingCharacters(in: .whitespaces)
        let trimmedPhone = phone.trimmingCharacters(in: .whitespaces)
        let trimmedBio = bio.trimmingCharacters(in: .whitespaces)

        var hasError = false
        if trimmedName.count < 2 { fullNameError = "Il nome è troppo corto"; hasError = true }
        if trimmedCity.isEmpty { cityError = "Inserisci la tua città"; hasError = true }
        guard let province = selectedProvince else {
            provinceError = "Seleziona la tua provincia"
            return
        }
        if let validationError = CityValidator.validate(city: trimmedCity, province: province) {
            cityError = validationError
            hasError = true
        }
        if trimmedBio.count > 500 { generalError = "La bio non può superare 500 caratteri"; hasError = true }
        if hasError { return }

        isLoading = true
        defer { isLoading = false }

        do {
            var avatarUrl: String? = session.currentProfile?.avatarUrl
            if let newImage = newAvatarImage {
                isUploadingAvatar = true
                avatarUrl = try await StorageService.shared.uploadAvatar(newImage)
                isUploadingAvatar = false
            }

            let phoneForDB = trimmedPhone.isEmpty ? "" : trimmedPhone.withItalianPrefix

            let updatedProfile = try await ProfileService.shared.updateProfileWithAvatar(
                fullName: trimmedName,
                phone: phoneForDB,
                city: CityValidator.normalizedCity(trimmedCity),
                province: province,
                bio: trimmedBio,
                avatarUrl: avatarUrl
            )

            session.updateLocalProfile(updatedProfile)

            if isOrganizer {
                guard let userId = session.userID else { return }
                let items: [(categoryId: UUID, description: String?)] = selectedCategoryIds.map { id in
                    let desc = categoryDescriptions[id]?.trimmingCharacters(in: .whitespaces)
                    return (categoryId: id, description: (desc?.isEmpty == false) ? desc : nil)
                }
                try await OrganizerCategoriesService.shared.updateCategoriesWithDescriptions(
                    organizerId: userId,
                    items: items
                )
                initialCategoryIds = selectedCategoryIds
                initialCategoryDescriptions = categoryDescriptions

                // Aree di copertura
                if selectedAreaSlugs != initialAreaSlugs {
                    let updated = try await ProfileService.shared.updateCoverageAreas(
                        Array(selectedAreaSlugs)
                    )
                    session.updateLocalProfile(updated)
                    initialAreaSlugs = selectedAreaSlugs
                }
            }

            withAnimation { showSuccessToast = true }
            try? await Task.sleep(nanoseconds: 1_200_000_000)

            if isPostUpgrade {
                onPostUpgradeExit?(false)
            } else {
                dismiss()
            }

        } catch {
            isUploadingAvatar = false
            generalError = "Impossibile salvare. Riprova più tardi."
            BrindooLog.error("\(error)")
        }
    }

    /// Rollback dell'upgrade: ripristina il ruolo cliente. Chiamato dal bottone
    /// "Annulla operazione" visibile solo in modalità `isPostUpgrade`.
    private func cancelUpgrade() async {
        isCancellingUpgrade = true
        defer { isCancellingUpgrade = false }
        do {
            let reverted = try await ProfileService.shared.setRole(.client)
            session.updateLocalProfile(reverted)
            ProfessionalOnboardingHint.clear()
            toasts.show(BrindooToast("Sei tornato cliente", style: .info))
            onPostUpgradeExit?(true)
        } catch {
            generalError = "Impossibile annullare l'operazione. Riprova."
            BrindooLog.error("cancelUpgrade: \(error)")
        }
    }
}
