-- ============================================
-- V002_PLUS: 节点化运营完整迁移（合并 V003~V009）
-- 包含以下模块：
--   校园活动运营系统（activities扩展 + 补贴 + 种子数据）
--   校园生活服务（寄存 + 转租 + 订单）
--   官方补贴 + 代金券系统
--   毕业季公益循环计划
--   审核机制 + 管理员权限 + 数据清理
-- 注意：此文件基于 V001+init.sql 已执行的前提
-- 所有 DDL 使用 IF NOT EXISTS，所有 DML 使用幂等写法
-- ============================================

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

-- ============================================
-- V004: 校园生活服务系统
-- 包含：寒暑假闲置寄存 + 校园转租服务
-- 说明：
-- 1. storage_services：寄存服务发布表
-- 2. storage_requests：寄存需求发布表
-- 3. rental_items：校园转租物品表
-- 4. rental_orders：租赁订单表
-- 5. 所有操作保证幂等性
-- ============================================


-- ============================================
-- 1. 寄存服务表（供方发布）
-- ============================================
CREATE TABLE IF NOT EXISTS storage_services (
    id              SERIAL PRIMARY KEY,
    user_id         INTEGER         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title           VARCHAR(200)    NOT NULL,
    description     TEXT,
    storage_type    VARCHAR(50)     NOT NULL,   -- bike/suitcase/fridge/other
    location        VARCHAR(200),
    campus          VARCHAR(50),
    price_per_month DECIMAL(10,2),
    capacity        INTEGER         DEFAULT 1,
    status          VARCHAR(20)     DEFAULT 'available',
    created_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_storage_services_type ON storage_services(storage_type);
CREATE INDEX IF NOT EXISTS idx_storage_services_user ON storage_services(user_id);

-- ============================================
-- 2. 寄存需求表（需方发布）
-- ============================================
CREATE TABLE IF NOT EXISTS storage_requests (
    id              SERIAL PRIMARY KEY,
    user_id         INTEGER         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title           VARCHAR(200)    NOT NULL,
    description     TEXT,
    item_type       VARCHAR(50)     NOT NULL,   -- bike/suitcase/fridge/other
    location        VARCHAR(200),
    campus          VARCHAR(50),
    budget          DECIMAL(10,2),
    start_date      DATE,
    end_date        DATE,
    status          VARCHAR(20)     DEFAULT 'open',  -- open/matched/closed
    created_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_storage_requests_type ON storage_requests(item_type);
CREATE INDEX IF NOT EXISTS idx_storage_requests_user ON storage_requests(user_id);

-- ============================================
-- 3. 校园转租物品表
-- ============================================
CREATE TABLE IF NOT EXISTS rental_items (
    id              SERIAL PRIMARY KEY,
    user_id         INTEGER         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title           VARCHAR(200)    NOT NULL,
    description     TEXT,
    category        VARCHAR(50)     NOT NULL,   -- bike/camera/drone/projector/racket/console/other
    rental_price    DECIMAL(10,2)   NOT NULL,   -- 日租价格
    deposit         DECIMAL(10,2),              -- 押金
    min_days        INTEGER         DEFAULT 1,
    max_days        INTEGER,
    location        VARCHAR(200),
    campus          VARCHAR(50),
    images          TEXT,                        -- JSON array of image URLs
    status          VARCHAR(20)     DEFAULT 'available',
    created_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_rental_items_category ON rental_items(category);
CREATE INDEX IF NOT EXISTS idx_rental_items_user ON rental_items(user_id);

-- ============================================
-- 4. 租赁订单表
-- ============================================
CREATE TABLE IF NOT EXISTS rental_orders (
    id              SERIAL PRIMARY KEY,
    rental_item_id  INTEGER         NOT NULL REFERENCES rental_items(id) ON DELETE CASCADE,
    renter_id       INTEGER         NOT NULL REFERENCES users(id),
    owner_id        INTEGER         NOT NULL REFERENCES users(id),
    start_date      DATE            NOT NULL,
    end_date        DATE            NOT NULL,
    total_price     DECIMAL(10,2)   NOT NULL,
    deposit         DECIMAL(10,2),
    status          VARCHAR(20)     DEFAULT 'pending',  -- pending/confirmed/active/completed/cancelled
    created_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_rental_orders_renter ON rental_orders(renter_id);
CREATE INDEX IF NOT EXISTS idx_rental_orders_owner ON rental_orders(owner_id);

-- ============================================
-- V005: 清理 + 校园节点化运营种子数据
-- 说明：
-- 1. 移除 activities 中的「寒暑假闲置寄存」（改由校园生活服务承载）
-- 2. 为三个官方补贴活动插入校园商品测试数据
-- 3. 插入寄存服务和转租物品测试数据
-- 4. 所有 INSERT 使用 WHERE NOT EXISTS 保证幂等
-- ============================================


-- ============================================
-- 1. 清理：删除 holiday_storage 活动
--    寒暑假闲置寄存不再作为活动，改为校园生活服务子模块
-- ============================================
DELETE FROM activities WHERE type = 'holiday_storage';

-- 调整三个活动时间覆盖全年，方便测试时都能展示
UPDATE activities SET start_time = '2026-01-01 00:00:00', end_time = '2026-12-31 23:59:59'
WHERE type IN ('graduation_sale', 'freshman_market', 'exam_materials');

-- ============================================
-- 2. 校园活动运营 — 商品测试数据
--    三个官方补贴活动：毕业甩卖、新生淘货、考研资料
-- ============================================

-- ---------- 毕业甩卖专场 (activity_id: 1) ----------
-- 获取活动ID
DO $$
DECLARE
    v_graduation_id INTEGER;
    v_freshman_id INTEGER;
    v_exam_id INTEGER;
BEGIN
    SELECT id INTO v_graduation_id FROM activities WHERE type = 'graduation_sale' LIMIT 1;
    SELECT id INTO v_freshman_id FROM activities WHERE type = 'freshman_market' LIMIT 1;
    SELECT id INTO v_exam_id FROM activities WHERE type = 'exam_materials' LIMIT 1;

    -- 毕业甩卖：书籍、电子产品、生活用品
    INSERT INTO items (title, description, price, category_id, user_id, status, is_approved, campus, quantity, activity_id)
    SELECT '机械键盘 Cherry MX 红轴', '毕业出，用了两年，手感依然很好，送拔键器', 150, 4, 3, 'on_sale', TRUE, '宝山校区', 1, v_graduation_id
    WHERE NOT EXISTS (SELECT 1 FROM items WHERE title = '机械键盘 Cherry MX 红轴' AND activity_id = v_graduation_id);

    INSERT INTO items (title, description, price, category_id, user_id, status, is_approved, campus, quantity, activity_id)
    SELECT '宿舍用小冰箱 50L', '毕业离校急出，冷藏冷冻两用，九成新自提', 280, 2, 4, 'on_sale', TRUE, '沪东校区', 1, v_graduation_id
    WHERE NOT EXISTS (SELECT 1 FROM items WHERE title = '宿舍用小冰箱 50L' AND activity_id = v_graduation_id);

    INSERT INTO items (title, description, price, category_id, user_id, status, is_approved, campus, quantity, activity_id)
    SELECT 'iPad Pro 2022 11寸 256G', '毕业换新出，屏幕完好，带原装笔和壳', 4200, 4, 5, 'on_sale', TRUE, '延长校区', 1, v_graduation_id
    WHERE NOT EXISTS (SELECT 1 FROM items WHERE title = 'iPad Pro 2022 11寸 256G' AND activity_id = v_graduation_id);

    INSERT INTO items (title, description, price, category_id, user_id, status, is_approved, campus, quantity, activity_id)
    SELECT '人体工学椅 网易严选', '坐了不到一年，腰部支撑很舒服，毕业带不走', 350, 2, 3, 'on_sale', TRUE, '宝山校区', 1, v_graduation_id
    WHERE NOT EXISTS (SELECT 1 FROM items WHERE title = '人体工学椅 网易严选' AND activity_id = v_graduation_id);

    -- ---------- 新生淘货专区 (activity_id: 2) ----------
    INSERT INTO items (title, description, price, category_id, user_id, status, is_approved, campus, quantity, activity_id)
    SELECT '高等数学（同济第七版）全新', '买错了版本，全新未拆封，新生必备', 28, 1, 3, 'on_sale', TRUE, '沪东校区', 3, v_freshman_id
    WHERE NOT EXISTS (SELECT 1 FROM items WHERE title = '高等数学（同济第七版）全新' AND activity_id = v_freshman_id);

    INSERT INTO items (title, description, price, category_id, user_id, status, is_approved, campus, quantity, activity_id)
    SELECT '宿舍床上三件套 纯棉', '全新未使用，花色清新，适合新生宿舍', 65, 2, 4, 'on_sale', TRUE, '宝山校区', 2, v_freshman_id
    WHERE NOT EXISTS (SELECT 1 FROM items WHERE title = '宿舍床上三件套 纯棉' AND activity_id = v_freshman_id);

    INSERT INTO items (title, description, price, category_id, user_id, status, is_approved, campus, quantity, activity_id)
    SELECT '凤凰山地自行车 26寸 24速', '骑了一年多，车况不错，送锁和水壶架', 280, 3, 5, 'on_sale', TRUE, '延长校区', 1, v_freshman_id
    WHERE NOT EXISTS (SELECT 1 FROM items WHERE title = '凤凰山地自行车 26寸 24速' AND activity_id = v_freshman_id);

    INSERT INTO items (title, description, price, category_id, user_id, status, is_approved, campus, quantity, activity_id)
    SELECT '小米显示器 23.8寸 1080P', '宿舍外接屏幕，显示清晰，HDMI接口', 350, 4, 3, 'on_sale', TRUE, '沪东校区', 1, v_freshman_id
    WHERE NOT EXISTS (SELECT 1 FROM items WHERE title = '小米显示器 23.8寸 1080P' AND activity_id = v_freshman_id);

    INSERT INTO items (title, description, price, category_id, user_id, status, is_approved, campus, quantity, activity_id)
    SELECT 'USB小台扇 静音桌面风扇', '宿舍床上用小风扇，静音可调三档，新生必备', 25, 2, 4, 'on_sale', TRUE, '宝山校区', 5, v_freshman_id
    WHERE NOT EXISTS (SELECT 1 FROM items WHERE title = 'USB小台扇 静音桌面风扇' AND activity_id = v_freshman_id);

    -- ---------- 考研资料专区 (activity_id: 3) ----------
    INSERT INTO items (title, description, price, category_id, user_id, status, is_approved, campus, quantity, activity_id, school, major, exam_year, is_landed)
    SELECT '408计算机考研全套资料', '王道四本+历年真题+笔记，已上岸学长整理，非常详细', 80, 1, 3, 'on_sale', TRUE, '宝山校区', 1, v_exam_id, '清华大学', '计算机科学与技术', 2025, TRUE
    WHERE NOT EXISTS (SELECT 1 FROM items WHERE title = '408计算机考研全套资料' AND activity_id = v_exam_id);

    INSERT INTO items (title, description, price, category_id, user_id, status, is_approved, campus, quantity, activity_id, school, major, exam_year, is_landed)
    SELECT '考研英语一历年真题 2000-2025', '张剑黄皮书全套，答案详解完整，已成功上岸', 45, 1, 5, 'on_sale', TRUE, '延长校区', 1, v_exam_id, '复旦大学', '金融学', 2025, TRUE
    WHERE NOT EXISTS (SELECT 1 FROM items WHERE title = '考研英语一历年真题 2000-2025' AND activity_id = v_exam_id);

    INSERT INTO items (title, description, price, category_id, user_id, status, is_approved, campus, quantity, activity_id, school, major, exam_year, is_landed)
    SELECT '考研数学一复习全书 李永乐', '李永乐复习全书+660题+330题，笔记整齐有重点标注', 55, 1, 4, 'on_sale', TRUE, '沪东校区', 1, v_exam_id, '上海交通大学', '电子信息', 2025, TRUE
    WHERE NOT EXISTS (SELECT 1 FROM items WHERE title = '考研数学一复习全书 李永乐' AND activity_id = v_exam_id);

    INSERT INTO items (title, description, price, category_id, user_id, status, is_approved, campus, quantity, activity_id, school, major, exam_year, is_landed)
    SELECT '考研政治肖秀荣全套', '精讲精练+1000题+肖四肖八，几乎全新，笔记很少', 35, 1, 3, 'on_sale', TRUE, '宝山校区', 2, v_exam_id, '浙江大学', '控制工程', 2025, TRUE
    WHERE NOT EXISTS (SELECT 1 FROM items WHERE title = '考研政治肖秀荣全套' AND activity_id = v_exam_id);

    INSERT INTO items (title, description, price, category_id, user_id, status, is_approved, campus, quantity, activity_id, school, major, exam_year, is_landed)
    SELECT '考研电子笔记合集（iPad GoodNotes）', '自用GoodNotes电子笔记，包含数学英语政治总结，可以直接导入', 20, 1, 5, 'on_sale', TRUE, '沪东校区', 10, v_exam_id, '北京大学', '软件工程', 2025, TRUE
    WHERE NOT EXISTS (SELECT 1 FROM items WHERE title = '考研电子笔记合集（iPad GoodNotes）' AND activity_id = v_exam_id);

END $$;

-- ============================================
-- 3. 校园生活服务 — 寒暑假闲置寄存 测试数据
-- ============================================

-- 寄存服务
INSERT INTO storage_services (user_id, title, description, storage_type, location, campus, price_per_month, capacity)
SELECT u.id, '宿舍楼下电动车寄存位', '假期宿舍楼下车棚，有遮雨棚，监控覆盖，安全可靠', 'bike', '3号宿舍楼下', '宝山校区', 30, 3
FROM users u WHERE u.username = 'zhangsan' AND NOT EXISTS (SELECT 1 FROM storage_services WHERE title = '宿舍楼下电动车寄存位');

INSERT INTO storage_services (user_id, title, description, storage_type, location, campus, price_per_month, capacity)
SELECT u.id, '寒假行李寄存 宿舍储物间', '宿舍自带储物小间，可存放行李箱、被子等，干燥通风', 'suitcase', '7号宿舍楼 502室', '沪东校区', 25, 2
FROM users u WHERE u.username = 'lisi' AND NOT EXISTS (SELECT 1 FROM storage_services WHERE title = '寒假行李寄存 宿舍储物间');

INSERT INTO storage_services (user_id, title, description, storage_type, location, campus, price_per_month, capacity)
SELECT u.id, '小冰箱暑假寄存', '暑假留校提供冰箱寄存服务，24小时不断电，有专人看管', 'fridge', '学校创业园 B区', '延长校区', 20, 1
FROM users u WHERE u.username = 'wangwu' AND NOT EXISTS (SELECT 1 FROM storage_services WHERE title = '小冰箱暑假寄存');

-- 寄存需求
INSERT INTO storage_requests (user_id, title, description, item_type, location, campus, budget, start_date, end_date)
SELECT u.id, '求寄存电动车 暑假两个月', '暑假回家，电动车需要寄存7-8月，要求有遮雨和充电', 'bike', '', '沪东校区', 40, '2026-07-01', '2026-08-31'
FROM users u WHERE u.username = 'zhangsan' AND NOT EXISTS (SELECT 1 FROM storage_requests WHERE title = '求寄存电动车 暑假两个月');

INSERT INTO storage_requests (user_id, title, description, item_type, location, campus, budget, start_date, end_date)
SELECT u.id, '寒假行李寄存一个月', '寒假回家过春节，一个28寸行李箱需要寄存1个月', 'suitcase', '', '宝山校区', 30, '2027-01-15', '2027-02-15'
FROM users u WHERE u.username = 'lisi' AND NOT EXISTS (SELECT 1 FROM storage_requests WHERE title = '寒假行李寄存一个月');

-- ============================================
-- 4. 校园生活服务 — 校园转租服务 测试数据
-- ============================================

INSERT INTO rental_items (user_id, title, description, category, rental_price, deposit, min_days, location, campus)
SELECT u.id, '索尼A7M4全画幅相机出租', '自用索尼A7M4+24-70GM镜头，适合拍短视频、作业拍摄，押金可退', 'camera', 80, 5000, 1, '传媒学院器材室', '延长校区'
FROM users u WHERE u.username = 'zhangsan' AND NOT EXISTS (SELECT 1 FROM rental_items WHERE title = '索尼A7M4全画幅相机出租');

INSERT INTO rental_items (user_id, title, description, category, rental_price, deposit, min_days, location, campus)
SELECT u.id, '大疆Mini 4 Pro无人机出租', '大疆Mini4Pro畅飞套装，成色极新，适合航拍校园活动', 'drone', 50, 2000, 1, '理工楼实验室', '宝山校区'
FROM users u WHERE u.username = 'lisi' AND NOT EXISTS (SELECT 1 FROM rental_items WHERE title = '大疆Mini 4 Pro无人机出租');

INSERT INTO rental_items (user_id, title, description, category, rental_price, deposit, min_days, location, campus)
SELECT u.id, '九号电动车 N70C 暑假转租', '暑假离校出租电动车，续航60km，押金还车退还，出问题包修', 'bike', 8, 800, 7, '东门充电桩旁', '沪东校区'
FROM users u WHERE u.username = 'wangwu' AND NOT EXISTS (SELECT 1 FROM rental_items WHERE title = '九号电动车 N70C 暑假转租');

INSERT INTO rental_items (user_id, title, description, category, rental_price, deposit, min_days, location, campus)
SELECT u.id, 'Nintendo Switch OLED 游戏机出租', '港版Switch OLED+塞尔达+马车8+大乱斗，暑假在家无聊？租台游戏机回去玩', 'console', 15, 1000, 7, '5号宿舍楼', '宝山校区'
FROM users u WHERE u.username = 'zhangsan' AND NOT EXISTS (SELECT 1 FROM rental_items WHERE title = 'Nintendo Switch OLED 游戏机出租');

INSERT INTO rental_items (user_id, title, description, category, rental_price, deposit, min_days, location, campus)
SELECT u.id, '尤尼克斯天斧100ZZ羽毛球拍出租', '正品天斧100ZZ 4UG5，穿BG80线26磅，适合比赛或体验', 'racket', 10, 300, 1, '校体育馆羽毛球馆', '沪东校区'
FROM users u WHERE u.username = 'lisi' AND NOT EXISTS (SELECT 1 FROM rental_items WHERE title = '尤尼克斯天斧100ZZ羽毛球拍出租');

INSERT INTO rental_items (user_id, title, description, category, rental_price, deposit, min_days, location, campus)
SELECT u.id, '极米投影仪 Z6X 出租', '家用投影仪1080P，带幕布，适合宿舍看电影、小组展示', 'projector', 25, 1500, 1, '学生活动中心', '延长校区'
FROM users u WHERE u.username = 'wangwu' AND NOT EXISTS (SELECT 1 FROM rental_items WHERE title = '极米投影仪 Z6X 出租');

-- ============================================
-- V006: 校园服务模块增强 + 测试数据
-- 说明：
-- 1. storage_services/requests 扩展字段
-- 2. 校园转租 + 寄存种子数据
-- 3. 确保 admin/operator 账号可登录
-- 4. 代金券 + 购物车测试数据
-- 5. 所有操作保证幂等
-- ============================================


-- ============================================
-- 1. storage_services 扩展
-- ============================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=current_schema() AND table_name='storage_services' AND column_name='image_url') THEN
        ALTER TABLE storage_services ADD COLUMN image_url VARCHAR(500);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=current_schema() AND table_name='storage_services' AND column_name='remain_capacity') THEN
        ALTER TABLE storage_services ADD COLUMN remain_capacity INTEGER;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=current_schema() AND table_name='storage_services' AND column_name='contact_info') THEN
        ALTER TABLE storage_services ADD COLUMN contact_info VARCHAR(200);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=current_schema() AND table_name='storage_services' AND column_name='location_detail') THEN
        ALTER TABLE storage_services ADD COLUMN location_detail TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=current_schema() AND table_name='storage_services' AND column_name='start_time') THEN
        ALTER TABLE storage_services ADD COLUMN start_time TIMESTAMP;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=current_schema() AND table_name='storage_services' AND column_name='end_time') THEN
        ALTER TABLE storage_services ADD COLUMN end_time TIMESTAMP;
    END IF;
