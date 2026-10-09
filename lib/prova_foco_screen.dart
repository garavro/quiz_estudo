import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'prova_resumo_screen.dart';

class ProvaFocoScreen extends StatefulWidget {
  final String provaId;
  final String sessaoId;
  final DateTime dataFimSessao;

  const ProvaFocoScreen({
    super.key,
    required this.provaId,
    required this.sessaoId,
    required this.dataFimSessao,
  });

  @override
  State<ProvaFocoScreen> createState() => _ProvaFocoScreenState();
}

class _ProvaFocoScreenState extends State<ProvaFocoScreen> with WidgetsBindingObserver {
  final _supabase = Supabase.instance.client;

  bool _carregando = true;
  bool _provaEncerrada = false;
  
  List<dynamic> _questoes = [];
  int _indiceAtual = 0;
  
  // Mapa para a Interface: Mostra a letra 'A', 'B' selecionada no mapa visual
  final Map<String, String> _respostasUI = {};
  
  // Mapa para o Banco: Guarda o TEXTO real para sabermos o que o aluno escolheu
  final Map<String, String> _respostasDB = {};
  
  // Guarda as opções misturadas de forma fixa para cada questão
  final Map<String, List<String>> _opcoesEmbaralhadas = {};

  Timer? _cronometro;
  Duration _tempoRestante = Duration.zero;

