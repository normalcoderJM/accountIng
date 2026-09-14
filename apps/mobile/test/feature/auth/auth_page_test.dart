import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mobile/core/token_storage.dart";
import "package:mobile/feature/auth/auth_api.dart";
import "package:mobile/feature/auth/auth_page.dart";
import "package:mobile/theme/app_theme.dart";
import "package:shared_preferences/shared_preferences.dart";

class FakeAuthGateway implements AuthGateway {
  AuthSession? registerResult;
  Object? registerError;
  String? registeredEmail;
  String? registeredPassword;

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
  }) async {
    registeredEmail = email;
    registeredPassword = password;
    if (registerError != null) {
      throw registerError!;
    }
    return registerResult!;
  }

  @override
  Future<AuthSession> login({required String email, required String password}) {
    throw UnimplementedError();
  }

  @override
  Future<AuthUser> me() {
    throw UnimplementedError();
  }
}

void main() {
  testWidgets("注册成功后应该保存 Token 并通知 AppGate", (tester) async {
    SharedPreferences.setMockInitialValues({});
    final gateway =
        FakeAuthGateway()
          ..registerResult = AuthSession(
            token: "registered-token",
            user: AuthUser(
              id: 7,
              email: "new@example.com",
              createdAt: DateTime.utc(2026, 9, 14),
            ),
          );
    final tokenStorage = TokenStorage();
    var loginSuccessCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AuthPage(
          authApi: gateway,
          tokenStorage: tokenStorage,
          onLoginSuccess: () async {
            loginSuccessCalled = true;
          },
        ),
      ),
    );

    await tester.tap(find.text("注册"));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey("auth-confirm-password-field")),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey("auth-email-field")),
      "  new@example.com  ",
    );
    await tester.enterText(
      find.byKey(const ValueKey("auth-password-field")),
      "password123",
    );
    await tester.enterText(
      find.byKey(const ValueKey("auth-confirm-password-field")),
      "password123",
    );
    final submitButton = find.byKey(const ValueKey("auth-submit-button"));
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(gateway.registeredEmail, "new@example.com");
    expect(gateway.registeredPassword, "password123");
    expect(await tokenStorage.readToken(), "registered-token");
    expect(loginSuccessCalled, isTrue);
  });

  testWidgets("注册时两次密码不一致应该阻止请求", (tester) async {
    SharedPreferences.setMockInitialValues({});
    final gateway = FakeAuthGateway();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AuthPage(
          authApi: gateway,
          tokenStorage: TokenStorage(),
          onLoginSuccess: () async {},
        ),
      ),
    );

    await tester.tap(find.text("注册"));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey("auth-email-field")),
      "new@example.com",
    );
    await tester.enterText(
      find.byKey(const ValueKey("auth-password-field")),
      "password123",
    );
    await tester.enterText(
      find.byKey(const ValueKey("auth-confirm-password-field")),
      "different-password",
    );
    final submitButton = find.byKey(const ValueKey("auth-submit-button"));
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pump();

    expect(find.text("两次输入的密码不一致"), findsOneWidget);
    expect(gateway.registeredEmail, isNull);
  });
}
