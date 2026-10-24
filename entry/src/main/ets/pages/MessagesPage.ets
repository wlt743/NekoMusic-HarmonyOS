import { NotificationService, NotificationItem } from '../services/NotificationService';
import { AuthService } from '../services/AuthService';
import { router } from '@kit.ArkUI';

@Entry
@Component
struct MessagesPage {
  @State private items: NotificationItem[] = [];
  @State private loading: boolean = true;
  @State private message: string = '';

  aboutToAppear(): void {
    this.load();
  }

  async load(): Promise<void> {
    this.loading = true;
    try {
      this.items = await NotificationService.list();
    } catch (error) {
      const err = error as Error;
      this.message = err.message;
    } finally {
      this.loading = false;
    }
  }

  private timeText(ts: number): string {
    if (ts <= 0) {
      return '';
    }
    const date = new Date(ts);
    const month = date.getMonth() + 1;
    const day = date.getDate();
    const hour = date.getHours().toString().padStart(2, '0');
    const minute = date.getMinutes().toString().padStart(2, '0');
    return month + '月' + day + '日 ' + hour + ':' + minute;
  }

  async open(item: NotificationItem): Promise<void> {
    if (!item.read) {
      try {
        await NotificationService.markRead(item.id);
        item.read = true;
        this.items = this.items.slice();
      } catch (error) {
        // 忽略标记失败
      }
    }
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

        Text('站内消息')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 56, bottom: 12 })

      if (!AuthService.isLoggedIn()) {
        Column() {
          Text('登录后查看消息').fontSize(14).fontColor('#999999')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.loading) {
        Column() {
          LoadingProgress().width(36).height(36)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.items.length === 0) {
        Column({ space: 6 }) {
          Text('暂无消息').fontSize(14).fontColor('#999999')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 10 }) {
          ForEach(this.items, (item: NotificationItem) => {
            ListItem() {
              Column({ space: 6 }) {
                Row({ space: 8 }) {
                  if (!item.read) {
                    Column()
                      .width(7)
                      .height(7)
                      .borderRadius(4)
                      .backgroundColor('#E5484D')
                  }
                  Text(item.title.length > 0 ? item.title : '通知')
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#1A1A1A')
                    .layoutWeight(1)
                    .maxLines(1)
                  Text(this.timeText(item.createdAt))
                    .fontSize(10)
                    .fontColor('#BBBBBB')
                }
                .width('100%')

                Text(item.content)
                  .fontSize(13)
                  .fontColor('#666666')
                  .width('100%')
              }
              .width('100%')
              .padding(14)
              .backgroundColor('#FFFFFF')
              .borderRadius(16)
              .onClick(() => {
                this.open(item);
              })
            }
          }, (item: NotificationItem) => item.id.toString())
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })
        .scrollBar(BarState.Off)
      }

      if (this.message.length > 0) {
        Text(this.message)
          .fontSize(11)
          .fontColor('#999999')
          .padding({ bottom: 16 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F8')
  }
}
