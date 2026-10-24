/** 歌曲条目（与后端 /api/music/* 返回一致） */
export interface MusicItem {
  id: number;
  title: string;
  artist: string;
  album?: string;
  duration?: number;
  coverPath?: string;
  coverUrl?: string;
  language?: string;
  tags?: string;
  fileFormat?: string;
  createdAt?: number;
  maxQuality?: string;
}

export interface MusicListData {
  success: boolean;
  message: string;
  data?: MusicItem[];
}
