package transactions

import (
	"errors"
	"fmt"
	"strconv"
	"strings"
	"time"
)

var (
	ErrInvalidTransactionCursor = errors.New("invalid transaction cursor")
	ErrInvalidTransactionPeriod = errors.New("invalid transaction period")
)

// transactionCursor 后端内部使用的游标结构
type transactionCursor struct {
	OccurredAt time.Time
	Id         int64
}

func encodeTransactionCursor(transaction Transaction) string {
	return fmt.Sprintf("%s_%d", transaction.OccurredAt.UTC().Format(time.RFC3339Nano), transaction.Id)
}

// 解析前端返回的时间参数
func decodeTransactionCursor(raw string) (*transactionCursor, error) {
	if raw == "" {
		return nil, nil
	}
	separatorIndex := strings.LastIndexByte(raw, '_')
	if separatorIndex <= 0 || separatorIndex == len(raw)-1 {
		return nil, ErrInvalidTransactionCursor
	}

	occurredAtText := raw[:separatorIndex]
	idText := raw[separatorIndex+1:]

	occrredAt, err := time.Parse(time.RFC3339Nano, occurredAtText)
	if err != nil {
		return nil, ErrInvalidTransactionCursor
	}
	id, err := strconv.ParseInt(idText, 10, 64)
	if err != nil || id <= 0 {
		return nil, ErrInvalidTransactionCursor
	}

	return &transactionCursor{
		OccurredAt: occrredAt,
		Id:         id,
	}, nil

}

// 校验时间格式 开始时间 结束时间 && 结束时间是否大于开始时间
func validateTransactionPeriod(startAt time.Time, endAt time.Time) error {
	if startAt.IsZero() || endAt.IsZero() || !startAt.Before((endAt)) {
		return ErrInvalidTransactionPeriod
	}
	return nil
}
