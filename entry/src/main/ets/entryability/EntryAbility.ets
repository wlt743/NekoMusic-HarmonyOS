import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { WallpaperService } from '../services/WallpaperService';
import { AuthService } from '../services/AuthService';
import { PlayerSessionService } from '../services/PlayerSessionService';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    // 沉浸式窗口：状态栏 / 导航条透明，内容延伸到全屏
    const mainWindow = windowStage.getMainWindowSync();
    mainWindow.setWindowLayoutFullScreen(true).then(() => {
      hilog.info(DOMAIN, 'testTag', 'fullscreen ok');
    }).catch((error: Error) => {
      hilog.error(DOMAIN, 'testTag', 'fullscreen failed: %{public}s', error.message);
    });
    mainWindow.setWindowSystemBarProperties({
      statusBarColor: '#00000000',
      navigationBarColor: '#00000000',
      statusBarContentColor: '#000000',
      navigationBarContentColor: '#000000'
    }).catch((error: Error) => {
      hilog.error(DOMAIN, 'testTag', 'systemBar failed: %{public}s', error.message);
    });

    // 服务初始化：登录态 + 壁纸
    PlayerSessionService.init(this.context).catch((error: Error) => {
      hilog.error(DOMAIN, 'testTag', 'avsession init failed: %{public}s', error.message);
    });
    AuthService.init(this.context).then(() => {
      hilog.info(DOMAIN, 'testTag', 'auth init ok');
    }).catch((error: Error) => {
      hilog.error(DOMAIN, 'testTag', 'auth init failed: %{public}s', error.message);
    });
    WallpaperService.init(this.context).catch((error: Error) => {
      hilog.error(DOMAIN, 'testTag', 'wallpaper init failed: %{public}s', error.message);
    });

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });

    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
