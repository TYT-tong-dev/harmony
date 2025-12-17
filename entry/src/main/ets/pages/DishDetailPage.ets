// DishDetailPage.ets - 菜品详情页面
import router from '@ohos.router';
import { Dish, DishReview, ApiResponse } from '../common/Types';
import { ApiUtils, ToastUtils } from '../common/Utils';

interface RouterParams {
  dishId?: number;
  dish?: Dish;
}

interface ReviewData {
  id: number;
  dish_id: number;
  user_id: number;
  username: string;
  avatar: string;
  rating: number;
  content: string;
  created_at: number;
}

// 提交评价请求
interface SubmitReviewRequest {
  rating: number;
  content: string;
}

@Entry
@Component
struct DishDetailPage {
  @State dish: Dish = new Dish();
  @State reviews: DishReview[] = [];
  @State isLoading: boolean = false;
  @State showReviewDialog: boolean = false;
  @State myRating: number = 5;
  @State myReviewContent: string = '';
  @State isSubmitting: boolean = false;
  @State myReview: ReviewData | null = null; // 当前用户的评价

  aboutToAppear() {
    const params = router.getParams() as RouterParams;
    if (params?.dish) {
      this.dish = params.dish;
    }
    if (params?.dishId) {
      this.loadDishDetail(params.dishId);
    } else if (this.dish.id) {
      this.loadDishDetail(this.dish.id);
    }
  }

