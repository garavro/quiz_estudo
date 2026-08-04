import 'package:supabase_flutter/supabase_flutter.dart';

class RankingService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<dynamic>> buscarTop10() async {
    return await _supabase
        .from('perfis')
        .select(
          '''
          nome_completo,
          pontuacao_total,
          serie_escolar,
          nivel_atual,
          titulo_atual
          ''',
        )
        .order('pontuacao_total', ascending: false)
        .limit(10);
  }

  Future<List<dynamic>> buscarTop10PorNivel({
    required String nivel,
  }) async {
    return await _supabase
        .from('perfis')
        .select(
          '''
          nome_completo,
          pontuacao_total,
          serie_escolar,
          nivel_atual,
          titulo_atual
          ''',
        )
        .eq('nivel_atual', nivel)
        .order('pontuacao_total', ascending: false)
        .limit(10);
  }

  Future<List<dynamic>> buscarTop10PorSeries({
    required List<String> series,
  }) async {
    final filtroSeries = '(${series.map((s) => '"$s"').join(',')})';

    return await _supabase
        .from('perfis')
        .select(
          '''
          nome_completo,
          pontuacao_total,
          serie_escolar,
          nivel_atual,
          titulo_atual
          ''',
        )
        .filter('serie_escolar', 'in', filtroSeries)
        .order('pontuacao_total', ascending: false)
        .limit(10);
  }

  Future<void> atualizarPontuacao({
    required String usuarioId,
    required int pontosGanhos,
  }) async {
    await _supabase.rpc(
      'adicionar_pontos',
      params: {
        'p_usuario_id': usuarioId,
        'p_pontos': pontosGanhos,
      },
    );
  }
}