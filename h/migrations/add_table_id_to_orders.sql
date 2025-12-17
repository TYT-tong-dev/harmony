-- 迁移脚本：为orders表添加table_id字段（支持顾客扫码点餐）
-- 执行时间：2025-12-03

-- 添加table_id字段
ALTER TABLE orders ADD COLUMN IF NOT EXISTS table_id VARCHAR(50) DEFAULT NULL COMMENT '桌号（顾客扫码点餐）' AFTER shop_id;

-- 添加remark字段
ALTER TABLE orders ADD COLUMN IF NOT EXISTS remark TEXT DEFAULT NULL COMMENT '订单备注' AFTER status;

-- 添加updated_at字段
ALTER TABLE orders ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER created_at;

-- 修改user_id为可空（支持匿名顾客下单）
ALTER TABLE orders MODIFY COLUMN user_id INT DEFAULT NULL;

-- 修改shop_id默认值
ALTER TABLE orders MODIFY COLUMN shop_id INT DEFAULT 1;

-- 添加索引
CREATE INDEX IF NOT EXISTS idx_table_id ON orders(table_id);
CREATE INDEX IF NOT EXISTS idx_status ON orders(status);

-- 删除外键约束（如果存在），允许匿名下单
-- ALTER TABLE orders DROP FOREIGN KEY IF EXISTS fk_orders_user;
-- ALTER TABLE orders DROP FOREIGN KEY IF EXISTS fk_orders_shop;

