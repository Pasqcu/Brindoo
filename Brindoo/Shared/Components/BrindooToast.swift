//
//  BrindooToast.swift
//  Brindoo
//
//  Toast effimero da mostrare in overlay con auto-dismiss.
//

import SwiftUI
import Combine

struct BrindooToast: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String?
    let style: BrindooBannerStyle
    let duration: TimeInterval

    init(_ title: String, message: String? = nil, style: BrindooBannerStyle = .info, duration: TimeInterval = 2.4) {
        self.title = title
        self.message = message
        self.style = style
        self.duration = duration
    }
}

@MainActor
final class BrindooToastCenter: ObservableObject {
    @Published var current: BrindooToast?
    private var dismissTask: Task<Void, Never>?

    func show(_ toast: BrindooToast) {
        dismissTask?.cancel()
        withAnimation(BrindooAnimation.smooth) {
            current = toast
        }
        BrindooHaptics.notify(toast.style == .error ? .error : (toast.style == .success ? .success : .warning))
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(toast.duration * 1_000_000_000))
            if Task.isCancelled { return }
            await MainActor.run {
                withAnimation(BrindooAnimation.smooth) {
                    self?.current = nil
                }
            }
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        withAnimation(BrindooAnimation.smooth) {
            current = nil
        }
    }
}

struct BrindooToastOverlay: ViewModifier {
    @EnvironmentObject private var center: BrindooToastCenter

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast = center.current {
                    BrindooBanner(
                        style: toast.style,
                        title: toast.title,
                        message: toast.message,
                        dismissAction: { center.dismiss() }
                    )
                    .padding(.horizontal, BrindooSpacing.md)
                    .padding(.top, BrindooSpacing.xs)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(999)
                }
            }
    }
}

extension View {
    func brindooToastOverlay() -> some View {
        modifier(BrindooToastOverlay())
    }
}
