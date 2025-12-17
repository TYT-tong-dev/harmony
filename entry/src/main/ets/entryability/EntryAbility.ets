import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { AppMode, NotificationType } from '../common/Types';
import { AppModeManager, DeepLinkUtils } from '../common/Utils';

const DOMAIN = 0x0000;

// 通知跳转参数
class NotificationExtra {
  conversationId: string = '';
  orderId: string = '';
  tableId: string = '';
}

class NotificationJumpParams {
  type: string = '';
  id: string = '';
  extra: NotificationExtra = new NotificationExtra();
}

export default class EntryAbility extends UIAbility {
  private pendingNotification: NotificationJumpParams | null = null;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 设置颜色模式
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);

    // 初始化应用数据
    AppStorage.setOrCreate('isLoggedIn', false);
    AppStorage.setOrCreate('userToken', '');
    AppStorage.setOrCreate('userInfo', '{}');
    AppStorage.setOrCreate('cartItems', '[]');
    AppModeManager.ensureInitialized();
    if (!AppStorage.get<AppMode>('appMode')) {
      AppStorage.setOrCreate<AppMode>('appMode', AppMode.MERCHANT);
    }
    this.applyIncomingMode(want);
    // 处理通知点击跳转
    this.handleNotificationIntent(want);

    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
  onNewWant(want: Want): void {
    hilog.info(DOMAIN, 'testTag', 'Ability onNewWant');
    this.applyIncomingMode(want);
    // 处理通知点击跳转
    this.handleNotificationIntent(want);
  }

  // 处理通知点击意图
  private handleNotificationIntent(want: Want): void {
    if (!want || !want.parameters) {
      return;
    }
    const params = want.parameters as Record<string, Object>;
    const notificationType = params['notificationType'] as string;
    const notificationId = params['notificationId'] as string;

    if (notificationType && notificationId) {
      hilog.info(DOMAIN, 'testTag', 'Notification intent: type=%{public}s, id=%{public}s', notificationType, notificationId);

      // 存储通知参数供页面使用
      const extra = new NotificationExtra();
      extra.conversationId = (params['conversationId'] as string) || '';
      extra.orderId = (params['orderId'] as string) || '';
      extra.tableId = (params['tableId'] as string) || '';

      const jumpParams = new NotificationJumpParams();
      jumpParams.type = notificationType;
      jumpParams.id = notificationId;
      jumpParams.extra = extra;
      this.pendingNotification = jumpParams;

      // 将跳转信息存储到 AppStorage 供页面消费
      AppStorage.setOrCreate('pendingNotification', JSON.stringify(this.pendingNotification));
    }
  }

  private applyIncomingMode(want?: Want): void {
    if (!want) {
      return;
    }
    const params = want.parameters as Record<string, Object> | undefined;
    const rawMode = params?.['mode'] ? String(params?.['mode']) : undefined;
    
    // 从参数中获取桌号
    const tableId = params?.['tableId'] as string | undefined;
    
    if (rawMode === AppMode.CUSTOMER || tableId) {
      const payload = DeepLinkUtils.resolveFromWantParameters(params) || DeepLinkUtils.resolveFromUri(want.uri);
      const finalTableId = tableId || payload?.tableId;
      if (finalTableId) {
        AppStorage.setOrCreate('currentTableId', finalTableId);
      }
      AppModeManager.setMode(AppMode.CUSTOMER, { tableId: finalTableId, silent: true });
      return;
    }
    if (rawMode === AppMode.MERCHANT) {
      AppModeManager.setMode(AppMode.MERCHANT, { silent: true });
      return;
    }
    const linkPayload = DeepLinkUtils.resolveFromUri(want.uri);
    if (linkPayload?.mode === AppMode.CUSTOMER) {
      if (linkPayload.tableId) {
        AppStorage.setOrCreate('currentTableId', linkPayload.tableId);
      }
      AppModeManager.setMode(AppMode.CUSTOMER, { tableId: linkPayload.tableId, silent: true });
    }
  }
}