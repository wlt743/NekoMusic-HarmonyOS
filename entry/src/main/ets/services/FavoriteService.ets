import { HttpClient } from "./HttpClient";
import { APIConfig } from "./APIConfig";
import { AuthService } from "./AuthService";
import { hilog } from '@kit.PerformanceAnalysisKit';
import { MusicItem } from '../models/Music';

interface FavoriteApiResponse {
  success: boolean;
  message: string;
}

/** 收藏：列表 / 添加 / 取消 */
export class FavoriteService {
  /** 已收藏的歌曲 id 集合（AppStorage 里存数组） */
  static ids(): number[] {
    return AppStorage.get<number[]>("favoriteIds") ?? [];
  }

  static isFavorite(musicId: number): boolean {
    return FavoriteService.ids().indexOf(musicId) >= 0;
  }

  static async refresh(): Promise<number[]> {
    if (!AuthService.isLoggedIn()) {
      AppStorage.set<number[]>("favoriteIds", []);
      return [];
    }
    try {
      const text: string = await HttpClient.get(APIConfig.favoritesURL(), AuthService.token());
      const json = JSON.parse(text) as Record<string, Object>;
      const favorites = json.favorites as Object[] | undefined;
      const ids: number[] = [];
      const items: MusicItem[] = [];
      if (favorites !== undefined) {
        for (const item of favorites) {
          const record = item as Record<string, Object>;
          // 后端 favorites 直接返回音乐对象：id 就是 musicId
          const music = record.music as Record<string, Object> | undefined;
          const source: Record<string, Object> = music !== undefined ? music : record;
          const id = record.musicId ?? record.id ?? source.id;
          if (typeof id === "number") {
            ids.push(id);
            const titleValue = source.title;
            const artistValue = source.artist;
            items.push({
              id: id,
              title: typeof titleValue === "string" ? titleValue : "",
              artist: typeof artistValue === "string" ? artistValue : ""
            });
          }
        }
      }
      AppStorage.set<number[]>("favoriteIds", ids);
      AppStorage.set<MusicItem[]>("favoriteList", items);
      return ids;
    } catch (error) {
      return FavoriteService.ids();
    }
  }

  /** 切换收藏，返回切换后的状态 */
  static async toggle(musicId: number): Promise<boolean> {
    if (!AuthService.isLoggedIn()) {
      throw new Error("请先登录");
    }
    const token: string = AuthService.token();
    const wasFavorite: boolean = FavoriteService.isFavorite(musicId);
    hilog.info(0x0000, 'NekoFav', 'toggle wasFavorite=%{public}s', wasFavorite ? 'true' : 'false');
    if (wasFavorite) {
      await HttpClient.delete(APIConfig.removeFavoriteURL(musicId), token);
    } else {
      await HttpClient.post(APIConfig.favoritesURL(), JSON.stringify({ musicId: musicId }), token);
    }
    hilog.info(0x0000, 'NekoFav', 'api ok, updating local state');
    const next: number[] = FavoriteService.ids();
    if (wasFavorite) {
      const index: number = next.indexOf(musicId);
      if (index >= 0) {
        next.splice(index, 1);
      }
    } else {
      next.push(musicId);
    }
    AppStorage.set<number[]>("favoriteIds", next);
    return !wasFavorite;
  }
}
