"""菜品数据模型"""
from .database import get_db_connection


class DishModel:
    """菜品模型"""

    @staticmethod
    def get_all(shop_id=1):
        """获取所有菜品"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                sql = """
                    SELECT id, name, description, cooking_method, price, image_url, category, 
                           is_recommended, status, created_at,
                           (SELECT COUNT(*) FROM order_items oi 
                            JOIN orders o ON oi.order_id = o.id 
                            WHERE oi.dish_id = dishes.id) as sales
                    FROM dishes
                    WHERE shop_id = %s
                    ORDER BY created_at DESC
                """
                cursor.execute(sql, (shop_id,))
                return cursor.fetchall()
        finally:
            connection.close()

    @staticmethod
    def get_by_id(dish_id):
        """根据ID获取菜品"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                sql = """
                    SELECT id, name, description, cooking_method, price, image_url, category, 
                           is_recommended, status, created_at,
                           (SELECT COUNT(*) FROM order_items oi 
                            JOIN orders o ON oi.order_id = o.id 
                            WHERE oi.dish_id = dishes.id) as sales
                    FROM dishes
                    WHERE id = %s
                """
                cursor.execute(sql, (dish_id,))
                return cursor.fetchone()
        finally:
            connection.close()

    @staticmethod
    def create(shop_id, name, description="", cooking_method="", price=0.0, image_url="", 
               category="", is_recommended=False, status="available"):
        """创建菜品"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                sql = """
                    INSERT INTO dishes (shop_id, name, description, cooking_method, price, image_url, 
                                      category, is_recommended, status)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                """
                cursor.execute(sql, (shop_id, name, description, cooking_method, price, image_url, 
                                   category, is_recommended, status))
                connection.commit()
                return DishModel.get_by_id(cursor.lastrowid)
        except Exception as e:
            connection.rollback()
            raise e
        finally:
            connection.close()

    @staticmethod
    def update(dish_id, name=None, description=None, cooking_method=None, price=None, image_url=None,
               category=None, is_recommended=None, status=None):
        """更新菜品"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                updates = []
                params = []
                
                if name is not None:
                    updates.append("name = %s")
                    params.append(name)
                if description is not None:
                    updates.append("description = %s")
                    params.append(description)
                if cooking_method is not None:
                    updates.append("cooking_method = %s")
                    params.append(cooking_method)
                if price is not None:
                    updates.append("price = %s")
                    params.append(price)
                if image_url is not None:
                    updates.append("image_url = %s")
                    params.append(image_url)
                if category is not None:
                    updates.append("category = %s")
                    params.append(category)
                if is_recommended is not None:
                    updates.append("is_recommended = %s")
                    params.append(is_recommended)
                if status is not None:
                    updates.append("status = %s")
                    params.append(status)
                
                if not updates:
                    return DishModel.get_by_id(dish_id)
                
                params.append(dish_id)
                sql = f"UPDATE dishes SET {', '.join(updates)} WHERE id = %s"
                cursor.execute(sql, params)
                connection.commit()
                return DishModel.get_by_id(dish_id)
        except Exception as e:
            connection.rollback()
            raise e
        finally:
            connection.close()

    @staticmethod
    def delete(dish_id):
        """删除菜品"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                sql = "DELETE FROM dishes WHERE id = %s"
                cursor.execute(sql, (dish_id,))
                connection.commit()
                return cursor.rowcount > 0
        except Exception as e:
            connection.rollback()
            raise e
        finally:
            connection.close()

