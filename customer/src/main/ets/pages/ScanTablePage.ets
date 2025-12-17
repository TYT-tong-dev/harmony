// ScanTablePage.ets - 扫码/输入桌号页面
import router from '@ohos.router';
import { CustomerToastUtils } from '../common/CustomerUtils';

@Entry
@Component
struct ScanTablePage {
  @State tableNumber: string = '';
  @State isScanning: boolean = false;

  build() {
    Column() {
      // 顶部Logo区域
      Column() {
        Text('🍽')
          .fontSize(60)
          .margin({ top: 60 })
        
        Text('食光记')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
          .margin({ top: 16 })
        
        Text('扫码点餐 · 美味即达')
          .fontSize(14)
          .fontColor('#999999')
          .margin({ top: 8 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      Blank()

      // 扫码区域
      Column({ space: 20 }) {
        // 扫码按钮
        Button({ type: ButtonType.Normal }) {
          Row({ space: 8 }) {
            Text('📷').fontSize(20)
            Text('扫描桌号二维码').fontSize(16).fontColor('#FFFFFF')
          }
        }
        .width('80%')
        .height(50)
        .borderRadius(25)
        .backgroundColor('#007DFF')
        .onClick(() => {
          this.startScan();
        })

        // 分隔线
        Row() {
          Divider().width('35%').color('#E0E0E0')
          Text('或').fontSize(12).fontColor('#999999').margin({ left: 12, right: 12 })
          Divider().width('35%').color('#E0E0E0')
        }
        .width('80%')
        .justifyContent(FlexAlign.Center)

        // 手动输入桌号
        Column({ space: 12 }) {
          Text('手动输入桌号')
            .fontSize(14)
            .fontColor('#666666')

          TextInput({ placeholder: '请输入桌号，如 A01' })
            .width('80%')
            .height(48)
            .borderRadius(8)
            .backgroundColor('#F5F7FA')
            .textAlign(TextAlign.Center)
            .fontSize(18)
            .onChange((value: string) => {
              this.tableNumber = value.toUpperCase();
            })

          Button('确认入座', { type: ButtonType.Normal })
            .width('80%')
            .height(48)
            .borderRadius(24)
            .backgroundColor(this.tableNumber.length > 0 ? '#007DFF' : '#CCCCCC')
            .enabled(this.tableNumber.length > 0)
            .onClick(() => {
              this.confirmTable();
            })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      Blank()

      // 底部提示
      Text('请扫描餐桌上的二维码开始点餐')
        .fontSize(12)
        .fontColor('#AAAAAA')
        .margin({ bottom: 40 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }

  private startScan(): void {
    // TODO: 调用系统扫码能力
    // 在真实场景中，这里会调用 @kit.ScanKit 进行扫码
    CustomerToastUtils.show('正在打开扫码...');
    
    // 模拟扫码结果
    setTimeout(() => {
      this.tableNumber = 'A01';
      this.confirmTable();
    }, 1000);
  }

  private confirmTable(): void {
    if (!this.tableNumber) {
      CustomerToastUtils.showError('请输入桌号');
      return;
    }

    // 保存桌号到AppStorage
    AppStorage.setOrCreate('tableId', this.tableNumber);
    AppStorage.setOrCreate('isCustomerMode', true);

    CustomerToastUtils.showSuccess(`已入座 ${this.tableNumber} 号桌`);

    // 跳转到点餐首页
    router.replaceUrl({
      url: 'pages/CustomerHomePage'
    });
  }
}

