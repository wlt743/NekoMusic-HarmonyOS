import { MusicItem } from '../models/Music';
import { MusicService } from '../services/MusicService';
import { AudioPlayerService } from '../services/AudioPlayerService';
import { togglePlay, currentPlayerState } from '../services/PlayerCore';
import { RemoteImage } from '../components/RemoteImage';
import { router } from '@kit.ArkUI';

/** 底部悬浮迷你播放条 */
@Component
export struct MiniPlayer {
  @StorageLink('currentMusic') currentMusic: MusicItem | undefined = undefined;
  @StorageLink('position') playbackPosition: number = 0;
  @StorageLink('duration') duration: number = 0;
  @State private playing: boolean = false;

  aboutToAppear(): void {
    setInterval(() => {
      const value: boolean = currentPlayerState() === 'playing';
      if (value !== this.playing) {
        this.playing = value;
      }
    }, 400);
  }

  private progress(): number {
    if (this.duration <= 0) {
      return 0;
    }
    return this.playbackPosition / this.duration;
  }

  build() {
    if (this.currentMusic !== undefined) {
      Column() {
        Row() {
          Row()
            .height(2.5)
            .width(Math.max(this.progress() * 100, 0) + '%')
            .backgroundColor('#E5484D')
            .borderRadius(2)
        }
        .width('100%')
        .height(2.5)
        .backgroundColor('#22000000')
        .borderRadius(2)

        Row({ space: 10 }) {
          RemoteImage({ url: MusicService.coverURL(this.currentMusic), cornerRadius: 10 })
            .width(42)
            .height(42)

          Column({ space: 2 }) {
            Text(this.currentMusic.title)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#1A1A1A')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
            Text(this.currentMusic.artist)
              .fontSize(11)
              .fontColor('#999999')
              .maxLines(1)
              .width('100%')
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Stack() {
            if (this.playing) {
              SymbolGlyph($r('sys.symbol.pause_fill'))
                .fontSize(22)
                .fontColor(['#1A1A1A'])
            } else {
              SymbolGlyph($r('sys.symbol.play_fill'))
                .fontSize(22)
                .fontColor(['#1A1A1A'])
            }
          }
          .width(40)
          .height(40)
          .onClick(() => {
            togglePlay().then((playing: boolean) => {
              this.playing = playing;
            });
          })

          Stack() {
            SymbolGlyph($r('sys.symbol.forward_end_fill'))
              .fontSize(20)
              .fontColor(['#1A1A1A'])
          }
          .width(40)
          .height(40)
          .onClick(() => {
            AudioPlayerService.shared().next();
          })
        }
        .width('100%')
        .padding({ left: 10, right: 8, top: 8, bottom: 8 })
      }
      .width('100%')
      .backgroundColor('#F5FFFFFF')
      .borderRadius(24)
      .clip(true)
      .shadow({ radius: 24, color: '#26000000', offsetY: 8 })
      .onClick(() => {
        router.pushUrl({ url: 'pages/PlayerPage' });
      })
    }
  }
}
