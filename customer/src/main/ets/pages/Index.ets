import router from '@ohos.router';
import { AppMode } from '../common/Types';
import { AppModeManager } from '../common/Utils';

@Entry
@Component
struct Index {
  @State opacityValue: number = 0;
  @StorageLink('appMode') appMode: AppMode = AppMode.CUSTOMER;
  @StorageLink('isLoggedIn') isLoggedIn: boolean = false;
  @StorageLink('userToken') userToken: string = '';

  aboutToAppear() {
    // 顾客端默认设置为顾客模式
    AppModeManager.setMode(AppMode.CUSTOMER);
    AppModeManager.ensureInitialized();

    // 延迟检查登录状态
    setTimeout(() => {
      this.checkLoginAndNavigate();
    }, 100);
  }

  private checkLoginAndNavigate() {
    // 从 AppStorage 获取最新的登录状态
    const isLoggedIn = AppStorage.get<boolean>('isLoggedIn') || false;
    const userToken = AppStorage.get<string>('userToken') || '';

    // 检查是否已登录
    if (isLoggedIn && userToken) {
      // 已登录，直接跳转到主页
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
        Button('开启美食之旅')
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
            // 跳转到登录页面
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
