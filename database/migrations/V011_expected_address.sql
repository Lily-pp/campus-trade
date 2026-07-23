-- =============================================
-- V011_expected_address.sql
-- 商品期望交易地址
-- =============================================

ALTER TABLE items
    ADD COLUMN IF NOT EXISTS expected_address VARCHAR(200);

ALTER TABLE items
    ADD COLUMN IF NOT EXISTS expected_longitude DECIMAL(10, 7);

ALTER TABLE items
    ADD COLUMN IF NOT EXISTS expected_latitude DECIMAL(10, 7);
