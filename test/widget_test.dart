import 'package:flutter_test/flutter_test.dart';

import 'package:rately_farms/main.dart';

void main() {
  testWidgets('Rately Farms authentication screen opens', (WidgetTester tester) async {
    await tester.pumpWidget(const RatelyFarmsApp());
    await tester.pump();

    expect(find.text('Rately Farms'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}
