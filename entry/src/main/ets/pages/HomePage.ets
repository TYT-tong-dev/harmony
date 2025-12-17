// HomePage.ets - 商家扫码点单应用首页
// 包含店铺信息、菜品管理、购物车等功能
import { ShopInfo, Dish, ApiResponse, CartResponse, AddToCartRequest, CreateDishRequest, NewDishForm, ShopInfoResponse, DishListResponse, DishReview, AppMode, NotificationListResponse, AppNotification, NotificationType } from '../common/Types';
import { ApiUtils, ToastUtils, CartSyncManager, LocalCartManager, AppModeManager } from '../common/Utils';
import { NotificationUtils, NotificationData } from '../common/NotificationUtils';
import router from '@ohos.router';
import picker from '@ohos.file.picker';
import common from '@ohos.app.ability.common';
import abilityAccessCtrl from '@ohos.abilityAccessCtrl';
import fs from '@ohos.file.fs';
// Map SDK暂不可用，使用静态地图预览替代
// import { MapComponent, MapProperties, MapType, MapController, MarkerOptions } from '@hms/map';

type MediaPermissionName =
  | 'ohos.permission.READ_MEDIA'
  | 'ohos.permission.WRITE_MEDIA'
  | 'ohos.permission.READ_IMAGEVIDEO'
  | 'ohos.permission.WRITE_IMAGEVIDEO'
  | 'ohos.permission.CAMERA';

interface PermissionRequestResult {
  permissions: MediaPermissionName[];
  authResults: number[];
}

const DEFAULT_LATITUDE: number = 39.9042;
const DEFAULT_LONGITUDE: number = 116.4074;
const HUAWEI_MAP_PROJECT_ID: string = '101653523862716962';
const HUAWEI_MAP_CLIENT_ID: string = '1829108310557615936';
const HUAWEI_MAP_CLIENT_SECRET: string = 'E36A71B8A0116DEE2B9E5272F7F2256C36BDF972217E18BAFF1BF20D205D6EE5';
const HUAWEI_MAP_API_KEY: string = 'DgEDAOP2OZMamC/Ot5UM8pXwFOtm5CCi2QrjHmSfx7YOlpmhBXWl2wL/fkua55f6Wa86BI+0s53oF7Wk5Q/EQbC5uwcufMWnls+HyA==';

@Entry
@Component
export struct HomePage {
  // 店铺信息
  @State shopInfo: ShopInfo = new ShopInfo();
  @StorageLink('appMode') appMode: AppMode = AppMode.MERCHANT;
  @StorageLink('currentTableId') currentTableId: string = '';
  
  // 菜品列表
  @State dishes: Dish[] = [];
  
  // 选中的分类
  @State selectedCategory: string = '全部';
  
  // 加载状态
  @State isLoading: boolean = true;
  
  // 购物车数量（同步）
  @StorageLink('cartItemCount') cartItemCount: number = 0;
  
  // 购物车总金额（同步）
  @StorageLink('cartTotalAmount') cartTotalAmount: number = 0;
  
  // 菜品分类
  @State categories: string[] = ['全部', '热菜', '凉菜', '主食', '汤类', '饮料', '甜品', '招牌菜'];
  
  // 是否显示添加菜品对话框
  @State showAddDishDialog: boolean = false;
  
  // 是否显示图片选择器
  @State showImagePicker: boolean = false;
  
  // 新菜品表单
  @State newDish: NewDishForm = new NewDishForm();
  
  // 本地图片资源列表
  @State localImages: string[] = [
    'app.media.dish1',
    'app.media.dish2',
    'app.media.dish3',
    'app.media.dish4',
    'app.media.dish5',
    'app.media.default_dish'
  ];

  private defaultFeaturedDishes?: Dish[];
  private context?: common.UIAbilityContext;
  private atManager?: abilityAccessCtrl.AtManager;
  private mediaPermissionsGranted: boolean = false;
  @State featuredActiveIndex: number = 0;
  @State featuredSlides: Dish[] = [];
  @State isRefreshing: boolean = false;
  @State imageProcessing: boolean = false;
  private pageScroller: Scroller = new Scroller();
  private categoryScroller: Scroller = new Scroller();
  @State showDishDetail: boolean = false;
  @State selectedDish?: Dish = undefined;
  @State reviewRating: number = 5;
  @State reviewContent: string = '';
  @State dishReviewStore: Record<number, DishReview[]> = {};
  @State showMapDialog: boolean = false;
  @State mapCenterLat: number = DEFAULT_LATITUDE;
  @State mapCenterLng: number = DEFAULT_LONGITUDE;
  
  private readonly mediaPermissions: MediaPermissionName[] = [
    'ohos.permission.READ_MEDIA',
    'ohos.permission.WRITE_MEDIA',
    'ohos.permission.READ_IMAGEVIDEO',
    'ohos.permission.WRITE_IMAGEVIDEO',
    'ohos.permission.CAMERA'
  ];

  // 通知轮询
  private notificationPollingId: number = -1;
  @State unreadNotificationCount: number = 0;
  @State lastNotificationId: number = 0;

  aboutToAppear() {
    try {
      this.context = getContext(this) as common.UIAbilityContext;
      this.atManager = abilityAccessCtrl.createAtManager();
    } catch (error) {
      console.error('获取页面上下文失败:' + JSON.stringify(error));
    }
    this.featuredSlides = this.buildCarouselSlidesFromAssets();
    this.loadShopData();
    this.loadDishes();
    this.loadCartData();
    // 商家模式下启动通知轮询
    if (!this.isCustomerMode) {
      this.startNotificationPolling();
    }
  }

  aboutToDisappear() {
    this.stopNotificationPolling();
  }

  // 启动通知轮询
  private startNotificationPolling(): void {
    // 立即检查一次
    this.checkNewNotifications();
    // 每10秒轮询一次
    this.notificationPollingId = setInterval(() => {
      this.checkNewNotifications();
    }, 10000);
  }

  // 停止通知轮询
  private stopNotificationPolling(): void {
    if (this.notificationPollingId !== -1) {
      clearInterval(this.notificationPollingId);
      this.notificationPollingId = -1;
    }
  }

  // 检查新通知
  private async checkNewNotifications(): Promise<void> {
    try {
      const response: ApiResponse = await ApiUtils.get('/notifications/list?unread_only=true&limit=5');
      if (response.statusCode === 200 && response.data) {
        const data = response.data as NotificationListResponse;
        this.unreadNotificationCount = data.unread_count;

        // 检查是否有新订单通知
        if (data.notifications && data.notifications.length > 0) {
          for (const notification of data.notifications) {
            // 只处理比上次更新的通知
            if (notification.id > this.lastNotificationId) {
              // 发送本地通知
              if (notification.type === 'order') {
                const notificationData = new NotificationData(
                  notification.id,
                  NotificationType.ORDER,
                  notification.title,
                  notification.content
                );
                await NotificationUtils.sendNotification(notificationData);
              }
            }
          }
          // 更新最后一条通知ID
          let maxId = 0;
          for (const n of data.notifications) {
            if (n.id > maxId) {
              maxId = n.id;
            }
          }
          this.lastNotificationId = maxId;
        }
      }
    } catch (error) {
      console.error('检查通知失败:' + JSON.stringify(error));
    }
  }

  private get isCustomerMode(): boolean {
    return this.appMode === AppMode.CUSTOMER;
  }

  private get tableDisplayText(): string {
    return this.currentTableId ? `当前餐桌：${this.currentTableId}` : '堂食顾客';
  }

  private hasValidCoordinates(): boolean {
    return typeof this.shopInfo.latitude === 'number' && typeof this.shopInfo.longitude === 'number';
  }

  private openMapPreview(): void {
    if (!this.shopInfo.address) {
      ToastUtils.showToast('暂无店铺地址');
      return;
    }
    if (!this.hasValidCoordinates()) {
      if (this.shopInfo.latitude === undefined) {
        this.shopInfo.latitude = DEFAULT_LATITUDE;
      }
      if (this.shopInfo.longitude === undefined) {
        this.shopInfo.longitude = DEFAULT_LONGITUDE;
      }
    }
    this.mapCenterLat = this.shopInfo.latitude ?? DEFAULT_LATITUDE;
    this.mapCenterLng = this.shopInfo.longitude ?? DEFAULT_LONGITUDE;
    this.showMapDialog = true;
  }

  // Map SDK暂不可用，移除handleMapReady方法
  // 如需地图功能，请确保@hms/map依赖正确安装并配置

  private closeMapDialog(): void {
    this.showMapDialog = false;
  }


  build() {
    Stack() {
      // 主内容区域 + 下拉刷新
      Refresh({ refreshing: this.isRefreshing, offset: 120 }) {
        Scroll(this.pageScroller) {
          Column() {
          // 顶部导航栏（右上角添加菜品按钮）
          this.TopNavigation()
          if (this.isCustomerMode) {
            this.CustomerAnnouncement()
          }

          // 1. 店铺信息
          this.ShopInfoCard()

          // 2. 主推菜品
          this.RecommendedDishesSection(this.getCarouselSlides())

          // 3. 菜品信息（分类导航 + 菜品列表）
          this.DishesSection()
        }
        .width('100%')
        .padding({ bottom: 110 }) // 为底部按钮留出空间
        }
        .width('100%')
        .height('100%')
        .scrollable(ScrollDirection.Vertical)
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring)
        .backgroundColor('#F8FAFF')
        .zIndex(0)
      }
      .width('100%')
      .height('100%')
      .onRefreshing(() => {
        if (!this.isRefreshing) {
          this.refreshHomeData();
        }
      })

      // 右下角固定购物车按钮，浮于内容之上
      Column() {
        Blank()
          .layoutWeight(1)
        Row() {
          this.FloatingCartButton()
        }
        .width('100%')
        .justifyContent(FlexAlign.End)
      }
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.Transparent)
      .padding({ right: 20, bottom: 24 })

      // 添加菜品对话框
      if (this.showAddDishDialog && !this.isCustomerMode) {
        this.AddDishDialog()
      }

      // 图片选择器对话框
      if (this.showImagePicker) {
        this.ImagePickerDialog()
      }

      if (this.showDishDetail && this.selectedDish) {
        this.DishDetailDialog()
      }

