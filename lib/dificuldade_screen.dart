import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'jogar_screen.dart';
import 'services/level_service.dart';
import 'services/question_service.dart';
import 'widgets/app_button.dart';
import 'widgets/loading_overlay.dart';

class DificuldadeScreen extends StatefulWidget {
  final String serieSelecionada;
  final String? nivelSelecionado;

  const DificuldadeScreen({
    super.key,
    required this.serieSelecionada,
    this.nivelSelecionado,
  });

  @override
  State<DificuldadeScreen> createState() => _DificuldadeScreenState();
}

class _DificuldadeScreenState extends State<DificuldadeScreen> {
  final QuestionService _questionService = QuestionService();

  bool _carregando = false;

  static const List<Map<String, dynamic>> _dificuldades = [
    {
      'texto': 'Fácil',
      'valor': 'facil',
      'icone': Icons.sentiment_satisfied_alt_rounded,
    },
    {
      'texto': 'Médio',
      'valor': 'medio',
      'icone': Icons.psychology_alt_rounded,
    },
    {
      'texto': 'Difícil',
      'valor': 'dificil',
      'icone': Icons.local_fire_department_rounded,
    },
  ];

  String get _nivelEfetivo {
    if (widget.nivelSelecionado != null &&
        widget.nivelSelecionado!.trim().isNotEmpty) {
      return widget.nivelSelecionado!;
    }

    switch (widget.serieSelecionada) {
      case '4 e 5 ano':
        return LevelService.nivel1;
      case '6 e 7 ano':
        return LevelService.nivel2;
      case '8 e 9 ano':
        return LevelService.nivel3;
      case 'Ensino Medio':
      default:
        return LevelService.nivel4;
    }
  }

  Future<void> _buscarQuestoes(String dificuldade) async {
    setState(() => _carregando = true);

    try {
      final usuario = Supabase.instance.client.auth.currentUser;

      if (usuario == null) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Faça login novamente para jogar.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      final questoes = await _questionService.buscarQuestoesParaRodada(
        usuarioId: usuario.id,
        nivelAtual: _nivelEfetivo,
        dificuldade: dificuldade,
      );

      if (!mounted) return;

      if (questoes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Nenhuma questão disponível nesta dificuldade. Tente outra opção.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => JogarScreen(
            questoes: questoes,
            dificuldade: dificuldade,
            nivelAtual: _nivelEfetivo,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao carregar questões. Tente novamente.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  String _nomeDificuldade(String dificuldade) {
    switch (dificuldade) {
      case 'facil':
        return 'Fácil';
      case 'medio':
        return 'Médio';
      case 'dificil':
        return 'Difícil';
      default:
        return dificuldade;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final nivelNome = LevelService.nomeNivel(_nivelEfetivo);

    return LoadingOverlay(
      carregando: _carregando,
      mensagem: 'Buscando questões...',
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Dificuldade'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(30),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 500,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.extension_rounded,
                      size: 72,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Escolha a dificuldade',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$nivelNome • ${widget.serieSelecionada}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Questões já acertadas não serão repetidas.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                    const SizedBox(height: 35),
                    ..._dificuldades.map((dificuldade) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: AppButton(
                          texto: _nomeDificuldade(dificuldade['valor']),
                          altura: 64,
                          icone: dificuldade['icone'],
                          onPressed: _carregando
                              ? null
                              : () {
                                  _buscarQuestoes(dificuldade['valor']);
                                },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}