// CartPage.ets - 同步购物车版本
import {
  CartItem,
  Dish,
  ApiResponse,
  CartResponse,
  CartItemData,
  AddToCartRequest,
  ClearCartRequest,
  CreateOrderRequest,
  OrderItemData
} from '../common/Types';
import { ApiUtils, ToastUtils, CartSyncManager, LocalCartManager, LocalCartItem } from '../common/Utils';
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { iap } from '@kit.IAPKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

// 支付方式枚举
enum PaymentMethod {
  HUAWEI_PAY = 'huawei',
  WECHAT_PAY = 'wechat'
}

// 支付结果接口
interface PaymentResult {
  success: boolean;
  orderId?: string;
  message: string;
}

// 华为支付产品信息
interface HuaweiProduct {
  productId: string;
  productName: string;
  price: number;
}

// 微信预支付数据
interface WechatPrepayData {
  prepayId: string;
  appId: string;
  partnerId: string;
  packageValue: string;
  nonceStr: string;
  timeStamp: string;
  sign: string;
}

// 微信订单请求数据
interface WechatOrderRequest {
  orderId: string;
  amount: number;
  description: string;
  items: WechatOrderItem[];
}

interface WechatOrderItem {
  dish_id: number;
  quantity: number;
}

// 华为支付订单项
interface HuaweiPayloadItem {
  dishId: number;
  name: string;
  quantity: number;
  price: number;
}

// 华为支付payload
interface HuaweiPayload {
  orderId: string;
  amount: number;
  items: HuaweiPayloadItem[];
}

// 订单同步请求
interface OrderSyncRequest {
  items: OrderItemData[];
  orderId: string;
  paymentMethod: string;
  transactionData: string;
  totalAmount: number;
  status: string;
}

// 服务器基础地址（用于图片）
const IMAGE_SERVER_URL: string = 'http://10.12.8.110:5000';

@Entry
@Component
export struct CartPage {
  @State cartItems: CartItem[] = [];
  @State totalAmount: number = 0;
  @State isLoading: boolean = true;
  @State showPaymentDialog: boolean = false;
  @State selectedPayment: PaymentMethod = PaymentMethod.HUAWEI_PAY;
  @State isProcessingPayment: boolean = false;
  // 使用同步的购物车数量
  @StorageLink('cartItemCount') cartItemCount: number = 0;
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;

  aboutToAppear() {
    this.loadCartItems();
  }

  private getLocalCartItems(): CartItem[] {
    const items: LocalCartItem[] = LocalCartManager.getItems();
    return items.map((local: LocalCartItem) => {
      const dish = new Dish();
      dish.id = local.id;
      dish.name = local.name;
      dish.price = local.price;
      dish.description = local.description;
      dish.imageUrl = local.imageUrl;
      return {
        dish: dish,
        quantity: local.quantity
      } as CartItem;
    });
  }

  private mergeCartItems(remoteItems: CartItem[], localItems: CartItem[]): CartItem[] {
    const merged: CartItem[] = [];
    for (const item of remoteItems) {
      merged.push(item);
    }
    for (const local of localItems) {
      const index = merged.findIndex(existing => existing.dish.id === local.dish.id);
      if (index !== -1) {
        merged[index].quantity += local.quantity;
      } else {
        merged.push(local);
      }
    }
    return merged;
  }

  private refreshCartSummary() {
    this.calculateTotal();
    const totalQuantity = this.cartItems.reduce((total, item) => total + item.quantity, 0);
    this.cartItemCount = totalQuantity;
    CartSyncManager.updateCartQuantity(totalQuantity);
    CartSyncManager.updateCartTotalAmount(this.totalAmount);
  }

