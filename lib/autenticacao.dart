import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'menu_screen.dart';
import 'services/auth_service.dart' as app_auth;
import 'widgets/app_button.dart';

const Color corFundoApp = Color.fromRGBO(242, 245, 250, 1);
const Color corCampoNormal = Color.fromRGBO(237, 240, 245, 1);
const Color corCampoErro = Color.fromRGBO(255, 217, 217, 1);
const Color corBotaoAzul = Color.fromRGBO(36, 115, 237, 1);
const Color corBotaoVerde = Color.fromRGBO(38, 173, 97, 1);

String traduzirErroAuth(AuthException erro) {
  final mensagem = erro.message.toLowerCase();

  if (mensagem.contains('invalid login credentials') ||
      mensagem.contains('invalid credentials')) {
    return 'E-mail ou senha incorretos.';
  }

  if (mensagem.contains('email not confirmed')) {
    return 'Confirme seu e-mail antes de fazer login.';
  }

  if (mensagem.contains('user already registered') ||
      mensagem.contains('already registered')) {
    return 'Este e-mail já está cadastrado.';
  }

  if (mensagem.contains('password')) {
    return 'A senha informada não atende aos requisitos.';
  }

  if (mensagem.contains('email')) {
    return 'Verifique o e-mail informado.';
  }

  return erro.message;
}

bool emailValido(String email) {
  final padraoEmail = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  return padraoEmail.hasMatch(email.trim());
}

bool dataNascimentoValida(String data) {
  final partes = data.split('/');

  if (partes.length != 3) return false;

  final dia = int.tryParse(partes[0]);
  final mes = int.tryParse(partes[1]);
  final ano = int.tryParse(partes[2]);

  if (dia == null || mes == null || ano == null) return false;

  final anoAtual = DateTime.now().year;

  if (ano < 1900 || ano > anoAtual) return false;
  if (mes < 1 || mes > 12) return false;
  if (dia < 1 || dia > 31) return false;

  try {
    final dataConvertida = DateTime(ano, mes, dia);

    return dataConvertida.day == dia &&
        dataConvertida.month == mes &&
        dataConvertida.year == ano;
  } catch (_) {
    return false;
  }
}

String converterDataParaBanco(String data) {
  final partes = data.split('/');

  final dia = partes[0].padLeft(2, '0');
  final mes = partes[1].padLeft(2, '0');
  final ano = partes[2];

  return '$ano-$mes-$dia';
}

class DataNascimentoFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String numeros = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (numeros.length > 8) {
      numeros = numeros.substring(0, 8);
    }

    String texto = '';

    for (int i = 0; i < numeros.length; i++) {
      if (i == 2 || i == 4) {
        texto += '/';
      }

      texto += numeros[i];
    }

    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

bool senhaForte(String senha) {
  final possuiMaiuscula = RegExp(r'[A-Z]').hasMatch(senha);
  final possuiNumero = RegExp(r'[0-9]').hasMatch(senha);

  return senha.length >= 8 && possuiMaiuscula && possuiNumero;
}

