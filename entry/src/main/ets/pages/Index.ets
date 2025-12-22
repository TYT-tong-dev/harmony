import router from '@ohos.router';
import { AppMode } from '../common/Types';
import { AppModeManager } from '../common/Utils';

@Entry
@Component
struct Index {
  @State opacityValue: number = 0;
  @StorageLink('appMode') appMode: AppMode = AppMode.MERCHANT;
  @StorageLink('isLoggedIn') isLoggedIn: boolean = false;
  @StorageLink('userToken') userToken: string = '';

  aboutToAppear() {
    AppModeManager.ensureInitialized();

    // 检查是否有扫码进入的桌号信息
    const params = router.getParams() as Record<string, Object> | undefined;
    const tableId = params?.['tableId'] as string | undefined;

    if (tableId) {
      // 从扫码进入，设置顾客模式和桌号
      AppModeManager.setMode(AppMode.CUSTOMER, { tableId: tableId });
      AppStorage.setOrCreate('currentTableId', tableId);
      // 跳转到顾客登录页面
      setTimeout(() => {
        router.replaceUrl({
          url: 'pages/CustomerLoginPage',
          params: { tableId: tableId }
        });
      }, 500);
      return;
    }

    // 延迟检查登录状态，确保 PersistentStorage 数据已加载
    setTimeout(() => {
      this.checkLoginAndNavigate();
    }, 100);
  }

  private checkLoginAndNavigate() {
    // 从 AppStorage 获取最新的登录状态
    const isLoggedIn = AppStorage.get<boolean>('isLoggedIn') || false;
    const userToken = AppStorage.get<string>('userToken') || '';

    // 检查是否已登录（持久化的登录状态）
    if (isLoggedIn && userToken) {
      // 已登录，直接跳转到主页
      this.navigateToMainDirect();
      return;
    }

    if (this.appMode === AppMode.CUSTOMER && AppModeManager.isCustomerSessionActive()) {
      this.navigateToMainDirect();
      return;
    }
    
    // 未登录，显示欢迎页面
    this.opacityValue = 1;
  }

  build() {
    Stack() {
      // 全屏图片背景
      Image($r('app.media.sgj'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)

      // 底部按钮 - 覆盖在图片上方
      Column() {
        Button(this.appMode === AppMode.CUSTOMER ? '立即进入点餐' : '开启味蕾之旅')
          .width('80%')
          .height(56)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .backgroundColor('#007DFF')
          .borderRadius(28)
          .shadow({
            radius: 12,
            color: '#40007DFF',
            offsetX: 0,
            offsetY: 4
          })
          .onClick(() => {
            if (this.appMode === AppMode.CUSTOMER) {
              this.navigateToMainDirect();
              return;
            }
            router.pushUrl({
              url: 'pages/LoginPage'
            });
          })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.End)
      .padding({ bottom: 60, left: 40, right: 40 })
    }
    .width('100%')
    .height('100%')
    .opacity(this.opacityValue)
    .animation({
      duration: 500,
      curve: Curve.EaseOut
    })
  }

  private navigateToMainDirect() {
    router.replaceUrl({
      url: 'pages/MainPage'
    });
  }
}