import SwiftUI
import UIKit

/// Contadores temporales para diagnosticar si tvOS entrega el texto de AutoFill.
final class LoginFieldDiagnostics: ObservableObject {
    static let shared = LoginFieldDiagnostics()

    @Published fileprivate(set) var systemChanges = 0
    @Published fileprivate(set) var editChanges = 0
    @Published fileprivate(set) var insertions = 0
    @Published fileprivate(set) var lastInsertionLength = 0
    @Published fileprivate(set) var lastSystemLength = 0
    @Published fileprivate(set) var lastEditLength = 0
    @Published fileprivate(set) var activations = 0

    private init() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.activations += 1 }
        }
    }
}

/// `UITextField` que pide el foco en cuanto entra en la jerarquía de vistas y
/// dibuja su propio fondo redondeado, para que el foco nativo de tvOS quede
/// exactamente del mismo tamaño que el campo.
final class AutoFocusTextField: UITextField {
    var autoFocus = false

    private var requestedFocus = false
    private let roundedBackground = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        roundedBackground.backgroundColor = UIColor(white: 0.15, alpha: 1)
        roundedBackground.layer.cornerRadius = 8
        roundedBackground.layer.cornerCurve = .continuous
        roundedBackground.isUserInteractionEnabled = false
        insertSubview(roundedBackground, at: 0)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        roundedBackground.frame = bounds
    }

    override func textRect(forBounds bounds: CGRect) -> CGRect {
        bounds.insetBy(dx: 16, dy: 0)
    }

    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        textRect(forBounds: bounds)
    }

    override func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        textRect(forBounds: bounds)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard autoFocus, !requestedFocus, window != nil else { return }
        requestedFocus = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            UIFocusSystem.focusSystem(for: self)?.requestFocusUpdate(to: self)
        }
    }
}

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
    var autoFocus: Bool = false

    func makeUIView(context: Context) -> UITextField {
        let field = AutoFocusTextField()
        field.autoFocus = autoFocus
        field.delegate = context.coordinator
        field.borderStyle = .none
        field.backgroundColor = .clear
        field.textColor = .white
        field.tintColor = .white
        field.font = .systemFont(ofSize: 26)
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

        // El texto va solo del `UITextField` al binding. Si acá se asignara el
        // valor del binding, un re-render borraría lo que escribe AutoFill.
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
            let diagnostics = LoginFieldDiagnostics.shared
            diagnostics.editChanges += 1
            diagnostics.lastEditLength = field.text?.count ?? 0
            sync(field)
        }

        @objc func textDidChange(_ notification: Notification) {
            let diagnostics = LoginFieldDiagnostics.shared
            diagnostics.systemChanges += 1
            guard let field = notification.object as? UITextField else { return }
            diagnostics.lastSystemLength = field.text?.count ?? 0
            sync(field)
        }

        func textFieldShouldReturn(_ field: UITextField) -> Bool {
            parent.onSubmit()
            return true
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            let diagnostics = LoginFieldDiagnostics.shared
            diagnostics.insertions += 1
            diagnostics.lastInsertionLength = string.count

            // AutoFill y el pegado llegan como una inserción en bloque. Se
            // aplica a mano para que el texto no se pierda si el sistema no
            // lo confirma.
            guard string.count > 1,
                  let current = textField.text,
                  let swiftRange = Range(range, in: current) else {
                return true
            }

            textField.text = current.replacingCharacters(in: swiftRange, with: string)
            sync(textField)
            return false
        }

        private func sync(_ field: UITextField) {
            let value = field.text ?? ""
            guard parent.text != value else { return }
            parent.text = value
        }
    }
}
