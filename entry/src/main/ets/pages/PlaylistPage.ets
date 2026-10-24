import { MusicItem } from '../models/Music';
import { PlaylistService } from '../services/PlaylistService';
import { AudioPlayerService } from '../services/AudioPlayerService';
import { MusicService } from '../services/MusicService';
import { RemoteImage } from '../components/RemoteImage';
import { router } from '@kit.ArkUI';

@Entry
@Component
struct PlaylistPage {
  @State songs: MusicItem[] = [];
  @State title: string = '歌单';
  @State loading: boolean = true;
  private playlistId: number = 0;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object> | undefined;
    if (params !== undefined) {
      const idValue = params.playlistId;
      const nameValue = params.name;
      if (typeof idValue === 'number') {
        this.playlistId = idValue;
      }
      if (typeof nameValue === 'string') {
        this.title = nameValue;
      }
    }
    this.loadSongs();
  }

  async loadSongs(): Promise<void> {
    this.loading = true;
    try {
      const list: MusicItem[] = await PlaylistService.music(this.playlistId);
      this.songs = list;
    } catch (error) {
      this.songs = [];
    } finally {
      this.loading = false;
    }
  }

  private play(item: MusicItem): void {
    let index: number = 0;
    for (let i: number = 0; i < this.songs.length; i++) {
      if (this.songs[i].id === item.id) {
        index = i;
        break;
      }
    }
    AudioPlayerService.shared().setPlaylist(this.songs, index);
    router.pushUrl({ url: 'pages/PlayerPage' });
  }

  pageTransition() {
    PageTransitionEnter({ duration: 260, curve: Curve.FastOutSlowIn })
      .slide(SlideEffect.Right)
    PageTransitionExit({ duration: 220, curve: Curve.EaseIn })
      .slide(SlideEffect.Right)
  }

  build() {
    Column() {
      // 顶栏
      Row({ space: 12 }) {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(22)
          .fontColor(['#1A1A1A'])
          .onClick(() => {
            router.back();
          })
        Text(this.title)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
          .layoutWeight(1)
          .maxLines(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 56, bottom: 12 })

      if (this.loading) {
        Column() {
          LoadingProgress().width(36).height(36)
        }
        .width('100%')
        .height(200)
        .justifyContent(FlexAlign.Center)
      } else if (this.songs.length === 0) {
        Column() {
          Text('歌单还是空的').fontSize(14).fontColor('#999999')
        }
        .width('100%')
        .height(200)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 4 }) {
          ForEach(this.songs, (item: MusicItem) => {
            ListItem() {
              Row({ space: 12 }) {
                RemoteImage({ url: MusicService.coverURL(item), cornerRadius: 14 })
                  .width(56)
                  .height(56)
                Column({ space: 4 }) {
                  Text(item.title)
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#1A1A1A')
                    .maxLines(1)
                  Text(item.artist)
                    .fontSize(12)
                    .fontColor('#999999')
                    .maxLines(1)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
              }
              .width('100%')
              .padding({ left: 10, right: 10, top: 8, bottom: 8 })
              .backgroundColor("#FFFFFF")
              .borderRadius(16)
              .onClick(() => {
                this.play(item);
              })
            }
          }, (item: MusicItem) => item.id.toString())
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F8')
  }
}
