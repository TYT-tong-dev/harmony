"""通知数据模型"""
from models.database import get_db_connection


class NotificationModel:
    """通知模型，处理通知的增删改查"""
    
    # 通知类型常量
    TYPE_ORDER = 'order'
    TYPE_MESSAGE = 'message'
    TYPE_FOLLOW = 'follow'
    TYPE_SYSTEM = 'system'
    
    @staticmethod
    def create(user_id, notification_type, title, content, related_id=None, related_type=None):
        """创建通知"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                sql = """
                    INSERT INTO notifications (user_id, type, title, content, related_id, related_type)
                    VALUES (%s, %s, %s, %s, %s, %s)
                """
                cursor.execute(sql, (user_id, notification_type, title, content, related_id, related_type))
                notification_id = cursor.lastrowid
                connection.commit()
                return {
                    'id': notification_id,
                    'user_id': user_id,
                    'type': notification_type,
                    'title': title,
                    'content': content,
                    'related_id': related_id,
                    'related_type': related_type,
                    'is_read': False
                }
        finally:
            connection.close()
    
    @staticmethod
    def create_order_notification(merchant_user_id, order_id, table_id, total_amount, item_count):
        """创建订单通知（给商家）"""
        title = '📋 新订单提醒'
        content = f'{table_id}号桌下单，{item_count}件商品，¥{total_amount:.2f}'
        return NotificationModel.create(
            user_id=merchant_user_id,
            notification_type=NotificationModel.TYPE_ORDER,
            title=title,
            content=content,
            related_id=order_id,
            related_type='order'
        )
    
    @staticmethod
    def create_message_notification(receiver_id, sender_name, message_content, conversation_id, message_id):
        """创建消息通知"""
        title = f'💬 {sender_name}'
        # 截断过长内容
        display_content = message_content[:50] + '...' if len(message_content) > 50 else message_content
        return NotificationModel.create(
            user_id=receiver_id,
            notification_type=NotificationModel.TYPE_MESSAGE,
            title=title,
            content=display_content,
            related_id=message_id,
            related_type='conversation'
        )
    
    @staticmethod
    def get_user_notifications(user_id, limit=20, offset=0, unread_only=False):
        """获取用户通知列表"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                if unread_only:
                    sql = """
                        SELECT id, user_id, type, title, content, related_id, related_type, 
                               is_read, created_at
                        FROM notifications 
                        WHERE user_id = %s AND is_read = 0
                        ORDER BY created_at DESC
                        LIMIT %s OFFSET %s
                    """
                else:
                    sql = """
                        SELECT id, user_id, type, title, content, related_id, related_type, 
                               is_read, created_at
                        FROM notifications 
                        WHERE user_id = %s
                        ORDER BY created_at DESC
                        LIMIT %s OFFSET %s
                    """
                cursor.execute(sql, (user_id, limit, offset))
                rows = cursor.fetchall()
                return [{
                    'id': row['id'],
                    'user_id': row['user_id'],
                    'type': row['type'],
                    'title': row['title'],
                    'content': row['content'],
                    'related_id': row['related_id'],
                    'related_type': row['related_type'],
                    'is_read': bool(row['is_read']),
                    'created_at': row['created_at'].isoformat() if row['created_at'] else None
                } for row in rows]
        finally:
            connection.close()
    
    @staticmethod
    def get_unread_count(user_id):
        """获取未读通知数量"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                sql = "SELECT COUNT(*) as count FROM notifications WHERE user_id = %s AND is_read = 0"
                cursor.execute(sql, (user_id,))
                result = cursor.fetchone()
                return result['count'] if result else 0
        finally:
            connection.close()
    
    @staticmethod
    def mark_as_read(notification_id, user_id):
        """标记通知为已读"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                sql = "UPDATE notifications SET is_read = 1 WHERE id = %s AND user_id = %s"
                cursor.execute(sql, (notification_id, user_id))
                connection.commit()
                return cursor.rowcount > 0
        finally:
            connection.close()
    
    @staticmethod
    def mark_all_as_read(user_id):
        """标记所有通知为已读"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                sql = "UPDATE notifications SET is_read = 1 WHERE user_id = %s AND is_read = 0"
                cursor.execute(sql, (user_id,))
                connection.commit()
                return cursor.rowcount
        finally:
            connection.close()
    
    @staticmethod
    def delete_notification(notification_id, user_id):
        """删除通知"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                sql = "DELETE FROM notifications WHERE id = %s AND user_id = %s"
                cursor.execute(sql, (notification_id, user_id))
                connection.commit()
                return cursor.rowcount > 0
        finally:
            connection.close()

