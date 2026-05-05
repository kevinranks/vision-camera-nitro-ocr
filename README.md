# @kpaterson/vision-camera-nitro-ocr

Nitro Modules OCR plugin for [react-native-vision-camera v5](https://visioncamera.margelo.com). Uses MLKit Text Recognition on both iOS and Android, exposed as a single Nitro `HybridObject` with a `recognize(frame)` method.

## Usage

```ts
import { useFrameOutput } from "react-native-vision-camera";
import { runOnJS } from "react-native-worklets";
import { useOcr } from "@kpaterson/vision-camera-nitro-ocr";

const ocr = useOcr();

const frameOutput = useFrameOutput({
  pixelFormat: "yuv",
  onFrame(frame) {
    "worklet";
    try {
      const result = ocr.recognize(frame);
      if (result.lines.length) runOnJS(handleText)(result.lines);
    } finally {
      frame.dispose();
    }
  },
});
```

## Output shape

```ts
interface OcrResult {
  text: string;
  blocks: Array<{
    text: string;
    lines: Array<{
      text: string;
      elements: Array<{
        text: string;
        boundingBox: { x: number; y: number; width: number; height: number };
      }>;
    }>;
  }>;
  lines: string[];
}
```

## License

MIT
