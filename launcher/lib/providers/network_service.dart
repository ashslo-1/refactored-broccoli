/*
 * FLauncher
 * Copyright (C) 2021  Oscar Rojas
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:async';
import 'dart:developer';

import 'package:flauncher/flauncher_channel.dart';
import 'package:flutter/material.dart';

enum NetworkType
{
  Cellular,
  Wifi,
  Vpn,
  Wired,
  Unknown
}

// https://developer.android.com/reference/android/telephony/TelephonyManager#NETWORK_TYPE_CDMA
enum CellularNetworkType
{
  Unknown,  // 0
  Gprs,     // 1
  Edge,     // 2
  Umts,     // 3
  Cdma,     // 4
  EvdoZero, // 5
  EvdoA,    // 6
  Unused_1, // 7
  Hsdpa,    // 8
  Hsupa,    // 9
  Hspa,     // 10
  Iden,     // 11
  EvdoB,    // 12
  Lte,      // 13
  Ehrpd,    // 14
  Hspap,    // 15
  Gsm,      // 16
  TdScdma,  // 17
  Iwlan,    // 18
  Unused_2, // 19
  Nr,       // 20
}

class NetworkService extends ChangeNotifier with WidgetsBindingObserver
{
  final FLauncherChannel  _channel;

  bool                _hasInternetAccess;
  CellularNetworkType _cellularNetworkType;
  NetworkType         _networkType;
  int                 _wirelessNetworkSignalLevel;
  int                 _dailyDataUsage; // In bytes
  bool                _hasUsageStatsPermission;
  bool                _vpnActive;
  Timer?              _usageTimer;
  int                 _callCount = 0;
  int                 _usageCallCount = 0;


  NetworkService(this._channel) :
        _hasInternetAccess = false,
        _cellularNetworkType = CellularNetworkType.Unknown,
        _networkType = NetworkType.Unknown,
        _wirelessNetworkSignalLevel = 0,
        _dailyDataUsage = 0,
        _hasUsageStatsPermission = false,
        _vpnActive = false
  {
    _channel.addNetworkChangedListener(_onNetworkChanged);

    _channel
        .getActiveNetworkInformation()
        .then((map) {
          if (map.isNotEmpty) {
            _getNetworkInformation(map.cast<String, dynamic>());
            notifyListeners();
          }
        }).catchError((e) {
          log("Error getting active network info: $e");
        });

    _checkPermissionAndStartPolling();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refreshPermissionAndUsage();
    }
  }

  void _checkPermissionAndStartPolling() async {
    final localCallCount = ++_callCount;
    final bool allowed = await _channel.checkUsageStatsPermission();
    if (localCallCount != _callCount) return;

    _hasUsageStatsPermission = allowed;
    if (_hasUsageStatsPermission) {
      _fetchUsage();
      if (_usageTimer == null || !_usageTimer!.isActive) {
        _usageTimer = Timer.periodic(const Duration(minutes: 5), (_) => _fetchUsage());
      }
    } else {
      _usageTimer?.cancel();
      _usageTimer = null;
    }
    notifyListeners();
  }

  Future<void> requestPermission() async {
    await _channel.requestUsageStatsPermission();
  }

  // Call this when app resumes
  Future<void> refreshPermissionAndUsage() async {
    _checkPermissionAndStartPolling();
  }

  Future<void> openWifiSettings() async {
    await _channel.openWifiSettings();
  }

  Future<void> openVpnSettings() async {
    await _channel.openVpnSettings();
  }

  Future<void> _fetchUsage() async {
     final localCallCount = ++_usageCallCount;
     int usage = await _channel.getDailyDataUsage();
     if (localCallCount != _usageCallCount) return;

     if (usage != -1) {
       _dailyDataUsage = usage;
       notifyListeners();
     }
  }

  Future<int> getDataUsageForPeriod(String period) async {
    switch (period) {
      case 'daily':
        return await _channel.getDailyDataUsage();
      case 'weekly':
        return await _channel.getWeeklyDataUsage();
      case 'monthly':
        return await _channel.getMonthlyDataUsage();
      default:
        return await _channel.getDailyDataUsage();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _usageTimer?.cancel();
    super.dispose();
  }

  bool                  get   hasInternetAccess             => _hasInternetAccess;
  CellularNetworkType   get   cellularNetworkType           => _cellularNetworkType;
  NetworkType           get   networkType                   => _networkType;
  int                   get   wirelessNetworkSignalLevel    => _wirelessNetworkSignalLevel;
  int                 get   dailyDataUsage                => _dailyDataUsage;
  bool                get   hasUsageStatsPermission       => _hasUsageStatsPermission;
  bool                get   vpnActive                     => _vpnActive;

  CellularNetworkType _getCellularNetworkType(int index) {
    if (index < 0 || index >= CellularNetworkType.values.length) {
      return CellularNetworkType.Unknown;
    }
    CellularNetworkType type = CellularNetworkType.values[index];
    if (type == CellularNetworkType.Unused_1 || type == CellularNetworkType.Unused_2) {
      type = CellularNetworkType.Unknown;
    }

    return type;
  }

  void _getNetworkInformation(Map<String, dynamic> map) {
    log("NetworkService: _getNetworkInformation: $map");
    try {
      int networkTypeInt = (map["networkType"] as num?)?.toInt() ?? 0;
      _hasInternetAccess = map["internetAccess"] as bool? ?? false;
      if (networkTypeInt >= 0 && networkTypeInt < NetworkType.values.length) {
        _networkType = NetworkType.values[networkTypeInt];
      } else {
        _networkType = NetworkType.Unknown;
      }
      _vpnActive = map["vpnActive"] as bool? ?? false;

      if (_networkType == NetworkType.Cellular || _networkType == NetworkType.Wifi) {
        _wirelessNetworkSignalLevel = (map["wirelessSignalLevel"] as num?)?.toInt() ?? 0;
      }
      log("NetworkService: parsed type $_networkType, signal $_wirelessNetworkSignalLevel, vpn $_vpnActive");
    } catch (e) {
      log("NetworkService error parsing: $e");
    }
  }

  void _onNetworkChanged(Map<String, dynamic> event) {
    switch (event["name"]) {
      case "NETWORK_AVAILABLE":
        Map<dynamic, dynamic> map = event["arguments"];
        _getNetworkInformation(map.cast<String, dynamic>());
        break;
      case "NETWORK_UNAVAILABLE":
        _hasInternetAccess = false;
        _networkType = NetworkType.Unknown;
        _vpnActive = false;
        break;
      case "CAPABILITIES_CHANGED":
        Map<dynamic, dynamic> map = event["arguments"];
        _getNetworkInformation(map.cast<String, dynamic>());
        break;
      case "CELLULAR_STATE_CHANGED":
        final int? typeIndex = (event["arguments"] as num?)?.toInt();
        if (typeIndex != null) {
          _cellularNetworkType = _getCellularNetworkType(typeIndex);
        }
        notifyListeners();
        break;
    }

    notifyListeners();
  }
}