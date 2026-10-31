import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app/app/licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('both bundled fonts\' OFL licences are on the licences page', () async {
    registerFontLicenses();

    final entries = await LicenseRegistry.licenses.toList();
    String licenceFor(String font) {
      final entry = entries.firstWhere((e) => e.packages.contains(font));
      return entry.paragraphs.map((p) => p.text).join('\n');
    }

    for (final font in ['Noto Sans', 'Noto Sans Ethiopic']) {
      final text = licenceFor(font);
      expect(text, contains('SIL Open Font License, Version 1.1'));
      expect(text, contains('The Noto Project Authors'));
    }
  });
}
