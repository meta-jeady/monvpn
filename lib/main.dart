import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

void main() {
  runApp(const MyApp());
}

bool globalConfigLockee = false;

// Chiffrement XOR pour SharedPreferences
String _xorEncrypt(String text, String key) {
  List<int> bytes = utf8.encode(text);
  List<int> keyBytes = utf8.encode(key);
  List<int> result = [];
  for (int i = 0; i < bytes.length; i++) {
    result.add(bytes[i] ^ keyBytes[i % keyBytes.length]);
  }
  return base64Encode(result);
}

String _xorDecrypt(String encoded, String key) {
  List<int> bytes = base64Decode(encoded);
  List<int> keyBytes = utf8.encode(key);
  List<int> result = [];
  for (int i = 0; i < bytes.length; i++) {
    result.add(bytes[i] ^ keyBytes[i % keyBytes.length]);
  }
  return utf8.decode(result);
}

const String _encryptionKey = "KCO4P_SECRET_2026_XOR";

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KCO4P VPN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const VpnScreen(),
    );
  }
}

class VpnScreen extends StatefulWidget {
  const VpnScreen({super.key});
  @override
  State<VpnScreen> createState() => _VpnScreenState();
}

class _VpnScreenState extends State<VpnScreen> {
  String state = "";
  String status = "";
  List<String> logs = [];

  TextEditingController hostCtrl = TextEditingController();
  TextEditingController configCtrl = TextEditingController();

  bool configImportee = false;
  String? nomConfig;
  String? dateExpiration;

  String _encryptedConfig = "";
  String _encryptedHost = "";

  @override
  void initState() {
    super.initState();
    _loadLockedConfig();
  }

  void _loadLockedConfig() async {
    final prefs = await SharedPreferences.getInstance();
    bool locked = prefs.getBool('configLocked')?? false;

    if (locked) {
      setState(() {
        configImportee = true;
        globalConfigLockee = true;
        nomConfig = prefs.getString('nomConfig');
        dateExpiration = prefs.getString('dateExpiration');
        _encryptedConfig = prefs.getString('encConfig')?? '';
        _encryptedHost = prefs.getString('encHost')?? '';
        configCtrl.text = '';
        hostCtrl.text = '';
      });
      _checkExpiration();
    }
  }

  // 🔥 CALENDRIER AUTO : suit l'année du téléphone
  bool _isExpired() {
    if (dateExpiration == null || dateExpiration!.isEmpty) return false;
    try {
      List<String> parts = dateExpiration!.split('/');
      int day = int.parse(parts[0]);
      int month = int.parse(parts[1]);
      int expYear = int.parse(parts[2]);

      // Si l'année d'expiration < année actuelle, on prend l'année actuelle
      int currentYear = DateTime.now().year;
      if (expYear < currentYear) {
        expYear = currentYear;
      }

      DateTime exp = DateTime(expYear, month, day);
      return DateTime.now().isAfter(exp);
    } catch (e) {
      return false;
    }
  }

  // Affiche la date d'expiration dynamique
  String _getDynamicExpiration() {
    if (dateExpiration == null || dateExpiration!.isEmpty) return "";
    try {
      List<String> parts = dateExpiration!.split('/');
      int currentYear = DateTime.now().year;
      return "${parts[0]}/${parts[1]}/$currentYear";
    } catch (e) {
      return dateExpiration!;
    }
  }

  void _checkExpiration() {
    if (_isExpired()) {
      setState(() {
        status = "❌ Configuration expirée";
      });
    }
  }

