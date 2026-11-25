import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'prova_foco_screen.dart';

class ProvaLobbyScreen extends StatefulWidget {
  final String alunoOficialId;

  const ProvaLobbyScreen({
    super.key,
    required this.alunoOficialId,
  });

  @override
  State<ProvaLobbyScreen> createState() => _ProvaLobbyScreenState();
}

class _ProvaLobbyScreenState extends State<ProvaLobbyScreen> {
  final _supabase = Supabase.instance.client;

  bool _carregando = true;
  String? _erroMensagem;
  String _logsDebug = "";
  Map<String, dynamic>? _provaAtiva;
  String? _nomeAluno;

  @override
  void initState() {
    super.initState();
    _carregarProva();
  }

  void _adicionarLog(String mensagem) {
    debugPrint('LOG PROVA: $mensagem');
    setState(() {
      _logsDebug += "$mensagem\n";
    });
  }

  Future<void> _carregarProva() async {
    try {
      setState(() {
        _carregando = true;
        _erroMensagem = null;
        _logsDebug = "";
      });

      _adicionarLog("1. A identificar aluno oficial: ${widget.alunoOficialId}");

      _adicionarLog("2. A procurar nível do aluno na tabela 'alunos_oficiais'...");
      final alunoRes = await _supabase
          .from('alunos_oficiais')
          .select('nome, nivel')
          .eq('id', widget.alunoOficialId)
          .maybeSingle();

      if (alunoRes == null) {
        throw Exception("Cadastro do aluno não encontrado na base de dados oficial.");
      }

      _nomeAluno = alunoRes['nome']?.toString();
      final nivelAluno = alunoRes['nivel']?.toString().trim();
      _adicionarLog("Aluno: '$_nomeAluno' | Nível no cadastro: '$nivelAluno'");

      if (nivelAluno == null || nivelAluno.isEmpty) {
        throw Exception("O cadastro deste aluno não possui um nível definido.");
      }

      _adicionarLog("3. A buscar provas ativas para o nível '$nivelAluno'...");
      final dataAtual = DateTime.now().toUtc().toIso8601String();
      _adicionarLog("Data/Hora UTC atual: $dataAtual");

      final provasRes = await _supabase
          .from('provas_oficiais')
          .select('*')
          .eq('status', 'publicada')
          .eq('nivel_alvo', nivelAluno)
          .lte('data_abertura', dataAtual)
          .gte('data_fechamento', dataAtual);

      _adicionarLog("Consulta concluída. Provas encontradas: ${provasRes.length}");

      if (provasRes.isEmpty) {
        _adicionarLog("\n--- DIAGNÓSTICO ---");
        _adicionarLog("Nenhuma prova passou nos filtros. A listar provas cadastradas...");

        final todasAsProvas = await _supabase
            .from('provas_oficiais')
            .select('titulo, status, nivel_alvo');

        if (todasAsProvas.isEmpty) {
          _adicionarLog("A tabela 'provas_oficiais' está vazia ou o RLS bloqueou a leitura.");
        } else {
          for (var p in todasAsProvas) {
            _adicionarLog("Encontrada: '${p['titulo']}' | Status: '${p['status']}' | Nível Alvo: '${p['nivel_alvo']}'");
          }
          _adicionarLog("Compare o 'Nível Alvo' acima com o nível do aluno ('$nivelAluno').");
        }

        setState(() {
          _provaAtiva = null;
          _carregando = false;
        });
        return;
      }

      setState(() {
        _provaAtiva = provasRes.first;
        _carregando = false;
      });
    } catch (e, stackTrace) {
      debugPrint('===== ERRO FATAL NO LOBBY =====');
      debugPrint(e.toString());
      debugPrint(stackTrace.toString());

      setState(() {
        _erroMensagem = e.toString();
        _carregando = false;
      });
    }
  }

  Future<void> _entrarNaProva() async {
    try {
      setState(() {
        _carregando = true;
        _erroMensagem = null;
      });

      final alunoId = widget.alunoOficialId;
      final provaId = _provaAtiva!['id'].toString();
      final tempoLim = _provaAtiva!['tempo_limite_minutos'] as int;

      final sessaoExistente = await _supabase
          .from('sessoes_prova')
          .select('*')
          .eq('prova_id', provaId)
          .eq('aluno_id', alunoId)
          .maybeSingle();

      String idSessao;
      DateTime dataFimSessao;

      if (sessaoExistente != null) {
        if (sessaoExistente['status'] != 'em_andamento') {
          throw Exception('A sua prova já foi ${sessaoExistente['status']}. Não é possível aceder novamente.');
        }

        idSessao = sessaoExistente['id'].toString();

        DateTime inicio;
        try {
          final dataCrua = sessaoExistente['data_hora_inicio'] ??
              sessaoExistente['created_at'] ??
              sessaoExistente['criado_em'];
          inicio = DateTime.parse(dataCrua.toString());
        } catch (_) {
          inicio = DateTime.now().toUtc();
        }

        dataFimSessao = inicio.add(Duration(minutes: tempoLim));
      } else {
        final novaSessao = await _supabase.from('sessoes_prova').insert({
          'prova_id': provaId,
          'aluno_id': alunoId,
          'status': 'em_andamento',
        }).select('id').single();

        idSessao = novaSessao['id'].toString();
        dataFimSessao = DateTime.now().toUtc().add(Duration(minutes: tempoLim));
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ProvaFocoScreen(
            provaId: provaId,
            sessaoId: idSessao,
            dataFimSessao: dataFimSessao,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _erroMensagem = e.toString();
        _carregando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sala de Espera'),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_erroMensagem != null) ...[
                    const Icon(Icons.error_outline, color: Colors.red, size: 60),
                    const SizedBox(height: 16),
                    const Text(
                      'Ops, ocorreu um erro técnico!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      color: Colors.red.shade50,
                      child: Text(
                        _erroMensagem!,
                        style: const TextStyle(color: Colors.red, fontFamily: 'monospace'),
                      ),
                    ),
                  ],

                  if (_erroMensagem == null && _provaAtiva == null) ...[
                    const Icon(Icons.search_off, color: Colors.orange, size: 60),
                    const SizedBox(height: 16),
                    const Text(
                      'Nenhuma prova disponível para você no momento.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    const Text('Logs de Diagnóstico:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade900,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _logsDebug,
                        style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 12),
                      ),
                    ),
                  ],

                  if (_provaAtiva != null) ...[
                    const Icon(Icons.assignment_turned_in, color: Colors.green, size: 60),
                    const SizedBox(height: 16),
                    if (_nomeAluno != null && _nomeAluno!.isNotEmpty) ...[
                      Text(
                        'Aluno: $_nomeAluno',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, color: Colors.black54, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      _provaAtiva!['titulo'] ?? 'Prova Oficial',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.timer),
                              title: const Text('Duração'),
                              subtitle: Text('${_provaAtiva!['tempo_limite_minutos']} minutos'),
                            ),
                            const Divider(),
                            const Text(
                              'Atenção: Ao iniciar, não poderá sair do aplicativo. Se minimizar a tela, a prova será bloqueada.',
                              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            )
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _entrarNaProva,
                      child: const Text('INICIAR PROVA AGORA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    )
                  ],
                ],
              ),
            ),
    );
  }
}