END $$;

-- 更新状态值约束（如果存在旧约束则跳过）
DO $$
BEGIN
    ALTER TABLE storage_services DROP CONSTRAINT IF EXISTS storage_services_status_check;
    ALTER TABLE storage_services ADD CONSTRAINT storage_services_status_check
        CHECK (status IN ('available','almost_full','full'));
EXCEPTION WHEN others THEN NULL;
END $$;

-- ============================================
-- 2. storage_requests 扩展
-- ============================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=current_schema() AND table_name='storage_requests' AND column_name='contact_info') THEN
        ALTER TABLE storage_requests ADD COLUMN contact_info VARCHAR(200);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=current_schema() AND table_name='storage_requests' AND column_name='expected_start_time') THEN
        ALTER TABLE storage_requests ADD COLUMN expected_start_time TIMESTAMP;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=current_schema() AND table_name='storage_requests' AND column_name='expected_end_time') THEN
        ALTER TABLE storage_requests ADD COLUMN expected_end_time TIMESTAMP;
    END IF;
END $$;

-- 更新状态值
DO $$
BEGIN
    ALTER TABLE storage_requests DROP CONSTRAINT IF EXISTS storage_requests_status_check;
    ALTER TABLE storage_requests ADD CONSTRAINT storage_requests_status_check
        CHECK (status IN ('searching','matched','closed'));
