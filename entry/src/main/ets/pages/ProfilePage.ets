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

interface SettingsItem {
  icon: string;
  title: string;
  value: string;
  showAvatar?: boolean;
  action: () => void;
}

// 创建设置项的辅助函数
function createSettingsItem(icon: string, title: string, value: string, action: () => void, showAvatar?: boolean): SettingsItem {
  const item: SettingsItem = {
    icon: icon,
    title: title,
    value: value,
    showAvatar: showAvatar || false,
    action: action
  };
  return item;
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
        // 顶部渐变背景头部
        this.ProfileHeader()

        if (this.isCustomerMode) {
          this.CustomerModeCard()
        }

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
      .padding({ bottom: 20 })
    }
    .layoutWeight(1)
    .backgroundColor('#F5F7FA')
  }

  @Builder
  ProfileHeader() {
    Stack({ alignContent: Alignment.Bottom }) {
      // 渐变背景
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

      // 用户信息卡片
      Column() {
        // 头像和基本信息
        Row({ space: 16 }) {
          Stack() {
            Image(this.getImagePath(this.userInfo.avatar) || $r('app.media.ic_user_avatar'))
              .width(80)
              .height(80)
              .borderRadius(40)
              .objectFit(ImageFit.Cover)
              .border({ width: 3, color: '#FFFFFF' })
              .shadow({
                radius: 12,
                color: 'rgba(0,0,0,0.15)',
                offsetX: 0,
                offsetY: 4
              })

            // 编辑头像图标
            Column() {
              Text('📷')
                .fontSize(14)
            }
            .width(28)
            .height(28)
            .borderRadius(14)
            .backgroundColor('#007DFF')
            .justifyContent(FlexAlign.Center)
            .position({ x: 56, y: 56 })
          }
          .onClick(() => {
            this.changeAvatar();
          })

          Column({ space: 6 }) {
            Text(this.userInfo.username || '未设置昵称')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A1A')

            Text(this.userInfo.email || '未设置邮箱')
              .fontSize(14)
              .fontColor('#666666')

            if (this.userInfo.address) {
              Row({ space: 4 }) {
                Text('📍')
                  .fontSize(12)
                Text(this.userInfo.address)
                  .fontSize(12)
                  .fontColor('#999999')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
            }
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 20, bottom: 16 })

        // 退出登录按钮
        Button('退出登录', { type: ButtonType.Normal, stateEffect: true })
          .width('90%')
          .height(44)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .backgroundColor('rgba(255,59,48,0.1)')
          .fontColor('#FF3B30')
          .borderRadius(22)
          .margin({ bottom: 16 })
          .onClick(() => {
            this.logout();
          })
      }
      .width('92%')
      .backgroundColor('#FFFFFF')
      .borderRadius(20)
      .shadow({
        radius: 20,
        color: 'rgba(0,0,0,0.08)',
        offsetX: 0,
        offsetY: 8
      })
      .margin({ bottom: -40 })
    }
    .width('100%')
    .height(260)
    .margin({ bottom: 50 })
  }

  @Builder
  NotLoggedInView() {
    Column() {
      // 渐变背景
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width('100%')
          .height('100%')
          .linearGradient({
            angle: 180,
            colors: [
              ['#667eea', 0],
              ['#764ba2', 0.5],
              ['#F5F7FA', 0.5],
              ['#F5F7FA', 1]
            ]
          })

        Column({ space: 24 }) {
          // 头像区域
          Column() {
            Image($r('app.media.ic_user_avatar'))
              .width(100)
              .height(100)
              .borderRadius(50)
              .border({ width: 4, color: '#FFFFFF' })
              .shadow({
                radius: 20,
                color: 'rgba(0,0,0,0.2)',
                offsetX: 0,
                offsetY: 8
              })
          }
          .width(120)
          .height(120)
          .borderRadius(60)
          .backgroundColor('rgba(255,255,255,0.2)')
          .justifyContent(FlexAlign.Center)

          // 文字区域
          Column({ space: 8 }) {
            Text('欢迎使用')
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A1A')

            Text('登录后享受更多服务')
              .fontSize(15)
              .fontColor('#666666')
          }

          // 登录按钮
          Button('立即登录', { type: ButtonType.Normal, stateEffect: true })
            .width(200)
            .height(50)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .borderRadius(25)
            .linearGradient({
              angle: 90,
              colors: [['#667eea', 0], ['#764ba2', 1]]
            })
            .fontColor('#FFFFFF')
            .shadow({
              radius: 16,
              color: 'rgba(102,126,234,0.4)',
              offsetX: 0,
              offsetY: 6
            })
            .onClick(() => {
              this.navigateToLogin();
            })
        }
        .padding({ top: 80 })
      }
    }
    .width('100%')
    .height('100%')
  }

  // LoginInfoCard已移至ProfileHeader中

  @Builder
  SalesInfoCard() {
    Column({ space: 16 }) {
      // 标题
      Row() {
        Column()
          .width(4)
          .height(20)
          .borderRadius(2)
          .backgroundColor('#007DFF')
          .margin({ right: 10 })
        Text('销售数据')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
      }
      .width('100%')

      // 销售统计卡片
      Row({ space: 12 }) {
        // 销售额卡片
        Column({ space: 8 }) {
          Row() {
            Column()
              .width(36)
              .height(36)
              .borderRadius(18)
              .linearGradient({
                angle: 135,
                colors: [['#FF9500', 0], ['#FF6B00', 1]]
              })
              .justifyContent(FlexAlign.Center)
          }
          Text('¥' + this.salesStats.total_revenue.toFixed(2))
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FF6B00')
          Text('总销售额')
            .fontSize(13)
            .fontColor('#888888')
        }
        .layoutWeight(1)
        .padding(16)
        .backgroundColor('#FFFAF5')
        .borderRadius(16)
        .alignItems(HorizontalAlign.Center)

        // 销售数量卡片
        Column({ space: 8 }) {
          Row() {
            Column()
              .width(36)
              .height(36)
              .borderRadius(18)
              .linearGradient({
                angle: 135,
                colors: [['#007DFF', 0], ['#5856D6', 1]]
              })
              .justifyContent(FlexAlign.Center)
          }
          Text(this.salesStats.total_quantity.toString())
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#007DFF')
          Text('总销售数量')
            .fontSize(13)
            .fontColor('#888888')
        }
        .layoutWeight(1)
        .padding(16)
        .backgroundColor('#F5F8FF')
        .borderRadius(16)
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')

      // 热销菜品
      if (this.salesStats.top_dish) {
        Column({ space: 12 }) {
          Row() {
            Text('🔥')
              .fontSize(16)
            Text('热销菜品')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#666666')
              .margin({ left: 6 })
          }
          .width('100%')

          Row({ space: 14 }) {
            Image(this.getImagePath(this.salesStats.top_dish.image_url))
              .width(70)
              .height(70)
              .borderRadius(14)
              .objectFit(ImageFit.Cover)
              .shadow({
                radius: 8,
                color: 'rgba(0,0,0,0.1)',
                offsetX: 0,
                offsetY: 2
              })

            Column({ space: 6 }) {
              Text(this.salesStats.top_dish.name)
                .fontSize(17)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1A1A1A')

              Row({ space: 6 }) {
                Text('已售')
                  .fontSize(13)
                  .fontColor('#888888')
                Text(`${this.salesStats.top_dish.total_sold}`)
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#FF6B00')
                Text('份')
                  .fontSize(13)
                  .fontColor('#888888')
              }
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Column() {
              Text('TOP1')
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
            }
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .borderRadius(12)
            .linearGradient({
              angle: 90,
              colors: [['#FF6B6B', 0], ['#FF8E53', 1]]
            })
          }
          .width('100%')
          .padding(14)
          .backgroundColor('#FAFAFA')
          .borderRadius(14)
        }
      } else {
        Column({ space: 8 }) {
          Text('📊')
            .fontSize(32)
          Text('暂无销售数据')
            .fontSize(14)
            .fontColor('#999999')
        }
        .width('100%')
        .padding(24)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
    .padding(20)
    .backgroundColor('#FFFFFF')
    .margin({ top: 12, left: 16, right: 16 })
    .borderRadius(20)
    .shadow({
      radius: 16,
      color: 'rgba(0,0,0,0.05)',
      offsetX: 0,
      offsetY: 4
    })
  }

  @Builder
  MerchantToolsCard() {
    Column({ space: 16 }) {
      // 标题
      Row() {
        Column()
          .width(4)
          .height(20)
          .borderRadius(2)
          .backgroundColor('#34C759')
          .margin({ right: 10 })
        Text('经营工具')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
      }
      .width('100%')

      // 工具列表
      Column() {
        this.ToolListItem('桌号二维码', '生成桌贴，顾客扫码即进入点餐', () => {
          this.navigateToTableQRCode();
        })
      }
    }
    .width('100%')
    .padding(20)
    .backgroundColor('#FFFFFF')
    .margin({ top: 12, left: 16, right: 16 })
    .borderRadius(20)
    .shadow({
      radius: 16,
      color: 'rgba(0,0,0,0.05)',
      offsetX: 0,
      offsetY: 4
    })
  }

  @Builder
  ToolListItem(title: string, subtitle: string, action: () => void) {
    Row({ space: 14 }) {
      // 图标背景
      Column() {
        Image($r('app.media.qr_code'))
          .width(24)
          .height(24)
          .fillColor('#FFFFFF')
      }
      .width(48)
      .height(48)
      .borderRadius(14)
      .justifyContent(FlexAlign.Center)
      .linearGradient({
        angle: 135,
        colors: [['#34C759', 0], ['#30D158', 1]]
      })

      Column({ space: 4 }) {
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1A1A1A')
        Text(subtitle)
          .fontSize(13)
          .fontColor('#888888')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Image($r('app.media.arrow_right'))
        .width(18)
        .height(18)
        .fillColor('#C7C7CC')
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#F8F9FA')
    .borderRadius(14)
    .onClick(() => action())
  }

  @Builder
  CustomerModeCard() {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        Column() {
          Text('👤')
            .fontSize(20)
        }
        .width(40)
        .height(40)
        .borderRadius(20)
        .backgroundColor('rgba(0,125,255,0.1)')
        .justifyContent(FlexAlign.Center)

        Column({ space: 4 }) {
          Text('当前为顾客模式')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A1A')
          Text('部分商家经营能力已隐藏')
            .fontSize(13)
            .fontColor('#666666')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }

      Button('切换回商家端', { type: ButtonType.Normal, stateEffect: true })
        .width('100%')
        .height(42)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .borderRadius(21)
        .backgroundColor('#007DFF')
        .fontColor('#FFFFFF')
        .onClick(() => {
          this.switchToMerchantMode();
        })
    }
    .width('100%')
    .padding(20)
    .linearGradient({
      angle: 135,
      colors: [['#E8F4FF', 0], ['#F0F6FF', 1]]
    })
    .margin({ top: 12, left: 16, right: 16 })
    .borderRadius(20)
    .shadow({
      radius: 12,
      color: 'rgba(0,125,255,0.1)',
      offsetX: 0,
      offsetY: 4
    })
  }

  @Builder
  CustomerTableCard() {
    Column({ space: 14 }) {
      Row({ space: 12 }) {
        Column() {
          Text('🍽️')
            .fontSize(24)
        }
        .width(50)
        .height(50)
        .borderRadius(25)
        .backgroundColor('#FFF5E6')
        .justifyContent(FlexAlign.Center)

        Column({ space: 4 }) {
          Text('顾客桌台信息')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A1A')
          Text(this.currentTableId ? `正在为 ${this.currentTableId} 桌点餐` : '未绑定桌号')
            .fontSize(14)
            .fontColor(this.currentTableId ? '#34C759' : '#888888')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }

      if (!this.currentTableId) {
        Button('扫码进入餐桌', { type: ButtonType.Normal, stateEffect: true })
          .width('100%')
          .height(42)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .borderRadius(21)
          .backgroundColor('#FF9500')
          .fontColor('#FFFFFF')
          .onClick(() => {
            ToastUtils.showToast('请扫描桌号二维码进入顾客端');
          })
      }
    }
    .width('100%')
    .padding(20)
    .backgroundColor('#FFFFFF')
    .margin({ top: 12, left: 16, right: 16 })
    .borderRadius(20)
    .shadow({
      radius: 16,
      color: 'rgba(0,0,0,0.05)',
      offsetX: 0,
      offsetY: 4
    })
  }

  @Builder
  SettingsSection() {
    Column({ space: 16 }) {
      // 个人资料部分
      this.SettingsGroup('个人资料', '#5856D6', this.getProfileSettingsItems())

      // 社交功能部分
      this.SettingsGroup('社交功能', '#FF9500', this.getSocialSettingsItems())

      // 账号安全部分
      this.SettingsGroup('账号安全', '#FF3B30', this.getSecuritySettingsItems())
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: 20 })
  }

  @Builder
  SettingsGroup(title: string, color: string, items: SettingsItem[]) {
    Column({ space: 12 }) {
      // 分组标题
      Row() {
        Column()
          .width(4)
          .height(18)
          .borderRadius(2)
          .backgroundColor(color)
          .margin({ right: 10 })
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
      }
      .width('100%')
      .padding({ left: 4 })

      // 设置项列表
      Column() {
        ForEach(items, (item: SettingsItem, index: number) => {
          Column() {
            Row({ space: 12 }) {
              Text(item.icon)
                .fontSize(18)

              Text(item.title)
                .fontSize(15)
                .fontColor('#1A1A1A')
                .layoutWeight(1)

              if (item.showAvatar) {
                Image(this.getImagePath(this.userInfo.avatar) || $r('app.media.ic_user_avatar'))
                  .width(36)
                  .height(36)
                  .borderRadius(18)
                  .objectFit(ImageFit.Cover)
              } else {
                Text(item.value)
                  .fontSize(14)
                  .fontColor('#888888')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .constraintSize({ maxWidth: 150 })
              }

              Image($r('app.media.arrow_right'))
                .width(16)
                .height(16)
                .fillColor('#C7C7CC')
            }
            .width('100%')
            .padding({ top: 14, bottom: 14, left: 4, right: 4 })
            .onClick(() => item.action())

            if (index < items.length - 1) {
              Divider()
                .strokeWidth(0.5)
                .color('#F0F0F0')
                .margin({ left: 34 })
            }
          }
        }, (item: SettingsItem, index: number) => `${title}-${index}`)
      }
      .backgroundColor('#FFFFFF')
      .borderRadius(16)
      .padding({ left: 12, right: 12 })
      .shadow({
        radius: 12,
        color: 'rgba(0,0,0,0.04)',
        offsetX: 0,
        offsetY: 2
      })
    }
    .width('100%')
    .margin({ top: 8 })
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
      .backgroundColor('rgba(0,0,0,0.5)')
      .onClick(() => {
        this.showEditProfile = false;
      })

      // 对话框内容
      Column({ space: 20 }) {
        // 标题
        Row() {
          Text('✏️')
            .fontSize(22)
          Text('编辑个人资料')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A1A')
            .margin({ left: 8 })
        }

        // 昵称输入
        Column({ space: 8 }) {
          Text('昵称')
            .fontSize(14)
            .fontColor('#666666')
            .alignSelf(ItemAlign.Start)
          TextInput({ placeholder: '请输入昵称', text: this.editUsername })
            .width('100%')
            .height(48)
            .borderRadius(12)
            .backgroundColor('#F5F7FA')
            .onChange((value: string) => {
              this.editUsername = value;
            })
        }

        // 地址输入
        Column({ space: 8 }) {
          Text('地址')
            .fontSize(14)
            .fontColor('#666666')
            .alignSelf(ItemAlign.Start)
          TextInput({ placeholder: '请输入地址', text: this.editAddress })
            .width('100%')
            .height(48)
            .borderRadius(12)
            .backgroundColor('#F5F7FA')
            .onChange((value: string) => {
              this.editAddress = value;
            })
        }

        // 按钮
        Row({ space: 12 }) {
          Button('取消', { type: ButtonType.Normal, stateEffect: true })
            .layoutWeight(1)
            .height(48)
            .backgroundColor('#F5F5F5')
            .fontColor('#666666')
            .fontSize(16)
            .borderRadius(24)
            .onClick(() => {
              this.showEditProfile = false;
            })

          Button('保存', { type: ButtonType.Normal, stateEffect: true })
            .layoutWeight(1)
            .height(48)
            .backgroundColor('#007DFF')
            .fontColor('#FFFFFF')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .borderRadius(24)
            .onClick(() => {
              this.saveProfile();
            })
        }
        .width('100%')
      }
      .width('88%')
      .padding(24)
      .backgroundColor('#FFFFFF')
      .borderRadius(24)
      .shadow({
        radius: 30,
        color: 'rgba(0,0,0,0.15)',
        offsetX: 0,
        offsetY: 10
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
      .backgroundColor('rgba(0,0,0,0.5)')
      .onClick(() => {
        this.showEditPassword = false;
      })

      // 对话框内容
      Column({ space: 16 }) {
        // 标题
        Row() {
          Text('🔒')
            .fontSize(22)
          Text('修改密码')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A1A')
            .margin({ left: 8 })
        }

        // 原密码
        Column({ space: 8 }) {
          Text('原密码')
            .fontSize(14)
            .fontColor('#666666')
            .alignSelf(ItemAlign.Start)
          TextInput({ placeholder: '请输入原密码', text: this.oldPassword })
            .type(InputType.Password)
            .width('100%')
            .height(48)
            .borderRadius(12)
            .backgroundColor('#F5F7FA')
            .onChange((value: string) => {
              this.oldPassword = value;
            })
        }

        // 新密码
        Column({ space: 8 }) {
          Text('新密码')
            .fontSize(14)
            .fontColor('#666666')
            .alignSelf(ItemAlign.Start)
          TextInput({ placeholder: '请输入新密码', text: this.newPassword })
            .type(InputType.Password)
            .width('100%')
            .height(48)
            .borderRadius(12)
            .backgroundColor('#F5F7FA')
            .onChange((value: string) => {
              this.newPassword = value;
            })
        }

        // 确认密码
        Column({ space: 8 }) {
          Text('确认密码')
            .fontSize(14)
            .fontColor('#666666')
            .alignSelf(ItemAlign.Start)
          TextInput({ placeholder: '请确认新密码', text: this.confirmPassword })
            .type(InputType.Password)
            .width('100%')
            .height(48)
            .borderRadius(12)
            .backgroundColor('#F5F7FA')
            .onChange((value: string) => {
              this.confirmPassword = value;
            })
        }

        // 按钮
        Row({ space: 12 }) {
          Button('取消', { type: ButtonType.Normal, stateEffect: true })
            .layoutWeight(1)
            .height(48)
            .backgroundColor('#F5F5F5')
            .fontColor('#666666')
            .fontSize(16)
            .borderRadius(24)
            .onClick(() => {
              this.showEditPassword = false;
            })

          Button('保存', { type: ButtonType.Normal, stateEffect: true })
            .layoutWeight(1)
            .height(48)
            .backgroundColor('#007DFF')
            .fontColor('#FFFFFF')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .borderRadius(24)
            .onClick(() => {
              this.savePassword();
            })
        }
        .width('100%')
        .margin({ top: 8 })
      }
      .width('88%')
      .padding(24)
      .backgroundColor('#FFFFFF')
      .borderRadius(24)
      .shadow({
        radius: 30,
        color: 'rgba(0,0,0,0.15)',
        offsetX: 0,
        offsetY: 10
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
      .backgroundColor('rgba(0,0,0,0.5)')
      .onClick(() => {
        this.showEditEmail = false;
      })

      // 对话框内容
      Column({ space: 20 }) {
        // 标题
        Row() {
          Text('📧')
            .fontSize(22)
          Text('修改邮箱')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A1A')
            .margin({ left: 8 })
        }

        // 邮箱输入
        Column({ space: 8 }) {
          Text('新邮箱')
            .fontSize(14)
            .fontColor('#666666')
            .alignSelf(ItemAlign.Start)
          TextInput({ placeholder: '请输入新邮箱', text: this.editEmail })
            .width('100%')
            .height(48)
            .borderRadius(12)
            .backgroundColor('#F5F7FA')
            .onChange((value: string) => {
              this.editEmail = value;
            })
        }

        // 按钮
        Row({ space: 12 }) {
          Button('取消', { type: ButtonType.Normal, stateEffect: true })
            .layoutWeight(1)
            .height(48)
            .backgroundColor('#F5F5F5')
            .fontColor('#666666')
            .fontSize(16)
            .borderRadius(24)
            .onClick(() => {
              this.showEditEmail = false;
            })

          Button('保存', { type: ButtonType.Normal, stateEffect: true })
            .layoutWeight(1)
            .height(48)
            .backgroundColor('#007DFF')
            .fontColor('#FFFFFF')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .borderRadius(24)
            .onClick(() => {
              this.saveEmail();
            })
        }
        .width('100%')
      }
      .width('88%')
      .padding(24)
      .backgroundColor('#FFFFFF')
      .borderRadius(24)
      .shadow({
        radius: 30,
        color: 'rgba(0,0,0,0.15)',
        offsetX: 0,
        offsetY: 10
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
  logout(): void {
    AppStorage.setOrCreate('isLoggedIn', false);
    AppStorage.setOrCreate('userToken', '');
    AppStorage.setOrCreate('userInfo', '{}');
    AppStorage.setOrCreate('loginTimestamp', 0); // 清除登录时间戳
    this.isLoggedIn = false;
    this.userInfo = new UserInfo();
    this.salesStats = new SalesStats();
    ToastUtils.showToast('已退出登录');
  }

  // 获取个人资料设置项
  private getProfileSettingsItems(): SettingsItem[] {
    const items: SettingsItem[] = [];

    const avatarItem: SettingsItem = {
      icon: '📷',
      title: '头像',
      value: '',
      showAvatar: true,
      action: (): void => { this.changeAvatar(); }
    };
    items.push(avatarItem);

    const nicknameItem: SettingsItem = {
      icon: '✏️',
      title: '昵称',
      value: this.userInfo.username || '未设置',
      showAvatar: false,
      action: (): void => {
        this.editUsername = this.userInfo.username || '';
        this.editAddress = this.userInfo.address || '';
        this.showEditProfile = true;
      }
    };
    items.push(nicknameItem);

    const addressItem: SettingsItem = {
      icon: '📍',
      title: '地址',
      value: this.userInfo.address || '未设置',
      showAvatar: false,
      action: (): void => {
        this.editUsername = this.userInfo.username || '';
        this.editAddress = this.userInfo.address || '';
        this.showEditProfile = true;
      }
    };
    items.push(addressItem);

    return items;
  }

  // 获取社交功能设置项
  private getSocialSettingsItems(): SettingsItem[] {
    const items: SettingsItem[] = [];

    const followItem: SettingsItem = {
      icon: '❤️',
      title: '我的关注',
      value: '查看关注的用户',
      showAvatar: false,
      action: (): void => {
        router.pushUrl({ url: 'pages/MyFollowsPage' });
      }
    };
    items.push(followItem);

    return items;
  }

  // 获取账号安全设置项
  private getSecuritySettingsItems(): SettingsItem[] {
    const items: SettingsItem[] = [];

    const passwordItem: SettingsItem = {
      icon: '🔒',
      title: '密码',
      value: '修改密码',
      showAvatar: false,
      action: (): void => {
        this.oldPassword = '';
        this.newPassword = '';
        this.confirmPassword = '';
        this.showEditPassword = true;
      }
    };
    items.push(passwordItem);

    const emailItem: SettingsItem = {
      icon: '📧',
      title: '邮箱',
      value: this.userInfo.email || '未设置',
      showAvatar: false,
      action: (): void => {
        this.editEmail = this.userInfo.email || '';
        this.showEditEmail = true;
      }
    };
    items.push(emailItem);

    return items;
  }
}
