# payment_routes.py - 支付相关API
from flask import Blueprint, request, jsonify
from functools import wraps
import jwt
import hashlib
import time
import random
import string
import json

payment_bp = Blueprint('payment', __name__)

# JWT密钥（与user_routes保持一致）
JWT_SECRET = 'harmony_app_secret_key_2024'

def token_required(f):
    """JWT token验证装饰器"""
    @wraps(f)
    def decorated(*args, **kwargs):
        token = request.headers.get('Authorization')
        if not token:
            return jsonify({'message': '缺少认证token'}), 401
        
        try:
            if token.startswith('Bearer '):
                token = token[7:]
            data = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
            request.user_id = data['user_id']
        except jwt.ExpiredSignatureError:
            return jsonify({'message': 'token已过期'}), 401
        except jwt.InvalidTokenError:
            return jsonify({'message': '无效的token'}), 401
        
        return f(*args, **kwargs)
    return decorated

def generate_nonce_str(length=32):
    """生成随机字符串"""
    chars = string.ascii_letters + string.digits
    return ''.join(random.choice(chars) for _ in range(length))

def generate_sign(params, api_key):
    """生成微信支付签名"""
    # 按字典序排序参数
    sorted_params = sorted(params.items(), key=lambda x: x[0])
    # 拼接字符串
    string_a = '&'.join([f'{k}={v}' for k, v in sorted_params if v])
    # 拼接API密钥
    string_sign_temp = f'{string_a}&key={api_key}'
    # MD5加密并转大写
    sign = hashlib.md5(string_sign_temp.encode('utf-8')).hexdigest().upper()
    return sign

@payment_bp.route('/wechat/create', methods=['POST'])
@token_required
def create_wechat_order():
    """创建微信预支付订单"""
    try:
        data = request.get_json()
        
        order_id = data.get('orderId')
        amount = data.get('amount')  # 单位：分
        description = data.get('description', '餐饮订单')
        items = data.get('items', [])
        
        if not order_id or not amount:
            return jsonify({'message': '缺少必要参数'}), 400
        
        # 微信支付配置（需要替换为实际的商户配置）
        # 注意：实际使用时需要从配置文件或环境变量读取
        WECHAT_APP_ID = 'wx_your_app_id'  # 微信AppID
        WECHAT_MCH_ID = 'your_mch_id'     # 商户号
        WECHAT_API_KEY = 'your_api_key'   # API密钥
        NOTIFY_URL = 'https://your-domain.com/api/payment/wechat/notify'  # 回调地址
        
        # 生成预支付参数
        nonce_str = generate_nonce_str()
        timestamp = str(int(time.time()))
        
        # 构建预支付请求参数
        prepay_params = {
            'appid': WECHAT_APP_ID,
            'mch_id': WECHAT_MCH_ID,
            'nonce_str': nonce_str,
            'body': description,
            'out_trade_no': order_id,
            'total_fee': amount,
            'spbill_create_ip': request.remote_addr or '127.0.0.1',
            'notify_url': NOTIFY_URL,
            'trade_type': 'APP'
        }
        
        # 生成签名
        sign = generate_sign(prepay_params, WECHAT_API_KEY)
        prepay_params['sign'] = sign
        
        # 实际应用中，这里需要调用微信统一下单API
        # response = requests.post('https://api.mch.weixin.qq.com/pay/unifiedorder', data=xml_data)
        # 解析返回的prepay_id
        
        # 模拟返回预支付数据（实际需要从微信API获取）
        prepay_id = f'wx{timestamp}{generate_nonce_str(16)}'
        
        # 构建APP调起支付的参数
        pay_params = {
            'appid': WECHAT_APP_ID,
            'partnerid': WECHAT_MCH_ID,
            'prepayid': prepay_id,
            'package': 'Sign=WXPay',
            'noncestr': nonce_str,
            'timestamp': timestamp
        }
        
        # 生成调起支付的签名
        pay_sign = generate_sign(pay_params, WECHAT_API_KEY)
        
        # 保存订单信息到数据库（实际应用中需要实现）
        # save_order_to_db(order_id, request.user_id, amount, items, 'wechat', 'pending')
        
        return jsonify({
            'prepayId': prepay_id,
            'appId': WECHAT_APP_ID,
            'partnerId': WECHAT_MCH_ID,
            'packageValue': 'Sign=WXPay',
            'nonceStr': nonce_str,
            'timeStamp': timestamp,
            'sign': pay_sign
        }), 200
        
    except Exception as e:
        print(f'创建微信订单失败: {str(e)}')
        return jsonify({'message': f'创建订单失败: {str(e)}'}), 500

@payment_bp.route('/wechat/notify', methods=['POST'])
def wechat_notify():
    """微信支付回调通知"""
    try:
        # 解析微信回调XML数据
        xml_data = request.data.decode('utf-8')
        
        # 实际应用中需要：
        # 1. 解析XML数据
        # 2. 验证签名
        # 3. 更新订单状态
        # 4. 返回成功响应给微信
        
        # 模拟处理成功
        print(f'收到微信支付回调: {xml_data}')
        
        # 返回成功响应
        return '''<xml>
            <return_code><![CDATA[SUCCESS]]></return_code>
            <return_msg><![CDATA[OK]]></return_msg>
        </xml>''', 200
        
    except Exception as e:
        print(f'处理微信回调失败: {str(e)}')
        return '''<xml>
            <return_code><![CDATA[FAIL]]></return_code>
            <return_msg><![CDATA[处理失败]]></return_msg>
        </xml>''', 500

@payment_bp.route('/huawei/verify', methods=['POST'])
@token_required
def verify_huawei_purchase():
    """验证华为支付购买"""
    try:
        data = request.get_json()
        
        purchase_token = data.get('purchaseToken')
        product_id = data.get('productId')
        order_id = data.get('orderId')
        
        if not purchase_token or not product_id:
            return jsonify({'message': '缺少必要参数'}), 400
        
        # 实际应用中需要调用华为服务器验证购买
        # 华为IAP服务端验证API: https://developer.huawei.com/consumer/cn/doc/development/HMSCore-References/api-order-verify-purchase-token-0000001050746113
        
        # 模拟验证成功
        # 更新订单状态为已支付
        # update_order_status(order_id, 'paid', 'huawei', purchase_token)
        
        return jsonify({
            'success': True,
            'message': '支付验证成功',
            'orderId': order_id
        }), 200
        
    except Exception as e:
        print(f'验证华为支付失败: {str(e)}')
        return jsonify({'message': f'验证失败: {str(e)}'}), 500

@payment_bp.route('/order/status', methods=['GET'])
@token_required
def get_order_status():
    """查询订单支付状态"""
    try:
        order_id = request.args.get('orderId')
        
        if not order_id:
            return jsonify({'message': '缺少订单号'}), 400
        
        # 实际应用中从数据库查询订单状态
        # order = get_order_by_id(order_id)
        
        # 模拟返回订单状态
        return jsonify({
            'orderId': order_id,
            'status': 'paid',  # pending, paid, failed, refunded
            'paymentMethod': 'huawei',
            'paidAt': int(time.time())
        }), 200
        
    except Exception as e:
        print(f'查询订单状态失败: {str(e)}')
        return jsonify({'message': f'查询失败: {str(e)}'}), 500
