// NotificationPage.ets - 通知列表页面
import { AppNotification, NotificationType, ApiResponse, NotificationListResponse } from '../common/Types';
import { ApiUtils, ToastUtils } from '../common/Utils';
import router from '@ohos.router';

// 请求类
class MarkReadRequest {
  notification_id: number = 0;
}

class EmptyRequest {}

class DeleteRequest {
  notification_id: number = 0;
}

@Entry
@Component
export struct NotificationPage {
  @State notifications: AppNotification[] = [];
  @State loading: boolean = false;
  @State unreadCount: number = 0;

  aboutToAppear() {
    this.loadNotifications();
  }

  // 加载通知列表
  private async loadNotifications(): Promise<void> {
    this.loading = true;
    try {
      const response: ApiResponse = await ApiUtils.get('/notifications/list?limit=50');
      if (response.statusCode === 200 && response.data) {
        const data = response.data as NotificationListResponse;
        this.notifications = data.notifications || [];
        this.unreadCount = data.unread_count;
      }
    } catch (error) {
      ToastUtils.showToast('加载通知失败');
      console.error('加载通知失败:' + JSON.stringify(error));
    } finally {
      this.loading = false;
    }
  }

  // 标记单条已读
  private async markAsRead(notification: AppNotification): Promise<void> {
    if (notification.is_read) return;
    try {
      const request = new MarkReadRequest();
      request.notification_id = notification.id;
      await ApiUtils.post('/notifications/read', request);
      notification.is_read = true;
      this.unreadCount = Math.max(0, this.unreadCount - 1);
    } catch (error) {
      console.error('标记已读失败:' + JSON.stringify(error));
    }
  }

  // 全部标记已读
  private async markAllAsRead(): Promise<void> {
    try {
      const request = new EmptyRequest();
      await ApiUtils.post('/notifications/read_all', request);
      this.notifications.forEach((n: AppNotification) => n.is_read = true);
      this.unreadCount = 0;
      ToastUtils.showToast('已全部标记为已读');
    } catch (error) {
      ToastUtils.showToast('操作失败');
    }
  }

  // 删除通知
  private async deleteNotification(notification: AppNotification): Promise<void> {
    try {
      const request = new DeleteRequest();
      request.notification_id = notification.id;
      await ApiUtils.post('/notifications/delete', request);
      const index = this.notifications.indexOf(notification);
      if (index > -1) {
        this.notifications.splice(index, 1);
      }
      ToastUtils.showToast('已删除');
    } catch (error) {
      ToastUtils.showToast('删除失败');
    }
  }

  // 点击通知跳转
  private handleNotificationClick(notification: AppNotification): void {
    this.markAsRead(notification);
    if (notification.type === 'message' && notification.related_id) {
      router.pushUrl({ url: 'pages/MessagePage', params: { conversationId: notification.related_id } });
    } else if (notification.type === 'order' && notification.related_id) {
      router.pushUrl({ url: 'pages/OrderPage', params: { orderId: notification.related_id } });
    }
  }

  // 获取通知图标
  private getNotificationIcon(type: string): Resource {
    switch (type) {
      case 'order': return $r('app.media.shopping_cart');      // 使用购物车图标代替订单
      case 'message': return $r('app.media.message');
      case 'follow': return $r('app.media.ic_user_avatar');    // 使用用户头像图标
      default: return $r('app.media.message');                 // 默认使用消息图标
    }
  }

  // 获取类型文字
  private getTypeText(type: string): string {
    switch (type) {
      case 'order': return '订单';
      case 'message': return '消息';
      case 'follow': return '关注';
      default: return '通知';
    }
  }

  // 格式化时间
  private formatTime(timeStr: string): string {
    const date = new Date(timeStr);
    const now = new Date();
    const diff = now.getTime() - date.getTime();
    if (diff < 60000) return '刚刚';
    if (diff < 3600000) return Math.floor(diff / 60000) + '分钟前';
    if (diff < 86400000) return Math.floor(diff / 3600000) + '小时前';
    return `${date.getMonth() + 1}/${date.getDate()}`;
  }

  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Image($r('app.media.back_icon'))
          .width(24).height(24)
          .onClick(() => router.back())
        Text('消息通知')
          .fontSize(18).fontWeight(FontWeight.Bold)
          .layoutWeight(1).textAlign(TextAlign.Center)
        if (this.unreadCount > 0) {
          Text('全部已读')
            .fontSize(14).fontColor('#007AFF')
            .onClick(() => this.markAllAsRead())
        } else {
          Text('').width(60)
        }
      }
      .width('100%').height(56).padding({ left: 16, right: 16 })
      .backgroundColor(Color.White)

      // 通知列表
      if (this.loading) {
        LoadingProgress().width(40).height(40).margin({ top: 100 })
      } else if (this.notifications.length === 0) {
        Column() {
          Image($r('app.media.empty')).width(120).height(120).opacity(0.5)
          Text('暂无通知').fontSize(14).fontColor('#999').margin({ top: 16 })
        }.margin({ top: 100 })
      } else {
        List() {
          ForEach(this.notifications, (item: AppNotification) => {
            ListItem() {
              this.NotificationItem(item)
            }.swipeAction({ end: this.DeleteButton(item) })
          })
        }.width('100%').layoutWeight(1)
      }
    }.width('100%').height('100%').backgroundColor('#F5F5F5')
  }

  @Builder
  NotificationItem(item: AppNotification) {
    Row() {
      // 未读指示器
      if (!item.is_read) {
        Circle().width(8).height(8).fill('#FF4D4F').margin({ right: 8 })
      } else {
        Blank().width(16)
      }

      // 图标
      Image(this.getNotificationIcon(item.type))
        .width(40).height(40)
        .borderRadius(20)
        .backgroundColor('#F0F0F0')
        .margin({ right: 12 })

      // 内容
      Column() {
        Row() {
          Text(item.title)
            .fontSize(15)
            .fontWeight(item.is_read ? FontWeight.Normal : FontWeight.Bold)
            .fontColor(item.is_read ? '#666' : '#333')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Text(this.formatTime(item.created_at))
            .fontSize(12).fontColor('#999')
        }.width('100%')

        Text(item.content)
          .fontSize(13).fontColor('#666')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 4 })

        // 类型标签
        Text(this.getTypeText(item.type))
          .fontSize(10)
          .fontColor('#999')
          .backgroundColor('#F5F5F5')
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .borderRadius(4)
          .margin({ top: 6 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .margin({ bottom: 1 })
    .onClick(() => this.handleNotificationClick(item))
  }

  @Builder
  DeleteButton(item: AppNotification) {
    Button('删除')
      .width(80)
      .height('100%')
      .backgroundColor('#FF4D4F')
      .fontColor(Color.White)
      .onClick(() => this.deleteNotification(item))
  }
}

