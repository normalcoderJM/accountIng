BEGIN;

-- 按创建顺序的相反方向删除约束。
ALTER TABLE transactions
DROP CONSTRAINT transactions_note_length_check;

ALTER TABLE transactions
DROP CONSTRAINT transactions_category_length_check;

ALTER TABLE transactions
DROP CONSTRAINT transactions_amount_positive_check;

ALTER TABLE transactions
DROP CONSTRAINT transactions_type_check;

COMMIT;