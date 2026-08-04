import 'dart:async';

import 'package:flutter/material.dart';

import 'services/level_service.dart';
import 'services/ranking_service.dart';

class PlacarScreen extends StatefulWidget {
  const PlacarScreen({super.key});

  @override
  State<PlacarScreen> createState() => _PlacarScreenState();
}

class _PlacarScreenState extends State<PlacarScreen> {
  final RankingService _rankingService = RankingService();

  bool _carregando = true;
  List<dynamic> _ranking = [];

  Timer? _timerAtualizacao;

  int _filtroSelecionado = 0;

  static final List<_FiltroRanking> _filtros = [
    const _FiltroRanking(
      titulo: 'Geral',
      subtitulo: 'Todos os jogadores',
      nivel: null,
    ),
    const _FiltroRanking(
      titulo: 'Nível I',
      subtitulo: '4º e 5º ano',
      nivel: LevelService.nivel1,
    ),
    const _FiltroRanking(
      titulo: 'Nível II',
      subtitulo: '6º e 7º ano',
      nivel: LevelService.nivel2,
    ),
    const _FiltroRanking(
      titulo: 'Nível III',
      subtitulo: '8º e 9º ano',
      nivel: LevelService.nivel3,
    ),
    const _FiltroRanking(
      titulo: 'Nível IV',
      subtitulo: 'Ensino Médio',
      nivel: LevelService.nivel4,
    ),
  ];