  void addLog(String msg) {
    String filteredMsg = msg;

    if (configImportee || globalConfigLockee) {
      String realHost = _encryptedHost.isNotEmpty? _xorDecrypt(_encryptedHost, _encryptionKey) : '';
      if (realHost.isNotEmpty) {
        filteredMsg = filteredMsg.replaceAll(realHost, "***");
      }

      filteredMsg = filteredMsg
   .replaceAll(RegExp(r'yamo\.mtn\.cm', caseSensitive: false), '***')
   .replaceAll(RegExp(r'auth\.mtn\.cm', caseSensitive: false), '***')
   .replaceAll(RegExp(r'auth\.orange\.cm', caseSensitive: false), '***')
   .replaceAll(RegExp(r'auth\.camtel\.cm', caseSensitive: false), '***')
   .replaceAll(RegExp(r'free\.orange\.cm', caseSensitive: false), '***')
   .replaceAll(RegExp(r'api\.[a-z]+\.cm', caseSensitive: false), '***')
   .replaceAll(RegExp(r'Host injecté: [^\s]+'), 'Host injecté: ***')
   .replaceAll(RegExp(r'vless://[^@\s]+@([^:\s]+)'), 'vless://***@***')
   .replaceAll(RegExp(r'vmess://[A-Za-z0-9+/=]+'), 'vmess://***')
   .replaceAll(RegExp(r'trojan://[^@\s]+@([^:\s]+)'), 'trojan://***@***')
   .replaceAll(RegExp(r'ss://[^@\s]+@([^:\s]+)'), 'ss://***@***')
   .replaceAll(RegExp(r'"address"\s*:\s*"[^"]+"'), '"address":"***"')
   .replaceAll(RegExp(r'"server"\s*:\s*"[^"]+"'), '"server":"***"')
   .replaceAll(RegExp(r'"sni"\s*:\s*"[^"]+"'), '"sni":"***"')
   .replaceAll(RegExp(r'"peer"\s*:\s*"[^"]+"'), '"peer":"***"')
   .replaceAll(RegExp(r'host\s*:\s*[^\s,}\]]+'), 'host:***')
   .replaceAll(RegExp(r'SNI\s*:\s*[^\s,}\]]+'), 'SNI:***')
   .replaceAll(RegExp(r'servername\s*:\s*[^\s,}\]]+'), 'servername:***')
   .replaceAll(RegExp(r'peer\s*:\s*[^\s,}\]]+'), 'peer:***')
   .replaceAll(RegExp(r'[a-zA-Z0-9-]+\.(cm|net|com|org|io|xyz|me|info|biz)', caseSensitive: false), '***')
   .replaceAll(RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}\b'), '***');
    }

    setState(() => logs.add("[${_now()}] $filteredMsg"));
  }

  String _now() {
    final now = DateTime.now();
    return "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
  }

