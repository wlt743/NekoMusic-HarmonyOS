import { media } from "@kit.MediaKit";
import { hilog } from "@kit.PerformanceAnalysisKit";

/**
 * 播放器全局引用。
 * ArkTS 里不同页面拿到的 class 单例不一定是同一个实例（实测 toggle 时 player 为 undefined），
 * 但模块级变量在所有 import 方之间共享，因此用模块级变量持有 AVPlayer。
 */
let globalPlayer: media.AVPlayer | undefined = undefined;

export function registerPlayer(player: media.AVPlayer): void {
  globalPlayer = player;
  hilog.info(0x0000, "NekoCore", "player registered");
}

export function getPlayer(): media.AVPlayer | undefined {
  return globalPlayer;
}

export function currentPlayerState(): string {
  const player: media.AVPlayer | undefined = globalPlayer;
  if (player === undefined) {
    return "none";
  }
  return player.state as string;
}

/** 切换播放，返回切换后是否在播放 */
export async function togglePlay(): Promise<boolean> {
  const player: media.AVPlayer | undefined = globalPlayer;
  if (player === undefined) {
    hilog.info(0x0000, "NekoCore", "togglePlay: no player");
    return false;
  }
  const state: string = player.state as string;
  hilog.info(0x0000, "NekoCore", "togglePlay: state=%{public}s", state);
  try {
    if (state === "playing") {
      await player.pause();
      return false;
    }
    await player.play();
    return true;
  } catch (error) {
    hilog.error(0x0000, "NekoCore", "togglePlay failed");
    return false;
  }
}
