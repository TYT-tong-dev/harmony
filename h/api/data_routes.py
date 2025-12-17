from __future__ import annotations

import itertools
import time
from copy import deepcopy
from typing import Dict, List

from flask import Blueprint, request

from utils.response_utils import error_response, success_response
from utils.jwt_utils import login_required, decode_token
from models.user_model import UserModel
from models.order_model import OrderModel
from models.message_model import MessageModel
from models.table_model import TableModel
from models.follow_model import FollowModel
from models.notification_model import NotificationModel
from models.dish_model import DishModel
from models.post_model import PostModel
from models.comment_model import CommentModel
from models.shop_model import ShopModel
from models.cart_model import CartModel

data_bp = Blueprint("data", __name__)

# -----------------------------
# In-memory sample data stores
# -----------------------------

shop_info = {
    "id": 1,
    "shop_name": "食光记",
    "name": "食光记餐厅",
    "description": "专注健康美食的智慧餐厅，提供每日新鲜菜品。",
    "business_hours": "09:00-22:00",
    "address": "宁夏大学中卫校区",
    "phone": "13800138000",
    "score": 4.8,
    "todayOrders": 56,
    "todayRevenue": 3120.5,
    "latitude": 37.5149,
    "longitude": 105.1965,
}


dish_id_counter = itertools.count(start=101)
dishes: List[Dict] = [
    {
        "id": 1,
        "name": "招牌番茄牛腩",
        "description": "慢炖牛腩配以新鲜番茄，汤汁浓郁。",
        "price": 38.0,
        "image_url": "",
        "category": "热菜",
        "is_recommended": True,
        "sales": 126,
        "status": "available",
    },
    {
        "id": 2,
        "name": "香辣小龙虾",
        "description": "精选麻辣口味，香辣过瘾。",
        "price": 58.0,
        "image_url": "",
        "category": "特色",
        "is_recommended": True,
        "sales": 203,
        "status": "available",
    },
    {
        "id": 3,
        "name": "清炒时蔬",
        "description": "每日新鲜蔬菜，清爽不油腻。",
        "price": 18.0,
        "image_url": "",
        "category": "素菜",
        "is_recommended": False,
        "sales": 87,
        "status": "available",
    },
]


cart: Dict = {
    "items": [],
    "total_quantity": 0,
    "total_amount": 0.0,
}


post_id_counter = itertools.count(start=1001)
comment_id_counter = itertools.count(start=5001)
posts: List[Dict] = [
    {
        "id": 1,
        "user_id": 2,
        "username": "美食探店",
        "avatar": "",
        "content": "今日推荐：招牌番茄牛腩，汤汁浓郁，配米饭绝绝子！",
        "images": [],
        "videos": [],
        "likeCount": 32,
        "commentCount": 4,
        "isLiked": False,
        "isFollowed": False,
        "createTime": int(time.time()) - 3600,
        "title": "今日推荐",
        "imageUrls": "",
    },
    {
        "id": 2,
        "user_id": 3,
        "username": "健康饮食",
        "avatar": "",
        "content": "低油低盐的清炒时蔬，营养又健康~",
        "images": [],
        "videos": [],
        "likeCount": 18,
        "commentCount": 2,
        "isLiked": False,
        "isFollowed": False,
        "createTime": int(time.time()) - 7200,
        "title": "健康饮食",
        "imageUrls": "",
    },
]

post_comments: Dict[int, List[Dict]] = {
    1: [
        {
            "id": 1,
            "content": "这道菜真的很好吃！",
            "user_id": 2,
            "username": "慕名而来",
            "avatar": "",
            "createTime": int(time.time()) - 1800,
        }
    ],
    2: [],
}


conversation_id_counter = itertools.count(start=201)
message_id_counter = itertools.count(start=50001)

users = [
    {"id": 1, "username": "管理员", "avatar": "", "shopName": "食光记", "email": "admin@example.com", "type": "admin"},
    {"id": 2, "username": "王小明", "avatar": "", "shopName": "食光记", "email": "user1@example.com", "type": "staff"},
    {"id": 3, "username": "李丽", "avatar": "", "shopName": "食光记", "email": "user2@example.com", "type": "staff"},
]

conversations: List[Dict] = [
    {
        "id": 1,
        "conversationId": 1,
        "userId": 2,
        "username": "王小明",
        "avatar": "",
        "lastContent": "好的，收到！",
        "lastTime": int(time.time()) - 600,
        "unreadCount": 0,
        "isOnline": True,
    },
    {
        "id": 2,
        "conversationId": 2,
        "userId": 3,
        "username": "李丽",
        "avatar": "",
        "lastContent": "今天的餐品销量不错。",
        "lastTime": int(time.time()) - 3600,
        "unreadCount": 1,
        "isOnline": False,
    },
]

conversation_messages: Dict[int, List[Dict]] = {
    1: [
        {
            "id": 1,
            "content": "今天菜品准备好了么？",
            "time": int(time.time()) - 7200,
            "isMe": True,
            "type": "text",
        },
        {
            "id": 2,
            "content": "都准备好了，已经安排上架。",
            "time": int(time.time()) - 6500,
            "isMe": False,
            "type": "text",
        },
    ],
    2: [
        {
            "id": 3,
            "content": "今天的餐品销量不错。",
            "time": int(time.time()) - 3600,
            "isMe": False,
            "type": "text",
        }
    ],
}


