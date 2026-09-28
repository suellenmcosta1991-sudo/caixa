import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provedores/caixa_provedor.dart';
import '../modelos/produto.dart';
import '../servicos/pdf_servico.dart';
import 'tela_backup.dart';
import 'tela_estoque.dart';
import 'tela_historico.dart';
import 'tela_relatorios.dart';

class TelaCaixa extends StatefulWidget {
  const TelaCaixa({super.key});

  @override
  State<TelaCaixa> createState() => _TelaCaixaState();
}

class _TelaCaixaState extends State<TelaCaixa> {
  TextEditingController? _campoBuscaController;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) return;
      final caixa = Provider.of<CaixaProvedor>(context, listen: false);
      await caixa.carregarDadosIniciais();
      await caixa.verificarStatusCaixa();
      if (!caixa.isCaixaAberto && mounted) {
        _exibirDialogoAberturaCaixa(context, caixa);
      }
    });
  }

  void _exibirDialogoAberturaCaixa(BuildContext context, CaixaProvedor caixa) {
    final valorCtrl = TextEditingController(text: '100.00');

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Abertura de Caixa Diário'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Informe o valor do troco inicial disponível na gaveta:',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: valorCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Valor de Troco Inicial (R\$)',
                prefixText: 'R\$ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final valor =
                  double.tryParse(valorCtrl.text.replaceAll(',', '.')) ?? 0.0;
              if (valor < 0) return;
              await caixa.abrirCaixaDia(valor);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('ABRIR CAIXA'),
          ),
        ],
      ),
    ).whenComplete(valorCtrl.dispose);
  }

  void _exibirDialogoFechamentoCaixa(
    BuildContext context,
    CaixaProvedor caixa,
  ) {
    final totalEsperadoEmDinheiro =
        caixa.valorTrocoInicial + caixa.vendasEmDinheiroSessao;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fechamento de Caixa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Troco Inicial: R\$ '
              '${caixa.valorTrocoInicial.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 8),
            Text(
              'Vendas em dinheiro: R\$ '
              '${caixa.vendasEmDinheiroSessao.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 8),
            Text(
              'Total estimado na gaveta: R\$ '
              '${totalEsperadoEmDinheiro.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await caixa.fecharCaixaDia(totalEsperadoEmDinheiro);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (mounted) _exibirDialogoAberturaCaixa(context, caixa);
            },
            child: const Text(
              'CONFIRMAR FECHAMENTO',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _biparProduto(String codigo, TextEditingController controller) {
    if (codigo.isEmpty) return;

    final caixa = Provider.of<CaixaProvedor>(context, listen: false);
    final erro = caixa.adicionarPorCodigoBarras(codigo);

    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(erro), backgroundColor: Colors.red),
      );
    }
    controller.clear();
  }

  Widget _construirCampoBuscaEBiper(BuildContext context, CaixaProvedor caixa) {
    return Autocomplete<Produto>(
      displayStringForOption: (produto) =>
          '${produto.nome} - ${produto.tamanho}/${produto.cor} '
          '(R\$ ${produto.preco.toStringAsFixed(2)})',
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<Produto>.empty();
        }
        final busca = textEditingValue.text.toLowerCase();
        return caixa.produtosCadastrados.where((produto) {
          return produto.nome.toLowerCase().contains(busca) ||
              produto.codigoBarras.toLowerCase().contains(busca) ||
              produto.tamanho.toLowerCase().contains(busca) ||
              produto.cor.toLowerCase().contains(busca);
        });
      },
      onSelected: (produto) {
        final erro = caixa.adicionarProdutoDireto(produto);
        if (erro != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(erro), backgroundColor: Colors.red),
          );
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _campoBuscaController?.clear();
        });
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        _campoBuscaController = controller;
        return TextField(
          controller: controller,
          focusNode: focusNode,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Bipe o código ou pesquise por Nome, Tamanho ou Cor...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => _biparProduto(value, controller),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: Container(
              width: 500,
              color: Colors.white,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final produto = options.elementAt(index);
                  return ListTile(
                    title: Text(
                      '${produto.nome} - ${produto.tamanho} / ${produto.cor}',
                    ),
                    subtitle: Text(
                      'Cód: ${produto.codigoBarras} | '
                      'Disp: ${produto.quantidadeEstoque} un.',
                    ),
                    trailing: Text(
                      'R\$ ${produto.preco.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onTap: () => onSelected(produto),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _abrirModalCadastro(BuildContext context) {
    final nomeCtrl = TextEditingController();
    final codigoCtrl = TextEditingController();
    final precoCtrl = TextEditingController();
    final tamanhoCtrl = TextEditingController();
    final corCtrl = TextEditingController();
    final estoqueCtrl = TextEditingController(text: '10');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cadastrar Nova Roupa'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeCtrl,
                decoration: const InputDecoration(labelText: 'Nome da Peça'),
              ),
              TextField(
                controller: codigoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Código de Barras',
                ),
              ),
              TextField(
                controller: precoCtrl,
                decoration: const InputDecoration(labelText: 'Preço (R\$)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: tamanhoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tamanho (ex: P, M, 42)',
                ),
              ),
              TextField(
                controller: corCtrl,
                decoration: const InputDecoration(labelText: 'Cor'),
              ),
              TextField(
                controller: estoqueCtrl,
                decoration: const InputDecoration(labelText: 'Estoque Inicial'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final novoProduto = Produto(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                nome: nomeCtrl.text,
                codigoBarras: codigoCtrl.text,
                preco: double.tryParse(precoCtrl.text) ?? 0.0,
                tamanho: tamanhoCtrl.text,
                cor: corCtrl.text,
                quantidadeEstoque: int.tryParse(estoqueCtrl.text) ?? 0,
              );

              Provider.of<CaixaProvedor>(
                context,
                listen: false,
              ).cadastrarNovoProduto(novoProduto);
              Navigator.pop(ctx);
            },
            child: const Text('Salvar no Banco'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final caixa = Provider.of<CaixaProvedor>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Caixa - Loja de Roupas'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              caixa.isCaixaAberto ? Icons.lock_open : Icons.lock,
              color: caixa.isCaixaAberto ? Colors.green : Colors.red,
            ),
            tooltip: caixa.isCaixaAberto ? 'Fechar Caixa' : 'Abrir Caixa',
            onPressed: () {
              if (caixa.isCaixaAberto) {
                if (caixa.carrinho.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Finalize ou limpe o carrinho antes de fechar o caixa.',
                      ),
                    ),
                  );
                  return;
                }
                _exibirDialogoFechamentoCaixa(context, caixa);
              } else {
                _exibirDialogoAberturaCaixa(context, caixa);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.inventory_2),
            tooltip: 'Gerenciar Estoque',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TelaEstoque()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Relatórios',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TelaRelatorios()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Histórico de Vendas',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TelaHistorico()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.cloud_sync),
            tooltip: 'Backup e Restauração',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TelaBackup()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.shopping_bag_outlined),
            tooltip: 'Cadastrar Roupa',
            onPressed: () => _abrirModalCadastro(context),
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _construirCampoBuscaEBiper(context, caixa),
                  const SizedBox(height: 16),
                  Expanded(
                    child: caixa.carrinho.isEmpty
                        ? const Center(child: Text('Carrinho vazio.'))
                        : ListView.builder(
                            itemCount: caixa.carrinho.length,
                            itemBuilder: (context, index) {
                              final item = caixa.carrinho[index];
                              return Card(
                                child: ListTile(
                                  title: Text(
                                    '${item.produto.nome} (${item.produto.tamanho} / ${item.produto.cor})',
                                  ),
                                  subtitle: Text(
                                    'Qtd: ${item.quantidade} x R\$ ${item.produto.preco.toStringAsFixed(2)} | Estoque disp.: ${item.produto.quantidadeEstoque}',
                                  ),
                                  trailing: Text(
                                    'R\$ ${item.valorTotal.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  leading: IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () =>
                                        caixa.removerProduto(item.produto.id),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.grey[200],
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Resumo da Compra',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const Divider(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal:', style: TextStyle(fontSize: 16)),
                      Text(
                        'R\$ ${caixa.subtotal.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Desconto:',
                            style: TextStyle(fontSize: 16, color: Colors.red),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.edit_note,
                              color: Colors.blue,
                            ),
                            tooltip: 'Aplicar ou Alterar Desconto',
                            onPressed: () =>
                                _exibirDialogoDesconto(context, caixa),
                          ),
                        ],
                      ),
                      Text(
                        '- R\$ ${caixa.desconto.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total:', style: TextStyle(fontSize: 20)),
                      Text(
                        'R\$ ${caixa.totalFinal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                    ),
                    onPressed: caixa.carrinho.isEmpty || !caixa.isCaixaAberto
                        ? null
                        : () => _exibirDialogoPagamento(context, caixa),
                    child: const Text(
                      'FINALIZAR VENDA',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _exibirDialogoDesconto(BuildContext context, CaixaProvedor caixa) {
    final valorCtrl = TextEditingController(
      text: caixa.isPorcentagem
          ? caixa.descontoPorcentagem.toStringAsFixed(0)
          : caixa.desconto.toStringAsFixed(2),
    );
    var porPorcentagem = caixa.isPorcentagem;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateModal) => AlertDialog(
          title: const Text('Aplicar Desconto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('R\$ (Valor Fixo)'),
                    selected: !porPorcentagem,
                    onSelected: (selected) {
                      if (selected) {
                        setStateModal(() => porPorcentagem = false);
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('% (Porcentagem)'),
                    selected: porPorcentagem,
                    onSelected: (selected) {
                      if (selected) {
                        setStateModal(() => porPorcentagem = true);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: valorCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: porPorcentagem
                      ? 'Porcentagem de Desconto (%)'
                      : 'Valor do Desconto (R\$)',
                  prefixText: porPorcentagem ? '' : 'R\$ ',
                  suffixText: porPorcentagem ? '%' : '',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                caixa.removerDesconto();
                Navigator.pop(ctx);
              },
              child: const Text(
                'Remover Desconto',
                style: TextStyle(color: Colors.red),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final valorInput =
                    double.tryParse(valorCtrl.text.replaceAll(',', '.')) ?? 0.0;
                if (porPorcentagem) {
                  caixa.aplicarDescontoPorcentagem(valorInput);
                } else {
                  caixa.aplicarDescontoFixo(valorInput);
                }
                Navigator.pop(ctx);
              },
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    ).whenComplete(valorCtrl.dispose);
  }

  void _exibirDialogoPagamento(BuildContext context, CaixaProvedor caixa) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Forma de Pagamento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.pix, color: Colors.teal),
              title: const Text('PIX'),
              onTap: () => _finalizarEGravar(context, caixa, 'PIX'),
            ),
            ListTile(
              leading: const Icon(Icons.credit_card, color: Colors.blue),
              title: const Text('Cartão'),
              onTap: () => _finalizarEGravar(context, caixa, 'Cartão'),
            ),
            ListTile(
              leading: const Icon(Icons.attach_money, color: Colors.green),
              title: const Text('Dinheiro'),
              onTap: () => _finalizarEGravar(context, caixa, 'Dinheiro'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _finalizarEGravar(
    BuildContext context,
    CaixaProvedor caixa,
    String formaPagamento,
  ) async {
    final itensVenda = List<ItemCarrinho>.from(caixa.carrinho);
    final subtotal = caixa.subtotal;
    final desconto = caixa.desconto;
    final total = caixa.totalFinal;

    Navigator.pop(context);

    // Registra a venda no banco de dados SQLite
    await caixa.registrarVenda(formaPagamento);
    caixa.limparCaixa();

    // Imprime o comprovante
    await PdfServico.imprimirComprovante(
      itens: itensVenda,
      subtotal: subtotal,
      desconto: desconto,
      total: total,
      formaPagamento: formaPagamento,
    );
  }
}
