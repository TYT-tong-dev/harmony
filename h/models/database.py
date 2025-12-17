import pymysql
from config import config

def get_db_connection():
    """获取数据库连接"""
    return pymysql.connect(
        host=config['default'].DB_HOST,
        port=config['default'].DB_PORT,
        user=config['default'].DB_USER,
        password=config['default'].DB_PASSWORD,
        database=config['default'].DB_NAME,
        charset='utf8mb4',
        cursorclass=pymysql.cursors.DictCursor
    )