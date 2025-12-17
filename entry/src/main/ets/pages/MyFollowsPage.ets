// MyFollowsPage.ets
import { FollowUser, FollowListResponse, ApiResponse, FollowResponse, FollowRequest } from '../common/Types';
import { ApiUtils, ToastUtils } from '../common/Utils';
import router from '@ohos.router';

@Entry
@Component
struct MyFollowsPage {
  @State followList: FollowUser[] = [];
  @State loading: boolean = false;
  @State currentPage: number = 1;
  @State hasMore: boolean = true;
  @State total: number = 0;

  aboutToAppear() {
    this.loadFollowList(true);
  }

  onPageShow() {
    // 页面显示时刷新列表,确保与发现页数据同步
    this.loadFollowList(true);
  }

  async loadFollowList(refresh: boolean = false): Promise<void> {
    if (this.loading) return;

    if (refresh) {
      this.currentPage = 1;
      this.hasMore = true;
    }

    if (!this.hasMore && !refresh) return;

    this.loading = true;

    try {
      const response: ApiResponse = await ApiUtils.get(`/follow/list?page=${this.currentPage}&limit=20`);

      if (response.statusCode === 200 && response.data) {
        const data = response.data as FollowListResponse;
        if (refresh) {
          this.followList = data.users || [];
        } else {
          this.followList = this.followList.concat(data.users || []);
        }
        this.total = data.total || 0;
        this.hasMore = this.currentPage < data.pages;
        this.currentPage++;
      } else {
        ToastUtils.showToast(response.message || '加载失败');
      }
    } catch (error) {
      console.error('加载关注列表失败:' + JSON.stringify(error));
      ToastUtils.showToast('网络异常，请重试');
    } finally {
      this.loading = false;
    }
  }

  async unfollowUser(user: FollowUser): Promise<void> {
    try {
      const request: FollowRequest = { user_id: user.id };
      const response: ApiResponse = await ApiUtils.post('/unfollow', request);

      if (response.statusCode === 200 && response.data) {
        const data = response.data as FollowResponse;
        // 确认取消关注成功（is_following 应该为 false）
        if (!data.is_following) {
          // 从列表中移除
          this.followList = this.followList.filter((u: FollowUser) => u.id !== user.id);
          this.total = Math.max(0, this.total - 1);
          ToastUtils.showToast('已取消关注');
        } else {
          // 如果响应显示仍在关注，说明操作可能失败
          ToastUtils.showToast('操作失败，请重试');
        }
      } else {
        // 显示后端返回的错误消息
        const errorMsg = response.message || '操作失败';
        ToastUtils.showToast(errorMsg);
        console.error('取消关注失败:', errorMsg);
      }
    } catch (error) {
      console.error('取消关注失败:' + JSON.stringify(error));
      ToastUtils.showToast('网络异常，请重试');
    }
  }

  formatFollowTime(timestamp: number): string {
    if (!timestamp) return '';
    const date = new Date(timestamp * 1000);
    const now = new Date();
    const diff = now.getTime() - date.getTime();
    const days = Math.floor(diff / (1000 * 60 * 60 * 24));

    if (days === 0) return '今天关注';
    if (days === 1) return '昨天关注';
    if (days < 30) return `${days}天前关注`;
    return `${date.getMonth() + 1}月${date.getDate()}日关注`;
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Image($r('app.media.back_icon'))
          .width(24)
          .height(24)
          .onClick(() => {
            router.back();
          })

        Text('我的关注')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Text(`${this.total}人`)
          .fontSize(14)
          .fontColor('#999999')
          .width(60)
          .textAlign(TextAlign.End)
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#FFFFFF')

      // 列表内容
      if (this.loading && this.followList.length === 0) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
          Text('加载中...')
            .fontSize(14)
            .fontColor('#999999')
            .margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.followList.length === 0) {
        Column() {
          Text('暂无关注')
            .fontSize(16)
            .fontColor('#999999')
          Text('去发现页关注感兴趣的用户吧')
            .fontSize(14)
            .fontColor('#CCCCCC')
            .margin({ top: 8 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.followList, (user: FollowUser) => {
            ListItem() {
              this.FollowUserItem(user)
            }
          }, (user: FollowUser) => user.id.toString())

          if (this.hasMore) {
            ListItem() {
              Row() {
                LoadingProgress().width(20).height(20)
                Text('加载更多...').fontSize(14).fontColor('#999').margin({ left: 8 })
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .padding(16)
            }
          }
        }
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('#F5F5F5')
        .onReachEnd(() => {
          if (this.hasMore && !this.loading) {
            this.loadFollowList(false);
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  @Builder
  FollowUserItem(user: FollowUser) {
    Row() {
      Image(user.avatar || $r('app.media.ic_user_avatar'))
        .width(48)
        .height(48)
        .borderRadius(24)

      Column() {
        Text(user.username)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
        Text(this.formatFollowTime(user.follow_time))
          .fontSize(12)
          .fontColor('#999999')
          .margin({ top: 4 })
      }
      .margin({ left: 12 })
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Button('已关注', { type: ButtonType.Normal })
        .fontSize(13)
        .fontColor('#666666')
        .backgroundColor('#F0F0F0')
        .borderRadius(16)
        .height(32)
        .padding({ left: 14, right: 14 })
        .onClick(() => {
          this.unfollowUser(user);
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .margin({ bottom: 1 })
  }
}

