import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

import '../modelos/produto.dart';
import '../modelos/relatorio.dart';
import '../modelos/venda.dart';

class BancoDados {
  static Database? _db;

  static Future<String> caminhoArquivoBanco() async =>
      join(await getDatabasesPath(), 'caixa_loja.db');

  static Future<void> fecharConexao() async {
    final db = _db;
    _db = null;
    if (db != null && db.isOpen) await db.close();
  }

  static Future<void> validarArquivoBackup(String caminho) async {
    await getInstancia();
    final dbTemporario = await databaseFactory.openDatabase(
      caminho,
      options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
    );
    try {
      final integridade = await dbTemporario.rawQuery('PRAGMA quick_check');
      if (integridade.isEmpty || integridade.first.values.first != 'ok') {
        throw const FormatException('O arquivo de backup está corrompido.');
      }

      final tabelas = await dbTemporario.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final nomes = tabelas.map((tabela) => tabela['name']).toSet();
      if (!nomes.contains('produtos') || !nomes.contains('vendas')) {
        throw const FormatException(
          'O arquivo selecionado não contém um backup válido do caixa.',
        );
      }
    } finally {
      await dbTemporario.close();
    }
  }

  static Future<Database> getInstancia() async {
    if (_db != null) return _db!;

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final caminho = await caminhoArquivoBanco();

    _db = await openDatabase(
      caminho,
      version: 6,
      onCreate: (db, version) async {
        await _criarTabelas(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS vendas(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              total REAL,
              desconto REAL,
              formaPagamento TEXT,
              dataHora TEXT
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE produtos ADD COLUMN quantidadeEstoque INTEGER NOT NULL DEFAULT 10',
          );
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS venda_itens(
              vendaId INTEGER NOT NULL,
              produtoId TEXT NOT NULL,
              quantidade INTEGER NOT NULL,
              PRIMARY KEY (vendaId, produtoId)
            )
          ''');
        }
        if (oldVersion < 5) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS caixa_sessoes(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              data TEXT NOT NULL,
              abertaEm TEXT NOT NULL,
              fechadaEm TEXT,
              trocoInicial REAL NOT NULL,
              valorFechamento REAL
            )
          ''');
        }
        if (oldVersion < 6) {
          await db.execute(
            'ALTER TABLE produtos ADD COLUMN ativo INTEGER NOT NULL DEFAULT 1',
          );
        }
      },
    );

