# customer_routes.py - 顾客端API路由
from flask import Blueprint, request, jsonify
from datetime import datetime
import pymysql
from models.database import get_db_connection
from models.notification_model import NotificationModel

customer_bp = Blueprint('customer', __name__, url_prefix='/customer')

@customer_bp.route('/session', methods=['POST'])
def create_session():
    """创建顾客临时会话"""
    data = request.get_json() or {}
    table_id = data.get('tableId', '')
    
    if not table_id:
        return jsonify({'success': False, 'message': '桌号不能为空'}), 400
    
    # 生成临时会话token（简化版，实际应使用JWT）
    import uuid
    session_token = str(uuid.uuid4())
    
    # 可以将会话信息存入数据库或Redis
    # 这里简化处理，直接返回token
    return jsonify({
        'success': True,
        'data': {
            'token': session_token,
            'tableId': table_id,
            'expiresIn': 7200  # 2小时有效期
        }
    })

@customer_bp.route('/menu', methods=['GET'])
def get_menu():
    """获取菜单（顾客端专用）"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor(pymysql.cursors.DictCursor)
        
        # 只返回上架的菜品
        cursor.execute('''
            SELECT id, name, price, image_url, category, description, 
                   rating, sales, is_available
            FROM dishes 
            WHERE is_available = 1
            ORDER BY category, sales DESC
        ''')
        dishes = cursor.fetchall()
        
        cursor.close()
        conn.close()
        
        return jsonify({
            'success': True,
            'data': {
                'dishes': dishes
            }
        })
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@customer_bp.route('/order', methods=['POST'])
def submit_order():
    """顾客提交订单"""
    data = request.get_json() or {}
    table_id = data.get('tableId', '')
    items = data.get('items', [])
    remark = data.get('remark', '')
    
    if not table_id:
        return jsonify({'success': False, 'message': '桌号不能为空'}), 400
    
    if not items:
        return jsonify({'success': False, 'message': '订单不能为空'}), 400
    
    try:
        conn = get_db_connection()
        cursor = conn.cursor(pymysql.cursors.DictCursor)
        
        # 计算订单总价
        total_price = 0
        for item in items:
            dish_id = item.get('dishId')
            quantity = item.get('quantity', 1)
            price = item.get('price', 0)
            total_price += price * quantity
        
        # 创建订单（顾客扫码点餐，无需登录）
        cursor.execute('''
            INSERT INTO orders (table_id, total_amount, status, remark, created_at)
            VALUES (%s, %s, %s, %s, %s)
        ''', (table_id, total_price, 'pending', remark, datetime.now()))
        
        order_id = cursor.lastrowid
        
        # 创建订单项
        for item in items:
            dish_id = item.get('dishId')
            quantity = item.get('quantity', 1)
            price = item.get('price', 0)
            
            cursor.execute('''
                INSERT INTO order_items (order_id, dish_id, quantity, price)
                VALUES (%s, %s, %s, %s)
            ''', (order_id, dish_id, quantity, price))
            
            # 更新菜品销量
            cursor.execute('''
                UPDATE dishes SET sales = sales + %s WHERE id = %s
            ''', (quantity, dish_id))
        
        conn.commit()
        cursor.close()
        conn.close()

        # 创建通知给商家（假设商家用户ID为1，实际应根据店铺关联查询）
        try:
            item_count = sum(item.get('quantity', 1) for item in items)
            NotificationModel.create_order_notification(
                merchant_user_id=1,  # 商家用户ID
                order_id=order_id,
                table_id=table_id,
                total_amount=total_price,
                item_count=item_count
            )
        except Exception as notify_error:
            # 通知创建失败不影响订单
            print(f"创建订单通知失败: {notify_error}")

        return jsonify({
            'success': True,
            'data': {
                'orderId': order_id,
                'tableId': table_id,
                'totalPrice': total_price,
                'itemCount': len(items),
                'status': 'pending',
                'message': '下单成功，请等待上菜'
            }
        })
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@customer_bp.route('/order/<int:order_id>/status', methods=['GET'])
def get_order_status(order_id):
    """获取订单状态"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor(pymysql.cursors.DictCursor)
        
        cursor.execute('''
            SELECT id, table_id, total_price, status, remark, created_at
            FROM orders WHERE id = %s
        ''', (order_id,))
        order = cursor.fetchone()
        
        if not order:
            return jsonify({'success': False, 'message': '订单不存在'}), 404
        
        # 获取订单项
        cursor.execute('''
            SELECT oi.*, d.name as dish_name, d.image_url
            FROM order_items oi
            JOIN dishes d ON oi.dish_id = d.id
            WHERE oi.order_id = %s
        ''', (order_id,))
        items = cursor.fetchall()
        
        cursor.close()
        conn.close()
        
        order['items'] = items
        return jsonify({'success': True, 'data': order})
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