def calculate_cart_totals():
    total_quantity = sum(item["quantity"] for item in cart["items"])
    total_amount = sum(item["quantity"] * item["price"] for item in cart["items"])
    cart["total_quantity"] = total_quantity
    cart["total_amount"] = round(total_amount, 2)


# -----------------------------
# Shop & Dish Endpoints
# -----------------------------


@data_bp.route("/shops/info", methods=["GET"])
def get_shop_info():
    try:
        shop_info = ShopModel.get_info(1)
        return success_response("获取店铺信息成功", shop_info)
    except Exception as e:
        return error_response(f"获取店铺信息失败: {str(e)}", 500)


@data_bp.route("/dishes/list", methods=["GET"])
@data_bp.route("/dishes", methods=["GET"])
def get_dish_list():
    try:
        shop_id = request.args.get("shop_id", 1, type=int)
        dishes_data = DishModel.get_all(shop_id)
        
        # 格式化菜品数据
        formatted_dishes = []
        for dish in dishes_data:
            formatted_dish = {
                "id": dish["id"],
                "name": dish["name"],
                "description": dish.get("description", ""),
                "price": float(dish["price"]),
                "image_url": dish.get("image_url", ""),
                "category": dish.get("category", ""),
                "is_recommended": bool(dish.get("is_recommended", False)),
                "sales": dish.get("sales", 0),
                "status": dish.get("status", "available")
            }
            formatted_dishes.append(formatted_dish)
        
        return success_response("获取菜品成功", {"dishes": formatted_dishes})
    except Exception as e:
        return error_response(f"获取菜品失败: {str(e)}", 500)


@data_bp.route("/dishes/add", methods=["POST"])
@login_required
def add_dish(_jwt_claims=None):
    try:
    data = request.get_json(silent=True) or {}
    name = data.get("name", "").strip()
    if not name:
        return error_response("菜品名称不能为空", 400)

        shop_id = data.get("shop_id", 1)
        description = data.get("description", "")
        price = float(data.get("price", 0)) if data.get("price") is not None else 0.0
        image_url = data.get("image_url", "")
        category = data.get("category", "")
        is_recommended = bool(data.get("is_recommended", False))
        status = data.get("status", "available")

        new_dish = DishModel.create(
            shop_id=shop_id,
            name=name,
            description=description,
            price=price,
            image_url=image_url,
            category=category,
            is_recommended=is_recommended,
            status=status
        )

        # 格式化返回数据
        formatted_dish = {
            "id": new_dish["id"],
            "name": new_dish["name"],
            "description": new_dish.get("description", ""),
            "price": float(new_dish["price"]),
            "image_url": new_dish.get("image_url", ""),
            "category": new_dish.get("category", ""),
            "is_recommended": bool(new_dish.get("is_recommended", False)),
            "sales": 0,
            "status": new_dish.get("status", "available")
        }

        return success_response("添加菜品成功", formatted_dish)
    except Exception as e:
        return error_response(f"添加菜品失败: {str(e)}", 500)


# -----------------------------
# Cart & Order Endpoints
# -----------------------------


@data_bp.route("/cart/items", methods=["GET"])
@login_required
def get_cart_items(_jwt_claims=None):
    try:
        token = request.headers.get('Authorization', '').replace('Bearer ', '')
        payload = decode_token(token)
        user_id = payload.get('uid') if payload else None
        
        if not user_id:
            return error_response("用户未登录", 401)
        
        cart_data = CartModel.get_items(user_id)
        return success_response("获取购物车成功", cart_data)
    except Exception as e:
        return error_response(f"获取购物车失败: {str(e)}", 500)


@data_bp.route("/cart/add", methods=["POST"])
@login_required
def add_to_cart(_jwt_claims=None):
    try:
        token = request.headers.get('Authorization', '').replace('Bearer ', '')
        payload = decode_token(token)
        user_id = payload.get('uid') if payload else None
        
        if not user_id:
            return error_response("用户未登录", 401)
        
    data = request.get_json(silent=True) or {}
    dish_id = data.get("dish_id")
    quantity = int(data.get("quantity", 1))

    if dish_id is None:
        return error_response("缺少菜品ID", 400)

        cart_data = CartModel.add_item(user_id, dish_id, quantity)
        if cart_data is None:
        return error_response("菜品不存在", 404)

        return success_response("加入购物车成功", cart_data)
    except Exception as e:
        return error_response(f"加入购物车失败: {str(e)}", 500)


@data_bp.route("/cart/update", methods=["POST"])
@login_required
def update_cart_item(_jwt_claims=None):
    try:
        token = request.headers.get('Authorization', '').replace('Bearer ', '')
        payload = decode_token(token)
        user_id = payload.get('uid') if payload else None
        
        if not user_id:
            return error_response("用户未登录", 401)
        
    data = request.get_json(silent=True) or {}
    dish_id = data.get("dish_id")
    quantity = int(data.get("quantity", 1))

        if dish_id is None:
            return error_response("缺少菜品ID", 400)

        cart_data = CartModel.update_item(user_id, dish_id, quantity)
        return success_response("更新购物车成功", cart_data)
    except Exception as e:
        return error_response(f"更新购物车失败: {str(e)}", 500)


