import 'package:flutter/material.dart';

class AppButton extends StatelessWidget {
  final String texto;
  final VoidCallback? onPressed;
  final Color cor;
  final double altura;
  final double largura;
  final bool carregando;
  final IconData? icone;

  const AppButton({
    super.key,
    required this.texto,
    required this.onPressed,
    this.cor = Colors.blueAccent,
    this.altura = 60,
    this.largura = double.infinity,
    this.carregando = false,
    this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: largura,
      height: altura,
      child: ElevatedButton(
        onPressed: carregando ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: cor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: carregando
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icone != null) ...[Icon(icone), const SizedBox(width: 8)],
                  Text(
                    texto,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
