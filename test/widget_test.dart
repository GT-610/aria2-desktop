import 'package:flutter_test/flutter_test.dart';

import 'package:setsuna/app.dart';

void main() {
  testWidgets('App can be created', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(MyApp), findsOneWidget);
  });
}
