class Produto {
  final String id;
  final String nome;
  final String codigoBarras;
  final double preco;
  final String tamanho; // P, M, G, GG, 38, 40...
  final String cor;
  int quantidadeEstoque;
  final bool ativo;

  Produto({
    required this.id,
    required this.nome,
    required this.codigoBarras,
    required this.preco,
    required this.tamanho,
    required this.cor,
    required this.quantidadeEstoque,
    this.ativo = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'codigoBarras': codigoBarras,
      'preco': preco,
      'tamanho': tamanho,
      'cor': cor,
      'quantidadeEstoque': quantidadeEstoque,
      'ativo': ativo ? 1 : 0,
    };
  }

  factory Produto.fromMap(Map<String, dynamic> map) {
    return Produto(
      id: map['id'],
      nome: map['nome'],
      codigoBarras: map['codigoBarras'],
      preco: map['preco'],
      tamanho: map['tamanho'],
      cor: map['cor'],
      quantidadeEstoque: map['quantidadeEstoque'] ?? 0,
      ativo: map['ativo'] == null || (map['ativo'] as num).toInt() != 0,
    );
  }
}