EXCEPTION WHEN others THEN NULL;
END $$;

-- ============================================
-- 3. 更新 V005 种子数据，补充新字段值
-- ============================================
UPDATE storage_services
SET remain_capacity = capacity,
    contact_info = '微信: campus_zhangsan',
    start_time = '2026-07-01 00:00:00',
    end_time = '2026-08-31 23:59:59',
    location_detail = '进校门后直走200米，右手边车棚，蓝色雨棚下面',
    status = 'available'
WHERE title = '宿舍楼下电动车寄存位' AND remain_capacity IS NULL;

UPDATE storage_services
SET remain_capacity = capacity,
    contact_info = '微信: lisi_dorm',
    start_time = '2026-07-01 00:00:00',
    end_time = '2026-08-31 23:59:59',
    location_detail = '7号楼进门左转第一间储物间，有独立锁',
    status = 'available'
WHERE title = '寒假行李寄存 宿舍储物间' AND remain_capacity IS NULL;

UPDATE storage_services
SET remain_capacity = capacity,
    contact_info = '微信: wangwu_fridge',
    start_time = '2026-07-01 00:00:00',
    end_time = '2026-08-31 23:59:59',
    location_detail = '学校创业园B区101室，进门右手边',
    status = 'available'
WHERE title = '小冰箱暑假寄存' AND remain_capacity IS NULL;

