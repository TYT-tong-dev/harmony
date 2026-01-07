// NotificationUtils.ets - 鸿蒙通知工具类
import notificationManager from '@ohos.notificationManager';
import { BusinessError } from '@ohos.base';
import wantAgent, { WantAgent } from '@ohos.app.ability.wantAgent';
import vibrator from '@ohos.vibrator';
import { Want } from '@kit.AbilityKit';
import { NotificationType } from './Types';

// 通知额外数据
export class NotificationExtraData {
  conversationId: string = '';
  orderId: string = '';
  tableId: string = '';
  senderId: string = '';

  constructor(data?: Partial<NotificationExtraData>) {
    if (data) {
      if (data.conversationId !== undefined) this.conversationId = data.conversationId;
      if (data.orderId !== undefined) this.orderId = data.orderId;
      if (data.tableId !== undefined) this.tableId = data.tableId;
      if (data.senderId !== undefined) this.senderId = data.senderId;
    }
  }
}

// 通知配置
export class NotificationConfig {
  enableVibrate: boolean = true;   // 是否震动
  enableSound: boolean = true;     // 是否响铃（系统默认）
}

// 通知数据
export class NotificationData {
  id: number = 0;
  type: NotificationType = NotificationType.ORDER;
  title: string = '';
  content: string = '';
  extra: NotificationExtraData | null = null;
  config: NotificationConfig | null = null;

  constructor(id: number, type: NotificationType, title: string, content: string) {
    this.id = id;
    this.type = type;
    this.title = title;
    this.content = content;
  }
}

// 震动时长
const VIBRATE_DURATION_ORDER: number = 500;    // 订单通知震动500ms
const VIBRATE_DURATION_MESSAGE: number = 200;  // 消息通知震动200ms

// 获取震动时长
function getVibrateDuration(type: NotificationType): number {
  if (type === NotificationType.ORDER) {
    return VIBRATE_DURATION_ORDER;
  }
  return VIBRATE_DURATION_MESSAGE;
}

// Want 参数类
class WantParameters {
  notificationType: string = '';
  notificationId: string = '';
  conversationId: string = '';
  orderId: string = '';
  tableId: string = '';
  senderId: string = '';

  // 转换为 Record<string, Object>
  toRecord(): Record<string, Object> {
    const jsonStr = JSON.stringify(this);
    const obj: Record<string, Object> = JSON.parse(jsonStr) as Record<string, Object>;
    return obj;
  }
}

// 通知工具类
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
      // 引导用户去设置开启通知
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
      const duration = getVibrateDuration(type);
      const effect: vibrator.VibrateTime = {
        type: 'time',
        duration: duration
      };
      const attr: vibrator.VibrateAttribute = {
        id: 0,
        usage: 'notification'
      };
      await vibrator.startVibration(effect, attr);
      console.info('[NotificationUtils] 震动触发成功');
    } catch (error) {
      const err = error as BusinessError;
      console.error('[NotificationUtils] 震动触发失败: ' + err.message);
    }
  }

  // 发送本地通知
  static async sendNotification(data: NotificationData): Promise<boolean> {
    try {
      const config = data.config || NotificationUtils.defaultConfig;

      // 构建跳转参数 - 使用类包装
      const params = new WantParameters();
      params.notificationType = data.type;
      params.notificationId = data.id.toString();
      // 合并额外参数
      if (data.extra) {
        if (data.extra.conversationId) {
          params.conversationId = data.extra.conversationId;
        }
        if (data.extra.orderId) {
          params.orderId = data.extra.orderId;
        }
        if (data.extra.tableId) {
          params.tableId = data.extra.tableId;
        }
        if (data.extra.senderId) {
          params.senderId = data.extra.senderId;
        }
      }

      // 创建 Want
      const want: Want = {
        bundleName: 'com.example.h',
        abilityName: 'EntryAbility',
        parameters: params.toRecord()
      };

      // 创建点击通知后的跳转意图
      const wantAgentInfo: wantAgent.WantAgentInfo = {
        wants: [want],
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
          ? notificationManager.SlotType.SOCIAL_COMMUNICATION  // 带声音
          : notificationManager.SlotType.CONTENT_INFORMATION   // 无声音
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

  // 发送订单通知（商家端使用）
  static async sendOrderNotification(
    orderId: number,
    tableId: string,
    totalAmount: number,
    itemCount: number
  ): Promise<boolean> {
    const notificationData = new NotificationData(
      orderId,
      NotificationType.ORDER,
      '📋 新订单提醒',
      `${tableId}号桌下单，${itemCount}件商品，¥${totalAmount.toFixed(2)}`
    );
    const extra = new NotificationExtraData();
    extra.orderId = orderId.toString();
    extra.tableId = tableId;
    notificationData.extra = extra;
    return NotificationUtils.sendNotification(notificationData);
  }

  // 发送消息通知
  static async sendMessageNotification(
    messageId: number,
    senderName: string,
    content: string,
    conversationId: number
  ): Promise<boolean> {
    // 截断过长的消息内容
    const displayContent = content.length > 50 ? content.substring(0, 50) + '...' : content;
    const notificationData = new NotificationData(
      messageId,
      NotificationType.MESSAGE,
      `💬 ${senderName}`,
      displayContent
    );
    const extra = new NotificationExtraData();
    extra.conversationId = conversationId.toString();
    extra.senderId = messageId.toString();
    notificationData.extra = extra;
    return NotificationUtils.sendNotification(notificationData);
  }

  // 取消通知
  static async cancelNotification(id: number): Promise<void> {
    try {
      await notificationManager.cancel(id);
      console.info('[NotificationUtils] 取消通知成功: ' + id);
    } catch (error) {
      const err = error as BusinessError;
      console.error('[NotificationUtils] 取消通知失败: ' + err.message);
    }
  }

  // 取消所有通知
  static async cancelAllNotifications(): Promise<void> {
    try {
      await notificationManager.cancelAll();
      console.info('[NotificationUtils] 取消所有通知成功');
    } catch (error) {
      const err = error as BusinessError;
      console.error('[NotificationUtils] 取消所有通知失败: ' + err.message);
    }
  }
}

