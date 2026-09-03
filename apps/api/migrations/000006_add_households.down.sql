BEGIN;

-- 先删除依赖 household_id 的索引。
DROP INDEX idx_transactions_household_occurred_at_id_desc;

-- 删除账单中的家庭字段。
-- 对应的外键约束会随字段一起删除。
ALTER TABLE transactions
DROP COLUMN household_id;

-- 成员表依赖家庭表，必须先删除成员表。
DROP TABLE household_members;

DROP TABLE households;

COMMIT;