"""店铺数据模型"""
from .database import get_db_connection


class ShopModel:
    """店铺模型"""

    @staticmethod
    def get_info(shop_id=1):
        """获取店铺信息"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                sql = """
                    SELECT s.id, s.shop_name, s.description, s.address, s.phone, 
                           s.business_hours, s.created_at,
                           (SELECT COUNT(*) FROM orders o WHERE o.shop_id = s.id 
                            AND DATE(o.created_at) = CURDATE()) as todayOrders,
                           (SELECT COALESCE(SUM(total_amount), 0) FROM orders o 
                            WHERE o.shop_id = s.id AND DATE(o.created_at) = CURDATE()) as todayRevenue
                    FROM shops s
                    WHERE s.id = %s
                """
                cursor.execute(sql, (shop_id,))
                shop = cursor.fetchone()
                
                if not shop:
                    # 如果店铺不存在，返回默认值
                    return {
                        'id': shop_id,
                        'shop_name': '食光记',
                        'name': '食光记餐厅',
                        'description': '专注健康美食的智慧餐厅，提供每日新鲜菜品。',
                        'business_hours': '09:00-22:00',
                        'address': '宁夏大学中卫校区',
                        'phone': '13800138000',
                        'score': 4.8,
                        'todayOrders': 0,
                        'todayRevenue': 0.0,
                        'latitude': 37.5149,
                        'longitude': 105.1965
                    }
                
                # 格式化店铺数据
                return {
                    'id': shop['id'],
                    'shop_name': shop['shop_name'],
                    'name': shop['shop_name'],
                    'description': shop.get('description', ''),
                    'business_hours': shop.get('business_hours', '09:00-22:00'),
                    'address': shop.get('address', ''),
                    'phone': shop.get('phone', ''),
                    'score': 4.8,  # 默认评分
                    'todayOrders': shop.get('todayOrders', 0),
                    'todayRevenue': float(shop.get('todayRevenue', 0)),
                    'latitude': 37.5149,  # 默认坐标
                    'longitude': 105.1965
                }
        finally:
            connection.close()

    @staticmethod
    def create_or_update(shop_id, shop_name, description="", address="", 
                        phone="", business_hours=""):
        """创建或更新店铺信息"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                # 检查店铺是否存在
                check_sql = "SELECT id FROM shops WHERE id = %s"
                cursor.execute(check_sql, (shop_id,))
                exists = cursor.fetchone()
                
                if exists:
                    # 更新
                    sql = """
                        UPDATE shops 
                        SET shop_name = %s, description = %s, address = %s, 
                            phone = %s, business_hours = %s
                        WHERE id = %s
                    """
                    cursor.execute(sql, (shop_name, description, address, phone, business_hours, shop_id))
                else:
                    # 创建（需要user_id，这里使用1作为默认值）
                    sql = """
                        INSERT INTO shops (id, user_id, shop_name, description, address, phone, business_hours)
                        VALUES (%s, 1, %s, %s, %s, %s, %s)
                    """
                    cursor.execute(sql, (shop_id, shop_name, description, address, phone, business_hours))
                
                connection.commit()
                return ShopModel.get_info(shop_id)
        except Exception as e:
            connection.rollback()
            raise e
        finally:
            connection.close()

