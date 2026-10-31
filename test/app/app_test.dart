import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app/app/app.dart';
import 'package:rental_app/app/config_error_app.dart';
import 'package:rental_app/core/config/app_config.dart';

void main() {
  testWidgets('RentalApp shows Hello and the base URL in debug', (
    tester,
  ) async {
    final config = AppConfig.parse('http://localhost:3000');

    await tester.pumpWidget(RentalApp(config: config));

    expect(find.text('Hello'), findsOneWidget);
    // Tests run in debug mode, so the base URL is visible.
    expect(find.text('http://localhost:3000'), findsOneWidget);
  });

  testWidgets('ConfigErrorApp shows the error and how to fix it', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ConfigErrorApp(message: 'API_BASE_URL is missing.'),
    );

    expect(find.text('Configuration error'), findsOneWidget);
    expect(find.text('API_BASE_URL is missing.'), findsOneWidget);
    expect(
      find.text('flutter run --dart-define=API_BASE_URL=http://localhost:3000'),
      findsOneWidget,
    );
    expect(find.text('Hello'), findsNothing);
  });
}
