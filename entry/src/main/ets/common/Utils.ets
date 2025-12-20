// Utils.ets
import prompt from '@ohos.promptAction';
import router from '@ohos.router';
import http from '@ohos.net.http';
import { BusinessError } from '@ohos.base';
import { ApiResponse, ApiResponseData, AppMode, Dish, PaginationData, Post, TableQRCodePayload } from './Types';

// 应用模式切换时的可选参数
export interface AppModeOptions {
  tableId?: string;
  silent?: boolean;
}

export class ToastUtils {
  static showToast(message: string): void {
    try {
      prompt.showToast({
        message: message,
        duration: 2000
      });
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      console.error('Show toast error: ' + JSON.stringify(err));
    }
  }
}

export class RouterUtils {
  static pushUrl(url: string): void {
    try {
      router.pushUrl({
        url: url
      } as router.RouterOptions).then(() => {
        console.log('pushUrl success');
      }).catch((err: BusinessError) => {
        console.error('Push url error: ' + JSON.stringify(err));
      });
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      console.error('Push url error: ' + JSON.stringify(err));
    }
  }

  static replaceUrl(url: string): void {
    try {
      router.replaceUrl({
        url: url
      } as router.RouterOptions).then(() => {
        console.log('replaceUrl success');
      }).catch((err: BusinessError) => {
        console.error('Replace url error: ' + JSON.stringify(err));
      });
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      console.error('Replace url error: ' + JSON.stringify(err));
    }
  }

  static back(): void {
    try {
      router.back();
    } catch (error) {
      const err: BusinessError = error as BusinessError;
      console.error('Back error: ' + JSON.stringify(err));
    }
  }
}

export class AppModeManager {
  private static readonly MODE_KEY: string = 'appMode';
  private static readonly TABLE_KEY: string = 'currentTableId';
  private static readonly CUSTOMER_SESSION_KEY: string = 'customerGuestMode';

  static ensureInitialized(): void {
    if (!AppModeManager.hasKey(AppModeManager.MODE_KEY)) {
      AppStorage.setOrCreate<AppMode>(AppModeManager.MODE_KEY, AppMode.MERCHANT);
    }
    if (!AppModeManager.hasKey(AppModeManager.TABLE_KEY)) {
      AppStorage.setOrCreate<string>(AppModeManager.TABLE_KEY, '');
    }
    if (!AppModeManager.hasKey(AppModeManager.CUSTOMER_SESSION_KEY)) {
      AppStorage.setOrCreate<boolean>(AppModeManager.CUSTOMER_SESSION_KEY, false);
    }
  }

  static getMode(): AppMode {
    AppModeManager.ensureInitialized();
    return AppStorage.get<AppMode>(AppModeManager.MODE_KEY) || AppMode.MERCHANT;
  }

  static isCustomerMode(): boolean {
    return AppModeManager.getMode() === AppMode.CUSTOMER;
  }

  static setMode(mode: AppMode, options?: AppModeOptions): void {
    AppModeManager.ensureInitialized();
    AppStorage.setOrCreate<AppMode>(AppModeManager.MODE_KEY, mode);
    if (mode === AppMode.CUSTOMER) {
      AppStorage.setOrCreate<string>(AppModeManager.TABLE_KEY, options?.tableId || '');
      AppStorage.setOrCreate<boolean>(AppModeManager.CUSTOMER_SESSION_KEY, true);
    } else {
      AppStorage.setOrCreate<string>(AppModeManager.TABLE_KEY, '');
      AppStorage.setOrCreate<boolean>(AppModeManager.CUSTOMER_SESSION_KEY, false);
    }
    if (!options?.silent) {
      console.info(`App mode switched to ${mode}`);
    }
  }

  static getCurrentTableId(): string {
    AppModeManager.ensureInitialized();
    return AppStorage.get<string>(AppModeManager.TABLE_KEY) || '';
  }

  static isCustomerSessionActive(): boolean {
    AppModeManager.ensureInitialized();
    return AppStorage.get<boolean>(AppModeManager.CUSTOMER_SESSION_KEY) || false;
  }

  private static hasKey(key: string): boolean {
    // ArkTS 对反射和 AppStorage 作为普通对象的用法有限制，这里采用直接读取值的方式判断
    const value: AppMode | string | boolean | null = AppStorage.get(key) as AppMode | string | boolean | null;
    return value !== undefined && value !== null;
  }
}

