import { AuthService } from '../services/AuthService';
import { APIConfig } from '../services/APIConfig';
import { HttpClient } from '../services/HttpClient';
import { picker } from '@kit.CoreFileKit';
import { http } from '@kit.NetworkKit';
import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

@Entry
@Component
struct UploadPage {
  @StorageLink('authToken') authToken: string = '';
  @State private title: string = '';
  @State private artist: string = '';
  @State private fileName: string = '';
  @State private fileUri: string = '';
  @State private uploading: boolean = false;
  @State private progress: number = 0;
  @State private message: string = '';

  async pickFile(): Promise<void> {
    try {
      const documentPicker = new picker.DocumentViewPicker();
      const options = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 1;
      const uris = await documentPicker.select(options);
      if (uris.length === 0) {
        return;
      }
      this.fileUri = uris[0];
      const parts = uris[0].split('/');
      this.fileName = parts[parts.length - 1];
    } catch (error) {
      const err = error as Error;
      this.message = '选择文件失败: ' + err.message;
    }
  }

  async upload(): Promise<void> {
    if (this.title.trim().length === 0 || this.artist.trim().length === 0) {
      this.message = '请填写标题和歌手';
      return;
    }
    if (this.fileUri.length === 0) {
      this.message = '请选择音频文件';
      return;
    }
    if (!AuthService.isLoggedIn()) {
      this.message = '请先登录';
      return;
    }
    this.uploading = true;
    this.progress = 0;
    this.message = '上传中…';
    try {
      const request = http.createHttp();
      try {
        const formData: http.MultiFormData[] = [
          { name: 'title', contentType: 'text/plain', remoteFileName: '', data: this.title.trim() },
          { name: 'artist', contentType: 'text/plain', remoteFileName: '', data: this.artist.trim() },
          { name: 'file', contentType: 'audio/mpeg', remoteFileName: this.fileName, filePath: this.fileUri }
        ];
        const header: Record<string, string> = APIConfig.clientHeaders();
        header['Authorization'] = this.authToken;
        const response = await request.request('https://music.nekocore.cn/api/user/upload', {
          method: http.RequestMethod.POST,
          header: header,
          multiFormDataList: formData,
          connectTimeout: 30000,
          readTimeout: 300000,
          expectDataType: http.HttpDataType.STRING
        });
        if (response.responseCode >= 200 && response.responseCode < 300) {
          this.message = '上传成功，等待审核';
          this.title = '';
          this.artist = '';
          this.fileName = '';
          this.fileUri = '';
        } else {
          this.message = '上传失败(' + response.responseCode + ')';
        }
      } finally {
        request.destroy();
      }
    } catch (error) {
      const err = error as Error;
      this.message = '上传失败: ' + err.message;
      hilog.error(0x0000, 'NekoUpload', 'upload failed: %{public}s', err.message);
    } finally {
      this.uploading = false;
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

        Text('上传音乐')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 56, bottom: 12 })

      Scroll() {
        Column({ space: 14 }) {
          Column({ space: 12 }) {
            Text('歌曲信息')
              .fontSize(13)
              .fontColor('#999999')
              .width('100%')

            TextInput({ placeholder: '歌曲标题', text: this.title })
              .height(46)
              .borderRadius(14)
              .onChange((value: string) => {
                this.title = value;
              })

            TextInput({ placeholder: '歌手', text: this.artist })
              .height(46)
              .borderRadius(14)
              .onChange((value: string) => {
                this.artist = value;
              })
          }
          .width('100%')
          .padding(20)
          .backgroundColor('#FFFFFF')
          .borderRadius(22)
          .shadow({ radius: 18, color: '#0F000000', offsetY: 6 })
          .alignItems(HorizontalAlign.Start)

          // 文件
          Column({ space: 12 }) {
            Row() {
              Column({ space: 4 }) {
                Text('音频文件')
                  .fontSize(15)
                  .fontColor('#1A1A1A')
                Text(this.fileName.length > 0 ? this.fileName : '未选择')
                  .fontSize(12)
                  .fontColor('#999999')
                  .maxLines(1)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Button('选择')
                .fontSize(13)
                .height(34)
                .borderRadius(17)
                .backgroundColor('#F2F2F5')
                .fontColor('#666666')
                .onClick(() => {
                  this.pickFile();
                })
            }
            .width('100%')

            if (this.uploading || this.progress > 0) {
              Progress({ value: this.progress * 100, total: 100, type: ProgressType.Linear })
                .width('100%')
                .color('#E5484D')
            }
          }
          .width('100%')
          .padding(20)
          .backgroundColor('#FFFFFF')
          .borderRadius(22)
          .shadow({ radius: 18, color: '#0F000000', offsetY: 6 })
          .alignItems(HorizontalAlign.Start)

          Button(this.uploading ? '上传中…' : '上传')
            .width('100%')
            .height(46)
            .borderRadius(23)
            .backgroundColor('#E5484D')
            .enabled(!this.uploading)
            .onClick(() => {
              this.upload();
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
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F8')
  }
}
