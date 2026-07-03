import SwiftUI

struct NodiTextField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var autocapitalization: TextInputAutocapitalization = .sentences
    var errorMessage: String? = nil

    @FocusState private var isFocused: Bool
    @State private var revealSecure = false

    var body: some View {
        VStack(alignment: .leading, spacing: NodiSpacing.xxs) {
            Text(title.uppercased())
                .font(NodiFont.caption(.semibold))
                .foregroundStyle(NodiColor.secondaryText)
                .tracking(0.5)

            HStack {
                Group {
                    if isSecure && !revealSecure {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled(keyboardType == .emailAddress || isSecure)
                .focused($isFocused)
                .font(NodiFont.body())

                if isSecure {
                    Button {
                        revealSecure.toggle()
                    } label: {
                        Image(systemName: revealSecure ? "eye.slash" : "eye")
                            .foregroundStyle(NodiColor.secondaryText)
                    }
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, NodiSpacing.md)
            .background(NodiColor.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: NodiRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: NodiRadius.md, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1.5)
            )

            if let errorMessage {
                Text(errorMessage)
                    .font(NodiFont.caption())
                    .foregroundStyle(NodiColor.danger)
            }
        }
        .animation(NodiAnimation.quickSpring, value: errorMessage)
    }

    private var borderColor: Color {
        if errorMessage != nil { return NodiColor.danger }
        return isFocused ? NodiColor.accent : .clear
    }
}
