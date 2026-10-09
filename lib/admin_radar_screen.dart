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

      if (adminCheck != null) {
        if (mounted) setState(() => _tipoVisao = 'Visão Global (Admin)');
        
        // ⚠️ AJUSTE 1: Mude 'sessoes_prova' para o nome exato da sua tabela de logs de fraude
        final respostaLogs = await _supabase
            .from('provas_oficiais') 
            .select()
            .order('criado_em', ascending: false)
            .limit(50);
            
        if (mounted) {
          setState(() {
            _logs = respostaLogs;
            _carregando = false;
          });
        }
        return;
      }

      // 2. Se não é Admin, é Professor.
      if (mounted) setState(() => _tipoVisao = 'Visão da Turma (Professor)');

      // Vai buscar OS DOCUMENTOS (ou IDs) apenas dos alunos deste professor
      final alunosTurma = await _supabase
          .from('alunos_oficiais')
          .select('documento')
          .eq('email_professor', userEmail!);

      final List<String> documentosPermitidos = alunosTurma
          .map((a) => a['documento'].toString())
          .toList();

      // Se o professor não tiver alunos, o radar fica vazio.
      if (documentosPermitidos.isEmpty) {
        if (mounted) setState(() { _logs = []; _carregando = false; });
        return;
      }

      // Filtra os logs do radar usando APENAS os documentos permitidos
      // ⚠️ AJUSTE 2: Mude 'sessoes_prova' para a sua tabela de logs
      // ⚠️ AJUSTE 3: Mude 'documento_aluno' para o nome da coluna que guarda o identificador do aluno nessa tabela
      final respostaLogs = await _supabase
          .from('provas_oficiais') 
          .select()
          .filter('documento', 'in', documentosPermitidos) 
          .order('criado_em', ascending: false)
          .limit(50);

      if (mounted) {
        setState(() {
          _logs = respostaLogs;
          _carregando = false;
        });
      }

    } catch (e) {
      if (mounted) {
        setState(() => _carregando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro de sincronização: $e'), backgroundColor: Colors.redAccent)
        );
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
          // Barra de status a mostrar qual é o nível de permissão a ser exibido
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
                        
                        // ⚠️ AJUSTE 4: Verifique se as variáveis correspondem às colunas da sua tabela de logs
                        final nome = log['aluno'] ?? 'Aluno Desconhecido';
                        final acao = log['acao'] ?? 'Atividade Registada';
                        final data = log['criado_em'] != null 
                            ? DateTime.parse(log['criado_em']).toLocal().toString().split('.')[0] 
                            : '--:--';
                        
                        // Lógica visual: Se a ação incluir "saiu" ou "fraude", fica vermelho.
                        final bool critico = acao.toString().toLowerCase().contains('saiu') || 
                                             acao.toString().toLowerCase().contains('fraude');

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          elevation: critico ? 4 : 1,
                          color: critico ? Colors.red.shade50 : Colors.white,
                          child: ListTile(
                            leading: Icon(
                              critico ? Icons.warning_amber_rounded : Icons.info_outline,
                              color: critico ? Colors.red : Colors.blueGrey,
                              size: 32,
                            ),
                            title: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('$acao\n$data', style: TextStyle(color: Colors.grey.shade700)),
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