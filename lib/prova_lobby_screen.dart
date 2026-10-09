import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import 'prova_foco_screen.dart';

class ProvaLobbyScreen extends StatefulWidget {
  final String alunoOficialId; // <-- 1. VARIÁVEL ADICIONADA AQUI

  const ProvaLobbyScreen({
    super.key,
    required this.alunoOficialId, // <-- 2. EXIGIDO NO CONSTRUTOR AQUI
  });

  @override
  State<ProvaLobbyScreen> createState() => _ProvaLobbyScreenState();
}

class _ProvaLobbyScreenState extends State<ProvaLobbyScreen> {
  final _supabase = Supabase.instance.client;
  
  bool _carregando = true;
  String? _erroMensagem;
  String _logsDebug = ""; // Vai mostrar na tela o que está a acontecer
  Map<String, dynamic>? _provaAtiva;
  
  @override
  void initState() {
    super.initState();
    _carregarProva();
  }

  void _adicionarLog(String mensagem) {
    print('LOG PROVA: $mensagem');
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

      _adicionarLog("1. A verificar utilizador...");
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception("Utilizador não autenticado no Supabase.");
      }
      _adicionarLog("Utilizador logado (Perfil): $userId");
      _adicionarLog("ID Oficial recebido para a prova: ${widget.alunoOficialId}");

      _adicionarLog("2. A procurar nível do aluno na tabela 'perfis'...");
      final perfilRes = await _supabase
          .from('perfis')
          .select('nivel_atual, serie_escolar')
          .eq('id', userId)
          .maybeSingle();

      if (perfilRes == null) {
        throw Exception("Perfil não encontrado na base de dados.");
      }

      final nivelAluno = perfilRes['nivel_atual']?.toString();
      _adicionarLog("Nível atual do aluno no banco: '$nivelAluno'");

      _adicionarLog("3. A buscar provas ativas...");
      final dataAtual = DateTime.now().toUtc().toIso8601String();
      _adicionarLog("Data/Hora UTC atual: $dataAtual");

      // Consulta à base de dados
      final provasRes = await _supabase
          .from('provas_oficiais')
          .select('*')
          .eq('status', 'publicada')
          .eq('nivel_alvo', nivelAluno as Object)
          .lte('data_abertura', dataAtual)
          .gte('data_fechamento', dataAtual);

      _adicionarLog("Consulta concluída. Provas encontradas: ${provasRes.length}");

      if (provasRes.isEmpty) {
        // Se não encontrou, vamos buscar TODAS as provas só para ver o que há lá
        _adicionarLog("\n--- DIAGNÓSTICO ---");
        _adicionarLog("Nenhuma prova passou nos filtros. A procurar todas as provas no banco para comparar...");
        
        final todasAsProvas = await _supabase
            .from('provas_oficiais')
            .select('titulo, status, nivel_alvo');
            
        if (todasAsProvas.isEmpty) {
          _adicionarLog("A tabela 'provas_oficiais' está completamente VAZIA ou o RLS está a bloquear a leitura.");
        } else {
          for (var p in todasAsProvas) {
            _adicionarLog("Encontrada: '${p['titulo']}' | Status: '${p['status']}' | Nível Alvo: '${p['nivel_alvo']}'");
          }
          _adicionarLog("Compare o 'Nível Alvo' acima com o seu 'Nível atual' ($nivelAluno). Devem ser exatamente iguais!");
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
      print('===== ERRO FATAL NO LOBBY =====');
      print(e.toString());
      print(stackTrace.toString());
      
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

      // 3. AQUI ESTÁ A MUDANÇA PRINCIPAL!
      // Usamos o widget.alunoOficialId em vez do currentUser.id
      final alunoId = widget.alunoOficialId; 
      final provaId = _provaAtiva!['id'].toString();
      final tempoLim = _provaAtiva!['tempo_limite_minutos'] as int;

      // 1. Verifica se o aluno já tem uma sessão em andamento
      final sessaoExistente = await _supabase
          .from('sessoes_prova')
          .select('*')
          .eq('prova_id', provaId)
          .eq('aluno_id', alunoId) // <-- LIGA A SESSÃO AO ALUNO OFICIAL
          .maybeSingle();

      String idSessao;
      DateTime dataFimSessao;

      if (sessaoExistente != null) {
        // Se a sessão já estava bloqueada ou finalizada, não deixa entrar de novo
        if (sessaoExistente['status'] != 'em_andamento') {
          throw Exception('A sua prova já foi ${sessaoExistente['status']}. Não é possível aceder novamente.');
        }
        
        idSessao = sessaoExistente['id'].toString();
        
        // Tenta ler qualquer formato de data possível. Se falhar, usa o momento atual.
        DateTime inicio;
        try {
          final dataCrua = sessaoExistente['data_hora_inicio'] ?? sessaoExistente['created_at'] ?? sessaoExistente['criado_em'];
          inicio = DateTime.parse(dataCrua.toString());
        } catch (_) {
          inicio = DateTime.now().toUtc();
        }
        
        dataFimSessao = inicio.add(Duration(minutes: tempoLim));

      } else {
        // 2. Se não tem sessão, cria uma nova
        final novaSessao = await _supabase.from('sessoes_prova').insert({
          'prova_id': provaId,
          'aluno_id': alunoId, // <-- CRIA A SESSÃO COM O ID DO ALUNO OFICIAL
          'status': 'em_andamento',
        }).select('id').single(); // Pedimos apenas o ID de volta, ignorando datas

        idSessao = novaSessao['id'].toString();
        
        // Como o aluno acabou de iniciar a prova, o limite é o momento exato de AGORA + a duração
        dataFimSessao = DateTime.now().toUtc().add(Duration(minutes: tempoLim));
      }

      if (!mounted) return;

      // Navega para a tela de Foco
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
                  
                  // SE HOUVER ERRO DO SISTEMA (ex: Falha de conexão ou RLS)
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

                  // SE NÃO ENCONTROU A PROVA, MOSTRAR OS LOGS DE DIAGNÓSTICO
                  if (_erroMensagem == null && _provaAtiva == null) ...[
                    const Icon(Icons.search_off, color: Colors.orange, size: 60),
                    const SizedBox(height: 16),
                    const Text(
                      'Nenhuma prova disponível para si.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    const Text('Logs de Diagnóstico (Para descobrir o erro):', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade900,
                        borderRadius: BorderRadius.circular(8)
                      ),
                      child: Text(
                        _logsDebug,
                        style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 12),
                      ),
                    ),
                  ],

                  // SE ENCONTROU A PROVA COM SUCESSO
                  if (_provaAtiva != null) ...[
                    const Icon(Icons.assignment_turned_in, color: Colors.green, size: 60),
                    const SizedBox(height: 16),
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