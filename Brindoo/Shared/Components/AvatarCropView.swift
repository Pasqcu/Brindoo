//
//  AvatarCropView.swift
//  Brindoo
//
//  Ritaglio della foto profilo: la foto scelta si sposta e si ingrandisce
//  sotto un cerchio, e si salva il quadrato che lo contiene. La foto copre
//  sempre tutto il cerchio: non restano bordi vuoti nell'avatar.
//

import SwiftUI
import UIKit

/// Foto da ritagliare, da passare a `.fullScreenCover(item:)`.
struct AvatarCropSource: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct AvatarCropView: View {

    let image: UIImage
    let onCancel: () -> Void
    let onDone: (UIImage) -> Void

    /// Lato del quadrato salvato, in pixel: basta e avanza per un avatar.
    static let outputSide: CGFloat = 1024
    static let maxZoom: CGFloat = 5

    @State private var zoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @GestureState private var pinch: CGFloat = 1
    @GestureState private var drag: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let diameter = max(1, min(geo.size.width, geo.size.height) - BrindooSpacing.xl * 2)
            let base = baseScale(diameter: diameter)
            let liveZoom = clampedZoom(zoom * pinch)
            let liveOffset = clamped(
                CGSize(width: offset.width + drag.width, height: offset.height + drag.height),
                zoom: liveZoom, base: base, diameter: diameter
            )

            // Base fissa a misura di schermo, tutto il resto in overlay: la
            // foto ingrandita sborda senza allargare niente. Prima stavano
            // in uno ZStack che cresceva con lo zoom e la maschera scura,
            // disegnata a coordinate fisse, scivolava via dal cerchio.
            Color.black
                .frame(width: geo.size.width, height: geo.size.height)
                .overlay {
                    Image(uiImage: image)
                        .resizable()
                        .frame(
                            width: image.size.width * base * liveZoom,
                            height: image.size.height * base * liveZoom
                        )
                        .offset(liveOffset)
                }
                .clipped()
                .overlay { cropMask(diameter: diameter) }
            .contentShape(Rectangle())
            .gesture(
                SimultaneousGesture(
                    MagnifyGesture()
                        .updating($pinch) { value, state, _ in state = value.magnification }
                        .onEnded { value in
                            zoom = clampedZoom(zoom * value.magnification)
                            offset = clamped(offset, zoom: zoom, base: base, diameter: diameter)
                        },
                    DragGesture()
                        .updating($drag) { value, state, _ in state = value.translation }
                        .onEnded { value in
                            offset = clamped(
                                CGSize(width: offset.width + value.translation.width,
                                       height: offset.height + value.translation.height),
                                zoom: zoom, base: base, diameter: diameter
                            )
                        }
                )
            )
            .onTapGesture(count: 2) {
                withAnimation(BrindooAnimation.smooth) {
                    zoom = 1
                    offset = .zero
                }
            }
            .overlay(alignment: .top) {
                Text("Sposta e ingrandisci")
                    .font(BrindooFont.titleSmall)
                    .foregroundStyle(.white)
                    .padding(.top, BrindooSpacing.md)
            }
            .overlay(alignment: .bottom) {
                HStack {
                    Button(BrindooText.cancel, action: onCancel)
                    Spacer()
                    Button("Usa foto") {
                        onDone(render(diameter: diameter, base: base))
                    }
                    .fontWeight(.semibold)
                }
                .font(BrindooFont.bodyLarge)
                .foregroundStyle(.white)
                .padding(.horizontal, BrindooSpacing.xl)
                .padding(.bottom, BrindooSpacing.lg)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .statusBarHidden()
    }

    /// Oscura tutto tranne il cerchio.
    private func cropMask(diameter: CGFloat) -> some View {
        ZStack {
            CropMaskShape(diameter: diameter)
                .fill(Color.black.opacity(0.6), style: FillStyle(eoFill: true))

            Circle()
                .strokeBorder(Color.white.opacity(0.8), lineWidth: 1)
                .frame(width: diameter, height: diameter)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Geometria

    /// Punti a schermo per punto di foto a zoom 1: la foto copre il cerchio.
    private func baseScale(diameter: CGFloat) -> CGFloat {
        guard image.size.width > 0, image.size.height > 0 else { return 1 }
        return max(diameter / image.size.width, diameter / image.size.height)
    }

    private func clampedZoom(_ value: CGFloat) -> CGFloat {
        min(max(value, 1), Self.maxZoom)
    }

    /// Lo spostamento non può scoprire il cerchio.
    private func clamped(_ value: CGSize, zoom: CGFloat, base: CGFloat, diameter: CGFloat) -> CGSize {
        let maxX = max(0, (image.size.width * base * zoom - diameter) / 2)
        let maxY = max(0, (image.size.height * base * zoom - diameter) / 2)
        return CGSize(
            width: min(max(value.width, -maxX), maxX),
            height: min(max(value.height, -maxY), maxY)
        )
    }

    /// Disegna il quadrato sotto il cerchio. `draw(in:)` rispetta già
    /// l'orientamento della foto.
    private func render(diameter: CGFloat, base: CGFloat) -> UIImage {
        let scale = base * zoom
        let off = clamped(offset, zoom: zoom, base: base, diameter: diameter)
        // Lato e origine del ritaglio in punti della foto.
        let cropSide = diameter / scale
        let originX = (image.size.width * scale / 2 - off.width - diameter / 2) / scale
        let originY = (image.size.height * scale / 2 - off.height - diameter / 2) / scale

        let side = min(Self.outputSide, cropSide * image.scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let ratio = side / cropSide
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            image.draw(in: CGRect(
                x: -originX * ratio,
                y: -originY * ratio,
                width: image.size.width * ratio,
                height: image.size.height * ratio
            ))
        }
    }
}

/// Rettangolo pieno con un buco tondo al centro. Il buco si calcola dal
/// rettangolo che la forma riceve, così resta sempre centrato.
private nonisolated struct CropMaskShape: Shape {
    let diameter: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        path.addEllipse(in: CGRect(
            x: rect.midX - diameter / 2,
            y: rect.midY - diameter / 2,
            width: diameter,
            height: diameter
        ))
        return path
    }
}
