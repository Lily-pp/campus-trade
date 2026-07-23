-- ============================================
-- V008: 校园生活服务订单系统 + 审核机制 + 需求接单
-- 1. storage_services/requests/rental_items 增加审核字段
-- 2. storage_orders 表：寄存服务预约订单
-- 3. 测试数据：寄存预约 + 租赁订单
-- 4. 所有操作保证幂等
-- ============================================

BEGIN;

-- ============================================
-- 1. 校园服务审核机制
--    新增发布默认 status='pending' + is_approved=FALSE
--    管理员审核通过后 status='available'/'searching' + is_approved=TRUE
-- ============================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=current_schema() AND table_name='storage_services' AND column_name='is_approved') THEN
        ALTER TABLE storage_services ADD COLUMN is_approved BOOLEAN DEFAULT FALSE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=current_schema() AND table_name='storage_requests' AND column_name='is_approved') THEN
        ALTER TABLE storage_requests ADD COLUMN is_approved BOOLEAN DEFAULT FALSE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=current_schema() AND table_name='rental_items' AND column_name='is_approved') THEN
        ALTER TABLE rental_items ADD COLUMN is_approved BOOLEAN DEFAULT FALSE;
    END IF;
END $$;

-- 已有数据全部标记为已审核
UPDATE storage_services SET is_approved = TRUE WHERE is_approved IS NOT TRUE;
UPDATE storage_requests SET is_approved = TRUE WHERE is_approved IS NOT TRUE;
UPDATE rental_items SET is_approved = TRUE WHERE is_approved IS NOT TRUE;

-- ============================================
-- 2. 寄存服务订单表
-- ============================================
CREATE TABLE IF NOT EXISTS storage_orders (
    id                  SERIAL PRIMARY KEY,
    storage_service_id  INTEGER         NOT NULL REFERENCES storage_services(id) ON DELETE CASCADE,
    user_id             INTEGER         NOT NULL REFERENCES users(id),
    provider_id         INTEGER         NOT NULL REFERENCES users(id),
    item_desc           VARCHAR(200),
    start_date          DATE            NOT NULL,
    end_date            DATE            NOT NULL,
    total_price         DECIMAL(10,2),
    status              VARCHAR(20)     DEFAULT 'pending' CHECK(status IN ('pending','confirmed','active','completed','cancelled')),
    created_at          TIMESTAMP       DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_storage_orders_user ON storage_orders(user_id);
CREATE INDEX IF NOT EXISTS idx_storage_orders_provider ON storage_orders(provider_id);

-- ============================================
-- 2. 寄存服务预约 测试数据
-- ============================================

-- zhangsan 预约了 lisi 的行李寄存服务
INSERT INTO storage_orders (storage_service_id, user_id, provider_id, item_desc, start_date, end_date, total_price, status)
SELECT
    ss.id,
    (SELECT id FROM users WHERE username='zhangsan' LIMIT 1),
    ss.user_id,
    '28寸行李箱+一床被子',
    '2026-07-05', '2026-09-01',
    50.00, 'confirmed'
FROM storage_services ss
WHERE ss.title = '寒假行李寄存 宿舍储物间'
AND NOT EXISTS (SELECT 1 FROM storage_orders WHERE storage_service_id = ss.id AND user_id = (SELECT id FROM users WHERE username='zhangsan' LIMIT 1));

-- wangwu 预约了 zhangsan 的电动车寄存
INSERT INTO storage_orders (storage_service_id, user_id, provider_id, item_desc, start_date, end_date, total_price, status)
SELECT
    ss.id,
    (SELECT id FROM users WHERE username='wangwu' LIMIT 1),
    ss.user_id,
    '九号N70C电动车',
    '2026-07-01', '2026-08-31',
    60.00, 'active'
FROM storage_services ss
WHERE ss.title = '宿舍楼下电动车寄存位'
AND NOT EXISTS (SELECT 1 FROM storage_orders WHERE storage_service_id = ss.id AND user_id = (SELECT id FROM users WHERE username='wangwu' LIMIT 1));

-- lisi 预约了 wangwu 的冰箱寄存
INSERT INTO storage_orders (storage_service_id, user_id, provider_id, item_desc, start_date, end_date, total_price, status)
SELECT
    ss.id,
    (SELECT id FROM users WHERE username='lisi' LIMIT 1),
    ss.user_id,
    '50L小冰箱',
    '2026-07-01', '2026-09-01',
    40.00, 'pending'
FROM storage_services ss
WHERE ss.title = '小冰箱暑假寄存'
AND NOT EXISTS (SELECT 1 FROM storage_orders WHERE storage_service_id = ss.id AND user_id = (SELECT id FROM users WHERE username='lisi' LIMIT 1));

-- ============================================
-- 3. 租赁订单 测试数据（校园转租）
-- ============================================

-- zhangsan 租了 lisi 的无人机 3天
INSERT INTO rental_orders (rental_item_id, renter_id, owner_id, start_date, end_date, total_price, deposit, status)
SELECT
    ri.id,
    (SELECT id FROM users WHERE username='zhangsan' LIMIT 1),
    ri.user_id,
    '2026-07-10', '2026-07-13',
    150.00, 2000.00, 'completed'
FROM rental_items ri
WHERE ri.title = '大疆Mini 4 Pro无人机出租'
AND NOT EXISTS (SELECT 1 FROM rental_orders WHERE rental_item_id = ri.id AND renter_id = (SELECT id FROM users WHERE username='zhangsan' LIMIT 1));

-- wangwu 租了 zhangsan 的 Switch 7天
INSERT INTO rental_orders (rental_item_id, renter_id, owner_id, start_date, end_date, total_price, deposit, status)
SELECT
    ri.id,
    (SELECT id FROM users WHERE username='wangwu' LIMIT 1),
    ri.user_id,
    '2026-07-15', '2026-07-22',
    105.00, 1000.00, 'active'
FROM rental_items ri
WHERE ri.title = 'Nintendo Switch OLED 游戏机出租'
AND NOT EXISTS (SELECT 1 FROM rental_orders WHERE rental_item_id = ri.id AND renter_id = (SELECT id FROM users WHERE username='wangwu' LIMIT 1));

-- lisi 租了 wangwu 的投影仪 1天
INSERT INTO rental_orders (rental_item_id, renter_id, owner_id, start_date, end_date, total_price, deposit, status)
SELECT
    ri.id,
    (SELECT id FROM users WHERE username='lisi' LIMIT 1),
    ri.user_id,
    '2026-07-18', '2026-07-19',
    25.00, 1500.00, 'pending'
FROM rental_items ri
WHERE ri.title = '极米投影仪 Z6X 出租'
AND NOT EXISTS (SELECT 1 FROM rental_orders WHERE rental_item_id = ri.id AND renter_id = (SELECT id FROM users WHERE username='lisi' LIMIT 1));

COMMIT;
