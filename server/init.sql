-- ============================================
-- CampusTrade 数据库初始化脚本
-- 说明：
-- 1. 这是纯 SQL 版本，可直接在 OpenGauss 客户端执行
-- 2. 执行前请先确认当前连接的数据库就是 campus_trade
-- 3. 如果已有旧数据，本脚本会清空测试数据，但不会删表
-- ============================================

BEGIN;

-- 用户表
CREATE TABLE IF NOT EXISTS users (
	id SERIAL PRIMARY KEY,
	username VARCHAR(50) UNIQUE NOT NULL,
	password VARCHAR(255) NOT NULL,
	real_name VARCHAR(50),
	role VARCHAR(20) DEFAULT 'user',
	campus VARCHAR(50),
	avatar VARCHAR(255),
	status SMALLINT DEFAULT 1,
	created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 分类表
CREATE TABLE IF NOT EXISTS categories (
	id SERIAL PRIMARY KEY,
	name VARCHAR(50) NOT NULL,
	parent_id INTEGER DEFAULT 0,
	sort_order INTEGER DEFAULT 0,
	created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 商品表
CREATE TABLE IF NOT EXISTS items (
	id SERIAL PRIMARY KEY,
	title VARCHAR(100) NOT NULL,
	description TEXT,
	price DECIMAL(10,2) NOT NULL,
	original_price DECIMAL(10,2),
	category_id INTEGER NOT NULL,
	user_id INTEGER NOT NULL,
	status VARCHAR(20) DEFAULT 'pending',
	views_count INTEGER DEFAULT 0,
	favorites_count INTEGER DEFAULT 0,
	campus VARCHAR(50),
	contact_info VARCHAR(100),
	created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	FOREIGN KEY (category_id) REFERENCES categories(id),
	FOREIGN KEY (user_id) REFERENCES users(id)
);

-- 收藏表
CREATE TABLE IF NOT EXISTS favorites (
	user_id INTEGER NOT NULL,
	item_id INTEGER NOT NULL,
	created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	PRIMARY KEY (user_id, item_id),
	FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
	FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE
);

-- 浏览记录表
CREATE TABLE IF NOT EXISTS views_log (
	id SERIAL PRIMARY KEY,
	user_id INTEGER,
	item_id INTEGER NOT NULL,
	viewed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
	FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_views_log_user ON views_log(user_id);
CREATE INDEX IF NOT EXISTS idx_views_log_item ON views_log(item_id);

-- 初始化分类
INSERT INTO categories (name, parent_id, sort_order)
SELECT '学习用品', 0, 1 WHERE NOT EXISTS (SELECT 1 FROM categories WHERE name = '学习用品' AND parent_id = 0);
INSERT INTO categories (name, parent_id, sort_order)
SELECT '生活用品', 0, 2 WHERE NOT EXISTS (SELECT 1 FROM categories WHERE name = '生活用品' AND parent_id = 0);
INSERT INTO categories (name, parent_id, sort_order)
SELECT '交通工具', 0, 3 WHERE NOT EXISTS (SELECT 1 FROM categories WHERE name = '交通工具' AND parent_id = 0);
INSERT INTO categories (name, parent_id, sort_order)
SELECT '数码产品', 0, 4 WHERE NOT EXISTS (SELECT 1 FROM categories WHERE name = '数码产品' AND parent_id = 0);

-- 清空测试数据
DELETE FROM favorites;
DELETE FROM views_log;
DELETE FROM items;
DELETE FROM users;

-- 重置序列，避免测试数据 user_id 与注释不一致
ALTER SEQUENCE IF EXISTS users_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS items_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS views_log_id_seq RESTART WITH 1;

-- 测试用户
INSERT INTO users (username, password, real_name, role, campus) VALUES
('admin', '123456', '超级管理员', 'admin', NULL),
('operator', '123456', '运营人员', 'operator', NULL),
('zhangsan', '123456', '张三', 'user', '沪东校区'),
('lisi', '123456', '李四', 'user', '延长校区');

-- 测试商品
INSERT INTO items (title, description, price, category_id, user_id, status) VALUES
('iPhone 13 九成新', '自用 iPhone 13，电池健康 92%，无划痕', 3800, 4, 3, 'on_sale'),
('高数教材同济第七版', '几乎全新，无笔记', 25, 1, 3, 'on_sale'),
('山地自行车', '骑了一年，车况良好，带坐垫', 350, 3, 4, 'on_sale'),
('台灯', '宿舍用小台灯，亮度可调', 45, 2, 4, 'on_sale'),
('笔记本电脑支架', '铝合金材质，折叠便携', 88, 4, 3, 'sold');

COMMIT;