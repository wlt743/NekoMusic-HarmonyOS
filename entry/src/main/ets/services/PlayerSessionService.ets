import { avSession } from '@kit.AVSessionKit';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { http } from '@kit.NetworkKit';
import { image } from '@kit.ImageKit';
import { APIConfig } from './APIConfig';

/**
 * 媒体会话：把播放状态同步到系统媒体中心 / 锁屏 / 耳机控制，
 * 并接入华为多端协同（超级终端投播、音频接续）。
 */
export class PlayerSessionService {
  private static session: avSession.AVSession | undefined = undefined;
  private static ready: boolean = false;
  private static currentAssetId: string = '';
  private static currentTitle: string = '';
  private static currentArtist: string = '';
  private static currentDuration: number = 0;
  private static currentImage: image.PixelMap | undefined = undefined;

  static async init(context: common.UIAbilityContext): Promise<void> {
    if (PlayerSessionService.ready) {
      return;
    }
    try {
      const session = await avSession.createAVSession(context, 'NekoMusic', 'audio');
      PlayerSessionService.session = session;
      PlayerSessionService.ready = true;
      PlayerSessionService.bindControls(session);
      await session.activate();
      hilog.info(0x0000, 'NekoSession', 'AVSession created');
    } catch (error) {
      const err = error as Error;
      hilog.error(0x0000, 'NekoSession', 'create failed: %{public}s', err.message);
    }
  }

  private static bindControls(session: avSession.AVSession): void {
    try {
      session.on('play', () => {
        // 由 AudioPlayerService 处理
        AppStorage.set<boolean>('sessionCommand', true);
        AppStorage.set<string>('sessionAction', 'play');
      });
      session.on('pause', () => {
        AppStorage.set<string>('sessionAction', 'pause');
      });
      session.on('playNext', () => {
        AppStorage.set<string>('sessionAction', 'next');
      });
      session.on('playPrevious', () => {
        AppStorage.set<string>('sessionAction', 'previous');
      });
      session.on('seek', (time: number) => {
        AppStorage.set<number>('sessionSeek', time);
        AppStorage.set<string>('sessionAction', 'seek');
      });
      session.on('stop', () => {
        AppStorage.set<string>('sessionAction', 'stop');
      });
    } catch (error) {
      hilog.error(0x0000, 'NekoSession', 'bind failed');
    }
  }

  /** 更新歌曲信息（标题/歌手/时长/封面） */
  static async updateMetadata(id: number, title: string, artist: string, duration: number,
    coverUrl: string): Promise<void> {
    const session = PlayerSessionService.session;
    if (session === undefined) {
      return;
    }
    const meta: avSession.AVMetadata = {
      assetId: id.toString(),
      title: title,
      artist: artist,
      duration: duration
    };
    const artwork = await PlayerSessionService.loadArtwork(coverUrl);
    if (artwork !== undefined) {
      meta.mediaImage = artwork;
    }
    try {
      await session.setAVMetadata(meta);
      hilog.info(0x0000, 'NekoSession', 'metadata updated, artwork=' + (artwork !== undefined ? '1' : '0'));
    } catch (error) {
      const err = error as Error;
      hilog.error(0x0000, 'NekoSession', 'metadata failed: %{public}s', err.message);
    }
  }

  /** 更新单行歌词（实况窗展示） */
  static async updateLyric(text: string): Promise<void> {
    const session = PlayerSessionService.session;
    if (session === undefined) {
      hilog.warn(0x0000, 'NekoSession', 'lyric skipped: no session');
      return;
    }
    try {
      await session.setAVMetadata({
        assetId: PlayerSessionService.currentAssetId,
        title: PlayerSessionService.currentTitle,
        artist: PlayerSessionService.currentArtist,
        duration: PlayerSessionService.currentDuration,
        mediaImage: PlayerSessionService.currentImage,
        singleLyricText: text
      });
      hilog.info(0x0000, 'NekoSession', 'lyric=' + text.substring(0, Math.min(12, text.length)));
    } catch (error) {
      const err = error as Error;
      hilog.error(0x0000, 'NekoSession', 'lyric failed: %{public}s', err.message);
    }
  }

  /** 下载封面并转 PixelMap（媒体会话要求） */
  private static async loadArtwork(url: string): Promise<image.PixelMap | undefined> {
    if (url.length === 0) {
      return undefined;
    }
    try {
      const request = http.createHttp();
      try {
        const header: Record<string, string> = APIConfig.clientHeaders();
        header['Accept'] = 'image/*';
        const response = await request.request(url, {
          method: http.RequestMethod.GET,
          header: header,
          expectDataType: http.HttpDataType.ARRAY_BUFFER,
          connectTimeout: 8000,
          readTimeout: 12000
        });
        if (response.responseCode !== 200 || response.result === undefined) {
          return undefined;
        }
        const buffer: ArrayBuffer = response.result as ArrayBuffer;
        const source = image.createImageSource(buffer);
        const pixelMap = await source.createPixelMap();
        await source.release();
        return pixelMap;
      } finally {
        request.destroy();
      }
    } catch (error) {
      hilog.error(0x0000, 'NekoSession', 'artwork load failed');
      return undefined;
    }
  }

  /** 更新播放状态与进度 */
  static async updatePlayback(playing: boolean, position: number, duration: number): Promise<void> {
    const session = PlayerSessionService.session;
    if (session === undefined) {
      return;
    }
    try {
      await session.setAVPlaybackState({
        state: playing ? avSession.PlaybackState.PLAYBACK_STATE_PLAY
          : avSession.PlaybackState.PLAYBACK_STATE_PAUSE,
        position: {
          elapsedTime: position,
          updateTime: Date.now()
        },
        speed: 1.0
      });
      hilog.info(0x0000, 'NekoSession', 'playback state=' + (playing ? 'PLAY' : 'PAUSE') +
        ' pos=' + position.toFixed(0));
    } catch (error) {
      const err = error as Error;
      hilog.error(0x0000, 'NekoSession', 'playback state failed: %{public}s', err.message);
    }
  }

  static async destroy(): Promise<void> {
    const session = PlayerSessionService.session;
    if (session === undefined) {
      return;
    }
    try {
      await session.destroy();
    } catch (error) {
      // 忽略
    }
    PlayerSessionService.session = undefined;
    PlayerSessionService.ready = false;
  }
}
