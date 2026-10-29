import SwiftUI
import UIKit

/// Campo de texto respaldado por `UITextField`.
///
/// Password AutoFill documenta el llenado sobre `UITextField`/`UITextView`; en
/// tvOS el `TextField` de SwiftUI no refleja el texto que AutoFill inserta
/// desde el iPhone. Este wrapper usa el `UITextField` real y escucha
/// `textDidChangeNotification`, la notificación que dispara el autocompletado.
struct LoginField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var contentType: UITextContentType?
    var keyboardType: UIKeyboardType = .default
    var returnKeyType: UIReturnKeyType = .default
    var onSubmit: () -> Void = {}
    var onFocusChange: (Bool) -> Void = { _ in }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.borderStyle = .none
        field.backgroundColor = .clear
        field.textColor = .white
        field.tintColor = UIColor(Theme.accent)
        field.font = UIFont.preferredFont(forTextStyle: .body)
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.spellCheckingType = .no
        field.smartQuotesType = .no
        field.smartDashesType = .no
        field.textContentType = contentType
        field.keyboardType = keyboardType
        field.returnKeyType = returnKeyType
        field.isSecureTextEntry = isSecure
        field.attributedPlaceholder = placeholderText
        field.addTarget(
            context.coordinator,
            action: #selector(Coordinator.editingChanged(_:)),
            for: .editingChanged
        )
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.textDidChange(_:)),
            name: UITextField.textDidChangeNotification,
            object: field
        )
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self

        if field.text != text {
            field.text = text
        }
        // Cambiar `isSecureTextEntry` en cada update borra el texto en curso.
        if field.isSecureTextEntry != isSecure {
            field.isSecureTextEntry = isSecure
        }
        field.textContentType = contentType
        field.keyboardType = keyboardType
        field.returnKeyType = returnKeyType
        field.attributedPlaceholder = placeholderText
    }

    static func dismantleUIView(_ field: UITextField, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(
            coordinator,
            name: UITextField.textDidChangeNotification,
            object: field
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private var placeholderText: NSAttributedString {
        NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.4)]
        )
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: LoginField

        init(_ parent: LoginField) {
            self.parent = parent
        }

        @objc func editingChanged(_ field: UITextField) {
            sync(field)
        }

        @objc func textDidChange(_ notification: Notification) {
            guard let field = notification.object as? UITextField else { return }
            sync(field)
        }

        func textFieldShouldReturn(_ field: UITextField) -> Bool {
            parent.onSubmit()
            return true
        }

        func textFieldDidBeginEditing(_ field: UITextField) {
            parent.onFocusChange(true)
        }

        func textFieldDidEndEditing(_ field: UITextField) {
            parent.onFocusChange(false)
        }

        private func sync(_ field: UITextField) {
            let value = field.text ?? ""
            guard parent.text != value else { return }
            parent.text = value
        }
    }
}
