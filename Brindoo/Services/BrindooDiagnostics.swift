//
//  BrindooDiagnostics.swift
//  Brindoo
//
//  Diagnostica senza servizi esterni:
//  - BrindooLogStore: archivio su file degli ultimi errori registrati
//  - BrindooCrashWatcher: raccoglie i rapporti di crash di sistema (MetricKit)
//  - BrindooDiagnostics: compone il rapporto che l'utente può inviare al supporto
//

import Foundation
import MetricKit
import UIKit

// MARK: - Archivio errori su file

/// Tiene su disco le ultime righe di errore, così un problema segnalato
/// dall'utente arriva al supporto con il contesto di cosa è andato storto.
final class BrindooLogStore: @unchecked Sendable {

    static let shared = BrindooLogStore()

    private let queue = DispatchQueue(label: "com.pasqcu.brindoo.logstore", qos: .utility)
    /// Oltre questa soglia il file viene dimezzato (si tiene la parte recente).
    private let maxBytes = 200_000

    private lazy var fileURL: URL? = {
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else { return nil }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("brindoo-errori.log")
    }()

    private static let timestamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "it_IT")
        return f
    }()

    /// Aggiunge una riga (con orario) in coda al file.
    func append(_ message: String) {
        queue.async { [self] in
            guard let url = fileURL else { return }
            let line = "[\(Self.timestamp.string(from: Date()))] \(message)\n"
            guard let data = line.data(using: .utf8) else { return }

            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: url)
            }

            trimIfNeeded(url)
        }
    }

    /// Contenuto attuale del registro (righe più vecchie in alto).
    func recentLog() -> String {
        queue.sync {
            guard let url = fileURL,
                  let text = try? String(contentsOf: url, encoding: .utf8)
            else { return "" }
            return text
        }
    }

    private func trimIfNeeded(_ url: URL) {
        guard let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? Int,
              size > maxBytes,
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return }
        // Tieni la seconda metà (le righe più recenti), allineata a inizio riga.
        let half = String(text.suffix(text.count / 2))
        let trimmed = half.drop(while: { $0 != "\n" }).dropFirst()
        try? String(trimmed).write(to: url, atomically: true, encoding: .utf8)
    }
}

// MARK: - Rapporti di crash (MetricKit)

/// Riceve dal sistema i rapporti di crash/blocco dell'app sui dispositivi reali
/// e li archivia nel registro. Nessun account o servizio esterno necessario.
final class BrindooCrashWatcher: NSObject, MXMetricManagerSubscriber {

    static let shared = BrindooCrashWatcher()
    private override init() { super.init() }

    /// Da chiamare una volta all'avvio dell'app.
    func start() {
        MXMetricManager.shared.add(self)
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            if let crashes = payload.crashDiagnostics, !crashes.isEmpty {
                for crash in crashes {
                    let reason = crash.terminationReason ?? "sconosciuta"
                    let signal = crash.signal.map(String.init) ?? "-"
                    BrindooLogStore.shared.append(
                        "CRASH (v\(crash.applicationVersion)) — causa: \(reason), segnale: \(signal)"
                    )
                }
            }
            if let hangs = payload.hangDiagnostics, !hangs.isEmpty {
                BrindooLogStore.shared.append(
                    "APP BLOCCATA: \(hangs.count) episodio/i di blocco rilevati dal sistema"
                )
            }
        }
    }
}

// MARK: - Rapporto per il supporto

enum BrindooDiagnostics {

    /// Testo del rapporto: dati del dispositivo + registro errori recente.
    @MainActor
    static func report() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let device = UIDevice.current
        let log = BrindooLogStore.shared.recentLog()

        return """
        RAPPORTO DIAGNOSTICO BRINDOO
        ============================
        App: \(version) (\(build))
        Dispositivo: \(device.model) — iOS \(device.systemVersion)
        Data: \(Date().formatted(date: .long, time: .standard))

        REGISTRO ERRORI RECENTE
        -----------------------
        \(log.isEmpty ? "(nessun errore registrato)" : log)
        """
    }

    /// Scrive il rapporto in un file temporaneo pronto da condividere.
    @MainActor
    static func reportFileURL() -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("diagnostica-brindoo.txt")
        do {
            try report().write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            BrindooLog.error("Impossibile creare il file di diagnostica: \(error)")
            return nil
        }
    }
}
