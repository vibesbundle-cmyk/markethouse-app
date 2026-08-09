import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:markethouse/screens/demand.dart';
import 'package:markethouse/screens/shop.dart';
import 'package:markethouse/theme/dark.dart';
import 'package:markethouse/theme/state.dart';

Widget _wrap(Widget child) => MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DarkProvider()),
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: MaterialApp(home: child),
    );

void main() {
  testWidgets('SupplyPage renders its form', (tester) async {
    await tester.pumpWidget(_wrap(const SupplyPage()));
    await tester.pumpAndSettle();
    expect(find.text('Post a Supply'), findsOneWidget);
    expect(find.text('List Item'), findsOneWidget);
    expect(find.text('Add photo'), findsOneWidget);
  });

  testWidgets('DemandPage renders its form', (tester) async {
    await tester.pumpWidget(_wrap(const DemandPage()));
    await tester.pumpAndSettle();
    expect(find.text('Post a Demand'), findsOneWidget);
    expect(find.text('Post Demand'), findsOneWidget);
  });

  testWidgets('Shop renders with supply/demand tabs', (tester) async {
    await tester.pumpWidget(_wrap(const Shop()));
    await tester.pumpAndSettle();
    expect(find.text('Shop'), findsOneWidget);
    expect(find.text('Supplies'), findsOneWidget);
    expect(find.text('Demands'), findsOneWidget);
    expect(find.text('Products'), findsOneWidget);
  });
}
