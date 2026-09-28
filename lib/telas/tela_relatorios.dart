import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../banco/banco_dados.dart';
import '../modelos/relatorio.dart';
import '../provedores/caixa_provedor.dart';
import '../servicos/pdf_servico.dart';

class TelaRelatorios extends StatefulWidget {
  const TelaRelatorios({super.key});

  @override
  State<TelaRelatorios> createState() => _TelaRelatoriosState();
}

class _TelaRelatoriosState extends State<TelaRelatorios> {
  double _totalFaturado = 0.0;
  List<TotalPorPagamento> _totaisPagamento = [];
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    try {
      final total = await BancoDados.buscarTotalFaturado();
      final pagamentos = await BancoDados.buscarTotaisPorPagamento();
      if (!mounted) return;

      setState(() {
        _totalFaturado = total;
        _totaisPagamento = pagamentos;
        _carregando = false;
        _erro = null;
      });
    } catch (erro) {
      if (!mounted) return;

      setState(() {
        _erro = 'Não foi possível carregar os relatórios.';
        _carregando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final caixa = context.watch<CaixaProvedor>();
    final totalVendas = caixa.historicoVendas.length;
    final ticketMedio = totalVendas > 0 ? _totalFaturado / totalVendas : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatórios de Vendas'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Exportar/Imprimir PDF',
            onPressed: () {
              PdfServico.imprimirRelatorioVendas(
                caixa.historicoVendas,
                _totalFaturado,
              );
            },
          ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _erro != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_erro!),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _carregando = true);
                      _carregarDados();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tentar novamente'),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'Resumo Geral',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final colunas = constraints.maxWidth >= 900
                          ? 3
                          : constraints.maxWidth >= 560
                          ? 2
                          : 1;
                      final largura =
                          (constraints.maxWidth - (colunas - 1) * 12) / colunas;

                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: largura,
                            child: _cardMetrica(
                              'Total Faturado',
                              'R\$ ${_totalFaturado.toStringAsFixed(2)}',
                              Icons.attach_money,
                              Colors.green,
                            ),
                          ),
                          SizedBox(
                            width: largura,
                            child: _cardMetrica(
                              'Total de Vendas',
                              '$totalVendas',
                              Icons.shopping_bag_outlined,
                              Colors.blue,
                            ),
                          ),
                          SizedBox(
                            width: largura,
                            child: _cardMetrica(
                              'Ticket Médio',
                              'R\$ ${ticketMedio.toStringAsFixed(2)}',
                              Icons.analytics_outlined,
                              Colors.orange,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Faturamento por Forma de Pagamento',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _totaisPagamento.isEmpty
                      ? const Text('Nenhuma venda registrada.')
                      : Card(
                          child: Column(
                            children: _totaisPagamento.map((pagamento) {
                              return ListTile(
                                leading: Icon(
                                  _iconePagamento(pagamento.formaPagamento),
                                  color: Colors.teal,
                                ),
                                title: Text(pagamento.formaPagamento),
                                trailing: Text(
                                  'R\$ ${pagamento.total.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                ],
              ),
            ),
    );
  }

  IconData _iconePagamento(String formaPagamento) {
    return switch (formaPagamento) {
      'PIX' => Icons.pix,
      'Cartão' => Icons.credit_card,
      'Dinheiro' => Icons.payments_outlined,
      _ => Icons.receipt_long,
    };
  }

  Widget _cardMetrica(String titulo, String valor, IconData icone, Color cor) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    titulo,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
                Icon(icone, color: cor, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              valor,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
