import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:binance_market/models/market_models.dart';
import 'package:k_chart/entity/k_line_entity.dart'; // 引入新库

class MarketService {
  final Dio _dio = Dio();
  final String _baseUrl = 'https://api.binance.com';
  final String _wsUrl = 'wss://stream.binance.com:9443/ws';

  /// 获取历史 K 线 (适配 k_chart)
  Future<List<KLineEntity>> fetchCandles({required String symbol, required String interval}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/api/v3/klines',
        queryParameters: {
          'symbol': symbol.toUpperCase(),
          'interval': interval,
          'limit': 1000,
        },
      );

      final List<dynamic> data = response.data;
      // k_chart 需要正序数据 (旧 -> 新)，Binance API 默认就是正序，直接 map 即可
      return data.map((e) => CandleHelper.fromList(e)).toList();
    } catch (e) {
      throw Exception('Failed to load candles: $e');
    }
  }

  /// 建立 K 线 WebSocket 连接
  Stream<dynamic> connectCandleStream({required String symbol, required String interval}) {
    final channel = WebSocketChannel.connect(
      Uri.parse('$_wsUrl/${symbol.toLowerCase()}@kline_$interval'),
    );
    return channel.stream;
  }

  /// 建立深度 WebSocket 连接
  Stream<dynamic> connectDepthStream({required String symbol}) {
    final channel = WebSocketChannel.connect(
      Uri.parse('$_wsUrl/${symbol.toLowerCase()}@depth20@100ms'),
    );
    return channel.stream;
  }

  /// 订阅 24h 迷你行情
  Stream<dynamic> connectTickerStream({required String symbol}) {
    final channel = WebSocketChannel.connect(
      Uri.parse('$_wsUrl/${symbol.toLowerCase()}@miniTicker'),
    );
    return channel.stream;
  }
}
