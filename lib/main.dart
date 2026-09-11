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
      title: 'KČØ4P VPN Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        // DARK CYAN MODE
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate 900
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF06B6D4), // Cyan 500
          brightness: Brightness.dark,
          primary: const Color(0xFF06B6D4), // Cyan 500 - accent principal
          secondary: const Color(0xFF0E7490), // Cyan 700 - secondaire
          surface: const Color(0xFF1E293B), // Slate 800 - cartes/champs
          background: const Color(0xFF0F172A), // Slate 900 - fond
          error: const Color(0xFFEF4444),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E293B),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E293B),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF06B6D4), width: 2),
          ),
        ),
        dropdownMenuTheme: DropdownMenuThemeData(
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF1E293B),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
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
                  backgroundColor: Color(0xFF06B6D4), // Cyan
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
          backgroundColor: const Color(0xFF1E293B),
          title: const Text("Importer une configuration"),
          content: TextField(
            controller: linkCtrl,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: "Colle ici le lien kco4p://...",
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
                backgroundColor: const Color(0xFF06B6D4), // Cyan
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
          backgroundColor: const Color(0xFF06B6D4), // Cyan
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
        backgroundColor: const Color(0xFF1E293B),
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
    if (estConnecte) return const Color(0xFF06B6D4); // Cyan si connecté
    if (enCours) return const Color(0xFFF59E0B); // Orange
    if (statut.contains("INVALIDE") || statut.contains("ÉCHEC")) {
      return const Color(0xFF64748B); // Slate 500
    }
    return const Color(0xFFEF4444); // Rouge déconnecté
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'KČØ4P VPN Pro',
      applicationVersion: '1.0.0 Pro',
      applicationIcon: const Icon(Icons.shield_moon_rounded, size: 50, color: Color(0xFF06B6D4)),
      children: [
        const Text(
          'KČØ4P VPN Pro - Édition Dark Cyan\n\n'
          'Client VPN sécurisé basé sur Xray/V2Ray avec interface professionnelle.\n\n'
          'Fonctionnalités Pro :\n'
          '• Support VLESS, VMess, Trojan\n'
          '• Import/Export chiffré\n'
          '• Mode verrouillé enterprise\n'
          '• Logs détaillés\n'
          '• Thème Dark Cyan optimisé OLED\n\n'
          'Développé par kcørp tech serf.',
          style: TextStyle(height: 1.5),
        ),
      ],
    );
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
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          "KČØ4P VPN PRO",
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.2),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Color(0xFF06B6D4)),
            onPressed: _showAboutDialog,
            tooltip: 'À propos',
          ),
          IconButton(
            icon: const Icon(Icons.article_outlined, color: Color(0xFF06B6D4)),
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
              Text(
                "Sélectionne le mode de configuration",
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: DropdownButton<String>(
                  value: modeSelectionne,
                  isExpanded: true,
                  underline: const SizedBox(),
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white),
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
  padding: const EdgeInsets.symmetric(vertical: 16),
  decoration: BoxDecoration(
    color: const Color(0xFF1E293B),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: const Color(0xFF334155)),
  ),
  child: Column(
    children: [
      Text(
        statut,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: couleur,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
      if (isLocked)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_rounded, color: Color(0xFFF59E0B), size: 14),
              const SizedBox(width: 4),
              Text(
                "CONFIGURATION VERROUILLÉE",
                style: TextStyle(
                  color: Colors.amber.shade400, 
                  fontSize: 11, 
                  fontWeight: FontWeight.w600
                ),
              ),
            ],
          ),
        ),
    ],
  ),
),
const SizedBox(height: 24),
GestureDetector(
  onTap: enCours ? null : toggle,
  child: AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    width: 150,
    height: 150,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0xFF1E293B),
      border: Border.all(color: couleur, width: 4),
      boxShadow: [
        BoxShadow(
          color: couleur.withOpacity(0.4),
          blurRadius: 30,
          spreadRadius: 4,
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: 20,
          offset: const Offset(0, 10),
        )
      ],
    ),
    child: Icon(
      Icons.power_settings_new_rounded,
      size: 70,
      color: couleur,
    ),
  ),
),
const SizedBox(height: 24),
Align(
  alignment: Alignment.centerLeft,
  child: Text(
    "HOST (domaine de ton pays)",
    style: TextStyle(
      color: Colors.grey.shade400, 
      fontSize: 12, 
      fontWeight: FontWeight.w500
    ),
  ),
),
const SizedBox(height: 6),
TextField(
  controller: hostCtrl,
  enabled: !isLocked,
  obscureText: isLocked,
  style: const TextStyle(color: Colors.white),
  decoration: InputDecoration(
    hintText: "Exemple: yamo.mtn.cm",
    hintStyle: TextStyle(color: Colors.grey.shade600),
  ),
),
const SizedBox(height: 12),
Align(
  alignment: Alignment.centerLeft,
  child: Text(
    "CONFIGURATION",
    style: TextStyle(
      color: Colors.grey.shade400, 
      fontSize: 12, 
      fontWeight: FontWeight.w500
    ),
  ),
),
const SizedBox(height: 6),
TextField(
  controller: configCtrl,
  enabled: !isLocked,
  maxLines: 3,
  style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.white),
  decoration: InputDecoration(
    hintText: "Colle ton lien vless:// ou vmess:// ou JSON",
    hintStyle: TextStyle(color: Colors.grey.shade600),
  ),
),
const SizedBox(height: 16),
Row(
  children: [
    Expanded(
      child: ElevatedButton.icon(
        onPressed: importConfig,
        icon: const Icon(Icons.download_rounded, size: 18),
        label: const Text("Import", style: TextStyle(fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF06B6D4), // Cyan
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    ),
    const SizedBox(width: 8),
    Expanded(
      child: ElevatedButton.icon(
        onPressed: isLocked ? cleanConfig : null,
        icon: const Icon(Icons.delete_forever_rounded, size: 18),
        label: const Text("Clean", style: TextStyle(fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFEF4444),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF334155),
          disabledForegroundColor: Colors.grey.shade600,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
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
        label: const Text("Export", style: TextStyle(fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0E7490), // Cyan foncé
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF334155),
          disabledForegroundColor: Colors.grey.shade600,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    ),
  ],
),
const Spacer(),
Text(
  "DEV : kcørp tech serf",
  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
),
