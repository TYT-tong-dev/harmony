// ProfilePage.ets
import { UserInfo, SalesStats, ApiResponse, TopDish, AppMode } from '../common/Types';
import { ApiUtils, ToastUtils, AppModeManager, RouterUtils } from '../common/Utils';
import router from '@ohos.router';
import picker from '@ohos.file.picker';
import abilityAccessCtrl from '@ohos.abilityAccessCtrl';
import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';
import prompt from '@ohos.promptAction';

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

interface UpdateProfileRequest {
  username?: string;
  address?: string;
  avatar?: string;
}

interface UpdatePasswordRequest {
  old_password: string;
  new_password: string;
}

interface UpdateEmailRequest {
  email: string;
}

interface StoredUserInfo {
  id?: number;
  username?: string;
  name?: string;
  email?: string;
  avatar?: string;
  shopName?: string;
  type?: string;
  address?: string;
}

@Entry
@Component
export struct ProfilePage {
  @State isLoggedIn: boolean = false;
  @State userInfo: UserInfo = new UserInfo();
  @State salesStats: SalesStats = new SalesStats();
  @State isLoading: boolean = false;
  @State showAvatarPicker: boolean = false;
  @State showEditProfile: boolean = false;
  @State showEditPassword: boolean = false;
  @State showEditEmail: boolean = false;
  @StorageLink('appMode') appMode: AppMode = AppMode.MERCHANT;
  @StorageLink('currentTableId') currentTableId: string = '';
  
  // 编辑表单状态
  @State editUsername: string = '';
  @State editAddress: string = '';
  @State oldPassword: string = '';
  @State newPassword: string = '';
  @State confirmPassword: string = '';
  @State editEmail: string = '';

  private context?: common.UIAbilityContext;
  private atManager?: abilityAccessCtrl.AtManager;
  private mediaPermissionsGranted: boolean = false;
  private readonly mediaPermissions: MediaPermissionName[] = [
    'ohos.permission.READ_MEDIA',
    'ohos.permission.WRITE_MEDIA',
    'ohos.permission.READ_IMAGEVIDEO',
    'ohos.permission.WRITE_IMAGEVIDEO',
    'ohos.permission.CAMERA'
  ];

  aboutToAppear() {
    try {
      this.context = getContext(this) as common.UIAbilityContext;
      this.atManager = abilityAccessCtrl.createAtManager();
    } catch (error) {
      console.error('初始化页面上下文失败:' + JSON.stringify(error));
    }
    this.checkLoginStatus();
    if (this.isLoggedIn) {
      this.loadUserProfile();
      this.loadSalesStats();
    }
  }

  private get isCustomerMode(): boolean {
    return this.appMode === AppMode.CUSTOMER;
  }

