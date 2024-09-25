import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

Future<List<InternetAddress>> getNetInter() async {
  final List<InternetAddress> netAddreseslist = [];
  var list = await NetworkInterface.list(
    includeLinkLocal: true,
    type: InternetAddressType.IPv4,
  );
  for (var netList in list) {
    for (var addr in netList.addresses) {
      netAddreseslist.add(addr);
    }
  }

  return netAddreseslist;
}

Future<void> setupUdpServer() async {
  var list = await getNetInter();
  for (var net in list) {
    var isolate = await Isolate.spawn<InternetAddress>(_createUdp, net);
  }
}

_createUdp(InternetAddress target) async {
  final server = UdpServer(target);
  await server.initUdp();
}

class UdpServer {
  InternetAddress target;
  UdpServer(this.target);

  RawDatagramSocket? udp;
  Stream<RawSocketEvent>? udpEventStream;

  /// 端口号
  static const int port = 18802;

  _print(List<dynamic> arg) {
    print(arg.toString());
  }

  Future<void> initUdp() async {
    if (!target.isLinkLocal) {
      return;
    }
    _print(["UDP 监听", target.address]);
    try {
      udp = await RawDatagramSocket.bind(target.address, port);
    } catch (e) {
      _print(["RawDatagramSocket bind fail", e]);
    }
    if (udp != null) {
      udp!.listen((event) {
        switch (event) {
          case RawSocketEvent.read:
            {
              Datagram? dg = udp!.receive();
              _print(["UDP消息读取", dg?.address.address, dg?.port, dg?.data.length]);
              if (dg != null) {
                var udpMsg = Utf8Codec().decode(dg.data);
                _print(['UDP MSG =', udpMsg]);
              }
            }
            break;
          case RawSocketEvent.write:
            _print(["UDP消息写入"]);
            break;
          case RawSocketEvent.closed:
            _print(["UDP关闭"]);
            break;

          default:
            break;
        }
      });
    }

    Timer.periodic(Duration(seconds: 5), (t) async {
      await getNetInter();
      _print(['------------------------']);
      sendBroadcast();

      _print(['------------------------']);
    });
  }

  sendBroadcast() {
    udp?.broadcastEnabled = true;
    var broadcastAddress = InternetAddress(
      "255.255.255.255",
      type: InternetAddressType.IPv4,
    );
    var json = '{"cmdData":"getDeviceInfo","cmdType":"system","isBroadcast":false}';
    final msg = utf8.encode(json);
    var flag = udp?.send(msg, broadcastAddress, 18801);
    // 表示系统堵塞中
    // 返回值 0 表示发送数据报将被阻塞，并且可以再次尝试发送调用
    if (flag == 0) {
      _print(["UDP 发送失败"]);
    }
    _print(["UDP 广播发送 val --> $flag"]);

    udp?.broadcastEnabled = false;
  }
}
