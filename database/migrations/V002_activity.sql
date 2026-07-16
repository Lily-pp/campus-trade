-- ============================================
-- V002: 校园活动运营系统（Activity Module）
-- 说明：
-- 1. 新增 activities 表，支持时间驱动的活动管理
-- 2. items 表增加 activity_id 外键
-- 3. 插入第一阶段初始活动数据
-- 4. 所有操作保证幂等性，可重复执行
-- ============================================

BEGIN;

-- ============================================
-- 1. 创建活动表
-- ============================================
CREATE TABLE IF NOT EXISTS activities (
    id              SERIAL PRIMARY KEY,
    name            VARCHAR(100)    NOT NULL,
    type            VARCHAR(50)     NOT NULL,
    description     TEXT,
    banner_url      VARCHAR(500),
    start_time      TIMESTAMP       NOT NULL,
    end_time        TIMESTAMP       NOT NULL,
    is_enabled      BOOLEAN         DEFAULT TRUE,
    sort_order      INTEGER         DEFAULT 0,
    created_by      INTEGER         REFERENCES users(id) ON DELETE SET NULL,
    created_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_activities_time CHECK (end_time > start_time)
);

-- 索引：加速首页按时间和启用状态查询有效活动
CREATE INDEX IF NOT EXISTS idx_activities_enabled_time
    ON activities(is_enabled, start_time, end_time);

-- ============================================
-- 2. items 表增加 activity_id 字段
-- ============================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = 'items'
          AND column_name = 'activity_id'
    ) THEN
        ALTER TABLE items
            ADD COLUMN activity_id INTEGER REFERENCES activities(id) ON DELETE SET NULL;
    END IF;
END $$;

-- 索引：加速按活动查询商品
CREATE INDEX IF NOT EXISTS idx_items_activity ON items(activity_id);

-- ============================================
-- 3. 插入初始活动数据（幂等：已存在则跳过）
-- ============================================
INSERT INTO activities (name, type, description, start_time, end_time, is_enabled, sort_order, created_by)
SELECT
    '毕业甩卖专场', 'graduation_sale',
    '毕业季大甩卖！书籍、电子产品、生活用品低价转让，助力学弟学妹轻松入学',
    '2026-05-01 00:00:00', '2026-07-31 23:59:59', TRUE, 1,
    (SELECT id FROM users WHERE username = 'admin' LIMIT 1)
WHERE NOT EXISTS (
    SELECT 1 FROM activities WHERE type = 'graduation_sale'
);

INSERT INTO activities (name, type, description, start_time, end_time, is_enabled, sort_order, created_by)
SELECT
    '新生淘货专区', 'freshman_market',
    '新生专属福利！学长学姐精选好物，教科书、宿舍用品一站购齐',
    '2026-08-01 00:00:00', '2026-10-31 23:59:59', TRUE, 2,
    (SELECT id FROM users WHERE username = 'admin' LIMIT 1)
WHERE NOT EXISTS (
    SELECT 1 FROM activities WHERE type = 'freshman_market'
);

INSERT INTO activities (name, type, description, start_time, end_time, is_enabled, sort_order, created_by)
SELECT
    '考研资料专区', 'exam_materials',
    '考研路上不孤单！历年真题、复习笔记、参考教材，助你一战成硕',
    '2026-03-01 00:00:00', '2026-05-31 23:59:59', TRUE, 3,
    (SELECT id FROM users WHERE username = 'admin' LIMIT 1)
WHERE NOT EXISTS (
    SELECT 1 FROM activities WHERE type = 'exam_materials'
);

INSERT INTO activities (name, type, description, start_time, end_time, is_enabled, sort_order, created_by)
SELECT
    '寒暑假闲置寄存', 'holiday_storage',
    '假期离校不用愁！闲置物品短期寄存/转租，省心又省钱',
    '2026-07-01 00:00:00', '2026-08-31 23:59:59', TRUE, 4,
    (SELECT id FROM users WHERE username = 'admin' LIMIT 1)
WHERE NOT EXISTS (
    SELECT 1 FROM activities WHERE type = 'holiday_storage'
);

COMMIT;
