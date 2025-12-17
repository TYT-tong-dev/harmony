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

@Entry
@Component
export struct CartPage {
  @State cartItems: CartItem[] = [];
  @State totalAmount: number = 0;
  @State isLoading: boolean = true;
  // 使用同步的购物车数量
  @StorageLink('cartItemCount') cartItemCount: number = 0;

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
      .padding({ left: 20, right: 20, bottom: 12 })

      // 购物车列表
      List({ space: 12 }) {
        ForEach(this.cartItems, (item: CartItem) => {
          ListItem() {
            this.EnhancedCartItemCard(item)
          }
        }, (item: CartItem) => item.dish.id.toString())
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 16, right: 16 })
    }
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
            Image(item.dish.imageUrl)
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
            this.checkout();
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

  // 结算 - 更新同步状态
  async checkout() {
    if (this.cartItems.length === 0) {
      promptAction.showToast({
        message: '购物车为空',
        duration: 2000
      });
      return;
    }

    try {
      // 创建订单
      const orderData: CreateOrderRequest = {
        items: this.cartItems.map(item => ({
          dish_id: item.dish.id,
          quantity: item.quantity
        } as OrderItemData))
      };

      const response: ApiResponse = await ApiUtils.post('/orders/create', orderData);

      if (response.statusCode === 200) {
        promptAction.showToast({
          message: '订单创建成功！总金额：¥' + this.totalAmount.toFixed(2),
          duration: 3000
        });

        // 清空购物车并更新同步状态
        await this.clearCart();
        router.back();
      }
    } catch (error) {
      console.error('结算失败:' + error);
      promptAction.showToast({
        message: '结算失败，请重试',
        duration: 2000
      });
    }
  }
}