-- ============================================
-- V003: 官方补贴活动系统 + 代金券 + 考研资料字段
-- 说明：
-- 1. activities 表扩展：补贴配置字段
-- 2. 新增 vouchers 表：校园代金券
-- 3. items 表扩展：考研资料专区字段
-- 4. 更新现有活动为补贴模式
-- 5. 所有操作保证幂等性
-- ============================================

BEGIN;

-- ============================================
-- 1. activities 表扩展：补贴配置
-- ============================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = 'activities'
          AND column_name = 'subsidy_enabled'
    ) THEN
        ALTER TABLE activities ADD COLUMN subsidy_enabled BOOLEAN DEFAULT FALSE;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = 'activities'
          AND column_name = 'subsidy_discount_rate'
    ) THEN
        ALTER TABLE activities ADD COLUMN subsidy_discount_rate DECIMAL(3,2) DEFAULT 0.10;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = 'activities'
          AND column_name = 'voucher_min_rate'
    ) THEN
        ALTER TABLE activities ADD COLUMN voucher_min_rate DECIMAL(3,2) DEFAULT 0.05;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = 'activities'
          AND column_name = 'voucher_max_rate'
    ) THEN
        ALTER TABLE activities ADD COLUMN voucher_max_rate DECIMAL(3,2) DEFAULT 0.10;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = 'activities'
          AND column_name = 'tagline'
    ) THEN
        ALTER TABLE activities ADD COLUMN tagline VARCHAR(200);
    END IF;
END $$;

-- ============================================
-- 2. 更新前三项活动为官方补贴模式
-- ============================================
UPDATE activities
SET subsidy_enabled = TRUE,
    subsidy_discount_rate = 0.10,
    voucher_min_rate = 0.05,
    voucher_max_rate = 0.10,
    tagline = '官方补贴10%，助你快速成交！成交即可抽5%~10%校园券'
WHERE type IN ('graduation_sale', 'freshman_market', 'exam_materials')
  AND subsidy_enabled IS NOT TRUE;

-- 寒暑假闲置寄存：非补贴活动，设置不同文案
UPDATE activities
SET tagline = '假期离校闲置物品寄存/转租，省心又省钱'
WHERE type = 'holiday_storage' AND tagline IS NULL;

-- ============================================
-- 3. 代金券表
-- ============================================
CREATE TABLE IF NOT EXISTS vouchers (
    id              SERIAL PRIMARY KEY,
    user_id         INTEGER         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    activity_id     INTEGER         REFERENCES activities(id) ON DELETE SET NULL,
    order_id        INTEGER         REFERENCES orders(id) ON DELETE SET NULL,
    amount          DECIMAL(10,2)   NOT NULL,
    status          VARCHAR(20)     DEFAULT 'unused' CHECK(status IN ('unused','used','expired')),
    obtained_at     TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    expires_at      TIMESTAMP       NOT NULL,
    used_at         TIMESTAMP,
    used_order_id   INTEGER         REFERENCES orders(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_vouchers_user ON vouchers(user_id);
CREATE INDEX IF NOT EXISTS idx_vouchers_status ON vouchers(user_id, status);

-- ============================================
-- 4. items 表扩展：考研资料专区字段
-- ============================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = 'items'
          AND column_name = 'school'
    ) THEN
        ALTER TABLE items ADD COLUMN school VARCHAR(100);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = 'items'
          AND column_name = 'major'
    ) THEN
        ALTER TABLE items ADD COLUMN major VARCHAR(100);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = 'items'
          AND column_name = 'exam_year'
    ) THEN
        ALTER TABLE items ADD COLUMN exam_year INTEGER;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = 'items'
          AND column_name = 'is_landed'
    ) THEN
        ALTER TABLE items ADD COLUMN is_landed BOOLEAN;
    END IF;
END $$;

COMMIT;
