import 'package:flutter_test/flutter_test.dart';
import 'package:whale_ledger/ui/common.dart';

void main() {
  test('金额格式化保留千分位', () {
    expect(fmtMoney(1234.5), '1,234.50');
    expect(fmtMoney(0), '0.00');
    expect(fmtMoney(-20), '-20.00');
    expect(fmtAmount(1200), '1,200');
  });
}
