// MessagePage.ets
import { Message, ChatMessage, UserInfo, ConversationListResponse, MessageListResponse, SendMessageRequest, CreateConversationRequest, UserSearchResponse, ConversationListResponseData, ConversationItemData, MessageListResponseData, ChatMessageItemData, SendMessageResponseData, NotificationListResponse, NotificationType, AppNotification } from '../common/Types';
import { ApiUtils, ToastUtils } from '../common/Utils';
import { NotificationUtils, NotificationData, NotificationExtraData } from '../common/NotificationUtils';
import { ApiResponse } from '../common/Types';
import router from '@ohos.router';
import picker from '@ohos.file.picker';
import media from '@ohos.multimedia.media';
import abilityAccessCtrl from '@ohos.abilityAccessCtrl';
import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';
import { BusinessError } from '@kit.BasicServicesKit';

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

@Entry
@Component
export struct MessagePage {
  @State messages: Message[] = [];
  @State selectedChat: Message | null = null;
  @State chatInput: string = '';
  @State showAddUserDialog: boolean = false;
  @State searchKeyword: string = '';
  @State searchUsers: UserInfo[] = [];
  @State loading: boolean = false;
  @State recording: boolean = false;
  @State recordingDuration: number = 0; // 录音时长（秒）

  private context?: common.UIAbilityContext;
  private atManager?: abilityAccessCtrl.AtManager;
  private mediaPermissionsGranted: boolean = false;
  private audioRecorder?: media.AudioRecorder;
  private audioPlayer?: media.AudioPlayer;
  private recordingTimer?: number;
  private recordingStartTime: number = 0;
  private recordingFilePath: string = '';
  private readonly mediaPermissions: MediaPermissionName[] = [
    'ohos.permission.READ_MEDIA',
    'ohos.permission.WRITE_MEDIA',
    'ohos.permission.READ_IMAGEVIDEO',
    'ohos.permission.WRITE_IMAGEVIDEO',
    'ohos.permission.CAMERA'
  ];

  // 消息轮询定时器
  private messagePollingTimer: number = -1;
  private readonly POLLING_INTERVAL: number = 5000; // 5秒轮询一次

  // 通知相关
  private lastMessageNotificationId: number = 0;
  @State unreadMessageCount: number = 0;

  aboutToAppear() {
    const token: string = (AppStorage.get('userToken') as string) || '';
    if (!token) {
      ToastUtils.showToast('请先登录');
      router.replaceUrl({ url: 'pages/LoginPage' });
      return;
    }
    try {
      this.context = getContext(this) as common.UIAbilityContext;
      this.atManager = abilityAccessCtrl.createAtManager();
    } catch (error) {
      console.error('初始化页面上下文失败:' + JSON.stringify(error));
    }
    this.loadMessages();
    // 启动消息轮询
    this.startMessagePolling();
    // 检查消息通知权限
    this.checkNotificationPermission();
  }

  // 检查通知权限
  private async checkNotificationPermission(): Promise<void> {
    try {
      await NotificationUtils.requestPermission();
    } catch (error) {
      console.error('检查通知权限失败:' + JSON.stringify(error));
    }
  }

  aboutToDisappear() {
    // 清理轮询定时器
    this.stopMessagePolling();
    
    // 清理录音资源
    if (this.recording && this.audioRecorder) {
      try {
        this.audioRecorder.stop();
        this.audioRecorder.release();
      } catch (error) {
        console.error('停止录音失败:', JSON.stringify(error));
      }
    }
    
    // 清理播放资源
    if (this.audioPlayer) {
      try {
        this.audioPlayer.stop();
        this.audioPlayer.release();
      } catch (error) {
        console.error('停止播放失败:', JSON.stringify(error));
      }
    }
    
    // 清理录音计时器
    if (this.recordingTimer) {
      clearInterval(this.recordingTimer);
      this.recordingTimer = undefined;
    }
  }

  // 启动消息轮询
  private startMessagePolling(): void {
    this.stopMessagePolling(); // 先清理已有定时器
    this.messagePollingTimer = setInterval(() => {
      this.pollMessages();
    }, this.POLLING_INTERVAL);
  }

  // 停止消息轮询
  private stopMessagePolling(): void {
    if (this.messagePollingTimer !== -1) {
      clearInterval(this.messagePollingTimer);
      this.messagePollingTimer = -1;
    }
  }

  // 轮询获取新消息
  private async pollMessages(): Promise<void> {
    try {
      // 如果在聊天详情页，刷新当前对话的消息
      if (this.selectedChat) {
        await this.loadChatMessagesQuietly(this.selectedChat.conversationId);
      } else {
        // 在会话列表页，刷新会话列表
        await this.loadMessagesQuietly();
      }
      // 检查消息通知
      await this.checkMessageNotifications();
    } catch (error) {
      console.error('轮询消息失败:', JSON.stringify(error));
    }
  }

  // 检查消息通知
  private async checkMessageNotifications(): Promise<void> {
    try {
      const response: ApiResponse = await ApiUtils.get('/notifications/list?unread_only=true&limit=10');
      if (response.statusCode === 200 && response.data) {
        const data = response.data as NotificationListResponse;
        this.unreadMessageCount = data.unread_count;

        // 检查是否有新消息通知
        if (data.notifications && data.notifications.length > 0) {
          for (const notification of data.notifications) {
            // 只处理消息类型且比上次更新的通知
            if (notification.type === 'message' && notification.id > this.lastMessageNotificationId) {
              // 发送本地通知
              const notificationData = new NotificationData(
                notification.id,
                NotificationType.MESSAGE,
                notification.title,
                notification.content
              );
              const extra = new NotificationExtraData();
              extra.conversationId = notification.related_id?.toString() || '';
              notificationData.extra = extra;
              await NotificationUtils.sendNotification(notificationData);
            }
          }
          // 更新最后一条通知ID
          const messageNotifications = data.notifications.filter((n: AppNotification) => n.type === 'message');
          if (messageNotifications.length > 0) {
            let maxId = 0;
            for (const n of messageNotifications) {
              if (n.id > maxId) {
                maxId = n.id;
              }
            }
            this.lastMessageNotificationId = maxId;
          }
        }
      }
    } catch (error) {
      console.error('检查消息通知失败:' + JSON.stringify(error));
    }
  }

