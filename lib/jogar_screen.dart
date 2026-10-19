import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'resultado_screen.dart';
import 'services/auth_service.dart' as app_auth;
import 'services/level_service.dart';
import 'services/progress_service.dart';
import 'services/ranking_service.dart';
import 'services/score_service.dart';
import 'widgets/app_button.dart';
import 'widgets/loading_overlay.dart';
import 'widgets/math_text.dart';

class JogarScreen extends StatefulWidget {
  final List<dynamic> questoes;
  final String dificuldade;
  final String nivelAtual;

  const JogarScreen({
    super.key,
    required this.questoes,
    required this.dificuldade,
    required this.nivelAtual,
  });

  @override
  State<JogarScreen> createState() => _JogarScreenState();
}

class _JogarScreenState extends State<JogarScreen>
    with WidgetsBindingObserver {
  final RankingService _rankingService = RankingService();
  final ProgressService _progressService = ProgressService();
  final app_auth.AuthService _authService = app_auth.AuthService();

  late final List<dynamic> _questoes;

  int _index = 0;
  int _certas = 0;
  int _erradas = 0;

  int _sequenciaAtual = 0;
  int _maiorSequencia = 0;
  int _bonusSequencia = 0;

  List<String> _alternativas = [];

  String _perguntaAtual = '';
  String _imagemUrl = '';
  String? _respostaSelecionada;

  bool _processandoResposta = false;
  bool _finalizando = false;
  bool _antiColaAcionado = false;

  // ==== VARIÁVEIS DE ACESSIBILIDADE E RASCUNHO ====
  bool _modoZoom = false; 
  bool _modoRascunho = false;
  bool _modoBorracha = false;
  bool _fundoBrancoAtivo = false;
  Color _corRascunhoAtual = Colors.blueAccent;
  
  // Sistema de Slides / Caderno de Rascunho
  List<List<PontoRascunho>> _paginasRascunho = [[]];
  int _paginaAtualRascunho = 0;

  final List<Map<String, dynamic>> _historicoRespostas = [];

  static const int _quantidadeParaBonusSequencia = 3;
  static const String _bucketQuestoesImagensUrl =
      'https://ojkkstibwifhbplakjfw.supabase.co/storage/v1/object/public/questoes-imagens/';
  static const String _bucketImagensAntigasUrl =
      'https://ojkkstibwifhbplakjfw.supabase.co/storage/v1/object/public/images/';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Ativa a proteção Anti-Print (Screenshot)
    _ativarAntiPrint();

    _questoes = List<dynamic>.from(widget.questoes)..shuffle();

    if (_questoes.isNotEmpty) {
      _prepararQuestao();
    }
  }

  // --- FUNÇÕES ANTI-PRINT ---
  Future<void> _ativarAntiPrint() async {
    if (kIsWeb) return; 
    if (!Platform.isAndroid) return;

    try {
      await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
    } catch (e) {
      debugPrint("Erro ao ativar Anti-Print: $e");
    }
  }

  Future<void> _desativarAntiPrint() async {
    if (kIsWeb) return;
    if (!Platform.isAndroid) return;

    try {
      await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
    } catch (e) {
      debugPrint("Erro ao desativar Anti-Print: $e");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _desativarAntiPrint(); 
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Bloqueio de troca de tela removido para o Banco de Treino
  }

  String? _resolverImagemUrl(dynamic valor) {
    if (valor == null) return null;
    final texto = valor.toString().trim();
    final textoMinusculo = texto.toLowerCase();

    if (texto.isEmpty || textoMinusculo == 'null' || textoMinusculo == 'empty') {
      return null;
    }

    if (texto.startsWith('http://') || texto.startsWith('https://')) return texto;
    if (texto.startsWith('questoes-imagens/')) {
      return 'https://ojkkstibwifhbplakjfw.supabase.co/storage/v1/object/public/$texto';
    }
    if (texto.startsWith('nivel_')) return '$_bucketQuestoesImagensUrl$texto';

    return '$_bucketImagensAntigasUrl$texto';
  }

  int get _multiplicadorDificuldade => ScoreService.multiplicadorPorDificuldade(widget.dificuldade);

  int get _bonusRodada => ScoreService.calcularBonusRodada(
      acertos: _certas,
      totalQuestoes: _questoes.length,
    );

  int get _pontuacaoRodada => ScoreService.calcularPontuacaoRodada(
      acertos: _certas,
      erros: _erradas,
      totalQuestoes: _questoes.length,
      bonusSequencia: _bonusSequencia,
      dificuldade: widget.dificuldade,
    );

  String _lerTexto(dynamic valor) => valor == null ? '' : valor.toString();

  int? _lerId(dynamic valor) {
    if (valor == null) return null;
    if (valor is int) return valor;
    if (valor is num) return valor.toInt();
    return int.tryParse(valor.toString());
  }

  void _prepararQuestao() {
    if (_index >= _questoes.length) return;

    final q = _questoes[_index];
    _perguntaAtual = _lerTexto(q['pergunta']).replaceAll(RegExp(r'\s+'), ' ').trim();    
    _imagemUrl = _lerTexto(q['imagem_url']);
    _respostaSelecionada = null;

    _alternativas = [
      _lerTexto(q['alternativa_correta']),
      _lerTexto(q['alternativa_errada1']),
      _lerTexto(q['alternativa_errada2']),
      _lerTexto(q['alternativa_errada3']),
      _lerTexto(q['alternativa_errada4']),
    ].where((a) => a.trim().isNotEmpty).toList();

    _alternativas.shuffle();
  }

  void _selecionarResposta(String resposta) {
    if (_processandoResposta || _finalizando) return;
    setState(() {
      _respostaSelecionada = resposta;
    });
  }

  Future<void> _confirmarResposta() async {
    if (_respostaSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione uma alternativa antes de confirmar.')),
      );
      return;
    }

    if (_processandoResposta || _finalizando) return;
    setState(() => _processandoResposta = true);

    final q = _questoes[_index];
    final correta = _lerTexto(q['alternativa_correta']);
    final resposta = _respostaSelecionada!;
    final acertou = resposta == correta;

    if (acertou) {
      _certas++;
      _sequenciaAtual++;
      if (_sequenciaAtual > _maiorSequencia) _maiorSequencia = _sequenciaAtual;
      if (_sequenciaAtual % _quantidadeParaBonusSequencia == 0) _bonusSequencia++;
    } else {
      _erradas++;
      _sequenciaAtual = 0;
    }

    _historicoRespostas.add({
      'questao_id': _lerId(q['id']),
      'nivel_questao': _lerTexto(q['nivel']).isEmpty ? widget.nivelAtual : _lerTexto(q['nivel']),
      'pergunta': _perguntaAtual,
      'resposta_usuario': resposta,
      'resposta_correta': correta,
      'acertou': acertou,
    });

    if (_index < _questoes.length - 1) {
      setState(() {
        _index++;
        _prepararQuestao();
        _processandoResposta = false;

        // Reseta todos os modos especiais ao avançar de questão
        _paginasRascunho = [[]];
        _paginaAtualRascunho = 0;
        _modoRascunho = false;
        _modoZoom = false;
        _modoBorracha = false;
        _fundoBrancoAtivo = false; 
      });
    } else {
      setState(() {
        _processandoResposta = false;
        _finalizando = true;
      });
      await _mostrarFimDeJogo();
    }
  }

  Future<void> _mostrarFimDeJogo() async {
    String nivelFinal = widget.nivelAtual;
    String tituloFinal = LevelService.tituloIniciante;
    bool houveAvancoNivel = false;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('ultimos_acertos', _certas);
      await prefs.setInt('ultimos_erros', _erradas);
      await prefs.setInt('ultima_pontuacao', _pontuacaoRodada);
      await prefs.setInt('ultimo_bonus_sequencia', _bonusSequencia);

      final usuarioAtual = Supabase.instance.client.auth.currentUser;

      if (usuarioAtual != null) {
        await _progressService.salvarProgressoQuestoes(
          usuarioId: usuarioAtual.id,
          nivelPadrao: widget.nivelAtual,
          historico: _historicoRespostas,
        );

        if (_pontuacaoRodada > 0) {
          await _rankingService.atualizarPontuacao(
            usuarioId: usuarioAtual.id,
            pontosGanhos: _pontuacaoRodada,
          );
        }

        final novoStatus = await _progressService.calcularNovoNivelETitulo(
          usuarioId: usuarioAtual.id,
          nivelAtual: widget.nivelAtual,
        );

        nivelFinal = novoStatus['nivel'] ?? widget.nivelAtual;
        tituloFinal = novoStatus['titulo'] ?? LevelService.tituloIniciante;
        houveAvancoNivel = nivelFinal != widget.nivelAtual;

        await _authService.atualizarNivelETitulo(nivelAtual: nivelFinal, tituloAtual: tituloFinal);
      }
    } catch (e) {
      debugPrint('Erro ao salvar resultado: $e');
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultadoScreen(
          certas: _certas,
          erradas: _erradas,
          historico: _historicoRespostas,
          pontosRodada: _pontuacaoRodada,
          multiplicador: _multiplicadorDificuldade,
          bonusRodada: _bonusRodada,
          bonusSequencia: _bonusSequencia,
          maiorSequencia: _maiorSequencia,
          nivelAnterior: widget.nivelAtual,
          nivelAtual: nivelFinal,
          tituloAtual: tituloFinal,
          houveAvancoNivel: houveAvancoNivel,
        ),
      ),
    );
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
            if (selecionado) const BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
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
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_drop_down, size: 28),
                    onPressed: _paginaAtualRascunho < _paginasRascunho.length - 1
                        ? () => setState(() => _paginaAtualRascunho++)
                        : null,
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  IconButton(
                    icon: const Icon(Icons.note_add_outlined, color: Colors.blueAccent),
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
                      _fundoBrancoAtivo ? Icons.rectangle : Icons.rectangle_outlined,
                      color: _fundoBrancoAtivo ? Colors.orange : Colors.grey.shade600,
                    ),
                    onPressed: () => setState(() => _fundoBrancoAtivo = !_fundoBrancoAtivo),
                    tooltip: _fundoBrancoAtivo ? 'Fundo Transparente' : 'Folha em Branco',
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 12),
                  IconButton(
                    icon: Icon(
                      Icons.cleaning_services_rounded,
                      color: _modoBorracha ? Colors.orange : Colors.grey.shade600,
                    ),
                    onPressed: () => setState(() => _modoBorracha = true),
                    tooltip: 'Borracha',
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 12), 
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () => setState(() => _paginasRascunho[_paginaAtualRascunho].clear()),
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

  Widget _imagemQuestao({bool emZoom = false}) {
    final urlCompleta = _resolverImagemUrl(_imagemUrl);

    if (urlCompleta == null) {
      return const SizedBox.shrink();
    }

    final widgetImagem = Image.network(
      urlCompleta,
      fit: BoxFit.contain,
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

    // Quando em modo zoom, remove a trava de maxHeight: 260 e o ClipRRect interno
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
  Widget _botaoAlternativa(String alternativa) {
    final selecionada = _respostaSelecionada == alternativa;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          elevation: selecionada ? 4 : 1,
          backgroundColor: selecionada ? Colors.amber : colorScheme.surfaceContainerHighest,
          foregroundColor: selecionada ? Colors.black : colorScheme.onSurface,
          padding: const EdgeInsets.all(18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: selecionada ? Colors.orange : colorScheme.primary,
              width: selecionada ? 2.5 : 1,
            ),
          ),
        ),
        onPressed: () => _selecionarResposta(alternativa),
        child: Center(
          child: MathText(
            alternativa,
            fontSize: 18,
            corTexto: selecionada ? Colors.black : colorScheme.onSurface,
            fontWeight: FontWeight.w600,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _barraProgresso() {
    final total = _questoes.length;
    final atual = _index + 1;
    final progresso = total == 0 ? 0.0 : atual / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Questão $atual de $total',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(value: progresso, minHeight: 10),
        ),
      ],
    );
  }

  String _nomeDificuldade() {
    switch (widget.dificuldade) {
      case 'medio': return 'Médio';
      case 'dificil': return 'Difícil';
      case 'facil': default: return 'Fácil';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_questoes.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Jogo'), centerTitle: true),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.quiz_outlined, size: 80, color: Colors.grey),
                const SizedBox(height: 20),
                const Text('Nenhuma questão disponível.', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                AppButton(texto: 'VOLTAR', largura: 220, onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
        ),
      );
    }

    return LoadingOverlay(
      carregando: _finalizando,
      mensagem: 'Salvando resultado...',
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text('${LevelService.nomeNivel(widget.nivelAtual)} - ${_nomeDificuldade()}'),
          centerTitle: true,
          automaticallyImplyLeading: !_finalizando,
          actions: [
            // BOTÃO ZOOM (ACESSIBILIDADE)
            IconButton(
              icon: Icon(
                _modoZoom ? Icons.zoom_out_map : Icons.zoom_in,
                color: _modoZoom ? Colors.blueAccent : null,
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
            // BOTÃO RASCUNHO
            IconButton(
              icon: Icon(
                _modoRascunho ? Icons.edit_off : Icons.edit,
                color: _modoRascunho ? Colors.orange : null,
                size: 30,
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
                  }
                });
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            // Camada Principal: Questão e Interação
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _barraProgresso(),
                        const SizedBox(height: 25),
                        
                     // BLOCO DA PERGUNTA COM OPÇÃO DE ZOOM
                        _modoZoom 
                        ? Container(
                            height: 420, // Aumentado para proporcionar melhor área de navegação
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.blueAccent, width: 2),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: InteractiveViewer(
                                panEnabled: true,
                                boundaryMargin: const EdgeInsets.all(100),
                                minScale: 0.8,
                                maxScale: 4.0,
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    children: [
                                      Card(
                                        elevation: 0,
                                        color: Colors.transparent,
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: MathText(
                                            _perguntaAtual,
                                            fontSize: 26,
                                            fontWeight: FontWeight.bold,
                                            corTexto: Theme.of(context).colorScheme.onSurface,
                                            textAlign: TextAlign.justify,
                                          ),
                                        ),
                                      ),
                                      _imagemQuestao(emZoom: true), // Passa emZoom: true aqui
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: MathText(
                                    _perguntaAtual,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    corTexto: Theme.of(context).colorScheme.onSurface,
                                    textAlign: TextAlign.justify,
                                  ),
                                ),
                              ),
                              _imagemQuestao(emZoom: false),
                            ],
                          ),
                        const SizedBox(height: 5),
                        
                        ..._alternativas.map(_botaoAlternativa),
                        const SizedBox(height: 12),
                        AppButton(
                          texto: 'CONFIRMAR RESPOSTA',
                          icone: Icons.check_circle_outline,
                          carregando: _processandoResposta,
                          onPressed: _respostaSelecionada == null ? null : _confirmarResposta,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Sequência atual: $_sequenciaAtual | Bônus: +$_bonusSequencia',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            // Camada de Fundo Branco para o Rascunho
            if (_modoRascunho && _fundoBrancoAtivo)
              Positioned.fill(
                child: Container(color: Theme.of(context).scaffoldBackgroundColor),
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
                      _paginasRascunho[_paginaAtualRascunho].add(PontoRascunho(offset: null));
                    });
                  },
                  child: Container(
                    color: Colors.transparent, 
                    child: CustomPaint(
                      painter: RascunhoPainter(_paginasRascunho[_paginaAtualRascunho]),
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