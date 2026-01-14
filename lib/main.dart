import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:k_chart/flutter_k_chart.dart'; // 核心库
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
        scaffoldBackgroundColor: AppColors.background,
        cardColor: AppColors.surface,
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.textSecondary),
          onPressed: () {},
        ),
        title: GestureDetector(
          onTap: () => _showSymbolSwitchSheet(context, ref),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.currency_bitcoin, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Text(symbol, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.buyGreen, size: 20),
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
                _buildCard(child: MarketHeader(ticker: ticker)),
                const SizedBox(height: 12),

                // --- K线图区域 ---
                _buildCard(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  height: 450,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: IntervalSelector(
                          currentInterval: interval,
                          onSelected: (val) => ref.read(intervalProvider.notifier).state = val,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Consumer(builder: (context, ref, child) {
                          final candles = ref.watch(candlesProvider('${symbol}_$interval'));
                          if (candles.isEmpty) {
                            return const Center(child: CircularProgressIndicator(color: AppColors.textSecondary));
                          }
                          return KChartWidget(
                            candles,
                            ChartStyle(),
                            ChartColors()
                              ..upColor = AppColors.buyGreen
                              ..dnColor = AppColors.sellRed
                              ..bgColor = [AppColors.surface, AppColors.surface]
                              ..gridColor = Colors.white10
                              ..infoWindowNormalColor = Colors.white
                              ..hCrossColor = Colors.white24
                              ..vCrossColor = Colors.white24
                              // 设置实时价格线颜色
                              ..nowPriceUpColor = AppColors.buyGreen
                              ..nowPriceDnColor = AppColors.sellRed
                              ..nowPriceTextColor = Colors.white,
                            isLine: false, // 蜡烛图
                            mainState: MainState.MA,

                            // 核心修改：将 MACD 改为 NONE
                            secondaryState: SecondaryState.NONE,

                            isTrendLine: false, // 保持你之前添加的修正

                            showNowPrice: true, // 开启实时价格虚线
                            hideGrid: false,
                            onLoadMore: (bool a) {},
                          );
                        }),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // --- 深度图 ---
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text("市场深度 (Order Book)", style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
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
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
      bottomSheet: const BottomActionBar(),
    );
  }

  void _showSymbolSwitchSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        final symbols = ref.read(availableSymbolsProvider);
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: AppColors.textSecondary.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
              const Text("Select Market", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: symbols.length,
                  separatorBuilder: (_, __) => Divider(color: Colors.white.withOpacity(0.05), height: 1),
                  itemBuilder: (context, index) {
                    final s = symbols[index];
                    final isSelected = s == ref.read(symbolProvider);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                      title: Text(s, style: TextStyle(fontSize: 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? AppColors.buyGreen : Colors.white)),
                      trailing: isSelected ? const Icon(Icons.check, color: AppColors.buyGreen) : null,
                      onTap: () {
                        ref.read(symbolProvider.notifier).state = s;
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCard({required Widget child, double? height, EdgeInsetsGeometry? padding}) {
    return Container(
      height: height, width: double.infinity, padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))]),
      child: child,
    );
  }
}

// --- 组件定义 ---

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
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("最新价格 (Last Price)", style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 4),
          Text(ticker!.currentPrice.toString(), style: TextStyle(color: color, fontSize: 30, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ]),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
             Text("24h Change", style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text("${isUp ? '+' : ''}${ticker!.priceChangePercent}%", style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
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
              decoration: isSelected ? BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)) : null,
              child: Text(item, style: TextStyle(color: isSelected ? Colors.white : AppColors.textSecondary, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
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
      decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24)), boxShadow: [BoxShadow(blurRadius: 20, color: Colors.black45)]),
      child: SafeArea(child: Row(children: [
        Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.buyGreen, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), onPressed: () {}, child: const Text("买入 / 做多", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
        const SizedBox(width: 16),
        Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.sellRed, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), onPressed: () {}, child: const Text("卖出 / 做空", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
      ])),
    );
  }
}
