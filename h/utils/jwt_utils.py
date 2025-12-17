import datetime
from functools import wraps

import jwt
from flask import request, jsonify, current_app


def generate_token(payload, expires_minutes=60):
    """生成 JWT"""
    secret = current_app.config.get('SECRET_KEY', 'dev-secret-key')
    issued_at = datetime.datetime.utcnow()
    expires_at = issued_at + datetime.timedelta(minutes=expires_minutes)
    claims = {
        **payload,
        'iat': issued_at,
        'exp': expires_at,
    }
    token = jwt.encode(claims, secret, algorithm='HS256')
    # PyJWT>=2 返回 str
    return token


def decode_token(token):
    """解析 JWT，校验签名与过期"""
    secret = current_app.config.get('SECRET_KEY', 'dev-secret-key')
    return jwt.decode(token, secret, algorithms=['HS256'])


def login_required(fn):
    """基于 JWT 的简单鉴权装饰器"""
    @wraps(fn)
    def wrapper(*args, **kwargs):
        auth_header = request.headers.get('Authorization', '')
        if not auth_header.startswith('Bearer '):
            return jsonify({'code': 401, 'message': '缺少或无效的认证头', 'data': None}), 401
        token = auth_header[7:].strip()
        try:
            claims = decode_token(token)
        except jwt.ExpiredSignatureError:
            return jsonify({'code': 401, 'message': '登录已过期', 'data': None}), 401
        except jwt.InvalidTokenError:
            return jsonify({'code': 401, 'message': '无效的令牌', 'data': None}), 401

        # 将 claims 透传给视图
        kwargs['_jwt_claims'] = claims
        return fn(*args, **kwargs)
    return wrapper

