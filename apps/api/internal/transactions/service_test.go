package transactions

import (
	"context"
	"errors"
	"testing"
	"time"
)

// fakeTransactionRepository 是内存中的测试 Repository。
//
// 这里不连接 PostgreSQL，只测试 Service 的分页业务逻辑：
// - 是否多取一条后正确截断；
// - nextCursor 是否正确；
// - 默认 limit 是否生效；
// - Repository 错误是否向上传递。
type fakeTransactionRepository struct {
	listResult []Transaction
	listError  error

	summaryResult TransactionSummary
	summaryError  error

	receivedUserId        int64
	receivedCursor        int64
	receivedLimit         int
	receivedSummaryUserId int64
}

var (
	testStartAt = time.Date(
		2026, 8, 1,
		0, 0, 0, 0,
		time.UTC,
	)

	testEndAt = time.Date(
		2026, 9, 1,
		0, 0, 0, 0,
		time.UTC,
	)
)
var cursorText = encodeTransactionCursor(
	Transaction{
		Id: 40,
		OccurredAt: time.Date(
			2026, 8, 20,
			12, 0, 0, 0,
			time.UTC,
		),
	},
)

func (f *fakeTransactionRepository) Create(
	ctx context.Context,
	userId int64,
	req CreateTransactionRequest,
) (Transaction, error) {
	return Transaction{}, nil
}

func (f *fakeTransactionRepository) ListPageByUserId(
	ctx context.Context,
	userId int64,
	startAt time.Time,
	endAt time.Time,
	cursor *transactionCursor,
	limit int,
) ([]Transaction, error) {
	f.receivedUserId = userId
	f.receivedLimit = limit

	if cursor != nil {
		f.receivedCursor = cursor.Id
	}

	if f.listError != nil {
		return nil, f.listError
	}

	return f.listResult, nil
}

func (f *fakeTransactionRepository) SummaryByUserId(
	ctx context.Context,
	userId int64,
	startAt time.Time,
	endAt time.Time,
) (TransactionSummary, error) {
	f.receivedSummaryUserId = userId

	if f.summaryError != nil {
		return TransactionSummary{}, f.summaryError
	}

	return f.summaryResult, nil
}

func (f *fakeTransactionRepository) Update(
	ctx context.Context,
	userId int64,
	id int64,
	req UpdateTransactionRequest,
) (Transaction, error) {
	return Transaction{}, nil
}

func (f *fakeTransactionRepository) Delete(
	ctx context.Context,
	userId int64,
	id int64,
) error {
	return nil
}

func TestServiceListPageHasMore(t *testing.T) {
	// limit=2 时，Store 会返回 3 条。
	// 第 3 条只用于判断是否还有下一页。
	repository := &fakeTransactionRepository{
		listResult: []Transaction{
			{
				Id: 30,
				OccurredAt: time.Date(
					2026, 8, 18,
					12, 0, 0, 0,
					time.UTC,
				),
			},
			{
				Id: 29,
				OccurredAt: time.Date(
					2026, 8, 18,
					11, 0, 0, 0,
					time.UTC,
				),
			},
			{
				Id: 28,
				OccurredAt: time.Date(
					2026, 8, 17,
					10, 0, 0, 0,
					time.UTC,
				),
			},
		},
	}

	service := NewService(
		repository,
		time.Second,
	)

	page, err := service.ListPage(
		context.Background(),
		7,
		ListTransactionsQuery{
			Cursor:  cursorText,
			Limit:   2,
			StartAt: testStartAt,
			EndAt:   testEndAt,
		},
	)
	if err != nil {
		t.Fatalf("分页查询不应该失败: %v", err)
	}

	// 检查 Service 是否把参数正确传给 Repository。
	if repository.receivedUserId != 7 {
		t.Fatalf(
			"期望 userId 为 7，实际得到 %d",
			repository.receivedUserId,
		)
	}

	if repository.receivedCursor != 40 {
		t.Fatalf(
			"期望 cursor 为 40，实际得到 %d",
			repository.receivedCursor,
		)
	}

	if repository.receivedLimit != 2 {
		t.Fatalf(
			"期望 limit 为 2，实际得到 %d",
			repository.receivedLimit,
		)
	}

	// 返回客户端的 items 只能有 2 条。
	if len(page.Items) != 2 {
		t.Fatalf(
			"期望返回 2 条账单，实际得到 %d",
			len(page.Items),
		)
	}

	if !page.HasMore {
		t.Fatal("返回 3 条、limit 为 2 时，HasMore 应该为 true")
	}

	if page.NextCursor == nil {
		t.Fatal("存在下一页时 NextCursor 不应该为 nil")
	}

	// 返回的最后一条是 ID 29，所以下一页游标应该是 29。
	decodedCursor, err := decodeTransactionCursor(
		*page.NextCursor,
	)
	if err != nil {
		t.Fatalf(
			"NextCursor 应该能够正确解析: %v",
			err,
		)
	}

	if decodedCursor == nil {
		t.Fatal("解析后的 NextCursor 不应该为 nil")
	}

	if decodedCursor.Id != 29 {
		t.Fatalf(
			"期望 NextCursor 中的 ID 为 29，实际得到 %d",
			decodedCursor.Id,
		)
	}
}

