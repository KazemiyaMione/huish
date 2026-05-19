import 'package:flutter_test/flutter_test.dart';
import 'package:cloudora/main.dart';

void main() {
  testWidgets('App loads login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const CloudoraApp());
    expect(find.text('云水'), findsOneWidget);
    expect(find.text('手机号'), findsOneWidget);
  });
}
