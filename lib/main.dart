import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'provedores/caixa_provedor.dart';
import 'telas/tela_caixa.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final caixaProvedor = CaixaProvedor();
  await caixaProvedor.carregarDadosIniciais();

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider.value(value: caixaProvedor)],
      child: const MeuSistemaCaixa(),
    ),
  );
}

class MeuSistemaCaixa extends StatelessWidget {
  const MeuSistemaCaixa({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Caixa de Loja de Roupas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
        useMaterial3: true,
      ),
      home: const TelaCaixa(),
    );
  }
}
