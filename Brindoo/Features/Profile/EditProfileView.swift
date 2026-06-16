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
    @State private var showAreaPicker: Bool = false
    @State private var showSuggestCategory: Bool = false

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
                    postUpgradeBanner
                }

                avatarSection

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

                BrindooTextField(
                    title: "Città",
                    placeholder: "Es. Roma, Tivoli, Latina…",
                    text: $city,
                    icon: "mappin.and.ellipse",
                    textContentType: .addressCity,
                    autocapitalization: .words,
                    errorMessage: cityError,
                    isDisabled: isLoading
                )

                provincePickerSection

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

                    categoriesWithDescriptions

                    suggestCategoryButton

                    sectionHeader("Aree di copertura")
                        .padding(.top, BrindooSpacing.md)

                    coverageAreasField
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

    @ViewBuilder
    private var avatarSection: some View {
        VStack(spacing: BrindooSpacing.sm) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let newImage = newAvatarImage {
                        Image(uiImage: newImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        AvatarView(
                            url: session.currentProfile?.avatarUrl,
                            name: fullName.isEmpty ? session.currentProfile?.fullName : fullName,
                            size: 110
                        )
                    }
                }
                .frame(width: 110, height: 110)
                .clipShape(Circle())

                PhotosPicker(
                    selection: $avatarPickerItem,
                    matching: .images,
                    preferredItemEncoding: .compatible,
                    photoLibrary: .shared()
                ) {
                    ZStack {
                        Circle()
                            .fill(Color.brindooCoral)
                            .frame(width: 36, height: 36)

                        if isUploadingAvatar {
                            ProgressView().tint(.white).scaleEffect(0.7)
                        } else {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .overlay(Circle().strokeBorder(Color.brindooBackground, lineWidth: 3))
                }
                .disabled(isUploadingAvatar || isLoading)
            }

            Text(newAvatarImage != nil ? "Nuova foto selezionata" : "Tocca l'icona per cambiare foto")
                .font(BrindooFont.caption)
                .foregroundStyle(Color.brindooTextSecondary)
        }
        .frame(maxWidth: .infinity)
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

    // MARK: - Categorie con descrizione

    @ViewBuilder
    private var categoriesWithDescriptions: some View {
        VStack(spacing: BrindooSpacing.xs) {
            ForEach(allCategories) { category in
                categoryRow(category)
            }
        }
    }

    @ViewBuilder
    private func categoryRow(_ category: ServiceCategory) -> some View {
        let isSelected = selectedCategoryIds.contains(category.id)
        let isExpanded = expandedCategoryId == category.id

        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isSelected {
                        expandedCategoryId = isExpanded ? nil : category.id
                    } else {
                        selectedCategoryIds.insert(category.id)
                        expandedCategoryId = category.id
                    }
                }
            } label: {
                HStack(spacing: BrindooSpacing.sm) {
                    Image(systemName: category.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(isSelected ? .white : Color.brindooCoral)
                        .frame(width: 32, height: 32)
                        .background(isSelected ? Color.brindooCoral : Color.brindooCoral.opacity(0.1))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.name)
                            .font(BrindooFont.bodyMedium.weight(.medium))
                            .foregroundStyle(Color.brindooTextPrimary)
                        if isSelected, let desc = categoryDescriptions[category.id], !desc.isEmpty {
                            Text(desc)
                                .font(BrindooFont.caption)
                                .foregroundStyle(Color.brindooTextSecondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    if isSelected {
                        Button {
                            withAnimation {
                                selectedCategoryIds.remove(category.id)
                                categoryDescriptions[category.id] = nil
                                if expandedCategoryId == category.id { expandedCategoryId = nil }
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(Color.brindooTextSecondary)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.brindooCoral)
                    }
                }
                .padding(BrindooSpacing.sm)
                .background(isSelected ? Color.brindooCoral.opacity(0.05) : Color.brindooSurface)
                .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
            }
            .buttonStyle(.plain)

            if isSelected && isExpanded {
                VStack(alignment: .leading, spacing: BrindooSpacing.xxs) {
                    let bindingDesc = Binding(
                        get: { categoryDescriptions[category.id] ?? "" },
                        set: { categoryDescriptions[category.id] = $0 }
                    )

                    TextField("Descrivi questo servizio (es. matrimoni, eventi corporate...)", text: bindingDesc, axis: .vertical)
                        .lineLimit(2...4)
                        .font(BrindooFont.bodyMedium)
                        .padding(BrindooSpacing.sm)
                        .background(Color.brindooBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: BrindooRadius.sm)
                                .strokeBorder(Color.brindooBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))

                    Text("Massimo 200 caratteri")
                        .font(BrindooFont.caption)
                        .foregroundStyle(Color.brindooTextSecondary)
                }
                .padding(.horizontal, BrindooSpacing.sm)
                .padding(.top, BrindooSpacing.xs)
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

    // MARK: - Post-upgrade banner

    @ViewBuilder
    private var postUpgradeBanner: some View {
        HStack(alignment: .top, spacing: BrindooSpacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 22))
                .foregroundStyle(Color.brindooCoral)
            VStack(alignment: .leading, spacing: 2) {
                Text("Benvenuto tra i Professionisti!")
                    .font(BrindooFont.bodyMedium.weight(.semibold))
                Text("Completa categorie, descrizione e aree di copertura per essere trovato dai clienti. Se cambi idea, tocca \"Annulla operazione\" in alto.")
                    .font(BrindooFont.caption)
                    .foregroundStyle(Color.brindooTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(BrindooSpacing.md)
        .background(
            LinearGradient(
                colors: [Color.brindooCoral.opacity(0.18), .pink.opacity(0.12)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: BrindooRadius.md)
                .strokeBorder(Color.brindooCoral.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Suggerisci categoria

    @ViewBuilder
    private var suggestCategoryButton: some View {
        Button {
            showSuggestCategory = true
        } label: {
            HStack(spacing: BrindooSpacing.sm) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.brindooWarning)
                Text("Proponi una nuova categoria")
                    .font(BrindooFont.bodyMedium.weight(.medium))
                    .foregroundStyle(Color.brindooCoral)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.brindooTextSecondary)
            }
            .padding(BrindooSpacing.sm)
            .background(Color.brindooCoral.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: BrindooRadius.md)
                    .strokeBorder(Color.brindooCoral.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSuggestCategory) {
            SuggestCategorySheet()
        }
    }

    // MARK: - Aree di copertura (organizer)

    @ViewBuilder
    private var coverageAreasField: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
            Text("Opzionale. Lascia vuoto per essere visibile in tutto il Lazio.")
                .font(BrindooFont.bodySmall)
                .foregroundStyle(Color.brindooTextSecondary)

            Button {
                showAreaPicker = true
            } label: {
                HStack(spacing: BrindooSpacing.sm) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.brindooCoral)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedAreaSlugs.isEmpty ? "Tutto il Lazio" : LazioArea.displayLabel(forSlugs: Array(selectedAreaSlugs)))
                            .font(BrindooFont.bodyMedium.weight(.semibold))
                            .foregroundStyle(Color.brindooTextPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        if !selectedAreaSlugs.isEmpty {
                            Text("\(selectedAreaSlugs.count) selezionate")
                                .font(BrindooFont.caption)
                                .foregroundStyle(Color.brindooTextSecondary)
                        } else {
                            Text("Tocca per restringere le aree")
                                .font(BrindooFont.caption)
                                .foregroundStyle(Color.brindooTextSecondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.brindooTextSecondary)
                }
                .padding(BrindooSpacing.sm)
                .background(Color.brindooSurface)
                .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: BrindooRadius.md)
                        .strokeBorder(Color.brindooBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showAreaPicker) {
                AreaPickerSheet(selected: $selectedAreaSlugs) { /* on apply */ }
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }

            // Hint suggerimento Roma: se l'utente vive a Roma, gli ricordiamo
            // che la lista include i quartieri romani per restringere ulteriormente.
            if session.currentProfile?.isInRome == true {
                HStack(alignment: .top, spacing: BrindooSpacing.xxs) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.brindooWarning)
                    Text("Vivi a Roma? Puoi selezionare anche i singoli quartieri (Centro Storico, EUR, Trastevere…).")
                        .font(BrindooFont.caption)
                        .foregroundStyle(Color.brindooTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
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
                print("❌ Errore caricamento categorie: \(error)")
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
            print("❌ \(error)")
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
            print("❌ cancelUpgrade: \(error)")
        }
    }
}
