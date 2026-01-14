import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:k_chart/flutter_k_chart.dart';
import 'package:binance_market/theme/app_colors.dart';
import 'package:binance_market/providers/market_provider.dart';
import 'package:binance_market/models/market_models.dart';
import 'package:binance_market/widgets/order_book_widget.dart';

class TradePage extends ConsumerWidget {
  const TradePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听当前交易对
    final symbol = ref.watch(symbolProvider);
    // 监听当前K线周期
    final interval = ref.watch(intervalProvider);
    // 监听 Ticker 数据 (最新价、涨跌幅)
    final ticker = ref.watch(tickerProvider(symbol));
    // 监听 K线数据
    final candles = ref.watch(candlesProvider('${symbol}_$interval'));
    // 监听 15m K线数据 (用于头部计算 24h 涨跌幅)
    final headerCandles = ref.watch(candlesProvider('${symbol}_15m'));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.textSecondary),
          onPressed: () {},
        ),
        // 顶部交易对切换按钮
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
                // 头部：价格与涨跌幅
                _buildCard(child: MarketHeader(ticker: ticker, datas: headerCandles)),
                const SizedBox(height: 12),

                // --- K线图区域 ---
                _buildCard(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  height: 450,
                  child: Column(
                    children: [
                      // K线周期选择器
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: IntervalSelector(
                          currentInterval: interval,
                          onSelected: (val) => ref.read(intervalProvider.notifier).state = val,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // K线图表
                      Expanded(
                        child: Consumer(builder: (context, ref, child) {
                          if (candles.isEmpty) {
                            return const Center(child: CircularProgressIndicator(color: AppColors.textSecondary));
                          }
                          return KChartContainer(candles: candles);
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

  // 显示底部弹窗切换交易对
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

  // 通用卡片构建方法
  Widget _buildCard({required Widget child, double? height, EdgeInsetsGeometry? padding}) {
    return Container(
      height: height, width: double.infinity, padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))]),
      child: child,
    );
  }
}

// --- 组件定义 ---

class KChartContainer extends StatefulWidget {
  final List<KLineEntity> candles;
  const KChartContainer({super.key, required this.candles});

  @override
  State<KChartContainer> createState() => _KChartContainerState();
}

class _KChartContainerState extends State<KChartContainer> {
  @override
  Widget build(BuildContext context) {
    return KChartWidget(
      widget.candles,
      ChartStyle(),
      ChartColors()
        ..upColor = AppColors.buyGreen
        ..dnColor = AppColors.sellRed
        ..bgColor = [AppColors.surface, AppColors.surface]
        ..gridColor = Colors.white10
        ..infoWindowNormalColor = Colors.white
        ..infoWindowTitleColor = AppColors.textSecondary
        ..infoWindowUpColor = AppColors.buyGreen
        ..infoWindowDnColor = AppColors.sellRed
        ..hCrossColor = Colors.white24
        ..vCrossColor = Colors.white24
        ..crossTextColor = Colors.white
        ..nowPriceUpColor = AppColors.buyGreen
        ..nowPriceDnColor = AppColors.sellRed
        ..nowPriceTextColor = Colors.white,
      isLine: false,
      mainState: MainState.MA,
      secondaryState: SecondaryState.NONE,
      isTrendLine: false,
      showNowPrice: true,
      hideGrid: false,
      // 恢复为默认逻辑：点击显示/隐藏十字线
      isTapShowInfoDialog: true,
      onLoadMore: (bool a) {},
    );
  }
}

class MarketHeader extends StatelessWidget {
  final Ticker? ticker;
  final List<KLineEntity>? datas;
  const MarketHeader({super.key, this.ticker, this.datas});
  @override
  Widget build(BuildContext context) {
    double price = 0.0;
    double change = 0.0;
    bool hasData = false;

    if (ticker != null) {
      price = ticker!.currentPrice;
      change = ticker!.priceChangePercent;
      hasData = true;
    } else if (datas != null && datas!.isNotEmpty) {
      final last = datas!.last;
      price = last.close;
      hasData = true;

      final int now = last.time ?? 0;
      final int oneDayAgo = now - 24 * 60 * 60 * 1000;
      final refCandle = datas!.firstWhere(
        (e) => (e.time ?? 0) >= oneDayAgo,
        orElse: () => datas!.first,
      );
      double refPrice = refCandle.open;
      if (refPrice == 0) refPrice = 1;
      change = ((price - refPrice) / refPrice) * 100;
    }

    if (!hasData) return const SizedBox(height: 60);

    final isUp = change >= 0;
    final color = isUp ? AppColors.buyGreen : AppColors.sellRed;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("最新价格 (Last Price)", style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 4),
          Text(price.toString(), style: TextStyle(color: color, fontSize: 30, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ]),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
             Text("24h Change", style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text("${isUp ? '+' : ''}${change.toStringAsFixed(2)}%", style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
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
