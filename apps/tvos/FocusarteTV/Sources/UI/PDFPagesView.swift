import SwiftUI
import UIKit
import CoreGraphics

/// Visor de PDF basado en Core Graphics.
///
/// No usamos PDFKit: es un framework que Apple no documenta para tvOS y
/// enlazarlo puede romper el arranque si el sistema no lo trae.
struct PDFPagesView: View {
    let data: Data

    @State private var pages: [UIImage] = []
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if !pages.isEmpty {
                ScrollView {
                    VStack(spacing: 36) {
                        ForEach(pages.indices, id: \.self) { index in
                            Image(uiImage: pages[index])
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .focusable()
                                .focusEffectDisabled(true)
                        }
                    }
                    .padding(60)
                }
            } else if let errorMessage {
                Text(errorMessage)
            } else {
                ProgressView()
            }
        }
        .task { await render() }
    }

    private func render() async {
        let data = self.data
        let rendered = await Task.detached(priority: .userInitiated) {
            PDFRenderer.render(data)
        }.value

        if rendered.isEmpty {
            errorMessage = "No se pudo leer el PDF."
        } else {
            pages = rendered
        }
    }
}

enum PDFRenderer {
    /// Renderiza todas las páginas a imágenes. Un PDF de 8 páginas son ~8
    /// imágenes de 1600 px de ancho: entra cómodo en memoria.
    static func render(_ data: Data, maxWidth: CGFloat = 1600) -> [UIImage] {
        guard let provider = CGDataProvider(data: data as CFData),
              let document = CGPDFDocument(provider),
              document.numberOfPages > 0 else {
            return []
        }

        var images: [UIImage] = []

        for index in 1...document.numberOfPages {
            guard let page = document.page(at: index) else { continue }
            let box = page.getBoxRect(.mediaBox)
            guard box.width > 0, box.height > 0 else { continue }

            let scale = min(maxWidth / box.width, 3)
            let size = CGSize(width: box.width * scale, height: box.height * scale)

            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = true

            let renderer = UIGraphicsImageRenderer(size: size, format: format)
            let image = renderer.image { context in
                let cg = context.cgContext
                UIColor.white.setFill()
                cg.fill(CGRect(origin: .zero, size: size))
                cg.translateBy(x: 0, y: size.height)
                cg.scaleBy(x: scale, y: -scale)
                cg.translateBy(x: -box.minX, y: -box.minY)
                cg.drawPDFPage(page)
            }
            images.append(image)
        }

        return images
    }
}
