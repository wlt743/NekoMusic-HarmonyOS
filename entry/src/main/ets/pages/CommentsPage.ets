import { CommentService, CommentItem } from '../services/CommentService';
import { MusicItem } from '../models/Music';
import { AuthService } from '../services/AuthService';
import { router } from '@kit.ArkUI';

@Entry
@Component
struct CommentsPage {
  @State private comments: CommentItem[] = [];
  @State private loading: boolean = true;
  @State private draft: string = '';
  @State private sending: boolean = false;
  @State private message: string = '';
  private musicId: number = 0;
  private musicTitle: string = '';

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object> | undefined;
    if (params !== undefined) {
      const idValue = params.musicId;
      const titleValue = params.title;
      if (typeof idValue === 'number') {
        this.musicId = idValue;
      }
      if (typeof titleValue === 'string') {
        this.musicTitle = titleValue;
      }
    }
    this.load();
  }

  async load(): Promise<void> {
    this.loading = true;
    try {
      const list: CommentItem[] = await CommentService.list(this.musicId);
      this.comments = list;
    } catch (error) {
      const err = error as Error;
      this.message = err.message;
    } finally {
      this.loading = false;
    }
  }

  async send(): Promise<void> {
    const text = this.draft.trim();
    if (text.length === 0) {
      return;
    }
    if (!AuthService.isLoggedIn()) {
      this.message = '请先登录';
      return;
    }
    this.sending = true;
    try {
      await CommentService.post(this.musicId, text);
      this.draft = '';
      this.message = '评论成功';
      await this.load();
    } catch (error) {
      const err = error as Error;
      this.message = err.message;
    } finally {
      this.sending = false;
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

        Column({ space: 2 }) {
          Text('评论')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A1A')
          if (this.musicTitle.length > 0) {
            Text(this.musicTitle)
              .fontSize(11)
              .fontColor('#999999')
              .maxLines(1)
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 56, bottom: 12 })

      // 列表
      if (this.loading) {
        Column() {
          LoadingProgress().width(36).height(36)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.comments.length === 0) {
        Column({ space: 6 }) {
          Text('还没有评论').fontSize(14).fontColor('#999999')
          Text('来说点什么吧').fontSize(12).fontColor('#BBBBBB')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 10 }) {
          ForEach(this.comments, (item: CommentItem) => {
            ListItem() {
              Row({ space: 10 }) {
                // 头像占位
                Stack() {
                  Text((item.nickname.length > 0 ? item.nickname.substring(0, 1) : '?').toUpperCase())
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#FFFFFF')
                }
                .width(34)
                .height(34)
                .borderRadius(17)
                .backgroundColor('#E5484D')

                Column({ space: 4 }) {
                  Row({ space: 8 }) {
                    Text(item.nickname.length > 0 ? item.nickname : '匿名')
                      .fontSize(13)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#1A1A1A')
                    Text(this.timeText(item.createdAt))
                      .fontSize(10)
                      .fontColor('#BBBBBB')
                  }
                  Text(item.content)
                    .fontSize(14)
                    .fontColor('#333333')
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
              }
              .width('100%')
              .padding(12)
              .backgroundColor('#FFFFFF')
              .borderRadius(16)
            }
          }, (item: CommentItem) => item.id.toString())
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
          .padding({ top: 6 })
      }

      // 输入栏
      Row({ space: 10 }) {
        TextInput({ placeholder: '说点什么…', text: this.draft })
          .layoutWeight(1)
          .height(44)
          .borderRadius(22)
          .onChange((value: string) => {
            this.draft = value;
          })
        Button(this.sending ? '…' : '发送')
          .height(42)
          .borderRadius(21)
          .backgroundColor('#E5484D')
          .enabled(!this.sending)
          .onClick(() => {
            this.send();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 20 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F8')
  }
}
