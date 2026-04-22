'use client';

import {
  createContext,
  useContext,
  useState,
  useMemo,
  useCallback,
  type ReactNode,
} from 'react';
import type { UploadedVideo } from '@gifstudio/shared';

interface GifDraft {
  sourceVideo: UploadedVideo;
  trim?: { start: number; end: number };
  gifBlob?: Blob;
  gifSettings?: { width: number; fps: number };
}

interface DraftContextValue {
  draft: GifDraft | null;
  setSourceVideo: (video: UploadedVideo) => void;
  setTrim: (trim: { start: number; end: number }) => void;
  setGifResult: (blob: Blob, settings: { width: number; fps: number }) => void;
  clear: () => void;
}

const DraftContext = createContext<DraftContextValue | undefined>(undefined);

export function DraftProvider({ children }: { children: ReactNode }) {
  const [draft, setDraft] = useState<GifDraft | null>(null);

  const setSourceVideo = useCallback((video: UploadedVideo) => {
    setDraft({ sourceVideo: video });
  }, []);

  const setTrim = useCallback((trim: { start: number; end: number }) => {
    setDraft((prev) => (prev ? { ...prev, trim } : prev));
  }, []);

  const setGifResult = useCallback(
    (blob: Blob, settings: { width: number; fps: number }) => {
      setDraft((prev) => (prev ? { ...prev, gifBlob: blob, gifSettings: settings } : prev));
    },
    [],
  );

  const clear = useCallback(() => setDraft(null), []);

  const value = useMemo(
    () => ({ draft, setSourceVideo, setTrim, setGifResult, clear }),
    [draft, setSourceVideo, setTrim, setGifResult, clear],
  );

  return <DraftContext.Provider value={value}>{children}</DraftContext.Provider>;
}

export function useDraft(): DraftContextValue {
  const ctx = useContext(DraftContext);
  if (!ctx) throw new Error('useDraft must be used within DraftProvider');
  return ctx;
}
