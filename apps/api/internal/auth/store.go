package auth

import (
	"context"
	"database/sql"
	"errors"
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
		&user.Password,
		&user.Email,
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

// 判断邮箱是否唯一
func IsDuplicateEmail(err error) bool {
	return errors.Is(err, sql.ErrNoRows)
}
