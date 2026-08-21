package db

import (
	"database/sql"
	"fmt"

	// 匿名导入 不直接调用包里的函数 需要在初始化的时候把pgx这个数据库驱动注册到database/sql里
	_ "github.com/jackc/pgx/v5/stdlib"
)

func Open(databaseURL string) (*sql.DB, error) {
	// 连接对应docker的配置
	database, err := sql.Open("pgx", databaseURL)

	if err != nil {
		return nil, fmt.Errorf("Open database： %w", err)
	}

	if err := database.Ping(); err != nil {
		// 初始化失败后释放资源
		database.Close()
		return nil, fmt.Errorf("ping database:%w", err)
	}

	return database, nil
}
