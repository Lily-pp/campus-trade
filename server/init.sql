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
	is_approved BOOLEAN DEFAULT FALSE,
	quantity INTEGER DEFAULT 1,
	views_count INTEGER DEFAULT 0,
	favorites_count INTEGER DEFAULT 0,
	campus VARCHAR(50),
	contact_info VARCHAR(100),
	created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	FOREIGN KEY (category_id) REFERENCES categories(id),
	FOREIGN KEY (user_id) REFERENCES users(id)
);

-- 兵容旧数据库迁移：若 items 表已存在但缺少 quantity 列
DO $$
BEGIN
	IF NOT EXISTS (
		SELECT 1 FROM information_schema.columns
		WHERE table_schema = current_schema()
		  AND table_name = 'items'
		  AND column_name = 'quantity'
	) THEN
		EXECUTE 'ALTER TABLE items ADD COLUMN quantity INTEGER DEFAULT 1';
	END IF;

	IF NOT EXISTS (
		SELECT 1 FROM information_schema.columns
		WHERE table_schema = current_schema()
		  AND table_name = 'items'
		  AND column_name = 'is_approved'
	) THEN
		EXECUTE 'ALTER TABLE items ADD COLUMN is_approved BOOLEAN DEFAULT FALSE';
	END IF;
END $$;

-- 历史数据修正：旧数据没有审核标记时，非 pending 商品视为已审核
UPDATE items
SET is_approved = CASE WHEN status = 'pending' THEN FALSE ELSE TRUE END
WHERE is_approved IS DISTINCT FROM CASE WHEN status = 'pending' THEN FALSE ELSE TRUE END;

-- 历史数据修正：已售商品库存统一归零，避免”已售但仍有库存”导致前端展示异常
UPDATE items
SET quantity = 0,
	updated_at = CURRENT_TIMESTAMP
WHERE status = 'sold'
  AND COALESCE(quantity, 1) <> 0;

-- 兼容旧数据库迁移：若 items 表已存在但缺少评价相关列
DO $$
BEGIN
	IF NOT EXISTS (
		SELECT 1 FROM information_schema.columns
		WHERE table_schema = current_schema()
		  AND table_name = 'items'
		  AND column_name = 'avg_rating'
	) THEN
		EXECUTE 'ALTER TABLE items ADD COLUMN avg_rating DECIMAL(3,2)';
	END IF;

	IF NOT EXISTS (
		SELECT 1 FROM information_schema.columns
		WHERE table_schema = current_schema()
		  AND table_name = 'items'
		  AND column_name = 'review_count'
	) THEN
		EXECUTE 'ALTER TABLE items ADD COLUMN review_count INTEGER DEFAULT 0';
	END IF;
END $$;

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

