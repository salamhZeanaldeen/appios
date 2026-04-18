import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:bonsoir/bonsoir.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DiscoveryService extends ChangeNotifier {
  String _baseUrl = 'https://survivors-toe-mega-wins.trycloudflare.com'; // New Global API Tunnel
  bool _isSearching = false;
  String? _serverName;
  BonsoirDiscovery? _discovery;
  StreamSubscription? _subscription;

  String get baseUrl => _baseUrl;
  bool get isSearching => _isSearching;
  String? get serverName => _serverName;

  DiscoveryService() {
    _loadSavedUrl();
    runDiscovery();
  }

  Future<void> _loadSavedUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('baseUrl');
    if (savedUrl != null) {
      _baseUrl = savedUrl;
      notifyListeners();
    }
  }

  Future<void> runDiscovery() async {
    if (_isSearching) return;
    
    _isSearching = true;
    notifyListeners();

    try {
      _discovery = BonsoirDiscovery(type: '_remmber._tcp');
      await _discovery!.ready;

      _subscription = _discovery!.eventStream!.listen((event) {
        if (event.type == BonsoirDiscoveryEventType.discoveryServiceResolved && event.service != null) {
          final service = event.service as ResolvedBonsoirService;
          
          // CRITICAL: Find non-loopback IP
          String host = service.ip ?? '127.0.0.1';
          
          // Try to find a better IP if the default is 127.0.0.1
          if (host.startsWith('127.') || host == 'localhost') {
            final json = service.toJson();
            final List? addresses = json['service.hostAddresses'];
            if (addresses != null && addresses.isNotEmpty) {
              host = addresses.firstWhere((ip) => !ip.toString().startsWith('127.'), orElse: () => host);
            }
          }

          _baseUrl = 'http://$host:${service.port}';
          _serverName = service.name;
          _isSearching = false;
          
          _saveUrl(_baseUrl);
          stopDiscovery();
          notifyListeners();
          print('Found REMMBER Server at $_baseUrl');
        }
      });

      await _discovery!.start();

      // Auto-stop after 15 seconds if nothing found
      Timer(const Duration(seconds: 15), () {
        if (_isSearching) {
          _isSearching = false;
          stopDiscovery();
          notifyListeners();
        }
      });
    } catch (e) {
      print('Discovery error: $e');
      _isSearching = false;
      notifyListeners();
    }
  }

  void stopDiscovery() {
    _subscription?.cancel();
    _discovery?.stop();
  }

  Future<void> _saveUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('baseUrl', url);
  }

  void setManualUrl(String url) {
    _baseUrl = url;
    _saveUrl(url);
    notifyListeners();
  }

  @override
  void dispose() {
    stopDiscovery();
    super.dispose();
  }
}