  // 静默加载消息列表（不显示loading状态）
  private async loadMessagesQuietly(): Promise<void> {
    try {
      const response: ApiResponse = await ApiUtils.get('/messages/conversations');
      if (response.statusCode === 200 && response.data) {
        const data = response.data as ConversationListResponseData;
        const conversations: ConversationItemData[] = data.conversations || [];
        this.messages = conversations.map((conv: ConversationItemData) => {
          const message = new Message();
          message.id = conv.conversationId || conv.id || 0;
          message.conversationId = conv.conversationId || conv.id || 0;
          message.userId = conv.userId || 0;
          message.username = conv.username || '';
          message.avatar = conv.avatar || '';
          message.lastContent = conv.lastContent || '';
          message.lastTime = conv.lastTime || 0;
          message.unreadCount = conv.unreadCount || 0;
          message.isOnline = conv.isOnline || false;
          message.messages = [];
          return message;
        });
      }
    } catch (error) {
      console.error('静默加载消息列表失败:', JSON.stringify(error));
    }
  }

  // 静默加载聊天消息（不显示loading状态）
  private async loadChatMessagesQuietly(conversationId: number): Promise<void> {
    if (!this.selectedChat) return;
    try {
      const response: ApiResponse = await ApiUtils.get(`/messages/list?conversation_id=${conversationId}`);
      if (response.statusCode === 200 && response.data) {
        const data = response.data as MessageListResponseData;
        const messages: ChatMessageItemData[] = data.messages || [];
        const newMessages: ChatMessage[] = messages.map((msg: ChatMessageItemData) => {
          const chatMessage = new ChatMessage();
          chatMessage.id = msg.id || 0;
          chatMessage.content = msg.content || '';
          chatMessage.time = msg.time || 0;
          chatMessage.isMe = msg.isMe || false;
          chatMessage.type = msg.type || 'text';
          chatMessage.imageUrl = msg.imageUrl || '';
          chatMessage.videoUrl = msg.videoUrl || '';
          chatMessage.voiceUrl = msg.voiceUrl || '';
          chatMessage.voiceDuration = msg.voiceDuration || 0;
          return chatMessage;
        });

        // 只有在有新消息时才更新
        if (newMessages.length > (this.selectedChat.messages?.length || 0)) {
          this.selectedChat.messages = newMessages;
        }
      }
    } catch (error) {
      console.error('静默加载聊天消息失败:', JSON.stringify(error));
    }
  }

  build() {
    Stack() {
      Column() {
        if (this.selectedChat) {
          this.ChatDetail()
        } else {
          this.ChatList()
        }
      }
      .width('100%')
      .height('100%')

      // 图片预览对话框
      if (this.showImagePreview) {
        this.ImagePreviewDialog()
      }

      // 视频预览对话框
      if (this.showVideoPreview) {
        this.VideoPreviewDialog()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  @Builder
  ChatList() {
    Column() {
      // 标题栏
      Row() {
        Text('消息')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
          .layoutWeight(1)

        // 通知入口（带红点）
        Stack() {
          Image($r('app.media.message'))
            .width(24)
            .height(24)
            .onClick(() => {
              router.pushUrl({ url: 'pages/NotificationPage' });
            })

          // 未读红点
          if (this.unreadMessageCount > 0) {
            Text(this.unreadMessageCount > 99 ? '99+' : this.unreadMessageCount.toString())
              .fontSize(10)
              .fontColor(Color.White)
              .backgroundColor('#FF3B30')
              .borderRadius(8)
              .padding({ left: 4, right: 4, top: 1, bottom: 1 })
              .position({ x: 14, y: -4 })
          }
        }
        .margin({ right: 12 })

        Button('添加朋友', { type: ButtonType.Normal })
          .fontSize(14)
          .fontColor('#007DFF')
          .fontWeight(FontWeight.Medium)
          .backgroundColor(Color.Transparent)
          .borderColor(Color.Transparent)
          .padding({ left: 8, right: 8 })
          .onClick(() => {
            this.showAddUserDialog = true;
          })
      }
      .padding(16)
      .backgroundColor('#FFFFFF')
      .width('100%')

      // 消息列表
      if (this.messages.length === 0 && !this.loading) {
        Column() {
          Text('暂无消息')
            .fontSize(14)
            .fontColor('#999')
            .textAlign(TextAlign.Center)
            .width('100%')
            .padding(16)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
      List() {
        ForEach(this.messages, (message: Message) => {
          ListItem() {
            this.MessageItem(message)
          }
        }, (message: Message) => message.id.toString())
      }
      .layoutWeight(1)
      .width('100%')
      }

      // 添加用户对话框
      if (this.showAddUserDialog) {
        this.AddUserDialog()
      }
    }
  }

  @Builder
  MessageItem(message: Message) {
    Row() {
      // 头像和在线状态
      Stack() {
        if (message.avatar && message.avatar.startsWith('app.media.avatar')) {
          Image($r(message.avatar))
            .width(48)
            .height(48)
            .borderRadius(24)
        } else if (message.avatar) {
          Image(message.avatar)
            .width(48)
            .height(48)
            .borderRadius(24)
        } else {
          Image($r('app.media.ic_user_avatar'))
            .width(48)
            .height(48)
            .borderRadius(24)
        }

        if (message.isOnline) {
          Circle()
            .width(12)
            .height(12)
            .fill('#52C41A')
            .position({ x: 36, y: 36 })
        }
      }

      Column() {
        Text(message.username)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')

        Text(message.lastContent)
          .fontSize(14)
          .fontColor('#666666')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 4 })
          .width('100%')
      }
      .margin({ left: 12 })
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      // 未读消息数
      if (message.unreadCount > 0) {
        Text(message.unreadCount > 99 ? '99+' : message.unreadCount.toString())
          .fontSize(10)
          .fontColor('#FFFFFF')
          .backgroundColor('#FF3B30')
          .padding({
            left: 6,
            right: 6,
            top: 2,
            bottom: 2
          })
          .borderRadius(10)
      }
    }
    .padding(12)
    .backgroundColor('#FFFFFF')
    .onClick(() => {
      this.selectedChat = message;
    })
  }

  @Builder
  ChatDetail() {
    Column() {
      // 聊天头部 - 全屏顶部，昵称居中
      Row() {
        Image($r('app.media.back_icon'))
          .width(24)
          .height(24)
          .onClick(() => {
            this.selectedChat = null;
            this.loadMessages(); // 刷新消息列表
          })

        Text(this.selectedChat?.username || '')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        // 占位，保持对称
        Blank()
          .width(24)
      }
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor('#FFFFFF')
      .width('100%')
      .border({ width: { bottom: 1 }, color: '#F0F0F0' })

      // 聊天内容
      List() {
        ForEach(this.selectedChat?.messages || [], (msg: ChatMessage) => {
          ListItem() {
            this.ChatBubble(msg)
          }
        }, (msg: ChatMessage) => msg.id.toString())
      }
      .layoutWeight(1)
      .width('100%')
      .backgroundColor('#F5F5F5')

      // 输入区域
      Row() {
        // 语音按钮
        Row({ space: 4 }) {
        Button(this.recording ? '🎤' : '🎙', { type: ButtonType.Normal })
          .fontSize(20)
          .backgroundColor(Color.Transparent)
          .borderColor(Color.Transparent)
          .width(32)
          .height(32)
          .onClick(() => {
            if (this.recording) {
              this.stopRecording();
            } else {
              this.startRecording();
            }
          })
          if (this.recording) {
            Text(`${this.recordingDuration}''`)
              .fontSize(12)
              .fontColor('#FF3B30')
              .fontWeight(FontWeight.Medium)
          }
        }
        .margin({ right: 8 })

        // 输入框
        TextInput({ placeholder: '输入消息...', text: this.chatInput })
          .layoutWeight(1)
          .height(40)
          .backgroundColor('#FFFFFF')
          .borderRadius(20)
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.chatInput = value;
          })

        // 图片按钮
        Button('📷', { type: ButtonType.Normal })
          .fontSize(20)
          .backgroundColor(Color.Transparent)
          .borderColor(Color.Transparent)
          .width(32)
          .height(32)
          .margin({ left: 8, right: 4 })
          .onClick(() => {
            this.selectImage();
          })

        // 视频按钮
        Button('🎥', { type: ButtonType.Normal })
          .fontSize(20)
          .backgroundColor(Color.Transparent)
          .borderColor(Color.Transparent)
          .width(32)
          .height(32)
          .margin({ left: 4, right: 8 })
          .onClick(() => {
            this.selectVideo();
          })

        // 发送按钮
        if (this.chatInput.trim()) {
          Button('发送', { type: ButtonType.Normal })
            .fontSize(14)
            .backgroundColor('#007DFF')
            .fontColor('#FFFFFF')
            .padding({ left: 12, right: 12 })
          .onClick(() => {
            this.sendMessage();
          })
        }
      }
      .padding(12)
      .backgroundColor('#FFFFFF')
      .width('100%')
    }
    .onAppear(() => {
      if (this.selectedChat) {
        this.loadChatMessages(this.selectedChat.conversationId);
      }
    })
  }

