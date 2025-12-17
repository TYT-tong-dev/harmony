"""评论数据模型"""
from .database import get_db_connection


class CommentModel:
    """评论模型"""

    @staticmethod
    def get_by_post_id(post_id):
        """根据帖子ID获取评论列表"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                sql = """
                    SELECT c.id, c.user_id, c.post_id, c.content, c.created_at,
                           u.username, u.avatar
                    FROM comments c
                    JOIN users u ON c.user_id = u.id
                    WHERE c.post_id = %s
                    ORDER BY c.created_at ASC
                """
                cursor.execute(sql, (post_id,))
                comments = cursor.fetchall()
                
                # 格式化评论数据
                formatted_comments = []
                for comment in comments:
                    formatted_comment = {
                        'id': comment['id'],
                        'user_id': comment['user_id'],
                        'post_id': comment['post_id'],
                        'content': comment['content'],
                        'username': comment['username'],
                        'avatar': comment.get('avatar', ''),
                        'createTime': int(comment['created_at'].timestamp()) if comment.get('created_at') else 0
                    }
                    formatted_comments.append(formatted_comment)
                
                return formatted_comments
        finally:
            connection.close()

    @staticmethod
    def create(post_id, user_id, content):
        """创建评论"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                # 插入评论
                sql = """
                    INSERT INTO comments (post_id, user_id, content)
                    VALUES (%s, %s, %s)
                """
                cursor.execute(sql, (post_id, user_id, content))
                comment_id = cursor.lastrowid
                
                # 更新帖子的评论数
                update_sql = "UPDATE posts SET comment_count = comment_count + 1 WHERE id = %s"
                cursor.execute(update_sql, (post_id,))
                
                connection.commit()
                
                # 获取更新后的评论数
                count_sql = "SELECT comment_count FROM posts WHERE id = %s"
                cursor.execute(count_sql, (post_id,))
                comment_count = cursor.fetchone()['comment_count']
                
                return {
                    'comment_id': comment_id,
                    'comment_count': comment_count
                }
        except Exception as e:
            connection.rollback()
            raise e
        finally:
            connection.close()

    @staticmethod
    def delete(comment_id):
        """删除评论"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                # 获取评论的post_id
                get_sql = "SELECT post_id FROM comments WHERE id = %s"
                cursor.execute(get_sql, (comment_id,))
                result = cursor.fetchone()
                if not result:
                    return False
                
                post_id = result['post_id']
                
                # 删除评论
                delete_sql = "DELETE FROM comments WHERE id = %s"
                cursor.execute(delete_sql, (comment_id,))
                
                # 更新帖子的评论数
                update_sql = "UPDATE posts SET comment_count = GREATEST(0, comment_count - 1) WHERE id = %s"
                cursor.execute(update_sql, (post_id,))
                
                connection.commit()
                return True
        except Exception as e:
            connection.rollback()
            raise e
        finally:
            connection.close()

