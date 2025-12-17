import os
from app import create_app


def main():
    # 环境：development / production
    env = os.getenv('FLASK_ENV', 'development')
    app = create_app(env)
    host = app.config.get('API_HOST', '0.0.0.0')
    port = int(app.config.get('API_PORT', 5000))
    debug = app.config.get('DEBUG', True)

    app.run(host=host, port=port, debug=debug)


if __name__ == '__main__':
    main()


