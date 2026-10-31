import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Registers the bundled fonts' licences (SIL Open Font License 1.1), so they
/// appear on Flutter's licences page (`showLicensePage`) next to the packages'.
/// The OFL requires the licence to travel with the fonts.
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (font, file) in _fontLicenses) {
      yield LicenseEntryWithLineBreaks([
        font,
      ], await rootBundle.loadString(file));
    }
  });
}

const _fontLicenses = [
  ('Noto Sans', 'assets/fonts/NotoSans-OFL.txt'),
  ('Noto Sans Ethiopic', 'assets/fonts/NotoSansEthiopic-OFL.txt'),
];
