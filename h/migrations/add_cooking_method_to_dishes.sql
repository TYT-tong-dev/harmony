-- 为dishes表添加cooking_method字段
ALTER TABLE dishes ADD COLUMN IF NOT EXISTS cooking_method VARCHAR(255) DEFAULT NULL AFTER description;

