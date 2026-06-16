//
//  BaseViewModel.swift
//  Brindoo
//
//  Protocollo base per i ViewModel della feature layer.
//  Espone uno stato di caricamento, errore e refresh standardizzato.
//

import Foundation
import Observation

/// Stato standard di una schermata data-driven.
enum LoadState<Value: Equatable>: Equatable {
    case idle
    case loading
    case loaded(Value)
    case empty
    case error(String)

    var value: Value? {
        if case .loaded(let v) = self { return v }
        return nil
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

@MainActor
protocol BrindooViewModel: AnyObject {
    func load() async
    func refresh() async
}
