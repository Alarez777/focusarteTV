import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var session: SessionStore

    @State private var email = ""
    @State private var password = ""

    private enum Field: Hashable {
        case email
        case password
    }

    @FocusState private var focused: Field?

    var body: some View {
        HStack(spacing: 90) {
            ZStack(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 24) {
                    Image("FocusarteWordmark")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 225)
                        .allowsHitTesting(false)

                    Text("Historia del Arte Clásico")
                        .font(.system(size: 30))
                        .foregroundStyle(.secondary)

                    Text("Ingresá con tu cuenta para ver los cursos.")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)
                        .padding(.top, 10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

                Text(Self.versionLabel)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 26) {
                fieldRow(title: "Correo", isFocused: focused == .email) {
                    TextField("", text: $email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .focused($focused, equals: .email)
                        .onSubmit { focused = .password }
                }

                fieldRow(title: "Contraseña", isFocused: focused == .password) {
                    SecureField("", text: $password)
                        .textContentType(.password)
                        .submitLabel(.continue)
                        .focused($focused, equals: .password)
                        .onSubmit { submit() }
                }

                if let error = session.errorMessage {
                    Text(error)
                        .font(.system(size: 20))
                        .foregroundStyle(.red)
                }

                HStack(spacing: 24) {
                    Button("Iniciar sesión") {
                        submit()
                    }
                    .disabled(session.isLoading)

                    if session.isLoading {
                        ProgressView()
                    }
                }
                .padding(.top, 4)

                Text("E=\"\(emailPreview)\" · P=\(password.count)")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 720)
        }
        .padding(90)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { focused = .email }
    }

    @ViewBuilder
    private func fieldRow<Field: View>(
        title: String,
        isFocused: Bool,
        @ViewBuilder field: () -> Field
    ) -> some View {
        HStack(spacing: 28) {
            Text(title)
                .font(.system(size: 26))
                .foregroundStyle(.secondary)
                .frame(width: 150, alignment: .leading)

            field()
                .font(.system(size: 26))
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(white: isFocused ? 0.30 : 0.15))
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var emailPreview: String {
        guard !email.isEmpty else { return "" }
        return email.count > 24 ? String(email.prefix(24)) + "…" : email
    }

    private func submit() {
        Task { await session.signIn(email: email, password: password) }
    }

    private static var versionLabel: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "FocusarteTV v\(version) (\(build))"
    }
}
