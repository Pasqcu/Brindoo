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

    /// Mesi di punta per gli eventi (matrimoni a maggio/giugno/settembre,
    /// feste aziendali e private a dicembre).
    static let peakMonths: Set<Int> = [5, 6, 9, 12]

    static func isPeak(_ date: Date) -> Bool {
        peakMonths.contains(Calendar.current.component(.month, from: date))
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
                Text("Periodo molto richiesto: in questo mese i professionisti si prenotano in fretta, muoviti in anticipo.")
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(BrindooFont.caption)
            .foregroundStyle(Color.brindooWarning)
        }
    }
}
