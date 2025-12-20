# 食光记 - 宁夏美食点餐应用

基于 HarmonyOS NEXT 开发的美食点餐与社交分享应用，后端使用 Python Flask 提供 API 服务。

## 功能特性

### 用户端
- 🍽️ 菜品浏览与搜索（按分类筛选）
- 🛒 购物车管理与下单
- 💳 华为支付集成
- ⭐ 菜品评价与评分
- 📱 发现页社交动态
- 👥 用户关注系统
- ❤️ 帖子点赞与评论

### 商家端
- 📊 菜品管理（增删改查）
- 📋 订单管理
- 🏪 店铺信息管理

## 技术栈

### 前端
- HarmonyOS NEXT (API 12)
- ArkTS / ArkUI
- 华为 IAP 支付

### 后端
- Python 3.x
- Flask 2.3.3
- MySQL 数据库
- PyJWT 认证

## 项目结构

```
├── entry/                  # 主模块（商家端）
│   └── src/main/ets/
│       ├── pages/          # 页面组件
│       │   ├── HomePage.ets        # 首页/菜品列表
│       │   ├── CartPage.ets        # 购物车
│       │   ├── DiscoverPage.ets    # 发现页
│       │   ├── DishDetailPage.ets  # 菜品详情
│       │   └── ...
│       └── common/         # 公共工具
│           └── Utils.ets   # API工具类
├── customer/               # 顾客端模块
├── h/                      # 后端服务
│   ├── api/               # API路由
│   ├── models/            # 数据模型
│   ├── static/            # 静态资源
│   ├── app.py             # Flask应用
│   └── config.py          # 配置文件
└── AppScope/              # 应用配置
```

## 环境要求

### 前端
- DevEco Studio 5.0+
- HarmonyOS SDK API 12
- 真机或模拟器

### 后端
- Python 3.8+
- MySQL 5.7+

## 快速开始

### 1. 配置数据库

```sql
CREATE DATABASE harmony_app CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

### 2. 启动后端服务

```bash
cd h
pip install -r requirements.txt
python run.py
```

服务默认运行在 `http://0.0.0.0:5000`

### 3. 配置前端

修改 `entry/src/main/ets/common/Utils.ets` 中的服务器地址：

```typescript
private static readonly BASE_URL: string = 'http://你的服务器IP:5000/api';
```

### 4. 运行应用

使用 DevEco Studio 打开项目，连接设备后运行。

## API 接口

### 用户认证
- `POST /api/Users/Login` - 用户登录
- `POST /api/Users/HuaweiLogin` - 华为账号登录

### 菜品管理
- `GET /api/dishes` - 获取菜品列表
- `POST /api/dishes` - 添加菜品
- `DELETE /api/dishes/<id>` - 删除菜品

### 帖子动态
- `GET /api/posts/list` - 获取帖子列表
- `POST /api/posts/create` - 发布帖子
- `POST /api/posts/<id>/like` - 点赞帖子

### 关注系统
- `POST /api/follow/<user_id>` - 关注用户
- `DELETE /api/follow/<user_id>` - 取消关注

## 数据库配置

在 `h/config.py` 中配置数据库连接：

```python
DB_HOST = 'localhost'
DB_PORT = 3306
DB_USER = 'root'
DB_PASSWORD = '123456'
DB_NAME = 'harmony_app'
```

## 许可证

MIT License
