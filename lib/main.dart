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
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        primaryColor: const Color(0xFF1E293B),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3B82F6),
          secondary: Color(0xFF10B981),
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
  String statutConnection = "DÉCONNECTÉ";
  bool estConnecte = false;
  bool enCoursDeConnexion = false;
  String? coreVersion;

  final TextEditingController _configController = TextEditingController(
    text: "vless://uuid@exemple.com:443?encryption=none&security=reality&sni=exemple.com&fp=chrome&pbk=publickey&sid=shortid&type=tcp#KCO4P-Serveur",
  );

  @override
  void initState() {
    super.initState();
    v2ray = FlutterV2ray(
      onStatusChanged: (status) {
        if (!mounted) return;
        setState(() {
          statutConnection = status.state.toUpperCase();
          estConnecte = status.state == "CONNECTED";
          enCoursDeConnexion = status.state == "CONNECTING";
        });
      },
    );
    _initV2Ray();
  }

  Future<void> _initV2Ray() async {
    await v2ray.initializeV2Ray();
    try {
      final version = await v2ray.getCoreVersion();
      if (mounted) {
        setState(() => coreVersion = version);
      }
    } catch (_) {}
  }

  Future<void> basculerVPN() async {
    if (estConnecte) {
      await v2ray.stopV2Ray();
      setState(() {
        estConnecte = false;
        enCoursDeConnexion = false;
        statutConnection = "DÉCONNECTÉ";
      });
      return;
    }

    String config = _configController.text.trim();
    if (config.isEmpty) {
      _showSnack("Veuillez coller une configuration VLESS / VMess valide");
      return;
    }

    if (!config.startsWith("vless://") &&
        !config.startsWith("vmess://") &&
        !config.startsWith("trojan://") &&
        !config.startsWith("{")) {
      _showSnack("Format non supporté. Utilisez vless://, vmess://, trojan:// ou JSON");
      return;
    }

    setState(() {
      enCoursDeConnexion = true;
      statutConnection = "CONNEXION EN COURS...";
    });

    try {
      String finalConfig = config;
      String remark = "KČØ4P Serveur";

      if (config.startsWith("vless://") ||
          config.startsWith("vmess://") ||
          config.startsWith("trojan://")) {
        final parser = FlutterV2ray.parseFromURL(config);
        finalConfig = parser.getFullConfiguration();
        remark = parser.remark.isNotEmpty ? parser.remark : "KČØ4P Serveur";
      }

      final hasPermission = await v2ray.requestPermission();
      if (!hasPermission) {
        setState(() {
          enCoursDeConnexion = false;
          statutConnection = "PERMISSION REFUSÉE";
        });
        _showSnack("Permission VPN refusée par l'utilisateur");
        return;
      }

      await v2ray.startV2Ray(
        remark: remark,
        config: finalConfig,
        blockedApps: [],
      );
    } catch (e) {
      setState(() {
        enCoursDeConnexion = false;
        statutConnection = "ERREUR";
      });
      _showSnack("Erreur de connexion : $e");
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Color obtenirCouleurBouton() {
    if (estConnecte) return const Color(0xFF10B981);
    if (enCoursDeConnexion) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  void dispose() {
    _configController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "KČØ4P VPN",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          if (coreVersion != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  "Xray $coreVersion",
                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Card(
                color: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 18.0,
                    horizontal: 28.0,
                  ),
                  child: Text(
                    statutConnection,
                    style: TextStyle(
                      color: obtenirCouleurBouton(),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: enCoursDeConnexion ? null : basculerVPN,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1E293B),
                    border: Border.all(
                      color: obtenirCouleurBouton(),
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: obtenirCouleurBouton().withOpacity(0.4),
                        blurRadius: 40,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.power_settings_new_rounded,
                    size: 90,
                    color: obtenirCouleurBouton(),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "CONFIGURATION (VLESS / VMess / Trojan / JSON)",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _configController,
                    maxLines: 4,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                    decoration: InputDecoration(
                      hintText: "Collez votre lien vless:// ou vmess:// ici...",
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFF3B82F6),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