  @override
  void initState() {
    super.initState();

    _buscarRanking();

    _timerAtualizacao = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _buscarRanking(silencioso: true),
    );
  }

  @override
  void dispose() {
    _timerAtualizacao?.cancel();
    super.dispose();
  }

  Future<void> _buscarRanking({
    bool silencioso = false,
  }) async {
    if (!silencioso && mounted) {
      setState(() => _carregando = true);
    }

    try {
      final filtro = _filtros[_filtroSelecionado];

      final ranking = filtro.nivel == null
          ? await _rankingService.buscarTop10()
          : await _rankingService.buscarTop10PorNivel(
              nivel: filtro.nivel!,
            );

      if (!mounted) return;

      setState(() {
        _ranking = ranking;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _carregando = false);

      if (!silencioso) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao carregar ranking. Tente novamente.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _trocarFiltro(int index) {
    if (_filtroSelecionado == index) return;

    setState(() {
      _filtroSelecionado = index;
      _ranking = [];
    });

    _buscarRanking();
  }

  int _lerPontuacao(dynamic valor) {
    if (valor == null) return 0;
    if (valor is int) return valor;
    if (valor is double) return valor.toInt();
    if (valor is num) return valor.toInt();

    return int.tryParse(valor.toString()) ?? 0;
  }

  String _lerTexto(
    dynamic valor, {
    required String padrao,
  }) {
    final texto = valor?.toString().trim() ?? '';

    if (texto.isEmpty) {
      return padrao;
    }

    return texto;
  }

  String _nomeNivel(dynamic valor) {
    final nivel = valor?.toString().trim() ?? '';

    if (nivel.isEmpty) {
      return 'Nível não definido';
    }

    return LevelService.nomeNivel(nivel);
  }

  Color _corTitulo(String titulo) {
    switch (titulo) {
      case LevelService.tituloLenda:
        return Colors.purple;
      case LevelService.tituloVeterano:
        return Colors.deepOrange;
      case LevelService.tituloHabilitado:
        return Colors.blueAccent;
      case LevelService.tituloIniciante:
      default:
        return Colors.green;
    }
  }

  IconData _iconeTitulo(String titulo) {
    switch (titulo) {
      case LevelService.tituloLenda:
        return Icons.workspace_premium_rounded;
      case LevelService.tituloVeterano:
        return Icons.military_tech_rounded;
      case LevelService.tituloHabilitado:
        return Icons.school_rounded;
      case LevelService.tituloIniciante:
      default:
        return Icons.flag_rounded;
    }
  }

  Widget _construirTrofeu(int posicao) {
    if (posicao == 1) {
      return const Icon(
        Icons.emoji_events,
        color: Color(0xFFFFD700),
        size: 36,
      );
    }

    if (posicao == 2) {
      return const Icon(
        Icons.emoji_events,
        color: Color(0xFFC0C0C0),
        size: 36,
      );
    }

    if (posicao == 3) {
      return const Icon(
        Icons.emoji_events,
        color: Color(0xFFCD7F32),
        size: 36,
      );
    }

    return CircleAvatar(
      backgroundColor: Colors.blue.withValues(alpha: 0.10),
      child: Text(
        '$posicaoº',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.blueAccent,
        ),
      ),
    );
  }

  Color _corBorda(int posicao) {
    if (posicao == 1) {
      return const Color(0xFFFFD700);
    }

    if (posicao == 2) {
      return const Color(0xFFC0C0C0);
    }

    if (posicao == 3) {
      return const Color(0xFFCD7F32);
    }

    return Colors.transparent;
  }

  Widget _seletorRanking() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _filtros.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final filtro = _filtros[index];
          final selecionado = _filtroSelecionado == index;

          return ChoiceChip(
            selected: selecionado,
            label: Text(filtro.titulo),
            selectedColor: Theme.of(context).colorScheme.primary,
            labelStyle: TextStyle(
              color: selecionado
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
            onSelected: (_) => _trocarFiltro(index),
          );
        },
      ),
    );
  }

  Widget _cabecalhoRanking(BuildContext context) {
    final filtro = _filtros[_filtroSelecionado];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
      child: Column(
        children: [
          Icon(
            Icons.leaderboard_rounded,
            size: 72,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 10),
          Text(
            filtro.titulo == 'Geral'
                ? 'Ranking Geral'
                : 'Ranking ${filtro.titulo}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            filtro.subtitulo,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
          ),
          const SizedBox(height: 20),
          _seletorRanking(),
        ],
      ),
    );
  }

  Widget _badgeTitulo(String titulo) {
    final cor = _corTitulo(titulo);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cor.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _iconeTitulo(titulo),
            size: 15,
            color: cor,
          ),
          const SizedBox(width: 4),
          Text(
            titulo,
            style: TextStyle(
              fontSize: 12,
              color: cor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemRanking(
    BuildContext context,
    dynamic jogador,
    int index,
  ) {
    final posicao = index + 1;

    final nome = _lerTexto(
      jogador['nome_completo'],
      padrao: 'Jogador Anônimo',
    );

    final pontos = _lerPontuacao(jogador['pontuacao_total']);

    final serie = _lerTexto(
      jogador['serie_escolar'],
      padrao: 'Série não informada',
    );

    final nivel = _nomeNivel(jogador['nivel_atual']);

    final titulo = _lerTexto(
      jogador['titulo_atual'],
      padrao: LevelService.tituloIniciante,
    );

    final top3 = posicao <= 3;

    return Card(
      elevation: top3 ? 5 : 1.5,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: _corBorda(posicao),
          width: top3 ? 2 : 0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        child: Row(
          children: [
            _construirTrofeu(posicao),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nome,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: top3 ? FontWeight.bold : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '$nivel • $serie',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _badgeTitulo(titulo),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '$pontos pts',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _estadoVazio() {
    final filtro = _filtros[_filtroSelecionado];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(30),
      children: [
        _cabecalhoRanking(context),
        const SizedBox(height: 50),
        const Icon(
          Icons.emoji_events_outlined,
          size: 90,
          color: Colors.grey,
        ),
        const SizedBox(height: 20),
        Text(
          filtro.nivel == null
              ? 'Nenhum jogador no ranking ainda.'
              : 'Nenhum jogador encontrado em ${filtro.titulo}.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Quando os jogadores pontuarem, eles aparecerão aqui.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _listaRanking(BuildContext context) {
    if (_ranking.isEmpty) {
      return _estadoVazio();
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      itemCount: _ranking.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _cabecalhoRanking(context);
        }

        final jogador = _ranking[index - 1];

        return _itemRanking(
          context,
          jogador,
          index - 1,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtro = _filtros[_filtroSelecionado];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          filtro.titulo == 'Geral'
              ? 'Placar Geral'
              : 'Placar - ${filtro.titulo}',
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Atualizar ranking',
            onPressed: _carregando ? null : () => _buscarRanking(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _carregando
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: () => _buscarRanking(),
              child: _listaRanking(context),
            ),
    );
  }
}

class _FiltroRanking {
  final String titulo;
  final String subtitulo;
  final String? nivel;

  const _FiltroRanking({
    required this.titulo,
    required this.subtitulo,
    required this.nivel,
  });
}