import 'package:flutter/foundation.dart';
import 'package:restaurant_app/services/activation_service.dart';

class ActivationChangeNotifier extends ChangeNotifier {
  ActivationChangeNotifier({ActivationService? service})
    : _service = service ?? ActivationService();

  final ActivationService _service;

  ActivationStatus _status = ActivationStatus.empty();
  bool _isLoading = false;
  bool _hasLoaded = false;

  ActivationStatus get status => _status;
  bool get isLoading => _isLoading;
  bool get isInitialized => _hasLoaded;
  bool get canAccessApp => _hasLoaded && !_isLoading && _status.canAccessApp;
  bool get requiresActivation =>
      _hasLoaded && !_isLoading && !_status.canAccessApp;

  Future<void> loadStatus({DateTime? now}) async {
    _isLoading = true;
    notifyListeners();

    _status = await _service.getStatus(now: now);
    _hasLoaded = true;
    _isLoading = false;
    notifyListeners();
  }

  Future<String?> activate(String code, {DateTime? now}) async {
    _isLoading = true;
    notifyListeners();

    final error = await _service.activateWithCode(code, now: now);
    _status = await _service.getStatus(now: now);
    _hasLoaded = true;
    _isLoading = false;
    notifyListeners();
    return error;
  }

  Future<void> reset() async {
    _isLoading = true;
    notifyListeners();

    await _service.clearActivation();
    _status = await _service.getStatus();
    _hasLoaded = true;
    _isLoading = false;
    notifyListeners();
  }
}
