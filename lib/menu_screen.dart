import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'autenticacao.dart';
import 'dificuldade_screen.dart';
import 'main.dart';
import 'placar_screen.dart';
import 'services/auth_service.dart' as app_auth;
import 'services/level_service.dart';
import 'widgets/app_button.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final app_auth.AuthService _authService = app_auth.AuthService();

  String? _fotoBase64;
  String? _serieEscolarAtual;
  String? _nivelAtual;
  String? _tituloAtual;

  bool _carregandoJogar = false;
  bool _carregandoLogout = false;
  bool _atualizandoSerie = false;

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

  @override
void initState() {
  super.initState();
  _carregarPreferencias();
  _verificarAvisoAntiCheat();
}

  Future<void> _verificarAvisoAntiCheat() async {
  final prefs = await SharedPreferences.getInstance();

  final antiCheatAcionado = prefs.getBool('anti_cheat_acionado') ?? false;

  if (!antiCheatAcionado) return;

  await prefs.remove('anti_cheat_acionado');

  if (!mounted) return;

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'A rodada foi encerrada porque o anti-cheat foi acionado.',
        ),
        backgroundColor: Colors.redAccent,
      ),
    );
  });
}

  Future<void> _carregarPreferencias() async {
    final prefs = await SharedPreferences.getInstance();

    final fotoSalva = prefs.getString('foto_perfil_base64');
    final temaEscuro = prefs.getBool('tema_escuro') ?? false;

    Map<String, dynamic>? perfil;

    try {
      perfil = await _authService.buscarPerfilAtual();
    } catch (_) {
      perfil = null;
    }

    final serie = perfil?['serie_escolar']?.toString();
    final nivel = perfil?['nivel_atual']?.toString();
    final titulo = perfil?['titulo_atual']?.toString();

    themeNotifier.value = temaEscuro ? ThemeMode.dark : ThemeMode.light;

    if (!mounted) return;

    setState(() {
      _fotoBase64 = fotoSalva;
      _serieEscolarAtual = serie;
      _nivelAtual = nivel;
      _tituloAtual = titulo;
    });
  }

  Future<void> _alternarTema() async {
    final novoTema = themeNotifier.value == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;

    themeNotifier.value = novoTema;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tema_escuro', novoTema == ThemeMode.dark);
  }

  Future<void> _jogar() async {
    setState(() => _carregandoJogar = true);

    try {
      final perfil = await _authService.buscarPerfilAtual();

      final serieEscolar = perfil?['serie_escolar']?.toString();

      if (serieEscolar == null || serieEscolar.trim().isEmpty) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Atualize sua série escolar antes de jogar.'),
            backgroundColor: Colors.orange,
          ),
        );

        _mostrarDialogAlterarSerie();
        return;
      }

      final nivel = perfil?['nivel_atual']?.toString().trim().isNotEmpty == true
          ? perfil!['nivel_atual'].toString()
          : LevelService.nivelPorSerieEscolar(serieEscolar);

      final categoria = LevelService.categoriaPorNivel(nivel);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DificuldadeScreen(
            serieSelecionada: categoria,
            nivelSelecionado: nivel,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao carregar perfil do usuário.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _carregandoJogar = false);
      }
    }
  }

  Future<void> _escolherFotoDaGaleria() async {
    try {
      final picker = ImagePicker();

      final imagem = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 500,
      );

      if (imagem == null) return;

      final bytes = await imagem.readAsBytes();
      final fotoConvertida = base64Encode(bytes);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('foto_perfil_base64', fotoConvertida);

      if (!mounted) return;

      setState(() {
        _fotoBase64 = fotoConvertida;
      });
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível escolher a foto.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _removerFoto() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('foto_perfil_base64');

    if (!mounted) return;

    setState(() {
      _fotoBase64 = null;
    });
  }

  Future<void> _alterarSerieEscolar(String novaSerie) async {
    setState(() => _atualizandoSerie = true);

    try {
      await _authService.atualizarSerieEscolar(
        serieEscolar: novaSerie,
      );

      final novoNivel = LevelService.nivelPorSerieEscolar(novaSerie);

      if (!mounted) return;

      setState(() {
        _serieEscolarAtual = novaSerie;
        _nivelAtual = novoNivel;
        _tituloAtual = LevelService.tituloIniciante;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Série escolar atualizada com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao atualizar série escolar.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _atualizandoSerie = false);
      }
    }
  }

  void _mostrarDialogAlterarSerie() {
    String? serieSelecionada = _serieEscolarAtual;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Alterar Série Escolar'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Selecione sua série atual:',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: serieSelecionada,
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.school_outlined),
                    ),
                    items: _seriesEscolares.map((serie) {
                      return DropdownMenuItem<String>(
                        value: serie,
                        child: Text(
                          serie,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (valor) {
                      setModalState(() {
                        serieSelecionada = valor;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: serieSelecionada == null
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                          _alterarSerieEscolar(serieSelecionada!);
                        },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _mostrarOpcoesFoto() {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Foto de Perfil'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: Colors.blueAccent,
                ),
                title: const Text('Escolher da Galeria'),
                onTap: () {
                  Navigator.pop(context);
                  _escolherFotoDaGaleria();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete,
                  color: Colors.redAccent,
                ),
                title: const Text('Remover Foto'),
                onTap: () {
                  Navigator.pop(context);
                  _removerFoto();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sair() async {
    setState(() => _carregandoLogout = true);

    try {
      await _authService.logout();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao sair da conta.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _carregandoLogout = false);
      }
    }
  }

  ImageProvider? _imagemPerfil() {
    if (_fotoBase64 == null || _fotoBase64!.isEmpty) {
      return null;
    }

    try {
      return MemoryImage(base64Decode(_fotoBase64!));
    } catch (_) {
      return null;
    }
  }

  Widget _botaoPerfil() {
    return PopupMenuButton<int>(
      offset: const Offset(0, 55),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      icon: CircleAvatar(
        radius: 26,
        backgroundColor: Colors.blueAccent,
        backgroundImage: _imagemPerfil(),
        child: _fotoBase64 == null
            ? const Icon(
                Icons.person,
                color: Colors.white,
                size: 28,
              )
            : null,
      ),
      onSelected: (value) {
        switch (value) {
          case 1:
            _alternarTema();
            break;
          case 2:
            _mostrarOpcoesFoto();
            break;
          case 3:
            _mostrarDialogAlterarSerie();
            break;
          case 4:
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Painel de ajuda em breve!'),
              ),
            );
            break;
          case 5:
            _sair();
            break;
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 1,
          child: Text('🌓 Alternar Tema'),
        ),
        const PopupMenuItem(
          value: 2,
          child: Text('📷 Mudar Foto'),
        ),
        PopupMenuItem(
          value: 3,
          child: Text(
            _serieEscolarAtual == null
                ? '🎓 Alterar Série'
                : '🎓 Série: $_serieEscolarAtual',
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const PopupMenuItem(
          value: 4,
          child: Text('❓ Ajuda'),
        ),
        const PopupMenuItem(
          value: 5,
          child: Text(
            '🚪 Sair',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoAluno() {
    final nivelTexto = _nivelAtual == null
        ? 'Nível não definido'
        : LevelService.nomeNivel(_nivelAtual!);

    final tituloTexto = _tituloAtual ?? 'Iniciante';

    return Column(
      children: [
        Text(
          nivelTexto,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blueAccent,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Título: $tituloTexto',
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _conteudoCentral(BuildContext context) {
    final larguraBotao =
        MediaQuery.of(context).size.width > 500 ? 260.0 : 220.0;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: 30,
          vertical: 40,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/titulo.png',
              height: 160,
              fit: BoxFit.contain,
              errorBuilder: (_, error, stackTrace) {
                return const Icon(
                  Icons.school_rounded,
                  size: 120,
                  color: Colors.blueAccent,
                );
              },
            ),
            const SizedBox(height: 20),
            _infoAluno(),
            const SizedBox(height: 55),
            AppButton(
              texto: 'JOGAR',
              largura: larguraBotao,
              altura: 62,
              icone: Icons.play_arrow_rounded,
              carregando: _carregandoJogar,
              onPressed: _jogar,
            ),
            const SizedBox(height: 20),
            AppButton(
              texto: 'PLACAR',
              largura: larguraBotao,
              altura: 62,
              icone: Icons.emoji_events_rounded,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PlacarScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _overlayCarregando() {
    if (!_carregandoLogout && !_atualizandoSerie) {
      return const SizedBox.shrink();
    }

    final mensagem = _carregandoLogout
        ? 'Saindo da conta...'
        : 'Atualizando série...';

    return Positioned.fill(
      child: Container(
        color: Colors.black45,
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(mensagem),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          _conteudoCentral(context),
          Positioned(
            top: 48,
            right: 20,
            child: _botaoPerfil(),
          ),
          _overlayCarregando(),
        ],
      ),
    );
  }
}