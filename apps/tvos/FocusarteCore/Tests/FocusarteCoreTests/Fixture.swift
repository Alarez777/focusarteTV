import Foundation

enum Fixture {
    static func text(_ name: String) throws -> String {
        guard let directory = Bundle.module.url(forResource: "Fixtures", withExtension: nil) else {
            throw NSError(
                domain: "Fixture",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No se encontró el directorio Fixtures"]
            )
        }
        let url = directory.appendingPathComponent(name)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
