// CustomerHomePage.ets - 顾客点餐首页（元服务）
import { CustomerApiUtils, CustomerToastUtils, CartManager } from '../common/CustomerUtils';
import router from '@ohos.router';

interface Dish {
  id: number;
  name: string;
  price: number;
  image_url: string;
  category: string;
  description: string;
  rating: number;
  sales: number;
}

interface CartItem {
  dish: Dish;
  quantity: number;
}

// 订单项接口
class OrderItem {
  dishId: number = 0;
  quantity: number = 0;
  price: number = 0;

  constructor(dishId: number, quantity: number, price: number) {
    this.dishId = dishId;
    this.quantity = quantity;
    this.price = price;
  }
}

@Entry
@Component
struct CustomerHomePage {
  @StorageLink('tableId') tableId: string = '';
  @State dishes: Dish[] = [];
  @State categories: string[] = ['全部', '热销', '主食', '小吃', '饮品', '套餐'];
  @State selectedCategory: string = '全部';
  @State cartItems: CartItem[] = [];
  @State showCart: boolean = false;
  @State loading: boolean = true;

  aboutToAppear() {
    this.loadDishes();
  }

  build() {
    Stack() {
      Column() {
        this.TopBar()
        this.CategoryBar()
        this.DishList()
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F5F7FA')

      this.CartBar()
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  TopBar() {
    Row() {
      Column() {
        Text('食光记').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#333333')
        Row({ space: 4 }) {
          Text('📍').fontSize(12)
          Text(`桌号: ${this.tableId}`).fontSize(12).fontColor('#666666')
        }
      }.alignItems(HorizontalAlign.Start)
      Blank()
      Button('换桌', { type: ButtonType.Capsule })
        .fontSize(12).height(28).backgroundColor('#F0F4FF').fontColor('#007DFF')
        .onClick(() => { router.replaceUrl({ url: 'pages/ScanTablePage' }); })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 8 })
    .backgroundColor('#FFFFFF')
  }

  @Builder
  CategoryBar() {
    Scroll() {
      Row({ space: 12 }) {
        ForEach(this.categories, (cat: string) => {
          Button(cat, { type: ButtonType.Capsule })
            .fontSize(14).height(32)
            .backgroundColor(this.selectedCategory === cat ? '#007DFF' : '#F0F4FA')
            .fontColor(this.selectedCategory === cat ? '#FFFFFF' : '#666666')
            .onClick(() => { this.selectedCategory = cat; })
        }, (cat: string) => cat)
      }.padding({ left: 16, right: 16 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%').height(48).backgroundColor('#FFFFFF')
  }

  @Builder
  DishList() {
    if (this.loading) {
      Column() {
        LoadingProgress().width(40).height(40).color('#007DFF')
        Text('加载中...').fontSize(14).fontColor('#999999').margin({ top: 12 })
      }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
    } else {
      List({ space: 12 }) {
        ForEach(this.getFilteredDishes(), (dish: Dish) => {
          ListItem() { this.DishCard(dish) }
        }, (dish: Dish) => dish.id.toString())
      }
      .width('100%').layoutWeight(1)
      .padding({ left: 16, right: 16, top: 12, bottom: 80 })
    }
  }

  @Builder
  DishCard(dish: Dish) {
    Row() {
      Image(dish.image_url || $r('app.media.dish_default'))
        .width(90).height(90).borderRadius(8).objectFit(ImageFit.Cover)
      Column() {
        Text(dish.name).fontSize(15).fontWeight(FontWeight.Medium).fontColor('#333')
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(dish.description || '暂无描述').fontSize(11).fontColor('#999')
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ top: 4 })
        Row() {
          Text('★').fontSize(11).fontColor('#FFB800')
          Text((dish.rating || 4.5).toFixed(1)).fontSize(11).fontColor('#FFB800')
          Text(`月售${dish.sales || 0}`).fontSize(10).fontColor('#999').margin({ left: 6 })
        }.margin({ top: 4 })
        Blank()
        Row() {
          Text('¥').fontSize(11).fontColor('#FF4D4F')
          Text(dish.price.toFixed(2)).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#FF4D4F')
          Blank()
          this.QuantityControl(dish)
        }.width('100%')
      }.layoutWeight(1).height(90).margin({ left: 10 }).alignItems(HorizontalAlign.Start)
    }.width('100%').padding(10).backgroundColor('#FFFFFF').borderRadius(10)
  }

  @Builder
  QuantityControl(dish: Dish) {
    Row({ space: 6 }) {
      if (this.getCartQuantity(dish.id) > 0) {
        Button('-', { type: ButtonType.Circle }).width(26).height(26).fontSize(14)
          .backgroundColor('#F0F0F0').fontColor('#333')
          .onClick(() => { this.updateCart(dish, -1); })
        Text(this.getCartQuantity(dish.id).toString()).fontSize(13).fontColor('#333').width(20).textAlign(TextAlign.Center)
      }
      Button('+', { type: ButtonType.Circle }).width(26).height(26).fontSize(14)
        .backgroundColor('#007DFF').fontColor('#FFF')
        .onClick(() => { this.updateCart(dish, 1); })
    }
  }

  @Builder
  CartBar() {
    if (this.getTotalQuantity() > 0) {
      Row() {
        Stack() {
          Text('🛒').fontSize(22)
          Text(this.getTotalQuantity().toString()).fontSize(9).fontColor('#FFF')
            .backgroundColor('#FF4D4F').borderRadius(8).padding({ left: 4, right: 4 })
            .position({ x: 14, y: -4 })
        }
        Column() {
          Text(`¥${this.getTotalPrice().toFixed(2)}`).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#333')
          Text('预估价格').fontSize(9).fontColor('#999')
        }.margin({ left: 10 }).alignItems(HorizontalAlign.Start)
        Blank()
        Button('去结算', { type: ButtonType.Normal }).height(36).width(90).borderRadius(18)
          .backgroundColor('#007DFF').fontColor('#FFF')
          .onClick(() => { this.submitOrder(); })
      }
      .width('100%').height(56).padding({ left: 14, right: 14 })
      .backgroundColor('#FFFFFF').shadow({ radius: 8, color: 'rgba(0,0,0,0.1)', offsetY: -2 })
      .position({ x: 0, y: '100%' }).translate({ y: -56 })
    }
  }

  // 加载菜品数据
  private async loadDishes(): Promise<void> {
    this.loading = true;
    try {
      const response = await CustomerApiUtils.getDishes();
      if (response.statusCode === 200 && response.data) {
        const data = response.data as DishListData;
        this.dishes = data.dishes || [];
      }
    } catch (error) {
      CustomerToastUtils.showError('加载菜品失败');
    } finally {
      this.loading = false;
    }
  }

  // 获取过滤后的菜品
  private getFilteredDishes(): Dish[] {
    if (this.selectedCategory === '全部') {
      return this.dishes;
    } else if (this.selectedCategory === '热销') {
      return this.dishes.filter((d: Dish) => (d.sales || 0) > 50);
    }
    return this.dishes.filter((d: Dish) => d.category === this.selectedCategory);
  }

  // 获取购物车中某菜品数量
  private getCartQuantity(dishId: number): number {
    const item = this.cartItems.find((i: CartItem) => i.dish.id === dishId);
    return item ? item.quantity : 0;
  }

  // 更新购物车
  private updateCart(dish: Dish, delta: number): void {
    const index = this.cartItems.findIndex((i: CartItem) => i.dish.id === dish.id);
    if (index >= 0) {
      this.cartItems[index].quantity += delta;
      if (this.cartItems[index].quantity <= 0) {
        this.cartItems.splice(index, 1);
      }
    } else if (delta > 0) {
      this.cartItems.push({ dish: dish, quantity: delta });
    }
    this.cartItems = [...this.cartItems]; // 触发刷新
  }

  // 获取总数量
  private getTotalQuantity(): number {
    return this.cartItems.reduce((sum: number, i: CartItem) => sum + i.quantity, 0);
  }

  // 获取总价格
  private getTotalPrice(): number {
    return this.cartItems.reduce((sum: number, i: CartItem) => sum + i.dish.price * i.quantity, 0);
  }

  // 提交订单
  private async submitOrder(): Promise<void> {
    if (this.cartItems.length === 0) {
      CustomerToastUtils.showError('购物车为空');
      return;
    }
    const items: OrderItem[] = [];
    for (const i of this.cartItems) {
      items.push(new OrderItem(i.dish.id, i.quantity, i.dish.price));
    }
    try {
      const response = await CustomerApiUtils.submitOrder(this.tableId, items, '');
      if (response.statusCode === 200) {
        CustomerToastUtils.showSuccess('下单成功！');
        this.cartItems = [];
      } else {
        CustomerToastUtils.showError(response.message || '下单失败');
      }
    } catch (error) {
      CustomerToastUtils.showError('网络错误');
    }
  }
}

interface DishListData {
  dishes: Dish[];
}

