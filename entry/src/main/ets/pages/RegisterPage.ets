import router from '@ohos.router';
import http from '@ohos.net.http';
import promptAction from '@ohos.promptAction';

interface ApiResponse {
  statusCode: number;
  message?: string;
}

@Entry
@Component
struct RegisterPage {
  @State username: string = '';
  @State password: string = '';
  @State confirmPassword: string = '';
  @State email: string = '';
  @State isLoading: boolean = false;
  @State opacityValue: number = 0;

  aboutToAppear() {
    this.opacityValue = 1;
  }

  async handleRegister() {
    if (!this.username || !this.password || !this.confirmPassword || !this.email) {
      promptAction.showToast({
        message: '请填写所有字段',
        duration: 2000
      });
      return;
    }

    if (this.password !== this.confirmPassword) {
      promptAction.showToast({
        message: '两次输入的密码不一致',
        duration: 2000
      });
      return;
    }

    // 邮箱格式验证
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(this.email)) {
      promptAction.showToast({
        message: '请输入有效的邮箱地址',
        duration: 2000
      });
      return;
    }

    this.isLoading = true;

    try {
      const httpRequest = http.createHttp();
      const response = await httpRequest.request(
        'http://10.12.8.110:5000/api/Users/Register',
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json'
          },
          extraData: JSON.stringify({
            username: this.username,
            password: this.password,
            email: this.email
          }),
          connectTimeout: 10000,
          readTimeout: 10000
        }
      );
      if (response.responseCode === 200) {
        const result: ApiResponse = JSON.parse(response.result as string);

        if (result.statusCode === 200) {
          promptAction.showToast({
            message: '注册成功',
            duration: 2000
          });

          setTimeout(() => {
            router.back();
          }, 1500);
        } else {
          promptAction.showToast({
            message: result.message || '注册失败',
            duration: 3000
          });
        }
      } else {
        promptAction.showToast({
          message: '网络请求失败',
          duration: 3000
        });
      }
    } catch (error) {
      console.error('注册请求错误:', error);
      promptAction.showToast({
        message: '网络连接错误',
        duration: 3000
      });
    } finally {
      this.isLoading = false;
    }
  }

  build() {
    Column() {
      // 头部导航 - 调整到更靠上位置
      Row() {
        // 返回按钮
        Stack() {
          Circle({ width: 40, height: 40 })
            .fill('#F8F9FA')

          Image($r('app.media.back_icon'))
            .width(20)
            .height(20)
            .fillColor('#333333')
        }
        .onClick(() => {
          router.back();
        })

        Text('用户注册')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
          .margin({ left: 16 })

        Blank()
      }
      .width('100%')
      .padding({
        left: 24,
        right: 24,
        top: 40, // 减少顶部间距，让导航更靠上
        bottom: 20
      })

      Scroll() {
        Column({ space: 24 }) {
          // 欢迎文本
          Column({ space: 8 }) {
            Text('创建账号')
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A1A')
              .textAlign(TextAlign.Start)
              .width('100%')

            Text('加入商家扫码点单系统')
              .fontSize(16)
              .fontColor('#666666')
              .textAlign(TextAlign.Start)
              .width('100%')
          }

          // 注册表单 - 调整到页面中间
          Column({ space: 20 }) {
            // 用户名
            Column({ space: 8 }) {
              Text('用户名')
                .fontSize(14)
                .fontColor('#666666')
                .align(Alignment.Start)
                .width('100%')

              TextInput({ placeholder: '设置您的用户名', text: this.username })
                .width('100%')
                .height(56)
                .backgroundColor('#FFFFFF')
                .borderRadius(16)
                .padding({ left: 20, right: 20 })
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

            // 邮箱
            Column({ space: 8 }) {
              Text('邮箱')
                .fontSize(14)
                .fontColor('#666666')
                .align(Alignment.Start)
                .width('100%')

              TextInput({ placeholder: '输入您的邮箱地址', text: this.email })
                .width('100%')
                .height(56)
                .backgroundColor('#FFFFFF')
                .borderRadius(16)
                .padding({ left: 20, right: 20 })
                .fontSize(16)
                .fontColor('#1A1A1A')
                .border({
                  width: 1,
                  color: this.email ? '#4F6BED' : '#E8E8E8'
                })
                .onChange((value: string) => {
                  this.email = value;
                })
            }

            // 密码 - 使用系统默认的眼睛图标
            Column({ space: 8 }) {
              Text('密码')
                .fontSize(14)
                .fontColor('#666666')
                .align(Alignment.Start)
                .width('100%')

              TextInput({ placeholder: '设置登录密码', text: this.password })
                .width('100%')
                .height(56)
                .backgroundColor('#FFFFFF')
                .borderRadius(16)
                .padding({ left: 20, right: 20 })
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

              // 密码强度指示器
              if (this.password) {
                Row({ space: 4 }) {
                  ForEach([1, 2, 3], (index: number) => {
                    Rect()
                      .width((this.getPasswordStrength() >= index) ? 32 : 16)
                      .height(4)
                      .fill(this.getPasswordStrengthColor())
                      .borderRadius(2)
                  })
                }
                .width('100%')
                .margin({ top: 8 })

                Text(this.getPasswordStrengthText())
                  .fontSize(12)
                  .fontColor(this.getPasswordStrengthColor())
                  .width('100%')
                  .textAlign(TextAlign.Start)
                  .margin({ top: 4 })
              }
            }

            // 确认密码 - 使用系统默认的眼睛图标
            Column({ space: 8 }) {
              Text('确认密码')
                .fontSize(14)
                .fontColor('#666666')
                .align(Alignment.Start)
                .width('100%')

              TextInput({ placeholder: '再次输入密码', text: this.confirmPassword })
                .width('100%')
                .height(56)
                .backgroundColor('#FFFFFF')
                .borderRadius(16)
                .padding({ left: 20, right: 20 })
                .fontSize(16)
                .fontColor('#1A1A1A')
                .type(InputType.Password)
                .border({
                  width: 1,
                  color: this.confirmPassword ?
                    (this.password === this.confirmPassword ? '#52C41A' : '#FF4D4F') : '#E8E8E8'
                })
                .onChange((value: string) => {
                  this.confirmPassword = value;
                })

              // 密码匹配提示
              if (this.confirmPassword && this.password !== this.confirmPassword) {
                Text('两次输入的密码不一致')
                  .fontSize(12)
                  .fontColor('#FF4D4F')
                  .width('100%')
                  .textAlign(TextAlign.Start)
                  .margin({ top: 4 })
              }
            }

            // 注册按钮
            Button('注册账号', { type: ButtonType.Normal })
              .width('100%')
              .height(56)
              .backgroundColor(this.isLoading || !this.username || !this.password || !this.confirmPassword ||
                !this.email ? '#CCCCCC' : '#4F6BED')
              .fontColor(Color.White)
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .borderRadius(16)
              .enabled(!this.isLoading && !!this.username && !!this.password && !!this.confirmPassword && !!this.email)
              .stateEffect(!this.isLoading && !!this.username && !!this.password && !!this.confirmPassword &&
                !!this.email)
              .onClick(() => {
                this.handleRegister();
              })

            if (this.isLoading) {
              LoadingProgress()
                .width(32)
                .height(32)
                .color(Color.White)
                .margin({ top: 16 })
            }

            // 服务条款
            Row({ space: 4 }) {
              Text('注册即表示同意')
                .fontSize(12)
                .fontColor('#999999')

              Text('服务条款')
                .fontSize(12)
                .fontColor('#4F6BED')
                .fontWeight(FontWeight.Medium)

              Text('和')
                .fontSize(12)
                .fontColor('#999999')

              Text('隐私政策')
                .fontSize(12)
                .fontColor('#4F6BED')
                .fontWeight(FontWeight.Medium)
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .margin({ top: 16 })
          }
          .width('100%')
          .padding(24)
          .backgroundColor(Color.White)
          .borderRadius(24)
          .shadow({
            radius: 40,
            color: '#00000010',
            offsetX: 0,
            offsetY: 10
          })
          .layoutWeight(1) // 让表单区域占据剩余空间
        }
        .width('100%')
        .height('100%')
        .padding({ left: 24, right: 24, bottom: 40 })
      }
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8F9FA')
    .opacity(this.opacityValue)
    .animation({
      duration: 500,
      curve: Curve.EaseOut
    })
  }

  // 密码强度评估
  getPasswordStrength(): number {
    if (!this.password) {
      return 0;
    }

    let strength = 0;
    if (this.password.length >= 6) {
      strength++;
    }
    if (this.password.length >= 8) {
      strength++;
    }
    if (/\d/.test(this.password) && /[a-zA-Z]/.test(this.password)) {
      strength++;
    }

    return Math.min(strength, 3);
  }

  getPasswordStrengthText(): string {
    const strength = this.getPasswordStrength();
    switch (strength) {
      case 0:
        return '密码强度：弱';
      case 1:
        return '密码强度：中';
      case 2:
        return '密码强度：强';
      case 3:
        return '密码强度：很强';
      default:
        return '';
    }
  }

  getPasswordStrengthColor(): string {
    const strength = this.getPasswordStrength();
    switch (strength) {
      case 0:
        return '#FF4D4F';
      case 1:
        return '#FAAD14';
      case 2:
        return '#52C41A';
      case 3:
        return '#1890FF';
      default:
        return '#999999';
    }
  }
}