@data_bp.route("/cart/clear", methods=["POST"])
@login_required
def clear_cart(_jwt_claims=None):
    try:
        token = request.headers.get('Authorization', '').replace('Bearer ', '')
        payload = decode_token(token)
        user_id = payload.get('uid') if payload else None
        
        if not user_id:
            return error_response("用户未登录", 401)
        
        cart_data = CartModel.clear(user_id)
        return success_response("购物车已清空", cart_data)
    except Exception as e:
        return error_response(f"清空购物车失败: {str(e)}", 500)


@data_bp.route("/orders/create", methods=["POST"])
@login_required
def create_order(_jwt_claims=None):
    """
    结算购物车并创建订单（默认标记为已支付）
    """
    try:
        token = request.headers.get('Authorization', '').replace('Bearer ', '')
        payload = decode_token(token)
        user_id = payload.get('uid') if payload else None

        if not user_id:
            return error_response("用户未登录", 401)

        # 获取用户购物车
        cart_data = CartModel.get_items(user_id)
        items = cart_data.get('items', []) if cart_data else []
        if not items:
        return error_response("购物车为空", 400)

        # 请求参数
        data = request.get_json(silent=True) or {}
        table_id = data.get("table_id")
        remark = data.get("remark", "")
        pay_now = data.get("pay_now", True)
        status = "paid" if pay_now else "pending"

        # 创建订单
        order = OrderModel.create_from_items(
            user_id=user_id,
            items=[{
                "dish_id": item.get("dish_id"),
                "quantity": item.get("quantity"),
                "price": item.get("price")
            } for item in items],
            table_id=table_id,
            remark=remark,
            status=status
        )

        if not order:
            return error_response("创建订单失败", 500)

    # 清空购物车
        CartModel.clear(user_id)

        return success_response("订单创建成功", order)
    except Exception as e:
        return error_response(f"创建订单失败: {str(e)}", 500)


@data_bp.route("/orders/pay", methods=["POST"])
@login_required
def pay_order(_jwt_claims=None):
    """
    支付订单（将状态置为 paid）
    """
    try:
        token = request.headers.get('Authorization', '').replace('Bearer ', '')
        payload = decode_token(token)
        user_id = payload.get('uid') if payload else None

        if not user_id:
            return error_response("用户未登录", 401)

        data = request.get_json(silent=True) or {}
        order_id = data.get("order_id")

        if not order_id:
            return error_response("缺少订单ID", 400)

        success = OrderModel.update_status(order_id, "paid", user_id)
        if not success:
            return error_response("订单不存在或无权限", 404)

        return success_response("支付成功", {
            "order_id": order_id,
            "status": "paid"
        })
    except Exception as e:
        return error_response(f"支付失败: {str(e)}", 500)


@data_bp.route("/orders", methods=["POST"])
def create_h5_order():
    """H5网页下单接口"""
    try:
        data = request.get_json()
        if not data:
            return error_response("请求数据为空", 400)

        table_number = data.get("table_number", "")
        items = data.get("items", [])
        source = data.get("source", "h5")

        if not items:
            return error_response("请选择菜品", 400)

        # 计算总价
        total_amount = 0
        total_quantity = 0
        order_items = []

        for item in items:
            dish_id = item.get("dish_id")
            quantity = item.get("quantity", 1)

            # 查找菜品
            dish = next((d for d in dishes if d["id"] == dish_id), None)
            if dish:
                item_total = dish["price"] * quantity
                total_amount += item_total
                total_quantity += quantity
                order_items.append({
                    "dish_id": dish_id,
                    "dish_name": dish["name"],
                    "price": dish["price"],
                    "quantity": quantity,
                    "subtotal": item_total
                })

        # 创建订单
        order_id = int(time.time() * 1000)
        order = {
            "order_id": order_id,
            "table_number": table_number,
            "items": order_items,
            "total_amount": total_amount,
            "total_quantity": total_quantity,
            "source": source,
            "status": "pending",
            "created_at": time.strftime("%Y-%m-%d %H:%M:%S")
        }

        # TODO: 保存到数据库
        # OrderModel.create(order)

        return success_response("下单成功", order)
    except Exception as e:
        return error_response(f"下单失败: {str(e)}", 500)

@data_bp.route("/sales/stats", methods=["GET"])
@login_required
def get_sales_stats(_jwt_claims=None):
    """获取用户销售统计"""
    try:
        user_id = _jwt_claims.get('uid') if _jwt_claims else None
        if not user_id:
            return error_response("未登录", 401)
        
        stats = OrderModel.get_user_sales_stats(user_id)
        return success_response("获取成功", stats)
    except Exception as e:
        return error_response(f"获取销售统计失败: {str(e)}", 500)

@data_bp.route("/orders/list", methods=["GET"])
@login_required
def get_user_orders(_jwt_claims=None):
    """获取用户订单列表"""
    try:
        user_id = _jwt_claims.get('uid') if _jwt_claims else None
        if not user_id:
            return error_response("未登录", 401)
        
        limit = int(request.args.get("limit", 10))
        orders = OrderModel.get_user_orders(user_id, limit)
        return success_response("获取成功", {"orders": orders})
    except Exception as e:
        return error_response(f"获取订单列表失败: {str(e)}", 500)


# -----------------------------
# Posts & Comments Endpoints
# -----------------------------


