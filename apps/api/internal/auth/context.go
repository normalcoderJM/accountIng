package auth

import "github.com/gin-gonic/gin"

// userIdContextKey 登录用户ID在gin Context中使用的key
// 统一放在auth保利 其他业务模块不需要知道具体字符串
const userIDContextKey = "userId"

// userIDContextKey 从请求上下文中获取当前登录ID
// 返回值
// - userId 当前登录用户ID
// - ok 是否成功获取到合法的用户 ID
func UserIDFromContext(c *gin.Context) (userId int64, ok bool) {
	value, exists := c.Get(userIDContextKey)
	if !exists {
		return 0, false
	}
	userId, ok = value.(int64)
	if !ok || userId <= 0 {
		return 0, false
	}
	return userId, true
}
