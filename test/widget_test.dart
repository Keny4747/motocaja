import 'package:flutter_test/flutter_test.dart';
import 'package:motocaja/widgets/common.dart';

void main() {
  test('money formats Peruvian soles with two decimals', () {
    expect(money(7), 'S/ 7.00');
    expect(money(7.5), 'S/ 7.50');
  });
}
