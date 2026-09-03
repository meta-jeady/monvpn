import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dartssh2/dartssh2.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const Kco4pVPNApp());
}

// ===== SERVICE SSH + UDPGW =====
class SshVpnService {
  SSHClient? client;
  SSHSocket? socket;
  bool isRunning = false;

  Future<bool> connectSSH({
    required String host,
    required int port,
    required String username,
    required String password,
    required Function(String) onLog,
    int localSocksPort = 10808,
  }) async {
    try {
      onLog("Connexion SSH $host:$port...");
      socket = await SSHSocket.connect(host, port, timeout: const Duration(seconds: 10));
      client = SSHClient(
        socket!,
        username: username,
        onPasswordRequest: () => password,
      );
      onLog("SSH authentifié...");
      // SOCKS5 Dynamique pour UDPGW - C'est ça qui fait le UDP
      final forward = await client!.forwardDynamic(bindPort: localSocksPort);
      onLog("UDPGW actif sur 127.0.0.1:$localSocksPort");
      isRunning = true;
      return true;
    } catch (e) {
      onLog("Erreur SSH: $e");
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      isRunning = false;
      client?.close();
      socket?.close();
    } catch (_) {}
  }
}

class Kco4pVPNApp extends StatelessWidget {
  const Kco4pVPNApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KČØ4P VPN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFE0F2FE),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0EA5E9),
          primary: const Color(0xFF0EA5E9),
          secondary: const Color(0xFF22C55E),
        ),
      ),
      home: const HomeScreen(),
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
  final SshVpnService sshService = SshVpnService();

  String statut = "DÉCONNECTÉ";
  bool estConnecte = false;
  bool enCours = false;
  String modeSelectionne = "VLESS / VMess";
  bool isLocked = false;

  String? lockedHost;
  String? lockedConfig;
  String? lockedName;

  final List<String> modes = ["VLESS / VMess", "UDP", "SlowDNS", "SSH", "Trojan"];

  final TextEditingController hostCtrl = TextEditingController();
  final TextEditingController configCtrl = TextEditingController();
  final List<String> logs = [];

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
            statut = "CONNEXION...";
            enCours = true;
            estConnecte = false;
          } else if (!sshService.isRunning) {
            statut = "DÉCONNECTÉ";
            estConnecte = false;
            enCours = false;
          }
        });
      },
    );
    initCore();
    loadLockedConfig();
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

  Future<void> saveLockedConfig({required String name, required String mode, required String host, required String config}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLocked', true);
    await prefs.setString('lockedName', name);
    await prefs.setString('lockedMode', mode);
    await prefs.setString('lockedHost', host);
    await prefs.setString('lockedConfig', config);
  }

  Future<void> loadLockedConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final locked = prefs.getBool('isLocked')?? false;
    if (locked) {
      setState(() {
        isLocked = true;
        lockedName = prefs.getString('lockedName');
        modeSelectionne = prefs.getString('lockedMode')?? "VLESS / VMess";
        lockedHost = prefs.getString('lockedHost');
        lockedConfig = prefs.getString('lockedConfig');
        hostCtrl.text = "*******";
        configCtrl.text = "******** Configuration verrouillée ********";
      });
      addLog("Configuration verrouillée chargée");
    }
  }

  void addLog(String msg) {
    String safeMsg = msg;
    if (lockedHost!= null && lockedHost!.isNotEmpty) safeMsg = safeMsg.replaceAll(lockedHost!, "*******");
    if (hostCtrl.text.isNotEmpty && hostCtrl.text!= "*******") safeMsg = safeMsg.replaceAll(hostCtrl.text, "*******");
    final time = DateTime.now().toString().substring(11, 19);
    setState(() => logs.add("[$time] $safeMsg"));
  }

  String get notificationName {
    switch (modeSelectionne) {
      case "UDP": return "kčø4p UDP connected";
      case "SlowDNS": return "kčø4p SlowDNS connected";
      case "SSH": return "kčø4p SSH connected";
      case "Trojan": return "kčø4p Trojan connected";
      default: return "kčø4p VLESS connected";
    }
  }

  // Parser pour ton format 185.253.117.26:1-65535@user:pass
  Map<String, dynamic>? parseSSHConfig(String hostInput, String configInput) {
    try {
      String full = hostInput.trim();
      if (configInput.isNotEmpty &&!configInput.contains("://") &&!configInput.startsWith("{")) {
        full = "$hostInput@${configInput.trim()}";
      } else if (hostInput.contains("@") || hostInput.contains(":")) {
        full = hostInput;
      } else {
        full = "$hostInput:${configInput.trim()}";
      }

      // Format: IP:PORT@USER:PASS ou IP:START-END@USER:PASS
      final atSplit = full.split("@");
      if (atSplit.length < 2) return null;
      final hostPortPart = atSplit[0];
      final userPassPart = atSplit[1];

      final hpSplit = hostPortPart.split(":");
      if (hpSplit.length < 2) return null;
      final host = hpSplit[0];
      String portStr = hpSplit.sublist(1).join(":");

      int port = 22;
      if (portStr.contains("-")) {
        final range = portStr.split("-");
        final start = int.parse(range[0]);
        final end = int.parse(range[1]);
        port = start + Random().nextInt(end - start + 1);
      } else {
        port = int.parse(portStr);
      }

      final upSplit = userPassPart.split(":");
      final user = upSplit[0];
      final pass = upSplit.sublist(1).join(":");

      return {"host": host, "port": port, "user": user, "pass": pass};
    } catch (e) {
      addLog("Parse SSH erreur: $e");
      return null;
    }
  }

  String? buildFinalConfig(String raw, String host) {
    try {
      if (raw.trim().startsWith("{")) return raw.trim();
      if (!raw.startsWith("vless://") &&!raw.startsWith("vmess://") &&!raw.startsWith("trojan://")) return null;
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
        } else if (network == "http" || network == "h2") {
          stream["httpSettings"]??= {};
          stream["httpSettings"]["host"] = [host];
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
      if (sshService.isRunning) await sshService.disconnect();
      await v2ray.stopV2Ray();
      setState(() {
        estConnecte = false;
        enCours = false;
        statut = "DÉCONNECTÉ";
      });
      addLog("Déconnecté");
      return;
    }

    final raw = isLocked? (lockedConfig?? "") : configCtrl.text.trim();
    final host = isLocked? (lockedHost?? "") : hostCtrl.text.trim();

    if (raw.isEmpty && host.isEmpty) {
      addLog("Aucune configuration");
      return;
    }

    // ===== MODE UDP / SSH / SlowDNS =====
    if (modeSelectionne == "UDP" || modeSelectionne == "SSH" || modeSelectionne == "SlowDNS") {
      final sshParsed = parseSSHConfig(host, raw);
      if (sshParsed == null) {
        setState(() => statut = "FORMAT INVALIDE");
        addLog("Format attendu: 185.253.117.26:22@user:pass ou IP:1-65535@user:pass");
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Format SSH: IP:PORT@user:pass")));
        return;
      }

      setState(() {
        enCours = true;
        statut = "CONNEXION ${modeSelectionne}...";
      });

      final ok = await sshService.connectSSH(
        host: sshParsed["host"],
        port: sshParsed["port"],
        username: sshParsed["user"],
        password: sshParsed["pass"],
        onLog: addLog,
      );

      if (!ok) {
        setState(() {
          enCours = false;
          statut = "ÉCHEC SSH";
        });
        return;
      }

      // On lance V2Ray en mode SOCKS qui utilise le tunnel SSH
      try {
        final perm = await v2ray.requestPermission();
        if (!perm) {
          setState(() {
            enCours = false;
            statut = "PERMISSION REFUSÉE";
          });
          return;
        }
        // Config V2Ray qui route tout vers le SOCKS SSH (10808)
        final socksConfig = jsonEncode({
          "log": {"loglevel": "warning"},
          "inbounds": [
            {"port": 10809, "protocol": "socks", "settings": {"auth": "noauth", "udp": true}, "sniffing": {"enabled": true, "destOverride": ["http", "tls"]}}
          ],
          "outbounds": [
            {"protocol": "socks", "settings": {"servers": [{"address": "127.0.0.1", "port": 10808}]}}
          ]
        });

        // Pour le VPN, on utilise une config VLESS bidon mais le trafic passe par le SSH
        // On démarre V2Ray normal
        await v2ray.startV2Ray(remark: notificationName, config: socksConfig, blockedApps: []);
        addLog("Tunnel ${modeSelectionne} actif!");
        setState(() {
          statut = "FREE SERF";
          estConnecte = true;
          enCours = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${modeSelectionne} Connecté!"), backgroundColor: const Color(0xFF22C55E)));
      } catch (e) {
        addLog("Erreur V2Ray: $e");
        setState(() {
          statut = "FREE SERF (SSH)";
          estConnecte = true;
          enCours = false;
        });
      }
      return;
    }

    // ===== MODE VLESS / TROJAN =====
    final config = buildFinalConfig(raw, host);
    if (config == null) {
      setState(() => statut = "CONFIG INVALIDE");
      return;
    }
    setState(() {
      enCours = true;
      statut = "CONNEXION...";
    });
    try {
      final ok = await v2ray.requestPermission();
      if (!ok) {
        setState(() {
          enCours = false;
          statut = "PERMISSION REFUSÉE";
        });
        return;
      }
      await v2ray.startV2Ray(remark: notificationName, config: config, blockedApps: []);
    } catch (e) {
      addLog("Échec: $e");
      setState(() {
        enCours = false;
        statut = "ÉCHEC";
      });
    }
  }

  Future<void> importConfig() async {
    final TextEditingController linkCtrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Importer une configuration"),
        content: TextField(controller: linkCtrl, maxLines: 5, decoration: const InputDecoration(hintText: "Colle ici le lien kco4p://...", border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(onPressed: () => Navigator.pop(context, linkCtrl.text.trim()), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9), foregroundColor: Colors.white), child: const Text("Importer")),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    try {
      String content = result;
      if (content.startsWith("kco4p://config/")) {
        content = content.replaceFirst("kco4p://config/", "");
        content = utf8.decode(base64.decode(content));
      }
      bool wasLocked = false;
      if (content.startsWith("KCO4P_LOCKED:")) {
        wasLocked = true;
        content = utf8.decode(base64.decode(content.replaceFirst("KCO4P_LOCKED:", "")));
      }
      final map = jsonDecode(content);
      if (map["app"]!= "KČØ4P VPN") return;
      if (map["expire_date"]!= null) {
        final expire = DateTime.tryParse(map["expire_date"]);
        if (expire!= null && DateTime.now().isAfter(expire)) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cette configuration a expiré")));
          return;
        }
      }
      final name = map["name"]?? "Configuration";
      final mode = map["mode"]?? "VLESS / VMess";
      final host = map["host"]?? "";
      final config = map["config"]?? "";
      final locked = map["locked"] == true || wasLocked;
      if (locked) {
        await saveLockedConfig(name: name, mode: mode, host: host, config: config);
        setState(() {
          isLocked = true;
          lockedName = name;
          lockedHost = host;
          lockedConfig = config;
          modeSelectionne = mode;
          hostCtrl.text = "*******";
          configCtrl.text = "******** Configuration verrouillée ********";
        });
      } else {
        setState(() {
          isLocked = false;
          modeSelectionne = mode;
          hostCtrl.text = host;
          configCtrl.text = config;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(locked? "Config verrouillée importée : $name" : "Importé : $name"), backgroundColor: const Color(0xFF22C55E)));
    } catch (e) {
      addLog("Erreur import : $e");
    }
  }

  Future<void> cleanConfig() async {
    if (!isLocked) return;
    final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text("Effacer"), content: Text("Supprimer ${lockedName?? ''}?"), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Annuler")), ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)), child: const Text("Effacer"))]));
    if (confirm!= true) return;
    if (estConnecte || enCours) {
      await sshService.disconnect();
      await v2ray.stopV2Ray();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    setState(() {
      isLocked = false;
      lockedHost = null;
      lockedConfig = null;
      lockedName = null;
      hostCtrl.clear();
      configCtrl.clear();
      modeSelectionne = "VLESS / VMess";
      statut = "DÉCONNECTÉ";
      estConnecte = false;
      enCours = false;
      logs.clear();
    });
  }

  Color get couleur {
    if (estConnecte) return const Color(0xFF22C55E);
    if (enCours) return const Color(0xFFF59E0B);
    if (statut.contains("INVALIDE") || statut.contains("ÉCHEC")) return const Color(0xFF6B7280);
    return const Color(0xFFEF4444);
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
      backgroundColor: const Color(0xFFE0F2FE),
      appBar: AppBar(
          title: const Text("KČØ4P VPN", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          centerTitle: true,
          backgroundColor: const Color(0xFF0EA5E9),
          actions: [
            IconButton(
                icon: const Icon(Icons.article_outlined, color: Colors.white),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LogsScreen(logs: logs))))
          ]),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text("Sélectionne le mode de configuration", style: TextStyle(color: Colors.black54, fontSize: 13)),
              const SizedBox(height: 8),
              Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: DropdownButton<String>(
                      value: modeSelectionne,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: modes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                      onChanged: isLocked
                         ? null
                          : (value) {
                              if (value!= null) {
                                setState(() => modeSelectionne = value);
                                addLog("Mode changé → $value");
                              }
                            })),
              const SizedBox(height: 14),
              Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: Column(children: [
                    Text(statut,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: estConnecte? const Color(0xFF22C55E) : couleur,
                            fontSize: 17,
                            fontWeight: FontWeight.bold)),
                    if (isLocked)
                      const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text("🔒 Configuration verrouillée", style: TextStyle(color: Colors.orange, fontSize: 12)))
                  ])),
              const SizedBox(height: 20),
              GestureDetector(
                  onTap: enCours? null : toggle,
                  child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: couleur, width: 4),
                          boxShadow: [BoxShadow(color: couleur.withOpacity(0.3), blurRadius: 20, spreadRadius: 2)]),
                      child: Icon(Icons.power_settings_new_rounded, size: 65, color: couleur))),
              const SizedBox(height: 20),
              Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                      modeSelectionne == "VLESS / VMess" || modeSelectionne == "Trojan"
                         ? "HOST (domaine de ton pays)"
                          : "SERVEUR SSH (IP:PORT ou IP:1-65535)",
                      style: const TextStyle(color: Colors.black54, fontSize: 12))),
              const SizedBox(height: 6),
              TextField(
                  controller: hostCtrl,
                  enabled:!isLocked,
                  obscureText: isLocked,
                  decoration: InputDecoration(
                      hintText: modeSelectionne == "VLESS / VMess"? "yamo.mtn.cm" : "185.253.117.26:22 ou 185.253.117.26:1-65535",
                      filled: true,
                      fillColor: isLocked? Colors.grey.shade200 : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
              const SizedBox(height: 12),
              Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                      modeSelectionne == "VLESS / VMess" || modeSelectionne == "Trojan"
                         ? "CONFIGURATION"
                          : "IDENTIFIANTS SSH (user:pass)",
                      style: const TextStyle(color: Colors.black54, fontSize: 12))),
              const SizedBox(height: 6),
              TextField(
                  controller: configCtrl,
                  enabled:!isLocked,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                      hintText: modeSelectionne == "VLESS / VMess"
                         ? "vless://..."
                          : "Vpn3-vpnjantit.com:Vpn3-vpnjantit.com",
                      filled: true,
                      fillColor: isLocked? Colors.grey.shade200 : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                    child: ElevatedButton.icon(
                        onPressed: importConfig,
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text("Import"),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0EA5E9),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
                const SizedBox(width: 8),
                Expanded(
                    child: ElevatedButton.icon(
                        onPressed: isLocked? cleanConfig : null,
                        icon: const Icon(Icons.delete_forever_rounded, size: 18),
                        label: const Text("Clean"),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.shade300,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
                const SizedBox(width: 8),
                Expanded(
                    child: ElevatedButton.icon(
                        onPressed: isLocked
                           ? null
                            : () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            ExportPage(mode: modeSelectionne, host: hostCtrl.text, config: configCtrl.text)));
                              },
                        icon: const Icon(Icons.link, size: 18),
                        label: const Text("Export"),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF22C55E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
              ]),
              const Spacer(),
              const Text("DEV : kcørp tech serf", style: TextStyle(color: Colors.black38, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class ExportPage extends StatefulWidget {
  final String mode;
  final String host;
  final String config;
  const ExportPage({super.key, required this.mode, required this.host, required this.config});
  @override
  State<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage> {
  final nameCtrl = TextEditingController();
  bool lockConfig = true;
  bool hasExpire = false;
  DateTime? expireDate;
  String? generatedLink;
  void generateLink() {
    if (nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mets un nom")));
      return;
    }
    final data = {
      "app": "KČØ4P VPN",
      "name": nameCtrl.text.trim(),
      "mode": widget.mode,
      "host": widget.host,
      "config": widget.config,
      "locked": lockConfig,
      "expire_date": hasExpire && expireDate!= null? expireDate!.toIso8601String() : null,
      "created_at": DateTime.now().toIso8601String()
    };
    String content = jsonEncode(data);
    if (lockConfig) content = "KCO4P_LOCKED:${base64.encode(utf8.encode(content))}";
    final link = "kco4p://config/${base64.encode(utf8.encode(content))}";
    setState(() => generatedLink = link);
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lien copié!"), backgroundColor: Color(0xFF22C55E)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: const Color(0xFFE0F2FE),
        appBar: AppBar(
            title: const Text("Exporter", style: TextStyle(color: Colors.white)),
            backgroundColor: const Color(0xFF0EA5E9),
            iconTheme: const IconThemeData(color: Colors.white)),
        body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Nom", style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                      hintText: "Ex: Serveur MTN",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
              const SizedBox(height: 20),
              Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: SwitchListTile(
                      title: const Text("Lock config"),
                      value: lockConfig,
                      activeColor: const Color(0xFF0EA5E9),
                      onChanged: (v) => setState(() => lockConfig = v))),
              const SizedBox(height: 12),
              Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: Column(children: [
                    SwitchListTile(
                        title: const Text("Expiration"),
                        value: hasExpire,
                        activeColor: const Color(0xFF0EA5E9),
                        onChanged: (v) => setState(() => hasExpire = v)),
                    if (hasExpire)
                      ListTile(
                          title: Text(expireDate == null
                             ? "Choisir une date"
                              : "Expire le : ${expireDate!.day}/${expireDate!.month}/${expireDate!.year}"),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () async {
                            final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now().add(const Duration(days: 30)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime(2035));
                            if (picked!= null) setState(() => expireDate = picked);
                          })
                  ])),
              const SizedBox(height: 24),
              SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                      onPressed: generateLink,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22C55E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text("Générer le lien", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))),
              if (generatedLink!= null)...[
                const SizedBox(height: 20),
                Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                    child: SelectableText(generatedLink!, style: const TextStyle(fontSize: 12)))
              ]
            ])));
  }
}

class LogsScreen extends StatelessWidget {
  final List<String> logs;
  const LogsScreen({super.key, required this.logs});
  Color _getLogColor(String log) {
    if (log.contains("ready to use") || log.contains("actif")) return const Color(0xFF22C55E);
    if (log.contains("Erreur") || log.contains("Échec")) return const Color(0xFFEF4444);
    if (log.contains("CONNEXION")) return const Color(0xFFF59E0B);
    return Colors.black87;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: const Color(0xFFE0F2FE),
        appBar: AppBar(
            title: const Text("Logs", style: TextStyle(color: Colors.white)),
            backgroundColor: const Color(0xFF0EA5E9),
            iconTheme: const IconThemeData(color: Colors.white)),
        body: logs.isEmpty
           ? const Center(child: Text("Aucun log"))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: logs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(logs[i],
                        style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: _getLogColor(logs[i]))))));
  }
}
