import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminRadarScreen extends StatefulWidget {
  const AdminRadarScreen({super.key});

  @override
  State<AdminRadarScreen> createState() => _AdminRadarScreenState();
}

class _AdminRadarScreenState extends State<AdminRadarScreen> {
  final _supabase = Supabase.instance.client;
  
  bool _carregando = true;
  List<dynamic> _logs = [];
  String _tipoVisao = 'A carregar...';
  Timer? _timerAtualizacao;

  @override
  void initState() {
    super.initState();
    _carregarRadar();
    
    // Atualiza o radar automaticamente a cada 5 segundos (Tempo Real simulado)
    _timerAtualizacao = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_carregando) _carregarRadar(silencioso: true);
    });
  }

  @override
  void dispose() {
    _timerAtualizacao?.cancel();
    super.dispose();
  }

  Future<void> _carregarRadar({bool silencioso = false}) async {
    if (!silencioso) setState(() => _carregando = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      final userEmail = _supabase.auth.currentUser?.email;
      if (userId == null) throw Exception('Utilizador não autenticado');

      // 1. Verifica se quem está logado é um Administrador (Direção/TI)
      final adminCheck = await _supabase
          .from('admins')
          .select('user_id')
          .eq('user_id', userId)
          .maybeSingle();

      List<String>? idsPermitidos;

      if (adminCheck != null) {
        if (mounted) setState(() => _tipoVisao = 'Visão Global (Admin)');
      } else {
        // 2. Se não é Admin, é Professor.
        if (mounted) setState(() => _tipoVisao = 'Visão da Turma (Professor)');

        final alunosTurma = await _supabase
            .from('alunos_oficiais')
            .select('id')
            .eq('email_professor', userEmail!);

        idsPermitidos = alunosTurma.map((a) => a['id'].toString()).toList();

        if (idsPermitidos.isEmpty) {
          if (mounted) {
            setState(() {
              _logs = [];
              _carregando = false;
            });
          }
          return;
        }
      }

      // 3. Prepara a busca das sessões bloqueadas (Primeiro filtramos, DEPOIS ordenamos)
      final filterBuilder = _supabase
          .from('sessoes_prova')
          .select()
          .eq('status', 'bloqueada');

      List<dynamic> respostaLogs;

      if (idsPermitidos != null) {
        // Se for professor, aplica o filtro de IDs permitidos antes da ordenação
        respostaLogs = await filterBuilder
            .inFilter('aluno_id', idsPermitidos)
            .order('data_hora_fim', ascending: false)
            .limit(50);
      } else {
        // Se for Admin, ordena diretamente
        respostaLogs = await filterBuilder
            .order('data_hora_fim', ascending: false)
            .limit(50);
      }

      if (respostaLogs.isEmpty) {
        if (mounted) {
          setState(() {
            _logs = [];
            _carregando = false;
          });
        }
        return;
      }

      // 4. Busca os dados dos alunos infratores na tabela alunos_oficiais
      final idsInfratores = respostaLogs
          .map((log) => log['aluno_id'].toString())
          .toSet()
          .toList();

      final respostaAlunosInfratores = await _supabase
          .from('alunos_oficiais')
          .select('id, nome, documento')
          .inFilter('id', idsInfratores);

      final Map<String, Map<String, dynamic>> mapAlunos = {};
      for (var aluno in respostaAlunosInfratores) {
        mapAlunos[aluno['id'].toString()] = aluno;
      }

      // 5. Mapeia os dados do aluno para cada log de trapaça
      final List<Map<String, dynamic>> logsCompletos = [];
      for (var log in respostaLogs) {
        final logMutavel = Map<String, dynamic>.from(log);
        final alunoId = log['aluno_id'].toString();

        if (mapAlunos.containsKey(alunoId)) {
          logMutavel['alunos_oficiais'] = mapAlunos[alunoId];
        }
        logsCompletos.add(logMutavel);
      }

      if (mounted) {
        setState(() {
          _logs = logsCompletos;
          _carregando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _carregando = false);
        if (!silencioso) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro de sincronização: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Radar Anti-Cheat'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _carregarRadar(),
            tooltip: 'Atualizar Agora',
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.red.shade50,
            child: Row(
              children: [
                const Icon(Icons.security, size: 16, color: Colors.redAccent),
                const SizedBox(width: 8),
                Text(
                  _tipoVisao,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: _carregando 
              ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
              : _logs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shield_outlined, size: 80, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          const Text('Nenhuma atividade suspeita.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const Text('O radar está limpo.', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        final log = _logs[index];
                        
                        // Agora puxa o nome diretamente da tabela oficial!
                        final nome = log['alunos_oficiais']?['nome'] ?? 'Aluno Desconhecido';
                        final documento = log['alunos_oficiais']?['documento'] ?? 'Sem Doc';
                        final acao = log['motivo_bloqueio'] ?? 'Tentou sair da prova ou fechou o app';
                        final data = log['data_hora_fim'] != null 
                            ? DateTime.parse(log['data_hora_fim']).toLocal().toString().split('.')[0] 
                            : '--:--';
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          elevation: 4,
                          color: Colors.red.shade50,
                          child: ListTile(
                            leading: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 32),
                            title: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Doc: $documento\n$acao\n$data', style: TextStyle(color: Colors.grey.shade800)),
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}