// DiscoverPage.ets
import {
  Post,
  NewPostForm,
  PostListResponse,
  LikeResponse,
  ApiResponse,
  CreatePostRequest,
  LikeRequest,
  Comment,
  CommentListResponse,
  CreateCommentRequest,
  CreateCommentResponse,
  FollowRequest,
  FollowResponse,
  Message,
  ConversationListResponseData,
  ConversationItemData,
  SendMessageRequest
} from '../common/Types';
import { ApiUtils, ToastUtils } from '../common/Utils';
import router from '@ohos.router';
import picker from '@ohos.file.picker';
import abilityAccessCtrl from '@ohos.abilityAccessCtrl';
import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';

// 分享好友项
interface ShareFriend {
  id: number;
  conversationId: number;
  username: string;
  avatar: string;
}

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

interface SelectedMediaPreview {
  path: string;
  type: 'image' | 'video';
  key: string;
  index: number;
}

interface SamplePostData {
  id: number;
  username: string;
  avatar: string;
  content: string;
  images: string[];
  videos: string[];
  likeCount: number;
  commentCount: number;
  createTimeOffsetMinutes: number;
}

interface SamplePreviewCard {
  id: string;
  avatar: Resource;
  nickname: string;
  tag: string;
  content: string;
}

function createEmptyPostForm(): NewPostForm {
  return {
    content: '',
    images: [],
    videos: []
  }as NewPostForm;
}

@Entry
@Component
export struct DiscoverPage {
  @State posts: Post[] = [];
  @State refreshing: boolean = false;
  @State loadingMore: boolean = false;
  @State currentPage: number = 1;
  @State hasMore: boolean = true;
  @State showPostDialog: boolean = false;
  @State newPost: NewPostForm = createEmptyPostForm();
  @State showCommentDialog: boolean = false;
  @State currentPost: Post | null = null;
  @State comments: Comment[] = [];
  @State commentContent: string = '';
  @State mediaProcessing: boolean = false;
  @State activeCategory: string = '推荐';
  @State posting: boolean = false;
  // 分享相关状态
  @State showShareDialog: boolean = false;
  @State sharePost: Post | null = null;
  @State shareFriends: ShareFriend[] = [];
  @State shareLoading: boolean = false;
  private readonly samplePreviewCards: SamplePreviewCard[] = [
    {
      id: 'sample_card_1',
      avatar: $r('app.media.avatar1'),
      nickname: '食光记·阿九',
      tag: '人气推荐',
      content: '宫保鸡丁花生脆、鸡肉嫩，撒上一点葱花瞬间升级下饭王者～'
    },
    {
      id: 'sample_card_2',
      avatar: $r('app.media.avatar2'),
      nickname: '今日小厨',
      tag: '今日探店',
      content: '酸菜鱼现切草鱼搭配自炒酸菜，汤底越喝越上瘾，配米饭绝了。'
    },
    {
      id: 'sample_card_3',
      avatar: $r('app.media.avatar3'),
      nickname: '甜咸党代表',
      tag: '轻松午餐',
      content: '新品胡萝卜炖牛腩，汤汁浓郁不卡嘴，再来一杯冰美式刚刚好。'
    }
  ];

  private readonly discoverCategories: string[] = ['推荐', '附近', '关注'];
  private readonly maxMediaCount: number = 6;
  private mediaPermissionsGranted: boolean = false;
  private context?: common.UIAbilityContext;
  private atManager?: abilityAccessCtrl.AtManager;
  private readonly mediaPermissions: MediaPermissionName[] = [
    'ohos.permission.READ_MEDIA',
    'ohos.permission.WRITE_MEDIA',
    'ohos.permission.READ_IMAGEVIDEO',
    'ohos.permission.WRITE_IMAGEVIDEO',
    'ohos.permission.CAMERA'
  ];

  aboutToAppear(): void {
    const token: string = AppStorage.get<string>('userToken') || '';
    try {
      this.context = getContext(this) as common.UIAbilityContext;
      this.atManager = abilityAccessCtrl.createAtManager();
    } catch (error) {
      console.error('初始化上下文失败:' + JSON.stringify(error));
    }
    if (!token) {
      ToastUtils.showToast('请先登录');
      router.replaceUrl({ url: 'pages/LoginPage' });
      return;
    }
    this.loadPosts(true);
    this.ensurePostFormInitialized();
  }

