import 'package:flutter/material.dart';

class LoadingOverlay extends StatelessWidget {
  final bool carregando;
  final Widget child;
  final String mensagem;

  const LoadingOverlay({
    super.key,
    required this.carregando,
    required this.child,
    this.mensagem = 'Carregando...',
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,

        if (carregando)
          Positioned.fill(
            child: Container(
              color: Colors.black45,
              child: Center(
                child: Card(
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 25,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 20),
                        Text(mensagem, style: const TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
