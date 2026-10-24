import { APIConfig } from "./APIConfig";
import { HttpClient } from "./HttpClient";
import { MusicItem, MusicListData } from "../models/Music";

interface SearchResultData {
  success: boolean;
  message: string;
  results?: MusicItem[];
}

interface MusicInfoData {
  lyrics?: string;
}

interface MusicInfoResponse {
  success: boolean;
  message: string;
  data?: MusicInfoData;
}

export class MusicService {
  static async latest(): Promise<MusicItem[]> {
    const text: string = await HttpClient.get(APIConfig.musicLatestURL());
    const json: MusicListData = JSON.parse(text) as MusicListData;
    if (!json.success) {
      throw new Error(json.message ?? "获取最新音乐失败");
    }
    return json.data ?? [];
  }

  static async ranking(): Promise<MusicItem[]> {
    const text: string = await HttpClient.get(APIConfig.musicRankingURL());
    const json: MusicListData = JSON.parse(text) as MusicListData;
    if (!json.success) {
      throw new Error(json.message ?? "获取排行榜失败");
    }
    return json.data ?? [];
  }

  static async search(query: string): Promise<MusicItem[]> {
    const body: string = JSON.stringify({ query: query });
    const text: string = await HttpClient.post(APIConfig.musicSearchURL(), body);
    const json: SearchResultData = JSON.parse(text) as SearchResultData;
    if (!json.success) {
      throw new Error(json.message ?? "搜索失败");
    }
    return json.results ?? [];
  }

  static async lyrics(musicId: number): Promise<string> {
    const text: string = await HttpClient.get(APIConfig.musicInfoURL(musicId));
    const json: MusicInfoResponse = JSON.parse(text) as MusicInfoResponse;
    if (!json.success || json.data === undefined) {
      throw new Error(json.message ?? "获取歌词失败");
    }
    return json.data.lyrics ?? "";
  }

  /** 每日推荐：返回项只有 musicId，需要映射 */
  static async dailyRecommend(token: string): Promise<MusicItem[]> {
    const text: string = await HttpClient.get(APIConfig.dailyRecommendURL(), token);
    const json = JSON.parse(text) as Record<string, Object>;
    const list = json.data as Record<string, Object>[] | undefined;
    const result: MusicItem[] = [];
    if (list !== undefined) {
      for (const item of list) {
        const musicId = item.musicId;
        if (typeof musicId === "number") {
          const titleValue = item.title;
          const artistValue = item.artist;
          result.push({
            id: musicId,
            title: typeof titleValue === "string" ? titleValue : "",
            artist: typeof artistValue === "string" ? artistValue : ""
          });
        }
      }
    }
    return result;
  }

  /** 封面完整地址 */
  static coverURL(item: MusicItem): string {
    if (item.coverUrl !== undefined && item.coverUrl.length > 0) {
      return APIConfig.buildFullURL(item.coverUrl);
    }
    return APIConfig.musicCoverURL(item.id);
  }
}
