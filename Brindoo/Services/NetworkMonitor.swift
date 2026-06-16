//
//  NetworkMonitor.swift
//  Brindoo
//
//  Monitor di connettività di rete con stato pubblicato per la UI.
//

import Foundation
import Network
import Observation

@MainActor
@Observable
final class NetworkMonitor {
    static let shared = NetworkMonitor()

    private(set) var isOnline: Bool = true
    private(set) var isExpensive: Bool = false
    private(set) var connectionType: NWInterface.InterfaceType?

    @ObservationIgnored private let monitor = NWPathMonitor()
    @ObservationIgnored private let queue = DispatchQueue(label: "brindoo.networkmonitor")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            let expensive = path.isExpensive
            let type = path.availableInterfaces.first(where: { path.usesInterfaceType($0.type) })?.type
            Task { @MainActor [weak self] in
                self?.isOnline = online
                self?.isExpensive = expensive
                self?.connectionType = type
            }
        }
        monitor.start(queue: queue)
    }
}