void mostrarMensagem(
  BuildContext context, {
  required String texto,
  Color cor = Colors.redAccent,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(texto),
      backgroundColor: cor,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

// ==========================================
// TELA DE LOGIN
// ==========================================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final app_auth.AuthService _authService = app_auth.AuthService();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();

  bool _ocultarSenha = true;
  bool _carregando = false;

  bool _erroEmail = false;
  bool _erroSenha = false;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _realizarLogin() async {
    final email = _emailController.text.trim();
    final senha = _senhaController.text;

    setState(() {
      _erroEmail = !emailValido(email);
      _erroSenha = senha.isEmpty;
    });

    if (_erroEmail || _erroSenha) {
      mostrarMensagem(context, texto: 'Informe um e-mail válido e uma senha.');
      return;
    }

    setState(() => _carregando = true);

    try {
      await _authService.login(email: email, senha: senha);

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MenuScreen()),
        (route) => false,
      );
    } on AuthException catch (erro) {
      if (!mounted) return;

      mostrarMensagem(context, texto: traduzirErroAuth(erro));
    } catch (e) {
      if (!mounted) return;

      mostrarMensagem(context, texto: 'Erro inesperado ao fazer login.');
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  Widget _campoEmail() {
    return TextField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autocorrect: false,
      decoration: InputDecoration(
        hintText: 'E-mail',
        prefixIcon: const Icon(Icons.email_outlined),
        filled: true,
        fillColor: _erroEmail ? corCampoErro : corCampoNormal,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: (_) {
        if (_erroEmail) {
          setState(() => _erroEmail = false);
        }
      },
    );
  }

  Widget _campoSenha() {
    return TextField(
      controller: _senhaController,
      obscureText: _ocultarSenha,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) {
        if (!_carregando) {
          _realizarLogin();
        }
      },
      decoration: InputDecoration(
        hintText: 'Senha',
        prefixIcon: const Icon(Icons.lock_outline),
        filled: true,
        fillColor: _erroSenha ? corCampoErro : corCampoNormal,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _ocultarSenha ? Icons.visibility : Icons.visibility_off,
            color: Colors.grey,
          ),
          onPressed: () {
            setState(() => _ocultarSenha = !_ocultarSenha);
          },
        ),
      ),
      onChanged: (_) {
        if (_erroSenha) {
          setState(() => _erroSenha = false);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: corFundoApp,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
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
                    Icons.school_rounded,
                    size: 56,
                    color: corBotaoAzul,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Bem-vindo!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Faça login para continuar',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 28),
                  _campoEmail(),
                  const SizedBox(height: 15),
                  _campoSenha(),
                  const SizedBox(height: 22),
                  AppButton(
                    texto: 'ENTRAR',
                    cor: corBotaoAzul,
                    altura: 52,
                    carregando: _carregando,
                    onPressed: _realizarLogin,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _carregando
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const EsqueceuSenhaScreen(),
                              ),
                            );
                          },
                    child: const Text(
                      'Esqueceu senha?',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  TextButton(
                    onPressed: _carregando
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CadastroScreen(),
                              ),
                            );
                          },
                    child: const Text(
                      'Não tem conta? Cadastre-se aqui',
                      style: TextStyle(
                        color: corBotaoAzul,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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

// ==========================================
// TELA DE CADASTRO
// ==========================================

class CadastroScreen extends StatefulWidget {
  const CadastroScreen({super.key});

  @override
  State<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  static const List<String> _seriesEscolares = [
    '4º ano do Ensino Fundamental',
    '5º ano do Ensino Fundamental',
    '6º ano do Ensino Fundamental',
    '7º ano do Ensino Fundamental',
    '8º ano do Ensino Fundamental',
    '9º ano do Ensino Fundamental',
    '1º ano do Ensino Médio',
    '2º ano do Ensino Médio',
    '3º ano do Ensino Médio',
  ];

  String? _serieEscolarSelecionada;
  bool _erroSerieEscolar = false;

  Widget _campoSerieEscolar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: _serieEscolarSelecionada,
        isExpanded: true,
        decoration: InputDecoration(
          hintText: 'Série Escolar',
          prefixIcon: const Icon(Icons.school_outlined),
          filled: true,
          fillColor: _erroSerieEscolar ? corCampoErro : corCampoNormal,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        items: _seriesEscolares.map((serie) {
          return DropdownMenuItem<String>(
            value: serie,
            child: Text(serie, overflow: TextOverflow.ellipsis),
          );
        }).toList(),
        onChanged: (valor) {
          setState(() {
            _serieEscolarSelecionada = valor;
            _erroSerieEscolar = false;
          });
        },
      ),
    );
  }

  final app_auth.AuthService _authService = app_auth.AuthService();

  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _dataNascimentoController =
      TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  final TextEditingController _confirmaSenhaController =
      TextEditingController();

  bool _ocultarSenha = true;
  bool _ocultarConfirma = true;
  bool _carregando = false;

  bool _erroNome = false;
  bool _erroEmail = false;
  bool _erroDataNascimento = false;
  bool _erroSenha = false;
  bool _erroConfirmaSenha = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _dataNascimentoController.dispose();
    _senhaController.dispose();
    _confirmaSenhaController.dispose();
    super.dispose();
  }

  String? _validarCadastro() {
    final nome = _nomeController.text.trim();
    final email = _emailController.text.trim();
    final dataNascimento = _dataNascimentoController.text.trim();
    final senha = _senhaController.text;
    final confirmaSenha = _confirmaSenhaController.text;

    setState(() {
      _erroNome = nome.length < 3;
      _erroEmail = !emailValido(email);
      _erroDataNascimento = !dataNascimentoValida(dataNascimento);
      _erroSenha = !senhaForte(senha);
      _erroConfirmaSenha = senha != confirmaSenha || confirmaSenha.isEmpty;
      _erroSerieEscolar =
          _serieEscolarSelecionada == null || _serieEscolarSelecionada!.isEmpty;
    });

    if (_erroNome) {
      return 'Informe seu nome completo.';
    }

    if (_erroEmail) {
      return 'Informe um e-mail válido.';
    }

    if (_erroDataNascimento) {
      return 'Informe uma data de nascimento válida.';
    }

    if (_erroSerieEscolar) {
      return 'Selecione sua série escolar.';
    }

    if (_erroSenha) {
      return 'A senha deve ter no mínimo 8 caracteres, uma letra maiúscula e um número.';
    }

    if (_erroConfirmaSenha) {
      return 'As senhas não coincidem.';
    }

    return null;
  }

  Future<void> _finalizarCadastro() async {
    final erroValidacao = _validarCadastro();

    if (erroValidacao != null) {
      mostrarMensagem(context, texto: erroValidacao);
      return;
    }

    setState(() => _carregando = true);

    try {
      final resposta = await _authService.cadastrar(
        email: _emailController.text.trim(),
        senha: _senhaController.text,
        nome: _nomeController.text.trim(),
        dataNascimento: converterDataParaBanco(
          _dataNascimentoController.text.trim(),
        ),
        serieEscolar: _serieEscolarSelecionada!,
      );

      final usuario = resposta.user;

      if (usuario == null) {
        if (!mounted) return;

        mostrarMensagem(
          context,
          texto:
              'Cadastro iniciado. Verifique seu e-mail para confirmar a conta.',
          cor: corBotaoVerde,
        );

        Navigator.pop(context);
        return;
      }

      if (!mounted) return;

      mostrarMensagem(
        context,
        texto: 'Cadastro realizado com sucesso! Faça seu login.',
        cor: corBotaoVerde,
      );

      Navigator.pop(context);
    } on AuthException catch (erro) {
      if (!mounted) return;

      mostrarMensagem(context, texto: traduzirErroAuth(erro));
    } catch (e) {
      if (!mounted) return;

      mostrarMensagem(context, texto: 'Erro inesperado ao criar conta.');
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  Widget _construirCampo({
    required String hint,
    required TextEditingController controller,
    required bool erro,
    IconData? icone,
    bool ehSenha = false,
    bool ocultar = false,
    VoidCallback? onToggle,
    TextInputType tipo = TextInputType.text,
    List<TextInputFormatter>? formatadores,
    TextInputAction textInputAction = TextInputAction.next,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: ehSenha ? ocultar : false,
        keyboardType: tipo,
        inputFormatters: formatadores,
        textInputAction: textInputAction,
        autocorrect: false,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: icone == null ? null : Icon(icone),
          filled: true,
          fillColor: erro ? corCampoErro : corCampoNormal,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          suffixIcon: ehSenha
              ? IconButton(
                  icon: Icon(
                    ocultar ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: onToggle,
                )
              : null,
        ),
        onChanged: (_) {
          if (erro) {
            setState(() {});
          }
        },
      ),
    );
  }

  Widget _textoRegrasSenha() {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(left: 4, bottom: 12),
        child: Text(
          'A senha deve ter no mínimo 8 caracteres, uma letra maiúscula e um número.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
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
        elevation: 0,
        foregroundColor: Colors.black87,
        title: const Text('Criar conta'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
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
                    Icons.person_add_alt_1_rounded,
                    size: 54,
                    color: corBotaoVerde,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Criar Conta',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 25),
                  _construirCampo(
                    hint: 'Nome Completo',
                    controller: _nomeController,
                    erro: _erroNome,
                    icone: Icons.person_outline,
                  ),
                  _construirCampo(
                    hint: 'E-mail',
                    controller: _emailController,
                    erro: _erroEmail,
                    icone: Icons.email_outlined,
                    tipo: TextInputType.emailAddress,
                  ),
                  _construirCampo(
                    hint: 'Data de Nascimento (dd/mm/aaaa)',
                    controller: _dataNascimentoController,
                    erro: _erroDataNascimento,
                    icone: Icons.calendar_today_outlined,
                    tipo: TextInputType.number,
                    formatadores: [DataNascimentoFormatter()],
                  ),

                  _campoSerieEscolar(),

                  _construirCampo(
                    hint: 'Crie uma Senha',
                    controller: _senhaController,
                    erro: _erroSenha,
                    icone: Icons.lock_outline,
                    ehSenha: true,
                    ocultar: _ocultarSenha,
                    onToggle: () {
                      setState(() => _ocultarSenha = !_ocultarSenha);
                    },
                  ),
                  _textoRegrasSenha(),
                  _construirCampo(
                    hint: 'Confirmar Senha',
                    controller: _confirmaSenhaController,
                    erro: _erroConfirmaSenha,
                    icone: Icons.lock_reset_outlined,
                    ehSenha: true,
                    ocultar: _ocultarConfirma,
                    textInputAction: TextInputAction.done,
                    onToggle: () {
                      setState(() => _ocultarConfirma = !_ocultarConfirma);
                    },
                  ),
                  const SizedBox(height: 10),
                  AppButton(
                    texto: 'CADASTRAR',
                    cor: corBotaoVerde,
                    altura: 52,
                    carregando: _carregando,
                    onPressed: _finalizarCadastro,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _carregando
                        ? null
                        : () => Navigator.pop(context),
                    child: const Text(
                      'Voltar para o Login',
                      style: TextStyle(color: Colors.grey),
                    ),
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

extension on Object? {}

// ==========================================
// TELA DE RECUPERAR SENHA
// ==========================================

class EsqueceuSenhaScreen extends StatefulWidget {
  const EsqueceuSenhaScreen({super.key});

  @override
  State<EsqueceuSenhaScreen> createState() => _EsqueceuSenhaScreenState();
}

class _EsqueceuSenhaScreenState extends State<EsqueceuSenhaScreen> {
  final app_auth.AuthService _authService = app_auth.AuthService();
  final TextEditingController _emailController = TextEditingController();

  bool _carregando = false;
  bool _erroEmail = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _enviarLink() async {
    final email = _emailController.text.trim();

    setState(() {
      _erroEmail = !emailValido(email);
    });

    if (_erroEmail) {
      mostrarMensagem(context, texto: 'Informe um e-mail válido.');
      return;
    }

    setState(() => _carregando = true);

    try {
      await _authService.enviarEmailRecuperacao(email);

      if (!mounted) return;

      mostrarMensagem(
        context,
        texto: 'Enviamos um link de recuperação para seu e-mail.',
        cor: corBotaoVerde,
      );

      Navigator.pop(context);
    } on AuthException catch (erro) {
      if (!mounted) return;

      mostrarMensagem(context, texto: traduzirErroAuth(erro));
    } catch (e) {
      if (!mounted) return;

      mostrarMensagem(context, texto: 'Erro ao enviar link de recuperação.');
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: corFundoApp,
      appBar: AppBar(
        backgroundColor: corFundoApp,
        foregroundColor: Colors.black87,
        title: const Text('Recuperar senha'),
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
                    Icons.lock_reset_rounded,
                    size: 60,
                    color: corBotaoAzul,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Recuperar Senha',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Digite seu e-mail. Você receberá um link para criar uma nova senha.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 25),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'E-mail',
                      prefixIcon: const Icon(Icons.email_outlined),
                      filled: true,
                      fillColor: _erroEmail ? corCampoErro : corCampoNormal,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) {
                      if (!_carregando) {
                        _enviarLink();
                      }
                    },
                  ),
                  const SizedBox(height: 22),
                  AppButton(
                    texto: 'ENVIAR LINK',
                    cor: corBotaoAzul,
                    altura: 52,
                    carregando: _carregando,
                    onPressed: _enviarLink,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _carregando
                        ? null
                        : () => Navigator.pop(context),
                    child: const Text(
                      'Voltar para o Login',
                      style: TextStyle(color: Colors.grey),
                    ),
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
