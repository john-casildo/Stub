// Stub OCR spike, pass 4 — pass 3's "overlap with any row member" rule
// caused transitive chaining (A~B, B~C -> A/B/C merged even if A/C don't
// overlap), collapsing whole sections into one row. This version compares
// each candidate only against the row's ANCHOR (first line added), using
// vertical overlap instead of pass 2's raw midY-distance threshold.
// See CLAUDE.md "OCR/parsing spike".
//
// Usage: swift ocr_layout_test3.swift <path-to-image>

import Vision
import AppKit
import Foundation

guard CommandLine.arguments.count > 1 else {
    print("Usage: swift ocr_layout_test3.swift <path-to-image>")
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

let sorted = lines.sorted { $0.minY > $1.minY }

func overlapFraction(_ a: Line, _ b: Line) -> CGFloat {
    let overlap = min(a.maxY, b.maxY) - max(a.minY, b.minY)
    guard overlap > 0 else { return 0 }
    let smaller = min(a.maxY - a.minY, b.maxY - b.minY)
    return smaller > 0 ? overlap / smaller : 0
}

var rows: [[Line]] = []
for line in sorted {
    if let idx = rows.lastIndex(where: { row in
        guard let anchor = row.first else { return false }
        return overlapFraction(line, anchor) > 0.2
    }) {
        rows[idx].append(line)
    } else {
        rows.append([line])
    }
}

print("=== \((path as NSString).lastPathComponent) — anchor-overlap reconstruction ===")
for row in rows {
    let sortedRow = row.sorted { $0.minX < $1.minX }
    print(sortedRow.map { $0.text }.joined(separator: "   |   "))
}