UPDATE storage_requests
SET contact_info = '手机: 138****6789',
    expected_start_time = '2026-07-01 00:00:00',
    expected_end_time = '2026-08-31 23:59:59',
    status = 'searching'
WHERE title = '求寄存电动车 暑假两个月' AND contact_info IS NULL;

UPDATE storage_requests
SET contact_info = '微信: lisi_bags',
    expected_start_time = '2027-01-15 00:00:00',
    expected_end_time = '2027-02-15 23:59:59',
    status = 'searching'
WHERE title = '寒假行李寄存一个月' AND contact_info IS NULL;

-- ============================================
-- 3.5 补充校园寄存需求测试数据
-- ============================================

-- zhangsan: 考研书籍寄存
INSERT INTO storage_requests (user_id, title, description, item_type, campus, location, budget, expected_start_time, expected_end_time, contact_info, status)
SELECT u.id, '考研书籍和笔记寄存 暑假两个月',
    '考研党，暑假要回家复习但宿舍清空，有一箱考研书籍+笔记+iPad需要寄存，怕受潮，最好有干燥通风的地方',
    'book', '宝山校区', '', 25, '2026-07-05 00:00:00', '2026-09-01 00:00:00', '微信: zhangsan_kaoyan', 'searching'
FROM users u WHERE u.username = 'zhangsan'
AND NOT EXISTS (SELECT 1 FROM storage_requests WHERE title = '考研书籍和笔记寄存 暑假两个月');

