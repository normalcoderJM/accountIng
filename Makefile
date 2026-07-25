.PHONY: dev-api tidy-api
# 命令执行go 省去cd目录的步骤
dev-api:
	cd apps/api && go run ./cmd/server

tidy-api:
	cd apps/api && go mod tidy
# flutter 执行命令
dev-mobile:
	cd apps/mobile && flutter run

doctor-mobile:
	cd apps/mobile && flutter doctor