//
//  BrindooPhotoPickerLabel.swift
//  Brindoo
//
//  Riquadro che fa da etichetta a un PhotosPicker: mostra la foto scelta,
//  quella gia' salvata, oppure l'invito a sceglierne una.
//
//  Sta in una vista a se' per due motivi. Primo: la closure di PhotosPicker
//  e' Sendable e non puo' leggere lo stato della schermata, quindi i valori
//  vanno passati come parametri. Secondo: le due schermate che lo usano
//  (nuova offerta, recensione) avevano lo stesso riquadro ricopiato, diverso
//  solo per altezza, icona e frase.
//

import SwiftUI

struct BrindooPhotoPickerLabel: View {
    /// Foto appena scelta dall'utente, se c'e'.
    let image: UIImage?
    /// Foto gia' salvata sul server, se c'e'.
    let existingUrl: String?
    let height: CGFloat
    let icon: String
    let hint: String
    var iconSize: CGFloat = 32

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let existingUrl, let url = URL(string: existingUrl) {
                BrindooCachedImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    BrindooSkeleton(cornerRadius: BrindooRadius.md)
                }
            } else {
                VStack(spacing: BrindooSpacing.xs) {
                    Image(systemName: icon)
                        .font(.system(size: iconSize))
                        .foregroundStyle(Color.brindooCoral)
                    Text(hint)
                        .font(BrindooFont.caption)
                        .foregroundStyle(Color.brindooTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(BrindooSpacing.md)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(Color.brindooSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: BrindooRadius.md)
                .strokeBorder(Color.brindooBorder, lineWidth: 1)
        )
    }
}
