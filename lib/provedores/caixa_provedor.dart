import 'package:flutter/material.dart';

import '../modelos/produto.dart';
import '../modelos/venda.dart';
import '../banco/banco_dados.dart';

class ItemCarrinho {
  final Produto produto;
  int quantidade;

  ItemCarrinho({required this.produto, this.quantidade = 1});

  double get valorTotal => produto.preco * quantidade;
}

class CaixaProvedor extends ChangeNotifier {
  final List<ItemCarrinho> _carrinho = [];
  List<Produto> _produtosCadastrados = [];
  List<Venda> _historicoVendas = [];
  double _descontoValor = 0.0;
  double _descontoPorcentagem = 0.0;
  bool _isPorcentagem = false;
  bool _isCaixaAberto = false;
  int? _sessaoCaixaId;
  DateTime? _abertaEm;
  double _valorTrocoInicial = 0.0;
  double _vendasEmDinheiroSessao = 0.0;

  List<ItemCarrinho> get carrinho => _carrinho;
  List<Produto> get produtosCadastrados => _produtosCadastrados;
  List<Venda> get historicoVendas => _historicoVendas;
  bool get isPorcentagem => _isPorcentagem;
  bool get isCaixaAberto => _isCaixaAberto;
  double get valorTrocoInicial => _valorTrocoInicial;
  double get vendasEmDinheiroSessao => _vendasEmDinheiroSessao;
  double get descontoPorcentagem => _descontoPorcentagem;
  double get desconto =>
      _isPorcentagem ? subtotal * (_descontoPorcentagem / 100) : _descontoValor;

  double get subtotal =>
      _carrinho.fold(0.0, (soma, item) => soma + item.valorTotal);
  double get totalFinal =>
      (subtotal - desconto) < 0 ? 0.0 : (subtotal - desconto);

  void aplicarDescontoFixo(double valor) {
    _isPorcentagem = false;
    _descontoValor = valor;
    _descontoPorcentagem = 0.0;
    notifyListeners();
  }

  void aplicarDescontoPorcentagem(double porcentagem) {
    _isPorcentagem = true;
    _descontoPorcentagem = porcentagem;
    _descontoValor = 0.0;
    notifyListeners();
  }

  void removerDesconto() {
    _descontoValor = 0.0;
    _descontoPorcentagem = 0.0;
    _isPorcentagem = false;
    notifyListeners();
  }

  Future<void> carregarDadosIniciais() async {
    _produtosCadastrados = await BancoDados.buscarProdutos();
    _historicoVendas = await BancoDados.buscarVendas();
    if (_abertaEm != null) {
      _vendasEmDinheiroSessao = await BancoDados.buscarVendasEmDinheiroDesde(
        _abertaEm!,
      );
    }
    notifyListeners();
  }

  Future<void> verificarStatusCaixa() async {
    final sessao = await BancoDados.buscarCaixaAbertoHoje();
    _isCaixaAberto = sessao != null;
    _sessaoCaixaId = sessao?['id'] as int?;
    _abertaEm = sessao == null
        ? null
        : DateTime.parse(sessao['abertaEm'] as String);
    _valorTrocoInicial = (sessao?['trocoInicial'] as num?)?.toDouble() ?? 0.0;
    _vendasEmDinheiroSessao = _abertaEm == null
        ? 0.0
        : await BancoDados.buscarVendasEmDinheiroDesde(_abertaEm!);
    notifyListeners();
  }

  Future<void> abrirCaixaDia(double trocoInicial) async {
    if (trocoInicial < 0) {
      throw ArgumentError.value(trocoInicial, 'trocoInicial');
    }
    final sessaoId = await BancoDados.abrirCaixaDia(trocoInicial);
    _isCaixaAberto = true;
    _sessaoCaixaId = sessaoId;
    _abertaEm = DateTime.now();
    _valorTrocoInicial = trocoInicial;
    _vendasEmDinheiroSessao = 0.0;
    notifyListeners();
  }

