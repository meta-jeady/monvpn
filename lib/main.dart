import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';

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
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B1220),
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
          statut = state;
          estConnecte = state == "CONNECTED";
          enCours = state == "CONNECTING";

          if (state == "DISCONNECTED" || state == "STOPPED") {
            estConnecte = false;
            enCours = false;
            statut = "DÉCONNECTÉ";
          }
        });
      },
    );
    initCore();
  }

  Future<void> initCore() async {
    addLog("Démarrage du core Xray...");
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

      if (host.isNotEmpty && json["outbounds"] != null && json["outbounds"].isNotEmpty) {
        final outbound = json["outbounds"][0];
        final stream = outbound["streamSettings"] ?? {};
        final network = stream["network"] ?? "ws";

        if (network == "ws") {
          stream["wsSettings"] ??= {};
          stream["wsSettings"]["headers"] ??= {};
          stream["wsSettings"]["headers"]["Host"] = host;
          addLog("Host injecté: $host");
        } else if (network == "http" || network == "h2") {
          stream["httpSettings"] ??= {};
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
        remark: host.isEmpty ? "KČØ4P" : "KČØ4P ($host)",
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

  Color get couleur {
    if (estConnecte) return const Color(0xFF10B981);
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
      appBar: AppBar(
        title: const Text("KČØ4P VPN", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Statut
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statut,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: couleur, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 18),

              // Bouton
              GestureDetector(
                onTap: enCours ? null : toggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1E293B),
                    border: Border.all(color: couleur, width: 4),
                    boxShadow: [
                      BoxShadow(color: couleur.withOpacity(0.35), blurRadius: 28, spreadRadius: 5)
                    ],
                  ),
                  child: Icon(Icons.power_settings_new_rounded, size: 70, color: couleur),
                ),
              ),

              const SizedBox(height: 18),

              // Host
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("HOST (domaine de ton pays)", style: TextStyle(color: Colors.white60, fontSize: 12)),
              ),
              const SizedBox(height: 5),
              TextField(
                controller: hostCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Exemple: yamo.mtn.cm",
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),

              const SizedBox(height: 12),

              // Configuration
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("CONFIGURATION (colle ton lien ici)", style: TextStyle(color: Colors.white60, fontSize: 12)),
              ),
              const SizedBox(height: 5),
              TextField(
                controller: configCtrl,
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: "vless://... ou vmess://... ou JSON",
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),

              const SizedBox(height: 14),

              // Logs
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("LOGS", style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 5),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: ListView.builder(
                    controller: logScroll,
                    itemCount: logs.length,
                    itemBuilder: (_, i) => Text(
                      logs[i],
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
