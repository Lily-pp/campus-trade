-- ============================================
-- V009: 毕业季公益循环计划
-- 1. items 增加 item_type / free_deadline
-- 2. free_apply 免费领取申请表
-- 3. donation_record 公益捐赠记录表
-- 4. users 增加 charity_points
-- 5. 测试数据：公益商品 + 领取申请
-- 6. 所有操作保证幂等
-- ============================================

BEGIN;

-- ============================================
-- 1. items 扩展：商品类型 + 领取截止时间
-- ============================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=current_schema() AND table_name='items' AND column_name='item_type') THEN
        ALTER TABLE items ADD COLUMN item_type VARCHAR(20) DEFAULT 'sale';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=current_schema() AND table_name='items' AND column_name='free_deadline') THEN
        ALTER TABLE items ADD COLUMN free_deadline TIMESTAMP;
    END IF;
END $$;

-- ============================================
-- 2. 免费领取申请表
-- ============================================
CREATE TABLE IF NOT EXISTS free_apply (
    id              SERIAL PRIMARY KEY,
    item_id         INTEGER         NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    applicant_id    INTEGER         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    owner_id        INTEGER         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status          VARCHAR(20)     DEFAULT 'pending' CHECK(status IN ('pending','accepted','completed','cancelled')),
    apply_message   TEXT,
    created_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_free_apply_item ON free_apply(item_id);
CREATE INDEX IF NOT EXISTS idx_free_apply_applicant ON free_apply(applicant_id);

-- ============================================
-- 3. 公益捐赠记录表
-- ============================================
CREATE TABLE IF NOT EXISTS donation_record (
    id              SERIAL PRIMARY KEY,
    item_id         INTEGER         REFERENCES items(id) ON DELETE SET NULL,
    batch_id        VARCHAR(50),
    donation_time   TIMESTAMP,
    organization    VARCHAR(200),
    description     TEXT,
    proof_image     VARCHAR(500),
    created_by      INTEGER         REFERENCES users(id),
    created_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 4. users 增加公益积分
-- ============================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=current_schema() AND table_name='users' AND column_name='charity_points') THEN
        ALTER TABLE users ADD COLUMN charity_points INTEGER DEFAULT 0;
    END IF;
END $$;

-- ============================================
-- 5. 修复价格 CHECK 约束：公益商品价格为 0
-- ============================================
ALTER TABLE items DROP CONSTRAINT IF EXISTS chk_items_price_positive;
ALTER TABLE items ADD CONSTRAINT chk_items_price_non_negative CHECK (price >= 0);

-- ============================================
-- 6. 测试数据：毕业公益赠送商品
-- ============================================

-- zhangsan 赠送旧教材
INSERT INTO items (title, description, price, category_id, user_id, status, is_approved, campus, quantity, item_type, activity_id)
SELECT '大学英语四级全套教材免费送', '四级备考全套资料，包括真题、词汇书、听力训练，虽然有点旧但内容完整可用',
    0, 1, u.id, 'on_sale', TRUE, '宝山校区', 1, 'charity',
    (SELECT id FROM activities WHERE type = 'graduation_sale' LIMIT 1)
FROM users u WHERE u.username = 'zhangsan'
AND NOT EXISTS (SELECT 1 FROM items WHERE title = '大学英语四级全套教材免费送');

-- lisi 赠送台灯
INSERT INTO items (title, description, price, category_id, user_id, status, is_approved, campus, quantity, item_type, activity_id)
SELECT '宿舍台灯免费送', '用了两年的台灯，亮度可调，功能正常，毕业带不走了，免费送给学弟学妹',
    0, 2, u.id, 'on_sale', TRUE, '延长校区', 1, 'charity',
    (SELECT id FROM activities WHERE type = 'graduation_sale' LIMIT 1)
FROM users u WHERE u.username = 'lisi'
AND NOT EXISTS (SELECT 1 FROM items WHERE title = '宿舍台灯免费送');

-- wangwu 赠送晾衣架
INSERT INTO items (title, description, price, category_id, user_id, status, is_approved, campus, quantity, item_type, activity_id)
SELECT '折叠晾衣架免费送', '不锈钢折叠晾衣架，展开可以晾很多衣服，宿舍必备，就是有点褪色不影响使用',
    0, 2, u.id, 'on_sale', TRUE, '沪东校区', 1, 'charity',
    (SELECT id FROM activities WHERE type = 'graduation_sale' LIMIT 1)
FROM users u WHERE u.username = 'wangwu'
AND NOT EXISTS (SELECT 1 FROM items WHERE title = '折叠晾衣架免费送');

-- zhangsan 赠送旧风扇
INSERT INTO items (title, description, price, category_id, user_id, status, is_approved, campus, quantity, item_type, activity_id)
SELECT '落地风扇免费送', '用了三年的落地扇，风力还行，有点噪音但夏天吹风够用，免费自提',
    0, 2, u.id, 'on_sale', TRUE, '宝山校区', 1, 'charity',
    (SELECT id FROM activities WHERE type = 'graduation_sale' LIMIT 1)
FROM users u WHERE u.username = 'zhangsan'
AND NOT EXISTS (SELECT 1 FROM items WHERE title = '落地风扇免费送');

-- lisi 赠送篮球
INSERT INTO items (title, description, price, category_id, user_id, status, is_approved, campus, quantity, item_type, activity_id)
SELECT '斯伯丁篮球免费送', '正品斯伯丁篮球，表皮有点磨损但弹性没问题，适合平时打球练习',
    0, 2, u.id, 'on_sale', TRUE, '延长校区', 1, 'charity',
    (SELECT id FROM activities WHERE type = 'graduation_sale' LIMIT 1)
FROM users u WHERE u.username = 'lisi'
AND NOT EXISTS (SELECT 1 FROM items WHERE title = '斯伯丁篮球免费送');

-- ============================================
-- 7. 测试数据：领取申请
-- ============================================

-- wangwu 申请 lisi 的台灯
INSERT INTO free_apply (item_id, applicant_id, owner_id, status, apply_message)
SELECT
    (SELECT id FROM items WHERE title = '宿舍台灯免费送' LIMIT 1),
    (SELECT id FROM users WHERE username = 'wangwu' LIMIT 1),
    (SELECT id FROM users WHERE username = 'lisi' LIMIT 1),
    'accepted', '学长你好，我宿舍正好缺个台灯，可以送我吗？'
WHERE EXISTS (SELECT 1 FROM items WHERE title = '宿舍台灯免费送')
AND NOT EXISTS (SELECT 1 FROM free_apply WHERE item_id = (SELECT id FROM items WHERE title = '宿舍台灯免费送' LIMIT 1) AND applicant_id = (SELECT id FROM users WHERE username = 'wangwu' LIMIT 1));

-- zhangsan 申请 wangwu 的晾衣架
INSERT INTO free_apply (item_id, applicant_id, owner_id, status, apply_message)
SELECT
    (SELECT id FROM items WHERE title = '折叠晾衣架免费送' LIMIT 1),
    (SELECT id FROM users WHERE username = 'zhangsan' LIMIT 1),
    (SELECT id FROM users WHERE username = 'wangwu' LIMIT 1),
    'pending', '晾衣架还在吗？我想申请领取！'
WHERE EXISTS (SELECT 1 FROM items WHERE title = '折叠晾衣架免费送')
AND NOT EXISTS (SELECT 1 FROM free_apply WHERE item_id = (SELECT id FROM items WHERE title = '折叠晾衣架免费送' LIMIT 1) AND applicant_id = (SELECT id FROM users WHERE username = 'zhangsan' LIMIT 1));

-- ============================================
-- 8. 测试数据：给已有用户增加公益积分
-- ============================================
UPDATE users SET charity_points = 15 WHERE username = 'zhangsan' AND charity_points = 0;
UPDATE users SET charity_points = 15 WHERE username = 'lisi' AND charity_points = 0;
UPDATE users SET charity_points = 10 WHERE username = 'wangwu' AND charity_points = 0;

COMMIT;
