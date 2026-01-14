import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:binance_market/theme/app_colors.dart';
import 'package:binance_market/models/api_config.dart';
import 'package:binance_market/providers/api_provider.dart';

class ApiManagementPage extends ConsumerStatefulWidget {
  const ApiManagementPage({super.key});

  @override
  ConsumerState<ApiManagementPage> createState() => _ApiManagementPageState();
}

class _ApiManagementPageState extends ConsumerState<ApiManagementPage> {
  
  String _generateUuid() {
    final random = Random();
    final s = (int n) => (random.nextInt(16)).toRadixString(16);
    return '${s(8)}${s(4)}-${s(4)}-${s(4)}-${s(12)}';
  }

  void _showAddApiDialog() {
    final nameController = TextEditingController();
    final apiKeyController = TextEditingController();
    final secretKeyController = TextEditingController();
    String selectedExchange = 'Bitget';
    final exchanges = ['Bitget', 'Binance', 'OKX'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Add API', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedExchange,
                  dropdownColor: AppColors.surface,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Exchange',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.textSecondary)),
                  ),
                  items: exchanges.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (val) => setState(() => selectedExchange = val!),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Name (e.g. My Main Account)',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.textSecondary)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: apiKeyController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'API Key',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.textSecondary)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: secretKeyController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Secret Key',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.textSecondary)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.isEmpty || apiKeyController.text.isEmpty || secretKeyController.text.isEmpty) {
                  return;
                }
                final newApi = ApiConfig(
                  id: DateTime.now().millisecondsSinceEpoch.toString(), // 使用时间戳代替 UUID
                  exchange: selectedExchange,
                  name: nameController.text,
                  apiKey: apiKeyController.text,
                  secretKey: secretKeyController.text,
                );
                ref.read(apiListProvider.notifier).addApi(newApi);
                Navigator.pop(context);
              },
              child: const Text('Add', style: TextStyle(color: AppColors.buyGreen)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSwitchApiDialog(ApiConfig api) {
    final passphraseController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Switch to ${api.name}', style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please enter your API Passphrase to verify and switch.', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            TextField(
              controller: passphraseController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Passphrase',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.textSecondary)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              if (passphraseController.text.isNotEmpty) {
                // 这里可以添加一个简单的 API 验证逻辑，比如请求一次余额接口
                // 如果成功则切换，失败则提示错误
                // 目前先直接切换
                ref.read(activeApiProvider.notifier).setActive(api, passphraseController.text);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Switched to ${api.name}'), backgroundColor: AppColors.buyGreen),
                );
              }
            },
            child: const Text('Confirm', style: TextStyle(color: AppColors.buyGreen)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final apiList = ref.watch(apiListProvider);
    final activeApi = ref.watch(activeApiProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('API Management', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.buyGreen),
            onPressed: _showAddApiDialog,
          ),
        ],
      ),
      body: apiList.isEmpty
          ? const Center(
              child: Text('No APIs added yet.\nTap + to add one.', 
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary)),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: apiList.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final api = apiList[index];
                final isActive = activeApi.config?.id == api.id;

                return Dismissible(
                  key: Key(api.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: AppColors.sellRed,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (direction) async {
                    return await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: AppColors.surface,
                        title: const Text('Delete API?', style: TextStyle(color: Colors.white)),
                        content: const Text('Are you sure you want to delete this API configuration?', style: TextStyle(color: AppColors.textSecondary)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: AppColors.sellRed))),
                        ],
                      ),
                    );
                  },
                  onDismissed: (direction) {
                    ref.read(apiListProvider.notifier).removeApi(api.id);
                    if (isActive) {
                      ref.read(activeApiProvider.notifier).clear();
                    }
                  },
                  child: InkWell(
                    onTap: () => _showSwitchApiDialog(api),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: isActive ? Border.all(color: AppColors.buyGreen, width: 2) : null,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.api,
                              color: isActive ? AppColors.buyGreen : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(api.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 4),
                                Text(api.exchange, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                const SizedBox(height: 2),
                                Text('${api.apiKey.substring(0, 4)}...${api.apiKey.substring(api.apiKey.length - 4)}', 
                                  style: TextStyle(color: AppColors.textSecondary.withOpacity(0.5), fontSize: 10)),
                              ],
                            ),
                          ),
                          if (isActive)
                            const Icon(Icons.check_circle, color: AppColors.buyGreen),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
