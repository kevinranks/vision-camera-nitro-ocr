require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))
# package["repository"] is { type, url } per npm convention; url is "git+https://..."
# Strip the "git+" prefix to get a plain HTTPS URL CocoaPods accepts.
repo_url = package["repository"]["url"].sub(/^git\+/, "").sub(/\.git$/, "")

Pod::Spec.new do |s|
  s.name         = "VisionCameraNitroOcr"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.description  = "#{package["description"]} Wraps MLKit Text Recognition behind a single Nitro HybridObject (`recognize(frame)`), unifying line reassembly natively across iOS and Android."
  s.homepage     = repo_url
  s.license      = package["license"]
  s.authors      = package["author"]

  # `min_ios_version_supported` is a React Native CocoaPods helper; MLKit
  # TextRecognition needs iOS 13.4+ and we use `HybridFrameSpec` APIs that
  # are iOS 13.4+ in vision-camera v5. Fall back to hardcoded 13.4 if the
  # helper isn't available in this environment.
  s.platforms    = { :ios => (defined?(min_ios_version_supported) ? min_ios_version_supported : "13.4") }
  s.source       = { :git => "#{repo_url}.git", :tag => "#{s.version}" }

  s.source_files = [
    # Swift implementation (our HybridNitroOcr + ML extensions).
    "ios/**/*.{swift}",
  ]
  s.frameworks = ["AVFoundation", "UIKit"]

  s.swift_version = "5.9"
  s.pod_target_xcconfig = {
    "DEFINES_MODULE" => "YES",
    "CLANG_CXX_LANGUAGE_STANDARD" => "c++20",
  }
  # Intentionally NO EXCLUDED_ARCHS for the simulator. Modern GoogleMLKit
  # (8.x+) ships both x86_64 and arm64 simulator slices, and excluding
  # arm64 forces consumer apps to build under Rosetta — which then triggers
  # Swift 6.2 / Xcode 26 C++ interop bugs (see Margelo issue #3785) that
  # don't manifest on native arm64 sim builds.

  # MLKit Text Recognition (latin script). Version pinned to match the
  # peer `react-native-vision-camera-barcode-scanner` v5.x pin of
  # `GoogleMLKit/BarcodeScanning 8.0.0` — both subspecs must come from
  # the same GoogleMLKit release (shared MLKitVision transitive dep).
  s.dependency "GoogleMLKit/TextRecognition", "~> 8.0"

  # VisionCamera pod name is "VisionCamera" (NOT "react-native-vision-camera").
  # This exposes HybridFrameSpec, NativeFrame, and CameraOrientation symbols
  # needed by our Swift code.
  s.dependency "VisionCamera"

  # Pull in Nitrogen-generated autolinking — this is what registers the
  # Swift HybridNitroOcr class and adds every generated Swift/C++ file to
  # the pod. Must come BEFORE install_modules_dependencies.
  load "nitrogen/generated/ios/VisionCameraNitroOcr+autolinking.rb"
  add_nitrogen_files(s)

  # Standard RN pod setup (React-jsi, React-callinvoker, etc.).
  install_modules_dependencies(s)
end
