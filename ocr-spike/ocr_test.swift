// Stub OCR accuracy spike — runs Apple's Vision framework text recognition
// against real screenshots to see if on-device OCR is good enough before
// committing to that architecture. See CLAUDE.md "Open items".
//
// Usage: swift ocr_test.swift <path-to-image>

import Vision
import AppKit
import Foundation

guard CommandLine.arguments.count > 1 else {
    print("Usage: swift ocr_test.swift <path-to-image>")
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

let start = Date()
do {
    try handler.perform([request])
} catch {
    print("ERROR: \(error)")
    exit(1)
}
let elapsed = Date().timeIntervalSince(start)

guard let observations = request.results else {
    print("No results")
    exit(0)
}

print("=== \((path as NSString).lastPathComponent) ===")
print("Time: \(String(format: "%.2f", elapsed))s | Lines: \(observations.count)")
print("---")
for obs in observations {
    guard let candidate = obs.topCandidates(1).first else { continue }
    let confidence = String(format: "%.2f", candidate.confidence)
    print("[\(confidence)] \(candidate.string)")
}
print("")
