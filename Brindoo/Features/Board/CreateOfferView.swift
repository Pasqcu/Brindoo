//
//  CreateOfferView.swift
//  Brindoo
//
//  Form per la pubblicazione di un'offerta di servizio da parte di un organizzatore.
//

import SwiftUI
import PhotosUI

struct CreateOfferView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var price: String = ""

    @State private var coverPickerItem: PhotosPickerItem?
    @State private var coverImage: UIImage?
    /// Foto ereditata dall'offerta duplicata (usata se non se ne sceglie una nuova).
    @State private var templateImageUrl: String?

    /// Crea il form vuoto, oppure precompilato da un'offerta esistente ("Duplica").
    init(template: ServiceOffer? = nil, templateCategoryIds: [UUID] = []) {
        _title = State(initialValue: template?.title ?? "")
        _description = State(initialValue: template?.description ?? "")
        _price = State(initialValue: template.map { String(Int($0.price)) } ?? "")
        _selectedCategoryIds = State(initialValue: Set(templateCategoryIds))
        _templateImageUrl = State(initialValue: template?.imageUrl)
    }

    @State private var allCategories: [ServiceCategory] = []
    @State private var selectedCategoryIds: Set<UUID> = []

    @State private var titleError: String?
    @State private var descError: String?
    @State private var priceError: String?
    @State private var categoryError: String?
    @State private var generalError: String?
    @State private var isLoading: Bool = false
    @State private var showSuccess: Bool = false
    @State private var showLimitPaywall: Bool = false
    @State private var limitMessage: String = ""
    @State private var showPaywallSheet: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BrindooSpacing.lg) {

                    coverImagePicker

                    BrindooTextField(
                        title: "Titolo dell'offerta",
                        placeholder: "Es. Pacchetto matrimonio Foto + Video",
                        text: $title,
                        icon: "text.alignleft",
                        autocapitalization: .sentences,
                        errorMessage: titleError,
                        isDisabled: isLoading
                    )

                    VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
                        Text("Descrizione")
                            .font(BrindooFont.bodySmall.weight(.medium))
                            .foregroundStyle(Color.brindooTextSecondary)
                        TextField("Cosa includi nel servizio? Tempistiche, dettagli…", text: $description, axis: .vertical)
                            .lineLimit(4...10)
                            .font(BrindooFont.bodyLarge)
                            .padding(BrindooSpacing.md)
                            .background(Color.brindooSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: BrindooRadius.md)
                                    .strokeBorder(descError != nil ? Color.brindooError : Color.brindooBorder, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
                            .disabled(isLoading)
                        if let descError {
                            Text(descError).font(BrindooFont.caption).foregroundStyle(Color.brindooError)
                        }
                    }

                    // MARK: - Categorie

                    VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
                        Text("Categorie del servizio offerto")
                            .font(BrindooFont.bodySmall.weight(.medium))
                            .foregroundStyle(Color.brindooTextSecondary)

                        Text("Puoi selezionarne più di una")
                            .font(BrindooFont.caption)
                            .foregroundStyle(Color.brindooTextSecondary)

                        FlowLayoutView(spacing: BrindooSpacing.xs) {
                            ForEach(allCategories) { cat in
                                let isSelected = selectedCategoryIds.contains(cat.id)
                                Button {
                                    if isSelected { selectedCategoryIds.remove(cat.id) }
                                    else { selectedCategoryIds.insert(cat.id) }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: cat.icon)
                                            .font(.system(size: 12))
                                        Text(cat.name)
                                            .font(BrindooFont.bodySmall.weight(.medium))
                                    }
                                    .padding(.horizontal, BrindooSpacing.sm)
                                    .padding(.vertical, BrindooSpacing.xs)
                                    .foregroundStyle(isSelected ? .white : Color.brindooCoral)
                                    .background(isSelected ? Color.brindooCoral : Color.brindooCoral.opacity(0.1))
                                    .clipShape(Capsule())
                                }
                            }
                        }

                        if let categoryError {
                            Text(categoryError).font(BrindooFont.caption).foregroundStyle(Color.brindooError)
                        }
                    }

                    coverageInheritedCard

                    // MARK: - Prezzo (singolo, obbligatorio — base per la trattativa)

                    VStack(alignment: .leading, spacing: BrindooSpacing.xxs) {
                        BrindooTextField(
                            title: "Prezzo del servizio (€)",
                            placeholder: "Es. 350",
                            text: $price,
                            icon: "eurosign",
                            keyboardType: .numberPad,
                            errorMessage: priceError,
                            isDisabled: isLoading
                        )
                        Text("I clienti potranno accettarlo, fare una controproposta o nascondere l'offerta.")
                            .font(BrindooFont.caption)
                            .foregroundStyle(Color.brindooTextSecondary)
                    }

                    if let generalError {
                        HStack(spacing: BrindooSpacing.xs) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(generalError).font(BrindooFont.bodySmall)
                        }
                        .foregroundStyle(Color.brindooError)
                        .padding(BrindooSpacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.brindooError.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
                    }
                }
                .padding(BrindooSpacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.brindooBackground)
            .navigationTitle("Nuova offerta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annulla") { dismiss() }
                        .disabled(isLoading)
                }
            }
            .safeAreaInset(edge: .bottom) {
                BrindooButton(
                    "Pubblica offerta",
                    style: .primary,
                    size: .large,
                    isLoading: isLoading
                ) {
                    Task { await submit() }
                }
                .padding(.horizontal, BrindooSpacing.lg)
                .padding(.vertical, BrindooSpacing.sm)
                .background(
                    Color.brindooBackground
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: -2)
                )
            }
            .task {
                do {
                    allCategories = try await CategoryService.shared.fetchCategories()
                } catch { BrindooLog.error("\(error)") }
            }
            .onChange(of: coverPickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        coverImage = img
                    }
                }
            }
            .alert("Offerta pubblicata!", isPresented: $showSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("La tua offerta è ora visibile ai clienti nella bacheca.")
            }
            .alert("Limite raggiunto", isPresented: $showLimitPaywall) {
                Button("Annulla", role: .cancel) {}
                Button("Scopri Pro") {
                    showLimitPaywall = false
                    showPaywallSheet = true
                }
            } message: {
                Text(limitMessage)
            }
            .sheet(isPresented: $showPaywallSheet) {
                PaywallView()
            }
        }
    }

    // MARK: - Foto di copertina

    @ViewBuilder
    private var coverImagePicker: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
            Text("Foto di copertina (consigliata)")
                .font(BrindooFont.bodySmall.weight(.medium))
                .foregroundStyle(Color.brindooTextSecondary)

            PhotosPicker(selection: $coverPickerItem, matching: .images) {
                ZStack {
                    if let coverImage {
                        Image(uiImage: coverImage)
                            .resizable()
                            .scaledToFill()
                    } else if let templateImageUrl, let url = URL(string: templateImageUrl) {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            BrindooSkeleton(cornerRadius: BrindooRadius.md)
                        }
                    } else {
                        VStack(spacing: BrindooSpacing.xs) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 32))
                                .foregroundStyle(Color.brindooCoral)
                            Text("Aggiungi una foto che mostri il tuo servizio")
                                .font(BrindooFont.caption)
                                .foregroundStyle(Color.brindooTextSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(BrindooSpacing.md)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .background(Color.brindooSurface)
                .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: BrindooRadius.md)
                        .strokeBorder(Color.brindooBorder, lineWidth: 1)
                )
            }
            .disabled(isLoading)

            if coverImage != nil || templateImageUrl != nil {
                Button {
                    coverImage = nil
                    coverPickerItem = nil
                    templateImageUrl = nil
                } label: {
                    Label("Rimuovi foto", systemImage: "trash")
                        .font(BrindooFont.caption.weight(.medium))
                        .foregroundStyle(Color.brindooError)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Aree di copertura (ereditate dal profilo)

    private var profileCoverageAreas: [String] {
        session.currentProfile?.coverageAreas ?? []
    }

    @ViewBuilder
    private var coverageInheritedCard: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
            HStack(spacing: BrindooSpacing.sm) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.brindooCoral)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Aree di copertura")
                        .font(BrindooFont.bodyMedium.weight(.semibold))
                    Text(LazioArea.displayLabel(forSlugs: profileCoverageAreas))
                        .font(BrindooFont.caption)
                        .foregroundStyle(Color.brindooTextSecondary)
                        .lineLimit(2)
                }
                Spacer()
            }

            HStack(alignment: .top, spacing: BrindooSpacing.xxs) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.brindooTextSecondary)
                Text("L'offerta eredita le aree dal tuo profilo. Per cambiarle, vai in Profilo › Modifica profilo.")
                    .font(BrindooFont.caption)
                    .foregroundStyle(Color.brindooTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(BrindooSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brindooSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: BrindooRadius.md)
                .strokeBorder(Color.brindooBorder, lineWidth: 1)
        )
    }

    // MARK: - Submit

    private func submit() async {
        titleError = nil; descError = nil
        priceError = nil; categoryError = nil; generalError = nil

        let tTitle = title.trimmingCharacters(in: .whitespaces)
        let tDesc = description.trimmingCharacters(in: .whitespaces)
        let priceVal = Double(price.replacingOccurrences(of: ",", with: "."))

        var hasError = false
        if tTitle.count < 5 { titleError = "Titolo troppo corto (min 5)"; hasError = true }
        if tDesc.count < 20 { descError = "Descrizione troppo breve (min 20)"; hasError = true }
        if selectedCategoryIds.isEmpty { categoryError = "Seleziona almeno una categoria"; hasError = true }
        if priceVal == nil || (priceVal ?? 0) <= 0 {
            priceError = "Inserisci un prezzo valido"; hasError = true
        }
        if hasError { return }

        isLoading = true
        defer { isLoading = false }

        // La copertura visibile è derivata dalle aree del profilo (read-only).
        let coverageAreaText = LazioArea.displayLabel(forSlugs: profileCoverageAreas)

        do {
            // Carica prima la foto di copertina, se presente.
            // In un duplicato senza nuova foto si riusa quella dell'originale.
            var imageUrl: String? = templateImageUrl
            if let coverImage {
                imageUrl = try await StorageService.shared.uploadOfferImage(coverImage)
            }

            _ = try await ServiceOfferService.shared.createOffer(
                title: tTitle,
                description: tDesc,
                coverageArea: coverageAreaText,
                price: priceVal!,
                categoryIds: Array(selectedCategoryIds),
                imageUrl: imageUrl
            )
            showSuccess = true
        } catch let limitError as BrindooLimitError {
            limitMessage = limitError.errorDescription ?? "Limite raggiunto."
            showLimitPaywall = true
        } catch {
            generalError = "Errore nella pubblicazione. Riprova."
            BrindooLog.error("\(error)")
        }
    }
}