  void importConfig() async {
    if (configImportee) {
      addLog("❌ Configuration déjà verrouillée à vie");
      return;
    }

    final data = await Clipboard.getData('text/plain');
    if (data?.text == null ||!data!.text!.startsWith('kco4p://')) {
      addLog("❌ Lien invalide");
      return;
    }

    try {
      String decoded = utf8.decode(base64Decode(data.text!.split('//')[1]));
      Map<String, dynamic> map = jsonDecode(decoded);

      String tempHost = map["host"]?? '';
      String tempConfig = map["config"]?? '';

      setState(() {
        configImportee = true;
        globalConfigLockee = true;
        nomConfig = map["nom"]?? "Config Sécurisée";
        dateExpiration = map["exp"]?? "31/12/2026"; // Date de base
        _encryptedHost = _xorEncrypt(tempHost, _encryptionKey);
        _encryptedConfig = _xorEncrypt(tempConfig, _encryptionKey);
        configCtrl.text = '';
        hostCtrl.text = '';
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('configLocked', true);
      await prefs.setString('nomConfig', nomConfig?? '');
      await prefs.setString('dateExpiration', dateExpiration?? '');
      await prefs.setString('encHost', _encryptedHost);
      await prefs.setString('encConfig', _encryptedConfig);

      addLog("🔒 Configuration importée et verrouillée à vie");
    } catch (e) {
      addLog("Erreur import : $e");
    }
  }

  Future<void> _lockManualConfig() async {
    if (hostCtrl.text.isEmpty || configCtrl.text.isEmpty) {
      addLog("❌ Remplis HOST et CONFIG");
      return;
    }

    _encryptedHost = _xorEncrypt(hostCtrl.text, _encryptionKey);
    _encryptedConfig = _xorEncrypt(configCtrl.text, _encryptionKey);

    setState(() {
      configImportee = true;
      globalConfigLockee = true;
      nomConfig = "Configuration Personnalisée";
      dateExpiration = "31/12/2026"; // Date de base, s'auto-update
      hostCtrl.text = '';
      configCtrl.text = '';
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('configLocked', true);
    await prefs.setString('nomConfig', nomConfig?? '');
    await prefs.setString('dateExpiration', dateExpiration?? '');
    await prefs.setString('encHost', _encryptedHost);
    await prefs.setString('encConfig', _encryptedConfig);

    addLog("🔒 Configuration verrouillée à vie");
  }

  void exportConfig() async {
    if (configImportee) {
      addLog("❌ Export désactivé : config verrouillée");
      return;
    }

    Map<String, dynamic> map = {
      "config": configCtrl.text,
      "host": hostCtrl.text,
      "locked": true,
      "nom": "FREE SERF KMER",
      "exp": "31/12/2026", // Date de base, s'auto-renouvelle
    };

    String encoded = "kco4p://" + base64Encode(utf8.encode(jsonEncode(map)));
    await Clipboard.setData(ClipboardData(text: encoded));
    addLog("Lien exporté (Auto-renouvellement annuel)");
  }

  String buildFinalConfig() {
    String realConfig = _xorDecrypt(_encryptedConfig, _encryptionKey);
    String realHost = _xorDecrypt(_encryptedHost, _encryptionKey);

    String finalCfg = realConfig;
    if (realHost.isNotEmpty) {
      finalCfg = finalCfg.replaceAll("REPLACE_HOST", realHost);
    }
    addLog("Host injecté: ***");
    return finalCfg;
  }

  void toggle() async {
    if (state == "DISCONNECTED" || state == "") {
      if (!configImportee && hostCtrl.text.isNotEmpty && configCtrl.text.isNotEmpty) {
        await _lockManualConfig();
      }

      if (configImportee && _isExpired()) {
        setState(() {
          status = "❌ Configuration expirée";
        });
        addLog("Connexion bloquée : configuration expirée");
        return;
      }

      if (!configImportee && (hostCtrl.text.isEmpty || configCtrl.text.isEmpty)) {
        addLog("❌ Configuration vide");
        return;
      }

      final finalCfg = buildFinalConfig();
      // await XrayCore.start(finalCfg);
      setState(() {
        state = "CONNECTING";
        status = "Connexion...";
      });
      addLog("Lancement du tunnel...");

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            state = "CONNECTED";
            status = "Connecté";
          });
          addLog("Tunnel actif");
        }
      });

    } else {
      // await XrayCore.stop();
      setState(() {
        state = "DISCONNECTED";
        status = "";
      });
      addLog("Déconnecté");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("KCO4P VPN", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => LogsScreen(logs: logs)),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (!configImportee)...[
              TextField(
                controller: hostCtrl,
                decoration: InputDecoration(
                  labelText: "HOST",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  hintText: null,
                  prefixIcon: const Icon(Icons.dns),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: configCtrl,
                maxLines: 8,
                decoration: InputDecoration(
                  labelText: "CONFIGURATION",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  hintText: "Mettre votre host ici\n\nvless://uuid@REPLACE_HOST:443?...",
                  alignLabelWithHint: true,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 120),
                    child: Icon(Icons.vpn_key),
                  ),
                ),
              ),
            ] else...[
              const SizedBox(height: 20),
              Icon(
                Icons.lock,
                color: _isExpired()? Colors.red : Colors.green,
                size: 80,
              ),
              const SizedBox(height: 16),
              Text(
                nomConfig?? '',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: _isExpired()? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isExpired()? Colors.red : Colors.green,
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isExpired()? Icons.error_outline : Icons.lock,
                      color: _isExpired()? Colors.red : Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isExpired()
                       ? "Expiré le : ${_getDynamicExpiration()}"
                        : "Valide jusqu'au ${_getDynamicExpiration()}", // ← Affiche l'année actuelle
                      style: TextStyle(
                        color: _isExpired()? Colors.red : Colors.green,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: toggle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: state == "CONNECTED"? Colors.red : Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      state == "CONNECTED"? Icons.power_settings_new : Icons.play_arrow,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      state == "CONNECTED"? "DÉCONNECTER" : "CONNECTER",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            if (status.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),

            const Spacer(),

            if (!configImportee)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: importConfig,
                      icon: const Icon(Icons.download),
                      label: const Text("Importer"),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: exportConfig,
                      icon: const Icon(Icons.upload),
                      label: const Text("Exporter"),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange, width: 2),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock, color: Colors.orange, size: 24),
                    SizedBox(width: 12),
                    Text(
                      "Configuration verrouillée à vie",
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class LogsScreen extends StatelessWidget {
  final List<String> logs;
  const LogsScreen({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Logs de connexion"),
        centerTitle: true,
      ),
      body: logs.isEmpty
 ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.article_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text("Aucun log", style: TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
          )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: logs.length,
              itemBuilder: (context, index) {
                String displayLine = logs[index];

                if (globalConfigLockee) {
                  displayLine = displayLine
             .replaceAll(RegExp(r'yamo\.mtn\.cm', caseSensitive: false), '***')
             .replaceAll(RegExp(r'auth\.[a-z]+\.cm', caseSensitive: false), '***')
             .replaceAll(RegExp(r'vless://[^@\s]+@([^:\s]+)'), 'vless://***@***')
             .replaceAll(RegExp(r'vmess://[A-Za-z0-9+/=]+'), 'vmess://***')
             .replaceAll(RegExp(r'trojan://[^@\s]+@([^:\s]+)'), 'trojan://***@***')
             .replaceAll(RegExp(r'ss://[^@\s]+@([^:\s]+)'), 'ss://***@***')
             .replaceAll(RegExp(r'"address"\s*:\s*"[^"]+"'), '"address":"***"')
             .replaceAll(RegExp(r'"server"\s*:\s*"[^"]+"'), '"server":"***"')
             .replaceAll(RegExp(r'[a-zA-Z0-9-]+\.(cm|net|com|org|io|xyz)', caseSensitive: false), '***')
             .replaceAll(RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}\b'), '***');
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    displayLine,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  ),
                );
              },
            ),
    );
  }
}
