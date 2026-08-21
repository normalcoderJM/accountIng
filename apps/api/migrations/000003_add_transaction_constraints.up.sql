BEGIN;

-- 账单类型只能是收入或支出。
ALTER TABLE transactions
ADD CONSTRAINT transactions_type_check
CHECK (type IN ('income', 'expense'))
NOT VALID;

-- 金额必须大于 0。
ALTER TABLE transactions
ADD CONSTRAINT transactions_amount_positive_check
CHECK (amount > 0)
NOT VALID;

-- 分类去掉前后空格后，长度必须在 1 到 20 之间。
ALTER TABLE transactions
ADD CONSTRAINT transactions_category_length_check
CHECK (
    char_length(btrim(category)) BETWEEN 1 AND 20
)
NOT VALID;

-- 备注可以为空，但最多 200 个字符。
ALTER TABLE transactions
ADD CONSTRAINT transactions_note_length_check
CHECK (
    note IS NULL OR char_length(note) <= 200
)
NOT VALID;

-- 验证现有数据。
ALTER TABLE transactions
VALIDATE CONSTRAINT transactions_type_check;

ALTER TABLE transactions
VALIDATE CONSTRAINT transactions_amount_positive_check;

ALTER TABLE transactions
VALIDATE CONSTRAINT transactions_category_length_check;

ALTER TABLE transactions
VALIDATE CONSTRAINT transactions_note_length_check;

COMMIT;