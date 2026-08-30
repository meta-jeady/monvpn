import 'package:flutter/material.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';

void main() {
  // Garantit que les liaisons Flutter sont initialisées avant le démarrage du VPN
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Kco4pVPNApp());
}

class Kco4pVPNApp extends StatelessWidget {
  const Kco4pVPNApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KČØ4P VPN',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Fond bleu nuit sombre
        primaryColor: const Color(0xFF1E293B),           // Couleur des composants
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false, // Enlève la bande de debug
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

  // Configuration VLESS par défaut (Remplacez cette valeur par votre propre clé VLESS si besoin)
  final TextEditingController _vlessController = TextEditingController(
    text: "vless://99ffff99-0000-1111-2222-333344445555@://exemple.com"
  );

  @override
  void initState() {
    super.initState();
    // Initialisation du noyau V2Ray et écoute des changements d'état du tunnel
    v2ray = FlutterV2ray(
      onStatusChange: (status) {
        setState(() {
          statutConnection = status.state.toUpperCase();
          estConnecte = status.state == "CONNECTED";
          enCoursDeConnexion = status.state == "CONNECTING";
        });
      },
    );
    v2ray.initializeV2Ray();
  }

  // Fonction déclenchée lors de l'appui sur le bouton d'alimentation central
  void basculerVPN() async {
    if (estConnecte) {
      await v2ray.stopV2Ray();
      setState(() {
        estConnecte = false;
        enCoursDeConnexion = false;
        statutConnection = "DÉCONNECTÉ";
      });
      return;
    }

    String vlessUri = _vlessController.text.trim();
    if (vlessUri.isEmpty || !vlessUri.startsWith("vless://")) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez saisir une configuration VLESS valide")),
      );
      return;
    }

    setState(() {
      enCoursDeConnexion = true;
      statutConnection = "CONNEXION EN COURS";
    });

    // Demande l'autorisation au système d'exploitation (Android VpnService)
    if (await v2ray.requestPermission()) {
      // Démarre le tunnel de chiffrement avec la configuration fournie
      await v2ray.startV2Ray(
        remark: "KČØ4P Serveur Actif",
        config: vlessUri,
        blockedApps: [], // Optionnel : mettez des packages d'applications pour le split-tunneling
      );
    } else {
      setState(() {
        enCoursDeConnexion = false;
        statutConnection = "PERMISSION REFUSÉE";
      });
    }
  }

  // Sélection dynamique de la couleur du thème selon l'état actuel du VPN
  Color obtenirCouleurBouton() {
    if (estConnecte) return const Color(0xFF10B981);       // Vert émeraude si connecté
    if (enCoursDeConnexion) return const Color(0xFFF59E0B); // Orange ambre si en cours
    return const Color(0xFFEF4444);                         // Rouge corail si déconnecté
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "KČØ4P VPN", 
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white)
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Boîtier d'affichage du statut textuel en haut
            Card(
              color: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 32.0),
                child: Text(
                  statutConnection,
                  style: TextStyle(
                    color: obtenirCouleurBouton(),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),

            // Gros bouton néon central interactif (Power Button)
            GestureDetector(
              onTap: basculerVPN,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 210,
                height: 210,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1E293B),
                  border: Border.all(color: obtenirCouleurBouton(), width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: obtenirCouleurBouton().withOpacity(0.35),
                      blurRadius: 35,
                      spreadRadius: 6,
                    )
                  ],
                ),
                child: Icon(
                  Icons.power_settings_new_rounded,
                  size: 95,
                  color: obtenirCouleurBouton(),
                ),
              ),
            ),

            // Zone de texte en bas permettant à l'utilisateur de coller sa propre clé
            TextField(
              controller: _vlessController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
              decoration: InputDecoration(
                labelText: "CONFIGURATION VLESS ACTIVE (URI)",
                labelStyle: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Colors.white24, width: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
