import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_radar_screen.dart';
import 'professor_liberar_acesso_screen.dart'; // Importação adicionada aqui!

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _supabase = Supabase.instance.client;
  bool _verificandoAcesso = true;
  String _nivelAcesso = 'nenhum'; // Pode ser 'admin', 'professor' ou 'nenhum'

  @override
  void initState() {
    super.initState();
    _verificarPermissao();
  }

  Future<void> _verificarPermissao() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception("Não autenticado");

      // 1. Verifica se é Admin (Acesso Total)
      final adminCheck = await _supabase
          .from('admins')
          .select('user_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (adminCheck != null) {
        if (mounted) setState(() { _nivelAcesso = 'admin'; _verificandoAcesso = false; });
        return;
      }

      // 2. Verifica se é Professor Aplicador (Acesso Restrito)
      final profCheck = await _supabase
          .from('professores_aplicadores')
          .select('user_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (profCheck != null) {
        if (mounted) setState(() { _nivelAcesso = 'professor'; _verificandoAcesso = false; });
        return;
      }

      // 3. Se não encontrou em lado nenhum, acesso negado
      if (mounted) setState(() { _nivelAcesso = 'nenhum'; _verificandoAcesso = false; });
      
    } catch (e) {
      if (mounted) setState(() { _nivelAcesso = 'nenhum'; _verificandoAcesso = false; });
    }
  }

  Widget _construirCardMenu({
    required String titulo,
    required String subtitulo,
    required IconData icone,
    required Color cor,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icone, size: 32, color: cor),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitulo,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_verificandoAcesso) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_nivelAcesso == 'nenhum') {
      return Scaffold(
        appBar: AppBar(title: const Text('Acesso Negado')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.security, size: 80, color: Colors.redAccent),
              const SizedBox(height: 16),
              const Text('Área Restrita', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Não tem permissão para aceder ao painel de gestão.'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Voltar'),
              )
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_nivelAcesso == 'admin' ? 'Painel de Administração' : 'Painel do Professor'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _nivelAcesso == 'admin' ? 'Gestão Geral' : 'Gestão de Turma',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            if (_nivelAcesso == 'professor' || _nivelAcesso == 'admin')
              _construirCardMenu(
                titulo: 'Liberar Acesso à Prova',
                subtitulo: 'Autorizar a entrada dos alunos da sua turma.',
                icone: Icons.how_to_reg,
                cor: Colors.orange,
                onTap: () {
                  // A navegação foi corrigida e formatada corretamente aqui
                  Navigator.push(
                    context, 
                    MaterialPageRoute(
                      builder: (_) => const ProfessorLiberarAcessoScreen()
                    )
                  );
                },
              ),

            // AMBOS VEEM A MONITORIZAÇÃO
            _construirCardMenu(
              titulo: 'Monitorização em Tempo Real',
              subtitulo: 'Ver logs do Anti-Cheat e alunos a realizar a prova.',
              icone: Icons.policy,
              cor: Colors.redAccent,
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminRadarScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }
}