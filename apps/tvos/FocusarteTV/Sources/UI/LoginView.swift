import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var session: SessionStore

    @State private var email = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case email
        case password
    }

    var body: some View {
        HStack(spacing: 90) {
            VStack(alignment: .leading, spacing: 22) {
                Text("Focusarte")
                    .font(.system(size: 84, weight: .bold, design: .serif))
                    .foregroundStyle(.white)

                Text("Historia del Arte Clásico")
                    .font(.system(size: 30, weight: .regular))
                    .foregroundStyle(.white.opacity(0.65))

                Text("Ingresá con tu cuenta para ver los cursos.")
                    .font(.system(size: 22))
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.top, 10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 26) {
                field(title: "Email", text: $email, field: .email, secure: false)
                field(title: "Contraseña", text: $password, field: .password, secure: true)

                if let error = session.errorMessage {
                    Text(error)
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.accent)
                }

                HStack(spacing: 20) {
                    Button {
                        Task { await session.signIn(email: email, password: password) }
                    } label: {
                        Text("Entrar")
                            .font(.system(size: 26, weight: .semibold))
                            .frame(width: 260)
                            .padding(.vertical, 6)
                    }
                    .disabled(session.isLoading)

                    if session.isLoading {
                        ProgressView()
                    }
                }
                .padding(.top, 4)
            }
            .frame(width: 600)
        }
        .padding(90)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func field(
        title: String,
        text: Binding<String>,
        field: Field,
        secure: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))

            Group {
                if secure {
                    SecureField(title, text: text)
                } else {
                    TextField(title, text: text)
                }
            }
            .textFieldStyle(.plain)
            .font(.system(size: 26))
            .foregroundStyle(.white)
            .padding(.horizontal, 26)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        Color.white.opacity(focusedField == field ? 0.55 : 0.10),
                        lineWidth: 2
                    )
            )
            .focused($focusedField, equals: field)
        }
    }
}
