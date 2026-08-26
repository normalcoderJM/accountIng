BEGIN;

-- 先允许为空，方便兼容已有账单。
ALTER TABLE transactions
ADD COLUMN occurred_at TIMESTAMPTZ;

-- 老数据没有实际发生时间，使用原 created_at 补齐。
UPDATE transactions
SET occurred_at = created_at
WHERE occurred_at IS NULL;

-- 数据补齐后改为必填。
ALTER TABLE transactions
ALTER COLUMN occurred_at SET NOT NULL;

-- 新增账单默认使用数据库当前时间。
-- Flutter 正常会明确传入 occurred_at。
ALTER TABLE transactions
ALTER COLUMN occurred_at SET DEFAULT NOW();

-- 旧分页使用 user_id + id，现在不再匹配新的排序方式。
DROP INDEX idx_transactions_user_id_id_desc;

-- 新的稳定分页索引：
-- WHERE user_id = ?
--   AND occurred_at >= ?
--   AND occurred_at < ?
-- ORDER BY occurred_at DESC, id DESC
CREATE INDEX idx_transactions_user_occurred_at_id_desc
ON transactions(user_id, occurred_at DESC, id DESC);

COMMIT;