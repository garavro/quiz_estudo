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
    final dificuldadeOriginal = _lerTexto(questao['dificuldade']);

    final dificuldadeEfetiva = LevelService.dificuldadeEfetiva(
      nivelAtual: nivelAtual,
      nivelQuestao: nivelQuestao,
      dificuldadeOriginal: dificuldadeOriginal,
    );

    return dificuldadeEfetiva == dificuldadeEscolhida;
  }

  // NOVO: Função para determinar qual é o próximo nível do aluno (Regra 3)
  String? _obterProximoNivel(String nivelAtual) {
    if (nivelAtual == 'nivel_1') return 'nivel_2';
    if (nivelAtual == 'nivel_2') return 'nivel_3';
    if (nivelAtual == 'nivel_3') return 'nivel_4';
    return null; // O Nível 4 é o limite, não há nível acima
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
    // 1. Níveis normais permitidos (ex: nivelAtual e inferiores)
    final niveisPermitidos = LevelService.niveisPermitidosAte(nivelAtual).toList();
    
    // 2. Adicionamos o próximo nível na busca inicial do banco (para termos as questões prontas caso o aluno precise avançar)
    final proximoNivel = _obterProximoNivel(nivelAtual);
    final niveisParaBusca = List<String>.from(niveisPermitidos);
    
    if (proximoNivel != null && !niveisParaBusca.contains(proximoNivel)) {
      niveisParaBusca.add(proximoNivel);
    }

    // 3. Busca o histórico de acertos para não repetir questões
    final questoesAcertadas = await _progressService.buscarQuestoesAcertadas(
      usuarioId: usuarioId,
    );
    final idsAcertadas = questoesAcertadas.toSet();

    // 4. Busca as questões na base de dados
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
        .filter('nivel', 'in', _filtroInTexto(niveisParaBusca));

    final todasQuestoes = List<Map<String, dynamic>>.from(response);

    // 5. Remove todas as questões que o aluno já acertou
    final questoesNaoRespondidas = todasQuestoes.where((q) {
      final id = q['id'];
      final idInt = id is int ? id : int.tryParse(id.toString());
      return idInt != null && !idsAcertadas.contains(idInt);
    }).toList();

    List<Map<String, dynamic>> questoesDisponiveis = [];

    // ==============================================================
    // 6. LÓGICA DE PROGRESSÃO GRADATIVA (Regras 1, 2, 3 e 4)
    // ==============================================================
    
    // A progressão para o próximo nível só acontece quando o aluno pede a dificuldade "Difícil" (Regra 4)
    if (dificuldade == 'dificil') {
      
      // Passo A: Tenta achar questões difíceis normais do nível atual do aluno
      questoesDisponiveis = questoesNaoRespondidas.where((q) {
        if (!niveisPermitidos.contains(q['nivel'])) return false;
        return _questaoCompativelComDificuldade(
          questao: q,
          nivelAtual: nivelAtual,
          dificuldadeEscolhida: 'dificil',
        );
      }).toList();

      // Passo B: Se a lista estiver vazia (esgotou as difíceis do nível atual), tenta o Próximo Nível (Regras 1 e 3)
      if (questoesDisponiveis.isEmpty && proximoNivel != null) {
        
        // Primeiro, libera as Fáceis do próximo nível
        questoesDisponiveis = questoesNaoRespondidas.where((q) => 
          q['nivel'] == proximoNivel && q['dificuldade'] == 'facil'
        ).toList();

        // Se já esgotou as Fáceis do próximo nível, libera as Medianas (Regra 2)
        if (questoesDisponiveis.isEmpty) {
          questoesDisponiveis = questoesNaoRespondidas.where((q) => 
            q['nivel'] == proximoNivel && q['dificuldade'] == 'medio'
          ).toList();
        }

        // Se já esgotou as Medianas do próximo nível, libera as Difíceis
        if (questoesDisponiveis.isEmpty) {
          questoesDisponiveis = questoesNaoRespondidas.where((q) => 
            q['nivel'] == proximoNivel && q['dificuldade'] == 'dificil'
          ).toList();
        }
      }
      
    } else {
      // Se ele escolheu Fácil ou Médio, mantém a regra original (apenas do nível atual ou inferior)
      questoesDisponiveis = questoesNaoRespondidas.where((q) {
        if (!niveisPermitidos.contains(q['nivel'])) return false;
        return _questaoCompativelComDificuldade(
          questao: q,
          nivelAtual: nivelAtual,
          dificuldadeEscolhida: dificuldade,
        );
      }).toList();
    }

    // 7. Embaralha e devolve 5 questões
    questoesDisponiveis.shuffle();

    return questoesDisponiveis.take(questoesPorPartida).toList();
  }
}