//
//  LazioMapView.swift
//  Brindoo
//
//  Mappa stilizzata del Lazio con le 5 province: quelle coperte dal
//  professionista si accendono in corallo. Disegno geometrico "a tessere",
//  volutamente semplificato (non è una mappa geografica fedele).
//

import SwiftUI

// MARK: - Geometria delle province

private struct ProvinceTile {
    let province: LazioProvince
    /// Vertici del poligono in uno spazio normalizzato 100×110 (x destra, y giù).
    let points: [CGPoint]

    var centroid: CGPoint {
        guard !points.isEmpty else { return .zero }
        let sx = points.reduce(0) { $0 + $1.x }
        let sy = points.reduce(0) { $0 + $1.y }
        return CGPoint(x: sx / CGFloat(points.count), y: sy / CGFloat(points.count))
    }
}

/// Disposizione approssimata: Viterbo a nord-ovest, Rieti a nord-est,
/// Roma fascia centrale sulla costa, Frosinone a sud-est interno,
/// Latina sulla costa sud.
private let lazioTiles: [ProvinceTile] = [
    ProvinceTile(province: .viterbo, points: [
        .init(x: 18, y: 2), .init(x: 46, y: 8), .init(x: 42, y: 30),
        .init(x: 28, y: 38), .init(x: 6, y: 26)
    ]),
    ProvinceTile(province: .rieti, points: [
        .init(x: 46, y: 8), .init(x: 80, y: 2), .init(x: 92, y: 24),
        .init(x: 72, y: 46), .init(x: 54, y: 40), .init(x: 42, y: 30)
    ]),
    ProvinceTile(province: .roma, points: [
        .init(x: 6, y: 26), .init(x: 28, y: 38), .init(x: 42, y: 30),
        .init(x: 54, y: 40), .init(x: 72, y: 46), .init(x: 60, y: 64),
        .init(x: 36, y: 72), .init(x: 12, y: 50)
    ]),
    ProvinceTile(province: .frosinone, points: [
        .init(x: 72, y: 46), .init(x: 94, y: 54), .init(x: 86, y: 82),
        .init(x: 62, y: 82), .init(x: 60, y: 64)
    ]),
    ProvinceTile(province: .latina, points: [
        .init(x: 36, y: 72), .init(x: 60, y: 64), .init(x: 62, y: 82),
        .init(x: 74, y: 96), .init(x: 48, y: 108), .init(x: 28, y: 86)
    ])
]

private struct ProvinceShape: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        func map(_ p: CGPoint) -> CGPoint {
            CGPoint(x: rect.minX + p.x / 100 * rect.width,
                    y: rect.minY + p.y / 110 * rect.height)
        }
        path.move(to: map(first))
        for p in points.dropFirst() { path.addLine(to: map(p)) }
        path.closeSubpath()
        return path
    }
}

// MARK: - Vista mappa

struct LazioMapView: View {

    /// Province evidenziate. Vuoto = nessuna copertura dichiarata (tutto acceso).
    let highlighted: Set<LazioProvince>

    private func isOn(_ p: LazioProvince) -> Bool {
        highlighted.isEmpty || highlighted.contains(p)
    }

    var body: some View {
        GeometryReader { geo in
            let rect = CGRect(origin: .zero, size: geo.size)
            ZStack {
                ForEach(lazioTiles, id: \.province) { tile in
                    let on = isOn(tile.province)
                    ProvinceShape(points: tile.points)
                        .fill(on ? Color.brindooCoral.opacity(0.85) : Color.brindooCoral.opacity(0.10))
                    ProvinceShape(points: tile.points)
                        .stroke(Color.brindooBackground, lineWidth: 2)

                    Text(tile.province.rawValue)
                        .font(.system(size: min(geo.size.width, geo.size.height) * 0.075,
                                      weight: .bold, design: .rounded))
                        .foregroundStyle(on ? .white : Color.brindooTextSecondary.opacity(0.7))
                        .position(
                            x: rect.minX + tile.centroid.x / 100 * rect.width,
                            y: rect.minY + tile.centroid.y / 110 * rect.height
                        )
                }
            }
        }
        .aspectRatio(100.0 / 110.0, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        if highlighted.isEmpty || highlighted.count == LazioProvince.allCases.count {
            return "Zone coperte: tutto il Lazio"
        }
        let names = LazioProvince.allCases.filter { highlighted.contains($0) }.map(\.displayName)
        return "Zone coperte: province di " + names.joined(separator: ", ")
    }
}

// MARK: - Da slug delle aree a province

extension LazioArea {
    /// Province toccate da una lista di slug di copertura.
    /// Lista vuota = il professionista lavora in tutto il Lazio.
    static func provinces(forSlugs slugs: [String]) -> Set<LazioProvince> {
        guard !slugs.isEmpty else { return Set(LazioProvince.allCases) }
        return Set(slugs.compactMap { area(forSlug: $0)?.province })
    }
}

#Preview {
    VStack(spacing: 24) {
        LazioMapView(highlighted: [.roma, .latina])
            .frame(height: 180)
        LazioMapView(highlighted: [])
            .frame(height: 180)
    }
    .padding()
}
