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
    /// Se presente, mostra il bottone "risposte rapide" (lato professionista).
    var onQuickReply: ((String) -> Void)? = nil
    /// Se presente, col campo vuoto il bottone d'invio diventa un microfono.
    var onSendVoice: ((URL, TimeInterval) -> Void)? = nil

    @State private var recorder = VoiceRecorder()
    @State private var micDenied = false

    var body: some View {
        Group {
            if recorder.isRecording || recorder.fileURL != nil {
                recordingBar
            } else {
                composerBar
            }
        }
        .padding(.horizontal, BrindooSpacing.md)
        .padding(.vertical, BrindooSpacing.sm)
        .background(Color.brindooBackground)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.brindooBorder).frame(height: 0.5)
        }
        // Se si esce dalla chat a metà registrazione, niente resti:
        // né file orfani né sessione audio lasciata accesa.
        .onDisappear { recorder.cancel() }
        .alert("Microfono non disponibile", isPresented: $micDenied) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Consenti l'accesso al microfono dalle Impostazioni di iOS per mandare vocali.")
        }
    }

    /// Barra di registrazione: puntino rosso, tempo, butta o invia.
    private var recordingBar: some View {
        HStack(spacing: BrindooSpacing.sm) {
            Circle()
                .fill(Color.brindooError)
                .frame(width: 10, height: 10)
                .opacity(recorder.isRecording ? 1 : 0.4)

            Text(VoiceMessage.durationLabel(recorder.elapsed))
                .font(BrindooFont.bodyMedium.monospacedDigit())
                .foregroundStyle(Color.brindooTextPrimary)

            Text(recorder.isRecording ? "Sto registrando..." : "Pronto da inviare")
                .font(BrindooFont.caption)
                .foregroundStyle(Color.brindooTextSecondary)

            Spacer()

            Button {
                recorder.cancel()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.brindooTextSecondary)
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel("Butta la registrazione")

            Button {
                BrindooHaptics.impact(.light)
                // Sotto il secondo `stop()` butta da solo, senza drammi.
                if let clip = recorder.stop() {
                    onSendVoice?(clip.url, clip.duration)
                }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 40, height: 40)
            .background(Color.brindooCoral)
            .clipShape(Circle())
            .accessibilityLabel("Invia il vocale")
        }
    }

    private var composerBar: some View {
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

            if let onQuickReply {
                QuickReplyMenuButton(onPick: onQuickReply)
            }

            TextField("Scrivi un messaggio", text: $inputText, axis: .vertical)
                .lineLimit(1...5)
                .font(BrindooFont.bodyMedium)
                .padding(.horizontal, BrindooSpacing.md)
                .padding(.vertical, BrindooSpacing.sm)
                .brindooSurfaceBackground(radius: BrindooRadius.lg)
                .disabled(isSending)

            if showMic {
                // Campo vuoto: si parla. Come si aspettano tutti dal 2015.
                Button {
                    BrindooHaptics.impact(.light)
                    Task {
                        if await !recorder.start() { micDenied = true }
                    }
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 40, height: 40)
                .background(Color.brindooCoral)
                .clipShape(Circle())
                .disabled(isSending)
                .accessibilityLabel("Registra un messaggio vocale")
            } else {
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
        }
    }

    private var showMic: Bool {
        onSendVoice != nil && !isEditing && !isAttachDisabled
            && inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
