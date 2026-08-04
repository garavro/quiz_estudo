import 'package:supabase_flutter/supabase_flutter.dart';

import 'level_service.dart';
import 'progress_service.dart';

class QuestionService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ProgressService _progressService = ProgressService();

  static const int questoesPorPartida = 5;

  String _filtroInTexto(List<String> valores) {
    return '(${valores.map((valor) => '"$valor"').join(',')})';
  }

  String _lerTexto(dynamic valor) {
    if (valor == null) return '';

    return valor.toString();
  }

  bool _questaoCompativelComDificuldade({
    required Map<String, dynamic> questao,
    required String nivelAtual,
    required String dificuldadeEscolhida,
  }) {
    final nivelQuestao = _lerTexto(questao['nivel']);

    final dificuldadeOriginal = _lerTexto(
      questao['dificuldade'],
    );

    final dificuldadeEfetiva = LevelService.dificuldadeEfetiva(
      nivelAtual: nivelAtual,
      nivelQuestao: nivelQuestao,
      dificuldadeOriginal: dificuldadeOriginal,
    );

    return dificuldadeEfetiva == dificuldadeEscolhida;
  }

  Future<List<dynamic>> buscarQuestoes({
    required String serie,
    required String dificuldade,
  }) async {
    final response = await _supabase
        .from('quest')
        .select(
          '''
          id,
          pergunta,
          imagem_url,
          alternativa_correta,
          alternativa_errada1,
          alternativa_errada2,
          alternativa_errada3,
          alternativa_errada4,
          serie,
          dificuldade,
          nivel
          ''',
        )
        .eq('serie', serie)
        .eq('dificuldade', dificuldade);

    final questoes = List<dynamic>.from(response);

    questoes.shuffle();

    return questoes.take(questoesPorPartida).toList();
  }

  Future<List<dynamic>> buscarQuestoesParaRodada({
    required String usuarioId,
    required String nivelAtual,
    required String dificuldade,
  }) async {
    final niveisPermitidos = LevelService.niveisPermitidosAte(
      nivelAtual,
    );

    final questoesAcertadas =
        await _progressService.buscarQuestoesAcertadas(
      usuarioId: usuarioId,
    );

    final idsAcertadas = questoesAcertadas.toSet();

    final response = await _supabase
        .from('quest')
        .select(
          '''
          id,
          pergunta,
          imagem_url,
          alternativa_correta,
          alternativa_errada1,
          alternativa_errada2,
          alternativa_errada3,
          alternativa_errada4,
          serie,
          dificuldade,
          nivel
          ''',
        )
        .filter(
          'nivel',
          'in',
          _filtroInTexto(niveisPermitidos),
        );

    final todasQuestoes = List<Map<String, dynamic>>.from(response);

    final questoesDisponiveis = todasQuestoes.where((questao) {
      final id = questao['id'];

      final idInt = id is int ? id : int.tryParse(id.toString());

      if (idInt != null && idsAcertadas.contains(idInt)) {
        return false;
      }

      return _questaoCompativelComDificuldade(
        questao: questao,
        nivelAtual: nivelAtual,
        dificuldadeEscolhida: dificuldade,
      );
    }).toList();

    questoesDisponiveis.shuffle();

    return questoesDisponiveis.take(questoesPorPartida).toList();
  }
}