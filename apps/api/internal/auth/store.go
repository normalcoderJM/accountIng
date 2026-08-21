package auth

import (
	"context"
	"database/sql"
	"errors"

	"github.com/jackc/pgx/v5/pgconn"
)

type Store struct {
	db *sql.DB
}

func NewStore(db *sql.DB) *Store {
	return &Store{db: db}
}

// 注册用户 写入数据库
func (s *Store) CreateUser(ctx context.Context, email string, password string) (User, error) {
	const query = `INSERT INTO users(email,password) 
	VALUES($1,$2) 
	RETURNING id,email,password,created_at`

	var user User
	err := s.db.QueryRowContext(ctx, query, email, password).Scan(
		&user.Id,
		&user.Email,
		&user.Password,
		&user.CreateAt,
	)
	if err != nil {
		return User{}, err
	}

	return user, nil

}

// 通过邮箱查找用户名
func (s *Store) GetUserByEmail(ctx context.Context, email string) (User, error) {
	const query = `SELECT id,password,email,created_at FROM users WHERE email = $1`
	var user User
	err := s.db.QueryRowContext(ctx, query, email).Scan(
		&user.Id,
		&user.Password,
		&user.Email,
		&user.CreateAt,
	)
	if err != nil {
		return User{}, err
	}
	return user, nil
}

// 根据id查找用户名
func (s *Store) GetUserById(ctx context.Context, id int64) (User, error) {
	const query = `SELECT id,password,email,created_at FROM users WHERE id = $1`
	var user User
	err := s.db.QueryRowContext(ctx, query, id).Scan(
		&user.Id,
		&user.Password,
		&user.Email,
		&user.CreateAt,
	)
	if err != nil {
		return User{}, err
	}
	return user, nil
}

// IsDuplicateEmail 判断数据库错误是否为邮箱唯一键冲突。
func IsDuplicateEmail(err error) bool {
	var postgresError *pgconn.PgError
	// errors.As 会沿着错误包装链，
	// 查找真实的 PostgreSQL 错误。
	if !errors.As(err, &postgresError) {
		return false
	}
	return postgresError.Code == "23505"
}
