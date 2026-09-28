import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../modelos/venda.dart';
import '../provedores/caixa_provedor.dart';

class TelaHistorico extends StatelessWidget {
  const TelaHistorico({super.key});

  Future<void> _confirmarCancelamento(
    BuildContext context,
    CaixaProvedor caixa,
    Venda venda,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar venda?'),
        content: Text(
          'Deseja realmente cancelar a venda #${venda.id}? '
          'O estoque será devolvido quando os itens da venda estiverem registrados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Não'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Sim, cancelar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true || !context.mounted) return;

    try {
      await caixa.cancelarVenda(venda, const []);
    } on StateError catch (erro) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro.message.toString())));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível cancelar a venda.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final caixa = Provider.of<CaixaProvedor>(context);

    double totalVendido = caixa.historicoVendas.fold(
      0.0,
      (soma, v) => soma + v.total,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de Vendas'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.grey[900],
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total de Vendas: ${caixa.historicoVendas.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                Text(
                  'Faturamento: R\$ ${totalVendido.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: caixa.historicoVendas.isEmpty
                ? const Center(
                    child: Text('Nenhuma venda registrada até o momento.'),
                  )
                : ListView.builder(
                    itemCount: caixa.historicoVendas.length,
                    itemBuilder: (context, index) {
                      final venda = caixa.historicoVendas[index];
                      final dataFormatada =
                          '${venda.dataHora.day}/${venda.dataHora.month}/${venda.dataHora.year} às ${venda.dataHora.hour}:${venda.dataHora.minute.toString().padLeft(2, '0')}';

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          leading: const Icon(
                            Icons.receipt_long,
                            color: Colors.black,
                          ),
                          title: Text(
                            'Venda #${venda.id} - R\$ ${venda.total.toStringAsFixed(2)}',
                          ),
                          subtitle: Text(
                            'Pagamento: ${venda.formaPagamento} | $dataFormatada',
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            tooltip: 'Cancelar venda',
                            onPressed: () =>
                                _confirmarCancelamento(context, caixa, venda),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