-- 评价表
CREATE TABLE IF NOT EXISTS reviews (
	id SERIAL PRIMARY KEY,
	item_id INTEGER NOT NULL,
	order_id INTEGER NOT NULL,
	reviewer_id INTEGER NOT NULL,
	rating SMALLINT NOT NULL,
	content TEXT,
	created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	UNIQUE(order_id, reviewer_id),
	FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE,
	FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
	FOREIGN KEY (reviewer_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_reviews_item ON reviews(item_id);

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
DELETE FROM reviews;
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
ALTER SEQUENCE IF EXISTS reviews_id_seq RESTART WITH 1;

-- 测试用户
INSERT INTO users (username, password, real_name, role, campus) VALUES
('admin', '123456', '超级管理员', 'admin', NULL),
('operator', '123456', '运营人员', 'operator', NULL),
('zhangsan', '123456', '张三', 'user', '沪东校区'),
('lisi', '123456', '李四', 'user', '延长校区'),
('wangwu', '123456', '王五', 'user', '宝山校区');

-- 测试商品（user_id: 3=张三, 4=李四, 5=王五）
INSERT INTO items (title, description, price, category_id, user_id, status, is_approved, quantity) VALUES
('iPhone 13 九成新', '自用 iPhone 13，电池健康 92%，无划痕', 3800, 4, 3, 'on_sale', TRUE, 1),
('高数教材同济第七版', '几乎全新，无笔记', 25, 1, 3, 'on_sale', TRUE, 1),
('山地自行车', '骑了一年，车况良好，带坐垫', 350, 3, 4, 'on_sale', TRUE, 1),
('台灯', '宿舍用小台灯，亮度可调', 45, 2, 4, 'on_sale', TRUE, 1),
('笔记本电脑支架', '铝合金材质，折叠便携', 88, 4, 3, 'sold', TRUE, 0),
('英语四级真题合集', '2020-2024年真题，附答案解析', 30, 1, 5, 'on_sale', TRUE, 1),
('机械键盘', '87键青轴，九成新', 180, 4, 5, 'pending', FALSE, 1);

-- 测试订单
-- order_id=1: 李四购买 iPhone 13（张三卖）
-- order_id=2: 王五购买 高数教材（张三卖）
INSERT INTO orders (item_id, buyer_id, seller_id, price, status) VALUES
(1, 4, 3, 3800, 'completed'),
(2, 5, 3, 25,   'completed');

-- 测试评价（基于以上订单）
INSERT INTO reviews (item_id, order_id, reviewer_id, rating, content) VALUES
(1, 1, 4, 5, '手机非常新，和描述完全一致，卖家发货很快，强烈推荐！'),
(2, 2, 5, 4, '书的品相很好，几乎没有笔记，物超所值。');

-- 同步 items 的评分统计
UPDATE items SET avg_rating = 5.0, review_count = 1 WHERE id = 1;
UPDATE items SET avg_rating = 4.0, review_count = 1 WHERE id = 2;

-- 测试举报
INSERT INTO reports (reporter_id, target_type, target_id, reason, status)
VALUES (4, 'item', 7, '商品描述与实物不符，疑似欺诈', 'pending');

COMMIT;

-- ============================================
-- 标签系统表结构（新增）
-- ============================================

-- 标签表
CREATE TABLE IF NOT EXISTS tags (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 商品-标签关联表
CREATE TABLE IF NOT EXISTS item_tags (
    item_id INTEGER NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    tag_id INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (item_id, tag_id)
);

-- 给标签名加索引，提升模糊搜索性能
CREATE INDEX IF NOT EXISTS idx_tags_name ON tags(name);



-- ============================================
-- 标签系统表结构（新增）
-- ============================================

CREATE TABLE IF NOT EXISTS tags (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS item_tags (
    item_id INTEGER NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    tag_id INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (item_id, tag_id)
);

CREATE INDEX IF NOT EXISTS idx_tags_name ON tags(name);





-- ============================================
-- 为测试商品关联标签（兼容写法）
-- ============================================

-- 给已有测试商品打标签
INSERT INTO item_tags (item_id, tag_id)
SELECT i.id, t.id
FROM items i
CROSS JOIN tags t
WHERE 
    (i.title LIKE '%台灯%' AND t.name = '台灯')
    OR (i.title LIKE '%机械键盘%' AND t.name = '键盘')
    OR (i.title LIKE '%充电宝%' AND t.name = '充电宝')
    OR (i.title LIKE '%算法导论%' AND t.name = '学习用品')
    OR (i.title LIKE '%显示器%' AND t.name = '显示器')
    AND NOT EXISTS (
        SELECT 1 FROM item_tags 
        WHERE item_id = i.id AND tag_id = t.id
    );


-- ============================================
-- 新增测试商品（带标签）
-- ============================================

-- 商品1：机械键盘
INSERT INTO items (title, description, price, category_id, user_id, status, is_approved, campus, quantity)
VALUES ('机械键盘 87键 青轴', '手感极佳，几乎全新', 189.00, 4, 3, 'on_sale', TRUE, '徐汇校区', 1);

INSERT INTO item_tags (item_id, tag_id)
SELECT i.id, t.id FROM items i CROSS JOIN tags t 
WHERE i.title = '机械键盘 87键 青轴' 
  AND t.name IN ('键盘', '数码', '学习用品')
  AND NOT EXISTS (
      SELECT 1 FROM item_tags WHERE item_id = i.id AND tag_id = t.id
  );

-- 商品2：小米充电宝
INSERT INTO items (title, description, price, category_id, user_id, status, is_approved, campus, quantity)
VALUES ('小米充电宝 20000mAh', '支持快充，成色9成新', 89.00, 4, 4, 'on_sale', TRUE, '宝山校区', 3);

INSERT INTO item_tags (item_id, tag_id)
SELECT i.id, t.id FROM items i CROSS JOIN tags t 
WHERE i.title = '小米充电宝 20000mAh' 
  AND t.name IN ('充电宝', '数码', '生活用品')
  AND NOT EXISTS (
      SELECT 1 FROM item_tags WHERE item_id = i.id AND tag_id = t.id
  );

-- 商品3：算法导论
INSERT INTO items (title, description, price, category_id, user_id, status, is_approved, campus, quantity)
VALUES ('二手《算法导论》第四版', '经典教材，笔记清晰，适合考研', 55.00, 1, 5, 'on_sale', TRUE, '嘉定校区', 1);

INSERT INTO item_tags (item_id, tag_id)
SELECT i.id, t.id FROM items i CROSS JOIN tags t 
WHERE i.title LIKE '%算法导论%' 
  AND t.name IN ('学习用品', '二手书')
  AND NOT EXISTS (
      SELECT 1 FROM item_tags WHERE item_id = i.id AND tag_id = t.id
  );


 -- =====================================================
-- CampusTrade 自动维护 Trigger（最终修复版）
-- =====================================================

-- 1. 收藏数自动维护
DROP TRIGGER IF EXISTS trg_favorites_after_insert ON favorites;
DROP TRIGGER IF EXISTS trg_favorites_after_delete ON favorites;
DROP FUNCTION IF EXISTS update_item_favorites_count();

CREATE OR REPLACE FUNCTION update_item_favorites_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE items 
        SET favorites_count = COALESCE(favorites_count, 0) + 1,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = NEW.item_id;
        RETURN NEW;

    ELSIF TG_OP = 'DELETE' THEN
        UPDATE items 
        SET favorites_count = GREATEST(COALESCE(favorites_count, 0) - 1, 0),
            updated_at = CURRENT_TIMESTAMP
        WHERE id = OLD.item_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_favorites_after_insert
AFTER INSERT ON favorites
FOR EACH ROW EXECUTE PROCEDURE update_item_favorites_count();

CREATE TRIGGER trg_favorites_after_delete
AFTER DELETE ON favorites
FOR EACH ROW EXECUTE PROCEDURE update_item_favorites_count();


-- 2. 浏览量自动维护
DROP TRIGGER IF EXISTS trg_views_log_after_insert ON views_log;
DROP FUNCTION IF EXISTS update_item_views_count();

CREATE OR REPLACE FUNCTION update_item_views_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE items 
    SET views_count = COALESCE(views_count, 0) + 1,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = NEW.item_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_views_log_after_insert
AFTER INSERT ON views_log
FOR EACH ROW EXECUTE PROCEDURE update_item_views_count();


-- 3. 评价统计自动维护（review_count + avg_rating）【已修复】
DROP TRIGGER IF EXISTS trg_reviews_after_insert ON reviews;
DROP TRIGGER IF EXISTS trg_reviews_after_update ON reviews;
DROP TRIGGER IF EXISTS trg_reviews_after_delete ON reviews;
DROP FUNCTION IF EXISTS update_item_review_stats();

CREATE OR REPLACE FUNCTION update_item_review_stats()
RETURNS TRIGGER AS $$
DECLARE
    v_item_id INTEGER;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_item_id := OLD.item_id;
    ELSE
        v_item_id := NEW.item_id;
    END IF;

    -- 更新商品的评价统计
    UPDATE items 
    SET 
        review_count = (SELECT COUNT(*) FROM reviews WHERE item_id = v_item_id),
        avg_rating = (
            SELECT COALESCE(ROUND(AVG(rating)::numeric, 2), 0) 
            FROM reviews WHERE item_id = v_item_id
        ),
        updated_at = CURRENT_TIMESTAMP
    WHERE id = v_item_id;

    -- 必须明确返回 NEW 或 OLD
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_reviews_after_insert
AFTER INSERT ON reviews
FOR EACH ROW EXECUTE PROCEDURE update_item_review_stats();

CREATE TRIGGER trg_reviews_after_update
AFTER UPDATE OF rating ON reviews
FOR EACH ROW EXECUTE PROCEDURE update_item_review_stats();

CREATE TRIGGER trg_reviews_after_delete
AFTER DELETE ON reviews
FOR EACH ROW EXECUTE PROCEDURE update_item_review_stats();