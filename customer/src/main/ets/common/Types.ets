// Types.ets
export class ShopInfo {
  id: number = 0;
  shop_name?: string = '';
  name: string = '食光记';
  description?: string = '';
  score: number = 4.8;
  business_hours?: string = '';
  businessHours: string = '09:00-22:00';
  address: string = '宁夏大学中卫校区';
  phone: string = '13800138000';
  todayOrders: number = 45;
  todayRevenue: number = 2860.50;
  created_at?: string = '';
  updated_at?: string = '';
  latitude?: number = 37.5149;
  longitude?: number = 105.1965;
}

export enum AppMode {
  MERCHANT = 'merchant',
  CUSTOMER = 'customer'
}

export interface TableQRCodePayload {
  mode: AppMode;
  tableId: string;
  nonce: string;
  issuedAt: number;
}

// 桌位信息
export interface TableInfo {
  id: number;
  table_number: string;
  table_name: string;
  capacity: number;
  status: string;
  qr_code_url?: string;
  created_at?: string;
  updated_at?: string;
}

export class Dish {
  id: number = 0;
  name: string = '';
  description: string = '';
  cookingMethod: string = '';
  price: number = 0;
  imageUrl: string = '';
  category: string = '';
  isRecommended: boolean = false;
  sales: number = 0;
  status: string = 'available';
  quantity: number = 0;
  rating: number = 4.8;
  reviewCount: number = 0;
  ingredients: string = '';
  cookTime: string = '';
  flavorTags: string[] = [];
  // 额外展示属性
  tags: string[] = [];
  isSignature: boolean = false;
  isNew: boolean = false;
}

export class NewDishForm {
  name: string = '';
  description: string = '';
  cookingMethod: string = '';
  price: string = '';
  category: string = '';
  imageUrl: string = '';
  isRecommended: boolean = false;
}

export class CartItem {
  dish: Dish = new Dish();
  quantity: number = 0;
}

export interface PaginationData {
  page: number;
  limit: number;
  total: number;
  pages: number;
}

export interface ApiResponseData {
  posts?: Post[];
  pagination?: PaginationData;
}

// 店铺信息响应数据
export interface ShopInfoResponse {
  id?: number;
  shop_name?: string;
  name?: string;
  description?: string;
  business_hours?: string;
  address?: string;
  phone?: string;
  score?: number;
  todayOrders?: number;
  todayRevenue?: number;
  latitude?: number;
  longitude?: number;
}

// 菜品列表响应数据
export interface DishListResponse {
  id?: number;
  name?: string;
  description?: string;
  cooking_method?: string;
  price?: number | string;
  image_url?: string;
  category?: string;
  is_recommended?: boolean;
  sales?: number;
  status?: string;
  rating?: number;
  review_count?: number;
  ingredients?: string;
  cook_time?: string;
  flavor_tags?: string[];
}

export interface ApiResponse {
  statusCode: number;
  message: string;
  data?: ApiResponseData | ShopInfoResponse | DishListResponse[] | CartResponse | Record<string, Object>;
}

export interface CartResponse {
  items: CartItemData[];
  total_amount: number;
  total_quantity: number;
}

export interface CartItemData {
  dish_id: number;
  quantity: number;
  name: string;
  price: number;
  image_url: string;
  description: string;
}

export interface RouterParams {
  url: string;
}

export interface AddToCartRequest {
  dish_id: number;
  quantity: number;
}

export interface ClearCartRequest {
  // 空接口，用于类型检查
}

export interface CreateDishRequest {
  name: string;
  description: string;
  cooking_method: string;
  price: number;
  category: string;
  is_recommended: boolean;
  shop_id: number;
  image_url: string;
  status: string;
}

export interface CreateOrderRequest {
  items: OrderItemData[];
}

export interface OrderItemData {
  dish_id: number;
  quantity: number;
}

export interface CartItemMapping {
  dish: Dish;
  quantity: number;
}

export interface DishReview {
  id: number;
  user: string;
  avatar?: string;
  rating: number;
  content: string;
  createdAt: number;
  highlights?: string[];
}

// 购物车同步状态
export class CartSyncState {
  totalQuantity: number = 0;
  totalAmount: number = 0;
  lastUpdate: number = 0;
}

// 消息相关类型
export class ChatMessage {
  id: number = 0;
  content: string = '';
  time: number = 0;
  isMe: boolean = false;
  type: 'text' | 'image' | 'video' | 'voice' = 'text';
  imageUrl?: string = '';
  videoUrl?: string = '';
  voiceUrl?: string = '';
  voiceDuration?: number = 0;
}

export class Message {
  id: number = 0;
  username: string = '';
  avatar: string = '';
  lastContent: string = '';
  lastTime: number = 0;
  unreadCount: number = 0;
  isOnline: boolean = false;
  messages: ChatMessage[] = [];
  userId: number = 0; // 对方用户ID
  conversationId: number = 0; // 会话ID
}

// 会话列表响应
export class ConversationListResponse {
  conversations: Message[] = [];
}

// 消息列表响应
export class MessageListResponse {
  messages: ChatMessage[] = [];
}

// 发送消息请求
export interface SendMessageRequest {
  conversation_id: number;
  content: string;
  type: 'text' | 'image' | 'video' | 'voice';
  image_url?: string;
  video_url?: string;
  voice_url?: string;
  voice_duration?: number;
}

// 创建会话请求
export interface CreateConversationRequest {
  user_id: number;
}

