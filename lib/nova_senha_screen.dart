import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'autenticacao.dart';
import 'services/auth_service.dart' as app_auth;
import 'widgets/app_button.dart';

class NovaSenhaScreen extends StatefulWidget {
  const NovaSenhaScreen({super.key});

  @override
  State<NovaSenhaScreen> createState() => _NovaSenhaScreenState();
}

class _NovaSenhaScreenState extends State<NovaSenhaScreen> {
  final app_auth.AuthService _authService = app_auth.AuthService();

  final TextEditingController _senhaController = TextEditingController();
  final TextEditingController _confirmarSenhaController =
      TextEditingController();

  bool _ocultarSenha = true;
  bool _ocultarConfirmar = true;
  bool _carregando = false;

  @override
  void dispose() {
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  Future<void> _salvarNovaSenha() async {
    final senha = _senhaController.text;
    final confirmarSenha = _confirmarSenhaController.text;

    if (!senhaForte(senha)) {
      mostrarMensagem(
        context,
        texto:
            'A senha deve ter no mínimo 8 caracteres, uma letra maiúscula e um número.',
      );
      return;
    }

    if (senha != confirmarSenha) {
      mostrarMensagem(context, texto: 'As senhas não coincidem.');
      return;
    }

    setState(() => _carregando = true);

    try {
      await _authService.atualizarSenha(senha);

      await Supabase.instance.client.auth.signOut();

      if (!mounted) return;

      mostrarMensagem(
        context,
        texto: 'Senha atualizada com sucesso! Faça login novamente.',
        cor: corBotaoVerde,
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } on AuthException catch (erro) {
      if (!mounted) return;

      mostrarMensagem(context, texto: traduzirErroAuth(erro));
    } catch (e) {
      if (!mounted) return;

      mostrarMensagem(context, texto: 'Erro ao atualizar senha.');
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  Widget _campoSenha({
    required String hint,
    required TextEditingController controller,
    required bool ocultar,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: ocultar,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.lock_outline),
        filled: true,
        fillColor: corCampoNormal,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            ocultar ? Icons.visibility : Icons.visibility_off,
            color: Colors.grey,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: corFundoApp,
      appBar: AppBar(
        backgroundColor: corFundoApp,
        foregroundColor: Colors.black87,
        title: const Text('Nova senha'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.password_rounded,
                    size: 60,
                    color: corBotaoVerde,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Criar nova senha',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Digite e confirme sua nova senha.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 25),
                  _campoSenha(
                    hint: 'Nova senha',
                    controller: _senhaController,
                    ocultar: _ocultarSenha,
                    onToggle: () {
                      setState(() => _ocultarSenha = !_ocultarSenha);
                    },
                  ),
                  const SizedBox(height: 14),
                  _campoSenha(
                    hint: 'Confirmar nova senha',
                    controller: _confirmarSenhaController,
                    ocultar: _ocultarConfirmar,
                    onToggle: () {
                      setState(() => _ocultarConfirmar = !_ocultarConfirmar);
                    },
                  ),
                  const SizedBox(height: 22),
                  AppButton(
                    texto: 'SALVAR NOVA SENHA',
                    cor: corBotaoVerde,
                    altura: 52,
                    carregando: _carregando,
                    onPressed: _salvarNovaSenha,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
