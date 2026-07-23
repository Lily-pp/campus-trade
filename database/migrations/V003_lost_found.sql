-- =============================================
-- V003_lost_found.sql
-- 失物招领模块
-- 创建时间：2026-07-16
-- =============================================

-- 1. 失物招领处表
CREATE TABLE IF NOT EXISTS lost_found_points (
    id              SERIAL PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    description     TEXT,
    location_detail VARCHAR(200),
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE lost_found_points IS '校园失物招领处';
COMMENT ON COLUMN lost_found_points.name IS '招领处名称，例如：图书馆一楼服务台';

-- 2. 招领物品表（捡到东西的人发布）
CREATE TABLE IF NOT EXISTS found_items (
    id                  SERIAL PRIMARY KEY,
    finder_user_id      INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title               VARCHAR(200) NOT NULL,
    description         TEXT NOT NULL,
    category            VARCHAR(50),
    found_location      VARCHAR(200) NOT NULL,
    placed_at_point_id  INTEGER REFERENCES lost_found_points(id),
    found_time          TIMESTAMP NOT NULL,
    image_url           TEXT,
    status              VARCHAR(20) DEFAULT 'available'
                        CHECK (status IN ('available', 'claimed', 'returned', 'expired')),
    contact_phone       VARCHAR(20),
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE found_items IS '招领物品（捡到的东西）';
COMMENT ON COLUMN found_items.status IS 'available=可认领, claimed=已被认领, returned=已归还, expired=已过期';

-- 3. 丢失申报表（丢东西的人发布）
CREATE TABLE IF NOT EXISTS lost_posts (
    id              SERIAL PRIMARY KEY,
    owner_user_id   INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title           VARCHAR(200) NOT NULL,
    description     TEXT NOT NULL,
    lost_location   VARCHAR(200) NOT NULL,
    lost_time       TIMESTAMP NOT NULL,
    image_url       TEXT,
    reward          NUMERIC(10,2) DEFAULT 0,
    status          VARCHAR(20) DEFAULT 'open'
                    CHECK (status IN ('open', 'found', 'claimed', 'closed')),
    contact_phone   VARCHAR(20),
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE lost_posts IS '丢失申报（丢东西的人发布）';
COMMENT ON COLUMN lost_posts.status IS 'open=寻找中, found=已找到, claimed=已认领, closed=已关闭';

-- 4. 交接记录表
CREATE TABLE IF NOT EXISTS lf_handovers (
    id                  SERIAL PRIMARY KEY,
    found_item_id       INTEGER REFERENCES found_items(id),
    lost_post_id        INTEGER REFERENCES lost_posts(id),
    claimed_by_user_id  INTEGER REFERENCES users(id),
    status              VARCHAR(20) DEFAULT 'proposed'
                        CHECK (status IN ('proposed', 'confirmed', 'completed', 'cancelled')),
    handover_time       TIMESTAMP,
    notes               TEXT,
    coupon_issued       BOOLEAN DEFAULT FALSE,
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE lf_handovers IS '失物招领交接记录';
COMMENT ON COLUMN lf_handovers.status IS 'proposed=提出交接, confirmed=双方确认, completed=交接完成, cancelled=已取消';

-- 5. 用户优惠券表
CREATE TABLE IF NOT EXISTS user_coupons (
    id                  SERIAL PRIMARY KEY,
    user_id             INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    coupon_code         VARCHAR(50) UNIQUE NOT NULL,
    discount_rate       NUMERIC(3,2) DEFAULT 0.90,
    source              VARCHAR(50) DEFAULT 'lost_found_handover',
    valid_from          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    valid_until         TIMESTAMP,
    is_used             BOOLEAN DEFAULT FALSE,
    used_at             TIMESTAMP,
    related_handover_id INTEGER REFERENCES lf_handovers(id),
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE user_coupons IS '用户优惠券（平台补贴）';
COMMENT ON COLUMN user_coupons.discount_rate IS '0.90 表示 9 折';

-- =============================================
-- 索引
-- =============================================
CREATE INDEX IF NOT EXISTS idx_found_items_status ON found_items(status);
CREATE INDEX IF NOT EXISTS idx_found_items_finder ON found_items(finder_user_id);
CREATE INDEX IF NOT EXISTS idx_found_items_found_time ON found_items(found_time DESC);
CREATE INDEX IF NOT EXISTS idx_lost_posts_status ON lost_posts(status);
CREATE INDEX IF NOT EXISTS idx_lost_posts_owner ON lost_posts(owner_user_id);
CREATE INDEX IF NOT EXISTS idx_lf_handovers_status ON lf_handovers(status);
CREATE INDEX IF NOT EXISTS idx_user_coupons_user ON user_coupons(user_id);
CREATE INDEX IF NOT EXISTS idx_user_coupons_code ON user_coupons(coupon_code);

-- =============================================
-- 初始化几个常见的失物招领处
-- =============================================
INSERT INTO lost_found_points (name, description, location_detail)
SELECT * FROM (VALUES
    ('图书馆一楼服务台', '图书馆一楼总服务台', '逸夫图书馆一楼'),
    ('第一食堂门口', '一食堂正门旁失物招领箱', '第一食堂正门'),
    ('教学楼A座门卫', 'A教学楼门卫室', '教学楼A座一层'),
    ('学生活动中心前台', '学生活动中心前台', '学生活动中心一楼'),
    ('宿舍区物业中心', '宿舍区物业服务中心', '南区宿舍物业')
) AS v(name, description, location_detail)
WHERE NOT EXISTS (SELECT 1 FROM lost_found_points LIMIT 1);

-- =============================================
-- 触发器：成功交接后自动发放 9 折优惠券
-- =============================================
CREATE OR REPLACE FUNCTION fn_issue_lost_found_coupon()
RETURNS TRIGGER AS $$
DECLARE
    v_owner_id INTEGER;
    v_coupon_code VARCHAR(50);
BEGIN
    -- 只有状态变为 completed 且还没发过券时才执行
    IF NEW.status = 'completed' AND (OLD.status IS DISTINCT FROM 'completed') AND NEW.coupon_issued = FALSE THEN
        
        -- 找到丢东西的人（优先用 lost_post 的 owner）
        IF NEW.lost_post_id IS NOT NULL THEN
            SELECT owner_user_id INTO v_owner_id
            FROM lost_posts
            WHERE id = NEW.lost_post_id;
        END IF;

        -- 如果找到了用户，就发券
        IF v_owner_id IS NOT NULL THEN
            -- 生成优惠券码
            v_coupon_code := 'LF' || TO_CHAR(NOW(), 'YYYYMMDD') || LPAD(NEW.id::TEXT, 4, '0');

            INSERT INTO user_coupons (
                user_id,
                coupon_code,
                discount_rate,
                source,
                valid_until,
                related_handover_id
            ) VALUES (
                v_owner_id,
                v_coupon_code,
                0.90,
                'lost_found_handover',
                NOW() + INTERVAL '30 days',
                NEW.id
            );

            -- 标记已发放
            NEW.coupon_issued := TRUE;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 绑定触发器（OpenGauss 必须用 EXECUTE PROCEDURE）
DROP TRIGGER IF EXISTS trg_issue_lost_found_coupon ON lf_handovers;
CREATE TRIGGER trg_issue_lost_found_coupon
    BEFORE UPDATE ON lf_handovers
    FOR EACH ROW
    EXECUTE PROCEDURE fn_issue_lost_found_coupon();

-- 给 found_items 表增加经纬度（兼容 OpenGauss）
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'found_items' AND column_name = 'longitude'
    ) THEN
        ALTER TABLE found_items ADD COLUMN longitude DECIMAL(10, 7);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'found_items' AND column_name = 'latitude'
    ) THEN
        ALTER TABLE found_items ADD COLUMN latitude DECIMAL(10, 7);
    END IF;
END $$;

-- 给 lost_posts 表增加经纬度（兼容 OpenGauss）
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'lost_posts' AND column_name = 'longitude'
    ) THEN
        ALTER TABLE lost_posts ADD COLUMN longitude DECIMAL(10, 7);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'lost_posts' AND column_name = 'latitude'
    ) THEN
        ALTER TABLE lost_posts ADD COLUMN latitude DECIMAL(10, 7);
    END IF;
END $$;

-- =============================================
-- 完成
-- =============================================