import type { HybridObject } from 'react-native-nitro-modules'
import type { Frame } from 'react-native-vision-camera'

/**
 * Axis-aligned rectangle in the frame's oriented (post-rotation) coordinate
 * space — same shape as `react-native-vision-camera`'s own `BoundingBox`.
 * `x`/`y` is the top-left corner in the image's oriented space; `width`/
 * `height` extend right/down. MLKit boxes are mapped into this shape natively
 * on both platforms.
 */
export interface BoundingBox {
  x: number
  y: number
  width: number
  height: number
}

/** Smallest unit — typically a single word. */
export interface OcrElement {
  text: string
  boundingBox: BoundingBox
}

/** A line of text composed of one or more elements. */
export interface OcrLine {
  text: string
  elements: OcrElement[]
}

/** A block of text composed of one or more lines. */
export interface OcrBlock {
  text: string
  lines: OcrLine[]
}

/** Full OCR result for one frame. */
export interface OcrResult {
  /** MLKit's raw full-text dump (unchanged, for fallback consumers). */
  text: string
  /**
   * MLKit's native block → line → element hierarchy. Bounding boxes are in
   * the frame's oriented space — because the native layer sets MLKit image
   * orientation from the v5 `HybridFrameSpec.orientation`, iOS and Android
   * agree on axis semantics (`x` = horizontal, `y` = vertical).
   */
  blocks: OcrBlock[]
  /**
   * Re-lined output: all elements regrouped into logical lines by bounding-box
   * proximity, each line's elements space-joined. Platform-aware grouping is
   * done natively and unified across iOS/Android (no `isIOS` branching on the
   * JS side). This is the primary output for regex-based label parsers.
   */
  lines: string[]
}

/**
 * Optional orientation hint for still images. Omit it for already-upright
 * cropped images. Camera-style values are accepted so callers can forward
 * existing orientation metadata without platform branching.
 */
export interface NitroOcr extends HybridObject<{ ios: 'swift'; android: 'kotlin' }> {
  /**
   * Run MLKit Text Recognition synchronously on a single vision-camera v5
   * frame. Invoke from inside a `useFrameOutput` worklet and throttle callers.
   */
  recognize(frame: Frame): OcrResult

  /**
   * Run MLKit Text Recognition on a local image path. This is intended for
   * flows that first crop/dewarp a camera frame into a label image, then OCR
   * the saved file outside the hot camera frame loop.
   *
   * Supported orientation strings: up, down, left, right, upMirrored,
   * downMirrored, leftMirrored, rightMirrored, portrait,
   * portraitUpsideDown, landscapeLeft, landscapeRight.
   */
  recognizeImage(imagePath: string, orientation?: string): OcrResult
}
