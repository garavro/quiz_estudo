import 'package:flutter/material.dart';

import 'dificuldade_screen.dart';
import 'widgets/app_button.dart';

class SerieScreen extends StatelessWidget {
  const SerieScreen({super.key});

  static const List<Map<String, String>> _series = [
    {'texto': '4º e 5º ano', 'valor': '4 e 5 ano'},
    {'texto': '6º e 7º ano', 'valor': '6 e 7 ano'},
    {'texto': '8º e 9º ano', 'valor': '8 e 9 ano'},
    {'texto': 'Ensino Médio', 'valor': 'Ensino Medio'},
  ];

  void _abrirDificuldade(BuildContext context, String serieSelecionada) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DificuldadeScreen(serieSelecionada: serieSelecionada),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Escolha a Série'), centerTitle: true),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.menu_book_rounded,
                    size: 72,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Selecione sua categoria',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'As questões serão filtradas de acordo com a série escolhida.',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 35),
                  ..._series.map((serie) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: AppButton(
                        texto: serie['texto']!,
                        altura: 64,
                        icone: Icons.arrow_forward_rounded,
                        onPressed: () {
                          _abrirDificuldade(context, serie['valor']!);
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
    );
  }
}
