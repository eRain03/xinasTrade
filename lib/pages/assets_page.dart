import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:binance_market/theme/app_colors.dart';
import 'package:binance_market/providers/api_provider.dart';

class AssetsPage extends ConsumerStatefulWidget {
  const AssetsPage({super.key});

  @override
  ConsumerState<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends ConsumerState<AssetsPage> {
  bool _isLoading = false;
  List<dynamic> _assets = [];
  String _error = '';
  double _totalUsdtValue = 0.0;
  
  // 最佳收益资产 (模拟数据，因为API未提供历史购买价格)
  Map<String, dynamic>? _bestPerformingAsset;

  final Dio _dio = Dio();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final activeApi = ref.read(activeApiProvider);
      if (activeApi.config != null && activeApi.passphrase != null) {
        _fetchAssets();
      }
    });
  }

  Future<void> _fetchAssets() async {
    final activeApi = ref.read(activeApiProvider);
    
    if (activeApi.config == null || activeApi.passphrase == null) {
      setState(() {
        _error = 'Please select an API and enter passphrase in API Management tab.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
      _totalUsdtValue = 0.0;
      _bestPerformingAsset = null;
    });

    try {
      if (activeApi.config!.exchange != 'Bitget') {
        setState(() {
          _error = 'Only Bitget is supported for now.';
          _isLoading = false;
        });
        return;
      }

      const String baseUrl = 'https://api.bitget.com';
      const String path = '/api/v2/spot/account/assets';
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      String message = timestamp + 'GET' + path;
      List<int> key = utf8.encode(activeApi.config!.secretKey);
      List<int> bytes = utf8.encode(message);
      Hmac hmac = Hmac(sha256, key);
      Digest digest = hmac.convert(bytes);
      String signature = base64.encode(digest.bytes);

      final response = await _dio.get(
        baseUrl + path,
        options: Options(
          headers: {
            'ACCESS-KEY': activeApi.config!.apiKey,
            'ACCESS-SIGN': signature,
            'ACCESS-TIMESTAMP': timestamp,
            'ACCESS-PASSPHRASE': activeApi.passphrase,
            'Content-Type': 'application/json',
            'locale': 'en-US',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['code'] == '00000') {
        final List<dynamic> rawAssets = response.data['data'];
        
        final activeAssets = rawAssets.where((asset) {
          final available = double.tryParse(asset['available'] ?? '0') ?? 0;
          final frozen = double.tryParse(asset['frozen'] ?? '0') ?? 0;
          final locked = double.tryParse(asset['locked'] ?? '0') ?? 0;
          return (available + frozen + locked) > 0;
        }).toList();

        double totalValue = 0.0;
        
        // 模拟计算最佳收益资产 (真实场景需要历史订单数据)
        // 这里我们简单地假设持有价值最高的非USDT资产为"最有价值"资产
        // 或者通过 24h 涨幅来模拟"今日最佳"
        Map<String, dynamic>? bestAsset;
        double maxPnl = -999.0;

        for (var asset in activeAssets) {
          final coin = asset['coin'];
          final available = double.tryParse(asset['available'] ?? '0') ?? 0;
          final frozen = double.tryParse(asset['frozen'] ?? '0') ?? 0;
          final locked = double.tryParse(asset['locked'] ?? '0') ?? 0;
          final amount = available + frozen + locked;
          
          asset['total_amount'] = amount;

          if (coin == 'USDT') {
            totalValue += amount;
            asset['usdt_value'] = amount;
            asset['change_24h'] = 0.0;
          } else {
            try {
              final tickerResponse = await _dio.get(
                '$baseUrl/api/v2/spot/market/tickers',
                queryParameters: {'symbol': '${coin}USDT'},
              );
              
              if (tickerResponse.statusCode == 200 && 
                  tickerResponse.data['code'] == '00000' && 
                  (tickerResponse.data['data'] as List).isNotEmpty) {
                final tickerData = tickerResponse.data['data'][0];
                final price = double.tryParse(tickerData['lastPr'] ?? '0') ?? 0;
                final change24h = double.tryParse(tickerData['change24h'] ?? '0') ?? 0; // 涨跌幅
                
                final value = amount * price;
                totalValue += value;
                asset['usdt_value'] = value;
                asset['change_24h'] = change24h * 100; // 转换为百分比

                // 寻找今日涨幅最高的资产
                if (change24h > maxPnl) {
                  maxPnl = change24h;
                  bestAsset = {
                    'coin': coin,
                    'pnl': change24h * 100,
                    'value': value
                  };
                }

              } else {
                 asset['usdt_value'] = 0.0;
                 asset['change_24h'] = 0.0;
              }
            } catch (e) {
              asset['usdt_value'] = 0.0;
              asset['change_24h'] = 0.0;
            }
          }
        }

        // 按价值排序
        activeAssets.sort((a, b) => (b['usdt_value'] as double).compareTo(a['usdt_value'] as double));

        setState(() {
          _assets = activeAssets;
          _totalUsdtValue = totalValue;
          _bestPerformingAsset = bestAsset;
        });
      } else {
        setState(() {
          _error = 'Error: ${response.data['msg'] ?? 'Unknown error'}';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Connection Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<PieChartSectionData> _getSections() {
    if (_assets.isEmpty || _totalUsdtValue == 0) return [];
    
    // 只显示前5个资产，其他的归为 "Others"
    final topAssets = _assets.take(5).toList();
    final otherAssets = _assets.skip(5).toList();
    
    List<PieChartSectionData> sections = [];
    final colors = [
      const Color(0xFF26A69A), // Green
      const Color(0xFFEF5350), // Red
      const Color(0xFFFFA726), // Orange
      const Color(0xFF42A5F5), // Blue
      const Color(0xFFAB47BC), // Purple
      const Color(0xFF78909C), // Grey
    ];

    for (int i = 0; i < topAssets.length; i++) {
      final asset = topAssets[i];
      final value = asset['usdt_value'] as double;
      final percentage = (value / _totalUsdtValue) * 100;
      
      sections.add(PieChartSectionData(
        color: colors[i % colors.length],
        value: value,
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 50,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ));
    }

    if (otherAssets.isNotEmpty) {
      double otherValue = 0;
      for (var asset in otherAssets) {
        otherValue += asset['usdt_value'] as double;
      }
      final percentage = (otherValue / _totalUsdtValue) * 100;
      sections.add(PieChartSectionData(
        color: colors[5],
        value: otherValue,
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 50,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ));
    }

    return sections;
  }

  @override
  Widget build(BuildContext context) {
    final activeApi = ref.watch(activeApiProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Assets Analysis', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            onPressed: _isLoading ? null : _fetchAssets,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 总资产卡片
            _buildTotalBalanceCard(activeApi),
            
            const SizedBox(height: 24),

            if (_assets.isNotEmpty) ...[
              // 2. 资产分布图 (Pie Chart)
              const Text('Portfolio Allocation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: Row(
                  children: [
                    Expanded(
                      child: PieChart(
                        PieChartData(
                          sections: _getSections(),
                          centerSpaceRadius: 40,
                          sectionsSpace: 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Legend
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _buildLegend(),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 3. 最佳表现资产 & 统计信息
              const Text('Insights', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildInsightCard(
                      title: 'Top Performer (24h)',
                      value: _bestPerformingAsset != null ? _bestPerformingAsset!['coin'] : 'N/A',
                      subValue: _bestPerformingAsset != null ? '+${(_bestPerformingAsset!['pnl'] as double).toStringAsFixed(2)}%' : '',
                      icon: Icons.trending_up,
                      color: AppColors.buyGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInsightCard(
                      title: 'Asset Count',
                      value: '${_assets.length}',
                      subValue: 'Coins Holding',
                      icon: Icons.category,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              
              // 4. 资产列表
              const Text('Assets List', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 12),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _assets.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final asset = _assets[index];
                  final coin = asset['coin'] ?? '';
                  final totalAmount = asset['total_amount'] as double;
                  final usdtValue = asset['usdt_value'] as double;
                  final change24h = asset['change_24h'] as double? ?? 0.0;
                  
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.white.withOpacity(0.1),
                          child: Text(coin.substring(0, 1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(coin, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text('${totalAmount.toStringAsFixed(4)} $coin', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          ],
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('\$${usdtValue.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text(
                              '${change24h >= 0 ? '+' : ''}${change24h.toStringAsFixed(2)}%',
                              style: TextStyle(
                                color: change24h >= 0 ? AppColors.buyGreen : AppColors.sellRed,
                                fontSize: 12,
                                fontWeight: FontWeight.bold
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
            
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Center(child: Text(_error, style: const TextStyle(color: AppColors.sellRed))),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalBalanceCard(ActiveApiState activeApi) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.surface, AppColors.surface.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Balance (USDT)',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            _isLoading ? 'Loading...' : '\$${_totalUsdtValue.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (activeApi.config != null)
            Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.buyGreen, size: 16),
                const SizedBox(width: 4),
                Text('Connected: ${activeApi.config!.name}', style: const TextStyle(color: AppColors.buyGreen, fontSize: 12)),
              ],
            )
          else
            const Text('Not Connected', style: TextStyle(color: AppColors.sellRed, fontSize: 12)),
        ],
      ),
    );
  }

  List<Widget> _buildLegend() {
    final topAssets = _assets.take(5).toList();
    final otherAssets = _assets.skip(5).toList();
    final colors = [
      const Color(0xFF26A69A), const Color(0xFFEF5350), const Color(0xFFFFA726),
      const Color(0xFF42A5F5), const Color(0xFFAB47BC), const Color(0xFF78909C),
    ];

    List<Widget> items = [];
    for (int i = 0; i < topAssets.length; i++) {
      items.add(_buildLegendItem(colors[i % colors.length], topAssets[i]['coin']));
    }
    if (otherAssets.isNotEmpty) {
      items.add(_buildLegendItem(colors[5], 'Others'));
    }
    return items;
  }

  Widget _buildLegendItem(Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildInsightCard({required String title, required String value, required String subValue, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 4),
          Text(subValue, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
