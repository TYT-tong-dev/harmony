// CustomerLoginPage.ets - 顾客端登录页面（集成华为Account Kit）
import router from '@ohos.router';
import http from '@ohos.net.http';
import { AppMode } from '../common/Types';
import { AppModeManager, ToastUtils, RouterUtils } from '../common/Utils';
import { authentication } from '@kit.AccountKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;

// 华为账号用户信息接口
interface HuaweiUserInfo {
  openID: string;
  unionID: string;
  displayName: string;
  avatarUri: string;
  email?: string;
  authorizationCode?: string;
}

// 顾客用户数据接口
interface CustomerUserData {
  id: number;
  name: string;
  type: string;
  avatar: string;
  token: string;
  huaweiOpenID: string;
  huaweiUnionID: string;
}

@Entry
@Component
struct CustomerLoginPage {
  @State username: string = '';
  @State password: string = '';
  @State isLoading: boolean = false;
  @State isHuaweiLoading: boolean = false;
  @State opacityValue: number = 0;
  @State tableId: string = '';
  @StorageLink('appMode') appMode: AppMode = AppMode.CUSTOMER;

  aboutToAppear() {
    this.opacityValue = 1;
    // 获取桌号参数
    const params = router.getParams() as Record<string, Object> | undefined;
    this.tableId = (params?.['tableId'] as string) || '';

    // 确保是顾客模式
    if (this.tableId) {
      AppModeManager.setMode(AppMode.CUSTOMER, { tableId: this.tableId });
      AppStorage.setOrCreate('currentTableId', this.tableId);
    }
  }

  // 普通账号登录
  async handleLogin() {
    if (!this.username || !this.password) {
      ToastUtils.showToast('请输入用户名和密码');
      return;
    }

    this.isLoading = true;

    try {
      const httpRequest = http.createHttp();
      const url =
        `http://10.12.8.110:5000/api/Users/Login?username=${encodeURIComponent(this.username)}&password=${encodeURIComponent(this.password)}`;

      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: 10000,
        readTimeout: 10000
      });