export class DeepLinkUtils {
  // 旧版Deep Link（兼容）
  static readonly TABLE_LINK_SCHEME: string = 'catering-app://table';
  // 元服务Deep Link（推荐）- 华为AGC平台注册的元服务
  static readonly ATOMIC_SERVICE_HOST: string = '6917591161906879671.atomicservice.com';
  static readonly ATOMIC_SERVICE_SCHEME: string = 'atomicservice://com.atomicservice.6917591161906879671';

  static buildTablePayload(tableId: string): TableQRCodePayload {
    return {
      mode: AppMode.CUSTOMER,
      tableId,
      nonce: `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
      issuedAt: Date.now()
    };
  }

  static encodePayload(payload: TableQRCodePayload): string {
    try {
      return JSON.stringify(payload);
    } catch (error) {
      console.error('Encode payload error: ' + JSON.stringify(error));
      return '';
    }
  }

  /**
   * 构建元服务Deep Link（推荐使用）
   * 格式: https://shiguangji.atomicservice.com/table?tableId=A01&shopId=1
   */
  static buildAtomicServiceLink(tableId: string, shopId: string = '1'): string {
    return `https://${DeepLinkUtils.ATOMIC_SERVICE_HOST}/table?tableId=${encodeURIComponent(tableId)}&shopId=${encodeURIComponent(shopId)}`;
  }

  /**
   * 构建桌号Deep Link
   * 优先使用元服务链接，兼容旧版链接
   */
  static buildTableDeepLink(tableId: string, useAtomicService: boolean = true): string {
    if (useAtomicService) {
      return DeepLinkUtils.buildAtomicServiceLink(tableId);
    }
    const payload = DeepLinkUtils.buildTablePayload(tableId);
    const encoded = encodeURIComponent(DeepLinkUtils.encodePayload(payload));
    return `${DeepLinkUtils.TABLE_LINK_SCHEME}?payload=${encoded}`;
  }

  static parsePayload(raw?: string): TableQRCodePayload | undefined {
    if (!raw) {
      return undefined;
    }
    try {
      const decoded = decodeURIComponent(raw);
      return JSON.parse(decoded) as TableQRCodePayload;
    } catch (error) {
      console.error('Parse payload error: ' + JSON.stringify(error));
      return undefined;
    }
  }

  static resolveFromWantParameters(params?: Record<string, Object>): TableQRCodePayload | undefined {
    if (!params) {
      return undefined;
    }
    if (params['payload'] && typeof params['payload'] === 'string') {
      return DeepLinkUtils.parsePayload(params['payload']);
    }
    if (params['tableId']) {
      return {
        mode: AppMode.CUSTOMER,
        tableId: String(params['tableId']),
        nonce: `${Date.now()}`,
        issuedAt: Date.now()
      };
    }
    return undefined;
  }

  static resolveFromUri(uri?: string): TableQRCodePayload | undefined {
    if (!uri) {
      return undefined;
    }
    try {
      const query: string = uri.split('?')[1];
      if (!query) {
        return undefined;
      }
      const params: Map<string, string> = new Map<string, string>();
      query.split('&').forEach((pair: string) => {
        const segments: string[] = pair.split('=');
        const key: string = segments.length > 0 ? segments[0] : '';
        const value: string = segments.length > 1 ? segments[1] : '';
        if (key && value) {
          params.set(key, value);
        }
      });
      const payloadParam: string | undefined = params.get('payload');
      if (payloadParam) {
        return DeepLinkUtils.parsePayload(payloadParam);
      }
      return undefined;
    } catch (error) {
      console.error('Parse deep link uri error: ' + JSON.stringify(error));
      return undefined;
    }
  }
}

// 购物车同步管理
export class CartSyncManager {
  // 更新购物车数量
  static updateCartQuantity(quantity: number): void {
    AppStorage.setOrCreate<number>('cartItemCount', quantity);
  }

  // 获取购物车数量
  static getCartQuantity(): number {
    return AppStorage.get<number>('cartItemCount') || 0;
  }

  // 更新购物车总金额
  static updateCartTotalAmount(amount: number): void {
    AppStorage.setOrCreate<number>('cartTotalAmount', amount);
  }