@data_bp.route("/posts/list", methods=["GET"])
def get_posts():
    try:
    page = int(request.args.get("page", 1))
    limit = int(request.args.get("limit", 10))
        category = request.args.get("category", "推荐")  # 支持: 推荐、附近、关注

    # 获取当前用户ID，添加关注状态
    token = request.headers.get('Authorization', '').replace('Bearer ', '')
    payload = decode_token(token)
    current_user_id = payload.get('uid') if payload else None

        # 获取关注用户ID列表（如果是"关注"分类）
        following_ids = None
        if category == "关注" and current_user_id:
            following_ids = FollowModel.get_following_ids(current_user_id)

        # 从数据库获取帖子
        result = PostModel.get_list(
            page=page,
            limit=limit,
            category=category,
            current_user_id=current_user_id,
            following_ids=following_ids
        )

        # 添加关注状态
        if current_user_id and result['posts']:
            user_ids = [p.get('user_id') for p in result['posts'] if p.get('user_id')]
        if user_ids:
            follow_status = FollowModel.check_following_batch(current_user_id, user_ids)
                for post in result['posts']:
                post_user_id = post.get('user_id')
                if post_user_id:
                    post['isFollowed'] = follow_status.get(post_user_id, False)

        return success_response("获取帖子成功", {
            "posts": result['posts'],
            "pagination": {
                "page": result['page'],
                "limit": result['limit'],
                "total": result['total'],
                "pages": result['pages']
            }
        })
    except Exception as e:
        return error_response(f"获取帖子失败: {str(e)}", 500)


@data_bp.route("/posts/create", methods=["POST"])
@login_required
def create_post(_jwt_claims=None):
    try:
    data = request.get_json(silent=True) or {}
    title = data.get("title", "").strip()
    content = data.get("content", "").strip()
    raw_images = data.get("images", []) or []
    raw_videos = data.get("videos", []) or []
    images = [str(item) for item in raw_images if isinstance(item, str) and item.strip()]
    videos = [str(item) for item in raw_videos if isinstance(item, str) and item.strip()]

    # 获取当前用户信息
    token = request.headers.get('Authorization', '').replace('Bearer ', '')
    payload = decode_token(token)
    current_user_id = payload.get('uid') if payload else None
    current_username = payload.get('username', '用户') if payload else '用户'

        if not current_user_id:
            return error_response("用户未登录", 401)

    if not title or not content:
        return error_response("标题和内容不能为空", 400)

    image_urls = data.get("image_urls", "")
    if not image_urls:
        image_urls = ",".join(images + videos)

        # 保存到数据库
        post = PostModel.create(
            user_id=current_user_id,
            title=title,
            content=content,
            image_urls=image_urls
        )

        # 格式化返回数据
        formatted_post = {
            "id": post["id"],
            "user_id": post["user_id"],
        "username": current_username,
            "avatar": post.get("avatar", ""),
        "content": content,
        "images": images,
        "videos": videos,
        "likeCount": 0,
        "commentCount": 0,
        "isLiked": False,
        "isFollowed": False,
            "createTime": int(post["created_at"].timestamp()) if post.get("created_at") else int(time.time()),
        "title": title,
        "imageUrls": image_urls,
    }

        return success_response("发布成功", formatted_post)
    except Exception as e:
        return error_response(f"发布失败: {str(e)}", 500)


@data_bp.route("/posts/like", methods=["POST"])
@login_required
def like_post(_jwt_claims=None):
    try:
        token = request.headers.get('Authorization', '').replace('Bearer ', '')
        payload = decode_token(token)
        current_user_id = payload.get('uid') if payload else None

        if not current_user_id:
            return error_response("用户未登录", 401)

    data = request.get_json(silent=True) or {}
    post_id = data.get("post_id")

        if not post_id:
            return error_response("缺少帖子ID", 400)

        # 检查帖子是否存在
        post = PostModel.get_by_id(post_id)
    if not post:
        return error_response("帖子不存在", 404)

        # 点赞/取消点赞
        result = PostModel.like_post(post_id, current_user_id)

        return success_response("操作成功", result)
    except Exception as e:
        return error_response(f"操作失败: {str(e)}", 500)


@data_bp.route("/posts/comments", methods=["GET"])
def get_post_comments():
    try:
    post_id = int(request.args.get("post_id", 0))
        if not post_id:
            return error_response("缺少帖子ID", 400)

        comments = CommentModel.get_by_post_id(post_id)
    return success_response("获取评论成功", {"comments": comments})
    except Exception as e:
        return error_response(f"获取评论失败: {str(e)}", 500)


@data_bp.route("/posts/comments/create", methods=["POST"])
@login_required
def create_comment(_jwt_claims=None):
    try:
        token = request.headers.get('Authorization', '').replace('Bearer ', '')
        payload = decode_token(token)
        current_user_id = payload.get('uid') if payload else None

        if not current_user_id:
            return error_response("用户未登录", 401)

    data = request.get_json(silent=True) or {}
    post_id = data.get("post_id")
    content = (data.get("content") or "").strip()

    if not post_id or not content:
        return error_response("评论内容不能为空", 400)

        # 检查帖子是否存在
        post = PostModel.get_by_id(post_id)
        if not post:
            return error_response("帖子不存在", 404)

        # 创建评论
        result = CommentModel.create(post_id, current_user_id, content)

        return success_response("评论成功", result)
    except Exception as e:
        return error_response(f"评论失败: {str(e)}", 500)


