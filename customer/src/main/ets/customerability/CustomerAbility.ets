import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

const DOMAIN = 0x0000;

// 桌号信息接口
interface TableInfo {
  tableId: string;
  shopId: string;
  timestamp: number;
}

export default class CustomerAbility extends UIAbility {
  private tableInfo: TableInfo | null = null;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 设置颜色模式
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    
    // 解析桌号信息
    this.parseTableInfo(want);
    
    // 初始化顾客端数据
    AppStorage.setOrCreate('isCustomerMode', true);
    AppStorage.setOrCreate('tableId', this.tableInfo?.tableId || '');
    AppStorage.setOrCreate('shopId', this.tableInfo?.shopId || '1');
    AppStorage.setOrCreate('customerToken', '');
    AppStorage.setOrCreate('cartItems', '[]');

    hilog.info(DOMAIN, 'CustomerAbility', '%{public}s', 'Ability onCreate, tableId: ' + (this.tableInfo?.tableId || 'unknown'));
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'CustomerAbility', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'CustomerAbility', '%{public}s', 'Ability onWindowStageCreate');

    // 根据是否有桌号决定加载的页面
    const pageUrl = this.tableInfo?.tableId ? 'pages/CustomerHomePage' : 'pages/ScanTablePage';
    
    windowStage.loadContent(pageUrl, (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'CustomerAbility', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'CustomerAbility', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'CustomerAbility', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'CustomerAbility', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'CustomerAbility', '%{public}s', 'Ability onBackground');
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'CustomerAbility', '%{public}s', 'Ability onNewWant');
    // 重新解析桌号（可能是从另一个桌子扫码）
    this.parseTableInfo(want);
    if (this.tableInfo?.tableId) {
      AppStorage.setOrCreate('tableId', this.tableInfo.tableId);
      AppStorage.setOrCreate('shopId', this.tableInfo.shopId);
    }
  }

  /**
   * 解析桌号信息
   * 支持多种URL格式：
   * 1. atomicservice://com.atomicservice.6917591161906879671?tableId=A01&shopId=1
   * 2. https://6917591161906879671.atomicservice.com/table?tableId=A01&shopId=1
   */
  private parseTableInfo(want: Want): void {
    const uri = want.uri;
    const params = want.parameters as Record<string, Object> | undefined;
    
    // 先尝试从parameters中获取
    if (params) {
      const tableId = params['tableId'] as string | undefined;
      const shopId = params['shopId'] as string | undefined;
      if (tableId) {
        this.tableInfo = {
          tableId: tableId,
          shopId: shopId || '1',
          timestamp: Date.now()
        };
        return;
      }
    }
    
    // 从URI中解析
    if (uri) {
      this.tableInfo = this.parseTableInfoFromUri(uri);
    }
  }

  private parseTableInfoFromUri(uri: string): TableInfo | null {
    try {
      const queryStart = uri.indexOf('?');
      if (queryStart === -1) {
        return null;
      }
      
      const queryString = uri.substring(queryStart + 1);
      const params = new Map<string, string>();
      
      queryString.split('&').forEach((pair: string) => {
        const eqIndex = pair.indexOf('=');
        if (eqIndex > 0) {
          const key = pair.substring(0, eqIndex);
          const value = decodeURIComponent(pair.substring(eqIndex + 1));
          params.set(key, value);
        }
      });
      
      const tableId = params.get('tableId');
      if (!tableId) {
        return null;
      }
      
      return {
        tableId: tableId,
        shopId: params.get('shopId') || '1',
        timestamp: Date.now()
      };
    } catch (error) {
      hilog.error(DOMAIN, 'CustomerAbility', 'Failed to parse URI: %{public}s', JSON.stringify(error));
      return null;
    }
  }
}

