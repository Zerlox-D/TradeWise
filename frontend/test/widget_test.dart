import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/main.dart';

void main() {
  testWidgets('TradeWise app boots', (WidgetTester tester) async {
    await tester.pumpWidget(const TradeWiseApp());
    expect(find.byType(TradeWiseApp), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
