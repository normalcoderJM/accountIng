BEGIN;

DROP INDEX idx_households_creator_normalized_name_unique;

-- up 迁移为避免丢失数据而重命名了历史重复项，down 不猜测其原始名称。

COMMIT;
