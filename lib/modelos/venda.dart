class Venda {
  final String? id;
  final double total;
  final double desconto;
  final String formaPagamento;
  final DateTime dataHora;

  Venda({
    this.id,
    required this.total,
    required this.desconto,
    required this.formaPagamento,
    required this.dataHora,
  });

  Map<String, dynamic> toMap() {
    return {
      'total': total,
      'desconto': desconto,
      'formaPagamento': formaPagamento,
      'dataHora': dataHora.toIso8601String(),
    };
  }

  factory Venda.fromMap(Map<String, dynamic> map) {
    return Venda(
      id: map['id'].toString(),
      total: map['total'],
      desconto: map['desconto'],
      formaPagamento: map['formaPagamento'],
      dataHora: DateTime.parse(map['dataHora']),
    );
  }
}
