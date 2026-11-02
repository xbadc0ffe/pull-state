// ShareSheet.swift
//
// Intentional UIKit exception. About → Export Shots first asks "Export N shots
// as a CSV table?" and only then opens the share sheet. SwiftUI's `ShareLink`
// can only open the sheet from its own tap, so it can't follow a
// confirmation; this tiny anchor presents `UIActivityViewController` from
// code instead.
//
// It shares a file URL written by `ShotCSV.writeFile`, never in-memory data:
// with a real file, Files keeps the name and ".csv" extension, and Mail and
// Messages attach the file instead of pasting the table into the message.
import SwiftUI
import UIKit

/// Invisible view that opens the system share sheet for `fileURL` once it
/// becomes non-nil. `onDone` runs when the sheet closes; the caller clears
/// `fileURL` there, and should also clear it before offering a new file so
/// every export counts as a change. Put it in the `.background` of the
/// control that started the share, so the iPad popover points at it.
struct ShareSheetPresenter: UIViewControllerRepresentable {
    let fileURL: URL?
    let onDone: () -> Void

    final class Coordinator {
        /// The sheet on screen, or still loading: UIKit only shows a share
        /// sheet once its content is ready, so `presentingViewController`
        /// stays nil for a moment. Prevents a re-render opening a second one.
        weak var sheet: UIActivityViewController?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIViewController {
        let anchor = UIViewController()
        anchor.view.backgroundColor = .clear
        anchor.view.isUserInteractionEnabled = false
        return anchor
    }

    func updateUIViewController(_ anchor: UIViewController, context: Context) {
        let coordinator = context.coordinator
        guard let fileURL else {
            // The caller is done with the last share; the next file opens a new sheet.
            coordinator.sheet = nil
            return
        }
        guard coordinator.sheet == nil else { return }
        let onDone = onDone
        let sheet = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        sheet.completionWithItemsHandler = { _, _, _, _ in
            coordinator.sheet = nil
            onDone()
        }
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = anchor.view
            popover.sourceRect = anchor.view.bounds
        }
        coordinator.sheet = sheet
        anchor.present(sheet, animated: true)
    }
}
