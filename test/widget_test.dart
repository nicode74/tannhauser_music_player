import 'package:flutter_test/flutter_test.dart';
import 'package:tannhauser_music_player/main.dart';

void main() {
  testWidgets('TannhauserApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TannhauserApp());
    expect(find.text('Tannhäuser Bit-Perfect Player'), findsOneWidget);
  });
}
