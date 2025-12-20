import pymysql

conn = pymysql.connect(
    host='localhost', 
    port=3306, 
    user='root', 
    password='123456', 
    database='harmony_app', 
    charset='utf8mb4', 
    cursorclass=pymysql.cursors.DictCursor
)
cursor = conn.cursor()
cursor.execute('SELECT id, user_id, title, likes, comment_count FROM posts')
posts = cursor.fetchall()
print("数据库中的帖子:")
print("-" * 60)
for p in posts:
    print(f"ID:{p['id']} | 用户ID:{p['user_id']} | 点赞:{p['likes']} | 评论:{p['comment_count']}")
    print(f"   标题: {p['title']}")
print("-" * 60)
print(f"共 {len(posts)} 条帖子")
conn.close()