func TestServiceListPageLastPageAndDefaultLimit(t *testing.T) {
	repository := &fakeTransactionRepository{
		listResult: []Transaction{
			{
				Id:         30,
				OccurredAt: time.Date(2026, 8, 18, 12, 0, 0, 0, time.UTC),
			},
		},
	}

	service := NewService(
		repository,
		time.Second,
	)

	// Limit 不传时应该使用 DefaultPageSize。
	page, err := service.ListPage(
		context.Background(),
		7,
		ListTransactionsQuery{
			StartAt: testStartAt,
			EndAt:   testEndAt,
		},
	)
	if err != nil {
		t.Fatalf("分页查询不应该失败: %v", err)
	}

	if repository.receivedCursor != 0 {
		t.Fatalf(
			"第一页 cursor 应该为 0，实际得到 %d",
			repository.receivedCursor,
		)
	}

	if repository.receivedLimit != DefaultPageSize {
		t.Fatalf(
			"期望默认 limit 为 %d，实际得到 %d",
			DefaultPageSize,
			repository.receivedLimit,
		)
	}

	if len(page.Items) != 1 {
		t.Fatalf(
			"期望返回 1 条账单，实际得到 %d",
			len(page.Items),
		)
	}

	if page.HasMore {
		t.Fatal("最后一页 HasMore 应该为 false")
	}

	if page.NextCursor != nil {
		t.Fatalf(
			"最后一页 NextCursor 应该为 nil，实际得到 %s",
			*page.NextCursor,
		)
	}
}

func TestServiceListPageReturnsEmptyArray(t *testing.T) {
	repository := &fakeTransactionRepository{
		listResult: nil,
	}

	service := NewService(
		repository,
		time.Second,
	)

	page, err := service.ListPage(
		context.Background(),
		7,
		ListTransactionsQuery{StartAt: testStartAt,
			EndAt: testEndAt},
	)
	if err != nil {
		t.Fatalf("空列表查询不应该失败: %v", err)
	}

	if page.Items == nil {
		t.Fatal("空列表 Items 应该是空切片，不能是 nil")
	}

	if len(page.Items) != 0 {
		t.Fatalf(
			"空列表长度应该为 0，实际得到 %d",
			len(page.Items),
		)
	}

	if page.HasMore {
		t.Fatal("空列表 HasMore 应该为 false")
	}

	if page.NextCursor != nil {
		t.Fatal("空列表 NextCursor 应该为 nil")
	}
}

func TestServiceListPageRepositoryError(t *testing.T) {
	expectedError := errors.New("database unavailable")

	repository := &fakeTransactionRepository{
		listError: expectedError,
	}

	service := NewService(
		repository,
		time.Second,
	)

	_, err := service.ListPage(
		context.Background(),
		7,
		ListTransactionsQuery{StartAt: testStartAt,
			EndAt: testEndAt},
	)

	if !errors.Is(err, expectedError) {
		t.Fatalf(
			"期望得到 Repository 错误，实际得到 %v",
			err,
		)
	}
}

func TestServiceSummary(t *testing.T) {
	repository := &fakeTransactionRepository{
		summaryResult: TransactionSummary{
			Income:  100000,
			Expense: 35000,
		},
	}

	service := NewService(
		repository,
		time.Second,
	)

	summary, err := service.Summary(
		context.Background(),
		7,
		SummaryTransactionsQuery{
			StartAt: testStartAt,
			EndAt:   testEndAt,
		},
	)
	if err != nil {
		t.Fatalf("汇总查询不应该失败: %v", err)
	}

	if repository.receivedSummaryUserId != 7 {
		t.Fatalf(
			"期望 userId 为 7，实际得到 %d",
			repository.receivedSummaryUserId,
		)
	}

	if summary.Income != 100000 {
		t.Fatalf(
			"期望收入为 100000，实际得到 %d",
			summary.Income,
		)
	}

	if summary.Expense != 35000 {
		t.Fatalf(
			"期望支出为 35000，实际得到 %d",
			summary.Expense,
		)
	}

	if summary.Balance != 65000 {
		t.Fatalf(
			"期望结余为 65000，实际得到 %d",
			summary.Balance,
		)
	}
}
