import 'package:flutter/services.dart' show MethodChannel, EventChannel;
import 'package:meta/meta.dart' show required;

class Service {
  final String name;
  final String host;
  final List<String> addresses;
  final int port;

  Service({
    @required this.name,
    this.host,
    this.addresses,
    this.port,
  });

  static Service fromMap(Map<dynamic, dynamic> data) {
    return new Service(
      name: data["name"] as String,
      host: data["host"] as String,
      addresses: (data["addresses"] as List<dynamic>)?.map((dynamic address) {
        return address as String;
      })?.toList(),
      port: data["port"] as int,
    );
  }

  @override
  String toString() {
    return "Name: ${this.name}, Host: ${this.host}, Addresses: ${this.addresses}, Port: ${this.port}";
  }
}

typedef void OnScanStarted();
typedef void OnScanStopped();
typedef void OnServiceFound(Service service);
typedef void OnServiceLost(Service service);
typedef void OnServiceResolved(Service service);
typedef void OnServiceNotResolved(Service service);
typedef void OnError();

class Zeroconf {
  static const MethodChannel _channel = const MethodChannel("ca.michaux.peter.zeroconf");

  final EventChannel _eventsChannel = const EventChannel("ca.michaux.peter.zeroconf.events");

  final OnScanStarted onScanStarted;
  final OnScanStopped onScanStopped;
  final OnServiceFound onServiceFound;
  final OnServiceLost onServiceLost;
  final OnServiceResolved onServiceResolved;
  final OnServiceNotResolved onServiceNotResolved;
  final OnError onError;

  Zeroconf({
    this.onScanStarted,
    this.onScanStopped,
    this.onServiceFound,
    this.onServiceLost,
    this.onServiceResolved,
    this.onServiceNotResolved,
    this.onError,
  }) {
    this._eventsChannel.receiveBroadcastStream().listen((final dynamic data) {
      switch (data["type"]) {
        case "ScanStarted":
          if (this.onScanStarted != null) this.onScanStarted();
          break;
        case "ScanStopped":
          if (this.onScanStopped != null) this.onScanStopped();
          break;
        case "ServiceFound":
          if (this.onServiceFound != null) this.onServiceFound(Service.fromMap(data["service"]));
          break;
        case "ServiceLost":
          if (this.onServiceLost != null) this.onServiceLost(Service.fromMap(data["service"]));
          break;
        case "ServiceResolved":
          if (this.onServiceResolved != null) this.onServiceResolved(Service.fromMap(data["service"]));
          break;
        case "ServiceNotResolved":
          if (this.onServiceNotResolved != null) this.onServiceNotResolved(Service.fromMap(data["service"]));
          break;
        case "Error":
          if (this.onError != null) this.onError();
          break;
        default:
          if (this.onError != null) this.onError();
          break;
      }
    });
  }

  Future<void> startScan({
    @required final String type,
  }) async {
    assert(type != null);
    await _channel.invokeMethod("startScan", <String, dynamic>{"type": type});
  }

  Future<void> stopScan() async {
    await _channel.invokeMethod("stopScan");
  }
}
