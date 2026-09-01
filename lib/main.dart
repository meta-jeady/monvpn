import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

void main() {
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
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0E27),
        primaryColor: const Color(0xFF00E5FF),
      ),
      home: const VpnHomePage(),
    );
  }
}

class VpnHomePage extends StatefulWidget {
  const VpnHomePage({super.key});

  @override
  State<VpnHomePage> createState() => _VpnHomePageState();
}

class _VpnHomePageState extends State<VpnHomePage> {
  bool isConnected = false;
  String selectedMode = "VLESS / VMess";
  final TextEditingController hostCtrl = TextEditingController();
  final TextEditingController configCtrl = TextEditingController();
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController descCtrl = TextEditingController();
  
  final Color primaryBlue = const Color(0xFF00E5FF);
  final Color bgDark = const Color(0xFF0A0E27);
  final Color cardDark = const Color(0xFF1A1F3A);
  final Color errorRed = const Color(0xFFFF3D3D);
  final Color successGreen = const Color(0xFF00FF88);

  // ==================== EXPORT ====================
  Future<void> generateFile() async {
    if (nameCtrl.text.trim().isEmpty) {
      showSnackBar("Mets un nom à la configuration", errorRed);
      return;
    }

    final data = {
      "app": "KČØ4P VPN",
      "name": nameCtrl.text.trim(),
      "description": descCtrl.text.trim(),
      "mode": selectedMode,
      "host": hostCtrl.text.trim(),
      "config": configCtrl.text.trim(),
      "locked": false,
      "created_at": DateTime.now().toIso8601String(),
    };

    String content = const JsonEncoder.withIndent(' ').convert(data);

    try {
      // Sauvegarde dans Téléchargements
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      final fileName = "${nameCtrl.text.trim().replaceAll(' ', '_')}.kcvpn";
      final file = File("${directory!.path}/$fileName");
      await file.writeAsString(content);

      showSnackBar("Fichier sauvé : Téléchargements/$fileName", successGreen);

      // Partage direct
      await Share.shareXFiles(
        [XFile(file.path)],
        text: "Configuration KČØ4P VPN - ${nameCtrl.text}",
      );
    } catch (e) {
      showSnackBar("Erreur export : $e", errorRed);
    }
  }

  // ==================== IMPORT ====================
  Future<void> importFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['kcvpn'], // SANS POINT !!!
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String content = await file.readAsString();
        
        final data = jsonDecode(content);
        
        // Remplit les champs
        setState(() {
          nameCtrl.text = data['name'] ?? '';
          descCtrl.text = data['description'] ?? '';
          selectedMode = data['mode'] ?? "VLESS / VMess";
          hostCtrl.text = data['host'] ?? '';
          configCtrl.text = data['config'] ?? '';
        });

        // Affiche le popup HTML
        showImportDialog(data['name'], data['description']);
        
        showSnackBar("Import réussi", successGreen);
      }
    } catch (e) {
      print("Erreur import: $e");
      showSnackBar("Import échoué", errorRed);
    }
  }

  // ==================== POPUP HTML ====================
  void showImportDialog(String name, String description) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardDark,
        title: Row(
          children: [
            Icon(Icons.check_circle, color: successGreen),
            const SizedBox(width: 8),
            Text(name, style: const TextStyle(color: Colors.white)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: HtmlWidget(
              description.isEmpty 
                ? "<i>Aucune description</i>" 
                : description,
              textStyle: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Fermer", style: TextStyle(color: primaryBlue)),
          ),
        ],
      ),
    );
  }

  void showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: bgDark,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "KČØ4P VPN",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Dropdown Mode
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: primaryBlue, width: 2),
                borderRadius: BorderRadius.circular(16),
                color: cardDark,
              ),
              child: DropdownButton<String>(
                value: selectedMode,
                isExpanded: true,
                dropdownColor: cardDark,
                underline: const SizedBox(),
                style: const TextStyle(color: Colors.white),
                items: ["VLESS / VMess", "Trojan", "Shadowsocks"]
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) => setState(() => selectedMode = val!),
              ),
            ),
            const SizedBox(height: 16),

            // Status
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(color: primaryBlue, width: 2),
                borderRadius: BorderRadius.circular(16),
                color: cardDark,
              ),
              child: Text(
                isConnected ? "CONNECTÉ" : "DÉCONNECTÉ",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isConnected ? successGreen : primaryBlue,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Power Button
            GestureDetector(
              onTap: () => setState(() => isConnected = !isConnected),
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: primaryBlue, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: primaryBlue.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.power_settings_new,
                  size: 60,
                  color: primaryBlue,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // HOST Field
            _buildTextField("HOST / SNI (domaine)", hostCtrl, Icons.dns),
            const SizedBox(height: 12),

            // CONFIG Field
            _buildTextField("CONFIGURATION", configCtrl, Icons.vpn_key),
            const SizedBox(height: 12),

            // NAME Field
            _buildTextField("Nom de la config", nameCtrl, Icons.label),
            const SizedBox(height: 12),

            // DESC Field
            _buildTextField("Description HTML", descCtrl, Icons.description, maxLines: 3),
            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: importFile,
                    icon: const Icon(Icons.download),
                    label: const Text("Import"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: generateFile,
                    icon: const Icon(Icons.upload),
                    label: const Text("Export"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryBlue,
                      side: BorderSide(color: primaryBlue, width: 2),
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, IconData icon, {int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: primaryBlue.withOpacity(0.5), width: 1),
        borderRadius: BorderRadius.circular(16),
        color: cardDark,
      ),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white70),
          prefixIcon: Icon(icon, color: primaryBlue),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }
}
  @override
  void dispose() {
    hostCtrl.dispose();
    configCtrl.dispose();
    nameCtrl.dispose();
    descCtrl.dispose();
    super.dispose();
  }
} // ← Ferme la classe _VpnHomePageState
