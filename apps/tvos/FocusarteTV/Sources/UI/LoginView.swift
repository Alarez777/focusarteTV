import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var diagnostics = LoginFieldDiagnostics.shared

    @State private var email = ""
    @State private var password = ""

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
                fieldRow(title: "Usuario") {
                    LoginField(
                        placeholder: "",
                        text: $email,
                        contentType: .username,
                        keyboardType: .emailAddress,
                        returnKeyType: .next,
                        autoFocus: true
                    )
                }

                fieldRow(title: "Contraseña") {
                    LoginField(
                        placeholder: "",
                        text: $password,
                        isSecure: true,
                        contentType: .password,
                        returnKeyType: .continue,
                        onSubmit: submit
                    )
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

                Text("AF · sistema=\(diagnostics.systemChanges) · edit=\(diagnostics.editChanges) · should=\(diagnostics.insertions) · last=\(diagnostics.lastInsertionLength) · activo=\(diagnostics.activations) · E=\(email.count) P=\(password.count)")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 720)
        }
        .padding(90)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func fieldRow<Field: View>(
        title: String,
        @ViewBuilder field: () -> Field
    ) -> some View {
        HStack(spacing: 28) {
            Text(title)
                .font(.system(size: 26))
                .foregroundStyle(.secondary)
                .frame(width: 150, alignment: .leading)

            field()
                .frame(height: 44)
        }
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
