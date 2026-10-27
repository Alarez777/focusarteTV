import Foundation

public enum KajabiError: Error, Equatable, LocalizedError {
    case invalidCredentials(String)
    case sessionExpired
    case notFound(String)
    case unexpectedStatus(Int)
    case parsing(String)
    case network(String)

    public var errorDescription: String? {
        switch self {
        case .invalidCredentials(let detail):
            return detail.isEmpty ? "Email o contraseña incorrectos." : detail
        case .sessionExpired:
            return "La sesión venció. Volvé a iniciar sesión."
        case .notFound(let what):
            return "No se encontró \(what)."
        case .unexpectedStatus(let code):
            return "El servidor respondió con estado \(code)."
        case .parsing(let detail):
            return "No se pudo interpretar la página: \(detail)"
        case .network(let detail):
            return "Error de red: \(detail)"
        }
    }
}