  Future<void> fecharCaixaDia(double valorFechamento) async {
    final sessaoId = _sessaoCaixaId;
    if (!_isCaixaAberto || sessaoId == null) {
      throw StateError('O caixa não está aberto.');
    }
    await BancoDados.fecharCaixaDia(sessaoId, valorFechamento);
    _isCaixaAberto = false;
    _sessaoCaixaId = null;
    _abertaEm = null;
    _valorTrocoInicial = 0.0;
    _vendasEmDinheiroSessao = 0.0;
    notifyListeners();
  }

  Future<void> cadastrarNovoProduto(Produto produto) async {
    await BancoDados.salvarProduto(produto);
    await carregarDadosIniciais();
  }

  Future<void> excluirProduto(String produtoId) async {
    await BancoDados.excluirProduto(produtoId);
    await carregarDadosIniciais();
  }

  // Salva a venda e atualiza o estoque de cada item vendido.
  Future<void> registrarVenda(String formaPagamento) async {
    if (!_isCaixaAberto) {
      throw StateError('Abra o caixa antes de registrar uma venda.');
    }
    final novaVenda = Venda(
      total: totalFinal,
      desconto: desconto,
      formaPagamento: formaPagamento,
      dataHora: DateTime.now(),
    );

    await BancoDados.salvarVenda(
      novaVenda,
      _carrinho
          .map(
            (item) => <String, Object?>{
              'produtoId': item.produto.id,
              'quantidade': item.quantidade,
            },
          )
          .toList(),
    );
    await carregarDadosIniciais();
  }

  Future<void> cancelarVenda(
    Venda venda,
    List<ItemCarrinho> itensParaRepor,
  ) async {
    final vendaId = int.tryParse(venda.id ?? '');
    if (vendaId == null) {
      throw StateError('Não foi possível identificar a venda.');
    }

    final cancelada = await BancoDados.excluirVenda(
      vendaId,
      itensParaRepor: itensParaRepor
          .map(
            (item) => <String, Object?>{
              'produtoId': item.produto.id,
              'quantidade': item.quantidade,
            },
          )
          .toList(),
    );
    if (!cancelada) {
      throw StateError(
        'Esta venda não possui itens registrados para devolver ao estoque.',
      );
    }
    await carregarDadosIniciais();
  }

  String? adicionarPorCodigoBarras(String codigo) {
    final produto = _produtosCadastrados.firstWhere(
      (p) => p.codigoBarras == codigo,
      orElse: () => Produto(
        id: '',
        nome: '',
        codigoBarras: '',
        preco: 0,
        tamanho: '',
        cor: '',
        quantidadeEstoque: 0,
      ),
    );

    if (produto.id.isEmpty) {
      return 'Produto não encontrado!';
    }

    return adicionarProdutoDireto(produto);
  }

  String? adicionarProdutoDireto(Produto produto) {
    final indice = _carrinho.indexWhere(
      (item) => item.produto.id == produto.id,
    );
    final quantidadeNoCarrinho = indice >= 0 ? _carrinho[indice].quantidade : 0;

    if (quantidadeNoCarrinho + 1 > produto.quantidadeEstoque) {
      return 'Estoque insuficiente! Disponível: ${produto.quantidadeEstoque}';
    }

    if (indice >= 0) {
      _carrinho[indice].quantidade++;
    } else {
      _carrinho.add(ItemCarrinho(produto: produto));
    }
    notifyListeners();
    return null;
  }

  void removerProduto(String produtoId) {
    _carrinho.removeWhere((item) => item.produto.id == produtoId);
    notifyListeners();
  }

  void limparCaixa() {
    _carrinho.clear();
    _descontoValor = 0.0;
    _descontoPorcentagem = 0.0;
    _isPorcentagem = false;
    notifyListeners();
  }
}
