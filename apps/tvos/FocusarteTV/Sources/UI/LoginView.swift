import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var session: SessionStore

    @State private var email = ""
    @State private var password = ""
    @State private var emailFocused = false
    @State private var passwordFocused = false

    var body: some View {
        HStack(spacing: 90) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Focusarte")
                    .font(.system(size: 84, weight: .bold, design: .serif))

                Text("Historia del Arte Clásico")
                    .font(.system(size: 30))
                    .foregroundStyle(.secondary)

                Text("Ingresá con tu cuenta para ver los cursos.")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
                    .padding(.top, 10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 30) {
                LoginField(
                    placeholder: "Email",
                    text: $email,
                    contentType: .username,
                    keyboardType: .emailAddress,
                    returnKeyType: .next,
                    onFocusChange: { emailFocused = $0 }
                )
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(fieldBackground(emailFocused))

                LoginField(
                    placeholder: "Contraseña",
                    text: $password,
                    isSecure: true,
                    contentType: .password,
                    returnKeyType: .go,
                    onSubmit: submit,
                    onFocusChange: { passwordFocused = $0 }
                )
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(fieldBackground(passwordFocused))

                if let error = session.errorMessage {
                    Text(error)
                        .font(.system(size: 20))
                        .foregroundStyle(.red)
                }

                HStack(spacing: 24) {
                    Button("Entrar") {
                        submit()
                    }
                    .disabled(session.isLoading)

                    if session.isLoading {
                        ProgressView()
                    }
                }

                Text(Self.versionLabel)
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
            .frame(width: 600)
        }
        .padding(90)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func fieldBackground(_ focused: Bool) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.white.opacity(focused ? 0.16 : 0.06))
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
