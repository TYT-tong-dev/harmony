from models.database import get_db_connection
from datetime import datetime, timedelta

class OrderModel:
    @staticmethod
    def create_from_items(user_id, items, table_id=None, remark="", status="paid", shop_id=1):
        """
        使用指定的商品列表创建订单（结算用）
        items: [{'dish_id': int, 'quantity': int, 'price': float}]
        """
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                # 计算总价
                total_amount = 0.0
                total_quantity = 0
                for item in items:
                    qty = int(item.get('quantity', 1))
                    price = float(item.get('price', 0))
                    total_amount += qty * price
                    total_quantity += qty

                if total_quantity == 0:
                    return None

                # 创建订单
                sql_order = """
                    INSERT INTO orders (user_id, shop_id, table_id, total_amount, status, remark, created_at)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                """
                cursor.execute(sql_order, (user_id, shop_id, table_id, total_amount, status, remark, datetime.now()))
                order_id = cursor.lastrowid

                # 创建订单项
                sql_item = """
                    INSERT INTO order_items (order_id, dish_id, quantity, price)
                    VALUES (%s, %s, %s, %s)
                """
                for item in items:
                    cursor.execute(sql_item, (
                        order_id,
                        item.get('dish_id'),
                        int(item.get('quantity', 1)),
                        float(item.get('price', 0))
                    ))

                    # 更新菜品销量
                    cursor.execute(
                        "UPDATE dishes SET sales = sales + %s WHERE id = %s",
                        (int(item.get('quantity', 1)), item.get('dish_id'))
                    )

                connection.commit()

                return {
                    'order_id': order_id,
                    'total_amount': round(total_amount, 2),
                    'status': status,
                    'item_count': total_quantity,
                    'created_at': datetime.now().isoformat()
                }
        except Exception:
            connection.rollback()
            raise
        finally:
            connection.close()

    @staticmethod
    def update_status(order_id, status, user_id=None):
        """更新订单状态，可选校验所属用户"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                if user_id:
                    sql = "UPDATE orders SET status = %s WHERE id = %s AND user_id = %s"
                    cursor.execute(sql, (status, order_id, user_id))
                else:
                    sql = "UPDATE orders SET status = %s WHERE id = %s"
                    cursor.execute(sql, (status, order_id))
                connection.commit()
                return cursor.rowcount > 0
        finally:
            connection.close()

    @staticmethod
    def get_user_sales_stats(user_id):
        """获取用户的销售统计信息"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                # 获取总销售额和总销售数量
                sql_total = """
                    SELECT 
                        COALESCE(SUM(o.total_amount), 0) as total_revenue,
                        COALESCE(SUM(oi.quantity), 0) as total_quantity
                    FROM orders o
                    LEFT JOIN order_items oi ON o.id = oi.order_id
                    WHERE o.user_id = %s AND o.status = 'completed'
                """
                cursor.execute(sql_total, (user_id,))
                total_stats = cursor.fetchone()
                
                # 获取销售最多的菜品
                sql_top_dish = """
                    SELECT 
                        d.id,
                        d.name,
                        d.image_url,
                        SUM(oi.quantity) as total_sold
                    FROM order_items oi
                    JOIN orders o ON oi.order_id = o.id
                    JOIN dishes d ON oi.dish_id = d.id
                    WHERE o.user_id = %s AND o.status = 'completed'
                    GROUP BY d.id, d.name, d.image_url
                    ORDER BY total_sold DESC
                    LIMIT 1
                """
                cursor.execute(sql_top_dish, (user_id,))
                top_dish = cursor.fetchone()
                
                return {
                    'total_revenue': float(total_stats['total_revenue']) if total_stats else 0.0,
                    'total_quantity': int(total_stats['total_quantity']) if total_stats else 0,
                    'top_dish': {
                        'id': top_dish['id'],
                        'name': top_dish['name'],
                        'image_url': top_dish.get('image_url', ''),
                        'total_sold': int(top_dish['total_sold'])
                    } if top_dish else None
                }
        finally:
            connection.close()
    
    @staticmethod
    def get_user_orders(user_id, limit=10):
        """获取用户的订单列表"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                sql = """
                    SELECT 
                        o.id,
                        o.total_amount,
                        o.status,
                        o.created_at,
                        COUNT(oi.id) as item_count
                    FROM orders o
                    LEFT JOIN order_items oi ON o.id = oi.order_id
                    WHERE o.user_id = %s
                    GROUP BY o.id, o.total_amount, o.status, o.created_at
                    ORDER BY o.created_at DESC
                    LIMIT %s
                """
                cursor.execute(sql, (user_id, limit))
                results = cursor.fetchall()
                
                orders = []
                for row in results:
                    orders.append({
                        'id': row['id'],
                        'total_amount': float(row['total_amount']),
                        'status': row['status'],
                        'created_at': row['created_at'].isoformat() if row['created_at'] else None,
                        'item_count': int(row['item_count']) if row['item_count'] else 0
                    })
                return orders
        finally:
            connection.close()

