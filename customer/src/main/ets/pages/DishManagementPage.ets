// DishManagementPage.ets
import router from '@ohos.router';

interface Dish {
  id: number;
  name: string;
  description: string;
  price: number;
  imageUrl: string;
  category: string;
  isRecommended: boolean;
  sales: number;
  status: string;
}

@Entry
@Component
struct DishManagementPage {
  @State dishes: Array<Dish> = [];
  @State selectedCategory: string = '全部';
  @State showAddDishDialog: boolean = false;
  @State editingDish: Dish | null = null;

  aboutToAppear() {
    this.loadDishes();
  }

  build() {
    Stack() {
      Column() {
        // 头部
        this.Header()

        // 分类筛选
        this.CategoryFilter()
        // 菜品列表
        List({ space: 8 }) {
          ForEach(this.dishes, (dish: Dish) => {
            ListItem() {
              this.DishItem(dish)
            }
          }, (dish: Dish) => dish.id.toString())
        }
        .layoutWeight(1)
        .width('100%')

        // 添加菜品按钮
        Button('添加菜品', { type: ButtonType.Normal, stateEffect: true })
          .width(120)
          .height(40)
          .backgroundColor('#007DFF')
          .fontColor('#FFFFFF')
          .margin(16)
          .onClick(() => {
            this.editingDish = null;
            this.showAddDishDialog = true;
          })
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F5F5F5')

      // 添加/编辑菜品对话框
      if (this.showAddDishDialog) {
        this.DishDialog()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  Header() {
    Row() {
      Image($r('app.media.back_icon'))
        .width(24)
        .height(24)
        .onClick(() => {
          router.back();
        })

      Text('菜品管理')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Image($r('app.media.search'))
        .width(24)
        .height(24)
    }
    .padding(16)
    .backgroundColor('#FFFFFF')
    .width('100%')
  }

  @Builder
  CategoryFilter() {
    Scroll() {
      Row() {
        ForEach(['全部', '热菜', '凉菜', '主食', '汤类', '饮料'], (category: string) => {
          Text(category)
            .fontSize(14)
            .fontColor(this.selectedCategory === category ? '#007DFF' : '#666666')
            .backgroundColor(this.selectedCategory === category ? '#E6F2FF' : '#F5F5F5')
            .padding({
              left: 16,
              right: 16,
              top: 8,
              bottom: 8
            })
            .borderRadius(16)
            .margin({ right: 8 })
            .onClick(() => {
              this.selectedCategory = category;
              this.filterDishes();
            })
        })
      }
      .padding(12)
    }
    .scrollBar(BarState.Off)
    .backgroundColor('#FFFFFF')
    .margin({ top: 8, left: 12, right: 12 })
    .borderRadius(8)
  }

  @Builder
  DishItem(dish: Dish) {
    Row() {
      // 菜品图片
      Image(dish.imageUrl || $r('app.media.image_gallery'))
        .width(80)
        .height(80)
        .borderRadius(8)
        .objectFit(ImageFit.Cover)

      Column() {
        Row() {
          Column() {
            Text(dish.name)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#333333')

            Text(dish.description)
              .fontSize(12)
              .fontColor('#999999')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 2 })

            Row() {
              Text('¥' + dish.price)
                .fontSize(16)
                .fontColor('#FF6B00')
                .fontWeight(FontWeight.Bold)

              Text('销量: ' + dish.sales)
                .fontSize(12)
                .fontColor('#999999')
                .margin({ left: 12 })
            }
            .margin({ top: 8 })
          }
          .layoutWeight(1)

          // 推荐标签和操作按钮
          Column() {
            if (dish.isRecommended) {
              Image($r('app.media.recommend_tag'))
                .width(40)
                .height(20)
                .margin({ bottom: 8 })
            }

            Row() {
              Image($r('app.media.edit'))
                .width(20)
                .height(20)
                .margin({ right: 12 })
                .onClick(() => {
                  this.editDish(dish);
                })

              Image($r('app.media.delete'))
                .width(20)
                .height(20)
                .onClick(() => {
                  this.deleteDish(dish);
                })
            }
          }
        }
      }
      .margin({ left: 12 })
      .layoutWeight(1)
    }
    .padding(12)
    .backgroundColor('#FFFFFF')
    .margin({ top: 4, left: 12, right: 12 })
    .borderRadius(8)
  }

  @Builder
  DishDialog() {
    Column() {
      Column() {
        // 标题和关闭按钮
        Row() {
          Text(this.editingDish ? '编辑菜品' : '添加菜品')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .layoutWeight(1)

          Image($r('app.media.delete'))
            .width(20)
            .height(20)
            .onClick(() => {
              this.showAddDishDialog = false;
              this.editingDish = null;
            })
        }
        .width('100%')
        .margin({ bottom: 20 })

        // 表单
        TextInput({ placeholder: '菜品名称', text: this.editingDish?.name || '' })
          .width('100%')
          .height(40)
          .backgroundColor('#F5F5F5')
          .borderRadius(4)
          .margin({ bottom: 12 })
          .onChange((value: string) => {
            if (this.editingDish) {
              this.editingDish.name = value;
            }
          })

        TextInput({ placeholder: '价格', text: this.editingDish?.price?.toString() || '' })
          .width('100%')
          .height(40)
          .backgroundColor('#F5F5F5')
          .borderRadius(4)
          .margin({ bottom: 12 })
          .onChange((value: string) => {
            if (this.editingDish) {
              this.editingDish.price = parseFloat(value);
            }
          })

        TextInput({ placeholder: '分类', text: this.editingDish?.category || '' })
          .width('100%')
          .height(40)
          .backgroundColor('#F5F5F5')
          .borderRadius(4)
          .margin({ bottom: 12 })
          .onChange((value: string) => {
            if (this.editingDish) {
              this.editingDish.category = value;
            }
          })

        TextInput({ placeholder: '描述', text: this.editingDish?.description || '' })
          .width('100%')
          .height(60)
          .backgroundColor('#F5F5F5')
          .borderRadius(4)
          .margin({ bottom: 12 })
          .onChange((value: string) => {
            if (this.editingDish) {
              this.editingDish.description = value;
            }
          })

        // 推荐开关
        Row() {
          Text('设为推荐菜品')
            .fontSize(14)
            .fontColor('#333333')
            .layoutWeight(1)

          Toggle({ type: ToggleType.Switch, isOn: this.editingDish?.isRecommended || false })
            .onChange((value: boolean) => {
              if (this.editingDish) {
                this.editingDish.isRecommended = value;
              }
            })
        }
        .width('100%')
        .margin({ bottom: 20 })

        // 按钮
        Row() {
          Button('取消', { type: ButtonType.Normal })
            .layoutWeight(1)
            .height(40)
            .backgroundColor('#F5F5F5')
            .fontColor('#666666')
            .margin({ right: 8 })
            .onClick(() => {
              this.showAddDishDialog = false;
              this.editingDish = null;
            })

          Button('确定', { type: ButtonType.Normal })
            .layoutWeight(1)
            .height(40)
            .backgroundColor('#007DFF')
            .fontColor('#FFFFFF')
            .margin({ left: 8 })
            .onClick(() => {
              this.saveDish();
            })
        }
        .width('100%')
      }
      .padding(20)
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
      .margin(24)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#CC000000')
    .justifyContent(FlexAlign.Center)
  }

  // 加载菜品
  loadDishes() {
    // 模拟数据
    this.dishes = [
      {
        id: 1,
        name: '宫保鸡丁',
        description: '经典川菜，麻辣鲜香',
        price: 38,
        imageUrl: '',
        category: '热菜',
        isRecommended: true,
        sales: 45,
        status: 'available'
      },
      {
        id: 2,
        name: '鱼香肉丝',
        description: '酸甜可口，下饭神器',
        price: 32,
        imageUrl: '',
        category: '热菜',
        isRecommended: false,
        sales: 38,
        status: 'available'
      }
      // 更多菜品...
    ];
  }

  // 筛选菜品
  filterDishes() {
    // 根据分类筛选菜品
  }

  // 编辑菜品
  editDish(dish: Dish) {
    this.editingDish = {
      id: dish.id,
      name: dish.name,
      description: dish.description,
      price: dish.price,
      imageUrl: dish.imageUrl,
      category: dish.category,
      isRecommended: dish.isRecommended,
      sales: dish.sales,
      status: dish.status
    };
    this.showAddDishDialog = true;
  }

  // 删除菜品
  deleteDish(dish: Dish) {
    this.dishes = this.dishes.filter(d => d.id !== dish.id);
  }

  // 保存菜品
  saveDish() {
    if (!this.editingDish) {
      return;
    }

    if (!this.editingDish.name || !this.editingDish.price || !this.editingDish.category) {
      // 显示错误提示
      return;
    }
    if (this.editingDish.id) {
      // 更新现有菜品
      const index = this.dishes.findIndex(d => d.id === this.editingDish!.id);
      if (index !== -1) {
        this.dishes[index] = {
          id: this.editingDish!.id,
          name: this.editingDish!.name,
          description: this.editingDish!.description,
          price: this.editingDish!.price,
          imageUrl: this.editingDish!.imageUrl,
          category: this.editingDish!.category,
          isRecommended: this.editingDish!.isRecommended,
          sales: this.editingDish!.sales,
          status: this.editingDish!.status
        };
      }
    } else {
      // 添加新菜品
      const newDish: Dish = {
        id: Date.now(),
        name: this.editingDish.name,
        description: this.editingDish.description,
        price: this.editingDish.price,
        imageUrl: this.editingDish.imageUrl,
        category: this.editingDish.category,
        isRecommended: this.editingDish.isRecommended,
        sales: 0,
        status: 'available'
      };
      this.dishes.push(newDish);
    }

    this.showAddDishDialog = false;
    this.editingDish = null;
  }
}