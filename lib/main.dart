import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(MaterialApp(home: Home()));
}

class Home extends StatelessWidget {
  static const channel = MethodChannel('proxy');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          child: Text("START PROXY"),

          onPressed: () async {
              print("FLUTTER: button pressed");
              await channel.invokeMethod("start");
              print("FLUTTER: method completed");

              if (context.mounted) {
                  showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                          title: Text("Разрешите фоновую работу"),
                          content: Text(
                              "Для работы прокси в фоне:\n\n"
                              "1. Настройки → Приложения → tg_proxy\n"
                              "2. Батарея → Без ограничений\n"
                              "3. Или: Настройки → Управление приложениями → "
                              "Автозапуск → включить tg_proxy"
                          ),
                          actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: Text("Понял"),
                              )
                          ],
                      ),
                  );
              }
          },
        ),
      ),
    );
  }
}
