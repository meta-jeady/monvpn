import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// Remplace par tes vrais imports Xray
// import 'package:xray_flutter/xray_flutter.dart';

void main() {
  runApp(const MyApp());
}

// Variable globale pour les logs
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

  // Variables de verrouillage
  bool configImportee = false;
  String? nomConfig;
  String? dateExpiration;

  @override
  void initState() {
    super.initState();
    _loadLockedConfig();
  }

  // Charge la config lockée au démarrage
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

  // Check si expiré mais on déverrouille PAS
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

  // Logs avec masquage automatique du host
  void addLog(String msg) {
    String filteredMsg = msg;

    // Si config lockée, on masque le host partout
    if (configImportee) {
      filteredMsg = filteredMsg
         .replaceAll(hostCtrl.text, "***")
         .replaceAll(RegExp(r'auth\.mtn\.cm'), '***')
         .replaceAll(RegExp(r'Host injecté: [^\s]+'), 'Host injecté: ***')
         .replaceAll(RegExp(r'vless://[^@\s]+@([^:\s]+)'), 'vless://***@***')
         .replaceAll(RegExp(r'vmess://[A-Za-z0-9+/=]+'), 'vmess://***')
         .replaceAll(RegExp(r'trojan://[^@\s]+@([^:\s]+)'), 'trojan://***@***')
         .replaceAll(RegExp(r'"address":\s*"[^"]+"'), '"address": "***"')
         .replaceAll(RegExp(r'"server":\s*"[^"]+"'), '"server": "***"')
         .replaceAll(RegExp(r'host:\s*[^\s,]+'), 'host: ***')
         .replaceAll(RegExp(r'SNI:\s*[^\s,]+'), 'SNI: ***');
    }

    setState(() => logs.add("[${_now()}] $filteredMsg"));
  }

  String _now() {
    final now = DateTime.now();
    return "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
  }

  // Import config avec sauvegarde
  void importConfig() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text == null) return;

    try {
      String decoded = utf8.decode(base64Decode(data!.text!.split('//')[1]));
      Map<String, dynamic> map = jsonDecode(decoded);

      // Si nouvelle config NON lockée, on déverrouille
      if (map["locked"]!= true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        setState(() {
          configImportee = false;
          globalConfigLockee = false;
          nomConfig = null;
          dateExpiration = null;
        });
        addLog("Import réussi : config déverrouillée");
      } else {
        // Config lockée
        setState(() {
          configImportee = true;
          globalConfigLockee = true;
          nomConfig = map["nom"];
          dateExpiration = map["exp"];
          configCtrl.text = map["config"]?? '';
          hostCtrl.text = map["host"]?? '';
        });

        // Sauvegarde permanente
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('configLocked', true);
        await prefs.setString('nomConfig', nomConfig?? '');
        await prefs.setString('dateExpiration', dateExpiration?? '');
        await prefs.setString('configCtrl', configCtrl.text);
        await prefs.setString('hostCtrl', hostCtrl.text);

        addLog("Import réussi : ${nomConfig}");
      }
    } catch (e) {
      addLog("Erreur import : $e");
    }
  }

  // Export config avec option lock
  void exportConfig(bool lockConfig, String nom, String exp) async {
    Map<String, dynamic> map = {
      "config": configCtrl.text,
      "host": hostCtrl.text,
      "locked": lockConfig,
      "nom": nom,
      "exp": exp,
    };

    String encoded = "kco4p://" + base64Encode(utf8.encode(jsonEncode(map)));
    await Clipboard.setData(ClipboardData(text: encoded));
    addLog("Lien exporté ${lockConfig? '(LOCKED)' : ''}");
  }

  // Build config finale avec masquage host dans logs
  String buildFinalConfig() {
    String finalCfg = configCtrl.text;
    if (hostCtrl.text.isNotEmpty) {
      finalCfg = finalCfg.replaceAll("REPLACE_HOST", hostCtrl.text);
    }

    addLog("Host injecté: ${configImportee? '***' : hostCtrl.text}");
    return finalCfg;
  }

  // Toggle avec blocage si expiré + pas de reset du lock
  void toggle() async {
    if (state == "DISCONNECTED" || state == "") {
      // Bloque si config lockée ET expirée
      if (configImportee && _isExpired()) {
        setState(() {
          status = "❌ Configuration expirée. Importez une nouvelle config.";
        });
        addLog("Connexion bloquée : configuration expirée");
        return;
      }

      final finalCfg = buildFinalConfig();
      // await XrayCore.start(finalCfg); // Décommente avec ton vrai code
      setState(() {
        state = "CONNECTING";
        status = "Connexion...";
      });
      addLog("Lancement du tunnel...");
    } else {
      // await XrayCore.stop(); // Décommente avec ton vrai code
      setState(() {
        state = "DISCONNECTED";
        status = "";
        traffic = "";
        // IMPORTANT: On touche PAS à configImportee, nomConfig, dateExpiration
        // Ça reste locké même après déco
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
            // AFFICHAGE LOCK OU FIELDS
            if (!configImportee)...[
              TextField(
                controller: hostCtrl,
                decoration: const InputDecoration(
                  labelText: "HOST (domaine de ton pays)",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: configCtrl,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: "CONFIGURATION",
                  border: OutlineInputBorder(),
                ),
              ),
            ] else...[
              Icon(
                Icons.lock,
                color: _isExpired()? Colors.red : Colors.orange,
                size: 48,
              ),
              const SizedBox(height: 8),
              Text(
                nomConfig?? '',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                _isExpired()
                   ? "❌ Expiré le : $dateExpiration"
                    : "Expire le : $dateExpiration",
                style: TextStyle(
                  color: _isExpired()? Colors.red : Colors.grey,
                  fontSize: 14,
                ),
              ),
              if (_isExpired())...[
                const SizedBox(height: 8),
                const Text(
                  "Importez une nouvelle configuration",
                  style: TextStyle(fontSize: 12, color: Colors.red),
                ),
              ]
            ],

            const SizedBox(height: 20),

            // BOUTON CONNECT
            ElevatedButton(
              onPressed: toggle,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: state == "CONNECTED"? Colors.red : Colors.green,
              ),
              child: Text(
                state == "CONNECTED"? "Déconnecter" : "Connecter",
                style: const TextStyle(fontSize: 18),
              ),
            ),

            const SizedBox(height: 12),
            Text(status, style: const TextStyle(fontSize: 14)),
            Text(traffic, style: const TextStyle(fontSize: 12, color: Colors.grey)),

            const Spacer(),

            // BOUTONS IMPORT/EXPORT
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: importConfig,
                    child: const Text("Import"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // Exemple export locké
                      exportConfig(true, "FREE SERF KMER", "31/12/2026");
                    },
                    child: const Text("Export Lien"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ECRAN LOGS avec masquage
class LogsScreen extends StatelessWidget {
  final List<String> logs;
  const LogsScreen({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Logs de connexion")),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: logs.map((line) {
          String displayLine = line;

          // Double sécurité si config lockée
          if (globalConfigLockee) {
            displayLine = displayLine
               .replaceAll(RegExp(r'auth\.mtn\.cm'), '***')
               .replaceAll(RegExp(r'vless://[^@\s]+@([^:\s]+)'), 'vless://***@***')
               .replaceAll(RegExp(r'vmess://[A-Za-z0-9+/=]+'), 'vmess://***')
               .replaceAll(RegExp(r'"address":\s*"[^"]+"'), '"address": "***"');
          }

          return Text(
            displayLine,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          );
        }).toList(),
      ),
    );
  }
}