-- lisi: 小型冰箱寄存
INSERT INTO storage_requests (user_id, title, description, item_type, campus, location, budget, expected_start_time, expected_end_time, contact_info, status)
SELECT u.id, '小型宿舍冰箱暑假寄存',
    '50L小冰箱暑假需要寄存两个月，静音省电，最好校内地下室或有电源的地方，离沪东校区近优先',
    'appliance', '沪东校区', '', 30, '2026-07-10 00:00:00', '2026-09-05 00:00:00', '手机: 139****1234', 'searching'
FROM users u WHERE u.username = 'lisi'
AND NOT EXISTS (SELECT 1 FROM storage_requests WHERE title = '小型宿舍冰箱暑假寄存');

-- wangwu: 两个大行李箱寄存
INSERT INTO storage_requests (user_id, title, description, item_type, campus, location, budget, expected_start_time, expected_end_time, contact_info, status)
SELECT u.id, '两个28寸行李箱寒假寄存',
    '寒假回家过春节，两个大行李箱+一床被子需要寄存大约一个月，箱子有密码锁，找个靠谱的地方',
    'suitcase', '延长校区', '', 35, '2027-01-20 00:00:00', '2027-02-20 00:00:00', '微信: wangwu_bags', 'searching'
FROM users u WHERE u.username = 'wangwu'
AND NOT EXISTS (SELECT 1 FROM storage_requests WHERE title = '两个28寸行李箱寒假寄存');

-- zhangsan: 电动车寄存
INSERT INTO storage_requests (user_id, title, description, item_type, campus, location, budget, expected_start_time, expected_end_time, contact_info, status)
SELECT u.id, '九号电动车寄存一个月',
    '新买的九号N70C，寒假回家需要寄存一个月，最好有遮雨棚和充电设施，宝山校区内优先',
    'bike', '宝山校区', '', 50, '2027-01-15 00:00:00', '2027-02-15 00:00:00', '微信: zhangsan_bike', 'searching'
FROM users u WHERE u.username = 'zhangsan'
AND NOT EXISTS (SELECT 1 FROM storage_requests WHERE title = '九号电动车寄存一个月');

-- lisi: 被褥和冬季衣物寄存
INSERT INTO storage_requests (user_id, title, description, item_type, campus, location, budget, expected_start_time, expected_end_time, contact_info, status)
SELECT u.id, '冬季被褥和厚衣服寄存',
    '一床厚被子+羽绒服+棉衣，大概两个大收纳袋，暑假不需要带回老家，找地方存放两个月，要求干燥防潮',
    'suitcase', '嘉定校区', '', 20, '2026-07-01 00:00:00', '2026-08-31 00:00:00', '手机: 156****7890', 'searching'
FROM users u WHERE u.username = 'lisi'
AND NOT EXISTS (SELECT 1 FROM storage_requests WHERE title = '冬季被褥和厚衣服寄存');

-- wangwu: 台式电脑寄存
INSERT INTO storage_requests (user_id, title, description, item_type, campus, location, budget, expected_start_time, expected_end_time, contact_info, status)
SELECT u.id, '台式电脑+显示器暑假寄存',
    '组装台式机+27寸显示器+机械键盘，价值较高，需要有安全保障的寄存环境（监控/有人看管），最好能偶尔开机通电防潮',
    'appliance', '延长校区', '', 60, '2026-07-01 00:00:00', '2026-09-01 00:00:00', '微信: wangwu_pc', 'searching'
FROM users u WHERE u.username = 'wangwu'
AND NOT EXISTS (SELECT 1 FROM storage_requests WHERE title = '台式电脑+显示器暑假寄存');

-- ============================================
-- 4. 校园转租服务 — 种子数据（符合校园场景）
-- ============================================

-- 清理旧转租数据（V005的），重新插入带完整字段的
DELETE FROM rental_items WHERE title IN (
    '索尼A7M4全画幅相机出租', '大疆Mini 4 Pro无人机出租', '九号电动车 N70C 暑假转租',
    'Nintendo Switch OLED 游戏机出租', '尤尼克斯天斧100ZZ羽毛球拍出租', '极米投影仪 Z6X 出租',
    '佳能镜头 70-200mm F2.8 出租', 'iPad Pro + Apple Pencil 出租', '索尼PS5游戏机出租'
);

-- 相机类
INSERT INTO rental_items (user_id, title, description, category, rental_price, deposit, min_days, location, campus)
SELECT u.id, '索尼A7M4全画幅相机出租',
    '自用索尼A7M4+24-70GM二代镜头，快门3000次，成色98新，适合拍短视频、课程作业、校园活动拍摄。包含原装电池2块+充电器+64G SD卡',
    'camera', 80, 5000, 1, '传媒学院器材室', '延长校区'
FROM users u WHERE u.username = 'zhangsan'
AND NOT EXISTS (SELECT 1 FROM rental_items WHERE title = '索尼A7M4全画幅相机出租');

INSERT INTO rental_items (user_id, title, description, category, rental_price, deposit, min_days, location, campus)
SELECT u.id, '佳能镜头 70-200mm F2.8 出租',
    '佳能小白兔二代，成色极好，镜片无划痕无霉点，适合拍运动会、文艺晚会等校园活动',
    'camera', 50, 3000, 1, '摄影社团活动室', '宝山校区'
FROM users u WHERE u.username = 'lisi'
AND NOT EXISTS (SELECT 1 FROM rental_items WHERE title = '佳能镜头 70-200mm F2.8 出租');

