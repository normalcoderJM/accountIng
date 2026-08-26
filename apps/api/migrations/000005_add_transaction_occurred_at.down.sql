BEGIN;

DROP INDEX idx_transactions_user_occurred_at_id_desc;

-- 回滚后恢复旧分页索引。
CREATE INDEX idx_transactions_user_id_id_desc
ON transactions(user_id, id DESC);

ALTER TABLE transactions
DROP COLUMN occurred_at;

COMMIT;