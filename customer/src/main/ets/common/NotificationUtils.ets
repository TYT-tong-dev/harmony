// NotificationUtils.ets - 顾客端通知工具类
import notificationManager from '@ohos.notificationManager';
import { BusinessError } from '@ohos.base';
import wantAgent, { WantAgent } from '@ohos.app.ability.wantAgent';
import vibrator from '@ohos.vibrator';

// 通知类型
export enum NotificationType {
  ORDER_STATUS = 'order_status',  // 订单状态通知
  SYSTEM = 'system'               // 系统通知
}

// 通知配置
export interface NotificationConfig {
  enableVibrate: boolean;
  enableSound: boolean;
}

// 通知数据
export interface NotificationData {
  id: number;
  type: NotificationType;
  title: string;
  content: string;
  extra?: Record<string, string>;
  config?: NotificationConfig;
}

// 震动模式
const VIBRATE_PATTERNS: Record<string, number> = {
  order_status: 300,
  system: 200
};

// 顾客端通知工具类
export class NotificationUtils {
  private static notificationId: number = 1;
  private static defaultConfig: NotificationConfig = {
    enableVibrate: true,
    enableSound: true
  };

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
      const duration = VIBRATE_PATTERNS[type] || 200;
      await vibrator.startVibration({
        type: 'time',
        duration: duration
      }, {
        id: 0,
        usage: 'notification'
      });
    } catch (error) {
      const err = error as BusinessError;
      console.error('[NotificationUtils] 震动触发失败: ' + err.message);
    }
  }

  // 发送本地通知
  static async sendNotification(data: NotificationData): Promise<boolean> {
    try {
      const config = data.config || NotificationUtils.defaultConfig;

      // 创建点击通知后的跳转意图
      const wantAgentInfo: wantAgent.WantAgentInfo = {
        wants: [
          {
            bundleName: 'com.example.h',
            abilityName: 'CustomerAbility',
            parameters: {
              notificationType: data.type,
              notificationId: data.id.toString(),
              ...data.extra
            }
          }
        ],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };

      const agent: WantAgent = await wantAgent.getWantAgent(wantAgentInfo);

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
    return this.sendNotification({
      id: orderId,
      type: NotificationType.ORDER_STATUS,
      title: '📦 订单状态更新',
      content: message,
      extra: {
        orderId: orderId.toString(),
        status: status
      }
    });
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

