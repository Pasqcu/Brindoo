//
//  QuickReplies.swift
//  Brindoo
//
//  Risposte rapide del professionista in chat: frasi pronte salvate sul
//  dispositivo, inseribili con un tocco dal composer. Include il pannello
//  di gestione (aggiungi / elimina).
//

import SwiftUI

// MARK: - Archivio frasi (UserDefaults)

enum QuickRepliesStore {

    static let storageKey = "brindoo.chat.quickReplies"
    static let maxCount = 8

    static let defaultReplies: [String] = [
        "Ciao! Sono disponibile, dimmi di più sull'evento 🎉",
        "Grazie per il messaggio! Ti rispondo con un preventivo entro oggi.",
        "In che zona si terrà l'evento e per quante persone?"
    ]

    static func load(defaults: UserDefaults = .standard) -> [String] {
        if let saved = defaults.stringArray(forKey: storageKey) {
            return saved
        }
        return defaultReplies
    }

    static func save(_ replies: [String], defaults: UserDefaults = .standard) {
        let cleaned = replies
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        defaults.set(Array(cleaned.prefix(maxCount)), forKey: storageKey)
    }
}

// MARK: - Bottone nel composer

/// Fulmine accanto al campo di testo: menu con le frasi pronte
/// e la voce per gestirle.
struct QuickReplyMenuButton: View {

    let onPick: (String) -> Void

    @State private var replies: [String] = []
    @State private var showManage = false

    var body: some View {
        Menu {
            ForEach(replies, id: \.self) { phrase in
                Button {
                    BrindooHaptics.impact(.light)
                    onPick(phrase)
                } label: {
                    Text(phrase)
                }
            }
            Divider()
            Button {
                showManage = true
            } label: {
                Label("Gestisci risposte rapide", systemImage: "pencil")
            }
        } label: {
            Image(systemName: "bolt.circle")
                .font(.system(size: 22))
                .foregroundStyle(Color.brindooCoral)
        }
        .accessibilityLabel("Risposte rapide")
        .onAppear { replies = QuickRepliesStore.load() }
        .sheet(isPresented: $showManage, onDismiss: {
            replies = QuickRepliesStore.load()
        }) {
            QuickRepliesManageSheet()
        }
    }
}

// MARK: - Pannello di gestione

struct QuickRepliesManageSheet: View {

    @Environment(\.dismiss) private var dismiss
    @State private var replies: [String] = QuickRepliesStore.load()
    @State private var newPhrase: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BrindooSpacing.lg) {
                    Text("Le frasi che usi più spesso, pronte da inserire con un tocco.")
                        .font(BrindooFont.bodySmall)
                        .foregroundStyle(Color.brindooTextSecondary)

                    VStack(spacing: BrindooSpacing.xs) {
                        ForEach(Array(replies.enumerated()), id: \.offset) { index, phrase in
                            HStack(spacing: BrindooSpacing.sm) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.brindooCoral)
                                Text(phrase)
                                    .font(BrindooFont.bodySmall)
                                    .foregroundStyle(Color.brindooTextPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Button {
                                    replies.remove(at: index)
                                    QuickRepliesStore.save(replies)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.brindooError)
                                }
                                .accessibilityLabel("Elimina risposta rapida")
                            }
                            .padding(BrindooSpacing.sm)
                            .background(Color.brindooSurface)
                            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
                        }
                    }

                    if replies.count < QuickRepliesStore.maxCount {
                        VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
                            Text("Nuova frase")
                                .font(BrindooFont.bodySmall.weight(.medium))
                                .foregroundStyle(Color.brindooTextSecondary)
                            HStack(spacing: BrindooSpacing.sm) {
                                TextField("Es. Ti chiamo appena posso!", text: $newPhrase, axis: .vertical)
                                    .lineLimit(1...3)
                                    .font(BrindooFont.bodyMedium)
                                    .padding(BrindooSpacing.sm)
                                    .background(Color.brindooSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
                                Button {
                                    let trimmed = newPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
                                    guard !trimmed.isEmpty else { return }
                                    replies.append(trimmed)
                                    QuickRepliesStore.save(replies)
                                    newPhrase = ""
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 28))
                                        .foregroundStyle(newPhrase.trimmingCharacters(in: .whitespaces).isEmpty
                                                         ? Color.brindooBorder : Color.brindooCoral)
                                }
                                .disabled(newPhrase.trimmingCharacters(in: .whitespaces).isEmpty)
                                .accessibilityLabel("Aggiungi risposta rapida")
                            }
                        }
                    } else {
                        Text("Hai raggiunto il massimo di \(QuickRepliesStore.maxCount) frasi.")
                            .font(BrindooFont.caption)
                            .foregroundStyle(Color.brindooTextSecondary)
                    }
                }
                .padding(BrindooSpacing.lg)
            }
            .background(Color.brindooBackground)
            .navigationTitle("Risposte rapide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fine") { dismiss() }
                        .font(BrindooFont.bodyMedium.weight(.semibold))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
