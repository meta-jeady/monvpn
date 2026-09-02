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

  // AJOUT: Variables pour config importée
  bool configImportee = false;
  bool configLocked = false;
  String configName = "";
  DateTime? configExpireDate;

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
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white, size: 20),
                      SizedBox(width: 10),
                      Text(
                        "Connected Successfully",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: const Color(0xFF22C55E),
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                  duration: const Duration(seconds: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            }
          } else if (state == "CONNECTING") {
            statut = "CONNEXION...";
            enCours = true;
            estConnecte = false;
          } else {
            if (estConnecte) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.cancel, color: Colors.white, size: 20),
                      SizedBox(width: 10),
                      Text(
                        "Disconnected",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: const Color(0xFFEF4444),
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                  duration: const Duration(seconds: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            }
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Colle une configuration d'abord")),
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
          backgroundColor: Colors.white,
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
      bool isLocked = false;

      if (content.startsWith("kco4p://config/")) {
        content = content.replaceFirst("kco4p://config/", "");
        content = utf8.decode(base64.decode(content));
        addLog("Lien kco4p décodé");
      }

      if (content.startsWith("KCO4P_LOCKED:")) {
        isLocked = true;
        content = utf8.decode(
            base64.decode(content.replaceFirst("KCO4P_LOCKED:", "")));
        addLog("Config verrouillée détectée");
      }

      final map = jsonDecode(content);

      if (map["app"]!= "KČØ4P VPN") {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Lien non compatible avec KČØ4P VPN")),
        );
        return;
      }

      DateTime? expireDateTemp;
      if (map["expire_date"]!= null) {
        expireDateTemp = DateTime.tryParse(map["expire_date"]);
        if (expireDateTemp!= null && DateTime.now().isAfter(expireDateTemp)) {
          addLog("Configuration expirée le ${expireDateTemp.day}/${expireDateTemp.month}/${expireDateTemp.year}");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Cette configuration a expiré")),
          );
          return;
        }
      }

      setState(() {
        modeSelectionne = map["mode"]?? "VLESS / VMess";
        hostCtrl.text = map["host"]?? "";
        configCtrl.text = map["config"]?? "";
        configLocked = isLocked || map["locked"] == true;
        configImportee = true;
        configName = map["name"]?? "Configuration";
        configExpireDate = expireDateTemp;
      });

      if (configLocked) {
        addLog("Import réussi : ${map["name"]?? "Configuration"} - VERROUILLÉE");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Importé : ${map["name"]?? "Configuration"} 🔒"),
            backgroundColor: const Color(0xFF22C55E),
          ),
        );
      } else {
        addLog("Import réussi : ${map["name"]?? "Configuration"}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Importé : ${map["name"]?? "Configuration"}"),
            backgroundColor: const Color(0xFF22C55E),
          ),
        );
      }
    } catch (e) {
      addLog("Erreur import : $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lien invalide")),
      );
    }
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
          child: configImportee? _buildVueImportee() : _buildVueNormale(),
        ),
      ),
    );
  }

  Widget _buildVueNormale() {
    return Column(
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
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            statut,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: estConnecte? const Color(0xFF22C55E) : couleur,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
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
          decoration: InputDecoration(
            hintText: "Exemple: yamo.mtn.cm",
            filled: true,
            fillColor: Colors.white,
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
          maxLines: 3,
          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: "Colle ton lien vless:// ou vmess:// ou JSON",
            filled: true,
            fillColor: Colors.white,
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
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
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
                label: const Text("Export Lien"),
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
    );
  }

  Widget _buildVueImportee() {
  return Column(
    children: [
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock, size: 18, color: Color(0xFF0EA5E9)),
                const SizedBox(width: 8),
                Text(
                  configName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            if (configExpireDate != null) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 14,
                    color: DateTime.now().isAfter(
                      configExpireDate!.subtract(const Duration(days: 3))
                    ) ? Colors.orange : Colors.black45,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "Expire le ${configExpireDate!.day}/${configExpireDate!.month}/${configExpireDate!.year}",
                    style: TextStyle(
                      fontSize: 12,
                      color: DateTime.now().isAfter(
                        configExpireDate!.subtract(const Duration(days: 3))
                      ) ? Colors.orange : Colors.black54,
                      fontWeight: DateTime.now().isAfter(
                        configExpireDate!.subtract(const Duration(days: 3))
                      ) ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 20),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          statut,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: estConnecte ? const Color(0xFF22C55E) : couleur,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      const SizedBox(height: 40),
      GestureDetector(
        onTap: enCours ? null : toggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: couleur, width: 5),
            boxShadow: [
              BoxShadow(
                color: couleur.withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 3,
              )
            ],
          ),
          child: Icon(
            Icons.power_settings_new_rounded,
            size: 75,
            color: couleur,
          ),
        ),
      ),
      const SizedBox(height: 30),
      TextButton.icon(
        onPressed: () {
          setState(() {
            configImportee = false;
            hostCtrl.clear();
            configCtrl.clear();
            configExpireDate = null;
            statut = "DÉCONNECTÉ";
          });
          v2ray.stopV2Ray();
        },
        icon: const Icon(Icons.refresh, size: 18),
        label: const Text("Changer de configuration"),
        style: TextButton.styleFrom(
          foregroundColor: Colors.black54,
        ),
      ),
      const Spacer(),
      const Text(
        "DEV : kcørp tech serf",
        style: TextStyle(color: Colors.black38, fontSize: 12),
      ),
    ],
  );
  }
  
