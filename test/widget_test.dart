import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jalplay/app.dart';
import 'package:jalplay/services/audio_handler.dart';

void main() {
  testWidgets('JALPlay smoke test', (WidgetTester tester) async {
    final handler = JalPlayAudioHandler();
    await tester.pumpWidget(JalPlayApp(handler: handler));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
