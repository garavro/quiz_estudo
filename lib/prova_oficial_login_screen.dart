import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'prova_lobby_screen.dart'; 

class ProvaOficialLoginScreen extends StatefulWidget {
  const ProvaOficialLoginScreen({super.key});

  @override
  State<ProvaOficialLoginScreen> createState() => _ProvaOficialLoginScreenState();
}

class _ProvaOficialLoginScreenState extends State<ProvaOficialLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  final _nomeController = TextEditingController();
  final _documentoController = TextEditingController();
  final _escolaController = TextEditingController();
  final _serieController = TextEditingController();
  final _professorController = TextEditingController(); // NOVO CONTROLADOR

  bool _carregando = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _documentoController.dispose();
    _escolaController.dispose();
    _serieController.dispose();
    _professorController.dispose(); // NOVO CONTROLADOR
    super.dispose();
  }

  Future<void> _validarAcesso() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _carregando = true);

    try {
      final docInformado = _documentoController.text.trim();
      final nomeInformado = _nomeController.text.trim().toLowerCase();
      final escolaInformada = _escolaController.text.trim().toLowerCase();
      final serieInformada = _serieController.text.trim().toLowerCase();
      final professorInformado = _professorController.text.trim().toLowerCase(); // NOVO CAMPO

      // 1. Procura o aluno pelo Documento (CPF/Email)
      final aluno = await _supabase
          .from('alunos_oficiais')
          .select()
          .eq('documento', docInformado)
          .maybeSingle();

      // Verifica se o aluno existe
      if (aluno == null) {
        _mostrarErro('Documento não encontrado na lista oficial. Verifique se digitou corretamente.');
        return;
      }

      // NOVO: BLOQUEIO DO PROFESSOR
      final statusAtual = aluno['status_acesso']?.toString().toLowerCase() ?? 'bloqueado';
      if (statusAtual != 'liberado') {
        _mostrarErro('Acesso bloqueado! Aguarde o professor da sua turma liberar a sua prova.');
        return;
      }
      // 2. Valida se os outros dados estão corretos (ignorando maiúsculas e minúsculas)
      final nomeBanco = aluno['nome']?.toString().trim().toLowerCase() ?? '';
      final escolaBanco = aluno['escola']?.toString().trim().toLowerCase() ?? '';
      final serieBanco = aluno['serie']?.toString().trim().toLowerCase() ?? '';
      final professorBanco = aluno['professor_aplicador']?.toString().trim().toLowerCase() ?? ''; // NOVO CAMPO

      if (nomeBanco != nomeInformado) {
        _mostrarErro('O Nome informado não corresponde ao documento cadastrado.');
        return;
      }
      if (escolaBanco != escolaInformada) {
        _mostrarErro('A Escola informada não corresponde ao seu cadastro oficial.');
        return;
      }
      if (serieBanco != serieInformada) {
        _mostrarErro('A Série informada não corresponde ao seu cadastro oficial.');
        return;
      }
      if (professorBanco != professorInformado) {
        _mostrarErro('O Professor Aplicador informado não está correto.');
        return;
      }

     // 3. SE TUDO ESTIVER CORRETO, LIBERA O ACESSO!
      if (!mounted) return;
      
      final String alunoIdOficial = aluno['id']; // <-- CAPTURA O ID DA TABELA OFICIAL
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Acesso Autorizado!'), backgroundColor: Colors.green),
      );

      // Leva o aluno para o Lobby enviando o ID Oficial
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ProvaLobbyScreen(alunoOficialId: alunoIdOficial), // <-- PASSA O ID AQUI
        ),
      );

    } catch (e) {
      _mostrarErro('Erro ao validar acesso: $e');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _mostrarErro(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)), 
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Autenticação Oficial'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.security, size: 80, color: Colors.blueAccent),
                const SizedBox(height: 16),
                const Text(
                  'Acesso Restrito',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Preencha exatamente como está no seu cadastro escolar para liberar a prova.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),

                TextFormField(
                  controller: _nomeController,
                  decoration: InputDecoration(
                    labelText: 'Nome Completo',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _documentoController,
                  decoration: InputDecoration(
                    labelText: 'Documento (CPF ou Email)',
                    prefixIcon: const Icon(Icons.badge),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _escolaController,
                  decoration: InputDecoration(
                    labelText: 'Nome da Escola',
                    prefixIcon: const Icon(Icons.school),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _serieController,
                  decoration: InputDecoration(
                    labelText: 'Série / Ano',
                    prefixIcon: const Icon(Icons.class_),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                ),
                const SizedBox(height: 16),

                // NOVO CAMPO: PROFESSOR APLICADOR
                TextFormField(
                  controller: _professorController,
                  decoration: InputDecoration(
                    labelText: 'Professor Aplicador da Prova',
                    prefixIcon: const Icon(Icons.assignment_ind),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                ),
                const SizedBox(height: 32),

                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _carregando ? null : _validarAcesso,
                    child: _carregando
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'VERIFICAR ACESSO',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}