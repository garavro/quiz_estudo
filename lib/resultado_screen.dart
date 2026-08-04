import 'package:flutter/material.dart';

import 'services/level_service.dart';
import 'widgets/app_button.dart';
import 'widgets/math_text.dart';

class ResultadoScreen extends StatelessWidget {
  final int certas;
  final int erradas;
  final List<Map<String, dynamic>> historico;

  final int pontosRodada;
  final int multiplicador;
  final int bonusRodada;
  final int bonusSequencia;
  final int maiorSequencia;

  final String nivelAnterior;
  final String nivelAtual;
  final String tituloAtual;
  final bool houveAvancoNivel;

  const ResultadoScreen({
    super.key,
    required this.certas,
    required this.erradas,
    required this.historico,
    required this.pontosRodada,
    required this.multiplicador,
    required this.bonusRodada,
    required this.bonusSequencia,
    required this.maiorSequencia,
    required this.nivelAnterior,
    required this.nivelAtual,
    required this.tituloAtual,
    required this.houveAvancoNivel,
  });

  int get totalQuestoes => certas + erradas;

  double get aproveitamento {
    if (totalQuestoes == 0) return 0;
    return certas / totalQuestoes;
  }

  String get aproveitamentoFormatado {
    return '${(aproveitamento * 100).toStringAsFixed(1)}%';
  }

  Color _corDesempenho() {
    if (aproveitamento >= 0.75) {
      return Colors.green;
    }

    if (aproveitamento >= 0.5) {
      return Colors.orange;
    }

    return Colors.red;
  }

  String _mensagemDesempenho() {
    if (totalQuestoes == 0) {
      return 'Nenhuma questão respondida.';
    }

    if (aproveitamento >= 0.85) {
      return 'Excelente desempenho!';
    }

    if (aproveitamento >= 0.7) {
      return 'Muito bom! Continue praticando.';
    }

    if (aproveitamento >= 0.5) {
      return 'Bom resultado, mas ainda dá para melhorar.';
    }

    return 'Continue estudando e tente novamente.';
  }

  void _voltarAoMenu(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Widget _cardResumo(BuildContext context) {
    final cor = _corDesempenho();

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(
              aproveitamento >= 0.7
                  ? Icons.emoji_events_rounded
                  : Icons.school_rounded,
              size: 70,
              color: cor,
            ),
            const SizedBox(height: 12),
            Text(
              aproveitamentoFormatado,
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.bold,
                color: cor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'de aproveitamento',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: LinearProgressIndicator(
                value: aproveitamento,
                minHeight: 12,
                backgroundColor: Colors.grey.shade300,
                color: cor,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _mensagemDesempenho(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              'Pontuação da rodada: $pontosRodada pontos',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Multiplicador: x$multiplicador | Bônus final: +$bonusRodada | Bônus sequência: +$bonusSequencia',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Maior sequência: $maiorSequencia acertos seguidos',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 18),
            _cardNivel(context),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _miniCardPontuacao(
                    titulo: 'Acertos',
                    valor: certas,
                    cor: Colors.green,
                    icone: Icons.check_circle_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _miniCardPontuacao(
                    titulo: 'Erros',
                    valor: erradas,
                    cor: Colors.red,
                    icone: Icons.cancel_rounded,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardNivel(BuildContext context) {
    final nivelNome = LevelService.nomeNivel(nivelAtual);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        children: [
          Text(
            houveAvancoNivel
                ? 'Parabéns! Você avançou de nível.'
                : 'Status atual',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blueAccent,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$nivelNome • $tituloAtual',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _miniCardPontuacao({
    required String titulo,
    required int valor,
    required Color cor,
    required IconData icone,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: cor.withValues(alpha: 0.30),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icone,
            color: cor,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            '$valor',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: cor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            titulo,
            style: TextStyle(
              fontSize: 14,
              color: cor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardQuestao(
    BuildContext context,
    Map<String, dynamic> item,
    int index,
  ) {
    final bool acertou = item['acertou'] == true;

    final pergunta = item['pergunta']?.toString() ?? '';
    final respostaUsuario = item['resposta_usuario']?.toString() ?? '';
    final respostaCorreta = item['resposta_correta']?.toString() ?? '';

    final cor = acertou ? Colors.green : Colors.red;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: cor,
          width: 1.6,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  acertou ? Icons.check_circle : Icons.cancel,
                  color: cor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Questão ${index + 1}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: cor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    acertou ? 'Acertou' : 'Errou',
                    style: TextStyle(
                      color: cor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(),
            const SizedBox(height: 8),
            MathText(
              pergunta,
              fontSize: 16,
              corTexto: Theme.of(context).colorScheme.onSurface,
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 18),
            Text(
              'Sua resposta:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            MathText(
              respostaUsuario,
              fontSize: 16,
              corTexto: cor,
              fontWeight: FontWeight.w600,
            ),
            if (!acertou) ...[
              const SizedBox(height: 14),
              Text(
                'Resposta correta:',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              MathText(
                respostaCorreta,
                fontSize: 16,
                corTexto: Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _historicoQuestoes(BuildContext context) {
    if (historico.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Text(
            'Nenhuma questão foi respondida.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Revisão das questões',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 14),
        ...historico.asMap().entries.map(
              (entry) => _cardQuestao(
                context,
                entry.value,
                entry.key,
              ),
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Desempenho Final'),
          centerTitle: true,
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 760,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _cardResumo(context),
                          const SizedBox(height: 24),
                          _historicoQuestoes(context),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: AppButton(
                    texto: 'VOLTAR AO MENU INICIAL',
                    icone: Icons.home_rounded,
                    onPressed: () => _voltarAoMenu(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}