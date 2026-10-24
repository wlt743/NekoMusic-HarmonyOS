import { HttpClient } from './HttpClient';
import { AuthService } from './AuthService';

export interface NotificationItem {
  id: number;
  title: string;
  content: string;
  createdAt: number;
  read: boolean;
}

export class NotificationService {
  static unreadCount(): number {
    return AppStorage.get<number>('unreadCount') ?? 0;
  }

  static async list(): Promise<NotificationItem[]> {
    if (!AuthService.isLoggedIn()) {
      AppStorage.set<number>('unreadCount', 0);
      return [];
    }
    const text: string = await HttpClient.get(
      'https://music.nekocore.cn/api/user/notifications?limit=50', AuthService.token());
    const json = JSON.parse(text) as Record<string, Object>;
    const data = json.data as Record<string, Object> | undefined;
    const result: NotificationItem[] = [];
    if (data !== undefined) {
      const unread = data.unread;
      if (typeof unread === 'number') {
        AppStorage.set<number>('unreadCount', unread);
      }
      const items = data.items as Record<string, Object>[] | undefined;
      if (items !== undefined) {
        for (const item of items) {
          const id = item.id;
          const title = item.title;
          const content = item.content;
          if (typeof id !== 'number') {
            continue;
          }
          result.push({
            id: id,
            title: typeof title === 'string' ? title : '',
            content: typeof content === 'string' ? content : '',
            createdAt: typeof item.createdAt === 'number' ? item.createdAt : 0,
            read: item.read === true
          });
        }
      }
    }
    return result;
  }

  static async markRead(id: number): Promise<void> {
    if (!AuthService.isLoggedIn()) {
      return;
    }
    await HttpClient.post('https://music.nekocore.cn/api/user/notifications/read',
      JSON.stringify({ id: id }), AuthService.token());
    const current = NotificationService.unreadCount();
    if (current > 0) {
      AppStorage.set<number>('unreadCount', current - 1);
    }
  }
}