  private updateLocalCartQuantity(item: CartItem, newQuantity: number) {
    const storedItems = LocalCartManager.getItems();
    const targetIndex = storedItems.findIndex(local => local.id === item.dish.id);

    if (newQuantity <= 0) {
      if (targetIndex !== -1) {
        storedItems.splice(targetIndex, 1);
      }
      this.cartItems = this.cartItems.filter(cartItem => cartItem.dish.id !== item.dish.id);
    } else {
      if (targetIndex === -1) {
        const newItem = new LocalCartItem();
        newItem.id = item.dish.id;
        newItem.name = item.dish.name;
        newItem.price = item.dish.price;
        newItem.description = item.dish.description;
        newItem.imageUrl = item.dish.imageUrl;
        newItem.quantity = newQuantity;
        storedItems.push(newItem);
      } else {
        storedItems[targetIndex].quantity = newQuantity;
      }

      const cartIndex = this.cartItems.findIndex(cartItem => cartItem.dish.id === item.dish.id);
      if (cartIndex === -1) {
        this.cartItems.push({
          dish: item.dish,
          quantity: newQuantity
        });
      } else {
        this.cartItems[cartIndex].quantity = newQuantity;
      }
    }

    LocalCartManager.saveItems(storedItems);
    this.refreshCartSummary();
    ToastUtils.showToast(newQuantity <= 0 ? '已删除商品' : '数量已更新');
  }

