import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:hai/main.dart'; // Đảm bảo đúng đường dẫn tới file main.dart

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(); // 🔧 Khởi tạo Firebase trong test
  });

  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MamApp());

    // Kiểm tra có hiển thị 0 không
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Bấm nút "+"
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Kiểm tra đã tăng thành 1
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