  // 获取购物车总金额
  static getCartTotalAmount(): number {
    return AppStorage.get<number>('cartTotalAmount') || 0;
  }
}

export class LocalCartItem {
  id: number = 0;
  name: string = '';
  price: number = 0;
  quantity: number = 0;
  imageUrl: string = '';
  description: string = '';
}

export class LocalCartSummary {
  quantity: number = 0;
  amount: number = 0;
}

export class LocalCartManager {
  private static readonly STORAGE_KEY: string = 'localCartItems';

  private static readRawStorage(): string {
    const storedValue = AppStorage.get(LocalCartManager.STORAGE_KEY) as string | LocalCartItem[] | null | undefined;
    if (typeof storedValue === 'string') {
      return storedValue;
    }
    if (Array.isArray(storedValue)) {
      try {
        const migrated: string = JSON.stringify(storedValue as LocalCartItem[]);
        AppStorage.setOrCreate<string>(LocalCartManager.STORAGE_KEY, migrated);
        return migrated;
      } catch (error) {
        console.error('序列化本地购物车失败:' + JSON.stringify(error));
        return '[]';
      }
    }
    return '[]';
  }

  static getItems(): LocalCartItem[] {
    const raw: string = LocalCartManager.readRawStorage();
    try {
      const parsed: LocalCartItem[] = JSON.parse(raw) as LocalCartItem[];
      if (!Array.isArray(parsed)) {
        return [];
      }
      const result: LocalCartItem[] = [];
      for (const item of parsed) {
        result.push(LocalCartManager.cloneItem(item));
      }
      return result;
    } catch (error) {
      console.error('解析本地购物车失败:' + JSON.stringify(error));
      return [];
    }
  }

  static saveItems(items: LocalCartItem[]): void {
    const clonedItems: LocalCartItem[] = [];
    for (const item of items) {
      clonedItems.push(LocalCartManager.cloneItem(item));
    }
    try {
      const payload: string = JSON.stringify(clonedItems);
      AppStorage.setOrCreate<string>(LocalCartManager.STORAGE_KEY, payload);
    } catch (error) {
      console.error('保存本地购物车失败:' + JSON.stringify(error));
    }
  }

  static clear(): void {
    AppStorage.setOrCreate<string>(LocalCartManager.STORAGE_KEY, '[]');
    CartSyncManager.updateCartQuantity(0);
    CartSyncManager.updateCartTotalAmount(0);
  }

  static addDish(dish: Dish, quantity: number = 1): void {
    const items: LocalCartItem[] = LocalCartManager.getItems();
    const existing = items.find(item => item.id === dish.id);
    if (existing) {
      existing.quantity += quantity;
    } else {
      const newItem = new LocalCartItem();
      newItem.id = dish.id;
      newItem.name = dish.name;
      newItem.price = dish.price;
      newItem.quantity = quantity;
      newItem.imageUrl = dish.imageUrl;
      newItem.description = dish.description;
      items.push(newItem);
    }
    LocalCartManager.saveItems(items);
    const summary = LocalCartManager.getSummary();
    CartSyncManager.updateCartQuantity(summary.quantity);
    CartSyncManager.updateCartTotalAmount(summary.amount);
  }

  static getSummary(): LocalCartSummary {
    const items: LocalCartItem[] = LocalCartManager.getItems();
    const summary = new LocalCartSummary();
    for (const item of items) {
      summary.quantity += item.quantity;
      summary.amount += item.quantity * item.price;
    }
    return summary;
  }

  private static cloneItem(source: LocalCartItem): LocalCartItem {
    const target = new LocalCartItem();
    target.id = source.id;
    target.name = source.name;
    target.price = source.price;
    target.quantity = source.quantity;
    target.imageUrl = source.imageUrl;
    target.description = source.description;
    return target;
  }
}
// API 工具类 - 连接后端MySQL数据库API
export class ApiUtils {
  // 后端API基础URL - 根据实际情况修改
  private static readonly BASE_URL: string = 'http://10.12.8.110:5000/api';
  
  // 获取用户token
  private static getToken(): string {
    return AppStorage.get<string>('userToken') || '';
  }

