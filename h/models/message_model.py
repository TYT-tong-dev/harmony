from models.database import get_db_connection
from datetime import datetime
import time


class MessageModel:
    @staticmethod
    def get_conversations(user_id):
        """获取用户的所有会话列表"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                sql = """
                    SELECT c.id, c.user1_id, c.user2_id, c.updated_at,
                           CASE WHEN c.user1_id = %s THEN u2.id ELSE u1.id END as other_user_id,
                           CASE WHEN c.user1_id = %s THEN u2.username ELSE u1.username END as username,
                           CASE WHEN c.user1_id = %s THEN u2.avatar ELSE u1.avatar END as avatar,
                           CASE WHEN c.user1_id = %s THEN u2.email ELSE u1.email END as email,
                           (SELECT content FROM messages WHERE conversation_id = c.id ORDER BY created_at DESC LIMIT 1) as last_content,
                           (SELECT created_at FROM messages WHERE conversation_id = c.id ORDER BY created_at DESC LIMIT 1) as last_time,
                           (SELECT COUNT(*) FROM messages WHERE conversation_id = c.id AND sender_id != %s AND is_read = 0) as unread_count
                    FROM conversations c
                    LEFT JOIN users u1 ON c.user1_id = u1.id
                    LEFT JOIN users u2 ON c.user2_id = u2.id
                    WHERE c.user1_id = %s OR c.user2_id = %s
                    ORDER BY c.updated_at DESC
                """
                cursor.execute(sql, (user_id, user_id, user_id, user_id, user_id, user_id, user_id))
                results = cursor.fetchall()
                conversations = []
                for row in results:
                    last_time = row.get('last_time')
                    if last_time:
                        last_time = int(last_time.timestamp()) if hasattr(last_time, 'timestamp') else int(time.time())
                    else:
                        last_time = int(row['updated_at'].timestamp()) if row.get('updated_at') else int(time.time())
                    
                    conv = {
                        'id': row['id'],
                        'conversationId': row['id'],
                        'userId': row['other_user_id'],
                        'username': row['username'] or '未知用户',
                        'avatar': row['avatar'] or '',
                        'email': row['email'] or '',
                        'lastContent': row['last_content'] or '',
                        'lastTime': last_time,
                        'unreadCount': row['unread_count'] or 0,
                        'isOnline': True
                    }
                    conversations.append(conv)
                return conversations
        finally:
            connection.close()

    @staticmethod
    def get_messages(conversation_id, user_id):
        """获取会话的消息列表"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                sql = """
                    SELECT id, conversation_id, sender_id, content, type, 
                           image_url, voice_url, voice_duration, video_url, is_read, created_at
                    FROM messages
                    WHERE conversation_id = %s
                    ORDER BY created_at ASC
                """
                cursor.execute(sql, (conversation_id,))
                results = cursor.fetchall()
                messages = []
                for row in results:
                    msg = {
                        'id': row['id'],
                        'content': row['content'] or '',
                        'time': int(row['created_at'].timestamp()) if row.get('created_at') else int(time.time()),
                        'isMe': row['sender_id'] == user_id,
                        'type': row['type'] or 'text',
                        'imageUrl': row['image_url'] or '',
                        'voiceUrl': row['voice_url'] or '',
                        'voiceDuration': row['voice_duration'] or 0,
                        'videoUrl': row['video_url'] or ''
                    }
                    messages.append(msg)
                return messages
        finally:
            connection.close()

    @staticmethod
    def send_message(conversation_id, sender_id, content, msg_type='text', image_url=None, voice_url=None, voice_duration=0, video_url=None):
        """发送消息"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                sql = """
                    INSERT INTO messages (conversation_id, sender_id, content, type, image_url, voice_url, voice_duration, video_url)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                """
                cursor.execute(sql, (conversation_id, sender_id, content, msg_type, image_url, voice_url, voice_duration, video_url))
                message_id = cursor.lastrowid
                
                # 更新会话的更新时间
                cursor.execute("UPDATE conversations SET updated_at = NOW() WHERE id = %s", (conversation_id,))
                connection.commit()
                
                return {
                    'id': message_id,
                    'content': content,
                    'time': int(time.time()),
                    'type': msg_type,
                    'imageUrl': image_url or '',
                    'voiceUrl': voice_url or '',
                    'voiceDuration': voice_duration,
                    'videoUrl': video_url or ''
                }
        finally:
            connection.close()

    @staticmethod
    def create_conversation(user1_id, user2_id):
        """创建会话"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                # 检查是否已存在会话
                sql = """
                    SELECT id FROM conversations 
                    WHERE (user1_id = %s AND user2_id = %s) OR (user1_id = %s AND user2_id = %s)
                """
                cursor.execute(sql, (user1_id, user2_id, user2_id, user1_id))
                existing = cursor.fetchone()
                if existing:
                    return existing['id'], False
                
                # 创建新会话
                sql = "INSERT INTO conversations (user1_id, user2_id) VALUES (%s, %s)"
                cursor.execute(sql, (user1_id, user2_id))
                connection.commit()
                return cursor.lastrowid, True
        finally:
            connection.close()

    @staticmethod
    def mark_messages_read(conversation_id, user_id):
        """标记消息为已读"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                sql = "UPDATE messages SET is_read = 1 WHERE conversation_id = %s AND sender_id != %s"
                cursor.execute(sql, (conversation_id, user_id))
                connection.commit()
                return cursor.rowcount
        finally:
            connection.close()

    @staticmethod
    def get_conversation_participant(conversation_id, sender_id):
        """获取会话的另一方参与者信息"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                sql = """
                    SELECT c.id, c.user1_id, c.user2_id,
                           CASE WHEN c.user1_id = %s THEN c.user2_id ELSE c.user1_id END as receiver_id,
                           CASE WHEN c.user1_id = %s THEN u2.username ELSE u1.username END as receiver_name,
                           CASE WHEN c.user1_id = %s THEN u1.username ELSE u2.username END as sender_name
                    FROM conversations c
                    LEFT JOIN users u1 ON c.user1_id = u1.id
                    LEFT JOIN users u2 ON c.user2_id = u2.id
                    WHERE c.id = %s
                """
                cursor.execute(sql, (sender_id, sender_id, sender_id, conversation_id))
                result = cursor.fetchone()
                if result:
                    return {
                        'receiver_id': result['receiver_id'],
                        'receiver_name': result['receiver_name'],
                        'sender_name': result['sender_name']
                    }
                return None
        finally:
            connection.close()
