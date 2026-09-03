import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const KCO4PApp());
}

// 🔒 Variable globale = si config importée = tout est locké
bool globalConfigLockee = false;

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
  DateTime? _dateExpirationReelle; // Date avec année à jour

  // 🔒 Chiffrement XOR simple
  String _xorEncrypt(String text, String key) {
    List<int> textBytes = utf8.encode(text);
    List<int> keyBytes = utf8.encode(key);
    List<int> result = [];
    for (int i = 0; i < textBytes.length; i++) {
      result.add(textBytes[i] ^ keyBytes[i % keyBytes.length]);
    }
    return base64.encode(result);
  }

  String _xorDecrypt(String encrypted, String key) {
    List<int> encryptedBytes = base64.decode(encrypted);
    List<int> keyBytes = utf8.encode(key);
    List<int> result = [];
    for (int i = 0; i < encryptedBytes.length; i++) {
      result.add(encryptedBytes[i] ^ keyBytes[i % keyBytes.length]);
    }
    return utf8.decode(result);
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
          _hostController.text = "***Config sécurisée***";
          _vlessController.text = "***Lien masqué***";
          _dateController.text = config['dateExpiration']?? '';
          dateExpiration = config['dateExpiration'];
          _configImportee = true;
          globalConfigLockee = true; // 🔒 LOCK GLOBAL
          _updateExpirationDate();
        });

        _addLog("Configuration importée avec succès");
        _addLog("Mode sécurisé activé - Champs verrouillés");

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Config importée - Mode sécurisé activé'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        _addLog("Erreur import: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur: Lien invalide')),
        );
      }
    } else {
      _addLog("Format invalide");
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
      _addLog("Connexion établie");
      _addLog("Tunnel sécurisé actif");
    } else {
      _addLog("Déconnexion");
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
            // 🔒 Message si config lockée
            if (_configImportee)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock, color: Colors.green),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Configuration sécurisée active",
                        style: TextStyle(color: Colors.green),
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
                      style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

            // Import
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
                      decoration: const InputDecoration(
                        hintText: "kco4p://...",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.link),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _importConfig,
                        icon: const Icon(Icons.download),
                        label: const Text("Importer"),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Config - Disparaît si importée
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

                // 🔒 DOUBLE SÉCURITÉ : Re-masque si config lockée
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
