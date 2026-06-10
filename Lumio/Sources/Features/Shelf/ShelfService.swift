import AppKit
import Foundation
import UniformTypeIdentifiers
import os

struct ShelfItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    var name: String { url.lastPathComponent }
}

@MainActor
@Observable
final class ShelfService {
    private(set) var items: [ShelfItem] = []
    private let logger = Logger(subsystem: "app.lumio.Lumio", category: "Shelf")

    private let storageDirectory: URL = {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumioShelf", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    func add(urls: [URL]) {
        for url in urls {
            // Copy into our own storage so the item survives the source being moved/deleted.
            let destination = storageDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                let target = destination.appendingPathComponent(url.lastPathComponent)
                try FileManager.default.copyItem(at: url, to: target)
                items.append(ShelfItem(url: target))
            } catch {
                logger.error("failed to stash \(url.path): \(error)")
            }
        }
    }

    func remove(_ item: ShelfItem) {
        items.removeAll { $0.id == item.id }
        try? FileManager.default.removeItem(at: item.url.deletingLastPathComponent())
    }

    func clear() {
        for item in items {
            try? FileManager.default.removeItem(at: item.url.deletingLastPathComponent())
        }
        items.removeAll()
    }

    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var found = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            found = true
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in
                    self.add(urls: [url])
                }
            }
        }
        return found
    }

    func airDrop(_ items: [ShelfItem]) {
        guard !items.isEmpty,
              let service = NSSharingService(named: .sendViaAirDrop) else { return }
        service.perform(withItems: items.map(\.url))
    }
}
