import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var session: SessionStore

    @State private var email = ""
    @State private var password = ""

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
                TextField("Email", text: $email)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                SecureField("Contraseña", text: $password)
                    .textContentType(.password)

                if let error = session.errorMessage {
                    Text(error)
                        .font(.system(size: 20))
                        .foregroundStyle(.red)
                }

                HStack(spacing: 24) {
                    Button("Entrar") {
                        Task { await session.signIn(email: email, password: password) }
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

    private static var versionLabel: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "FocusarteTV v\(version) (\(build))"
    }
}
