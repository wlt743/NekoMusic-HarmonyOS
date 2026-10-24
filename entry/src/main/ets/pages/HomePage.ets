import { MaterialService } from "../services/MaterialService";
import { hdsMaterial } from "@hms.hds.hdsMaterial";
import { MusicService } from "../services/MusicService";
import { MusicItem } from "../models/Music";
import { RemoteImage } from "../components/RemoteImage";
import { AudioPlayerService } from "../services/AudioPlayerService";
import { router } from "@kit.ArkUI";

@Component
export struct HomePage {
  @State latest: MusicItem[] = [];
  @State ranking: MusicItem[] = [];
  @State loading: boolean = true;
  @State errorText: string = "";
  @StorageLink("wallpaperUri") wallpaperUri: string = "";
  @StorageLink("authToken") authToken: string = "";
  @State dailyList: MusicItem[] = [];

  async loadDaily(): Promise<void> {
    if (this.authToken.length === 0) {
      return;
    }
    try {
      const list: MusicItem[] = await MusicService.dailyRecommend(this.authToken);
      this.dailyList = list;
    } catch (error) {
      this.dailyList = [];
    }
  }

  aboutToAppear(): void {
    this.loadDaily();
    this.loadData();
  }

  private openPlayer(item: MusicItem, list: MusicItem[]): void {
    let index: number = 0;
    for (let i: number = 0; i < list.length; i++) {
      if (list[i].id === item.id) {
        index = i;
        break;
      }
    }
    AudioPlayerService.shared().setPlaylist(list, index);
    router.pushUrl({ url: "pages/PlayerPage" });
  }

  async loadData(): Promise<void> {
    try {
      const latestList: MusicItem[] = await MusicService.latest();
      const rankingList: MusicItem[] = await MusicService.ranking();
      this.latest = latestList;
      this.ranking = rankingList;
      this.loading = false;
    } catch (error) {
      const err = error as Error;
      this.errorText = err.message;
      this.loading = false;
    }
  }

  @Builder
  sectionHeader(title: string) {
    Row() {
      Text(title)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor("#1A1A1A")
      Blank()
      Text("更多")
        .fontSize(13)
        .fontColor("#999999")
    }
    .width("100%")
    .padding({ left: 16, right: 16, top: 24, bottom: 12 })
  }

  @Builder
  coverCard(item: MusicItem, width: number, source: MusicItem[]) {
    Column({ space: 8 }) {
      RemoteImage({ url: MusicService.coverURL(item), cornerRadius: 16 })
        .width(width)
        .height(width)
        .onClick(() => {
          this.openPlayer(item, source);
        })

      Text(item.title)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor("#1A1A1A")
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width(width)

      Text(item.artist)
        .fontSize(12)
        .fontColor("#999999")
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width(width)
    }
    .width(width)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack() {
      // 壁纸背景
      if (this.wallpaperUri.length > 0) {
        Image(this.wallpaperUri)
          .width("100%")
          .height("100%")
          .objectFit(ImageFit.Cover)
          .blur(18)
        Column()
          .width("100%")
          .height("100%")
          .backgroundColor("#D9F5F6F8")
      }

      Scroll() {
      Column() {
        Blank().height(0)
        // 顶部标题
        Row() {
          Text("NekoMusic")
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor("#1A1A1A")
          Blank()
          SymbolGlyph($r("sys.symbol.magnifyingglass"))
            .fontSize(22)
            .fontColor(["#1A1A1A"])
        }
        .width("100%")
        .padding({ left: 16, right: 16, top: 56, bottom: 8 })
        .systemMaterial(MaterialService.header())

        if (this.loading) {
          Column() {
            LoadingProgress()
              .width(48)
              .height(48)
            Text("加载中…")
              .fontSize(14)
              .fontColor("#999999")
              .margin({ top: 8 })
          }
          .width("100%")
          .height(300)
          .justifyContent(FlexAlign.Center)
        } else if (this.errorText.length > 0) {
          Column() {
            Text("加载失败")
              .fontSize(16)
              .fontColor("#E5484D")
            Text(this.errorText)
              .fontSize(12)
              .fontColor("#999999")
              .margin({ top: 6 })
          }
          .width("100%")
          .height(300)
          .justifyContent(FlexAlign.Center)
        } else {
          // 推荐（横向大卡片，封面完整不裁剪）
          this.sectionHeader("推荐")
          List({ space: 14 }) {
            ForEach(this.ranking.slice(0, 10), (item: MusicItem) => {
              ListItem() {
                this.coverCard(item, 168, this.ranking)
              }
            }, (item: MusicItem) => item.id.toString())
          }
          .listDirection(Axis.Horizontal)
          .width("100%")
          .padding({ left: 16, right: 16 })
          .height(228)
          .scrollBar(BarState.Off)

          // 最新上架（横向）
          this.sectionHeader("最新上架")
          List({ space: 12 }) {
            ForEach(this.latest.slice(0, 15), (item: MusicItem) => {
              ListItem() {
                this.coverCard(item, 130, this.latest)
              }
            }, (item: MusicItem) => item.id.toString())
          }
          .listDirection(Axis.Horizontal)
          .width("100%")
          .padding({ left: 16, right: 16 })
          .height(190)
          .scrollBar(BarState.Off)

          // 热门排行（横向）
          this.sectionHeader("热门排行")
          List({ space: 12 }) {
            ForEach(this.ranking.slice(0, 15), (item: MusicItem) => {
              ListItem() {
                this.coverCard(item, 130, this.ranking)
              }
            }, (item: MusicItem) => item.id.toString())
          }
          .listDirection(Axis.Horizontal)
          .width("100%")
          .padding({ left: 16, right: 16 })
          .height(190)
          .scrollBar(BarState.Off)

          Blank().height(120)
        }
      }
      .width("100%")
    }
      .width("100%")
      .height("100%")
      .backgroundColor(this.wallpaperUri.length > 0 ? "#00000000" : "#F5F6F8")
      .scrollBar(BarState.Off)
    }
    .width("100%")
    .height("100%")
  }
}
