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
  final List<String> logs = [];
  final ScrollController logScroll = ScrollController();

  final List<String> modes = [
    "VLESS / VMess",
    "UDP",
    "SlowDNS",
    "SSH",
    "Trojan",
  ];

  @override
  void initState() {
    super.initState();
    v2ray = FlutterV2ray(
      onStatusChanged: (status) {
        if (!mounted) return;
        final state = status.state.toUpperCase();
        setState(() {
          if (state == "CONNECTED") {
            if (statut!= "FREE SERF") {
              addLog("→ ready to use");
              statut = "FREE SERF";
              estConnecte = true;
              enCours = false;
            }
          } else if (state == "CONNECTING") {
            if (statut!= "CONNEXION...") {
              addLog("→ CONNECTING");
              statut = "CONNEXION...";
              enCours = true;
              estConnecte = false;
            }
          } else {
            if (statut!= "DÉCONNECTÉ") {
              addLog("→ DISCONNECTED");
              statut = "DÉCONNECTÉ";
              estConnecte = false;
              enCours = false;
            }
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

  Color get couleur {
    if (estConnecte) return const Color(0xFF10B981);
    if (enCours) return const Color(0xFFF59E0B);
    if (statut.contains("INVALIDE") || statut.contains("ÉCHEC")) {
      return const Color(0xFF6B7280);
    }
    return const Color(0xFFEF4444);
  }

  void ouvrirEcranMode() {
    switch (modeSelectionne) {
      case "VLESS / VMess":
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => EcranVless(
            v2ray: v2ray,
            addLog: addLog,
            logs: logs,
          ),
        ));
        break;
      case "UDP":
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => EcranUDP(
            v2ray: v2ray,
            addLog: addLog,
            logs: logs,
          ),
        ));
        break;
      case "SlowDNS":
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => EcranSlowDNS(
            v2ray: v2ray,
            addLog: addLog,
            logs: logs,
          ),
        ));
        break;
      case "Trojan":
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => EcranTrojan(
            v2ray: v2ray,
            addLog: addLog,
            logs: logs,
          ),
        ));
        break;
      case "SSH":
        addLog("Mode SSH bientôt disponible");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Mode SSH bientôt disponible")),
        );
        break;
    }
  }

  @override
  void dispose() {
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
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => LogsScreen(logs: logs)
              ));
            },
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
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: ouvrirEcranMode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text("Ouvrir $modeSelectionne", style: const TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 20),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("LOGS", style: TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 5),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (context) => LogsScreen(logs: logs)
                    ));
                  },
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
                          itemCount: logs.length > 5? 5 : logs.length,
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

class EcranVless extends StatefulWidget {
  final FlutterV2ray v2ray;
  final Function(String) addLog;
  final List<String> logs;

  const EcranVless({
    super.key,
    required this.v2ray,
    required this.addLog,
    required this.logs,
  });

  @override
  State<EcranVless> createState() => _EcranVlessState();
}

class _EcranVlessState extends State<EcranVless> {
  final TextEditingController hostCtrl = TextEditingController();
  final TextEditingController configCtrl = TextEditingController();
  bool enCours = false;

  String? buildFinalConfig(String raw, String host) {
    try {
      if (raw.trim().startsWith("{")) {
        widget.addLog("JSON détecté");
        return raw.trim();
      }

      if (!raw.startsWith("vless://") &&
!raw.startsWith("vmess://") &&
!raw.startsWith("trojan://")) {
        return null;
      }

      widget.addLog("Transformation du lien...");
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
          widget.addLog("Host injecté: $host");
        } else if (network == "http" || network == "h2") {
          stream["httpSettings"]??= {};
          stream["httpSettings"]["host"] = [host];
          widget.addLog("Host HTTP injecté: $host");
        }
        outbound["streamSettings"] = stream;
      }

