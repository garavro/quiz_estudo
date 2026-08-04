import 'package:supabase_flutter/supabase_flutter.dart';

import 'level_service.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<AuthResponse> login({
    required String email,
    required String senha,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email.trim(),
      password: senha,
    );
  }

  Future<AuthResponse> cadastrar({
    required String email,
    required String senha,
    required String nome,
    required String dataNascimento,
    required String serieEscolar,
  }) async {
    final nivelInicial = LevelService.nivelPorSerieEscolar(serieEscolar);

    return await _supabase.auth.signUp(
      email: email.trim(),
      password: senha,
      data: {
        'nome_completo': nome,
        'data_nascimento': dataNascimento,
        'serie_escolar': serieEscolar,
        'nivel_atual': nivelInicial,
        'titulo_atual': LevelService.tituloIniciante,
      },
    );
  }

  Future<void> recuperarSenha(String email) async {
    await _supabase.auth.resetPasswordForEmail(
      email.trim(),
    );
  }

  Future<void> enviarEmailRecuperacao(String email) async {
    await _supabase.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: 'quizestudo://recuperar-senha',
    );
  }

  Future<void> atualizarSenha(String novaSenha) async {
    await _supabase.auth.updateUser(
      UserAttributes(
        password: novaSenha,
      ),
    );
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  Future<Map<String, dynamic>?> buscarPerfilAtual() async {
    final usuario = _supabase.auth.currentUser;

    if (usuario == null) {
      return null;
    }

    final response = await _supabase
        .from('perfis')
        .select(
          '''
          id,
          nome_completo,
          data_nascimento,
          serie_escolar,
          pontuacao_total,
          nivel_atual,
          titulo_atual
          ''',
        )
        .eq('id', usuario.id)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return Map<String, dynamic>.from(response);
  }

  Future<String?> buscarSerieEscolarAtual() async {
    final perfil = await buscarPerfilAtual();

    return perfil?['serie_escolar']?.toString();
  }

  Future<String?> buscarNivelAtual() async {
    final perfil = await buscarPerfilAtual();

    return perfil?['nivel_atual']?.toString();
  }

  Future<void> atualizarSerieEscolar({
    required String serieEscolar,
  }) async {
    final usuario = _supabase.auth.currentUser;

    if (usuario == null) {
      throw Exception('Usuário não autenticado.');
    }

    final novoNivel = LevelService.nivelPorSerieEscolar(serieEscolar);

    await _supabase
        .from('perfis')
        .update({
          'serie_escolar': serieEscolar,
          'nivel_atual': novoNivel,
          'titulo_atual': LevelService.tituloIniciante,
        })
        .eq('id', usuario.id);
  }

  Future<void> atualizarNivelETitulo({
    required String nivelAtual,
    required String tituloAtual,
  }) async {
    final usuario = _supabase.auth.currentUser;

    if (usuario == null) {
      throw Exception('Usuário não autenticado.');
    }

    await _supabase
        .from('perfis')
        .update({
          'nivel_atual': nivelAtual,
          'titulo_atual': tituloAtual,
        })
        .eq('id', usuario.id);
  }

  User? get usuarioAtual => _supabase.auth.currentUser;

  Session? get sessaoAtual => _supabase.auth.currentSession;
}