"""桌位数据模型"""
from .database import get_db_connection

class TableModel:
    """桌位模型"""

    @staticmethod
    def init_table():
        """初始化桌位表"""
        conn = get_db_connection()
        try:
            cursor = conn.cursor()
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS tables_info (
                    id INT PRIMARY KEY AUTO_INCREMENT,
                    table_number VARCHAR(20) NOT NULL UNIQUE,
                    table_name VARCHAR(50),
                    capacity INT DEFAULT 4,
                    status VARCHAR(20) DEFAULT 'available',
                    qr_code_url TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
                )
            ''')
            conn.commit()

            # 初始化默认桌位
            TableModel._init_default_tables()
        finally:
            conn.close()

    @staticmethod
    def _init_default_tables():
        """初始化默认桌位数据"""
        conn = get_db_connection()
        try:
            cursor = conn.cursor()

            # 检查是否已有数据
            cursor.execute('SELECT COUNT(*) as cnt FROM tables_info')
            result = cursor.fetchone()
            count = result['cnt'] if result else 0
            if count > 0:
                return

            # 创建默认桌位 A01-A10, B01-B10
            for prefix in ['A', 'B']:
                for i in range(1, 11):
                    table_number = f'{prefix}{i:02d}'
                    table_name = f'{prefix}区{i}号桌'
                    capacity = 4 if prefix == 'A' else 6
                    cursor.execute(
                        'INSERT INTO tables_info (table_number, table_name, capacity, status) VALUES (%s, %s, %s, %s)',
                        (table_number, table_name, capacity, 'available')
                    )
            conn.commit()
        finally:
            conn.close()

    @staticmethod
    def get_all():
        """获取所有桌位"""
        conn = get_db_connection()
        try:
            cursor = conn.cursor()
            cursor.execute('SELECT * FROM tables_info ORDER BY table_number')
            rows = cursor.fetchall()
            return rows if rows else []
        finally:
            conn.close()

    @staticmethod
    def get_by_id(table_id: int):
        """根据ID获取桌位"""
        conn = get_db_connection()
        try:
            cursor = conn.cursor()
            cursor.execute('SELECT * FROM tables_info WHERE id = %s', (table_id,))
            row = cursor.fetchone()
            return row
        finally:
            conn.close()

    @staticmethod
    def get_by_number(table_number: str):
        """根据桌号获取桌位"""
        conn = get_db_connection()
        try:
            cursor = conn.cursor()
            cursor.execute('SELECT * FROM tables_info WHERE table_number = %s', (table_number,))
            row = cursor.fetchone()
            return row
        finally:
            conn.close()

    @staticmethod
    def create(table_number: str, table_name: str = None, capacity: int = 4):
        """创建桌位"""
        conn = get_db_connection()
        try:
            cursor = conn.cursor()
            cursor.execute(
                'INSERT INTO tables_info (table_number, table_name, capacity) VALUES (%s, %s, %s)',
                (table_number, table_name or f'{table_number}号桌', capacity)
            )
            conn.commit()
            return TableModel.get_by_id(cursor.lastrowid)
        finally:
            conn.close()

    @staticmethod
    def update_status(table_id: int, status: str):
        """更新桌位状态"""
        conn = get_db_connection()
        try:
            cursor = conn.cursor()
            cursor.execute(
                'UPDATE tables_info SET status = %s WHERE id = %s',
                (status, table_id)
            )
            conn.commit()
            return TableModel.get_by_id(table_id)
        finally:
            conn.close()

    @staticmethod
    def delete(table_id: int):
        """删除桌位"""
        conn = get_db_connection()
        try:
            cursor = conn.cursor()
            cursor.execute('DELETE FROM tables_info WHERE id = %s', (table_id,))
            conn.commit()
            return cursor.rowcount > 0
        finally:
            conn.close()

