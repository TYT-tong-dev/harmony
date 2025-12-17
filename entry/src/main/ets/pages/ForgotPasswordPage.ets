import router from '@ohos.router';
import http from '@ohos.net.http';
import promptAction from '@ohos.promptAction';

@Entry
@Component
struct ForgotPasswordPage {
  @State currentStep: number = 1;
  @State email: string = '';
  @State resetToken: string = '';
  @State newPassword: string = '';
  @State confirmPassword: string = '';
  @State isLoading: boolean = false;
  @State countdown: number = 0;
  @State timer: number = 0;
  @State opacityValue: number = 0;

  aboutToAppear() {
    this.opacityValue = 1;
  }

  aboutToDisappear() {
    if (this.timer) {
      clearInterval(this.timer);
    }
  }

  startCountdown() {
    this.countdown = 60;
    this.timer = setInterval(() => {
      if (this.countdown > 0) {
        this.countdown--;
      } else {
        clearInterval(this.timer);
      }
    }, 1000);
  }

  async handleSendResetEmail() {
    if (!this.email) {
      promptAction.showToast({
        message: '请输入邮箱地址',
        duration: 2000
      });
      return;
    }

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
        'http://10.12.8.110:5000/Users/ForgotPassword',
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json'
          },
          extraData: JSON.stringify({
            email: this.email
          }),
          connectTimeout: 10000,
          readTimeout: 10000
        }
      );
      if (response.responseCode === 200) {
        interface ForgotPasswordData {
          reset_token: string;
        }

        interface ForgotPasswordResponse {
          statusCode: number;
          message?: string;
          data: ForgotPasswordData;
        }

        const result: ForgotPasswordResponse = JSON.parse(response.result as string);

        if (result.statusCode === 200) {
          promptAction.showToast({
            message: '重置验证码已发送到您的邮箱',
            duration: 3000
          });

          this.resetToken = result.data.reset_token;
          this.startCountdown();

          setTimeout(() => {
            this.currentStep = 2;
            this.isLoading = false;
          }, 1500);
        } else {
          promptAction.showToast({
            message: result.message || '发送失败',
            duration: 3000
          });
          this.isLoading = false;
        }
      } else {
        promptAction.showToast({
          message: '网络请求失败，请检查网络连接',
          duration: 3000
        });
        this.isLoading = false;
      }
    } catch (error) {
      console.error('发送重置邮件错误:', error);
      promptAction.showToast({
        message: '网络连接错误，请稍后重试',
        duration: 3000
      });
      this.isLoading = false;
    }
  }

  async handleResetPassword() {
    if (!this.resetToken) {
      promptAction.showToast({
        message: '请先获取重置验证码',
        duration: 2000
      });
      return;
    }

    if (!this.newPassword || !this.confirmPassword) {
      promptAction.showToast({
        message: '请填写新密码和确认密码',
        duration: 2000
      });
      return;
    }

    if (this.newPassword !== this.confirmPassword) {
      promptAction.showToast({
        message: '两次输入的密码不一致',
        duration: 2000
      });
      return;
    }

    if (this.newPassword.length < 6) {
      promptAction.showToast({
        message: '密码长度至少6位',
        duration: 2000
      });
      return;
    }

    this.isLoading = true;

    try {
      const httpRequest = http.createHttp();
      const response = await httpRequest.request(
        'http://10.12.8.110:5000/Users/ResetPassword',
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json'
          },
          extraData: JSON.stringify({
            token: this.resetToken,
            new_password: this.newPassword
          }),
          connectTimeout: 10000,
          readTimeout: 10000
        }
      );
      if (response.responseCode === 200) {
        interface ResetPasswordData {
          // 重置密码响应数据，根据实际API响应定义具体字段
        }

        interface ResetPasswordResponse {
          statusCode: number;
          message?: string;
          data: ResetPasswordData;
        }

        const result: ResetPasswordResponse = JSON.parse(response.result as string);

        if (result.statusCode === 200) {
          promptAction.showToast({
            message: '密码重置成功',
            duration: 2000
          });

          setTimeout(() => {
            router.back();
          }, 1500);
        } else {
          promptAction.showToast({
            message: result.message || '重置失败',
            duration: 3000
          });
          this.isLoading = false;
        }
      } else {
        promptAction.showToast({
          message: '网络请求失败',
          duration: 3000
        });
        this.isLoading = false;
      }
    } catch (error) {
      console.error('重置密码错误:', error);
      promptAction.showToast({
        message: '网络连接错误',
        duration: 3000
      });
      this.isLoading = false;
    }
  }

  async handleResendCode() {
    if (this.countdown > 0) {
      promptAction.showToast({
        message: `请等待${this.countdown}秒后重试`,
        duration: 2000
      });
      return;
    }

    await this.handleSendResetEmail();
  }

  build() {
    Column() {
      // 头部导航 - 调整到更靠上位置
      Row() {
        Stack() {
          Circle({ width: 40, height: 40 })
            .fill('#F8F9FA')

          Image($r('app.media.back_icon'))
            .width(20)
            .height(20)
            .fillColor('#333333')
        }
        .onClick(() => {
          if (this.currentStep === 1) {
            router.back();
          } else {
            this.currentStep = 1;
          }
        })

        Text('找回密码')
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
        Column({ space: 32 }) {
          // 步骤指示器
          Row({ space: 16 }) {
            ForEach([1, 2], (step: number) => {
              Column({ space: 8 }) {
                // 步骤圆圈
                Stack() {
                  Circle({ width: 32, height: 32 })
                    .fill(this.currentStep >= step ? '#4F6BED' : '#F0F0F0')

                  Text(step.toString())
                    .fontSize(14)
                    .fontColor(this.currentStep >= step ? Color.White : '#999999')
                    .fontWeight(FontWeight.Medium)
                }

                // 步骤文字
                Text(step === 1 ? '验证身份' : '重置密码')
                  .fontSize(12)
                  .fontColor(this.currentStep >= step ? '#4F6BED' : '#999999')
              }

              // 连接线（除了最后一个）
              if (step < 2) {
                Blank()
                  .height(2)
                  .backgroundColor(this.currentStep > step ? '#4F6BED' : '#F0F0F0')
                  .layoutWeight(1)
                  .margin({ top: 16 })
              }
            })
          }
          .width('100%')
          .padding({ left: 40, right: 40 })

          if (this.currentStep === 1) {
            this.buildStep1()
          } else {
            this.buildStep2()
          }
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

  @Builder
  buildStep1() {
    Column({ space: 24 }) {
      // 说明区域
      Column({ space: 12 }) {
        Text('找回密码')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
          .textAlign(TextAlign.Start)
          .width('100%')

        Text('请输入您注册时使用的邮箱地址，我们将发送重置验证码')
          .fontSize(14)
          .fontColor('#666666')
          .textAlign(TextAlign.Start)
          .width('100%')
      }

      // 表单区域 - 调整到页面中间
      Column({ space: 20 }) {
        // 邮箱输入
        Column({ space: 8 }) {
          Text('邮箱地址')
            .fontSize(14)
            .fontColor('#666666')
            .align(Alignment.Start)
            .width('100%')

          TextInput({ placeholder: '请输入注册邮箱', text: this.email })
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

        // 发送按钮
        Button('发送验证码', { type: ButtonType.Normal })
          .width('100%')
          .height(56)
          .backgroundColor(this.isLoading || !this.email ? '#CCCCCC' : '#4F6BED')
          .fontColor(Color.White)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .borderRadius(16)
          .enabled(!this.isLoading && !!this.email)
          .stateEffect(!this.isLoading && !!this.email)
          .onClick(() => {
            this.handleSendResetEmail();
          })

        if (this.isLoading) {
          LoadingProgress()
            .width(32)
            .height(32)
            .color(Color.White)
            .margin({ top: 16 })
        }
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
  }

  @Builder
  buildStep2() {
    Column({ space: 24 }) {
      // 说明区域
      Column({ space: 12 }) {
        Text('重置密码')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
          .textAlign(TextAlign.Start)
          .width('100%')

        Text(`验证码已发送到：${this.email}`)
          .fontSize(14)
          .fontColor('#666666')
          .textAlign(TextAlign.Start)
          .width('100%')

        Row({ space: 4 }) {
          Text('没有收到验证码？')
            .fontSize(14)
            .fontColor('#666666')

          Text(this.countdown > 0 ? `${this.countdown}秒后重试` : '重新发送')
            .fontSize(14)
            .fontColor(this.countdown > 0 ? '#999999' : '#4F6BED')
            .fontWeight(FontWeight.Medium)
            .onClick(() => {
              if (this.countdown === 0) {
                this.handleResendCode();
              }
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
      }

      // 表单区域 - 调整到页面中间
      Column({ space: 20 }) {
        // 验证码输入
        Column({ space: 8 }) {
          Text('验证码')
            .fontSize(14)
            .fontColor('#666666')
            .align(Alignment.Start)
            .width('100%')

          TextInput({ placeholder: '请输入重置验证码', text: this.resetToken })
            .width('100%')
            .height(56)
            .backgroundColor('#FFFFFF')
            .borderRadius(16)
            .padding({ left: 20, right: 20 })
            .fontSize(16)
            .fontColor('#1A1A1A')
            .border({
              width: 1,
              color: this.resetToken ? '#4F6BED' : '#E8E8E8'
            })
            .onChange((value: string) => {
              this.resetToken = value;
            })
        }

        // 新密码 - 使用系统默认的眼睛图标
        Column({ space: 8 }) {
          Text('新密码')
            .fontSize(14)
            .fontColor('#666666')
            .align(Alignment.Start)
            .width('100%')

          TextInput({ placeholder: '请输入新密码', text: this.newPassword })
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
              color: this.newPassword ? '#4F6BED' : '#E8E8E8'
            })
            .onChange((value: string) => {
              this.newPassword = value;
            })

          // 密码强度
          if (this.newPassword) {
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

          TextInput({ placeholder: '请再次输入新密码', text: this.confirmPassword })
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
                (this.newPassword === this.confirmPassword ? '#52C41A' : '#FF4D4F') : '#E8E8E8'
            })
            .onChange((value: string) => {
              this.confirmPassword = value;
            })

          if (this.confirmPassword && this.newPassword !== this.confirmPassword) {
            Text('两次输入的密码不一致')
              .fontSize(12)
              .fontColor('#FF4D4F')
              .width('100%')
              .textAlign(TextAlign.Start)
              .margin({ top: 4 })
          }
        }

        // 重置按钮
        Button('重置密码', { type: ButtonType.Normal })
          .width('100%')
          .height(56)
          .backgroundColor(this.isLoading || !this.resetToken || !this.newPassword || !this.confirmPassword ?
            '#CCCCCC' : '#4F6BED')
          .fontColor(Color.White)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .borderRadius(16)
          .enabled(!this.isLoading && !!this.resetToken && !!this.newPassword && !!this.confirmPassword)
          .stateEffect(!this.isLoading && !!this.resetToken && !!this.newPassword && !!this.confirmPassword)
          .onClick(() => {
            this.handleResetPassword();
          })

        if (this.isLoading) {
          LoadingProgress()
            .width(32)
            .height(32)
            .color(Color.White)
            .margin({ top: 16 })
        }
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
  }

  // 密码强度评估
  getPasswordStrength(): number {
    if (!this.newPassword) {
      return 0;
    }

    let strength = 0;
    if (this.newPassword.length >= 6) {
      strength++;
    }
    if (this.newPassword.length >= 8) {
      strength++;
    }
    if (/\d/.test(this.newPassword) && /[a-zA-Z]/.test(this.newPassword)) {
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