import { HttpClient } from '../services/HttpClient';
import { AuthService } from '../services/AuthService';
import { router } from '@kit.ArkUI';

interface VipPriceItem {
  id: number;
  months: number;
  days: number;
  priceYuan: number;
}

@Entry
@Component
struct VipPage {
  @State private prices: VipPriceItem[] = [];
  @State private loading: boolean = true;
  @State private selectedId: number = 0;
  @State private message: string = '';

  aboutToAppear(): void {
    this.load();
  }

  async load(): Promise<void> {
    this.loading = true;
    try {
      const text: string = await HttpClient.get('https://music.nekocore.cn/api/vip/pricing');
      const json = JSON.parse(text) as Record<string, Object>;
      const data = json.data as Record<string, Object>[] | undefined;
      const list: VipPriceItem[] = [];
      if (data !== undefined) {
        for (const item of data) {
          const id = item.id;
          if (typeof id !== 'number') {
            continue;
          }
          list.push({
            id: id,
            months: typeof item.months === 'number' ? item.months : 0,
            days: typeof item.days === 'number' ? item.days : 0,
            priceYuan: typeof item.priceYuan === 'number' ? item.priceYuan : 0
          });
        }
      }
      this.prices = list;
      if (list.length > 0) {
        this.selectedId = list[0].id;
      }
    } catch (error) {
      const err = error as Error;
      this.message = err.message;
    } finally {
      this.loading = false;
    }
  }

  private buy(): void {
    if (!AuthService.isLoggedIn()) {
      this.message = '请先登录';
      return;
    }
    this.message = '华为支付需要先在 AGC 配置商品，暂未开通';
  }

  private label(item: VipPriceItem): string {
    if (item.months > 0) {
      return item.months + ' 个月';
    }
    return item.days + ' 天';
  }

  private daysText(item: VipPriceItem): string {
    if (item.months > 0) {
      return (item.months * 30) + ' 天';
    }
    return item.days + ' 天';
  }

  build() {
    Column() {
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

        Text('Neko 会员')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 56, bottom: 12 })

      if (this.loading) {
        Column() {
          LoadingProgress().width(36).height(36)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 12 }) {
            // 权益卡
            Column({ space: 8 }) {
              Text('会员权益')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor('#1A1A1A')
                .width('100%')
              Text('· 无损音质\n· 专属标识\n· 优先体验新功能')
                .fontSize(13)
                .fontColor('#666666')
                .lineHeight(22)
                .width('100%')
            }
            .width('100%')
            .padding(20)
            .backgroundColor('#FFFFFF')
            .borderRadius(22)
            .shadow({ radius: 18, color: '#0F000000', offsetY: 6 })
            .alignItems(HorizontalAlign.Start)

            // 价格列表
            ForEach(this.prices, (item: VipPriceItem) => {
              Row({ space: 12 }) {
                Column({ space: 4 }) {
                  Text(this.label(item))
                    .fontSize(17)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.selectedId === item.id ? '#E5484D' : '#1A1A1A')
                  Text(this.daysText(item))
                    .fontSize(11)
                    .fontColor('#999999')
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Text('¥' + item.priceYuan.toFixed(2))
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.selectedId === item.id ? '#E5484D' : '#1A1A1A')
              }
              .width('100%')
              .padding(18)
              .backgroundColor('#FFFFFF')
              .borderRadius(18)
              .border({ width: this.selectedId === item.id ? 2 : 0, color: '#E5484D' })
              .shadow({ radius: 14, color: '#0A000000', offsetY: 4 })
              .onClick(() => {
                this.selectedId = item.id;
              })
            }, (item: VipPriceItem) => item.id.toString())

            Button('立即购买')
              .width('100%')
              .height(48)
              .borderRadius(24)
              .backgroundColor('#E5484D')
              .onClick(() => {
                this.buy();
              })

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
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F8')
  }
}