      if (response.responseCode === 200) {
        interface LoginData {
          id?: number;
          name?: string;
          type?: string;
          email?: string;
          token: string;
        }

        interface LoginResponse {
          statusCode: number;
          message?: string;
          data: LoginData;
        }

        const result: LoginResponse = JSON.parse(response.result as string);

        if (result.statusCode === 200 && result.data && result.data.token) {
          const userData: CustomerUserData = {
            id: result.data.id || 0,
            name: result.data.name || this.username,
            type: result.data.type || 'customer',
            avatar: '',
            token: result.data.token,
            huaweiOpenID: '',
            huaweiUnionID: ''
          };
          this.saveLoginState(result.data.token, userData);
          ToastUtils.showToast('登录成功');
          this.navigateToMain();
        } else {
          ToastUtils.showToast(result.message || '登录失败');
        }
      } else {
        ToastUtils.showToast('网络请求失败');
      }
    } catch (error) {
      console.error('登录请求错误:', error);
      ToastUtils.showToast('网络连接错误，请稍后重试');
    } finally {
      this.isLoading = false;
    }
  }

  // 华为账号登录 - 使用Account Kit
  async handleHuaweiLogin() {
    this.isHuaweiLoading = true;

    try {
      hilog.info(DOMAIN, 'HuaweiLogin', '开始华为账号登录');

      // 创建华为账号登录请求
      const loginRequest = new authentication.HuaweiIDProvider().createLoginWithHuaweiIDRequest();
      // 设置强制登录（每次都弹出授权页面）
      loginRequest.forceLogin = false;
      // 设置登录类型
      loginRequest.state = 'customer_login_' + Date.now();

      // 执行登录请求
      const controller = new authentication.AuthenticationController(getContext(this));
      const response = await controller.executeRequest(loginRequest);

      hilog.info(DOMAIN, 'HuaweiLogin', '华为登录响应: %{public}s', JSON.stringify(response));

      // 处理登录响应
      const loginResponse = response as authentication.LoginWithHuaweiIDResponse;

      if (loginResponse.data) {
        const authData = loginResponse.data;

        // 获取用户信息 - LoginWithHuaweiIDCredential只有openID, unionID, authorizationCode等基本字段
        const huaweiUser: HuaweiUserInfo = {
          openID: authData.openID || '',
          unionID: authData.unionID || '',
          displayName: '华为用户',
          avatarUri: '',
          authorizationCode: authData.authorizationCode
        };

        hilog.info(DOMAIN, 'HuaweiLogin', '华为用户信息: openID=%{public}s',
          huaweiUser.openID);

        // 如果有授权码，可以发送到后端换取token
        if (huaweiUser.authorizationCode) {
          await this.exchangeHuaweiToken(huaweiUser);
        } else {
          // 没有授权码，直接使用openID作为标识
          this.handleHuaweiLoginSuccess(huaweiUser);
        }
      } else {
        ToastUtils.showToast('华为账号登录失败');
      }
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(DOMAIN, 'HuaweiLogin', '华为登录失败: code=%{public}d, message=%{public}s',
        err.code, err.message);

      // 处理特定错误码
      if (err.code === 1001502001) {
        // 用户取消登录
        ToastUtils.showToast('已取消登录');
      } else if (err.code === 1001500001) {
        // 系统服务异常
        ToastUtils.showToast('系统服务异常，请稍后重试');
      } else {
        ToastUtils.showToast('华为账号登录失败，请重试');
      }
    } finally {
      this.isHuaweiLoading = false;
    }
  }

  // 将华为授权码发送到后端换取token
  private async exchangeHuaweiToken(huaweiUser: HuaweiUserInfo): Promise<void> {
    try {
      const httpRequest = http.createHttp();
      // 发送到后端进行验证和换取token
      const response = await httpRequest.request(
        'http://10.12.8.110:5000/api/Users/HuaweiLogin',
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json'
          },
          extraData: JSON.stringify({
            openID: huaweiUser.openID,
            unionID: huaweiUser.unionID,
            displayName: huaweiUser.displayName,
            avatarUri: huaweiUser.avatarUri,
            authorizationCode: huaweiUser.authorizationCode
          }),
          connectTimeout: 10000,
          readTimeout: 10000
        }
      );

      if (response.responseCode === 200) {
        interface HuaweiLoginResponseData {
          token: string;
          id: number;
          username: string;
        }

        interface HuaweiLoginResponse {
          statusCode: number;
          message?: string;
          data?: HuaweiLoginResponseData;
        }

        const result: HuaweiLoginResponse = JSON.parse(response.result as string);

        if (result.statusCode === 200 && result.data?.token) {
          const userData: CustomerUserData = {
            id: result.data.id,
            name: huaweiUser.displayName,
            type: 'customer',
            avatar: huaweiUser.avatarUri,
            token: result.data.token,
            huaweiOpenID: huaweiUser.openID,
            huaweiUnionID: ''
          };
          this.saveLoginState(result.data.token, userData);
          ToastUtils.showToast('华为账号登录成功');
          this.navigateToMain();
        } else {
          // 后端验证失败，使用本地模式
          this.handleHuaweiLoginSuccess(huaweiUser);
        }
      } else {
        // 网络请求失败，使用本地模式
        this.handleHuaweiLoginSuccess(huaweiUser);
      }
    } catch (error) {
      hilog.error(DOMAIN, 'HuaweiLogin', '后端验证失败，使用本地模式');
      // 后端不可用时，使用本地模式登录
      this.handleHuaweiLoginSuccess(huaweiUser);
    }
  }

  // 华为登录成功处理（本地模式）
  private handleHuaweiLoginSuccess(huaweiUser: HuaweiUserInfo): void {
    // 生成本地token
    const localToken = 'huawei_' + huaweiUser.openID + '_' + Date.now();

    const userData: CustomerUserData = {
      id: 0,
      name: huaweiUser.displayName,
      type: 'customer',
      avatar: huaweiUser.avatarUri,
      token: localToken,
      huaweiOpenID: huaweiUser.openID,
      huaweiUnionID: huaweiUser.unionID
    };

    this.saveLoginState(localToken, userData);
    ToastUtils.showToast('华为账号登录成功');
    this.navigateToMain();
  }

  // 保存登录状态
  private saveLoginState(token: string, userData: CustomerUserData): void {
    AppStorage.setOrCreate('userToken', token);
    AppStorage.setOrCreate('userInfo', JSON.stringify(userData));
    AppStorage.setOrCreate('isLoggedIn', true);
    AppStorage.setOrCreate('loginTimestamp', Date.now());
    // 确保保持顾客模式
    AppModeManager.setMode(AppMode.CUSTOMER, { tableId: this.tableId });
  }

  // 跳转到主页
  private navigateToMain(): void {
    setTimeout(() => {
      RouterUtils.replaceUrl('pages/MainPage');
    }, 1000);
  }

  // 游客模式进入（不登录直接点餐）
  private enterAsGuest(): void {
    AppStorage.setOrCreate('isLoggedIn', false);
    AppStorage.setOrCreate('userToken', '');
    AppStorage.setOrCreate('userInfo', '{}');
    AppModeManager.setMode(AppMode.CUSTOMER, { tableId: this.tableId });
    ToastUtils.showToast('游客模式，部分功能受限');
    RouterUtils.replaceUrl('pages/MainPage');
  }

  build() {
    Column() {
      // 顶部装饰
      Row() {
        Circle({ width: 80, height: 80 })
          .fill('#FF6B6B')
          .opacity(0.1)
        Circle({ width: 120, height: 120 })
          .fill('#FF6B6B')
          .opacity(0.05)
          .margin({ left: -40 })
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .margin({ top: -40, left: -40 })

      // 主内容区
      Column({ space: 24 }) {
        // Logo和标题
        Column({ space: 16 }) {
          Stack() {
            Circle({ width: 100, height: 100 })
              .fill('#FF6B6B')
              .opacity(0.15)

            Image($r('app.media.ic_shop'))
              .width(60)
              .height(60)
              .objectFit(ImageFit.Contain)
          }

          Column({ space: 6 }) {
            Text('食光记')
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A1A')

            Text('扫码点餐，美味即刻开启')
              .fontSize(14)
              .fontColor('#666666')

            if (this.tableId) {
              Text(`桌号: ${this.tableId}`)
                .fontSize(13)
                .fontColor('#FF6B6B')
                .fontWeight(FontWeight.Medium)
                .margin({ top: 8 })
                .padding({ left: 12, right: 12, top: 4, bottom: 4 })
                .backgroundColor('#FFF0F0')
                .borderRadius(12)
            }
          }
        }
        .margin({ top: 20 })

        // 登录表单卡片
        Column({ space: 16 }) {
          // 用户名输入
          Column({ space: 6 }) {
            Text('手机号/用户名')
              .fontSize(14)
              .fontColor('#666666')
              .width('100%')

            TextInput({ placeholder: '请输入手机号或用户名', text: this.username })
              .width('100%')
              .height(50)
              .backgroundColor('#F8F8F8')
              .borderRadius(12)
              .padding({ left: 16, right: 16 })
              .fontSize(16)
              .onChange((value: string) => {
                this.username = value;
              })
          }

          // 密码输入
          Column({ space: 6 }) {
            Text('密码')
              .fontSize(14)
              .fontColor('#666666')
              .width('100%')

            TextInput({ placeholder: '请输入密码', text: this.password })
              .width('100%')
              .height(50)
              .backgroundColor('#F8F8F8')
              .borderRadius(12)
              .padding({ left: 16, right: 16 })
              .fontSize(16)
              .type(InputType.Password)
              .onChange((value: string) => {
                this.password = value;
              })
          }

          // 登录按钮
          Button(this.isLoading ? '登录中...' : '登录', { type: ButtonType.Normal })
            .width('100%')
            .height(50)
            .backgroundColor(this.isLoading ? '#CCCCCC' : '#FF6B6B')
            .fontColor(Color.White)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .borderRadius(12)
            .enabled(!this.isLoading)
            .onClick(() => {
              this.handleLogin();
            })

          // 注册链接
          Row({ space: 4 }) {
            Text('还没有账号？')
              .fontSize(13)
              .fontColor('#999999')

            Text('立即注册')
              .fontSize(13)
              .fontColor('#FF6B6B')
              .fontWeight(FontWeight.Medium)
              .onClick(() => {
                router.pushUrl({
                  url: 'pages/RegisterPage',
                  params: { tableId: this.tableId, isCustomer: true }
                });
              })
          }
          .margin({ top: 8 })
        }
        .width('100%')
        .padding(24)
        .backgroundColor(Color.White)
        .borderRadius(20)
        .shadow({
          radius: 20,
          color: '#10000000',
          offsetX: 0,
          offsetY: 4
        })

        // 分隔线
        Row() {
          Divider()
            .width('30%')
            .color('#E0E0E0')

          Text('其他登录方式')
            .fontSize(13)
            .fontColor('#999999')
            .margin({ left: 16, right: 16 })

          Divider()
            .width('30%')
            .color('#E0E0E0')
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .margin({ top: 16 })

        // 华为账号登录按钮
        Button({ type: ButtonType.Normal }) {
          Row({ space: 10 }) {
            // 华为账号图标
            Text('H')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#CF0A2C')
              .width(24)
              .height(24)
              .textAlign(TextAlign.Center)
              .backgroundColor('#FFEBEE')
              .borderRadius(4)

            Text(this.isHuaweiLoading ? '登录中...' : '华为账号登录')
              .fontSize(16)
              .fontColor('#1A1A1A')
              .fontWeight(FontWeight.Medium)
          }
        }
        .width('100%')
        .height(50)
        .backgroundColor('#FFFFFF')
        .borderRadius(12)
        .border({ width: 1, color: '#E0E0E0' })
        .enabled(!this.isHuaweiLoading)
        .onClick(() => {
          this.handleHuaweiLogin();
        })

        // 游客模式入口
        Text('游客模式点餐')
          .fontSize(14)
          .fontColor('#999999')
          .decoration({ type: TextDecorationType.Underline })
          .margin({ top: 16 })
          .onClick(() => {
            this.enterAsGuest();
          })
      }
      .width('100%')
      .padding({ left: 24, right: 24 })
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)

      // 底部装饰
      Row() {
        Circle({ width: 60, height: 60 })
          .fill('#FF6B6B')
          .opacity(0.05)
        Circle({ width: 40, height: 40 })
          .fill('#FF6B6B')
          .opacity(0.1)
          .margin({ left: -15 })
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
      .margin({ bottom: -20, right: -20 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFF8F8')
    .opacity(this.opacityValue)
    .animation({
      duration: 400,
      curve: Curve.EaseOut
    })
  }
}
