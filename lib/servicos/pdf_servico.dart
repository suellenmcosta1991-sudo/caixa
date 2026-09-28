import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../provedores/caixa_provedor.dart';
import '../modelos/venda.dart';

class PdfServico {
  static Future<void> imprimirComprovante({
    required List<ItemCarrinho> itens,
    required double subtotal,
    required double desconto,
    required double total,
    required String formaPagamento,
  }) async {
    final pdf = pw.Document();
    final dataVenda = DateTime.now();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text(
                'LOJA DE ROUPAS',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            pw.Center(
              child: pw.Text(
                'Comprovante Não Fiscal',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Data: ${dataVenda.day}/${dataVenda.month}/${dataVenda.year} '
              '${dataVenda.hour}:${dataVenda.minute.toString().padLeft(2, '0')}',
              style: const pw.TextStyle(fontSize: 8),
            ),
            pw.Divider(thickness: 0.5),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    'Item',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 8,
                    ),
                  ),
                ),
                pw.Text(
                  'Qtd',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 8,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Text(
                  'Total',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 8,
                  ),
                ),
              ],
            ),
            pw.Divider(thickness: 0.5),
            ...itens.map(
              (item) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        '${item.produto.nome}\n'
                        '(${item.produto.tamanho}/${item.produto.cor})',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    ),
                    pw.Text(
                      '${item.quantidade}x',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Text(
                      'R\$ ${item.valorTotal.toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ],
                ),
              ),
            ),
            pw.Divider(thickness: 0.5),
            _linhaTotal('Subtotal:', subtotal),
            if (desconto > 0)
              _linhaTotal('Desconto:', desconto, prefixo: '- R\$ '),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'TOTAL:',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                pw.Text(
                  'R\$ ${total.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Pagamento:', style: const pw.TextStyle(fontSize: 8)),
                pw.Text(formaPagamento, style: const pw.TextStyle(fontSize: 8)),
              ],
            ),
            pw.Divider(thickness: 0.5),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                'Obrigado pela preferência!',
                style: pw.TextStyle(
                  fontStyle: pw.FontStyle.italic,
                  fontSize: 9,
                ),
              ),
            ),
            pw.Center(
              child: pw.Text(
                'Trocas somente com este comprovante.',
                style: const pw.TextStyle(fontSize: 7),
              ),
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) => pdf.save(),
      name: 'Comprovante-Venda',
    );
  }

  static Future<void> imprimirRelatorioVendas(
    List<Venda> vendas,
    double totalFaturado,
  ) async {
    final pdf = pw.Document();
    final dataGeracao = DateTime.now();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => pw.Header(
          level: 0,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(
                  'Relatório de Vendas - Loja de Roupas',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Text(_formatarData(dataGeracao)),
            ],
          ),
        ),
        build: (context) => [
          pw.Text('Total de Vendas Realizadas: ${vendas.length}'),
          pw.Text(
            'Faturamento Total: R\$ ${totalFaturado.toStringAsFixed(2)}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: [
              'ID Venda',
              'Data / Hora',
              'Forma Pagamento',
              'Desconto',
              'Total',
            ],
            data: vendas
                .map(
                  (venda) => [
                    '#${venda.id ?? '-'}',
                    _formatarDataHora(venda.dataHora),
                    venda.formaPagamento,
                    'R\$ ${venda.desconto.toStringAsFixed(2)}',
                    'R\$ ${venda.total.toStringAsFixed(2)}',
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) => pdf.save(),
      name: 'Relatorio-de-Vendas',
    );
  }

  static pw.Widget _linhaTotal(
    String titulo,
    double valor, {
    String prefixo = 'R\$ ',
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(titulo, style: const pw.TextStyle(fontSize: 9)),
        pw.Text(
          '$prefixo${valor.toStringAsFixed(2)}',
          style: const pw.TextStyle(fontSize: 9),
        ),
      ],
    );
  }

  static String _formatarData(DateTime data) =>
      '${data.day}/${data.month}/${data.year}';

  static String _formatarDataHora(DateTime data) =>
      '${_formatarData(data)} ${data.hour}:'
      '${data.minute.toString().padLeft(2, '0')}';
}
