// MainPage.ets
import { TabItem, NotificationType, AppMode } from '../common/Types';
import { HomePage } from './HomePage';
import { DiscoverPage } from './DiscoverPage';
import { MessagePage } from './MessagePage';
import { ProfilePage } from './ProfilePage';
import { AppModeManager } from '../common/Utils';
import router from '@ohos.router';
import { scanBarcode } from '@kit.ScanKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import promptAction from '@ohos.promptAction';

const DOMAIN = 0x0000;

// MainPage.ets
export { DiscoverPage } from './DiscoverPage';

// 通知跳转额外参数
class NotificationExtraData {
  conversationId: string = '';
  orderId: string = '';
  tableId: string = '';
}

// 通知跳转参数
class PendingNotification {
  type: string = '';
  id: string = '';
  extra: NotificationExtraData = new NotificationExtraData();
}

@Entry
@Component
struct MainPage {
  @State currentIndex: number = 0;
  @StorageLink('pendingNotification') pendingNotificationStr: string = '';

  aboutToAppear() {
    // 顾客端默认设置为顾客模式
    AppModeManager.setMode(AppMode.CUSTOMER);
    // 处理通知点击跳转
    this.handlePendingNotification();
  }

  // 处理待处理的通知跳转
  private handlePendingNotification(): void {
    if (!this.pendingNotificationStr) {
      return;
    }
    try {
      const notification: PendingNotification = JSON.parse(this.pendingNotificationStr);
      // 清除待处理通知
      AppStorage.setOrCreate('pendingNotification', '');

      // 根据通知类型跳转
      if (notification.type === 'message') {
        this.currentIndex = 2; // 切换到消息Tab
        if (notification.extra?.conversationId) {
          setTimeout(() => {
            router.pushUrl({
              url: 'pages/ChatPage',
              params: { conversationId: parseInt(notification.extra?.conversationId || '0') }
            });
          }, 300);
        }
      } else if (notification.type === 'order') {
        this.currentIndex = 0; // 切换到首页
        // 订单通知可以在首页显示
      }
    } catch (error) {
      console.error('解析通知参数失败:' + JSON.stringify(error));
    }
  }

  // 底部导航数据
  private tabItems: TabItem[] = [
    {
      index: 0,
      name: '首页',
      icon: $r('app.media.home'),
      activeIcon: $r('app.media.home_active'),
      page: 'home'
    },
    {
      index: 1,
      name: '发现',
      icon: $r('app.media.discover'),
      activeIcon: $r('app.media.discover_active'),
      page: 'discover'
    },
    {
      index: 2,
      name: '扫码',
      icon: $r('app.media.qr_code'),
      activeIcon: $r('app.media.qr_code'),
      page: 'scan'
    },
    {
      index: 3,
      name: '消息',
      icon: $r('app.media.message'),
      activeIcon: $r('app.media.message_active'),
      page: 'message'
    },
    {
      index: 4,
      name: '我的',
      icon: $r('app.media.ic_user_avatar'),
      activeIcon: $r('app.media.ic_user_avatar_active'),
      page: 'profile'
    }
  ]

