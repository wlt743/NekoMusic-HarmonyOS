import { AuthService, NekoUser } from '../services/AuthService';
import { WallpaperService } from '../services/WallpaperService';
import { RemoteImage } from '../components/RemoteImage';
import { HttpClient } from '../services/HttpClient';
import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

@Entry
@Component
struct SettingsPage {
  @StorageLink('authToken') authToken: string = '';
  @StorageLink('authUser') authUser: NekoUser | undefined = undefined;
  @StorageLink('wallpaperUri') wallpaperUri: string = '';
  @State private nickname: string = '';
  @State private saving: boolean = false;
  @State private message: string = '';

  aboutToAppear(): void {
    this.nickname = this.authUser?.nickname ?? '';
  }

  private avatarUrl(): string {
    const user = this.authUser;
    if (user === undefined) {
      return '';
    }
    return 'https://music.nekocore.cn/api/user/avatar/' + user.id;
  }

  async saveNickname(): Promise<void> {
    const name = this.nickname.trim();
    if (name.length === 0) {
      this.message = '昵称不能为空';
      return;
    }
    this.saving = true;
    this.message = '';
    try {
      const body: string = JSON.stringify({ nickname: name });
      await HttpClient.post('https://music.nekocore.cn/api/user/nickname/change', body, this.authToken);
      const user = this.authUser;
      if (user !== undefined) {
        const updated: NekoUser = {
          id: user.id,
          email: user.email,
          nickname: name
        };
        AppStorage.set<NekoUser>('authUser', updated);
      }
      this.message = '昵称已更新';
    } catch (error) {
      const err = error as Error;
      this.message = err.message;
    } finally {
      this.saving = false;
    }
  }

  async pickWallpaper(): Promise<void> {
    try {
      const uri: string = await WallpaperService.pick();
      this.message = uri.length > 0 ? '壁纸已更新' : '';
    } catch (error) {
      const err = error as Error;
      this.message = '选择壁纸失败: ' + err.message;
    }
  }

  async clearWallpaper(): Promise<void> {
    await WallpaperService.clear();
    this.message = '壁纸已清除';
  }

  async logout(): Promise<void> {
    await AuthService.logout();
    router.back();
  }

  @Builder
  row(title: string, subtitle: string, action: () => void) {
    Row() {
      Column({ space: 4 }) {
        Text(title).fontSize(16).fontColor('#1A1A1A')
        if (subtitle.length > 0) {
          Text(subtitle).fontSize(12).fontColor('#999999')
        }
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
    .onClick(action)
  }

  build() {
    Column() {
      // 顶栏
      Row({ space: 12 }) {
        Stack() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(20)
            .fontColor(['#1A1A1A'])
        }
        .width(40)
        .height(40)
        .onClick(() => {
          router.back();
        })

        Text('设置')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 56, bottom: 12 })

      Scroll() {
        Column({ space: 14 }) {
          // 头像
          Column({ space: 10 }) {
            if (this.avatarUrl().length > 0) {
              RemoteImage({ url: this.avatarUrl(), cornerRadius: 40 })
                .width(80)
                .height(80)
            } else {
              Stack() {
                Text((this.authUser?.nickname ?? 'N').substring(0, 1).toUpperCase())
                  .fontSize(30)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#FFFFFF')
              }
              .width(80)
              .height(80)
              .borderRadius(40)
              .backgroundColor('#E5484D')
            }

            Text(this.authUser?.email ?? '')
              .fontSize(12)
              .fontColor('#999999')
          }
          .width('100%')
          .padding(20)
          .backgroundColor('#FFFFFF')
          .borderRadius(22)
          .shadow({ radius: 18, color: '#0F000000', offsetY: 6 })

          // 昵称
          Column({ space: 10 }) {
            Text('昵称')
              .fontSize(13)
              .fontColor('#999999')
              .width('100%')
            TextInput({ placeholder: '输入昵称', text: this.nickname })
              .height(46)
              .borderRadius(14)
              .onChange((value: string) => {
                this.nickname = value;
              })
            Button(this.saving ? '保存中…' : '保存昵称')
              .width('100%')
              .height(46)
              .borderRadius(23)
              .backgroundColor('#E5484D')
              .enabled(!this.saving)
              .onClick(() => {
                this.saveNickname();
              })
          }
          .width('100%')
          .padding(20)
          .backgroundColor('#FFFFFF')
          .borderRadius(22)
          .shadow({ radius: 18, color: '#0F000000', offsetY: 6 })
          .alignItems(HorizontalAlign.Start)

          // 个性化
          Column() {
            Text('个性化')
              .fontSize(13)
              .fontColor('#999999')
              .width('100%')
              .padding({ left: 4, bottom: 8 })
            Column({ space: 1 }) {
              this.row('更换壁纸', this.wallpaperUri.length > 0 ? '已设置' : '未设置', () => {
                this.pickWallpaper();
              })
              this.row('清除壁纸', '恢复纯色背景', () => {
                this.clearWallpaper();
              })
            }
            .borderRadius(22)
            .clip(true)
            .shadow({ radius: 18, color: '#0F000000', offsetY: 6 })
          }
          .width('100%')

          // 退出
          Column() {
            this.row('退出登录', '', () => {
              this.logout();
            })
          }
          .borderRadius(22)
          .clip(true)
          .shadow({ radius: 18, color: '#0F000000', offsetY: 6 })

          if (this.message.length > 0) {
            Text(this.message)
              .fontSize(12)
              .fontColor('#999999')
          }
        }
        .padding({ left: 16, right: 16, bottom: 40 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F8')
  }
}
