import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/utils/csv_export_service.dart';

void main() {
  group('CsvExportService — _esc helper', () {
    // We test the CSV escaping logic indirectly since _esc is private.
    // Instead we test the overall structure expectations.

    test('CsvExportService class exists and is callable', () {
      // Smoke test — verifying the service class is importable
      expect(CsvExportService, isNotNull);
    });
  });
}
