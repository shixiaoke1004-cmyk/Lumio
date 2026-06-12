import Foundation
import PDFKit
import UniformTypeIdentifiers

// Extracts plain text from a resume file, entirely on-device; only the
// extracted text is ever stored or sent to the LLM.
enum ResumeImport {
    static let allowedTypes: [UTType] = {
        var types: [UTType] = [.pdf, .plainText]
        if let markdown = UTType(filenameExtension: "md") { types.append(markdown) }
        return types
    }()

    static func extractText(from url: URL) -> String? {
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }

        if url.pathExtension.lowercased() == "pdf" {
            guard let text = PDFDocument(url: url)?.string else { return nil }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
