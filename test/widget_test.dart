// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:sistema_caixa_roupas/main.dart';
import 'package:sistema_caixa_roupas/provedores/caixa_provedor.dart';

void main() {
  testWidgets('mostra a tela inicial do caixa', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => CaixaProvedor(),
        child: const MeuSistemaCaixa(),
      ),
    );

    expect(find.text('Caixa - Loja de Roupas'), findsOneWidget);
    expect(find.text('Nenhum item no carrinho.'), findsOneWidget);
    expect(find.text('R\$ 0.00'), findsNWidgets(2));
  });
}
