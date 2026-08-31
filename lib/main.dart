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
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
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
            statut = "FREE SERF";
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

  bool get hostRequis {
    return modeSelectionne == "VLESS / VMess" ||
        modeSelectionne == "Trojan" ||
        modeSelectionne == "SlowDNS";
  }

  Map<String, String>? parseUdpSsh(String raw) {
    final regex = RegExp(r'^(.+):(\d+)@(.+):(.+)$');
    final match = regex.firstMatch(raw.trim());
    if (match == null) return null;
    return {
      'ip': match.group(1)!,
      'port': match.group(2)!,
      'username': match.group(3)!,
      'password': match.group(4)!,
    };
  }

  String? buildFinalConfig(String raw, String host) {
    try {
      if (raw.trim().startsWith("{")) {
        addLog("JSON détecté");
        return raw.trim();
      }

      if (raw.startsWith("vless://") || raw.startsWith("vmess://") || raw.startsWith("trojan://")) {
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
            addLog("Host WS injecté: $host");
          } else if (network == "http" || network == "h2") {
            stream["httpSettings"]??= {};
            stream["httpSettings"]["host"] = [host];
            addLog("Host HTTP injecté: $host");
          } else if (network == "tcp" && stream["security"] == "tls") {
            stream["tlsSettings"]??= {};
            stream["tlsSettings"]["serverName"] = host;
            addLog("SNI TLS injecté: $host");
          } else if (network == "grpc") {
            stream["grpcSettings"]??= {};
            stream["grpcSettings"]["serviceName"] = host;
            addLog("SNI gRPC injecté: $host");
          }
          outbound["streamSettings"] = stream;
        }

        return jsonEncode(json);
      }

      if (modeSelectionne == "UDP" || modeSelectionne == "SSH") {
        final data = parseUdpSsh(raw);
        if (data == null) {
          addLog("Format invalide. Ex: 192.168.1.1:1080@user:pass");
          return null;
        }

        addLog("Config ${modeSelectionne}: ${data['ip']}:${data['port']}");
        final json = {
          "outbounds": [
            {
              "protocol": "socks",
              "settings": {
                "servers": [
                  {
                    "address": data['ip'],
                    "port": int.parse(data['port']!),
                    "users": [
                      {
                        "user": data['username'],
                        "pass": data['password']
                      }
                    ]
                  }
                ]
              }
            }
          ]
        };
        return jsonEncode(json);
      }

      if (modeSelectionne == "SlowDNS") {
        if (raw.startsWith("vless://") || raw.startsWith("vmess://")) {
          final parser = FlutterV2ray.parseFromURL(raw.trim());
          final full = parser.getFullConfiguration();
          final Map<String, dynamic> json = jsonDecode(full);

          if (json["outbounds"]!= null && json["outbounds"].isNotEmpty) {
            final outbound = json["outbounds"][0];
            if (outbound["port"] == null) {
              outbound["port"] = 53;
            }
          }

          if (host.isNotEmpty && json["outbounds"]!= null && json["outbounds"].isNotEmpty) {
            final outbound = json["outbounds"][0];
            final stream = outbound["streamSettings"]?? {};
            stream["wsSettings"]??= {};
            stream["wsSettings"]["headers"]??= {};
            stream["wsSettings"]["headers"]["Host"] = host;
            outbound["streamSettings"] = stream;
            addLog("Host SlowDNS injecté: $host");
          }

          return jsonEncode(json);
        }
      }

      return null;
    } catch (e) {
      addLog("Erreur build: $e");
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

    if (hostRequis && host.isEmpty) {
      addLog("ERREUR: Host requis pour $modeSelectionne");
      setState(() => statut = "HOST MANQUANT");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Mets le Host de ton pays d'abord!"),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
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
    if (host.isNotEmpty) addLog("Host: $host");
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
    addLog("Configuration exportée");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Configuration copiée")),
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
      addLog("Import échoué - format invalide");
    }
  }

  void _openLogsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LogsScreen(logs: logs)),
    );
  }

  Color get couleur {
    if (estConnecte) return const Color(0xFF10B981);
    if (enCours) return const Color(0xFFF59E0B);
    if (statut.contains("INVALIDE") || statut.contains("ÉCHEC") || statut.contains("MANQUANT")) {
      return const Color(0xFF6B7280);
    }
    return const Color(0xFFEF4444);
  }

  String get hintConfig {
    switch (modeSelectionne) {
      case "UDP":
      case "SSH":
        return "Exemple: 192.168.1.1:1080@user:pass";
      case "SlowDNS":
        return "Colle ton lien vless:// ou config SlowDNS";
      case "Trojan":
        return "Colle ton lien trojan://";
      default:
        return "Colle ton lien vless:// ou vmess:// ou JSON";
    }
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("KČØ4P VPN", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.article),
            tooltip: "Logs",
            onPressed: _openLogsScreen,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                "Sélectionne le mode de configuration",
                style: TextStyle(color: Colors.black87, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
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
                    color: estConnecte? Colors.green : couleur,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
                  child: enCours
                     ? const CircularProgressIndicator(
                          color: Color(0xFFF59E0B),
                          strokeWidth: 3,
                        )
                      : Icon(Icons.power_settings_new_rounded, size: 65, color: couleur),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    if (hostRequis)
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 14),
                    if (hostRequis) const SizedBox(width: 4),
                    Text(
                      hostRequis? "HOST (Obligatoire)" : "HOST (Optionnel)",
                      style: TextStyle(
                        color: hostRequis? const Color(0xFFEF4444) : Colors.black54,
                        fontSize: 12,
                        fontWeight: hostRequis? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: (hostRequis && hostCtrl.text.isEmpty)
                         ? const Color(0xFFEF4444)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: (hostRequis && hostCtrl.text.isEmpty)
                         ? const Color(0xFFEF4444)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: (hostRequis && hostCtrl.text.isEmpty)
                         ? const Color(0xFFEF4444)
                          : const Color(0xFF10B981),
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onChanged: (v) => setState(() {}),
              ),
              const SizedBox(height: 10),
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
                  hintText: hintConfig,
                  hintStyle: const TextStyle(color: Colors.black38),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
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
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("LOGS", style: TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 5),
              Expanded(
                child: GestureDetector(
                  onTap: _openLogsScreen,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: logs.isEmpty
                     ? const Center(child: Text("Clique pour voir les logs", style: TextStyle(color: Colors.black38)))
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
    );
  }
}

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
            child: SelectableText(
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
