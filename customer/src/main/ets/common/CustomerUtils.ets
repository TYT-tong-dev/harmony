// CustomerUtils.ets - 顾客端工具类
import { http } from '@kit.NetworkKit';
import { promptAction } from '@kit.ArkUI';

// API响应接口
export interface ApiResponse {
  statusCode: number;
  data?: object;
  message?: string;
}

// 请求体接口
interface OrderRequestBody {
  tableId: string;
  items: object[];
  remark: string;
}

interface SessionRequestBody {
  tableId: string;
}

// 顾客端API工具类
const API_BASE_URL: string = 'http://10.52.131.181:5000';

export class CustomerApiUtils {
  // 获取菜品列表（使用和商家端相同的接口）
  static async getDishes(): Promise<ApiResponse> {
    return await CustomerApiUtils.request('/api/dishes/list', 'GET', undefined);
  }

  // 获取菜品详情
  static async getDishDetail(dishId: number): Promise<ApiResponse> {
    return await CustomerApiUtils.request('/api/dishes/' + dishId, 'GET', undefined);
  }

  // 提交订单（使用标准订单接口）
  static async submitOrder(tableId: string, items: object[], remark: string): Promise<ApiResponse> {
    const body: OrderRequestBody = {
      tableId: tableId,
      items: items,
      remark: remark
    };
    return await CustomerApiUtils.request('/api/orders/create', 'POST', body);
  }

  // 创建临时会话
  static async createSession(tableId: string): Promise<ApiResponse> {
    const body: SessionRequestBody = {
      tableId: tableId
    };
    return await CustomerApiUtils.request('/api/customer/session', 'POST', body);
  }

  // 获取订单状态
  static async getOrderStatus(orderId: number): Promise<ApiResponse> {
    return await CustomerApiUtils.request('/api/customer/order/' + orderId + '/status', 'GET', undefined);
  }

  // 通用请求方法
  private static async request(path: string, method: string, body: object | undefined): Promise<ApiResponse> {
    const httpRequest = http.createHttp();
    try {
      const token = AppStorage.get<string>('customerToken') || '';
      const options: http.HttpRequestOptions = {
        method: method === 'POST' ? http.RequestMethod.POST : http.RequestMethod.GET,
        header: {
          'Content-Type': 'application/json',
          'Authorization': token ? 'Bearer ' + token : ''
        },
        extraData: body ? JSON.stringify(body) : undefined
      };

      const response = await httpRequest.request(API_BASE_URL + path, options);
      const result = JSON.parse(response.result as string) as ApiResponse;
      const apiResponse: ApiResponse = {
        statusCode: response.responseCode,
        data: result.data,
        message: result.message
      };
      return apiResponse;
    } catch (error) {
      console.error('CustomerApiUtils request error:', JSON.stringify(error));
      const errorResponse: ApiResponse = {
        statusCode: 500,
        message: '网络请求失败'
      };
      return errorResponse;
    } finally {
      httpRequest.destroy();
    }
  }
}

// Toast工具类
export class CustomerToastUtils {
  static show(message: string): void {
    promptAction.showToast({
      message: message,
      duration: 2000
    });
  }

  static showSuccess(message: string): void {
    promptAction.showToast({
      message: '✓ ' + message,
      duration: 2000
    });
  }

  static showError(message: string): void {
    promptAction.showToast({
      message: '✗ ' + message,
      duration: 2000
    });
  }
}

// 数据接口
export interface DishData {
  id: number;
  name: string;
  price: number;
  image_url: string;
  category: string;
  description: string;
  rating: number;
  sales: number;
}

export class CartItemData {
  dish: DishData;
  quantity: number;

  constructor(dish: DishData, quantity: number) {
    this.dish = dish;
    this.quantity = quantity;
  }
}

// 购物车Key常量
const CART_STORAGE_KEY: string = 'cartItems';

// 购物车管理类
export class CartManager {
  static getItems(): CartItemData[] {
    const cartJson = AppStorage.get<string>(CART_STORAGE_KEY) || '[]';
    return JSON.parse(cartJson) as CartItemData[];
  }

  static addItem(dish: DishData, quantity: number = 1): void {
    const items = CartManager.getItems();
    const existingIndex = items.findIndex((item: CartItemData) => item.dish.id === dish.id);
    if (existingIndex >= 0) {
      items[existingIndex].quantity += quantity;
      if (items[existingIndex].quantity <= 0) {
        items.splice(existingIndex, 1);
      }
    } else if (quantity > 0) {
      const newItem = new CartItemData(dish, quantity);
      items.push(newItem);
    }
    AppStorage.setOrCreate(CART_STORAGE_KEY, JSON.stringify(items));
  }

  static clear(): void {
    AppStorage.setOrCreate(CART_STORAGE_KEY, '[]');
  }

  static getTotalPrice(): number {
    const items = CartManager.getItems();
    let total: number = 0;
    for (const item of items) {
      total += item.dish.price * item.quantity;
    }
    return total;
  }

  static getTotalQuantity(): number {
    const items = CartManager.getItems();
    let total: number = 0;
    for (const item of items) {
      total += item.quantity;
    }
    return total;
  }
}