  @Builder
  ChatBubble(message: ChatMessage) {
    Row() {
      if (!message.isMe) {
        if (this.selectedChat?.avatar && this.selectedChat.avatar.startsWith('app.media.avatar')) {
          Image($r(this.selectedChat.avatar))
            .width(32)
            .height(32)
            .borderRadius(16)
            .margin({ right: 8 })
        } else if (this.selectedChat?.avatar) {
          Image(this.selectedChat.avatar)
            .width(32)
            .height(32)
            .borderRadius(16)
            .margin({ right: 8 })
        } else {
          Image($r('app.media.ic_user_avatar'))
            .width(32)
            .height(32)
            .borderRadius(16)
            .margin({ right: 8 })
        }
      }

      Column() {
        if (message.type === 'text') {
          Text(message.content)
            .fontSize(14)
            .fontColor(message.isMe ? '#FFFFFF' : '#333333')
            .backgroundColor(message.isMe ? '#007DFF' : '#FFFFFF')
            .padding(12)
            .borderRadius(12)
            .constraintSize({ maxWidth: '70%' })
            .maxLines(10)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        } else if (message.type === 'image' && message.imageUrl) {
          Stack() {
            if (message.imageUrl.startsWith('app.media.')) {
              Image($r(message.imageUrl))
                .width(200)
                .height(200)
                .borderRadius(12)
                .objectFit(ImageFit.Cover)
            } else {
              Image(this.normalizeImagePath(message.imageUrl))
                .width(200)
                .height(200)
                .borderRadius(12)
                .objectFit(ImageFit.Cover)
            }
          }
          .width(200)
          .height(200)
          .borderRadius(12)
          .onClick(() => {
            // 点击图片全屏展示
            this.previewImage(message.imageUrl || '');
          })
        } else if (message.type === 'video' && message.videoUrl) {
          Stack({ alignContent: Alignment.Center }) {
            if (message.videoUrl.startsWith('app.media.')) {
              Image($r(message.videoUrl))
                .width(200)
                .height(200)
                .borderRadius(12)
                .objectFit(ImageFit.Cover)
            } else {
              Image(this.normalizeImagePath(message.videoUrl))
                .width(200)
                .height(200)
                .borderRadius(12)
                .objectFit(ImageFit.Cover)
            }
            // 播放按钮
            Row() {
              Text('▶')
                .fontSize(32)
                .fontColor('#FFFFFF')
            }
            .width(60)
            .height(60)
            .borderRadius(30)
            .backgroundColor('rgba(0, 0, 0, 0.5)')
            .justifyContent(FlexAlign.Center)
          }
          .width(200)
          .height(200)
          .borderRadius(12)
          .onClick(() => {
            this.playVideo(message.videoUrl || '');
          })
        } else if (message.type === 'voice' && message.voiceUrl) {
          Row() {
            Text('▶')
              .fontSize(16)
              .fontColor(message.isMe ? '#FFFFFF' : '#333333')
              .margin({ right: 8 })
            Text(`${message.voiceDuration || 0}''`)
              .fontSize(14)
              .fontColor(message.isMe ? '#FFFFFF' : '#333333')
          }
          .backgroundColor(message.isMe ? '#007DFF' : '#FFFFFF')
          .padding(12)
          .borderRadius(12)
          .onClick(() => {
            this.playVoice(message.voiceUrl || '');
          })
        }
      }
      .alignItems(message.isMe ? HorizontalAlign.End : HorizontalAlign.Start)

      if (message.isMe) {
        Image($r('app.media.ic_user_avatar'))
          .width(32)
          .height(32)
          .borderRadius(16)
          .margin({ left: 8 })
      }
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 8 })
    .justifyContent(message.isMe ? FlexAlign.End : FlexAlign.Start)
  }

  // 添加用户对话框
  @Builder
  AddUserDialog() {
    Column() {
      // 搜索框
      Row() {
        TextInput({ placeholder: '搜索用户名或邮箱...', text: this.searchKeyword })
          .layoutWeight(1)
          .height(40)
          .backgroundColor('#F5F5F5')
          .borderRadius(20)
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.searchKeyword = value;
            if (value.trim()) {
              this.searchUsersByName(value);
            } else {
              this.searchUsers = [];
            }
          })

        Text('取消')
          .fontSize(14)
          .fontColor('#007DFF')
          .margin({ left: 12 })
          .onClick(() => {
            this.showAddUserDialog = false;
            this.searchKeyword = '';
            this.searchUsers = [];
          })
      }
      .padding(16)
      .backgroundColor('#FFFFFF')
      .width('100%')

      // 用户列表
      if (this.searchUsers.length > 0) {
        List() {
          ForEach(this.searchUsers, (user: UserInfo) => {
            ListItem() {
              Row() {
                Image(user.avatar || $r('app.media.ic_user_avatar'))
                  .width(48)
                  .height(48)
                  .borderRadius(24)

                Column() {
                  Text(user.username)
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#333333')
                  if (user.email) {
                    Text(user.email)
                      .fontSize(12)
                      .fontColor('#999999')
                      .margin({ top: 4 })
                  }
                }
                .margin({ left: 12 })
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Button('添加', { type: ButtonType.Normal })
                  .fontSize(14)
                  .backgroundColor('#007DFF')
                  .fontColor('#FFFFFF')
                  .onClick(() => {
                    this.createConversation(user.id);
                  })
              }
              .padding(12)
              .width('100%')
            }
          }, (user: UserInfo) => user.id.toString())
        }
        .layoutWeight(1)
        .width('100%')
      } else if (this.searchKeyword.trim() && !this.loading) {
        Column() {
          Text('未找到用户')
            .fontSize(14)
            .fontColor('#999')
            .textAlign(TextAlign.Center)
            .width('100%')
            .padding(16)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  // 加载消息列表
  async loadMessages() {
    try {
      this.loading = true;
      const response: ApiResponse = await ApiUtils.get('/messages/conversations');

      if (response.statusCode === 200 && response.data) {
        const data = response.data as ConversationListResponseData;
        const conversations: ConversationItemData[] = data.conversations || [];
        this.messages = conversations.map((conv: ConversationItemData) => {
          const message = new Message();
          message.id = conv.conversationId || conv.id || 0;
          message.conversationId = conv.conversationId || conv.id || 0;
          message.userId = conv.userId || 0;
          message.username = conv.username || '';
          message.avatar = conv.avatar || '';
          message.lastContent = conv.lastContent || '';
          message.lastTime = conv.lastTime || 0;
          message.unreadCount = conv.unreadCount || 0;
          message.isOnline = conv.isOnline || false;
          message.messages = [];
          return message;
        });
        if (this.messages.length === 0) {
          // 本地示例（厨师、客服、用户）
          this.messages = this.createLocalConversations();
        }
      } else {
        ToastUtils.showToast(response.message || '加载失败');
        // 失败时使用本地示例
        this.messages = this.createLocalConversations();
      }
    } catch (error) {
      console.error('加载消息列表失败:', JSON.stringify(error));
      ToastUtils.showToast('网络异常，请重试');
      // 异常时使用本地示例
      this.messages = this.createLocalConversations();
    } finally {
      this.loading = false;
    }
  }

  // 加载聊天消息
  async loadChatMessages(conversationId: number) {
    if (!this.selectedChat) return;

    try {
      const response: ApiResponse = await ApiUtils.get(`/messages/list?conversation_id=${conversationId}`);

      if (response.statusCode === 200 && response.data) {
        const data = response.data as MessageListResponseData;
        const messages: ChatMessageItemData[] = data.messages || [];
        this.selectedChat.messages = messages.map((msg: ChatMessageItemData) => {
          const chatMessage = new ChatMessage();
          chatMessage.id = msg.id || 0;
          chatMessage.content = msg.content || '';
          chatMessage.time = msg.time || 0;
          chatMessage.isMe = msg.isMe || false;
          chatMessage.type = msg.type || 'text';
          chatMessage.imageUrl = msg.imageUrl || '';
          chatMessage.videoUrl = msg.videoUrl || '';
          chatMessage.voiceUrl = msg.voiceUrl || '';
          chatMessage.voiceDuration = msg.voiceDuration || 0;
          return chatMessage;
        });
      } else {
        ToastUtils.showToast(response.message || '加载消息失败');
      }
    } catch (error) {
      console.error('加载聊天消息失败:', JSON.stringify(error));
      ToastUtils.showToast('网络异常，请重试');
    }
  }

  // 发送消息
  async sendMessage() {
    if (!this.chatInput.trim() || !this.selectedChat) {
      return;
    }

    const content = this.chatInput;
    this.chatInput = '';

    try {
      const request: SendMessageRequest = {
        conversation_id: this.selectedChat.conversationId,
        content: content,
        type: 'text'
      };

      const response: ApiResponse = await ApiUtils.post('/messages/send', request);

      if (response.statusCode === 200 && response.data) {
        const data = response.data as SendMessageResponseData;
        const newMessage = new ChatMessage();
        newMessage.id = data.id || 0;
        newMessage.content = data.content || content;
        newMessage.time = data.time || new Date().getTime();
        newMessage.isMe = true;
        newMessage.type = data.type || 'text';

        if (!this.selectedChat.messages) {
          this.selectedChat.messages = [];
        }
        this.selectedChat.messages.push(newMessage);
        this.selectedChat.lastContent = content;
        this.selectedChat.lastTime = newMessage.time;

        // 刷新消息列表
        this.loadMessages();
      } else {
        // 如果API失败，对于本地示例对话，直接添加到消息列表
        if (this.selectedChat.conversationId >= 1001 && this.selectedChat.conversationId <= 1003) {
          const newMessage = new ChatMessage();
          newMessage.id = Date.now();
          newMessage.content = content;
          newMessage.time = new Date().getTime();
          newMessage.isMe = true;
          newMessage.type = 'text';

          if (!this.selectedChat.messages) {
            this.selectedChat.messages = [];
          }
          this.selectedChat.messages.push(newMessage);
          this.selectedChat.lastContent = content;
          this.selectedChat.lastTime = newMessage.time;
        } else {
          ToastUtils.showToast(response.message || '发送失败');
          this.chatInput = content; // 恢复输入内容
        }
      }
    } catch (error) {
      console.error('发送消息失败:', JSON.stringify(error));
      // 对于本地示例对话，即使网络失败也允许发送
      if (this.selectedChat && this.selectedChat.conversationId >= 1001 && this.selectedChat.conversationId <= 1003) {
        const newMessage = new ChatMessage();
        newMessage.id = Date.now();
        newMessage.content = content;
        newMessage.time = new Date().getTime();
        newMessage.isMe = true;
        newMessage.type = 'text';

        if (!this.selectedChat.messages) {
          this.selectedChat.messages = [];
        }
        this.selectedChat.messages.push(newMessage);
        this.selectedChat.lastContent = content;
        this.selectedChat.lastTime = newMessage.time;
      } else {
        ToastUtils.showToast('网络异常，请重试');
        this.chatInput = content; // 恢复输入内容
      }
    }
  }

  // 搜索用户
  async searchUsersByName(keyword: string) {
    try {
      const response: ApiResponse = await ApiUtils.get(`/messages/users/search?keyword=${encodeURIComponent(keyword)}`);

      if (response.statusCode === 200 && response.data) {
        const data = response.data as UserSearchResponse;
        this.searchUsers = data.users || [];
      } else {
        this.searchUsers = [];
      }
    } catch (error) {
      console.error('搜索用户失败:', JSON.stringify(error));
      this.searchUsers = [];
    }
  }

  // 创建会话
  async createConversation(userId: number) {
    try {
      const request: CreateConversationRequest = {
        user_id: userId
      };

      const response: ApiResponse = await ApiUtils.post('/messages/conversation/create', request);

      if (response.statusCode === 200 && response.data) {
        // 创建会话成功，不需要解析响应数据
        ToastUtils.showToast('添加成功');
        this.showAddUserDialog = false;
        this.searchKeyword = '';
        this.searchUsers = [];
        
        // 刷新消息列表
        this.loadMessages();
      } else {
        ToastUtils.showToast(response.message || '添加失败');
      }
    } catch (error) {
      console.error('创建会话失败:', JSON.stringify(error));
      ToastUtils.showToast('网络异常，请重试');
    }
  }

  // 选择图片
  async selectImage() {
    const granted = await this.ensureMediaPermissions();
    if (!granted) {
      return;
    }
    try {
      const photoViewPicker = new picker.PhotoViewPicker();
      const photoSelectOptions = new picker.PhotoSelectOptions();
      photoSelectOptions.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
      photoSelectOptions.maxSelectNumber = 1;

      const photoSelectResult = await photoViewPicker.select(photoSelectOptions);
      if (photoSelectResult && photoSelectResult.photoUris && photoSelectResult.photoUris.length > 0) {
        const imageUri = photoSelectResult.photoUris[0];
        await this.sendImageMessage(imageUri);
      }
    } catch (error) {
      console.error('选择图片失败:', JSON.stringify(error));
      ToastUtils.showToast('选择图片失败');
    }
  }

  // 发送图片消息
  async sendImageMessage(imageUri: string) {
    if (!this.selectedChat) return;

    try {
      // 保存图片到应用私有目录
      const storedPath = await this.persistMedia(imageUri, 'image');
      
      const request: SendMessageRequest = {
        conversation_id: this.selectedChat.conversationId,
        content: '[图片]',
        type: 'image',
        image_url: storedPath
      };

      const response: ApiResponse = await ApiUtils.post('/messages/send', request);

      if (response.statusCode === 200 && response.data) {
        const data = response.data as SendMessageResponseData;
        const newMessage = new ChatMessage();
        newMessage.id = data.id || 0;
        newMessage.content = data.content || '[图片]';
        newMessage.time = data.time || new Date().getTime();
        newMessage.isMe = true;
        newMessage.type = 'image';
        newMessage.imageUrl = data.imageUrl || storedPath;

        if (!this.selectedChat.messages) {
          this.selectedChat.messages = [];
        }
        this.selectedChat.messages.push(newMessage);
        this.selectedChat.lastContent = '[图片]';
        this.selectedChat.lastTime = newMessage.time;

        // 刷新消息列表
        this.loadMessages();
      } else {
        // 如果API失败，对于本地示例对话，直接添加到消息列表
        if (this.selectedChat.conversationId >= 1001 && this.selectedChat.conversationId <= 1003) {
          const newMessage = new ChatMessage();
          newMessage.id = Date.now();
          newMessage.content = '[图片]';
          newMessage.time = new Date().getTime();
          newMessage.isMe = true;
          newMessage.type = 'image';
          newMessage.imageUrl = storedPath;

          if (!this.selectedChat.messages) {
            this.selectedChat.messages = [];
          }
          this.selectedChat.messages.push(newMessage);
          this.selectedChat.lastContent = '[图片]';
          this.selectedChat.lastTime = newMessage.time;
        } else {
          ToastUtils.showToast(response.message || '发送失败');
        }
      }
    } catch (error) {
      console.error('发送图片失败:', JSON.stringify(error));
      ToastUtils.showToast('网络异常，请重试');
    }
  }

  // 开始录音
  async startRecording() {
    if (!this.selectedChat) {
      ToastUtils.showToast('请先选择对话');
      return;
    }

    try {
      if (!this.context) {
        this.context = getContext(this) as common.UIAbilityContext;
      }
      if (!this.context) {
        ToastUtils.showToast('无法获取应用上下文');
        return;
      }

      // 创建录音文件路径
      const filesDir = this.context.filesDir;
      const messagesDir = `${filesDir}/messages`;
      try {
        fs.accessSync(messagesDir);
      } catch {
        fs.mkdirSync(messagesDir, true);
      }

      const fileName = `voice_${Date.now()}.m4a`;
      this.recordingFilePath = `${messagesDir}/${fileName}`;

      // 创建AudioRecorder - 暂时禁用，因为API可能不兼容
      // TODO: 根据HarmonyOS SDK版本实现正确的录音功能
      ToastUtils.showToast('录音功能暂未实现');
      return;

      this.recording = true;
      this.recordingStartTime = Date.now();
      this.recordingDuration = 0;

      // 启动计时器
      this.recordingTimer = setInterval(() => {
        this.recordingDuration = Math.floor((Date.now() - this.recordingStartTime) / 1000);
      }, 1000);

      ToastUtils.showToast('开始录音');
    } catch (error) {
      console.error('开始录音失败:', JSON.stringify(error));
      ToastUtils.showToast('录音失败，请重试');
      this.recording = false;
      if (this.audioRecorder) {
        try {
          await this.audioRecorder.release();
        } catch (e) {
          console.error('释放录音器失败:', JSON.stringify(e));
        }
        this.audioRecorder = undefined;
      }
    }
  }

  // 停止录音
  async stopRecording() {
    if (!this.recording || !this.audioRecorder) {
      return;
    }

    try {
      // 停止录音
      await this.audioRecorder.stop();
      await this.audioRecorder.release();
      this.audioRecorder = undefined;

      // 清除计时器
      if (this.recordingTimer) {
        clearInterval(this.recordingTimer);
        this.recordingTimer = undefined;
      }

      const duration = this.recordingDuration;
      this.recording = false;
      this.recordingDuration = 0;

      // 如果录音时长太短（小于1秒），取消发送
      if (duration < 1) {
        ToastUtils.showToast('录音时间太短');
        // 删除录音文件
        try {
          if (this.recordingFilePath) {
            fs.unlinkSync(this.recordingFilePath);
          }
        } catch (e) {
          console.error('删除录音文件失败:', JSON.stringify(e));
        }
        return;
      }

      // 发送语音消息
      if (this.recordingFilePath && this.selectedChat) {
        const relativePath = `messages/${this.recordingFilePath.split('/').pop()}`;
        await this.sendVoiceMessage(relativePath, duration);
      }
    } catch (error) {
      console.error('停止录音失败:', JSON.stringify(error));
      ToastUtils.showToast('录音失败，请重试');
      this.recording = false;
      this.recordingDuration = 0;
    }
  }

  // 发送语音消息
  async sendVoiceMessage(voicePath: string, duration: number) {
    if (!this.selectedChat) return;

    try {
      const request: SendMessageRequest = {
        conversation_id: this.selectedChat.conversationId,
        content: '[语音]',
        type: 'voice',
        voice_url: voicePath,
        voice_duration: duration
      };

      const response: ApiResponse = await ApiUtils.post('/messages/send', request);

      if (response.statusCode === 200 && response.data) {
        const data = response.data as SendMessageResponseData;
        const newMessage = new ChatMessage();
        newMessage.id = data.id || 0;
        newMessage.content = data.content || '[语音]';
        newMessage.time = data.time || new Date().getTime();
        newMessage.isMe = true;
        newMessage.type = 'voice';
        newMessage.voiceUrl = data.voiceUrl || voicePath;
        newMessage.voiceDuration = data.voiceDuration || duration;

        if (!this.selectedChat.messages) {
          this.selectedChat.messages = [];
        }
        this.selectedChat.messages.push(newMessage);
        this.selectedChat.lastContent = '[语音]';
        this.selectedChat.lastTime = newMessage.time;

        // 刷新消息列表
        this.loadMessages();
        ToastUtils.showToast('语音发送成功');
      } else {
        // 如果API失败，对于本地示例对话，直接添加到消息列表
        if (this.selectedChat.conversationId >= 1001 && this.selectedChat.conversationId <= 1003) {
          const newMessage = new ChatMessage();
          newMessage.id = Date.now();
          newMessage.content = '[语音]';
          newMessage.time = new Date().getTime();
          newMessage.isMe = true;
          newMessage.type = 'voice';
          newMessage.voiceUrl = voicePath;
          newMessage.voiceDuration = duration;

          if (!this.selectedChat.messages) {
            this.selectedChat.messages = [];
          }
          this.selectedChat.messages.push(newMessage);
          this.selectedChat.lastContent = '[语音]';
          this.selectedChat.lastTime = newMessage.time;
        } else {
          ToastUtils.showToast(response.message || '发送失败');
        }
      }
    } catch (error) {
      console.error('发送语音失败:', JSON.stringify(error));
      ToastUtils.showToast('网络异常，请重试');
    }
  }

  // 播放语音
  async playVoice(voiceUrl: string) {
    try {
      // 如果正在播放，先停止
      if (this.audioPlayer) {
        try {
          await this.audioPlayer.stop();
          await this.audioPlayer.release();
        } catch (e) {
          console.error('停止播放失败:', JSON.stringify(e));
        }
        this.audioPlayer = undefined;
      }

      if (!this.context) {
        this.context = getContext(this) as common.UIAbilityContext;
      }
      if (!this.context) {
        ToastUtils.showToast('无法获取应用上下文');
        return;
      }

      // 获取语音文件路径
      let filePath = voiceUrl;
      if (voiceUrl.startsWith('messages/')) {
        filePath = `${this.context.filesDir}/${voiceUrl}`;
      } else if (!voiceUrl.startsWith('/') && !voiceUrl.startsWith('file://')) {
        filePath = `${this.context.filesDir}/messages/${voiceUrl}`;
      }

      // 检查文件是否存在
      try {
        fs.accessSync(filePath);
      } catch {
        ToastUtils.showToast('语音文件不存在');
        return;
      }

      // 创建AudioPlayer - 暂时禁用，因为API可能不兼容
      // TODO: 根据HarmonyOS SDK版本实现正确的播放功能
      ToastUtils.showToast('播放功能暂未实现');
    } catch (error) {
      console.error('播放语音失败:', JSON.stringify(error));
      ToastUtils.showToast('播放失败');
      if (this.audioPlayer) {
        try {
          await this.audioPlayer.release();
        } catch (e) {
          console.error('释放播放器失败:', JSON.stringify(e));
        }
        this.audioPlayer = undefined;
      }
    }
  }

  // 选择视频
  async selectVideo() {
    const granted = await this.ensureMediaPermissions();
    if (!granted) {
      return;
    }
    try {
      const photoViewPicker = new picker.PhotoViewPicker();
      const photoSelectOptions = new picker.PhotoSelectOptions();
      photoSelectOptions.MIMEType = picker.PhotoViewMIMETypes.VIDEO_TYPE;
      photoSelectOptions.maxSelectNumber = 1;

      const photoSelectResult = await photoViewPicker.select(photoSelectOptions);
      if (photoSelectResult && photoSelectResult.photoUris && photoSelectResult.photoUris.length > 0) {
        const videoUri = photoSelectResult.photoUris[0];
        await this.sendVideoMessage(videoUri);
      }
    } catch (error) {
      console.error('选择视频失败:', JSON.stringify(error));
      ToastUtils.showToast('选择视频失败');
    }
  }

  // 发送视频消息
  async sendVideoMessage(videoUri: string) {
    if (!this.selectedChat) return;

    try {
      // 保存视频到应用私有目录
      const storedPath = await this.persistMedia(videoUri, 'video');
      
      const request: SendMessageRequest = {
        conversation_id: this.selectedChat.conversationId,
        content: '[视频]',
        type: 'video',
        video_url: storedPath
      };

      const response: ApiResponse = await ApiUtils.post('/messages/send', request);

      if (response.statusCode === 200 && response.data) {
        const data = response.data as SendMessageResponseData;
        const newMessage = new ChatMessage();
        newMessage.id = data.id || 0;
        newMessage.content = data.content || '[视频]';
        newMessage.time = data.time || new Date().getTime();
        newMessage.isMe = true;
        newMessage.type = 'video';
        newMessage.videoUrl = data.videoUrl || storedPath;

        if (!this.selectedChat.messages) {
          this.selectedChat.messages = [];
        }
        this.selectedChat.messages.push(newMessage);
        this.selectedChat.lastContent = '[视频]';
        this.selectedChat.lastTime = newMessage.time;

        // 刷新消息列表
        this.loadMessages();
      } else {
        // 如果API失败，对于本地示例对话，直接添加到消息列表
        if (this.selectedChat.conversationId >= 1001 && this.selectedChat.conversationId <= 1003) {
          const newMessage = new ChatMessage();
          newMessage.id = Date.now();
          newMessage.content = '[视频]';
          newMessage.time = new Date().getTime();
          newMessage.isMe = true;
          newMessage.type = 'video';
          newMessage.videoUrl = storedPath;

          if (!this.selectedChat.messages) {
            this.selectedChat.messages = [];
          }
          this.selectedChat.messages.push(newMessage);
          this.selectedChat.lastContent = '[视频]';
          this.selectedChat.lastTime = newMessage.time;
        } else {
          ToastUtils.showToast(response.message || '发送失败');
        }
      }
    } catch (error) {
      console.error('发送视频失败:', JSON.stringify(error));
      ToastUtils.showToast('网络异常，请重试');
    }
  }

  // 预览图片（全屏展示）
  @State showImagePreview: boolean = false;
  @State previewImageUrl: string = '';

  // 预览视频（全屏展示）
  @State showVideoPreview: boolean = false;
  @State previewVideoUrl: string = '';

  previewImage(imageUrl: string) {
    this.previewImageUrl = imageUrl;
    this.showImagePreview = true;
  }

  @Builder
  ImagePreviewDialog() {
    if (this.showImagePreview) {
      Column() {
        // 顶部信息栏 - 固定在顶部，昵称居中
        Row() {
          Image($r('app.media.back_icon'))
            .width(24)
            .height(24)
            .fillColor('#FFFFFF')
            .onClick(() => {
              this.showImagePreview = false;
            })

          Text(this.selectedChat?.username || '图片预览')
            .layoutWeight(1)
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .textAlign(TextAlign.Center)

          Blank()
            .width(24)
        }
        .width('100%')
        .padding({ top: 40, left: 16, right: 16, bottom: 12 })
        .backgroundColor('#000000')

        // 图片展示区域
        Stack({ alignContent: Alignment.Center }) {
          if (this.previewImageUrl.startsWith('app.media.')) {
            Image($r(this.previewImageUrl))
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Contain)
          } else {
            Image(this.normalizeImagePath(this.previewImageUrl))
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Contain)
          }
        }
        .layoutWeight(1)
        .width('100%')
        .onClick(() => {
          this.showImagePreview = false;
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#000000')
    }
  }

  // 播放视频（全屏展示）
  playVideo(videoUrl: string) {
    this.previewVideoUrl = videoUrl;
    this.showVideoPreview = true;
  }

  @Builder
  VideoPreviewDialog() {
    if (this.showVideoPreview) {
      Column() {
        // 顶部信息栏 - 固定在顶部，昵称居中
        Row() {
          Image($r('app.media.back_icon'))
            .width(24)
            .height(24)
            .fillColor('#FFFFFF')
            .onClick(() => {
              this.showVideoPreview = false;
            })

          Text(this.selectedChat?.username || '视频播放')
            .layoutWeight(1)
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .textAlign(TextAlign.Center)

          Blank()
            .width(24)
        }
        .width('100%')
        .padding({ top: 40, left: 16, right: 16, bottom: 12 })
        .backgroundColor('#000000')

        // 视频播放区域
        Stack({ alignContent: Alignment.Center }) {
          Video({
            src: this.normalizeImagePath(this.previewVideoUrl),
            controller: new VideoController()
          })
            .width('100%')
            .height('100%')
            .autoPlay(true)
            .controls(true)
            .objectFit(ImageFit.Contain)
        }
        .layoutWeight(1)
        .width('100%')
        .backgroundColor('#000000')
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#000000')
    }
  }

  // 本地示例对话（头像：avatar1=厨师、avatar2=客服、avatar3=用户）
  createLocalConversations(): Message[] {
    const now = Date.now();

    const chef = new Message();
    chef.id = 1001;
    chef.conversationId = 1001;
    chef.userId = 501;
    chef.username = '厨师';
    chef.avatar = 'app.media.avatar1';
    chef.isOnline = true;
    chef.messages = [
      this.createTextMsg(1, '您好，今天的新品是黑椒牛柳配烤时蔬，要尝试一下吗？', false, now - 60 * 60 * 1000),
      this.createTextMsg(2, '有无辣版吗？我不太能吃辣。', true, now - 59 * 60 * 1000),
      this.createTextMsg(3, '可以的～黑椒口味偏鲜香，不辣。也可按您口味调整。', false, now - 58 * 60 * 1000)
    ];
    chef.lastContent = chef.messages[chef.messages.length - 1].content;
    chef.lastTime = chef.messages[chef.messages.length - 1].time;
    chef.unreadCount = 0;

    const support = new Message();
    support.id = 1002;
    support.conversationId = 1002;
    support.userId = 502;
    support.username = '客服';
    support.avatar = 'app.media.avatar2';
    support.isOnline = true;
    support.messages = [
      this.createTextMsg(4, '您好，这里是客服，请问需要什么帮助？', false, now - 30 * 60 * 1000),
      this.createTextMsg(5, '我想咨询一下配送时间，大概多久能到？', true, now - 29 * 60 * 1000),
      this.createTextMsg(6, '同城平均30-45分钟，尖峰时段可能略有延迟哦～', false, now - 28 * 60 * 1000)
    ];
    support.lastContent = support.messages[support.messages.length - 1].content;
    support.lastTime = support.messages[support.messages.length - 1].time;
    support.unreadCount = 2;

    const user = new Message();
    user.id = 1003;
    user.conversationId = 1003;
    user.userId = 503;
    user.username = '用户';
    user.avatar = 'app.media.avatar3';
    user.isOnline = false;
    user.messages = [
      this.createTextMsg(7, '周末一起去尝尝店里的新甜品？', false, now - 10 * 60 * 1000),
      this.createTextMsg(8, '好呀！我看评价都不错～', true, now - 9 * 60 * 1000),
      this.createTextMsg(9, '那就这么定啦，周六下午见。', false, now - 8 * 60 * 1000)
    ];
    user.lastContent = user.messages[user.messages.length - 1].content;
    user.lastTime = user.messages[user.messages.length - 1].time;
    user.unreadCount = 0;

    return [chef, support, user];
  }

  // 便捷创建文本消息
  private createTextMsg(id: number, content: string, isMe: boolean, time: number): ChatMessage {
    const m = new ChatMessage();
    m.id = id;
    m.content = content;
    m.isMe = isMe;
    m.time = time;
    m.type = 'text';
    return m;
  }

  // 权限申请
  private async ensureMediaPermissions(): Promise<boolean> {
    if (this.mediaPermissionsGranted) {
      return true;
    }
    if (!this.atManager || !this.context) {
      try {
        this.context = getContext(this) as common.UIAbilityContext;
        this.atManager = abilityAccessCtrl.createAtManager();
      } catch (error) {
        console.error('获取上下文失败:' + JSON.stringify(error));
        return false;
      }
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

  // 保存媒体文件到应用私有目录
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
      
      // 创建messages子目录用于存储消息媒体
      const messagesDir: string = `${filesDir}/messages`;
      try {
        fs.accessSync(messagesDir);
      } catch (error) {
        // 目录不存在,创建它
        try {
          fs.mkdirSync(messagesDir, true);
        } catch (mkdirError) {
          console.error('创建messagesDir失败:' + JSON.stringify(mkdirError));
        }
      }
      
      // 生成唯一文件名
      const extension: string = this.extractExtension(sourcePath, type === 'video' ? '.mp4' : '.jpg');
      const fileName: string = `msg_${type}_${Date.now()}_${Math.floor(Math.random() * 10000)}${extension}`;
      const targetPath: string = `${messagesDir}/${fileName}`;
      
      // 复制文件到应用私有目录
      fs.copyFileSync(sourcePath, targetPath);
      
      // 返回相对路径(相对于filesDir),这样数据库只存储相对路径
      const relativePath: string = `messages/${fileName}`;
      console.log('媒体已保存到:' + targetPath + ', 相对路径:' + relativePath);
      return relativePath;
    } catch (error) {
      console.error('保存媒体文件失败:' + JSON.stringify(error));
      ToastUtils.showToast('媒体保存失败，将使用原始路径');
      return uri;
    }
  }

  // 将相对路径转换为绝对路径用于显示
  private normalizeImagePath(path: string): string {
    if (!path) {
      return '';
    }
    // 如果是app.media资源，直接返回
    if (path.startsWith('app.media.')) {
      return path;
    }
    // 如果是绝对路径，直接返回
    if (path.startsWith('/') || path.startsWith('file://')) {
      return path.startsWith('file://') ? path.replace('file://', '') : path;
    }
    // 如果是相对路径（messages/xxx），转换为绝对路径
    if (path.startsWith('messages/')) {
      if (!this.context) {
        try {
          this.context = getContext(this) as common.UIAbilityContext;
        } catch (error) {
          console.error('获取上下文失败:' + JSON.stringify(error));
          return path;
        }
      }
      if (this.context) {
        return `${this.context.filesDir}/${path}`;
      }
    }
    return path;
  }

  // 解析文件路径
  private resolveFilePath(uri: string): string {
    if (!uri) {
      return '';
    }
    if (uri.startsWith('file://')) {
      return uri.replace('file://', '');
    }
    return uri;
  }

  // 提取文件扩展名
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
}