import { MusicItem } from '../models/Music';
import { MusicService } from '../services/MusicService';
import { AudioPlayerService } from '../services/AudioPlayerService';
import { togglePlay, currentPlayerState } from '../services/PlayerCore';
import { RemoteImage } from '../components/RemoteImage';
import { MaterialService } from '../services/MaterialService';
import { router } from '@kit.ArkUI';

/** 底部悬浮迷你播放条（沉浸光感材质） */
@Component
export struct MiniPlayer {
  @StorageLink('currentMusic') currentMusic: MusicItem | undefined = undefined;
  @StorageLink('position') playbackPosition: number = 0;
  @StorageLink('duration') duration: number = 0;
  @State private playing: boolean = false;
  @State private dragging: boolean = false;
  @State private dragValue: number = 0;

  aboutToAppear(): void {
    setInterval(() => {
      const value: boolean = currentPlayerState() === 'playing';
      if (value !== this.playing) {
        this.playing = value;
      }
    }, 400);
  }

  build() {
    if (this.currentMusic !== undefined) {
      Column() {
        Row({ space: 8 }) {
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
              .fontColor('#666666')
              .maxLines(1)
              .width('100%')
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Stack() {
            SymbolGlyph($r('sys.symbol.backward_end_fill'))
              .fontSize(20)
              .fontColor(['#1A1A1A'])
          }
          .width(38)
          .height(38)
          .onClick(() => {
            AudioPlayerService.shared().previous();
          })

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
          .width(38)
          .height(38)
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
          .width(38)
          .height(38)
          .onClick(() => {
            AudioPlayerService.shared().next();
          })
        }
        .width('100%')
        .padding({ left: 10, right: 6, top: 8, bottom: 2 })

        Slider({
          value: this.dragging ? this.dragValue : (this.duration > 0 ? this.playbackPosition : 0),
          min: 0,
          max: this.duration > 0 ? this.duration : 1,
          style: SliderStyle.OutSet
        })
          .width('100%')
          .trackThickness(2.5)
          .blockSize({ width: 10, height: 10 })
          .trackColor('#33000000')
          .selectedColor('#E5484D')
          .blockColor('#E5484D')
          .onChange((value: number, mode: SliderChangeMode) => {
            if (mode === SliderChangeMode.Begin || mode === SliderChangeMode.Moving) {
              this.dragging = true;
              this.dragValue = value;
            } else if (mode === SliderChangeMode.End) {
              AudioPlayerService.shared().seek(value);
              this.dragging = false;
            }
          })
          .margin({ bottom: 2 })
      }
      .width('100%')
      .borderRadius(24)
      .clip(true)
      .backgroundColor('#E8FFFFFF')
      .systemMaterial(MaterialService.header())
      .shadow({ radius: 24, color: '#26000000', offsetY: 8 })
      .onClick(() => {
        router.pushUrl({ url: 'pages/PlayerPage' });
      })
    }
  }
}
