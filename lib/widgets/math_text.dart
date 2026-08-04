import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

class MathText extends StatelessWidget {
  final String texto;
  final double fontSize;
  final Color corTexto;
  final FontWeight fontWeight;
  final TextAlign textAlign;

  const MathText(
    this.texto, {
    super.key,
    this.fontSize = 18,
    this.corTexto = Colors.black87,
    this.fontWeight = FontWeight.normal,
    this.textAlign = TextAlign.justify,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Regex inteligente: ignora o cifrão se ele estiver escapado com barra invertida (R\$)
    final RegExp exp = RegExp(r'(?<!\\)\$(.*?)(?<!\\)\$');

    final matches = exp.allMatches(texto);

    if (matches.isEmpty) {
      return Text(
        // 2. Limpa a barra invertida do texto final para o usuário ler "R$" normal
        texto.replaceAll(r'\$', r'$'),
        textAlign: textAlign,
        style: TextStyle(
          fontSize: fontSize,
          color: corTexto,
          fontWeight: fontWeight,
        ),
      );
    }

    List<InlineSpan> spans = [];
    int ultimoIndice = 0;

    for (final match in matches) {
      if (match.start > ultimoIndice) {
        // Pega o texto normal antes da equação e limpa as barras (R\$ vira R$)
        String textoNormal = texto
            .substring(ultimoIndice, match.start)
            .replaceAll(r'\$', r'$');
        spans.add(TextSpan(text: textoNormal));
      }

      final expressao = match.group(1) ?? '';

      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Math.tex(
            expressao,
            textStyle: TextStyle(
              fontSize: fontSize,
              color: corTexto,
              fontWeight: fontWeight,
            ),
            onErrorFallback: (erro) {
              return Text(
                expressao,
                style: TextStyle(color: Colors.red, fontSize: fontSize),
              );
            },
          ),
        ),
      );

      ultimoIndice = match.end;
    }

    if (ultimoIndice < texto.length) {
      // Processa o restante do texto após a última equação
      String textoNormalFinal = texto
          .substring(ultimoIndice)
          .replaceAll(r'\$', r'$');
      spans.add(TextSpan(text: textoNormalFinal));
    }

    return RichText(
      textAlign: textAlign,
      text: TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          color: corTexto,
          fontWeight: fontWeight,
        ),
        children: spans,
      ),
    );
  }
}
