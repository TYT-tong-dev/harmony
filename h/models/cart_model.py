"""购物车数据模型"""
from .database import get_db_connection
from models.dish_model import DishModel


class CartModel:
    """购物车模型"""

    @staticmethod
    def get_items(user_id):
        """获取购物车商品"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                sql = """
                    SELECT ci.id, ci.dish_id, ci.quantity, ci.created_at,
                           d.name, d.price, d.image_url, d.description
                    FROM cart_items ci
                    JOIN dishes d ON ci.dish_id = d.id
                    WHERE ci.user_id = %s
                    ORDER BY ci.created_at DESC
                """
                cursor.execute(sql, (user_id,))
                items = cursor.fetchall()
                
                # 格式化购物车数据
                formatted_items = []
                total_amount = 0.0
                total_quantity = 0
                
                for item in items:
                    quantity = item['quantity']
                    price = float(item['price'])
                    amount = quantity * price
                    
                    formatted_item = {
                        'dish_id': item['dish_id'],
                        'quantity': quantity,
                        'name': item['name'],
                        'price': price,
                        'image_url': item.get('image_url', ''),
                        'description': item.get('description', '')
                    }
                    formatted_items.append(formatted_item)
                    total_amount += amount
                    total_quantity += quantity
                
                return {
                    'items': formatted_items,
                    'total_amount': round(total_amount, 2),
                    'total_quantity': total_quantity
                }
        finally:
            connection.close()

    @staticmethod
    def add_item(user_id, dish_id, quantity=1):
        """添加商品到购物车"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                # 检查商品是否存在
                dish = DishModel.get_by_id(dish_id)
                if not dish:
                    return None
                
                # 检查购物车中是否已有该商品
                check_sql = "SELECT id, quantity FROM cart_items WHERE user_id = %s AND dish_id = %s"
                cursor.execute(check_sql, (user_id, dish_id))
                existing = cursor.fetchone()
                
                if existing:
                    # 更新数量
                    new_quantity = existing['quantity'] + quantity
                    update_sql = "UPDATE cart_items SET quantity = %s WHERE id = %s"
                    cursor.execute(update_sql, (new_quantity, existing['id']))
                else:
                    # 添加新商品
                    insert_sql = "INSERT INTO cart_items (user_id, dish_id, quantity) VALUES (%s, %s, %s)"
                    cursor.execute(insert_sql, (user_id, dish_id, quantity))
                
                connection.commit()
                return CartModel.get_items(user_id)
        except Exception as e:
            connection.rollback()
            raise e
        finally:
            connection.close()

    @staticmethod
    def update_item(user_id, dish_id, quantity):
        """更新购物车商品数量"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                if quantity <= 0:
                    # 删除商品
                    delete_sql = "DELETE FROM cart_items WHERE user_id = %s AND dish_id = %s"
                    cursor.execute(delete_sql, (user_id, dish_id))
                else:
                    # 更新数量
                    update_sql = "UPDATE cart_items SET quantity = %s WHERE user_id = %s AND dish_id = %s"
                    cursor.execute(update_sql, (quantity, user_id, dish_id))
                
                connection.commit()
                return CartModel.get_items(user_id)
        except Exception as e:
            connection.rollback()
            raise e
        finally:
            connection.close()

    @staticmethod
    def remove_item(user_id, dish_id):
        """从购物车移除商品"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                sql = "DELETE FROM cart_items WHERE user_id = %s AND dish_id = %s"
                cursor.execute(sql, (user_id, dish_id))
                connection.commit()
                return CartModel.get_items(user_id)
        except Exception as e:
            connection.rollback()
            raise e
        finally:
            connection.close()

    @staticmethod
    def clear(user_id):
        """清空购物车"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                sql = "DELETE FROM cart_items WHERE user_id = %s"
                cursor.execute(sql, (user_id,))
                connection.commit()
                return CartModel.get_items(user_id)
        except Exception as e:
            connection.rollback()
            raise e
        finally:
            connection.close()

