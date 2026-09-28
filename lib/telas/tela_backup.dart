import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provedores/caixa_provedor.dart';
import '../servicos/backup_servico.dart';

class TelaBackup extends StatefulWidget {
  const TelaBackup({super.key});

  @override
  State<TelaBackup> createState() => _TelaBackupState();
}

class _TelaBackupState extends State<TelaBackup> {
  bool _processando = false;

  Future<void> _fazerBackup() async {
    setState(() => _processando = true);
    try {
      final erro = await BackupServico.exportarBackup();
      if (!mounted) return;
      if (erro == null) {
        _mostrarMensagem('Backup exportado com sucesso!');
      } else if (erro != 'Operação cancelada.') {
        _mostrarMensagem(erro, erro: true);
      }
    } catch (erro) {
      if (mounted) {
        _mostrarMensagem('Erro ao exportar backup: $erro', erro: true);
      }
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  Future<void> _restaurarBackup() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Restaurar backup?'),
        content: const Text(
          'Os dados atuais serão substituídos pelos dados do arquivo '
          'selecionado. Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(contexto).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    setState(() => _processando = true);
    try {
      final erro = await BackupServico.importarBackup();
      if (!mounted) return;

      if (erro == null) {
        final caixa = context.read<CaixaProvedor>();
        caixa.limparCaixa();
        await caixa.carregarDadosIniciais();
        await caixa.verificarStatusCaixa();
        if (!mounted) return;
        _mostrarMensagem('Backup restaurado com sucesso!');
      } else if (erro != 'Nenhum arquivo selecionado.') {
        _mostrarMensagem(erro, erro: true);
      }
    } catch (erro) {
      if (mounted) {
        _mostrarMensagem('Erro ao restaurar backup: $erro', erro: true);
      }
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  void _mostrarMensagem(String mensagem, {bool erro = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: erro ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup e Restauração'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: _processando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.cloud_upload_outlined,
                      color: Colors.blue,
                      size: 32,
                    ),
                    title: const Text(
                      'Exportar backup',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Salva produtos, vendas e estoque em um arquivo .db.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _fazerBackup,
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.settings_backup_restore,
                      color: Colors.deepOrange,
                      size: 32,
                    ),
                    title: const Text(
                      'Restaurar backup',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Substitui os dados atuais por um arquivo .db salvo.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _restaurarBackup,
                  ),
                ),
              ],
            ),
    );
  }
}
