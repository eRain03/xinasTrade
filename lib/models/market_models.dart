import 'package:k_chart/entity/k_line_entity.dart';

// --- K线数据适配器 ---
class CandleHelper {
  // 解析 REST API (List<dynamic>) -> KLineEntity
  static KLineEntity fromList(List<dynamic> data) {
    return KLineEntity.fromCustom(
      time: data[0], // 毫秒时间戳
      open: double.parse(data[1]),
      high: double.parse(data[2]),
      low: double.parse(data[3]),
      close: double.parse(data[4]),
      vol: double.parse(data[5]), // 基础成交量
      amount: double.parse(data[7]), // 成交额 (Quote Asset Volume)
    );
  }

  // 解析 WebSocket (Map<String, dynamic>) -> KLineEntity
  static KLineEntity fromStream(Map<String, dynamic> data) {
    return KLineEntity.fromCustom(
      time: data['t'],
      open: double.parse(data['o']),
      high: double.parse(data['h']),
      low: double.parse(data['l']),
      close: double.parse(data['c']),
      vol: double.parse(data['v']),
      amount: double.parse(data['q']),
    );
  }
}

// --- 深度数据模型 (Order Book) ---
class OrderBook {
  final List<Order> bids;
  final List<Order> asks;

  OrderBook({required this.bids, required this.asks});

  factory OrderBook.fromSnapshot(Map<String, dynamic> json) {
    List<Order> parse(List<dynamic> list) {
      return list.map((e) => Order(price: double.parse(e[0]), amount: double.parse(e[1]))).toList();
    }
    return OrderBook(bids: parse(json['bids']), asks: parse(json['asks']));
  }
}

class Order {
  final double price;
  final double amount;
  Order({required this.price, required this.amount});
}

// --- 头部 Ticker ---
class Ticker {
  final double currentPrice;
  final double priceChangePercent;

  Ticker({required this.currentPrice, required this.priceChangePercent});

  factory Ticker.fromJson(Map<String, dynamic> json) {
    return Ticker(
      currentPrice: double.parse(json['c']),
      priceChangePercent: double.parse(json['P']),
    );
  }
}
