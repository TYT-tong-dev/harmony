// MainPage.ets
import { TabItem, NotificationType } from '../common/Types';
import { HomePage } from './HomePage';
import { DiscoverPage } from './DiscoverPage';
import { MessagePage } from './MessagePage';
import { ProfilePage } from './ProfilePage';
import router from '@ohos.router';

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
      name: '消息',
      icon: $r('app.media.message'),
      activeIcon: $r('app.media.message_active'),
      page: 'message'
    },
    {
      index: 3,
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
        } else if (this.currentIndex === 2) {
          MessagePage()
        } else if (this.currentIndex === 3) {
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

  @Builder
  BottomTabBar() {
    Row() {
      ForEach(this.tabItems, (item: TabItem, index: number) => {
        Column() {
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
        .width('25%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.currentIndex = index;
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