import { MusicItem } from '../models/Music';
import { FavoriteService } from '../services/FavoriteService';
import { AudioPlayerService } from '../services/AudioPlayerService';
import { MusicService } from '../services/MusicService';
import { RemoteImage } from '../components/RemoteImage';
import { MaterialService } from '../services/MaterialService';
import { router } from '@kit.ArkUI';
import { AuthService } from '../services/AuthService';
import { PlaylistService, PlaylistInfo } from '../services/PlaylistService';

@Component
export struct LibraryPage {
  @StorageLink('favoriteList') favorites: MusicItem[] = [];
  @StorageLink('authToken') authToken: string = '';
  @StorageLink('myPlaylists') playlists: PlaylistInfo[] = [];
  @State toast: string = '';

  aboutToAppear(): void {
    if (AuthService.isLoggedIn()) {
      FavoriteService.refresh().catch(() => {});
      PlaylistService.refresh().catch(() => {});
    }
  }

  async createPlaylist(): Promise<void> {
    try {
      const name: string = '我的歌单 ' + (this.playlists.length + 1);
      await PlaylistService.create(name, '');
      this.toast = '歌单已创建';
    } catch (error) {
      const err = error as Error;
      this.toast = err.message;
    }
  }

  private openPlayer(item: MusicItem): void {
    let index: number = 0;
    for (let i: number = 0; i < this.favorites.length; i++) {
      if (this.favorites[i].id === item.id) {
        index = i;
        break;
      }
    }
    AudioPlayerService.shared().setPlaylist(this.favorites, index);
    router.pushUrl({ url: 'pages/PlayerPage' });
  }

  @Builder
  songRow(item: MusicItem) {
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
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(item.artist)
          .fontSize(12)
          .fontColor('#999999')
          .maxLines(1)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      SymbolGlyph($r('sys.symbol.play_fill'))
        .fontSize(18)
        .fontColor(['#C7C7CC'])
    }
    .width('100%')
    .padding({ left: 10, right: 10, top: 8, bottom: 8 })
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .onClick(() => {
      this.openPlayer(item);
    })
  }

  build() {
    Column() {
      Row() {
        Text('音乐库')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 56, bottom: 8 })
      .systemMaterial(MaterialService.header())

      if (this.authToken.length === 0) {
        Column({ space: 8 }) {
          Text('登录后可查看收藏').fontSize(14).fontColor('#999999')
        }
        .width('100%')
        .height(200)
        .justifyContent(FlexAlign.Center)
      } else {
        // 我的歌单（始终显示）
        Row() {
          Text('我的歌单 (' + this.playlists.length + ')')
            .fontSize(13)
            .fontColor('#999999')
            .layoutWeight(1)
          Text('+ 新建')
            .fontSize(13)
            .fontColor('#E5484D')
            .onClick(() => {
              this.createPlaylist();
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 4 })

        ForEach(this.playlists, (item: PlaylistInfo) => {
          Row({ space: 12 }) {
            Column({ space: 4 }) {
              Text(item.name)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor('#1A1A1A')
                .maxLines(1)
              Text((item.musicCount ?? 0) + ' 首')
                .fontSize(12)
                .fontColor('#999999')
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(16)
              .fontColor(['#C7C7CC'])
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 14, bottom: 14 })
          .backgroundColor('#FFFFFF')
          .onClick(() => {
            router.pushUrl({ url: 'pages/PlaylistPage', params: { playlistId: item.id, name: item.name } });
          })
        }, (item: PlaylistInfo) => item.id.toString())

        Blank().height(12)

        Text('我喜欢的音乐 (' + this.favorites.length + ')')
          .fontSize(13)
          .fontColor('#999999')
          .width('100%')
          .padding({ left: 16, top: 8, bottom: 4 })

        if (this.favorites.length === 0) {
          Column() {
            Text('还没有收藏歌曲').fontSize(14).fontColor('#999999')
          }
          .width('100%')
          .height(120)
          .justifyContent(FlexAlign.Center)
        } else {
          List({ space: 4 }) {
            ForEach(this.favorites, (item: MusicItem) => {
              ListItem() {
                this.songRow(item)
              }
            }, (item: MusicItem) => item.id.toString())
          }
          .width('100%')
          .layoutWeight(1)
          .padding({ left: 16, right: 16 })
          .divider({ strokeWidth: 0.5, color: '#EEEEEE', startMargin: 68, endMargin: 0 })
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F8')
  }
}
