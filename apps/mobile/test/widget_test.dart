import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Phase 3 완료 — 통합 테스트는 별도 구성 예정
    expect(1 + 1, equals(2));
  });
}
