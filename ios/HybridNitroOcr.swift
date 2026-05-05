//
//  HybridNitroOcr.swift
//  VisionCameraNitroOcr
//
//  Concrete implementation of the Nitro `NitroOcr` hybrid object for iOS.
//  Registered by Nitrogen via `nitro.json → autolinking → HybridNitroOcr`.
//

import Foundation
import MLKitTextRecognition
import MLKitVision
import NitroModules
import VisionCamera

class HybridNitroOcr: HybridNitroOcrSpec {
  private let textRecognizer: TextRecognizer

  override init() {
    let options = TextRecognizerOptions()
    self.textRecognizer = TextRecognizer.textRecognizer(options: options)
    super.init()
  }

  /// Synchronously run MLKit on the frame's buffer and return MLKit's
  /// full block → line → element hierarchy PLUS native re-lined output.
  func recognize(frame: any HybridFrameSpec) throws -> OcrResult {
    let image: MLImage
    do {
      image = try frame.toMLImage()
    } catch {
      NSLog("[NitroOcr] toMLImage failed: \(error.localizedDescription)")
      return OcrResult(text: "", blocks: [], lines: [])
    }

    do {
      let text = try self.textRecognizer.results(in: image)
      if text.text.isEmpty {
        return OcrResult(text: "", blocks: [], lines: [])
      }
      let blocks = text.blocks.map(Self.mapBlock)
      let allElements = blocks.flatMap { block in block.lines.flatMap { $0.elements } }
      return OcrResult(text: text.text, blocks: blocks, lines: Self.reLine(allElements))
    } catch {
      // Match v4 fork behavior: swallow and return empty on error to keep
      // the camera alive; consumers treat empty results as "nothing recognized".
      NSLog("[NitroOcr] recognize failed: \(error.localizedDescription)")
      return OcrResult(text: "", blocks: [], lines: [])
    }
  }

  // MARK: - MLKit → Ocr mapping helpers

  private static func mapBlock(_ block: TextBlock) -> OcrBlock {
    OcrBlock(text: block.text, lines: block.lines.map(Self.mapLine))
  }

  private static func mapLine(_ line: TextLine) -> OcrLine {
    OcrLine(text: line.text, elements: line.elements.map(Self.mapElement))
  }

  private static func mapElement(_ element: TextElement) -> OcrElement {
    OcrElement(text: element.text, boundingBox: Self.mapBoundingBox(element.frame))
  }

  private static func mapBoundingBox(_ rect: CGRect) -> BoundingBox {
    // Generated shape is { x, y, width, height } — same as vision-camera's
    // BoundingBox, because Nitrogen deduplicates on the shared type name.
    BoundingBox(
      x: Double(rect.minX),
      y: Double(rect.minY),
      width: Double(rect.width),
      height: Double(rect.height)
    )
  }

  // MARK: - Re-lining (unified standard-axis algorithm)
  //
  // Because toMLImage() sets orientation from HybridFrameSpec.orientation,
  // MLKit returns bounding boxes in the viewer's orientation: `x` = horizontal,
  // `y` = vertical. Same as Android MLKit. No iOS-specific axis swap.

  /// Sort elements into reading order (top-to-bottom, then left-to-right).
  private static func sortBefore(_ a: OcrElement, _ b: OcrElement) -> Bool {
    let diffOfTops  = a.boundingBox.y - b.boundingBox.y
    let diffOfLefts = a.boundingBox.x - b.boundingBox.x
    let height = (a.boundingBox.height + b.boundingBox.height) / 2.0
    if abs(diffOfTops) > height * 0.5 { return diffOfTops < 0 }
    return diffOfLefts < 0
  }

  /// True if two elements belong to the same logical line.
  private static func isSameLine(_ a: OcrElement, _ b: OcrElement) -> Bool {
    let diffOfTops = a.boundingBox.y - b.boundingBox.y
    let threshold = (a.boundingBox.height + b.boundingBox.height) * 0.35
    return abs(diffOfTops) <= threshold
  }

  private static func reLine(_ elements: [OcrElement]) -> [String] {
    guard !elements.isEmpty else { return [] }
    let sorted = elements.sorted(by: sortBefore)

    var lines: [[OcrElement]] = [[sorted[0]]]
    for i in 1..<sorted.count {
      let curr = sorted[i]
      if let prev = lines.last?.last, isSameLine(prev, curr) {
        lines[lines.count - 1].append(curr)
      } else {
        lines.append([curr])
      }
    }

    return lines.map { line in line.map { $0.text }.joined(separator: " ") }
  }
}