      if (this.showMapDialog) {
        this.MapPreviewDialog()
      }
    }
    .width('100%')
    .height('100%')
  }

  // 顶部导航栏（右上角添加菜品按钮）
  @Builder
  TopNavigation() {
    Row() {
      // 店铺Logo和名称
      Row() {
        Image($r('app.media.ic_shop'))
          .width(44)
          .height(44)
          .borderRadius(22)
          .margin({ right: 12 })
          .shadow({
            radius: 6,
            color: '#20000000',
            offsetX: 0,
            offsetY: 2
          })

        Column() {
          Text(this.shopInfo.shop_name || this.shopInfo.name || '美味餐厅')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A1A')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Row({ space: 4 }) {
            Image($r('app.media.star'))
              .width(14)
              .height(14)
              .fillColor('#FFB800')
            Text((this.shopInfo.score || 4.8).toFixed(1))
              .fontSize(13)
              .fontColor('#FF9500')
              .fontWeight(FontWeight.Medium)
            Text('·')
              .fontSize(13)
              .fontColor('#CCCCCC')
            Text('营业中')
              .fontSize(12)
              .fontColor('#34C759')
          }
          .alignItems(VerticalAlign.Center)
          .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)

      if (!this.isCustomerMode) {
        // 右上角「添加菜品」按钮
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row({ space: 6 }) {
            Text('+')
              .fontSize(18)
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Bold)
            Text('添加菜品')
              .fontSize(13)
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Medium)
          }
          .alignItems(VerticalAlign.Center)
          .justifyContent(FlexAlign.Center)
        }
        .height(40)
        .padding({ left: 16, right: 18 })
        .backgroundColor('#34C759')
        .borderRadius(20)
        .shadow({
          radius: 10,
          color: '#4034C759',
          offsetX: 0,
          offsetY: 4
        })
        .onClick(() => {
          console.info('添加菜品按钮被点击');
          this.navigateToAddDishPage();
        })
      } else {
        this.CustomerModeBadge()
      }
    }
    .width('100%')
    .padding({
      left: 16,
      right: 16,
      top: 12,
      bottom: 12
    })
    .backgroundColor('#FFFFFF')
    .shadow({
      radius: 12,
      color: '#12000000',
      offsetX: 0,
      offsetY: 4
    })
  }

  @Builder
  CustomerModeBadge() {
    Row({ space: 6 }) {
      Image($r('app.media.qr_code'))
        .width(18)
        .height(18)
        .fillColor('#007DFF')
      Text(this.tableDisplayText)
        .fontSize(13)
        .fontColor('#007DFF')
        .fontWeight(FontWeight.Medium)
    }
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .backgroundColor('#EAF3FF')
    .borderRadius(18)
  }

  @Builder
  CustomerAnnouncement() {
    Row() {
      Column({ space: 4 }) {
        Text('欢迎使用顾客点餐版')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1A1A1A')
        Text(this.tableDisplayText)
          .fontSize(12)
          .fontColor('#666666')
      }
      .layoutWeight(1)

      Button('切换商家端', { type: ButtonType.Normal, stateEffect: true })
        .height(34)
        .padding({ left: 12, right: 12 })
        .fontSize(12)
        .borderRadius(17)
        .backgroundColor('#FFFFFF')
        .fontColor('#007DFF')
        .onClick(() => {
          AppModeManager.setMode(AppMode.MERCHANT);
          ToastUtils.showToast('已切回商家端，请重新登录');
          router.replaceUrl({
            url: 'pages/LoginPage'
          });
        })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 4, bottom: 4 })
    .backgroundColor('#F5F9FF')
  }

  // 店铺信息卡片
  @Builder
  ShopInfoCard() {
    Column() {
      // 店铺详情信息
      Row() {
        // 营业时间
        Column() {
          Row() {
            Image($r('app.media.time'))
              .width(14)
              .height(14)
              .margin({ right: 6 })
            Text('营业时间')
              .fontSize(11)
              .fontColor('#666666')
          }
          .alignItems(VerticalAlign.Center)
          .justifyContent(FlexAlign.Start)

          Text(this.shopInfo.business_hours || this.shopInfo.businessHours)
            .fontSize(12)
            .fontColor('#333333')
            .margin({ top: 4 })
            .textAlign(TextAlign.Start)
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .padding({ right: 10 })

        // 店铺地址
        Column() {
          Row() {
            Image($r('app.media.location'))
              .width(14)
              .height(14)
              .margin({ right: 6 })
            Text('店铺地址')
              .fontSize(11)
              .fontColor('#666666')
          }
          .alignItems(VerticalAlign.Center)
          .justifyContent(FlexAlign.Start)

          Row({ space: 8 }) {
            Text(this.shopInfo.address)
              .fontSize(12)
              .fontColor('#333333')
              .margin({ top: 4 })
              .textAlign(TextAlign.Start)
              .width('100%')
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)

            Button({ type: ButtonType.Normal }) {
              Row({ space: 4 }) {
                Image($r('app.media.location'))
                  .width(14)
                  .height(14)
                  .fillColor('#FFFFFF')
                Text('查看地图')
                  .fontSize(11)
                  .fontColor('#FFFFFF')
              }
              .alignItems(VerticalAlign.Center)
            }
            .height(28)
            .padding({ left: 10, right: 10 })
            .backgroundColor('#007DFF')
            .borderRadius(16)
            .onClick(() => {
              this.openMapPreview();
            })
          }
          .alignItems(VerticalAlign.Center)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 10 })
      }
      .width('100%')
      .padding({
        top: 12,
        bottom: 12,
        left: 16,
        right: 16
      })
      .alignItems(VerticalAlign.Top)
    }
    .width('94%')
    .backgroundColor('#FFFFFF')
    .borderRadius(18)
    .margin({ top: 8, bottom: 2, left: '3%', right: '3%' })
    .padding({ top: 14, bottom: 14, left: 14, right: 14 })
    .shadow({
      radius: 16,
      color: '#15000000',
      offsetX: 0,
      offsetY: 6
    })
  }

  // 主推菜品区域 - 轮播展示dish1-dish5图片
  @Builder
  RecommendedDishesSection(slides: Dish[]) {
    Column() {
      if (slides.length > 0) {
        Row() {
          Row({ space: 8 }) {
            Image($r('app.media.recommend_tag'))
              .width(20)
              .height(20)
              .fillColor('#FF6B00')
            Text('主推菜品')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A1A')
          }
          .layoutWeight(1)

          Row({ space: 4 }) {
            Text('自动轮播')
              .fontSize(11)
              .fontColor('#999999')
            Image($r('app.media.arrow_right'))
              .width(12)
              .height(12)
              .fillColor('#999999')
          }
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: 10, bottom: 8 })

        Swiper() {
          ForEach(slides, (dish: Dish, index: number) => {
            Column() {
              this.FeaturedDishCard(dish)
            }
            .width('100%')
          }, (dish: Dish, index: number) => `featured-${dish.id}-${index}`)
        }
        .height(300)
        .width('100%')
        .padding({ left: 16, right: 16 })
        .indicator(false)
        .loop(true)
        .autoPlay(true)
        .interval(3500)
        .duration(400)
        .cachedCount(5)
        .itemSpace(12)
        .displayCount(1)
        .index(this.featuredActiveIndex)
        .onChange((index: number) => {
          this.featuredActiveIndex = index;
        })

        // 轮播指示器 - 更美观的设计
        Row({ space: 8 }) {
          ForEach(slides, (_dish: Dish, index: number) => {
            Column()
              .width(this.featuredActiveIndex === index ? 24 : 8)
              .height(8)
              .borderRadius(4)
              .backgroundColor(this.featuredActiveIndex === index ? '#007DFF' : '#E0E0E0')
              .animation({ duration: 300, curve: Curve.EaseInOut })
          }, (_dish: Dish, index: number) => `indicator-${index}`)
        }
        .justifyContent(FlexAlign.Center)
        .padding({ top: 12, bottom: 8 })
      }
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(20)
    .margin({ left: 12, right: 12, top: 4, bottom: 0 })
    .padding({ top: 4, bottom: 4 })
    .shadow({
      radius: 16,
      color: '#10000000',
      offsetX: 0,
      offsetY: 4
    })
  }

  @Builder
  FeaturedDishCard(dish: Dish) {
    Column() {
      Stack({ alignContent: Alignment.BottomStart }) {
        if (dish.imageUrl && dish.imageUrl.startsWith('app.media.')) {
          Image($r(dish.imageUrl))
            .width('100%')
            .height(200)
            .borderRadius(16)
            .objectFit(ImageFit.Cover)
        } else if (dish.imageUrl) {
          Image(this.normalizeDishImagePath(dish.imageUrl))
            .width('100%')
            .height(200)
            .borderRadius(16)
            .objectFit(ImageFit.Cover)
        } else {
          Image($r('app.media.dish1'))
            .width('100%')
            .height(200)
            .borderRadius(16)
            .objectFit(ImageFit.Cover)
        }

        // 渐变遮罩层和信息
        Column() {
          Row({ space: 8 }) {
            Text('主推')
              .fontSize(11)
              .fontColor('#FFFFFF')
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .backgroundColor('#FF6B00')
              .borderRadius(10)
            Text(`月售${dish.sales}份`)
              .fontSize(11)
              .fontColor('#FFFFFF')
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .backgroundColor('#00000060')
              .borderRadius(10)
          }
          .margin({ bottom: 8 })

          Text(dish.name || '精选菜品')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .margin({ bottom: 4 })

          Text(dish.description || '今日精选推荐')
            .fontSize(13)
            .fontColor('#FFFFFFDD')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .padding({ left: 16, right: 16, bottom: 16, top: 40 })
        .width('100%')
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [['#00000000', 0], ['#00000080', 0.5], ['#000000CC', 1]]
        })
        .borderRadius({ bottomLeft: 16, bottomRight: 16 })
        .alignItems(HorizontalAlign.Start)
      }

      // 底部价格和加入购物车按钮
      Row() {
        Column({ space: 2 }) {
          Row() {
            Text('¥')
              .fontSize(14)
              .fontColor('#FF3B30')
              .fontWeight(FontWeight.Bold)
            Text(dish.price.toFixed(2))
              .fontSize(22)
              .fontColor('#FF3B30')
              .fontWeight(FontWeight.Bold)
          }
          Row({ space: 4 }) {
            Image($r('app.media.star'))
              .width(12)
              .height(12)
              .fillColor('#FFB800')
            Text(`${(dish.rating || 4.8).toFixed(1)}分`)
              .fontSize(11)
              .fontColor('#888888')
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row({ space: 6 }) {
            Image($r('app.media.shopping_cart'))
              .width(16)
              .height(16)
              .fillColor('#FFFFFF')
            Text('加入购物车')
              .fontSize(13)
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Medium)
          }
        }
        .height(36)
        .padding({ left: 16, right: 16 })
        .backgroundColor('#007DFF')
        .borderRadius(18)
        .onClick(() => {
          this.addToCart(dish);
        })
      }
      .width('100%')
      .padding({ top: 12, left: 4, right: 4 })
    }
    .width('100%')
    .padding(8)
    .backgroundColor('#FFFFFF')
    .borderRadius(20)
    .shadow({
      radius: 12,
      color: '#15000000',
      offsetX: 0,
      offsetY: 4
    })
  }

  // 菜品信息区域（分类导航 + 菜品列表）
  @Builder
  DishesSection() {
    Column() {
      // 分类导航
      this.CategoryTabs()

      // 菜品列表
      if (this.isLoading) {
        this.LoadingView()
      } else {
        this.DishListView()
      }
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(20)
    .margin({ left: 12, right: 12, top: 8 })
    .padding({ bottom: 16 })
    .shadow({
      radius: 12,
      color: '#08000000',
      offsetX: 0,
      offsetY: 2
    })
  }

  // 分类导航 - 优化滑动体验
  @Builder
  CategoryTabs() {
    Column() {
      Row() {
        Row({ space: 8 }) {
          Text('🍽')
            .fontSize(18)
          Text('菜品分类')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A1A')
        }
        .layoutWeight(1)

        Text('左右滑动')
          .fontSize(11)
          .fontColor('#AAAAAA')
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 12, bottom: 10 })

      // 使用List组件实现更流畅的横向滑动
      List({ space: 10 }) {
        ForEach(this.categories, (category: string, index: number) => {
          ListItem() {
            Column() {
              Text(category)
                .fontSize(14)
                .fontWeight(this.selectedCategory === category ? FontWeight.Bold : FontWeight.Medium)
                .fontColor(this.selectedCategory === category ? '#FFFFFF' : '#666666')
                .padding({
                  left: 20,
                  right: 20,
                  top: 10,
                  bottom: 10
                })
                .backgroundColor(this.selectedCategory === category ? '#007DFF' : '#F0F2F5')
                .borderRadius(20)
                .shadow(this.selectedCategory === category ? {
                  radius: 8,
                  color: '#40007DFF',
                  offsetX: 0,
                  offsetY: 2
                } : {
                  radius: 0,
                  color: '#00000000',
                  offsetX: 0,
                  offsetY: 0
                })
            }
            .onClick(() => {
              this.selectedCategory = category;
            })
          }
        }, (category: string) => category)
      }
      .listDirection(Axis.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .height(50)
      .padding({ left: 16, right: 16 })
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
  }

  // 右下角浮动购物车按钮 - 优化设计
  @Builder
  FloatingCartButton() {
    Column() {
      // 购物车按钮
      Button({ type: ButtonType.Normal }) {
        Stack({ alignContent: Alignment.TopEnd }) {
          Column() {
            Image($r('app.media.shopping_cart'))
              .width(24)
              .height(24)
              .fillColor('#FFFFFF')
          }
          .width(56)
          .height(56)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)

          // 购物车数量徽章
          if (this.cartItemCount > 0) {
            Text(this.cartItemCount > 99 ? '99+' : this.cartItemCount.toString())
              .fontSize(10)
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Bold)
              .backgroundColor('#FF3B30')
              .padding({
                left: this.cartItemCount > 9 ? 5 : 6,
                right: this.cartItemCount > 9 ? 5 : 6,
                top: 2,
                bottom: 2
              })
              .borderRadius(10)
              .textAlign(TextAlign.Center)
              .border({ width: 2, color: '#FFFFFF' })
              .position({ x: 32, y: 2 })
          }
        }
      }
      .width(56)
      .height(56)
      .backgroundColor('#007DFF')
      .borderRadius(28)
      .shadow({
        radius: 16,
        color: '#50007DFF',
        offsetX: 0,
        offsetY: 6
      })
      .onClick(() => {
        router.pushUrl({ url: 'pages/CartPage' });
      })

      // 显示总金额
      if (this.cartTotalAmount > 0) {
        Text(`¥${this.cartTotalAmount.toFixed(0)}`)
          .fontSize(11)
          .fontColor('#007DFF')
          .fontWeight(FontWeight.Bold)
          .margin({ top: 4 })
      }
    }
    .alignItems(HorizontalAlign.Center)
  }

  // 加载视图
  @Builder
  LoadingView() {
    Column() {
      LoadingProgress()
        .width(50)
        .height(50)
        .color('#007DFF')

      Text('美味加载中...')
        .fontSize(14)
        .fontColor('#666666')
        .margin({ top: 16 })
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  // 菜品列表视图
  @Builder
  DishListView() {
    Column() {
      if (this.getFilteredDishes().length === 0) {
        this.EmptyDishView()
      } else {
        // 显示菜品数量
        Row() {
          Text(`共 ${this.getFilteredDishes().length} 道菜品`)
            .fontSize(12)
            .fontColor('#999999')
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: 8, bottom: 4 })

        Column({ space: 10 }) {
          ForEach(this.getFilteredDishes(), (dish: Dish) => {
            this.DishItem(dish)
          }, (dish: Dish) => dish.id.toString())
        }
        .width('100%')
        .padding({ left: 12, right: 12, bottom: 16, top: 4 })
      }
    }
  }

  // 空状态视图
  @Builder
  EmptyDishView() {
    Column() {
      Image($r('app.media.empty'))
        .width(150)
        .height(150)
        .margin({ bottom: 24 })

      Text('暂无菜品')
        .fontSize(16)
        .fontColor('#999999')
        .margin({ bottom: 8 })

      if (!this.isCustomerMode) {
        Text('当前分类暂无菜品，快去添加吧')
          .fontSize(14)
          .fontColor('#CCCCCC')

        Button({ type: ButtonType.Capsule, stateEffect: true }) {
          Text('添加菜品')
            .fontSize(14)
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Medium)
        }
        .height(38)
        .padding({ left: 24, right: 24 })
        .backgroundColor('#007DFF')
        .borderRadius(19)
        .margin({ top: 20 })
        .onClick(() => {
          this.navigateToAddDishPage();
        })
      } else {
        Text('请稍候，服务员将为您推荐菜品')
          .fontSize(14)
          .fontColor('#CCCCCC')
      }
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  // 菜品项 - 优化设计
  @Builder
  DishItem(dish: Dish) {
    Row() {
      // 菜品图片
      Stack({ alignContent: Alignment.TopStart }) {
        if (dish.imageUrl) {
          if (dish.imageUrl.startsWith('app.media.')) {
            Image($r(dish.imageUrl))
              .width(100)
              .height(100)
              .borderRadius(12)
              .objectFit(ImageFit.Cover)
          } else {
            Image(this.normalizeDishImagePath(dish.imageUrl))
              .width(100)
              .height(100)
              .borderRadius(12)
              .objectFit(ImageFit.Cover)
          }
        } else {
          Image($r('app.media.dish1'))
            .width(100)
            .height(100)
            .borderRadius(12)
            .objectFit(ImageFit.Cover)
        }

        // 推荐标签
        if (dish.isRecommended) {
          Text('荐')
            .fontSize(10)
            .fontColor('#FFFFFF')
            .padding({ left: 6, right: 6, top: 3, bottom: 3 })
            .backgroundColor('#FF6B00')
            .borderRadius({ topLeft: 12, bottomRight: 8 })
        }
      }
      .margin({ right: 12 })

      // 菜品信息
      Column() {
        // 名称和评分
        Row() {
          Text(dish.name)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A1A')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)

          Row({ space: 2 }) {
            Image($r('app.media.star'))
              .width(12)
              .height(12)
              .fillColor('#FFB800')
            Text((dish.rating || 4.5).toFixed(1))
              .fontSize(12)
              .fontColor('#FF9500')
              .fontWeight(FontWeight.Medium)
            Text('点击评价')
              .fontSize(10)
              .fontColor('#007DFF')
              .margin({ left: 4 })
          }
          .onClick(() => {
            // 跳转到菜品详情页进行评价
            router.pushUrl({
              url: 'pages/DishDetailPage',
              params: { dishId: dish.id, dish: dish }
            });
          })
        }
        .width('100%')

        // 描述
        Text(dish.description || '美味可口，值得品尝')
          .fontSize(12)
          .fontColor('#888888')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 4 })

        // 销量标签
        Row({ space: 8 }) {
          Text(`月售${dish.sales}`)
            .fontSize(11)
            .fontColor('#999999')
          if (dish.cookingMethod) {
            Text(dish.cookingMethod)
              .fontSize(11)
              .fontColor('#007DFF')
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .backgroundColor('#E6F2FF')
              .borderRadius(4)
          }
        }
        .margin({ top: 6 })

        // 价格和购物车按钮
        Row() {
          Row() {
            Text('¥')
              .fontSize(14)
              .fontColor('#FF3B30')
              .fontWeight(FontWeight.Bold)
            Text(dish.price.toFixed(2))
              .fontSize(18)
              .fontColor('#FF3B30')
              .fontWeight(FontWeight.Bold)
          }
          .layoutWeight(1)

          // 加入购物车按钮
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            Text('+')
              .fontSize(20)
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Bold)
          }
          .width(32)
          .height(32)
          .backgroundColor('#007DFF')
          .shadow({
            radius: 6,
            color: '#40007DFF',
            offsetX: 0,
            offsetY: 2
          })
          .onClick(() => {
            console.info('加入购物车按钮被点击，菜品：' + dish.name);
            this.addToCart(dish);
          })
        }
        .width('100%')
        .margin({ top: 8 })
        .alignItems(VerticalAlign.Center)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.SpaceBetween)
      .height(100)
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .shadow({
      radius: 8,
      color: '#0A000000',
      offsetX: 0,
      offsetY: 2
    })
    .onClick(() => {
      this.openDishDetail(dish);
    })
  }

  @Builder
  StarRating(score: number, size: number = 16, interactive: boolean = false, onChange?: (value: number) => void) {
    Row({ space: 4 }) {
      ForEach([0, 1, 2, 3, 4], (index: number) => {
        Image($r('app.media.star'))
          .width(size)
          .height(size)
          .fillColor(score >= index + 1 ? '#FFB800' : '#D9D9D9')
          .opacity(score >= index + 1 ? 1 : (score > index && score < index + 1 ? 0.7 : 0.4))
          .onClick(() => {
            if (interactive && onChange) {
              onChange(index + 1);
            }
          })
      }, (index: number) => index.toString())
    }
  }

  @Builder
  DishDetailDialog() {
    Column() {
      Blank()
        .layoutWeight(1)
        .onClick(() => {
          this.closeDishDetail();
        })

      Column() {
        Row() {
          Text('菜品详情')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A1A')
            .layoutWeight(1)
            .textAlign(TextAlign.Center)

          Image($r('app.media.back_icon'))
            .width(24)
            .height(24)
            .fillColor('#333333')
            .onClick(() => {
              this.closeDishDetail();
            })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 16, bottom: 8 })

        Scroll() {
          Column({ space: 20 }) {
            if (this.selectedDish) {
              this.DishHeroSection(this.selectedDish)
              this.DishMetaSection(this.selectedDish)
              this.DishCookingSection(this.selectedDish)
              this.DishReviewSection(this.selectedDish, this.getDishReviews(this.selectedDish.id))
            }
          }
          .width('100%')
          .padding({ left: 20, right: 20, bottom: 120 })
        }
        .layoutWeight(1)

        Row({ space: 12 }) {
          Button('加入购物车', { type: ButtonType.Normal, stateEffect: true })
            .layoutWeight(1)
            .height(48)
            .backgroundColor('#007DFF')
            .fontColor('#FFFFFF')
            .fontSize(16)
            .borderRadius(24)
            .onClick(() => {
              if (this.selectedDish) {
                this.addToCart(this.selectedDish);
              }
            })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 12, bottom: 28 })
        .backgroundColor('#FFFFFF')
        .shadow({
          radius: 12,
          color: '#20000000',
          offsetX: 0,
          offsetY: -4
        })
      }
      .width('100%')
      .height('82%')
      .backgroundColor('#FFFFFF')
      .borderRadius({ topLeft: 24, topRight: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#99000000')
  }

  @Builder
  MapPreviewDialog() {
    Column() {
      Blank()
        .layoutWeight(1)
        .onClick(() => {
          this.closeMapDialog();
        })

      Column({ space: 12 }) {
        Row() {
          Text('店铺地图')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)

          Image($r('app.media.close'))
            .width(20)
            .height(20)
            .fillColor('#333333')
            .onClick(() => {
              this.closeMapDialog();
            })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 18, bottom: 10 })

        // 静态地图预览（Map SDK暂不可用）
        Column() {
          Image($r('app.media.location'))
            .width(48)
            .height(48)
            .fillColor('#007DFF')
            .margin({ bottom: 12 })

          Text('店铺位置')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1A1A1A')
            .margin({ bottom: 8 })

          Text(`经度: ${this.mapCenterLng.toFixed(4)}`)
            .fontSize(13)
            .fontColor('#666666')
            .margin({ bottom: 4 })

          Text(`纬度: ${this.mapCenterLat.toFixed(4)}`)
            .fontSize(13)
            .fontColor('#666666')
        }
        .width('92%')
        .height(260)
        .borderRadius(20)
        .backgroundColor('#F5F8FF')
        .alignSelf(ItemAlign.Center)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)

        Column({ space: 4 }) {
          Text('店铺地址')
            .fontSize(13)
            .fontColor('#888888')
          Text(this.shopInfo.address || '未配置')
            .fontSize(15)
            .fontColor('#1A1A1A')
            .fontWeight(FontWeight.Medium)
        }
        .width('90%')
        .alignSelf(ItemAlign.Center)

        Button('我知道了', { type: ButtonType.Capsule, stateEffect: true })
          .width('90%')
          .height(46)
          .backgroundColor('#007DFF')
          .fontColor('#FFFFFF')
          .fontSize(16)
          .borderRadius(23)
          .alignSelf(ItemAlign.Center)
          .margin({ bottom: 24 })
          .onClick(() => {
            this.closeMapDialog();
          })
      }
      .width('100%')
      .backgroundColor('#FFFFFF')
      .borderRadius({ topLeft: 24, topRight: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#80000000')
  }

  @Builder
  DishHeroSection(dish: Dish) {
    Column({ space: 12 }) {
      Stack() {
        if (dish.imageUrl && dish.imageUrl.startsWith('app.media.')) {
          Image($r(dish.imageUrl))
            .width('100%')
            .height(220)
            .borderRadius(20)
            .objectFit(ImageFit.Cover)
        } else if (dish.imageUrl) {
          Image(this.normalizeDishImagePath(dish.imageUrl))
            .width('100%')
            .height(220)
            .borderRadius(20)
            .objectFit(ImageFit.Cover)
        } else {
          Image($r('app.media.image_gallery'))
            .width('100%')
            .height(220)
            .borderRadius(20)
            .objectFit(ImageFit.Cover)
        }

        Column({ space: 6 }) {
          Row({ space: 12 }) {
            Text(dish.category || '美味菜品')
              .fontSize(12)
              .fontColor('#FFFFFF')
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .backgroundColor('#40000000')
              .borderRadius(14)

            Text(dish.cookTime || this.getDefaultCookTime(dish.category))
              .fontSize(12)
              .fontColor('#FFFFFF')
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .backgroundColor('#40000000')
              .borderRadius(14)
          }

          Column({ space: 6 }) {
            Row({ space: 6 }) {
              this.StarRating(dish.rating || 0)
              Text(`${(dish.rating || 0).toFixed(1)}分`)
                .fontSize(14)
                .fontColor('#FFFFFF')
                .fontWeight(FontWeight.Medium)
              Text(`${dish.reviewCount || 0} 条评价`)
                .fontSize(12)
                .fontColor('#F5F5F5')
            }
            Text(dish.name)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')

            Text(dish.description || '厨师精选 · 现点现做 · 美味即达')
              .fontSize(13)
              .fontColor('#F2F2F2')
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .padding({ left: 16, right: 16, bottom: 18, top: 18 })
        .width('100%')
        .backgroundImage('linear-gradient(to top, rgba(0,0,0,0.7), rgba(0,0,0,0.05))')
        .borderRadius(20)
        .alignItems(HorizontalAlign.Start)
      }

      Row({ space: 24 }) {
        this.DishStatCard('售价', `¥${dish.price.toFixed(2)}`, '每日限量供应')
        this.DishStatCard('月售', `${dish.sales} 份`, '出餐高峰常售罄')
      }

      Row({ space: 10 }) {
        ForEach(this.resolveFlavorTags(dish), (tag: string) => {
          Text(tag)
            .fontSize(12)
            .fontColor('#007DFF')
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .backgroundColor('#E8F2FF')
            .borderRadius(14)
        }, (tag: string) => `${dish.id}-${tag}`)
      }
    }
  }

  @Builder
  DishStatCard(title: string, value: string, tip: string) {
    Column({ space: 4 }) {
      Text(title)
        .fontSize(12)
        .fontColor('#999999')
      Text(value)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A1A')
      Text(tip)
        .fontSize(11)
        .fontColor('#BBBBBB')
    }
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor('#F7F9FC')
    .borderRadius(16)
    .layoutWeight(1)
  }

  @Builder
  DishMetaSection(dish: Dish) {
    Column({ space: 12 }) {
      Text('菜品亮点')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A1A')

      Column({ space: 12 }) {
        this.DetailInfoRow('所属分类', dish.category || '暂无分类信息')
        this.DetailInfoRow('预计出餐', dish.cookTime || this.getDefaultCookTime(dish.category))
        this.DetailInfoRow('主要食材', dish.ingredients || this.getDefaultIngredients(dish.category))
      }
      .padding(16)
      .backgroundColor('#FFFFFF')
      .borderRadius(16)
      .shadow({
        radius: 6,
        color: '#08000000',
        offsetX: 0,
        offsetY: 2
      })
    }
  }

  @Builder
  DetailInfoRow(label: string, value: string) {
    Column() {
      Text(label)
        .fontSize(12)
        .fontColor('#999999')
      Text(value)
        .fontSize(14)
        .fontColor('#1A1A1A')
        .fontWeight(FontWeight.Medium)
        .margin({ top: 4 })
    }
  }

  @Builder
  DishCookingSection(dish: Dish) {
    Column({ space: 10 }) {
      Text('烹饪方式')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A1A')

      Text(dish.cookingMethod || '厨师正在补充详细做法，敬请期待。')
        .fontSize(14)
        .fontColor('#555555')
        .lineHeight(22)
        .backgroundColor('#FFFFFF')
        .padding(16)
        .borderRadius(16)
    }
  }

  @Builder
  DishReviewSection(dish: Dish, reviews: DishReview[]) {
    Column({ space: 12 }) {
      Text('食客评价')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A1A')

      if (reviews.length === 0) {
        Column() {
          Text('还没有评价，成为第一位品鉴官吧')
            .fontSize(13)
            .fontColor('#999999')
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#FFFFFF')
        .borderRadius(16)
      } else {
        Column({ space: 12 }) {
          ForEach(reviews, (review: DishReview) => {
            this.ReviewCard(review)
          }, (review: DishReview) => review.id.toString())
        }
      }

      Column({ space: 12 }) {
        Text('写下你的感受')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1A1A1A')

        Row({ space: 8 }) {
          Text('评分')
            .fontSize(13)
            .fontColor('#666666')
          this.StarRating(this.reviewRating, 20, true, (value: number) => {
            this.reviewRating = value;
          })
          Text(`${this.reviewRating} 分`)
            .fontSize(12)
            .fontColor('#FF9500')
        }

        TextInput({ placeholder: '分享口味、口感或搭配建议', text: this.reviewContent })
          .width('100%')
          .height(90)
          .backgroundColor('#F5F5F5')
          .borderRadius(12)
          .padding(12)
          .maxLines(4)
          .onChange((value: string) => {
            this.reviewContent = value;
          })

        Button('提交评价', { type: ButtonType.Capsule, stateEffect: true })
          .width('100%')
          .height(44)
          .backgroundColor('#34C759')
          .fontColor('#FFFFFF')
          .fontSize(15)
          .borderRadius(22)
          .enabled(this.reviewContent.trim().length > 0)
          .opacity(this.reviewContent.trim().length > 0 ? 1 : 0.5)
          .onClick(() => {
            this.submitDishReview();
          })
      }
      .padding(16)
      .backgroundColor('#FFFFFF')
      .borderRadius(16)
    }
  }

  @Builder
  ReviewCard(review: DishReview) {
    Column({ space: 8 }) {
      Row({ space: 10 }) {
        Image($r('app.media.ic_user_avatar'))
          .width(36)
          .height(36)
          .borderRadius(18)
          .backgroundColor('#F0F0F0')

        Column() {
          Text(review.user)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1A1A1A')
          Row({ space: 6 }) {
            this.StarRating(review.rating, 14, false)
            Text(this.formatReviewTime(review.createdAt))
              .fontSize(11)
              .fontColor('#999999')
          }
        }
        .layoutWeight(1)
      }

      Text(review.content)
        .fontSize(13)
        .fontColor('#444444')
        .lineHeight(20)

      if (review.highlights && review.highlights.length > 0) {
        Row({ space: 8 }) {
          ForEach(review.highlights, (tag: string) => {
            Text(tag)
              .fontSize(11)
              .fontColor('#FF6B00')
              .padding({ left: 10, right: 10, top: 4, bottom: 4 })
              .backgroundColor('#FFF3E6')
              .borderRadius(12)
          }, (tag: string) => `${review.id}-${tag}`)
        }
      }
    }
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .shadow({
      radius: 4,
      color: '#08000000',
      offsetX: 0,
      offsetY: 2
    })
  }

  openDishDetail(dish: Dish) {
    if (!dish) {
      return;
    }
    // 跳转到独立的菜品详情页面
    router.pushUrl({
      url: 'pages/DishDetailPage',
      params: {
        dishId: dish.id,
        dish: dish
      }
    });
  }

  closeDishDetail() {
    this.showDishDetail = false;
    this.selectedDish = undefined;
    this.reviewContent = '';
  }

  private getDishReviews(dishId: number): DishReview[] {
    return this.dishReviewStore[dishId] ? this.dishReviewStore[dishId] : [];
  }

  private createDefaultReviews(dish: Dish): DishReview[] {
    const now = Date.now();
    const baseRating = dish.rating || 4.8;
    return [
      {
        id: Number(`${dish.id}01`),
        user: '美食客·温暖',
        rating: Math.min(5, Math.max(4, Math.round(baseRating))),
        content: `${dish.name} 非常下饭，口感层次丰富，搭配米饭一绝！`,
        createdAt: now - 1000 * 60 * 60 * 4,
        highlights: ['口味正宗', '分量足']
      },
      {
        id: Number(`${dish.id}02`),
        user: '吃货笔记',
        rating: Math.min(5, Math.max(4, Math.round(baseRating - 0.2))),
        content: '食材新鲜，火候把握得很好，推荐加一份招牌饮品更搭。',
        createdAt: now - 1000 * 60 * 60 * 10,
        highlights: ['出餐快', '环境好']
      }
    ];
  }

  private submitDishReview() {
    if (!this.selectedDish) {
      return;
    }
    const content = this.reviewContent.trim();
    if (content.length === 0) {
      ToastUtils.showToast('请输入评价内容');
      return;
    }
    const dishId = this.selectedDish.id;
    const current = this.getDishReviews(dishId);
    const newReview: DishReview = {
      id: Date.now(),
      user: '匿名食客',
      rating: this.reviewRating,
      content,
      createdAt: Date.now(),
      highlights: ['口味', '服务']
    };
    const updated: DishReview[] = current.concat(newReview);
    if (!this.dishReviewStore) {
      this.dishReviewStore = {};
    }
    this.dishReviewStore[dishId] = updated;
    this.reviewContent = '';
    this.reviewRating = 5;
    this.recalculateDishRating(dishId, updated);
    ToastUtils.showToast('感谢您的评价');
  }

  private recalculateDishRating(dishId: number, reviews: DishReview[]) {
    if (reviews.length === 0) {
      return;
    }
    const total = reviews.reduce((sum: number, review: DishReview) => sum + review.rating, 0);
    const avg = parseFloat((total / reviews.length).toFixed(1));
    this.dishes = this.dishes.map((item: Dish) => {
      if (item.id === dishId) {
        const updated = this.cloneDish(item);
        updated.rating = avg;
        updated.reviewCount = reviews.length;
        if (this.selectedDish && this.selectedDish.id === dishId) {
          this.selectedDish = updated;
        }
        return updated;
      }
      return item;
    });
  }

  private resolveFlavorTags(dish: Dish): string[] {
    if (dish.flavorTags && dish.flavorTags.length > 0) {
      return dish.flavorTags;
    }
    return this.getDefaultFlavorTags(dish.category);
  }

  private formatReviewTime(timestamp: number): string {
    const diff = Date.now() - timestamp;
    const minutes = Math.floor(diff / (1000 * 60));
    if (minutes < 60) {
      return `${Math.max(1, minutes)}分钟前`;
    }
    const hours = Math.floor(minutes / 60);
    if (hours < 24) {
      return `${hours}小时前`;
    }
    const days = Math.floor(hours / 24);
    return `${days}天前`;
  }

  private cloneDish(dish: Dish): Dish {
    const cloned = new Dish();
    // ArkTS 对标准库的限制使得不能直接使用 Object.assign，这里逐字段复制
    cloned.id = dish.id;
    cloned.name = dish.name;
    cloned.category = dish.category;
    cloned.price = dish.price;
    cloned.imageUrl = dish.imageUrl;
    cloned.description = dish.description;
    cloned.sales = dish.sales;
    cloned.tags = dish.tags;
    cloned.isSignature = dish.isSignature;
    cloned.isNew = dish.isNew;
    cloned.isRecommended = dish.isRecommended;
    cloned.rating = dish.rating;
    cloned.reviewCount = dish.reviewCount;
    cloned.flavorTags = dish.flavorTags;
    return cloned;
  }

  // 添加菜品对话框
  @Builder
  AddDishDialog() {
    // 半透明背景
    Column() {
      // 空白区域，点击关闭对话框
      Blank()
        .layoutWeight(1)
        .onClick(() => {
          this.showAddDishDialog = false;
          this.resetNewDishForm();
        })

      // 对话框内容
      Column() {
        // 标题栏
        Row() {
          Text('添加菜品')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A1A')
            .layoutWeight(1)
            .textAlign(TextAlign.Center)

          Image($r('app.media.back_icon'))
            .width(24)
            .height(24)
            .onClick(() => {
              this.showAddDishDialog = false;
              this.resetNewDishForm();
            })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 16, bottom: 16 })

        // 表单内容
        Scroll() {
          Column() {
            // 菜品照片
            Column() {
              Text('菜品照片')
                .fontSize(14)
                .fontColor('#333333')
                .margin({ bottom: 8 })

              Stack({ alignContent: Alignment.Center }) {
                if (this.newDish.imageUrl) {
                  if (this.newDish.imageUrl.startsWith('app.media.')) {
                    Image($r(this.newDish.imageUrl))
                      .width(120)
                      .height(120)
                      .borderRadius(12)
                      .objectFit(ImageFit.Cover)
                      .backgroundColor('#F5F5F5')
                  } else {
                    Image(this.getPreviewImageSource())
                      .width(120)
                      .height(120)
                      .borderRadius(12)
                      .objectFit(ImageFit.Cover)
                      .backgroundColor('#F5F5F5')
                  }

                  Button({ type: ButtonType.Normal }) {
                    Image($r('app.media.delete'))
                      .width(20)
                      .height(20)
                      .fillColor('#FFFFFF')
                  }
                  .width(32)
                  .height(32)
                  .backgroundColor('#CC000000')
                  .borderRadius(16)
                  .position({ x: 100, y: 4 })
                  .onClick(() => {
                    this.newDish.imageUrl = '';
                  })
                } else {
                  Column() {
                    if (this.imageProcessing) {
                      LoadingProgress()
                        .width(32)
                        .height(32)
                        .color('#007DFF')
                    } else {
                      Image($r('app.media.camera'))
                        .width(32)
                        .height(32)
                        .fillColor('#999999')
                        .margin({ bottom: 8 })
                    }
                    Text(this.imageProcessing ? '处理中...' : '点击上传图片')
                      .fontSize(12)
                      .fontColor('#999999')
                  }
                  .position({ x: 0, y: 0 })
                }
              }
              .width(120)
              .height(120)
              .onClick(() => {
                if (!this.imageProcessing) {
                  this.showImagePicker = true;
                }
              })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
            .margin({ top: 16 })

            // 菜品名称
            Column() {
              Text('菜品名称 *')
                .fontSize(14)
                .fontColor('#333333')
                .margin({ bottom: 8 })

              TextInput({ placeholder: '请输入菜品名称', text: this.newDish.name })
                .width('100%')
                .height(44)
                .backgroundColor('#F5F5F5')
                .borderRadius(8)
                .padding(12)
                .onChange((value: string) => {
                  this.newDish.name = value;
                })
            }
            .margin({ top: 16 })

            // 价格
            Column() {
              Text('价格 *')
                .fontSize(14)
                .fontColor('#333333')
                .margin({ bottom: 8 })

              TextInput({ placeholder: '0.00', text: this.newDish.price })
                .width('100%')
                .height(44)
                .backgroundColor('#F5F5F5')
                .borderRadius(8)
                .padding(12)
                .type(InputType.Number)
                .onChange((value: string) => {
                  this.newDish.price = value;
                })
            }
            .margin({ top: 16 })

            // 分类
            Column() {
              Text('分类 *')
                .fontSize(14)
                .fontColor('#333333')
                .margin({ bottom: 8 })

              Scroll() {
                Row() {
                  ForEach(this.categories.filter(c => c !== '全部'), (category: string) => {
                    Text(category)
                      .fontSize(14)
                      .fontColor(this.newDish.category === category ? '#FFFFFF' : '#666666')
                      .backgroundColor(this.newDish.category === category ? '#007DFF' : '#F0F0F0')
                      .padding({
                        left: 16,
                        right: 16,
                        top: 10,
                        bottom: 10
                      })
                      .borderRadius(16)
                      .margin({ right: 8 })
                      .onClick(() => {
                        this.newDish.category = category;
                      })
                  })
                }
                .padding(12)
              }
              .scrollBar(BarState.Off)
              .scrollable(ScrollDirection.Horizontal)
              .backgroundColor('#F5F5F5')
              .borderRadius(8)
            }
            .margin({ top: 16 })

            // 描述
            Column() {
              Text('描述')
                .fontSize(14)
                .fontColor('#333333')
                .margin({ bottom: 8 })

              TextInput({ placeholder: '请输入菜品描述', text: this.newDish.description })
                .width('100%')
                .height(80)
                .backgroundColor('#F5F5F5')
                .borderRadius(8)
                .padding(12)
                .onChange((value: string) => {
                  this.newDish.description = value;
                })
            }
            .margin({ top: 16 })

            // 做法
            Column() {
              Text('做法 *')
                .fontSize(14)
                .fontColor('#333333')
                .margin({ bottom: 8 })

              TextInput({ placeholder: '请输入详细做法步骤，方便厨房操作', text: this.newDish.cookingMethod })
                .width('100%')
                .height(100)
                .backgroundColor('#F5F5F5')
                .borderRadius(8)
                .padding(12)
                .maxLines(4)
                .onChange((value: string) => {
                  this.newDish.cookingMethod = value;
                })
            }
            .margin({ top: 16 })

            // 推荐开关
            Row() {
              Text('设为推荐菜品')
                .fontSize(14)
                .fontColor('#333333')
                .layoutWeight(1)

              Toggle({
                type: ToggleType.Switch,
                isOn: this.newDish.isRecommended
              })
                .onChange((value: boolean) => {
                  this.newDish.isRecommended = value;
                })
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#F5F5F5')
            .borderRadius(8)
            .margin({ top: 16 })

            // 快速添加示例菜品按钮
            Button('快速添加示例菜品', { type: ButtonType.Normal, stateEffect: true })
              .width('100%')
              .height(44)
              .backgroundColor('#34C759')
              .fontColor('#FFFFFF')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .borderRadius(22)
              .margin({ top: 16 })
              .onClick(() => {
                this.addSampleDishes();
                this.showAddDishDialog = false;
              })

            // 保存按钮
            Button('保存菜品', { type: ButtonType.Normal, stateEffect: true })
              .width('100%')
              .height(50)
              .backgroundColor('#007DFF')
              .fontColor('#FFFFFF')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .borderRadius(25)
              .margin({ top: 16, bottom: 24 })
              .onClick(() => {
                this.saveDish();
              })
          }
          .width('100%')
          .padding({ left: 20, right: 20 })
        }
        .layoutWeight(1)
      }
      .width('100%')
      .height('80%')
      .backgroundColor('#FFFFFF')
      .borderRadius({ topLeft: 20, topRight: 20 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#80000000')
    .onClick(() => {
      this.showAddDishDialog = false;
      this.resetNewDishForm();
    })
  }

  // 获取筛选后的菜品
  getFilteredDishes(): Dish[] {
    if (this.selectedCategory === '全部') {
      return this.dishes;
    }
    return this.dishes.filter(dish => dish.category === this.selectedCategory);
  }

  // 获取推荐菜品
  private buildDefaultFeaturedDishes(): Dish[] {
    const dishes: Dish[] = [];

    const dish1 = new Dish();
    dish1.id = -101;
    dish1.name = '宫保鸡丁';
    dish1.description = '鸡丁酥嫩，花生脆香，酸甜微辣的经典川味';
    dish1.cookingMethod = '鸡肉切丁腌制，辅以花生、辣椒爆炒，加入酱汁收汁即可。';
    dish1.price = 38;
    dish1.imageUrl = 'app.media.dish1';
    dish1.category = '招牌菜';
    dish1.isRecommended = true;
    dish1.status = 'available';
    dishes.push(dish1);

    const dish2 = new Dish();
    dish2.id = -102;
    dish2.name = '麻婆豆腐';
    dish2.description = '豆腐嫩滑，麻辣鲜香，地道川菜风味';
    dish2.cookingMethod = '豆腐焯水后与牛肉末、豆瓣酱同炒，加入花椒粉保持麻辣口感。';
    dish2.price = 28;
    dish2.imageUrl = 'app.media.dish2';
    dish2.category = '招牌菜';
    dish2.isRecommended = true;
    dish2.status = 'available';
    dishes.push(dish2);

    const dish3 = new Dish();
    dish3.id = -103;
    dish3.name = '糖醋里脊';
    dish3.description = '外酥里嫩，酸甜爽口，老少皆宜';
    dish3.cookingMethod = '里脊腌制后裹浆炸至金黄，糖醋汁勾芡翻炒包裹即可。';
    dish3.price = 42;
    dish3.imageUrl = 'app.media.dish3';
    dish3.category = '招牌菜';
    dish3.isRecommended = true;
    dish3.status = 'available';
    dishes.push(dish3);

    const dish4 = new Dish();
    dish4.id = -104;
    dish4.name = '红烧肉';
    dish4.description = '肥而不腻，入口即化的家常经典';
    dish4.cookingMethod = '五花肉焯水后加冰糖小火慢炖，加入酱油调色，收汁即成。';
    dish4.price = 48;
    dish4.imageUrl = 'app.media.dish4';
    dish4.category = '招牌菜';
    dish4.isRecommended = true;
    dish4.status = 'available';
    dishes.push(dish4);

    const dish5 = new Dish();
    dish5.id = -105;
    dish5.name = '清蒸鲈鱼';
    dish5.description = '鲜嫩清香，原汁原味的营养好味道';
    dish5.cookingMethod = '鲈鱼处理干净，铺姜葱蒸熟，淋热油与蒸鱼豉油即可。';
    dish5.price = 68;
    dish5.imageUrl = 'app.media.dish5';
    dish5.category = '招牌菜';
    dish5.isRecommended = true;
    dish5.status = 'available';
    dishes.push(dish5);

    return dishes;
  }

  private getDefaultFeaturedDishes(): Dish[] {
    if (!this.defaultFeaturedDishes || this.defaultFeaturedDishes.length === 0) {
      this.defaultFeaturedDishes = this.buildDefaultFeaturedDishes();
    }
    return this.defaultFeaturedDishes;
  }

  private getCarouselSlides(): Dish[] {
    if (!this.featuredSlides || this.featuredSlides.length === 0) {
      this.featuredSlides = this.buildCarouselSlidesFromAssets();
    }
    return this.featuredSlides;
  }

  private buildCarouselSlidesFromAssets(): Dish[] {
    const source: Dish[] = this.createLocalSampleDishes();
    if (!source || source.length === 0) {
      return [];
    }
    const fallbackImages: string[] = ['app.media.dish1', 'app.media.dish2', 'app.media.dish3', 'app.media.dish4', 'app.media.dish5'];
    const slides: Dish[] = [];
    for (let index = 0; index < Math.min(5, source.length); index++) {
      const original = source[index];
      const cloned = this.cloneDish(original);
      cloned.imageUrl = fallbackImages[index] || fallbackImages[fallbackImages.length - 1];
      cloned.isRecommended = true;
      slides.push(cloned);
    }
    return slides;
  }

  private async navigateToAddDishPage(): Promise<void> {
    if (this.isCustomerMode) {
      ToastUtils.showToast('顾客端不支持添加菜品');
      return;
    }
    try {
      await router.pushUrl({
        url: 'pages/AddDishPage',
        params: {}
      });
    } catch (error) {
      console.error('跳转添加菜品失败:' + JSON.stringify(error));
      // 如果跳转失败，打开内置对话框
      this.resetNewDishForm();
      if (!this.isCustomerMode) {
        this.showAddDishDialog = true;
      }
    }
  }

  private normalizeDishImagePath(path: string): string {
    if (!path) {
      return '';
    }
    const lower = path.toLowerCase();
    // 资源引用(app.media.xxx)
    if (path.startsWith('app.media.')) {
      return path;
    }
    // HTTP/HTTPS URL
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return path;
    }
    // file://协议
    if (lower.startsWith('file://')) {
      return path.replace('file://', '');
    }
    // 绝对路径
    if (path.startsWith('/')) {
      return path;
    }
    // 相对路径(dishes/xxx),需要转换为绝对路径
    if (!this.context) {
      try {
        this.context = getContext(this) as common.UIAbilityContext;
      } catch (error) {
        console.error('获取上下文失败:' + JSON.stringify(error));
        return path;
      }
    }
    if (!this.context) {
      return path;
    }
    // 如果是相对路径(如dishes/xxx),拼接filesDir
    return `${this.context.filesDir}/${path}`;
  }

  private async refreshHomeData(): Promise<void> {
    if (this.isRefreshing) {
      return;
    }
    this.isRefreshing = true;
    try {
      await this.loadShopData();
      await this.loadDishes();
      await this.loadCartData();
      this.featuredSlides = this.buildCarouselSlidesFromAssets();
    } catch (error) {
      console.error('刷新首页失败:' + JSON.stringify(error));
    } finally {
      this.isRefreshing = false;
    }
  }

  // 加载店铺数据
  async loadShopData() {
    try {
      const response: ApiResponse = await ApiUtils.get('/shops/info');
      if (response.statusCode === 200 && response.data) {
        const shopData = response.data as ShopInfoResponse;
        this.shopInfo.id = shopData.id || 0;
        this.shopInfo.shop_name = shopData.shop_name || '';
        this.shopInfo.name = shopData.shop_name || shopData.name || '食光记';
        this.shopInfo.description = shopData.description || '';
        this.shopInfo.business_hours = shopData.business_hours || '';
        this.shopInfo.businessHours = shopData.business_hours || '09:00-22:00';
        this.shopInfo.address = shopData.address || '宁夏大学中卫校区';
        this.shopInfo.phone = shopData.phone || '13800138000';
        this.shopInfo.score = shopData.score || 4.8;
        this.shopInfo.todayOrders = shopData.todayOrders || 45;
        this.shopInfo.todayRevenue = shopData.todayRevenue || 2860.50;
        if (typeof shopData.latitude === 'number' && typeof shopData.longitude === 'number') {
          this.shopInfo.latitude = shopData.latitude;
          this.shopInfo.longitude = shopData.longitude;
        } else {
          this.shopInfo.latitude = this.shopInfo.latitude ?? DEFAULT_LATITUDE;
          this.shopInfo.longitude = this.shopInfo.longitude ?? DEFAULT_LONGITUDE;
        }
      }
    } catch (error) {
      console.error('加载店铺信息失败:' + error);
      // 使用默认数据
      this.shopInfo = new ShopInfo();
    }
  }

  // 加载菜品数据
  async loadDishes() {
    try {
      this.isLoading = true;
      const response: ApiResponse = await ApiUtils.get('/dishes/list');

      if (response.statusCode === 200 && response.data) {
        const dishesData = response.data as DishListResponse[];
        if (Array.isArray(dishesData)) {
          this.dishes = dishesData.map((item: DishListResponse) => {
            const dish = new Dish();
            dish.id = item.id || 0;
            dish.name = item.name || '';
            dish.description = item.description || '';
            dish.cookingMethod = item.cooking_method || '';
            const priceValue = typeof item.price === 'string' ? parseFloat(item.price) : (item.price || 0);
            dish.price = priceValue;
            const rawImage = item.image_url || '';
            dish.imageUrl = this.normalizeDishImagePath(rawImage);
            dish.category = item.category || '';
            dish.isRecommended = item.is_recommended || false;
            dish.sales = item.sales || 0;
            dish.status = item.status || 'available';
            dish.quantity = 0;
            dish.rating = item.rating || this.generateFallbackRating(dish.category);
            dish.reviewCount = item.review_count || this.generateFallbackReviewCount();
            dish.ingredients = item.ingredients || this.getDefaultIngredients(dish.category);
            dish.cookTime = item.cook_time || this.getDefaultCookTime(dish.category);
            dish.flavorTags = (item.flavor_tags && item.flavor_tags.length > 0) ? item.flavor_tags : this.getDefaultFlavorTags(dish.category);
            return dish;
          });

          // 如果后端暂无菜品，使用本地示例菜品作为占位
          if (!this.dishes || this.dishes.length === 0) {
            const localDishes = this.createLocalSampleDishes();
            this.dishes = localDishes;
            // 同时将示例菜品添加到默认推荐菜品列表
            if (!this.defaultFeaturedDishes || this.defaultFeaturedDishes.length === 0) {
              this.defaultFeaturedDishes = localDishes.filter(d => d.isRecommended).slice(0, 5);
            }
          } else {
            // 如果后端有菜品，也确保有推荐菜品用于轮播
            const recommended = this.dishes.filter(d => d.isRecommended);
            if (recommended.length === 0) {
              // 如果没有推荐菜品，使用前5个作为推荐
              this.defaultFeaturedDishes = this.dishes.slice(0, 5).map(d => {
                const featured = new Dish();
                featured.id = d.id;
                featured.name = d.name;
                featured.description = d.description;
                featured.cookingMethod = d.cookingMethod;
                featured.price = d.price;
                featured.imageUrl = d.imageUrl;
                featured.category = d.category;
                featured.isRecommended = d.isRecommended;
                featured.sales = d.sales;
                featured.status = d.status;
                featured.quantity = d.quantity;
                return featured;
              });
            } else {
              this.defaultFeaturedDishes = recommended.slice(0, 5).map(d => {
                const featured = new Dish();
                featured.id = d.id;
                featured.name = d.name;
                featured.description = d.description;
                featured.cookingMethod = d.cookingMethod;
                featured.price = d.price;
                featured.imageUrl = d.imageUrl;
                featured.category = d.category;
                featured.isRecommended = d.isRecommended;
                featured.sales = d.sales;
                featured.status = d.status;
                featured.quantity = d.quantity;
                return featured;
              });
            }
          }
        }
      }
    } catch (error) {
      console.error('加载菜品失败:' + error);
      // 加载失败时回退到本地示例菜品，便于演示
      const localDishes = this.createLocalSampleDishes();
      this.dishes = localDishes;
      // 设置默认推荐菜品
      if (!this.defaultFeaturedDishes || this.defaultFeaturedDishes.length === 0) {
        this.defaultFeaturedDishes = localDishes.filter(d => d.isRecommended).slice(0, 5);
      }
    } finally {
      this.isLoading = false;
      if (!this.featuredSlides || this.featuredSlides.length === 0) {
        this.featuredSlides = this.buildCarouselSlidesFromAssets();
      }
    }
  }

  // 加载购物车数据
  async loadCartData() {
    try {
      const response: ApiResponse = await ApiUtils.get('/cart/items');
      if (response.statusCode === 200 && response.data) {
        const cartData: CartResponse = response.data as CartResponse;
        const localSummary = LocalCartManager.getSummary();
        const remoteQuantity = cartData.total_quantity || 0;
        const remoteAmount = cartData.total_amount || 0;
        this.cartItemCount = remoteQuantity + localSummary.quantity;
        this.cartTotalAmount = remoteAmount + localSummary.amount;
        CartSyncManager.updateCartQuantity(this.cartItemCount);
        CartSyncManager.updateCartTotalAmount(this.cartTotalAmount);
      }
    } catch (error) {
      console.error('加载购物车失败:' + error);
      const localSummary = LocalCartManager.getSummary();
      this.cartItemCount = localSummary.quantity;
      this.cartTotalAmount = localSummary.amount;
      CartSyncManager.updateCartQuantity(this.cartItemCount);
      CartSyncManager.updateCartTotalAmount(this.cartTotalAmount);
    }
  }

  // 添加到购物车
  async addToCart(dish: Dish) {
    if (!dish) {
      ToastUtils.showToast('菜品信息错误');
      return;
    }

    console.info(`添加菜品到购物车: ${dish.name}, ID: ${dish.id}, 价格: ${dish.price}`);

    // 示例菜品(id < 0 或 id 为 undefined/null/0)直接加入本地购物车
    if (dish.id === undefined || dish.id === null || dish.id <= 0) {
      console.info('示例菜品，使用本地购物车');
      this.handleAddToLocalCart(dish);
      ToastUtils.showToast(`${dish.name} 已加入购物车`);
      return;
    }

    try {
      const requestData: AddToCartRequest = {
        dish_id: dish.id,
        quantity: 1
      };

      const response: ApiResponse = await ApiUtils.post('/cart/add', requestData);

      if (response.statusCode === 200) {
        ToastUtils.showToast(`${dish.name} 已加入购物车`);
        await this.loadCartData();
      } else {
        // 如果后端添加失败，也加入本地购物车
        console.info('后端添加失败，回退到本地购物车');
        this.handleAddToLocalCart(dish);
        ToastUtils.showToast(`${dish.name} 已加入购物车`);
      }
    } catch (error) {
      console.error('添加到购物车失败:' + JSON.stringify(error));
      // 网络错误时加入本地购物车
      this.handleAddToLocalCart(dish);
      ToastUtils.showToast(`${dish.name} 已加入购物车`);
    }
  }

  private handleAddToLocalCart(dish: Dish) {
    const cartDish: Dish = this.prepareDishForLocalCart(dish);
    LocalCartManager.addDish(cartDish, 1);
    const summary = LocalCartManager.getSummary();
    this.cartItemCount = summary.quantity;
    this.cartTotalAmount = summary.amount;
    CartSyncManager.updateCartQuantity(this.cartItemCount);
    CartSyncManager.updateCartTotalAmount(this.cartTotalAmount);
  }

  private prepareDishForLocalCart(dish: Dish): Dish {
    if (dish.id && dish.id !== 0) {
      return dish;
    }
    const clonedDish = new Dish();
    clonedDish.id = this.generateLocalDishId(dish);
    clonedDish.name = dish.name;
    clonedDish.description = dish.description;
    clonedDish.cookingMethod = dish.cookingMethod;
    clonedDish.price = dish.price;
    clonedDish.imageUrl = dish.imageUrl;
    clonedDish.category = dish.category;
    clonedDish.isRecommended = dish.isRecommended;
    clonedDish.sales = dish.sales;
    clonedDish.status = dish.status;
    clonedDish.quantity = dish.quantity;
    clonedDish.rating = dish.rating;
    clonedDish.reviewCount = dish.reviewCount;
    clonedDish.ingredients = dish.ingredients;
    clonedDish.cookTime = dish.cookTime;
    clonedDish.flavorTags = dish.flavorTags;
    return clonedDish;
  }

  private generateLocalDishId(dish: Dish): number {
    const base: string = `${dish.name}-${dish.price}-${dish.category}`.trim();
    if (!base) {
      return -Date.now();
    }
    let hash: number = 0;
    for (let index = 0; index < base.length; index++) {
      hash = ((hash << 5) - hash) + base.charCodeAt(index);
      hash |= 0;
    }
    if (hash === 0) {
      hash = -Date.now();
    }
    return hash > 0 ? -hash : hash;
  }

  private async handleImageSelection(imageUri: string) {
    if (!imageUri || imageUri.length === 0) {
      return;
    }
    this.imageProcessing = true;
    try {
      const storedPath = await this.persistDishImage(imageUri);
      this.newDish.imageUrl = storedPath;
      ToastUtils.showToast('图片选择成功');
    } catch (error) {
      console.error('处理图片失败:' + JSON.stringify(error));
      ToastUtils.showToast('图片处理失败，请重试');
    } finally {
      this.imageProcessing = false;
    }
  }

  // 保存菜品
  async saveDish() {
    // 验证必填字段
    if (!this.newDish.name || !this.newDish.price || !this.newDish.category || !this.newDish.cookingMethod) {
      ToastUtils.showToast('请填写完整信息（名称、价格、分类、做法必填）');
      return;
    }

    // 验证价格格式
    const price = parseFloat(this.newDish.price);
    if (isNaN(price) || price <= 0) {
      ToastUtils.showToast('价格格式不正确');
      return;
    }

    try {
      const imagePayloadPath: string = this.normalizePayloadImagePath(this.newDish.imageUrl);
      const dishData: CreateDishRequest = {
        name: this.newDish.name,
        description: this.newDish.description || '',
        cooking_method: this.newDish.cookingMethod,
        price: price,
        category: this.newDish.category,
        is_recommended: this.newDish.isRecommended,
        image_url: imagePayloadPath,
        status: 'available'
      };

      const response: ApiResponse = await ApiUtils.post('/dishes/add', dishData);

      if (response.statusCode === 200) {
        ToastUtils.showToast('添加菜品成功');
        this.showAddDishDialog = false;
        this.resetNewDishForm();
        
        // 重新加载菜品列表
        await this.loadDishes();
      } else {
        ToastUtils.showToast(response.message || '添加菜品失败');
      }
    } catch (error) {
      console.error('添加菜品失败:' + error);
      ToastUtils.showToast('添加菜品失败，请重试');
    }
  }

  // 重置新菜品表单
  resetNewDishForm() {
    this.newDish = new NewDishForm();
  }

  // 图片选择器对话框
  @Builder
  ImagePickerDialog() {
    Column() {
      Blank()
        .layoutWeight(1)
        .onClick(() => {
          this.showImagePicker = false;
        })

      Column() {
        // 标题栏
        Row() {
          Text('选择图片')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A1A')
            .layoutWeight(1)
            .textAlign(TextAlign.Center)

          Image($r('app.media.close'))
            .width(24)
            .height(24)
            .onClick(() => {
              this.showImagePicker = false;
            })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 16, bottom: 16 })

        // 本地图片资源
        Column() {
          Text('本地图片')
            .fontSize(14)
            .fontColor('#666666')
            .margin({ bottom: 12, left: 20 })
            .alignSelf(ItemAlign.Start)

          Grid() {
            ForEach(this.localImages, (imagePath: string) => {
              GridItem() {
                Stack({ alignContent: Alignment.Center }) {
                  Image($r(imagePath))
                    .width('100%')
                    .height('100%')
                    .borderRadius(8)
                    .objectFit(ImageFit.Cover)

                  if (this.newDish.imageUrl === imagePath) {
                    Image($r('app.media.check_circle'))
                      .width(24)
                      .height(24)
                      .position({ x: 0, y: 0 })
                  }
                }
                .width('100%')
                .height('100%')
                .onClick(() => {
                  this.newDish.imageUrl = imagePath;
                  this.showImagePicker = false;
                  ToastUtils.showToast('图片选择成功');
                })
              }
            })
          }
          .columnsTemplate('1fr 1fr 1fr')
          .rowsGap(12)
          .columnsGap(12)
          .width('100%')
          .height(200)
          .padding({ left: 20, right: 20 })
        }
        .width('100%')
        .margin({ bottom: 20 })

        // 从相册选择按钮
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row() {
            Image($r('app.media.image_gallery'))
              .width(20)
              .height(20)
              .fillColor('#FFFFFF')
              .margin({ right: 8 })
            Text('从相册选择')
              .fontSize(16)
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Medium)
          }
        }
        .width('90%')
        .height(50)
        .backgroundColor('#007DFF')
        .borderRadius(25)
        .margin({ bottom: 12 })
        .onClick(() => {
          this.pickImageFromGallery();
        })

        // 拍照按钮
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row() {
            Image($r('app.media.camera'))
              .width(20)
              .height(20)
              .fillColor('#FFFFFF')
              .margin({ right: 8 })
            Text('拍照')
              .fontSize(16)
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Medium)
          }
        }
        .width('90%')
        .height(50)
        .backgroundColor('#34C759')
        .borderRadius(25)
        .margin({ bottom: 20 })
        .onClick(() => {
          this.takePhoto();
        })
      }
      .width('100%')
      .backgroundColor('#FFFFFF')
      .borderRadius({ topLeft: 20, topRight: 20 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#80000000')
    .onClick(() => {
      this.showImagePicker = false;
    })
  }

  // 从相册选择图片
  async pickImageFromGallery() {
    try {
      this.showImagePicker = false;
      const granted = await this.ensureMediaPermissions();
      if (!granted) {
        return;
      }
      const photoViewPicker = new picker.PhotoViewPicker();
      const photoSelectOptions = new picker.PhotoSelectOptions();
      photoSelectOptions.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
      photoSelectOptions.maxSelectNumber = 1;

      const photoSelectResult = await photoViewPicker.select(photoSelectOptions);
      if (photoSelectResult && photoSelectResult.photoUris && photoSelectResult.photoUris.length > 0) {
        const imageUri = photoSelectResult.photoUris[0];
        await this.handleImageSelection(imageUri);
      }
    } catch (error) {
      console.error('选择图片失败:', JSON.stringify(error));
      ToastUtils.showToast('选择图片失败，请重试');
    }
  }

  // 拍照
  async takePhoto() {
    try {
      this.showImagePicker = false;
      const granted = await this.ensureMediaPermissions();
      if (!granted) {
        return;
      }
      // 使用PhotoViewPicker，它会自动提供相册和相机选项
      const photoViewPicker = new picker.PhotoViewPicker();
      const photoSelectOptions = new picker.PhotoSelectOptions();
      photoSelectOptions.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
      photoSelectOptions.maxSelectNumber = 1;

      // PhotoViewPicker会自动显示相册和相机选项
      const photoSelectResult = await photoViewPicker.select(photoSelectOptions);
      if (photoSelectResult && photoSelectResult.photoUris && photoSelectResult.photoUris.length > 0) {
        const imageUri = photoSelectResult.photoUris[0];
        await this.handleImageSelection(imageUri);
      }
    } catch (error) {
      console.error('拍照失败:', JSON.stringify(error));
      ToastUtils.showToast('拍照失败，请重试');
    }
  }

  // 快速添加示例菜品
  async addSampleDishes() {
    const sampleDishes: CreateDishRequest[] = [
      {
        name: '宫保鸡丁',
        description: '经典川菜，鸡肉鲜嫩，花生香脆，微辣微甜',
        cooking_method: '鸡丁淀粉抓匀腌制，花生炸香后与辣椒、花椒一同大火翻炒，加入糖醋酱汁收汁。',
        price: 38.00,
        category: '热菜',
        is_recommended: true,
        image_url: 'app.media.dish1',
        status: 'available'
      },
      {
        name: '麻婆豆腐',
        description: '四川传统名菜，豆腐嫩滑，麻辣鲜香',
        cooking_method: '豆腐焯水定型，锅中炒香牛肉末与豆瓣酱，加入豆腐小火煮，撒花椒粉提麻香。',
        price: 28.00,
        category: '热菜',
        is_recommended: true,
        image_url: 'app.media.dish2',
        status: 'available'
      },
      {
        name: '糖醋里脊',
        description: '酸甜可口，外酥里嫩，老少皆宜',
        cooking_method: '里脊条裹浆炸至金黄，锅中调糖醋汁，快速翻炒使酱汁包裹均匀。',
        price: 42.00,
        category: '热菜',
        is_recommended: true,
        image_url: 'app.media.dish3',
        status: 'available'
      },
      {
        name: '红烧肉',
        description: '肥而不腻，入口即化，经典家常菜',
        cooking_method: '五花肉焯水后与冰糖翻炒上色，加入酱油与香料慢炖收汁。',
        price: 48.00,
        category: '热菜',
        is_recommended: true,
        image_url: 'app.media.dish4',
        status: 'available'
      },
      {
        name: '清蒸鲈鱼',
        description: '鲜嫩清香，营养丰富，健康美味',
        cooking_method: '鲈鱼处理干净后铺姜丝蒸熟，淋热油和蒸鱼豉油提味。',
        price: 68.00,
        category: '热菜',
        is_recommended: false,
        image_url: 'app.media.dish5',
        status: 'available'
      },
      {
        name: '酸辣土豆丝',
        description: '酸香爽脆，小炒必备，家常经典',
        cooking_method: '土豆丝冲淋去淀粉，锅中热油放干辣椒、花椒爆香，加入土豆丝翻炒，调入醋和盐。',
        price: 18.00,
        category: '凉菜',
        is_recommended: false,
        image_url: 'app.media.default_dish',
        status: 'available'
      },
      {
        name: '牛肉拉面',
        description: '汤鲜味浓，面条劲道，暖胃主食',
        cooking_method: '牛肉与香料炖煮成汤底，拉制面条煮熟后浇上牛肉汤即可。',
        price: 32.00,
        category: '主食',
        is_recommended: true,
        image_url: 'app.media.dish3',
        status: 'available'
      },
      {
        name: '芒果布丁',
        description: '香甜丝滑，清爽解腻，午后甜点',
        cooking_method: '芒果泥与牛奶、吉利丁混合，倒入模具冷藏凝固，食用前点缀芒果粒。',
        price: 22.00,
        category: '甜品',
        is_recommended: true,
        image_url: 'app.media.default_dish',
        status: 'available'
      }
    ];

    let successCount = 0;
    for (const dishData of sampleDishes) {
      try {
        const response: ApiResponse = await ApiUtils.post('/dishes/add', dishData);
        if (response.statusCode === 200) {
          successCount++;
        }
      } catch (error) {
        console.error('添加示例菜品失败:', error);
      }
    }

    if (successCount > 0) {
      ToastUtils.showToast(`成功添加 ${successCount} 个示例菜品`);
      await this.loadDishes();
    } else {
      ToastUtils.showToast('添加示例菜品失败');
    }
  }

  private generateFallbackRating(category: string): number {
    const baseMap: Record<string, number> = {
      '热菜': 4.7,
      '凉菜': 4.6,
      '主食': 4.7,
      '汤类': 4.8,
      '饮料': 4.8,
      '甜品': 4.9
    };
    const base = baseMap[category] || 4.7;
    const rating = base + Math.random() * 0.2;
    return parseFloat(rating.toFixed(1));
  }

  private generateFallbackReviewCount(): number {
    return 120 + Math.floor(Math.random() * 160);
  }

  private getDefaultCookTime(category: string): string {
    const mapping: Record<string, string> = {
      '热菜': '约15分钟',
      '凉菜': '约8分钟',
      '主食': '约20分钟',
      '汤类': '约25分钟',
      '饮料': '现做现调',
      '甜品': '约10分钟'
    };
    return mapping[category] || '约15分钟';
  }

  private getDefaultIngredients(category: string): string {
    const mapping: Record<string, string> = {
      '热菜': '甄选肉类 · 时蔬搭配',
      '凉菜': '新鲜蔬果 · 清爽佐料',
      '主食': '优选面点 · 现点现做',
      '汤类': '熬煮高汤 · 多料慢炖',
      '饮料': '鲜果 · 冰饮 · 手调',
      '甜品': '牛奶 · 鸡蛋 · 时令水果'
    };
    return mapping[category] || '当日采购 · 新鲜烹制';
  }

  private getDefaultFlavorTags(category: string): string[] {
    const mapping: Record<string, string[]> = {
      '热菜': ['热辣鲜香', '现炒出锅'],
      '凉菜': ['清爽开胃', '低脂健康'],
      '主食': ['饱腹首选', '能量充沛'],
      '汤类': ['暖胃滋补', '营养加倍'],
      '饮料': ['冰爽解腻', '轻负担'],
      '甜品': ['丝滑香甜', '下午茶']
    };
    return mapping[category] ? mapping[category].slice() : ['人气口碑', '招牌推荐'];
  }

  // 本地示例菜品（基于 dish1.png ~ dish5.png）
  createLocalSampleDishes(): Dish[] {
    // 使用interface替代对象字面量类型声明，满足 ArkTS 约束
    interface LocalDishSample {
      id: number;
      name: string;
      description: string;
      cookingMethod: string;
      price: number;
      image: string;
      category: string;
      isRecommended: boolean;
      sales: number;
      rating: number;
      reviewCount: number;
      ingredients: string;
      cookTime: string;
      flavorTags: string[];
    }
    const samples: LocalDishSample[] = [
      { id: -1, name: '宫保鸡丁', description: '鸡丁酥嫩 花生脆香 酸甜微辣', cookingMethod: '鸡丁淀粉抓匀腌制，花生炸香后与辣椒、葱段搭配爆炒，淋糖醋酱收汁。', price: 38, image: 'app.media.dish1', category: '热菜', isRecommended: true, sales: 328, rating: 4.9, reviewCount: 268, ingredients: '鸡胸肉·花生米·干辣椒·花椒', cookTime: '约15分钟', flavorTags: ['酸甜微辣', '下饭必点'] },
      { id: -2, name: '麻婆豆腐', description: '豆腐嫩滑 麻辣鲜香 下饭首选', cookingMethod: '豆腐切块焯水，锅中炒香豆瓣酱与牛肉末，加入豆腐小火煮，撒花椒粉提味。', price: 28, image: 'app.media.dish2', category: '热菜', isRecommended: true, sales: 412, rating: 4.8, reviewCount: 322, ingredients: '北豆腐·牛肉末·郫县豆瓣·花椒粉', cookTime: '约12分钟', flavorTags: ['麻辣鲜香', '米饭搭档'] },
      { id: -3, name: '糖醋里脊', description: '外酥里嫩 酸甜适口 老少皆宜', cookingMethod: '里脊条腌制后裹糊炸至金黄，锅中调糖醋汁快速翻炒裹匀。', price: 42, image: 'app.media.dish3', category: '热菜', isRecommended: true, sales: 295, rating: 4.9, reviewCount: 301, ingredients: '里脊肉·番茄酱·白醋·白芝麻', cookTime: '约18分钟', flavorTags: ['酸甜开胃', '儿童喜爱'] },
      { id: -4, name: '红烧肉', description: '肥而不腻 入口即化 经典家常', cookingMethod: '五花肉焯水后加冰糖慢炖，加入老抽、生抽和香料小火收汁。', price: 48, image: 'app.media.dish4', category: '热菜', isRecommended: true, sales: 366, rating: 4.7, reviewCount: 210, ingredients: '五花肉·老抽·生抽·冰糖', cookTime: '约40分钟', flavorTags: ['醇厚浓香', '米饭杀手'] },
      { id: -5, name: '清蒸鲈鱼', description: '清鲜不腥 原汁原味 健康低脂', cookingMethod: '鲈鱼处理干净抹盐，铺姜丝蒸熟后淋热油和蒸鱼豉油。', price: 68, image: 'app.media.dish5', category: '热菜', isRecommended: false, sales: 156, rating: 4.8, reviewCount: 146, ingredients: '鲜鲈鱼·姜丝·蒸鱼豉油', cookTime: '约15分钟', flavorTags: ['清淡少油', '高蛋白'] },
      { id: -6, name: '酸辣土豆丝', description: '酸香爽脆 小炒必备 家常经典', cookingMethod: '土豆丝冲淋去淀粉，锅中热油放干辣椒、花椒爆香，加入土豆丝翻炒，调入醋和盐。', price: 18, image: 'app.media.default_dish', category: '凉菜', isRecommended: false, sales: 238, rating: 4.6, reviewCount: 188, ingredients: '土豆丝·青红椒·干辣椒·米醋', cookTime: '约8分钟', flavorTags: ['脆爽解腻', '酸辣开胃'] },
      { id: -7, name: '牛肉拉面', description: '牛肉鲜香 汤汁浓郁 面条劲道', cookingMethod: '牛肉与香料炖煮成汤底，拉制面条入锅煮熟，浇上牛肉汤即可。', price: 32, image: 'app.media.dish3', category: '主食', isRecommended: true, sales: 189, rating: 4.7, reviewCount: 233, ingredients: '牛腱肉·手工面·八角·香菜', cookTime: '约20分钟', flavorTags: ['汤浓味厚', '暖胃饱腹'] },
      { id: -8, name: '芒果布丁', description: '香甜丝滑 清爽解腻 午后甜点', cookingMethod: '芒果泥与牛奶、吉利丁混合，倒入模具冷藏凝固，食用前点缀芒果粒。', price: 22, image: 'app.media.default_dish', category: '甜品', isRecommended: true, sales: 142, rating: 4.8, reviewCount: 165, ingredients: '芒果·牛奶·淡奶油·吉利丁', cookTime: '约10分钟+冷藏', flavorTags: ['清爽顺滑', '下午茶'] }
    ];

    return samples.map(s => {
      const d = new Dish();
      d.id = s.id;
      d.name = s.name;
      d.description = s.description;
      d.cookingMethod = s.cookingMethod;
      d.price = s.price;
      d.imageUrl = s.image;
      d.category = s.category;
      d.isRecommended = s.isRecommended;
      d.sales = s.sales;
      d.status = 'available';
      d.quantity = 0;
      d.rating = s.rating;
      d.reviewCount = s.reviewCount;
      d.ingredients = s.ingredients;
      d.cookTime = s.cookTime;
      d.flavorTags = s.flavorTags;
      return d;
    });
  }

  // 权限管理
  private async ensureMediaPermissions(): Promise<boolean> {
    if (this.mediaPermissionsGranted) {
      return true;
    }
    if (!this.atManager || !this.context) {
      ToastUtils.showToast('无法获取能力上下文');
      return false;
    }
    try {
      const result = await this.atManager.requestPermissionsFromUser(
        this.context,
        this.mediaPermissions
      ) as PermissionRequestResult;
      const granted = result.authResults.every((status: number) => status === 0);
      this.mediaPermissionsGranted = granted;
      if (!granted) {
        ToastUtils.showToast('请授予相册与相机权限后再试');
      }
      return granted;
    } catch (error) {
      console.error('申请媒体权限失败:' + JSON.stringify(error));
      ToastUtils.showToast('权限申请失败，请稍后重试');
      return false;
    }
  }

  // 保存菜品图片到应用私有目录
  private async persistDishImage(uri: string): Promise<string> {
    if (!this.context) {
      try {
        this.context = getContext(this) as common.UIAbilityContext;
      } catch (error) {
        console.error('获取上下文失败:' + JSON.stringify(error));
        return uri;
      }
    }
    if (!this.context) {
      return uri;
    }
    try {
      const sourcePath: string = this.resolveFilePath(uri);
      if (!sourcePath) {
        console.error('无法解析图片路径:' + uri);
        return uri;
      }
      
      // 检查源文件是否存在
      try {
        fs.accessSync(sourcePath);
      } catch (error) {
        console.error('源图片文件不存在:' + sourcePath);
        return uri;
      }
      
      // 确保应用私有目录存在
      const filesDir: string = this.context.filesDir;
      try {
        fs.accessSync(filesDir);
      } catch (error) {
        try {
          fs.mkdirSync(filesDir, true);
        } catch (mkdirError) {
          console.error('创建filesDir失败:' + JSON.stringify(mkdirError));
        }
      }
      
      // 创建dishes子目录用于存储菜品图片
      const dishesDir: string = `${filesDir}/dishes`;
      try {
        fs.accessSync(dishesDir);
      } catch (error) {
        try {
          fs.mkdirSync(dishesDir, true);
        } catch (mkdirError) {
          console.error('创建dishesDir失败:' + JSON.stringify(mkdirError));
        }
      }
      
      // 生成唯一文件名
      const extension: string = this.extractExtension(sourcePath, '.jpg');
      const fileName: string = `dish_${Date.now()}_${Math.floor(Math.random() * 10000)}${extension}`;
      const targetPath: string = `${dishesDir}/${fileName}`;
      
      // 复制文件到应用私有目录
      fs.copyFileSync(sourcePath, targetPath);
      
      // 返回相对路径(相对于filesDir),这样数据库只存储相对路径
      const relativePath: string = `dishes/${fileName}`;
      console.log('图片已保存到:' + targetPath + ', 相对路径:' + relativePath);
      return relativePath;
    } catch (error) {
      console.error('保存菜品图片失败:' + JSON.stringify(error));
      ToastUtils.showToast('图片保存失败，将使用原始路径');
      return uri;
    }
  }

  private resolveFilePath(uri: string): string {
    if (!uri) {
      return '';
    }
    if (uri.startsWith('file://')) {
      return uri.replace('file://', '');
    }
    return uri;
  }

  private extractExtension(path: string, fallback: string = '.jpg'): string {
    if (!path) {
      return fallback;
    }
    const dotIndex: number = path.lastIndexOf('.');
    if (dotIndex === -1 || dotIndex === path.length - 1) {
      return fallback;
    }
    return path.substring(dotIndex);
  }

  private normalizePayloadImagePath(path: string): string {
    if (!path) {
      return '';
    }
    // 如果是资源引用(app.media.xxx),直接返回
    if (path.startsWith('app.media.')) {
      return path;
    }
    // 如果已经是相对路径(dishes/xxx),直接返回
    if (path.startsWith('dishes/')) {
      return path;
    }
    // 如果是绝对路径,转换为相对路径
    return this.toRelativeDishPath(path);
  }

  private getPreviewImageSource(): string {
    if (!this.newDish.imageUrl) {
      return '';
    }
    if (this.newDish.imageUrl.startsWith('app.media.')) {
      return this.newDish.imageUrl;
    }
    return this.toAbsoluteDishPath(this.newDish.imageUrl);
  }

  private toRelativeDishPath(path: string): string {
    if (!path) {
      return '';
    }
    if (!this.context) {
      try {
        this.context = getContext(this) as common.UIAbilityContext;
      } catch (error) {
        console.error('获取上下文失败:' + JSON.stringify(error));
        return path;
      }
    }
    if (!this.context) {
      return path;
    }
    const filesDir: string = this.context.filesDir;
    // 如果路径以filesDir开头,提取相对路径
    if (path.startsWith(filesDir)) {
      const trimmed: string = path.substring(filesDir.length);
      return trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
    }
    // 如果路径已经是相对路径格式,直接返回
    if (!path.startsWith('/') && !path.startsWith('file://')) {
      return path;
    }
    // 其他情况返回原路径
    return path;
  }

  private toAbsoluteDishPath(path: string): string {
    if (!path) {
      return '';
    }
    const lower: string = path.toLowerCase();
    if (path.startsWith('app.media.')) {
      return path;
    }
    if (lower.startsWith('file://')) {
      return path.replace('file://', '');
    }
    if (path.startsWith('/')) {
      return path;
    }
    if (!this.context) {
      return path;
    }
    return `${this.context.filesDir}/${path}`;
  }
}