# -----------------------------
# Messaging Endpoints
# -----------------------------


@data_bp.route("/messages/conversations", methods=["GET"])
@login_required
def get_conversations(_jwt_claims=None):
    """获取当前用户的会话列表（从数据库）"""
    token = request.headers.get('Authorization', '').replace('Bearer ', '')
    payload = decode_token(token)
    current_user_id = payload.get('uid') if payload else None

    if not current_user_id:
        return error_response("用户未登录", 401)

    try:
        conversations_list = MessageModel.get_conversations(current_user_id)
        return success_response("获取会话列表成功", {"conversations": conversations_list})
    except Exception as e:
        # 回退到内存数据
        return success_response("获取会话列表成功", {"conversations": deepcopy(conversations)})


@data_bp.route("/messages/list", methods=["GET"])
@login_required
def get_messages(_jwt_claims=None):
    """获取会话消息列表（从数据库）"""
    conversation_id = int(request.args.get("conversation_id", 0))
    token = request.headers.get('Authorization', '').replace('Bearer ', '')
    payload = decode_token(token)
    current_user_id = payload.get('uid') if payload else None

    if not current_user_id:
        return error_response("用户未登录", 401)

    try:
        messages_list = MessageModel.get_messages(conversation_id, current_user_id)
        # 标记消息为已读
        MessageModel.mark_messages_read(conversation_id, current_user_id)
        return success_response("获取消息成功", {"messages": messages_list})
    except Exception as e:
        # 回退到内存数据
        messages = deepcopy(conversation_messages.get(conversation_id, []))
        return success_response("获取消息成功", {"messages": messages})


@data_bp.route("/messages/send", methods=["POST"])
@login_required
def send_message(_jwt_claims=None):
    """发送消息（保存到数据库）"""
    data = request.get_json(silent=True) or {}
    conversation_id = data.get("conversation_id")
    content = (data.get("content") or "").strip()
    msg_type = data.get("type", "text")

    token = request.headers.get('Authorization', '').replace('Bearer ', '')
    payload = decode_token(token)
    current_user_id = payload.get('uid') if payload else None
    current_username = payload.get('username', '用户') if payload else '用户'

    if not current_user_id:
        return error_response("用户未登录", 401)

    if not conversation_id or not content:
        return error_response("消息内容不能为空", 400)

    try:
        message = MessageModel.send_message(
            conversation_id=conversation_id,
            sender_id=current_user_id,
            content=content,
            msg_type=msg_type,
            image_url=data.get("image_url"),
            voice_url=data.get("voice_url"),
            voice_duration=data.get("voice_duration", 0),
            video_url=data.get("video_url")
        )

        # 创建消息通知给接收者
        try:
            participant = MessageModel.get_conversation_participant(conversation_id, current_user_id)
            if participant and participant.get('receiver_id'):
                display_content = content
                if msg_type == 'image':
                    display_content = '[图片]'
                elif msg_type == 'video':
                    display_content = '[视频]'
                elif msg_type == 'voice':
                    display_content = '[语音]'

                NotificationModel.create_message_notification(
                    receiver_id=participant['receiver_id'],
                    sender_name=current_username,
                    message_content=display_content,
                    conversation_id=conversation_id,
                    message_id=message.get('id', 0)
                )
        except Exception as notify_error:
            print(f"创建消息通知失败: {notify_error}")

        return success_response("发送成功", message)
    except Exception as e:
        # 回退到内存处理
        conversation_messages.setdefault(conversation_id, [])
        message = {
            "id": next(message_id_counter),
            "content": content,
            "time": int(time.time()),
            "isMe": True,
            "type": msg_type,
            "imageUrl": data.get("image_url", ""),
            "voiceUrl": data.get("voice_url", ""),
            "voiceDuration": data.get("voice_duration", 0),
            "videoUrl": data.get("video_url", "")
        }
        conversation_messages[conversation_id].append(message)
        return success_response("发送成功", message)


@data_bp.route("/messages/users/search", methods=["GET"])
def search_users():
    """搜索用户"""
    keyword = (request.args.get("keyword") or "").strip()
    token = request.headers.get('Authorization', '').replace('Bearer ', '')
    payload = decode_token(token)
    current_user_id = payload.get('uid') if payload else None

    try:
        # 从数据库搜索用户
        results = UserModel.search_users(keyword)
        # 排除当前用户自己
        if current_user_id:
            results = [u for u in results if u['id'] != current_user_id]
        return success_response("搜索成功", {"users": results})
    except Exception as e:
        # 如果数据库搜索失败，回退到内存搜索
        if not keyword:
            results = users
        else:
            results = [user for user in users if keyword.lower() in user["username"].lower()]
        return success_response("搜索成功", {"users": deepcopy(results)})


