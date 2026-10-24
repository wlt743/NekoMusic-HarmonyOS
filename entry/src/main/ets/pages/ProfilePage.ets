import { WallpaperService } from "../services/WallpaperService";
import { MaterialService } from "../services/MaterialService";

@Component
export struct ProfilePage {
  @StorageLink("wallpaperUri") wallpaperUri: string = "";
  @State message: string = "";

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
        Text(title)
          .fontSize(16)
          .fontColor("#1A1A1A")
        Text(subtitle)
          .fontSize(12)
          .fontColor("#999999")
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

  build() {
    Column() {
      Row() {
        Text("我的")
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor("#1A1A1A")
      }
      .width("100%")
      .padding({ left: 16, right: 16, top: 24, bottom: 8 })
      .systemMaterial(MaterialService.header())

      Blank().height(12)

      Column({ space: 1 }) {
        this.settingRow("更换壁纸", this.wallpaperUri.length > 0 ? "已设置" : "未设置", () => {
          this.pickWallpaper();
        })
        this.settingRow("清除壁纸", "恢复纯色背景", () => {
          this.clearWallpaper();
        })
      }
      .borderRadius(16)
      .clip(true)
      .margin({ left: 16, right: 16 })

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
  }
}
