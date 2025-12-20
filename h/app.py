import os
from flask import Flask, jsonify, render_template, request, send_from_directory
from flask_cors import CORS
from config import config
from utils.logger import setup_logging

# 华为元服务APP ID
HUAWEI_APP_ID = '6917591161906879671'
HUAWEI_PACKAGE_NAME = f'com.atomicservice.{HUAWEI_APP_ID}'

def create_app(config_name):
    app = Flask(__name__, template_folder='templates', static_folder='static')
    app.config.from_object(config[config_name])
    
    # 确保静态文件目录存在
    static_dir = os.path.join(os.path.dirname(__file__), 'static')
    images_dir = os.path.join(static_dir, 'images', 'dishes')
    os.makedirs(images_dir, exist_ok=True)

    # 设置日志
    setup_logging(app)

    # 启用CORS
    CORS(app)

    # 注册蓝图
    from api.user_routes import user_bp
    from api.auth_routes import auth_bp
    from api.data_routes import data_bp
    from api.customer_routes import customer_bp
    from api.payment_routes import payment_bp

    app.register_blueprint(user_bp, url_prefix='/api')
    app.register_blueprint(auth_bp, url_prefix='/api')
    app.register_blueprint(data_bp, url_prefix='/api')
    app.register_blueprint(customer_bp, url_prefix='/api')
    app.register_blueprint(payment_bp, url_prefix='/api/payment')

    # 初始化桌位表
    from models.table_model import TableModel
    with app.app_context():
        TableModel.init_table()

    # 首页 - 引导页面
    @app.route('/')
    def index():
        return '''
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>餐饮点餐系统</title>
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body {
                    font-family: -apple-system, sans-serif;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    min-height: 100vh;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    padding: 20px;
                }
                .card {
                    background: white;
                    border-radius: 20px;
                    padding: 40px;
                    text-align: center;
                    max-width: 400px;
                    box-shadow: 0 20px 60px rgba(0,0,0,0.3);
                }
                h1 { font-size: 28px; margin-bottom: 10px; }
                .icon { font-size: 60px; margin-bottom: 20px; }
                p { color: #666; margin-bottom: 30px; }
                .btn {
                    display: block;
                    padding: 14px 24px;
                    margin: 10px 0;
                    border-radius: 10px;
                    text-decoration: none;
                    font-weight: 600;
                }
                .btn-primary { background: #667eea; color: white; }
                .btn-secondary { background: #f0f0f0; color: #333; }
            </style>
        </head>
        <body>
            <div class="card">
                <div class="icon">🍽️</div>
                <h1>餐饮点餐系统</h1>
                <p>扫码点餐 · 智慧经营</p>
                <a href="/scan/table/A01" class="btn btn-primary">体验扫码点餐</a>
                <a href="/h5/order?table=A01" class="btn btn-secondary">H5网页点餐</a>
                <a href="/health" class="btn btn-secondary">API状态</a>
            </div>
        </body>
        </html>
        '''

    # 健康检查路由
    @app.route('/health')
    def health_check():
        return {'status': 'healthy', 'service': 'Harmony Login API'}

    # 图片服务路由
    @app.route('/images/dishes/<path:filename>')
    def serve_dish_image(filename):
        """提供菜品图片"""
        images_dir = os.path.join(os.path.dirname(__file__), 'static', 'images', 'dishes')
        return send_from_directory(images_dir, filename)

    @app.route('/images/<path:filename>')
    def serve_image(filename):
        """提供通用图片"""
        images_dir = os.path.join(os.path.dirname(__file__), 'static', 'images')
        return send_from_directory(images_dir, filename)

    # 华为App Linking验证文件 (applinking.json)
    @app.route('/.well-known/applinking.json')
    def huawei_app_linking():
        """华为App Linking域名验证文件"""
        return jsonify({
            "applinking": {
                "apps": [
                    {
                        "appIdentifier": HUAWEI_PACKAGE_NAME
                    }
                ]
            }
        })

    # Android assetlinks.json (备用)
    @app.route('/.well-known/assetlinks.json')
    def android_asset_links():
        """Android App Links验证文件"""
        return jsonify([
            {
                "relation": ["delegate_permission/common.handle_all_urls"],
                "target": {
                    "namespace": "android_app",
                    "package_name": HUAWEI_PACKAGE_NAME,
                    "sha256_cert_fingerprints": []
                }
            }
        ])

    # 扫码跳转页面
    @app.route('/scan/table/<table_number>')
    def scan_table_redirect(table_number):
        """顾客扫码后的中转页面"""
        from models.table_model import TableModel

        # 查询桌位信息
        table = TableModel.get_by_number(table_number)
        if not table:
            return render_template('scan_redirect.html',
                table_id=table_number,
                table_number=table_number,
                h5_order_url=f"/h5/order?table={table_number}",
                download_url="/download"
            )

        # 获取服务器地址
        server_host = request.host_url.rstrip('/')

        return render_template('scan_redirect.html',
            table_id=table['table_number'],
            table_number=table['table_number'],
            table_name=table.get('table_name', ''),
            h5_order_url=f"{server_host}/h5/order?table={table['table_number']}",
            download_url=f"{server_host}/download"
        )

    # H5点餐页面
    @app.route('/h5/order')
    def h5_order_page():
        """H5网页点餐"""
        table = request.args.get('table', '未知')
        server_host = request.host_url.rstrip('/')
        return render_template('h5_order.html',
            table_number=table,
            api_base=f"{server_host}/api"
        )

    # 下载页面
    @app.route('/download')
    def download_page():
        """App下载页面"""
        return '''
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>下载点餐App</title>
            <style>
                body { font-family: sans-serif; padding: 40px 20px; text-align: center; background: #f5f5f5; }
                .card { background: white; padding: 30px; border-radius: 16px; max-width: 360px; margin: 0 auto; }
                h1 { color: #333; margin-bottom: 20px; }
                .btn { display: block; padding: 15px; background: #667eea; color: white; text-decoration: none; border-radius: 10px; margin: 10px 0; }
            </style>
        </head>
        <body>
            <div class="card">
                <h1>📱 下载点餐App</h1>
                <p>支持鸿蒙/安卓设备</p>
                <a href="#" class="btn">华为应用市场下载</a>
                <a href="#" class="btn" style="background: #34c759;">安卓APK直接下载</a>
            </div>
        </body>
        </html>
        '''

    return app