import { http } from "@kit.NetworkKit";
import { APIConfig } from "./APIConfig";
import { NonceService } from "./NonceService";

/**
 * 统一网络层：
 * 1. 所有请求带客户端识别头
 * 2. 除白名单外自动附加一次性 X-Neko-Nonce
 * 3. 409 / 403 时换 nonce 重试一次
 */
export class HttpClient {
  static async get(url: string, token: string = ""): Promise<string> {
    return HttpClient.send(url, http.RequestMethod.GET, "", token);
  }

  static async post(url: string, body: string, token: string = ""): Promise<string> {
    return HttpClient.send(url, http.RequestMethod.POST, body, token);
  }

  private static async send(url: string, method: http.RequestMethod,
    body: string, token: string): Promise<string> {
    for (let attempt: number = 0; attempt < 2; attempt++) {
      const header: Record<string, string> = APIConfig.clientHeaders();
      if (token.length > 0) {
        header["Authorization"] = token;
      }
      if (method !== http.RequestMethod.GET) {
        header["Content-Type"] = "application/json";
      }

      let path: string = url;
      const schemeIndex: number = url.indexOf("://");
      if (schemeIndex >= 0) {
        const pathIndex: number = url.indexOf("/", schemeIndex + 3);
        path = pathIndex >= 0 ? url.substring(pathIndex) : "/";
      }
      if (APIConfig.requiresNonce(path)) {
        const nonce: string = await NonceService.shared().nextNonce(method !== http.RequestMethod.GET);
        header["X-Neko-Nonce"] = nonce;
      }

      const request: http.HttpRequest = http.createHttp();
      try {
        const response: http.HttpResponse = await request.request(url, {
          method: method,
          header: header,
          extraData: body.length > 0 ? body : undefined,
          expectDataType: http.HttpDataType.STRING,
          connectTimeout: 30000,
          readTimeout: 60000
        });
        const code: number = response.responseCode;
        const text: string = (response.result as string) ?? "";

        if (code === 409 && attempt === 0) {
          continue;
        }
        if (code === 409) {
          throw new Error("请求被服务端拒绝，请检查网络环境");
        }
        if (code === 401) {
          throw new Error("登录已失效");
        }
        if (code < 200 || code >= 300) {
          throw new Error("请求失败(" + code + "): " + text.substring(0, 120));
        }
        return text;
      } finally {
        request.destroy();
      }
    }
    throw new Error("请求失败");
  }

  /**
   * 音频接口现在返回 {"data":{"url":"/media/..."}}，
   * 需要先换成真实地址再交给播放器。
   */
  static async resolveAudioURL(musicId: number, quality: string = "hq"): Promise<string> {
    const text: string = await HttpClient.get(APIConfig.musicFileURL(musicId, quality));
    const json: AudioFileResponse = JSON.parse(text) as AudioFileResponse;
    if (!json.success || json.data === undefined) {
      throw new Error(json.message ?? "无法获取播放地址");
    }
    return APIConfig.buildFullURL(json.data.url);
  }
}

interface AudioFileData {
  url: string;
}

interface AudioFileResponse {
  success: boolean;
  message: string;
  data?: AudioFileData;
}
