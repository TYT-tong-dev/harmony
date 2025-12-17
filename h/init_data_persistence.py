"""初始化数据持久化 - 确保数据库表和数据正确初始化"""
from models.database import get_db_connection
from models.shop_model import ShopModel
from models.dish_model import DishModel


def init_default_shop():
    """初始化默认店铺"""
    try:
        shop = ShopModel.get_info(1)
        if not shop or shop.get('id') != 1:
            # 创建默认店铺
            ShopModel.create_or_update(
                shop_id=1,
                shop_name="食光记",
                description="专注健康美食的智慧餐厅，提供每日新鲜菜品。",
                address="宁夏大学中卫校区",
                phone="13800138000",
                business_hours="09:00-22:00"
            )
            print("✓ 默认店铺初始化成功")
        else:
            print("✓ 默认店铺已存在")
    except Exception as e:
        print(f"✗ 初始化默认店铺失败: {str(e)}")


def init_default_dishes():
    """初始化默认菜品（如果数据库为空）"""
    try:
        dishes = DishModel.get_all(1)
        if len(dishes) == 0:
            # 添加默认菜品
            default_dishes = [
                {
                    "name": "招牌番茄牛腩",
                    "description": "慢炖牛腩配以新鲜番茄，汤汁浓郁。",
                    "price": 38.0,
                    "category": "热菜",
                    "is_recommended": True,
                },
                {
                    "name": "香辣小龙虾",
                    "description": "精选麻辣口味，香辣过瘾。",
                    "price": 58.0,
                    "category": "特色",
                    "is_recommended": True,
                },
                {
                    "name": "清炒时蔬",
                    "description": "每日新鲜蔬菜，清爽不油腻。",
                    "price": 18.0,
                    "category": "素菜",
                    "is_recommended": False,
                },
            ]
            
            for dish_data in default_dishes:
                DishModel.create(
                    shop_id=1,
                    name=dish_data["name"],
                    description=dish_data["description"],
                    price=dish_data["price"],
                    category=dish_data["category"],
                    is_recommended=dish_data["is_recommended"]
                )
            print(f"✓ 初始化了 {len(default_dishes)} 个默认菜品")
        else:
            print(f"✓ 数据库中已有 {len(dishes)} 个菜品")
    except Exception as e:
        print(f"✗ 初始化默认菜品失败: {str(e)}")


def init_data_persistence():
    """初始化数据持久化"""
    print("开始初始化数据持久化...")
    
    # 初始化默认店铺
    init_default_shop()
    
    # 初始化默认菜品
    init_default_dishes()
    
    print("数据持久化初始化完成！")


if __name__ == "__main__":
    init_data_persistence()

