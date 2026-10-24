import { MaterialService } from "../services/MaterialService";
import { router } from "@kit.ArkUI";
import { hilog } from "@kit.PerformanceAnalysisKit";
import { togglePlay, currentPlayerState } from "../services/PlayerCore";
import { MusicService } from "../services/MusicService";
import { MusicItem } from "../models/Music";
import { AudioPlayerService } from "../services/AudioPlayerService";
import { RemoteImage } from "../components/RemoteImage";
import { PlayToggleButton } from "../components/PlayToggleButton";
import { FavoriteButton } from "../components/FavoriteButton";
import { FavoriteService } from "../services/FavoriteService";
import { AuthService } from "../services/AuthService";
import { LyricLine } from "../services/LyricsParser";
import { AudioPlayerService as Player } from "../services/AudioPlayerService";

@Entry
@Component
struct PlayerPage {
  @StorageLink("currentMusic") currentMusic: MusicItem | undefined = undefined;
  @StorageLink("isPlaying") isPlaying: boolean = false;
  @State playingSync: boolean = false;
  @StorageLink("favoriteIds") favoriteIds: number[] = [];
  @State private favorited: boolean = false;
  @State private toast: string = "";
  @StorageLink("position") playbackPosition: number = 0;
  @StorageLink("duration") duration: number = 0;
  @StorageLink("currentLyric") currentLyric: string = "";
  @StorageLink("nextLyric") nextLyric: string = "";
  @StorageLink("lyricLines") lyricLines: LyricLine[] = [];
  @StorageLink("lyricIndex") lyricIndex: number = -1;
  @StorageLink("isLoading") isLoading: boolean = false;
  @StorageLink("loadError") loadError: string = "";
  @State private lyricProgress: number = 0;
  @State private dragStart: number = 0;
  private lyricScroller: Scroller = new Scroller();
  private pageController: SwiperController = new SwiperController();

  @Builder
  controlButton(icon: Resource, size: number, action: () => void) {
    SymbolGlyph(icon)
      .fontSize(size)
      .fontColor([Color.White])
      .width(64)
      .height(64)
      .onClick(action)
  }

  formatTime(ms: number): string {
    const total: number = Math.floor(ms / 1000);
    const minute: number = Math.floor(total / 60);
    const second: number = total % 60;
    return minute.toString().padStart(2, "0") + ":" + second.toString().padStart(2, "0");
  }