-- 无人机类
INSERT INTO rental_items (user_id, title, description, category, rental_price, deposit, min_days, location, campus)
SELECT u.id, '大疆Mini 4 Pro无人机出租',
    '大疆Mini4Pro畅飞套装（三电+带屏遥控），成色极新，续航47分钟，4K/60fps，适合航拍校园全景、毕业照创意拍摄',
    'drone', 50, 2000, 1, '理工楼实验室', '宝山校区'
FROM users u WHERE u.username = 'lisi'
AND NOT EXISTS (SELECT 1 FROM rental_items WHERE title = '大疆Mini 4 Pro无人机出租');

-- 电动车类
INSERT INTO rental_items (user_id, title, description, category, rental_price, deposit, min_days, location, campus)
SELECT u.id, '九号电动车 N70C 暑假转租',
    '暑假离校出租电动车，续航60km，最高时速45km/h，充满电可跑一周，押金还车退还。送头盔+雨披+充电器',
    'bike', 8, 800, 7, '东门充电桩旁', '沪东校区'
FROM users u WHERE u.username = 'wangwu'
AND NOT EXISTS (SELECT 1 FROM rental_items WHERE title = '九号电动车 N70C 暑假转租');

-- 游戏机类
INSERT INTO rental_items (user_id, title, description, category, rental_price, deposit, min_days, location, campus)
SELECT u.id, 'Nintendo Switch OLED 游戏机出租',
    '港版Switch OLED白色+塞尔达王国之泪+马里奥赛车8+任天堂大乱斗+健身环，周末宿舍聚会必备',
    'console', 15, 1000, 3, '5号宿舍楼318室', '宝山校区'
FROM users u WHERE u.username = 'zhangsan'
AND NOT EXISTS (SELECT 1 FROM rental_items WHERE title = 'Nintendo Switch OLED 游戏机出租');

INSERT INTO rental_items (user_id, title, description, category, rental_price, deposit, min_days, location, campus)
SELECT u.id, '索尼PS5游戏机出租',
    '国行PS5光驱版+双手柄+蜘蛛侠2+战神诸神黄昏+GT7，配4K显示器，畅享次世代游戏体验',
    'console', 20, 1500, 3, '研究生公寓2号楼', '延长校区'
FROM users u WHERE u.username = 'lisi'
AND NOT EXISTS (SELECT 1 FROM rental_items WHERE title = '索尼PS5游戏机出租');

-- 球拍类
INSERT INTO rental_items (user_id, title, description, category, rental_price, deposit, min_days, location, campus)
SELECT u.id, '尤尼克斯天斧100ZZ羽毛球拍出租',
    '正品天斧100ZZ 4UG5，穿BG80线26磅，手感极佳，适合比赛或试打体验，送球拍袋',
    'racket', 10, 300, 1, '校体育馆羽毛球馆前台', '沪东校区'
FROM users u WHERE u.username = 'wangwu'
AND NOT EXISTS (SELECT 1 FROM rental_items WHERE title = '尤尼克斯天斧100ZZ羽毛球拍出租');

-- 投影仪类
INSERT INTO rental_items (user_id, title, description, category, rental_price, deposit, min_days, location, campus)
SELECT u.id, '极米投影仪 Z6X 出租',
    '1080P高清投影仪，800ANSI流明，自带哈曼卡顿音响，送100寸幕布，适合宿舍观影、小组展示、社团活动',
    'projector', 25, 1500, 1, '学生活动中心器材室', '延长校区'
FROM users u WHERE u.username = 'wangwu'
AND NOT EXISTS (SELECT 1 FROM rental_items WHERE title = '极米投影仪 Z6X 出租');

-- 平板类
INSERT INTO rental_items (user_id, title, description, category, rental_price, deposit, min_days, location, campus)
SELECT u.id, 'iPad Pro + Apple Pencil 出租',
    'iPad Pro 2022 12.9寸 M2芯片 + Apple Pencil二代，配妙控键盘，适合设计专业绘图、无纸化学习、考研刷题',
    'other', 30, 3000, 1, '图书馆自习室', '宝山校区'
FROM users u WHERE u.username = 'zhangsan'
AND NOT EXISTS (SELECT 1 FROM rental_items WHERE title = 'iPad Pro + Apple Pencil 出租');

-- ============================================
-- 5. 确保 admin/operator 账号存在且可登录
--    （修复本地测试时 admin 登录失败问题）
-- ============================================
INSERT INTO users (username, password, real_name, role, campus, status)
SELECT 'admin', '123456', '超级管理员', 'admin', NULL, 1
WHERE NOT EXISTS (SELECT 1 FROM users WHERE username = 'admin');

INSERT INTO users (username, password, real_name, role, campus, status)
SELECT 'operator', '123456', '运营人员', 'operator', NULL, 1
WHERE NOT EXISTS (SELECT 1 FROM users WHERE username = 'operator');

-- 如果已存在但被禁用，则重新启用
UPDATE users SET status = 1, password = '123456' WHERE username IN ('admin', 'operator') AND (status = 0 OR password IS NULL);

-- ============================================
-- 6. 校园代金券测试数据（符合抽奖逻辑）
--    代金券金额 = 订单实付价 × 随机5%~10%
--    有效期30天，状态 unused
-- ============================================

-- zhangsan 买了毕业甩卖的机械键盘(¥150 → 补贴价¥135)，抽到 7.4%=¥10.00
INSERT INTO vouchers (user_id, activity_id, order_id, amount, status, obtained_at, expires_at)
SELECT
    (SELECT id FROM users WHERE username='zhangsan' LIMIT 1),
    (SELECT id FROM activities WHERE type='graduation_sale' LIMIT 1),
    NULL,
    10.00, 'unused',
    '2026-07-10 15:30:00',
    '2026-08-09 15:30:00'
WHERE NOT EXISTS (SELECT 1 FROM vouchers WHERE user_id=(SELECT id FROM users WHERE username='zhangsan' LIMIT 1) AND amount=10.00 AND obtained_at='2026-07-10 15:30:00');

