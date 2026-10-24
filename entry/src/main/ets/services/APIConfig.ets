/**
 * 后端配置与请求头。
 * 后端启用了防爬与客户端识别：请求头不完整会被判成爬虫（403 或降级成 SEO 页面）。
 */
export class APIConfig {
  static readonly baseURL: string = "https://music.nekocore.cn";
  static readonly clientVersion: string = "1.0.0";
  /** 官方客户端标识：后端已支持 harmony 平台（FantasyNetworkCN/NekoMusic#107 已合入并部署） */
  static readonly clientHeader: string = "harmony+" + APIConfig.clientVersion;

  /** 官方客户端 UA：严格格式 NekoMusic-<平台>/<版本>，后端据此识别为官方客户端 */
  static readonly userAgent: string = "NekoMusic-harmony/" + APIConfig.clientVersion;

  /** 浏览器指纹头（仅伪装场景使用） */
  static readonly browserUserAgent: string =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36";

  static clientHeaders(): Record<string, string> {
    const headers: Record<string, string> = {
      "User-Agent": APIConfig.userAgent,
      "X-Neko-Client": APIConfig.clientHeader,
      "Accept": "application/json, text/plain, */*",
      "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
      "Accept-Encoding": "identity",
      "X-Requested-With": "XMLHttpRequest",
      "sec-ch-ua": "\"Chromium\";v=\"141\", \"Not?A_Brand\";v=\"24\"",
      "sec-ch-ua-mobile": "?0",
      "sec-ch-ua-platform": "\"macOS\"",
      "Referer": APIConfig.baseURL + "/"
    };
    return headers;
  }

  /** 需要 nonce 的接口白名单（这些不需要） */
  static requiresNonce(path: string): boolean {
    const whitelist: string[] = [
      "/api/replay/",
      "/api/music/cover/",
      "/api/user/avatar/",
      "/media/",
      "/assets/",
      "/loser/"
    ];
    for (const prefix of whitelist) {
      if (path.startsWith(prefix)) {
        return false;
      }
    }
    const exact: string[] = ["/api/music/latest", "/api/music/ranking"];
    for (const p of exact) {
      if (path === p) {
        return false;
      }
    }
    return true;
  }

  // MARK: - 防重放
  static replayChallengeURL(): string {
    return APIConfig.baseURL + "/api/replay/challenge";
  }

  static replayNonceURL(): string {
    return APIConfig.baseURL + "/api/replay/nonce";
  }

  // MARK: - 音乐
  static musicLatestURL(): string {
    return APIConfig.baseURL + "/api/music/latest";
  }

  static musicRankingURL(): string {
    return APIConfig.baseURL + "/api/music/ranking";
  }

  static musicSearchURL(): string {
    return APIConfig.baseURL + "/api/music/search";
  }

  static musicFileURL(id: number, quality: string = "hq"): string {
    return APIConfig.baseURL + "/api/music/file/" + id + "?quality=" + quality;
  }

  static musicCoverURL(id: number): string {
    return APIConfig.baseURL + "/api/music/cover/" + id;
  }

  static musicInfoURL(id: number): string {
    return APIConfig.baseURL + "/api/music/info/" + id;
  }

  static lyricsURL(id: number): string {
    return APIConfig.baseURL + "/api/music/lyrics/" + id;
  }

  // MARK: - 用户
  static myPlaylistsURL(): string {
    return APIConfig.baseURL + '/api/user/playlists';
  }

  static playlistCreateURL(): string {
    return APIConfig.baseURL + '/api/user/playlist/create';
  }

  static playlistDeleteURL(): string {
    return APIConfig.baseURL + '/api/user/playlist/delete';
  }

  static playlistMusicURL(playlistId: number): string {
    return APIConfig.baseURL + '/api/user/playlist/music/' + playlistId;
  }

  static playlistAddMusicURL(): string {
    return APIConfig.baseURL + '/api/user/playlist/music/add';
  }

  static playlistRemoveMusicURL(): string {
    return APIConfig.baseURL + '/api/user/playlist/music/remove';
  }

  static favoritesURL(): string {
    return APIConfig.baseURL + "/api/user/favorites";
  }

  static removeFavoriteURL(musicId: number): string {
    return APIConfig.baseURL + "/api/user/favorites/" + musicId;
  }

  static loginURL(): string {
    return APIConfig.baseURL + "/api/user/login";
  }

  static dailyRecommendURL(): string {
    return APIConfig.baseURL + "/api/user/recommendations/daily";
  }

  /** 把相对路径补成完整地址 */
  static buildFullURL(path: string): string {
    if (path.startsWith("http")) {
      return path;
    }
    if (path.startsWith("/")) {
      return APIConfig.baseURL + path;
    }
    return APIConfig.baseURL + "/" + path;
  }
}
