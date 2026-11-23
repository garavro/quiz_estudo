import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_windowmanager_plus/flutter_windowmanager_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'prova_resumo_screen.dart';
import 'widgets/math_text.dart';

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

class _ProvaFocoScreenState extends State<ProvaFocoScreen>
    with WidgetsBindingObserver {
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

  // Controle do nível de zoom
  double _escalaZoom = 1.2;
  double _escalaAnterior = 1.2;

  // ==== VARIÁVEIS DE ACESSIBILIDADE E RASCUNHO ====
  bool _modoZoom = false;
  bool _modoRascunho = false;
  bool _modoBorracha = false;
  bool _fundoBrancoAtivo = false;
  Color _corRascunhoAtual = Colors.blueAccent;

  final ScrollController _zoomVerticalController = ScrollController();
  final ScrollController _zoomHorizontalController = ScrollController();

  // Sistema de Slides / Caderno de Rascunho
  List<List<PontoRascunho>> _paginasRascunho = [[]];
  int _paginaAtualRascunho = 0;

  static const String _bucketQuestoesImagensUrl =
      'https://ojkkstibwifhbplakjfw.supabase.co/storage/v1/object/public/questoes-imagens/';
  static const String _bucketImagensAntigasUrl =
      'https://ojkkstibwifhbplakjfw.supabase.co/storage/v1/object/public/images/';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Ativa a proteção Anti-Print (Screenshot) no Android
    _ativarAntiPrint();

    _iniciarProva();
  }

  // --- FUNÇÕES ANTI-PRINT ---
  Future<void> _ativarAntiPrint() async {
    if (kIsWeb) return;
    if (!Platform.isAndroid) return;

    try {
      await FlutterWindowManagerPlus.addFlags(
          FlutterWindowManagerPlus.FLAG_SECURE);
    } catch (e) {
      debugPrint("Erro ao ativar Anti-Print: $e");
    }
  }

  Future<void> _desativarAntiPrint() async {
    if (kIsWeb) return;
    if (!Platform.isAndroid) return;

    try {
      await FlutterWindowManagerPlus.clearFlags(
          FlutterWindowManagerPlus.FLAG_SECURE);
    } catch (e) {
      debugPrint("Erro ao desativar Anti-Print: $e");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cronometro?.cancel();
    _desativarAntiPrint();
    _zoomVerticalController.dispose();
    _zoomHorizontalController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_provaEncerrada) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _acionarAntiCheat();
    }
  }

  void _resetarModosEspeciais() {
    _paginasRascunho = [[]];
    _paginaAtualRascunho = 0;
    _modoRascunho = false;
    _modoZoom = false;
    _modoBorracha = false;
    _fundoBrancoAtivo = false;
  }

  String? _resolverImagemUrl(dynamic valor) {
    if (valor == null) return null;
    final texto = valor.toString().trim();
    final textoMinusculo = texto.toLowerCase();

    if (texto.isEmpty ||
        textoMinusculo == 'null' ||
        textoMinusculo == 'empty') {
      return null;
    }

    if (texto.startsWith('http://') || texto.startsWith('https://')) {
      return texto;
    }
    if (texto.startsWith('questoes-imagens/')) {
      return 'https://ojkkstibwifhbplakjfw.supabase.co/storage/v1/object/public/$texto';
    }
    if (texto.startsWith('nivel_')) return '$_bucketQuestoesImagensUrl$texto';

    return '$_bucketImagensAntigasUrl$texto';
  }

  Future<void> _iniciarProva() async {
    try {
      // 1. Busca os dados da sessão atual para saber quando o aluno INICIOU a prova
      final sessaoAtual = await _supabase
          .from('sessoes_prova')
          .select('data_hora_inicio, provas_oficiais(tempo_limite_minutos)')
          .eq('id', widget.sessaoId)
          .single();

      final dataInicioUTC =
          DateTime.parse(sessaoAtual['data_hora_inicio']).toUtc();
      final duracaoMinutos =
          sessaoAtual['provas_oficiais']['tempo_limite_minutos'] as int;

      // O tempo limite exato deste aluno é a hora que ele começou + os minutos da prova
      final limiteIndividual =
          dataInicioUTC.add(Duration(minutes: duracaoMinutos));

      // Compara o limite individual com o limite global (dataFimSessao que vem do Widget)
      DateTime limiteFinalParaUsar = limiteIndividual;
      if (widget.dataFimSessao.isBefore(limiteIndividual)) {
        limiteFinalParaUsar = widget.dataFimSessao;
      }

      // 2. Busca as questões da prova
      final dados = await _supabase
          .from('provas_questoes')
          .select('peso, questoes:questoes_oficiais (*)')
          .eq('prova_id', widget.provaId)
          .order('ordem', ascending: true);

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

      // 3. Inicia o cronômetro passando o limite calculado
      _iniciarCronometro(limiteFinalParaUsar);
    } catch (e) {
      _mostrarErroFatal('Falha técnica ao carregar:\n\n${e.toString()}');
    }
  }

  void _iniciarCronometro(DateTime horaLimite) {
    _cronometro = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_provaEncerrada) {
        timer.cancel();
        return;
      }

      final agora = DateTime.now().toUtc();
      final restante = horaLimite.difference(agora);

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
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
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
        content: const Text(
            'O tempo da prova acabou. Suas respostas foram enviadas automaticamente.'),
        actions: [
          ElevatedButton(
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
            child: const Text('Voltar ao Menu'),
          ),
        ],
      ),
    );
  }

  Future<void> _salvarRespostaSupabase(
      String questaoId, String textoAlternativa) async {
    try {
      await _supabase.from('respostas_prova').upsert({
        'sessao_id': widget.sessaoId,
        'questao_id': questaoId,
        'alternativa_selecionada': textoAlternativa,
      }, onConflict: 'sessao_id, questao_id');
    } catch (e) {
      // Falha silenciosa: O aluno continua vendo que marcou a opção localmente
    }
  }

  void _selecionarAlternativa(
      String questaoId, String letra, String textoAlternativa) {
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
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
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

  // ==== WIDGETS DO RASCUNHO ==== //

  Widget _botaoCor(Color cor) {
    final selecionado = _corRascunhoAtual == cor && !_modoBorracha;
    return GestureDetector(
      onTap: () => setState(() {
        _corRascunhoAtual = cor;
        _modoBorracha = false;
      }),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: cor,
          shape: BoxShape.circle,
          border: Border.all(
            color: selecionado ? Colors.orange : Colors.transparent,
            width: selecionado ? 3 : 0,
          ),
          boxShadow: [
            if (selecionado)
              const BoxShadow(
                  color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
          ],
        ),
      ),
    );
  }

  Widget _barraFerramentasRascunho() {
    return Positioned(
      right: 12,
      top: 0,
      bottom: 0,
      child: Center(
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(30),
          color: Theme.of(context).colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- CONTROLES DE PÁGINA (SLIDES) ---
                  IconButton(
                    icon: const Icon(Icons.arrow_drop_up, size: 28),
                    onPressed: _paginaAtualRascunho > 0
                        ? () => setState(() => _paginaAtualRascunho--)
                        : null,
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                  Text(
                    '${_paginaAtualRascunho + 1}/${_paginasRascunho.length}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_drop_down, size: 28),
                    onPressed:
                        _paginaAtualRascunho < _paginasRascunho.length - 1
                            ? () => setState(() => _paginaAtualRascunho++)
                            : null,
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  IconButton(
                    icon: const Icon(Icons.note_add_outlined,
                        color: Colors.blueAccent),
                    tooltip: 'Nova Página',
                    onPressed: () {
                      setState(() {
                        _paginasRascunho.add([]);
                        _paginaAtualRascunho = _paginasRascunho.length - 1;
                      });
                    },
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  Container(width: 24, height: 1, color: Colors.grey.shade400),
                  const SizedBox(height: 8),

                  // --- FERRAMENTAS DE DESENHO ---
                  _botaoCor(Colors.black),
                  _botaoCor(Colors.blueAccent),
                  _botaoCor(Colors.redAccent),
                  _botaoCor(Colors.green),
                  const SizedBox(height: 8),
                  Container(width: 24, height: 1, color: Colors.grey.shade400),
                  const SizedBox(height: 8),

                  IconButton(
                    icon: Icon(
                      _fundoBrancoAtivo
                          ? Icons.rectangle
                          : Icons.rectangle_outlined,
                      color: _fundoBrancoAtivo
                          ? Colors.orange
                          : Colors.grey.shade600,
                    ),
                    onPressed: () =>
                        setState(() => _fundoBrancoAtivo = !_fundoBrancoAtivo),
                    tooltip: _fundoBrancoAtivo
                        ? 'Fundo Transparente'
                        : 'Folha em Branco',
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 12),
                  IconButton(
                    icon: Icon(
                      Icons.cleaning_services_rounded,
                      color:
                          _modoBorracha ? Colors.orange : Colors.grey.shade600,
                    ),
                    onPressed: () => setState(() => _modoBorracha = true),
                    tooltip: 'Borracha',
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 12),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.redAccent),
                    onPressed: () => setState(
                        () => _paginasRascunho[_paginaAtualRascunho].clear()),
                    tooltip: 'Limpar página atual',
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================= //

  Widget _imagemQuestao(String? imagemUrl,
      {bool emZoom = false, double escala = 1.0}) {
    final urlCompleta = _resolverImagemUrl(imagemUrl);

    if (urlCompleta == null) {
      return const SizedBox.shrink();
    }

    final widgetImagem = Image.network(
      urlCompleta,
      fit: BoxFit.contain,
      width:
          emZoom ? (MediaQuery.of(context).size.width * 0.75) * escala : null,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const SizedBox(
          height: 180,
          child: Center(child: CircularProgressIndicator()),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          height: 180,
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image, size: 56, color: Colors.redAccent),
                SizedBox(height: 8),
                Text(
                  'Não foi possível carregar a imagem da questão.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (emZoom) {
      return Column(
        children: [
          const SizedBox(height: 20),
          widgetImagem,
          const SizedBox(height: 20),
        ],
      );
    }

    return Column(
      children: [
        const SizedBox(height: 20),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(
              maxHeight: 260,
            ),
            color: Colors.grey.shade100,
            child: widgetImagem,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _construirBotaoAlternativa(
      String questaoId, String letra, String textoAlternativa) {
    if (textoAlternativa.trim().isEmpty) return const SizedBox.shrink();

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
            color: selecionada
                ? Colors.blue.shade50
                : Theme.of(context).colorScheme.surface,
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
                backgroundColor:
                    selecionada ? Colors.blueAccent : Colors.grey.shade200,
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
                child: MathText(
                  textoAlternativa,
                  fontSize: 16,
                  fontWeight:
                      selecionada ? FontWeight.w600 : FontWeight.normal,
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
        body: const Center(
            child: Text('Nenhuma questão encontrada para esta prova.')),
      );
    }

    final questaoAtual = _questoes[_indiceAtual]['questoes'];
    final questaoId = questaoAtual['id'].toString();
    final textoPergunta = (questaoAtual['pergunta']?.toString() ?? '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final imagemUrl = questaoAtual['imagem_url']?.toString();
    final corTempo =
        _tempoRestante.inMinutes < 5 ? Colors.redAccent : Colors.black87;

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
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                      style: TextStyle(
                          color: corTempo,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            // BOTÃO RASCUNHO
            IconButton(
              icon: Icon(
                _modoRascunho ? Icons.edit_off : Icons.edit,
                color: _modoRascunho ? Colors.orange : null,
                size: 28,
              ),
              tooltip: 'Rascunho',
              onPressed: () {
                setState(() {
                  _modoRascunho = !_modoRascunho;
                  if (_modoRascunho) _modoZoom = false;
                  if (!_modoRascunho) {
                    _paginasRascunho = [[]];
                    _paginaAtualRascunho = 0;
                    _modoBorracha = false;
                    _fundoBrancoAtivo = false;
                  }
                });
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            // Camada Principal: Questão, Alternativas e Navegação
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1000),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // BLOCO DA PERGUNTA COM OPÇÃO DE ZOOM E ROLAGEM INDEPENDENTE
                              Stack(
                                children: [
                                  _modoZoom
                                      ? Container(
                                          height: 420,
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                                color: Colors.blueAccent,
                                                width: 2),
                                            borderRadius:
                                                BorderRadius.circular(18),
                                          ),
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            // Barra de rolagem Horizontal (Fixa no rodapé)
                                            child: Scrollbar(
                                              controller:
                                                  _zoomHorizontalController,
                                              thumbVisibility: true,
                                              thickness: 8,
                                              notificationPredicate: (notif) =>
                                                  notif.depth == 0,
                                              child: SingleChildScrollView(
                                                controller:
                                                    _zoomHorizontalController,
                                                scrollDirection:
                                                    Axis.horizontal,
                                                child: SizedBox(
                                                  height: 420,
                                                  // Barra de rolagem Vertical (Fixa na lateral direita)
                                                  child: Scrollbar(
                                                    controller:
                                                        _zoomVerticalController,
                                                    thumbVisibility: true,
                                                    thickness: 8,
                                                    notificationPredicate:
                                                        (notif) =>
                                                            notif.depth == 0,
                                                    child:
                                                        SingleChildScrollView(
                                                      controller:
                                                          _zoomVerticalController,
                                                      scrollDirection:
                                                          Axis.vertical,
                                                      child: GestureDetector(
                                                        // Permite Zoom com gesto de pinça (dois dedos)
                                                        onScaleStart:
                                                            (details) {
                                                          _escalaAnterior =
                                                              _escalaZoom;
                                                        },
                                                        onScaleUpdate:
                                                            (details) {
                                                          setState(() {
                                                            _escalaZoom = (_escalaAnterior *
                                                                    details
                                                                        .scale)
                                                                .clamp(
                                                                    1.0, 3.0);
                                                          });
                                                        },
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(12),
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              SizedBox(
                                                                width: (MediaQuery.of(
                                                                                context)
                                                                            .size
                                                                            .width *
                                                                        0.8) *
                                                                    _escalaZoom,
                                                                child: Card(
                                                                  elevation: 0,
                                                                  color: Colors
                                                                      .transparent,
                                                                  child:
                                                                      Padding(
                                                                    padding: const EdgeInsets
                                                                        .only(
                                                                        left:
                                                                            12,
                                                                        top: 40,
                                                                        bottom:
                                                                            35,
                                                                        right:
                                                                            40),
                                                                    child:
                                                                        MathText(
                                                                      textoPergunta,
                                                                      fontSize:
                                                                          18 *
                                                                              _escalaZoom,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      corTexto: Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .onSurface,
                                                                      textAlign:
                                                                          TextAlign
                                                                              .justify,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                              _imagemQuestao(
                                                                  imagemUrl,
                                                                  emZoom: true,
                                                                  escala:
                                                                      _escalaZoom),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                      : Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Card(
                                              elevation: 2,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          18)),
                                              child: Padding(
                                                padding: const EdgeInsets.only(
                                                    left: 20,
                                                    top: 20,
                                                    bottom: 35,
                                                    right: 40),
                                                child: MathText(
                                                  textoPergunta,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  corTexto: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface,
                                                  textAlign: TextAlign.justify,
                                                ),
                                              ),
                                            ),
                                            _imagemQuestao(imagemUrl,
                                                emZoom: false),
                                          ],
                                        ),

                                  // CONTROLES DE ZOOM (+ / - / %) NO CANTO SUPERIOR ESQUERDO
                                  if (_modoZoom)
                                    Positioned(
                                      top: 8,
                                      left: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surface
                                              .withValues(alpha: 0.95),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                              color:
                                                  Colors.blueAccent.shade100),
                                          boxShadow: const [
                                            BoxShadow(
                                                color: Colors.black12,
                                                blurRadius: 4)
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.remove,
                                                  size: 18),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(
                                                  minWidth: 32, minHeight: 32),
                                              onPressed: _escalaZoom > 1.0
                                                  ? () => setState(() =>
                                                      _escalaZoom =
                                                          (_escalaZoom - 0.2)
                                                              .clamp(1.0, 3.0))
                                                  : null,
                                            ),
                                            Text(
                                              '${(_escalaZoom * 100).round()}%',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.add,
                                                  size: 18),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(
                                                  minWidth: 32, minHeight: 32),
                                              onPressed: _escalaZoom < 3.0
                                                  ? () => setState(() =>
                                                      _escalaZoom =
                                                          (_escalaZoom + 0.2)
                                                              .clamp(1.0, 3.0))
                                                  : null,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                  // LUPA NO CANTO INFERIOR DIREITO
                                  Positioned(
                                    bottom: _modoZoom
                                        ? 12
                                        : (_resolverImagemUrl(imagemUrl) != null
                                            ? 25
                                            : 5),
                                    right: 8,
                                    child: IconButton(
                                      icon: Icon(
                                        _modoZoom
                                            ? Icons.zoom_out_map
                                            : Icons.zoom_in,
                                        color: _modoZoom
                                            ? Colors.blueAccent
                                            : Colors.black87,
                                        size: 30,
                                      ),
                                      tooltip: 'Acessibilidade (Zoom)',
                                      onPressed: () {
                                        setState(() {
                                          _modoZoom = !_modoZoom;
                                          if (_modoZoom) _modoRascunho = false;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Renderização Dinâmica das Alternativas
                              ...(() {
                                final opcoes =
                                    _opcoesEmbaralhadas[questaoId] ?? [];
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
                    ),
                  ),

                  // Barra Inferior de Navegação da Prova
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Colors.black12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _indiceAtual > 0
                              ? () => setState(() {
                                    _indiceAtual--;
                                    _resetarModosEspeciais();
                                  })
                              : null,
                          icon: const Icon(Icons.arrow_back_ios_new, size: 16),
                          label: const Text('Anterior'),
                        ),
                        if (_indiceAtual < _questoes.length - 1)
                          ElevatedButton(
                            onPressed: () => setState(() {
                              _indiceAtual++;
                              _resetarModosEspeciais();
                            }),
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
                                    respostas: _respostasUI,
                                    respostasTexto: _respostasDB,
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
                  ),
                ],
              ),
            ),

            // Camada de Fundo Branco para o Rascunho
            if (_modoRascunho && _fundoBrancoAtivo)
              Positioned.fill(
                child: Container(color: Colors.grey.shade50),
              ),

            // Camada Intermediária: Tela de Desenho (Canvas)
            if (_modoRascunho)
              Positioned.fill(
                child: GestureDetector(
                  onPanStart: (details) {
                    setState(() {
                      _paginasRascunho[_paginaAtualRascunho].add(PontoRascunho(
                        offset: details.localPosition,
                        cor: _corRascunhoAtual,
                        isBorracha: _modoBorracha,
                        espessura: _modoBorracha ? 25.0 : 3.0,
                      ));
                    });
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      _paginasRascunho[_paginaAtualRascunho].add(PontoRascunho(
                        offset: details.localPosition,
                        cor: _corRascunhoAtual,
                        isBorracha: _modoBorracha,
                        espessura: _modoBorracha ? 25.0 : 3.0,
                      ));
                    });
                  },
                  onPanEnd: (details) {
                    setState(() {
                      _paginasRascunho[_paginaAtualRascunho]
                          .add(PontoRascunho(offset: null));
                    });
                  },
                  child: Container(
                    color: Colors.transparent,
                    child: CustomPaint(
                      painter: RascunhoPainter(
                          _paginasRascunho[_paginaAtualRascunho]),
                    ),
                  ),
                ),
              ),

            // Camada Superior: Barra de Ferramentas
            if (_modoRascunho) _barraFerramentasRascunho(),
          ],
        ),
      ),
    );
  }
}

// ==== CLASSES DE PINTURA E MODELAGEM ==== //

class PontoRascunho {
  final Offset? offset;
  final Color cor;
  final double espessura;
  final bool isBorracha;

  PontoRascunho({
    this.offset,
    this.cor = Colors.blueAccent,
    this.espessura = 3.0,
    this.isBorracha = false,
  });
}

class RascunhoPainter extends CustomPainter {
  final List<PontoRascunho> pontos;

  RascunhoPainter(this.pontos);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    for (int i = 0; i < pontos.length - 1; i++) {
      if (pontos[i].offset != null && pontos[i + 1].offset != null) {
        final paint = Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = pontos[i].espessura
          ..style = PaintingStyle.stroke;

        if (pontos[i].isBorracha) {
          paint.blendMode = BlendMode.clear;
        } else {
          paint.color = pontos[i].cor;
        }

        canvas.drawLine(pontos[i].offset!, pontos[i + 1].offset!, paint);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant RascunhoPainter oldDelegate) => true;
}