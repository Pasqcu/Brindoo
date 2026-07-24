//
//  DepositSheet.swift
//  Brindoo
//
//  Acconto e saldo di un evento concordato.
//
//  Come funziona, in breve:
//   1. le parti scelgono come pagare: contanti alla consegna oppure
//      bonifico / altro mezzo tracciato (o "da concordare");
//   2. chi riceve i soldi dichiara l'importo dell'acconto;
//   3. l'altra parte conferma. Solo allora l'acconto risulta versato.
//
//  Brindoo non incassa e non trattiene nulla: registra l'accordo e lascia
//  a entrambi una traccia con data, importo e modo di pagamento.
//

import SwiftUI

struct DepositSheet: View {

    let proposal: OfferProposal
    /// Chiamata dopo ogni modifica riuscita, per ricaricare la lista.
    let onChange: () async -> Void

    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var toastCenter: BrindooToastCenter

    @State private var depositMethod: PaymentMethod
    @State private var balanceMethod: PaymentMethod
    @State private var amountText: String
    @State private var note: String
    @State private var saving = false
    @State private var showClearConfirm = false

    init(proposal: OfferProposal, onChange: @escaping () async -> Void) {
        self.proposal = proposal
        self.onChange = onChange
        _depositMethod = State(initialValue: proposal.depositMethod ?? .cash)
        _balanceMethod = State(initialValue: proposal.balanceMethod ?? .cash)
        _amountText = State(initialValue: proposal.depositAmount.map { String(format: "%.2f", $0).replacingOccurrences(of: ".", with: ",") } ?? "")
        _note = State(initialValue: proposal.depositNote ?? "")
    }

    private var me: UUID? { session.userID }

    /// Di norma incassa il professionista: a lui proponiamo "dichiara",
    /// all'altra parte "conferma".
    private var iCollect: Bool { me == proposal.organizerId }

    private var amount: Double? {
        let cleaned = amountText
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard let value = Double(cleaned), value > 0 else { return nil }
        return value
    }

