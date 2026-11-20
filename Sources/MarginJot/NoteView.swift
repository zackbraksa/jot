import AppKit
import SwiftUI

@MainActor
final class Note: ObservableObject {
    @Published private(set) var storageMessage: String?
    @Published private(set) var text = ""
    private let file: URL

    init() {
        let support = URL.applicationSupportDirectory
        let identifier = Bundle.main.bundleIdentifier ?? "com.scratchpadexperiment.marginjot"
        file = support.appending(path: identifier, directoryHint: .isDirectory)
            .appending(path: "Note.txt", directoryHint: .notDirectory)

        do {
            text = try String(contentsOf: file, encoding: .utf8)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            // A first launch starts with a blank note.
        } catch {
            storageMessage = "Couldn’t load the saved note."
        }
    }

    func save(_ text: String) {
        self.text = text
        do {
            try FileManager.default.createDirectory(
                at: file.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try text.write(to: file, atomically: true, encoding: .utf8)
            storageMessage = nil
        } catch {
            storageMessage = "Couldn’t save the note."
        }
    }
}

struct NoteView: View {
    @ObservedObject var note: Note
    let focus: EditorFocus
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NoteEditor(note: note, focus: focus, dismiss: dismiss)
                .overlay(alignment: .topLeading) {
                    if note.text.isEmpty {
                        Text("Write a note…")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(nsColor: .placeholderTextColor))
                            .padding(.horizontal, 16)
                            .padding(.top, 14)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }

            if let message = note.storageMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }
        }
        .frame(width: 340, height: 260)
        .background(Color(nsColor: .textBackgroundColor))
    }
}

@MainActor
final class EditorFocus {
    weak var editor: NSTextView?

    func makeFirstResponder() {
        guard let editor, let window = editor.window else { return }
        window.makeFirstResponder(editor)
        window.makeKey()
    }
}

struct NoteEditor: NSViewRepresentable {
    let note: Note
    let focus: EditorFocus
    let dismiss: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(note: note)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let editor = TextView()
        editor.dismiss = dismiss
        editor.isRichText = false
        editor.importsGraphics = false
        editor.allowsUndo = true
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.drawsBackground = false
        editor.font = .systemFont(ofSize: 14)
        editor.textColor = .textColor
        editor.insertionPointColor = .textColor
        editor.textContainerInset = NSSize(width: 16, height: 14)
        editor.isVerticallyResizable = true
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.textContainer?.lineFragmentPadding = 0
        editor.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        editor.string = note.text
        editor.setSelectedRange(NSRange(location: (note.text as NSString).length, length: 0))
        editor.delegate = context.coordinator
        editor.setAccessibilityLabel("Note")
        scrollView.documentView = editor
        focus.editor = editor
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {}

    final class Coordinator: NSObject, NSTextViewDelegate {
        private let note: Note

        init(note: Note) {
            self.note = note
        }

        func textDidChange(_ notification: Notification) {
            if let editor = notification.object as? NSTextView {
                note.save(editor.string)
            }
        }
    }

    final class TextView: NSTextView {
        var dismiss: (() -> Void)?

        override func cancelOperation(_ sender: Any?) {
            dismiss?()
        }
    }
}