-- lisi 买了考研资料408全套(¥80 → 补贴价¥72)，抽到 8.3%=¥6.00
INSERT INTO vouchers (user_id, activity_id, order_id, amount, status, obtained_at, expires_at)
SELECT
    (SELECT id FROM users WHERE username='lisi' LIMIT 1),
    (SELECT id FROM activities WHERE type='exam_materials' LIMIT 1),
    NULL,
    6.00, 'unused',
    '2026-07-12 10:15:00',
    '2026-08-11 10:15:00'
WHERE NOT EXISTS (SELECT 1 FROM vouchers WHERE user_id=(SELECT id FROM users WHERE username='lisi' LIMIT 1) AND amount=6.00 AND obtained_at='2026-07-12 10:15:00');

-- wangwu 买了新生专区的山地自行车(¥280 → 补贴价¥252)，抽到 5.6%=¥14.00
INSERT INTO vouchers (user_id, activity_id, order_id, amount, status, obtained_at, expires_at)
SELECT
    (SELECT id FROM users WHERE username='wangwu' LIMIT 1),
    (SELECT id FROM activities WHERE type='freshman_market' LIMIT 1),
    NULL,
    14.00, 'unused',
    '2026-07-08 20:45:00',
    '2026-08-07 20:45:00'
WHERE NOT EXISTS (SELECT 1 FROM vouchers WHERE user_id=(SELECT id FROM users WHERE username='wangwu' LIMIT 1) AND amount=14.00 AND obtained_at='2026-07-08 20:45:00');

-- zhangsan 买了考研政治全套(¥35 → 补贴价¥31.5)，抽到 9.5%=¥3.00
INSERT INTO vouchers (user_id, activity_id, order_id, amount, status, obtained_at, expires_at)
SELECT
    (SELECT id FROM users WHERE username='zhangsan' LIMIT 1),
    (SELECT id FROM activities WHERE type='exam_materials' LIMIT 1),
    NULL,
    3.00, 'unused',
    '2026-07-05 09:20:00',
    '2026-08-04 09:20:00'
WHERE NOT EXISTS (SELECT 1 FROM vouchers WHERE user_id=(SELECT id FROM users WHERE username='zhangsan' LIMIT 1) AND amount=3.00 AND obtained_at='2026-07-05 09:20:00');

-- lisi 买了毕业甩卖的宿舍小冰箱(¥280 → 补贴价¥252)，抽到 6.3%=¥16.00
INSERT INTO vouchers (user_id, activity_id, order_id, amount, status, obtained_at, expires_at)
SELECT
    (SELECT id FROM users WHERE username='lisi' LIMIT 1),
    (SELECT id FROM activities WHERE type='graduation_sale' LIMIT 1),
    NULL,
    16.00, 'unused',
    '2026-07-15 14:00:00',
    '2026-08-14 14:00:00'
WHERE NOT EXISTS (SELECT 1 FROM vouchers WHERE user_id=(SELECT id FROM users WHERE username='lisi' LIMIT 1) AND amount=16.00 AND obtained_at='2026-07-15 14:00:00');

-- wangwu 之前买过高数教材订单(¥25)，抽到 8%=¥2.00（已使用）
INSERT INTO vouchers (user_id, activity_id, order_id, amount, status, obtained_at, expires_at, used_at)
SELECT
    (SELECT id FROM users WHERE username='wangwu' LIMIT 1),
    (SELECT id FROM activities WHERE type='freshman_market' LIMIT 1),
    NULL,
    2.00, 'used',
    '2026-06-20 12:00:00',
    '2026-07-20 12:00:00',
    '2026-06-25 18:00:00'
WHERE NOT EXISTS (SELECT 1 FROM vouchers WHERE user_id=(SELECT id FROM users WHERE username='wangwu' LIMIT 1) AND amount=2.00 AND status='used');

-- ============================================
-- 7. 购物车测试数据（符合校园交易场景）
-- ============================================

-- zhangsan 想买考研资料（把考研英语真题加入购物车）
INSERT INTO cart (user_id, item_id)
SELECT
    (SELECT id FROM users WHERE username='zhangsan' LIMIT 1),
    (SELECT id FROM items WHERE title='考研英语一历年真题 2000-2025' LIMIT 1)
WHERE NOT EXISTS (
    SELECT 1 FROM cart WHERE user_id=(SELECT id FROM users WHERE username='zhangsan' LIMIT 1)
    AND item_id=(SELECT id FROM items WHERE title='考研英语一历年真题 2000-2025' LIMIT 1)
);

-- zhangsan 也想买新生专区的小米显示器
INSERT INTO cart (user_id, item_id)
SELECT
    (SELECT id FROM users WHERE username='zhangsan' LIMIT 1),
    (SELECT id FROM items WHERE title='小米显示器 23.8寸 1080P' LIMIT 1)
WHERE NOT EXISTS (
    SELECT 1 FROM cart WHERE user_id=(SELECT id FROM users WHERE username='zhangsan' LIMIT 1)
    AND item_id=(SELECT id FROM items WHERE title='小米显示器 23.8寸 1080P' LIMIT 1)
);

-- lisi 想买毕业甩卖的机械键盘
INSERT INTO cart (user_id, item_id)
SELECT
    (SELECT id FROM users WHERE username='lisi' LIMIT 1),
    (SELECT id FROM items WHERE title='机械键盘 Cherry MX 红轴' LIMIT 1)
WHERE NOT EXISTS (
    SELECT 1 FROM cart WHERE user_id=(SELECT id FROM users WHERE username='lisi' LIMIT 1)
    AND item_id=(SELECT id FROM items WHERE title='机械键盘 Cherry MX 红轴' LIMIT 1)
);

-- lisi 想买iPad Pro
INSERT INTO cart (user_id, item_id)
SELECT
    (SELECT id FROM users WHERE username='lisi' LIMIT 1),
    (SELECT id FROM items WHERE title='iPad Pro 2022 11寸 256G' LIMIT 1)
WHERE NOT EXISTS (
    SELECT 1 FROM cart WHERE user_id=(SELECT id FROM users WHERE username='lisi' LIMIT 1)
    AND item_id=(SELECT id FROM items WHERE title='iPad Pro 2022 11寸 256G' LIMIT 1)
);

