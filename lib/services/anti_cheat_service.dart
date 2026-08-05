import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AntiCheatService {
  static const MethodChannel _channel = MethodChannel('quiz_estudo/anti_cheat');

  static bool get _suportaProtecaoNativa {
    if (kIsWeb) return false;

    return defaultTargetPlatform == TargetPlatform.android;
  }

  static Future<void> ativarProtecao() async {
    if (!_suportaProtecaoNativa) {
      debugPrint('Anti-cola nativo disponível apenas no Android.');
      return;
    }

    try {
      await _channel.invokeMethod('ativarProtecao');
    } catch (e) {
      debugPrint('Erro ao ativar anti-cola: $e');
    }
  }

  static Future<void> desativarProtecao() async {
    if (!_suportaProtecaoNativa) {
      return;
    }

    try {
      await _channel.invokeMethod('desativarProtecao');
    } catch (e) {
      debugPrint('Erro ao desativar anti-cola: $e');
    }
  }
}