    private var canDeclare: Bool {
        guard let amount else { return false }
        return amount <= proposal.currentPrice && !saving
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BrindooSpacing.lg) {
                    statusCard
                    methodsSection
                    if proposal.isDepositPaid {
                        paidRecap
                    } else if let declaredBy = proposal.depositDeclaredBy, let me, declaredBy != me {
                        confirmSection
                    } else {
                        declareSection
                    }
                    disclaimer
                }
                .padding(BrindooSpacing.md)
                .brindooReadableWidth()
            }
            .background(Color.brindooBackground)
            .navigationTitle("Acconto e pagamento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Chiudi") { dismiss() }
                        .foregroundStyle(Color.brindooCoral)
                }
            }
            .confirmationDialog(
                "Annullare la registrazione dell'acconto?",
                isPresented: $showClearConfirm,
                titleVisibility: .visible
            ) {
                Button("Annulla registrazione", role: .destructive) {
                    Task { await clearDeposit() }
                }
                Button("Lascia com'è", role: .cancel) {}
            } message: {
                Text("L'importo e la conferma verranno cancellati. Potrai registrarli di nuovo.")
            }
        }
    }

    // MARK: - Riepilogo in cima

    @ViewBuilder
    private var statusCard: some View {
        let (icon, title, subtitle, color) = statusContent

        HStack(alignment: .top, spacing: BrindooSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BrindooFont.titleSmall)
                    .foregroundStyle(Color.brindooTextPrimary)
                Text(subtitle)
                    .font(BrindooFont.bodySmall)
                    .foregroundStyle(Color.brindooTextSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(BrindooSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brindooSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
        .accessibilityElement(children: .combine)
    }

    private var statusContent: (String, String, String, Color) {
        if proposal.isDepositPaid {
            let amount = proposal.depositAmountDisplay ?? "Acconto"
            return ("checkmark.seal.fill", "Acconto versato",
                    "\(amount) · \(proposal.depositMethod?.shortLabel ?? "modo non indicato")",
                    .brindooSuccess)
        }
        if proposal.isDepositAwaitingConfirmation {
            let who = proposal.depositDeclaredBy == me ? "Attendi la conferma dell'altra parte" : "Conferma tu che l'hai versato"
            return ("clock.fill", "Acconto dichiarato, non confermato", who, .brindooWarning)
        }
        return ("eurosign.circle", "Acconto non ancora registrato",
                "Totale concordato: \(proposal.currentPriceDisplay)", .brindooCoral)
    }

    // MARK: - Come si paga

    @ViewBuilder
    private var methodsSection: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
            BrindooSectionHeader("Come pagate")

            methodPicker(title: "Acconto", selection: $depositMethod)
            methodPicker(title: "Saldo (il resto)", selection: $balanceMethod)

            Text(depositMethod.hint)
                .font(BrindooFont.caption)
                .foregroundStyle(Color.brindooTextSecondary)

            Button {
                Task { await saveMethods() }
            } label: {
                Text("Salva il modo di pagamento")
                    .font(BrindooFont.buttonSmall)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(Color.brindooCoral)
            .disabled(saving)
        }
    }

    @ViewBuilder
    private func methodPicker(title: String, selection: Binding<PaymentMethod>) -> some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.xxs) {
            Text(title)
                .font(BrindooFont.bodySmall.weight(.medium))
                .foregroundStyle(Color.brindooTextSecondary)

            Picker(title, selection: selection) {
                ForEach(PaymentMethod.allCases) { method in
                    Text(method.shortLabel).tag(method)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Dichiarazione di chi incassa

    @ViewBuilder
    private var declareSection: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
            BrindooSectionHeader(iCollect ? "Hai ricevuto l'acconto?" : "Hai versato l'acconto?")

            Text(iCollect
                 ? "Scrivi quanto hai ricevuto: il cliente dovrà confermare."
                 : "Scrivi quanto hai versato: il professionista dovrà confermare.")
                .font(BrindooFont.bodySmall)
                .foregroundStyle(Color.brindooTextSecondary)

            HStack(spacing: BrindooSpacing.xs) {
                Text("€")
                    .font(BrindooFont.titleMedium)
                    .foregroundStyle(Color.brindooTextSecondary)
                TextField("0,00", text: $amountText)
                    .font(BrindooFont.titleMedium)
                    .keyboardType(.decimalPad)
                    .accessibilityLabel("Importo dell'acconto in euro")
            }
            .padding(BrindooSpacing.sm)
            .background(Color.brindooSurfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))

            if let amount, amount > proposal.currentPrice {
                Text("L'acconto non può superare il totale di \(proposal.currentPriceDisplay).")
                    .font(BrindooFont.caption)
                    .foregroundStyle(Color.brindooError)
            }

            BrindooTextField(
                title: "Nota (facoltativa)",
                placeholder: "Es. versato in contanti alla firma",
                text: $note
            )

            Button {
                Task { await declare() }
            } label: {
                if saving {
                    ProgressView().tint(.white).frame(maxWidth: .infinity)
                } else {
                    Text("Registra acconto")
                        .font(BrindooFont.button)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.brindooCoral)
            .disabled(!canDeclare)
        }
    }

    // MARK: - Conferma dell'altra parte

    @ViewBuilder
    private var confirmSection: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
            BrindooSectionHeader("Conferma")

            VStack(alignment: .leading, spacing: BrindooSpacing.xxs) {
                Text("Dichiarato: \(proposal.depositAmountDisplay ?? "-")")
                    .font(BrindooFont.bodyLarge.weight(.semibold))
                    .foregroundStyle(Color.brindooTextPrimary)
                Text("Modo: \(proposal.depositMethod?.label ?? "non indicato")")
                    .font(BrindooFont.bodySmall)
                    .foregroundStyle(Color.brindooTextSecondary)
                if let note = proposal.depositNote, !note.isEmpty {
                    Text("Nota: \(note)")
                        .font(BrindooFont.bodySmall)
                        .foregroundStyle(Color.brindooTextSecondary)
                }
            }
            .padding(BrindooSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.brindooSurface)
            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))

            Text("Conferma solo se i soldi sono davvero passati di mano.")
                .font(BrindooFont.caption)
                .foregroundStyle(Color.brindooTextSecondary)

            Button {
                Task { await confirm() }
            } label: {
                if saving {
                    ProgressView().tint(.white).frame(maxWidth: .infinity)
                } else {
                    Label("Confermo, l'acconto è stato versato", systemImage: "checkmark.circle.fill")
                        .font(BrindooFont.button)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.brindooSuccess)
            .disabled(saving)

            Button("Non risulta: annulla la registrazione") {
                showClearConfirm = true
            }
            .font(BrindooFont.bodySmall)
            .foregroundStyle(Color.brindooError)
        }
    }

    // MARK: - Riepilogo ad acconto confermato

    @ViewBuilder
    private var paidRecap: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
            BrindooSectionHeader("Riepilogo")

            recapRow("Acconto", proposal.depositAmountDisplay ?? "-")
            if let balance = proposal.balanceDueDisplay {
                recapRow("Resta da saldare", balance)
            }
            recapRow("Modo acconto", proposal.depositMethod?.shortLabel ?? "-")
            recapRow("Modo saldo", proposal.balanceMethod?.shortLabel ?? "-")
            if let date = proposal.depositConfirmedAt {
                recapRow("Confermato il", date.formatted(date: .abbreviated, time: .omitted))
            }

            Button("Annulla la registrazione dell'acconto") {
                showClearConfirm = true
            }
            .font(BrindooFont.bodySmall)
            .foregroundStyle(Color.brindooError)
            .padding(.top, BrindooSpacing.xs)
        }
    }

    @ViewBuilder
    private func recapRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(BrindooFont.bodySmall)
                .foregroundStyle(Color.brindooTextSecondary)
            Spacer()
            Text(value)
                .font(BrindooFont.bodyMedium.weight(.semibold))
                .foregroundStyle(Color.brindooTextPrimary)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Nota legale

    @ViewBuilder
    private var disclaimer: some View {
        Text("I pagamenti avvengono direttamente fra cliente e professionista. Brindoo non incassa, non trattiene e non garantisce le somme: registra solo quello che le parti dichiarano.")
            .font(BrindooFont.caption)
            .foregroundStyle(Color.brindooTextSecondary)
            .padding(.top, BrindooSpacing.xs)
    }

    // MARK: - Azioni

    private func saveMethods() async {
        saving = true
        defer { saving = false }
        do {
            try await OfferProposalService.shared.setPaymentMethods(
                proposalId: proposal.id,
                deposit: depositMethod,
                balance: balanceMethod
            )
            BrindooHaptics.notify(.success)
            toastCenter.show(BrindooToast("Modo di pagamento salvato", style: .success))
            await onChange()
        } catch {
            fail(error)
        }
    }

    private func declare() async {
        guard let amount else { return }
        saving = true
        defer { saving = false }
        do {
            try await OfferProposalService.shared.setPaymentMethods(
                proposalId: proposal.id,
                deposit: depositMethod,
                balance: balanceMethod
            )
            try await OfferProposalService.shared.declareDeposit(
                proposalId: proposal.id,
                amount: amount,
                method: depositMethod,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            BrindooHaptics.notify(.success)
            toastCenter.show(BrindooToast(
                "Acconto registrato",
                message: "In attesa della conferma dell'altra parte.",
                style: .success
            ))
            await onChange()
            dismiss()
        } catch {
            fail(error)
        }
    }

    private func confirm() async {
        saving = true
        defer { saving = false }
        do {
            try await OfferProposalService.shared.confirmDeposit(proposalId: proposal.id)
            BrindooHaptics.notify(.success)
            toastCenter.show(BrindooToast("Acconto confermato", style: .success))
            await onChange()
            dismiss()
        } catch {
            fail(error)
        }
    }

    private func clearDeposit() async {
        saving = true
        defer { saving = false }
        do {
            try await OfferProposalService.shared.clearDeposit(proposalId: proposal.id)
            toastCenter.show(BrindooToast("Registrazione annullata", style: .info))
            await onChange()
            dismiss()
        } catch {
            fail(error)
        }
    }

    private func fail(_ error: Error) {
        BrindooLog.error("Acconto: \(error)")
        toastCenter.show(BrindooToast(
            "Non è stato possibile salvare",
            message: "Controlla la connessione e riprova.",
            style: .error
        ))
    }
}