  bool _modoRascunho = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); 
    _iniciarProva();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); 
    _cronometro?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_provaEncerrada) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _acionarAntiCheat();
    }
  }

  Future<void> _iniciarProva() async {
    try {
      final dados = await _supabase
          .from('provas_questoes')
          .select('peso, questoes:quest (*)')
          .eq('prova_id', widget.provaId)
          .order('ordem', ascending: true);

      // Embaralha as alternativas de forma determinística (não muda ao recarregar a página)
      for (var item in dados) {
        final questao = item['questoes'];
        if (questao == null) continue;
        
        final id = questao['id'].toString();
        final opcoes = [
          questao['alternativa_correta']?.toString() ?? '',
          questao['alternativa_errada1']?.toString() ?? '',
          questao['alternativa_errada2']?.toString() ?? '',
          questao['alternativa_errada3']?.toString() ?? '',
          questao['alternativa_errada4']?.toString() ?? '',
        ];
        
        opcoes.removeWhere((o) => o.trim().isEmpty);
        // Usa o hash do ID como semente para o Random. Mistura, mas de forma fixa!
        opcoes.shuffle(Random(id.hashCode)); 
        
        _opcoesEmbaralhadas[id] = opcoes;
      }

      final respostasSalvas = await _supabase
          .from('respostas_prova')
          .select('questao_id, alternativa_selecionada')
          .eq('sessao_id', widget.sessaoId);

      for (var r in respostasSalvas) {
        final qId = r['questao_id'].toString();
        final textoSalvo = r['alternativa_selecionada'].toString();
        
        _respostasDB[qId] = textoSalvo;
        
        // Encontra qual letra corresponde ao texto salvo
        final opcoes = _opcoesEmbaralhadas[qId] ?? [];
        final index = opcoes.indexOf(textoSalvo);
        if (index != -1) {
          const letras = ['A', 'B', 'C', 'D', 'E'];
          _respostasUI[qId] = letras[index];
        }
      }

      if (!mounted) return;

      setState(() {
        _questoes = dados;
        _carregando = false;
      });

      _iniciarCronometro();
    } catch (e) {
      _mostrarErroFatal('Falha técnica ao carregar:\n\n${e.toString()}');
    }
  }

  void _iniciarCronometro() {
    _cronometro = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_provaEncerrada) {
        timer.cancel();
        return;
      }

      final agora = DateTime.now().toUtc();
      final restante = widget.dataFimSessao.difference(agora);

      if (restante.isNegative) {
        timer.cancel();
        _finalizarProvaPorTempo();
      } else {
        setState(() {
          _tempoRestante = restante;
        });
      }
    });
  }

  Future<void> _acionarAntiCheat() async {
    _provaEncerrada = true;
    _cronometro?.cancel();

    try {
      await _supabase.from('sessoes_prova').update({
        'status': 'bloqueada',
        'motivo_bloqueio': 'Saiu do aplicativo ou sobrepôs outra tela',
        'data_hora_fim': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', widget.sessaoId);
    } catch (_) {}

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
            SizedBox(width: 10),
            Text('Prova Bloqueada', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: const Text(
          'O sistema Anti-Cheat detectou que você saiu do aplicativo ou abriu outra janela.\n\n'
          'Sua prova foi suspensa. Comunique o Professor Gestor.',
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            child: const Text('Sair para o Menu'),
          ),
        ],
      ),
    );
  }

  Future<void> _finalizarProvaPorTempo() async {
    _provaEncerrada = true;
    
    try {
      await _supabase.from('sessoes_prova').update({
        'status': 'finalizada',
        'data_hora_fim': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', widget.sessaoId);
    } catch (_) {}

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Tempo Esgotado!'),
        content: const Text('O tempo da prova acabou. Suas respostas foram enviadas automaticamente.'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            child: const Text('Voltar ao Menu'),
          ),
        ],
      ),
    );
  }

  Future<void> _salvarRespostaSupabase(String questaoId, String textoAlternativa) async {
    try {
      await _supabase.from('respostas_prova').upsert({
        'sessao_id': widget.sessaoId,
        'questao_id': questaoId,
        'alternativa_selecionada': textoAlternativa, // Agora salva o texto, não a letra!
      }, onConflict: 'sessao_id, questao_id');
    } catch (e) {
      // Falha silenciosa: O aluno continua vendo que marcou a opção localmente
    }
  }

  void _selecionarAlternativa(String questaoId, String letra, String textoAlternativa) {
    if (_provaEncerrada) return;

    setState(() {
      _respostasUI[questaoId] = letra;
      _respostasDB[questaoId] = textoAlternativa;
    });

    _salvarRespostaSupabase(questaoId, textoAlternativa);
  }

  void _mostrarErroFatal(String mensagem) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Erro'),
        content: Text(mensagem),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            child: const Text('Voltar'),
          )
        ],
      ),
    );
  }

  String _formatarCronometro(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final horas = twoDigits(duration.inHours);
    final minutos = twoDigits(duration.inMinutes.remainder(60));
    final segundos = twoDigits(duration.inSeconds.remainder(60));
    return horas == '00' ? '$minutos:$segundos' : '$horas:$minutos:$segundos';
  }

  Widget _construirBotaoAlternativa(String questaoId, String letra, String textoAlternativa) {
    if (textoAlternativa.trim().isEmpty) return const SizedBox.shrink();

    // Compara com a letra selecionada
    final selecionada = _respostasUI[questaoId] == letra;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _selecionarAlternativa(questaoId, letra, textoAlternativa),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: selecionada ? Colors.blue.shade50 : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selecionada ? Colors.blueAccent : Colors.grey.shade300,
              width: selecionada ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: selecionada ? Colors.blueAccent : Colors.grey.shade200,
                child: Text(
                  letra,
                  style: TextStyle(
                    color: selecionada ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  textoAlternativa,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: selecionada ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_questoes.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Prova Vazia')),
        body: const Center(child: Text('Nenhuma questão encontrada para esta prova.')),
      );
    }

    final questaoAtual = _questoes[_indiceAtual]['questoes'];
    final questaoId = questaoAtual['id'].toString();
    final textoPergunta = (questaoAtual['pergunta']?.toString() ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    final imagemUrl = questaoAtual['imagem_url']?.toString();
    final corTempo = _tempoRestante.inMinutes < 5 ? Colors.redAccent : Colors.black87;

    return WillPopScope(
      onWillPop: () async => false, 
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.white,
          elevation: 1,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Questão ${_indiceAtual + 1} de ${_questoes.length}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: corTempo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined, color: corTempo, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      _formatarCronometro(_tempoRestante),
                      style: TextStyle(color: corTempo, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        textoPergunta,
                        textAlign: TextAlign.justify,
                        style: const TextStyle(fontSize: 18, height: 1.5),
                      ),
                      const SizedBox(height: 20),
                      
                      if (imagemUrl != null && imagemUrl.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              imagemUrl,
                              width: double.infinity,
                              fit: BoxFit.contain,
                              errorBuilder: (c, e, s) => const Text('Erro ao carregar imagem.'),
                            ),
                          ),
                        ),
                      
                      // Renderização Dinâmica das Alternativas
                      ...(() {
                        final opcoes = _opcoesEmbaralhadas[questaoId] ?? [];
                        const letras = ['A', 'B', 'C', 'D', 'E'];
                        
                        return List.generate(opcoes.length, (index) {
                          return _construirBotaoAlternativa(
                            questaoId, 
                            letras[index], 
                            opcoes[index],
                          );
                        });
                      }()),
                    ],
                  ),
                ),
              ),
              
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.black12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _indiceAtual > 0 
                          ? () => setState(() { _indiceAtual--; }) 
                          : null,
                      icon: const Icon(Icons.arrow_back_ios_new, size: 16),
                      label: const Text('Anterior'),
                    ),
                    
                    if (_indiceAtual < _questoes.length - 1)
                      ElevatedButton(
                        onPressed: () => setState(() { _indiceAtual++; }),
                        child: const Row(
                          children: [
                            Text('Próxima'),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_ios, size: 16),
                          ],
                        ),
                      )
                    else
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProvaResumoScreen(
                                sessaoId: widget.sessaoId,
                                questoes: _questoes,
                                respostas: _respostasUI, // Passa apenas as letras para o mapa visual!
				 respostasTexto: _respostasDB, // <-- ADICIONE ESTA LINHA AQUI!
                              ),
                            ),
                          );
                        },
                        child: const Row(
                          children: [
                            Text('Finalizar Prova'),
                            SizedBox(width: 8),
                            Icon(Icons.check_circle_outline, size: 16),
                          ],
                        ),
                      ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}