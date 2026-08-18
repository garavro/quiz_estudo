class LevelService {
  static const String nivel1 = 'nivel_1';
  static const String nivel2 = 'nivel_2';
  static const String nivel3 = 'nivel_3';
  static const String nivel4 = 'nivel_4';

  static const String tituloIniciante = 'Iniciante';
  static const String tituloHabilitado = 'Habilitado';
  static const String tituloVeterano = 'Veterano';
  static const String tituloLenda = 'Lenda';

  static const List<String> seriesEscolares = [
    '4º ano do Ensino Fundamental',
    '5º ano do Ensino Fundamental',
    '6º ano do Ensino Fundamental',
    '7º ano do Ensino Fundamental',
    '8º ano do Ensino Fundamental',
    '9º ano do Ensino Fundamental',
    '1º ano do Ensino Médio',
    '2º ano do Ensino Médio',
    '3º ano do Ensino Médio',
    'Graduado',
    'Pós-graduado',
  ];

 static String nivelPorSerieEscolar(String? serieEscolar) {
  if (serieEscolar == '4º ano do Ensino Fundamental' ||
      serieEscolar == '5º ano do Ensino Fundamental') {
    return nivel1;
  }

  if (serieEscolar == '6º ano do Ensino Fundamental' ||
      serieEscolar == '7º ano do Ensino Fundamental') {
    return nivel2;
  }

  if (serieEscolar == '8º ano do Ensino Fundamental' ||
      serieEscolar == '9º ano do Ensino Fundamental') {
    return nivel3;
  }

  if (serieEscolar == '1º ano do Ensino Médio' ||
      serieEscolar == '2º ano do Ensino Médio' ||
      serieEscolar == '3º ano do Ensino Médio' ||
      serieEscolar == 'Graduado' ||
      serieEscolar == 'Pós-graduado') {
    return nivel4;
  }

  return nivel1;
}
   

  static String categoriaPorNivel(String nivel) {
    switch (nivel) {
      case nivel1:
        return '4 e 5 ano';
      case nivel2:
        return '6 e 7 ano';
      case nivel3:
        return '8 e 9 ano';
      case nivel4:
      default:
        return 'Ensino Medio';
    }
  }

  static String nomeNivel(String nivel) {
    switch (nivel) {
      case nivel1:
        return 'Nível I';
      case nivel2:
        return 'Nível II';
      case nivel3:
        return 'Nível III';
      case nivel4:
        return 'Nível IV';
      default:
        return 'Nível I';
    }
  }

  static int ordemNivel(String nivel) {
    switch (nivel) {
      case nivel1:
        return 1;
      case nivel2:
        return 2;
      case nivel3:
        return 3;
      case nivel4:
        return 4;
      default:
        return 1;
    }
  }

  static List<String> niveisPermitidosAte(String nivelAtual) {
    final ordem = ordemNivel(nivelAtual);

    final niveis = <String>[];

    if (ordem >= 1) niveis.add(nivel1);
    if (ordem >= 2) niveis.add(nivel2);
    if (ordem >= 3) niveis.add(nivel3);
    if (ordem >= 4) niveis.add(nivel4);

    return niveis;
  }

  static String? proximoNivel(String nivelAtual) {
    switch (nivelAtual) {
      case nivel1:
        return nivel2;
      case nivel2:
        return nivel3;
      case nivel3:
        return nivel4;
      case nivel4:
      default:
        return null;
    }
  }

  static String tituloPorAcertos(int acertosNoNivel) {
    if (acertosNoNivel >= 100) {
      return tituloLenda;
    }

    if (acertosNoNivel >= 50) {
      return tituloVeterano;
    }

    if (acertosNoNivel >= 25) {
      return tituloHabilitado;
    }

    return tituloIniciante;
  }

  static String dificuldadeEfetiva({
    required String nivelAtual,
    required String nivelQuestao,
    required String dificuldadeOriginal,
  }) {
    final ordemAtual = ordemNivel(nivelAtual);
    final ordemQuestao = ordemNivel(nivelQuestao);

    if (ordemQuestao >= ordemAtual) {
      return dificuldadeOriginal;
    }

    switch (nivelQuestao) {
      case nivel1:
        return 'facil';
      case nivel2:
        return 'medio';
      case nivel3:
        return 'dificil';
      default:
        return dificuldadeOriginal;
    }
  }
}
