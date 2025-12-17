"""创建 follows 表"""
from models.database import get_db_connection

def create_follows_table():
    """创建用户关注表"""
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            sql = """
            CREATE TABLE IF NOT EXISTS follows (
                id INT AUTO_INCREMENT PRIMARY KEY,
                follower_id INT NOT NULL,
                following_id INT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE KEY uniq_follow (follower_id, following_id),
                INDEX idx_follower (follower_id),
                INDEX idx_following (following_id),
                CONSTRAINT fk_follows_follower FOREIGN KEY (follower_id) REFERENCES users(id) ON DELETE CASCADE,
                CONSTRAINT fk_follows_following FOREIGN KEY (following_id) REFERENCES users(id) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
            """
            cursor.execute(sql)
            connection.commit()
            print("follows 表创建成功!")
    except Exception as e:
        print(f"创建表失败: {e}")
    finally:
        connection.close()

if __name__ == "__main__":
    create_follows_table()

