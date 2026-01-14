import 'package:candlesticks/candlesticks.dart';

/// 深度数据模型
class OrderBook {
  final List<Order> bids;
  final List<Order> asks;

  OrderBook({required this.bids, required this.asks});

  factory OrderBook.fromSnapshot(Map<String, dynamic> json) {
    List<Order> parse(List<dynamic> list) {
      return list
          .map((e) => Order(
                price: double.parse(e[0]),
                amount: double.parse(e[1]),
              ))
          .toList();
    }

    return OrderBook(
      bids: parse(json['bids']),
      asks: parse(json['asks']),
    );
  }
}

/// 简单的买卖单模型
class Order {
  final double price;
  final double amount;
  Order({required this.price, required this.amount});
}

/// 24h 迷你行情 (Mini Ticker)
class Ticker {
  final double currentPrice;
  final double priceChangePercent;

  Ticker({required this.currentPrice, required this.priceChangePercent});

  factory Ticker.fromJson(Map<String, dynamic> json) {
    return Ticker(
      currentPrice: double.parse(json['c']), // c = current price
      priceChangePercent: double.parse(json['P']), // P = price change percent
    ); // P = price change percent
  }
}

/// K线数据转换辅助类
class CandleHelper {
  // 解析 REST API
  static Candle fromList(List<dynamic> data) {
    return Candle(
      date: DateTime.fromMillisecondsSinceEpoch(data[0]),
      high: double.parse(data[2]),
      low: double.parse(data[3]),
      open: double.parse(data[1]),
      close: double.parse(data[4]),
      volume: double.parse(data[5]),
    );
  }

  // 解析 WebSocket
  static Candle fromStream(Map<String, dynamic> data) {
    return Candle(
      date: DateTime.fromMillisecondsSinceEpoch(data['t']),
      high: double.parse(data['h']),
      low: double.parse(data['l']),
      open: double.parse(data['o']),
      close: double.parse(data['c']),
      volume: double.parse(data['v']),
    );
  }
}
