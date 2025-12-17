import router from '@ohos.router';
import http from '@ohos.net.http';
import preferences from '@ohos.data.preferences';
import promptAction from '@ohos.promptAction';
import { AppMode } from '../common/Types';
import { AppModeManager, ToastUtils, RouterUtils } from '../common/Utils';

@Entry
@Component
struct LoginPage {
  @State username: string = '';
  @State password: string = '';
  @State rememberMe: boolean = false;
  @State isLoading: boolean = false;
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
        `http://10.12.8.110:5000/api/Users/Login?username=${encodeURIComponent(this.username)}&password=${encodeURIComponent(this.password)}`;

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

  build() {
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


      Column({ space: 30 }) {
        // Logo和标题区域 - 向上调整
        Column({ space: 20 }) {
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
            Text('食光记——商家版')
              .fontSize(26)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A1A')
              .textAlign(TextAlign.Center)

            Text('Shop Management System')
              .fontSize(13)
              .fontColor('#666666')
              .opacity(0.8)
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .margin({ top: 20 })

        // 登录表单 - 调整到页面中间
        Column({ space: 20 }) {
          // 用户名输入框
          Column({ space: 6 }) {
            Text('用户名')
              .fontSize(14)
              .fontColor('#666666')
              .align(Alignment.Start)
              .width('100%')

            TextInput({ placeholder: '请输入您的用户名', text: this.username })
              .width('100%')
              .height(52)
              .backgroundColor('#FFFFFF')
              .borderRadius(14)
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

          // 密码输入框 - 使用系统默认的眼睛图标
          Column({ space: 6 }) {
            Text('密码')
              .fontSize(14)
              .fontColor('#666666')
              .align(Alignment.Start)
              .width('100%')

            TextInput({ placeholder: '请输入您的密码', text: this.password })
              .width('100%')
              .height(52)
              .backgroundColor('#FFFFFF')
              .borderRadius(14)
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
              // 自定义复选框
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
            .height(52)
            .backgroundColor(this.isLoading || !this.username || !this.password ? '#CCCCCC' : '#4F6BED')
            .fontColor(Color.White)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .borderRadius(14)
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
              .margin({ top: 12 })
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
          .margin({ top: 20 })
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .padding(28)
        .backgroundColor(Color.White)
        .borderRadius(20)
        .shadow({
          radius: 30,
          color: '#00000010',
          offsetX: 0,
          offsetY: 8
        })
        .margin({ top: 10 }) // 减少表单上方的间距
      }
      .width('100%')
      .padding({
        left: 24,
        right: 24
      })
      .layoutWeight(1) // 占据主要空间，实现居中
      .justifyContent(FlexAlign.Center) // 垂直居中

      // 底部装饰 - 减小尺寸
      Row() {
        Circle({ width: 80, height: 80 })
          .fill('#4F6BED')
          .opacity(0.05)
        Circle({ width: 50, height: 50 })
          .fill('#4F6BED')
          .opacity(0.1)
          .margin({ left: -20 })
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
      .margin({ bottom: -30, right: -20 })
    }
    .width('100%')
    .height('100%')
    .backgroundImage($r('app.media.login_bg'))
    .backgroundImageSize(ImageSize.Cover)
    .opacity(this.opacityValue)
    .animation({
      duration: 500,
      curve: Curve.EaseOut
    })
  }
}