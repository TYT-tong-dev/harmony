// WalletPage.ets
import promptAction from '@ohos.promptAction';

// 交易记录类
class Transaction {
  id: number = 0;
  type: string = 'income';
  title: string = '';
  amount: number = 0;
  time: number = 0;
  note: string = '';
}

@Entry
@Component
export struct WalletPage {
  @State balance: number = 1286.50;
  @State frozenAmount: number = 200.00;
  @State incomeMonth: number = 85600.00;
  @State transactions: Transaction[] = [];
  @State showAmountDialog: boolean = false;
  @State amountInput: string = '';
  @State dialogMode: string = 'recharge';

  aboutToAppear() {
    this.initMockData();
  }

  initMockData() {
    const now = Date.now();
    const tx1 = new Transaction();
    tx1.id = 1;
    tx1.type = 'income';
    tx1.title = '订单收入';
    tx1.amount = 86.00;
    tx1.time = now - 60 * 60 * 1000;

    const tx2 = new Transaction();
    tx2.id = 2;
    tx2.type = 'income';
    tx2.title = '订单收入';
    tx2.amount = 52.00;
    tx2.time = now - 2 * 60 * 60 * 1000;

    const tx3 = new Transaction();
    tx3.id = 3;
    tx3.type = 'withdraw';
    tx3.title = '提现成功';
    tx3.amount = -500.00;
    tx3.time = now - 24 * 60 * 60 * 1000;

    const tx4 = new Transaction();
    tx4.id = 4;
    tx4.type = 'refund';
    tx4.title = '售后退款';
    tx4.amount = -18.50;
    tx4.time = now - 2 * 24 * 60 * 60 * 1000;

    const tx5 = new Transaction();
    tx5.id = 5;
    tx5.type = 'income';
    tx5.title = '订单收入';
    tx5.amount = 138.00;
    tx5.time = now - 3 * 24 * 60 * 60 * 1000;

    this.transactions = [tx1, tx2, tx3, tx4, tx5];
  }

