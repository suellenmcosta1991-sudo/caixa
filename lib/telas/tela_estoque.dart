import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../modelos/produto.dart';
import '../provedores/caixa_provedor.dart';

class TelaEstoque extends StatelessWidget {
  const TelaEstoque({super.key});

  void _alterarQuantidade(
    BuildContext context,
    Produto produto,
    int alteracao,
  ) {
    final novaQuantidade = produto.quantidadeEstoque + alteracao;
    if (novaQuantidade < 0) return;

    produto.quantidadeEstoque = novaQuantidade;
    Provider.of<CaixaProvedor>(
      context,
      listen: false,
    ).cadastrarNovoProduto(produto);
  }

  void _abrirModalEditarEstoque(BuildContext context, Produto produto) {
    final controller = TextEditingController(
      text: produto.quantidadeEstoque.toString(),
    );

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Ajustar Estoque - ${produto.nome}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Nova Quantidade em Estoque',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final quantidade =
                  int.tryParse(controller.text) ?? produto.quantidadeEstoque;
              if (quantidade < 0) return;

              produto.quantidadeEstoque = quantidade;
              Provider.of<CaixaProvedor>(
                context,
                listen: false,
              ).cadastrarNovoProduto(produto);
              Navigator.pop(ctx);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  void _abrirModalEditarProduto(BuildContext context, Produto produto) {
    final formKey = GlobalKey<FormState>();
    final nomeController = TextEditingController(text: produto.nome);
    final codigoController = TextEditingController(text: produto.codigoBarras);
    final precoController = TextEditingController(
      text: produto.preco.toStringAsFixed(2),
    );
    final tamanhoController = TextEditingController(text: produto.tamanho);
    final corController = TextEditingController(text: produto.cor);
    final quantidadeController = TextEditingController(
      text: produto.quantidadeEstoque.toString(),
    );

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Editar cadastro da roupa'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nomeController,
                    decoration: const InputDecoration(labelText: 'Nome'),
                    validator: (valor) => valor == null || valor.trim().isEmpty
                        ? 'Informe o nome da roupa.'
                        : null,
                  ),
                  TextFormField(
                    controller: codigoController,
                    decoration: const InputDecoration(
                      labelText: 'Código de barras',
                    ),
                  ),
                  TextFormField(
                    controller: precoController,
                    decoration: const InputDecoration(
                      labelText: 'Preço (R\$)',
                      prefixText: 'R\$ ',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (valor) {
                      final preco = double.tryParse(
                        (valor ?? '').trim().replaceAll(',', '.'),
                      );
                      if (preco == null || preco < 0) {
                        return 'Informe um preço válido.';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: tamanhoController,
                    decoration: const InputDecoration(labelText: 'Tamanho'),
                  ),
                  TextFormField(
                    controller: corController,
                    decoration: const InputDecoration(labelText: 'Cor'),
                  ),
                  TextFormField(
                    controller: quantidadeController,
                    decoration: const InputDecoration(
                      labelText: 'Quantidade em estoque',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (valor) {
                      final quantidade = int.tryParse((valor ?? '').trim());
                      if (quantidade == null || quantidade < 0) {
                        return 'Informe uma quantidade válida.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final produtoAtualizado = Produto(
                id: produto.id,
                nome: nomeController.text.trim(),
                codigoBarras: codigoController.text.trim(),
                preco: double.parse(
                  precoController.text.trim().replaceAll(',', '.'),
                ),
                tamanho: tamanhoController.text.trim(),
                cor: corController.text.trim(),
                quantidadeEstoque: int.parse(quantidadeController.text.trim()),
              );

              await Provider.of<CaixaProvedor>(
                context,
                listen: false,
              ).cadastrarNovoProduto(produtoAtualizado);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Salvar alterações'),
          ),
        ],
      ),
    ).whenComplete(() {
      nomeController.dispose();
      codigoController.dispose();
      precoController.dispose();
      tamanhoController.dispose();
      corController.dispose();
      quantidadeController.dispose();
    });
  }

  Future<void> _confirmarExclusao(BuildContext context, Produto produto) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Apagar cadastro?'),
        content: Text(
          '“${produto.nome}” deixará de aparecer no estoque e não poderá '
          'ser vendido. O histórico de vendas será preservado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Apagar cadastro'),
          ),
        ],
      ),
    );
    if (confirmar != true || !context.mounted) return;

    try {
      await context.read<CaixaProvedor>().excluirProduto(produto.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cadastro removido do estoque.')),
      );
    } catch (erro) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível apagar o cadastro: $erro')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final produtos = Provider.of<CaixaProvedor>(context).produtosCadastrados;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciamento de Estoque'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: produtos.isEmpty
          ? const Center(child: Text('Nenhum produto cadastrado.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: produtos.length,
              itemBuilder: (context, index) {
                final produto = produtos[index];
                final semEstoque = produto.quantidadeEstoque == 0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${produto.nome} (${produto.tamanho} / ${produto.cor})',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cód. Barras: ${produto.codigoBarras} | '
                                'R\$ ${produto.preco.toStringAsFixed(2)}',
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Estoque: ${produto.quantidadeEstoque} un.',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: semEstoque
                                      ? Colors.red
                                      : Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Wrap(
                          alignment: WrapAlignment.end,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Editar'),
                              onPressed: () =>
                                  _abrirModalEditarProduto(context, produto),
                            ),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Apagar'),
                              onPressed: () =>
                                  _confirmarExclusao(context, produto),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: Colors.red,
                              ),
                              tooltip: 'Diminuir estoque',
                              onPressed: () =>
                                  _alterarQuantidade(context, produto, -1),
                            ),
                            InkWell(
                              onTap: () =>
                                  _abrirModalEditarEstoque(context, produto),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${produto.quantidadeEstoque}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.add_circle_outline,
                                color: Colors.green,
                              ),
                              tooltip: 'Aumentar estoque',
                              onPressed: () =>
                                  _alterarQuantidade(context, produto, 1),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
