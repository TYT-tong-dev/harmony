// NotificationUtils.ets - 顾客端通知工具类
import notificationManager from '@ohos.notificationManager';
import { BusinessError } from '@ohos.base';
import wantAgent, { WantAgent } from '@ohos.app.ability.wantAgent';
import vibrator from '@ohos.vibrator';
import Want from '@ohos.app.ability.Want';

// 通知类型
export enum NotificationType {
  ORDER_STATUS = 'order_status',  // 订单状态通知
  SYSTEM = 'system'               // 系统通知
}

// 通知配置
export class NotificationConfig {
  enableVibrate: boolean = true;
  enableSound: boolean = true;
}

// 通知数据
export class NotificationData {
  id: number = 0;
  type: NotificationType = NotificationType.SYSTEM;
  title: string = '';
  content: string = '';
  extra?: Record<string, string>;
  config?: NotificationConfig;
}

// 震动模式
class VibratePatterns {
  static readonly ORDER_STATUS: number = 300;
  static readonly SYSTEM: number = 200;

  static getDuration(type: NotificationType): number {
    if (type === NotificationType.ORDER_STATUS) {
      return VibratePatterns.ORDER_STATUS;
    }
    return VibratePatterns.SYSTEM;
  }
}

// 顾客端通知工具类
export class NotificationUtils {
  private static notificationId: number = 1;
  private static defaultConfig: NotificationConfig = new NotificationConfig();

  // 请求通知权限
  static async requestPermission(): Promise<boolean> {
    try {
      const isEnabled = await notificationManager.isNotificationEnabled();
      if (isEnabled) {
        console.info('[NotificationUtils] 通知权限已开启');
        return true;
      }
      console.info('[NotificationUtils] 需要用户手动开启通知权限');
      return false;
    } catch (error) {
      const err = error as BusinessError;
      console.error('[NotificationUtils] 检查通知权限失败: ' + err.message);
      return false;
    }
  }

  // 触发震动
  private static async triggerVibrate(type: NotificationType): Promise<void> {
    try {
      const duration = VibratePatterns.getDuration(type);
      const vibrateEffect: vibrator.VibrateTime = {
        type: 'time',
        duration: duration
      };
      const vibrateAttr: vibrator.VibrateAttribute = {
        id: 0,
        usage: 'notification'
      };
      await vibrator.startVibration(vibrateEffect, vibrateAttr);
    } catch (error) {
      const err = error as BusinessError;
      console.error('[NotificationUtils] 震动触发失败: ' + err.message);
    }
  }

  // 发送本地通知
  static async sendNotification(data: NotificationData): Promise<boolean> {
    try {
      const config = data.config || NotificationUtils.defaultConfig;

      // 构建参数对象
      const extraParams: Record<string, Object> = {};
      extraParams['notificationType'] = data.type as string;
      extraParams['notificationId'] = data.id.toString();
      if (data.extra) {
        const keys = Object.keys(data.extra);
        for (const key of keys) {
          extraParams[key] = data.extra[key] as Object;
        }
      }

      // 创建Want对象
      const want: Want = {
        bundleName: 'com.example.h',
        abilityName: 'CustomerAbility',
        parameters: extraParams
      };

      // 创建点击通知后的跳转意图
      const wantInfo: wantAgent.WantAgentInfo = {
        wants: [want],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };

      const agent: WantAgent = await wantAgent.getWantAgent(wantInfo);

      // 构建通知请求
      const notificationRequest: notificationManager.NotificationRequest = {
        id: NotificationUtils.notificationId++,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: data.title,
            text: data.content
          }
        },
        wantAgent: agent,
        notificationSlotType: config.enableSound
          ? notificationManager.SlotType.SOCIAL_COMMUNICATION
          : notificationManager.SlotType.CONTENT_INFORMATION
      };

      await notificationManager.publish(notificationRequest);
      console.info('[NotificationUtils] 发送通知成功: ' + data.title);

      // 触发震动
      if (config.enableVibrate) {
        await NotificationUtils.triggerVibrate(data.type);
      }

      return true;
    } catch (error) {
      const err = error as BusinessError;
      console.error('[NotificationUtils] 发送通知失败: ' + err.message);
      return false;
    }
  }

  // 发送订单状态通知
  static async sendOrderStatusNotification(
    orderId: number,
    status: string,
    message: string
  ): Promise<boolean> {
    const notificationData = new NotificationData();
    notificationData.id = orderId;
    notificationData.type = NotificationType.ORDER_STATUS;
    notificationData.title = '📦 订单状态更新';
    notificationData.content = message;
    const extraData: Record<string, string> = {};
    extraData['orderId'] = orderId.toString();
    extraData['status'] = status;
    notificationData.extra = extraData;
    return NotificationUtils.sendNotification(notificationData);
  }

  // 取消通知
  static async cancelNotification(id: number): Promise<void> {
    try {
      await notificationManager.cancel(id);
    } catch (error) {
      const err = error as BusinessError;
      console.error('[NotificationUtils] 取消通知失败: ' + err.message);
    }
  }
}

