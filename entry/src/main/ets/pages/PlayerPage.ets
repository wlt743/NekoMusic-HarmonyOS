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
import { AddToPlaylistButton } from '../components/AddToPlaylistButton';
import { FavoriteService } from "../services/FavoriteService";
import { AuthService } from "../services/AuthService";
import { LyricLine } from "../services/LyricsParser";
import { AudioPlayerService as Player } from "../services/AudioPlayerService";
import { PlaylistService, PlaylistInfo } from '../services/PlaylistService';
import { promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { display } from '@kit.ArkUI';

@Entry
@Component
struct PlayerPage {
  @StorageLink("currentMusic") currentMusic: MusicItem | undefined = undefined;
  @StorageLink("isPlaying") isPlaying: boolean = false;
  @State playingSync: boolean = false;
  @StorageLink("favoriteIds") favoriteIds: number[] = [];
  @State private favorited: boolean = false;
  @State private toast: string = "";
  @State showPlaylistSheet: boolean = false;
  @StorageLink('myPlaylists') playlists: PlaylistInfo[] = [];
  @StorageLink("position") playbackPosition: number = 0;
  @StorageLink("duration") duration: number = 0;
  @StorageLink("currentLyric") currentLyric: string = "";
  @StorageLink("nextLyric") nextLyric: string = "";
  @StorageLink("lyricLines") lyricLines: LyricLine[] = [];
  @StorageLink("lyricIndex") lyricIndex: number = -1;
  @StorageLink("isLoading") isLoading: boolean = false;
  @StorageLink("loadError") loadError: string = "";
  @State private lyricProgress: number = 0;
  @State private isWide: boolean = false;
  @State private isCompactWide: boolean = false;
  @State private isFolded: boolean = false;
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

  pageTransition() {
    PageTransitionEnter({ duration: 280, curve: Curve.FastOutSlowIn })
      .slide(SlideEffect.Bottom)
    PageTransitionExit({ duration: 240, curve: Curve.EaseIn })
      .slide(SlideEffect.Bottom)
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
        // 顶部栏：圆形返回 + 右侧胶囊（词 / 更多）
        Row() {
          Stack() {
            SymbolGlyph($r('sys.symbol.chevron_left'))
              .fontSize(20)
              .fontColor([Color.White])
          }
          .width(40)
          .height(40)
          .backgroundColor('#33FFFFFF')
          .borderRadius(20)
          .onClick(() => {
            router.back();
          })

          Blank()

          Row() {
            // 评论
            Stack() {
              Text('评')
                .fontSize(14)
                .fontColor('#DDDDDD')
            }
            .width(44)
            .height(38)
            .onClick(() => {
              const music = this.currentMusic;
              router.pushUrl({
                url: 'pages/CommentsPage',
                params: { musicId: music?.id ?? 0, title: music?.title ?? '' }
              });
            })

            Text('词')
              .fontSize(15)
              .fontWeight(this.lyricProgress > 0.5 ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(this.lyricProgress > 0.5 ? '#FFFFFF' : '#DDDDDD')
              .padding({ left: 18, right: 18, top: 10, bottom: 10 })
              .onClick(() => {
                if (this.lyricProgress > 0.5) {
                  this.pageController.showPrevious();
                } else {
                  this.pageController.showNext();
                }
              })

            Text('···')
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor('#DDDDDD')
              .padding({ left: 16, right: 16, top: 10, bottom: 10 })
              .onClick(() => {
                this.showPlaylistSheet = true;
              })
          }
          .backgroundColor('#33FFFFFF')
          .borderRadius(22)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 56, bottom: 12 })

        Blank().height(12)

        // 封面
        // 封面 / 歌词 两页（Swiper 左右滑动，固定高度防跳动）
        // 宽屏：左封面右歌词；竖屏：滑动切页
        if (this.isWide) {
          Row({ space: 24 }) {
            Column() {
              if (this.currentMusic !== undefined) {
                RemoteImage({
                  url: MusicService.coverURL(this.currentMusic),
                  cornerRadius: 28
                })
                  .width(this.isCompactWide ? 150 : 210)
                  .height(this.isCompactWide ? 150 : 210)
                  .shadow({ radius: 44, color: "#4D000000", offsetY: 16 })
              }

              // 紧凑模式：歌名/歌手/进度/控制全收进左栏
              if (this.isCompactWide) {
                Text(this.currentMusic?.title ?? "")
                  .fontSize(17)
                  .fontWeight(FontWeight.Bold)
                  .fontColor("#FFFFFF")
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width("100%")
                  .textAlign(TextAlign.Center)

                Text(this.currentMusic?.artist ?? "")
                  .fontSize(12)
                  .fontColor("#CCCCCC")
                  .maxLines(1)
                  .width("100%")
                  .textAlign(TextAlign.Center)

                Row() {
                  Text(this.formatTime(this.playbackPosition))
                    .fontSize(9)
                    .fontColor("#AAAAAA")
                  Slider({
                    value: this.playbackPosition,
                    min: 0,
                    max: this.duration > 0 ? this.duration : 1,
                    style: SliderStyle.OutSet
                  })
                    .layoutWeight(1)
                    .trackThickness(2)
                    .blockSize({ width: 7, height: 7 })
                    .trackColor("#55FFFFFF")
                    .selectedColor("#FFFFFF")
                    .blockColor("#FFFFFF")
                    .onChange((value: number, mode: SliderChangeMode) => {
                      if (mode === SliderChangeMode.End) {
                        AudioPlayerService.shared().seek(value);
                      }
                    })
                  Text(this.formatTime(this.duration))
                    .fontSize(9)
                    .fontColor("#AAAAAA")
                }
                .width("100%")

                Row({ space: 16 }) {
                  SymbolGlyph($r("sys.symbol.backward_end_fill"))
                    .fontSize(18)
                    .fontColor(["#FFFFFF"])
                    .onClick(() => {
                      AudioPlayerService.shared().previous();
                    })
                  SymbolGlyph(this.playingSync ? $r("sys.symbol.pause_fill") : $r("sys.symbol.play_fill"))
                    .fontSize(28)
                    .fontColor([Color.White])
                    .onClick(() => {
                      togglePlay().then((playing: boolean) => {
                        this.playingSync = playing;
                      });
                    })
                  SymbolGlyph($r("sys.symbol.forward_end_fill"))
                    .fontSize(18)
                    .fontColor(["#FFFFFF"])
                    .onClick(() => {
                      AudioPlayerService.shared().next();
                    })
                  SymbolGlyph($r("sys.symbol.heart"))
                    .fontSize(18)
                    .fontColor([this.favorited ? "#E5484D" : "#FFFFFF"])
                    .onClick(() => {
                      this.toggleFavorite();
                    })
                }
                .justifyContent(FlexAlign.Center)
                .width("100%")
              }
            }
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)

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
            .layoutWeight(1)
            .height(this.isCompactWide ? 200 : 240)
            .scrollBar(BarState.Off)
          }
          .width("100%")
          .height(this.isCompactWide ? 200 : 240)
        } else {
          Swiper(this.pageController) {
            // 页 1：封面
            Column() {
              if (this.currentMusic !== undefined) {
                RemoteImage({
                  url: MusicService.coverURL(this.currentMusic),
                  cornerRadius: 28
                })
                  .width(276)
                  .height(276)
                  .shadow({ radius: 44, color: "#4D000000", offsetY: 16 })
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
        }

        Blank().height(this.isWide ? 8 : 24)

        // 歌名 / 歌手（紧凑横屏时已在左栏内）
        if (!this.isCompactWide) {
        Row({ space: 12 }) {
          Text(this.currentMusic?.title ?? "未在播放")
            .fontSize(this.isWide ? 20 : 26)
            .fontWeight(FontWeight.Bold)
            .fontColor("#FFFFFF")
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .constraintSize({ maxWidth: "76%" })

          Stack() {
            SymbolGlyph($r('sys.symbol.share'))
              .fontSize(20)
              .fontColor([Color.White])
          }
          .width(36)
          .height(36)
          .onClick(() => {
            this.shareSong();
          })
        }
        .justifyContent(FlexAlign.Center)
        .width("100%")

        Text(this.currentMusic?.artist ?? "")
          .fontSize(15)
          .fontColor("#CCCCCC")
          .margin({ top: 6 })
          .maxLines(1)

        Blank().height(12)

        // 封面页只预览一行当前歌词（宽屏时右栏已有歌词，隐藏）
        if (!this.isWide) {
          Text(this.currentLyric.length > 0 ? this.currentLyric
            : (this.currentMusic?.artist ?? ""))
          .fontSize(15)
          .fontColor("#CCFFFFFF")
          .maxLines(1)
          .textAlign(TextAlign.Center)
            .width("80%")
            .margin({ top: 10 })
        }

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
        .width("78%")
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ top: 8 })
        }

      }
      .width("100%")
      .height("100%")
      .backgroundColor("#33000000")
      .onAreaChange((oldValue: Area, newValue: Area) => {
        const w: number = Number(newValue.width);
        const h: number = Number(newValue.height);
        const wide: boolean = w > h * 1.2;
        if (wide !== this.isWide) {
          this.isWide = wide;
        }
        this.updateFoldState();
      })
    }
    .width("100%")
    .height("100%")
    .backgroundColor("#1A1A1A")
    .bindSheet($$this.showPlaylistSheet, this.playlistSheet(), {
      height: 360,
      dragBar: true
    })
  }

  @Builder
  playlistMenu() {
    Menu() {
      if (this.playlists.length === 0) {
        MenuItem({ content: '还没有歌单，去音乐库新建' })
      } else {
        ForEach(this.playlists, (item: PlaylistInfo) => {
          MenuItem({ content: item.name })
            .onClick(() => {
              this.addToPlaylist(item.id);
            })
        }, (item: PlaylistInfo) => item.id.toString())
      }
    }
  }

  async addToPlaylist(playlistId: number): Promise<void> {
    const music = this.currentMusic;
    if (music === undefined) {
      return;
    }
    try {
      await PlaylistService.addMusic(playlistId, music.id);
      this.toast = '已添加到歌单';
    } catch (error) {
      const err = error as Error;
      this.toast = err.message;
    }
  }

  showMoreMenu(): void {
    if (this.playlists.length === 0) {
      this.toast = '先去音乐库新建歌单';
      return;
    }
    this.addToPlaylist(this.playlists[0].id);
  }

  /** 分享：把歌曲信息复制到剪贴板 */
  shareSong(): void {
    const music = this.currentMusic;
    if (music === undefined) {
      return;
    }
    const text: string = music.title + ' - ' + music.artist + '\n' + 'https://music.nekocore.cn/music/' + music.id;
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      pasteboard.getSystemPasteboard().setData(data);
      this.toast = '分享文案已复制';
    } catch (error) {
      this.toast = '复制失败';
    }
  }

  @Builder
  playlistSheet() {
    Column({ space: 4 }) {
      Text('添加到歌单')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1A1A1A')
        .width('100%')
        .padding({ left: 20, top: 8, bottom: 12 })

      if (this.playlists.length === 0) {
        Text('还没有歌单，先去音乐库新建')
          .fontSize(14)
          .fontColor('#999999')
          .width('100%')
          .padding({ left: 20, top: 12, bottom: 12 })
      } else {
        ForEach(this.playlists, (item: PlaylistInfo) => {
          Row({ space: 12 }) {
            SymbolGlyph($r('sys.symbol.music_note_list'))
              .fontSize(18)
              .fontColor(['#E5484D'])
            Text(item.name)
              .fontSize(15)
              .fontColor('#1A1A1A')
              .layoutWeight(1)
            Text((item.musicCount ?? 0) + ' 首')
              .fontSize(12)
              .fontColor('#999999')
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 14, bottom: 14 })
          .onClick(() => {
            this.showPlaylistSheet = false;
            this.addToPlaylist(item.id);
          })
        }, (item: PlaylistInfo) => item.id.toString())
      }
    }
    .width('100%')
    .padding({ bottom: 24 })
  }

  async toggleFavorite(): Promise<void> {
    hilog.info(0x0000, "NekoFav", "toggleFavorite called");
    const music = this.currentMusic;
    if (music === undefined) {
      hilog.info(0x0000, "NekoFav", "no current music");
      return;
    }
    if (!AuthService.isLoggedIn()) {
      this.toast = "请先登录";
      return;
    }
    try {
      hilog.info(0x0000, "NekoFav", "calling api musicId=%{public}d", music.id);
      const next: boolean = await FavoriteService.toggle(music.id);
      this.favorited = next;
      this.toast = next ? "已收藏" : "已取消收藏";
    } catch (error) {
      const err = error as Error;
      this.toast = err.message;
    }
  }

  /** 读取设备折叠状态：折叠合上时用紧凑布局 */
  private updateFoldState(): void {
    try {
      const status: display.FoldStatus = display.getFoldStatus();
      const folded: boolean = status === display.FoldStatus.FOLD_STATUS_FOLDED;
      if (folded !== this.isFolded) {
        this.isFolded = folded;
      }
      const compact: boolean = this.isWide && folded;
      if (compact !== this.isCompactWide) {
        this.isCompactWide = compact;
      }
    } catch (error) {
      this.isFolded = false;
      this.isCompactWide = false;
    }
  }

  aboutToAppear(): void {
    this.autoScrollLyric();
    this.favorited = FavoriteService.isFavorite(this.currentMusic?.id ?? -1);
    if (AuthService.isLoggedIn()) {
      PlaylistService.refresh().catch(() => {});
      FavoriteService.refresh().then(() => {
        this.favorited = FavoriteService.isFavorite(this.currentMusic?.id ?? -1);
      }).catch(() => {});
    }
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
