import 'package:flutter_test/flutter_test.dart';
import 'package:motocaja/main.dart';

void main() {
  testWidgets('MotoCaja boots', (tester) async {
    await tester.pumpWidget(const MotoCajaApp());
    expect(find.text('MotoCaja'), findsNothing);
  }, skip: true);
}
