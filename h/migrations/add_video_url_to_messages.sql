-- 为messages表添加video_url字段
ALTER TABLE messages ADD COLUMN IF NOT EXISTS video_url VARCHAR(255) DEFAULT NULL AFTER voice_duration;

