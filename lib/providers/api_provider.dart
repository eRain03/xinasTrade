import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:binance_market/models/api_config.dart';

// 存储所有 API 配置
class ApiListNotifier extends StateNotifier<List<ApiConfig>> {
  ApiListNotifier() : super([]) {
    _loadApis();
  }

  Future<void> _loadApis() async {
    final prefs = await SharedPreferences.getInstance();
    final String? apisJson = prefs.getString('saved_apis');
    if (apisJson != null) {
      final List<dynamic> decoded = jsonDecode(apisJson);
      state = decoded.map((e) => ApiConfig.fromJson(e)).toList();
    }
  }

  Future<void> addApi(ApiConfig api) async {
    state = [...state, api];
    await _saveApis();
  }

  Future<void> removeApi(String id) async {
    state = state.where((api) => api.id != id).toList();
    await _saveApis();
  }

  Future<void> _saveApis() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(state.map((e) => e.toJson()).toList());
    await prefs.setString('saved_apis', encoded);
  }
}

final apiListProvider = StateNotifierProvider<ApiListNotifier, List<ApiConfig>>((ref) {
  return ApiListNotifier();
});

// 当前选中的 API 配置 (包含临时输入的 passphrase)
class ActiveApiState {
  final ApiConfig? config;
  final String? passphrase;

  ActiveApiState({this.config, this.passphrase});
}

class ActiveApiNotifier extends StateNotifier<ActiveApiState> {
  ActiveApiNotifier() : super(ActiveApiState());

  void setActive(ApiConfig config, String passphrase) {
    state = ActiveApiState(config: config, passphrase: passphrase);
  }
  
  void clear() {
    state = ActiveApiState();
  }
}

final activeApiProvider = StateNotifierProvider<ActiveApiNotifier, ActiveApiState>((ref) {
  return ActiveApiNotifier();
});
