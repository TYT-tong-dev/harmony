import router from '@ohos.router';
import http from '@ohos.net.http';
import preferences from '@ohos.data.preferences';
import promptAction from '@ohos.promptAction';
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
  authorizationCode?: string;
}

// 用户数据接口
interface UserData {
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
struct LoginPage {
  @State username: string = '';
  @State password: string = '';
  @State rememberMe: boolean = false;
  @State isLoading: boolean = false;
  @State isHuaweiLoading: boolean = false;
  @State opacityValue: number = 0;

  private prefs: preferences.Preferences | null = null;
  private readonly PREF_NAME: string = 'shop_login_prefs';
  private readonly KEY_USERNAME: string = 'username';
  private readonly KEY_PASSWORD: string = 'password';
  private readonly KEY_REMEMBER: string = 'remember_me';

  aboutToAppear() {
    this.opacityValue = 1;
    this.loadSavedCredentials();
    
    // 检查是否从扫码进入
    const params = router.getParams() as Record<string, Object> | undefined;
    const tableId = params?.['tableId'] as string | undefined;
    const fromScan = params?.['fromScan'] as boolean | undefined;
    
    if (tableId && fromScan) {
      // 从扫码进入，设置为顾客模式
      AppModeManager.setMode(AppMode.CUSTOMER, { tableId: tableId });
      AppStorage.setOrCreate('currentTableId', tableId);
    }
  }

  async loadSavedCredentials() {
    try {
      this.prefs = await preferences.getPreferences(getContext(this), this.PREF_NAME);
      const remember = await this.prefs.get(this.KEY_REMEMBER, false);
      if (remember) {
        this.rememberMe = true;
        this.username = (await this.prefs.get(this.KEY_USERNAME, '')) as string;
        this.password = (await this.prefs.get(this.KEY_PASSWORD, '')) as string;
      }
    } catch (error) {
      console.error('加载保存的凭据失败:', error);
    }
  }

  async saveCredentials() {
    if (!this.prefs) {
      return;
    }

    try {
      if (this.rememberMe) {
        await this.prefs.put(this.KEY_USERNAME, this.username);
        await this.prefs.put(this.KEY_PASSWORD, this.password);
        await this.prefs.put(this.KEY_REMEMBER, true);
      } else {
        await this.prefs.delete(this.KEY_USERNAME);
        await this.prefs.delete(this.KEY_PASSWORD);
        await this.prefs.put(this.KEY_REMEMBER, false);
      }
      await this.prefs.flush();
    } catch (error) {
      console.error('保存凭据失败:', error);
    }
  }

