"""帖子数据模型"""
from .database import get_db_connection
from models.user_model import UserModel


class PostModel:
    """帖子模型"""

    @staticmethod
    def get_list(page=1, limit=10, category="推荐", current_user_id=None, following_ids=None):
        """获取帖子列表"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                offset = (page - 1) * limit
                
                # 构建查询条件
                where_clauses = []
                params = []
                
                # 如果是"关注"分类
                if category == "关注":
                    # following_ids为None表示用户未登录，为[]表示没有关注任何人
                    if following_ids is None or len(following_ids) == 0:
                        # 没有关注任何人，返回空列表
                        return {
                            'posts': [],
                            'total': 0,
                            'page': page,
                            'limit': limit,
                            'pages': 0
                        }
                    else:
                        placeholders = ', '.join(['%s'] * len(following_ids))
                        where_clauses.append(f"p.user_id IN ({placeholders})")
                        params.extend(following_ids)
                
                where_sql = " WHERE " + " AND ".join(where_clauses) if where_clauses else ""
                
                # 获取帖子列表
                sql = f"""
                    SELECT p.id, p.user_id, p.title, p.content, p.image_urls, 
                           p.likes, p.comment_count, p.created_at,
                           u.username, u.avatar
                    FROM posts p
                    JOIN users u ON p.user_id = u.id
                    {where_sql}
                    ORDER BY p.created_at DESC
                    LIMIT %s OFFSET %s
                """
                params.extend([limit, offset])
                cursor.execute(sql, params)
                posts = cursor.fetchall()
                
                # 获取总数
                count_sql = f"SELECT COUNT(*) as total FROM posts p {where_sql}"
                cursor.execute(count_sql, params[:-2])  # 去掉limit和offset参数
                total = cursor.fetchone()['total']
                
                # 格式化帖子数据
                formatted_posts = []
                for post in posts:
                    # 解析图片URLs
                    image_urls = post.get('image_urls', '') or ''
                    images = [url.strip() for url in image_urls.split(',') if url.strip()]
                    
                    # 检查当前用户是否点赞
                    is_liked = False
                    if current_user_id:
                        like_sql = "SELECT id FROM post_likes WHERE user_id = %s AND post_id = %s"
                        cursor.execute(like_sql, (current_user_id, post['id']))
                        is_liked = cursor.fetchone() is not None
                    
                    formatted_post = {
                        'id': post['id'],
                        'user_id': post['user_id'],
                        'username': post['username'],
                        'avatar': post.get('avatar', ''),
                        'content': post['content'],
                        'title': post.get('title', ''),
                        'imageUrls': image_urls,
                        'images': images,
                        'videos': [],  # 暂时不支持视频
                        'likeCount': post.get('likes', 0),
                        'commentCount': post.get('comment_count', 0),
                        'isLiked': is_liked,
                        'isFollowed': False,  # 将在API层设置
                        'createTime': int(post['created_at'].timestamp()) if post.get('created_at') else 0
                    }
                    formatted_posts.append(formatted_post)
                
                return {
                    'posts': formatted_posts,
                    'total': total,
                    'page': page,
                    'limit': limit,
                    'pages': (total + limit - 1) // limit if limit else 1
                }
        finally:
            connection.close()

    @staticmethod
    def create(user_id, title, content, image_urls=""):
        """创建帖子"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                sql = """
                    INSERT INTO posts (user_id, title, content, image_urls)
                    VALUES (%s, %s, %s, %s)
                """
                cursor.execute(sql, (user_id, title, content, image_urls))
                connection.commit()
                return PostModel.get_by_id(cursor.lastrowid)
        except Exception as e:
            connection.rollback()
            raise e
        finally:
            connection.close()

    @staticmethod
    def get_by_id(post_id):
        """根据ID获取帖子"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                sql = """
                    SELECT p.id, p.user_id, p.title, p.content, p.image_urls, 
                           p.likes, p.comment_count, p.created_at,
                           u.username, u.avatar
                    FROM posts p
                    JOIN users u ON p.user_id = u.id
                    WHERE p.id = %s
                """
                cursor.execute(sql, (post_id,))
                return cursor.fetchone()
        finally:
            connection.close()

    @staticmethod
    def like_post(post_id, user_id):
        """点赞/取消点赞帖子"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                # 检查是否已点赞
                check_sql = "SELECT id FROM post_likes WHERE user_id = %s AND post_id = %s"
                cursor.execute(check_sql, (user_id, post_id))
                existing = cursor.fetchone()
                
                if existing:
                    # 取消点赞
                    delete_sql = "DELETE FROM post_likes WHERE user_id = %s AND post_id = %s"
                    cursor.execute(delete_sql, (user_id, post_id))
                    # 更新点赞数
                    update_sql = "UPDATE posts SET likes = GREATEST(0, likes - 1) WHERE id = %s"
                    cursor.execute(update_sql, (post_id,))
                    is_liked = False
                else:
                    # 添加点赞
                    insert_sql = "INSERT INTO post_likes (user_id, post_id) VALUES (%s, %s)"
                    cursor.execute(insert_sql, (user_id, post_id))
                    # 更新点赞数
                    update_sql = "UPDATE posts SET likes = likes + 1 WHERE id = %s"
                    cursor.execute(update_sql, (post_id,))
                    is_liked = True
                
                connection.commit()
                
                # 获取更新后的点赞数
                count_sql = "SELECT likes FROM posts WHERE id = %s"
                cursor.execute(count_sql, (post_id,))
                likes = cursor.fetchone()['likes']
                
                return {'is_liked': is_liked, 'likes': likes}
        except Exception as e:
            connection.rollback()
            raise e
        finally:
            connection.close()

    @staticmethod
    def delete(post_id):
        """删除帖子"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                sql = "DELETE FROM posts WHERE id = %s"
                cursor.execute(sql, (post_id,))
                connection.commit()
                return cursor.rowcount > 0
        except Exception as e:
            connection.rollback()
            raise e
        finally:
            connection.close()

