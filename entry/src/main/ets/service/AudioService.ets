import { media } from '@kit.MediaKit';
import { resourceManager } from '@kit.LocalizationKit';
import { BusinessError } from '@kit.BasicServicesKit';

const AUDIO_FILE: string = 'tone.wav';
const PREPARE_TIMEOUT_MS: number = 10000;

export class AudioService {
  private static instance: AudioService = new AudioService();
  private player: media.AVPlayer | undefined;
  private manager: resourceManager.ResourceManager | undefined;
  private rawFileOpen: boolean = false;
  private initialized: boolean = false;
  private initializing: Promise<void> | undefined;
  private releasing: Promise<void> | undefined;
  private foreground: boolean = true;
  private initializationCount: number = 0;

  private constructor() {}

  static getInstance(): AudioService {
    return AudioService.instance;
  }

  getInitializationCount(): number {
    return this.initializationCount;
  }

  initialize(manager: resourceManager.ResourceManager): Promise<void> {
    if (this.releasing) {
      return this.releasing.then(() => this.initialize(manager));
    }
    if (this.initialized) {
      return Promise.resolve();
    }
    if (this.initializing) {
      return this.initializing;
    }
    this.initializing = this.initializeOnce(manager).finally(() => {
      this.initializing = undefined;
    });
    return this.initializing;
  }

  private async initializeOnce(manager: resourceManager.ResourceManager): Promise<void> {
    try {
      await this.cleanup();
      this.manager = manager;
      const descriptor = await this.manager.getRawFd(AUDIO_FILE);
      this.rawFileOpen = true;
      const player = await media.createAVPlayer();
      this.player = player;
      await new Promise<void>((resolve, reject) => {
        const timer: number = setTimeout(() => {
          reject(new Error('Audio preparation timed out.'));
        }, PREPARE_TIMEOUT_MS);
        player.on('error', (error: BusinessError) => {
          clearTimeout(timer);
          this.initialized = false;
          reject(new Error(error.message));
        });
        player.on('stateChange', (state: string) => {
          if (state === 'initialized') {
            player.prepare().catch((error: BusinessError) => {
              clearTimeout(timer);
              reject(new Error(error.message));
            });
          } else if (state === 'prepared') {
            clearTimeout(timer);
            resolve();
          }
        });
        try {
          player.fdSrc = { fd: descriptor.fd, offset: descriptor.offset, length: descriptor.length };
        } catch (error) {
          clearTimeout(timer);
          reject(new Error((error as Error).message));
        }
      });
      this.initialized = true;
      this.initializationCount++;
    } catch (error) {
      await this.cleanup();
      throw new Error((error as Error).message);
    }
  }

  async play(manager: resourceManager.ResourceManager): Promise<void> {
    await this.initialize(manager);
    const player = this.player;
    if (!player || !this.foreground || this.releasing) {
      return;
    }
    if (player.state !== 'playing') {
      try {
        await player.play();
        if (!this.foreground) {
          await this.setForeground(false);
        }
      } catch (error) {
        throw new Error((error as Error).message);
      }
    }
  }

  async setForeground(foreground: boolean): Promise<void> {
    this.foreground = foreground;
    if (!foreground && this.player?.state === 'playing') {
      try {
        await this.player.pause();
      } catch (error) {
        throw new Error((error as Error).message);
      }
    }
  }

  release(): Promise<void> {
    if (this.releasing) {
      return this.releasing;
    }
    this.releasing = this.releaseOnce().finally(() => {
      this.releasing = undefined;
    });
    return this.releasing;
  }

  private async releaseOnce(): Promise<void> {
    try {
      await this.initializing;
    } catch (_) {
    }
    await this.cleanup();
  }

  private async cleanup(): Promise<void> {
    this.initialized = false;
    try {
      if (this.player) {
        try {
          await this.player.release();
        } catch (error) {
          throw new Error((error as Error).message);
        }
      }
    } finally {
      this.player = undefined;
      try {
        if (this.rawFileOpen && this.manager) {
          try {
            await this.manager.closeRawFd(AUDIO_FILE);
          } catch (_) {
            // Cleanup is best-effort; state is reset in the finally block below.
          }
        }
      } finally {
        this.rawFileOpen = false;
        this.manager = undefined;
      }
    }
  }
}
