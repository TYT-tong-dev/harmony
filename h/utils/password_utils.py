import bcrypt

def hash_password(password):
    """加密密码"""
    return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

def verify_password(password, hashed):
    """验证密码"""
    if not hashed:
        return False

    try:
        return bcrypt.checkpw(password.encode('utf-8'), hashed.encode('utf-8'))
    except ValueError:
        # 非法哈希值（例如旧数据仍为明文）时，视为校验失败
        return False