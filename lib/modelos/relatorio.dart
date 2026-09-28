class ProdutoMaisVendido {
  final String nome;
  final String tamanho;
  final String cor;
  final int quantidadeVendida;

  ProdutoMaisVendido({
    required this.nome,
    required this.tamanho,
    required this.cor,
    required this.quantidadeVendida,
  });
}

class TotalPorPagamento {
  final String formaPagamento;
  final double total;

  TotalPorPagamento({required this.formaPagamento, required this.total});
}
