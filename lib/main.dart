import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KČØ4P VPN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0EA5E9)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFE0F2FE),
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
  late final FlutterV2ray v2ray;
  final hostCtrl = TextEditingController();
  final configCtrl = TextEditingController();

  String statut = "DÉCONNECTÉ";
  bool estConnecte = false;
  bool enCours = false;
  String protocol = "vless";
  V2RayURL? v2rayConfig;

  // Variables pour config lock
  bool configImportee = false;
  bool configLocked = false;
  String configName = "";
  String configExpireDate = "";

  @override
  void initState() {
    super.initState();
    v2ray = FlutterV2ray(
      onStatusChanged: (status) {
        if (!mounted) return;
        setState(() {
          if (status.state == "CONNECTED") {
            estConnecte = true;
            enCours = false;
            statut = "FREE SERF";
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text("Connected Successfully"),
                  ],
                ),
                backgroundColor: const Color(0xFF22C55E),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                duration: const Duration(seconds: 2),
              ),
            );
          } else if (status.state == "DISCONNECTED") {
            estConnecte = false;
            enCours = false;
            statut = "DÉCONNECTÉ";
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.error, color: Colors.white),
                    SizedBox(width: 8),
                    Text("Disconnected"),
                  ],
                ),
                backgroundColor: const Color(0xFFEF4444),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                duration: const Duration(seconds: 2),
              ),
            );
          } else {
            enCours = true;
            statut = "CONNEXION...";
          }
        });
      },
    );
    v2ray.initializeV2Ray();
  }

  void toggle() async {
    if (estConnecte) {
      v2ray.stopV2Ray();
    } else {
      try {
        if (configLocked && v2rayConfig!= null) {
          await v2ray.startV2Ray(
            remark: v2rayConfig!.remark,
            config: v2rayConfig!.getFullConfiguration(),
          );
        } else {
          if (hostCtrl.text.isEmpty || configCtrl.text.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Remplis HOST et CONFIGURATION")),
            );
            return;
          }
          final conf = FlutterV2ray.parseFromURL("vless://${configCtrl.text}@${hostCtrl.text}:443?security=tls&type=ws#KCO4P");
          await v2ray.startV2Ray(
            remark: conf.remark,
            config: conf.getFullConfiguration(),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: $e")),
        );
        setState(() => enCours = false);
      }
    }
  }

  void importerConfig() {
    Clipboard.getData('text/plain').then((value) {
      if (value?.text == null) return;
      final content = value!.text!;

      if (content.startsWith("kco4p://config/KCO4P_LOCKED:")) {
        try {
          final payload = content.split("KCO4P_LOCKED:")[1];
          final parts = payload.split(":");
          final name = parts[0];
          final expiry = parts[1];
          final configB64 = parts[2];

          final decoded = utf8.decode(base64.decode(configB64));
          v2rayConfig = FlutterV2ray.parseFromURL(decoded);

          setState(() {
            configImportee = true;
            configLocked = true;
            configName = name;
            configExpireDate = expiry;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Configuration sécurisée importée")),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Lien invalide")),
          );
        }
      } else if (content.startsWith("vless://") || content.startsWith("vmess://")) {
        final parsed = FlutterV2ray.parseFromURL(content);
        setState(() {
          hostCtrl.text = parsed.address;
          configCtrl.text = parsed.password;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Config importée")),
        );
      }
    });
  }

  void exporterLien() {
    if (hostCtrl.text.isEmpty || configCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Remplis d'abord HOST et CONFIGURATION")),
      );
      return;
    }
    final lien = "vless://${configCtrl.text}@${hostCtrl.text}:443?security=tls&type=ws#KCO4P";
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExportPage(v2rayLink: lien),
      ),
    );
  }

  Widget _buildVueNormale() {
    final couleur = estConnecte? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: protocol,
          decoration: InputDecoration(
            labelText: "Protocole",
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: const [
            DropdownMenuItem(value: "vless", child: Text("VLESS / VMess")),
          ],
          onChanged: (v) => setState(() => protocol = v!),
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
              color: estConnecte? const Color(0xFF22C55E) : couleur,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 40),
        GestureDetector(
          onTap: enCours? null : toggle,
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
        const SizedBox(height: 40),
        TextField(
          controller: hostCtrl,
          decoration: InputDecoration(
            labelText: "HOST",
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: configCtrl,
          decoration: InputDecoration(
            labelText: "CONFIGURATION",
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: importerConfig,
                icon: const Icon(Icons.download),
                label: const Text("Import"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0EA5E9),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: exporterLien,
                icon: const Icon(Icons.share),
                label: const Text("Export Lien"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    final couleur = estConnecte? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF0EA5E9), width: 2),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock, color: Color(0xFF0EA5E9), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    configName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0EA5E9),
                    ),
                  ),
                ],
              ),
              if (configExpireDate.isNotEmpty)...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.timer_outlined, size: 16, color: Colors.black54),
                    const SizedBox(width: 4),
                    Text(
                      "Expire le $configExpireDate",
                      style: const TextStyle(fontSize: 14, color: Colors.black54),
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
              color: estConnecte? const Color(0xFF22C55E) : couleur,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 40),
        GestureDetector(
          onTap: enCours? null : toggle,
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
              configExpireDate = "";
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0EA5E9),
        title: const Text("KČØ4P VPN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.article_outlined, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LogsScreen())),
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
}

// ==================== PAGE EXPORT (LIEN) ====================
class ExportPage extends StatefulWidget {
  const ExportPage({super.key, required this.v2rayLink});
  final String v2rayLink;

  @override
  State<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage> {
  bool _isLocked = false;
  final _nameCtrl = TextEditingController(text: "KCO4P Config");
  final _dateCtrl = TextEditingController();

  String _generateLink() {
    if (_isLocked) {
      final payload = "${_nameCtrl.text}:${_dateCtrl.text}:${base64.encode(utf8.encode(widget.v2rayLink))}";
      return "kco4p://config/KCO4P_LOCKED:$payload";
    }
    return widget.v2rayLink;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Exporter le lien"),
        backgroundColor: const Color(0xFF0EA5E9),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: const Text("Verrouiller la configuration"),
              subtitle: const Text("Masque HOST/CONFIG après import"),
              value: _isLocked,
              onChanged: (v) => setState(() => _isLocked = v),
            ),
            if (_isLocked)...[
              const SizedBox(height: 12),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: "Nom de la config",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _dateCtrl,
                decoration: const InputDecoration(
                  labelText: "Date expiration: 31/12/2026",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 20),
            const Text("Lien généré :", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(_generateLink()),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _generateLink()));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Lien copié")),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text("Copier le lien"),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Share.share(_generateLink()),
                icon: const Icon(Icons.share),
                label: const Text("Partager"),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== PAGE LOGS ====================
class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Logs")),
      body: const Center(child: Text("Logs V2Ray ici")),
    );
  }
}
