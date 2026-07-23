-- ============================================
-- V006: 校园服务模块增强 + 测试数据
-- 说明：
-- 1. storage_services/requests 扩展字段
-- 2. 校园转租 + 寄存种子数据
-- 3. 确保 admin/operator 账号可登录
-- 4. 代金券 + 购物车测试数据
-- 5. 所有操作保证幂等
-- ============================================

BEGIN;

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

COMMIT;
