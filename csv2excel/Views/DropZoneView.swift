import SwiftUI
import AppKit

struct DropZoneView: NSViewRepresentable {
    let onDrop: (URL) -> Void

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
    var onDrop: ((URL) -> Void)?

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
        guard singleFileURL(from: sender) != nil else { return [] }
        return .copy
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        guard let url = singleFileURL(from: sender) else { return false }
        DispatchQueue.main.async { [weak self] in
            self?.onDrop?(url)
        }
        return true
    }

    private func singleFileURL(from info: NSDraggingInfo) -> URL? {
        guard let items = info.draggingPasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
              items.count == 1,
              let url = items.first,
              url.isFileURL,
              Self.acceptedExtensions.contains(url.pathExtension.lowercased())
        else { return nil }
        return url
    }
}
