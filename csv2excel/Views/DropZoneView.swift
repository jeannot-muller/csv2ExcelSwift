import SwiftUI
import AppKit

struct DropZoneView: NSViewRepresentable {
    let onDrop: ([URL]) -> Void

    func makeNSView(context: Context) -> DropTargetView {
        let view = DropTargetView()
        view.onDrop = onDrop
        return view
    }

    func updateNSView(_ nsView: DropTargetView, context: Context) {
        nsView.onDrop = onDrop
    }
}

class DropTargetView: NSView {
    private static let acceptedExtensions: Set<String> = ["csv", "txt", "tsv"]
    var onDrop: (([URL]) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    // Pass through all mouse events to views underneath
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard !validFileURLs(from: sender).isEmpty else { return [] }
        return .copy
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let urls = validFileURLs(from: sender)
        guard !urls.isEmpty else { return false }
        DispatchQueue.main.async { [weak self] in
            self?.onDrop?(urls)
        }
        return true
    }

    private func validFileURLs(from info: NSDraggingInfo) -> [URL] {
        guard let items = info.draggingPasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] else {
            return []
        }
        return items.filter { $0.isFileURL && Self.acceptedExtensions.contains($0.pathExtension.lowercased()) }
    }
}