  build() {
    Column() {
      // 顶部余额卡
      this.BalanceCard()

      // 快捷操作
      this.QuickActions()

      // 交易明细
      this.TransactionList()

      if (this.showAmountDialog) {
        this.AmountDialog()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  @Builder
  BalanceCard() {
    Column() {
      Row() {
        Column() {
          Text('账户余额')
            .fontSize(14)
            .fontColor('#999999')
          Text('¥' + this.balance.toFixed(2))
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A1A')
            .margin({ top: 6 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Column({ space: 6 }) {
          Text('冻结金额')
            .fontSize(12)
            .fontColor('#999999')
            .textAlign(TextAlign.End)
          Text('¥' + this.frozenAmount.toFixed(2))
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FF6B00')
            .textAlign(TextAlign.End)
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')

      Row() {
        Text('本月收入')
          .fontSize(12)
          .fontColor('#999999')
          .layoutWeight(1)
        Text('¥' + this.incomeMonth.toFixed(2))
          .fontSize(14)
          .fontColor('#1A1A1A')
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .padding(16)
    .margin({ top: 12, left: 12, right: 12 })
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
  }

  @Builder
  QuickActions() {
    Row() {
      Button('充值', { type: ButtonType.Capsule, stateEffect: true })
        .width('46%')
        .height(40)
        .backgroundColor('#007DFF')
        .fontColor('#FFFFFF')
        .onClick(() => {
          this.dialogMode = 'recharge';
          this.amountInput = '';
          this.showAmountDialog = true;
        })

      Column()
        .width('8%')

      Button('提现', { type: ButtonType.Capsule, stateEffect: true })
        .width('46%')
        .height(40)
        .backgroundColor('#52C41A')
        .fontColor('#FFFFFF')
        .onClick(() => {
          this.dialogMode = 'withdraw';
          this.amountInput = '';
          this.showAmountDialog = true;
        })
    }
    .margin({ top: 12, left: 12, right: 12 })
  }

  @Builder
  TransactionList() {
    Column() {
      Text('交易明细')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#333333')
        .margin({ bottom: 12 })

      ForEach(this.transactions, (tx: Transaction) => {
        Row() {
          Column() {
            Text(tx.title)
              .fontSize(14)
              .fontColor('#333333')
            Text(this.formatTime(tx.time))
              .fontSize(12)
              .fontColor('#999999')
              .margin({ top: 2 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Text((tx.amount > 0 ? '+' : '') + '¥' + tx.amount.toFixed(2))
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.getAmountColor(tx.type))
        }
        .width('100%')
        .padding({ top: 10, bottom: 10 })
      }, (tx: Transaction) => tx.id.toString())
    }
    .padding(16)
    .margin({ top: 12, left: 12, right: 12, bottom: 12 })
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
  }

  @Builder
  AmountDialog() {
    Column() {
      // 遮罩
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')
        .position({ x: 0, y: 0 })
        .onClick(() => {
          this.showAmountDialog = false;
        })

      Column() {
        Text(this.dialogMode === 'recharge' ? '充值金额' : '提现金额')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1A1A1A')
          .margin({ bottom: 12 })

        TextInput({ placeholder: '请输入金额', text: this.amountInput })
          .width('100%')
          .height(44)
          .backgroundColor('#F5F5F5')
          .borderRadius(8)
          .padding({ left: 12, right: 12 })
          .onChange((v: string) => {
            this.amountInput = v;
          })

        Row() {
          Button('取消')
            .width('48%')
            .height(40)
            .backgroundColor('#EDEDED')
            .fontColor('#333333')
            .onClick(() => {
              this.showAmountDialog = false;
            })

          Column()
            .width('4%')

          Button('确定')
            .width('48%')
            .height(40)
            .backgroundColor('#007DFF')
            .fontColor('#FFFFFF')
            .onClick(() => {
              this.submitAmount();
            })
        }
        .margin({ top: 16 })
      }
      .width('80%')
      .padding(16)
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
      .position({ x: '10%', y: '35%' })
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })
  }

  submitAmount(): void {
    const value = parseFloat(this.amountInput || '0');
    if (isNaN(value) || value <= 0) {
      promptAction.showToast({ message: '请输入有效金额', duration: 2000 });
      return;
    }
    const now = Date.now();
    if (this.dialogMode === 'recharge') {
      this.balance += value;
      const newTx = new Transaction();
      newTx.id = now;
      newTx.type = 'income';
      newTx.title = '充值成功';
      newTx.amount = value;
      newTx.time = now;
      this.transactions.unshift(newTx);
      promptAction.showToast({ message: '充值成功', duration: 1500 });
    } else {
      if (value > this.balance - this.frozenAmount) {
        promptAction.showToast({ message: '可用余额不足', duration: 2000 });
        return;
      }
      this.balance -= value;
      const newTx = new Transaction();
      newTx.id = now;
      newTx.type = 'withdraw';
      newTx.title = '提现申请提交';
      newTx.amount = -value;
      newTx.time = now;
      this.transactions.unshift(newTx);
      promptAction.showToast({ message: '已提交提现申请', duration: 1500 });
    }
    this.showAmountDialog = false;
  }

  formatTime(ts: number): string {
    const d = new Date(ts);
    const yyyy = d.getFullYear();
    const mm = (d.getMonth() + 1).toString().padStart(2, '0');
    const dd = d.getDate().toString().padStart(2, '0');
    const hh = d.getHours().toString().padStart(2, '0');
    const mi = d.getMinutes().toString().padStart(2, '0');
    return `${yyyy}-${mm}-${dd} ${hh}:${mi}`;
  }

  getAmountColor(type: string): string {
    switch (type) {
      case 'income':
        return '#52C41A';
      case 'withdraw':
        return '#007DFF';
      case 'refund':
        return '#FF3B30';
      case 'expense':
      default:
        return '#666666';
    }
  }
}
