//
//  ChatImageViews.swift
//  Brindoo
//
//  Viste della chat legate alle foto: visualizzazione a schermo intero,
//  anteprima prima dell'invio e viewer delle foto "bomba".
//  (Estratte da ChatView.)
//

import SwiftUI

// MARK: - Pending image wrapper

struct PendingImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

// MARK: - Full screen image

struct FullScreenWrapper: Identifiable {
    let id = UUID()
    let url: String
    let message: Message
}

struct FullScreenImageView: View {
    let url: String
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            AsyncImage(url: URL(string: url)) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                ProgressView().tint(.white)
            }

            Button { onClose() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white)
            }
            .padding()
        }
    }
}

// MARK: - Photo preview before send (stile WhatsApp)

struct PhotoPreviewSendView: View {
    let image: UIImage
    let onCancel: () -> Void
    let onSend: (_ asBomb: Bool) -> Void

    @State private var asBomb: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Top bar (rimane sotto la status bar grazie al safe area)
            HStack {
                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Anteprima foto")
                    .font(BrindooFont.bodyMedium.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer()

                // Spazio per bilanciare il bottone X
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, BrindooSpacing.md)
            .padding(.top, BrindooSpacing.sm)
            .padding(.bottom, BrindooSpacing.xs)

            // Image
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, BrindooSpacing.md)

            // Bottom bar
            HStack(spacing: BrindooSpacing.md) {
                // Toggle bomba
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        asBomb.toggle()
                    }
                } label: {
                    HStack(spacing: BrindooSpacing.xs) {
                        Image(systemName: asBomb ? "flame.fill" : "flame")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Bomba")
                            .font(BrindooFont.bodyMedium.weight(.semibold))
                    }
                    .foregroundStyle(asBomb ? .white : .white.opacity(0.85))
                    .padding(.horizontal, BrindooSpacing.md)
                    .padding(.vertical, BrindooSpacing.sm)
                    .background(asBomb ? Color.orange : Color.white.opacity(0.15))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Spacer()

                // Send
                Button {
                    onSend(asBomb)
                } label: {
                    HStack(spacing: BrindooSpacing.xs) {
                        Text("Invia")
                            .font(BrindooFont.bodyMedium.weight(.bold))
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, BrindooSpacing.lg)
                    .padding(.vertical, BrindooSpacing.sm)
                    .background(Color.brindooCoral)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, BrindooSpacing.md)
            .padding(.bottom, BrindooSpacing.md)

            if asBomb {
                HStack(spacing: BrindooSpacing.xs) {
                    Image(systemName: "info.circle.fill")
                    Text("La foto sparirà dopo che il destinatario la apre")
                        .font(BrindooFont.caption)
                }
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, BrindooSpacing.md)
                .padding(.bottom, BrindooSpacing.md)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}

// MARK: - Bomb image viewer (foto che sparisce dopo close)

struct BombImageViewer: View {
    let message: Message
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: BrindooSpacing.lg) {
                HStack {
                    HStack(spacing: BrindooSpacing.xs) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                        Text("Foto bomba")
                            .font(BrindooFont.bodyMedium.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Button { onClose() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
                    }
                }
                .padding()

                if let urlString = message.imageUrl,
                   let url = URL(string: urlString) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        ProgressView().tint(.white)
                    }
                } else {
                    Text("Foto non più disponibile")
                        .foregroundStyle(.white)
                }

                Text("Questa foto sparirà alla chiusura")
                    .font(BrindooFont.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.bottom)
            }
        }
    }
}
