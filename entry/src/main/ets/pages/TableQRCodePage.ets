// TableQRCodePage.ets
import { AppMode, ApiResponse, TableInfo } from '../common/Types';
import { AppModeManager, DeepLinkUtils, ToastUtils, RouterUtils, ApiUtils } from '../common/Utils';
import router from '@ohos.router';

@Entry
@Component
export struct TableQRCodePage {
  @State tableNumber: string = 'A01';
  @State qrImageUrl: string = '';
  @State deepLink: string = '';
  @State isLoading: boolean = false;
  @State tables: TableInfo[] = [];
  @State loadingTables: boolean = true;
  @StorageLink('appMode') appMode: AppMode = AppMode.MERCHANT;

  private readonly qrApi: string = 'https://api.qrserver.com/v1/create-qr-code/?size=360x360&data=';

  aboutToAppear() {
    if (this.appMode === AppMode.CUSTOMER) {
      ToastUtils.showToast('请回到商家端使用该功能');
      router.back();
      return;
    }
    this.loadTables();
    this.generateQRCode();
  }

  private async loadTables(): Promise<void> {
    this.loadingTables = true;
    try {
      const response: ApiResponse = await ApiUtils.get('/tables');
      if (response.statusCode === 200 && response.data) {
        const data = response.data as Record<string, Object>;
        const tableList = data['tables'] as TableInfo[];
        if (tableList && tableList.length > 0) {
          this.tables = tableList;
          // 默认选中第一个桌位
          if (!this.tableNumber && this.tables.length > 0) {
            this.tableNumber = this.tables[0].table_number;
            this.generateQRCode();
          }
        }
      }
    } catch (error) {
      console.error('加载桌位列表失败:' + JSON.stringify(error));
    } finally {
      this.loadingTables = false;
    }
  }

