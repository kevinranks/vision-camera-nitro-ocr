# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this package is

A Nitro Modules OCR plugin for `react-native-vision-camera` v5. Wraps MLKit Text Recognition (latin) on both iOS and Android behind a single Nitro `HybridObject` (`NitroOcr`) with a synchronous `recognize(frame)` method intended to be called from inside a `useFrameOutput` worklet.

There is no JS-side platform branching — both natives produce the identical `OcrResult` shape (`text`, `blocks[]`, `lines[]`) with bounding boxes in the frame's oriented coordinate space.

## Common commands

```bash
# TypeScript check (only thing that runs at the package root)
npm run typecheck

# Regenerate Nitrogen specs after editing src/NitroOcr.nitro.ts
npm run nitrogen

# Example app (separate workspace under example/)
cd example
npm run start            # Metro
npm run ios              # build + run iOS
npm run android          # build + run Android
```

There is no test runner, lint script, or unit test suite at the package root — only `tsc --noEmit`. The example app has the standard RN `__tests__/` skeleton.

## Architecture

### Nitro spec is the source of truth

`src/NitroOcr.nitro.ts` declares the `NitroOcr` HybridObject and all DTO types (`OcrResult`, `OcrBlock`, `OcrLine`, `OcrElement`, `BoundingBox`). Running `npm run nitrogen` reads it plus `nitro.json` and writes Swift/Kotlin/C++ glue into `nitrogen/generated/`. Consumers usually install this package via a GitHub tarball and **do not regenerate**, so `nitrogen/generated/` is intentionally committed (see `.gitignore`).

Editing the public API means: edit `NitroOcr.nitro.ts` → run nitrogen → update both native impls to match the regenerated spec base classes.

### `nitro.json` autolinking

`nitro.json` maps the module name `NitroOcr` to:
- iOS: Swift class `HybridNitroOcr` (in module `VisionCameraNitroOcr`)
- Android: Kotlin class `HybridNitroOcr` (in package `com.margelo.nitro.nitroocr`, the Nitrogen convention — separate from the React package class in `com.visioncameranitroocr`)

Both `implementationClassName` values must match the actual class names exactly; the JNI `kJavaDescriptor` is derived from this and getting it wrong shows up at registration time on Android.

### Native implementations

| File | Role |
|------|------|
| `ios/HybridNitroOcr.swift` | Swift impl extending the Nitrogen-generated `HybridNitroOcrSpec`. Holds a single `TextRecognizer`. |
| `ios/Extensions/ML+HybridFrameSpec.swift` | `HybridFrameSpec → MLImage` bridge (sets `image.orientation` from frame orientation). |
| `ios/Extensions/UI+CameraOrientation.swift` | `CameraOrientation → UIImage.Orientation` mapping. |
| `android/src/main/java/com/margelo/nitro/nitroocr/HybridNitroOcr.kt` | Kotlin impl. Uses `Tasks.await(recognizer.process(...))` to run MLKit synchronously on the worklet thread. |
| `android/src/main/java/com/margelo/nitro/nitroocr/extensions/MLHybridFrameSpec.kt` | `HybridFrameSpec → InputImage` bridge. |
| `android/src/main/java/com/visioncameranitroocr/VisionCameraNitroOcrPackage.kt` | RN `BaseReactPackage` whose `init` calls `NitroOcrOnLoad.initializeNative()` to load the native lib. |
| `android/src/main/cpp/cpp-adapter.cpp` | `JNI_OnLoad` → `registerAllNatives()`. |

The `MLHybridFrameSpec.kt` and `ML+HybridFrameSpec.swift` extensions are ported verbatim from `react-native-vision-camera-barcode-scanner` — that's the canonical v5 pattern for a frame-processor MLKit plugin and should not be diverged from without a reason.

### Re-lining algorithm

Both platforms run the same re-lining pass (`sortBefore` + `isSameLine` + `reLine`) over MLKit elements. Because `toMLImage` / `toInputImage` set MLKit's image orientation from `HybridFrameSpec.orientation`, MLKit returns boxes in the viewer's oriented space on both platforms — `x = horizontal`, `y = vertical`, no iOS-specific axis swap. **Keep the two implementations in sync** (top-to-bottom by `y`, ties left-to-right by `x`, new line when y-gap > ~0.35 × average element height).

### Error handling contract

On any error path (`toMLImage`/`toInputImage` failure, MLKit failure), both natives `NSLog`/`Log.w` and return an empty `OcrResult`. This is intentional and matches the v4 fork behavior — the camera stays alive and consumers treat empty as "nothing recognized." Don't surface throws to JS.

## Build gotchas (real bugs that have been hit)

**Android — ABI selection.** `android/build.gradle` reads `reactNativeArchitectures` from the consumer's Gradle properties and falls back to all four ABIs only when unset. Hardcoding all four caused linker errors against consumer Nitro plugins (NitroModules, VisionCamera) that built fewer ABIs. Don't change the `reactNativeArchitectures()` helper without understanding this.

**Android — prefab.** `android/fix-prefab.gradle` is a workaround that re-touches `prefab_config.json` so the `.so` ends up in the prefab publication. Both `prefab true` (in `buildFeatures`) and this script are required.

**Android — packagingOptions excludes.** The list strips `libc++_shared.so`, `libNitroModules.so`, `libfbjni.so`, etc. so the consumer's app doesn't get duplicate `.so`s when multiple Nitro plugins are installed.

**iOS — MLKit version pin.** `VisionCameraNitroOcr.podspec` pins `GoogleMLKit/TextRecognition ~> 8.0` to match the `MLKitVision` transitive used by `react-native-vision-camera-barcode-scanner` v5.x. Both subspecs must come from the same GoogleMLKit release.

**iOS — simulator arm64.** `EXCLUDED_ARCHS[sdk=iphonesimulator*] = arm64` is set in both `pod_target_xcconfig` and `user_target_xcconfig` because MLKit doesn't ship arm64 simulator slices.

**iOS — podspec ordering.** `add_nitrogen_files(s)` from `nitrogen/generated/ios/VisionCameraNitroOcr+autolinking.rb` must run **before** `install_modules_dependencies(s)` in the podspec.

## Public API shape

`useOcr()` returns a cached singleton `NitroOcr`. `recognize(frame)` is synchronous and is meant to be invoked from inside a `'worklet'` `useFrameOutput` callback (vision-camera v5). Consumers typically only need `result.lines` (the re-lined output) — `text` is raw MLKit and `blocks` is the full hierarchy with bounding boxes.

## Repo conventions

- `lib/` is the build output and is gitignored — don't commit it.
- `nitrogen/generated/` IS committed (see above).
- The `.gitignore` has an explicit comment about this; don't "tidy it up."
- The package's npm `files` field (`package.json`) controls what ships to consumers; keep `nitrogen/generated`, `ios`, `android`, `nitro.json`, and `VisionCameraNitroOcr.podspec` listed.
