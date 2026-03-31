-- 用户表
-- role: admin（后台管理员）/ user（前台普通用户）/ operator（后台运营）
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    real_name VARCHAR(50),
    role VARCHAR(20) DEFAULT 'user',
    campus VARCHAR(50),
    avatar VARCHAR(255),
    status SMALLINT DEFAULT 1,          -- 1: 正常, 0: 禁用
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);