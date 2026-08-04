import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AntiCheatService {
  static const MethodChannel _channel = MethodChannel('quiz_estudo/anti_cheat');

  static Future<void> ativarProtecao() async {
    if (kIsWeb) {
      debugPrint('Anti-cola não suportado no Web.');
      return;
    }

    try {
      await _channel.invokeMethod('ativarProtecao');
    } catch (e) {
      debugPrint('Erro ao ativar anti-cola: $e');
    }
  }

  static Future<void> desativarProtecao() async {
    if (kIsWeb) {
      return;
    }

    try {
      await _channel.invokeMethod('desativarProtecao');
    } catch (e) {
      debugPrint('Erro ao desativar anti-cola: $e');
    }
  }
}
