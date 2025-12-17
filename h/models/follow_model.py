from models.database import get_db_connection


class FollowModel:
    @staticmethod
    def follow_user(follower_id, following_id):
        """关注用户"""
        if follower_id == following_id:
            return False, "不能关注自己"
        
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                # 检查被关注用户是否存在
                sql = "SELECT id FROM users WHERE id = %s"
                cursor.execute(sql, (following_id,))
                if not cursor.fetchone():
                    return False, "用户不存在"
                
                # 检查是否已关注
                sql = "SELECT id FROM follows WHERE follower_id = %s AND following_id = %s"
                cursor.execute(sql, (follower_id, following_id))
                if cursor.fetchone():
                    return False, "已经关注过了"
                
                # 添加关注
                sql = "INSERT INTO follows (follower_id, following_id) VALUES (%s, %s)"
                cursor.execute(sql, (follower_id, following_id))
                connection.commit()
                return True, "关注成功"
        except Exception as e:
            connection.rollback()
            return False, f"关注失败: {str(e)}"
        finally:
            connection.close()

    @staticmethod
    def unfollow_user(follower_id, following_id):
        """取消关注"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                sql = "DELETE FROM follows WHERE follower_id = %s AND following_id = %s"
                cursor.execute(sql, (follower_id, following_id))
                connection.commit()
                return cursor.rowcount > 0
        finally:
            connection.close()

    @staticmethod
    def is_following(follower_id, following_id):
        """检查是否已关注"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                sql = "SELECT id FROM follows WHERE follower_id = %s AND following_id = %s"
                cursor.execute(sql, (follower_id, following_id))
                return cursor.fetchone() is not None
        finally:
            connection.close()

    @staticmethod
    def get_following_list(user_id, page=1, limit=20):
        """获取关注列表（我关注的人）"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                offset = (page - 1) * limit
                
                # 获取关注列表
                sql = """
                    SELECT u.id, u.username, u.avatar, u.email, f.created_at as follow_time
                    FROM follows f
                    JOIN users u ON f.following_id = u.id
                    WHERE f.follower_id = %s
                    ORDER BY f.created_at DESC
                    LIMIT %s OFFSET %s
                """
                cursor.execute(sql, (user_id, limit, offset))
                users = cursor.fetchall()
                
                # 获取总数
                cursor.execute(
                    "SELECT COUNT(*) as total FROM follows WHERE follower_id = %s",
                    (user_id,)
                )
                total = cursor.fetchone()['total']
                
                return {
                    'users': users,
                    'total': total,
                    'page': page,
                    'limit': limit,
                    'pages': (total + limit - 1) // limit
                }
        finally:
            connection.close()

    @staticmethod
    def get_followers_list(user_id, page=1, limit=20):
        """获取粉丝列表（关注我的人）"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                offset = (page - 1) * limit
                
                sql = """
                    SELECT u.id, u.username, u.avatar, u.email, f.created_at as follow_time
                    FROM follows f
                    JOIN users u ON f.follower_id = u.id
                    WHERE f.following_id = %s
                    ORDER BY f.created_at DESC
                    LIMIT %s OFFSET %s
                """
                cursor.execute(sql, (user_id, limit, offset))
                users = cursor.fetchall()
                
                cursor.execute(
                    "SELECT COUNT(*) as total FROM follows WHERE following_id = %s",
                    (user_id,)
                )
                total = cursor.fetchone()['total']
                
                return {
                    'users': users,
                    'total': total,
                    'page': page,
                    'limit': limit,
                    'pages': (total + limit - 1) // limit
                }
        finally:
            connection.close()

    @staticmethod
    def get_follow_stats(user_id):
        """获取关注统计（关注数、粉丝数）"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                # 关注数
                cursor.execute(
                    "SELECT COUNT(*) as count FROM follows WHERE follower_id = %s",
                    (user_id,)
                )
                following_count = cursor.fetchone()['count']
                
                # 粉丝数
                cursor.execute(
                    "SELECT COUNT(*) as count FROM follows WHERE following_id = %s",
                    (user_id,)
                )
                followers_count = cursor.fetchone()['count']
                
                return {
                    'following_count': following_count,
                    'followers_count': followers_count
                }
        finally:
            connection.close()

    @staticmethod
    def check_following_batch(follower_id, user_ids):
        """批量检查是否已关注"""
        if not user_ids:
            return {}
        
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                placeholders = ', '.join(['%s'] * len(user_ids))
                sql = f"""
                    SELECT following_id FROM follows 
                    WHERE follower_id = %s AND following_id IN ({placeholders})
                """
                cursor.execute(sql, [follower_id] + list(user_ids))
                results = cursor.fetchall()
                following_ids = {row['following_id'] for row in results}
                return {uid: uid in following_ids for uid in user_ids}
        finally:
            connection.close()

    @staticmethod
    def get_following_ids(follower_id):
        """获取用户关注的所有用户ID列表"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                sql = "SELECT following_id FROM follows WHERE follower_id = %s"
                cursor.execute(sql, (follower_id,))
                results = cursor.fetchall()
                return [row['following_id'] for row in results]
        finally:
            connection.close()