  // GET 请求
  static async get(url: string): Promise<ApiResponse> {
    return new Promise((resolve, reject) => {
      const httpRequest = http.createHttp();
      const token = ApiUtils.getToken();
      
      httpRequest.request(ApiUtils.BASE_URL + url, {
        method: http.RequestMethod.GET,
        header: {
          'Content-Type': 'application/json',
          'Authorization': token ? `Bearer ${token}` : ''
        },
        connectTimeout: 10000,
        readTimeout: 10000
      }).then((data: http.HttpResponse) => {
        if (data.responseCode === 200) {
          try {
          const response = JSON.parse(data.result.toString()) as ApiResponse;
          resolve(response);
          } catch (e) {
            reject(new Error('解析响应失败'));
          }
        } else {
          reject(new Error(`请求失败: ${data.responseCode}`));
        }
      }).catch((err: BusinessError) => {
        console.error('HTTP GET请求失败:', JSON.stringify(err));
        // 如果网络请求失败,返回模拟数据作为降级方案
        const mockResponse: ApiResponse = {
          statusCode: 200,
          message: 'Success',
          data: {
          posts: [],
          pagination: {
            page: 1,
            limit: 10,
            total: 0,
            pages: 1
          }
          }
        };
        resolve(mockResponse);
      }).finally(() => {
        httpRequest.destroy();
      });
    });
  }

  // POST 请求
  static async post(url: string, data: object): Promise<ApiResponse> {
    return new Promise((resolve, reject) => {
      const httpRequest = http.createHttp();
      const token = ApiUtils.getToken();
      
      httpRequest.request(ApiUtils.BASE_URL + url, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': token ? `Bearer ${token}` : ''
        },
        extraData: JSON.stringify(data),
        connectTimeout: 10000,
        readTimeout: 10000
      }).then((data: http.HttpResponse) => {
        if (data.responseCode === 200) {
          try {
            const response = JSON.parse(data.result.toString()) as ApiResponse;
            resolve(response);
          } catch (e) {
            reject(new Error('解析响应失败'));
          }
        } else {
          reject(new Error(`请求失败: ${data.responseCode}`));
        }
      }).catch((err: BusinessError) => {
        console.error('HTTP POST请求失败:', JSON.stringify(err));
        // 如果网络请求失败,返回模拟数据作为降级方案
        const mockResponse: ApiResponse = {
          statusCode: 200,
          message: 'Success',
          data: undefined
        };
        resolve(mockResponse);
      }).finally(() => {
        httpRequest.destroy();
      });
    });
  }

  // PUT 请求
  static async put(url: string, data: object): Promise<ApiResponse> {
    return new Promise((resolve, reject) => {
      const httpRequest = http.createHttp();
      const token = ApiUtils.getToken();
      
      httpRequest.request(ApiUtils.BASE_URL + url, {
        method: http.RequestMethod.PUT,
        header: {
          'Content-Type': 'application/json',
          'Authorization': token ? `Bearer ${token}` : ''
        },
        extraData: JSON.stringify(data),
        connectTimeout: 10000,
        readTimeout: 10000
      }).then((data: http.HttpResponse) => {
        if (data.responseCode === 200) {
          try {
            const response = JSON.parse(data.result.toString()) as ApiResponse;
            resolve(response);
          } catch (e) {
            reject(new Error('解析响应失败'));
          }
        } else {
          reject(new Error(`请求失败: ${data.responseCode}`));
        }
      }).catch((err: BusinessError) => {
        console.error('HTTP PUT请求失败:', JSON.stringify(err));
        reject(err);
      }).finally(() => {
        httpRequest.destroy();
      });
    });
  }

  // DELETE 请求
  static async delete(url: string): Promise<ApiResponse> {
    return new Promise((resolve, reject) => {
      const httpRequest = http.createHttp();
      const token = ApiUtils.getToken();

      httpRequest.request(ApiUtils.BASE_URL + url, {
        method: http.RequestMethod.DELETE,
        header: {
          'Content-Type': 'application/json',
          'Authorization': token ? `Bearer ${token}` : ''
        },
        connectTimeout: 10000,
        readTimeout: 10000
      }).then((data: http.HttpResponse) => {
        if (data.responseCode === 200) {
          try {
            const response = JSON.parse(data.result.toString()) as ApiResponse;
            resolve(response);
          } catch (e) {
            reject(new Error('解析响应失败'));
          }
        } else {
          reject(new Error(`请求失败: ${data.responseCode}`));
        }
      }).catch((err: BusinessError) => {
        console.error('HTTP DELETE请求失败:', JSON.stringify(err));
        reject(err);
      }).finally(() => {
        httpRequest.destroy();
      });
    });
  }
}