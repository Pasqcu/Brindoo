//
//  BrindooLiveActivityBundle.swift
//  BrindooLiveActivity (Widget Extension target)
//
//  Punto di ingresso del Widget Extension. Va creato dal template Xcode
//  (File > New > Target > Widget Extension), poi sostituisci il file
//  generato con questo. Espone tutti i widget dell'app — al momento solo
//  la Live Activity delle trattative.
//

import SwiftUI
import WidgetKit

@main
struct BrindooLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 16.2, *) {
            BrindooNegotiationLiveActivity()
        }
    }
}
