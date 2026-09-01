import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'resultado_screen.dart';
import 'services/anti_cheat_service.dart';
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
  
  // Variáveis do rascunho
  bool _modoRascunho = false;
  List<Offset?> _pontos = [];

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
    AntiCheatService.ativarProtecao();

    _questoes = List<dynamic>.from(widget.questoes)..shuffle();

    if (_questoes.isNotEmpty) {
      _prepararQuestao();
    }
  }

  String? _resolverImagemUrl(dynamic valor) {
    if (valor == null) return null;

    final texto = valor.toString().trim();
    final textoMinusculo = texto.toLowerCase();

    if (texto.isEmpty || textoMinusculo == 'null' || textoMinusculo == 'empty') {
      return null;
    }

    if (texto.startsWith('http://') || texto.startsWith('https://')) {
      return texto;
    }

    if (texto.startsWith('questoes-imagens/')) {
      return 'https://ojkkstibwifhbplakjfw.supabase.co/storage/v1/object/public/$texto';
    }

    if (texto.startsWith('nivel_')) {
      return '$_bucketQuestoesImagensUrl$texto';
    }

    return '$_bucketImagensAntigasUrl$texto';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AntiCheatService.desativarProtecao();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (_finalizando || _antiColaAcionado) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _encerrarPorSaidaDoApp();
    }
  }

  int get _multiplicadorDificuldade {
    return ScoreService.multiplicadorPorDificuldade(widget.dificuldade);
  }

  int get _bonusRodada {
    return ScoreService.calcularBonusRodada(
      acertos: _certas,
      totalQuestoes: _questoes.length,
    );
  }

  int get _pontuacaoRodada {
    return ScoreService.calcularPontuacaoRodada(
      acertos: _certas,
      erros: _erradas,
      totalQuestoes: _questoes.length,
      bonusSequencia: _bonusSequencia,
      dificuldade: widget.dificuldade,
    );
  }

  String _lerTexto(dynamic valor) {
    if (valor == null) return '';
    return valor.toString();
  }

  int? _lerId(dynamic valor) {
    if (valor == null) return null;
    if (valor is int) return valor;
    if (valor is num) return valor.toInt();
    return int.tryParse(valor.toString());
  }

  void _prepararQuestao() {
    if (_index >= _questoes.length) return;

    final q = _questoes[_index];

    _perguntaAtual = _lerTexto(q['pergunta']);
    _imagemUrl = _lerTexto(q['imagem_url']);
    _respostaSelecionada = null;

    _alternativas = [
      _lerTexto(q['alternativa_correta']),
      _lerTexto(q['alternativa_errada1']),
      _lerTexto(q['alternativa_errada2']),
      _lerTexto(q['alternativa_errada3']),
      _lerTexto(q['alternativa_errada4']),
    ].where((alternativa) => alternativa.trim().isNotEmpty).toList();

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
        const SnackBar(
          content: Text('Selecione uma alternativa antes de confirmar.'),
        ),
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

      if (_sequenciaAtual > _maiorSequencia) {
        _maiorSequencia = _sequenciaAtual;
      }

      if (_sequenciaAtual % _quantidadeParaBonusSequencia == 0) {
        _bonusSequencia++;
      }
    } else {
      _erradas++;
      _sequenciaAtual = 0;
    }

    _historicoRespostas.add({
      'questao_id': _lerId(q['id']),
      'nivel_questao': _lerTexto(q['nivel']).isEmpty
          ? widget.nivelAtual
          : _lerTexto(q['nivel']),
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
        
        // Limpa o rascunho e desativa ao passar de questão
        _pontos.clear();
        _modoRascunho = false;
      });
    } else {
      setState(() {
        _processandoResposta = false;
        _finalizando = true;
      });

      await _mostrarFimDeJogo();
    }
  }

  Future<void> _encerrarPorSaidaDoApp() async {
    if (_antiColaAcionado || _finalizando) return;

    _antiColaAcionado = true;

    if (mounted) {
      setState(() {
        _finalizando = true;
      });
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('anti_cheat_acionado', true);

    await AntiCheatService.desativarProtecao();

    if (!mounted) return;

    Navigator.of(context).popUntil((route) => route.isFirst);
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

        final pontosGanhos = _pontuacaoRodada;

        if (pontosGanhos > 0) {
          await _rankingService.atualizarPontuacao(
            usuarioId: usuarioAtual.id,
            pontosGanhos: pontosGanhos,
          );
        }

        final novoStatus = await _progressService.calcularNovoNivelETitulo(
          usuarioId: usuarioAtual.id,
          nivelAtual: widget.nivelAtual,
        );

        nivelFinal = novoStatus['nivel'] ?? widget.nivelAtual;
        tituloFinal = novoStatus['titulo'] ?? LevelService.tituloIniciante;
        houveAvancoNivel = nivelFinal != widget.nivelAtual;

        await _authService.atualizarNivelETitulo(
          nivelAtual: nivelFinal,
          tituloAtual: tituloFinal,
        );
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

  Widget _imagemQuestao() {
    final urlCompleta = _resolverImagemUrl(_imagemUrl);

    if (urlCompleta == null) {
      return const SizedBox.shrink();
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
            child: Image.network(
              urlCompleta,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;

                return const SizedBox(
                  height: 180,
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                debugPrint('Erro ao carregar imagem da questão: $error');
                debugPrint('URL da imagem: $urlCompleta');

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
                        Icon(
                          Icons.broken_image,
                          size: 56,
                          color: Colors.redAccent,
                        ),
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
            ),
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
          backgroundColor: selecionada
              ? Colors.amber
              : colorScheme.surfaceContainerHighest,
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
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: progresso,
            minHeight: 10,
          ),
        ),
      ],
    );
  }

  Widget _telaSemQuestoes() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jogo'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.quiz_outlined,
                size: 80,
                color: Colors.grey,
              ),
              const SizedBox(height: 20),
              const Text(
                'Nenhuma questão disponível.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              AppButton(
                texto: 'VOLTAR',
                largura: 220,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _nomeDificuldade() {
    switch (widget.dificuldade) {
      case 'medio':
        return 'Médio';
      case 'dificil':
        return 'Difícil';
      case 'facil':
      default:
        return 'Fácil';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_questoes.isEmpty) {
      return _telaSemQuestoes();
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
            IconButton(
              icon: Icon(
                _modoRascunho ? Icons.edit_off : Icons.edit,
                color: _modoRascunho ? Colors.orange : null,
              ),
              tooltip: 'Rascunho',
              onPressed: () {
                setState(() {
                  _modoRascunho = !_modoRascunho;
                  if (!_modoRascunho) {
                    _pontos.clear(); // Apaga o rascunho ao desativar
                  }
                });
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 700,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _barraProgresso(),
                        const SizedBox(height: 25),
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
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
                        _imagemQuestao(),
                        const SizedBox(height: 5),
                        ..._alternativas.map(_botaoAlternativa),
                        const SizedBox(height: 12),
                        AppButton(
                          texto: 'CONFIRMAR RESPOSTA',
                          icone: Icons.check_circle_outline,
                          carregando: _processandoResposta,
                          onPressed: _respostaSelecionada == null
                              ? null
                              : _confirmarResposta,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Sequência atual: $_sequenciaAtual | Bônus: +$_bonusSequencia',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            // Camada do Rascunho
            if (_modoRascunho)
              Positioned.fill(
                child: GestureDetector(
                  onPanStart: (details) {
                    setState(() {
                      _pontos.add(details.localPosition);
                    });
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      _pontos.add(details.localPosition);
                    });
                  },
                  onPanEnd: (details) {
                    setState(() {
                      _pontos.add(null);
                    });
                  },
                  child: Container(
                    color: Colors.transparent, // Necessário para detectar toques
                    child: CustomPaint(
                      painter: RascunhoPainter(_pontos),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Classe que desenha o rascunho, colocada FORA da classe _JogarScreenState
class RascunhoPainter extends CustomPainter {
  final List<Offset?> pontos;

  RascunhoPainter(this.pontos);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueAccent
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    for (int i = 0; i < pontos.length - 1; i++) {
      if (pontos[i] != null && pontos[i + 1] != null) {
        canvas.drawLine(pontos[i]!, pontos[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant RascunhoPainter oldDelegate) {
    return true; 
  }
}