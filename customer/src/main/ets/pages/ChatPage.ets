// pages/ChatPage.ets
import router from '@ohos.router';

interface Message {
  id: number;
  content: string;
  isMe: boolean;
  time: string;
  type: 'text' | 'image';
}

interface Conversation {
  id: number;
  name: string;
  avatar: Resource;
}

@Entry
@Component
struct ChatPage {
  @State messages: Message[] = [];
  @State newMessage: string = '';
  @State conversation: Conversation | null = null;

  aboutToAppear() {
    const params = router.getParams() as Record<string, Object>;
    if (params && params['conversation']) {
      try {
        this.conversation = JSON.parse(params['conversation'] as string) as Conversation;
        // 加载模拟消息数据
        this.loadMessages();
      } catch (error) {
        console.error('解析对话信息失败:', error);
      }
    }
  }

  loadMessages() {
    // 模拟消息数据
    this.messages = [
      {
        id: 1,
        content: '您好，有什么可以帮您的？',
        isMe: false,
        time: '10:00',
        type: 'text'
      },
      {
        id: 2,
        content: '我想了解一下今天的特色菜',
        isMe: true,
        time: '10:01',
        type: 'text'
      },
      {
        id: 3,
        content: '今天我们的特色菜是红烧肉和清蒸鱼，都很受欢迎',
        isMe: false,
        time: '10:02',
        type: 'text'
      }
    ];
  }

  sendMessage() {
    if (!this.newMessage.trim()) {
      return;
    }

    const newMsg: Message = {
      id: this.messages.length + 1,
      content: this.newMessage,
      isMe: true,
      time: this.getCurrentTime(),
      type: 'text'
    };

    this.messages = [...this.messages, newMsg];
    this.newMessage = '';

    // 模拟回复
    setTimeout(() => {
      const replyMsg: Message = {
        id: this.messages.length + 1,
        content: '收到您的消息，我们会尽快处理',
        isMe: false,
        time: this.getCurrentTime(),
        type: 'text'
      };
      this.messages = [...this.messages, replyMsg];
    }, 1000);
  }

  getCurrentTime(): string {
    const now = new Date();
    return `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}`;
  }

  build() {
    Column() {
      // 顶部导航
      Row() {
        Image($r('app.media.back_icon'))
          .width(24)
          .height(24)
          .onClick(() => {
            router.back();
          })

        if (this.conversation) {
          Image(this.conversation.avatar)
            .width(36)
            .height(36)
            .borderRadius(18)
            .margin({ left: 12 })

          Text(this.conversation.name)
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .layoutWeight(1)
            .margin({ left: 8 })
        }
      }
      .width('100%')
      .padding({
        left: 16,
        right: 16,
        top: 12,
        bottom: 12
      })
      .backgroundColor('#ffffff')
      .border({ width: { bottom: 1 }, color: '#f0f0f0' })

      // 消息列表
      List() {
        ForEach(this.messages, (message: Message) => {
          ListItem() {
            Row() {
              if (!message.isMe) {
                Image($r('app.media.ic_user_avatar'))
                  .width(36)
                  .height(36)
                  .borderRadius(18)
                  .margin({ right: 8 })
              }

              Column() {
                if (message.type === 'text') {
                  Text(message.content)
                    .fontSize(16)
                    .fontColor(message.isMe ? '#ffffff' : '#333333')
                    .padding(12)
                    .backgroundColor(message.isMe ? '#1890ff' : '#f0f0f0')
                    .borderRadius(18)
                    .width('70%')
                }

                Text(message.time)
                  .fontSize(12)
                  .fontColor('#999999')
                  .margin({ top: 4 })
              }
              .alignItems(message.isMe ? HorizontalAlign.End : HorizontalAlign.Start)
              .layoutWeight(1)

              if (message.isMe) {
                Image($r('app.media.ic_user_avatar'))
                  .width(36)
                  .height(36)
                  .borderRadius(18)
                  .margin({ left: 8 })
              }
            }
            .width('100%')
            .justifyContent(message.isMe ? FlexAlign.End : FlexAlign.Start)
            .margin({ bottom: 16 })
          }
        })
      }
      .layoutWeight(1)
      .padding(16)
      .backgroundColor('#fafafa')

      // 输入区域
      Row() {
        TextInput({ placeholder: '输入消息...', text: this.newMessage })
          .layoutWeight(1)
          .height(40)
          .padding(10)
          .backgroundColor('#ffffff')
          .borderRadius(20)
          .border({ width: 1, color: '#e6e6e6' })
          .onChange((value: string) => {
            this.newMessage = value;
          })

        Button('发送', { type: ButtonType.Normal })
          .margin({ left: 8 })
          .padding({ left: 16, right: 16 })
          .backgroundColor('#1890ff')
          .fontColor('#ffffff')
          .borderRadius(16)
          .enabled(!!this.newMessage.trim())
          .onClick(() => {
            this.sendMessage();
          })
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#ffffff')
      .border({ width: { top: 1 }, color: '#f0f0f0' })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#ffffff')
  }
}