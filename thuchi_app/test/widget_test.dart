import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thuchi_app/app.dart';

void main() {
  testWidgets('App launches and displays home screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: ThuChiApp(),
      ),
    );

    // Verify the app renders correctly
    expect(find.text('ThuChi'), findsOneWidget);
    expect(find.text('Chào mừng đến ThuChi!'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
