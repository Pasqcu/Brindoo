//
//  EditProfileSections.swift
//  Brindoo
//
//  Sezioni della schermata "Modifica profilo": avatar, provincia,
//  categorie con descrizione, aree di copertura, banner post-upgrade.
//

import SwiftUI
import PhotosUI

// MARK: - Avatar con bottone fotocamera

struct AvatarEditSection: View {
    let newAvatarImage: UIImage?
    @Binding var avatarPickerItem: PhotosPickerItem?
    let currentAvatarUrl: String?
    let fallbackName: String?
    let isUploading: Bool
    let isDisabled: Bool

    var body: some View {
        VStack(spacing: BrindooSpacing.sm) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let newImage = newAvatarImage {
                        Image(uiImage: newImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        AvatarView(
                            url: currentAvatarUrl,
                            name: fallbackName,
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

                        if isUploading {
                            ProgressView().tint(.white).scaleEffect(0.7)
                        } else {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .overlay(Circle().strokeBorder(Color.brindooBackground, lineWidth: 3))
                }
                .disabled(isUploading || isDisabled)
            }

            Text(newAvatarImage != nil ? "Nuova foto selezionata" : "Tocca l'icona per cambiare foto")
                .font(BrindooFont.caption)
                .foregroundStyle(Color.brindooTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Riga categoria con descrizione espandibile

struct EditCategoryRow: View {
    let category: ServiceCategory
    @Binding var selectedIds: Set<UUID>
    @Binding var descriptions: [UUID: String]
    @Binding var expandedId: UUID?

    var body: some View {
        let isSelected = selectedIds.contains(category.id)
        let isExpanded = expandedId == category.id

        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isSelected {
                        expandedId = isExpanded ? nil : category.id
                    } else {
                        selectedIds.insert(category.id)
                        expandedId = category.id
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
                        if isSelected, let desc = descriptions[category.id], !desc.isEmpty {
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
                                selectedIds.remove(category.id)
                                descriptions[category.id] = nil
                                if expandedId == category.id { expandedId = nil }
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
                        get: { descriptions[category.id] ?? "" },
                        set: { descriptions[category.id] = $0 }
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
}

// MARK: - Banner post-upgrade (Cliente → Professionista)

struct PostUpgradeBanner: View {
    var body: some View {
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
}

// MARK: - Bottone "Proponi una nuova categoria"

struct SuggestCategoryButton: View {
    @State private var showSuggestCategory = false

    var body: some View {
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
}

// MARK: - Aree di copertura (organizer)

struct CoverageAreasField: View {
    @Binding var selectedAreaSlugs: Set<String>
    /// True se l'utente vive a Roma (mostra il suggerimento sui quartieri).
    let showsRomeHint: Bool

    @State private var showAreaPicker = false

    var body: some View {
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
            if showsRomeHint {
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
}

// MARK: - Selettore provincia

struct ProvincePickerSection: View {
    @Binding var selectedProvince: LazioProvince?
    @Binding var error: String?
    let isDisabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
            Text("Provincia")
                .font(BrindooFont.bodySmall.weight(.medium))
                .foregroundStyle(Color.brindooTextSecondary)

            HStack(spacing: BrindooSpacing.xs) {
                ForEach(LazioProvince.allCases) { province in
                    let isSelected = selectedProvince == province
                    Button {
                        selectedProvince = province
                        error = nil
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
                    .disabled(isDisabled)
                }
            }

            if let error {
                Text(error)
                    .font(BrindooFont.caption)
                    .foregroundStyle(Color.brindooError)
            } else {
                Text("Brindoo è disponibile in tutto il \(CityValidator.allowedRegionDisplay).")
                    .font(BrindooFont.caption)
                    .foregroundStyle(Color.brindooTextSecondary)
            }
        }
    }
}
