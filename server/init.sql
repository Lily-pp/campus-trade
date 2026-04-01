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

-- 商品图片表
CREATE TABLE IF NOT EXISTS item_images (
	id SERIAL PRIMARY KEY,
	item_id INTEGER NOT NULL,
	image_url VARCHAR(500) NOT NULL,
	sort_order INTEGER DEFAULT 0,
	FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE
);

-- 兼容旧版本字段：若历史表仍是 url，则迁移为 image_url
DO $$
BEGIN
	IF EXISTS (
		SELECT 1
		FROM information_schema.columns
		WHERE table_schema = current_schema()
		  AND table_name = 'item_images'
		  AND column_name = 'url'
	) AND NOT EXISTS (
		SELECT 1
		FROM information_schema.columns
		WHERE table_schema = current_schema()
		  AND table_name = 'item_images'
		  AND column_name = 'image_url'
	) THEN
		EXECUTE 'ALTER TABLE item_images RENAME COLUMN url TO image_url';
	END IF;
END $$;

-- 订单表
CREATE TABLE IF NOT EXISTS orders (
	id SERIAL PRIMARY KEY,
	item_id INTEGER NOT NULL,
	buyer_id INTEGER NOT NULL,
	seller_id INTEGER NOT NULL,
	price DECIMAL(10,2) NOT NULL,
	status VARCHAR(20) DEFAULT 'pending',
	remark TEXT,
	created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	FOREIGN KEY (item_id) REFERENCES items(id),
	FOREIGN KEY (buyer_id) REFERENCES users(id),
	FOREIGN KEY (seller_id) REFERENCES users(id)
);

-- 举报表
CREATE TABLE IF NOT EXISTS reports (
	id SERIAL PRIMARY KEY,
	reporter_id INTEGER NOT NULL,
	target_type VARCHAR(20) NOT NULL,
	target_id INTEGER NOT NULL,
	reason VARCHAR(200) NOT NULL,
	status VARCHAR(20) DEFAULT 'pending',
	handled_by INTEGER,
	handled_at TIMESTAMP,
	created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	FOREIGN KEY (reporter_id) REFERENCES users(id),
	FOREIGN KEY (handled_by) REFERENCES users(id) ON DELETE SET NULL
);

-- 管理员操作日志表
CREATE TABLE IF NOT EXISTS admin_logs (
	id SERIAL PRIMARY KEY,
	admin_id INTEGER NOT NULL,
	action VARCHAR(100) NOT NULL,
	target_type VARCHAR(20),
	target_id INTEGER,
	detail TEXT,
	created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	FOREIGN KEY (admin_id) REFERENCES users(id)
);

-- 购物车表
CREATE TABLE IF NOT EXISTS cart (
	id SERIAL PRIMARY KEY,
	user_id INTEGER NOT NULL,
	item_id INTEGER NOT NULL,
	created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	UNIQUE(user_id, item_id),
	FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
	FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE
);

-- 私信消息表
CREATE TABLE IF NOT EXISTS messages (
	id SERIAL PRIMARY KEY,
	sender_id INTEGER NOT NULL,
	receiver_id INTEGER NOT NULL,
	item_id INTEGER,
	content TEXT NOT NULL,
	is_read SMALLINT DEFAULT 0,
	created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE,
	FOREIGN KEY (receiver_id) REFERENCES users(id) ON DELETE CASCADE,
	FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_messages_sender ON messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_receiver ON messages(receiver_id);
CREATE INDEX IF NOT EXISTS idx_cart_user ON cart(user_id);

-- 初始化分类
INSERT INTO categories (name, parent_id, sort_order)
SELECT '学习用品', 0, 1 WHERE NOT EXISTS (SELECT 1 FROM categories WHERE name = '学习用品' AND parent_id = 0);
INSERT INTO categories (name, parent_id, sort_order)
SELECT '生活用品', 0, 2 WHERE NOT EXISTS (SELECT 1 FROM categories WHERE name = '生活用品' AND parent_id = 0);
INSERT INTO categories (name, parent_id, sort_order)
SELECT '交通工具', 0, 3 WHERE NOT EXISTS (SELECT 1 FROM categories WHERE name = '交通工具' AND parent_id = 0);
INSERT INTO categories (name, parent_id, sort_order)
SELECT '数码产品', 0, 4 WHERE NOT EXISTS (SELECT 1 FROM categories WHERE name = '数码产品' AND parent_id = 0);

-- 清空测试数据（按外键依赖顺序）
DELETE FROM messages;
DELETE FROM cart;
DELETE FROM admin_logs;
DELETE FROM reports;
DELETE FROM orders;
DELETE FROM item_images;
DELETE FROM favorites;
DELETE FROM views_log;
DELETE FROM items;
DELETE FROM users;

-- 重置序列，避免测试数据 user_id 与注释不一致
ALTER SEQUENCE IF EXISTS users_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS items_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS views_log_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS orders_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS reports_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS admin_logs_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS cart_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS messages_id_seq RESTART WITH 1;

-- 测试用户
INSERT INTO users (username, password, real_name, role, campus) VALUES
('admin', '123456', '超级管理员', 'admin', NULL),
('operator', '123456', '运营人员', 'operator', NULL),
('zhangsan', '123456', '张三', 'user', '沪东校区'),
('lisi', '123456', '李四', 'user', '延长校区'),
('wangwu', '123456', '王五', 'user', '宝山校区');

-- 测试商品（user_id: 3=张三, 4=李四, 5=王五）
INSERT INTO items (title, description, price, category_id, user_id, status) VALUES
('iPhone 13 九成新', '自用 iPhone 13，电池健康 92%，无划痕', 3800, 4, 3, 'on_sale'),
('高数教材同济第七版', '几乎全新，无笔记', 25, 1, 3, 'on_sale'),
('山地自行车', '骑了一年，车况良好，带坐垫', 350, 3, 4, 'on_sale'),
('台灯', '宿舍用小台灯，亮度可调', 45, 2, 4, 'on_sale'),
('笔记本电脑支架', '铝合金材质，折叠便携', 88, 4, 3, 'sold'),
('英语四级真题合集', '2020-2024年真题，附答案解析', 30, 1, 5, 'on_sale'),
('机械键盘', '87键青轴，九成新', 180, 4, 5, 'pending');

-- 测试订单（buyer_id=4=李四 购买 item_id=1=iPhone）
INSERT INTO orders (item_id, buyer_id, seller_id, price, status)
VALUES (1, 4, 3, 3800, 'pending');

-- 测试举报
INSERT INTO reports (reporter_id, target_type, target_id, reason, status)
VALUES (4, 'item', 7, '商品描述与实物不符，疑似欺诈', 'pending');

COMMIT;