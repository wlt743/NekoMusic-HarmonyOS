import { HttpClient } from './HttpClient';
import { AuthService } from './AuthService';
import { hilog } from '@kit.PerformanceAnalysisKit';

/** 评论 */
export interface CommentItem {
  id: number;
  content: string;
  createdAt: number;
  userId: number;
  nickname: string;
  parentId?: number;
  likeCount?: number;
}

interface CommentBody {
  musicId: number;
  content: string;
  parentId?: number;
}

export class CommentService {
  static async list(musicId: number, page: number = 1): Promise<CommentItem[]> {
    const url: string = 'https://music.nekocore.cn/api/comments?musicId=' + musicId + '&page=' + page + '&pageSize=30';
    const text: string = await HttpClient.get(url);
    const json = JSON.parse(text) as Record<string, Object>;
    const comments = json.comments as Record<string, Object>[] | undefined;
    const result: CommentItem[] = [];
    if (comments !== undefined) {
      for (const c of comments) {
        const id = c.id;
        const content = c.content;
        if (typeof id !== 'number' || typeof content !== 'string') {
          continue;
        }
        const user = c.user as Record<string, Object> | undefined;
        let userId: number = 0;
        let nickname: string = '';
        if (user !== undefined) {
          const uid = user.id;
          const nick = user.nickname;
          if (typeof uid === 'number') {
            userId = uid;
          }
          if (typeof nick === 'string') {
            nickname = nick;
          }
        }
        result.push({
          id: id,
          content: content,
          createdAt: typeof c.createdAt === 'number' ? c.createdAt : 0,
          userId: userId,
          nickname: nickname
        });
      }
    }
    return result;
  }

  static async post(musicId: number, content: string, parentId?: number): Promise<void> {
    if (!AuthService.isLoggedIn()) {
      throw new Error('请先登录');
    }
    const body: CommentBody = { musicId: musicId, content: content };
    if (parentId !== undefined) {
      body.parentId = parentId;
    }
    await HttpClient.post('https://music.nekocore.cn/api/comments', JSON.stringify(body), AuthService.token());
  }
}
