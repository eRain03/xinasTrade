class ApiConfig {
  final String id;
  final String exchange; // 'Bitget', 'Binance', 'OKX'
  final String name; // 用户自定义名称，如 "我的Bitget主号"
  final String apiKey;
  final String secretKey;
  // 注意：出于安全考虑，通常不建议本地明文存储 Passphrase，
  // 但根据需求"输入密码正确则使用"，我们可能需要验证密码。
  // 这里的逻辑是：用户点击切换时输入密码，我们用这个密码去尝试请求一次API，成功则切换。
  // 所以这里不需要存 Passphrase。

  ApiConfig({
    required this.id,
    required this.exchange,
    required this.name,
    required this.apiKey,
    required this.secretKey,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exchange': exchange,
      'name': name,
      'apiKey': apiKey,
      'secretKey': secretKey,
    };
  }

  factory ApiConfig.fromJson(Map<String, dynamic> json) {
    return ApiConfig(
      id: json['id'],
      exchange: json['exchange'],
      name: json['name'],
      apiKey: json['apiKey'],
      secretKey: json['secretKey'],
    );
  }
}