  build() {
    Stack() {
      // 背景：封面模糊
      if (this.currentMusic !== undefined) {
        RemoteImage({
          url: MusicService.coverURL(this.currentMusic),
          cornerRadius: 0
        })
          .width("100%")
          .height("100%")
          .blur(60)
          .opacity(0.55)
      }

      Column() {
        // 顶部返回
        Row() {
          Text("⌄")
            .fontSize(30)
            .fontColor("#FFFFFF")
            .onClick(() => {
              router.back();
            })
          Blank()
          Text("正在播放")
            .fontSize(14)
            .fontColor("#DDDDDD")
          Blank()
          Text("词")
            .fontSize(16)
            .fontWeight(this.lyricProgress > 0.5 ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.lyricProgress > 0.5 ? "#FFFFFF" : "#DDDDDD")
            .padding({ left: 14, right: 14 })
            .onClick(() => {
              if (this.lyricProgress > 0.5) {
                this.pageController.showPrevious();
              } else {
                this.pageController.showNext();
              }
            })
          Blank()
          Text("更多")
            .fontSize(14)
            .fontColor("#DDDDDD")
        }
        .width("100%")
        .padding({ left: 20, right: 20, top: 12, bottom: 12 })
        .systemMaterial(MaterialService.header())

        Blank().height(12)

        // 封面
        // 封面 / 歌词 两页（Swiper 左右滑动，固定高度防跳动）
        Swiper(this.pageController) {
          // 页 1：封面
          Column() {
            if (this.currentMusic !== undefined) {
              RemoteImage({
                url: MusicService.coverURL(this.currentMusic),
                cornerRadius: 24
              })
                .width(260)
                .height(260)
                .shadow({ radius: 30, color: "#66000000", offsetY: 10 })
            }
          }
          .width("100%")
          .height(260)
          .justifyContent(FlexAlign.Center)

          // 页 2：歌词
          List({ scroller: this.lyricScroller }) {
            ForEach(this.lyricLines, (line: LyricLine, index: number) => {
              ListItem() {
                Text(line.text)
                  .fontSize(index === this.lyricIndex ? 20 : 15)
                  .fontWeight(index === this.lyricIndex ? FontWeight.Bold : FontWeight.Normal)
                  .fontColor(index === this.lyricIndex ? "#FFFFFF" : "#88FFFFFF")
                  .textAlign(TextAlign.Center)
                  .width("100%")
                  .padding({ top: 9, bottom: 9 })
                  .onClick(() => {
                    AudioPlayerService.shared().seek(line.time);
                  })
              }
            }, (line: LyricLine, index: number) => index.toString())
          }
          .width("100%")
          .height(260)
          .scrollBar(BarState.Off)
        }
        .width("100%")
        .height(260)
        .indicator(false)
        .loop(false)
        .onChange((index: number) => {
          this.lyricProgress = index;
        })

        Blank().height(24)

        // 歌名 / 歌手
        Text(this.currentMusic?.title ?? "未在播放")
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor("#FFFFFF")
          .maxLines(1)

        Text(this.currentMusic?.artist ?? "")
          .fontSize(14)
          .fontColor("#CCCCCC")
          .margin({ top: 6 })
          .maxLines(1)

        Blank().height(12)

        // 封面页只预览一行当前歌词
        Text(this.currentLyric.length > 0 ? this.currentLyric : " ")
          .fontSize(15)
          .fontColor("#CCFFFFFF")
          .maxLines(1)
          .textAlign(TextAlign.Center)
          .width("80%")
          .margin({ top: 10 })

        if (this.loadError.length > 0) {
          Text(this.loadError)
            .fontSize(12)
            .fontColor("#FF9999")
            .margin({ top: 4 })
        }

        Blank().height(12)

        // 进度
        Slider({
          value: this.playbackPosition,
          min: 0,
          max: this.duration > 0 ? this.duration : 1,
          style: SliderStyle.OutSet
        })
          .width("85%")
          .selectedColor("#FFFFFF")
          .trackColor("#55FFFFFF")
          .blockColor("#FFFFFF")
          .onChange((value: number) => {
            AudioPlayerService.shared().seek(value);
          })

        Row() {
          Text(this.formatTime(this.playbackPosition))
            .fontSize(12)
            .fontColor("#CCCCCC")
          Blank()
          Text(this.formatTime(this.duration))
            .fontSize(12)
            .fontColor("#CCCCCC")
        }
        .width("85%")
        .margin({ top: 4 })

        Blank().height(8)

        // 控制
        Row() {
          this.controlButton($r("sys.symbol.repeat"), 22, () => {})
          this.controlButton($r("sys.symbol.backward_end_fill"), 26, () => {
            AudioPlayerService.shared().previous();
          })
          PlayToggleButton({
            playing: this.playingSync,
            onToggle: () => {
              togglePlay().then((playing: boolean) => {
                this.playingSync = playing;
              });
            }
          })
          this.controlButton($r("sys.symbol.forward_end_fill"), 26, () => {
            AudioPlayerService.shared().next();
          })
          FavoriteButton({
            favorited: this.favorited,
            onToggle: () => {
              this.toggleFavorite();
            }
          })
        }
        .width("85%")
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ top: 8 })
      }
      .width("100%")
      .height("100%")
      .backgroundColor("#33000000")
    }
    .width("100%")
    .height("100%")
    .backgroundColor("#1A1A1A")
  }

  async toggleFavorite(): Promise<void> {
    const music = this.currentMusic;
    if (music === undefined) {
      return;
    }
    if (!AuthService.isLoggedIn()) {
      this.toast = "请先登录";
      return;
    }
    try {
      const next: boolean = await FavoriteService.toggle(music.id);
      this.favorited = next;
      this.toast = next ? "已收藏" : "已取消收藏";
    } catch (error) {
      const err = error as Error;
      this.toast = err.message;
    }
  }

  aboutToAppear(): void {
    this.autoScrollLyric();
    this.favorited = FavoriteService.isFavorite(this.currentMusic?.id ?? -1);
    // @StorageLink 对 AVPlayer 回调线程的更新不敏感，这里轮询同步
    setInterval(() => {
      const currentId: number = this.currentMusic?.id ?? -1;
      const isFav: boolean = this.favoriteIds.indexOf(currentId) >= 0;
      if (isFav !== this.favorited) {
        this.favorited = isFav;
      }
      const value: boolean = currentPlayerState() === "playing";
      if (value !== this.playingSync) {
        this.playingSync = value;
        hilog.info(0x0000, "NekoPlayer", "playingSync -> %{public}s", value ? "true" : "false");
      }
    }, 400);
  }

  private autoScrollLyric(): void {
    setInterval(() => {
      if (this.lyricProgress > 0.5 && this.lyricIndex >= 0) {
        this.lyricScroller.scrollToIndex(this.lyricIndex, true, ScrollAlign.CENTER);
      }
    }, 800);
  }
}
