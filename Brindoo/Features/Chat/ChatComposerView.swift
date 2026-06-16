//
//  ChatComposerView.swift
//  Brindoo
//
//  Composer riutilizzabile per ChatView: campo testo, allegato, invio.
//

import SwiftUI
import PhotosUI

struct ChatComposerView: View {
    @Binding var inputText: String
    @Binding var photoPickerItem: PhotosPickerItem?

    let isSending: Bool
    let isEditing: Bool
    let isAttachDisabled: Bool
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: BrindooSpacing.sm) {
            PhotosPicker(
                selection: $photoPickerItem,
                matching: .images,
                preferredItemEncoding: .compatible,
                photoLibrary: .shared()
            ) {
                Image(systemName: BrindooIcon.attachment)
                    .font(.system(size: 22))
                    .foregroundStyle(isAttachDisabled ? Color.brindooBorder : Color.brindooCoral)
            }
            .disabled(isAttachDisabled)
            .accessibilityLabel("Allega foto")

            TextField("Scrivi un messaggio", text: $inputText, axis: .vertical)
                .lineLimit(1...5)
                .font(BrindooFont.bodyMedium)
                .padding(.horizontal, BrindooSpacing.md)
                .padding(.vertical, BrindooSpacing.sm)
                .background(Color.brindooSurface)
                .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.lg))
                .disabled(isSending)

            Button {
                BrindooHaptics.impact(.light)
                onSend()
            } label: {
                if isSending {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: isEditing ? "checkmark" : "arrow.up")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 40, height: 40)
            .background(canSend ? Color.brindooCoral : Color.brindooBorder)
            .clipShape(Circle())
            .disabled(!canSend || isSending)
            .brindooPressEffect(isPressed: isSending)
            .accessibilityLabel(isEditing ? "Salva modifica" : "Invia messaggio")
        }
        .padding(.horizontal, BrindooSpacing.md)
        .padding(.vertical, BrindooSpacing.sm)
        .background(Color.brindooBackground)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.brindooBorder).frame(height: 0.5)
        }
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
