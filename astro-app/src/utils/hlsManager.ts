// HLS Manager - Handles HLS.js initialization and playback for Astro
import logger from './logger';
import type Hls from 'hls.js';

// Lazy load HLS.js dynamically to avoid SSR issues
let HlsClass: typeof Hls | null = null;
let hlsLoadPromise: Promise<typeof Hls | null> | null = null;

// Load HLS.js dynamically (only in browser)
const loadHLS = async (): Promise<typeof Hls | null> => {
  if (typeof window === 'undefined') {
    return null;
  }
  
  if (HlsClass) {
    return HlsClass;
  }
  
  if (hlsLoadPromise) {
    return hlsLoadPromise;
  }
  
  try {
    hlsLoadPromise = import('hls.js').then(module => {
      HlsClass = module.default;
      return HlsClass;
    }).catch(e => {
      logger.warn('🚫 HLS: Failed to load hls.js module', e);
      hlsLoadPromise = null;
      return null;
    });
  } catch (e) {
    logger.warn('🚫 HLS: Failed to create dynamic import', e);
    hlsLoadPromise = Promise.resolve(null);
  }
  
  return hlsLoadPromise;
};

// Check if HLS.js is available (lazy check)
const isHlsAvailable = (): boolean => {
  return HlsClass !== null && typeof HlsClass !== 'undefined' && typeof HlsClass.isSupported === 'function';
};

// Track HLS instances to avoid creating duplicates
const hlsInstances = new Map<HTMLVideoElement, Hls>();

/**
 * Get existing HLS instance for a video element
 */
export function getHLSInstance(videoElement: HTMLVideoElement): Hls | undefined {
  return hlsInstances.get(videoElement);
}

/**
 * Initialize HLS for a video element if needed
 * Returns true if HLS was initialized or native playback is supported
 */
export async function initializeHLS(
  videoElement: HTMLVideoElement,
  src: string
): Promise<boolean> {
  if (typeof window === 'undefined') {
    return false;
  }

  // Check if browser supports native HLS
  if (videoElement.canPlayType('application/vnd.apple.mpegurl')) {
    logger.debug('📺 HLS: Native playback supported', src);
    videoElement.src = src;
    return true;
  }

  // Load HLS.js
  const Hls = await loadHLS();
  
  if (!Hls || !Hls.isSupported()) {
    logger.warn('🚫 HLS: HLS.js not supported in this browser');
    return false;
  }

  // Don't create duplicate instances
  if (hlsInstances.has(videoElement)) {
    logger.debug('♻️ HLS: Reusing existing instance');
    return true;
  }

  try {
    const hls = new Hls({
      maxBufferLength: 10,
      maxMaxBufferLength: 20,
      maxBufferSize: 10 * 1000 * 1000, // 10MB
      maxBufferHole: 0.5,
      enableWorker: true,
      lowLatencyMode: false,
      backBufferLength: 10,
    });

    hls.loadSource(src);
    hls.attachMedia(videoElement);

    hlsInstances.set(videoElement, hls);

    hls.on(Hls.Events.MANIFEST_PARSED, () => {
      logger.debug('✅ HLS: Manifest loaded and parsed', src);
    });

    hls.on(Hls.Events.ERROR, (event, data) => {
      if (data.fatal) {
        logger.error('💥 HLS: Fatal error', data);
        destroyHLS(videoElement);
      } else {
        logger.warn('⚠️ HLS: Non-fatal error', data.type, data.details);
      }
    });

    return true;
  } catch (error) {
    logger.error('❌ HLS: Failed to initialize', error);
    return false;
  }
}

/**
 * Destroy HLS instance and cleanup resources
 */
export function destroyHLS(videoElement: HTMLVideoElement): void {
  const hls = hlsInstances.get(videoElement);
  if (hls) {
    try {
      hls.destroy();
      hlsInstances.delete(videoElement);
      logger.debug('🧹 HLS: Instance destroyed');
    } catch (error) {
      logger.error('❌ HLS: Error destroying instance', error);
    }
  }
}

/**
 * Cleanup all HLS instances
 */
export function cleanupAllHLS(): void {
  hlsInstances.forEach((hls, video) => {
    try {
      hls.destroy();
    } catch (error) {
      logger.error('❌ HLS: Error destroying instance during cleanup', error);
    }
  });
  hlsInstances.clear();
  logger.info('🧹 HLS: All instances cleaned up');
}
