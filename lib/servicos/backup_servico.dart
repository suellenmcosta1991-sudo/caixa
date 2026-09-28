import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart';

import '../banco/banco_dados.dart';

class BackupServico {
  static Future<String?> exportarBackup() async {
    try {
      final pastaDestino = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Selecione a pasta para salvar o Backup',
      );
      if (pastaDestino == null) return 'Operação cancelada.';

      final caminhoOriginal = await BancoDados.caminhoArquivoBanco();
      final db = await BancoDados.getInstancia();
      await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
      await BancoDados.fecharConexao();

      final arquivoOriginal = File(caminhoOriginal);
      if (!await arquivoOriginal.exists()) {
        return 'Banco de dados não encontrado.';
      }

      final agora = DateTime.now();
      final dataFormatada =
          '${agora.year}${_doisDigitos(agora.month)}${_doisDigitos(agora.day)}_'
          '${_doisDigitos(agora.hour)}${_doisDigitos(agora.minute)}'
          '${_doisDigitos(agora.second)}';
      final destino = join(pastaDestino, 'backup_caixa_loja_$dataFormatada.db');

      await arquivoOriginal.copy(destino);
      return null;
    } catch (erro) {
      return 'Erro ao exportar backup: $erro';
    }
  }

  static Future<String?> importarBackup() async {
    File? arquivoTemporario;
    File? copiaAnterior;
    try {
      final resultado = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['db'],
        dialogTitle: 'Selecione o arquivo de backup (.db)',
      );
      if (resultado == null || resultado.files.single.path == null) {
        return 'Nenhum arquivo selecionado.';
      }

      final caminhoOriginal = await BancoDados.caminhoArquivoBanco();
      arquivoTemporario = File('$caminhoOriginal.importando');
      await File(resultado.files.single.path!).copy(arquivoTemporario.path);
      await BancoDados.validarArquivoBackup(arquivoTemporario.path);

      await BancoDados.fecharConexao();
      final arquivoOriginal = File(caminhoOriginal);
      copiaAnterior = File('$caminhoOriginal.anterior');
      if (await arquivoOriginal.exists()) {
        await arquivoOriginal.copy(copiaAnterior.path);
      }
      await _removerSeExistir(File('$caminhoOriginal-wal'));
      await _removerSeExistir(File('$caminhoOriginal-shm'));
      await _removerSeExistir(File('$caminhoOriginal-journal'));

      try {
        await arquivoTemporario.copy(caminhoOriginal);
      } catch (_) {
        if (await copiaAnterior.exists()) {
          await copiaAnterior.copy(caminhoOriginal);
        }
        rethrow;
      }

      return null;
    } catch (erro) {
      return 'Erro ao importar backup: $erro';
    } finally {
      if (arquivoTemporario != null && await arquivoTemporario.exists()) {
        await arquivoTemporario.delete();
      }
      if (copiaAnterior != null && await copiaAnterior.exists()) {
        await copiaAnterior.delete();
      }
    }
  }

  static Future<void> _removerSeExistir(File arquivo) async {
    if (await arquivo.exists()) await arquivo.delete();
  }

  static String _doisDigitos(int valor) => valor.toString().padLeft(2, '0');
}
