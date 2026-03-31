-- 测试数据（PostgreSQL 兼容）

-- 先删除旧数据（注意依赖顺序）
DELETE FROM favorites;
DELETE FROM items;
DELETE FROM users;

-- 插入用户
-- 后台管理员
INSERT INTO users (username, password, real_name, role, campus) VALUES
('admin', '123456', '超级管理员', 'admin', NULL),
('operator', '123456', '运营人员', 'operator', NULL);

-- 前台普通用户
INSERT INTO users (username, password, real_name, role, campus) VALUES
('zhangsan', '123456', '张三', 'user', '沪东校区'),
('lisi', '123456', '李四', 'user', '延长校区');

-- 插入商品（user_id 3 = zhangsan, user_id 4 = lisi）
INSERT INTO items (title, description, price, category_id, user_id, status) VALUES
('iPhone 13 九成新', '自用 iPhone 13，电池健康 92%，无划痕', 3800, 4, 3, 'on_sale'),
('高数教材同济第七版', '几乎全新，无笔记', 25, 1, 3, 'on_sale'),
('山地自行车', '骑了一年，车况良好，带坐垫', 350, 3, 4, 'on_sale'),
('台灯', '宿舍用小台灯，亮度可调', 45, 2, 4, 'on_sale'),
('笔记本电脑支架', '铝合金材质，折叠便携', 88, 4, 3, 'sold');