  @Builder
  DiscoverHeader() {
    Column() {
      // 顶部渐变背景区域
      Stack({ alignContent: Alignment.BottomStart }) {
        Column()
          .width('100%')
          .height(200)
          .linearGradient({
            angle: 135,
            colors: [
              ['#667eea', 0],
              ['#764ba2', 1]
            ]
          })

        Column() {
          // 标题和发布按钮
          Row() {
            Column({ space: 4 }) {
              Text('发现美食')
                .fontSize(26)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
              Text('分享你的味蕾故事')
                .fontSize(13)
                .fontColor('rgba(255,255,255,0.85)')
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Button({ type: ButtonType.Normal, stateEffect: true }) {
              Row({ space: 6 }) {
                Text('+')
                  .fontSize(18)
                  .fontColor('#FFFFFF')
                  .fontWeight(FontWeight.Bold)
                Text('发布')
                  .fontSize(15)
                  .fontColor('#FFFFFF')
                  .fontWeight(FontWeight.Medium)
              }
            }
            .height(40)
            .padding({ left: 16, right: 18 })
            .backgroundColor('#FF6B6B')
            .borderRadius(20)
            .shadow({
              radius: 12,
              color: 'rgba(255,107,107,0.4)',
              offsetX: 0,
              offsetY: 4
            })
            .onClick(() => {
              try {
              console.info('顶部发布按钮被点击');
              this.ensurePostFormInitialized();
              this.showPostDialog = true;
              } catch (error) {
                console.error('打开发布对话框失败: ' + JSON.stringify(error));
                ToastUtils.showToast('打开发布对话框失败，请重试');
              }
            })
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          // 统计信息卡片 - 使用深色卡片确保文字可见
          Row({ space: 10 }) {
            // 动态数
            Column({ space: 4 }) {
              Text(`${this.posts.length}`)
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
              Text('动态')
                .fontSize(11)
                .fontColor('rgba(255,255,255,0.8)')
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)
            .padding({ top: 12, bottom: 12 })
            .backgroundColor('rgba(255,255,255,0.2)')
            .borderRadius(12)

            // 当前频道
            Column({ space: 4 }) {
              Text(this.activeCategory)
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
              Text('频道')
                .fontSize(11)
                .fontColor('rgba(255,255,255,0.8)')
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)
            .padding({ top: 12, bottom: 12 })
            .backgroundColor('rgba(255,255,255,0.2)')
            .borderRadius(12)

            // 状态
            Column({ space: 4 }) {
              Row({ space: 4 }) {
                if (this.refreshing) {
                  LoadingProgress()
                    .width(12)
                    .height(12)
                    .color('#FFFFFF')
                } else {
                  Column()
                    .width(8)
                    .height(8)
                    .borderRadius(4)
                    .backgroundColor('#4ADE80')
                }
                Text(this.refreshing ? '刷新' : '在线')
                  .fontSize(13)
                  .fontColor('#FFFFFF')
              }
              Text('状态')
                .fontSize(11)
                .fontColor('rgba(255,255,255,0.8)')
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)
            .padding({ top: 12, bottom: 12 })
            .backgroundColor('rgba(255,255,255,0.2)')
            .borderRadius(12)
          }
          .margin({ top: 16 })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 20, bottom: 24 })
      }
    }
  }

  @Builder
  CategoryChips() {
    List({ space: 10 }) {
      ForEach(this.discoverCategories, (category: string) => {
        ListItem() {
          Column() {
            Text(category)
              .fontSize(14)
              .fontWeight(this.activeCategory === category ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(this.activeCategory === category ? '#FFFFFF' : '#666666')
          }
          .padding({ left: 18, right: 18, top: 10, bottom: 10 })
          .backgroundColor(this.activeCategory === category ? '#007DFF' : '#FFFFFF')
          .borderRadius(20)
          .shadow(this.activeCategory === category ? {
            radius: 8,
            color: '#30007DFF',
            offsetX: 0,
            offsetY: 4
          } : {
            radius: 4,
            color: '#10000000',
            offsetX: 0,
            offsetY: 2
          })
          .onClick(() => {
            if (this.activeCategory !== category) {
              this.activeCategory = category;
              this.loadPosts(true);
            }
          })
        }
      }, (category: string) => category)
    }
    .listDirection(Axis.Horizontal)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor('#F8F8F8')
  }

  @Builder
  SampleGuideCard() {
    Column() {
      this.SectionHeader('灵感指南', '从头像、昵称、内容排版入手打造统一视觉')

      Row() {
        Column() {
          Text('每条示例都包含头像、昵称与详细内容，便于快速参考。')
            .fontSize(13)
            .fontColor('#666')
            .margin({ top: 4 })
        }
        .layoutWeight(1)

        Button('刷新示例', { type: ButtonType.Normal })
          .fontColor('#007DFF')
          .backgroundColor(Color.Transparent)
          .borderColor(Color.Transparent)
          .onClick(() => {
            this.posts = this.createLocalSamplePosts();
            this.hasMore = false;
            this.currentPage = 1;
          })
      }

      Text('上滑浏览更多动态，或点击右上角“发布”上传新的图文/视频。')
        .fontSize(12)
        .fontColor('#999')
        .margin({ top: 8 })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 12, bottom: 12 })
  }

  @Builder
  SectionHeader(title: string, subtitle: string) {
    Column({ space: 4 }) {
      Text(title)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1F1F1F')
      Text(subtitle)
        .fontSize(13)
        .fontColor('#7A7A7A')
    }
    .width('100%')
  }

  @Builder
  SamplePreviewSection() {
    Column() {
      this.SectionHeader('示例帖子排版', '头像 + 昵称 + 文案的完整组合示例')

      Scroll() {
        Row() {
          ForEach(this.samplePreviewCards, (card: SamplePreviewCard) => {
            this.SamplePreviewCard(card)
          }, (card: SamplePreviewCard) => card.id)
        }
        .padding({ left: 20, right: 20 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .padding({ top: 12 })
    }
    .width('100%')
    .padding({ bottom: 8 })
  }

  @Builder
  SamplePostShowcase(samples: Post[]) {
    Column({ space: 12 }) {
      this.SectionHeader('示例帖子展示', '头像、昵称与内容按纵向卡片排布')
      Column({ space: 12 }) {
        ForEach(samples, (post: Post) => {
          this.SamplePostPreviewItem(post);
        }, (post: Post) => post.id.toString());
      }
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 12, bottom: 12 })
  }

  @Builder
  SamplePostPreviewItem(post: Post) {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Image(this.normalizePostImagePath(post.avatar) || $r('app.media.ic_user_avatar'))
          .width(44)
          .height(44)
          .borderRadius(22)
          .objectFit(ImageFit.Cover)
          .border({ width: 2, color: '#F0F0F0' })

        Text(post.username || '美食达人')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1F1F1F')
      }

      Text(post.content || '')
        .fontSize(14)
        .fontColor('#333')
        .lineHeight(20)

      if (post.images && post.images.length > 0) {
        Row({ space: 8 }) {
          ForEach(post.images.slice(0, 3), (image: string, index: number) => {
            if (image.startsWith('app.media.')) {
              Image($r(image))
                .width(90)
                .height(90)
                .borderRadius(10)
                .objectFit(ImageFit.Cover)
            } else {
              Image(this.normalizePostImagePath(image))
                .width(90)
                .height(90)
                .borderRadius(10)
                .objectFit(ImageFit.Cover)
            }
          }, (image: string, index: number) => `${image}-preview-${index}`)
        }
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(18)
    .shadow({
      radius: 12,
      color: '#14000000',
      offsetX: 0,
      offsetY: 4
    })
  }

  @Builder
  PullToRefreshIndicator() {
    if (this.refreshing) {
      Column({ space: 8 }) {
      LoadingProgress()
          .width(32)
          .height(32)
        .color('#007DFF')
        Text('正在刷新...')
          .fontSize(14)
        .fontColor('#666')
    }
      .padding(16)
      .width('100%')
      .alignItems(HorizontalAlign.Center)
    }
  }

  @Builder
  PostingOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      Row() {}
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')

      Column({ space: 12 }) {
        LoadingProgress()
          .width(36)
          .height(36)
          .color('#007DFF')
        Text('正在发布，请稍候...')
          .fontSize(14)
          .fontColor('#333')
      }
      .padding({ left: 32, right: 32, top: 24, bottom: 24 })
      .backgroundColor(Color.White)
      .borderRadius(20)
      .shadow({
        radius: 18,
        color: '#22000000',
        offsetX: 0,
        offsetY: 6
      })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  SamplePreviewCard(card: SamplePreviewCard) {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Image(card.avatar)
          .width(40)
          .height(40)
          .borderRadius(20)
          .objectFit(ImageFit.Cover)

        Column({ space: 4 }) {
          Text(card.nickname)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#222')
          Text(card.tag)
            .fontSize(12)
            .fontColor('#5C6BFF')
            .backgroundColor('#EEF0FF')
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .borderRadius(12)
        }
      }

      Text(card.content)
        .fontSize(14)
        .fontColor('#444')
        .lineHeight(20)

      Text('头像 + 昵称 + 文案 + 媒体，保持 16px 内边距与圆角。')
        .fontSize(12)
        .fontColor('#999')
    }
    .width(240)
    .padding(16)
    .margin({ right: 16 })
    .backgroundColor(Color.White)
    .borderRadius(16)
    .shadow({
      radius: 12,
      color: '#1A000000',
      offsetX: 0,
      offsetY: 2
    })
  }

  @Builder
  PostFeedSection() {
    Column({ space: 12 }) {
      if (this.posts.length === 0 && !this.refreshing) {
        this.EmptyPlaceholder()
      } else {
        Column({ space: 12 }) {
          ForEach(this.posts, (post: Post) => {
            this.PostItem(post)
          }, (post: Post) => post.id.toString())

          if (this.loadingMore) {
            Row({ space: 8 }) {
              LoadingProgress()
                .width(24)
                .height(24)
                .color('#007DFF')
              Text('加载中…')
                .fontSize(14)
                .fontColor('#666')
            }
            .justifyContent(FlexAlign.Center)
            .width('100%')
            .padding({ top: 16, bottom: 16 })
          } else if (this.hasMore && this.posts.length > 0) {
            Button('继续加载', { type: ButtonType.Normal, stateEffect: true })
              .fontSize(14)
              .fontColor('#007DFF')
              .backgroundColor(Color.Transparent)
              .margin({ top: 8 })
              .onClick(() => {
                this.onLoadMore();
              })
          } else if (!this.hasMore && this.posts.length > 0) {
            Text('没有更多动态了')
              .fontSize(14)
              .fontColor('#999')
              .textAlign(TextAlign.Center)
              .width('100%')
              .padding({ top: 16, bottom: 16 })
          }
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12 })
  }

  @Builder
  EmptyPlaceholder() {
    Column({ space: 12 }) {
      Image($r('app.media.empty'))
        .width(140)
        .height(140)
        .objectFit(ImageFit.Cover)

      Text('还没有帖子，发布一条吧～')
        .fontSize(14)
        .fontColor('#999')

      Button('立即发布', { type: ButtonType.Normal })
        .backgroundColor('#007DFF')
        .fontColor(Color.White)
        .borderRadius(20)
        .padding({ left: 20, right: 20 })
        .onClick(() => {
          this.showPostDialog = true;
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 40, bottom: 20 })
  }

  private ensurePostFormInitialized(): void {
    try {
      if (!this.newPost) {
        this.newPost = createEmptyPostForm();
        return;
      }
      // 确保content是字符串
      if (typeof this.newPost.content !== 'string') {
        this.newPost.content = '';
      }
      // 确保images是数组
      if (!Array.isArray(this.newPost.images)) {
        this.newPost.images = [];
      }
      // 确保videos是数组
      if (!Array.isArray(this.newPost.videos)) {
        this.newPost.videos = [];
      }
    } catch (error) {
      console.error('初始化发布表单失败: ' + JSON.stringify(error));
      try {
        this.newPost = createEmptyPostForm();
      } catch (e) {
        console.error('创建空表单失败: ' + JSON.stringify(e));
        // 如果创建失败，至少确保基本结构
        this.newPost = {
          content: '',
          images: [],
          videos: []
        } as NewPostForm;
      }
    }
  }

  private resetNewPostForm(): void {
    try {
      this.newPost = createEmptyPostForm();
      this.mediaProcessing = false;
    } catch (error) {
      console.error('重置表单失败: ' + JSON.stringify(error));
      // 如果创建失败，至少重置基本字段
      try {
        this.newPost = {
          content: '',
          images: [],
          videos: []
        } as NewPostForm;
        this.mediaProcessing = false;
      } catch (e) {
        console.error('重置表单字段失败: ' + JSON.stringify(e));
      }
    }
  }

  private normalizePosts(posts: Post[]): Post[] {
    if (!posts || posts.length === 0) {
      return [];
    }
    const normalized: Post[] = [];
    for (const post of posts) {
      normalized.push(this.normalizePostMedia(post));
    }
    return normalized;
  }

  private normalizePostMedia(post: Post): Post {
    if (!post.images) {
      post.images = [];
    }
    if (!post.videos) {
      post.videos = [];
    }
    if (post.imageUrls && post.imageUrls.length > 0 && post.images.length === 0 && post.videos.length === 0) {
      const cleaned = post.imageUrls.split(',')
        .map((item: string) => item.trim())
        .filter((item: string) => !!item);
      for (const mediaPath of cleaned) {
        if (this.isVideoPath(mediaPath)) {
          post.videos.push(mediaPath);
        } else {
          post.images.push(mediaPath);
        }
      }
    }
    post.images = post.images.map((path: string) => this.toAbsoluteMediaPath(path));
    post.videos = post.videos.map((path: string) => this.toAbsoluteMediaPath(path));
    return post;
  }

  private isVideoPath(path: string): boolean {
    if (!path) {
      return false;
    }
    const lower = path.toLowerCase();
    return lower.endsWith('.mp4') || lower.endsWith('.mov') || lower.endsWith('.avi') || lower.endsWith('.mkv');
  }

  private getCurrentMediaTotal(): number {
    try {
      if (!this.newPost) {
        return 0;
      }
      const imageList: string[] = (Array.isArray(this.newPost.images)) ? this.newPost.images : [];
      const videoList: string[] = (Array.isArray(this.newPost.videos)) ? this.newPost.videos : [];
      return imageList.length + videoList.length;
    } catch (error) {
      console.error('getCurrentMediaTotal异常: ' + JSON.stringify(error));
      return 0;
    }
  }

  private buildSelectedMediaPreview(): SelectedMediaPreview[] {
    const preview: SelectedMediaPreview[] = [];
    const images: string[] = this.newPost?.images ?? [];
    const videos: string[] = this.newPost?.videos ?? [];
    images.forEach((path: string, index: number) => {
      preview.push({ path, type: 'image', key: `image-${index}`, index });
    });
    videos.forEach((path: string, index: number) => {
      preview.push({ path, type: 'video', key: `video-${index}`, index });
    });
    return preview;
  }

  private get mediaPreviewList(): SelectedMediaPreview[] {
    return this.buildSelectedMediaPreview();
  }

  private removeMedia(type: 'image' | 'video', index: number): void {
    this.ensurePostFormInitialized();
    if (type === 'image') {
      const sourceImages: string[] = this.newPost.images ?? [];
      const newImages: string[] = sourceImages.slice();
      newImages.splice(index, 1);
      this.newPost.images = newImages;
    } else {
      const sourceVideos: string[] = this.newPost.videos ?? [];
      const newVideos: string[] = sourceVideos.slice();
      newVideos.splice(index, 1);
      this.newPost.videos = newVideos;
    }
  }

  private toRelativeMediaPath(path: string): string {
    try {
      if (!path || typeof path !== 'string') {
        return '';
      }
      if (!this.context) {
        // 尝试获取context
        try {
          this.context = getContext(this) as common.UIAbilityContext;
        } catch (e) {
          console.error('获取context失败: ' + JSON.stringify(e));
          return path;
        }
      }
      if (!this.context) {
        return path;
      }
      const filesDir = this.context.filesDir;
      if (!filesDir) {
        return path;
      }
      if (path.startsWith(filesDir)) {
        const trimmed = path.substring(filesDir.length);
        return trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
      }
      return path;
    } catch (error) {
      console.error('toRelativeMediaPath异常: ' + JSON.stringify(error));
      return path || '';
    }
  }

  private toAbsoluteMediaPath(path: string): string {
    if (!path) {
      return '';
    }
    if (path.startsWith('file://')) {
      return path.replace('file://', '');
    }
    const lower = path.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return path;
    }
    if (path.startsWith('app.media.')) {
      return path;
    }
    if (path.startsWith('/')) {
      return path;
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
    // 如果是相对路径(如posts/xxx或dishes/xxx),拼接filesDir
    return `${this.context.filesDir}/${path}`;
  }

  // 标准化帖子图片路径(用于显示)
  private normalizePostImagePath(path: string): string {
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
    // 相对路径(posts/xxx或dishes/xxx),需要转换为绝对路径
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
    // 如果是相对路径,拼接filesDir
    return `${this.context.filesDir}/${path}`;
  }

  private buildPayloadPaths(paths: string[] = []): string[] {
    try {
      if (!paths || !Array.isArray(paths)) {
        return [];
      }
      const dedup: string[] = [];
      paths.forEach((path: string) => {
        try {
          if (path) {
            const relative = this.toRelativeMediaPath(path);
            if (relative && relative.length > 0 && dedup.indexOf(relative) === -1) {
              dedup.push(relative);
            }
          }
        } catch (e) {
          console.error('处理路径失败: ' + JSON.stringify(e));
          // 跳过无效路径
        }
      });
      return dedup;
    } catch (error) {
      console.error('buildPayloadPaths异常: ' + JSON.stringify(error));
      return [];
    }
  }

  private async ensureMediaPermissions(): Promise<boolean> {
    if (this.mediaPermissionsGranted) {
      return true;
    }
    if (!this.atManager || !this.context) {
      return false;
    }
    try {
      const permissionResult = await this.atManager.requestPermissionsFromUser(
        this.context,
        this.mediaPermissions
      ) as PermissionRequestResult;
      const granted = permissionResult.authResults.every((status: number) => status === 0);
      this.mediaPermissionsGranted = granted;
      if (!granted) {
        ToastUtils.showToast('请授予相册与相机权限后再试');
      }
      return granted;
    } catch (error) {
      console.error('申请媒体权限失败:' + JSON.stringify(error));
      ToastUtils.showToast('权限申请失败');
      return false;
    }
  }

  private async openGallery(type: 'image' | 'video'): Promise<void> {
    this.ensurePostFormInitialized();
    const granted = await this.ensureMediaPermissions();
    if (!granted) {
      return;
    }
    const remain = this.maxMediaCount - this.getCurrentMediaTotal();
    if (remain <= 0) {
      ToastUtils.showToast(`最多只能选择${this.maxMediaCount}个文件`);
      return;
    }
    try {
      const viewPicker = new picker.PhotoViewPicker();
      const options = new picker.PhotoSelectOptions();
      options.MIMEType = type === 'video' ? picker.PhotoViewMIMETypes.VIDEO_TYPE : picker.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = remain;
      const result = await viewPicker.select(options);
      if (result && result.photoUris && result.photoUris.length > 0) {
        await this.handleMediaResult(result.photoUris, type);
      }
    } catch (error) {
      console.error('选择媒体失败:' + JSON.stringify(error));
      ToastUtils.showToast('选择媒体失败，请重试');
    }
  }

  private async captureFromCamera(): Promise<void> {
    this.ensurePostFormInitialized();
    const granted = await this.ensureMediaPermissions();
    if (!granted) {
      return;
    }
    try {
      const viewPicker = new picker.PhotoViewPicker();
      const options = new picker.PhotoSelectOptions();
      options.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const result = await viewPicker.select(options);
      if (result && result.photoUris && result.photoUris.length > 0) {
        await this.handleMediaResult([result.photoUris[0]], 'image');
      }
    } catch (error) {
      console.error('拍摄媒体失败:' + JSON.stringify(error));
      ToastUtils.showToast('拍摄失败，请重试');
    }
  }

  // 安全包装器 - 防止异步调用导致崩溃
  private safeOpenGallery(type: 'image' | 'video'): void {
    this.openGallery(type).catch((error: Error) => {
      console.error('safeOpenGallery异常:' + JSON.stringify(error));
    });
  }

  private safeCaptureFromCamera(): void {
    this.captureFromCamera().catch((error: Error) => {
      console.error('safeCaptureFromCamera异常:' + JSON.stringify(error));
    });
  }

  private async handleMediaResult(uris: string[], type: 'image' | 'video'): Promise<void> {
    try {
      this.ensurePostFormInitialized();
      if (!uris || !Array.isArray(uris) || uris.length === 0) {
        return;
      }
      this.mediaProcessing = true;
      try {
        for (const uri of uris) {
          if (!uri || typeof uri !== 'string') {
            continue;
          }
          if (this.getCurrentMediaTotal() >= this.maxMediaCount) {
            ToastUtils.showToast(`最多只能选择${this.maxMediaCount}个文件`);
            break;
          }
          try {
            const storedPath = await this.persistMedia(uri, type);
            if (storedPath && typeof storedPath === 'string') {
              this.ensurePostFormInitialized();
              if (type === 'image') {
                if (Array.isArray(this.newPost.images)) {
                  this.newPost.images = [...this.newPost.images, storedPath];
                } else {
                  this.newPost.images = [storedPath];
                }
              } else {
                if (Array.isArray(this.newPost.videos)) {
                  this.newPost.videos = [...this.newPost.videos, storedPath];
                } else {
                  this.newPost.videos = [storedPath];
                }
              }
            }
          } catch (e) {
            console.error('处理单个媒体文件失败: ' + JSON.stringify(e));
            // 继续处理下一个文件
          }
        }
      } finally {
        this.mediaProcessing = false;
      }
    } catch (error) {
      console.error('handleMediaResult异常: ' + JSON.stringify(error));
      this.mediaProcessing = false;
      ToastUtils.showToast('处理媒体文件失败，请重试');
    }
  }

  private async persistMedia(uri: string, type: 'image' | 'video'): Promise<string> {
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
        console.error('无法解析媒体路径:' + uri);
        return uri;
      }
      
      // 检查源文件是否存在
      try {
        fs.accessSync(sourcePath);
      } catch (error) {
        console.error('源媒体文件不存在:' + sourcePath);
        return uri;
      }
      
      // 确保应用私有目录存在
      const filesDir: string = this.context.filesDir;
      try {
        fs.accessSync(filesDir);
      } catch (error) {
        // 目录不存在,创建它
        try {
          fs.mkdirSync(filesDir, true);
        } catch (mkdirError) {
          console.error('创建filesDir失败:' + JSON.stringify(mkdirError));
        }
      }
      
      // 创建posts子目录用于存储帖子媒体
      const postsDir: string = `${filesDir}/posts`;
      try {
        fs.accessSync(postsDir);
      } catch (error) {
        // 目录不存在,创建它
        try {
          fs.mkdirSync(postsDir, true);
        } catch (mkdirError) {
          console.error('创建postsDir失败:' + JSON.stringify(mkdirError));
        }
      }
      
      // 生成唯一文件名
      const extension: string = this.extractExtension(sourcePath, type === 'video' ? '.mp4' : '.jpg');
      const fileName: string = `post_${type}_${Date.now()}_${Math.floor(Math.random() * 10000)}${extension}`;
      const targetPath: string = `${postsDir}/${fileName}`;
      
      // 复制文件到应用私有目录
      fs.copyFileSync(sourcePath, targetPath);
      
      // 返回相对路径(相对于filesDir),这样数据库只存储相对路径
      const relativePath: string = `posts/${fileName}`;
      console.log('媒体已保存到:' + targetPath + ', 相对路径:' + relativePath);
      return relativePath;
    } catch (error) {
      console.error('保存媒体文件失败:' + JSON.stringify(error));
      ToastUtils.showToast('媒体保存失败，将使用原始路径');
      return uri;
    }
  }

  private extractExtension(path: string, fallback: string = ''): string {
    if (!path) {
      return fallback;
    }
    const dotIndex = path.lastIndexOf('.');
    if (dotIndex === -1) {
      return fallback;
    }
    return path.substring(dotIndex);
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

  // 加载帖子数据
  async loadPosts(isRefresh: boolean = false): Promise<void> {
    try {
      if (isRefresh) {
        this.refreshing = true;
        this.currentPage = 1;
        this.hasMore = true;
      } else {
        if (!this.hasMore || this.loadingMore) {
          return;
        }
        this.loadingMore = true;
      }

      // 根据当前分类构建API请求
      const categoryParam = this.activeCategory === '关注' ? '&category=关注' : 
                          this.activeCategory === '附近' ? '&category=附近' : 
                          '&category=推荐';
      const response: ApiResponse = await ApiUtils.get(`/posts/list?page=${this.currentPage}&limit=10${categoryParam}`);

      if (response.statusCode === 200 && response.data) {
        const data = response.data as PostListResponse;
        const newPosts: Post[] = data.posts || [];
        const normalizedPosts: Post[] = this.normalizePosts(newPosts);

        if (isRefresh) {
          // 对于"关注"标签,如果没有数据就不显示示例帖子
          if (this.activeCategory === '关注') {
            this.posts = normalizedPosts;
          } else {
          this.posts = normalizedPosts.length > 0 ? normalizedPosts : this.createLocalSamplePosts();
          }
        } else {
          this.posts = this.posts.concat(normalizedPosts);
          // 对于"关注"标签,如果没有数据就不显示示例帖子
          if (normalizedPosts.length === 0 && this.posts.length === 0 && this.activeCategory !== '关注') {
            this.posts = this.createLocalSamplePosts();
          }
        }

        if (normalizedPosts.length === 0) {
          this.hasMore = false;
        } else {
        this.hasMore = this.currentPage < data.pagination.pages;
        this.currentPage++;
        }
      } else {
        ToastUtils.showToast(response.message || '加载失败');
        if (this.posts.length === 0 && this.activeCategory !== '关注') {
          this.posts = this.createLocalSamplePosts();
          this.hasMore = false;
        }
      }
    } catch (error) {
      console.error('加载帖子失败:' + JSON.stringify(error));
      ToastUtils.showToast('网络异常，请重试');
      if (this.posts.length === 0 && this.activeCategory !== '关注') {
        this.posts = this.createLocalSamplePosts();
        this.hasMore = false;
      }
    } finally {
      this.refreshing = false;
      this.loadingMore = false;
    }
  }

  // 处理发布动态 - 使用非async方式避免崩溃
  private handlePublishPost(): void {
    try {
      console.info('handlePublishPost 开始执行');
      
      // 防止重复调用
      if (this.posting) {
        console.info('正在发布中，忽略重复点击');
        return;
      }

      // 确保表单已初始化
      this.ensurePostFormInitialized();
      
      // 验证内容
      if (!this.newPost) {
        console.error('发布表单未初始化');
        this.newPost = createEmptyPostForm();
      }
      
      const content: string = (this.newPost.content || '').trim();
      if (!content) {
        ToastUtils.showToast('请输入动态内容');
        return;
      }

      // 设置发布状态
      this.posting = true;
      console.info('开始发布动态，内容: ' + content.substring(0, 20));

      // 使用Promise链式调用代替async/await
      this.doPublishPost(content)
        .then(() => {
          console.info('发布成功');
          // posting状态在doPublishPost中已经处理，这里确保重置
          this.posting = false;
        })
        .catch((error: Error) => {
          console.error('发布失败: ' + JSON.stringify(error));
          this.posting = false;
          ToastUtils.showToast('发布失败，请重试');
        })
        .finally(() => {
          // 确保posting状态被重置
          this.posting = false;
        });
    } catch (error) {
      console.error('handlePublishPost 异常: ' + JSON.stringify(error));
      this.posting = false;
      ToastUtils.showToast('发布异常，请重试');
    }
  }

  // 实际发布逻辑
  private async doPublishPost(content: string): Promise<void> {
    try {
      // 再次确保表单已初始化
      this.ensurePostFormInitialized();
      
      // 验证内容
      if (!content || content.trim().length === 0) {
        ToastUtils.showToast('请输入动态内容');
        return;
      }
      
      // 安全获取图片和视频数组，防止undefined导致崩溃
      const images: string[] = (this.newPost?.images && Array.isArray(this.newPost.images)) ? this.newPost.images : [];
      const videos: string[] = (this.newPost?.videos && Array.isArray(this.newPost.videos)) ? this.newPost.videos : [];
      
      // 将媒体路径转换为相对路径(用于数据库存储) - 增加空数组保护
      let payloadImages: string[] = [];
      let payloadVideos: string[] = [];
      try {
        if (images.length > 0) {
          const result = this.buildPayloadPaths(images);
          payloadImages = Array.isArray(result) ? result : [];
        }
        if (videos.length > 0) {
          const result = this.buildPayloadPaths(videos);
          payloadVideos = Array.isArray(result) ? result : [];
        }
      } catch (e) {
        console.error('构建路径失败: ' + JSON.stringify(e));
        // 路径构建失败不影响发布，继续使用空数组
        payloadImages = [];
        payloadVideos = [];
      }
      
      // 安全拼接路径
      const combinedPayload: string[] = (payloadImages || []).concat(payloadVideos || []);
      const imageUrlsStr: string = combinedPayload.length > 0 ? combinedPayload.join(',') : '';
      
      // 安全截取标题
      let title: string = '';
      try {
        title = content.length > 20 ? (content.substring(0, 20) + '...') : content;
      } catch (e) {
        console.error('截取标题失败: ' + JSON.stringify(e));
        title = content;
      }
      
      const postData: CreatePostRequest = {
        title: title,
        content: content,
        image_urls: imageUrlsStr,
        images: payloadImages || [],
        videos: payloadVideos || []
      };

      console.info('发送发布请求...');
      const response: ApiResponse = await ApiUtils.post('/posts/create', postData);
      console.info('发布响应: ' + JSON.stringify(response));

      // 检查响应是否有效
      if (!response) {
        ToastUtils.showToast('网络请求失败，请检查网络连接');
        this.posting = false;
        return;
      }

      if (response.statusCode === 200) {
        ToastUtils.showToast('发布成功');
        // 重置状态
        this.posting = false;
        this.resetNewPostForm();
        this.showPostDialog = false;
        // 刷新列表 - 使用安全的方式
        try {
          this.loadPosts(true);
        } catch (e) {
          console.error('刷新列表失败: ' + JSON.stringify(e));
          // 刷新失败不影响发布成功
        }
      } else {
        // 发布失败，重置状态
        this.posting = false;
        const errorMsg = response.message || '发布失败';
        ToastUtils.showToast(errorMsg);
        console.error('发布失败:', errorMsg);
      }
    } catch (error) {
      console.error('发布动态失败:' + JSON.stringify(error));
      // 确保重置发布状态
      this.posting = false;
      ToastUtils.showToast('发布失败，请重试');
      // 不重新抛出错误，让上层Promise的catch处理
      // 这样可以避免在ArkTS中抛出非Error类型的问题
    }
  }

  // 发布动态 (保留原方法以兼容)
  async publishPost(): Promise<void> {
    this.handlePublishPost();
  }

  // 点赞/取消点赞
  async toggleLike(post: Post): Promise<void> {
    // 本地示例帖（id < 0）只做前端本地切换，不调用后端
    if (post.id < 0) {
      const index: number = this.posts.findIndex((p: Post) => p.id === post.id);
      if (index !== -1) {
        const isLikedNow: boolean = !this.posts[index].isLiked;
        const newLikeCount: number = Math.max(0, this.posts[index].likeCount + (isLikedNow ? 1 : -1));
        // 创建新数组触发UI更新
        const updatedPosts: Post[] = [...this.posts];
        updatedPosts[index].isLiked = isLikedNow;
        updatedPosts[index].likeCount = newLikeCount;
        this.posts = updatedPosts;
      }
      return;
    }
    try {
      const likeData: LikeRequest = {
        post_id: post.id
      };

      const response: ApiResponse = await ApiUtils.post('/posts/like', likeData);

      if (response.statusCode === 200 && response.data) {
        const data = response.data as LikeResponse;
        const index: number = this.posts.findIndex((p: Post) => p.id === post.id);
        if (index !== -1) {
          // 创建新数组触发UI更新
          const updatedPosts: Post[] = [...this.posts];
          updatedPosts[index].isLiked = data.is_liked;
          updatedPosts[index].likeCount = data.likes;
          this.posts = updatedPosts;
        }
      }
    } catch (error) {
      console.error('点赞操作失败:' + JSON.stringify(error));
      ToastUtils.showToast('操作失败，请重试');
    }
  }

  // 关注/取消关注
  async toggleFollow(post: Post): Promise<void> {
    // 本地示例帖（id < 0 或 user_id <= 0）只做前端本地切换
    if (post.id < 0 || post.user_id <= 0) {
      const index: number = this.posts.findIndex((p: Post) => p.id === post.id);
      if (index !== -1) {
        const newFollowStatus: boolean = !this.posts[index].isFollowed;
        // 创建新数组触发UI更新
        const updatedPosts: Post[] = [...this.posts];
        updatedPosts[index].isFollowed = newFollowStatus;
        this.posts = updatedPosts;
        ToastUtils.showToast(newFollowStatus ? '已关注' : '已取消关注');
      }
      return;
    }

    try {
      // 验证用户ID有效性
      if (!post.user_id || post.user_id <= 0) {
        ToastUtils.showToast('无效的用户信息');
        return;
      }

      const isCurrentlyFollowed = post.isFollowed;
      const endpoint = isCurrentlyFollowed ? '/unfollow' : '/follow';
      const followData: FollowRequest = {
        user_id: post.user_id
      };

      const response: ApiResponse = await ApiUtils.post(endpoint, followData);

      if (response.statusCode === 200 && response.data) {
        const data = response.data as FollowResponse;
        // 创建新数组触发UI更新
        const updatedPosts: Post[] = [...this.posts];
        // 同步更新同一用户的所有帖子关注状态
        updatedPosts.forEach((p: Post) => {
          if (p.user_id === post.user_id) {
            p.isFollowed = data.is_following;
          }
        });
        this.posts = updatedPosts;
        ToastUtils.showToast(data.is_following ? '关注成功' : '已取消关注');
        
        // 如果当前在"关注"标签页且取消关注,刷新列表
        if (this.activeCategory === '关注' && !data.is_following) {
          this.loadPosts(true);
        }
      } else {
        // 显示后端返回的错误消息
        const errorMsg = response.message || '操作失败';
        ToastUtils.showToast(errorMsg);
        console.error('关注操作失败:', errorMsg);
      }
    } catch (error) {
      console.error('关注操作失败:' + JSON.stringify(error));
      ToastUtils.showToast('网络异常，请重试');
    }
  }

  // 处理下拉刷新
  onRefresh(): void {
    this.loadPosts(true);
  }

  // 处理上拉加载更多
  onLoadMore(): void {
    this.loadPosts(false);
  }

  build() {
    Stack() {
      Refresh({ refreshing: this.refreshing, offset: 80, friction: 80 }) {
        Scroll() {
          Column({ space: 0 }) {
            // 下拉刷新指示器 - 更美观的设计
            if (this.refreshing) {
              Column({ space: 12 }) {
                LoadingProgress()
                  .width(36)
                  .height(36)
                  .color('#007DFF')
                Text('正在刷新内容...')
                  .fontSize(14)
                  .fontColor('#666')
                  .fontWeight(FontWeight.Medium)
              }
              .width('100%')
              .padding({ top: 24, bottom: 16 })
              .justifyContent(FlexAlign.Center)
              .backgroundColor('#F8F8F8')
            }

            this.DiscoverHeader()
            this.CategoryChips()
            this.PostFeedSection()

            // 底部加载更多指示器
            if (this.loadingMore) {
              Row({ space: 8 }) {
                LoadingProgress()
                  .width(20)
                  .height(20)
                  .color('#007DFF')
                Text('加载更多...')
                  .fontSize(13)
                  .fontColor('#999')
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .padding({ top: 16, bottom: 24 })
            } else if (!this.hasMore && this.posts.length > 0) {
              Text('— 已经到底啦 —')
                .fontSize(13)
                .fontColor('#CCCCCC')
                .width('100%')
                .textAlign(TextAlign.Center)
                .padding({ top: 16, bottom: 24 })
            }
          }
          .width('100%')
          .padding({ bottom: 32 })
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .onScrollFrameBegin((offset: number, state: ScrollState) => {
          if (offset > 0 && !this.loadingMore && this.hasMore) {
            const estimatedVisibleHeight: number = 800;
            const estimatedContentHeight: number = 600 + this.posts.length * 300;
            if (offset + estimatedVisibleHeight >= estimatedContentHeight - 120) {
              this.onLoadMore();
            }
          }
          return { offsetRemain: offset };
        })
      }
      .width('100%')
      .height('100%')
      .onRefreshing(() => {
        console.info('触发下拉刷新');
        if (!this.refreshing) {
          this.onRefresh();
        }
      })

      if (this.showPostDialog) {
        Column() {
          // 遮罩层 - 点击关闭
          Column()
            .width('100%')
            .height('10%')
            .backgroundColor('#66000000')
            .onClick(() => {
              try {
                if (!this.posting) {
                  this.showPostDialog = false;
                  this.resetNewPostForm();
                } else {
                  ToastUtils.showToast('正在发布中，请稍候...');
                }
              } catch (error) {
                console.error('关闭对话框异常: ' + JSON.stringify(error));
                this.showPostDialog = false;
              }
            })

          // 对话框内容区域
          Column() {
            this.PostDialog(this.canPublishPost())
          }
          .width('100%')
          .height('90%')
          .backgroundColor('#FFFFFF')
          .borderRadius({ topLeft: 24, topRight: 24 })
        }
        .width('100%')
        .height('100%')
      }

      if (this.showCommentDialog) {
        Stack({ alignContent: Alignment.Bottom }) {
          // 遮罩层
          Row()
            .width('100%')
            .height('100%')
            .backgroundColor('#66000000')
            .onClick(() => {
              this.showCommentDialog = false;
              this.currentPost = null;
              this.comments = [];
              this.commentContent = '';
            })

          // 对话框内容
        this.CommentDialog()
        }
        .width('100%')
        .height('100%')
      }

      // 分享对话框
      if (this.showShareDialog) {
        Stack({ alignContent: Alignment.Bottom }) {
          // 遮罩层
          Row()
            .width('100%')
            .height('100%')
            .backgroundColor('#66000000')
            .onClick(() => {
              this.showShareDialog = false;
              this.sharePost = null;
            })

          // 分享对话框内容
          this.ShareDialog()
        }
        .width('100%')
        .height('100%')
      }

      if (this.posting) {
        this.PostingOverlay()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  // 帖子项组件 - 优化布局设计
  @Builder
  PostItem(post: Post) {
    Column({ space: 12 }) {
      // 用户信息行 - 头像、昵称、时间
      Row({ space: 12 }) {
        // 头像 - 添加渐变边框效果
        Stack() {
          Column()
            .width(52)
            .height(52)
            .borderRadius(26)
            .linearGradient({
              angle: 45,
              colors: [['#667eea', 0], ['#764ba2', 0.5], ['#f093fb', 1]]
            })
          Image(this.normalizePostImagePath(post.avatar) || $r('app.media.ic_user_avatar'))
            .width(48)
            .height(48)
            .borderRadius(24)
            .objectFit(ImageFit.Cover)
            .backgroundColor('#FFFFFF')
        }

        // 昵称
        Row({ space: 8 }) {
          Text(post.username || '美食达人')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1F1F1F')
          // 用户标签
          Text('美食家')
            .fontSize(10)
            .fontColor('#FFFFFF')
            .backgroundColor('#FF6B00')
            .borderRadius(8)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
        }
        .alignItems(VerticalAlign.Center)
        .layoutWeight(1)

        // 关注按钮
        Button(post.isFollowed ? '已关注' : '关注', { type: ButtonType.Normal, stateEffect: true })
          .fontSize(12)
          .fontColor(post.isFollowed ? '#999999' : '#007DFF')
          .backgroundColor(post.isFollowed ? '#F5F5F5' : '#E8F4FF')
          .borderRadius(14)
          .height(28)
          .padding({ left: 12, right: 12 })
          .onClick(() => {
            this.toggleFollow(post);
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // 帖子内容
      if (post.content) {
        Text(post.content)
          .fontSize(15)
          .fontColor('#333333')
          .textAlign(TextAlign.Start)
          .width('100%')
          .lineHeight(24)
          .maxLines(5)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }

      // 图片与视频展示
      if (post.images && post.images.length > 0) {
        this.PostImages(post.images)
      }

      if (post.videos && post.videos.length > 0) {
        this.PostVideos(post.videos)
      }

      // 互动按钮行 - 优化样式
      Row() {
        // 点赞按钮
        Row({ space: 4 }) {
          Image(post.isLiked ? $r('app.media.like_filled') : $r('app.media.like'))
            .width(20)
            .height(20)
            .fillColor(post.isLiked ? '#FF3B30' : '#999')
          Text(post.likeCount > 0 ? post.likeCount.toString() : '点赞')
            .fontSize(13)
            .fontColor(post.isLiked ? '#FF3B30' : '#999')
        }
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .backgroundColor(post.isLiked ? '#FFF0F0' : '#F8F8F8')
        .borderRadius(16)
        .onClick(() => {
          this.toggleLike(post);
        })

        // 评论按钮
        Row({ space: 4 }) {
          Image($r('app.media.comment'))
            .width(20)
            .height(20)
            .fillColor('#999')
          Text(post.commentCount > 0 ? post.commentCount.toString() : '评论')
            .fontSize(13)
            .fontColor('#999')
        }
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .backgroundColor('#F8F8F8')
        .borderRadius(16)
        .margin({ left: 12 })
        .onClick(() => {
          this.showComments(post);
        })

        Blank()

        // 分享按钮
        Row({ space: 4 }) {
          Image($r('app.media.share'))
            .width(18)
            .height(18)
            .fillColor('#999')
          Text('分享')
            .fontSize(13)
            .fontColor('#999')
        }
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .onClick(() => {
          this.showSharePostDialog(post);
        })
      }
      .width('100%')
      .margin({ top: 4 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(20)
    .margin({ left: 12, right: 12, bottom: 12 })
    .shadow({
      radius: 12,
      color: '#08000000',
      offsetX: 0,
      offsetY: 4
    })
  }

  @Builder
  PostImages(images: string[]) {
    if (!images || images.length === 0) {
      Column() {};
    } else if (images.length === 1) {
      Image(this.normalizePostImagePath(images[0]))
        .width('100%')
        .height(240)
        .objectFit(ImageFit.Cover)
        .borderRadius(12)
    } else if (images.length === 2) {
      Row({ space: 8 }) {
        Image(this.normalizePostImagePath(images[0]))
          .width('50%')
          .height(180)
          .objectFit(ImageFit.Cover)
          .borderRadius(12)
        Image(this.normalizePostImagePath(images[1]))
          .width('50%')
          .height(180)
          .objectFit(ImageFit.Cover)
          .borderRadius(12)
      }
      .width('100%')
    } else if (images.length === 3) {
      Column({ space: 8 }) {
        Image(this.normalizePostImagePath(images[0]))
          .width('100%')
          .height(180)
          .objectFit(ImageFit.Cover)
          .borderRadius(12)
        Row({ space: 8 }) {
          Image(this.normalizePostImagePath(images[1]))
            .width('50%')
            .height(120)
            .objectFit(ImageFit.Cover)
            .borderRadius(12)
          Image(this.normalizePostImagePath(images[2]))
            .width('50%')
            .height(120)
            .objectFit(ImageFit.Cover)
            .borderRadius(12)
        }
      }
      .width('100%')
    } else {
      Grid() {
        ForEach(images.slice(0, 9), (image: string, index: number) => {
          GridItem() {
            Stack({ alignContent: Alignment.Center }) {
              Image(this.normalizePostImagePath(image))
                .width('100%')
                .height('100%')
                .objectFit(ImageFit.Cover)
                .borderRadius(8)
              if (images.length > 9 && index === 8) {
                Text(`+${images.length - 9}`)
                  .fontSize(16)
                  .fontColor(Color.White)
                  .fontWeight(FontWeight.Bold)
                  .backgroundColor('#66000000')
                  .width('100%')
                  .height('100%')
                  .textAlign(TextAlign.Center)
                  .borderRadius(8)
              }
            }
          }
        }, (image: string, index: number) => `${image}-${index}`)
      }
      .columnsTemplate('1fr 1fr 1fr')
      .rowsTemplate('auto')
      .columnsGap(6)
      .rowsGap(6)
      .width('100%')
    }
  }

  @Builder
  PostVideos(videos: string[]) {
    if (!videos || videos.length === 0) {
      Column() {};
    } else {
      Column({ space: 8 }) {
        ForEach(videos, (video: string, index: number) => {
          Stack({ alignContent: Alignment.Center }) {
            Video({ src: this.normalizePostImagePath(video), previewUri: '' })
              .width('100%')
              .height(240)
              .controls(true)
              .autoPlay(false)
              .loop(false)
              .borderRadius(12)
              .objectFit(ImageFit.Cover)

            Text('视频')
              .fontSize(12)
              .fontColor(Color.White)
              .padding({ left: 10, right: 10, top: 4, bottom: 4 })
              .backgroundColor('#66000000')
              .borderRadius(12)
              .position({ x: 16, y: 16 })
          }
        }, (video: string, index: number) => `${video}-video-${index}`)
      }
      .width('100%')
    }
  }

  // 发布对话框组件 - 修复发布按钮问题
  @Builder
  PostDialog(canPublish: boolean) {
    Column() {
      // 标题栏
      Row() {
        Button('取消', { type: ButtonType.Normal, stateEffect: true })
          .fontSize(16)
          .fontColor('#666')
          .backgroundColor(Color.Transparent)
          .height(40)
          .onClick(() => {
            try {
              console.info('取消按钮被点击');
              if (!this.posting) {
                this.showPostDialog = false;
                this.resetNewPostForm();
              } else {
                ToastUtils.showToast('正在发布中，请稍候...');
              }
            } catch (error) {
              console.error('取消按钮异常: ' + JSON.stringify(error));
              this.showPostDialog = false;
            }
          })

        Text('发布动态')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Button('发布', { type: ButtonType.Normal, stateEffect: true })
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(canPublish ? '#FFFFFF' : '#CCCCCC')
          .backgroundColor(canPublish ? '#FF6B6B' : '#F0F0F0')
          .borderRadius(20)
          .height(36)
          .padding({ left: 20, right: 20 })
          .enabled(canPublish && !this.posting)
          .onClick(() => {
            try {
              console.info('发布请求开始');
              // 双重检查，防止重复点击
              if (this.posting) {
                console.info('正在发布中，忽略重复点击');
                return;
              }
              // 确保表单已初始化
              this.ensurePostFormInitialized();
              // 检查内容是否为空
              const content = (this.newPost?.content || '').trim();
              if (!content) {
                ToastUtils.showToast('请输入动态内容');
                return;
              }
              // 调用发布方法
              this.handlePublishPost();
            } catch (error) {
              console.error('发布异常:', error);
              this.posting = false;
              ToastUtils.showToast('发布失败，请重试');
            }
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 12 })
      .alignItems(VerticalAlign.Center)

      // 内容输入区
      TextArea({ placeholder: '分享你的美食体验...', text: this.newPost?.content ?? '' })
        .fontSize(16)
        .fontColor('#333')
        .backgroundColor(Color.Transparent)
        .width('100%')
        .height(120)
        .padding(16)
        .enabled(!this.posting)
        .onChange((value: string) => {
          this.ensurePostFormInitialized();
          this.newPost.content = value;
        })

      Row() {
        Text(`已选 ${this.getCurrentMediaTotal()}/${this.maxMediaCount}`)
          .fontSize(13)
          .fontColor('#666')
          .layoutWeight(1)
        if (this.mediaProcessing) {
          Row() {
            LoadingProgress()
              .width(14)
              .height(14)
              .color('#007DFF')
            Text('处理中...')
              .fontSize(12)
              .fontColor('#999')
              .margin({ left: 6 })
          }
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 8 })

      if (this.mediaPreviewList.length > 0) {
        Scroll() {
          Row() {
            ForEach(this.mediaPreviewList, (media: SelectedMediaPreview, index: number) => {
              Stack() {
                if (media.type === 'image') {
                  Image(this.normalizePostImagePath(media.path))
                    .width(88)
                    .height(88)
                    .objectFit(ImageFit.Cover)
                    .borderRadius(10)
                } else {
                  Stack({ alignContent: Alignment.Center }) {
                    Image($r('app.media.video'))
                      .width(88)
                      .height(88)
                      .objectFit(ImageFit.Contain)
                    Text('视频')
                      .fontSize(12)
                      .fontColor('#333')
                      .backgroundColor('#80FFFFFF')
                      .borderRadius(12)
                      .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                  }
                  .backgroundColor('#F1F1F1')
                  .width(88)
                  .height(88)
                  .borderRadius(10)
                }

                Button({ type: ButtonType.Normal }) {
                  Image($r('app.media.delete'))
                    .width(16)
                    .height(16)
                    .fillColor(Color.White)
                }
                .width(24)
                .height(24)
                .backgroundColor('#CC000000')
                .borderRadius(12)
                .position({ x: 68, y: 4 })
                .onClick(() => {
                  this.removeMedia(media.type, media.index);
                })
              }
              .margin({ right: 12 })
            }, (media: SelectedMediaPreview, index: number) => media.key)
          }
          .padding({ left: 16, right: 16, bottom: 8 })
        }
        .scrollable(ScrollDirection.Horizontal)
      } else {
        Row() {
          Text('可添加图片或视频，支持从相册/相机获取。')
            .fontSize(13)
            .fontColor('#999')
        }
        .padding({ left: 16, right: 16, bottom: 8 })
      }

      // 分隔线
      Divider()
        .color('#F0F0F0')
        .margin({ left: 16, right: 16, top: 8 })

      // 操作按钮栏 - 优化布局
      Row({ space: 16 }) {
        // 相册图片按钮
        Column({ space: 4 }) {
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            Image($r('app.media.image_gallery'))
              .width(24)
              .height(24)
              .fillColor('#007DFF')
          }
          .width(48)
          .height(48)
          .backgroundColor('#E8F4FF')
          .enabled(!this.posting)
          .onClick(() => {
            try {
              console.info('选择相册图片');
              this.safeOpenGallery('image');
            } catch (e) {
              console.error('选择图片异常:' + JSON.stringify(e));
            }
          })
          Text('图片')
            .fontSize(12)
            .fontColor('#666')
        }
        .alignItems(HorizontalAlign.Center)

        // 相册视频按钮
        Column({ space: 4 }) {
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            Image($r('app.media.video'))
              .width(24)
              .height(24)
              .fillColor('#FF6B00')
          }
          .width(48)
          .height(48)
          .backgroundColor('#FFF3E8')
          .enabled(!this.posting)
          .onClick(() => {
            try {
              console.info('选择相册视频');
              this.safeOpenGallery('video');
            } catch (e) {
              console.error('选择视频异常:' + JSON.stringify(e));
            }
          })
          Text('视频')
            .fontSize(12)
            .fontColor('#666')
        }
        .alignItems(HorizontalAlign.Center)

        // 拍摄按钮
        Column({ space: 4 }) {
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            Image($r('app.media.camera'))
              .width(24)
              .height(24)
              .fillColor('#34C759')
          }
          .width(48)
          .height(48)
          .backgroundColor('#E8F8EC')
          .enabled(!this.posting)
          .onClick(() => {
            try {
              console.info('打开相机');
              this.safeCaptureFromCamera();
            } catch (e) {
              console.error('拍摄异常:' + JSON.stringify(e));
            }
          })
          Text('拍摄')
            .fontSize(12)
            .fontColor('#666')
        }
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ top: 20, bottom: 20 })
    }
    .width('100%')
    .layoutWeight(1)
  }



  // 显示评论
  async showComments(post: Post): Promise<void> {
    this.currentPost = post;
    this.showCommentDialog = true;
    this.commentContent = '';
    // 本地示例帖（id < 0）不请求后端
    if (post.id < 0) {
      this.comments = [];
      return;
    }
    await this.loadComments(post.id);
  }

  // 加载评论列表
  async loadComments(postId: number): Promise<void> {
    if (postId < 0) {
      this.comments = [];
      return;
    }
    try {
      const response: ApiResponse = await ApiUtils.get(`/posts/comments?post_id=${postId}`);

      if (response.statusCode === 200 && response.data) {
        const data = response.data as CommentListResponse;
        this.comments = data.comments || [];
      } else {
        ToastUtils.showToast(response.message || '加载评论失败');
      }
    } catch (error) {
      console.error('加载评论失败:' + JSON.stringify(error));
      ToastUtils.showToast('网络异常，请重试');
    }
  }

  // 添加评论
  async addComment(): Promise<void> {
    if (!this.currentPost) {
      return;
    }

    if (!this.commentContent.trim()) {
      ToastUtils.showToast('请输入评论内容');
      return;
    }
    // 本地示例帖（id < 0）不支持评论
    if (this.currentPost.id < 0) {
      ToastUtils.showToast('示例帖子仅供预览，无法评论');
      return;
    }

    try {
      const commentData: CreateCommentRequest = {
        post_id: this.currentPost.id,
        content: this.commentContent.trim()
      };

      const response: ApiResponse = await ApiUtils.post('/posts/comments/create', commentData);

      if (response.statusCode === 200 && response.data) {
        const data = response.data as CreateCommentResponse;
        // 更新帖子评论数
        const index: number = this.posts.findIndex((p: Post) => p.id === this.currentPost!.id);
        if (index !== -1) {
          this.posts[index].commentCount = data.comment_count;
        }
        // 重新加载评论列表
        await this.loadComments(this.currentPost.id);
        // 清空输入框
        this.commentContent = '';
        ToastUtils.showToast('评论成功');
      } else {
        ToastUtils.showToast(response.message || '评论失败');
      }
    } catch (error) {
      console.error('添加评论失败:' + JSON.stringify(error));
      ToastUtils.showToast('评论失败，请重试');
    }
  }

  // 显示分享对话框
  async showSharePostDialog(post: Post): Promise<void> {
    this.sharePost = post;
    this.showShareDialog = true;
    await this.loadShareFriends();
  }

  // 加载好友列表
  async loadShareFriends(): Promise<void> {
    this.shareLoading = true;
    try {
      const response: ApiResponse = await ApiUtils.get('/messages/conversations');
      if (response.statusCode === 200 && response.data) {
        const data = response.data as ConversationListResponseData;
        const conversations: ConversationItemData[] = data.conversations || [];
        this.shareFriends = conversations.map((conv: ConversationItemData) => {
          return {
            id: conv.userId || 0,
            conversationId: conv.conversationId || conv.id || 0,
            username: conv.username || '',
            avatar: conv.avatar || ''
          } as ShareFriend;
        });
        // 如果没有真实好友，使用本地示例
        if (this.shareFriends.length === 0) {
          this.shareFriends = this.createLocalShareFriends();
        }
      } else {
        this.shareFriends = this.createLocalShareFriends();
      }
    } catch (error) {
      console.error('加载好友列表失败:' + JSON.stringify(error));
      this.shareFriends = this.createLocalShareFriends();
    } finally {
      this.shareLoading = false;
    }
  }

  // 本地示例好友
  private createLocalShareFriends(): ShareFriend[] {
    return [
      { id: 501, conversationId: 1001, username: '厨师', avatar: 'app.media.avatar1' },
      { id: 502, conversationId: 1002, username: '客服', avatar: 'app.media.avatar2' },
      { id: 503, conversationId: 1003, username: '用户', avatar: 'app.media.avatar3' }
    ];
  }

  // 分享给好友
  async shareToFriend(friend: ShareFriend): Promise<void> {
    if (!this.sharePost) return;

    try {
      const shareContent = `【分享帖子】\n${this.sharePost.username}：${this.sharePost.content.substring(0, 100)}${this.sharePost.content.length > 100 ? '...' : ''}`;

      const request: SendMessageRequest = {
        conversation_id: friend.conversationId,
        content: shareContent,
        type: 'text'
      };

      const response: ApiResponse = await ApiUtils.post('/messages/send', request);

      if (response.statusCode === 200) {
        ToastUtils.showToast(`已分享给 ${friend.username}`);
        this.showShareDialog = false;
        this.sharePost = null;
      } else {
        // 对于本地示例对话，也提示成功
        if (friend.conversationId >= 1001 && friend.conversationId <= 1003) {
          ToastUtils.showToast(`已分享给 ${friend.username}`);
          this.showShareDialog = false;
          this.sharePost = null;
        } else {
          ToastUtils.showToast(response.message || '分享失败');
        }
      }
    } catch (error) {
      console.error('分享失败:' + JSON.stringify(error));
      // 对于本地示例对话，即使网络失败也提示成功
      if (friend.conversationId >= 1001 && friend.conversationId <= 1003) {
        ToastUtils.showToast(`已分享给 ${friend.username}`);
        this.showShareDialog = false;
        this.sharePost = null;
      } else {
        ToastUtils.showToast('分享失败，请重试');
      }
    }
  }

  // 评论对话框组件
  @Builder
  CommentDialog() {
    Column() {
      // 标题栏
      Row() {
        Button('关闭')
          .fontSize(16)
          .fontColor('#666')
          .backgroundColor(Color.Transparent)
          .borderColor(Color.Transparent)
          .onClick(() => {
            this.showCommentDialog = false;
            this.currentPost = null;
            this.comments = [];
            this.commentContent = '';
          })

        Text('评论')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .padding(16)
      .border({ width: { bottom: 1 }, color: '#EEE' })

      // 评论列表
      Scroll() {
        Column() {
          if (this.comments.length === 0) {
            Text('暂无评论，快来抢沙发吧~')
              .fontSize(14)
              .fontColor('#999')
              .textAlign(TextAlign.Center)
              .width('100%')
              .padding(40)
          } else {
            ForEach(this.comments, (comment: Comment) => {
              this.CommentItem(comment)
            }, (comment: Comment) => comment.id.toString())
          }
        }
        .width('100%')
        .padding(16)
      }
      .layoutWeight(1)
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Off)

      // 评论输入区
      Row() {
        TextArea({ placeholder: '写评论...', text: this.commentContent })
          .fontSize(15)
          .fontColor('#333')
          .backgroundColor('#F5F5F5')
          .borderRadius(20)
          .layoutWeight(1)
          .height(40)
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .onChange((value: string) => {
            this.commentContent = value;
          })

        Button('发送')
          .fontSize(15)
          .fontColor(this.commentContent.trim() ? '#007DFF' : '#CCC')
          .backgroundColor(Color.Transparent)
          .borderColor(Color.Transparent)
          .enabled(!!this.commentContent.trim())
          .margin({ left: 8 })
          .onClick(() => {
            this.addComment();
          })
      }
      .width('100%')
      .padding(16)
      .backgroundColor(Color.White)
      .border({ width: { top: 1 }, color: '#EEE' })
    }
    .width('100%')
    .height('70%')
    .backgroundColor(Color.White)
    .borderRadius({ topLeft: 16, topRight: 16 })
    .position({ x: 0, y: '30%' })
    .shadow({
      radius: 24,
      color: '#40000000',
      offsetX: 0,
      offsetY: -8
    })
  }

  // 评论项组件
  @Builder
  CommentItem(comment: Comment) {
    Row() {
      Image(comment.avatar || $r('app.media.ic_user_avatar'))
        .width(32)
        .height(32)
        .borderRadius(16)
        .objectFit(ImageFit.Cover)

      Column() {
        Text(comment.username)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333')

        Text(comment.content)
          .fontSize(14)
          .fontColor('#333')
          .width('100%')
          .margin({ top: 4 })
          .lineHeight(20)
      }
      .margin({ left: 12 })
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ top: 12, bottom: 12 })
    .border({ width: { bottom: 1 }, color: '#F0F0F0' })
  }

  // 分享对话框组件
  @Builder
  ShareDialog() {
    Column() {
      // 标题栏
      Row() {
        Text('分享给好友')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Button('×')
          .fontSize(24)
          .fontColor('#666')
          .backgroundColor(Color.Transparent)
          .borderColor(Color.Transparent)
          .width(40)
          .height(40)
          .onClick(() => {
            this.showShareDialog = false;
            this.sharePost = null;
          })
      }
      .width('100%')
      .padding({ left: 16, right: 8, top: 12, bottom: 12 })
      .border({ width: { bottom: 1 }, color: '#EEE' })

      // 分享内容预览
      if (this.sharePost) {
        Row() {
          Column() {
            Text(this.sharePost.username)
              .fontSize(13)
              .fontColor('#666')
              .maxLines(1)
            Text(this.sharePost.content)
              .fontSize(14)
              .fontColor('#333')
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          if (this.sharePost.images && this.sharePost.images.length > 0) {
            Image(this.normalizePostImagePath(this.sharePost.images[0]))
              .width(50)
              .height(50)
              .borderRadius(6)
              .objectFit(ImageFit.Cover)
              .margin({ left: 12 })
          }
        }
        .width('100%')
        .padding(12)
        .backgroundColor('#F8F8F8')
        .borderRadius(8)
        .margin(16)
      }

      // 好友列表
      if (this.shareLoading) {
        LoadingProgress()
          .width(40)
          .height(40)
          .margin({ top: 40 })
      } else if (this.shareFriends.length === 0) {
        Text('暂无好友')
          .fontSize(14)
          .fontColor('#999')
          .textAlign(TextAlign.Center)
          .width('100%')
          .padding(40)
      } else {
        List() {
          ForEach(this.shareFriends, (friend: ShareFriend) => {
            ListItem() {
              Row() {
                Image(friend.avatar.startsWith('app.media.')
                  ? $r(friend.avatar)
                  : (friend.avatar || $r('app.media.ic_user_avatar')))
                  .width(44)
                  .height(44)
                  .borderRadius(22)
                  .objectFit(ImageFit.Cover)

                Text(friend.username)
                  .fontSize(16)
                  .fontColor('#333')
                  .margin({ left: 12 })
                  .layoutWeight(1)

                Button('发送')
                  .fontSize(14)
                  .fontColor(Color.White)
                  .backgroundColor('#007DFF')
                  .borderRadius(16)
                  .height(32)
                  .onClick(() => {
                    this.shareToFriend(friend);
                  })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            }
          }, (friend: ShareFriend) => friend.id.toString())
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('60%')
    .backgroundColor(Color.White)
    .borderRadius({ topLeft: 16, topRight: 16 })
    .position({ x: 0, y: '40%' })
    .shadow({
      radius: 24,
      color: '#40000000',
      offsetX: 0,
      offsetY: -8
    })
  }

  private getSampleShowcasePosts(): Post[] {
    return this.createLocalSamplePosts().slice(0, 3);
  }

  private canPublishPost(): boolean {
    try {
      if (this.posting) {
        return false;
      }
      if (!this.newPost) {
        return false;
      }
      const content: string = (this.newPost.content && typeof this.newPost.content === 'string') 
        ? this.newPost.content 
        : '';
      return content.trim().length > 0;
    } catch (error) {
      console.error('canPublishPost异常: ' + JSON.stringify(error));
      return false;
    }
  }

  private createLocalSamplePosts(): Post[] {
    const now: number = Date.now();
    const samples: SamplePostData[] = [
      {
        id: -101,
        username: '美食达人阿九',
        avatar: 'app.media.avatar1',
        content: '刚推出的宫保鸡丁超受欢迎！花生酥脆、鸡肉鲜嫩，一口下去满满的幸福感～配上米饭简直是绝配！',
        images: ['app.media.dish1'],
        videos: [],
        likeCount: 128,
        commentCount: 23,
        createTimeOffsetMinutes: 12
      },
      {
        id: -102,
        username: '今日小厨',
        avatar: 'app.media.avatar2',
        content: '麻婆豆腐上线啦！秘制豆瓣酱调味，吃一口就停不下来。谁愿意和我一起加个蛋黄？',
        images: ['app.media.dish2', 'app.media.dish4'],
        videos: [],
        likeCount: 86,
        commentCount: 17,
        createTimeOffsetMinutes: 35
      },
      {
        id: -103,
        username: '甜咸党代表',
        avatar: 'app.media.avatar3',
        content: '糖醋里脊是甜口党的快乐源泉！酸酸甜甜超级开胃，今天的午饭又被治愈了～推荐大家试试！',
        images: ['app.media.dish3'],
        videos: [],
        likeCount: 204,
        commentCount: 31,
        createTimeOffsetMinutes: 58
      },
      {
        id: -104,
        username: '健康吃货',
        avatar: 'app.media.avatar',
        content: '清蒸鲈鱼来了！少油少盐保留原汁原味，肉质细嫩，强烈推荐给正在健身的朋友们。',
        images: ['app.media.dish5'],
        videos: [],
        likeCount: 64,
        commentCount: 9,
        createTimeOffsetMinutes: 90
      },
      {
        id: -105,
        username: '美食探索家',
        avatar: 'app.media.avatar1',
        content: '今天尝试了新的川菜，水煮鱼片麻辣鲜香，配上一碗白米饭，简直是人间美味！',
        images: ['app.media.dish1', 'app.media.dish2'],
        videos: [],
        likeCount: 156,
        commentCount: 28,
        createTimeOffsetMinutes: 120
      },
      {
        id: -106,
        username: '料理小能手',
        avatar: 'app.media.avatar2',
        content: '自己做的红烧肉，肥而不腻，入口即化。分享给大家，希望你们也能做出美味的家常菜！',
        images: ['app.media.dish3', 'app.media.dish4', 'app.media.dish5'],
        videos: [],
        likeCount: 189,
        commentCount: 42,
        createTimeOffsetMinutes: 150
      }
    ];

    return samples.map((sample: SamplePostData) => {
      const post = new Post();
      post.id = sample.id;
      post.username = sample.username;
      post.avatar = sample.avatar;
      post.content = sample.content;
      post.images = sample.images ? sample.images : [];
      post.videos = sample.videos ? sample.videos : [];
      post.likeCount = sample.likeCount;
      post.commentCount = sample.commentCount;
      post.isLiked = false;
      post.createTime = now - sample.createTimeOffsetMinutes * 60 * 1000;
      return post;
    });
  }
}