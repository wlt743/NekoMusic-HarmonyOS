import { preferences } from "@kit.ArkData";
import { hilog } from "@kit.PerformanceAnalysisKit";
import { common } from "@kit.AbilityKit";
import { HttpClient } from "./HttpClient";
import { APIConfig } from "./APIConfig";

export interface NekoUser {
  id: number;
  email: string;
  nickname: string;
  avatar?: string;
}

interface LoginData {
  token: string;
  user: NekoUser;
}

interface LoginResponse {
  success: boolean;
  message: string;
  data?: LoginData;
}

/** 账号登录 + token 持久化 */
export class AuthService {
  private static store: preferences.Preferences | undefined = undefined;
  private static readonly TOKEN_KEY: string = "auth_token";
  private static readonly USER_KEY: string = "auth_user";

  static async init(context: common.UIAbilityContext): Promise<void> {
    if (AuthService.store !== undefined) {
      return;
    }
    AuthService.store = await preferences.getPreferences(context, "nekomusic_auth");
    const token = await AuthService.store.get(AuthService.TOKEN_KEY, "");
    const userJson = await AuthService.store.get(AuthService.USER_KEY, "");
    const tokenValue: string = typeof token === "string" ? token : "";
    hilog.info(0x0000, "NekoAuth", "init token length=%{public}d", tokenValue.length);
    AppStorage.setOrCreate<string>("authToken", tokenValue);
    if (tokenValue.length > 0) {
      // setOrCreate 在 key 已存在时不覆盖，这里强制同步一次
      AppStorage.set<string>("authToken", tokenValue);
    }
    if (typeof userJson === "string" && userJson.length > 0) {
      try {
        AppStorage.setOrCreate<NekoUser>("authUser", JSON.parse(userJson) as NekoUser);
      } catch (error) {
        AppStorage.setOrCreate<NekoUser | undefined>("authUser", undefined);
      }
    }
  }

  static token(): string {
    return AppStorage.get<string>("authToken") ?? "";
  }

  static isLoggedIn(): boolean {
    return AuthService.token().length > 0;
  }

  static async login(email: string, password: string): Promise<string> {
    const body: string = JSON.stringify({ email: email, password: password });
    const text: string = await HttpClient.post(APIConfig.loginURL(), body);
    const json: LoginResponse = JSON.parse(text) as LoginResponse;
    if (!json.success || json.data === undefined) {
      throw new Error(json.message.length > 0 ? json.message : "登录失败");
    }
    await AuthService.saveSession(json.data.token, json.data.user);
    return json.data.token;
  }

  static async logout(): Promise<void> {
    AppStorage.set<string>("authToken", "");
    AppStorage.set<boolean>("favoriteIdsLoaded", false);
    if (AuthService.store !== undefined) {
      await AuthService.store.put(AuthService.TOKEN_KEY, "");
      await AuthService.store.put(AuthService.USER_KEY, "");
      await AuthService.store.flush();
    }
  }

  private static async saveSession(token: string, user: NekoUser): Promise<void> {
    AppStorage.set<string>("authToken", token);
    AppStorage.set<NekoUser>("authUser", user);
    if (AuthService.store !== undefined) {
      await AuthService.store.put(AuthService.TOKEN_KEY, token);
      await AuthService.store.put(AuthService.USER_KEY, JSON.stringify(user));
      await AuthService.store.flush();
    }
  }
}
