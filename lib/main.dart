import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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
      title: 'kcorp vpn',
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      home: const HomeScreen(),
      routes: {
        '/logs': (context) => const LogsScreen(),
      },
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
  final String whatsappGroupLink = "https://chat.whatsapp.com/GtBg9UmAV0k0ZwyfA07NkX";

  String statut = "DÉCONNECTÉ";
  bool estConnecte = false;
  bool enCours = false;
  bool isConfigLocked = false; // NOUVEAU
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
            statut = "kcorp vpn connecter";
            estConnecte = true;
            enCours = false;
            addLog("Free serf");
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

  Future<void> openWhatsAppGroup() async {
    final uri = Uri.parse(whatsappGroupLink);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      addLog("Ouverture groupe WhatsApp");
    } else {
      addLog("Impossible d'ouvrir WhatsApp");
    }
  }

  String get notificationName {
    switch (modeSelectionne) {
      case "UDP":
        return "kcorp UDP connected";
      case "SlowDNS":
        return "kcorp SlowDNS connected";
      case "SSH":
        return "kcorp SSH connected";
      case "Trojan":
        return "kcorp Trojan connected";
      default:
        return "kcorp VLESS connected";
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

  // EXPORT AVEC PARAMÈTRES
  Future<void> exportConfig() async {
    final nameCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    bool lockConfig = false;
    DateTime? expireDate;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFFFFFFF),
              title: const Text("Paramètres Export", style: TextStyle(color: Colors.black)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        labelText: "Nom de la config",
                        hintText: "Ex: kcorp free 4G",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: msgCtrl,
                      style: const TextStyle(color: Colors.black),
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: "Message",
                        hintText: "Ex: Valable MTN seulement",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      title: const Text("Lock config", style: TextStyle(color: Colors.black)),
                      subtitle: const Text("Empêcher modification", style: TextStyle(fontSize: 11)),
                      value: lockConfig,
                      onChanged: (val) => setDialogState(() => lockConfig = val!),
                      activeColor: const Color(0xFF007AFF),
                    ),
                    ListTile(
                      title: const Text("Expire config", style: TextStyle(color: Colors.black)),
                      subtitle: Text(
                        expireDate == null
                        ? "Jamais"
                          : "${expireDate!.day}/${expireDate!.month}/${expireDate!.year}",
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: const Icon(Icons.calendar_month, color: Color(0xFF007AFF)),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date!= null) setDialogState(() => expireDate = date);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Annuler"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007AFF)),
                  onPressed: () {
                    Navigator.pop(context, {
                      'name': nameCtrl.text.trim(),
                      'message': msgCtrl.text.trim(),
                      'locked': lockConfig,
                      'expire': expireDate?.toIso8601String(),
                    });
                  },
                  child: const Text("Exporter", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    final data = {
      "app": "kcorp_vpn",
      "version": 2,
      "name": result['name'].isEmpty? "kcorp_config" : result['name'],
      "message": result['message'],
      "locked": result['locked'],
      "expire": result['expire'],
      "mode": modeSelectionne,
      "host": hostCtrl.text.trim(),
      "config": configCtrl.text.trim(),
      "date": DateTime.now().toIso8601String(),
    };
    final jsonStr = const JsonEncoder.withIndent(' ').convert(data);

    try {
      final dir = await getTemporaryDirectory();
      final fileName = "${result['name'].isEmpty? 'kcorp_config' : result['name']}.kcorp";
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(jsonStr);

      await Share.shareXFiles([XFile(file.path)], text: 'Config ${result['name']}');
      addLog("Fichier.kcorp exporté: ${result['name']}");
    } catch (e) {
      addLog("Erreur export: $e");
    }
  }

  // IMPORT AVEC PARAMÈTRES
  Future<void> importConfig() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['kcorp', 'json'],
      );

      if (result == null) return;

      File file = File(result.files.single.path!);
      String content = await file.readAsString();
      final map = jsonDecode(content);

      // Vérification expiration
      if (map["expire"]!= null) {
        final expireDate = DateTime.parse(map["expire"]);
        if (DateTime.now().isAfter(expireDate)) {
          addLog("⚠️ Config expirée depuis ${expireDate.day}/${expireDate.month}/${expireDate.year}");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Cette config a expiré le ${expireDate.day}/${expireDate.month}/${expireDate.year}"),
              backgroundColor: const Color(0xFFFF3B30),
            ),
          );
          return;
        }
      }

      final bool isLocked = map["locked"]?? false;

      setState(() {
        isConfigLocked = isLocked;
        modeSelectionne = map["mode"]?? "VLESS / VMess";
        hostCtrl.text = map["host"]?? "";
        configCtrl.text = map["config"]?? "";
      });

      String infoMsg = "Config importée: ${map["name"]?? 'Sans nom'}";

      if (map["message"]!= null && map["message"].toString().isNotEmpty) {
        infoMsg += "\nMessage: ${map["message"]}";
        addLog("📢 Message: ${map["message"]}");
      }

      if (isLocked) {
        infoMsg += "\n🔒 Config verrouillée";
        addLog("🔒 Config verrouillée - modification bloquée");
      }

      if (map["expire"]!= null) {
        final expireDate = DateTime.parse(map["expire"]);
        final daysLeft = expireDate.difference(DateTime.now()).inDays;
        infoMsg += "\n⏰ Expire dans $daysLeft jours";
        addLog("⏰ Expire le ${expireDate.day}/${expireDate.month}/${expireDate.year}");
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(infoMsg),
          duration: const Duration(seconds: 4),
          backgroundColor: const Color(0xFF007AFF),
        ),
      );

      addLog("✅ Configuration importée: ${map["name"]?? 'Sans nom'}");

    } catch (e) {
      addLog("Import échoué: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Import échoué: fichier invalide"),
          backgroundColor: const Color(0xFFFF3B30),
        ),
      );
    }
  }

  Color get couleur {
    if (estConnecte) return const Color(0xFF34C759);
    if (enCours) return const Color(0xFFFF9500);
    if (statut.contains("INVALIDE") || statut.contains("ÉCHEC")) {
      return const Color(0xFF8E8E93);
    }
    return const Color(0xFFFF3B30);
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
        title: const Text("kcorp vpn", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black)),
        centerTitle: true,
        backgroundColor: const Color(0xFFFFFFFF),
        elevation: 0.5,
        shadowColor: Colors.black12,
        // BOUTON WHATSAPP EN HAUT À GAUCHE
        leading: IconButton(
          icon: const Icon(Icons.whatshot, color: Color(0xFF25D366)),
          tooltip: "Rejoindre le groupe",
          onPressed: openWhatsAppGroup,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.article, color: Color(0xFF007AFF)),
            tooltip: "Logs",
            onPressed: () => Navigator.pushNamed(context, '/logs', arguments: logs),
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
                style: TextStyle(color: Color(0xFF3C3C43), fontSize: 13),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5E5EA)),
                ),
                child: DropdownButton<String>(
                  value: modeSelectionne,
                  isExpanded: true,
                  dropdownColor: const Color(0xFFFFFFFF),
                  underline: const SizedBox(),
                  style: const TextStyle(color: Colors.black),
                  items: modes.map((m) {
                    return DropdownMenuItem(value: m, child: Text(m));
                  }).toList(),
                  onChanged: (value) {
                    if (value!= null &&!isConfigLocked) {
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
                  color: const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5E5EA)),
                ),
                child: Text(
                  statut,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: estConnecte? const Color(0xFF34C759) : couleur,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
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
                    color: const Color(0xFFFFFFFF),
                    border: Border.all(color: couleur, width: 4),
                    boxShadow: [
                      BoxShadow(color: couleur.withOpacity(0.25), blurRadius: 20, spreadRadius: 2)
                    ],
                  ),
                  child: Icon(Icons.power_settings_new_rounded, size: 65, color: couleur),
                ),
              ),

              const SizedBox(height: 16),

              Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    const Text("HOST (domaine de ton pays)", style: TextStyle(color: Color(0xFF3C3C43), fontSize: 12)),
                    if (isConfigLocked)...[
                      const SizedBox(width: 5),
                      const Icon(Icons.lock, size: 14, color: Color(0xFF8E8E93)),
                    ]
                  ],
                ),
              ),
              const SizedBox(height: 5),
