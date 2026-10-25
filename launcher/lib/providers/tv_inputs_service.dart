import 'package:flutter/foundation.dart';
import 'package:flauncher/flauncher_channel.dart';
import 'package:flauncher/models/tv_input.dart';

class TvInputsService extends ChangeNotifier {
  final FLauncherChannel _channel;
  List<TvInput> _inputs = [];
  bool _initialized = false;

  TvInputsService(this._channel) {
    _init();
  }

  List<TvInput> get inputs => List.unmodifiable(_inputs);
  bool get hasInputs => _inputs.isNotEmpty;
  bool get initialized => _initialized;

  Future<void> _init() async {
    await refreshInputs();
    _initialized = true;
    notifyListeners();
  }

  Future<void> refreshInputs() async {
    final List<Map<dynamic, dynamic>> rawInputs = await _channel.getTvInputs();
    _inputs = rawInputs.map((map) => TvInput.fromMap(map)).toList();
    notifyListeners();
  }

  Future<bool> switchInput(String id) async {
    return await _channel.launchTvInput(id);
  }
}
