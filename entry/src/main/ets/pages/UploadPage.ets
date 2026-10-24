import { AuthService } from '../services/AuthService';
import { APIConfig } from '../services/APIConfig';
import { HttpClient } from '../services/HttpClient';
import { picker } from '@kit.CoreFileKit';
import { http } from '@kit.NetworkKit';
import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AudioMetadataParser } from '../services/AudioMetadataParser';
import { media } from '@kit.MediaKit';

interface MyUpload {
  id: number;
  title: string;
  artist: string;
  duration: number;
  createdAt: number;
}

@Entry
@Component
struct UploadPage {
  @StorageLink('authToken') authToken: string = '';
  @State private title: string = '';
  @State private artist: string = '';
  @State private language: string = 'zh';
  @State private fileName: string = '';
  @State private fileUri: string = '';
  @State private uploading: boolean = false;
  @State private message: string = '';
  @State private uploads: MyUpload[] = [];
  @State private loadingUploads: boolean = false;
  @State private previewing: boolean = false;
  @State private progress: number = 0;
  private previewPlayer: media.AVPlayer | undefined = undefined;

  aboutToAppear(): void {
    this.loadUploads();
  }

  private languages: string[] = ['zh', 'ja', 'en', 'instrumental'];

  private langLabel(code: string): string {
    if (code === 'zh') {
      return '中文';
    }
    if (code === 'ja') {
      return '日语';
    }
    if (code === 'en') {
      return '英文';
    }
    return '纯音乐';
  }

  async loadUploads(): Promise<void> {
    if (!AuthService.isLoggedIn()) {
      return;
    }
    this.loadingUploads = true;
    try {
      const text: string = await HttpClient.get(
        'https://music.nekocore.cn/api/user/uploaded-music', this.authToken);
      const json = JSON.parse(text) as Record<string, Object>;
      const data = json.data as Record<string, Object>[] | undefined;
      const list: MyUpload[] = [];
      if (data !== undefined) {
        for (const item of data) {
          const id = item.id;
          if (typeof id !== 'number') {
            continue;
          }
          list.push({
            id: id,
            title: typeof item.title === 'string' ? item.title : '',
            artist: typeof item.artist === 'string' ? item.artist : '',
            duration: typeof item.duration === 'number' ? item.duration : 0,
            createdAt: typeof item.createdAt === 'number' ? item.createdAt : 0
          });
        }
      }
      this.uploads = list;
    } catch (error) {
      const err = error as Error;
      this.message = err.message;
    } finally {
      this.loadingUploads = false;
    }
  }

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
      // 自动解析 ID3 标签
      const meta = await AudioMetadataParser.parse(this.fileUri);
      if (meta.title.length > 0 && this.title.trim().length === 0) {
        this.title = meta.title;
      }
      if (meta.artist.length > 0 && this.artist.trim().length === 0) {
        this.artist = meta.artist;
      }
    } catch (error) {
      const err = error as Error;
      this.message = '选择文件失败: ' + err.message;
    }
  }

  async togglePreview(): Promise<void> {
    if (this.previewing) {
      await this.stopPreview();
      return;
    }
    if (this.fileUri.length === 0) {
      this.message = '先选择音频文件';
      return;
    }
    try {
      if (this.previewPlayer === undefined) {
        this.previewPlayer = await media.createAVPlayer();
      }
      this.previewPlayer.url = this.fileUri;
      this.previewPlayer.on('stateChange', (state: string) => {
        if (state === 'prepared') {
          this.previewPlayer?.play();
          this.previewing = true;
        } else if (state === 'completed') {
          this.previewing = false;
        }
      });
      this.previewPlayer.prepare();
    } catch (error) {
      const err = error as Error;
      this.message = '预览失败: ' + err.message;
      this.previewing = false;
    }
  }

  async stopPreview(): Promise<void> {
    try {
      if (this.previewPlayer !== undefined) {
        await this.previewPlayer.pause();
        await this.previewPlayer.reset();
      }
    } catch (error) {
      // ignore
    }
    this.previewing = false;
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
          { name: 'language', contentType: 'text/plain', remoteFileName: '', data: this.language },
          { name: 'file', contentType: 'audio/mpeg', remoteFileName: this.fileName, filePath: this.fileUri }
        ];
        const header: Record<string, string> = APIConfig.clientHeaders();
        header['Authorization'] = this.authToken;
        // 上传进度监听
        request.on('dataSendProgress', (info: http.DataSendProgressInfo) => {
          if (info.totalSize > 0) {
            this.progress = Math.min(info.sendSize / info.totalSize, 1);
          }
        });
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
          await this.loadUploads();
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
          // 歌曲信息
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

            // 语言选择
            Row({ space: 8 }) {
              Text('语言')
                .fontSize(13)
                .fontColor('#999999')
              ForEach(this.languages, (code: string) => {
                Text(this.langLabel(code))
                  .fontSize(13)
                  .fontColor(this.language === code ? '#FFFFFF' : '#666666')
                  .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                  .backgroundColor(this.language === code ? '#E5484D' : '#F2F2F5')
                  .borderRadius(14)
                  .onClick(() => {
                    this.language = code;
                  })
              }, (code: string) => code)
            }
            .width('100%')
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

              Button(this.previewing ? '停止' : '预览')
                .fontSize(13)
                .height(34)
                .borderRadius(17)
                .backgroundColor('#F2F2F5')
                .fontColor('#666666')
                .margin({ left: 8 })
                .enabled(this.fileUri.length > 0)
                .onClick(() => {
                  this.togglePreview();
                })
            }
            .width('100%')
          }
          .width('100%')
          .padding(20)
          .backgroundColor('#FFFFFF')
          .borderRadius(22)
          .shadow({ radius: 18, color: '#0F000000', offsetY: 6 })
          .alignItems(HorizontalAlign.Start)

          if (this.uploading) {
            Column({ space: 4 }) {
              Progress({ value: this.progress * 100, total: 100, type: ProgressType.Linear })
                .width('100%')
                .color('#E5484D')
              Text(Math.round(this.progress * 100) + '%')
                .fontSize(11)
                .fontColor('#999999')
            }
            .width('100%')
          }

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

          // 我的上传
          if (AuthService.isLoggedIn()) {
            Text('我的上传 (' + this.uploads.length + ')')
              .fontSize(13)
              .fontColor('#999999')
              .width('100%')
              .padding({ top: 8 })

            if (this.loadingUploads) {
              LoadingProgress().width(30).height(30)
            } else if (this.uploads.length === 0) {
              Text('还没有上传过歌曲')
                .fontSize(12)
                .fontColor('#BBBBBB')
                .padding({ top: 8 })
            } else {
              ForEach(this.uploads, (item: MyUpload) => {
                Row({ space: 10 }) {
                  Column({ space: 4 }) {
                    Text(item.title)
                      .fontSize(14)
                      .fontColor('#1A1A1A')
                      .maxLines(1)
                    Text(item.artist)
                      .fontSize(11)
                      .fontColor('#999999')
                      .maxLines(1)
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  Text('已上架')
                    .fontSize(10)
                    .fontColor('#07C160')
                }
                .width('100%')
                .padding(14)
                .backgroundColor('#FFFFFF')
                .borderRadius(16)
              }, (item: MyUpload) => item.id.toString())
            }
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
