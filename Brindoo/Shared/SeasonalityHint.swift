//
//  SeasonalityHint.swift
//  Brindoo
//
//  Avviso "periodo molto richiesto" sotto i selettori di data:
//  nei mesi di punta degli eventi nel Lazio (maggio, giugno, settembre,
//  dicembre) i professionisti si prenotano con largo anticipo.
//

import SwiftUI

enum Seasonality {

    /// Mesi di punta per gli eventi nel Lazio: matrimoni da maggio a
    /// luglio e a settembre, feste aziendali e private a dicembre.
    /// Luglio mancava, ed è uno dei mesi in cui si fatica di più a
    /// trovare un professionista libero.
    static let peakMonths: Set<Int> = [5, 6, 7, 9, 12]

    static func isPeak(_ date: Date) -> Bool {
        peakMonths.contains(Calendar.current.component(.month, from: date))
    }

    /// Sotto questo margine il consiglio di muoversi in anticipo non serve
    /// più: l'anticipo non c'è già più, e va detta un'altra cosa.
    static let shortNoticeDays = 30

    static func isShortNotice(_ date: Date, from now: Date = Date()) -> Bool {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: date)).day ?? 0
        return days <= shortNoticeDays
    }
}

/// Riga di avviso mostrata solo se la data cade in un mese di punta.
struct SeasonalityHintRow: View {
    let date: Date

    var body: some View {
        if Seasonality.isPeak(date) {
            HStack(alignment: .top, spacing: BrindooSpacing.xs) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 13, weight: .semibold))
                Text(Seasonality.isShortNotice(date)
                     ? "Periodo molto richiesto e data vicina: aspettati poche disponibilità, conviene contattarne più di uno."
                     : "Periodo molto richiesto: in questo mese i professionisti si prenotano in fretta, muoviti in anticipo.")
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(BrindooFont.caption)
            .foregroundStyle(Color.brindooWarning)
        }
    }
}
