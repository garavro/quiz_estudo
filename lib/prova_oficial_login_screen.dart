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
  final _codigoTurmaController = TextEditingController();

  bool _carregando = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _documentoController.dispose();
    _codigoTurmaController.dispose();
    super.dispose();
  }

  String _normalizarNome(String texto) {
    var s = texto.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    const comAcento = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const semAcento = 'aaaaaeeeeiiiiooooouuuucn';
    for (int i = 0; i < comAcento.length; i++) {
      s = s.replaceAll(comAcento[i], semAcento[i]);
    }
    return s;
  }

  String _formatarCpf(String digitos) {
    return '${digitos.substring(0, 3)}.'
        '${digitos.substring(3, 6)}.'
        '${digitos.substring(6, 9)}-'
        '${digitos.substring(9, 11)}';
  }

  Future<void> _validarAcesso() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _carregando = true);

    try {
      final docInformado = _documentoController.text.trim();
      final nomeInformado = _normalizarNome(_nomeController.text);
      final codigoInformado = _codigoTurmaController.text.trim().toUpperCase();

      // 1. Valida o Código da Turma gerado pelo professor
      final registroCodigo = await _supabase
          .from('codigos_aplicacao')
          .select('professor_email, professor_nome, ativo')
          .eq('codigo', codigoInformado)
          .eq('ativo', true)
          .maybeSingle();

      if (registroCodigo == null) {
        _mostrarErro('Código da turma inválido ou já encerrado pelo professor.');
        return;
      }

      // 2. Procura o aluno pelo Documento (CPF com/sem máscara ou E-mail)
      var query = _supabase.from('alunos_oficiais').select();

      if (docInformado.contains('@')) {
        query = query.ilike('documento', docInformado.toLowerCase());
      } else {
        final somenteDigitos = docInformado.replaceAll(RegExp(r'\D'), '');
        if (somenteDigitos.length == 11) {
          final cpfComMascara = _formatarCpf(somenteDigitos);
          query = query.or('documento.eq.$somenteDigitos,documento.eq.$cpfComMascara');
        } else if (somenteDigitos.isNotEmpty) {
          query = query.or('documento.eq.$somenteDigitos,documento.ilike.$docInformado');
        } else {
          query = query.ilike('documento', docInformado);
        }
      }

      final aluno = await query.limit(1).maybeSingle();

      if (aluno == null) {
        _mostrarErro('Documento ou e-mail não encontrado na lista oficial. Verifique se digitou corretamente.');
        return;
      }

      // 3. Valida o Nome do aluno
      final nomeBanco = _normalizarNome(aluno['nome']?.toString() ?? '');
      if (nomeBanco != nomeInformado) {
        _mostrarErro('O Nome informado não corresponde ao documento cadastrado.');
        return;
      }

      // 4. Registra o professor da aplicação no cadastro do aluno e libera o acesso
      final profEmail = registroCodigo['professor_email'].toString().trim().toLowerCase();
      final profNome = registroCodigo['professor_nome'].toString().trim();

      await _supabase.from('alunos_oficiais').update({
        'email_professor': profEmail,
        'professor_aplicador': profNome,
        'status_acesso': 'liberado',
      }).eq('id', aluno['id']);

      if (!mounted) return;

      final String alunoIdOficial = aluno['id'].toString();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Acesso Autorizado! Aplicador: $profNome'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ProvaLobbyScreen(alunoOficialId: alunoIdOficial),
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
                  'Acesso à Prova Oficial',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Informe seu nome completo, CPF ou e-mail cadastrado e o código fornecido pelo professor.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),

                TextFormField(
                  controller: _nomeController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Nome Completo',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _documentoController,
                  decoration: InputDecoration(
                    labelText: 'Documento (CPF ou E-mail)',
                    prefixIcon: const Icon(Icons.badge),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _codigoTurmaController,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 3),
                  decoration: InputDecoration(
                    labelText: 'Código da Turma',
                    hintText: 'Ex: A7K9P2',
                    prefixIcon: const Icon(Icons.vpn_key),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o código passado pelo professor' : null,
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