    return _db!;
  }

  static Future<void> _criarTabelas(Database db) async {
    await db.execute('''
      CREATE TABLE produtos(
        id TEXT PRIMARY KEY,
        nome TEXT,
        codigoBarras TEXT,
        preco REAL,
        tamanho TEXT,
        cor TEXT,
        quantidadeEstoque INTEGER NOT NULL DEFAULT 10,
        ativo INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE vendas(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        total REAL,
        desconto REAL,
        formaPagamento TEXT,
        dataHora TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE venda_itens(
        vendaId INTEGER NOT NULL,
        produtoId TEXT NOT NULL,
        quantidade INTEGER NOT NULL,
        PRIMARY KEY (vendaId, produtoId)
      )
    ''');

    await db.execute('''
      CREATE TABLE caixa_sessoes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        data TEXT NOT NULL,
        abertaEm TEXT NOT NULL,
        fechadaEm TEXT,
        trocoInicial REAL NOT NULL,
        valorFechamento REAL
      )
    ''');

    await db.insert('produtos', {
      'id': '1',
      'nome': 'Camiseta Oversized Algodão',
      'codigoBarras': '7891001',
      'preco': 89.90,
      'tamanho': 'G',
      'cor': 'Preto',
      'quantidadeEstoque': 10,
    });
  }

  static Future<Map<String, Object?>?> buscarCaixaAbertoHoje() async {
    final db = await getInstancia();
    final hoje = DateTime.now().toIso8601String().split('T').first;
    final sessoes = await db.query(
      'caixa_sessoes',
      where: 'data = ? AND fechadaEm IS NULL',
      whereArgs: [hoje],
      orderBy: 'id DESC',
      limit: 1,
    );
    return sessoes.isEmpty ? null : sessoes.first;
  }

  static Future<int> abrirCaixaDia(double trocoInicial) async {
    final db = await getInstancia();
    final agora = DateTime.now();
    return db.insert('caixa_sessoes', {
      'data': agora.toIso8601String().split('T').first,
      'abertaEm': agora.toIso8601String(),
      'trocoInicial': trocoInicial,
    });
  }

  static Future<double> buscarVendasEmDinheiroDesde(DateTime abertura) async {
    final db = await getInstancia();
    final resultado = await db.rawQuery(
      '''
      SELECT SUM(total) as total
      FROM vendas
      WHERE formaPagamento = ? AND dataHora >= ?
      ''',
      ['Dinheiro', abertura.toIso8601String()],
    );
    return (resultado.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  static Future<void> fecharCaixaDia(
    int sessaoId,
    double valorFechamento,
  ) async {
    final db = await getInstancia();
    final quantidadeAtualizada = await db.update(
      'caixa_sessoes',
      {
        'fechadaEm': DateTime.now().toIso8601String(),
        'valorFechamento': valorFechamento,
      },
      where: 'id = ? AND fechadaEm IS NULL',
      whereArgs: [sessaoId],
    );
    if (quantidadeAtualizada == 0) {
      throw StateError('O caixa não está aberto.');
    }
  }

  static Future<List<Produto>> buscarProdutos() async {
    final db = await getInstancia();
    final List<Map<String, dynamic>> maps = await db.query(
      'produtos',
      where: 'ativo = ?',
      whereArgs: [1],
    );
    return maps.map(Produto.fromMap).toList();
  }

  static Future<void> salvarProduto(Produto produto) async {
    final db = await getInstancia();
    await db.insert(
      'produtos',
      produto.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> excluirProduto(String produtoId) async {
    final db = await getInstancia();
    final quantidadeAtualizada = await db.update(
      'produtos',
      {'ativo': 0},
      where: 'id = ? AND ativo = 1',
      whereArgs: [produtoId],
    );
    if (quantidadeAtualizada == 0) {
      throw StateError('O cadastro não foi encontrado ou já foi removido.');
    }
  }

  static Future<void> darBaixaEstoque(
    String produtoId,
    int quantidadeVendida,
  ) async {
    final db = await getInstancia();
    await db.rawUpdate(
      '''
      UPDATE produtos
      SET quantidadeEstoque = quantidadeEstoque - ?
      WHERE id = ?
      ''',
      [quantidadeVendida, produtoId],
    );
  }

  // Registra uma nova venda concluída
  static Future<int> salvarVenda(
    Venda venda,
    List<Map<String, Object?>> itens,
  ) async {
    final db = await getInstancia();
    return db.transaction((txn) async {
      final vendaId = await txn.insert('vendas', venda.toMap());
      for (final item in itens) {
        await txn.insert('venda_itens', {
          'vendaId': vendaId,
          'produtoId': item['produtoId'],
          'quantidade': item['quantidade'],
        });
        await txn.rawUpdate(
          '''
          UPDATE produtos
          SET quantidadeEstoque = quantidadeEstoque - ?
          WHERE id = ?
          ''',
          [item['quantidade'], item['produtoId']],
        );
      }
      return vendaId;
    });
  }

  static Future<bool> excluirVenda(
    int vendaId, {
    List<Map<String, Object?>> itensParaRepor = const [],
  }) async {
    final db = await getInstancia();
    return db.transaction((txn) async {
      final vendas = await txn.query(
        'vendas',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [vendaId],
      );
      if (vendas.isEmpty) return false;

      final itensSalvos = await txn.query(
        'venda_itens',
        where: 'vendaId = ?',
        whereArgs: [vendaId],
      );
      final itens = itensSalvos.isNotEmpty ? itensSalvos : itensParaRepor;
      if (itens.isEmpty) return false;

      for (final item in itens) {
        await txn.rawUpdate(
          '''
          UPDATE produtos
          SET quantidadeEstoque = quantidadeEstoque + ?
          WHERE id = ?
          ''',
          [item['quantidade'], item['produtoId']],
        );
      }

      await txn.delete(
        'venda_itens',
        where: 'vendaId = ?',
        whereArgs: [vendaId],
      );
      await txn.delete('vendas', where: 'id = ?', whereArgs: [vendaId]);
      return true;
    });
  }

  // Busca todo o histórico de vendas
  static Future<List<Venda>> buscarVendas() async {
    final db = await getInstancia();
    final List<Map<String, dynamic>> maps = await db.query(
      'vendas',
      orderBy: 'id DESC',
    );
    return List.generate(maps.length, (i) => Venda.fromMap(maps[i]));
  }

  static Future<double> buscarTotalFaturado() async {
    final db = await getInstancia();
    final resultado = await db.rawQuery(
      'SELECT SUM(total) as total FROM vendas',
    );
    return (resultado.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  static Future<List<TotalPorPagamento>> buscarTotaisPorPagamento() async {
    final db = await getInstancia();
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT formaPagamento, SUM(total) as total
      FROM vendas
      GROUP BY formaPagamento
    ''');

    return maps
        .map(
          (map) => TotalPorPagamento(
            formaPagamento: map['formaPagamento'] ?? 'Outros',
            total: (map['total'] as num?)?.toDouble() ?? 0.0,
          ),
        )
        .toList();
  }
}
