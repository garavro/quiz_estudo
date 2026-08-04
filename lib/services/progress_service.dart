import 'package:supabase_flutter/supabase_flutter.dart';

import 'level_service.dart';

class ProgressService {
  final SupabaseClient _supabase = Supabase.instance.client;

  int? _lerId(dynamic valor) {
    if (valor == null) return null;

    if (valor is int) return valor;

    if (valor is num) return valor.toInt();

    return int.tryParse(valor.toString());
  }

  Future<void> salvarProgressoQuestoes({
    required String usuarioId,
    required String nivelPadrao,
    required List<Map<String, dynamic>> historico,
  }) async {
    for (final item in historico) {
      final questaoId = _lerId(item['questao_id']);

      if (questaoId == null) {
        continue;
      }

      final acertou = item['acertou'] == true;

      final nivelQuestao =
          item['nivel_questao']?.toString() ??
          item['nivel']?.toString() ??
          nivelPadrao;

      await _supabase.from('progresso_questoes').upsert(
        {
          'usuario_id': usuarioId,
          'questao_id': questaoId,
          'nivel': nivelQuestao,
          'acertou': acertou,
          'ultima_resposta_em': DateTime.now().toIso8601String(),
        },
        onConflict: 'usuario_id,questao_id',
      );
    }
  }

  Future<List<int>> buscarQuestoesAcertadas({
    required String usuarioId,
  }) async {
    final response = await _supabase
        .from('progresso_questoes')
        .select('questao_id')
        .eq('usuario_id', usuarioId)
        .eq('acertou', true);

    final dados = List<Map<String, dynamic>>.from(response);

    return dados
        .map((item) => _lerId(item['questao_id']))
        .whereType<int>()
        .toList();
  }

  Future<int> contarAcertosNoNivel({
    required String usuarioId,
    required String nivel,
  }) async {
    final response = await _supabase
        .from('progresso_questoes')
        .select('questao_id')
        .eq('usuario_id', usuarioId)
        .eq('nivel', nivel)
        .eq('acertou', true);

    return List<Map<String, dynamic>>.from(response).length;
  }

  Future<int> contarTotalQuestoesDoNivel({
    required String nivel,
  }) async {
    final response = await _supabase
        .from('quest')
        .select('id')
        .eq('nivel', nivel);

    return List<Map<String, dynamic>>.from(response).length;
  }

  Future<bool> nivelFoiConcluido({
    required String usuarioId,
    required String nivel,
  }) async {
    final total = await contarTotalQuestoesDoNivel(
      nivel: nivel,
    );

    if (total == 0) {
      return false;
    }

    final acertos = await contarAcertosNoNivel(
      usuarioId: usuarioId,
      nivel: nivel,
    );

    return acertos >= total;
  }

  Future<Map<String, String>> calcularNovoNivelETitulo({
    required String usuarioId,
    required String nivelAtual,
  }) async {
    final acertosNoNivel = await contarAcertosNoNivel(
      usuarioId: usuarioId,
      nivel: nivelAtual,
    );

    final titulo = LevelService.tituloPorAcertos(acertosNoNivel);

    final concluiuNivel = await nivelFoiConcluido(
      usuarioId: usuarioId,
      nivel: nivelAtual,
    );

    if (!concluiuNivel) {
      return {
        'nivel': nivelAtual,
        'titulo': titulo,
      };
    }

    final proximoNivel = LevelService.proximoNivel(nivelAtual);

    if (proximoNivel == null) {
      return {
        'nivel': nivelAtual,
        'titulo': titulo,
      };
    }

    return {
      'nivel': proximoNivel,
      'titulo': LevelService.tituloIniciante,
    };
  }
}