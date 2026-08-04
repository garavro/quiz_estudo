class ScoreService {
  static int multiplicadorPorDificuldade(String dificuldade) {
    switch (dificuldade) {
      case 'medio':
        return 2;
      case 'dificil':
        return 3;
      case 'facil':
      default:
        return 1;
    }
  }

  static int calcularBonusRodada({
    required int acertos,
    required int totalQuestoes,
  }) {
    if (totalQuestoes == 0) return 0;

    return acertos == totalQuestoes ? 1 : 0;
  }

  static int calcularPontuacaoRodada({
    required int acertos,
    required int erros,
    required int totalQuestoes,
    required int bonusSequencia,
    required String dificuldade,
  }) {
    final bonusRodada = calcularBonusRodada(
      acertos: acertos,
      totalQuestoes: totalQuestoes,
    );

    final base = acertos - erros + bonusRodada + bonusSequencia;

    final multiplicador = multiplicadorPorDificuldade(dificuldade);

    final total = base * multiplicador;

    return total < 0 ? 0 : total;
  }
}