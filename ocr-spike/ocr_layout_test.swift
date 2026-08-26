// Stub OCR spike, pass 2 — tests whether reconstructing text by bounding-box
// position (row-cluster by Y, then sort by X within each row) fixes the
// multi-column scrambling seen in pass 1 (see CLAUDE.md "OCR/parsing spike").
//
// Usage: swift ocr_layout_test.swift <path-to-image>

import Vision
import AppKit
import Foundation

guard CommandLine.arguments.count > 1 else {
    print("Usage: swift ocr_layout_test.swift <path-to-image>")
    exit(1)
}

let path = CommandLine.arguments[1]
guard let nsImage = NSImage(contentsOfFile: path),
      let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    print("ERROR: could not load image at \(path)")
    exit(1)
}

let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.usesLanguageCorrection = true

let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
try handler.perform([request])

guard let observations = request.results else {
    print("No results")
    exit(0)
}

// Each observation's boundingBox is normalized (0-1), origin bottom-left.
struct Line { let text: String; let minX: CGFloat; let midY: CGFloat }

var lines: [Line] = []
for obs in observations {
    guard let candidate = obs.topCandidates(1).first else { continue }
    let box = obs.boundingBox
    lines.append(Line(text: candidate.string, minX: box.minX, midY: box.midY))
}

// Row-cluster by Y (top to bottom == descending midY in this coord system),
// grouping lines whose vertical centers are within a small threshold.
let sortedByY = lines.sorted { $0.midY > $1.midY }
let rowThreshold: CGFloat = 0.012

var rows: [[Line]] = []
for line in sortedByY {
    if let lastRow = rows.last, let anchor = lastRow.first,
       abs(anchor.midY - line.midY) < rowThreshold {
        rows[rows.count - 1].append(line)
    } else {
        rows.append([line])
    }
}

print("=== \((path as NSString).lastPathComponent) — layout-reconstructed ===")
for row in rows {
    let sortedRow = row.sorted { $0.minX < $1.minX }
    print(sortedRow.map { $0.text }.joined(separator: "   |   "))
}
