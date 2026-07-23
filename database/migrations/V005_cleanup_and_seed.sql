-- ============================================
-- V005: 清理 + 校园节点化运营种子数据
-- 说明：
-- 1. 移除 activities 中的「寒暑假闲置寄存」（改由校园生活服务承载）
-- 2. 为三个官方补贴活动插入校园商品测试数据
-- 3. 插入寄存服务和转租物品测试数据
-- 4. 所有 INSERT 使用 WHERE NOT EXISTS 保证幂等
-- ============================================

BEGIN;

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

COMMIT;