TextField(
  controller: hostCtrl,
  enabled: !isConfigLocked,
  style: TextStyle(color: isConfigLocked? const Color(0xFF8E8E93) : Colors.black),
  decoration: InputDecoration(
    hintText: "votre host ici ",
    hintStyle: const TextStyle(color: Color(0xFFC7C7CC)),
    filled: true,
    fillColor: isConfigLocked? const Color(0xFFF2F2F7) : const Color(0xFFFFFFFF),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFE5E5EA))
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFE5E5EA))
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFE5E5EA))
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  ),
),

const SizedBox(height: 10),

Align(
  alignment: Alignment.centerLeft,
  child: Row(
    children: [
      const Text("CONFIGURATION", style: TextStyle(color: Color(0xFF3C3C43), fontSize: 12)),
      if (isConfigLocked)...[
        const SizedBox(width: 5),
        const Icon(Icons.lock, size: 14, color: Color(0xFF8E8E93)),
      ]
    ],
  ),
),
const SizedBox(height: 5),
TextField(
  controller: configCtrl,
  enabled:!isConfigLocked,
  maxLines: 3,
  style: TextStyle(
    color: isConfigLocked? const Color(0xFF8E8E93) : Colors.black,
    fontSize: 12,
    fontFamily: 'monospace'
  ),
  decoration: InputDecoration(
    hintText: "Colle ton lien vless:// ou vmess:// ou JSON",
    hintStyle: const TextStyle(color: Color(0xFFC7C7CC)),
    filled: true,
    fillColor: isConfigLocked? const Color(0xFFF2F2F7) : const Color(0xFFFFFFFF),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFE5E5EA))
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFE5E5EA))
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFE5E5EA))
    ),
  ),
),

const SizedBox(height: 10),

Row(
  children: [
    Expanded(
      child: ElevatedButton.icon(
        onPressed: importConfig,
        icon: const Icon(Icons.file_open, size: 18),
        label: const Text("Import Fichier"),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF007AFF),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
    ),
    const SizedBox(width: 10),
    Expanded(
      child: ElevatedButton.icon(
        onPressed: exportConfig,
        icon: const Icon(Icons.share, size: 18),
        label: const Text("Export Fichier"),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF007AFF),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
    ),
  ],
),

const Spacer(),

const SizedBox(height: 8),
const Text(
  "DEV : kcørp tech serf",
  style: TextStyle(color: Color(0xFF8E8E93), fontSize: 11),
),
