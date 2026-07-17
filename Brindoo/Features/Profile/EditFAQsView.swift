//
//  EditFAQsView.swift
//  Brindoo
//
//  Editor delle domande frequenti del professionista (max 5).
//  Risposte pronte sul profilo = meno chat ripetitive, decisioni più rapide.
//

import SwiftUI

struct EditFAQsView: View {

    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var faqs: [ProfileFAQ] = []
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var editingIndex: Int?
    @State private var draftQuestion = ""
    @State private var draftAnswer = ""
    @State private var showEditor = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BrindooSpacing.md) {
                    Text("Rispondi in anticipo alle domande che i clienti fanno più spesso (attrezzatura, durata, spostamenti…). Compaiono sul tuo profilo pubblico.")
                        .font(BrindooFont.bodySmall)
                        .foregroundStyle(Color.brindooTextSecondary)

                    if faqs.isEmpty {
                        ContentUnavailableView(
                            "Nessuna domanda frequente",
                            systemImage: "questionmark.bubble",
                            description: Text("Aggiungi la prima: esempio \"Porti tu l'attrezzatura?\"")
                        )
                    }

                    ForEach(Array(faqs.enumerated()), id: \.offset) { index, faq in
                        faqCard(faq, index: index)
                    }

                    if faqs.count < ProfileFAQ.maxCount {
                        BrindooButton("Aggiungi domanda", style: .secondary, size: .medium, icon: "plus") {
                            editingIndex = nil
                            draftQuestion = ""
                            draftAnswer = ""
                            showEditor = true
                        }
                    } else {
                        Text("Hai raggiunto il massimo di \(ProfileFAQ.maxCount) domande.")
                            .font(BrindooFont.caption)
                            .foregroundStyle(Color.brindooTextSecondary)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(BrindooFont.bodySmall)
                            .foregroundStyle(Color.brindooError)
                    }
                }
                .padding(BrindooSpacing.md)
            }
            .background(Color.brindooBackground)
            .navigationTitle("Domande frequenti")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Chiudi") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving { ProgressView() } else { Text("Salva").bold() }
                    }
                    .disabled(isSaving || faqs == (session.currentProfile?.faqs ?? []))
                }
            }
            .sheet(isPresented: $showEditor) { editorSheet }
            .onAppear { faqs = session.currentProfile?.faqs ?? [] }
        }
    }

    @ViewBuilder
    private func faqCard(_ faq: ProfileFAQ, index: Int) -> some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
            HStack(alignment: .top) {
                Text(faq.question)
                    .font(BrindooFont.bodyMedium.weight(.semibold))
                Spacer()
                Button {
                    editingIndex = index
                    draftQuestion = faq.question
                    draftAnswer = faq.answer
                    showEditor = true
                } label: {
                    Image(systemName: "pencil")
                        .foregroundStyle(Color.brindooCoral)
                }
                Button {
                    faqs.remove(at: index)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(Color.brindooError)
                }
            }
            Text(faq.answer)
                .font(BrindooFont.bodySmall)
                .foregroundStyle(Color.brindooTextSecondary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(BrindooSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brindooSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
    }

    private var editorSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: BrindooSpacing.md) {
                TextField("Domanda (es. Porti tu l'attrezzatura?)", text: $draftQuestion, axis: .vertical)
                    .font(BrindooFont.bodyMedium)
                    .padding(BrindooSpacing.sm)
                    .background(Color.brindooSurface)
                    .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))

                TextField("Risposta", text: $draftAnswer, axis: .vertical)
                    .font(BrindooFont.bodyMedium)
                    .lineLimit(3...8)
                    .padding(BrindooSpacing.sm)
                    .background(Color.brindooSurface)
                    .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))

                Spacer()
            }
            .padding(BrindooSpacing.md)
            .background(Color.brindooBackground)
            .navigationTitle(editingIndex == nil ? "Nuova domanda" : "Modifica domanda")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annulla") { showEditor = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fatto") {
                        let q = draftQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
                        let a = draftAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !q.isEmpty, !a.isEmpty else { return }
                        let faq = ProfileFAQ(question: q, answer: a)
                        if let editingIndex, faqs.indices.contains(editingIndex) {
                            faqs[editingIndex] = faq
                        } else {
                            faqs.append(faq)
                        }
                        showEditor = false
                    }
                    .bold()
                    .disabled(
                        draftQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || draftAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
            .presentationDetents([.medium])
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let updated = try await ProfileService.shared.updateFAQs(faqs)
            session.updateLocalProfile(updated)
            BrindooHaptics.notify(.success)
            dismiss()
        } catch {
            errorMessage = "Impossibile salvare. Riprova."
            BrindooLog.error("updateFAQs: \(error)")
        }
    }
}
