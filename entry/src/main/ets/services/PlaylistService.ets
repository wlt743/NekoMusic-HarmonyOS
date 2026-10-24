import { HttpClient } from './HttpClient';
import { APIConfig } from './APIConfig';
import { AuthService } from './AuthService';
import { MusicItem } from '../models/Music';
import { hilog } from '@kit.PerformanceAnalysisKit';

/** 歌单 */
export interface PlaylistInfo {
  id: number;
  name: string;
  description?: string;
  coverUrl?: string;
  musicCount?: number;
  createdAt?: number;
}

interface PlaylistListResponse {
  success: boolean;
  message: string;
  playlists?: PlaylistInfo[];
}

interface PlaylistCreateResponse {
  success: boolean;
  message: string;
  playlist?: PlaylistInfo;
}

/** 歌单：列表 / 创建 / 详情 / 加歌 / 移除 / 删除 */
export class PlaylistService {
  static list(): PlaylistInfo[] {
    return AppStorage.get<PlaylistInfo[]>('myPlaylists') ?? [];
  }

  static async refresh(): Promise<PlaylistInfo[]> {
    if (!AuthService.isLoggedIn()) {
      AppStorage.set<PlaylistInfo[]>('myPlaylists', []);
      return [];
    }
    try {
      const text: string = await HttpClient.get(APIConfig.myPlaylistsURL(), AuthService.token());
      const json: PlaylistListResponse = JSON.parse(text) as PlaylistListResponse;
      const items: PlaylistInfo[] = json.playlists ?? [];
      AppStorage.set<PlaylistInfo[]>('myPlaylists', items);
      hilog.info(0x0000, 'NekoPlaylist', 'loaded %{public}d playlists', items.length);
      return items;
    } catch (error) {
      const err = error as Error;
      hilog.error(0x0000, 'NekoPlaylist', 'refresh failed: %{public}s', err.message);
      return PlaylistService.list();
    }
  }

  static async create(name: string, description: string): Promise<PlaylistInfo> {
    const body: string = JSON.stringify({ name: name, description: description });
    const text: string = await HttpClient.post(APIConfig.playlistCreateURL(), body, AuthService.token());
    const json: PlaylistCreateResponse = JSON.parse(text) as PlaylistCreateResponse;
    if (!json.success) {
      throw new Error(json.message.length > 0 ? json.message : '创建歌单失败');
    }
    await PlaylistService.refresh();
    return json.playlist as PlaylistInfo;
  }

  static async addMusic(playlistId: number, musicId: number): Promise<void> {
    const body: string = JSON.stringify({ playlistId: playlistId, musicId: musicId });
    await HttpClient.post(APIConfig.playlistAddMusicURL(), body, AuthService.token());
  }

  static async removeMusic(playlistId: number, musicId: number): Promise<void> {
    const body: string = JSON.stringify({ playlistId: playlistId, musicId: musicId });
    await HttpClient.post(APIConfig.playlistRemoveMusicURL(), body, AuthService.token());
  }

  static async deletePlaylist(playlistId: number): Promise<void> {
    const body: string = JSON.stringify({ playlistId: playlistId });
    await HttpClient.post(APIConfig.playlistDeleteURL(), body, AuthService.token());
    await PlaylistService.refresh();
  }

  static async music(playlistId: number): Promise<MusicItem[]> {
    const text: string = await HttpClient.get(APIConfig.playlistMusicURL(playlistId), AuthService.token());
    const json = JSON.parse(text) as Record<string, Object>;
    const list = json.data as MusicItem[] | undefined;
    return list ?? [];
  }
}
