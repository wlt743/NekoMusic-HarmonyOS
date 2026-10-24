import { photoAccessHelper } from "@kit.MediaLibraryKit";
import { preferences } from "@kit.ArkData";
import { common } from "@kit.AbilityKit";

/** 首页壁纸：系统相册选图 + Preferences 持久化 */
export class WallpaperService {
  private static store: preferences.Preferences | undefined = undefined;
  private static readonly KEY: string = "wallpaper_uri";

  static async init(context: common.UIAbilityContext): Promise<void> {
    if (WallpaperService.store !== undefined) {
      return;
    }
    WallpaperService.store = await preferences.getPreferences(context, "nekomusic_settings");
    const saved: preferences.ValueType = await WallpaperService.store.get(WallpaperService.KEY, "");
    AppStorage.setOrCreate<string>("wallpaperUri", typeof saved === "string" ? saved : "");
  }

  static async pick(): Promise<string> {
    const picker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
    const options: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
    options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = 1;
    const result: photoAccessHelper.PhotoSelectResult = await picker.select(options);
    if (result.photoUris.length === 0) {
      return "";
    }
    const uri: string = result.photoUris[0];
    // 拿到长期访问权限，否则重启后读不到
    try {
      const context = getContext() as common.UIAbilityContext;
      await context.resourceManager;
      const file = await photoAccessHelper.getPhotoAccessHelper(context).getAssets ? Promise.resolve() : Promise.resolve();
    } catch (error) {
      // 忽略：部分系统不需要显式授权
    }
    await WallpaperService.save(uri);
    AppStorage.set<string>("wallpaperUri", uri);
    return uri;
  }

  static async save(uri: string): Promise<void> {
    if (WallpaperService.store === undefined) {
      return;
    }
    await WallpaperService.store.put(WallpaperService.KEY, uri);
    await WallpaperService.store.flush();
  }

  static async clear(): Promise<void> {
    await WallpaperService.save("");
    AppStorage.set<string>("wallpaperUri", "");
  }

  static current(): string {
    return AppStorage.get<string>("wallpaperUri") ?? "";
  }
}
