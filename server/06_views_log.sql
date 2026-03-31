-- 浏览记录表
CREATE TABLE IF NOT EXISTS views_log (
    id SERIAL PRIMARY KEY,
    user_id INTEGER,                        -- 未登录用户为 NULL
    item_id INTEGER NOT NULL,
    viewed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE
);

-- 按用户+商品建索引，加速查重和查询
CREATE INDEX IF NOT EXISTS idx_views_log_user ON views_log(user_id);
CREATE INDEX IF NOT EXISTS idx_views_log_item ON views_log(item_id);
