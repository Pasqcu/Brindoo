//
//  BrindooSectionHeader.swift
//  Brindoo
//
//  Header standard per sezioni di lista o schermate.
//

import SwiftUI

struct BrindooSectionHeader: View {
    let title: String
    let subtitle: String?
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        _ title: String,
        subtitle: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BrindooFont.titleLarge)
                    .foregroundStyle(Color.brindooTextPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(BrindooFont.bodySmall)
                        .foregroundStyle(Color.brindooTextSecondary)
                }
            }
            Spacer()
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(BrindooFont.buttonSmall)
                        .foregroundStyle(Color.brindooCoral)
                }
            }
        }
    }
}
