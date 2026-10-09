import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_dashboard_screen.dart';

class ProfessorLoginScreen extends StatefulWidget {
  const ProfessorLoginScreen({super.key});

  @override
  State<ProfessorLoginScreen> createState() => _ProfessorLoginScreenState();
}

class _ProfessorLoginScreenState extends State<ProfessorLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  final _emailController = TextEditingController();
  final _tokenController = TextEditingController();

  bool _carregando = false;
  bool _codigoEnviado = false; 

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _enviarCodigoParaEmail() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _carregando = true);
    
    try {
      final emailDigitado = _emailController.text.trim().toLowerCase();

      // 1. Verifica se a coordenação já cadastrou este professor na planilha
      final profCadastrado = await _supabase
          .from('professores_aplicadores')
          .select('email')
          .eq('email', emailDigitado)
          .maybeSingle();

      if (profCadastrado == null) {
        _mostrarErro('Acesso Negado: Este email não foi cadastrado pela escola na planilha oficial.');
        return;
      }

      // 2. Se existe, envia o token
      await _supabase.auth.signInWithOtp(
        email: emailDigitado,
        shouldCreateUser: true, 
      );
      
      if (!mounted) return;
      setState(() {
        _codigoEnviado = true;
        _carregando = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token enviado! Verifique o seu email.'), backgroundColor: Colors.green),
      );
    } catch (e) {
      _mostrarErro('Erro ao enviar código: $e');
    }
  }

  Future<void> _validarTokenEEntrar() async {
    if (_tokenController.text.trim().isEmpty) {
      _mostrarErro('Digite o código numérico.');
      return;
    }

    setState(() => _carregando = true);

    try {
      final emailDigitado = _emailController.text.trim().toLowerCase();

      // 1. Valida o Token
      final AuthResponse res = await _supabase.auth.verifyOTP(
        type: OtpType.email,
        email: emailDigitado,
        token: _tokenController.text.trim(),
      );

      if (res.user == null) throw Exception("Falha de autenticação.");

      // 2. Vincula a chave de segurança ao cadastro feito pela planilha
      await _supabase.from('professores_aplicadores').update({
        'user_id': res.user!.id,
      }).eq('email', emailDigitado);

      if (!mounted) return;
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
      );

    } catch (e) {
      _mostrarErro('Código inválido ou expirado. Tente novamente.');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _mostrarErro(String msg) {
    if (!mounted) return;
    setState(() => _carregando = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acesso do Professor'),
        backgroundColor: Colors.deepPurple,
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
                const Icon(Icons.co_present_rounded, size: 80, color: Colors.deepPurple),
                const SizedBox(height: 16),
                const Text(
                  'Gestão de Turma',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Insira o email cadastrado pela escola para receber a chave de acesso.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 40),

                TextFormField(
                  controller: _emailController,
                  enabled: !_codigoEnviado,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email Cadastrado', prefixIcon: Icon(Icons.email), border: OutlineInputBorder()),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Obrigatório';
                    if (!v.contains('@')) return 'Email inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                if (!_codigoEnviado)
                  SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _carregando ? null : _enviarCodigoParaEmail,
                      icon: _carregando ? const SizedBox.shrink() : const Icon(Icons.send),
                      label: _carregando 
                          ? const CircularProgressIndicator(color: Colors.white) 
                          : const Text('RECEBER TOKEN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  )
                else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade200)),
                    child: Column(
                      children: [
                        const Text('Token enviado ao seu email!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _tokenController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(hintText: '000000', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 56,
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                            onPressed: _carregando ? null : _validarTokenEEntrar,
                            icon: _carregando ? const SizedBox.shrink() : const Icon(Icons.lock_open),
                            label: _carregando 
                                ? const CircularProgressIndicator(color: Colors.white) 
                                : const Text('VALIDAR E ENTRAR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() { _codigoEnviado = false; _tokenController.clear(); }),
                    child: const Text('Corrigir email ou reenviar token'),
                  )
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}