@data_bp.route("/messages/conversation/create", methods=["POST"])
@login_required
def create_conversation(_jwt_claims=None):
    """创建或获取已有会话（保存到数据库）"""
    data = request.get_json(silent=True) or {}
    raw_user_id = data.get("user_id")

    token = request.headers.get('Authorization', '').replace('Bearer ', '')
    payload = decode_token(token)
    current_user_id = payload.get('uid') if payload else None

    if not current_user_id:
        return error_response("用户未登录", 401)

    try:
        user_id = int(raw_user_id)
    except (TypeError, ValueError):
        return error_response("缺少或无效的用户ID", 400)

    # 不能添加自己
    if user_id == current_user_id:
        return error_response("不能添加自己为好友", 400)

    # 从数据库获取用户信息
    user = UserModel.find_by_id(user_id)
    if not user:
        return error_response("用户不存在", 404)

    try:
        # 创建会话到数据库
        conversation_id, is_new = MessageModel.create_conversation(current_user_id, user_id)

        conversation = {
            "id": conversation_id,
            "conversationId": conversation_id,
            "userId": user["id"],
            "username": user["username"],
            "avatar": user.get("avatar", ""),
            "email": user.get("email", ""),
            "lastContent": "",
            "lastTime": int(time.time()),
            "unreadCount": 0,
            "isOnline": True,
        }

        if is_new:
            return success_response("创建会话成功", conversation)
        else:
            return success_response("会话已存在", conversation)
    except Exception as e:
        # 回退到内存处理
        existing = next((item for item in conversations if item["userId"] == user_id), None)
        if existing:
            return success_response("会话已存在", deepcopy(existing))

        new_conversation_id = next(conversation_id_counter)
        conversation = {
            "id": new_conversation_id,
            "conversationId": new_conversation_id,
            "userId": user["id"],
            "username": user["username"],
            "avatar": user.get("avatar", ""),
            "email": user.get("email", ""),
            "lastContent": "",
            "lastTime": int(time.time()),
            "unreadCount": 0,
            "isOnline": True,
        }
        conversations.append(conversation)
        conversation_messages[new_conversation_id] = []
        return success_response("创建会话成功", deepcopy(conversation))


# -----------------------------
# Dish Review Endpoints (评价功能)
# -----------------------------

# 内存评价存储
review_id_counter = itertools.count(start=1)
dish_reviews: Dict[int, List[Dict]] = {}  # dish_id -> list of reviews


@data_bp.route("/dishes/<int:dish_id>", methods=["GET"])
def get_dish_detail(dish_id: int):
    """获取菜品详情"""
    try:
        from models.dish_model import DishModel
        from models.dish_review_model import DishReviewModel
        
        dish = DishModel.get_by_id(dish_id)
    if not dish:
        return error_response("菜品不存在", 404)

        # 获取评分统计
        stats = DishReviewModel.get_rating_stats(dish_id)
        
        dish_data = {
            "id": dish["id"],
            "name": dish["name"],
            "description": dish.get("description", "") or "",
            "cooking_method": dish.get("cooking_method", "") or "",
            "price": float(dish["price"]),
            "image_url": dish.get("image_url", "") or "",
            "category": dish.get("category", "") or "",
            "is_recommended": bool(dish.get("is_recommended", 0)),
            "sales": dish.get("sales", 0) or 0,
            "rating": stats["avg_rating"],
            "review_count": stats["review_count"]
        }

    return success_response("获取菜品详情成功", dish_data)
    except Exception as e:
        return error_response(f"获取菜品详情失败: {str(e)}", 500)


@data_bp.route("/dishes/<int:dish_id>/reviews", methods=["GET"])
def get_dish_reviews(dish_id: int):
    """获取菜品评价列表"""
    try:
        from models.dish_model import DishModel
        from models.dish_review_model import DishReviewModel
        
        dish = DishModel.get_by_id(dish_id)
    if not dish:
        return error_response("菜品不存在", 404)

        page = request.args.get("page", 1, type=int)
        limit = request.args.get("limit", 20, type=int)

        reviews = DishReviewModel.get_by_dish_id(dish_id, page, limit)

        return success_response("获取评价成功", reviews)
    except Exception as e:
        return error_response(f"获取评价失败: {str(e)}", 500)


@data_bp.route("/dishes/<int:dish_id>/reviews", methods=["POST"])
@login_required
def add_dish_review(dish_id: int, _jwt_claims=None):
    """添加或更新菜品评价"""
    try:
        from models.dish_model import DishModel
        from models.dish_review_model import DishReviewModel
        
        dish = DishModel.get_by_id(dish_id)
    if not dish:
        return error_response("菜品不存在", 404)

    data = request.get_json(silent=True) or {}
    rating = data.get("rating", 5)
    content = data.get("content", "").strip()

    # 验证评分
    if not isinstance(rating, int) or rating < 1 or rating > 5:
        return error_response("评分必须是1-5之间的整数", 400)

    if not content:
        return error_response("评论内容不能为空", 400)

        # 获取用户ID
        token = request.headers.get('Authorization', '').replace('Bearer ', '')
    payload = decode_token(token)
        user_id = payload.get('uid') if payload else None

        if not user_id:
            return error_response("用户未登录", 401)

        # 创建或更新评价
        review = DishReviewModel.create(dish_id, user_id, rating, content)

        return success_response("评价成功", review)
    except Exception as e:
        return error_response(f"评价失败: {str(e)}", 500)


# ========================================
# 桌位管理 API
# ========================================

@data_bp.route("/tables", methods=["GET"])
@login_required
def get_tables(_jwt_claims=None):
    """获取所有桌位"""
    try:
        tables = TableModel.get_all()
        return success_response("获取桌位列表成功", {"tables": tables})
    except Exception as e:
        return error_response(f"获取桌位失败: {str(e)}", 500)


