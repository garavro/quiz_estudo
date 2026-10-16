import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfessorLiberarAcessoScreen extends StatefulWidget {
  const ProfessorLiberarAcessoScreen({super.key});

  @override
  State<ProfessorLiberarAcessoScreen> createState() => _ProfessorLiberarAcessoScreenState();
}

class _ProfessorLiberarAcessoScreenState extends State<ProfessorLiberarAcessoScreen> {
  final _supabase = Supabase.instance.client;
  
  bool _carregando = true;
  List<String> _abasTurmas = [];
  Map<String, List<Map<String, dynamic>>> _alunosAgrupados = {};
  Timer? _timerAtualizacao;

  @override
  void initState() {
    super.initState();
    _carregarAlunosDaTurma();
    
    _timerAtualizacao = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_carregando) _carregarAlunosDaTurma(silencioso: true);
    });
  }

  @override
  void dispose() {
    _timerAtualizacao?.cancel();
    super.dispose();
  }

  Future<void> _carregarAlunosDaTurma({bool silencioso = false}) async {
    if (!silencioso) setState(() => _carregando = true);

    try {
      final emailUsuario = _supabase.auth.currentUser?.email;
      if (emailUsuario == null) throw Exception("Sessão expirada.");

      // 1. Busca todos os alunos oficiais deste professor
      final respostaAlunos = await _supabase
          .from('alunos_oficiais')
          .select()
          .eq('email_professor', emailUsuario)
          .order('nome', ascending: true);

      // Se não houver alunos, paramos por aqui
      if (respostaAlunos.isEmpty) {
        if (mounted) {
           setState(() {
             _alunosAgrupados = {};
             _abasTurmas = [];
             _carregando = false;
           });
        }
        return;
      }

      // 2. Extrai os IDs dos alunos para buscar as sessões deles
      final List<String> idsAlunos = respostaAlunos.map((a) => a['id'].toString()).toList();

      // 3. Busca as sessões de prova desses alunos (para saber o status em tempo real)
      final respostaSessoes = await _supabase
          .from('sessoes_prova')
          .select('aluno_id, status')
          .filter('aluno_id', 'in', idsAlunos);

      // Cria um mapa rápido de AlunoID -> StatusDaSessão
      final Map<String, String> statusSessoes = {};
      for (var sessao in respostaSessoes) {
        statusSessoes[sessao['aluno_id'].toString()] = sessao['status'].toString();
      }

      final Map<String, List<Map<String, dynamic>>> gruposTemp = {};

      for (var aluno in respostaAlunos) {
        final serie = aluno['serie'] ?? 'Série N/A';
        final turma = aluno['turma'] ?? 'Turma N/A';
        final turno = aluno['turno'] ?? 'Turno N/A';
        final nomeAba = '$serie $turma -$turno';

        // --- LÓGICA DO STATUS REAL ---
        String statusReal = 'Não iniciada';
        final alunoIdStr = aluno['id'].toString();
        
        if (statusSessoes.containsKey(alunoIdStr)) {
           final statusBd = statusSessoes[alunoIdStr];
           if (statusBd == 'em_andamento') statusReal = 'Em andamento';
           else if (statusBd == 'finalizada') statusReal = 'Finalizada';
           else if (statusBd == 'bloqueada') statusReal = 'Bloqueada';
           else if (statusBd == 'anulada') statusReal = 'Anulada'; // Para o caso de fraude extrema
        }
        
        // Guardamos o status real para usar no visual da lista
        // Importante: Como `respostaAlunos` vem como List<Map<String,dynamic>> que pode ser read-only,
        // criamos um novo Map mutável para cada aluno.
        final Map<String, dynamic> alunoMutavel = Map<String, dynamic>.from(aluno);
        alunoMutavel['status_prova_real'] = statusReal;
        // -----------------------------

        if (!gruposTemp.containsKey(nomeAba)) {
          gruposTemp[nomeAba] = [];
        }
        gruposTemp[nomeAba]!.add(alunoMutavel);
      }

      final abasOrdenadas = gruposTemp.keys.toList()..sort();

      if (mounted) {
        setState(() {
          _alunosAgrupados = gruposTemp;
          // Só atualiza as abas na primeira vez para não quebrar a navegação do professor
          if (_abasTurmas.isEmpty) _abasTurmas = abasOrdenadas; 
          _carregando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _carregando = false);
        if (!silencioso) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Future<void> _alternarAcesso(Map<String, dynamic> aluno, bool liberar) async {
    final novoStatus = liberar ? 'liberado' : 'bloqueado';
    final statusAntigo = aluno['status_acesso'];

    setState(() => aluno['status_acesso'] = novoStatus);

    try {
      // 1. Atualiza o status de acesso na tabela principal
      await _supabase
          .from('alunos_oficiais')
          .update({'status_acesso': novoStatus})
          .eq('id', aluno['id']);
          
      // 2. SE FOR PARA LIBERAR, apaga a sessão bloqueada (se existir) para perdoar a trapaça
      if (liberar) {
         await _supabase
            .from('sessoes_prova')
            .delete()
            .eq('aluno_id', aluno['id'])
            .eq('status', 'bloqueada');
            
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('${aluno['nome']} foi liberado e a prova foi perdoada!'), backgroundColor: Colors.green)
           );
         }
      }

    } catch (e) {
      setState(() => aluno['status_acesso'] = statusAntigo);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro de conexão.'), backgroundColor: Colors.red));
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
        await _supabase.from('alunos_oficiais').update({'status_acesso': 'liberado'}).eq('id', aluno['id']);
        
        // Apaga o bloqueio de cada aluno
        await _supabase.from('sessoes_prova').delete()
          .eq('aluno_id', aluno['id']).eq('status', 'bloqueada');
      }));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Turma inteira liberada! (Trapaças perdoadas)'), backgroundColor: Colors.green));
      }
    } catch (e) {
      _carregarAlunosDaTurma(); 
    }
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
        appBar: AppBar(title: const Text('Liberar Acesso'), backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_alt_outlined, size: 80, color: Colors.grey),
              SizedBox(height: 16),
              Text('Nenhum aluno encontrado.', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    return DefaultTabController(
      length: _abasTurmas.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gestão de Provas'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: _abasTurmas.map((aba) => Tab(text: aba, icon: const Icon(Icons.class_))).toList(),
          ),
        ),
        body: TabBarView(
          children: _abasTurmas.map((aba) {
            final alunosDaAba = _alunosAgrupados[aba] ?? [];
            
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
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
                            Expanded(child: Text(aluno['nome'] ?? 'Sem Nome', style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
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
    );
  }
}