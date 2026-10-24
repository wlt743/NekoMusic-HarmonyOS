import { media } from "@kit.MediaKit";
import { BusinessError } from "@kit.BasicServicesKit";
import { hilog } from "@kit.PerformanceAnalysisKit";
import { HttpClient } from "./HttpClient";
import { MusicService } from "./MusicService";
import { LyricsParser, LyricLine } from "./LyricsParser";
import { MusicItem } from "../models/Music";

/**
 * 鸿蒙端播放引擎。
 * 状态放在 AppStorage 里，页面用 @StorageLink 绑定即可自动刷新。
 */
export class AudioPlayerService {
  private static instance: AudioPlayerService = new AudioPlayerService();
  private player: media.AVPlayer | undefined = undefined;
  private playlist: MusicItem[] = [];
  private currentIndex: number = -1;
  private preparing: boolean = false;
  private lyrics: LyricLine[] = [];
  private lastLyricIndex: number = -1;

  static shared(): AudioPlayerService {
    return AudioPlayerService.instance;
  }

  private constructor() {
    AppStorage.setOrCreate<MusicItem | undefined>("currentMusic", undefined);
    AppStorage.setOrCreate<boolean>("isPlaying", false);
    AppStorage.setOrCreate<number>("position", 0);
    AppStorage.setOrCreate<number>("duration", 0);
    AppStorage.setOrCreate<boolean>("playerReady", false);
    AppStorage.setOrCreate<string>("currentLyric", "");
    AppStorage.setOrCreate<string>("nextLyric", "");
    AppStorage.setOrCreate<LyricLine[]>("lyricLines", []);
    AppStorage.setOrCreate<number>("lyricIndex", -1);
    AppStorage.setOrCreate<boolean>("isLoading", false);
    AppStorage.setOrCreate<string>("loadError", "");
  }

  /** 直接读播放器状态，绕开 AppStorage 的线程问题 */
  isPlayingNow(): boolean {
    return this.player !== undefined && this.player.state === "playing";
  }

  currentMusic(): MusicItem | undefined {
    return AppStorage.get<MusicItem>("currentMusic");
  }

  setPlaylist(list: MusicItem[], startAt: number = 0): void {
    this.playlist = list;
    this.currentIndex = startAt;
    this.playAt(startAt);
  }

  list(): MusicItem[] {
    return this.playlist;
  }

  async playAt(index: number): Promise<void> {
    if (index < 0 || index >= this.playlist.length) {
      return;
    }
    this.currentIndex = index;
    const music: MusicItem = this.playlist[index];
    AppStorage.set<MusicItem | undefined>("currentMusic", music);
    AppStorage.set<boolean>("isPlaying", false);
    AppStorage.set<number>("position", 0);
    AppStorage.set<number>("duration", (music.duration ?? 0) * 1000);

    AppStorage.set<boolean>("isLoading", true);
    AppStorage.set<string>("loadError", "");
    this.lyrics = [];
    this.lastLyricIndex = -1;
    AppStorage.set<string>("currentLyric", "");
    AppStorage.set<string>("nextLyric", "");
    AppStorage.set<LyricLine[]>("lyricLines", []);
    AppStorage.set<number>("lyricIndex", -1);
    this.loadLyrics(music.id);

    try {
      const realURL: string = await HttpClient.resolveAudioURL(music.id);
      await this.switchTo(realURL);
      AppStorage.set<boolean>("isLoading", false);
    } catch (error) {
      AppStorage.set<boolean>("isPlaying", false);
      AppStorage.set<boolean>("isLoading", false);
      const err = error as Error;
      AppStorage.set<string>("loadError", "加载失败: " + (err.message ?? "未知错误"));
    }
  }

