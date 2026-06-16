//
//  BrindooTextField.swift
//

import SwiftUI

struct BrindooTextField: View {
    let title: String?
    let placeholder: String
    @Binding var text: String
    let icon: String?
    let isSecure: Bool
    let keyboardType: UIKeyboardType
    let textContentType: UITextContentType?
    let autocapitalization: TextInputAutocapitalization
    let errorMessage: String?
    let isDisabled: Bool
    let showPasswordToggle: Bool
    
    @State private var isPasswordVisible: Bool = false
    
    init(
        title: String? = nil,
        placeholder: String,
        text: Binding<String>,
        icon: String? = nil,
        isSecure: Bool = false,
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil,
        autocapitalization: TextInputAutocapitalization = .sentences,
        errorMessage: String? = nil,
        isDisabled: Bool = false,
        showPasswordToggle: Bool = false
    ) {
        self.title = title
        self.placeholder = placeholder
        self._text = text
        self.icon = icon
        self.isSecure = isSecure
        self.keyboardType = keyboardType
        self.textContentType = textContentType
        self.autocapitalization = autocapitalization
        self.errorMessage = errorMessage
        self.isDisabled = isDisabled
        self.showPasswordToggle = showPasswordToggle
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
            if let title {
                Text(title)
                    .font(BrindooFont.bodySmall.weight(.medium))
                    .foregroundStyle(Color.brindooTextSecondary)
            }
            
            HStack(spacing: BrindooSpacing.sm) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(Color.brindooTextSecondary)
                        .frame(width: 20)
                }
                
                Group {
                    if isSecure && !isPasswordVisible {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .font(BrindooFont.bodyLarge)
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled(shouldDisableAutocorrection)
                
                if showPasswordToggle {
                    Button {
                        isPasswordVisible.toggle()
                    } label: {
                        Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.brindooTextSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, BrindooSpacing.md)
            .frame(height: 52)
            .background(Color.brindooSurface)
            .overlay(
                RoundedRectangle(cornerRadius: BrindooRadius.md)
                    .strokeBorder(
                        errorMessage != nil ? Color.brindooError : Color.brindooBorder,
                        lineWidth: errorMessage != nil ? 1.5 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
            .opacity(isDisabled ? 0.5 : 1.0)
            .disabled(isDisabled)
            
            if let errorMessage {
                HStack(spacing: BrindooSpacing.xxs) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 12))
                    Text(errorMessage)
                        .font(BrindooFont.caption)
                }
                .foregroundStyle(Color.brindooError)
                .transition(.opacity)
            }
        }
    }
    
    private var shouldDisableAutocorrection: Bool {
        keyboardType == .emailAddress
            || isSecure
            || textContentType == .password
            || textContentType == .newPassword
            || textContentType == .emailAddress
    }
}

struct BrindooPhoneTextField: View {
    let title: String?
    @Binding var text: String
    let errorMessage: String?
    let isDisabled: Bool
    
    init(
        title: String? = "Telefono",
        text: Binding<String>,
        errorMessage: String? = nil,
        isDisabled: Bool = false
    ) {
        self.title = title
        self._text = text
        self.errorMessage = errorMessage
        self.isDisabled = isDisabled
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
            if let title {
                Text(title)
                    .font(BrindooFont.bodySmall.weight(.medium))
                    .foregroundStyle(Color.brindooTextSecondary)
            }
            
            HStack(spacing: BrindooSpacing.sm) {
                HStack(spacing: 4) {
                    Image(systemName: "phone")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.brindooTextSecondary)
                    Text("+39")
                        .font(BrindooFont.bodyLarge.weight(.medium))
                        .foregroundStyle(Color.brindooTextPrimary)
                }
                
                Rectangle()
                    .fill(Color.brindooBorder)
                    .frame(width: 1, height: 24)
                
                TextField("333 1234567", text: $text)
                    .font(BrindooFont.bodyLarge)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .autocorrectionDisabled()
                    .onChange(of: text) { _, newValue in
                        let filtered = newValue.filter { $0.isNumber || $0 == " " }
                        if filtered != newValue { text = filtered }
                    }
            }
            .padding(.horizontal, BrindooSpacing.md)
            .frame(height: 52)
            .background(Color.brindooSurface)
            .overlay(
                RoundedRectangle(cornerRadius: BrindooRadius.md)
                    .strokeBorder(
                        errorMessage != nil ? Color.brindooError : Color.brindooBorder,
                        lineWidth: errorMessage != nil ? 1.5 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
            .opacity(isDisabled ? 0.5 : 1.0)
            .disabled(isDisabled)
            
            if let errorMessage {
                HStack(spacing: BrindooSpacing.xxs) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 12))
                    Text(errorMessage)
                        .font(BrindooFont.caption)
                }
                .foregroundStyle(Color.brindooError)
            }
        }
    }
}

extension String {
    var digitsOnly: String { filter { $0.isNumber } }
    
    var withItalianPrefix: String {
        let digits = self.digitsOnly
        guard !digits.isEmpty else { return "" }
        if digits.hasPrefix("39") { return "+\(digits)" }
        return "+39\(digits)"
    }
    
    var withoutItalianPrefix: String {
        var stripped = self
        if stripped.hasPrefix("+39") { stripped = String(stripped.dropFirst(3)) }
        return stripped.trimmingCharacters(in: .whitespaces)
    }
    
    var isCompleteEmail: Bool {
        let regex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return self.range(of: regex, options: .regularExpression) != nil
    }
}
