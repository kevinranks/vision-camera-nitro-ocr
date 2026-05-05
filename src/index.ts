import { NitroModules } from 'react-native-nitro-modules'
import type { NitroOcr } from './NitroOcr.nitro'

let _instance: NitroOcr | undefined

/**
 * Returns the singleton OCR hybrid object. Safe to call repeatedly —
 * the instance is created once and cached.
 */
export function useOcr(): NitroOcr {
  if (_instance == null) {
    _instance = NitroModules.createHybridObject<NitroOcr>('NitroOcr')
  }
  return _instance
}

export type {
  NitroOcr,
  OcrResult,
  OcrBlock,
  OcrLine,
  OcrElement,
  BoundingBox,
} from './NitroOcr.nitro'
