import 'package:flutter/material.dart';

import 'package:zeroconf/zeroconf.dart';

void main() {
  runApp(ZeroconfApp());
}

class ZeroconfApp extends StatelessWidget {
  @override
  Widget build(final BuildContext context) {
    return MaterialApp(
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() {
    return _HomePageState();
  }
}

class _HomePageState extends State<HomePage> {
  Zeroconf _zeroconf;
  bool _scanning = false;
  List<Service> _services = <Service>[];

  Future<void> _startScan() async {
    this.setState(() {
      this._scanning = false;
      this._services = <Service>[];
    });

    this._zeroconf = Zeroconf(
      onScanStarted: this._onScanStarted,
      onScanStopped: this._onScanStopped,
      onServiceResolved: this._onServiceResolved,
      onError: this._onError,
    );

    this._zeroconf.startScan(type: '_http._tcp.');
  }

  Future<void> _stopScan() async {
    this._zeroconf?.stopScan();
    this._zeroconf = null;
  }

  void _onScanStarted() {
    this.setState(() {
      this._scanning = true;
    });
  }

  void _onScanStopped() {
    this.setState(() {
      this._scanning = false;
    });
  }

  void _onServiceResolved(Service service) {
    this.setState(() {
      this._services.add(service);
    });
  }

  void _onError() {
    showDialog(
      context: this.context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: new Text("Error"),
          content: new Text("An error occurred while scanning for services."),
          actions: <Widget>[
            new FlatButton(
              child: new Text("Close"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(final BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zeroconf Plugin'),
      ),
      body: Container(
        margin: EdgeInsets.all(10.0),
        child: ListView.builder(
          itemCount: this._services.length + 1,
          itemBuilder: (BuildContext context, int index) {
            if (index == 0) {
              // header
              List<Widget> widgets;
              if (this._scanning) {
                widgets = <Widget>[
                  CircularProgressIndicator(),
                  RaisedButton(
                    onPressed: this._stopScan,
                    child: Text("Stop Scan"),
                  ),
                ];
              } else {
                widgets = <Widget>[
                  RaisedButton(
                    onPressed: this._startScan,
                    child: Text("Start Scan"),
                  ),
                ];
              }
              return Column(children: widgets);
            } else {
              // service
              return Container(
                margin: EdgeInsets.only(top: 10.0),
                child: Card(
                  child: Text(this._services[index - 1].toString()),
                ),
              );
            }
          },
        ),
      ),
    );
  }
}
