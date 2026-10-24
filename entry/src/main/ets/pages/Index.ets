import { HdsTabs } from "@hms.hds.hdsBaseComponent";
import { NonceService } from "../services/NonceService";
import { HomePage } from "./HomePage";
import { DiscoverPage } from "./DiscoverPage";
import { LibraryPage } from "./LibraryPage";
import { ProfilePage } from "./ProfilePage";

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;

  aboutToAppear(): void {
    // 预热 nonce，减少点歌时的等待
    NonceService.shared().warmUp();
  }

  @Builder
  tabItem(title: string, icon: Resource, activeIcon: Resource, index: number) {
    Column({ space: 3 }) {
      SymbolGlyph(this.currentIndex === index ? activeIcon : icon)
        .fontSize(22)
        .fontColor([this.currentIndex === index ? "#E5484D" : "#7A7A7E"])
      Text(title)
        .fontSize(10)
        .fontWeight(this.currentIndex === index ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.currentIndex === index ? "#E5484D" : "#7A7A7E")
    }
    .width("100%")
    .height(56)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    HdsTabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
      TabContent() {
        HomePage()
      }.tabBar(this.tabItem("首页", $r("sys.symbol.house"), $r("sys.symbol.house_fill"), 0))

      TabContent() {
        DiscoverPage()
      }.tabBar(this.tabItem("发现", $r("sys.symbol.magnifyingglass"), $r("sys.symbol.magnifyingglass"), 1))

      TabContent() {
        LibraryPage()
      }.tabBar(this.tabItem("音乐库", $r("sys.symbol.music_note_list"), $r("sys.symbol.music_note_list"), 2))

      TabContent() {
        ProfilePage()
      }.tabBar(this.tabItem("我的", $r("sys.symbol.person"), $r("sys.symbol.person_fill"), 3))
    }
    .barHeight(64)
    .barBackgroundBlurStyle(BlurStyle.COMPONENT_THICK)
    .barBackgroundColor("#CCFFFFFF")
    .barFloatingStyle({ barSideMargin: 40, barBottomMargin: 16 })
    .scrollable(false)
    .onChange((index: number) => {
      this.currentIndex = index;
    })
    .width("100%")
    .height("100%")
    .backgroundColor("#F5F6F8")
  }
}
