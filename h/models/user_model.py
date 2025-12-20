from models.database import get_db_connection
from utils.password_utils import hash_password, verify_password
from datetime import datetime

class UserModel:
    @staticmethod
    def find_by_username(username):
        """根据用户名查找用户"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                sql = """
                    SELECT id, username, password, user_type, email, avatar, address, created_at, last_login
                    FROM users WHERE username = %s
                """
                cursor.execute(sql, (username,))
                return cursor.fetchone()
        finally:
            connection.close()
    
    @staticmethod
    def create_user(username, password, email=None, avatar=None, user_type='user'):
        """创建新用户"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                hashed_pwd = hash_password(password)
                sql = """
                    INSERT INTO users (username, password, email, user_type, avatar) 
                    VALUES (%s, %s, %s, %s, %s)
                """
                cursor.execute(sql, (username, hashed_pwd, email, user_type, avatar))
                connection.commit()
                return cursor.lastrowid
        finally:
            connection.close()
    
    @staticmethod
    def update_last_login(user_id):
        """更新最后登录时间"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                sql = "UPDATE users SET last_login = %s WHERE id = %s"
                cursor.execute(sql, (datetime.now(), user_id))
                connection.commit()
        finally:
            connection.close()
    
    @staticmethod
    def find_by_id(user_id):
        """根据ID查找用户"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                sql = """
                    SELECT id, username, password, user_type, email, avatar, address, created_at, last_login
                    FROM users WHERE id = %s
                """
                cursor.execute(sql, (user_id,))
                return cursor.fetchone()
        finally:
            connection.close()
    
    @staticmethod
    def update_user_profile(user_id, username=None, avatar=None, address=None):
        """更新用户资料（头像、昵称、地址）"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                updates = []
                params = []
                
                if username is not None:
                    updates.append("username = %s")
                    params.append(username)
                
                if avatar is not None:
                    updates.append("avatar = %s")
                    params.append(avatar)
                
                if address is not None:
                    updates.append("address = %s")
                    params.append(address)
                
                if not updates:
                    return False
                
                params.append(user_id)
                sql = f"UPDATE users SET {', '.join(updates)} WHERE id = %s"
                cursor.execute(sql, params)
                connection.commit()
                return cursor.rowcount > 0
        finally:
            connection.close()
    
    @staticmethod
    def update_password(user_id, new_password):
        """更新用户密码"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                hashed_pwd = hash_password(new_password)
                sql = "UPDATE users SET password = %s WHERE id = %s"
                cursor.execute(sql, (hashed_pwd, user_id))
                connection.commit()
                return cursor.rowcount > 0
        finally:
            connection.close()
    
    @staticmethod
    def update_email(user_id, new_email):
        """更新用户邮箱"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                sql = "UPDATE users SET email = %s WHERE id = %s"
                cursor.execute(sql, (new_email, user_id))
                connection.commit()
                return cursor.rowcount > 0
        finally:
            connection.close()
    
    @staticmethod
    def search_users(keyword):
        """根据关键词搜索用户（用户名或邮箱）"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                if keyword:
                    sql = """
                        SELECT id, username, email, user_type, avatar, created_at, last_login
                        FROM users 
                        WHERE username LIKE %s OR email LIKE %s
                        ORDER BY username
                        LIMIT 50
                    """
                    search_pattern = f'%{keyword}%'
                    cursor.execute(sql, (search_pattern, search_pattern))
                else:
                    sql = """
                        SELECT id, username, email, user_type, avatar, created_at, last_login
                        FROM users 
                        ORDER BY username
                        LIMIT 50
                    """
                    cursor.execute(sql)
                results = cursor.fetchall()
                # 转换为字典列表，排除密码字段
                users = []
                for row in results:
                    user = {
                        'id': row['id'],
                        'username': row['username'],
                        'email': row.get('email', ''),
                        'type': row.get('user_type', 'user'),  # 前端期望type字段
                        'avatar': row.get('avatar', ''),
                        'created_at': row.get('created_at').isoformat() if row.get('created_at') else None,
                        'last_login': row.get('last_login').isoformat() if row.get('last_login') else None
                    }
                    users.append(user)
                return users
        finally:
            connection.close()


    @staticmethod
    def find_by_huawei_open_id(huawei_open_id):
        """根据华为OpenID查找用户"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                sql = """
                    SELECT id, username, password, user_type, email, avatar, address, 
                           created_at, last_login, huawei_open_id, huawei_union_id
                    FROM users WHERE huawei_open_id = %s
                """
                cursor.execute(sql, (huawei_open_id,))
                return cursor.fetchone()
        finally:
            connection.close()

    @staticmethod
    def create_huawei_user(username, password, email, avatar, huawei_open_id, huawei_union_id, display_name):
        """创建华为账号关联的用户"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                hashed_pwd = hash_password(password)
                sql = """
                    INSERT INTO users (username, password, email, user_type, avatar, huawei_open_id, huawei_union_id)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                """
                cursor.execute(sql, (username, hashed_pwd, email, 'customer', avatar, huawei_open_id, huawei_union_id))
                connection.commit()
                return cursor.lastrowid
        finally:
            connection.close()

    @staticmethod
    def update_huawei_user_info(user_id, display_name, avatar_uri):
        """更新华为用户信息"""
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                updates = []
                params = []
                
                if avatar_uri:
                    updates.append("avatar = %s")
                    params.append(avatar_uri)
                
                if not updates:
                    return True
                
                params.append(user_id)
                sql = f"UPDATE users SET {', '.join(updates)} WHERE id = %s"
                cursor.execute(sql, params)
                connection.commit()
                return cursor.rowcount > 0
        finally:
            connection.close()
