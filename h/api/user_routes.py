from flask import Blueprint, request
from models.user_model import UserModel
from utils.response_utils import success_response, error_response
from utils.jwt_utils import generate_token, login_required, decode_token
from utils.password_utils import verify_password, hash_password

user_bp = Blueprint('user', __name__)

@user_bp.route('/Users/Login', methods=['GET'])
def login():
    """用户登录接口"""
    username = request.args.get('username', '').strip()
    password = request.args.get('password', '').strip()

    if not username or not password:
        return error_response('用户名或密码不能为空', 400)

    user = UserModel.find_by_username(username)
    if not user:
        return error_response('用户不存在或密码错误', 401)

    if not verify_password(password, user['password']):
        return error_response('用户不存在或密码错误', 401)

    # 更新最后登录时间
    UserModel.update_last_login(user['id'])

    token = generate_token({'uid': user['id'], 'username': user['username'], 'userType': user.get('user_type', 'user')})

    user_info = {
        'id': user['id'],
        'username': user['username'],
        'email': user.get('email'),
        'userType': user.get('user_type', 'user'),
        'avatar': user.get('avatar', ''),
        'token': token,
    }
    return success_response('登录成功', user_info)

@user_bp.route('/Users/Register', methods=['POST'])
def register():
    """用户注册接口"""
    data = request.get_json(silent=True) or {}
    username = str(data.get('username', '')).strip()
    password = str(data.get('password', '')).strip()
    email = str(data.get('email', '')).strip()
    avatar = str(data.get('avatar', '')).strip() if data.get('avatar') else ''

    if not username or not password or not email:
        return error_response('用户名、密码、邮箱不能为空', 400)

    # 检查是否已存在
    existing = UserModel.find_by_username(username)
    if existing:
        return error_response('用户名已存在', 409)

    try:
        user_id = UserModel.create_user(username=username, password=password, email=email, avatar=avatar)
    except Exception as e:
        return error_response(f'注册失败: {str(e)}', 500)

    created = UserModel.find_by_username(username)
    user_info = {
        'id': user_id,
        'username': username,
        'email': email,
        'userType': created.get('user_type', 'user') if created else 'user',
        'avatar': created.get('avatar', '') if created else avatar,
    }
    return success_response('注册成功', user_info)

@user_bp.route('/Users/Profile', methods=['GET'])
@login_required
def get_profile(_jwt_claims=None):
    """获取用户资料"""
    try:
        user_id = _jwt_claims.get('uid') if _jwt_claims else None
        
        user = UserModel.find_by_id(user_id)
        if not user:
            return error_response('用户不存在', 404)
        
        user_info = {
            'id': user['id'],
            'username': user['username'],
            'email': user.get('email', ''),
            'userType': user.get('user_type', 'user'),
            'avatar': user.get('avatar', ''),
            'address': user.get('address', ''),
        }
        return success_response('获取成功', user_info)
    except Exception as e:
        return error_response(f'获取资料失败: {str(e)}', 500)

@user_bp.route('/Users/Profile', methods=['PUT'])
@login_required
def update_profile(_jwt_claims=None):
    """更新用户资料（头像、昵称、地址）"""
    try:
        user_id = _jwt_claims.get('uid') if _jwt_claims else None
        
        data = request.get_json(silent=True) or {}
        username = data.get('username', '').strip() if data.get('username') else None
        avatar = data.get('avatar', '').strip() if data.get('avatar') else None
        address = data.get('address', '').strip() if data.get('address') else None
        
        if not any([username, avatar, address]):
            return error_response('至少需要提供一个更新字段', 400)
        
        success = UserModel.update_user_profile(user_id, username=username, avatar=avatar, address=address)
        if success:
            user = UserModel.find_by_id(user_id)
            user_info = {
                'id': user['id'],
                'username': user['username'],
                'email': user.get('email', ''),
                'userType': user.get('user_type', 'user'),
                'avatar': user.get('avatar', ''),
                'address': user.get('address', ''),
            }
            return success_response('更新成功', user_info)
        else:
            return error_response('更新失败', 500)
    except Exception as e:
        return error_response(f'更新资料失败: {str(e)}', 500)

