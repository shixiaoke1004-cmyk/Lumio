import SwiftUI
import UniformTypeIdentifiers

struct ShelfView: View {
    let shelf: ShelfService
    @State private var isDropTargeted = false

    var body: some View {
        Group {
            if shelf.items.isEmpty {
                emptyState
            } else {
                itemsRow
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isDropTargeted ? Color.accentColor : .white.opacity(0.2),
                    style: StrokeStyle(lineWidth: 1.5, dash: shelf.items.isEmpty ? [5] : [])
                )
        }
        .animation(.easeOut(duration: 0.15), value: isDropTargeted)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            shelf.handleDrop(providers)
        }
    }

    private var emptyState: some View {
        HStack(spacing: 8) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 16))
            Text("Drop files here")
                .font(.caption)
        }
        .foregroundStyle(.white.opacity(0.45))
        .frame(maxWidth: .infinity)
    }

    private var itemsRow: some View {
        VStack(spacing: 8) {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 8)], spacing: 8) {
                    ForEach(shelf.items) { item in
                        ShelfItemView(item: item, shelf: shelf)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 8)
            }
            HStack(spacing: 10) {
                Spacer()
                Button {
                    shelf.clear()
                } label: {
                    Label("Clear", systemImage: "trash")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 12)
                        .frame(height: 26)
                        .background(Capsule().fill(.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .help("Remove all items")
                Button {
                    shelf.airDrop(shelf.items)
                } label: {
                    Label("AirDrop", systemImage: "shareplay")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 26)
                        .background(Capsule().fill(.white.opacity(0.18)))
                }
                .buttonStyle(.plain)
                .help("AirDrop all items")
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
    }

}

struct ShelfItemView: View {
    let item: ShelfItem
    let shelf: ShelfService
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 3) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                .resizable()
                .frame(width: 36, height: 36)
            Text(item.name)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
                .frame(maxWidth: 60)
        }
        // Padding keeps the delete button inside the hover-tracked bounds,
        // otherwise hover ends as the mouse moves onto the button.
        .padding(.top, 10)
        .padding(.horizontal, 8)
        .overlay(alignment: .topTrailing) {
            if isHovering {
                Button {
                    shelf.remove(item)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white, .gray)
                }
                .buttonStyle(.plain)
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .draggable(item.url)
        .help(item.name)
    }
}