  build() {
    Column() {
      this.TopBar()

      Scroll() {
        Column({ space: 24 }) {
          this.TableSelector()
          this.QRPreview()
          this.DeepLinkCard()
          this.ActionButtons()
        }
        .padding(20)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F7FB')
  }

  @Builder
  TopBar() {
    Row() {
      Image($r('app.media.back_icon'))
        .width(24)
        .height(24)
        .onClick(() => {
          router.back();
        })

      Text('桌号二维码')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1C1C1C')
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Blank().width(24)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 12 })
    .backgroundColor('#FFFFFF')
  }

  @Builder
  TableSelector() {
    Column({ space: 12 }) {
      Row() {
        Text('选择桌位')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1A1A1A')
          .layoutWeight(1)

        if (this.loadingTables) {
          LoadingProgress().width(18).height(18).color('#007DFF')
        }
      }

      Row({ space: 8 }) {
        TextInput({ text: this.tableNumber, placeholder: '如 A01 / VIP01' })
          .fontSize(16)
          .height(44)
          .layoutWeight(1)
          .border({ width: 1, color: '#DDE3F0' })
          .borderRadius(10)
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.tableNumber = value.trim().toUpperCase();
          })

        Button('生成', { type: ButtonType.Normal, stateEffect: true })
          .height(44)
          .width(88)
          .borderRadius(12)
          .backgroundColor('#007DFF')
          .fontColor('#FFFFFF')
          .onClick(() => {
            this.generateQRCode();
          })
      }

      // 从API加载的桌位列表
      if (this.tables.length > 0) {
        Text('已配置桌位').fontSize(12).fontColor('#888888').margin({ top: 8 })
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
          ForEach(this.tables, (table: TableInfo) => {
            Column({ space: 2 }) {
              Text(table.table_number)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.tableNumber === table.table_number ? '#FFFFFF' : '#333333')
              Text(table.table_name || '')
                .fontSize(10)
                .fontColor(this.tableNumber === table.table_number ? '#FFFFFFCC' : '#888888')
            }
            .width(72)
            .height(52)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .backgroundColor(this.tableNumber === table.table_number ? '#007DFF' : '#F0F4FA')
            .borderRadius(10)
            .margin({ right: 8, bottom: 8 })
            .onClick(() => {
              this.tableNumber = table.table_number;
              this.generateQRCode();
            })
          }, (table: TableInfo) => table.table_number)
        }
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
  }

  @Builder
  QRPreview() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Text('二维码预览')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
        if (this.isLoading) {
          LoadingProgress()
            .width(18)
            .height(18)
            .color('#007DFF')
        }
      }

      if (this.qrImageUrl) {
        Column({ space: 12 }) {
          Image(this.qrImageUrl)
            .width('100%')
            .height(320)
            .objectFit(ImageFit.Contain)
            .backgroundColor('#FFFFFF')
            .borderRadius(20)
            .border({ width: 1, color: '#E1E8F5' })
            .padding(12)

          Text(`桌号：${this.tableNumber}`)
            .fontSize(14)
            .fontColor('#555555')
            .textAlign(TextAlign.Center)
        }
      } else {
        Column({ space: 8 }) {
          LoadingProgress()
            .width(40)
            .height(40)
            .color('#007DFF')
          Text('正在生成二维码...')
            .fontSize(14)
            .fontColor('#666666')
        }
        .width('100%')
        .padding(20)
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
  }

  @Builder
  DeepLinkCard() {
    Column({ space: 8 }) {
      Text('跳转链接')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1A1A1A')
      if (this.deepLink) {
        Text(this.deepLink)
          .fontSize(12)
          .fontColor('#007DFF')
          .textAlign(TextAlign.Start)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      } else {
        Text('生成二维码后自动展示链接')
          .fontSize(12)
          .fontColor('#999999')
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
  }

  @Builder
  ActionButtons() {
    Column({ space: 12 }) {
      Button('保存为桌贴', { type: ButtonType.Normal, stateEffect: true })
        .height(44)
        .borderRadius(12)
        .backgroundColor('#FF9500')
        .fontColor('#FFFFFF')
        .onClick(() => {
          ToastUtils.showToast('长按二维码即可保存，打印后张贴至桌面');
        })

      Button('模拟顾客端', { type: ButtonType.Capsule, stateEffect: true })
        .height(44)
        .borderRadius(22)
        .backgroundColor('#FFFFFF')
        .fontColor('#007DFF')
        .border({ width: 1, color: '#BBD6FF' })
        .onClick(() => {
          this.previewCustomer();
        })
    }
    .width('100%')
  }

  private generateQRCode() {
    if (!this.tableNumber) {
      ToastUtils.showToast('请先输入桌号');
      return;
    }
    this.isLoading = true;

    // 查找对应桌位的ID
    const table = this.tables.find(t => t.table_number === this.tableNumber);
    if (table && table.id) {
      // 从API获取扫码链接
      this.fetchQRCodeFromApi(table.id);
    } else {
      // 使用本地生成的链接（兼容手动输入的桌号）
      const link = DeepLinkUtils.buildTableDeepLink(this.tableNumber, false);
      this.deepLink = link;
      this.qrImageUrl = `${this.qrApi}${encodeURIComponent(link)}`;
      this.isLoading = false;
    }
  }

  private async fetchQRCodeFromApi(tableId: number): Promise<void> {
    try {
      const response: ApiResponse = await ApiUtils.get(`/tables/${tableId}/qrcode`);
      if (response.statusCode === 200 && response.data) {
        const data = response.data as Record<string, string>;
        // 使用scan_url生成二维码（顾客扫这个）
        const scanUrl = data['scan_url'] || '';
        this.deepLink = scanUrl;
        this.qrImageUrl = `${this.qrApi}${encodeURIComponent(scanUrl)}`;
      } else {
        // 降级使用本地生成
        const link = DeepLinkUtils.buildTableDeepLink(this.tableNumber, false);
        this.deepLink = link;
        this.qrImageUrl = `${this.qrApi}${encodeURIComponent(link)}`;
      }
    } catch (error) {
      console.error('获取二维码失败:' + JSON.stringify(error));
      // 降级使用本地生成
      const link = DeepLinkUtils.buildTableDeepLink(this.tableNumber, false);
      this.deepLink = link;
      this.qrImageUrl = `${this.qrApi}${encodeURIComponent(link)}`;
    } finally {
      this.isLoading = false;
    }
  }

  private previewCustomer() {
    AppModeManager.setMode(AppMode.CUSTOMER, { tableId: this.tableNumber });
    ToastUtils.showToast(`已切换至顾客端 (${this.tableNumber})`);
    RouterUtils.replaceUrl('pages/MainPage');
  }
}

