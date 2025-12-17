#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""创建通知表脚本"""

import pymysql
from config import Config

def create_notifications_table():
    """创建 notifications 表"""
    conn = pymysql.connect(
        host=Config.DB_HOST,
        port=Config.DB_PORT,
        user=Config.DB_USER,
        password=Config.DB_PASSWORD,
        database=Config.DB_NAME,
        charset='utf8mb4'
    )
    
    cursor = conn.cursor()
    
    # 创建 notifications 表
    sql = '''
    CREATE TABLE IF NOT EXISTS notifications (
      id INT AUTO_INCREMENT PRIMARY KEY,
      user_id INT NOT NULL,
      type VARCHAR(50) NOT NULL,
      title VARCHAR(200) NOT NULL,
      content TEXT NOT NULL,
      related_id INT DEFAULT NULL,
      related_type VARCHAR(50) DEFAULT NULL,
      is_read TINYINT(1) DEFAULT 0,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      INDEX idx_user_id (user_id),
      INDEX idx_type (type),
      INDEX idx_is_read (is_read),
      INDEX idx_created_at (created_at),
      CONSTRAINT fk_notifications_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    '''
    
    try:
        cursor.execute(sql)
        conn.commit()
        print('✅ notifications 表创建成功!')
    except Exception as e:
        print(f'❌ 创建失败: {e}')
    
    # 检查表是否存在
    cursor.execute('SHOW TABLES LIKE "notifications"')
    result = cursor.fetchone()
    if result:
        print('✅ 表已存在: notifications')
        cursor.execute('DESCRIBE notifications')
        columns = cursor.fetchall()
        print('表结构:')
        for col in columns:
            print(f'  - {col[0]}: {col[1]}')
    else:
        print('❌ 表不存在')
    
    cursor.close()
    conn.close()

if __name__ == '__main__':
    create_notifications_table()

