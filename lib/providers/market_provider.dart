import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:candlesticks/candlesticks.dart';
import 'package:binance_market/services/market_service.dart';
import 'package:binance_market/models/market_models.dart';

// --- 全局状态 ---

// 当前选中的交易对
final symbolProvider = StateProvider<String>((ref) => "BTCUSDT");
// 当前 K 线周期
final intervalProvider = StateProvider<String>((ref) => "1h");
// 预设支持的币种列表
final availableSymbolsProvider = Provider<List<String>>((ref) {
  return ['BTCUSDT', 'ETHUSDT', 'SOLUSDT', 'BNBUSDT', 'DOGEUSDT', 'XRPUSDT', 'ADAUSDT', 'AVAXUSDT'];
});

// --- K线状态管理 ---

class CandleStateNotifier extends StateNotifier<List<Candle>> {
  final MarketService _service = MarketService();
  final String symbol;
  final String interval;

  CandleStateNotifier(this.symbol, this.interval) : super([]) {
    loadInitialData();
  }

  Future<void> loadInitialData() async {
    try {
      final candles = await _service.fetchCandles(symbol: symbol, interval: interval);
      state = candles.reversed.toList();
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

      final lastCandle = state[0];

      if (newCandle.date.compareTo(lastCandle.date) == 0) {
        state = [newCandle, ...state.sublist(1)];
      } else if (newCandle.date.isAfter(lastCandle.date)) {
        state = [newCandle, ...state];
      }
    }, onError: (e) {
      print("WS Error: $e");
    });
  }
}

final candlesProvider = StateNotifierProvider.family<CandleStateNotifier, List<Candle>, String>((ref, key) {
  final parts = key.split('_');
  return CandleStateNotifier(parts[0], parts[1]);
});

// --- 深度状态管理 ---

class DepthStateNotifier extends StateNotifier<OrderBook?> {
  final MarketService _service = MarketService();
  final String symbol;

  DepthStateNotifier(this.symbol) : super(null) {
    _connectWebSocket();
  }

  void _connectWebSocket() {
    _service.connectDepthStream(symbol: symbol).listen((event) {
      final json = jsonDecode(event);
      state = OrderBook.fromSnapshot(json);
    });
  }
}

final depthProvider = StateNotifierProvider.family<DepthStateNotifier, OrderBook?, String>((ref, symbol) {
  return DepthStateNotifier(symbol);
});

// --- Ticker (头部价格) 状态管理 ---

class TickerNotifier extends StateNotifier<Ticker?> {
  final MarketService _service = MarketService();
  final String symbol;

  TickerNotifier(this.symbol) : super(null) {
    _connectStream();
  }

  void _connectStream() {
    _service.connectTickerStream(symbol: symbol).listen((event) {
      final json = jsonDecode(event);
      state = Ticker.fromJson(json);
    });
  }
}

final tickerProvider = StateNotifierProvider.family<TickerNotifier, Ticker?, String>((ref, symbol) {
  return TickerNotifier(symbol);
});
