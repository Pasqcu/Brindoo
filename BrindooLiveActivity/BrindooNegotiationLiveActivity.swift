//
//  BrindooNegotiationLiveActivity.swift
//  BrindooLiveActivity (Widget Extension target)
//
//  Vista della Live Activity per le trattative.
//  IMPORTANTE: questo file NON fa parte del target principale Brindoo.
//  Va spostato dentro un nuovo Widget Extension target che dovrai creare
//  da Xcode. Vedi README.md nella stessa cartella per istruzioni complete.
//
//  Una volta dentro il widget target, ricordati di aggiungere anche
//  `Brindoo/LiveActivities/NegotiationActivityAttributes.swift` al membership
//  del widget target (Target Inspector → Target Membership).
//

import ActivityKit
import SwiftUI
import WidgetKit

@available(iOS 16.2, *)
struct BrindooNegotiationLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NegotiationActivityAttributes.self) { context in
            // Lock Screen / Notification view
            lockScreenView(context)
                .activityBackgroundTint(Color.black.opacity(0.05))
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        Image(systemName: "tag.fill")
                            .foregroundStyle(.orange)
                        Text(context.attributes.offerTitle)
                            .font(.caption).bold()
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("€\(context.state.currentPrice)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.orange)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Image(systemName: statusIcon(context.state.status))
                        Text(statusLabel(context.state.status, viewer: context.attributes.viewerRole, last: context.state.lastProposer))
                            .font(.caption)
                        Spacer()
                        Text(context.attributes.counterpartyName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: "tag.fill")
                    .foregroundStyle(.orange)
            } compactTrailing: {
                Text("€\(context.state.currentPrice)")
                    .font(.caption2).bold()
            } minimal: {
                Image(systemName: "tag.fill")
                    .foregroundStyle(.orange)
            }
        }
    }

    @ViewBuilder
    private func lockScreenView(_ context: ActivityViewContext<NegotiationActivityAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "tag.fill").foregroundStyle(.orange)
                Text(context.attributes.offerTitle)
                    .font(.subheadline).bold()
                    .lineLimit(1)
                Spacer()
                Text("€\(context.state.currentPrice)")
                    .font(.title3).bold()
                    .foregroundStyle(.orange)
            }
            HStack(spacing: 6) {
                Image(systemName: statusIcon(context.state.status))
                    .font(.caption)
                Text(statusLabel(
                    context.state.status,
                    viewer: context.attributes.viewerRole,
                    last: context.state.lastProposer
                ))
                .font(.caption)
                Spacer()
                Text(context.attributes.counterpartyName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private func statusIcon(_ status: NegotiationActivityAttributes.ContentState.NegotiationStatus) -> String {
        switch status {
        case .pending:   return "arrow.left.arrow.right"
        case .accepted:  return "checkmark.circle.fill"
        case .rejected:  return "xmark.circle.fill"
        case .withdrawn: return "arrow.uturn.backward"
        }
    }

    private func statusLabel(
        _ status: NegotiationActivityAttributes.ContentState.NegotiationStatus,
        viewer: NegotiationActivityAttributes.ContentState.Proposer,
        last: NegotiationActivityAttributes.ContentState.Proposer
    ) -> String {
        switch status {
        case .accepted:  return "Accettata"
        case .rejected:  return "Rifiutata"
        case .withdrawn: return "Ritirata"
        case .pending:
            return last == viewer ? "In attesa di risposta" : "Hai una controproposta"
        }
    }
}
