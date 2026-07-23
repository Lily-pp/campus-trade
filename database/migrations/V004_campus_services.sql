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

BEGIN;

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

COMMIT;
