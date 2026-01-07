// SystemSettingsPage.ets
import promptAction from '@ohos.promptAction';

@Entry
@Component
export struct SystemSettingsPage {
  @State notificationsEnabled: boolean = true;
  @State soundEnabled: boolean = true;
  @State darkMode: boolean = false;
  @State language: string = 'zh-CN';
  @State cacheSizeMB: number = 23.4;

  build() {
    Column() {
      // 通知设置
      Column() {
        Text('通知设置')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
          .margin({ bottom: 12 })
        this.SwitchRow('接收通知', this.notificationsEnabled, (v: boolean) => {
          this.notificationsEnabled = v;
        })
        this.SwitchRow('提示音', this.soundEnabled, (v: boolean) => {
          this.soundEnabled = v;
        })
      }
      .padding(16)
      .margin({ top: 12 })
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
      .width('100%')

      // 显示与语言
      Column() {
        Text('显示与语言')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
          .margin({ bottom: 12 })
        this.SwitchRow('深色模式', this.darkMode, (v: boolean) => {
          this.darkMode = v;
        })
        this.SelectRow('语言', this.getLanguageLabel(this.language))
      }
      .padding(16)
      .margin({ top: 12 })
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
      .width('100%')

      // 存储
      Column() {
        Text('存储')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
          .margin({ bottom: 12 })
        this.InfoRow('缓存大小', `${this.cacheSizeMB.toFixed(1)} MB`)
        Button('清除缓存')
          .width('100%')
          .height(40)
          .backgroundColor('#FF3B30')
          .fontColor('#FFFFFF')
          .borderRadius(8)
          .margin({ top: 8 })
          .onClick(() => {
            this.clearCache();
          })
      }
      .padding(16)
      .margin({ top: 12 })
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
      .width('100%')

      // 关于
      Column() {
        Text('关于')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
          .margin({ bottom: 12 })
        this.InfoRow('应用版本', 'v1.0.0')
        this.InfoRow('隐私政策', '点击查看')
      }
      .padding(16)
      .margin({ top: 12 })
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
    .padding(12)
  }

  @Builder
  SwitchRow(title: string, value: boolean, onChange: (v: boolean) => void) {
    Row() {
      Text(title)
        .fontSize(14)
        .fontColor('#1A1A1A')
        .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: value })
        .onChange((v: boolean) => onChange(v))
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
  }

  @Builder
  SelectRow(title: string, value: string) {
    Row() {
      Column() {
        Text(title)
          .fontSize(14)
          .fontColor('#1A1A1A')
        Text(value)
          .fontSize(12)
          .fontColor('#999999')
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Image($r('app.media.arrow_right'))
        .width(16)
        .height(16)
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
    .onClick(() => {
      this.toggleLanguage();
    })
  }

  @Builder
  InfoRow(title: string, value: string) {
    Row() {
      Text(title)
        .fontSize(14)
        .fontColor('#1A1A1A')
        .layoutWeight(1)
      Text(value)
        .fontSize(14)
        .fontColor('#666666')
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
  }

  toggleLanguage(): void {
    this.language = this.language === 'zh-CN' ? 'en-US' : 'zh-CN';
    promptAction.showToast({
      message: `已切换为 ${this.getLanguageLabel(this.language)}`,
      duration: 1500
    });
  }

  getLanguageLabel(code: string): string {
    return code === 'en-US' ? 'English (US)' : '简体中文';
  }

  clearCache(): void {
    this.cacheSizeMB = 0;
    promptAction.showToast({
      message: '缓存已清除',
      duration: 1500
    });
  }
}