-- wangwu 想买新生专区的USB小风扇和人体工学椅
INSERT INTO cart (user_id, item_id)
SELECT
    (SELECT id FROM users WHERE username='wangwu' LIMIT 1),
    (SELECT id FROM items WHERE title='USB小台扇 静音桌面风扇' LIMIT 1)
WHERE NOT EXISTS (
    SELECT 1 FROM cart WHERE user_id=(SELECT id FROM users WHERE username='wangwu' LIMIT 1)
    AND item_id=(SELECT id FROM items WHERE title='USB小台扇 静音桌面风扇' LIMIT 1)
);

INSERT INTO cart (user_id, item_id)
SELECT
    (SELECT id FROM users WHERE username='wangwu' LIMIT 1),
    (SELECT id FROM items WHERE title='人体工学椅 网易严选' LIMIT 1)
WHERE NOT EXISTS (
    SELECT 1 FROM cart WHERE user_id=(SELECT id FROM users WHERE username='wangwu' LIMIT 1)
    AND item_id=(SELECT id FROM items WHERE title='人体工学椅 网易严选' LIMIT 1)
);

-- ============================================
-- V007: 综合修复 + 补充种子数据
-- 1. 彻底修复 admin/operator 登录问题
-- 2. 移除同一用户的寄存冲突数据
-- 3. 所有操作保证幂等
-- ============================================


-- ============================================
-- 1. 彻底修复 admin/operator 登录
--    - 确保密码为纯文本 '123456'（无空白）
--    - 确保 role 正确
--    - 确保 status = 1（启用）
-- ============================================
UPDATE users
SET password = '123456',
    role = CASE WHEN username = 'admin' THEN 'admin' WHEN username = 'operator' THEN 'operator' ELSE role END,
    status = 1
WHERE username IN ('admin', 'operator');

-- ============================================
-- 2. 移除冲突数据：zhangsan 不应既有寄存服务又有同类需求
--    zhangsan 的需求「求寄存电动车 暑假两个月」与其服务「宿舍楼下电动车寄存位」冲突
--    改为删除 zhangsan 的电动车寄存需求（他提供的是服务）
-- ============================================
DELETE FROM storage_requests
WHERE user_id = (SELECT id FROM users WHERE username = 'zhangsan' LIMIT 1)
  AND title = '求寄存电动车 暑假两个月';

-- 同样删除 zhangsan 的「九号电动车寄存一个月」需求
DELETE FROM storage_requests
WHERE user_id = (SELECT id FROM users WHERE username = 'zhangsan' LIMIT 1)
  AND title = '九号电动车寄存一个月';

-- ============================================
-- 3. 补充一条更合理的数据：
--    zhangsan 提供电动车寄存（已有），同时新增一条他的行李寄存需求
-- ============================================
INSERT INTO storage_requests (user_id, title, description, item_type, campus, location, budget, expected_start_time, expected_end_time, contact_info, status)
SELECT u.id, '假期行李和被子寄存',
    '暑假回家，一个28寸行李箱+一床冬被需要寄存两个月，宝山校区内优先',
    'suitcase', '宝山校区', '', 30,
    '2026-07-05 00:00:00', '2026-09-01 00:00:00',
    '微信: zhangsan_kaoyan', 'searching'
FROM users u WHERE u.username = 'zhangsan'
AND NOT EXISTS (SELECT 1 FROM storage_requests WHERE user_id = u.id AND title = '假期行李和被子寄存');

-- ============================================
-- 3. rental_items 表增加 contact_info 字段
--    用于在前端详情弹窗中展示联系方式
-- ============================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=current_schema() AND table_name='rental_items' AND column_name='contact_info') THEN
        ALTER TABLE rental_items ADD COLUMN contact_info VARCHAR(200);
    END IF;
END $$;

-- 补充转租物品的联系方式
UPDATE rental_items SET contact_info = '微信: campus_zhangsan' WHERE title = '索尼A7M4全画幅相机出租' AND contact_info IS NULL;
UPDATE rental_items SET contact_info = '手机: 138****5678' WHERE title = '佳能镜头 70-200mm F2.8 出租' AND contact_info IS NULL;
UPDATE rental_items SET contact_info = '微信: lisi_drone' WHERE title = '大疆Mini 4 Pro无人机出租' AND contact_info IS NULL;
UPDATE rental_items SET contact_info = '微信: wangwu_bike' WHERE title = '九号电动车 N70C 暑假转租' AND contact_info IS NULL;
UPDATE rental_items SET contact_info = '微信: campus_zhangsan' WHERE title = 'Nintendo Switch OLED 游戏机出租' AND contact_info IS NULL;
UPDATE rental_items SET contact_info = '微信: lisi_game' WHERE title = '索尼PS5游戏机出租' AND contact_info IS NULL;
UPDATE rental_items SET contact_info = '手机: 156****9012' WHERE title = '尤尼克斯天斧100ZZ羽毛球拍出租' AND contact_info IS NULL;
UPDATE rental_items SET contact_info = '微信: wangwu_proj' WHERE title = '极米投影仪 Z6X 出租' AND contact_info IS NULL;
UPDATE rental_items SET contact_info = '微信: campus_zhangsan' WHERE title = 'iPad Pro + Apple Pencil 出租' AND contact_info IS NULL;

-- ============================================
-- V008: 校园生活服务订单系统 + 审核机制 + 需求接单
-- 1. storage_services/requests/rental_items 增加审核字段
-- 2. storage_orders 表：寄存服务预约订单
-- 3. 测试数据：寄存预约 + 租赁订单
-- 4. 所有操作保证幂等
-- ============================================


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

-- ============================================
-- V009: 毕业季公益循环计划
-- 1. items 增加 item_type / free_deadline
-- 2. free_apply 免费领取申请表
-- 3. donation_record 公益捐赠记录表
-- 4. users 增加 charity_points
-- 5. 测试数据：公益商品 + 领取申请
-- 6. 所有操作保证幂等
-- ============================================


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
