import { WallpaperService } from "../services/WallpaperService";
import { MaterialService } from "../services/MaterialService";
import { AuthService, NekoUser } from "../services/AuthService";
import { FavoriteService } from '../services/FavoriteService';
import { RemoteImage } from '../components/RemoteImage';
import { router } from '@kit.ArkUI';

@Component
export struct ProfilePage {
  @StorageLink("wallpaperUri") wallpaperUri: string = "";
  @StorageLink('unreadCount') unreadCount: number = 0;
  @StorageLink("authToken") authToken: string = "";
  @StorageLink("authUser") authUser: NekoUser | undefined = undefined;
  @State email: string = "";
  @State password: string = "";
  @State loggingIn: boolean = false;
  @State message: string = "";

  /** 头像地址：NekoMusic 账号头像接口 */
  private avatarUrl(): string {
    const user = this.authUser;
    if (user === undefined) {
      return "";
    }
    return "https://music.nekocore.cn/api/user/avatar/" + user.id;
  }

  async doLogin(): Promise<void> {
    if (this.email.trim().length === 0 || this.password.length === 0) {
      this.message = "请输入邮箱和密码";
      return;
    }
    this.loggingIn = true;
    this.message = "";
    try {
      await AuthService.login(this.email.trim(), this.password);
      await FavoriteService.refresh();
      this.password = "";
      this.message = "登录成功";
    } catch (error) {
      const err = error as Error;
      this.message = err.message;
    } finally {
      this.loggingIn = false;
    }
  }

  async doLogout(): Promise<void> {
    await AuthService.logout();
    this.message = "已退出登录";
  }

  async pickWallpaper(): Promise<void> {
    try {
      const uri: string = await WallpaperService.pick();
      this.message = uri.length > 0 ? "壁纸已更新" : "";
    } catch (error) {
      const err = error as Error;
      this.message = "选择壁纸失败: " + err.message;
    }
  }

  async clearWallpaper(): Promise<void> {
    await WallpaperService.clear();
    this.message = "壁纸已清除";
  }

  @Builder
  settingRow(title: string, subtitle: string, action: () => void) {
    Row() {
      Column({ space: 4 }) {
        Text(title).fontSize(16).fontColor("#1A1A1A")
        Text(subtitle).fontSize(12).fontColor("#999999")
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      SymbolGlyph($r("sys.symbol.chevron_right"))
        .fontSize(16)
        .fontColor(["#C7C7CC"])
    }
    .width("100%")
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor("#FFFFFF")
    .onClick(action)
  }

  @Builder
  loginCard() {
    Column({ space: 12 }) {
      Text("登录 NekoMusic")
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor("#1A1A1A")
        .width("100%")

      TextInput({ placeholder: "邮箱", text: this.email })
        .type(InputType.Email)
        .height(46)
        .borderRadius(14)
        .onChange((value: string) => {
          this.email = value;
        })

      TextInput({ placeholder: "密码", text: this.password })
        .type(InputType.Password)
        .height(46)
        .borderRadius(14)
        .onChange((value: string) => {
          this.password = value;
        })

      Button(this.loggingIn ? "登录中…" : "登录")
        .width("100%")
        .height(46)
        .borderRadius(23)
        .backgroundColor("#E5484D")
        .enabled(!this.loggingIn)
        .onClick(() => {
          this.doLogin();
        })
    }
    .width("100%")
    .padding(20)
    .backgroundColor("#FFFFFF")
    .borderRadius(22)
    .shadow({ radius: 18, color: "#0F000000", offsetY: 6 })
    .onClick(() => {
      router.pushUrl({ url: "pages/SettingsPage" });
    })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  userCard() {
    Row({ space: 14 }) {
      // 头像：有 avatar 用图片，否则显示昵称首字母
      if (this.avatarUrl().length > 0) {
        RemoteImage({ url: this.avatarUrl(), cornerRadius: 28 })
          .width(56)
          .height(56)
      } else {
        Stack() {
          Text((this.authUser?.nickname ?? "N").substring(0, 1).toUpperCase())
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor("#FFFFFF")
        }
        .width(56)
        .height(56)
        .borderRadius(28)
        .backgroundColor("#E5484D")
      }

      Column({ space: 4 }) {
        Text(this.authUser?.nickname ?? "已登录")
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor("#1A1A1A")
        Text(this.authUser?.email ?? "")
          .fontSize(12)
          .fontColor("#999999")
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Button("退出")
        .fontSize(13)
        .height(32)
        .backgroundColor("#F2F2F5")
        .fontColor("#666666")
        .onClick(() => {
          this.doLogout();
        })
    }
    .width("100%")
    .padding(20)
    .backgroundColor("#FFFFFF")
    .borderRadius(22)
    .shadow({ radius: 18, color: "#0F000000", offsetY: 6 })
    .onClick(() => {
      router.pushUrl({ url: "pages/SettingsPage" });
    })
  }

  build() {
    Column() {
      Row() {
        Text("我的").fontSize(30).fontWeight(FontWeight.Bold).fontColor("#1A1A1A")
      }
      .width("100%")
      .padding({ left: 16, right: 16, top: 56, bottom: 8 })
      .systemMaterial(MaterialService.header())

      Blank().height(12)

      if (this.authToken.length > 0) {
        this.userCard()
      } else {
        this.loginCard()
      }

      Blank().height(14)

      // 上传音乐入口
      Column() {
        this.settingRow('上传音乐', '上传自己的音频', () => {
          router.pushUrl({ url: 'pages/UploadPage' });
        })
      }
      .borderRadius(22)
      .clip(true)
      .shadow({ radius: 18, color: '#0F000000', offsetY: 6 })
      .margin({ bottom: 14 })

      // 会员入口
      Column() {
        this.settingRow('会员中心', '无损音质、专属标识', () => {
          router.pushUrl({ url: 'pages/VipPage' });
        })
      }
      .borderRadius(22)
      .clip(true)
      .shadow({ radius: 18, color: '#0F000000', offsetY: 6 })
      .margin({ bottom: 14 })

      // 站内消息入口
      Column() {
        this.settingRow('站内消息',
          this.unreadCount > 0 ? this.unreadCount + ' 条未读' : '', () => {
            router.pushUrl({ url: 'pages/MessagesPage' });
          })
      }
      .borderRadius(22)
      .clip(true)
      .shadow({ radius: 18, color: '#0F000000', offsetY: 6 })
      .margin({ bottom: 14 })

      // 设置入口
      Column() {
        this.settingRow("设置", "头像、昵称、个性化", () => {
          router.pushUrl({ url: "pages/SettingsPage" });
        })
      }
      .borderRadius(22)
      .clip(true)
      .shadow({ radius: 18, color: "#0F000000", offsetY: 6 })

      Blank().height(16)

      if (this.message.length > 0) {
        Text(this.message)
          .fontSize(12)
          .fontColor("#999999")
          .margin({ top: 12 })
      }

      Blank()
    }
    .width("100%")
    .height("100%")
    .backgroundColor("#F5F6F8")
    .padding({ left: 16, right: 16 })
  }
}
