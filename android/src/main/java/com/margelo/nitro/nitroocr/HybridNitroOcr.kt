package com.margelo.nitro.nitroocr

import android.util.Log
import androidx.annotation.OptIn
import androidx.camera.core.ExperimentalGetImage
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.text.Text
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.TextRecognizer
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.margelo.nitro.camera.HybridFrameSpec
import com.margelo.nitro.nitroocr.extensions.toInputImage
import kotlin.math.abs

/**
 * Concrete implementation of the Nitro `NitroOcr` hybrid object for Android.
 * Registered by Nitrogen via `nitro.json → autolinking → HybridNitroOcr`.
 */
class HybridNitroOcr : HybridNitroOcrSpec() {
  companion object {
    private const val TAG = "NitroOcr"
  }

  private val recognizer: TextRecognizer =
    TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

  @OptIn(ExperimentalGetImage::class)
  override fun recognize(frame: HybridFrameSpec): OcrResult {
    val inputImage = try {
      frame.toInputImage()
    } catch (e: Throwable) {
      Log.w(TAG, "toInputImage failed", e)
      return empty()
    }

    return try {
      val text = Tasks.await(recognizer.process(inputImage))
      if (text.text.isEmpty()) empty()
      else {
        val blocks = text.textBlocks.map(::mapBlock)
        val allElements = blocks.flatMap { b -> b.lines.flatMap { it.elements.toList() } }
        OcrResult(
          text = text.text,
          blocks = blocks.toTypedArray(),
          lines = reLine(allElements).toTypedArray()
        )
      }
    } catch (e: Exception) {
      // Match v4 fork behavior: swallow and return empty on error.
      Log.w(TAG, "recognize failed", e)
      empty()
    }
    // NOTE: vision-camera's worklet pipeline owns the ImageProxy lifecycle;
    // it is closed when the worklet returns. Do NOT close anything here.
  }

  private fun empty() = OcrResult(
    text = "",
    blocks = emptyArray(),
    lines = emptyArray()
  )

  // MARK: MLKit → Ocr mapping

  private fun mapBlock(block: Text.TextBlock): OcrBlock = OcrBlock(
    text = block.text,
    lines = block.lines.map(::mapLine).toTypedArray()
  )

  private fun mapLine(line: Text.Line): OcrLine = OcrLine(
    text = line.text,
    elements = line.elements.map(::mapElement).toTypedArray()
  )

  private fun mapElement(element: Text.Element): OcrElement = OcrElement(
    text = element.text,
    boundingBox = element.boundingBox?.let {
      BoundingBox(
        x = it.left.toDouble(),
        y = it.top.toDouble(),
        width = (it.right - it.left).toDouble(),
        height = (it.bottom - it.top).toDouble()
      )
    } ?: BoundingBox(x = 0.0, y = 0.0, width = 0.0, height = 0.0)
  )

  // MARK: Re-lining (unified standard-axis algorithm — identical to iOS)
  //
  // `x` = horizontal, `y` = vertical. Sort top-to-bottom (by y), break ties
  // left-to-right (by x). Group into a new logical line when y gap exceeds
  // ~half the average height.

  private fun sortComparator(a: OcrElement, b: OcrElement): Int {
    val diffOfTops = a.boundingBox.y - b.boundingBox.y
    val diffOfLefts = a.boundingBox.x - b.boundingBox.x
    val height = (a.boundingBox.height + b.boundingBox.height) / 2.0
    return if (abs(diffOfTops) > height * 0.5) {
      diffOfTops.compareTo(0.0)
    } else {
      diffOfLefts.compareTo(0.0)
    }
  }

  private fun isSameLine(a: OcrElement, b: OcrElement): Boolean {
    val diffOfTops = a.boundingBox.y - b.boundingBox.y
    val threshold = (a.boundingBox.height + b.boundingBox.height) * 0.35
    return abs(diffOfTops) <= threshold
  }

  private fun reLine(elements: List<OcrElement>): List<String> {
    if (elements.isEmpty()) return emptyList()
    val sorted = elements.sortedWith(::sortComparator)

    val lines = mutableListOf<MutableList<OcrElement>>()
    lines.add(mutableListOf(sorted[0]))
    for (i in 1 until sorted.size) {
      val curr = sorted[i]
      val prev = lines.last().last()
      if (isSameLine(prev, curr)) {
        lines.last().add(curr)
      } else {
        lines.add(mutableListOf(curr))
      }
    }

    return lines.map { line -> line.joinToString(" ") { it.text } }
  }
}
