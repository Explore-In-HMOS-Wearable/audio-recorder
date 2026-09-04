import { abilityAccessCtrl, common, Permissions, PermissionRequestResult } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

const NEEDED: Permissions[] = ['ohos.permission.MICROPHONE'];

export async function requestMicPermission(context: common.UIAbilityContext): Promise<boolean> {
  try {
    const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    const result: PermissionRequestResult =
      await atManager.requestPermissionsFromUser(context, NEEDED);
    for (let i = 0; i < result.authResults.length; i++) {
      if (result.authResults[i] !== 0) {
        return false;
      }
    }
    return true;
  } catch (err) {
    console.error(`[Permissions] failed: ${(err as BusinessError).message}`);
    return false;
  }
}