@data_bp.route("/tables/<int:table_id>", methods=["GET"])
@login_required
def get_table(table_id: int, _jwt_claims=None):
    """获取单个桌位信息"""
    try:
        table = TableModel.get_by_id(table_id)
        if not table:
            return error_response("桌位不存在", 404)
        return success_response("获取桌位成功", table)
    except Exception as e:
        return error_response(f"获取桌位失败: {str(e)}", 500)


@data_bp.route("/tables", methods=["POST"])
@login_required
def create_table(_jwt_claims=None):
    """创建新桌位"""
    data = request.get_json() or {}
    table_number = data.get("table_number", "").strip()
    table_name = data.get("table_name", "").strip()
    capacity = data.get("capacity", 4)

    if not table_number:
        return error_response("桌号不能为空", 400)

    # 检查桌号是否已存在
    existing = TableModel.get_by_number(table_number)
    if existing:
        return error_response("桌号已存在", 400)

    try:
        table = TableModel.create(table_number, table_name, capacity)
        return success_response("创建桌位成功", table)
    except Exception as e:
        return error_response(f"创建桌位失败: {str(e)}", 500)


@data_bp.route("/tables/<int:table_id>/status", methods=["PUT"])
@login_required
def update_table_status(table_id: int, _jwt_claims=None):
    """更新桌位状态"""
    data = request.get_json() or {}
    status = data.get("status", "").strip()

    if status not in ["available", "occupied", "reserved", "cleaning"]:
        return error_response("无效的状态", 400)

    try:
        table = TableModel.update_status(table_id, status)
        if not table:
            return error_response("桌位不存在", 404)
        return success_response("更新状态成功", table)
    except Exception as e:
        return error_response(f"更新状态失败: {str(e)}", 500)


@data_bp.route("/tables/<int:table_id>", methods=["DELETE"])
@login_required
def delete_table(table_id: int, _jwt_claims=None):
    """删除桌位"""
    try:
        success = TableModel.delete(table_id)
        if not success:
            return error_response("桌位不存在", 404)
        return success_response("删除桌位成功")
    except Exception as e:
        return error_response(f"删除桌位失败: {str(e)}", 500)


@data_bp.route("/tables/<int:table_id>/qrcode", methods=["GET"])
def get_table_qrcode(table_id: int):
    """获取桌位二维码信息"""
    try:
        table = TableModel.get_by_id(table_id)
        if not table:
            return error_response("桌位不存在", 404)

        # 获取服务器地址（从请求中获取）
        from flask import request
        server_host = request.host_url.rstrip('/')

        # 构建二维码数据
        qr_data = {
            "table_id": table["id"],
            "table_number": table["table_number"],
            "table_name": table["table_name"],
            # 扫码跳转链接（顾客扫码用这个）
            "scan_url": f"{server_host}/scan/table/{table['table_number']}",
            # Deep Link（App内部使用）
            "deep_link": f"catering-app://table?tableId={table['table_number']}&mode=customer",
        }
        return success_response("获取二维码数据成功", qr_data)
    except Exception as e:
        return error_response(f"获取二维码失败: {str(e)}", 500)


# =====================
# 关注功能 API
# =====================

@data_bp.route("/follow", methods=["POST"])
@login_required
def follow_user(_jwt_claims=None):
    """关注用户"""
    data = request.get_json(silent=True) or {}
    following_id = data.get("user_id")

    token = request.headers.get('Authorization', '').replace('Bearer ', '')
    payload = decode_token(token)
    current_user_id = payload.get('uid') if payload else None

    if not current_user_id:
        return error_response("用户未登录", 401)

    if not following_id:
        return error_response("缺少用户ID", 400)

    try:
        following_id = int(following_id)
    except (TypeError, ValueError):
        return error_response("无效的用户ID", 400)

    success, message = FollowModel.follow_user(current_user_id, following_id)
    if success:
        return success_response(message, {"is_following": True})
    else:
        return error_response(message, 400)


@data_bp.route("/unfollow", methods=["POST"])
@login_required
def unfollow_user(_jwt_claims=None):
    """取消关注"""
    data = request.get_json(silent=True) or {}
    following_id = data.get("user_id")

    token = request.headers.get('Authorization', '').replace('Bearer ', '')
    payload = decode_token(token)
    current_user_id = payload.get('uid') if payload else None

    if not current_user_id:
        return error_response("用户未登录", 401)

    if not following_id:
        return error_response("缺少用户ID", 400)

    try:
        following_id = int(following_id)
    except (TypeError, ValueError):
        return error_response("无效的用户ID", 400)

    success = FollowModel.unfollow_user(current_user_id, following_id)
    if success:
        return success_response("已取消关注", {"is_following": False})
    else:
        return error_response("取消关注失败", 400)


@data_bp.route("/follow/check", methods=["GET"])
@login_required
def check_follow(_jwt_claims=None):
    """检查是否已关注某用户"""
    following_id = request.args.get("user_id")

    token = request.headers.get('Authorization', '').replace('Bearer ', '')
    payload = decode_token(token)
    current_user_id = payload.get('uid') if payload else None

    if not current_user_id:
        return error_response("用户未登录", 401)

    if not following_id:
        return error_response("缺少用户ID", 400)

    try:
        following_id = int(following_id)
    except (TypeError, ValueError):
        return error_response("无效的用户ID", 400)

    is_following = FollowModel.is_following(current_user_id, following_id)
    return success_response("查询成功", {"is_following": is_following})