// 搜索用户响应
export class UserSearchResponse {
  users: UserInfo[] = [];
}

// 会话列表响应数据（API返回格式）
export interface ConversationListResponseData {
  conversations?: ConversationItemData[];
}

// 会话项数据（API返回格式）
export interface ConversationItemData {
  id?: number;
  conversationId?: number;
  userId?: number;
  username?: string;
  avatar?: string;
  lastContent?: string;
  lastTime?: number;
  unreadCount?: number;
  isOnline?: boolean;
}

// 消息列表响应数据（API返回格式）
export interface MessageListResponseData {
  messages?: ChatMessageItemData[];
}

// 聊天消息项数据（API返回格式）
export interface ChatMessageItemData {
  id?: number;
  content?: string;
  time?: number;
  isMe?: boolean;
  type?: 'text' | 'image' | 'video' | 'voice';
  imageUrl?: string;
  videoUrl?: string;
  voiceUrl?: string;
  voiceDuration?: number;
}

// 发送消息响应数据
export interface SendMessageResponseData {
  id?: number;
  content?: string;
  time?: number;
  type?: 'text' | 'image' | 'video' | 'voice';
  imageUrl?: string;
  videoUrl?: string;
  voiceUrl?: string;
  voiceDuration?: number;
}

// 用户信息相关类型
export class UserInfo {
  username: string = '';
  avatar: string = '';
  shopName: string = '';
  email: string = '';
  type: string = '';
  id: number = 0;
  address?: string = '';
}

// 销售最多的菜品信息
export interface TopDish {
  id: number;
  name: string;
  image_url: string;
  total_sold: number;
}

// 销售统计信息
export class SalesStats {
  total_revenue: number = 0;
  total_quantity: number = 0;
  top_dish?: TopDish = undefined;
}

export class Stats {
  todayOrders: number = 0;
  weekOrders: number = 0;
  monthRevenue: number = 0;
  totalCustomers: number = 0;
}

export class Order {
  id: number = 0;
  customerName: string = '';
  phone: string = '';
  totalAmount: number = 0;
  itemCount: number = 0;
  createTime: number = 0;
  status: string = '';
  items: OrderItem[] = [];
}

export class OrderItem {
  dishId: number = 0;
  dishName: string = '';
  quantity: number = 0;
  price: number = 0;
}

// 发现页面相关类型
export class Post {
  id: number = 0;
  user_id: number = 0;
  username: string = '';
  avatar: string = '';
  content: string = '';
  images: string[] = [];
  videos: string[] = [];
  likeCount: number = 0;
  commentCount: number = 0;
  isLiked: boolean = false;
  isFollowed: boolean = false;
  createTime: number = 0;
  title: string = '';
  imageUrls: string = '';
}

export class NewPostForm {
  content: string = '';
  images: string[] = [];
  videos: string[] = [];
}

// 主页面标签项类型
export class TabItem {
  index: number = 0;
  name: string = '';
  icon: Resource = $r('app.media.home');
  activeIcon: Resource = $r('app.media.home_active');
  page: string = '';
}

// 帮助中心常见问题类型
export class FAQ {
  id: number = 0;
  question: string = '';
  answer: string = '';
  category: string = '';
}

// API响应数据类型 - 使用类而不是接口
export class PostListResponse {
  posts: Post[] = [];
  pagination: Pagination = new Pagination();
}

export class Pagination {
  page: number = 0;
  limit: number = 0;
  total: number = 0;
  pages: number = 0;
}

export class LikeResponse {
  is_liked: boolean = false;
  likes: number = 0;
}

// 发布帖子请求数据类型
export interface CreatePostRequest {
  title: string;
  content: string;
  image_urls: string;
  images?: string[];
  videos?: string[];
}

// 点赞请求数据类型
export interface LikeRequest {
  post_id: number;
}

// 评论相关类型
export class Comment {
  id: number = 0;
  content: string = '';
  user_id: number = 0;
  username: string = '';
  avatar: string = '';
  createTime: number = 0;
}

export interface CommentListResponse {
  comments: Comment[];
}

export interface CreateCommentRequest {
  post_id: number;
  content: string;
}

export interface CreateCommentResponse {
  comment_id: number;
  comment_count: number;
}

// 删除帖子请求
export interface DeletePostRequest {
  post_id: number;
}

// 用户帖子响应
export interface UserPostsResponse {
  posts: Post[];
  pagination: Pagination;
}

// 关注相关类型
export interface FollowRequest {
  user_id: number;
}

export interface FollowResponse {
  is_following: boolean;
}

export class FollowUser {
  id: number = 0;
  username: string = '';
  avatar: string = '';
  email: string = '';
  follow_time: number = 0;
}

export interface FollowListResponse {
  users: FollowUser[];
  total: number;
  page: number;
  limit: number;
  pages: number;
}

export interface FollowStatsResponse {
  following_count: number;
  followers_count: number;
}

// 通知相关类型
export enum NotificationType {
  ORDER = 'order',
  MESSAGE = 'message',
  FOLLOW = 'follow',
  SYSTEM = 'system'
}

export class AppNotification {
  id: number = 0;
  user_id: number = 0;
  type: string = '';
  title: string = '';
  content: string = '';
  related_id: number | null = null;
  related_type: string | null = null;
  is_read: boolean = false;
  created_at: string = '';
}

export interface NotificationListResponse {
  notifications: AppNotification[];
  unread_count: number;
}

export interface UnreadCountResponse {
  unread_count: number;
}

export interface MarkReadRequest {
  notification_id: number;
}