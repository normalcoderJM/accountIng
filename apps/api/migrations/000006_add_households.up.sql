BEGIN;

-- ============================================================
-- 1. 创建家庭表
-- ============================================================

CREATE TABLE households (
    id BIGSERIAL PRIMARY KEY,

    -- 家庭名称，例如“我们家”“小林的家庭”。
    name TEXT NOT NULL,

    -- 记录是谁创建了家庭。
    -- 家庭拥有者最终由 household_members.role = owner 表示。
    created_by_user_id BIGINT NOT NULL
        REFERENCES users(id)
        ON DELETE RESTRICT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT households_name_length_check
    CHECK (
        char_length(btrim(name)) BETWEEN 1 AND 40
    )
);

-- ============================================================
-- 2. 创建家庭成员表
-- ============================================================

CREATE TABLE household_members (
    id BIGSERIAL PRIMARY KEY,

    household_id BIGINT NOT NULL
        REFERENCES households(id)
        ON DELETE CASCADE,

    user_id BIGINT NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE,

    -- owner：家庭拥有者
    -- admin：管理员
    -- member：普通成员
    -- viewer：只能查看
    role TEXT NOT NULL DEFAULT 'member',

    -- 不立即删除退出家庭的成员记录。
    -- 保留记录有利于后续审计和恢复成员关系。
    status TEXT NOT NULL DEFAULT 'active',

    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT household_members_role_check
    CHECK (
        role IN ('owner', 'admin', 'member', 'viewer')
    ),

    CONSTRAINT household_members_status_check
    CHECK (
        status IN ('active', 'left')
    ),

    -- 同一个用户在同一个家庭只能有一条成员关系。
    CONSTRAINT household_members_household_user_unique
    UNIQUE (household_id, user_id)
);

-- 查询“当前用户加入了哪些家庭”时使用。
CREATE INDEX idx_household_members_user_status
ON household_members(user_id, status, household_id);

-- 一个家庭最多只能有一个有效 owner。
--
-- 这是部分唯一索引：
-- 只有 role=owner 且 status=active 的记录才参与唯一约束。
CREATE UNIQUE INDEX idx_household_members_one_active_owner
ON household_members(household_id)
WHERE role = 'owner' AND status = 'active';

-- ============================================================
-- 3. 给每一个现有用户创建默认家庭
-- ============================================================

INSERT INTO households (
    name,
    created_by_user_id
)
SELECT
    '我的家庭',
    users.id
FROM users;

-- ============================================================
-- 4. 把每个旧用户加入自己的默认家庭
-- ============================================================

INSERT INTO household_members (
    household_id,
    user_id,
    role,
    status
)
SELECT
    households.id,
    households.created_by_user_id,
    'owner',
    'active'
FROM households;

-- ============================================================
-- 5. 给现有账单增加 household_id
-- ============================================================

-- 第一步必须允许 NULL。
-- 如果直接设置 NOT NULL，现有账单没有 household_id，迁移会失败。
ALTER TABLE transactions
ADD COLUMN household_id BIGINT;

-- 根据账单原来的 user_id 找到这个用户的默认家庭。
UPDATE transactions
SET household_id = households.id
FROM households
WHERE households.created_by_user_id = transactions.user_id
  AND transactions.household_id IS NULL;

-- ============================================================
-- 6. 验证旧数据是否全部回填
-- ============================================================

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM transactions
        WHERE household_id IS NULL
    ) THEN
        RAISE EXCEPTION
            '存在未能匹配默认家庭的历史账单，取消迁移';
    END IF;
END
$$;

-- 数据全部回填成功后，才能设置为必填。
ALTER TABLE transactions
ALTER COLUMN household_id SET NOT NULL;

-- 最后添加外键。
ALTER TABLE transactions
ADD CONSTRAINT transactions_household_id_fkey
FOREIGN KEY (household_id)
REFERENCES households(id)
ON DELETE RESTRICT;

-- ============================================================
-- 7. 创建家庭账单分页索引
-- ============================================================

-- 后续家庭账单列表会使用：
--
-- WHERE household_id = ?
--   AND occurred_at >= ?
--   AND occurred_at < ?
-- ORDER BY occurred_at DESC, id DESC
CREATE INDEX idx_transactions_household_occurred_at_id_desc
ON transactions(
    household_id,
    occurred_at DESC,
    id DESC
);

COMMIT;