  private async loadLyrics(musicId: number): Promise<void> {
    try {
      const lrc: string = await MusicService.lyrics(musicId);
      const parsed: LyricLine[] = LyricsParser.parse(lrc);
      const current = this.currentMusic();
      if (current === undefined || current.id !== musicId) {
        return;
      }
      this.lyrics = parsed;
      AppStorage.set<LyricLine[]>("lyricLines", parsed);
      if (parsed.length === 0) {
        AppStorage.set<string>("currentLyric", lrc.length > 0 ? "纯音乐，请欣赏" : "");
      } else {
        AppStorage.set<string>("currentLyric", parsed[0].text);
        AppStorage.set<string>("nextLyric", parsed.length > 1 ? parsed[1].text : "");
      }
    } catch (error) {
      AppStorage.set<string>("currentLyric", "");
    }
  }

  private updateLyricLine(positionMs: number): void {
    if (this.lyrics.length === 0) {
      return;
    }
    const index: number = LyricsParser.indexAt(positionMs, this.lyrics);
    if (index === this.lastLyricIndex || index < 0) {
      return;
    }
    this.lastLyricIndex = index;
    AppStorage.set<number>("lyricIndex", index);
    AppStorage.set<string>("currentLyric", this.lyrics[index].text);
    AppStorage.set<string>("nextLyric", index + 1 < this.lyrics.length ? this.lyrics[index + 1].text : "");
  }

  private async switchTo(url: string): Promise<void> {
    this.preparing = true;
    if (this.player === undefined) {
      this.player = await media.createAVPlayer();
      this.attachListeners();
    }
    this.player.url = url;
    this.preparing = false;
  }

  private attachListeners(): void {
    const player: media.AVPlayer | undefined = this.player;
    if (player === undefined) {
      return;
    }
    player.on("stateChange", (state: string) => {
      hilog.info(0x0000, "NekoPlayer", "state=%{public}s", state);
      // 回调可能在后台线程，切回主线程再更新 AppStorage，否则 UI 不刷新
      setTimeout(() => {
        if (state === "initialized") {
          player.prepare();
        } else if (state === "prepared") {
          AppStorage.set<boolean>("isLoading", false);
          AppStorage.set<boolean>("playerReady", true);
          player.play();
        } else if (state === "playing") {
          AppStorage.set<boolean>("isPlaying", true);
        } else if (state === "paused") {
          AppStorage.set<boolean>("isPlaying", false);
        } else if (state === "completed") {
          AppStorage.set<boolean>("isPlaying", false);
        }
      }, 0);
    });

    player.on("timeUpdate", (time: number) => {
      AppStorage.set<number>("position", time);
      this.updateLyricLine(time);
    });
    player.on("durationUpdate", (duration: number) => {
      AppStorage.set<number>("duration", duration);
    });
    player.on("error", (error: BusinessError) => {
      console.error("[NekoPlayer] error code=" + error.code + " msg=" + error.message);
      AppStorage.set<boolean>("isPlaying", false);
      AppStorage.set<boolean>("playerReady", false);
    });
  }

  /** 切换播放，返回切换后的状态（true=正在播放） */
  async toggle(): Promise<boolean> {
    const player: media.AVPlayer | undefined = this.player;
    if (player === undefined) {
      hilog.info(0x0000, "NekoPlayer", "toggle: player is undefined");
      return false;
    }
    const state: string = player.state as string;
    hilog.info(0x0000, "NekoPlayer", "toggle: state=%{public}s", state);
    try {
      if (state === "playing") {
        await player.pause();
        AppStorage.set<boolean>("isPlaying", false);
        return false;
      }
      await player.play();
      AppStorage.set<boolean>("isPlaying", true);
      return true;
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(0x0000, "NekoPlayer", "toggle failed: %{public}s", err.message);
      return false;
    }
  }

  async seek(positionMs: number): Promise<void> {
    const player: media.AVPlayer | undefined = this.player;
    if (player === undefined) {
      return;
    }
    await player.seek(positionMs);
    AppStorage.set<number>("position", positionMs);
  }

  next(): void {
    if (this.playlist.length === 0) {
      return;
    }
    const nextIndex: number = (this.currentIndex + 1) % this.playlist.length;
    this.playAt(nextIndex);
  }

  previous(): void {
    if (this.playlist.length === 0) {
      return;
    }
    const prevIndex: number = this.currentIndex <= 0 ? this.playlist.length - 1 : this.currentIndex - 1;
    this.playAt(prevIndex);
  }
}
