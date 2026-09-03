import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ==================== MAIN ====================
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KČØ4P VPN',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0EA5E9)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

// ==================== HOME SCREEN ====================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String modeSelectionne = "VLESS / VMess";
  String statut = "DÉCONNECTÉ";
  bool estConnecte = false;
  bool enCours = false;
  bool isLocked = false;
  String? lockedHost;
  String? lockedConfig;
  String? lockedName;
  String? lockedExpireDate;

  final hostCtrl = TextEditingController();
  final configCtrl = TextEditingController();

  FlutterV2ray v2ray = FlutterV2ray(
    onStatusChanged: (s) {
      print("V2Ray status: $s");
    },
  );

  List<String> logs = [];

  @override
  void initState() {
    super.initState();
    v2ray.initializeV2Ray();
    loadLockedConfig();
  }

  @override
  void dispose() {
    hostCtrl.dispose();
    configCtrl.dispose();
    super.dispose();
  }

  void addLog(String msg) {
    final time = DateTime.now().toIso8601String().substring(11, 19);
    String safeMsg = msg;

    if (lockedHost!= null && lockedHost!.isNotEmpty) {
      safeMsg = safeMsg.replaceAll(lockedHost!, "*******");
    }

    if (lockedConfig!= null && lockedConfig!.isNotEmpty) {
      final uri = Uri.tryParse(lockedConfig!);
      if (uri!= null) {
        if (uri.userInfo.isNotEmpty) {
          safeMsg = safeMsg.replaceAll(uri.userInfo, "*******");
        }
        if (uri.host.isNotEmpty) {
          safeMsg = safeMsg.replaceAll(uri.host, "*******");
        }
      }
    }

    setState(() {
      logs.insert(0, "$time - $safeMsg");
      if (logs.length > 100) logs.removeLast();
    });
  }

  Color get couleur {
    if (enCours) return const Color(0xFFF59E0B);
    if (estConnecte) return const Color(0xFF22C55E);
    return const Color(0xFFEF4444);
  }

  Future<void> saveLockedConfig({
    required String name,
    required String mode,
    required String host,
    required String config,
    String? expireDate,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLocked', true);
    await prefs.setString('lockedName', name);
    await prefs.setString('lockedMode', mode);
    await prefs.setString('lockedHost', host);
    await prefs.setString('lockedConfig', config);
    await prefs.setString('lockedExpireDate', expireDate?? '');
  }

  Future<void> loadLockedConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final locked = prefs.getBool('isLocked')?? false;

    if (locked) {
      final expireDateStr = prefs.getString('lockedExpireDate');
      if (expireDateStr!= null && expireDateStr.isNotEmpty) {
        final expire = DateTime.tryParse(expireDateStr);
        if (expire!= null && DateTime.now().isAfter(expire)) {
          addLog("Configuration expirée - suppression auto");
          await prefs.clear();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Configuration expirée. App réinitialisée."),
                backgroundColor: Color(0xFFEF4444),
              ),
            );
          }
          return;
        }
      }

      setState(() {
        isLocked = true;
        lockedName = prefs.getString('lockedName');
        modeSelectionne = prefs.getString('lockedMode')?? "VLESS / VMess";
        lockedHost = prefs.getString('lockedHost');
        lockedConfig = prefs.getString('lockedConfig');
        lockedExpireDate = prefs.getString('lockedExpireDate');
        hostCtrl.text = "*******";
        configCtrl.text = "******** Configuration verrouillée ********";
      });
      addLog("Configuration verrouillée chargée");
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
      lockedExpireDate = null;
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

  Future<void> importConfig() async {
    final data = await Clipboard.getData('text/plain');
    if (data == null || data.text == null || data.text!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Presse-papiers vide")),
      );
      return;
    }

    final text = data.text!.trim();

    if (!text.startsWith("kco4p://")) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lien invalide")),
      );
      return;
    }

    try {
      final b64 = text.substring(14);
      var content = utf8.decode(base64.decode(b64));

      if (content.startsWith("KCO4P_LOCKED:")) {
        final b64Json = content.substring(13);
        content = utf8.decode(base64.decode(b64Json));
      }

      final map = jsonDecode(content);

      if (map["app"]!= "KČØ4P VPN") {
        throw "App invalide";
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

      final locked = map["locked"]?? false;
      final name = map["name"]?? "Config";
      final mode = map["mode"]?? "VLESS / VMess";
      final host = map["host"]?? "";
      final config = map["config"]?? "";
      final expireDate = map["expire_date"];

      if (locked) {
        await saveLockedConfig(
          name: name,
          mode: mode,
          host: host,
          config: config,
          expireDate: expireDate,
        );

        setState(() {
          isLocked = true;
          lockedName = name;
          lockedHost = host;
          lockedConfig = config;
          lockedExpireDate = expireDate;
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

      addLog("Import: $name ready to use");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Configuration importée: $name"),
          backgroundColor: const Color(0xFF22C55E),
        ),
      );
    } catch (e) {
      addLog("Erreur import: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Échec de l'import")),
      );
    }
  }

  Future<String> buildFinalConfig() async {
    if (isLocked && lockedConfig!= null && lockedConfig!.isNotEmpty) {
      return lockedConfig!;
    }
    return configCtrl.text.trim();
  }

  Future<void> toggle() async {
    if (enCours) return;

    if (!estConnecte && isLocked) {
      final prefs = await SharedPreferences.getInstance();
      final expireDateStr = prefs.getString('lockedExpireDate');
      if (expireDateStr!= null && expireDateStr.isNotEmpty) {
        final expire = DateTime.tryParse(expireDateStr);
        if (expire!= null && DateTime.now().isAfter(expire)) {
          addLog("Configuration expirée - déconnexion");
          await prefs.clear();

          setState(() {
            isLocked = false;
            lockedHost = null;
            lockedConfig = null;
            lockedName = null;
            lockedExpireDate = null;
            hostCtrl.clear();
            configCtrl.clear();
            modeSelectionne = "VLESS / VMess";
            statut = "DÉCONNECTÉ";
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Configuration expirée. App réinitialisée."),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
          return;
        }
      }
    }

    if (!estConnecte) {
      setState(() {
        enCours = true;
        statut = "CONNEXION...";
      });
      addLog("CONNEXION EN COURS");

      try {
        final finalConfig = await buildFinalConfig();

        if (finalConfig.isEmpty) {
          throw "Configuration vide";
        }

        if (modeSelectionne == "VLESS / VMess") {
          final parser = await v2ray.parseFromURL(finalConfig);
          await v2ray.startV2Ray(
            remark: parser.remark,
            config: parser.getFullConfiguration(),
            proxyOnly: false,
          );
        } else {
          await v2ray.startV2Ray(
            remark: "Hysteria2",
            config: finalConfig,
            proxyOnly: false,
          );
        }

        setState(() {
          enCours = false;
          estConnecte = true;
          statut = "CONNECTÉ";
        });
        addLog("CONNECTÉ");
      } catch (e) {
        setState(() {
          enCours = false;
          statut = "DÉCONNECTÉ";
        });
        addLog("Erreur: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: $e")),
        );
      }
    } else {
      setState(() {
        enCours = true;
        statut = "DÉCONNEXION...";
      });
      addLog("DÉCONNEXION EN COURS");

      try {
        await v2ray.stopV2Ray();
        setState(() {
          enCours = false;
          estConnecte = false;
          statut = "DÉCONNECTÉ";
        });
        addLog("DÉCONNECTÉ");
      } catch (e) {
        setState(() {
          enCours = false;
        });
        addLog("Erreur déconnexion: $e");
      }
    }
  }

  void showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0EA5E9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.security, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              "À propos",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "KČØ4P VPN",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0EA5E9),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Version 1.0.0",
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const Divider(height: 24),
            const Text(
              "Développé par",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Kcørp Tech",
              style: TextStyle(fontSize: 15),
            ),
            const Text(
              "Jeune développeur passionné\nRésidant au Cameroun 🇨🇲",
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            const Text(
              "Contact",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () {
                Clipboard.setData(const ClipboardData(text: "+237687960259"));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Numéro copié")),
                );
              },
              child: const Row(
                children: [
                  Icon(Icons.phone, size: 16, color: Color(0xFF0EA5E9)),
                  SizedBox(width: 8),
                  Text("+237 687 960 259"),
                ],
              ),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () {
                Clipboard.setData(const ClipboardData(text: "+237680370344"));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Numéro copié")),
                );
              },
              child: const Row(
                children: [
                  Icon(Icons.phone, size: 16, color: Color(0xFF0EA5E9)),
                  SizedBox(width: 8),
                  Text("+237 680 370 344"),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "© 2026 Kcørp Tech. Tous droits réservés.",
              style: TextStyle(color: Colors.black38, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fermer"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0F2FE),
      appBar: AppBar(
        title: const Text(
          "KČØ4P VPN",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF0EA5E9),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: showAboutDialog,
          ),
          IconButton(
            icon: const Icon(Icons.article_outlined, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LogsScreen(logs: logs),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Sélectionne le mode de configuration",
                style: TextStyle(color: Colors.black54, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: modeSelectionne,
                    isExpanded: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    items: ["VLESS / VMess", "Hysteria 2"]
                     .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e),
                            ))
                     .toList(),
                    onChanged: isLocked
                     ? null
                        : (v) {
                            if (v!= null) {
                              setState(() => modeSelectionne = v);
                            }
                          },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      statut,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: couleur,
                      ),
                    ),
                    if (isLocked)...[
                      const SizedBox(height: 4),
                      const Text(
                        "🔒 Configuration verrouillée",
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFF59E0B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: GestureDetector(
                  onTap: enCours? null : toggle,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: couleur, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: couleur.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.power_settings_new_rounded,
                      size: 64,
                      color: couleur,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "HOST (domaine de ton pays)",
                style: TextStyle(color: Colors.black54, fontSize: 14),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: hostCtrl,
                enabled: !isLocked,
                decoration: InputDecoration(
                  hintText: "exemple.com ou IP",
                  filled: true,
                  fillColor: isLocked? Colors.grey.shade200 : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "CONFIGURATION",
                style: TextStyle(color: Colors.black54, fontSize: 14),
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
                  fillColor: isLocked? Colors.grey.shade200 : Colors.white,
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
                      onPressed: isLocked? cleanConfig : null,
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
      "expire_date": hasExpire && expireDate!= null
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
        content: Text("Lien copié dans le presse-papiers!"),
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
                        if (picked!= null) {
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
            if (generatedLink!= null)...[
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
