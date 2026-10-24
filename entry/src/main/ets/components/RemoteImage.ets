import { http } from "@kit.NetworkKit";
import { image } from "@kit.ImageKit";
import { APIConfig } from "../services/APIConfig";

/**
 * 带客户端头的网络图片。
 * ArkTS 的 Image(url) 无法附加请求头，会被后端判定为爬虫（403），
 * 所以这里先 http 拉取再转 PixelMap，并按 URL 缓存。
 */
export class ImageCache {
  private static cache: Map<string, image.PixelMap> = new Map<string, image.PixelMap>();
  private static pending: Map<string, Promise<image.PixelMap | undefined>> =
    new Map<string, Promise<image.PixelMap | undefined>>();

  static get(url: string): image.PixelMap | undefined {
    return ImageCache.cache.get(url);
  }

  static async load(url: string): Promise<image.PixelMap | undefined> {
    const cached: image.PixelMap | undefined = ImageCache.cache.get(url);
    if (cached !== undefined) {
      return cached;
    }
    const inflight: Promise<image.PixelMap | undefined> | undefined = ImageCache.pending.get(url);
    if (inflight !== undefined) {
      return inflight;
    }
    const task: Promise<image.PixelMap | undefined> = ImageCache.fetchPixelMap(url);
    ImageCache.pending.set(url, task);
    const result: image.PixelMap | undefined = await task;
    ImageCache.pending.delete(url);
    if (result !== undefined) {
      ImageCache.cache.set(url, result);
    }
    return result;
  }

  private static async fetchPixelMap(url: string): Promise<image.PixelMap | undefined> {
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(url, {
        method: http.RequestMethod.GET,
        header: APIConfig.clientHeaders(),
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 15000,
        readTimeout: 30000
      });
      if (response.responseCode !== 200) {
        return undefined;
      }
      const buffer: ArrayBuffer = response.result as ArrayBuffer;
      if (buffer === undefined || buffer.byteLength === 0) {
        return undefined;
      }
      const source: image.ImageSource = image.createImageSource(buffer);
      const pixelMap: image.PixelMap = await source.createPixelMap({
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      });
      await source.release();
      return pixelMap;
    } catch (error) {
      return undefined;
    } finally {
      request.destroy();
    }
  }
}

@Component
export struct RemoteImage {
  url: string = "";
  cornerRadius: number = 16;
  @State private pixelMap: image.PixelMap | undefined = undefined;
  @State private failed: boolean = false;

  aboutToAppear(): void {
    this.loadImage();
  }

  async loadImage(): Promise<void> {
    if (this.url.length === 0) {
      return;
    }
    const cached: image.PixelMap | undefined = ImageCache.get(this.url);
    if (cached !== undefined) {
      this.pixelMap = cached;
      return;
    }
    const loaded: image.PixelMap | undefined = await ImageCache.load(this.url);
    if (loaded === undefined) {
      this.failed = true;
    } else {
      this.pixelMap = loaded;
    }
  }

  build() {
    Stack() {
      if (this.pixelMap !== undefined) {
        Image(this.pixelMap)
          .width("100%")
          .height("100%")
          .objectFit(ImageFit.Cover)
      } else {
        Column() {
          Text(this.failed ? "🎵" : "")
            .fontSize(28)
            .fontColor("#CCCCCC")
        }
        .width("100%")
        .height("100%")
        .justifyContent(FlexAlign.Center)
        .backgroundColor("#EFEFEF")
      }
    }
    .width("100%")
    .height("100%")
    .borderRadius(this.cornerRadius)
    .clip(true)
  }
}
