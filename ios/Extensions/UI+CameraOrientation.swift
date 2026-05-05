//
//  UI+CameraOrientation.swift
//  VisionCameraNitroOcr
//
//  Ported from react-native-vision-camera-barcode-scanner (canonical v5 pattern).
//

import UIKit
import VisionCamera

extension CameraOrientation {
  func toUIImageOrientation(isMirrored: Bool = false) -> UIImage.Orientation {
    switch self {
    case .up:    return isMirrored ? .upMirrored    : .up
    case .down:  return isMirrored ? .downMirrored  : .down
    case .left:  return isMirrored ? .leftMirrored  : .left
    case .right: return isMirrored ? .rightMirrored : .right
    }
  }
}
