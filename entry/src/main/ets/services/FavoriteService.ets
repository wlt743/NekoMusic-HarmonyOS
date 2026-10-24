import { HttpClient } from "./HttpClient";
import { APIConfig } from "./APIConfig";
import { AuthService } from "./AuthService";

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
      if (favorites !== undefined) {
        for (const item of favorites) {
          const record = item as Record<string, Object>;
          const music = record.music as Record<string, Object> | undefined;
          const id = record.musicId ?? (music !== undefined ? music.id : undefined);
          if (typeof id === "number") {
            ids.push(id);
          }
        }
      }
      AppStorage.set<number[]>("favoriteIds", ids);
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
    if (wasFavorite) {
      await HttpClient.delete(APIConfig.removeFavoriteURL(musicId), token);
    } else {
      await HttpClient.post(APIConfig.favoritesURL(), JSON.stringify({ musicId: musicId }), token);
    }
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
