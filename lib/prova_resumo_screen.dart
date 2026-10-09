import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProvaResumoScreen extends StatefulWidget {
  final String sessaoId;
  final List<dynamic> questoes;
  final Map<String, String> respostas;
  final Map<String, String> respostasTexto; // <-- NOVA VARIÁVEL (Garante a gravação da nota)

  const ProvaResumoScreen({
    super.key,
    required this.sessaoId,
    required this.questoes,
    required this.respostas,
    required this.respostasTexto, // <-- INICIALIZADA AQUI
  });

  @override
  State<ProvaResumoScreen> createState() => _ProvaResumoScreenState();
}

class _ProvaResumoScreenState extends State<ProvaResumoScreen> {
  final _supabase = Supabase.instance.client;
  bool _enviando = false;

  Future<void> _entregarProva() async {
    setState(() => _enviando = true);

    try {
      // --- CÁLCULO DA NOTA FINAL ---
      int acertos = 0;
      for (var item in widget.questoes) {
        final questao = item['questoes'];
        final String qId = questao['id'].toString();
        final String correta = questao['alternativa_correta'].toString();
        
        // Verifica se o texto que o aluno marcou é igual à alternativa correta
        if (widget.respostasTexto[qId] == correta) {
          acertos++;
        }
      }
      
      // Neste exemplo, a nota final será a quantidade de acertos. 
      final num notaFinal = acertos; 
      // ---------------------------------

      // Atualiza o status E a nota final na sessão
      await _supabase.from('sessoes_prova').update({
        'status': 'finalizada',
        'nota_final': notaFinal,
        'data_hora_fim': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', widget.sessaoId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prova entregue com sucesso! O gabarito será liberado em breve.'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).popUntil((route) => route.isFirst);
   } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro técnico: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _confirmarEntrega() {
    final questoesEmBranco = widget.questoes.where((q) {
      final id = q['questoes']['id'].toString();
      return !widget.respostas.containsKey(id);
    }).length;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Entrega'),
        content: Text(
          questoesEmBranco > 0
              ? 'Você deixou $questoesEmBranco questão(ões) em branco.\n\nTem certeza que deseja finalizar a prova agora? Não será possível alterar suas respostas depois.'
              : 'Você respondeu todas as questões.\n\nTem certeza que deseja finalizar a prova agora?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Revisar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _entregarProva();
            },
            child: const Text('Sim, Entregar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Resumo da Prova'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Verifique o mapa da sua prova antes de entregar. Você pode tocar no botão "Voltar" para revisar suas respostas.',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            
            // Mapa Visual das Questões
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: widget.questoes.length,
                itemBuilder: (context, index) {
                  final questaoId = widget.questoes[index]['questoes']['id'].toString();
                  final respondida = widget.respostas.containsKey(questaoId);
                  final alternativa = widget.respostas[questaoId];

                  return Container(
                    decoration: BoxDecoration(
                      color: respondida ? Colors.blueAccent : Colors.grey.shade200,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: respondida ? Colors.blue.shade700 : Colors.grey.shade400,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        respondida ? alternativa! : '${index + 1}',
                        style: TextStyle(
                          color: respondida ? Colors.white : Colors.black54,
                          fontWeight: FontWeight.bold,
                          fontSize: respondida ? 20 : 16,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Botões de Ação
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.black12)),
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _enviando ? null : _confirmarEntrega,
                      child: _enviando
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('ENTREGAR PROVA DEFINITIVAMENTE', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton(
                      onPressed: _enviando ? null : () => Navigator.of(context).pop(),
                      child: const Text('Voltar para as questões'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}