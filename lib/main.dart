import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:candlesticks/candlesticks.dart';
import 'package:binance_market/theme/app_colors.dart';
import 'package:binance_market/providers/market_provider.dart';
import 'package:binance_market/models/market_models.dart';
import 'package:binance_market/widgets/order_book_widget.dart';

void main() {
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bybit Clone',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.background, // 深色底板
        cardColor: AppColors.surface, // 卡片颜色
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          elevation: 0,
        ),
      ),
      home: const TradePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class TradePage extends ConsumerWidget {
  const TradePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final symbol = ref.watch(symbolProvider);
    final interval = ref.watch(intervalProvider);
    final ticker = ref.watch(tickerProvider(symbol));

    return Scaffold(
      drawer: const CoinDrawer(),
      appBar: AppBar(
        leading: Builder(builder: (context) {
          return IconButton(
            icon: const Icon(Icons.dashboard_rounded, color: AppColors.textSecondary),
            onPressed: () => Scaffold.of(context).openDrawer(),
          );
        }),
        title: GestureDetector(
          onTap: () => Scaffold.of(context).openDrawer(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.currency_bitcoin, color: Colors.orange, size: 18), // 装饰图标
                const SizedBox(width: 4),
                Text(symbol, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary, size: 18),
              ],
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                // 1. 头部行情卡片
                _buildCard(
                  child: MarketHeader(ticker: ticker),
                ),

                const SizedBox(height: 12),

                // 2. K线图卡片
                _buildCard(
                  padding: EdgeInsets.zero, // K线图充满卡片，不要内边距
                  height: 450, // 固定高度
                  child: Column(
                    children: [
                      // 周期选择器放在卡片内部顶部
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: IntervalSelector(
                          currentInterval: interval,
                          onSelected: (val) => ref.read(intervalProvider.notifier).state = val,
                        ),
                      ),
                      Divider(height: 1, color: Colors.white.withOpacity(0.05)),
                      Expanded(
                        child: Consumer(builder: (context, ref, child) {
                          final candles = ref.watch(candlesProvider('${symbol}_$interval'));
                          if (candles.isEmpty) {
                            return const Center(child: CircularProgressIndicator(color: AppColors.textSecondary));
                          }
                          return ClipRRect( // 裁剪下方圆角
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                            child: Candlesticks(
                              candles: candles,
                              onLoadMoreCandles: () async {},
                              actions: [], // 隐藏默认按钮保持整洁
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // 3. 深度图卡片
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text("市场深度 (Order Book)",
                          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)
                        ),
                      ),
                      Consumer(builder: (context, ref, child) {
                        final orderBook = ref.watch(depthProvider(symbol));
                        return orderBook != null
                            ? OrderBookWidget(orderBook: orderBook)
                            : const SizedBox(height: 200, child: Center(child: Text("Loading Depth...", style: TextStyle(color: AppColors.textSecondary))));
                      }),
                    ],
                  ),
                ),

                // 底部留白，防止被按钮遮挡
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
      // 底部悬浮按钮
      bottomSheet: const BottomActionBar(),
    );
  }

  // --- 通用卡片构建器 ---
  Widget _buildCard({required Widget child, double? height, EdgeInsetsGeometry? padding}) {
    return Container(
      height: height,
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface, // 卡片背景色
        borderRadius: BorderRadius.circular(16), // 大圆角
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: child,
    );
  }
}

class CoinDrawer extends ConsumerWidget {
  const CoinDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final symbols = ref.watch(availableSymbolsProvider);
    return Drawer(
      backgroundColor: AppColors.surface,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 50, bottom: 20),
            color: AppColors.background,
            width: double.infinity,
            child: const Center(
              child: Text("Markets", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white))
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: symbols.map((s) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.currency_bitcoin, color: AppColors.textSecondary),
                  title: Text(s, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
                  onTap: () {
                    ref.read(symbolProvider.notifier).state = s;
                    Navigator.pop(context);
                  },
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class MarketHeader extends StatelessWidget {
  final Ticker? ticker;

  const MarketHeader({super.key, this.ticker});

  @override
  Widget build(BuildContext context) {
    if (ticker == null) return const SizedBox(height: 60);

    final isUp = ticker!.priceChangePercent >= 0;
    final color = isUp ? AppColors.buyGreen : AppColors.sellRed;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("最新价格 (Last Price)", style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            const SizedBox(height: 4),
            Text(
              ticker!.currentPrice.toString(),
              style: TextStyle(
                color: color,
                fontSize: 30, // 加大字号
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
               Text(
                "24h Change",
                style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                "${isUp ? '+' : ''}${ticker!.priceChangePercent}%",
                style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        )
      ],
    );
  }
}

class IntervalSelector extends StatelessWidget {
  final String currentInterval;
  final Function(String) onSelected;

  const IntervalSelector({super.key, required this.currentInterval, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final intervals = ['15m', '1h', '4h', '1d', '1w'];
    return SizedBox(
      height: 32,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: intervals.map((item) {
          final isSelected = item == currentInterval;
          return InkWell(
            onTap: () => onSelected(item),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: isSelected ? BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ) : null,
              child: Text(
                item,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)), // 底部栏上方圆角
        boxShadow: [BoxShadow(blurRadius: 20, color: Colors.black45)],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.buyGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // 按钮圆角
                ),
                onPressed: () {},
                child: const Text("买入 / 做多", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sellRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // 按钮圆角
                ),
                onPressed: () {},
                child: const Text("卖出 / 做空", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
