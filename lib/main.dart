import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:encrypt/encrypt.dart' as enc;

void main() => runApp(const Kco4pVPNApp());

class C {
  static const vert = Color(0xFF009A44);
  static const jaune = Color(0xFFFCD116);
  static const rouge = Color(0xFFCE1126);
  static const bg = Color(0xFF0F1A0F);
  static const card = Color(0xFF1A2E1A);
}

class Kco4pVPNApp extends StatelessWidget {
  const Kco4pVPNApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: C.bg),
      home: const HomePage(),
    );
  }
}

class Logs {
  static List<String> list = [];
  static ValueNotifier<int> n = ValueNotifier(0);
  static void add(String m) {
    list.add("[${DateTime.now().toString().substring(11,19)}] $m");
    n.value++;
  }
}

class KTManager {
  static String _k(String p) {
    String k = p.padRight(32, '0');
    return k.length > 32? k.substring(0, 32) : k;
  }
  static Future<File> exportKT(String host, String config, String mode, String pwd) async {
    final payload = jsonEncode({"host": host, "config": config, "mode": mode});
    final key = enc.Key.fromUtf8(_k(pwd));
    final iv = enc.IV.fromSecureRandom(16);
    final encr = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc)).encrypt(payload, iv: iv);
    final data = jsonEncode({"type": "KCO4P_LOCKED", "iv": iv.base64, "data": encr.base64});
    final dir = await getApplicationDocumentsDirectory();
    final f = File("${dir.path}/${DateTime.now().millisecondsSinceEpoch}.kt");
    await f.writeAsString(data);
    return f;
  }
  static Future<Map<String,dynamic>?> importKT(String path, String pwd) async {
    try {
      final outer = jsonDecode(await File(path).readAsString());
      final key = enc.Key.fromUtf8(_k(pwd));
      final iv = enc.IV.fromBase64(outer["iv"]);
      final dec = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc)).decrypt(enc.Encrypted.fromBase64(outer["data"]), iv: iv);
      return jsonDecode(dec);
    } catch (_) { return null; }
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late FlutterV2ray v2ray;
  String statut = "DÉCONNECTÉ";
  bool estConnecte = false, enCours = false;
  String mode = "VLESS / VMess";
  final modes = ["VLESS / VMess", "UDP", "SlowDNS", "SSH", "Trojan"];
  final hostCtrl = TextEditingController(text: "yamo.mtn.cm");
  final configCtrl = TextEditingController();
  final passCtrl = TextEditingController(text: "237");

  @override
  void initState() {
    super.initState();
    v2ray = FlutterV2ray(onStatusChanged: (s) {
      if (!mounted) return;
      final st = s.state.toUpperCase();
      Logs.add("→ $st");
      setState(() {
        if (st == "CONNECTED") {
          statut = "kcorp vpn connecter";
          estConnecte = true;
          enCours = false;
        } else if (st == "CONNECTING") {
          statut = "CONNEXION...";
          enCours = true;
          estConnecte = false;
        } else {
          statut = "DÉCONNECTÉ";
          estConnecte = false;
          enCours = false;
        }
      });
    });
    v2ray.initializeV2Ray();
  }

  String? buildFinalConfig(String raw, String host) {
    try {
      if (raw.trim().startsWith("{")) return raw.trim();
      if (!raw.startsWith("vless://") &&!raw.startsWith("vmess://") &&!raw.startsWith("trojan://")) return null;
      final parser = FlutterV2ray.parseFromURL(raw.trim());
      final Map<String, dynamic> json = jsonDecode(parser.getFullConfiguration());
      if (host.isNotEmpty && json["outbounds"]!= null) {
        final outbound = json["outbounds"][0];
        final stream = outbound["streamSettings"]?? {};
        final network = stream["network"]?? "ws";
        if (network == "ws") {
          stream["wsSettings"]??= {};
          stream["wsSettings"]["headers"]??= {};
          stream["wsSettings"]["headers"]["Host"] = host;
        }
        outbound["streamSettings"] = stream;
      }
      return jsonEncode(json);
    } catch (e) {
      return null;
    }
  }

  Future<void> toggle() async {
    if (estConnecte || enCours) {
      await v2ray.stopV2Ray();
      return;
    }
    final raw = configCtrl.text.trim();
    final host = hostCtrl.text.trim();
    if (raw.isEmpty) return;
    final config = buildFinalConfig(raw, host);
    if (config == null) {
      setState(() => statut = "CONFIG INVALIDE");
      return;
    }
    setState(() { enCours = true; statut = "CONNEXION..."; });
    final ok = await v2ray.requestPermission();
    if (!ok) {
      setState(() { enCours = false; statut = "PERMISSION REFUSÉE"; });
      return;
    }
    await v2ray.startV2Ray(remark: "kčø4p connected", config: config);
  }

  void doExport() {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: C.card,
      title: const Text("Exporter.kt 🔒"),
      content: TextField(controller: passCtrl, decoration: const InputDecoration(labelText: "Mot de passe")),
      actions: [
        TextButton(onPressed: ()=> Navigator.pop(context), child: const Text("Annuler")),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: C.vert), onPressed: () async {
          Navigator.pop(context);
          if (configCtrl.text.isEmpty) return;
          final f = await KTManager.exportKT(hostCtrl.text, configCtrl.text, mode, passCtrl.text);
          await Share.shareXFiles([XFile(f.path)]);
        }, child: const Text("EXPORTER")),
      ],
    ));
  }

  void doImport() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['kt']);
    if (res == null) return;
    if (!mounted) return;
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: C.card,
      title: const Text("Importer.kt 🔓"),
      content: TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: "Mot de passe")),
      actions: [
        TextButton(onPressed: ()=> Navigator.pop(context), child: const Text("Annuler")),
        ElevatedButton(onPressed: () async {
          Navigator.pop(context);
          final data = await KTManager.importKT(res.files.single.path!, passCtrl.text);
          if (data!= null) {
            setState(() { hostCtrl.text = data["host"]; configCtrl.text = data["config"]; mode = data["mode"]; });
          }
        }, child: const Text("IMPORTER")),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    Color couleur = estConnecte? C.vert : enCours? C.jaune : C.rouge;
    return Scaffold(
      appBar: AppBar(backgroundColor: C.vert, title: const Text("KČØ4P • 237 🇨🇲 •.KT")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal:12), decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(10)), child: DropdownButton<String>(value: mode, isExpanded: true, dropdownColor: C.card, underline: const SizedBox(), items: modes.map((m)=> DropdownMenuItem(value:m, child:Text(m))).toList(), onChanged: (v)=> setState(()=> mode=v!))),
          const SizedBox(height:10),
          Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: couleur, width:2)), child: Text(statut, textAlign: TextAlign.center, style: TextStyle(color: couleur, fontWeight: FontWeight.bold))),
          const SizedBox(height:18),
          GestureDetector(onTap: enCours? null : toggle, child: Container(width:140,height:140,decoration: BoxDecoration(shape:BoxShape.circle,color: C.card,border: Border.all(color: couleur,width:4)), child: Icon(Icons.power_settings_new, size:65, color:couleur))),
          const SizedBox(height:16),
          TextField(controller: hostCtrl, decoration: InputDecoration(labelText:"HOST", filled:true, fillColor:C.card, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
          const SizedBox(height:10),
          TextField(controller: configCtrl, maxLines:3, style: const TextStyle(fontSize:12, fontFamily:'monospace'), decoration: InputDecoration(labelText:"CONFIG VLESS", filled:true, fillColor:C.card, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
          const SizedBox(height:12),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: doImport, icon: const Icon(Icons.lock_open), label: const Text("IMPORTER.KT"))),
            const SizedBox(width:10),
            Expanded(child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: C.vert), onPressed: doExport, icon: const Icon(Icons.lock), label: const Text("EXPORTER.KT"))),
          ]),
          const Spacer(),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: C.card), onPressed: ()=> Navigator.push(context, MaterialPageRoute(builder: (_)=> const LogsPage())), icon: const Icon(Icons.terminal), label: const Text("ECRAN 2 - LOGS"))),
        ]),
      ),
    );
  }
}

class LogsPage extends StatelessWidget {
  const LogsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: C.vert, title: const Text("Logs - Écran 2")),
      body: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(10)),
        child: ValueListenableBuilder(
          valueListenable: Logs.n,
          builder: (_, __, ___) => ListView.builder(
            itemCount: Logs.list.length,
            itemBuilder: (_, i) {
              final log = Logs.list[i];
              if (log.toUpperCase().contains("CONNECTED")) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(log, style: const TextStyle(color: Colors.white54, fontSize: 11, fontFamily: 'monospace')),
                    const Text("free surf", style: TextStyle(color: Color(0xFF00FF00), fontSize: 16, fontWeight: FontWeight.bold)),
                  ]),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(log, style: const TextStyle(color: Color(0xFF8BC34A), fontSize: 11, fontFamily: 'monospace')),
              );
            },
          ),
        ),
      ),
    );
  }
}
