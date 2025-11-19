import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const MethodChannel _method =
      MethodChannel('gopro_usb/methods');

  static const EventChannel _events =
      EventChannel('gopro_usb/events');

  String status = "Checking USB connection…";
  String? goProModel;
  String apiResponse = "";
  String? goProIP;

  @override
  void initState() {
    super.initState();

    _checkOnce();
    _listenToEvents();
  }

  

  Future<void> _checkOnce() async {
    final String? model =
        await _method.invokeMethod<String>('isGoProConnected');

    setState(() {
      goProModel = model;
      status = model != null
          ? "📸 $model connected!"
          : "❌ No GoPro detected";
    });
  }

  void _listenToEvents() {
    _events.receiveBroadcastStream().listen((event) {
      final String? model = event as String?;

      setState(() {
        goProModel = model;
        status = model != null
            ? "📸 $model connected!"
            : "❌ GoPro disconnected";
        apiResponse = "";
        goProIP = null;
      });
      
      // When GoPro is detected, discover its IP via mDNS
      if (model != null) {
        _discoverGoProIP();
      }
    });
  }

  Future<void> _discoverGoProIP() async {
    try {
      setState(() {
        apiResponse = "Discovering GoPro IP...";
      });

      // Call the Android method to discover GoPro IP
      final String? ip =
          await _method.invokeMethod<String>('discoverGoProIP');

      if (ip != null && ip.isNotEmpty) {
        setState(() {
          goProIP = ip;
          apiResponse = "Found GoPro at: $ip\nTap button to query API";
        });
      } else {
        setState(() {
          apiResponse = "GoPro not found.\nMake sure it's connected and powered on.";
        });
      }
    } catch (e) {
      setState(() {
        apiResponse = "Discovery Error: $e\nUsing fallback...";
      });
      // Fallback to hardcoded IP
      goProIP = '172.28.183.51';
    }
  }

  Future<void> _queryGoProAPI() async {
    if (goProModel == null) {
      setState(() {
        apiResponse = "GoPro not connected";
      });
      return;
    }

    // Use discovered IP or fallback
    final String ip = goProIP ?? '172.28.183.51';

    try {
      setState(() {
        apiResponse = "Attempting network binding...";
      });

      // Bind to the USB network on Android
      bool bound = false;
      String bindStatus = "";
      try {
        bound =
            await _method.invokeMethod<bool>('bindToGoProNetwork') ?? false;
        bindStatus = bound
            ? "✓ Network binding successful"
            : "⚠️ Could not bind to USB network (continuing anyway)";
      } catch (e) {
        bindStatus = "⚠️ Network binding error: $e\n(continuing anyway)";
      }

      setState(() {
        apiResponse = "$bindStatus\n\nConnecting to $ip:8080...";
      });

      // Try different endpoints in order
      final endpoints = [
        '/gopro/camera/info',
      ];

      http.Response? response;
      String? lastError;
      String? successfulEndpoint;

      for (final endpoint in endpoints) {
        try {
          final url = 'http://$ip:8080$endpoint';

          response = await http.get(
            Uri.parse(url),
            headers: {
              'User-Agent': 'GoPro USB Detector',
              'Connection': 'close',
            },
          ).timeout(const Duration(seconds: 5));

          if (response.statusCode == 200 || response.statusCode == 404) {
            successfulEndpoint = endpoint;
            break;
          }
        } catch (e) {
          lastError = e.toString();
          continue;
        }
      }

      if (response != null) {
        final resp = response;
        if (resp.statusCode == 200) {
          setState(() {
            apiResponse = "✅ API Connected!\n\nEndpoint: $successfulEndpoint\nStatus: ${resp.statusCode}\n\nResponse:\n${resp.body}";
          });
        } else {
          setState(() {
            apiResponse = "⚠️ Got response (Status ${resp.statusCode})\n\nEndpoint: $successfulEndpoint\nResponse:\n${resp.body}";
          });
        }
      } else {
        setState(() {
          apiResponse = "❌ Connection Failed\n\nTried endpoints:\n${endpoints.join('\n')}\n\nLast error: $lastError\n\n💡 Troubleshooting:\n- Enable Airplane Mode to route all traffic through USB\n- Check GoPro is powered on and WiFi enabled\n- Check USB cable connection";
        });
      }
    } on TimeoutException {
      setState(() {
        apiResponse = "⏱️ Timeout Error\n\nEach endpoint request timed out after 5 seconds.\n\n💡 Solutions:\n1. Enable Airplane Mode\n2. Check GoPro WiFi is enabled\n3. Move closer to GoPro\n4. Restart the GoPro\n5. Check USB cable";
      });
    } catch (e) {
      setState(() {
        apiResponse = "❌ Error: $e\n\n💡 Make sure:\n- GoPro is connected via USB\n- GoPro is powered on\n- WiFi is enabled on GoPro\n- USB cable is properly connected";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text("GoPro USB Detector")),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  status,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (goProModel != null)
                  Column(
                    children: [
                      ElevatedButton(
                        onPressed: _discoverGoProIP,
                        child: const Text("Discover GoPro IP"),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _queryGoProAPI,
                        child: const Text("Query GoPro API"),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                if (apiResponse.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          apiResponse,
                          style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
                          textAlign: TextAlign.left,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