  build() {
    Column() { // 将底部导航栏放到页面底部：修改为纵向布局
      Column() {
        // 主要内容区域
        if (this.currentIndex === 0) {
          HomePage()
        } else if (this.currentIndex === 1) {
          DiscoverPage()
        } else if (this.currentIndex === 3) {
          MessagePage()
        } else if (this.currentIndex === 4) {
          ProfilePage()
        }
      }
      .width('100%')
      .layoutWeight(1)

      // 底部导航栏
      this.BottomTabBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  // 扫码点餐功能
  private async startScanOrder(): Promise<void> {
    try {
      hilog.info(DOMAIN, 'ScanOrder', '开始扫码点餐');
      
      const result = await scanBarcode.startScanForResult(getContext(this));
      
      if (result && result.originalValue) {
        hilog.info(DOMAIN, 'ScanOrder', '扫码结果: %{public}s', result.originalValue);
        
        // 解析二维码内容，获取桌号
        const tableId = this.parseTableIdFromQR(result.originalValue);
        
        if (tableId) {
          // 保存桌号
          AppStorage.setOrCreate('currentTableId', tableId);
          promptAction.showToast({
            message: `已入座 ${tableId} 号桌`,
            duration: 2000
          });
          // 切换到首页开始点餐
          this.currentIndex = 0;
        } else {
          promptAction.showToast({
            message: '无效的桌号二维码',
            duration: 2000
          });
        }
      }
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(DOMAIN, 'ScanOrder', '扫码失败: code=%{public}d, message=%{public}s', err.code, err.message);
      
      if (err.code === 1000500001) {
        promptAction.showToast({
          message: '已取消扫码',
          duration: 1500
        });
      } else {
        promptAction.showToast({
          message: '扫码失败，请重试',
          duration: 2000
        });
      }
    }
  }

  // 解析二维码中的桌号
  private parseTableIdFromQR(qrContent: string): string {
    // 支持多种格式：
    // 1. 直接桌号: A01, B02
    // 2. URL格式: ...?tableId=A01
    // 3. JSON格式: {"tableId": "A01"}
    
    // 尝试URL参数格式
    if (qrContent.includes('tableId=')) {
      const match = qrContent.match(/tableId=([^&]+)/);
      if (match && match[1]) {
        return decodeURIComponent(match[1]);
      }
    }
    
    // 尝试JSON格式
    try {
      const json = JSON.parse(qrContent) as Record<string, string>;
      if (json.tableId) {
        return json.tableId;
      }
    } catch (e) {
      // 不是JSON格式
    }
    
    // 直接作为桌号（如果是简单的字母数字组合）
    if (/^[A-Za-z0-9]+$/.test(qrContent) && qrContent.length <= 10) {
      return qrContent.toUpperCase();
    }
    
    return '';
  }

  @Builder
  BottomTabBar() {
    Row() {
      ForEach(this.tabItems, (item: TabItem, index: number) => {
        Column() {
          // 扫码按钮特殊样式
          if (item.page === 'scan') {
            Column() {
              Image(item.icon)
                .width(28)
                .height(28)
                .objectFit(ImageFit.Contain)
                .fillColor('#FFFFFF')
            }
            .width(50)
            .height(50)
            .borderRadius(25)
            .backgroundColor('#007DFF')
            .justifyContent(FlexAlign.Center)
            .shadow({
              radius: 8,
              color: '#40007DFF',
              offsetX: 0,
              offsetY: 2
            })
            .margin({ top: -15 })
          } else {
            // 图标
            Image(this.currentIndex === index ? item.activeIcon : item.icon)
              .width(24)
              .height(24)
              .objectFit(ImageFit.Contain)

            // 标题
            Text(item.name)
              .fontSize(10)
              .fontColor(this.currentIndex === index ? '#007DFF' : '#666666')
              .margin({ top: 4 })
          }
        }
        .width('20%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          if (item.page === 'scan') {
            // 点击扫码按钮，启动扫码
            this.startScanOrder();
          } else {
            this.currentIndex = index;
          }
        })
      })
    }
    .width('100%')
    .height(56)
    .backgroundColor('#FFFFFF')
    .shadow({
      radius: 8,
      color: '#1A000000',
      offsetX: 0,
      offsetY: -2
    })
  }

  @Builder
  TabContent(index: number) {
    if (this.currentIndex === 0) {
      // 首页
      // ShopHomePage() 或其他页面
    } else if (this.currentIndex === 1) {
      // 发现页
      DiscoverPage()
    } else if (this.currentIndex === 2) {
      // 消息页
      // MessagePage()
    } else if (this.currentIndex === 3) {
      // 我的页面
      // ProfilePage()
    }
  }
}