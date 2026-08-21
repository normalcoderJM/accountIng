-- 创建账单表  表示删除用户时 删除对应的账单
CREATE TABLE transactions(
    id BIGSERIAL PRIMARY KEY,
    type TEXT NOT NULL,
    amount BIGINT NOT NULL,
    category TEXT NOT NULL,
    note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE  
);
-- 首页按照用户和创建时间查询账单
-- 这个联合索引可以加速列表查询
CREATE INDEX idx_transactions_user_id_created_at
ON transactions(user_id,created_at DESC);
