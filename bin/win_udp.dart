import 'dart:async';

import 'package:win_udp/udp.dart';

void main() async {
  await setupUdpServer();
  Timer.periodic(Duration(seconds: 1), (t) {
    print(1);
  });
}
