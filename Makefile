.PHONY: dev-api tidy-api migrate-up migrate-version migrate-create
# 命令执行go 省去cd目录的步骤 set -a 会把 .env 中读取的变量自动导出给 Go 程序。
dev-api:
	cd apps/api && \
	set -a && \
	. ../../.env && \
	set +a && \
	go build -o ./bin/accounting-api ./cmd/server && \
	exec ./bin/accounting-api

tidy-api:
	cd apps/api && go mod tidy
# flutter 执行命令
dev-mobile:
	cd apps/mobile && flutter run

doctor-mobile:
	cd apps/mobile && flutter doctor

	# 执行所有尚未运行的数据库 migration。
migrate-up:
	cd apps/api && \
	set -a && \
	. ../../.env && \
	set +a && \
	migrate -path ./migrations -database "$$DATABASE_URL" up

# 查看当前数据库 migration 版本。
migrate-version:
	cd apps/api && \
	set -a && \
	. ../../.env && \
	set +a && \
	migrate -path ./migrations -database "$$DATABASE_URL" version

# 创建一对新的 up/down migration 文件。
# 使用方式：make migrate-create NAME=add_transaction_updated_at
migrate-create:
	@if [ -z "$(NAME)" ]; then \
		echo "Usage: make migrate-create NAME=migration_name"; \
		exit 1; \
	fi
	cd apps/api && \
	migrate create -ext sql -dir ./migrations -seq "$(NAME)"