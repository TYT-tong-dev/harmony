from flask import Blueprint, jsonify
from utils.jwt_utils import login_required

auth_bp = Blueprint('auth', __name__)

# 可以添加其他认证相关路由
@auth_bp.route('/auth/test')
@login_required
def test(_jwt_claims=None):
    return jsonify({'code': 0, 'message': 'ok', 'data': {'claims': _jwt_claims}})