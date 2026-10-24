import { MaterialService } from "../services/MaterialService";
import { MusicService } from "../services/MusicService";
import { MusicItem } from "../models/Music";
import { RemoteImage } from "../components/RemoteImage";
import { AudioPlayerService } from "../services/AudioPlayerService";
import { router } from "@kit.ArkUI";

@Component
export struct DiscoverPage {
  @State keyword: string = "";
  @State results: MusicItem[] = [];
  @State searching: boolean = false;
  @State message: string = "";

  async runSearch(): Promise<void> {
    const query: string = this.keyword.trim();
    if (query.length === 0) {
      return;
    }
    this.searching = true;
    this.message = "";
    try {
      const list: MusicItem[] = await MusicService.search(query);
      this.results = list;
      if (list.length === 0) {
        this.message = "没有找到相关歌曲";
      }
    } catch (error) {
      const err = error as Error;
      this.message = err.message;
    } finally {
      this.searching = false;
    }
  }

  private openPlayer(item: MusicItem): void {
    let index: number = 0;
    for (let i: number = 0; i < this.results.length; i++) {
      if (this.results[i].id === item.id) {
        index = i;
        break;
      }
    }
    AudioPlayerService.shared().setPlaylist(this.results, index);
    router.pushUrl({ url: "pages/PlayerPage" });
  }

  @Builder
  resultRow(item: MusicItem) {
    Row({ space: 12 }) {
      RemoteImage({ url: MusicService.coverURL(item), cornerRadius: 10 })
        .width(56)
        .height(56)

      Column({ space: 4 }) {
        Text(item.title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor("#1A1A1A")
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(item.artist)
          .fontSize(12)
          .fontColor("#999999")
          .maxLines(1)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      SymbolGlyph($r("sys.symbol.play_fill"))
        .fontSize(18)
        .fontColor(["#C7C7CC"])
    }
    .width("100%")
    .padding({ top: 8, bottom: 8 })
    .onClick(() => {
      this.openPlayer(item);
    })
  }

  build() {
    Column() {
      // 搜索框
      Row({ space: 10 }) {
        Search({ value: this.keyword, placeholder: "搜索歌曲、歌手" })
          .layoutWeight(1)
          .height(44)
          .backgroundColor("#EFEFF2")
          .placeholderColor("#999999")
          .onChange((value: string) => {
            this.keyword = value;
          })
          .enterKeyType(EnterKeyType.Search)
          .onSubmit((value: string) => {
            this.keyword = value;
            this.runSearch();
          })

        Button("搜索")
          .height(40)
          .fontSize(14)
          .backgroundColor("#E5484D")
          .onClick(() => {
            this.runSearch();
          })
      }
      .width("100%")
      .padding({ left: 16, right: 16, top: 40, bottom: 8 })
      .systemMaterial(MaterialService.header())
      .backgroundColor("#F5F6F8")

      if (this.searching) {
        Column() {
          LoadingProgress().width(40).height(40)
          Text("搜索中…").fontSize(13).fontColor("#999999").margin({ top: 8 })
        }
        .width("100%")
        .height(200)
        .justifyContent(FlexAlign.Center)
      } else if (this.message.length > 0) {
        Column() {
          Text(this.message).fontSize(14).fontColor("#999999")
        }
        .width("100%")
        .height(200)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 4 }) {
          ForEach(this.results, (item: MusicItem) => {
            ListItem() {
              this.resultRow(item)
            }
          }, (item: MusicItem) => item.id.toString())
        }
        .width("100%")
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })
        .divider({ strokeWidth: 0.5, color: "#EEEEEE", startMargin: 68, endMargin: 0 })
      }
    }
    .width("100%")
    .height("100%")
    .backgroundColor("#F5F6F8")
  }
}