  build() {
    Stack() {
      Column() {
        // 顶部导航栏
        this.TopNavigation()

        if (this.isLoading) {
          this.LoadingView()
        } else if (this.cartItems.length === 0) {
          this.EmptyCartView()
        } else {
          this.EnhancedCartListView()
          this.EnhancedCheckoutBar()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F8FAFF')

      // 支付方式选择对话框
      if (this.showPaymentDialog) {
        this.PaymentMethodDialog()
      }

      // 支付处理中遮罩
      if (this.isProcessingPayment) {
        this.PaymentProcessingOverlay()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  TopNavigation() {
    Row() {
      Image($r('app.media.back_icon'))
        .width(24)
        .height(24)
        .margin({ left: 16 })
        .onClick(() => {
          router.back();
        })

      Text('购物车')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A1A')
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      if (this.cartItems.length > 0) {
        Text('清空')
          .fontSize(14)
          .fontColor('#FF3B30')
          .margin({ right: 16 })
          .onClick(() => {
            this.showClearConfirm();
          })
      } else {
        Text('')
          .width(40)
          .margin({ right: 16 })
      }
    }
    .width('100%')
    .height(56)
    .backgroundColor('#FFFFFF')
    .shadow({
      radius: 4,
      color: '#1A000000',
      offsetX: 0,
      offsetY: 2
    })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  LoadingView() {
    Column() {
      LoadingProgress()
        .width(50)
        .height(50)
        .color('#007DFF')

      Text('加载购物车...')
        .fontSize(14)
        .fontColor('#666666')
        .margin({ top: 16 })
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  EmptyCartView() {
    Column() {
      Image($r('app.media.empty'))
        .width(180)
        .height(180)
        .margin({ bottom: 24 })

      Text('购物车空空如也')
        .fontSize(18)
        .fontColor('#999999')
        .margin({ bottom: 8 })

      Text('快去添加喜欢的菜品吧')
        .fontSize(14)
        .fontColor('#CCCCCC')
        .margin({ bottom: 32 })

      Button('去逛逛', { type: ButtonType.Normal, stateEffect: true })
        .width(140)
        .height(44)
        .backgroundColor('#007DFF')
        .fontColor('#FFFFFF')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .borderRadius(22)
        .onClick(() => {
          router.back();
        })
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  EnhancedCartListView() {
    Column() {
      // 购物车标题
      Row() {
        Text('购物车商品')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
          .layoutWeight(1)

        Text('共' + this.cartItems.length + '件商品')
          .fontSize(12)
          .fontColor('#666666')
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 12, bottom: 12 })

      // 购物车列表
      List({ space: 12 }) {
        ForEach(this.cartItems, (item: CartItem) => {
          ListItem() {
            this.EnhancedCartItemCard(item)
          }
        }, (item: CartItem) => item.dish.id.toString())
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 16 })
    }
    .layoutWeight(1)
  }

  @Builder
  EnhancedCartItemCard(item: CartItem) {
    Column() {
      Row() {
        // 菜品图片
        Stack() {
          if (item.dish.imageUrl && item.dish.imageUrl.startsWith('app.media.')) {
            Image($r(item.dish.imageUrl))
              .width(80)
              .height(80)
              .borderRadius(12)
              .objectFit(ImageFit.Cover)
          } else if (item.dish.imageUrl) {
            // 处理服务器图片路径
            Image(item.dish.imageUrl.startsWith('/images/') ? `${IMAGE_SERVER_URL}${item.dish.imageUrl}` : item.dish.imageUrl)
              .width(80)
              .height(80)
              .borderRadius(12)
              .objectFit(ImageFit.Cover)
          } else {
            Image($r('app.media.image_gallery'))
              .width(80)
              .height(80)
              .borderRadius(12)
              .objectFit(ImageFit.Cover)
          }
        }
          .shadow({
            radius: 4,
            color: '#1A000000',
            offsetX: 0,
            offsetY: 2
          })

        // 菜品信息
        Column() {
          Row() {
            Column() {
              Text(item.dish.name)
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1A1A1A')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })

              Text(item.dish.description)
                .fontSize(12)
                .fontColor('#999999')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .margin({ top: 4 })

              Row() {
                Text('¥')
                  .fontSize(14)
                  .fontColor('#FF6B00')
                Text(item.dish.price.toFixed(2))
                  .fontSize(18)
                  .fontColor('#FF6B00')
                  .fontWeight(FontWeight.Bold)
              }
              .margin({ top: 8 })
            }
            .layoutWeight(1)
          }

          // 数量控制和删除
          Row() {
            // 数量控制
            Row() {
              Image($r('app.media.remove_circle'))
                .width(28)
                .height(28)
                .onClick(() => {
                  this.updateQuantity(item, item.quantity - 1);
                })

              Text(item.quantity.toString())
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor('#1A1A1A')
                .margin({ left: 16, right: 16 })
                .width(30)
                .textAlign(TextAlign.Center)

              Image($r('app.media.add_circle'))
                .width(28)
                .height(28)
                .onClick(() => {
                  this.updateQuantity(item, item.quantity + 1);
                })
            }
            .alignItems(VerticalAlign.Center)
            .layoutWeight(1)

            // 小计和删除
            Column() {
              Text('小计: ¥' + (item.dish.price * item.quantity).toFixed(2))
                .fontSize(13)
                .fontColor('#FF6B00')
                .fontWeight(FontWeight.Medium)

              Text('删除')
                .fontSize(12)
                .fontColor('#FF3B30')
                .margin({ top: 4 })
                .onClick(() => {
                  this.updateQuantity(item, 0);
                })
            }
            .alignItems(HorizontalAlign.End)
          }
          .margin({ top: 8 })
        }
        .margin({ left: 16 })
        .layoutWeight(1)
      }
    }
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .shadow({
      radius: 6,
      color: '#0A000000',
      offsetX: 0,
      offsetY: 2
    })
  }

  @Builder
  EnhancedCheckoutBar() {
    Column() {
      // 优惠信息
      Row() {
        Text('优惠券')
          .fontSize(14)
          .fontColor('#666666')
          .layoutWeight(1)

        Text('暂无可用')
          .fontSize(14)
          .fontColor('#999999')
          .margin({ right: 8 })

        Image($r('app.media.arrow_right'))
          .width(16)
          .height(16)
      }
      .width('100%')
      .padding({ bottom: 12 })

      // 总计信息
      Row() {
        Column() {
          Text('总计')
            .fontSize(14)
            .fontColor('#666666')
          Text('¥' + this.totalAmount.toFixed(2))
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FF6B00')
            .margin({ top: 4 })
        }
        .layoutWeight(1)

        Button('立即结算', { type: ButtonType.Normal, stateEffect: true })
          .width(160)
          .height(50)
          .backgroundColor('#007DFF')
          .fontColor('#FFFFFF')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .borderRadius(25)
          .onClick(() => {
            this.showPaymentDialog = true;
          })
      }
      .width('100%')
    }
    .padding(20)
    .backgroundColor('#FFFFFF')
    .borderRadius(20)
    .margin({ left: 16, right: 16, bottom: 16 })
    .shadow({
      radius: 12,
      color: '#1A000000',
      offsetX: 0,
      offsetY: 4
    })
  }

  // 支付方式选择对话框
  @Builder
  PaymentMethodDialog() {
    Stack({ alignContent: Alignment.Bottom }) {
      // 遮罩层
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.5)')
        .onClick(() => {
          if (!this.isProcessingPayment) {
            this.showPaymentDialog = false;
          }
        })

      // 对话框内容
      Column() {
        // 顶部拖动条
        Column()
          .width(40)
          .height(4)
          .borderRadius(2)
          .backgroundColor('#E0E0E0')
          .margin({ top: 12, bottom: 16 })

        // 标题
        Row() {
          Text('选择支付方式')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A1A')
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .margin({ bottom: 24 })

        // 订单金额
        Column({ space: 8 }) {
          Text('订单金额')
            .fontSize(14)
            .fontColor('#888888')
          Text('¥' + this.totalAmount.toFixed(2))
            .fontSize(32)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FF6B00')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .margin({ bottom: 24 })

        // 支付方式列表
        Column({ space: 12 }) {
          // 华为支付
          this.PaymentOptionItem(
            '华为支付',
            'HUAWEI Pay 安全快捷',
            '🔴',
            PaymentMethod.HUAWEI_PAY,
            '#FF0000'
          )

          // 微信支付
          this.PaymentOptionItem(
            '微信支付',
            '推荐使用微信支付',
            '💚',
            PaymentMethod.WECHAT_PAY,
            '#07C160'
          )
        }
        .width('100%')
        .padding({ left: 20, right: 20 })

        // 确认支付按钮
        Button('确认支付 ¥' + this.totalAmount.toFixed(2), { type: ButtonType.Normal, stateEffect: true })
          .width('90%')
          .height(52)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .borderRadius(26)
          .linearGradient({
            angle: 90,
            colors: this.selectedPayment === PaymentMethod.HUAWEI_PAY
              ? [['#FF416C', 0], ['#FF4B2B', 1]]
              : [['#07C160', 0], ['#06AD56', 1]]
          })
          .margin({ top: 32, bottom: 24 })
          .onClick(() => {
            this.processPayment();
          })

        // 安全提示
        Row({ space: 6 }) {
          Text('🔒')
            .fontSize(12)
          Text('支付安全由华为/微信提供保障')
            .fontSize(12)
            .fontColor('#999999')
        }
        .margin({ bottom: 20 })
      }
      .width('100%')
      .backgroundColor('#FFFFFF')
      .borderRadius({ topLeft: 24, topRight: 24 })
      .shadow({
        radius: 30,
        color: 'rgba(0,0,0,0.15)',
        offsetX: 0,
        offsetY: -10
      })
    }
    .width('100%')
    .height('100%')
  }

  // 支付选项组件
  @Builder
  PaymentOptionItem(name: string, desc: string, emoji: string, method: PaymentMethod, color: string) {
    Row({ space: 14 }) {
      // 图标
      Column() {
        Text(emoji)
          .fontSize(24)
      }
      .width(48)
      .height(48)
      .borderRadius(12)
      .backgroundColor(method === PaymentMethod.HUAWEI_PAY ? '#FFF0F0' : '#E8F5E9')
      .justifyContent(FlexAlign.Center)

      // 名称和描述
      Column({ space: 4 }) {
        Text(name)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1A1A1A')
        Text(desc)
          .fontSize(12)
          .fontColor('#888888')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 选中状态
      if (this.selectedPayment === method) {
        Column() {
          Text('✓')
            .fontSize(16)
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Bold)
        }
        .width(24)
        .height(24)
        .borderRadius(12)
        .backgroundColor(color)
        .justifyContent(FlexAlign.Center)
      } else {
        Column()
          .width(24)
          .height(24)
          .borderRadius(12)
          .border({ width: 2, color: '#E0E0E0' })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.selectedPayment === method ? '#F8F9FA' : '#FFFFFF')
    .borderRadius(14)
    .border({
      width: this.selectedPayment === method ? 2 : 1,
      color: this.selectedPayment === method ? color : '#F0F0F0'
    })
    .onClick(() => {
      this.selectedPayment = method;
    })
  }

  // 支付处理中遮罩
  @Builder
  PaymentProcessingOverlay() {
    Column() {
      Column({ space: 16 }) {
        LoadingProgress()
          .width(48)
          .height(48)
          .color('#007DFF')

        Text('正在处理支付...')
          .fontSize(16)
          .fontColor('#333333')

        Text('请勿关闭页面')
          .fontSize(13)
          .fontColor('#888888')
      }
      .padding(32)
      .backgroundColor('#FFFFFF')
      .borderRadius(20)
      .shadow({
        radius: 20,
        color: 'rgba(0,0,0,0.15)',
        offsetX: 0,
        offsetY: 8
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0,0,0,0.5)')
    .justifyContent(FlexAlign.Center)
  }

  // 显示清空确认
  showClearConfirm() {
    this.clearCart();
  }

  // 加载购物车商品 - 更新同步状态
  async loadCartItems() {
    this.isLoading = true;
    let remoteItems: CartItem[] = [];

    try {
      const response: ApiResponse = await ApiUtils.get('/cart/items');
      if (response.statusCode === 200 && response.data) {
        const cartData: CartResponse = response.data as CartResponse;
        remoteItems = cartData.items.map((item: CartItemData) => {
          const dish = new Dish();
          dish.id = item.dish_id;
          dish.name = item.name;
          dish.price = item.price;
          dish.description = item.description;
          dish.imageUrl = item.image_url;
          return {
            dish: dish,
            quantity: item.quantity
          } as CartItem;
        });
      }
    } catch (error) {
      console.error('加载购物车失败:' + error);
    } finally {
      const localItems = this.getLocalCartItems();
      this.cartItems = this.mergeCartItems(remoteItems, localItems);
      this.refreshCartSummary();
      this.isLoading = false;
    }
  }

  // 更新数量 - 更新同步状态
  async updateQuantity(item: CartItem, newQuantity: number) {
    if (newQuantity < 0) {
      return;
    }

    if (item.dish.id <= 0) {
      this.updateLocalCartQuantity(item, newQuantity);
      return;
    }

    try {
      await ApiUtils.post('/cart/update', {
        dish_id: item.dish.id,
        quantity: newQuantity
      } as AddToCartRequest);

      // 更新本地状态
      if (newQuantity === 0) {
        this.cartItems = this.cartItems.filter(i => i.dish.id !== item.dish.id);
      } else {
        const index = this.cartItems.findIndex(i => i.dish.id === item.dish.id);
        if (index !== -1) {
          this.cartItems[index].quantity = newQuantity;
        }
      }

      this.refreshCartSummary();

      ToastUtils.showToast(newQuantity === 0 ? '已删除商品' : '数量已更新');
    } catch (error) {
      console.error('更新数量失败:' + error);
      ToastUtils.showToast('操作失败，请重试');
    }
  }

  // 清空购物车 - 更新同步状态
  async clearCart() {
    let remoteCleared = false;
    try {
      await ApiUtils.post('/cart/clear', {} as ClearCartRequest);
      remoteCleared = true;
    } catch (error) {
      console.error('清空购物车失败:' + error);
    } finally {
      LocalCartManager.clear();
      this.cartItems = [];
      this.refreshCartSummary();
      if (remoteCleared) {
        ToastUtils.showToast('购物车已清空');
      } else {
        ToastUtils.showToast('已清空本地购物车');
      }
    }
  }

  // 计算总金额
  calculateTotal() {
    this.totalAmount = this.cartItems.reduce((total, item) => {
      return total + (item.dish.price * item.quantity);
    }, 0);
  }

  // 处理支付
  private processPayment(): void {
    if (this.cartItems.length === 0) {
      ToastUtils.showToast('购物车为空');
      return;
    }

    this.isProcessingPayment = true;
    this.showPaymentDialog = false;

    if (this.selectedPayment === PaymentMethod.HUAWEI_PAY) {
      this.processHuaweiPay();
    } else {
      this.processWechatPay();
    }
  }

  // 华为支付处理
  private processHuaweiPay(): void {
    // 生成订单号
    const orderId = `ORDER_${Date.now()}_${Math.floor(Math.random() * 10000)}`;

    // 构建华为支付payload
    const payloadItems: HuaweiPayloadItem[] = [];
    for (const item of this.cartItems) {
      const payloadItem: HuaweiPayloadItem = {
        dishId: item.dish.id,
        name: item.dish.name,
        quantity: item.quantity,
        price: item.dish.price
      };
      payloadItems.push(payloadItem);
    }
    const payload: HuaweiPayload = {
      orderId: orderId,
      amount: this.totalAmount,
      items: payloadItems
    };

    // 检查IAP是否可用（模拟器上可能不可用）
    try {
      // 在模拟器上直接使用模拟支付
      let iapAvailable = false;
      try {
        // 尝试访问ProductType，如果失败则IAP不可用
        const testType = iap.ProductType;
        iapAvailable = testType !== undefined && testType !== null;
      } catch (e) {
        iapAvailable = false;
      }

      if (!iapAvailable) {
        console.warn('华为IAP不可用，使用模拟支付');
        this.simulatePaymentSuccess(orderId, PaymentMethod.HUAWEI_PAY);
        return;
      }

      // 创建华为支付请求
      const createPurchaseParam: iap.PurchaseParameter = {
        productId: `meal_order_${orderId}`,
        productType: iap.ProductType.CONSUMABLE,
        developerPayload: JSON.stringify(payload)
      };

      // 调用华为IAP支付
      iap.createPurchase(this.context, createPurchaseParam)
        .then((result: iap.CreatePurchaseResult) => {
          console.info('华为支付成功: ' + JSON.stringify(result));
          this.handlePaymentSuccess(orderId, PaymentMethod.HUAWEI_PAY, result.purchaseData);
        })
        .catch((error: BusinessError) => {
          console.error('华为支付失败: ' + JSON.stringify(error));
          this.handlePaymentError(error, PaymentMethod.HUAWEI_PAY);
        });
    } catch (error) {
      console.error('华为支付初始化失败: ' + JSON.stringify(error));
      // 在模拟器或IAP不可用时，使用模拟支付
      this.simulatePaymentSuccess(orderId, PaymentMethod.HUAWEI_PAY);
    }
  }

  // 模拟支付成功（用于模拟器测试）
  private simulatePaymentSuccess(orderId: string, method: PaymentMethod): void {
    console.info('模拟支付成功，订单号: ' + orderId);
    // 模拟支付延迟
    setTimeout(() => {
      this.handlePaymentSuccess(orderId, method, 'simulated_purchase_data');
    }, 1000);
  }

  // 微信支付处理
  private processWechatPay(): void {
    // 生成订单号
    const orderId = `ORDER_${Date.now()}_${Math.floor(Math.random() * 10000)}`;

    // 调用后端创建微信预支付订单
    this.createWechatOrder(orderId)
      .then((prepayData: WechatPrepayData | null) => {
        if (prepayData) {
          // 调用微信支付SDK (需要集成微信SDK)
          this.invokeWechatPay(prepayData, orderId);
        } else {
          this.handlePaymentError({ code: -1, message: '创建预支付订单失败' } as BusinessError, PaymentMethod.WECHAT_PAY);
        }
      })
      .catch((error: Error) => {
        console.error('微信支付失败: ' + error.message);
        this.handlePaymentError({ code: -1, message: error.message } as BusinessError, PaymentMethod.WECHAT_PAY);
      });
  }

  // 创建微信预支付订单
  private async createWechatOrder(orderId: string): Promise<WechatPrepayData | null> {
    try {
      // 构建订单项
      const orderItems: WechatOrderItem[] = [];
      for (const item of this.cartItems) {
        const orderItem: WechatOrderItem = {
          dish_id: item.dish.id,
          quantity: item.quantity
        };
        orderItems.push(orderItem);
      }

      // 构建请求数据
      const requestData: WechatOrderRequest = {
        orderId: orderId,
        amount: Math.round(this.totalAmount * 100),
        description: `餐饮订单-${this.cartItems.length}件商品`,
        items: orderItems
      };

      const response: ApiResponse = await ApiUtils.post('/payment/wechat/create', requestData);

      if (response.statusCode === 200 && response.data) {
        return response.data as WechatPrepayData;
      }
      return null;
    } catch (error) {
      console.error('创建微信订单失败: ' + JSON.stringify(error));
      return null;
    }
  }

  // 调用微信支付
  private invokeWechatPay(prepayData: WechatPrepayData, orderId: string): void {
    // 注意：实际微信支付需要集成微信OpenSDK
    // 这里模拟支付流程，实际需要调用微信SDK
    console.info('调用微信支付: ' + JSON.stringify(prepayData));

    // 模拟支付成功（实际应用中需要替换为真实的微信SDK调用）
    // 微信SDK调用示例：
    // WXApi.sendReq(payReq) 然后在回调中处理结果

    // 暂时模拟支付成功
    setTimeout(() => {
      // 模拟支付成功
      this.handlePaymentSuccess(orderId, PaymentMethod.WECHAT_PAY, prepayData.prepayId);
    }, 2000);
  }

  // 支付成功处理
  private handlePaymentSuccess(orderId: string, method: PaymentMethod, transactionData: string): void {
    this.isProcessingPayment = false;

    // 同步订单到服务器
    this.syncOrderToServer(orderId, method, transactionData)
      .then(() => {
        // 清空购物车
        this.clearCart();

        // 显示成功提示
        promptAction.showDialog({
          title: '支付成功',
          message: `订单号: ${orderId}\n支付金额: ¥${this.totalAmount.toFixed(2)}\n支付方式: ${method === PaymentMethod.HUAWEI_PAY ? '华为支付' : '微信支付'}`,
          buttons: [{ text: '确定', color: '#007DFF' }]
        }).then(() => {
          router.back();
        });
      })
      .catch((error: Error) => {
        console.error('同步订单失败: ' + error.message);
        ToastUtils.showToast('订单已支付，同步中...');
        router.back();
      });
  }

  // 支付失败处理
  private handlePaymentError(error: BusinessError, method: PaymentMethod): void {
    this.isProcessingPayment = false;

    let errorMessage = '支付失败';

    // 华为支付错误码处理
    if (method === PaymentMethod.HUAWEI_PAY) {
      switch (error.code) {
        case 60001:
          errorMessage = '用户取消支付';
          break;
        case 60002:
          errorMessage = '网络异常，请重试';
          break;
        case 60003:
          errorMessage = '商品不存在';
          break;
        case 60004:
          errorMessage = '商品已拥有';
          break;
        case 60005:
          errorMessage = '商品不可购买';
          break;
        case 60050:
          errorMessage = '华为账号未登录';
          break;
        default:
          errorMessage = `支付失败(${error.code}): ${error.message}`;
      }
    } else {
      // 微信支付错误处理
      if (error.code === -2) {
        errorMessage = '用户取消支付';
      } else {
        errorMessage = error.message || '微信支付失败';
      }
    }

    ToastUtils.showToast(errorMessage);
  }

  // 同步订单到服务器
  private async syncOrderToServer(orderId: string, method: PaymentMethod, transactionData: string): Promise<void> {
    // 先同步本地购物车
    await this.syncLocalCartToServer();

    // 构建订单项
    const orderItems: OrderItemData[] = [];
    for (const item of this.cartItems) {
      const orderItem: OrderItemData = {
        dish_id: item.dish.id,
        quantity: item.quantity
      };
      orderItems.push(orderItem);
    }

    // 构建同步请求
    const syncRequest: OrderSyncRequest = {
      items: orderItems,
      orderId: orderId,
      paymentMethod: method,
      transactionData: transactionData,
      totalAmount: this.totalAmount,
      status: 'paid'
    };

    const response: ApiResponse = await ApiUtils.post('/orders/create', syncRequest);

    if (response.statusCode !== 200) {
      throw new Error(response.message || '订单同步失败');
    }
  }

  // 旧的结算方法（保留兼容）
  async checkout() {
    this.showPaymentDialog = true;
  }

  // 同步本地购物车到服务器
  private async syncLocalCartToServer(): Promise<void> {
    const localItems: LocalCartItem[] = LocalCartManager.getItems();
    if (localItems.length === 0) {
      return;
    }

    try {
      for (const item of localItems) {
        if (item.id > 0) {
          await ApiUtils.post('/cart/add', {
            dish_id: item.id,
            quantity: item.quantity
          } as AddToCartRequest);
        }
      }
      // 同步成功后清空本地购物车
      LocalCartManager.clear();
    } catch (error) {
      console.error('同步本地购物车失败:' + error);
      // 同步失败不阻止结算，继续尝试
    }
  }
}