@user_bp.route('/Users/Password', methods=['PUT'])
@login_required
def update_password(_jwt_claims=None):
    """更新用户密码"""
    try:
        user_id = _jwt_claims.get('uid') if _jwt_claims else None
        
        data = request.get_json(silent=True) or {}
        old_password = data.get('old_password', '').strip()
        new_password = data.get('new_password', '').strip()
        
        if not old_password or not new_password:
            return error_response('旧密码和新密码不能为空', 400)
        
        user = UserModel.find_by_id(user_id)
        if not user:
            return error_response('用户不存在', 404)
        
        if not verify_password(old_password, user['password']):
            return error_response('旧密码错误', 401)
        
        success = UserModel.update_password(user_id, new_password)
        if success:
            return success_response('密码更新成功', {})
        else:
            return error_response('密码更新失败', 500)
    except Exception as e:
        return error_response(f'更新密码失败: {str(e)}', 500)

@user_bp.route('/Users/Email', methods=['PUT'])
@login_required
def update_email(_jwt_claims=None):
    """更新用户邮箱"""
    try:
        user_id = _jwt_claims.get('uid') if _jwt_claims else None
        
        data = request.get_json(silent=True) or {}
        new_email = data.get('email', '').strip()
        
        if not new_email:
            return error_response('邮箱不能为空', 400)
        
        success = UserModel.update_email(user_id, new_email)
        if success:
            user = UserModel.find_by_id(user_id)
            user_info = {
                'id': user['id'],
                'username': user['username'],
                'email': user.get('email', ''),
                'userType': user.get('user_type', 'user'),
                'avatar': user.get('avatar', ''),
                'address': user.get('address', ''),
            }
            return success_response('邮箱更新成功', user_info)
        else:
            return error_response('邮箱更新失败', 500)
    except Exception as e:
        return error_response(f'更新邮箱失败: {str(e)}', 500)


@user_bp.route('/Users/HuaweiLogin', methods=['POST'])
def huawei_login():
    """华为账号登录接口"""
    data = request.get_json(silent=True) or {}
    open_id = str(data.get('openID', '')).strip()
    union_id = str(data.get('unionID', '')).strip()
    display_name = str(data.get('displayName', '')).strip() or '华为用户'
    avatar_uri = str(data.get('avatarUri', '')).strip()
    authorization_code = str(data.get('authorizationCode', '')).strip()

    if not open_id:
        return error_response('缺少华为账号标识', 400)

    try:
        # 查找是否已有该华为账号关联的用户
        user = UserModel.find_by_huawei_open_id(open_id)
        
        if user:
            # 已有用户，更新信息并登录
            UserModel.update_huawei_user_info(user['id'], display_name, avatar_uri)
            UserModel.update_last_login(user['id'])
        else:
            # 新用户，创建账号
            # 生成唯一用户名
            username = f"huawei_{open_id[:8]}"
            # 检查用户名是否已存在，如果存在则添加随机后缀
            existing = UserModel.find_by_username(username)
            if existing:
                import time
                username = f"huawei_{open_id[:8]}_{int(time.time()) % 10000}"
            
            # 创建用户（使用随机密码，因为华为登录不需要密码）
            import secrets
            random_password = secrets.token_hex(16)
            email = f"{open_id[:8]}@huawei.user"
            
            user_id = UserModel.create_huawei_user(
                username=username,
                password=random_password,
                email=email,
                avatar=avatar_uri,
                huawei_open_id=open_id,
                huawei_union_id=union_id,
                display_name=display_name
            )
            user = UserModel.find_by_id(user_id)

        if not user:
            return error_response('创建用户失败', 500)

        # 生成token
        token = generate_token({
            'uid': user['id'],
            'username': user['username'],
            'userType': user.get('user_type', 'customer'),
            'loginType': 'huawei'
        })

        user_info = {
            'id': user['id'],
            'username': user['username'],
            'email': user.get('email', ''),
            'userType': user.get('user_type', 'customer'),
            'avatar': user.get('avatar', '') or avatar_uri,
            'displayName': display_name,
            'token': token,
            'loginType': 'huawei'
        }
        return success_response('华为账号登录成功', user_info)
    except Exception as e:
        return error_response(f'华为账号登录失败: {str(e)}', 500)
