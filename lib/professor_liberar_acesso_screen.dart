import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef AlunoRegistro = Map<String, dynamic>;

class ProfessorLiberarAcessoScreen extends StatefulWidget {
  const ProfessorLiberarAcessoScreen({super.key});

  @override
  State<ProfessorLiberarAcessoScreen> createState() => _ProfessorLiberarAcessoScreenState();
}

class _ProfessorLiberarAcessoScreenState extends State<ProfessorLiberarAcessoScreen> {
  final _supabase = Supabase.instance.client;

  bool _carregando = true;
  bool _gerandoCodigo = false;
  String? _codigoAtivo;
  String _nomeProfessor = '';

  List<String> _abasTurmas = [];
  Map<String, List<AlunoRegistro>> _alunosAgrupados = {};
  Timer? _timerAtualizacao;

  @override
  void initState() {
    super.initState();
    _carregarDadosIniciais();

    _timerAtualizacao = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_carregando && !_gerandoCodigo) {
        _carregarAlunosDaTurma(silencioso: true);
      }
    });
  }

  @override
  void dispose() {
    _timerAtualizacao?.cancel();
    super.dispose();
  }

  Future<void> _carregarDadosIniciais() async {
    setState(() => _carregando = true);
    await Future.wait([
      _carregarCodigoAtivo(),
      _carregarAlunosDaTurma(silencioso: true),
    ]);
    if (mounted) setState(() => _carregando = false);
  }

  Future<void> _carregarCodigoAtivo() async {
    try {
      final emailUsuario = _supabase.auth.currentUser?.email?.trim().toLowerCase();
      if (emailUsuario == null) return;

      final profData = await _supabase
          .from('professores_aplicadores')
          .select('nome')
          .ilike('email', emailUsuario)
          .maybeSingle();

      final codigoData = await _supabase
          .from('codigos_aplicacao')
          .select('codigo')
          .ilike('professor_email', emailUsuario)
          .eq('ativo', true)
          .order('criado_em', ascending: false)
          .limit(1)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _nomeProfessor = profData?['nome']?.toString() ?? emailUsuario;
          _codigoAtivo = codigoData?['codigo']?.toString();
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar código ativo: $e');
    }
  }

  String _gerarStringAleatoria() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    return List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  Future<void> _gerarNovoCodigo() async {
    final user = _supabase.auth.currentUser;
    final emailUsuario = user?.email?.trim().toLowerCase();
    if (emailUsuario == null) return;

    setState(() => _gerandoCodigo = true);

    try {
      await _supabase
          .from('codigos_aplicacao')
          .update({
            'ativo': false,
            'encerrado_em': DateTime.now().toUtc().toIso8601String(),
          })
          .ilike('professor_email', emailUsuario)
          .eq('ativo', true);

      String novoCodigo = '';
      bool inserido = false;

      for (int tentativa = 0; tentativa < 5; tentativa++) {
        novoCodigo = _gerarStringAleatoria();
        try {
          await _supabase.from('codigos_aplicacao').insert({
            'codigo': novoCodigo,
            'professor_email': emailUsuario,
            'professor_nome': _nomeProfessor.isNotEmpty ? _nomeProfessor : emailUsuario,
            'professor_user_id': user!.id,
            'ativo': true,
          });
          inserido = true;
          break;
        } catch (_) {
          // Repete caso haja colisão de código
        }
      }

      if (!inserido) {
        throw Exception('Não foi possível gerar um código único. Tente novamente.');
      }

      if (mounted) {
        setState(() {
          _codigoAtivo = novoCodigo;
          _gerandoCodigo = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Código $novoCodigo gerado! Informe-o à turma.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _gerandoCodigo = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar código: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _encerrarCodigoAtivo() async {
    final emailUsuario = _supabase.auth.currentUser?.email?.trim().toLowerCase();
    if (emailUsuario == null || _codigoAtivo == null) return;

    setState(() => _gerandoCodigo = true);

    try {
      await _supabase
          .from('codigos_aplicacao')
          .update({
            'ativo': false,
            'encerrado_em': DateTime.now().toUtc().toIso8601String(),
          })
          .ilike('professor_email', emailUsuario)
          .eq('ativo', true);

      if (mounted) {
        setState(() {
          _codigoAtivo = null;
          _gerandoCodigo = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Código encerrado. Novos alunos não poderão entrar com ele.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _gerandoCodigo = false);
    }
  }

  Future<void> _carregarAlunosDaTurma({bool silencioso = false}) async {
    if (!silencioso) setState(() => _carregando = true);

    try {
      final emailUsuario = _supabase.auth.currentUser?.email?.trim().toLowerCase();
      if (emailUsuario == null) throw Exception("Sessão expirada.");

      final respostaAlunos = await _supabase
          .from('alunos_oficiais')
          .select()
          .ilike('email_professor', emailUsuario)
          .order('nome', ascending: true);

      if (respostaAlunos.isEmpty) {
        if (mounted) {
          setState(() {
            _alunosAgrupados = {};
            _abasTurmas = [];
            if (!silencioso) _carregando = false;
          });
        }
        return;
      }

      final List<String> idsAlunos = respostaAlunos.map((a) => a['id'].toString()).toList();

      final respostaSessoes = await _supabase
          .from('sessoes_prova')
          .select('aluno_id, status')
          .inFilter('aluno_id', idsAlunos);

      final Map<String, String> statusSessoes = {};
      for (var sessao in respostaSessoes) {
        statusSessoes[sessao['aluno_id'].toString()] = sessao['status'].toString();
      }

      final Map<String, List<AlunoRegistro>> gruposTemp = {};

      for (var aluno in respostaAlunos) {
        final nivelOuSerie = (aluno['nivel'] != null && aluno['nivel'].toString().trim().isNotEmpty)
            ? aluno['nivel'].toString().trim()
            : (aluno['serie']?.toString().trim() ?? 'Nível N/A');
        final turma = aluno['turma']?.toString().trim() ?? 'Turma N/A';
        final turno = aluno['turno']?.toString().trim() ?? 'Turno N/A';
        final nomeAba = '$nivelOuSerie • $turma ($turno)';

        String statusReal = 'Não iniciada';
        final alunoIdStr = aluno['id'].toString();

        if (statusSessoes.containsKey(alunoIdStr)) {
          final statusBd = statusSessoes[alunoIdStr];
          if (statusBd == 'em_andamento') {
            statusReal = 'Em andamento';
          } else if (statusBd == 'finalizada') {
            statusReal = 'Finalizada';
          } else if (statusBd == 'bloqueada') {
            statusReal = 'Bloqueada';
          } else if (statusBd == 'anulada') {
            statusReal = 'Anulada';
          }
        }

        final AlunoRegistro alunoMutavel = AlunoRegistro.from(aluno);
        alunoMutavel['status_prova_real'] = statusReal;

        gruposTemp.putIfAbsent(nomeAba, () => []);
        gruposTemp[nomeAba]!.add(alunoMutavel);
      }

      final abasOrdenadas = gruposTemp.keys.toList()..sort();

      if (mounted) {
        setState(() {
          _alunosAgrupados = gruposTemp;
          _abasTurmas = abasOrdenadas;
          if (!silencioso) _carregando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        if (!silencioso) {
          setState(() => _carregando = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _alternarAcesso(AlunoRegistro aluno, bool liberar) async {
    final novoStatus = liberar ? 'liberado' : 'bloqueado';
    final statusAntigo = aluno['status_acesso'];

    setState(() => aluno['status_acesso'] = novoStatus);

    try {
      await _supabase
          .from('alunos_oficiais')
          .update({'status_acesso': novoStatus})
          .eq('id', aluno['id']);

      if (liberar) {
        await _supabase
            .from('sessoes_prova')
            .delete()
            .eq('aluno_id', aluno['id'])
            .eq('status', 'bloqueada');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${aluno['nome']} liberado e eventual bloqueio removido!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => aluno['status_acesso'] = statusAntigo);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro de conexão.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _liberarTurmaCompleta(String nomeAba) async {
    final alunosDaAba = _alunosAgrupados[nomeAba] ?? [];

    setState(() {
      for (var aluno in alunosDaAba) {
        aluno['status_acesso'] = 'liberado';
      }
    });

    try {
      await Future.wait(alunosDaAba.map((aluno) async {
        await _supabase
            .from('alunos_oficiais')
            .update({'status_acesso': 'liberado'})
            .eq('id', aluno['id']);
        await _supabase
            .from('sessoes_prova')
            .delete()
            .eq('aluno_id', aluno['id'])
            .eq('status', 'bloqueada');
      }));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Turma inteira liberada!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      _carregarAlunosDaTurma();
    }
  }

  Widget _construirCardCodigoTurma() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.deepPurple.shade200, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.vpn_key_rounded, color: Colors.deepPurple),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Código de Acesso da Turma',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                ),
              ),
              if (_codigoAtivo != null)
                TextButton.icon(
                  onPressed: _gerandoCodigo ? null : _encerrarCodigoAtivo,
                  icon: const Icon(Icons.stop_circle_outlined, size: 18, color: Colors.red),
                  label: const Text('Encerrar', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_codigoAtivo != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.deepPurple.shade100),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SelectableText(
                    _codigoAtivo!,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 6,
                      color: Colors.deepPurple,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copiar código',
                    icon: const Icon(Icons.copy, color: Colors.deepPurple),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _codigoAtivo!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Código copiado para a área de transferência!')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Informe este código aos alunos. Ao digitá-lo na prova, eles serão vinculados automaticamente a você.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ] else ...[
            const Text(
              'Nenhum código ativo no momento. Gere um código para que os alunos da sua turma iniciem a prova.',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ],
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _gerandoCodigo ? null : _gerarNovoCodigo,
            icon: _gerandoCodigo
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: Text(
              _codigoAtivo == null ? 'GERAR CÓDIGO DA TURMA' : 'GERAR NOVO CÓDIGO',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirIndicadorStatus(String status) {
    Color cor;
    IconData icone;

    switch (status.toLowerCase()) {
      case 'em andamento':
        cor = Colors.blue;
        icone = Icons.edit_document;
        break;
      case 'finalizada':
        cor = Colors.green;
        icone = Icons.check_circle;
        break;
      case 'ausente/fraude':
      case 'bloqueada':
        cor = Colors.red;
        icone = Icons.warning_amber_rounded;
        break;
      default:
        cor = Colors.grey;
        icone = Icons.schedule;
    }

    return Tooltip(
      message: 'Status: $status',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 14, color: cor),
            const SizedBox(width: 4),
            Text(status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: cor)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.deepPurple)));
    }

    if (_abasTurmas.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Gestão de Provas'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _carregarDadosIniciais,
              tooltip: 'Atualizar',
            ),
          ],
        ),
        body: Column(
          children: [
            _construirCardCodigoTurma(),
            const Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_alt_outlined, size: 72, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Nenhum aluno vinculado ainda.',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Assim que os alunos informarem o código gerado acima, eles aparecerão aqui automaticamente.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return DefaultTabController(
      key: ValueKey(_abasTurmas.join('|')),
      length: _abasTurmas.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gestão de Provas'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _carregarDadosIniciais,
              tooltip: 'Atualizar',
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: _abasTurmas.map((aba) => Tab(text: aba, icon: const Icon(Icons.class_))).toList(),
          ),
        ),
        body: Column(
          children: [
            _construirCardCodigoTurma(),
            Expanded(
              child: TabBarView(
                children: _abasTurmas.map((aba) {
                  final alunosDaAba = _alunosAgrupados[aba] ?? [];

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 46),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _liberarTurmaCompleta(aba),
                          icon: const Icon(Icons.lock_open),
                          label: Text('LIBERAR TODOS: $aba', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: alunosDaAba.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final aluno = alunosDaAba[index];
                            final estaLiberado = aluno['status_acesso'] == 'liberado';
                            final statusDaProva = aluno['status_prova_real'] ?? 'Não iniciada';

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: estaLiberado ? Colors.green.shade100 : Colors.red.shade100,
                                child: Icon(
                                  estaLiberado ? Icons.check_circle : Icons.lock,
                                  color: estaLiberado ? Colors.green : Colors.red,
                                ),
                              ),
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      aluno['nome'] ?? 'Sem Nome',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  _construirIndicadorStatus(statusDaProva),
                                ],
                              ),
                              subtitle: Text('Doc: ${aluno['documento']}'),
                              trailing: Switch(
                                activeColor: Colors.green,
                                inactiveThumbColor: Colors.redAccent,
                                value: estaLiberado,
                                onChanged: (valor) => _alternarAcesso(aluno, valor),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}