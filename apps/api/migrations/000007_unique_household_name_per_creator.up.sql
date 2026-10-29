BEGIN;

-- 旧版本允许同一个创建者建立重名家庭。为保留所有账单和成员数据，
-- 给第二个及之后的重名家庭追加稳定的 ID 后缀，而不是删除记录。
DO $$
DECLARE
    duplicate_household RECORD;
    candidate_name TEXT;
    suffix TEXT;
    attempt INTEGER;
BEGIN
    FOR duplicate_household IN
        SELECT id, created_by_user_id, name
        FROM (
            SELECT
                id,
                created_by_user_id,
                name,
                ROW_NUMBER() OVER (
                    PARTITION BY created_by_user_id, LOWER(BTRIM(name))
                    ORDER BY created_at, id
                ) AS duplicate_number
            FROM households
        ) ranked
        WHERE duplicate_number > 1
        ORDER BY id
    LOOP
        attempt := 0;
        LOOP
            suffix := ' #' || duplicate_household.id::TEXT ||
                CASE WHEN attempt = 0 THEN '' ELSE '-' || attempt::TEXT END;
            candidate_name := LEFT(
                BTRIM(duplicate_household.name),
                40 - CHAR_LENGTH(suffix)
            ) || suffix;

            EXIT WHEN NOT EXISTS (
                SELECT 1
                FROM households
                WHERE created_by_user_id = duplicate_household.created_by_user_id
                  AND id <> duplicate_household.id
                  AND LOWER(BTRIM(name)) = LOWER(candidate_name)
            );
            attempt := attempt + 1;
        END LOOP;

        UPDATE households
        SET name = candidate_name,
            updated_at = NOW()
        WHERE id = duplicate_household.id;
    END LOOP;
END $$;

CREATE UNIQUE INDEX idx_households_creator_normalized_name_unique
ON households(created_by_user_id, LOWER(BTRIM(name)));

COMMIT;
