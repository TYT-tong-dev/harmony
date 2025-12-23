// AddDishPage.ets - 添加菜品页面
import { Dish, NewDishForm, ApiResponse, CreateDishRequest, AppMode } from '../common/Types';
import { ApiUtils, ToastUtils } from '../common/Utils';
import router from '@ohos.router';
import picker from '@ohos.file.picker';
import abilityAccessCtrl from '@ohos.abilityAccessCtrl';
import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';

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
export struct AddDishPage {
  @State newDish: NewDishForm = new NewDishForm();
  @StorageLink('appMode') appMode: AppMode = AppMode.MERCHANT;
  @State isLoading: boolean = false;
  @State categories: string[] = ['热菜', '凉菜', '汤品', '主食', '饮料', '甜品'];
  @State showImagePicker: boolean = false; // 是否显示图片选择对话框
  @State imageProcessing: boolean = false;

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
    if (this.appMode === AppMode.CUSTOMER) {
      ToastUtils.showToast('顾客端无法添加菜品');
      router.back();
      return;
    }
  }

  build() {
    Stack() {
      Column() {
        // 顶部导航栏
        this.TopNavigation()

        // 表单内容
        Scroll() {
          Column() {
            this.DishImageUpload()
            this.DishForm()
          }
          .padding(16)
        }
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F8FAFF')

      // 图片选择对话框
      if (this.showImagePicker) {
        this.ImagePickerDialog()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  TopNavigation() {
    Row() {
      Image($r('app.media.back_icon'))
        .width(24)
        .height(24)
        .margin({ left: 16 })
        .onClick(() => {
          router.back();
        })

      Text('添加菜品')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A1A')
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      if (this.isLoading) {
        LoadingProgress()
          .width(20)
          .height(20)
          .color('#007DFF')
          .margin({ right: 16 })
      } else {
        Text('保存')
          .fontSize(14)
          .fontColor('#007DFF')
          .margin({ right: 16 })
          .onClick(() => {
            this.saveDish();
          })
      }
    }
    .width('100%')
    .height(56)
    .backgroundColor('#FFFFFF')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  DishImageUpload() {
    Column() {
      Text('菜品照片')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#333333')
        .alignSelf(ItemAlign.Start)
        .margin({ bottom: 12 })

      Stack({ alignContent: Alignment.Center }) {
        if (this.newDish.imageUrl) {
          if (this.newDish.imageUrl.startsWith('app.media.')) {
            Image($r(this.newDish.imageUrl))
              .width('100%')
              .height(200)
              .borderRadius(12)
              .objectFit(ImageFit.Cover)
              .backgroundColor('#F5F5F5')
          } else {
            Image(this.getPreviewImageSource())
              .width('100%')
              .height(200)
              .borderRadius(12)
              .objectFit(ImageFit.Cover)
              .backgroundColor('#F5F5F5')
          }

          // 删除按钮
          Button({ type: ButtonType.Normal }) {
            Image($r('app.media.delete'))
              .width(20)
              .height(20)
              .fillColor('#FFFFFF')
          }
          .width(36)
          .height(36)
          .backgroundColor('#CC000000')
          .borderRadius(18)
          .position({ x: 0, y: 0 })
          .margin({ right: 12, top: 12 })
          .onClick(() => {
            this.newDish.imageUrl = '';
          })
        } else {
          // 未选择图片时的占位符
          Column() {
            Image($r('app.media.camera'))
              .width(48)
              .height(48)
              .fillColor('#999999')
              .margin({ bottom: 12 })
            Text('点击上传图片')
              .fontSize(14)
              .fontColor('#666666')
            Text('支持相册或拍照')
              .fontSize(12)
              .fontColor('#999999')
              .margin({ top: 4 })
          }
          .width('100%')
          .height(200)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor('#F5F5F5')
          .borderRadius(12)
          .border({
            width: 1,
            style: BorderStyle.Dashed,
            color: '#CCCCCC'
          })
        }
        if (this.imageProcessing) {
          LoadingProgress()
            .width(40)
            .height(40)
            .color('#007DFF')
        }
      }
      .width('100%')
      .onClick(() => {
        // 点击图片区域可以重新选择图片
        this.showImagePicker = true;
      })
    }
    .width('100%')
    .padding(20)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .margin({ bottom: 16 })
    .shadow({
      radius: 8,
      color: '#1A000000',
      offsetX: 0,
      offsetY: 2
    })
  }

  @Builder
  DishForm() {
    Column() {
      // 菜品名称
      Column() {
        Text('菜品名称 *')
          .fontSize(14)
          .fontColor('#333333')
          .margin({ bottom: 8 })

        TextInput({ placeholder: '请输入菜品名称', text: this.newDish.name })
          .width('100%')
          .height(44)
          .backgroundColor('#FFFFFF')
          .borderRadius(8)
          .padding(12)
          .onChange((value: string) => {
            this.newDish.name = value;
          })
      }
      .margin({ top: 16 })

      // 价格
      Column() {
        Text('价格 *')
          .fontSize(14)
          .fontColor('#333333')
          .margin({ bottom: 8 })

        TextInput({ placeholder: '0.00', text: this.newDish.price })
          .width('100%')
          .height(44)
          .backgroundColor('#FFFFFF')
          .borderRadius(8)
          .padding(12)
          .type(InputType.Number)
          .onChange((value: string) => {
            this.newDish.price = value;
          })
      }
      .margin({ top: 16 })

      // 分类
      Column() {
        Text('分类 *')
          .fontSize(14)
          .fontColor('#333333')
          .margin({ bottom: 8 })

        this.CategorySelector()
      }
      .margin({ top: 16 })

      // 描述
      Column() {
        Text('描述')
          .fontSize(14)
          .fontColor('#333333')
          .margin({ bottom: 8 })

        TextArea({ placeholder: '请输入菜品描述（可选）', text: this.newDish.description })
          .width('100%')
          .height(100)
          .backgroundColor('#F5F5F5')
          .borderRadius(8)
          .padding(12)
          .onChange((value: string) => {
            this.newDish.description = value;
          })
      }
      .margin({ top: 16 })

      // 做法
      Column() {
        Text('做法 *')
          .fontSize(14)
          .fontColor('#333333')
          .margin({ bottom: 8 })

        TextArea({ placeholder: '请输入详细做法步骤', text: this.newDish.cookingMethod })
          .width('100%')
          .height(120)
          .backgroundColor('#F5F5F5')
          .borderRadius(8)
          .padding(12)
          .onChange((value: string) => {
            this.newDish.cookingMethod = value;
          })
      }
      .margin({ top: 16 })

      // 推荐开关
      Row() {
        Text('设为推荐菜品')
          .fontSize(14)
          .fontColor('#333333')
          .layoutWeight(1)

        Toggle({
          type: ToggleType.Switch,
          isOn: this.newDish.isRecommended
        })
          .onChange((value: boolean) => {
            this.newDish.isRecommended = value;
          })
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#FFFFFF')
      .borderRadius(8)
      .margin({ top: 16 })

      // 保存按钮
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Text(this.isLoading ? '保存中...' : '保存菜品')
          .fontSize(16)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')
      .height(50)
      .backgroundColor('#007DFF')
      .borderRadius(25)
      .margin({ top: 24, bottom: 16 })
      .enabled(!this.isLoading)
      .onClick(() => {
        this.saveDish();
      })

      // 批量添加示例菜品（基于 dish1.png ~ dish5.png）
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Text('快速添加示例菜品')
          .fontSize(16)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')
      .height(44)
      .backgroundColor('#34C759')
      .borderRadius(22)
      .margin({ bottom: 8 })
      .enabled(!this.isLoading)
      .onClick(() => {
        this.addSampleDishes();
      })
    }
    .width('100%')
  }

  @Builder
  CategorySelector() {
    Scroll() {
      Row() {
        ForEach(this.categories, (category: string) => {
          Text(category)
            .fontSize(14)
            .fontColor(this.newDish.category === category ? '#FFFFFF' : '#666666')
            .backgroundColor(this.newDish.category === category ? '#007DFF' : '#F0F0F0')
            .padding({
              left: 16,
              right: 16,
              top: 10,
              bottom: 10
            })
            .borderRadius(16)
            .margin({ right: 8 })
            .onClick(() => {
              this.newDish.category = category;
            })
        })
      }
      .padding(12)
    }
    .scrollBar(BarState.Off)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
  }

  // 图片选择对话框
  @Builder
  ImagePickerDialog() {
    Column() {
      Blank()
        .layoutWeight(1)
        .onClick(() => {
          this.showImagePicker = false;
        })

      Column() {
        // 标题栏
        Row() {
          Text('选择图片')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A1A')
            .layoutWeight(1)
            .textAlign(TextAlign.Center)

          Image($r('app.media.close'))
            .width(24)
            .height(24)
            .onClick(() => {
              this.showImagePicker = false;
            })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 16, bottom: 16 })

        // 从相册选择按钮
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row() {
            Image($r('app.media.image_gallery'))
              .width(20)
              .height(20)
              .fillColor('#FFFFFF')
              .margin({ right: 8 })
            Text('从相册选择')
              .fontSize(16)
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Medium)
          }
        }
        .width('90%')
        .height(50)
        .backgroundColor('#007DFF')
        .borderRadius(25)
        .margin({ bottom: 12 })
        .onClick(() => {
          this.pickImageFromGallery();
        })

        // 拍照按钮
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row() {
            Image($r('app.media.camera'))
              .width(20)
              .height(20)
              .fillColor('#FFFFFF')
              .margin({ right: 8 })
            Text('拍照')
              .fontSize(16)
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Medium)
          }
        }
        .width('90%')
        .height(50)
        .backgroundColor('#34C759')
        .borderRadius(25)
        .margin({ bottom: 20 })
        .onClick(() => {
          this.takePhoto();
        })
      }
      .width('100%')
      .backgroundColor('#FFFFFF')
      .borderRadius({ topLeft: 20, topRight: 20 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#80000000')
    .onClick(() => {
      this.showImagePicker = false;
    })
  }

  // 从相册选择图片
  async pickImageFromGallery() {
    try {
      this.showImagePicker = false;
      const granted = await this.ensureMediaPermissions();
      if (!granted) {
        return;
      }
      const photoViewPicker = new picker.PhotoViewPicker();
      const photoSelectOptions = new picker.PhotoSelectOptions();
      photoSelectOptions.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
      photoSelectOptions.maxSelectNumber = 1;

      const photoSelectResult = await photoViewPicker.select(photoSelectOptions);
      if (photoSelectResult && photoSelectResult.photoUris && photoSelectResult.photoUris.length > 0) {
        const imageUri = photoSelectResult.photoUris[0];
        await this.handleImageSelection(imageUri);
      }
    } catch (error) {
      console.error('选择图片失败:', JSON.stringify(error));
      ToastUtils.showToast('选择图片失败，请重试');
    }
  }

  // 拍照
  async takePhoto() {
    try {
      this.showImagePicker = false;
      const granted = await this.ensureMediaPermissions();
      if (!granted) {
        return;
      }
      // 使用PhotoViewPicker，它会自动提供相册和相机选项
      const photoViewPicker = new picker.PhotoViewPicker();
      const photoSelectOptions = new picker.PhotoSelectOptions();
      photoSelectOptions.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
      photoSelectOptions.maxSelectNumber = 1;

      // PhotoViewPicker会自动显示相册和相机选项
      const photoSelectResult = await photoViewPicker.select(photoSelectOptions);
      if (photoSelectResult && photoSelectResult.photoUris && photoSelectResult.photoUris.length > 0) {
        const imageUri = photoSelectResult.photoUris[0];
        await this.handleImageSelection(imageUri);
      }
    } catch (error) {
      console.error('拍照失败:', JSON.stringify(error));
      ToastUtils.showToast('拍照失败，请重试');
    }
  }

  private async handleImageSelection(imageUri: string) {
    if (!imageUri || imageUri.length === 0) {
      return;
    }
    this.imageProcessing = true;
    try {
      // 上传图片到服务器
      const serverPath = await this.uploadImageToServer(imageUri);
      if (serverPath) {
        this.newDish.imageUrl = serverPath;
        ToastUtils.showToast('图片上传成功');
      } else {
        // 如果上传失败，回退到本地存储
        const storedPath = await this.persistDishImage(imageUri);
        this.newDish.imageUrl = storedPath;
        ToastUtils.showToast('图片已保存到本地');
      }
    } catch (error) {
      console.error('处理图片失败:' + JSON.stringify(error));
      ToastUtils.showToast('图片处理失败，请重试');
    } finally {
      this.imageProcessing = false;
    }
  }

  // 上传图片到服务器
  private async uploadImageToServer(imageUri: string): Promise<string> {
    try {
      const sourcePath = this.resolveFilePath(imageUri);
      if (!sourcePath) {
        console.error('无法解析图片路径');
        return '';
      }

      // 检查文件是否存在
      try {
        fs.accessSync(sourcePath);
      } catch (error) {
        console.error('图片文件不存在:' + sourcePath);
        return '';
      }

      // 读取文件内容
      const file = fs.openSync(sourcePath, fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(sourcePath);
      const buffer = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buffer);
      fs.closeSync(file);

      // 转为Base64
      const uint8Array = new Uint8Array(buffer);
      let binary = '';
      for (let i = 0; i < uint8Array.length; i++) {
        binary += String.fromCharCode(uint8Array[i]);
      }
      const base64Data = btoa(binary);

      // 获取文件名
      const fileName = sourcePath.split('/').pop() || `dish_${Date.now()}.jpg`;

      // 上传到服务器
      const uploadData = {
        filename: fileName,
        type: 'dishes',
        data: base64Data
      };

      const response: ApiResponse = await ApiUtils.post('/upload/base64', uploadData);
      if (response.statusCode === 200 && response.data) {
        const data = response.data as Record<string, string>;
        const serverUrl = data['url'] || '';
        if (serverUrl) {
          console.log('图片上传成功，服务器路径:' + serverUrl);
          return serverUrl;
        }
      }
      console.error('上传响应异常:' + JSON.stringify(response));
      return '';
    } catch (error) {
      console.error('上传图片到服务器失败:' + JSON.stringify(error));
      return '';
    }
  }

  // 保存菜品
  async saveDish() {
    // 验证必填字段
    if (!this.newDish.name || !this.newDish.price || !this.newDish.category || !this.newDish.cookingMethod) {
      ToastUtils.showToast('请填写完整信息（名称、价格、分类、做法必填）');
      return;
    }
    if (!this.newDish.imageUrl) {
      ToastUtils.showToast('请先上传菜品图片');
      return;
    }

    // 验证价格格式
    const price = parseFloat(this.newDish.price);
    if (isNaN(price) || price <= 0) {
      ToastUtils.showToast('价格格式不正确，请输入大于0的数字');
      return;
    }

    this.isLoading = true;

    try {
      const imagePayloadPath: string = this.normalizePayloadImagePath(this.newDish.imageUrl);
      const dishData: CreateDishRequest = {
        name: this.newDish.name,
        description: this.newDish.description || '',
        cooking_method: this.newDish.cookingMethod,
        price: price,
        category: this.newDish.category,
        is_recommended: this.newDish.isRecommended,
        shop_id: 1,
        image_url: imagePayloadPath,
        status: 'available'
      };

      const response: ApiResponse = await ApiUtils.post('/dishes/add', dishData);

      if (response.statusCode === 200) {
        ToastUtils.showToast('添加菜品成功');
        // 延迟一下再返回，让用户看到成功提示
        setTimeout(() => {
          router.back();
        }, 500);
      } else {
        ToastUtils.showToast(response.message || '添加菜品失败');
      }
    } catch (error) {
      console.error('添加菜品失败:', error);
      ToastUtils.showToast('添加菜品失败，请重试');
    } finally {
      this.isLoading = false;
    }
  }

  // 快速添加示例菜品（基于 dish1.png ~ dish5.png）
  async addSampleDishes() {
    if (this.isLoading) {
      return;
    }
    this.isLoading = true;
    try {
      const sampleDishes: Array<CreateDishRequest> = [
        {
          name: '宫保鸡丁',
          description: '经典川菜，鸡肉鲜嫩，花生香脆，微辣微甜',
          cooking_method: '鸡丁腌制入味，花生炸香后与干辣椒爆炒，再淋入糖醋酱汁收汁。',
          price: 38.00,
          category: '热菜',
          is_recommended: true,
          shop_id: 1,
          image_url: 'app.media.dish1',
          status: 'available'
        },
        {
          name: '麻婆豆腐',
          description: '四川传统名菜，豆腐嫩滑，麻辣鲜香',
          cooking_method: '豆腐焯水定型，牛肉末与豆瓣酱炒香后加入豆腐焖煮，最后撒花椒粉。',
          price: 28.00,
          category: '热菜',
          is_recommended: true,
          shop_id: 1,
          image_url: 'app.media.dish2',
          status: 'available'
        },
        {
          name: '糖醋里脊',
          description: '外酥里嫩，酸甜适口，老少皆宜',
          cooking_method: '里脊肉裹糊炸至金黄，锅中调制糖醋汁快速翻炒裹匀。',
          price: 42.00,
          category: '热菜',
          is_recommended: true,
          shop_id: 1,
          image_url: 'app.media.dish3',
          status: 'available'
        },
        {
          name: '红烧肉',
          description: '肥而不腻，入口即化，经典家常菜',
          cooking_method: '五花肉焯水后加冰糖小火慢炖，加入酱油和香料收汁。',
          price: 48.00,
          category: '热菜',
          is_recommended: true,
          shop_id: 1,
          image_url: 'app.media.dish4',
          status: 'available'
        },
        {
          name: '清蒸鲈鱼',
          description: '鲜嫩清香，营养丰富，健康美味',
          cooking_method: '鲈鱼去腥处理后铺姜丝蒸熟，淋热油和蒸鱼豉油提味。',
          price: 68.00,
          category: '热菜',
          is_recommended: false,
          shop_id: 1,
          image_url: 'app.media.dish5',
          status: 'available'
        }
      ];
      let successCount = 0;
      for (const dish of sampleDishes) {
        try {
          const resp: ApiResponse = await ApiUtils.post('/dishes/add', dish);
          if (resp.statusCode === 200) {
            successCount++;
          } else if (resp.statusCode === 401) {
            ToastUtils.showToast('请先登录后再添加示例菜品');
            break;
          } else {
            ToastUtils.showToast(resp.message || '添加示例菜品失败');
          }
        } catch (e) {
          console.error('添加示例菜品失败:', e);
        }
      }
      if (successCount > 0) {
        ToastUtils.showToast(`成功添加 ${successCount} 个示例菜品`);
        // 成功后清空当前表单
        this.newDish = new NewDishForm();
      } else {
        ToastUtils.showToast('添加示例菜品失败');
      }
    } finally {
      this.isLoading = false;
    }
  }

  private normalizePayloadImagePath(path: string): string {
    if (!path) {
      return '';
    }
    // 如果是资源引用(app.media.xxx),直接返回
    if (path.startsWith('app.media.')) {
      return path;
    }
    // 如果已经是相对路径(dishes/xxx),直接返回
    if (path.startsWith('dishes/')) {
      return path;
    }
    // 如果是绝对路径,转换为相对路径
    return this.toRelativeDishPath(path);
  }

  private getPreviewImageSource(): string {
    if (!this.newDish.imageUrl) {
      return '';
    }
    if (this.newDish.imageUrl.startsWith('app.media.')) {
      return this.newDish.imageUrl;
    }
    // 如果是服务器路径（images/开头），拼接服务器URL
    if (this.newDish.imageUrl.startsWith('images/')) {
      return `http://10.12.8.110:5000/${this.newDish.imageUrl}`;
    }
    return this.toAbsoluteDishPath(this.newDish.imageUrl);
  }

  private toRelativeDishPath(path: string): string {
    if (!path) {
      return '';
    }
    if (!this.context) {
      try {
        this.context = getContext(this) as common.UIAbilityContext;
      } catch (error) {
        console.error('获取上下文失败:' + JSON.stringify(error));
        return path;
      }
    }
    if (!this.context) {
      return path;
    }
    const filesDir: string = this.context.filesDir;
    // 如果路径以filesDir开头,提取相对路径
    if (path.startsWith(filesDir)) {
      const trimmed: string = path.substring(filesDir.length);
      return trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
    }
    // 如果路径已经是相对路径格式,直接返回
    if (!path.startsWith('/') && !path.startsWith('file://')) {
      return path;
    }
    // 其他情况返回原路径
    return path;
  }

  private toAbsoluteDishPath(path: string): string {
    if (!path) {
      return '';
    }
    const lower: string = path.toLowerCase();
    if (path.startsWith('app.media.')) {
      return path;
    }
    if (lower.startsWith('file://')) {
      return path.replace('file://', '');
    }
    if (path.startsWith('/')) {
      return path;
    }
    if (!this.context) {
      return path;
    }
    return `${this.context.filesDir}/${path}`;
  }

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

  private async persistDishImage(uri: string): Promise<string> {
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
        console.error('无法解析图片路径:' + uri);
        return uri;
      }
      
      // 检查源文件是否存在(使用try-catch)
      try {
        fs.accessSync(sourcePath);
      } catch (error) {
        console.error('源图片文件不存在:' + sourcePath);
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
      
      // 创建dishes子目录用于存储菜品图片
      const dishesDir: string = `${filesDir}/dishes`;
      try {
        fs.accessSync(dishesDir);
      } catch (error) {
        // 目录不存在,创建它
        try {
          fs.mkdirSync(dishesDir, true);
        } catch (mkdirError) {
          console.error('创建dishesDir失败:' + JSON.stringify(mkdirError));
        }
      }
      
      // 生成唯一文件名
      const extension: string = this.extractExtension(sourcePath, '.jpg');
      const fileName: string = `dish_${Date.now()}_${Math.floor(Math.random() * 10000)}${extension}`;
      const targetPath: string = `${dishesDir}/${fileName}`;
      
      // 复制文件到应用私有目录
      fs.copyFileSync(sourcePath, targetPath);
      
      // 返回相对路径(相对于filesDir),这样数据库只存储相对路径
      const relativePath: string = `dishes/${fileName}`;
      console.log('图片已保存到:' + targetPath + ', 相对路径:' + relativePath);
      return relativePath;
    } catch (error) {
      console.error('保存菜品图片失败:' + JSON.stringify(error));
      ToastUtils.showToast('图片保存失败，将使用原始路径');
      return uri;
    }
  }

  private resolveFilePath(uri: string): string {
    if (!uri) {
      return '';
    }
    if (uri.startsWith('file://')) {
      return uri.replace('file://', '');
    }
    return uri;
  }

  private extractExtension(path: string, fallback: string = '.jpg'): string {
    if (!path) {
      return fallback;
    }
    const dotIndex: number = path.lastIndexOf('.');
    if (dotIndex === -1 || dotIndex === path.length - 1) {
      return fallback;
    }
    return path.substring(dotIndex);
  }
}