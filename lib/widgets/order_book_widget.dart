import 'package:flutter/material.dart';
import 'package:binance_market/models/market_models.dart';
import 'package:binance_market/theme/app_colors.dart';

class OrderBookWidget extends StatelessWidget {
  final OrderBook orderBook;

  const OrderBookWidget({super.key, required this.orderBook});

  @override
  Widget build(BuildContext context) {
    // 移除 Container 的 color，背景由外部 Card 决定
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bid (买单)
        Expanded(child: _buildColumn(orderBook.bids, AppColors.buyGreen, true)),
        const SizedBox(width: 4), // 中间留一点缝隙
        // Ask (卖单)
        Expanded(child: _buildColumn(orderBook.asks, AppColors.sellRed, false)),
      ],
    );
  }

  Widget _buildColumn(List<Order> orders, Color color, bool isBuy) {
    double maxAmt = 0;
    if (orders.isNotEmpty) {
      maxAmt = orders.map((e) => e.amount).reduce((a, b) => a > b ? a : b);
    }

    // 增加数据显示条数，填满卡片
    final list = orders.take(12).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(isBuy ? "数量(Qty)" : "价格(Price)", style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              Text(isBuy ? "价格(Price)" : "数量(Qty)", style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
            ],
          ),
        ),
        ...list.map((order) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 1.0), // 增加一点行间距
            child: Stack(
              children: [
                Align(
                  alignment: isBuy ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    height: 18, // 稍微调高一点高度
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4), // 内部条形图也搞成小圆角
                    ),
                    width: (order.amount / maxAmt) * 100,
                  ),
                ),
                Container(
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: isBuy
                      ? [
                          Text(order.amount.toStringAsFixed(3), style: const TextStyle(fontSize: 11, color: AppColors.textPrimary)),
                          Text(order.price.toStringAsFixed(2), style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
                        ]
                      : [
                          Text(order.price.toStringAsFixed(2), style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
                          Text(order.amount.toStringAsFixed(3), style: const TextStyle(fontSize: 11, color: AppColors.textPrimary)),
                        ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}
