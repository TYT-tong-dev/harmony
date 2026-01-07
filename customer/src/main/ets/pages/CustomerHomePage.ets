// CustomerHomePage.ets - 顾客端入口
// 直接跳转到商家版主页面，以顾客模式运行
import router from '@ohos.router';

// 应用模式枚举
enum AppMode {
  MERCHANT = 'merchant',
  CUSTOMER = 'customer'
}

@Entry
@Component
struct CustomerHomePage {
  @StorageLink('tableId') tableId: string = 'A01';
  @StorageLink('appMode') appMode: AppMode = AppMode.CUSTOMER;

  aboutToAppear() {
    // 设置为顾客模式
    AppStorage.setOrCreate('appMode', AppMode.CUSTOMER);
    AppStorage.setOrCreate('currentTableId', this.tableId);
    AppStorage.setOrCreate('isCustomerMode', true);
    
    // 延迟跳转到主页面
    setTimeout(() => {
      this.navigateToMain();
    }, 100);
  }

  build() {
    Column() {
      // 加载页面
      Column() {
        LoadingProgress()
          .width(50)
          .height(50)
          .color('#007DFF')
        Text('正在加载...')
          .fontSize(14)
          .fontColor('#666')
          .margin({ top: 16 })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F7FA')
  }

  private navigateToMain() {
    // 跳转到商家版主页面
    router.replaceUrl({
      url: '@ohos/entry/ets/pages/MainPage'
    }).catch(() => {
      // 如果跳转失败，尝试其他路径
      router.replaceUrl({
        url: 'pages/MainPage'
      }).catch(() => {
        console.error('跳转主页面失败');
      });
    });
  }
}
