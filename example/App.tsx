import React, { useCallback, useRef, useState } from 'react'
import { SafeAreaView, StyleSheet, Text, TouchableOpacity, View } from 'react-native'
import {
  Camera,
  useCameraDevice,
  useCameraPermission,
  useFrameOutput,
} from 'react-native-vision-camera'
import { runOnJS } from 'react-native-worklets'
import { useOcr, type OcrResult } from '@kpaterson/vision-camera-nitro-ocr'

export default function App() {
  const { hasPermission, requestPermission } = useCameraPermission()
  const device = useCameraDevice('back')
  const ocr = useOcr()

  const [latestText, setLatestText] = useState('')
  const [elementCount, setElementCount] = useState(0)
  const [reLinedPreview, setReLinedPreview] = useState<string[]>([])

  // Mutable throttle state captured by the worklet closure.
  // useRef gives a stable JS object whose .current is accessible from the worklet.
  const throttle = useRef({ lastProcessedAt: 0 })

  const onResult = useCallback((result: OcrResult) => {
    setLatestText(result.text.slice(0, 500))
    const count = result.blocks.reduce(
      (acc: number, b: OcrResult['blocks'][number]) =>
        acc + b.lines.reduce((la: number, l: OcrResult['blocks'][number]['lines'][number]) => la + l.elements.length, 0),
      0
    )
    setElementCount(count)
    // Show the first 8 re-lined rows so we can eyeball native re-lining parity.
    setReLinedPreview(result.lines.slice(0, 8))
  }, [])

  const frameOutput = useFrameOutput({
    pixelFormat: 'yuv',
    onFrame(frame) {
      'worklet'
      try {
        // 5 FPS throttle: skip if <200ms since last process.
        // NOTE: verify the unit of frame.timestamp before trusting this constant.
        const now = Date.now()
        if (now - throttle.current.lastProcessedAt < 200) return
        throttle.current.lastProcessedAt = now

        const result = ocr.recognize(frame)
        if (result.lines.length > 0) runOnJS(onResult)(result)
      } finally {
        frame.dispose()
      }
    },
  })

  if (!hasPermission) {
    return (
      <SafeAreaView style={styles.centered}>
        <TouchableOpacity onPress={requestPermission} style={styles.button}>
          <Text style={styles.buttonText}>Grant camera permission</Text>
        </TouchableOpacity>
      </SafeAreaView>
    )
  }

  if (device == null) {
    return (
      <SafeAreaView style={styles.centered}>
        <Text>No back camera found.</Text>
      </SafeAreaView>
    )
  }

  return (
    <View style={StyleSheet.absoluteFill}>
      <Camera
        style={StyleSheet.absoluteFill}
        device={device}
        isActive={true}
        outputs={[frameOutput]}
      />
      <SafeAreaView style={styles.overlay} pointerEvents="none">
        <Text style={styles.counter}>
          elements: {elementCount} · native-lines: {reLinedPreview.length}
        </Text>
        {reLinedPreview.map((line, i) => (
          <Text key={i} style={styles.recognized}>{line}</Text>
        ))}
        {reLinedPreview.length === 0 && (
          <Text style={styles.recognized}>{latestText || '(no text yet)'}</Text>
        )}
      </SafeAreaView>
    </View>
  )
}

const styles = StyleSheet.create({
  centered: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  button: { backgroundColor: '#0a84ff', padding: 16, borderRadius: 8 },
  buttonText: { color: 'white', fontSize: 16 },
  overlay: { flex: 1, justifyContent: 'flex-end', padding: 16 },
  counter: { color: 'white', backgroundColor: 'rgba(0,0,0,0.6)', padding: 4, alignSelf: 'flex-start' },
  recognized: {
    color: 'white',
    backgroundColor: 'rgba(0,0,0,0.7)',
    padding: 8,
    marginTop: 8,
    fontSize: 12,
  },
})
