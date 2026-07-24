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
            await channel.invokeMethod("start");
          },
        ),
      ),
    );
  }
}
