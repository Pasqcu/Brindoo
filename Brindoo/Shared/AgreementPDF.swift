//
//  AgreementPDF.swift
//  Brindoo
//
//  L'accordo chiuso come PDF: stesso contenuto del riepilogo testuale,
//  ma in un foglio con intestazione, pronto da archiviare o inoltrare.
//  Nel mondo eventi il "pezzo di carta" chiude le discussioni.
//

import SwiftUI
import UIKit

enum AgreementPDF {

    /// Genera il PDF su file temporaneo e ne restituisce l'URL.
    /// Riceve il testo già composto (`AgreementSummary.text`): così il
    /// disegno e la scrittura su disco stanno fuori dal main actor senza
    /// portarsi dietro i modelli.
    nonisolated static func render(body: String, filename: String) async -> URL? {

        // A4 in punti, margini generosi: deve sembrare un documento, non uno scontrino.
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let margin: CGFloat = 56
        let coral = UIColor(red: 1.00, green: 0.45, blue: 0.38, alpha: 1)

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        paragraph.paragraphSpacing = 4

        // Il testo del riepilogo ha già titolo e data nelle prime righe:
        // qui le prime due diventano intestazione grafica, il resto corpo.
        let lines = body.components(separatedBy: "\n")
        let headerTitle = "Brindoo"
        let headerSubtitle = lines.count > 1 ? lines[1] : ""
        let bodyText = lines.dropFirst(2).joined(separator: "\n")

        let renderer = UIGraphicsPDFRenderer(bounds: page)
        let data = renderer.pdfData { ctx in
            ctx.beginPage()

            headerTitle.draw(
                at: CGPoint(x: margin, y: margin),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 30, weight: .heavy),
                    .foregroundColor: coral
                ]
            )
            "Riepilogo accordo".draw(
                at: CGPoint(x: margin, y: margin + 38),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 15, weight: .semibold),
                    .foregroundColor: UIColor.black
                ]
            )
            headerSubtitle.draw(
                at: CGPoint(x: margin, y: margin + 58),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 11),
                    .foregroundColor: UIColor.darkGray
                ]
            )

            // Filo di separazione color corallo sotto l'intestazione.
            let line = ctx.cgContext
            line.setStrokeColor(coral.cgColor)
            line.setLineWidth(2)
            line.move(to: CGPoint(x: margin, y: margin + 80))
            line.addLine(to: CGPoint(x: page.width - margin, y: margin + 80))
            line.strokePath()

            bodyText.draw(
                in: CGRect(
                    x: margin, y: margin + 96,
                    width: page.width - margin * 2,
                    height: page.height - margin * 2 - 96
                ),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 11.5),
                    .foregroundColor: UIColor.black,
                    .paragraphStyle: paragraph
                ]
            )
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

/// Bottone "Accordo in PDF": genera il file e apre la condivisione.
/// Un componente solo per i tre punti in cui l'accordo si condivide.
struct AgreementPDFShareButton: View {

    let offer: ServiceOffer
    let organizerName: String?
    var clientName: String? = nil
    let proposal: OfferProposal

    /// `compact`: solo icona, per le righe di lista accanto agli altri bottoni.
    var compact: Bool = false

    @State private var pdfURL: URL?
    @State private var isRendering = false

    var body: some View {
        Button {
            guard !isRendering else { return }
            isRendering = true
            let body = AgreementSummary.text(
                offer: offer,
                organizerName: organizerName,
                clientName: clientName,
                proposal: proposal
            )
            let filename = "accordo-brindoo-\(BrindooFormat.dayString(from: Date())).pdf"
            Task {
                pdfURL = await AgreementPDF.render(body: body, filename: filename)
                isRendering = false
            }
        } label: {
            if compact {
                Image(systemName: "doc.richtext")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.brindooCoral)
                    .frame(width: 44, height: 44)
                    .background(Color.brindooCoral.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
            } else {
                Label("Accordo in PDF", systemImage: "doc.richtext")
                    .font(BrindooFont.bodySmall.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, BrindooSpacing.sm)
                    .foregroundStyle(Color.brindooCoral)
            }
        }
        .accessibilityLabel("Accordo in PDF")
        .sheet(item: $pdfURL) { url in
            ActivityShareSheet(items: [url])
        }
    }
}

/// `sheet(item:)` vuole Identifiable: per un file temporaneo basta il percorso.
extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