  async handleLogin() {
    if (!this.username || !this.password) {
      ToastUtils.showToast('请输入用户名和密码');
      return;
    }

    this.isLoading = true;

    try {
      const httpRequest = http.createHttp();
      const url =
        `http://10.52.131.181:5000/api/Users/Login?username=${encodeURIComponent(this.username)}&password=${encodeURIComponent(this.password)}`;

      const response = await httpRequest.request(
        url,
        {
          method: http.RequestMethod.GET,
          connectTimeout: 10000,
          readTimeout: 10000
        }
      );
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
          await this.saveCredentials();

          if (this.prefs) {
            await this.prefs.put('user_token', result.data.token);
            await this.prefs.put('user_info', JSON.stringify(result.data));
            await this.prefs.flush();
          }

          // 写入全局 AppStorage，供接口鉴权读取
          AppStorage.setOrCreate('userToken', result.data.token);
          AppStorage.setOrCreate('userInfo', JSON.stringify(result.data));
          AppStorage.setOrCreate('isLoggedIn', true);
          // 记录登录时间戳（用于7天有效期检查）
          AppStorage.setOrCreate('loginTimestamp', Date.now());

          // 检查当前模式，如果是顾客模式则保持，否则切换到商家模式
          const currentMode = AppStorage.get<AppMode>('appMode');
          if (currentMode !== AppMode.CUSTOMER) {
            AppModeManager.setMode(AppMode.MERCHANT, { silent: true });
          }
          
          ToastUtils.showToast('登录成功');

          // 延迟跳转，确保 Toast 显示完成
          setTimeout(async () => {
            try {
              console.log('准备跳转到 MainPage');
              RouterUtils.replaceUrl('pages/MainPage');
              console.log('跳转到 MainPage 成功');
            } catch (err) {
              console.error('跳转到 MainPage 失败:', JSON.stringify(err));
              // 如果 replaceUrl 失败，尝试使用 pushUrl
              try {
                await router.pushUrl({
                  url: 'pages/MainPage'
                });
                console.log('使用 pushUrl 跳转成功');
              } catch (pushErr) {
                console.error('pushUrl 也失败:', JSON.stringify(pushErr));
                promptAction.showToast({
                  message: '页面跳转失败，请重试',
                  duration: 2000
                });
              }
            }
          }, 1500);
        } else {
          ToastUtils.showToast(result.message || '登录失败');
        }
      } else {
        ToastUtils.showToast('网络请求失败，请检查网络连接');
      }
    } catch (error) {
      console.error('登录请求错误:', error);
      ToastUtils.showToast('网络连接错误，请稍后重试');
    } finally {
      this.isLoading = false;
    }
  }

  // 华为账号登录
  async handleHuaweiLogin() {
    this.isHuaweiLoading = true;

    try {
      hilog.info(DOMAIN, 'HuaweiLogin', '开始华为账号登录');

      const loginRequest = new authentication.HuaweiIDProvider().createLoginWithHuaweiIDRequest();
      loginRequest.forceLogin = false;
      loginRequest.state = 'customer_login_' + Date.now();

      const controller = new authentication.AuthenticationController(getContext(this));
      const response = await controller.executeRequest(loginRequest);

      hilog.info(DOMAIN, 'HuaweiLogin', '华为登录响应: %{public}s', JSON.stringify(response));

      const loginResponse = response as authentication.LoginWithHuaweiIDResponse;

      if (loginResponse.data) {
        const authData = loginResponse.data;

        const huaweiUser: HuaweiUserInfo = {
          openID: authData.openID || '',
          unionID: authData.unionID || '',
          displayName: '华为用户',
          avatarUri: '',
          authorizationCode: authData.authorizationCode
        };

        if (huaweiUser.authorizationCode) {
          await this.exchangeHuaweiToken(huaweiUser);
        } else {
          this.handleHuaweiLoginSuccess(huaweiUser);
        }
      } else {
        ToastUtils.showToast('华为账号登录失败');
      }
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(DOMAIN, 'HuaweiLogin', '华为登录失败: code=%{public}d, message=%{public}s',
        err.code, err.message);

      if (err.code === 1001502001) {
        ToastUtils.showToast('已取消登录');
      } else if (err.code === 1001500001) {
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
      const response = await httpRequest.request(
        'http://10.52.131.181:5000/api/Users/HuaweiLogin',
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
          const userData: UserData = {
            id: result.data.id,
            name: huaweiUser.displayName,
            type: 'customer',
            avatar: huaweiUser.avatarUri,
            token: result.data.token,
            huaweiOpenID: huaweiUser.openID,
            huaweiUnionID: ''
          };
          this.saveHuaweiLoginState(result.data.token, userData);
          ToastUtils.showToast('华为账号登录成功');
          this.navigateToMain();
        } else {
          this.handleHuaweiLoginSuccess(huaweiUser);
        }
      } else {
        this.handleHuaweiLoginSuccess(huaweiUser);
      }
    } catch (error) {
      hilog.error(DOMAIN, 'HuaweiLogin', '后端验证失败，使用本地模式');
      this.handleHuaweiLoginSuccess(huaweiUser);
    }
  }

  // 华为登录成功处理（本地模式）
  private handleHuaweiLoginSuccess(huaweiUser: HuaweiUserInfo): void {
    const localToken = 'huawei_' + huaweiUser.openID + '_' + Date.now();

    const userData: UserData = {
      id: 0,
      name: huaweiUser.displayName,
      type: 'customer',
      avatar: huaweiUser.avatarUri,
      token: localToken,
      huaweiOpenID: huaweiUser.openID,
      huaweiUnionID: huaweiUser.unionID
    };

    this.saveHuaweiLoginState(localToken, userData);
    ToastUtils.showToast('华为账号登录成功');
    this.navigateToMain();
  }

  // 保存华为登录状态
  private saveHuaweiLoginState(token: string, userData: UserData): void {
    AppStorage.setOrCreate('userToken', token);
    AppStorage.setOrCreate('userInfo', JSON.stringify(userData));
    AppStorage.setOrCreate('isLoggedIn', true);
    AppStorage.setOrCreate('loginTimestamp', Date.now());
    AppModeManager.setMode(AppMode.CUSTOMER, { silent: true });
  }

  // 跳转到主页
  private navigateToMain(): void {
    setTimeout(() => {
      RouterUtils.replaceUrl('pages/MainPage');
    }, 1000);
  }

  build() {
    Scroll() {
      Column() {
        // 顶部装饰性元素 - 减小尺寸和间距
        Row() {
          Circle({ width: 60, height: 60 })
            .fill('#4F6BED')
            .opacity(0.1)
          Circle({ width: 90, height: 90 })
            .fill('#4F6BED')
            .opacity(0.05)
            .margin({ left: -30 })
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .margin({ top: -30, left: -30 })


        Column({ space: 24 }) {
          // Logo和标题区域
          Column({ space: 16 }) {
            // Logo容器带渐变背景
            Stack() {
              Circle({ width: 100, height: 100 })
                .fill('#4F6BED')
                .opacity(0.1)

              Image($r('app.media.ic_shop'))
                .width(70)
                .height(70)
                .objectFit(ImageFit.Contain)
                .margin(15)
            }
            .width(100)
            .height(100)

            Column({ space: 6 }) {
              Text('食光记')
                .fontSize(26)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1A1A1A')
                .textAlign(TextAlign.Center)

              Text('Shiguangji')
                .fontSize(13)
                .fontColor('#666666')
                .opacity(0.8)
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .margin({ top: 10 })

          // 登录表单
          Column({ space: 16 }) {
            // 用户名输入框
            Column({ space: 6 }) {
              Text('用户名')
                .fontSize(14)
                .fontColor('#666666')
                .align(Alignment.Start)
                .width('100%')

              TextInput({ placeholder: '请输入您的用户名', text: this.username })
                .width('100%')
                .height(50)
                .backgroundColor('#FFFFFF')
                .borderRadius(12)
                .padding({ left: 16, right: 16 })
                .fontSize(16)
                .fontColor('#1A1A1A')
                .border({
                  width: 1,
                  color: this.username ? '#4F6BED' : '#E8E8E8'
                })
                .onChange((value: string) => {
                  this.username = value;
                })
            }
            .width('100%')

            // 密码输入框
            Column({ space: 6 }) {
              Text('密码')
                .fontSize(14)
                .fontColor('#666666')
                .align(Alignment.Start)
                .width('100%')

              TextInput({ placeholder: '请输入您的密码', text: this.password })
                .width('100%')
                .height(50)
                .backgroundColor('#FFFFFF')
                .borderRadius(12)
                .padding({ left: 16, right: 16 })
                .fontSize(16)
                .fontColor('#1A1A1A')
                .type(InputType.Password)
                .border({
                  width: 1,
                  color: this.password ? '#4F6BED' : '#E8E8E8'
                })
                .onChange((value: string) => {
                  this.password = value;
                })
            }
            .width('100%')

            // 记住我和忘记密码
            Row() {
              Row({ space: 10 }) {
                Stack() {
                  if (this.rememberMe) {
                    Circle({ width: 18, height: 18 })
                      .fill('#4F6BED')

                    Image($r('app.media.d'))
                      .width(10)
                      .height(10)
                      .fillColor(Color.White)
                  } else {
                    Circle({ width: 18, height: 18 })
                      .fill(Color.White)
                      .strokeWidth(2)
                      .stroke('#DDDDDD')
                  }
                }
                .onClick(() => {
                  this.rememberMe = !this.rememberMe;
                })

                Text('记住我')
                  .fontSize(13)
                  .fontColor('#666666')
              }
              .onClick(() => {
                this.rememberMe = !this.rememberMe;
              })

              Blank()

              Text('忘记密码？')
                .fontSize(13)
                .fontColor('#4F6BED')
                .fontWeight(FontWeight.Medium)
                .onClick(() => {
                  router.pushUrl({
                    url: 'pages/ForgotPasswordPage'
                  });
                })
            }
            .width('100%')
            .height(36)

            // 登录按钮
            Button('登录', { type: ButtonType.Normal })
              .width('100%')
              .height(50)
              .backgroundColor(this.isLoading || !this.username || !this.password ? '#CCCCCC' : '#4F6BED')
              .fontColor(Color.White)
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .borderRadius(12)
              .enabled(!this.isLoading && !!this.username && !!this.password)
              .stateEffect(!this.isLoading && !!this.username && !!this.password)
              .onClick(() => {
                this.handleLogin();
              })

            // 加载指示器
            if (this.isLoading) {
              LoadingProgress()
                .width(28)
                .height(28)
                .color(Color.White)
                .margin({ top: 8 })
            }

            // 注册链接
            Row({ space: 4 }) {
              Text('还没有账号？')
                .fontSize(13)
                .fontColor('#999999')

              Text('立即注册')
                .fontSize(13)
                .fontColor('#4F6BED')
                .fontWeight(FontWeight.Medium)
                .onClick(() => {
                  router.pushUrl({
                    url: 'pages/RegisterPage'
                  });
                })
            }
            .margin({ top: 12 })
            .width('100%')
            .justifyContent(FlexAlign.Center)
          }
          .width('100%')
          .padding(24)
          .backgroundColor(Color.White)
          .borderRadius(20)
          .shadow({
            radius: 20,
            color: '#00000010',
            offsetX: 0,
            offsetY: 6
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
        }
        .width('100%')
        .padding({
          left: 24,
          right: 24,
          bottom: 40
        })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .backgroundImage($r('app.media.login_bg'))
    .backgroundImageSize(ImageSize.Cover)
    .opacity(this.opacityValue)
    .animation({
      duration: 500,
      curve: Curve.EaseOut
    })
  }
}