      return jsonEncode(json);
    } catch (e) {
      widget.addLog("Erreur: $e");
      return null;
    }
  }

  Future<void> connecter() async {
    final raw = configCtrl.text.trim();
    final host = hostCtrl.text.trim();

    if (raw.isEmpty) {
      widget.addLog("Aucune configuration");
      return;
    }

    final config = buildFinalConfig(raw, host);
    if (config == null) {
      widget.addLog("Configuration invalide");
      return;
    }

    setState(() => enCours = true);
    widget.addLog("Mode: VLESS / VMess");
    widget.addLog("Demande permission VPN...");

    try {
      final ok = await widget.v2ray.requestPermission();
      if (!ok) {
        widget.addLog("Permission refusée");
        setState(() => enCours = false);
        return;
      }

      widget.addLog("Lancement du tunnel...");
      await widget.v2ray.startV2Ray(
        remark: "kčø4p VLESS connected",
        config: config,
        blockedApps: [],
      );
      Navigator.pop(context);
    } catch (e) {
      widget.addLog("Échec: $e");
      setState(() => enCours = false);
    }
  }

  @override
  void dispose() {
    hostCtrl.dispose();
    configCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("VLESS / VMess"),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
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
              ),
            ),
            const SizedBox(height: 10),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("CONFIGURATION", style: TextStyle(color: Colors.black54, fontSize: 12)),
            ),
            const SizedBox(height: 5),
            Expanded(
              child: TextField(
                controller: configCtrl,
                maxLines: null,
                expands: true,
                style: const TextStyle(color: Colors.black, fontSize: 12, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: "Colle ton lien vless:// ou vmess:// ou JSON",
                  hintStyle: const TextStyle(color: Colors.black38),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: enCours? null : connecter,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(enCours? "CONNEXION..." : "CONNECTER"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EcranUDP extends StatefulWidget {
  final FlutterV2ray v2ray;
  final Function(String) addLog;
  final List<String> logs;

  const EcranUDP({
    super.key,
    required this.v2ray,
    required this.addLog,
    required this.logs,
  });

  @override
  State<EcranUDP> createState() => _EcranUDPState();
}

class _EcranUDPState extends State<EcranUDP> {
  final TextEditingController ipCtrl = TextEditingController();
  final TextEditingController portCtrl = TextEditingController();
  final TextEditingController userCtrl = TextEditingController();
  final TextEditingController passCtrl = TextEditingController();
  final TextEditingController dnsCtrl = TextEditingController();
  bool dnsEnable = true;
  bool enCours = false;

  String? buildUDPConfig() {
    try {
      final ip = ipCtrl.text.trim();
      final port = int.tryParse(portCtrl.text.trim())?? 443;
      final user = userCtrl.text.trim();
      final pass = passCtrl.text.trim();
      final dns = dnsCtrl.text.trim();

      if (ip.isEmpty || user.isEmpty || pass.isEmpty) {
        widget.addLog("IP, User et Pass requis");
        return null;
      }

      widget.addLog("Config UDP: $ip:$port@$user");

      Map<String, dynamic> config = {
        "inbounds": [
          {
            "port": 10808,
            "listen": "127.0.0.1",
            "protocol": "socks",
            "settings": {"udp": true}
          }
        ],
        "outbounds": [
          {
            "protocol": "socks",
            "settings": {
              "servers": [
                {
                  "address": ip,
                  "port": port,
                  "users": [{"user": user, "pass": pass}]
                }
              ]
            },
            "streamSettings": {
              "network": "udp",
              "sockopt": {"mark": 255}
            }
          }
        ]
      };

      if (dnsEnable) {
        config["dns"] = <String, dynamic>{
          "servers": [dns.isNotEmpty? dns : "8.8.8.8", "1.1.1.1"]
        };
      }

      widget.addLog("DNS ${dnsEnable? 'activé' : 'désactivé'}");
      return jsonEncode(config);
    } catch (e) {
      widget.addLog("Erreur UDP: $e");
      return null;
    }
  }

  Future<void> connecter() async {
    final config = buildUDPConfig();
    if (config == null) return;

    setState(() => enCours = true);
    widget.addLog("Mode: UDP");
    widget.addLog("Demande permission VPN...");

    try {
      final ok = await widget.v2ray.requestPermission();
      if (!ok) {
        widget.addLog("Permission refusée");
        setState(() => enCours = false);
        return;
      }

      widget.addLog("Lancement du tunnel...");
      await widget.v2ray.startV2Ray(
        remark: "kčø4p UDP connected",
        config: config,
        blockedApps: [],
      );
      Navigator.pop(context);
    } catch (e) {
      widget.addLog("Échec: $e");
      setState(() => enCours = false);
    }
  }

  @override
  void dispose() {
    ipCtrl.dispose();
    portCtrl.dispose();
    userCtrl.dispose();
    passCtrl.dispose();
    dnsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Mode UDP"),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: ipCtrl,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                labelText: "IP Serveur",
                hintText: "45.76.123.45",
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: portCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                labelText: "Port",
                hintText: "443",
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: userCtrl,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                labelText: "Username",
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passCtrl,
              obscureText: true,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                labelText: "Password",
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Checkbox(
                  value: dnsEnable,
                  onChanged: (val) => setState(() => dnsEnable = val?? true),
                ),
                const Text("Activer DNS", style: TextStyle(color: Colors.black87)),
              ],
            ),
            if (dnsEnable)...[
              const SizedBox(height: 10),
              TextField(
                controller: dnsCtrl,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  labelText: "DNS Server",
                  hintText: "1.1.1.1",
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: enCours? null : connecter,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(enCours? "CONNEXION..." : "CONNECTER"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EcranSlowDNS extends StatefulWidget {
  final FlutterV2ray v2ray;
  final Function(String) addLog;
  final List<String> logs;

  const EcranSlowDNS({
    super.key,
    required this.v2ray,
    required this.addLog,
    required this.logs,
  });

  @override
  State<EcranSlowDNS> createState() => _EcranSlowDNSState();
}

class _EcranSlowDNSState extends State<EcranSlowDNS> {
  final TextEditingController dnsCtrl = TextEditingController();
  final TextEditingController configCtrl = TextEditingController();
  bool enCours = false;

  String? buildSlowDNSConfig() {
    try {
      final raw = configCtrl.text.trim();
      if (raw.startsWith("{")) {
        widget.addLog("JSON SlowDNS custom détecté");
        return raw;
      }

      final dns = dnsCtrl.text.trim();
      if (dns.isEmpty) {
        widget.addLog("SlowDNS nécessite un DNS Server");
        return null;
      }

      widget.addLog("Construction config SlowDNS...");
      Map<String, dynamic> config = {
        "inbounds": [
          {
            "port": 10808,
            "listen": "127.0.0.1",
            "protocol": "socks",
            "settings": {"udp": true}
          }
        ],
        "outbounds": [
          {
            "protocol": "freedom",
            "settings": {"domainStrategy": "UseIP"},
            "streamSettings": {"network": "tcp"}
          }
        ],
        "dns": {
          "servers": [dns, "8.8.8.8"],
          "queryStrategy": "UseIP"
        }
      };
      widget.addLog("Config SlowDNS prête - DNS: $dns");
      return jsonEncode(config);
    } catch (e) {
      widget.addLog("Erreur SlowDNS: $e");
      return null;
    }
  }

  Future<void> connecter() async {
    final config = buildSlowDNSConfig();
    if (config == null) return;

    setState(() => enCours = true);
    widget.addLog("Mode: SlowDNS");
    widget.addLog("Demande permission VPN...");

    try {
      final ok = await widget.v2ray.requestPermission();
      if (!ok) {
        widget.addLog("Permission refusée");
        setState(() => enCours = false);
        return;
      }

      widget.addLog("Lancement du tunnel...");
      await widget.v2ray.startV2Ray(
        remark: "kčø4p SlowDNS connected",
        config: config,
        blockedApps: [],
      );
      Navigator.pop(context);
    } catch (e) {
      widget.addLog("Échec: $e");
      setState(() => enCours = false);
    }
  }

  @override
  void dispose() {
    dnsCtrl.dispose();
    configCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("SlowDNS"),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("DNS SERVER", style: TextStyle(color: Colors.black54, fontSize: 12)),
            ),
            const SizedBox(height: 5),
            TextField(
              controller: dnsCtrl,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                hintText: "1.1.1.1",
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("CONFIG JSON (optionnel)", style: TextStyle(color: Colors.black54, fontSize: 12)),
            ),
            const SizedBox(height: 5),
            Expanded(
              child: TextField(
                controller: configCtrl,
                maxLines: null,
                expands: true,
                style: const TextStyle(color: Colors.black, fontSize: 12, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: "Laisse vide pour config auto\nou colle ton JSON SlowDNS custom",
                  hintStyle: const TextStyle(color: Colors.black38),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: enCours? null : connecter,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(enCours? "CONNEXION..." : "CONNECTER"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EcranTrojan extends StatefulWidget {
  final FlutterV2ray v2ray;
  final Function(String) addLog;
  final List<String> logs;

  const EcranTrojan({
    super.key,
    required this.v2ray,
    required this.addLog,
    required this.logs,
  });

  @override
  State<EcranTrojan> createState() => _EcranTrojanState();
}

class _EcranTrojanState extends State<EcranTrojan> {
  final TextEditingController hostCtrl = TextEditingController();
  final TextEditingController configCtrl = TextEditingController();
  bool enCours = false;

  String? buildFinalConfig(String raw, String host) {
    try {
      if (raw.trim().startsWith("{")) {
        widget.addLog("JSON détecté");
        return raw.trim();
      }

      if (!raw.startsWith("trojan://")) return null;

      widget.addLog("Transformation du lien...");
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
          widget.addLog("Host injecté: $host");
        } else if (network == "http" || network == "h2") {
          stream["httpSettings"]??= {};
          stream["httpSettings"]["host"] = [host];
          widget.addLog("Host HTTP injecté: $host");
        }
        outbound["streamSettings"] = stream;
      }

      return jsonEncode(json);
    } catch (e) {
      widget.addLog("Erreur: $e");
      return null;
    }
  }

  Future<void> connecter() async {
    final raw = configCtrl.text.trim();
    final host = hostCtrl.text.trim();

    if (raw.isEmpty) {
      widget.addLog("Aucune configuration");
      return;
    }

    final config = buildFinalConfig(raw, host);
    if (config == null) {
      widget.addLog("Configuration invalide");
      return;
    }

    setState(() => enCours = true);
    widget.addLog("Mode: Trojan");
    widget.addLog("Demande permission VPN...");

    try {
      final ok = await widget.v2ray.requestPermission();
      if (!ok) {
        widget.addLog("Permission refusée");
        setState(() => enCours = false);
        return;
      }

      widget.addLog("Lancement du tunnel...");
      await widget.v2ray.startV2Ray(
        remark: "kčø4p Trojan connected",
        config: config,
        blockedApps: [],
      );
      Navigator.pop(context);
    } catch (e) {
      widget.addLog("Échec: $e");
      setState(() => enCours = false);
    }
  }

  @override
  void dispose() {
    hostCtrl.dispose();
    configCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Trojan"),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
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
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("CONFIGURATION", style: TextStyle(color: Colors.black54, fontSize: 12)),
            ),
            const SizedBox(height: 5),
            Expanded(
              child: TextField(
                controller: configCtrl,
                maxLines: null,
                expands: true,
                style: const TextStyle(color: Colors.black, fontSize: 12, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: "Colle ton lien trojan:// ou JSON",
                  hintStyle: const TextStyle(color: Colors.black38),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: enCours? null : connecter,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(enCours? "CONNEXION..." : "CONNECTER"),
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

  Color _getLogColor(String log) {
    if (log.contains("ready to use")) return Colors.green;
    if (log.contains("Failed") || log.contains("Erreur") || log.contains("Échec")) return Colors.red;
    if (log.contains("CONNECTING")) return Colors.orange;
    if (log.contains("stopped") || log.contains("Déconnecté")) return Colors.amber;
    return Colors.black87;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Logs'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: logs.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          thickness: 0.5,
          color: Colors.grey[300],
        ),
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            logs[index],
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: _getLogColor(logs[index]),
              fontWeight: logs[index].contains("ready to use")? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
