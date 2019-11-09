import 'dart:convert';

import 'package:background_fetch/background_fetch.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

const LOCATION_POS = "location_log";
const TRACKING_CHECK = 'tracking_check';

/// This "Headless Task" is run when app is terminated.
void backgroundFetchHeadlessTask() async {
  print('[BackgroundFetch] Headless event received.');
  SharedPreferences prefs = await SharedPreferences.getInstance();

  // Read fetch_events from SharedPreferences
  List<String> events = [];
  String json = prefs.getString(LOCATION_POS);
  if (json != null) {
    events = jsonDecode(json).cast<String>();
  }
  // Add new event.
  events.insert(0, new DateTime.now().toString() + ' [Headless]');
  // Persist fetch events in SharedPreferences
  prefs.setString(LOCATION_POS, jsonEncode(events));

  BackgroundFetch.finish();
}

void main() {
  runApp(MyApp());
  BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter GeoTracking background '),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _locationPosition = '';
  int _status = 0;
  bool _enabled = false;
  bool _isInitBackground = false;
  List<String> _events = [];
  @override
  void initState() {
    super.initState();
    this.intiPlatformState();
  }

  Future<void> intiPlatformState() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // Persist fetch events in SharedPreferences
    var isTracking = prefs.getBool(TRACKING_CHECK) ?? false;
    if (isTracking) {
      startTracking();
    }
    setState(() {
      _enabled = isTracking;
    });

    // Read fetch_events from SharedPreferences
    List<String> events = [];
    String json = prefs.getString(LOCATION_POS);
    if (json != null) {
      events = jsonDecode(json).cast<String>();
    }
    setState(() {
      _events = events;
    });
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initBackgroundServiceConfig() async {
    if (_isInitBackground) return;
    _isInitBackground = true;
    // Configure BackgroundFetch.
    BackgroundFetch.configure(
            BackgroundFetchConfig(
                minimumFetchInterval: 15,
                stopOnTerminate: false,
                enableHeadless: false,
                requiresBatteryNotLow: false,
                requiresCharging: false,
                requiresStorageNotLow: false,
                requiresDeviceIdle: false,
                requiredNetworkType: BackgroundFetchConfig.NETWORK_TYPE_NONE),
            _onBackgroundFetch)
        .then((int status) {
      print('[BackgroundFetch] configure success: $status');
      setState(() {
        _status = status;
      });
    }).catchError((e) {
      print('[BackgroundFetch] configure ERROR: $e');
      setState(() {
        _status = e;
      });
    });

    // Optionally query the current BackgroundFetch status.
    int status = await BackgroundFetch.status;
    setState(() {
      _status = status;
    });

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;
  }

  void _onBackgroundFetch() async {
    // This is the fetch-event callback.
    print('[BackgroundFetch] Event received');
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isTracking = prefs.getBool(TRACKING_CHECK) ?? false;
    if (isTracking) {
      String message = '';
      try {
        Position position = await Geolocator().getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            locationPermissionLevel: GeolocationPermission.locationAlways);
        message =
            'POS: [${position.longitude}:${position.latitude}] - Time: ${new DateTime.now().toString()} ';
      } catch (error) {
        message = 'Error get Position ${error.toString()}';
      }
      print(message);
      List<String> events = [];
      String json = prefs.getString(LOCATION_POS);
      if (json != null) {
        events = jsonDecode(json).cast<String>();
      }
      events.insert(0, message);
      setState(() {
        _events = events;
      });
      // Persist fetch events in SharedPreferences
      prefs.setString(LOCATION_POS, jsonEncode(_events));
    }
    // IMPORTANT:  You must signal completion of your fetch task or the OS can punish your app
    // for taking too long in the background.
    BackgroundFetch.finish();
  }

  Future<void> getGeolocation() async {
    setState(() {
      _locationPosition = '';
    });
    Position position = await Geolocator().getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        locationPermissionLevel: GeolocationPermission.locationAlways);
    setState(() {
      _locationPosition = '${position.longitude}: ${position.latitude}';
    });
  }

  void startTracking() async {
    // run that for check permission
    await getGeolocation();
    _enabled = true;
    if (!this._isInitBackground) {
      //init background config will auto start service;
      this.initBackgroundServiceConfig();
    } else {
      BackgroundFetch.start().then((int status) {
        print('[BackgroundFetch] start success: $status');
      }).catchError((e) {
        print('[BackgroundFetch] start FAILURE: $e');
      });
    }
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool(TRACKING_CHECK, _enabled);
  }

  void stopTracking() async {
    _enabled = false;
    //clear local storage
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove(LOCATION_POS);
    prefs.setBool(TRACKING_CHECK, _enabled);
    setState(() {
      _events = [];
      _enabled = false;
    });
    BackgroundFetch.stop().then((int status) {
      print('[BackgroundFetch] stop success: $status');
    });
  }

  void clearLog() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(LOCATION_POS);
    setState(() {
      _events = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          buildCommandBar(),
          SizedBox(
            height: 5,
          ),
          Expanded(
            flex: 4,
            child: Container(
                child: _events.isEmpty
                    ? Text("Empty data,Waiting for fetch event..")
                    : Container(
                        child: new ListView.builder(
                            itemCount: _events.length,
                            itemBuilder: (BuildContext context, int index) {
                              String logEvent = _events[index];
                              return InputDecorator(
                                  decoration: InputDecoration(
                                      contentPadding: EdgeInsets.only(
                                          left: 5.0, top: 5.0, bottom: 5.0),
                                      labelStyle: TextStyle(
                                          color: Colors.blue, fontSize: 20.0),
                                      labelText: "[background fetch event]"),
                                  child: new Text(logEvent,
                                      style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 16.0)));
                            }),
                      )),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 5,
              ),
              Text('Current Position :'),
              SizedBox(
                width: 10,
              ),
              Text(
                '$_locationPosition',
              ),
            ],
          ),
          SizedBox(
            height: 30,
          )
        ],
      ),
    );
  }

  Column buildCommandBar() {
    return Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            RaisedButton(
              onPressed: _enabled
                  ? null
                  : () {
                      this.startTracking();
                    },
              color: Colors.green,
              child: const Text('Start Tracking',
                  style: TextStyle(fontSize: 20, color: Colors.white)),
            ),
            SizedBox(
              width: 30,
            ),
            RaisedButton(
              onPressed: !_enabled
                  ? null
                  : () {
                      this.stopTracking();
                    },
              color: Colors.red,
              child: const Text('Stop Tracking',
                  style: TextStyle(fontSize: 20, color: Colors.white)),
            ),
          ],
        ),
        RaisedButton(
          onPressed: () {
            this.clearLog();
          },
          color: Colors.blue,
          child: const Text('Clear log',
              style: TextStyle(fontSize: 20, color: Colors.white)),
        )
      ],
    );
  }
}
