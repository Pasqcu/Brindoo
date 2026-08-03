//
//  VoiceMessage.swift
//  Brindoo
//
//  Messaggi vocali in chat: registrazione (AAC .m4a), invio e riproduzione.
//  Per il database un vocale è un messaggio "image" con URL che finisce
//  in .m4a: nessuna colonna nuova, decide tutto il client. Il testo del
//  messaggio porta la durata, così anteprime e notifiche restano parlanti.
//

import SwiftUI
import AVFoundation

enum VoiceMessage {

    /// Oltre i due minuti un vocale è un podcast: la registrazione si ferma da sola.
    static let maxDuration: TimeInterval = 120

    static func isVoiceURL(_ urlString: String?) -> Bool {
        urlString?.hasSuffix(".m4a") == true
    }

    /// "0:42" / "1:05".
    static func durationLabel(_ t: TimeInterval) -> String {
        let s = max(0, Int(t.rounded()))
        return "\(s / 60):" + String(format: "%02d", s % 60)
    }

    /// Contenuto testuale del messaggio (anteprime, risposte, accessibilità).
    static func contentLabel(duration: TimeInterval) -> String {
        "🎤 Messaggio vocale · \(durationLabel(duration))"
    }

    /// Copia locale del vocale remoto, scaricata una volta sola.
    /// Il nome file è già un UUID: fa da chiave di cache senza inventarne una.
    nonisolated static func localFile(for remote: URL) async throws -> URL {
        let fm = FileManager.default
        let base = fm.urls(for: .cachesDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        let dir = base.appendingPathComponent("BrindooVoice", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let local = dir.appendingPathComponent(remote.lastPathComponent)
        if fm.fileExists(atPath: local.path) { return local }
        let (data, _) = try await URLSession.shared.data(from: remote)
        try data.write(to: local, options: .atomic)
        return local
    }
}

// MARK: - Registratore

@MainActor
@Observable
final class VoiceRecorder {

    private var recorder: AVAudioRecorder?
    private var tick: Task<Void, Never>?
    private(set) var fileURL: URL?
    private(set) var isRecording = false
    private(set) var elapsed: TimeInterval = 0

    /// Avvia la registrazione. False se il microfono è negato o non parte.
    func start() async -> Bool {
        guard await AVAudioApplication.requestRecordPermission() else { return false }

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try? session.setActive(true)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        guard let r = try? AVAudioRecorder(url: url, settings: settings), r.record() else {
            try? session.setActive(false)
            return false
        }

        recorder = r
        fileURL = url
        elapsed = 0
        isRecording = true

        tick = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard let self, let rec = self.recorder else { return }
                self.elapsed = rec.currentTime
                if rec.currentTime >= VoiceMessage.maxDuration {
                    // Tetto raggiunto: si ferma il nastro, la barra resta
                    // in mano alla persona per inviare o buttare.
                    self.elapsed = rec.currentTime
                    rec.stop()
                    self.recorder = nil
                    return
                }
            }
        }
        return true
    }

    /// Ferma e restituisce file e durata; nil se troppo corto (< 1s).
    func stop() -> (url: URL, duration: TimeInterval)? {
        tick?.cancel()
        if let r = recorder {
            elapsed = r.currentTime
            r.stop()
            recorder = nil
        }
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        guard elapsed >= 1, let fileURL else { return nil }
        return (fileURL, elapsed)
    }

    /// Butta la registrazione e pulisce il file.
    func cancel() {
        tick?.cancel()
        recorder?.stop()
        recorder = nil
        isRecording = false
        if let fileURL { try? FileManager.default.removeItem(at: fileURL) }
        fileURL = nil
        elapsed = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

// MARK: - Riproduttore

@MainActor
@Observable
final class VoicePlayer {

    private var player: AVAudioPlayer?
    private var tick: Task<Void, Never>?
    private(set) var isPlaying = false
    private(set) var isLoading = false
    private(set) var progress: Double = 0
    private(set) var duration: TimeInterval = 0
    private(set) var failed = false

    func toggle(urlString: String) async {
        if isPlaying {
            pause()
            return
        }
        if player == nil {
            guard let remote = URL(string: urlString) else {
                failed = true
                return
            }
            isLoading = true
            defer { isLoading = false }
            do {
                let local = try await VoiceMessage.localFile(for: remote)
                let p = try AVAudioPlayer(contentsOf: local)
                p.prepareToPlay()
                player = p
                duration = p.duration
                failed = false
            } catch {
                failed = true
                return
            }
        }

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio)
        try? session.setActive(true)
        player?.play()
        isPlaying = true

        tick = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self, let p = self.player else { return }
                self.progress = p.duration > 0 ? p.currentTime / p.duration : 0
                if !p.isPlaying, self.isPlaying {
                    // Arrivato in fondo (o interrotto dal sistema): si riparte da capo.
                    self.isPlaying = false
                    p.currentTime = 0
                    self.progress = 0
                    return
                }
            }
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        tick?.cancel()
    }
}

// MARK: - Bolla vocale

/// La bolla del messaggio vocale: play/pausa, barra di avanzamento, durata.
struct VoiceMessageBubble: View {

    let urlString: String
    let isOwn: Bool
    /// Etichetta dal contenuto del messaggio (es. "0:42"), mostrata
    /// finché il file non è stato scaricato e la durata vera non è nota.
    let fallbackContent: String

    @State private var player = VoicePlayer()

    private var accent: Color { isOwn ? .white : .brindooCoral }

    var body: some View {
        HStack(spacing: BrindooSpacing.sm) {
            Button {
                Task { await player.toggle(urlString: urlString) }
            } label: {
                ZStack {
                    Circle()
                        .fill(accent.opacity(isOwn ? 0.25 : 0.15))
                        .frame(width: 36, height: 36)
                    if player.isLoading {
                        ProgressView().tint(accent).scaleEffect(0.7)
                    } else {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(accent)
                    }
                }
            }
            .disabled(player.isLoading)
            .accessibilityLabel(player.isPlaying ? "Metti in pausa" : "Ascolta il messaggio vocale")

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(accent.opacity(0.25))
                        .frame(height: 4)
                    Capsule()
                        .fill(accent)
                        .frame(width: max(4, geo.size.width * player.progress), height: 4)
                }
                .frame(maxHeight: .infinity)
            }
            .frame(width: 110, height: 36)

            Text(player.duration > 0
                 ? VoiceMessage.durationLabel(player.duration)
                 : durationFromContent)
                .font(BrindooFont.caption.monospacedDigit())
                .foregroundStyle(isOwn ? .white.opacity(0.85) : Color.brindooTextSecondary)
        }
        .padding(.horizontal, BrindooSpacing.sm)
        .padding(.vertical, BrindooSpacing.xs)
        .overlay {
            if player.failed {
                Text("Vocale non disponibile")
                    .font(BrindooFont.caption)
                    .foregroundStyle(isOwn ? .white.opacity(0.85) : Color.brindooTextSecondary)
            }
        }
    }

    /// Estrae "0:42" da "🎤 Messaggio vocale · 0:42"; vuoto se assente.
    private var durationFromContent: String {
        fallbackContent.components(separatedBy: "· ").last.flatMap {
            $0.contains(":") ? $0 : nil
        } ?? "–:––"
    }
}
