from models.database import get_db_connection
from datetime import datetime
import time


class DishReviewModel:
    @staticmethod
    def get_by_dish_id(dish_id, page=1, limit=20):
        """获取菜品的评价列表"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                offset = (page - 1) * limit
                
                sql = """
                    SELECT dr.id, dr.dish_id, dr.user_id, dr.rating, dr.content, dr.created_at,
                           u.username, u.avatar
                    FROM dish_reviews dr
                    JOIN users u ON dr.user_id = u.id
                    WHERE dr.dish_id = %s
                    ORDER BY dr.created_at DESC
                    LIMIT %s OFFSET %s
                """
                cursor.execute(sql, (dish_id, limit, offset))
                results = cursor.fetchall()
                
                reviews = []
                for row in results:
                    created_at = row.get('created_at')
                    if created_at:
                        # 转换为时间戳（毫秒）
                        if hasattr(created_at, 'timestamp'):
                            timestamp = int(created_at.timestamp() * 1000)
                        else:
                            timestamp = int(time.time() * 1000)
                    else:
                        timestamp = int(time.time() * 1000)
                    
                    reviews.append({
                        'id': row['id'],
                        'dish_id': row['dish_id'],
                        'user_id': row['user_id'],
                        'username': row['username'] or '匿名用户',
                        'avatar': row.get('avatar', '') or '',
                        'rating': row['rating'],
                        'content': row['content'] or '',
                        'created_at': timestamp
                    })
                
                return reviews
        finally:
            connection.close()

    @staticmethod
    def get_user_review(dish_id, user_id):
        """获取用户对某个菜品的评价"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                sql = """
                    SELECT dr.id, dr.dish_id, dr.user_id, dr.rating, dr.content, dr.created_at
                    FROM dish_reviews dr
                    WHERE dr.dish_id = %s AND dr.user_id = %s
                    LIMIT 1
                """
                cursor.execute(sql, (dish_id, user_id))
                result = cursor.fetchone()
                
                if result:
                    created_at = result.get('created_at')
                    if created_at:
                        if hasattr(created_at, 'timestamp'):
                            timestamp = int(created_at.timestamp() * 1000)
                        else:
                            timestamp = int(time.time() * 1000)
                    else:
                        timestamp = int(time.time() * 1000)
                    
                    return {
                        'id': result['id'],
                        'dish_id': result['dish_id'],
                        'user_id': result['user_id'],
                        'rating': result['rating'],
                        'content': result['content'] or '',
                        'created_at': timestamp
                    }
                return None
        finally:
            connection.close()

    @staticmethod
    def create(dish_id, user_id, rating, content):
        """创建或更新评价（如果已存在则更新）"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                # 检查是否已存在评价
                existing = DishReviewModel.get_user_review(dish_id, user_id)
                
                if existing:
                    # 更新现有评价
                    sql = """
                        UPDATE dish_reviews 
                        SET rating = %s, content = %s, created_at = NOW()
                        WHERE dish_id = %s AND user_id = %s
                    """
                    cursor.execute(sql, (rating, content, dish_id, user_id))
                    connection.commit()
                    review_id = existing['id']
                else:
                    # 创建新评价
                    sql = """
                        INSERT INTO dish_reviews (dish_id, user_id, rating, content)
                        VALUES (%s, %s, %s, %s)
                    """
                    cursor.execute(sql, (dish_id, user_id, rating, content))
                    connection.commit()
                    review_id = cursor.lastrowid
                
                # 获取用户信息
                from models.user_model import UserModel
                user = UserModel.find_by_id(user_id)
                
                created_at = int(time.time() * 1000)
                
                return {
                    'id': review_id,
                    'dish_id': dish_id,
                    'user_id': user_id,
                    'username': user['username'] if user else '匿名用户',
                    'avatar': user.get('avatar', '') if user else '',
                    'rating': rating,
                    'content': content,
                    'created_at': created_at
                }
        except Exception as e:
            connection.rollback()
            raise e
        finally:
            connection.close()

    @staticmethod
    def get_rating_stats(dish_id):
        """获取菜品的评分统计"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                sql = """
                    SELECT 
                        COUNT(*) as review_count,
                        AVG(rating) as avg_rating
                    FROM dish_reviews
                    WHERE dish_id = %s
                """
                cursor.execute(sql, (dish_id,))
                result = cursor.fetchone()
                
                if result and result['review_count']:
                    return {
                        'review_count': result['review_count'],
                        'avg_rating': round(float(result['avg_rating']), 1)
                    }
                else:
                    return {
                        'review_count': 0,
                        'avg_rating': 5.0
                    }
        finally:
            connection.close()

    @staticmethod
    def delete(review_id, user_id):
        """删除评价（只能删除自己的）"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                sql = "DELETE FROM dish_reviews WHERE id = %s AND user_id = %s"
                cursor.execute(sql, (review_id, user_id))
                connection.commit()
                return cursor.rowcount > 0
        except Exception as e:
            connection.rollback()
            raise e
        finally:
            connection.close()