  build() {
    Stack() {
      Column() {
        if (this.isLoggedIn) {
          this.LoggedInView()
        } else {
          this.NotLoggedInView()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F5F5F5')

      // 编辑个人资料对话框
      if (this.showEditProfile) {
        this.EditProfileDialog()
      }

      // 修改密码对话框
      if (this.showEditPassword) {
        this.EditPasswordDialog()
      }

      // 修改邮箱对话框
      if (this.showEditEmail) {
        this.EditEmailDialog()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  LoggedInView() {
    Scroll() {
      Column() {
        if (this.isCustomerMode) {
          this.CustomerModeCard()
        }

        // 登录信息展示
        this.LoginInfoCard()

        if (!this.isCustomerMode) {
          // 销售信息展示
          this.SalesInfoCard()
          this.MerchantToolsCard()
        } else {
          this.CustomerTableCard()
        }

        // 设置部分
        this.SettingsSection()
      }
    }
    .layoutWeight(1)
  }

  @Builder
  NotLoggedInView() {
    Column() {
      Image($r('app.media.ic_user_avatar'))
        .width(80)
        .height(80)
        .margin({ bottom: 20 })

      Text('登录后享受更多服务')
        .fontSize(16)
        .fontColor('#666666')
        .margin({ bottom: 30 })

      Button('点击登录')
        .width(200)
        .height(44)
        .backgroundColor('#007DFF')
        .fontColor('#FFFFFF')
        .fontSize(16)
        .borderRadius(22)
        .onClick(() => {
          this.navigateToLogin();
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  LoginInfoCard() {
    Row() {
      // 头像
      Image(this.getImagePath(this.userInfo.avatar) || $r('app.media.ic_user_avatar'))
        .width(60)
        .height(60)
        .borderRadius(30)
        .margin({ right: 12 })
        .onClick(() => {
          this.changeAvatar();
        })

      Column() {
        Text(this.userInfo.username || '未设置昵称')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')

        Text(this.userInfo.email || '未设置邮箱')
          .fontSize(14)
          .fontColor('#666666')
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Button('退出登录', { type: ButtonType.Normal, stateEffect: true })
        .height(36)
        .fontSize(14)
        .backgroundColor('#FF3B30')
        .fontColor('#FFFFFF')
        .borderRadius(18)
        .onClick(() => {
          this.logout();
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .margin({ top: 12, left: 12, right: 12 })
    .borderRadius(8)
  }

  @Builder
  SalesInfoCard() {
    Column() {
      Text('销售信息')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
        .margin({ bottom: 16 })

      // 销售额
      Row() {
        Column() {
          Text('¥' + this.salesStats.total_revenue.toFixed(2))
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FF6B00')

          Text('总销售额')
            .fontSize(14)
            .fontColor('#666666')
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .padding({ top: 16, bottom: 16 })
      .margin({ bottom: 12 })
      .backgroundColor('#FFF7E6')
      .borderRadius(8)

      // 销售数量
      Row() {
        Column() {
          Text(this.salesStats.total_quantity.toString())
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#007DFF')

          Text('总销售数量')
            .fontSize(14)
            .fontColor('#666666')
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .padding({ top: 16, bottom: 16 })
      .margin({ bottom: 12 })
      .backgroundColor('#E6F2FF')
      .borderRadius(8)

      // 销售最多的菜品
      if (this.salesStats.top_dish) {
        Row() {
          Image(this.getImagePath(this.salesStats.top_dish.image_url))
            .width(60)
            .height(60)
            .borderRadius(8)
            .margin({ right: 12 })

          Column() {
            Text('销售最多')
              .fontSize(12)
              .fontColor('#999999')
              .margin({ bottom: 4 })

            Text(this.salesStats.top_dish.name)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#333333')

            Text(`已售 ${this.salesStats.top_dish.total_sold} 份`)
              .fontSize(14)
              .fontColor('#666666')
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .padding(12)
        .backgroundColor('#F0F9FF')
        .borderRadius(8)
      } else {
        Row() {
          Text('暂无销售数据')
            .fontSize(14)
            .fontColor('#999999')
        }
        .width('100%')
        .padding(12)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .margin({ top: 12, left: 12, right: 12 })
    .borderRadius(8)
  }

  @Builder
  MerchantToolsCard() {
    Column({ space: 12 }) {
      Text('经营工具')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')

      Column() {
        this.ToolListItem('桌号二维码', '生成桌贴，顾客扫码即进入点餐', () => {
          this.navigateToTableQRCode();
        })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .margin({ top: 12, left: 12, right: 12 })
    .borderRadius(8)
  }

  @Builder
  ToolListItem(title: string, subtitle: string, action: () => void) {
    Row() {
      Column() {
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1A1A1A')
        Text(subtitle)
          .fontSize(12)
          .fontColor('#888888')
          .margin({ top: 4 })
      }
      .layoutWeight(1)

      Image($r('app.media.qr_code'))
        .width(32)
        .height(32)
        .fillColor('#007DFF')
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
    .onClick(() => action())
  }

  @Builder
  CustomerModeCard() {
    Column({ space: 8 }) {
      Text('当前为顾客模式')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A1A')
      Text('部分商家经营能力已隐藏，扫码点餐体验一致。')
        .fontSize(13)
        .fontColor('#666666')
      Button('切换回商家端', { type: ButtonType.Normal, stateEffect: true })
        .height(38)
        .fontSize(14)
        .borderRadius(19)
        .backgroundColor('#FFFFFF')
        .fontColor('#007DFF')
        .onClick(() => {
          this.switchToMerchantMode();
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#F0F6FF')
    .margin({ top: 12, left: 12, right: 12 })
    .borderRadius(10)
  }

  @Builder
  CustomerTableCard() {
    Column({ space: 6 }) {
      Text('顾客桌台信息')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A1A')
      Text(this.currentTableId ? `正在为 ${this.currentTableId} 桌点餐` : '未绑定桌号，可扫码进入指定餐桌')
        .fontSize(14)
        .fontColor('#666666')
      Button('重新扫码进入', { type: ButtonType.Capsule, stateEffect: true })
        .height(34)
        .fontSize(13)
        .borderRadius(17)
        .backgroundColor('#007DFF')
        .fontColor('#FFFFFF')
        .onClick(() => {
          ToastUtils.showToast('请扫描桌号二维码进入顾客端');
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .margin({ top: 12, left: 12, right: 12 })
    .borderRadius(8)
  }

  @Builder
  SettingsSection() {
    Column() {
      // 个人资料
      Text('个人资料')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#333333')
        .margin({ bottom: 12 })
        .alignSelf(ItemAlign.Start)

      // 头像
      Row() {
        Text('头像')
          .fontSize(16)
          .fontColor('#333333')
          .layoutWeight(1)

        Image(this.getImagePath(this.userInfo.avatar) || $r('app.media.ic_user_avatar'))
          .width(50)
          .height(50)
          .borderRadius(25)
          .margin({ right: 8 })

        Image($r('app.media.arrow_right'))
          .width(16)
          .height(16)
      }
      .width('100%')
      .padding({ top: 12, bottom: 12 })
      .onClick(() => {
        this.changeAvatar();
      })

      Divider()
        .strokeWidth(1)
        .color('#F0F0F0')

      // 昵称
      Row() {
        Text('昵称')
          .fontSize(16)
          .fontColor('#333333')
          .layoutWeight(1)

        Text(this.userInfo.username || '未设置')
          .fontSize(14)
          .fontColor('#666666')
          .margin({ right: 8 })

        Image($r('app.media.arrow_right'))
          .width(16)
          .height(16)
      }
      .width('100%')
      .padding({ top: 12, bottom: 12 })
      .onClick(() => {
        this.editUsername = this.userInfo.username || '';
        this.showEditProfile = true;
      })

      Divider()
        .strokeWidth(1)
        .color('#F0F0F0')

      // 地址
      Row() {
        Text('地址')
          .fontSize(16)
          .fontColor('#333333')
          .layoutWeight(1)

        Text(this.userInfo.address || '未设置')
          .fontSize(14)
          .fontColor('#666666')
          .margin({ right: 8 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Image($r('app.media.arrow_right'))
          .width(16)
          .height(16)
      }
      .width('100%')
      .padding({ top: 12, bottom: 12 })
      .onClick(() => {
        this.editAddress = this.userInfo.address || '';
        this.showEditProfile = true;
      })

      // 社交功能
      Text('社交功能')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#333333')
        .margin({ top: 24, bottom: 12 })
        .alignSelf(ItemAlign.Start)

      // 我的关注
      Row() {
        Text('我的关注')
          .fontSize(16)
          .fontColor('#333333')
          .layoutWeight(1)

        Text('查看关注的用户')
          .fontSize(14)
          .fontColor('#666666')
          .margin({ right: 8 })

        Image($r('app.media.arrow_right'))
          .width(16)
          .height(16)
      }
      .width('100%')
      .padding({ top: 12, bottom: 12 })
      .onClick(() => {
        router.pushUrl({ url: 'pages/MyFollowsPage' });
      })

      // 账号安全
      Text('账号安全')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#333333')
        .margin({ top: 24, bottom: 12 })
        .alignSelf(ItemAlign.Start)

      // 密码
      Row() {
        Text('密码')
          .fontSize(16)
          .fontColor('#333333')
          .layoutWeight(1)

        Text('修改密码')
          .fontSize(14)
          .fontColor('#666666')
          .margin({ right: 8 })

        Image($r('app.media.arrow_right'))
          .width(16)
          .height(16)
      }
      .width('100%')
      .padding({ top: 12, bottom: 12 })
      .onClick(() => {
        this.oldPassword = '';
        this.newPassword = '';
        this.confirmPassword = '';
        this.showEditPassword = true;
      })

      Divider()
        .strokeWidth(1)
        .color('#F0F0F0')

      // 邮箱
      Row() {
        Text('邮箱')
          .fontSize(16)
          .fontColor('#333333')
          .layoutWeight(1)

        Text(this.userInfo.email || '未设置')
          .fontSize(14)
          .fontColor('#666666')
          .margin({ right: 8 })

        Image($r('app.media.arrow_right'))
          .width(16)
          .height(16)
      }
      .width('100%')
      .padding({ top: 12, bottom: 12 })
      .onClick(() => {
        this.editEmail = this.userInfo.email || '';
        this.showEditEmail = true;
      })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .margin({ top: 12, left: 12, right: 12, bottom: 12 })
    .borderRadius(8)
  }

  @Builder
  EditProfileDialog() {
    Stack({ alignContent: Alignment.Center }) {
      // 背景遮罩
      Column() {
      Blank()
      }
        .width('100%')
        .height('100%')
        .backgroundColor('#80000000')
        .onClick(() => {
          this.showEditProfile = false;
        })

      // 对话框内容
      Column() {
        Text('编辑个人资料')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
          .margin({ bottom: 20 })

        TextInput({ placeholder: '请输入昵称', text: this.editUsername })
          .width('100%')
          .height(44)
          .margin({ bottom: 12 })
          .onChange((value: string) => {
            this.editUsername = value;
          })

        TextInput({ placeholder: '请输入地址', text: this.editAddress })
          .width('100%')
          .height(44)
          .margin({ bottom: 20 })
          .onChange((value: string) => {
            this.editAddress = value;
          })

        Row() {
          Button('取消', { type: ButtonType.Normal, stateEffect: true })
            .layoutWeight(1)
            .height(44)
            .backgroundColor('#F5F5F5')
            .fontColor('#333333')
            .margin({ right: 8 })
            .onClick(() => {
              this.showEditProfile = false;
            })

          Button('保存', { type: ButtonType.Normal, stateEffect: true })
            .layoutWeight(1)
            .height(44)
            .backgroundColor('#007DFF')
            .fontColor('#FFFFFF')
            .onClick(() => {
              this.saveProfile();
            })
        }
        .width('100%')
      }
      .width('90%')
      .padding(20)
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
      .shadow({
        radius: 20,
        color: '#000000',
        offsetX: 0,
        offsetY: 4
      })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  EditPasswordDialog() {
    Stack({ alignContent: Alignment.Center }) {
      // 背景遮罩
      Column() {
      Blank()
      }
        .width('100%')
        .height('100%')
        .backgroundColor('#80000000')
        .onClick(() => {
          this.showEditPassword = false;
        })

      // 对话框内容
      Column() {
        Text('修改密码')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
          .margin({ bottom: 20 })

        TextInput({ placeholder: '请输入原密码', text: this.oldPassword })
          .type(InputType.Password)
          .width('100%')
          .height(44)
          .margin({ bottom: 12 })
          .onChange((value: string) => {
            this.oldPassword = value;
          })

        TextInput({ placeholder: '请输入新密码', text: this.newPassword })
          .type(InputType.Password)
          .width('100%')
          .height(44)
          .margin({ bottom: 12 })
          .onChange((value: string) => {
            this.newPassword = value;
          })

        TextInput({ placeholder: '请确认新密码', text: this.confirmPassword })
          .type(InputType.Password)
          .width('100%')
          .height(44)
          .margin({ bottom: 20 })
          .onChange((value: string) => {
            this.confirmPassword = value;
          })

        Row() {
          Button('取消', { type: ButtonType.Normal, stateEffect: true })
            .layoutWeight(1)
            .height(44)
            .backgroundColor('#F5F5F5')
            .fontColor('#333333')
            .margin({ right: 8 })
            .onClick(() => {
              this.showEditPassword = false;
            })

          Button('保存', { type: ButtonType.Normal, stateEffect: true })
            .layoutWeight(1)
            .height(44)
            .backgroundColor('#007DFF')
            .fontColor('#FFFFFF')
            .onClick(() => {
              this.savePassword();
            })
        }
        .width('100%')
      }
      .width('90%')
      .padding(20)
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
      .shadow({
        radius: 20,
        color: '#000000',
        offsetX: 0,
        offsetY: 4
      })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  EditEmailDialog() {
    Stack({ alignContent: Alignment.Center }) {
      // 背景遮罩
      Column() {
      Blank()
      }
        .width('100%')
        .height('100%')
        .backgroundColor('#80000000')
        .onClick(() => {
          this.showEditEmail = false;
        })

      // 对话框内容
      Column() {
        Text('修改邮箱')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
          .margin({ bottom: 20 })

        TextInput({ placeholder: '请输入新邮箱', text: this.editEmail })
          .width('100%')
          .height(44)
          .margin({ bottom: 20 })
          .onChange((value: string) => {
            this.editEmail = value;
          })

        Row() {
          Button('取消', { type: ButtonType.Normal, stateEffect: true })
            .layoutWeight(1)
            .height(44)
            .backgroundColor('#F5F5F5')
            .fontColor('#333333')
            .margin({ right: 8 })
            .onClick(() => {
              this.showEditEmail = false;
            })

          Button('保存', { type: ButtonType.Normal, stateEffect: true })
            .layoutWeight(1)
            .height(44)
            .backgroundColor('#007DFF')
            .fontColor('#FFFFFF')
            .onClick(() => {
              this.saveEmail();
            })
        }
        .width('100%')
      }
      .width('90%')
      .padding(20)
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
      .shadow({
        radius: 20,
        color: '#000000',
        offsetX: 0,
        offsetY: 4
      })
    }
    .width('100%')
    .height('100%')
  }

  // 检查登录状态
  checkLoginStatus() {
    try {
      const token = AppStorage.get<string>('userToken') || '';
      const infoStr = AppStorage.get<string>('userInfo') || '';
      this.isLoggedIn = !!token;
      if (infoStr && this.isLoggedIn) {
        const parsed: StoredUserInfo = JSON.parse(infoStr) as StoredUserInfo;
        if (parsed.username !== undefined || parsed.name !== undefined) {
          this.userInfo.username = parsed.username !== undefined ? parsed.username as string
            : (parsed.name as string);
        }
        if (parsed.email !== undefined) {
          this.userInfo.email = parsed.email as string;
        }
        if (parsed.id !== undefined) {
          this.userInfo.id = parsed.id as number;
        }
        if (parsed.avatar !== undefined) {
          this.userInfo.avatar = parsed.avatar as string;
        }
        if (parsed.shopName !== undefined) {
          this.userInfo.shopName = parsed.shopName as string;
        }
        if (parsed.type !== undefined) {
          this.userInfo.type = parsed.type as string;
        }
        if (parsed.address !== undefined) {
          this.userInfo.address = parsed.address as string;
        }
      }
    } catch (e) {
      this.isLoggedIn = false;
    }
  }

  // 加载用户资料
  private navigateToTableQRCode() {
    if (this.isCustomerMode) {
      ToastUtils.showToast('请在商家端使用桌号工具');
      return;
    }
    RouterUtils.pushUrl('pages/TableQRCodePage');
  }

  private switchToMerchantMode() {
    AppModeManager.setMode(AppMode.MERCHANT, { silent: true });
    ToastUtils.showToast('已切回商家端，请登录继续');
    RouterUtils.replaceUrl('pages/LoginPage');
  }

  async loadUserProfile() {
    try {
      this.isLoading = true;
      const response: ApiResponse = await ApiUtils.get('/Users/Profile');
      if (response.statusCode === 200 && response.data) {
        const data = response.data as Record<string, Object>;
        if (data.username !== undefined) {
          this.userInfo.username = data.username as string;
        }
        if (data.email !== undefined) {
          this.userInfo.email = data.email as string;
        }
        if (data.avatar !== undefined) {
          this.userInfo.avatar = data.avatar as string;
        }
        if (data.address !== undefined) {
          this.userInfo.address = data.address as string;
        }
        // 更新本地存储
        AppStorage.setOrCreate('userInfo', JSON.stringify({
          username: this.userInfo.username,
          email: this.userInfo.email,
          avatar: this.userInfo.avatar,
          address: this.userInfo.address,
          id: this.userInfo.id
        }));
      }
    } catch (error) {
      console.error('加载用户资料失败:' + JSON.stringify(error));
    } finally {
      this.isLoading = false;
    }
  }

  // 加载销售统计
  async loadSalesStats() {
    try {
      const response: ApiResponse = await ApiUtils.get('/sales/stats');
      if (response.statusCode === 200 && response.data) {
        const data = response.data as Record<string, Object>;
        if (data.total_revenue !== undefined) {
          this.salesStats.total_revenue = Number(data.total_revenue);
        }
        if (data.total_quantity !== undefined) {
          this.salesStats.total_quantity = Number(data.total_quantity);
        }
        if (data.top_dish !== undefined) {
          this.salesStats.top_dish = data.top_dish as TopDish;
        }
      }
    } catch (error) {
      console.error('加载销售统计失败:' + JSON.stringify(error));
    }
  }

  // 修改头像
  async changeAvatar() {
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
        const uri = result.photoUris[0];
        const savedPath = await this.persistAvatarImage(uri);
        if (savedPath) {
          await this.updateAvatar(savedPath);
        }
      }
    } catch (error) {
      console.error('选择头像失败:' + JSON.stringify(error));
      ToastUtils.showToast('选择头像失败，请重试');
    }
  }

  // 保存头像到应用私有目录
  private async persistAvatarImage(uri: string): Promise<string> {
    if (!this.context) {
      try {
        this.context = getContext(this) as common.UIAbilityContext;
      } catch (error) {
        console.error('获取上下文失败:' + JSON.stringify(error));
        return '';
      }
    }
    if (!this.context) {
      return '';
    }
    try {
      const sourcePath: string = this.resolveFilePath(uri);
      if (!sourcePath) {
        console.error('无法解析图片路径:' + uri);
        return '';
      }
      
      // 检查源文件是否存在
      try {
        fs.accessSync(sourcePath);
      } catch (error) {
        console.error('源图片文件不存在:' + sourcePath);
        return '';
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
      
      // 创建avatars子目录用于存储头像
      const avatarsDir: string = `${filesDir}/avatars`;
      try {
        fs.accessSync(avatarsDir);
      } catch (error) {
        try {
          fs.mkdirSync(avatarsDir, true);
        } catch (mkdirError) {
          console.error('创建avatarsDir失败:' + JSON.stringify(mkdirError));
        }
      }
      
      // 生成唯一文件名
      const extension: string = this.extractExtension(sourcePath, '.jpg');
      const fileName: string = `avatar_${Date.now()}_${Math.floor(Math.random() * 10000)}${extension}`;
      const targetPath: string = `${avatarsDir}/${fileName}`;
      
      // 复制文件到应用私有目录
      fs.copyFileSync(sourcePath, targetPath);
      
      // 返回相对路径(相对于filesDir),这样数据库只存储相对路径
      const relativePath: string = `avatars/${fileName}`;
      console.log('头像已保存到:' + targetPath + ', 相对路径:' + relativePath);
      return relativePath;
    } catch (error) {
      console.error('保存头像失败:' + JSON.stringify(error));
      ToastUtils.showToast('保存头像失败');
      return '';
    }
  }

  // 更新头像到服务器
  private async updateAvatar(avatarPath: string) {
    try {
      this.isLoading = true;
      const requestBody: UpdateProfileRequest = {
        avatar: avatarPath
      };
      const response: ApiResponse = await ApiUtils.put('/Users/Profile', requestBody);
      if (response.statusCode === 200 && response.data) {
        const data = response.data as Record<string, Object>;
        if (data.avatar !== undefined) {
          this.userInfo.avatar = data.avatar as string;
        }
        // 更新本地存储
        const infoStr = AppStorage.get<string>('userInfo') || '{}';
        try {
          const userInfo: StoredUserInfo = JSON.parse(infoStr) as StoredUserInfo;
          userInfo.avatar = this.userInfo.avatar;
          AppStorage.setOrCreate('userInfo', JSON.stringify(userInfo));
        } catch (e) {
          console.error('更新本地存储失败:' + JSON.stringify(e));
        }
        ToastUtils.showToast('头像更新成功');
      } else {
        ToastUtils.showToast(response.message || '头像更新失败');
      }
    } catch (error) {
      console.error('更新头像失败:' + JSON.stringify(error));
      ToastUtils.showToast('头像更新失败');
    } finally {
      this.isLoading = false;
    }
  }

  // 保存个人资料
  async saveProfile() {
    if (!this.editUsername.trim() && !this.editAddress.trim()) {
      ToastUtils.showToast('请至少填写一项');
      return;
    }
    try {
      this.isLoading = true;
      const requestBody: UpdateProfileRequest = {};
      if (this.editUsername.trim()) {
        requestBody.username = this.editUsername.trim();
      }
      if (this.editAddress.trim()) {
        requestBody.address = this.editAddress.trim();
      }
      const response: ApiResponse = await ApiUtils.put('/Users/Profile', requestBody);
      if (response.statusCode === 200 && response.data) {
        const data = response.data as Record<string, Object>;
        if (data.username !== undefined) {
          this.userInfo.username = data.username as string;
        }
        if (data.address !== undefined) {
          this.userInfo.address = data.address as string;
        }
        // 更新本地存储
        const infoStr = AppStorage.get<string>('userInfo') || '{}';
        try {
          const userInfo: StoredUserInfo = JSON.parse(infoStr) as StoredUserInfo;
          userInfo.username = this.userInfo.username;
          userInfo.address = this.userInfo.address;
          AppStorage.setOrCreate('userInfo', JSON.stringify(userInfo));
        } catch (e) {
          console.error('更新本地存储失败:' + JSON.stringify(e));
        }
        ToastUtils.showToast('更新成功');
        this.showEditProfile = false;
      } else {
        ToastUtils.showToast(response.message || '更新失败');
      }
    } catch (error) {
      console.error('更新个人资料失败:' + JSON.stringify(error));
      ToastUtils.showToast('更新失败');
    } finally {
      this.isLoading = false;
    }
  }

  // 保存密码
  async savePassword() {
    if (!this.oldPassword.trim()) {
      ToastUtils.showToast('请输入原密码');
      return;
    }
    if (!this.newPassword.trim()) {
      ToastUtils.showToast('请输入新密码');
      return;
    }
    if (this.newPassword.length < 6) {
      ToastUtils.showToast('密码长度至少6位');
      return;
    }
    if (this.newPassword !== this.confirmPassword) {
      ToastUtils.showToast('两次输入的密码不一致');
      return;
    }
    try {
      this.isLoading = true;
      const requestBody: UpdatePasswordRequest = {
        old_password: this.oldPassword,
        new_password: this.newPassword
      };
      const response: ApiResponse = await ApiUtils.put('/Users/Password', requestBody);
      if (response.statusCode === 200) {
        ToastUtils.showToast('密码修改成功');
        this.showEditPassword = false;
        this.oldPassword = '';
        this.newPassword = '';
        this.confirmPassword = '';
      } else {
        ToastUtils.showToast(response.message || '密码修改失败');
      }
    } catch (error) {
      console.error('修改密码失败:' + JSON.stringify(error));
      ToastUtils.showToast('密码修改失败');
    } finally {
      this.isLoading = false;
    }
  }

  // 保存邮箱
  async saveEmail() {
    if (!this.editEmail.trim()) {
      ToastUtils.showToast('请输入邮箱');
      return;
    }
    // 简单的邮箱格式验证
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(this.editEmail.trim())) {
      ToastUtils.showToast('邮箱格式不正确');
      return;
    }
    try {
      this.isLoading = true;
      const requestBody: UpdateEmailRequest = {
        email: this.editEmail.trim()
      };
      const response: ApiResponse = await ApiUtils.put('/Users/Email', requestBody);
      if (response.statusCode === 200 && response.data) {
        const data = response.data as Record<string, Object>;
        if (data.email !== undefined) {
          this.userInfo.email = data.email as string;
        }
        // 更新本地存储
        const infoStr = AppStorage.get<string>('userInfo') || '{}';
        try {
          const userInfo: StoredUserInfo = JSON.parse(infoStr) as StoredUserInfo;
          userInfo.email = this.userInfo.email;
          AppStorage.setOrCreate('userInfo', JSON.stringify(userInfo));
        } catch (e) {
          console.error('更新本地存储失败:' + JSON.stringify(e));
        }
        ToastUtils.showToast('邮箱更新成功');
        this.showEditEmail = false;
      } else {
        ToastUtils.showToast(response.message || '邮箱更新失败');
      }
    } catch (error) {
      console.error('更新邮箱失败:' + JSON.stringify(error));
      ToastUtils.showToast('邮箱更新失败');
    } finally {
      this.isLoading = false;
    }
  }

  // 申请媒体权限
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

  // 解析文件路径
  private resolveFilePath(uri: string): string {
    if (!uri) {
      return '';
    }
    if (uri.startsWith('file://')) {
      return uri.replace('file://', '');
    }
    if (uri.startsWith('/')) {
      return uri;
    }
    if (!this.context) {
      return uri;
    }
    return `${this.context.filesDir}/${uri}`;
  }

  // 提取文件扩展名
  private extractExtension(path: string, defaultExt: string): string {
    const lastDot = path.lastIndexOf('.');
    if (lastDot > 0 && lastDot < path.length - 1) {
      return path.substring(lastDot);
    }
    return defaultExt;
  }

  // 获取图片路径（支持相对路径和绝对路径）
  private getImagePath(path: string): string {
    if (!path) {
      return '';
    }
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    if (path.startsWith('/')) {
      return `file://${path}`;
    }
    if (!this.context) {
      try {
        this.context = getContext(this) as common.UIAbilityContext;
      } catch (error) {
        return path;
      }
    }
    if (!this.context) {
      return path;
    }
    const fullPath = `${this.context.filesDir}/${path}`;
    try {
      fs.accessSync(fullPath);
      return `file://${fullPath}`;
    } catch (error) {
      return path;
    }
  }

  // 跳转到登录页面
  navigateToLogin() {
    router.pushUrl({
      url: 'pages/LoginPage'
    });
  }

  // 退出登录
  logout() {
    AppStorage.setOrCreate('isLoggedIn', false);
    AppStorage.setOrCreate('userToken', '');
    AppStorage.setOrCreate('userInfo', '{}');
    this.isLoggedIn = false;
    this.userInfo = new UserInfo();
    this.salesStats = new SalesStats();
    ToastUtils.showToast('已退出登录');
  }
}
