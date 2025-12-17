import os
import pymysql
from config import config


def init_database():
	"""从 schema.sql 初始化数据库（自动创建数据库与表）。"""
	db_config = config['default']
	schema_path = os.path.join(os.path.dirname(__file__), 'schema.sql')

	if not os.path.exists(schema_path):
		print('未找到 schema.sql，初始化中止。')
		return

	# 先连接不指定数据库，执行 CREATE DATABASE 与后续脚本
	connection = pymysql.connect(
		host=db_config.DB_HOST,
		port=db_config.DB_PORT,
		user=db_config.DB_USER,
		password=db_config.DB_PASSWORD,
		charset='utf8mb4',
		autocommit=True
	)

	try:
		with open(schema_path, 'r', encoding='utf-8') as f:
			sql_script = f.read()

		with connection.cursor() as cursor:
			for statement in [s.strip() for s in sql_script.split(';') if s.strip()]:
				cursor.execute(statement)

		print('数据库初始化成功！')
	except Exception as e:
		print(f'数据库初始化失败: {str(e)}')
	finally:
		connection.close()


if __name__ == '__main__':
	init_database()