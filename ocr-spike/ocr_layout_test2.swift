// Stub OCR spike, pass 3 — improves on pass 2's row clustering by using
// vertical bounding-box OVERLAP instead of a fixed midY-distance threshold.
// Pass 2 missed short/small tokens (like a lone quantity digit) whose center
// point sat outside the threshold even though the box visually overlapped
// the row it belongs to. See CLAUDE.md "OCR/parsing spike".
//
// Usage: swift ocr_layout_test2.swift <path-to-image>

import Vision
import AppKit
import Foundation

guard CommandLine.arguments.count > 1 else {
    print("Usage: swift ocr_layout_test2.swift <path-to-image>")
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

struct Line { let text: String; let minX: CGFloat; let minY: CGFloat; let maxY: CGFloat }

var lines: [Line] = []
for obs in observations {
    guard let candidate = obs.topCandidates(1).first else { continue }
    let box = obs.boundingBox
    lines.append(Line(text: candidate.string, minX: box.minX, minY: box.minY, maxY: box.maxY))
}

// Sort top to bottom first.
let sorted = lines.sorted { $0.minY > $1.minY }

// Row-cluster by vertical overlap: a line joins the current row if its
// Y-range overlaps ANY line already in that row by at least 25% of its own
// height (not just a distance-from-anchor check like pass 2).
func overlapFraction(_ a: Line, _ b: Line) -> CGFloat {
    let overlap = min(a.maxY, b.maxY) - max(a.minY, b.minY)
    guard overlap > 0 else { return 0 }
    let aHeight = a.maxY - a.minY
    return aHeight > 0 ? overlap / aHeight : 0
}

var rows: [[Line]] = []
for line in sorted {
    if let idx = rows.lastIndex(where: { row in
        row.contains { overlapFraction(line, $0) > 0.25 || overlapFraction($0, line) > 0.25 }
    }) {
        rows[idx].append(line)
    } else {
        rows.append([line])
    }
}

print("=== \((path as NSString).lastPathComponent) — overlap-based reconstruction ===")
for row in rows {
    let sortedRow = row.sorted { $0.minX < $1.minX }
    print(sortedRow.map { $0.text }.joined(separator: "   |   "))
}
