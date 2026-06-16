//
//  ReferralView.swift
//  Brindoo
//
//  Schermata "Invita amici": codice + statistiche + riscatto.
//

import SwiftUI

@MainActor
@Observable
final class ReferralViewModel: BrindooViewModel {
    var code: ReferralCode?
    var stats: ReferralStats = .zero
    var isLoading: Bool = true
    var errorMessage: String?

    var redeemCode: String = ""
    var redeemMessage: (style: BrindooBannerStyle, text: String)?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let codeTask = ReferralService.shared.fetchOrCreateMyCode()
            async let statsTask = ReferralService.shared.fetchMyStats()
            code = try await codeTask
            stats = (try? await statsTask) ?? .zero
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async { await load() }

    func redeem() async {
        do {
            try await ReferralService.shared.redeem(code: redeemCode)
            redeemMessage = (.success, "Codice riscattato! Riceverai il bonus a breve.")
            redeemCode = ""
            BrindooHaptics.notify(.success)
            await load()
        } catch let err as ReferralError {
            redeemMessage = (.error, err.localizedDescription)
            BrindooHaptics.notify(.error)
        } catch {
            redeemMessage = (.error, error.localizedDescription)
        }
    }
}

struct ReferralView: View {
    @State private var vm = ReferralViewModel()
    @State private var showShare = false

    var body: some View {
        ScrollView {
            VStack(spacing: BrindooSpacing.lg) {
                heroCard
                statsRow
                redeemSection
            }
            .padding(BrindooSpacing.md)
        }
        .background(Color.brindooBackground)
        .navigationTitle("Invita amici")
        .task { await vm.load() }
        .refreshable { await vm.refresh() }
        .sheet(isPresented: $showShare) {
            if let url = vm.code?.shareURL {
                ShareSheet(items: [
                    "Usa il mio codice \(vm.code?.displayCode ?? "") su Brindoo e ottieni 1 mese Pro gratis!",
                    url
                ])
            }
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        VStack(spacing: BrindooSpacing.md) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 92, height: 92)
                Image(systemName: BrindooIcon.gift)
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text("Invita un amico, ottieni 1 mese Pro gratis")
                .font(BrindooFont.titleMedium)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text("Quando un amico si iscrive con il tuo codice e completa il profilo, ricevi un mese Pro. Anche lui!")
                .font(BrindooFont.bodySmall)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)

            if vm.isLoading {
                ProgressView().tint(.white)
            } else if let code = vm.code {
                HStack(spacing: BrindooSpacing.xs) {
                    Text(code.displayCode)
                        .font(.system(size: 28, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, BrindooSpacing.md)
                        .padding(.vertical, BrindooSpacing.xs)
                        .background(Color.white.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
                    Button {
                        UIPasteboard.general.string = code.displayCode
                        BrindooHaptics.notify(.success)
                    } label: {
                        Image(systemName: BrindooIcon.copy)
                            .foregroundStyle(.white)
                            .font(.system(size: 18, weight: .bold))
                            .padding(BrindooSpacing.xs + 2)
                            .background(Color.white.opacity(0.18))
                            .clipShape(Circle())
                    }
                }
                BrindooButton("Condividi invito", style: .white, size: .medium, icon: BrindooIcon.share) {
                    showShare = true
                }
                .padding(.horizontal, BrindooSpacing.xl)
            }
        }
        .padding(BrindooSpacing.xl)
        .frame(maxWidth: .infinity)
        .background(BrindooGradient.coral)
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.xl))
        .brindooCardShadow()
    }

    private var statsRow: some View {
        HStack(spacing: BrindooSpacing.md) {
            BrindooStatTile(
                icon: BrindooIcon.invite,
                value: "\(vm.stats.totalInvited)",
                label: "Inviti inviati"
            )
            BrindooStatTile(
                icon: BrindooIcon.success,
                value: "\(vm.stats.totalActivated)",
                label: "Attivati",
                tint: .brindooSuccess
            )
            BrindooStatTile(
                icon: BrindooIcon.crown,
                value: "\(vm.stats.proMonthsEarned)",
                label: "Mesi Pro",
                tint: Color(red: 0.95, green: 0.6, blue: 0.15)
            )
        }
    }

    private var redeemSection: some View {
        BrindooCard(style: .flat) {
            VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
                BrindooSectionHeader("Hai un codice da un amico?", subtitle: "Inseriscilo qui per riscattarlo.")
                BrindooTextField(
                    placeholder: "Es. BRN-1234",
                    text: $vm.redeemCode,
                    icon: BrindooIcon.referral,
                    autocapitalization: .characters
                )
                if let msg = vm.redeemMessage {
                    BrindooBanner(style: msg.style, title: msg.text)
                }
                BrindooButton("Riscatta", style: .primary, isDisabled: vm.redeemCode.isEmpty) {
                    Task { await vm.redeem() }
                }
            }
        }
    }
}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
