import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:k_chart/flutter_k_chart.dart';
import 'package:binance_market/services/market_service.dart';
import 'package:binance_market/models/market_models.dart';

final symbolProvider = StateProvider<String>((ref) => "BTCUSDT");
final intervalProvider = StateProvider<String>((ref) => "1h");
final availableSymbolsProvider = Provider<List<String>>((ref) {
  return ['BTCUSDT', 'ETHUSDT', 'SOLUSDT', 'BNBUSDT', 'DOGEUSDT', 'XRPUSDT'];
});

// --- K线状态管理 ---
class CandleStateNotifier extends StateNotifier<List<KLineEntity>> {
  final MarketService _service = MarketService();
  final String symbol;
  final String interval;

  CandleStateNotifier(this.symbol, this.interval) : super([]) {
    loadInitialData();
  }

  Future<void> loadInitialData() async {
    try {
      // 1. 获取数据
      final candles = await _service.fetchCandles(symbol: symbol, interval: interval);
      // 2. 核心：计算指标 (MA, VOL, MACD 等)
      DataUtil.calculate(candles);
      state = candles;
      _connectWebSocket();
    } catch (e) {
      print("Error loading candles: $e");
    }
  }

  void _connectWebSocket() {
    _service.connectCandleStream(symbol: symbol, interval: interval).listen((event) {
      final json = jsonDecode(event);
      final kline = json['k'];
      final newCandle = CandleHelper.fromStream(kline);

      if (state.isEmpty) return;

      // 复制列表以触发状态更新
      List<KLineEntity> datas = List.from(state);
      final lastCandle = datas.last;

      // 实时更新逻辑
      if (newCandle.time == lastCandle.time) {
        datas.last = newCandle;
      } else if (newCandle.time != null && newCandle.time! > lastCandle.time!) {
        datas.add(newCandle);
        // 保持数据量，移除过早数据
        if (datas.length > 2000) datas.removeAt(0);
      }

      // 3. 实时数据也必须重新计算指标
      DataUtil.calculate(datas);
      state = datas;
    });
  }
}

final candlesProvider = StateNotifierProvider.family<CandleStateNotifier, List<KLineEntity>, String>((ref, key) {
  final parts = key.split('_');
  return CandleStateNotifier(parts[0], parts[1]);
});

// --- Ticker Provider ---
class TickerNotifier extends StateNotifier<Ticker?> {
  final MarketService _service = MarketService();
  TickerNotifier(String symbol) : super(null) {
    _service.connectTickerStream(symbol: symbol).listen((event) {
      state = Ticker.fromJson(jsonDecode(event));
    });
  }
}
final tickerProvider = StateNotifierProvider.family<TickerNotifier, Ticker?, String>((ref, symbol) => TickerNotifier(symbol));

// --- Depth Provider ---
class DepthStateNotifier extends StateNotifier<OrderBook?> {
  final MarketService _service = MarketService();
  DepthStateNotifier(String symbol) : super(null) {
    _service.connectDepthStream(symbol: symbol).listen((event) {
      state = OrderBook.fromSnapshot(jsonDecode(event));
    });
  }
}
final depthProvider = StateNotifierProvider.family<DepthStateNotifier, OrderBook?, String>((ref, symbol) => DepthStateNotifier(symbol));