@data_bp.route("/follow/list", methods=["GET"])
@login_required
def get_following_list(_jwt_claims=None):
    """获取我的关注列表"""
    token = request.headers.get('Authorization', '').replace('Bearer ', '')
    payload = decode_token(token)
    current_user_id = payload.get('uid') if payload else None

    if not current_user_id:
        return error_response("用户未登录", 401)

    page = request.args.get("page", 1, type=int)
    limit = request.args.get("limit", 20, type=int)

    result = FollowModel.get_following_list(current_user_id, page, limit)

    # 转换用户数据格式
    users = []
    for user in result['users']:
        users.append({
            "id": user['id'],
            "username": user['username'],
            "avatar": user.get('avatar', ''),
            "email": user.get('email', ''),
            "follow_time": int(user['follow_time'].timestamp()) if user.get('follow_time') else 0
        })

    return success_response("获取成功", {
        "users": users,
        "total": result['total'],
        "page": result['page'],
        "limit": result['limit'],
        "pages": result['pages']
    })


@data_bp.route("/follow/stats", methods=["GET"])
@login_required
def get_follow_stats(_jwt_claims=None):
    """获取关注统计"""
    token = request.headers.get('Authorization', '').replace('Bearer ', '')
    payload = decode_token(token)
    current_user_id = payload.get('uid') if payload else None

    if not current_user_id:
        return error_response("用户未登录", 401)

    stats = FollowModel.get_follow_stats(current_user_id)
    return success_response("获取成功", stats)


# -----------------------------
# Notification Endpoints
# -----------------------------

@data_bp.route("/notifications/list", methods=["GET"])
@login_required
def get_notifications(_jwt_claims=None):
    """获取通知列表"""
    token = request.headers.get('Authorization', '').replace('Bearer ', '')
    payload = decode_token(token)
    current_user_id = payload.get('uid') if payload else None

    if not current_user_id:
        return error_response("用户未登录", 401)

    limit = int(request.args.get("limit", 20))
    offset = int(request.args.get("offset", 0))
    unread_only = request.args.get("unread_only", "false").lower() == "true"

    try:
        notifications = NotificationModel.get_user_notifications(
            current_user_id, limit, offset, unread_only
        )
        unread_count = NotificationModel.get_unread_count(current_user_id)
        return success_response("获取成功", {
            "notifications": notifications,
            "unread_count": unread_count
        })
    except Exception as e:
        return error_response(f"获取通知失败: {str(e)}", 500)


@data_bp.route("/notifications/unread_count", methods=["GET"])
@login_required
def get_unread_notification_count(_jwt_claims=None):
    """获取未读通知数量"""
    token = request.headers.get('Authorization', '').replace('Bearer ', '')
    payload = decode_token(token)
    current_user_id = payload.get('uid') if payload else None

    if not current_user_id:
        return error_response("用户未登录", 401)

    try:
        count = NotificationModel.get_unread_count(current_user_id)
        return success_response("获取成功", {"unread_count": count})
    except Exception as e:
        return error_response(f"获取未读数量失败: {str(e)}", 500)


@data_bp.route("/notifications/read", methods=["POST"])
@login_required
def mark_notification_read(_jwt_claims=None):
    """标记通知为已读"""
    token = request.headers.get('Authorization', '').replace('Bearer ', '')
    payload = decode_token(token)
    current_user_id = payload.get('uid') if payload else None

    if not current_user_id:
        return error_response("用户未登录", 401)

    data = request.get_json(silent=True) or {}
    notification_id = data.get("notification_id")

    if not notification_id:
        return error_response("通知ID不能为空", 400)

    try:
        success = NotificationModel.mark_as_read(notification_id, current_user_id)
        if success:
            return success_response("已标记为已读")
        else:
            return error_response("通知不存在或无权操作", 404)
    except Exception as e:
        return error_response(f"标记失败: {str(e)}", 500)


@data_bp.route("/notifications/read_all", methods=["POST"])
@login_required
def mark_all_notifications_read(_jwt_claims=None):
    """标记所有通知为已读"""
    token = request.headers.get('Authorization', '').replace('Bearer ', '')
    payload = decode_token(token)
    current_user_id = payload.get('uid') if payload else None

    if not current_user_id:
        return error_response("用户未登录", 401)

    try:
        count = NotificationModel.mark_all_as_read(current_user_id)
        return success_response("已全部标记为已读", {"marked_count": count})
    except Exception as e:
        return error_response(f"标记失败: {str(e)}", 500)


@data_bp.route("/notifications/delete", methods=["POST"])
@login_required
def delete_notification(_jwt_claims=None):
    """删除通知"""
    token = request.headers.get('Authorization', '').replace('Bearer ', '')
    payload = decode_token(token)
    current_user_id = payload.get('uid') if payload else None

    if not current_user_id:
        return error_response("用户未登录", 401)

    data = request.get_json(silent=True) or {}
    notification_id = data.get("notification_id")

    if not notification_id:
        return error_response("通知ID不能为空", 400)

    try:
        success = NotificationModel.delete_notification(notification_id, current_user_id)
        if success:
            return success_response("已删除")
        else:
            return error_response("通知不存在或无权操作", 404)
    except Exception as e:
        return error_response(f"删除失败: {str(e)}", 500)
