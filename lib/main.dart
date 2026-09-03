import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  String statut = "DÉCONNECTÉ";
  bool estConnecte = false;
  bool enCours = false;
  String modeSelectionne = "VLESS / VMess";
  bool isLocked = false;

  String? lockedHost;
  String? lockedConfig;
  String? lockedName;

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

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Connected successfully"),
                  backgroundColor: Color(0xFF22C55E),
                  duration: Duration(seconds: 2),
                ),
              );
            }
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

  Future<void> saveLockedConfig({
    required String name,
    required String mode,
    required String host,
    required String config,
  }) async {
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
    if (lockedHost!= null && lockedHost!.isNotEmpty) {
      safeMsg = safeMsg.replaceAll(lockedHost!, "*******");
    }
    if (hostCtrl.text.isNotEmpty && hostCtrl.text!= "*******") {
      safeMsg = safeMsg.replaceAll(hostCtrl.text, "*******");
    }

    final time = DateTime.now().toString().substring(11, 19);
    setState(() {
      logs.add("[$time] $safeMsg");
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

      if (host.isNotEmpty &&
          json["outbounds"]!= null &&
          json["outbounds"].isNotEmpty) {
        final outbound = json["outbounds"][0];
        final stream = outbound["streamSettings"]?? {};
        final network = stream["network"]?? "ws";

        if (network == "ws") {
          stream["wsSettings"]??= {};
          stream["wsSettings"]["headers"]??= {};
          stream["wsSettings"]["headers"]["Host"] = host;
          addLog("Host injecté: *******");
        } else if (network == "http" || network == "h2") {
          stream["httpSettings"]??= {};
          stream["httpSettings"]["host"] = [host];
          addLog("Host HTTP injecté: *******");
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

    final raw = isLocked? (lockedConfig?? "") : configCtrl.text.trim();
    final host = isLocked? (lockedHost?? "") : hostCtrl.text.trim();

    if (raw.isEmpty) {
      addLog("Aucune configuration");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Aucune configuration disponible")),
      );
      return;
    }

    if (modeSelectionne == "UDP" ||
        modeSelectionne == "SlowDNS" ||
        modeSelectionne == "SSH") {
      addLog("Mode $modeSelectionne pas encore disponible");
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

  Future<void> importConfig() async {
    final TextEditingController linkCtrl = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Importer une configuration"),
          content: TextField(
            controller: linkCtrl,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: "Colle ici le lien kco4p://...",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, linkCtrl.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
                foregroundColor: Colors.white,
              ),
              child: const Text("Importer"),
            ),
          ],
        );
      },
    );

    if (result == null || result.isEmpty) {
      addLog("Import annulé");
      return;
    }

    try {
      String content = result;

      if (content.startsWith("kco4p://config/")) {
        content = content.replaceFirst("kco4p://config/", "");
        content = utf8.decode(base64.decode(content));
      }

      bool wasLocked = false;
      if (content.startsWith("KCO4P_LOCKED:")) {
        wasLocked = true;
        content = utf8.decode(
            base64.decode(content.replaceFirst("KCO4P_LOCKED:", "")));
      }

      final map = jsonDecode(content);

      if (map["app"]!= "KČØ4P VPN") {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Lien non compatible")),
        );
        return;
      }

      if (map["expire_date"]!= null) {
        final expire = DateTime.tryParse(map["expire_date"]);
        if (expire!= null && DateTime.now().isAfter(expire)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Cette configuration a expiré")),
          );
          return;
        }
      }

      final name = map["name"]?? "Configuration";
      final mode = map["mode"]?? "VLESS / VMess";
      final host = map["host"]?? "";
      final config = map["config"]?? "";
      final locked = map["locked"] == true || wasLocked;

      if (locked) {
        await saveLockedConfig(
          name: name,
          mode: mode,
          host: host,
          config: config,
        );

        setState(() {
          isLocked = true;
          lockedName = name;
          lockedHost = host;
          lockedConfig = config;
          modeSelectionne = mode;
          hostCtrl.text = "*******";
          configCtrl.text = "******** Configuration verrouillée ********";
        });

        addLog("Configuration verrouillée importée");
      } else {
        setState(() {
          isLocked = false;
          modeSelectionne = mode;
          hostCtrl.text = host;
          configCtrl.text = config;
        });
        addLog("Configuration importée");
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(locked
             ? "Config verrouillée importée : $name"
              : "Importé : $name"),
          backgroundColor: const Color(0xFF22C55E),
        ),
      );
    } catch (e) {
      addLog("Erreur import : $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lien invalide")),
      );
    }
  }

  Future<void> cleanConfig() async {
    if (!isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Aucune configuration verrouillée à effacer")),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Effacer la configuration"),
        content: Text(
          "Supprimer définitivement la configuration \"${lockedName?? 'verrouillée'}\"?\n\nL'app redeviendra vierge.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text("Effacer"),
          ),
        ],
      ),
    );

    if (confirm!= true) return;

    if (estConnecte || enCours) {
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

    addLog("App réinitialisée - configuration supprimée");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Configuration effacée. App vierge."),
        backgroundColor: Color(0xFFEF4444),
      ),
    );
  }

  Color get couleur {
    if (estConnecte) return const Color(0xFF22C55E);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0F2FE),
      appBar: AppBar(
        title: const Text(
          "KČØ4P VPN",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF0EA5E9),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.article_outlined, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => LogsScreen(logs: logs)),
              );
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
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButton<String>(
                  value: modeSelectionne,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: modes
                     .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                     .toList(),
                  onChanged: isLocked
                     ? null
                      : (value) {
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
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      statut,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: estConnecte? const Color(0xFF22C55E) : couleur,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isLocked)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          "🔒 Configuration verrouillée",
                          style: TextStyle(color: Colors.orange, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
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
                    boxShadow: [
                      BoxShadow(
                        color: couleur.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: Icon(
                    Icons.power_settings_new_rounded,
                    size: 65,
                    color: couleur,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "HOST (domaine de ton pays)",
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: hostCtrl,
                enabled:!isLocked,
                obscureText: isLocked,
                decoration: InputDecoration(
                  hintText: "Exemple: yamo.mtn.cm",
                  filled: true,
                  fillColor: isLocked? Colors.grey.shade200 : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "CONFIGURATION",
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ),
              
              const SizedBox(height: 6),
              TextField(
                controller: configCtrl,
                enabled: !isLocked,
                maxLines: 3,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: "Colle ton lien vless:// ou vmess:// ou JSON",
                  filled: true,
                  fillColor: isLocked ? Colors.grey.shade200 : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: importConfig,
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text("Import"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0EA5E9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isLocked ? cleanConfig : null,
                      icon: const Icon(Icons.delete_forever_rounded, size: 18),
                      label: const Text("Clean"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isLocked
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ExportPage(
                                    mode: modeSelectionne,
                                    host: hostCtrl.text,
                                    config: configCtrl.text,
                                  ),
                                ),
                              );
                            },
                      icon: const Icon(Icons.link, size: 18),
                      label: const Text("Export"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22C55E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              const Text(
                "DEV : kcørp tech serf",
                style: TextStyle(color: Colors.black38, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== PAGE EXPORT ====================
class ExportPage extends StatefulWidget {
  final String mode;
  final String host;
  final String config;

  const ExportPage({
    super.key,
    required this.mode,
    required this.host,
    required this.config,
  });

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mets un nom à la configuration")),
      );
      return;
    }

    final data = {
      "app": "KČØ4P VPN",
      "name": nameCtrl.text.trim(),
      "mode": widget.mode,
      "host": widget.host,
      "config": widget.config,
      "locked": lockConfig,
      "expire_date": hasExpire && expireDate != null
          ? expireDate!.toIso8601String()
          : null,
      "created_at": DateTime.now().toIso8601String(),
    };

    String content = jsonEncode(data);

    if (lockConfig) {
      content = "KCO4P_LOCKED:${base64.encode(utf8.encode(content))}";
    }

    final link = "kco4p://config/${base64.encode(utf8.encode(content))}";

    setState(() {
      generatedLink = link;
    });

    Clipboard.setData(ClipboardData(text: link));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Lien copié dans le presse-papiers !"),
        backgroundColor: Color(0xFF22C55E),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0F2FE),
      appBar: AppBar(
        title: const Text("Exporter en Lien", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0EA5E9),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Nom de la configuration",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                hintText: "Ex: Serveur MTN Cameroun",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SwitchListTile(
                title: const Text("Lock config"),
                subtitle: const Text("Configuration verrouillée (recommandé)"),
                value: lockConfig,
                activeColor: const Color(0xFF0EA5E9),
                onChanged: (v) => setState(() => lockConfig = v),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text("Date d'expiration"),
                    value: hasExpire,
                    activeColor: const Color(0xFF0EA5E9),
                    onChanged: (v) => setState(() => hasExpire = v),
                  ),
                  if (hasExpire)
                    ListTile(
                      title: Text(
                        expireDate == null
                            ? "Choisir une date"
                            : "Expire le : ${expireDate!.day}/${expireDate!.month}/${expireDate!.year}",
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setState(() => expireDate = picked);
                        }
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: generateLink,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Générer le lien",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (generatedLink != null) ...[
              const SizedBox(height: 20),
              const Text("Lien généré :", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SelectableText(
                  generatedLink!,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ==================== PAGE LOGS ====================
class LogsScreen extends StatelessWidget {
  final List<String> logs;
  const LogsScreen({super.key, required this.logs});

  Color _getLogColor(String log) {
    if (log.contains("ready to use") || log.contains("Import")) {
      return const Color(0xFF22C55E);
    }
    if (log.contains("Erreur") || log.contains("Échec") || log.contains("expiré")) {
      return const Color(0xFFEF4444);
    }
    if (log.contains("CONNECTING") || log.contains("CONNEXION")) {
      return const Color(0xFFF59E0B);
    }
    return Colors.black87;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0F2FE),
      appBar: AppBar(
        title: const Text("Logs", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0EA5E9),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: logs.isEmpty
          ? const Center(child: Text("Aucun log pour le moment"))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: logs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final log = logs[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    log,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: _getLogColor(log),
                      fontWeight: log.contains("ready to use")
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
    );
  }
}
