import { uiMaterial } from "@kit.ArkUI";

/**
 * 系统沉浸光感材质（API 26+）。
 * 低版本系统不支持时返回 undefined，组件退回普通样式。
 */
export class MaterialService {
  private static navMaterial: uiMaterial.ImmersiveMaterial | undefined = undefined;
  private static checked: boolean = false;
  private static supported: boolean = false;

  private static ensure(): boolean {
    if (!MaterialService.checked) {
      MaterialService.checked = true;
      try {
        MaterialService.supported = uiMaterial.isImmersiveMaterialSupported();
      } catch (error) {
        MaterialService.supported = false;
      }
    }
    return MaterialService.supported;
  }

  static navBar(): uiMaterial.ImmersiveMaterial | undefined {
    if (!MaterialService.ensure()) {
      return undefined;
    }
    if (MaterialService.navMaterial === undefined) {
      MaterialService.navMaterial = new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.THICK
      });
    }
    return MaterialService.navMaterial;
  }

  static header(): uiMaterial.ImmersiveMaterial | undefined {
    if (!MaterialService.ensure()) {
      return undefined;
    }
    return MaterialService.navBar();
  }
}
