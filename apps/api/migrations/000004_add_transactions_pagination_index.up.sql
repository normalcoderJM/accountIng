BEGIN;

-- 账单分页查询使用：
--
-- WHERE user_id = ?
--   AND id < ?
-- ORDER BY id DESC
--
-- user_id 放在前面，因为所有账单查询都必须限制当前用户。
-- id 放在后面，用于游标过滤和倒序排列。
CREATE INDEX idx_transactions_user_id_id_desc
ON transactions(user_id, id DESC);

COMMIT;