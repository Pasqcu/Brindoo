//
//  ClientFeedbackPrompt.swift
//  Brindoo
//
//  Richiesta di esito evento mostrata al professionista in Agenda.
//  Vive in un file suo per tenere AgendaView leggibile.
//

import SwiftUI

// MARK: - "Com'è andata col cliente?"

/// Richiesta leggera mostrata al professionista dopo un evento passato.
/// Un tap e sparisce; si può anche saltare.
struct ClientFeedbackPrompt: View {

    let clientName: String
    let isSending: Bool
    let onChoose: (ClientOutcome) -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
            HStack(spacing: BrindooSpacing.xs) {
                Image(systemName: "hand.thumbsup")
                    .font(.system(size: 15, weight: .semibold))
                Text("Com'è andata con \(clientName)?")
                    .font(BrindooFont.titleSmall)
                Spacer(minLength: 0)
                Button("Salta", action: onSkip)
                    .font(BrindooFont.bodySmall)
                    .foregroundStyle(Color.brindooTextSecondary)
            }
            .foregroundStyle(Color.brindooCoral)

            Text("Resta un conteggio, non una recensione: nessuno leggerà commenti sul cliente.")
                .font(BrindooFont.caption)
                .foregroundStyle(Color.brindooTextSecondary)

            if isSending {
                ProgressView().tint(.brindooCoral).frame(maxWidth: .infinity)
            } else {
                VStack(spacing: BrindooSpacing.xs) {
                    ForEach(ClientOutcome.allCases) { outcome in
                        Button {
                            onChoose(outcome)
                        } label: {
                            HStack(spacing: BrindooSpacing.xs) {
                                Image(systemName: outcome.icon)
                                    .frame(width: 20)
                                Text(outcome.label)
                                    .font(BrindooFont.bodyMedium.weight(.medium))
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(outcome == .honored ? Color.brindooSuccess : Color.brindooTextPrimary)
                            .padding(.horizontal, BrindooSpacing.sm)
                            .padding(.vertical, BrindooSpacing.xs)
                            .frame(maxWidth: .infinity)
                            .background(Color.brindooSurfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(BrindooSpacing.md)
        .brindooSurfaceBackground()
        .brindooElevation(.card)
    }
}