  build() {
    Stack() {
      Column() {
        // 顶部导航栏
        this.HeaderBar()

        // 内容区域
        Scroll() {
          Column() {
            // 菜品图片
            this.DishImage()

            // 菜品信息
            this.DishInfo()

            // 评价概览
            this.RatingOverview()

            // 评价列表
            this.ReviewList()
          }
          .width('100%')
          .padding({ bottom: 100 })
        }
        .layoutWeight(1)

        // 底部操作栏
        this.BottomBar()
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F5F5F5')

      // 评价对话框
      if (this.showReviewDialog) {
        this.ReviewDialog()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  HeaderBar() {
    Row() {
      Image($r('app.media.back_icon'))
        .width(24)
        .height(24)
        .onClick(() => { router.back(); })

      Text('菜品详情')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A1A')
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Blank().width(24)
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor('#FFFFFF')
  }

  @Builder
  DishImage() {
    Stack({ alignContent: Alignment.BottomStart }) {
      if (this.dish.imageUrl) {
        Image(this.normalizeImagePath(this.dish.imageUrl))
          .width('100%')
          .height(250)
          .objectFit(ImageFit.Cover)
      } else {
        Image($r('app.media.dish1'))
          .width('100%')
          .height(250)
          .objectFit(ImageFit.Cover)
      }

      // 推荐标签
      if (this.dish.isRecommended) {
        Text('主厨推荐')
          .fontSize(12)
          .fontColor('#FFFFFF')
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .backgroundColor('#FF6B00')
          .borderRadius(4)
          .margin({ left: 16, bottom: 16 })
      }
    }
    .width('100%')
  }

  @Builder
  DishInfo() {
    Column() {
      // 名称和价格
      Row() {
        Text(this.dish.name)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
          .layoutWeight(1)

        Text(`¥${this.dish.price.toFixed(2)}`)
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FF6B00')
      }
      .width('100%')
      .margin({ bottom: 12 })

      // 分类
      Row() {
        Text('分类：')
          .fontSize(14)
          .fontColor('#666666')
        Text(this.dish.category || '未分类')
          .fontSize(14)
          .fontColor('#333333')
      }
      .width('100%')
      .margin({ bottom: 8 })

      // 做法
      if (this.dish.cookingMethod) {
        Row() {
          Text('做法：')
            .fontSize(14)
            .fontColor('#666666')
          Text(this.dish.cookingMethod)
            .fontSize(14)
            .fontColor('#333333')
        }
        .width('100%')
        .margin({ bottom: 8 })
      }

      // 销量
      Row() {
        Text('月销：')
          .fontSize(14)
          .fontColor('#666666')
        Text(`${this.dish.sales || 0} 份`)
          .fontSize(14)
          .fontColor('#333333')
      }
      .width('100%')
      .margin({ bottom: 12 })

      // 描述
      if (this.dish.description) {
        Text(this.dish.description)
          .fontSize(14)
          .fontColor('#666666')
          .lineHeight(22)
          .width('100%')
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .margin({ top: 12, left: 12, right: 12 })
    .borderRadius(12)
  }

  @Builder
  RatingOverview() {
    Column() {
      Row() {
        Text('用户评价')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
          .layoutWeight(1)

        Row() {
          ForEach([1, 2, 3, 4, 5], (star: number) => {
            Text('★')
              .fontSize(16)
              .fontColor(star <= Math.round(this.dish.rating) ? '#FFB800' : '#E0E0E0')
          })
          Text(` ${this.dish.rating.toFixed(1)}`)
            .fontSize(16)
            .fontColor('#FF6B00')
            .fontWeight(FontWeight.Bold)
            .margin({ left: 4 })
        }
      }
      .width('100%')

      Text(`共 ${this.dish.reviewCount || this.reviews.length} 条评价`)
        .fontSize(12)
        .fontColor('#999999')
        .margin({ top: 8 })
        .alignSelf(ItemAlign.Start)
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .margin({ top: 12, left: 12, right: 12 })
    .borderRadius(12)
  }

  @Builder
  ReviewList() {
    Column() {
      if (this.reviews.length === 0) {
        Column() {
          Text('暂无评价')
            .fontSize(14)
            .fontColor('#999999')
          Text('快来成为第一个评价的人吧~')
            .fontSize(12)
            .fontColor('#CCCCCC')
            .margin({ top: 8 })
        }
        .width('100%')
        .padding({ top: 40, bottom: 40 })
        .justifyContent(FlexAlign.Center)
      } else {
        ForEach(this.reviews, (review: DishReview) => {
          this.ReviewItem(review)
        }, (review: DishReview) => review.id.toString())
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .margin({ top: 12, left: 12, right: 12, bottom: 12 })
    .borderRadius(12)
  }

  @Builder
  ReviewItem(review: DishReview) {
    Column() {
      Row() {
        // 头像
        Image(review.avatar ? this.normalizeImagePath(review.avatar) : $r('app.media.ic_user_avatar'))
          .width(40)
          .height(40)
          .borderRadius(20)
          .margin({ right: 12 })

        Column() {
          Text(review.user)
            .fontSize(14)
            .fontColor('#333333')
            .fontWeight(FontWeight.Medium)

          Row() {
            ForEach([1, 2, 3, 4, 5], (star: number) => {
              Text('★')
                .fontSize(12)
                .fontColor(star <= review.rating ? '#FFB800' : '#E0E0E0')
            })
          }
          .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text(this.formatTime(review.createdAt))
          .fontSize(12)
          .fontColor('#999999')
      }
      .width('100%')

      Text(review.content)
        .fontSize(14)
        .fontColor('#666666')
        .lineHeight(22)
        .margin({ top: 12 })
        .width('100%')

      Divider()
        .strokeWidth(1)
        .color('#F0F0F0')
        .margin({ top: 16 })
    }
    .width('100%')
    .padding({ bottom: 16 })
  }

  @Builder
  BottomBar() {
    Row() {
      Button('写评价', { type: ButtonType.Normal })
        .layoutWeight(1)
        .height(48)
        .backgroundColor('#007DFF')
        .fontColor('#FFFFFF')
        .fontSize(16)
        .borderRadius(24)
        .onClick(() => {
          this.myRating = 5;
          this.myReviewContent = '';
          this.showReviewDialog = true;
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor('#FFFFFF')
    .shadow({ radius: 8, color: '#10000000', offsetX: 0, offsetY: -2 })
  }

  @Builder
  ReviewDialog() {
    Stack({ alignContent: Alignment.Center }) {
      // 背景遮罩
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#80000000')
        .onClick(() => { this.showReviewDialog = false; })

      // 对话框
      Column() {
        Text('评价菜品')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
          .margin({ bottom: 20 })

        // 星星评分
        Text('您的评分')
          .fontSize(14)
          .fontColor('#666666')
          .alignSelf(ItemAlign.Start)
          .margin({ bottom: 12 })

        Row({ space: 8 }) {
          ForEach([1, 2, 3, 4, 5], (star: number) => {
            Text('★')
              .fontSize(36)
              .fontColor(star <= this.myRating ? '#FFB800' : '#E0E0E0')
              .onClick(() => { this.myRating = star; })
          })
        }
        .margin({ bottom: 20 })

        // 评论内容
        Text('您的评价')
          .fontSize(14)
          .fontColor('#666666')
          .alignSelf(ItemAlign.Start)
          .margin({ bottom: 8 })

        TextArea({ placeholder: '请输入您对这道菜的评价...', text: this.myReviewContent })
          .width('100%')
          .height(120)
          .backgroundColor('#F5F5F5')
          .borderRadius(8)
          .onChange((value: string) => { this.myReviewContent = value; })
          .margin({ bottom: 20 })

        // 按钮
        Row({ space: 12 }) {
          Button('取消', { type: ButtonType.Normal })
            .layoutWeight(1)
            .height(44)
            .backgroundColor('#F5F5F5')
            .fontColor('#666666')
            .onClick(() => { this.showReviewDialog = false; })

          Button('提交', { type: ButtonType.Normal })
            .layoutWeight(1)
            .height(44)
            .backgroundColor('#007DFF')
            .fontColor('#FFFFFF')
            .onClick(() => { this.submitReview(); })
        }
        .width('100%')
      }
      .width('90%')
      .padding(20)
      .backgroundColor('#FFFFFF')
      .borderRadius(16)
    }
    .width('100%')
    .height('100%')
  }

  // 加载菜品详情
  async loadDishDetail(dishId: number) {
    try {
      this.isLoading = true;
      const response: ApiResponse = await ApiUtils.get(`/dishes/${dishId}`);
      if (response.statusCode === 200 && response.data) {
        const data = response.data as Record<string, Object>;
        this.dish.id = (data.id as number) || this.dish.id;
        this.dish.name = (data.name as string) || this.dish.name;
        this.dish.description = (data.description as string) || '';
        this.dish.cookingMethod = (data.cooking_method as string) || '';
        this.dish.price = Number(data.price) || 0;
        this.dish.category = (data.category as string) || '';
        this.dish.imageUrl = (data.image_url as string) || '';
        this.dish.isRecommended = Boolean(data.is_recommended);
        this.dish.sales = Number(data.sales) || 0;
        this.dish.rating = Number(data.rating) || 5.0;
        this.dish.reviewCount = Number(data.review_count) || 0;
      }
      // 加载评价列表
      await this.loadReviews(dishId);
    } catch (error) {
      console.error('加载菜品详情失败:' + JSON.stringify(error));
    } finally {
      this.isLoading = false;
    }
  }

  // 加载评价列表
  async loadReviews(dishId: number) {
    try {
      const response: ApiResponse = await ApiUtils.get(`/dishes/${dishId}/reviews`);
      if (response.statusCode === 200 && response.data) {
        const data = response.data as ReviewData[];
        this.reviews = data.map((item: ReviewData): DishReview => ({
          id: item.id,
          user: item.username,
          avatar: item.avatar,
          rating: item.rating,
          content: item.content,
          createdAt: item.created_at
        }));
      }
    } catch (error) {
      console.error('加载评价失败:' + JSON.stringify(error));
    }
  }

  // 提交评价
  async submitReview() {
    if (!this.myReviewContent.trim()) {
      ToastUtils.showToast('请输入评价内容');
      return;
    }
    try {
      this.isSubmitting = true;
      const reviewRequest: SubmitReviewRequest = {
        rating: this.myRating,
        content: this.myReviewContent.trim()
      };
      const response: ApiResponse = await ApiUtils.post(`/dishes/${this.dish.id}/reviews`, reviewRequest);
      if (response.statusCode === 200) {
        ToastUtils.showToast('评价成功');
        this.showReviewDialog = false;
        // 重新加载评价列表
        await this.loadReviews(this.dish.id);
        // 重新加载菜品详情以更新评分
        await this.loadDishDetail(this.dish.id);
      } else {
        ToastUtils.showToast(response.message || '评价失败');
      }
    } catch (error) {
      console.error('提交评价失败:' + JSON.stringify(error));
      ToastUtils.showToast('评价失败，请重试');
    } finally {
      this.isSubmitting = false;
    }
  }

  // 格式化时间
  formatTime(timestamp: number): string {
    const date = new Date(timestamp);
    const now = new Date();
    const diff = now.getTime() - date.getTime();
    const days = Math.floor(diff / (1000 * 60 * 60 * 24));
    if (days === 0) {
      const hours = Math.floor(diff / (1000 * 60 * 60));
      if (hours === 0) {
        const minutes = Math.floor(diff / (1000 * 60));
        return minutes <= 1 ? '刚刚' : `${minutes}分钟前`;
      }
      return `${hours}小时前`;
    } else if (days < 7) {
      return `${days}天前`;
    } else {
      const month = (date.getMonth() + 1).toString().padStart(2, '0');
      const day = date.getDate().toString().padStart(2, '0');
      return `${month}-${day}`;
    }
  }

  // 规范化图片路径
  normalizeImagePath(path: string): string {
    if (!path) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    if (path.startsWith('app.media.')) return path;
    if (path.startsWith('file://')) return path;
    if (path.startsWith('/')) return `file://${path}`;
    return path;
  }
}

