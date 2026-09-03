import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// Remplace par tes vrais imports Xray
// import 'package:xray_flutter/xray_flutter.dart';

void main() {
  runApp(const MyApp());
}

bool globalConfigLockee = false;

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KCO4P VPN',
      theme: ThemeData(primarySwatch: Colors.blue),
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
  String traffic = "";
  List<String> logs = [];

  TextEditingController hostCtrl = TextEditingController();
  TextEditingController configCtrl = TextEditingController();

  bool configImportee = false;
  String? nomConfig;
  String? dateExpiration;

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
        configCtrl.text = prefs.getString('configCtrl')?? '';
        hostCtrl.text = prefs.getString('hostCtrl')?? '';
      });
      _checkExpiration();
    }
  }

  bool _isExpired() {
    if (dateExpiration == null || dateExpiration!.isEmpty) return false;
    try {
      List<String> parts = dateExpiration!.split('/');
      DateTime exp = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      return DateTime.now().isAfter(exp);
    } catch (e) {
      return false;
    }
  }

  void _checkExpiration() {
    if (_isExpired()) {
      setState(() {
        status = "❌ Configuration expirée";
      });
    }
  }

  // MASQUAGE TOTAL DES LOGS
  void addLog(String msg) {
    String filteredMsg = msg;

    if (configImportee || globalConfigLockee) {
      if (hostCtrl.text.isNotEmpty) {
        filteredMsg = filteredMsg.replaceAll(hostCtrl.text, "***");
      }

      filteredMsg = filteredMsg
        .replaceAll(RegExp(r'auth\.mtn\.cm', caseSensitive: false), '***')
        .replaceAll(RegExp(r'auth\.orange\.cm', caseSensitive: false), '***')
        .replaceAll(RegExp(r'auth\.camtel\.cm', caseSensitive: false), '***')
        .replaceAll(RegExp(r'Host injecté: [^\s]+'), 'Host injecté: ***')
        .replaceAll(RegExp(r'vless://[^@\s]+@([^:\s]+)'), 'vless://***@***')
        .replaceAll(RegExp(r'vmess://[A-Za-z0-9+/=]+'), 'vmess://***')
        .replaceAll(RegExp(r'trojan://[^@\s]+@([^:\s]+)'), 'trojan://***@***')
        .replaceAll(RegExp(r'ss://[^@\s]+@([^:\s]+)'), 'ss://***@***')
        .replaceAll(RegExp(r'"address"\s*:\s*"[^"]+"'), '"address":"***"')
        .replaceAll(RegExp(r'"server"\s*:\s*"[^"]+"'), '"server":"***"')
        .replaceAll(RegExp(r'"add"\s*:\s*"[^"]+"'), '"add":"***"')
        .replaceAll(RegExp(r'host\s*:\s*[^\s,}]+'), 'host:***')
        .replaceAll(RegExp(r'SNI\s*:\s*[^\s,}]+'), 'SNI:***')
        .replaceAll(RegExp(r'servername\s*:\s*[^\s,}]+'), 'servername:***')
        .replaceAll(RegExp(r'peer\s*:\s*[^\s,}]+'), 'peer:***')
        .replaceAll(RegExp(r'[a-zA-Z0-9-]+\.(cm|net|com|org|io)', caseSensitive: false), '***');
    }

    setState(() => logs.add("[${_now()}] $filteredMsg"));
  }

  String _now() {
    final now = DateTime.now();
    return "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
  }

  // LOCK À VIE SUR IMPORT
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

      setState(() {
        configImportee = true;
        globalConfigLockee = true;
        nomConfig = map["nom"]?? "Config Sécurisée";
        dateExpiration = map["exp"]?? "31/12/2099";
        configCtrl.text = map["config"]?? '';
        hostCtrl.text = map["host"]?? '';
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('configLocked', true);
      await prefs.setString('nomConfig', nomConfig?? '');
      await prefs.setString('dateExpiration', dateExpiration?? '');
      await prefs.setString('configCtrl', configCtrl.text);
      await prefs.setString('hostCtrl', hostCtrl.text);

      addLog("🔒 Configuration importée et verrouillée à vie");
    } catch (e) {
      addLog("Erreur import : $e");
    }
  }

  // AUTO-LOCK À LA PREMIÈRE CONFIG MANUELLE
  Future<void> _lockManualConfig() async {
    if (hostCtrl.text.isEmpty || configCtrl.text.isEmpty) {
      addLog("❌ Remplis HOST et CONFIG");
      return;
    }

    setState(() {
      configImportee = true;
      globalConfigLockee = true;
      nomConfig = "Configuration Personnalisée";
      dateExpiration = "31/12/2099";
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('configLocked', true);
    await prefs.setString('nomConfig', nomConfig?? '');
    await prefs.setString('dateExpiration', dateExpiration?? '');
    await prefs.setString('configCtrl', configCtrl.text);
    await prefs.setString('hostCtrl', hostCtrl.text);

    addLog("🔒 Configuration verrouillée à vie");
  }

  void exportConfig(bool lockConfig, String nom, String exp) async {
    if (configImportee) {
      addLog("❌ Export désactivé : config verrouillée");
      return;
    }

    Map<String, dynamic> map = {
      "config": configCtrl.text,
      "host": hostCtrl.text,
      "locked": true,
      "nom": nom,
      "exp": exp,
    };

    String encoded = "kco4p://" + base64Encode(utf8.encode(jsonEncode(map)));
    await Clipboard.setData(ClipboardData(text: encoded));
    addLog("Lien exporté (LOCKED)");
  }

  String buildFinalConfig() {
    String finalCfg = configCtrl.text;
    if (hostCtrl.text.isNotEmpty) {
      finalCfg = finalCfg.replaceAll("REPLACE_HOST", hostCtrl.text);
    }
    addLog("Host injecté: ***");
    return finalCfg;
  }

  void toggle() async {
    if (state == "DISCONNECTED" || state == "") {
      // AUTO-LOCK À LA PREMIÈRE CONNEXION
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

      if (hostCtrl.text.isEmpty || configCtrl.text.isEmpty) {
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
        traffic = "";
      });
      addLog("Déconnecté");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("KCO4P VPN"),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (!configImportee)...[
              TextField(
                controller: hostCtrl,
                decoration: const InputDecoration(
                  labelText: "HOST",
                  border: OutlineInputBorder(),
                  hintText: "ex: auth.mtn.cm",
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: configCtrl,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: "CONFIGURATION",
                  border: OutlineInputBorder(),
                  hintText: "Mettre votre host ici\n\nvless://uuid@REPLACE_HOST:443?...",
                  alignLabelWithHint: true,
                ),
              ),
            ] else...[
              Icon(
                Icons.lock,
                color: _isExpired()? Colors.red : Colors.green,
                size: 64,
              ),
              const SizedBox(height: 12),
              Text(
                nomConfig?? '',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _isExpired()? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isExpired()? Colors.red : Colors.green,
                  ),
                ),
                child: Text(
                  _isExpired()
                    ? "❌ Expiré le : $dateExpiration"
                      : "🔒 Verrouillé à vie",
                  style: TextStyle(
                    color: _isExpired()? Colors.red : Colors.green,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: toggle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: state == "CONNECTED"? Colors.red : Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  state == "CONNECTED"? "DÉCONNECTER" : "CONNECTER",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),

            const SizedBox(height: 16),
            if (status.isNotEmpty)
              Text(status, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),

            const Spacer(),

            if (!configImportee)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: importConfig,
                      icon: const Icon(Icons.download),
                      label: const Text("Importer"),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => exportConfig(true, "FREE SERF KMER", "31/12/2026"),
                      icon: const Icon(Icons.upload),
                      label: const Text("Exporter"),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                    ),
                  ),
                ],
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "Configuration verrouillée à vie",
                      style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
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
      appBar: AppBar(title: const Text("Logs de connexion")),
      body: logs.isEmpty
        ? const Center(child: Text("Aucun log"))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: logs.length,
              itemBuilder: (context, index) {
                String displayLine = logs[index];

                if (globalConfigLockee) {
                  displayLine = displayLine
                    .replaceAll(RegExp(r'auth\.[a-z]+\.cm', caseSensitive: false), '***')
                    .replaceAll(RegExp(r'vless://[^@\s]+@([^:\s]+)'), 'vless://***@***')
                    .replaceAll(RegExp(r'vmess://[A-Za-z0-9+/=]+'), 'vmess://***')
                    .replaceAll(RegExp(r'trojan://[^@\s]+@([^:\s]+)'), 'trojan://***@***')
                    .replaceAll(RegExp(r'ss://[^@\s]+@([^:\s]+)'), 'ss://***@***')
                    .replaceAll(RegExp(r'"address"\s*:\s*"[^"]+"'), '"address":"***"')
                    .replaceAll(RegExp(r'"server"\s*:\s*"[^"]+"'), '"server":"***"')
                    .replaceAll(RegExp(r'[a-zA-Z0-9-]+\.(cm|net|com|org|io)', caseSensitive: false), '***');
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    displayLine,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                );
              },
            ),
    );
  }
}
