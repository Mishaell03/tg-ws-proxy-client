class ProxySettings {
  const ProxySettings({
    required this.host,
    required this.port,
    required this.secret,
    required this.dcIp,
    required this.bufferKb,
    required this.poolSize,
    required this.cfProxy,
    required this.cfProxyDomains,
    required this.cfWorkerDomains,
    required this.forceTestDc,
    required this.wsKeepaliveInterval,
  });

  final String host;
  final int port;
  final String secret;
  final List<String> dcIp;
  final int bufferKb;
  final int poolSize;
  final bool cfProxy;
  final List<String> cfProxyDomains;
  final List<String> cfWorkerDomains;
  final bool forceTestDc;
  final int wsKeepaliveInterval;

  factory ProxySettings.fromMap(Map<String, dynamic> map) {
    List<String> strings(String key) =>
        (map[key] as List<dynamic>? ?? const <dynamic>[])
            .map((value) => value.toString())
            .toList();

    int integer(String key, int fallback) =>
        (map[key] as num?)?.toInt() ??
        int.tryParse(map[key]?.toString() ?? '') ??
        fallback;

    return ProxySettings(
      host: map['host']?.toString() ?? '127.0.0.1',
      port: integer('port', 1443),
      secret: map['secret']?.toString() ?? '',
      dcIp: strings('dcIp'),
      bufferKb: integer('bufferKb', 256),
      poolSize: integer('poolSize', 2),
      cfProxy: map['cfProxy'] as bool? ?? true,
      cfProxyDomains: strings('cfProxyDomains'),
      cfWorkerDomains: strings('cfWorkerDomains'),
      forceTestDc: map['forceTestDc'] as bool? ?? false,
      wsKeepaliveInterval: integer('wsKeepaliveInterval', 30),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'host': host,
    'port': port,
    'secret': secret,
    'dcIp': dcIp,
    'bufferKb': bufferKb,
    'poolSize': poolSize,
    'cfProxy': cfProxy,
    'cfProxyDomains': cfProxyDomains,
    'cfWorkerDomains': cfWorkerDomains,
    'forceTestDc': forceTestDc,
    'wsKeepaliveInterval': wsKeepaliveInterval,
  };
}
