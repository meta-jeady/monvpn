import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:url_launcher/url_launcher.dart'; // ← AJOUT 1

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const Kco4pVPNApp());
}

class Kco4pVPNApp extends StatelessWidget {
  const Kco4pVPNApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KČØ4P VPN',
      theme: ThemeData.light().copyWith( // ← MODIF 1: Thème blanc
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[100],
        ),
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
  late FlutterV2ray v2ray;

  String statut = "DÉCONNECTÉ";
  bool estConnecte = false;
  bool enCours = false;
  String modeSelectionne = "VLESS / VMess";

  final List<String> modes = [
    "VLESS / VMess",
    "UDP",
    "SlowDNS",
    "SSH",
    "Trojan",
  ];

  final TextEditingController hostCtrl = TextEditingController();
  final TextEditingController configCtrl = TextEditingController();
  final List<String> logs = [];
  final ScrollController logScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    v2ray = FlutterV2ray(
      onStatusChanged: (status) {
        if (!mounted) return;
        final state = status.state.toUpperCase();
        addLog("→ $state");

        setState(() {
          if (state == "CONNECTED") {
            statut = "FREE SERF"; // ← MODIF 2: FREE SERF
            estConnecte = true;
            enCours = false;
          } else if (state == "CONNECTING") {
            statut = "CONNEXION...";
            enCours = true;
            estConnecte = false;
          } else {
            statut = "DÉCONNECTÉ";
            estConnecte = false;
            enCours = false;
          }
        });
      },
    );
    initCore();
  }

  Future<void> initCore() async {
    addLog("Démarrage du core...");
    await v2ray.initializeV2Ray();
    try {
      final version = await v2ray.getCoreVersion();
      addLog("Core prêt - Xray $version");
    } catch (e) {
      addLog("Erreur core: $e");
    }
  }

  void addLog(String msg) {
    final time = DateTime.now().toString().substring(11, 19);
    setState(() {
      logs.add("[$time] $msg");
    });
    Future.delayed(const Duration(milliseconds: 80), () {
      if (logScroll.hasClients) {
        logScroll.jumpTo(logScroll.position.maxScrollExtent);
      }
    });
  }

  String get notificationName {
    switch (modeSelectionne) {
      case "UDP":
        return "kčø4p UDP connected";
      case "SlowDNS":
        return "kčø4p SlowDNS connected";
      case "SSH":
        return "kčø4p SSH connected";
      case "Trojan":
        return "kčø4p Trojan connected";
      default:
        return "kčø4p VLESS connected";
    }
  }

  String? buildFinalConfig(String raw, String host) {
    try {
      if (raw.trim().startsWith("{")) {
        addLog("JSON détecté");
        return raw.trim();
      }

      if (!raw.startsWith("vless://") &&
         !raw.startsWith("vmess://") &&
         !raw.startsWith("trojan://")) {
        return null;
      }

      addLog("Transformation du lien...");
      final parser = FlutterV2ray.parseFromURL(raw.trim());
      final full = parser.getFullConfiguration();
      final Map<String, dynamic> json = jsonDecode(full);

      if (host.isNotEmpty && json["outbounds"]!= null && json["outbounds"].isNotEmpty) {
        final outbound = json["outbounds"][0];
        final stream = outbound["streamSettings"]?? {};
        final network = stream["network"]?? "ws";

        if (network == "ws") {
          stream["wsSettings"]??= {};
          stream["wsSettings"]["headers"]??= {};
          stream["wsSettings"]["headers"]["Host"] = host;
          addLog("Host injecté: $host");
        } else if (network == "http" || network == "h2") {
          stream["httpSettings"]??= {};
          stream["httpSettings"]["host"] = [host];
          addLog("Host HTTP injecté: $host");
        }
        outbound["streamSettings"] = stream;
      }

      return jsonEncode(json);
    } catch (e) {
      addLog("Erreur: $e");
      return null;
    }
  }

  Future<void> toggle() async {
    if (estConnecte || enCours) {
      addLog("Déconnexion...");
      await v2ray.stopV2Ray();
      setState(() {
        estConnecte = false;
        enCours = false;
        statut = "DÉCONNECTÉ";
      });
      addLog("Déconnecté");
      return;
    }

    final raw = configCtrl.text.trim();
    final host = hostCtrl.text.trim();

    if (raw.isEmpty) {
      addLog("Aucune configuration");
      return;
    }

    // Pour l'instant seuls VLESS/VMess/Trojan sont supportés
    if (modeSelectionne == "UDP" || modeSelectionne == "SlowDNS" || modeSelectionne == "SSH") {
      addLog("Mode $modeSelectionne pas encore disponible (demain)");
      setState(() => statut = "MODE BIENTÔT DISPO");
      return;
    }

    final config = buildFinalConfig(raw, host);
    if (config == null) {
      setState(() => statut = "CONFIG INVALIDE");
      addLog("Configuration invalide");
      return;
    }

    setState(() {
      enCours = true;
      statut = "CONNEXION...";
    });

    addLog("Mode: $modeSelectionne");
    addLog("Demande permission VPN...");

    try {
      final ok = await v2ray.requestPermission();
      if (!ok) {
        addLog("Permission refusée");
        setState(() {
          enCours = false;
          statut = "PERMISSION REFUSÉE";
        });
        return;
      }

      addLog("Lancement du tunnel...");
      await v2ray.startV2Ray(
        remark: notificationName,
        config: config,
        blockedApps: [],
      );
    } catch (e) {
      addLog("Échec: $e");
      setState(() {
        enCours = false;
        statut = "ÉCHEC";
      });
    }
  }

  void exportConfig() {
    final data = {
      "mode": modeSelectionne,
      "host": hostCtrl.text.trim(),
      "config": configCtrl.text.trim(),
    };
    final jsonStr = jsonEncode(data);
    Clipboard.setData(ClipboardData(text: jsonStr));
    addLog("Configuration exportée (copiée)");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Configuration copiée dans le presse-papiers")),
    );
  }

  void importConfig() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null) return;

    try {
      final map = jsonDecode(data!.text!);
      setState(() {
        modeSelectionne = map["mode"]?? "VLESS / VMess";
        hostCtrl.text = map["host"]?? "";
        configCtrl.text = map["config"]?? "";
      });
      addLog("Configuration importée");
    } catch (e) {
      addLog("Import échoué");
    }
  }

  // ← MODIF 3: Fonction pour ouvrir les logs à part
  void _openLogsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LogsScreen(logs: logs)),
    );
  }

  // ← MODIF 4: Ouvrir WhatsApp
  void _launchWhatsApp() async {
    final url = Uri.parse('https://chat.whatsapp.com/GtBg9UmAV0k0ZwyfA07NkX');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Color get couleur {
    if (estConnecte) return const Color(0xFF10B981); // Vert
    if (enCours) return const Color(0xFFF59E0B);
    if (statut.contains("INVALIDE") || statut.contains("ÉCHEC")) {
      return const Color(0xFF6B7280);
    }
    return const Color(0xFFEF4444);
  }

  @override
  void dispose() {
    hostCtrl.dispose();
    configCtrl.dispose();
    logScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // ← Interface blanche
      appBar: AppBar(
        title: const Text("KČØ4P VPN", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.article),
            tooltip: "Logs",
            onPressed: _openLogsScreen, // ← Écran logs à part
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Message + Dropdown Mode
              const Text(
                "Sélectionne le mode de configuration",
                style: TextStyle(color: Colors.black87, fontSize: 13), // ← Noir
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[100], // ← Gris clair
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButton<String>(
                  value: modeSelectionne,
                  isExpanded: true,
                  dropdownColor: Colors.white,
                  underline: const SizedBox(),
                  style: const TextStyle(color: Colors.black),
                  items: modes.map((m) {
                    return DropdownMenuItem(value: m, child: Text(m));
                  }).toList(),
                  onChanged: (value) {
                    if (value!= null) {
                      setState(() => modeSelectionne = value);
                      addLog("Mode changé → $value");
                    }
                  },
                ),
              ),

              const SizedBox(height: 14),

              // Statut FREE SERF en vert gras
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statut,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: estConnecte? Colors.green : couleur, // ← Vert quand connecté
                    fontSize: 18, // ← Plus gros
                    fontWeight: FontWeight.bold, // ← GRAS
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Bouton Power
              GestureDetector(
                onTap: enCours? null : toggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[100],
                    border: Border.all(color: couleur, width: 4),
                    boxShadow: [
                      BoxShadow(color: couleur.withOpacity(0.35), blurRadius: 25, spreadRadius: 4)
                    ],
                  ),
                  child: Icon(Icons.power_settings_new_rounded, size: 65, color: couleur),
                ),
              ),

              const SizedBox(height: 16),

              // Host
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("HOST (domaine de ton pays)", style: TextStyle(color: Colors.black54, fontSize: 12)),
              ),
              const SizedBox(height: 5),
              TextField(
                controller: hostCtrl,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  hintText: "Exemple: yamo.mtn.cm",
                  hintStyle: const TextStyle(color: Colors.black38),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),

              const SizedBox(height: 10),

              // Configuration
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("CONFIGURATION", style: TextStyle(color: Colors.black54, fontSize: 12)),
              ),
              const SizedBox(height: 5),
              TextField(
                controller: configCtrl,
                maxLines: 3,
                style: const TextStyle(color: Colors.black, fontSize: 12, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: "Colle ton lien vless:// ou vmess:// ou JSON",
                  hintStyle: const TextStyle(color: Colors.black38),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),

              const SizedBox(height: 10),

              // Boutons Import / Export
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: importConfig,
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text("Import"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: exportConfig,
                      icon: const Icon(Icons.upload, size: 18),
                      label: const Text("Export"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Logs aperçu - clique pour ouvrir
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("LOGS", style: TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 5),
              Expanded(
                child: GestureDetector(
                  onTap: _openLogsScreen, // ← Clique pour ouvrir logs
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: logs.isEmpty
                     ? Center(child: Text("Clique pour voir les logs", style: TextStyle(color: Colors.black38)))
                      : ListView.builder(
                          controller: logScroll,
                          itemCount: logs.length > 3? 3 : logs.length,
                          itemBuilder: (_, i) => Text(
                            logs[logs.length - 1 - i],
                            style: const TextStyle(color: Colors.black54, fontSize: 11, fontFamily: 'monospace'),
                          ),
                        ),
                  ),
                ),
              ),

              const SizedBox(height: 8),
              const Text(
                "DEV : kcørp tech serf",
                style: TextStyle(color: Colors.black38, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
      // Bouton WhatsApp vert flottant
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        child: Icon(Icons.chat, color: Colors.white),
        onPressed: _launchWhatsApp,
      ),
    );
  }
}

// ← NOUVEL ÉCRAN LOGS SÉPARÉ
class LogsScreen extends StatelessWidget {
  final List<String> logs;

  const LogsScreen({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Logs'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: logs.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              logs[index],
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          );
        },
      ),
    );
  }
}
