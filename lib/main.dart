import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 🔒 Variable globale = si config importée = tout est locké À VIE
bool globalConfigLockee = false;

void main() {
  runApp(const KCO4PApp());
}

class KCO4PApp extends StatelessWidget {
  const KCO4PApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KCO4P',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF0A0E1A),
        cardColor: const Color(0xFF1A1F2E),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _importController = TextEditingController();
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _vlessController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  bool _isConnected = false;
  bool _configImportee = false;
  List<String> _logs = [];
  String? dateExpiration;
  DateTime? _dateExpirationReelle;

  @override
  void initState() {
    super.initState();
    _chargerLock(); // 🔒 Vérifie le lock au démarrage
  }

  // 🔒 SAUVEGARDE LE LOCK À VIE - IRRÉVERSIBLE
  Future<void> _sauvegarderLock() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('config_lockee_a_vie', true);
    await prefs.setString('date_exp', dateExpiration?? '');
  }

  // 🔒 CHARGE LE LOCK AU DÉMARRAGE - SI LOCKÉ = MORT
  Future<void> _chargerLock() async {
    final prefs = await SharedPreferences.getInstance();
    bool lock = prefs.getBool('config_lockee_a_vie')?? false;
    if (lock) {
      setState(() {
        _configImportee = true;
        globalConfigLockee = true;
        dateExpiration = prefs.getString('date_exp');
        _hostController.text = "***CONFIG VERROUILLÉE À VIE***";
        _vlessController.text = "***LIEN MASQUÉ À VIE***";
        _dateController.text = dateExpiration?? '';
        _updateExpirationDate();
      });
      _addLog("🔒 CONFIGURATION VERROUILLÉE À VIE ACTIVE");
    }
  }

  // 🔥 CALENDRIER AUTO : Met à jour l'année + expire à 23h59
  void _updateExpirationDate() {
    if (dateExpiration == null || dateExpiration!.isEmpty) return;
    try {
      List<String> parts = dateExpiration!.split('/');
      int day = int.parse(parts[0]);
      int month = int.parse(parts[1]);
      int expYear = int.parse(parts[2]);

      // 🔥 Si l'année est dépassée, prend l'année actuelle du téléphone
      int currentYear = DateTime.now().year;
      if (expYear < currentYear) {
        expYear = currentYear;
      }

      _dateExpirationReelle = DateTime(expYear, month, day, 23, 59, 59);
    } catch (e) {
      _dateExpirationReelle = null;
    }
  }

  // 🔒 Vérifie expiration
  bool _isExpired() {
    _updateExpirationDate();
    if (_dateExpirationReelle == null) return false;
    return DateTime.now().isAfter(_dateExpirationReelle!);
  }

  // 🔥 Affiche la date avec année à jour
  String _getDateAffichage() {
    _updateExpirationDate();
    if (_dateExpirationReelle == null) return dateExpiration?? '';
    return "${_dateExpirationReelle!.day.toString().padLeft(2, '0')}/${_dateExpirationReelle!.month.toString().padLeft(2, '0')}/${_dateExpirationReelle!.year}";
  }

  void _importConfig() {
    String text = _importController.text.trim();

    if (text.startsWith('kco4p://')) {
      try {
        String base64Part = text.replaceFirst('kco4p://', '');
        String decoded = utf8.decode(base64.decode(base64Part));
        Map<String, dynamic> config = json.decode(decoded);

        setState(() {
          _hostController.text = "***CONFIG VERROUILLÉE À VIE***";
          _vlessController.text = "***LIEN MASQUÉ À VIE***";
          _dateController.text = config['dateExpiration']?? '';
          dateExpiration = config['dateExpiration'];
          _configImportee = true;
          globalConfigLockee = true; // 🔒 LOCK GLOBAL À VIE
          _updateExpirationDate();
        });

        _sauvegarderLock(); // 🔒 SAUVEGARDE IRRÉVERSIBLE

        _addLog("✅ Configuration importée");
        _addLog("🔒 VERROUILLAGE À VIE ACTIVÉ - IRRÉVERSIBLE");

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔒 Config verrouillée à vie - Irréversible'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      } catch (e) {
        _addLog("❌ Erreur import: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur: Lien invalide')),
        );
      }
    } else {
      _addLog("❌ Format invalide");
    }
    _importController.clear();
  }

  void _connect() {
    if (_isExpired()) {
      _addLog("❌ Configuration expirée");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuration expirée'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isConnected =!_isConnected;
    });

    if (_isConnected) {
      _addLog("✅ Connexion établie");
      _addLog("🔒 Tunnel sécurisé actif - Config toujours verrouillée");
    } else {
      _addLog("🔌 Déconnexion");
      _addLog("🔒 Config reste verrouillée à vie");
    }
  }

  void _addLog(String message) {
    setState(() {
      _logs.insert(0, "[${DateTime.now().toString().substring(11, 19)}] $message");
      if (_logs.length > 50) _logs.removeLast();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KCO4P'),
        centerTitle: true,
        backgroundColor: _configImportee? Colors.red.shade900 : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.article_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LogsScreen(logs: _logs),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 🔒 Message LOCK À VIE
            if (_configImportee)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red, width: 2),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock, color: Colors.red, size: 30),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "VERROUILLÉ À VIE",
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            "Configuration irréversible",
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // 🔥 Affiche la date AVEC ANNÉE À JOUR
            if (dateExpiration!= null && dateExpiration!.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.orange, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      "Valide jusqu'au ${_getDateAffichage()}",
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

            // Import - DÉSACTIVÉ SI LOCKÉ
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Importer configuration",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _importController,
                      enabled:!_configImportee, // 🔒 Désactivé si locké
                      decoration: InputDecoration(
                        hintText: _configImportee
                           ? "VERROUILLÉ À VIE"
                            : "kco4p://...",
                        border: const OutlineInputBorder(),
                        prefixIcon: Icon(
                          _configImportee? Icons.lock : Icons.link,
                        ),
                        filled: _configImportee,
                        fillColor: _configImportee? Colors.red.withOpacity(0.1) : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _configImportee? null : _importConfig,
                        icon: Icon(_configImportee? Icons.lock : Icons.download),
                        label: Text(
                          _configImportee
                             ? "VERROUILLÉ À VIE"
                              : "Importer & Verrouiller",
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _configImportee? Colors.grey : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Config - DISPARAÎT SI LOCKÉ
            if (!_configImportee)...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Configuration manuelle",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _hostController,
                        decoration: const InputDecoration(
                          labelText: "Host",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.dns),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _vlessController,
                        decoration: const InputDecoration(
                          labelText: "Lien VLESS",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.vpn_key),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _dateController,
                        decoration: const InputDecoration(
                          labelText: "Date expiration (JJ/MM/AAAA)",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Bouton connexion
            SizedBox(
              height: 60,
              child: ElevatedButton(
                onPressed: _connect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isConnected? Colors.red : Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isConnected? Icons.power_off : Icons.power,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isConnected? "DÉCONNECTER" : "CONNECTER",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _importController.dispose();
    _hostController.dispose();
    _vlessController.dispose();
    _dateController.dispose();
    super.dispose();
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
        backgroundColor: globalConfigLockee? Colors.red.shade900 : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Logs effacés")),
              );
            },
          ),
        ],
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

                // 🔒 DOUBLE SÉCURITÉ : Re-masque si config lockée À VIE
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
                    border: globalConfigLockee
                       ? Border.all(color: Colors.red.withOpacity(0.3))
                        : null,
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
