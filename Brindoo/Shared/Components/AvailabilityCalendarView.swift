//
//  AvailabilityCalendarView.swift
//  Brindoo
//
//  Calendario mensile in sola lettura: mostra ai clienti i giorni in cui
//  il professionista NON è disponibile, prima ancora di contattarlo.
//

import SwiftUI

struct AvailabilityCalendarView: View {

    /// Giorni occupati, formato "yyyy-MM-dd".
    let unavailableDays: Set<String>

    @State private var monthOffset: Int = 0

    private let calendar = Calendar.current
    private let maxMonthsAhead = 5

    private static let dayKey: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private static let monthTitle: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    private var displayedMonth: Date {
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
        return calendar.date(byAdding: .month, value: monthOffset, to: start) ?? start
    }

    var body: some View {
        VStack(spacing: BrindooSpacing.sm) {
            // Intestazione con frecce mese precedente/successivo
            HStack {
                Button {
                    monthOffset -= 1
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(monthOffset > 0 ? Color.brindooCoral : Color.brindooTextTertiary)
                }
                .disabled(monthOffset <= 0)

                Spacer()

                Text(Self.monthTitle.string(from: displayedMonth).capitalized)
                    .font(BrindooFont.bodyMedium.weight(.semibold))

                Spacer()

                Button {
                    monthOffset += 1
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(monthOffset < maxMonthsAhead ? Color.brindooCoral : Color.brindooTextTertiary)
                }
                .disabled(monthOffset >= maxMonthsAhead)
            }

            // Iniziali dei giorni della settimana (lun → dom)
            HStack {
                ForEach(["L", "M", "M", "G", "V", "S", "D"].indices, id: \.self) { i in
                    Text(["L", "M", "M", "G", "V", "S", "D"][i])
                        .font(BrindooFont.caption.weight(.semibold))
                        .foregroundStyle(Color.brindooTextSecondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Griglia dei giorni
            let days = monthDays()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
                ForEach(days.indices, id: \.self) { i in
                    if let day = days[i] {
                        dayCell(day)
                    } else {
                        Color.clear.frame(height: 32)
                    }
                }
            }

            // Legenda
            HStack(spacing: BrindooSpacing.md) {
                legendDot(color: .brindooError, label: "Occupato")
                legendDot(color: .brindooSuccess, label: "Libero")
                Spacer()
            }
            .padding(.top, BrindooSpacing.xxs)
        }
        .padding(BrindooSpacing.md)
        .background(Color.brindooSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
        .accessibilityLabel("Calendario disponibilità del professionista")
    }

    // MARK: - Celle

    @ViewBuilder
    private func dayCell(_ date: Date) -> some View {
        let key = Self.dayKey.string(from: date)
        let isBusy = unavailableDays.contains(key)
        let isPast = date < calendar.startOfDay(for: Date())
        let isToday = calendar.isDateInToday(date)

        Text("\(calendar.component(.day, from: date))")
            .font(BrindooFont.bodySmall.weight(isToday ? .bold : .regular))
            .foregroundStyle(
                isPast ? Color.brindooTextTertiary :
                isBusy ? Color.brindooError : Color.brindooTextPrimary
            )
            .strikethrough(isBusy && !isPast, color: .brindooError)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(
                Circle()
                    .fill(isBusy && !isPast ? Color.brindooError.opacity(0.1)
                          : isToday ? Color.brindooCoral.opacity(0.12)
                          : Color.clear)
            )
            .accessibilityLabel(isBusy ? "Giorno occupato" : "Giorno libero")
    }

    @ViewBuilder
    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(BrindooFont.caption)
                .foregroundStyle(Color.brindooTextSecondary)
        }
    }

    // MARK: - Date del mese

    /// Giorni del mese mostrato, con `nil` come riempitivo prima del primo
    /// giorno (settimana che inizia di lunedì).
    private func monthDays() -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))
        else { return [] }

        // weekday: 1 = domenica … 7 = sabato → indice 0 = lunedì
        let weekday = calendar.component(.weekday, from: firstDay)
        let leading = (weekday + 5) % 7

        var days: [Date?] = Array(repeating: nil, count: leading)
        for day in range {
            days.append(calendar.date(byAdding: .day, value: day - 1, to: firstDay))
        }
        return days
    }
}
