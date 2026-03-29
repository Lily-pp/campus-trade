-- 测试数据（OpenGauss 兼容版）

-- 先删除旧数据
DELETE FROM items;
DELETE FROM users;

-- 插入用户
INSERT INTO users (username, password, real_name, role) VALUES
('admin', '123456', '超级管理员', 'admin'),
('operator', '123456', '运营人员', 'operator');

-- 插入商品
INSERT INTO items (title, description, price, category_id, user_id, status) VALUES
('iPhone 13 九成新', '自用iPhone13，电池健康92%', 3800, 4, 1, 'on_sale'),
('高数教材', '同济第七版，几乎全新', 25, 1, 2, 'on_sale');