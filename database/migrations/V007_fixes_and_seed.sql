-- ============================================
-- V007: 综合修复 + 补充种子数据
-- 1. 彻底修复 admin/operator 登录问题
-- 2. 移除同一用户的寄存冲突数据
-- 3. 所有操作保证幂等
-- ============================================

BEGIN;

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

COMMIT;
