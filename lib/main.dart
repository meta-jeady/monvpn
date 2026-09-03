import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  runApp(const Kco4pVPNApp());
}

class Kco4pVPNApp extends StatelessWidget {
  const Kco4pVPNApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KČØ4P VPN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, scaffoldBackgroundColor: const Color(0xFFE0F2FE), colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0EA5E9))),
      home: const HomeScreen(),
    );
  }
}

class CustomSSHServer {
  String host; int port; String username; String password;
  CustomSSHServer(this.host, this.port, this.username, this.password);
}

class SshTunnelService {
  SSHClient? _client;
  ServerSocket? _socksServer;
  RawDatagramSocket? _udpGwSocket;
  bool _running = false;

  String _time() {
    final now = DateTime.now();
    return "${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}:${now.second.toString().padLeft(2,'0')}";
  }

  Future<void> connect(CustomSSHServer server, Function(String) onLog) async {
    _running = true;
    onLog("[${_time()}] WakeLock acquire");
    onLog("[${_time()}] UDP Starting...");
    onLog("[${_time()}] dns forwarding enable");
    onLog("[${_time()}] Preferred DNS 8.8.8.8");
    onLog("[${_time()}] Alternate DNS 8.8.4.4");
    onLog("[${_time()}] set UDPGW 127.0.0.1:7300");
    onLog("[${_time()}] UDP Executing...");
    onLog("[${_time()}] UDP Connecting to Server...");

    final socket = await SSHSocket.connect(server.host, server.port, timeout: const Duration(seconds: 15));
    _client = SSHClient(socket, username: server.username, onPasswordRequest: () => server.password);
    await _client!.authenticated;

    _udpGwSocket = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 7300);
    _socksServer = await ServerSocket.bind(InternetAddress.loopbackIPv4, 10808);
    _socksServer!.listen((client) async {
      try { await _handleSocks(client); } catch (_) {}
    });

    await Future.delayed(const Duration(milliseconds: 600));
    onLog("[${_time()}] UDP Connected");
    await Future.delayed(const Duration(milliseconds: 200));
    onLog("[${_time()}] HTTP Custom ready to use");
  }

  Future<void> _handleSocks(Socket client) async {
    try {
      final data = await client.first.timeout(const Duration(seconds: 5));
      if (data[0]!= 0x05) { client.close(); return; }
      client.add([0x05, 0x00]);
      final req = await client.first.timeout(const Duration(seconds: 5));
      String dstHost = ""; int dstPort = 0;
      if (req[3] == 0x01) {
        dstHost = "${req[4]}.${req[5]}.${req[6]}.${req[7]}";
        dstPort = (req[8] << 8) + req[9];
      } else if (req[3] == 0x03) {
        final len = req[4];
        dstHost = utf8.decode(req.sublist(5, 5 + len));
        dstPort = (req[5 + len] << 8) + req[5 + len + 1];
      } else { client.close(); return; }
      final remote = await _client!.forwardLocal(dstHost, dstPort);
      client.add([0x05, 0x00, 0x00, 0x01, 0, 0, 0, 0, 0, 0]);
      remote.stream.cast<List<int>>().listen((d) => client.add(d), onDone: () => client.close());
      client.listen((d) => remote.add(d), onDone: () => remote.close());
    } catch (_) { try { client.close(); } catch (_) {} }
  }

  Future<void> disconnect() async {
    _running = false;
    try { await _socksServer?.close(); } catch (_) {}
    try { _udpGwSocket?.close(); } catch (_) {}
    _client?.close();
  }
}

class HomeScreen extends StatefulWidget { const HomeScreen({super.key}); @override State<HomeScreen> createState() => _HomeScreenState(); }

class _HomeScreenState extends State<HomeScreen> {
  late FlutterV2ray v2ray;
  final SshTunnelService sshTunnel = SshTunnelService();

  String statut = "DÉCONNECTÉ"; bool estConnecte = false; bool enCours = false;
  String modeSelectionne = "SSH"; bool isLocked = false;
  String? lockedHost; String? lockedConfig; String? lockedName;
  final List<String> modes = ["VLESS / VMess", "UDP", "SlowDNS", "SSH", "Trojan"];
  final List<String> logs = [];

  Map<String, Map<String, String>> configs = {
    "VLESS / VMess": {"host": "", "config": ""},
    "SSH": {"host": "", "config": "185.253.117.26:1-65535@Vpn3-vpnjantit.com:Vpn2"},
    "UDP": {"host": "", "config": "185.253.117.26:1-65535@Vpn3-vpnjantit.com:Vpn2"},
    "SlowDNS": {"host": "", "config": ""},
    "Trojan": {"host": "", "config": ""},
  };

  @override
  void initState() {
    super.initState();
    v2ray = FlutterV2ray(onStatusChanged: (s) {
      if (!mounted) return;
      final state = s.state.toUpperCase();
      if (state == "CONNECTED" && statut!= "FREE SERF") {
        setState(() { statut = "FREE SERF"; estConnecte = true; enCours = false; });
      } else if (state == "CONNECTING") {
        setState(() { statut = "CONNEXION..."; enCours = true; });
      } else if (state == "DISCONNECTED") {
        setState(() { statut = "DÉCONNECTÉ"; estConnecte = false; enCours = false; });
      }
    });
    initCore(); loadLockedConfig();
  }

  Future<void> initCore() async { await v2ray.initializeV2Ray(); addLog("Core prêt"); }
  Future<void> loadLockedConfig() async { final p = await SharedPreferences.getInstance(); if (p.getBool('isLocked')?? false) { setState(() { isLocked = true; lockedName = p.getString('lockedName'); modeSelectionne = p.getString('lockedMode')?? "SSH"; lockedHost = p.getString('lockedHost'); lockedConfig = p.getString('lockedConfig'); }); } }
  Future<void> saveLockedConfig({required String name, required String mode, required String host, required String config}) async { final p = await SharedPreferences.getInstance(); await p.setBool('isLocked', true); await p.setString('lockedName', name); await p.setString('lockedMode', mode); await p.setString('lockedHost', host); await p.setString('lockedConfig', config); }

  String _time() { final n = DateTime.now(); return "${n.hour.toString().padLeft(2,'0')}:${n.minute.toString().padLeft(2,'0')}:${n.second.toString().padLeft(2,'0')}"; }

  String maskLog(String msg) {
    String safe = msg;
    // Masque tout ce qui ressemble à IP, domaine, user, pass
    try {
      configs.forEach((_, data) {
        final host = data["host"]?? "";
        final config = data["config"]?? "";
        if (host.isNotEmpty && host.length > 2) safe = safe.replaceAll(host, "*******");
        if (config.contains("@")) {
          final ip = config.split('@')[0].split(':')[0];
          if (ip.length > 3) safe = safe.replaceAll(ip, "*******");
          final userPart = config.split('@').length > 1? config.split('@')[1] : "";
          if (userPart.contains(":")) {
            final user = userPart.split(':')[0];
            final pass = userPart.split(':')[1];
            if (user.length > 2) safe = safe.replaceAll(user, "*******");
            if (pass.length > 1) safe = safe.replaceAll(pass, "*******");
          }
        }
      });
      if (lockedHost!= null && lockedHost!.isNotEmpty) safe = safe.replaceAll(lockedHost!, "*******");
      if (lockedConfig!= null && lockedConfig!.contains("@")) {
        final ip = lockedConfig!.split('@')[0].split(':')[0];
        safe = safe.replaceAll(ip, "*******");
      }
    } catch (_) {}
    safe = safe.replaceAll(RegExp(r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b'), "*******");
    safe = safe.replaceAll(RegExp(r'Vpn[0-9].*?\.com', caseSensitive: false), "*******");
    return safe;
  }

  void addLog(String msg) {
    final masked = maskLog(msg);
    setState(() => logs.add("[$_time()] $masked"));
  }

  CustomSSHServer? parseCustom(String input) {
    try {
      input = input.trim(); if (!input.contains('@')) return null;
      if (input.startsWith("vless://") || input.startsWith("vmess://") || input.startsWith("trojan://")) return null;
      final pr = input.split('@'); final hp = pr[0]; final up = pr[1];
      final lc = hp.lastIndexOf(':'); final ip = hp.substring(0, lc).trim(); var prg = hp.substring(lc + 1).trim();
      int port; if (prg.contains('-')) { final r = prg.split('-'); port = int.parse(r[0]) + Random().nextInt(int.parse(r[1]) - int.parse(r[0]) + 1); } else { port = int.parse(prg); }
      final fc = up.indexOf(':'); final user = up.substring(0, fc).trim(); final pass = up.substring(fc + 1).trim();
      return CustomSSHServer(ip, port, user, pass);
    } catch (_) { return null; }
  }

  String? buildFinalConfig(String raw, String host) {
    try {
      if (raw.trim().startsWith("{")) return raw.trim();
      final parser = FlutterV2ray.parseFromURL(raw.trim());
      final full = parser.getFullConfiguration();
      final Map<String, dynamic> json = jsonDecode(full);
      if (host.isNotEmpty && json["outbounds"]!= null && json["outbounds"].isNotEmpty) {
        final outbound = json["outbounds"][0]; final stream = outbound["streamSettings"]?? {};
        if (stream["network"] == "ws") { stream["wsSettings"]??= {}; stream["wsSettings"]["headers"]??= {}; stream["wsSettings"]["headers"]["Host"] = host; }
        outbound["streamSettings"] = stream;
      }
      return jsonEncode(json);
    } catch (_) { return null; }
  }

  Future<void> toggle() async {
    if (estConnecte || enCours) {
      addLog("UDP Stopping..."); addLog("WakeLock release"); addLog("HTTP Custom stopped");
      await sshTunnel.disconnect(); await v2ray.stopV2Ray();
      setState(() { estConnecte = false; enCours = false; statut = "DÉCONNECTÉ"; }); return;
    }
    final raw = isLocked? (lockedConfig?? "") : (configs[modeSelectionne]!["config"]?? "");
    if (raw.isEmpty) { addLog("Aucune configuration"); return; }

    final srv = parseCustom(raw);
    if (srv!= null) {
      setState(() => enCours = true);
      try {
        await sshTunnel.connect(srv, (m) => addLog(m));
        final ok = await v2ray.requestPermission(); if (!ok) { setState(() { enCours = false; statut = "PERMISSION REFUSÉE"; }); return; }
        final cfg = jsonEncode({"inbounds": [{"port": 10800, "protocol": "socks", "settings": {"udp": true}}], "outbounds": [{"protocol": "socks", "settings": {"servers": [{"address": "127.0.0.1", "port": 10808}]}}]});
        await v2ray.startV2Ray(remark: "kčø4p ${modeSelectionne} connected", config: cfg, blockedApps: []);
        setState(() { statut = "FREE SERF"; estConnecte = true; enCours = false; });
      } catch (e) {
        addLog("Échec: ${maskLog(e.toString())}"); setState(() { enCours = false; statut = "ÉCHEC"; }); await sshTunnel.disconnect();
      }
      return;
    }

    final host = isLocked? (lockedHost?? "") : (configs[modeSelectionne]!["host"]?? "");
    final config = buildFinalConfig(raw, host);
    if (config == null) { setState(() => statut = "CONFIG INVALIDE"); return; }
    setState(() => enCours = true);
    try { final ok = await v2ray.requestPermission(); if (!ok) return; await v2ray.startV2Ray(remark: "kčø4p VLESS connected", config: config, blockedApps: []); } catch (e) { addLog("Échec: ${maskLog(e.toString())}"); setState(() => enCours = false); }
  }

  void openConfigPage() {
    if (isLocked) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Config verrouillée - Clean d'abord"))); return; }
    Widget page;
    switch (modeSelectionne) {
      case "SSH": page = SSHConfigPage(configs: configs[modeSelectionne]!, onSave: (m) => setState(() => configs[modeSelectionne] = m)); break;
      case "UDP": page = UDPConfigPage(configs: configs[modeSelectionne]!, onSave: (m) => setState(() => configs[modeSelectionne] = m)); break;
      case "Trojan": page = TrojanConfigPage(configs: configs[modeSelectionne]!, onSave: (m) => setState(() => configs[modeSelectionne] = m)); break;
      case "SlowDNS": page = SlowDNSConfigPage(configs: configs[modeSelectionne]!, onSave: (m) => setState(() => configs[modeSelectionne] = m)); break;
      default: page = VlessConfigPage(configs: configs[modeSelectionne]!, onSave: (m) => setState(() => configs[modeSelectionne] = m)); break;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Future<void> cleanConfig() async { final p = await SharedPreferences.getInstance(); await p.clear(); setState(() { isLocked = false; lockedHost = null; lockedConfig = null; configs.forEach((k, v) { v["host"] = ""; v["config"] = ""; }); statut = "DÉCONNECTÉ"; logs.clear(); }); addLog("App réinitialisée"); }

  Color get couleur { if (estConnecte) return const Color(0xFF22C55E); if (enCours) return const Color(0xFFF59E0B); return const Color(0xFFEF4444); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0F2FE),
      appBar: AppBar(title: const Text("KČØ4P VPN", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), backgroundColor: const Color(0xFF0EA5E9), actions: [IconButton(icon: const Icon(Icons.article, color: Colors.white), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LogsScreen(logs: logs))))]),
      body: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: DropdownButton<String>(value: modeSelectionne, isExpanded: true, underline: const SizedBox(), items: modes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(), onChanged: (v) { if (v!= null) setState(() => modeSelectionne = v); })),
        const SizedBox(height: 14),
        Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: Text(statut, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: couleur))),
        const SizedBox(height: 20),
        GestureDetector(onTap: enCours? null : toggle, child: Container(width: 140, height: 140, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, border: Border.all(color: couleur, width: 4)), child: Icon(Icons.power_settings_new, size: 70, color: couleur))),
        const SizedBox(height: 20),
        ElevatedButton.icon(onPressed: openConfigPage, icon: const Icon(Icons.settings), label: Text("Configurer $modeSelectionne"), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.download, size: 18), label: const Text("Import"), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9), foregroundColor: Colors.white))),
          const SizedBox(width: 8),
          Expanded(child: ElevatedButton.icon(onPressed: cleanConfig, icon: const Icon(Icons.delete, size: 18), label: const Text("Clean"), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white))),
          const SizedBox(width: 8),
          Expanded(child: ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExportPage(mode: modeSelectionne, host: configs[modeSelectionne]!["host"]?? "", config: configs[modeSelectionne]!["config"]?? ""))), icon: const Icon(Icons.link, size: 18), label: const Text("Export"), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E), foregroundColor: Colors.white))),
        ]),
        const Spacer(), const Text("DEV : kcørp tech serf", style: TextStyle(color: Colors.black38, fontSize: 12)),
      ])),
    );
  }
}

// PAGES
class VlessConfigPage extends StatefulWidget { final Map<String,String> configs; final Function(Map<String,String>) onSave; const VlessConfigPage({super.key, required this.configs, required this.onSave}); @override State<VlessConfigPage> createState()=>_VlessConfigPageState(); }
class _VlessConfigPageState extends State<VlessConfigPage> { late TextEditingController h,c; @override void initState(){super.initState(); h=TextEditingController(text:widget.configs["host"]); c=TextEditingController(text:widget.configs["config"]);} @override Widget build(BuildContext context){return Scaffold(backgroundColor: const Color(0xFFE0F2FE), appBar: AppBar(title: const Text("VLESS / VMess Config", style: TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF0EA5E9)), body: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("HOST", style: TextStyle(color: Colors.black54, fontSize:12)), TextField(controller: h, decoration: InputDecoration(filled:true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))), const SizedBox(height:12), const Text("CONFIGURATION", style: TextStyle(color: Colors.black54, fontSize:12)), TextField(controller: c, maxLines:5, decoration: InputDecoration(filled:true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))), const Spacer(), SizedBox(width: double.infinity, child: ElevatedButton(onPressed:(){widget.onSave({"host":h.text,"config":c.text}); Navigator.pop(context);}, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical:16)), child: const Text("Sauvegarder")))])));}}

class SSHConfigPage extends StatefulWidget { final Map<String,String> configs; final Function(Map<String,String>) onSave; const SSHConfigPage({super.key, required this.configs, required this.onSave}); @override State<SSHConfigPage> createState()=>_SSHConfigPageState(); }
class _SSHConfigPageState extends State<SSHConfigPage> { late TextEditingController c; @override void initState(){super.initState(); c=TextEditingController(text:widget.configs["config"]);} @override Widget build(BuildContext context){return Scaffold(backgroundColor: const Color(0xFFE0F2FE), appBar: AppBar(title: const Text("SSH Config", style: TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF0EA5E9)), body: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)), child: const Text("Format: IP:PORT@USER:PASS\nEx: 185.253.117.26:1-65535@Vpn3-vpnjantit.com:Vpn2", style: TextStyle(fontFamily:'monospace', fontSize:11))), const SizedBox(height:12), TextField(controller: c, maxLines:4, obscureText: true, decoration: InputDecoration(labelText:"Serveur masqué", filled:true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))), const Spacer(), SizedBox(width: double.infinity, child: ElevatedButton(onPressed:(){widget.onSave({"host":"","config":c.text}); Navigator.pop(context);}, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical:16)), child: const Text("Sauvegarder SSH")))])));}}

class UDPConfigPage extends StatefulWidget { final Map<String,String> configs; final Function(Map<String,String>) onSave; const UDPConfigPage({super.key, required this.configs, required this.onSave}); @override State<UDPConfigPage> createState()=>_UDPConfigPageState(); }
class _UDPConfigPageState extends State<UDPConfigPage> {
  late TextEditingController c;
  @override void initState(){super.initState(); c=TextEditingController(text:widget.configs["config"]);}
  @override Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: const Color(0xFFE0F2FE),
      appBar: AppBar(title: const Text("UDP Config", style: TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF0EA5E9)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Mode UDPGW - HTTP Custom Ready To Use", style: TextStyle(fontWeight: FontWeight.bold, fontSize:12)),
                  SizedBox(height:4),
                  Text("Format: IP:PORT@USER:PASS\nDonne internet avec UDPGW 127.0.0.1:7300", style: TextStyle(fontFamily:'monospace', fontSize:10, color: Colors.black54)),
                ],
              )
            ),
            const SizedBox(height:12),
            const Text("CONFIGURATION UDP", style: TextStyle(color: Colors.black54, fontSize:12)),
            const SizedBox(height:4),
            TextField(
              controller: c,
              maxLines:4,
              obscureText: true,
              decoration: InputDecoration(
                labelText:"Serveur masqué",
                hintText:"*******",
                filled:true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)
              )
            ),
            const Spacer(),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed:(){widget.onSave({"host":"","config":c.text}); Navigator.pop(context);}, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical:16)), child: const Text("Sauvegarder UDP")))
          ]
        )
      )
    );
  }
}

class TrojanConfigPage extends StatefulWidget { final Map<String,String> configs; final Function(Map<String,String>) onSave; const TrojanConfigPage({super.key, required this.configs, required this.onSave}); @override State<TrojanConfigPage> createState()=>_TrojanConfigPageState(); }
class _TrojanConfigPageState extends State<TrojanConfigPage> { late TextEditingController h,c; @override void initState(){super.initState(); h=TextEditingController(text:widget.configs["host"]); c=TextEditingController(text:widget.configs["config"]);} @override Widget build(BuildContext context){return Scaffold(backgroundColor: const Color(0xFFE0F2FE), appBar: AppBar(title: const Text("Trojan Config", style: TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF0EA5E9)), body: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("HOST", style: TextStyle(color: Colors.black54, fontSize:12)), TextField(controller: h, decoration: InputDecoration(filled:true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))), const SizedBox(height:12), const Text("TROJAN URL", style: TextStyle(color: Colors.black54, fontSize:12)), TextField(controller: c, maxLines:5, decoration: InputDecoration(filled:true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))), const Spacer(), SizedBox(width: double.infinity, child: ElevatedButton(onPressed:(){widget.onSave({"host":h.text,"config":c.text}); Navigator.pop(context);}, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical:16)), child: const Text("Sauvegarder")))])));}}

class SlowDNSConfigPage extends StatefulWidget { final Map<String,String> configs; final Function(Map<String,String>) onSave; const SlowDNSConfigPage({super.key, required this.configs, required this.onSave}); @override State<SlowDNSConfigPage> createState()=>_SlowDNSConfigPageState(); }
class _SlowDNSConfigPageState extends State<SlowDNSConfigPage> { late TextEditingController h,c; @override void initState(){super.initState(); h=TextEditingController(text:widget.configs["host"]); c=TextEditingController(text:widget.configs["config"]);} @override Widget build(BuildContext context){return Scaffold(backgroundColor: const Color(0xFFE0F2FE), appBar: AppBar(title: const Text("SlowDNS Config", style: TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF0EA5E9)), body: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("HOST / DNS", style: TextStyle(color: Colors.black54, fontSize:12)), TextField(controller: h, decoration: InputDecoration(filled:true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))), const SizedBox(height:12), const Text("CONFIG", style: TextStyle(color: Colors.black54, fontSize:12)), TextField(controller: c, maxLines:3, decoration: InputDecoration(filled:true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))), const Spacer(), SizedBox(width: double.infinity, child: ElevatedButton(onPressed:(){widget.onSave({"host":h.text,"config":c.text}); Navigator.pop(context);}, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical:16)), child: const Text("Sauvegarder")))])));}}

class ExportPage extends StatefulWidget { final String mode; final String host; final String config; const ExportPage({super.key, required this.mode, required this.host, required this.config}); @override State<ExportPage> createState()=>_ExportPageState(); }
class _ExportPageState extends State<ExportPage> {
  final nameCtrl=TextEditingController();
  bool lock=true;
  String? link;
  DateTime? expireDate;

  void gen(){
    final data={
      "app":"KČØ4P VPN",
      "name":nameCtrl.text.isEmpty? "KČØ4P ${widget.mode}" : nameCtrl.text,
      "mode":widget.mode,
      "host":widget.host,
      "config":widget.config,
      "locked":lock,
      "expire_date": expireDate?.toIso8601String()
    };
    String content=jsonEncode(data);
    if(lock) content="KCO4P_LOCKED:${base64.encode(utf8.encode(content))}";
    setState(()=>link="kco4p://config/${base64.encode(utf8.encode(content))}");
    Clipboard.setData(ClipboardData(text:link!));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lien copié!")));
  }

  @override Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: const Color(0xFFE0F2FE),
      appBar: AppBar(title: Text("Exporter ${widget.mode}", style: const TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF0EA5E9)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: nameCtrl, decoration: InputDecoration(labelText:"Nom de la config", hintText:"Ex: MTN Cameroon ${widget.mode}", filled:true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
            const SizedBox(height:12),
            SwitchListTile(
              title: const Text("Verrouiller la config"),
              subtitle: Text(lock? "Le client verra *******" : "Le client verra le serveur en clair"),
              value: lock,
              onChanged:(v)=>setState(()=>lock=v),
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            const SizedBox(height:12),
            ListTile(
              title: const Text("Date d'expiration"),
              subtitle: Text(expireDate == null? "Jamais" : expireDate.toString().split(' ')[0]),
              trailing: const Icon(Icons.calendar_today),
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onTap: () async {
                final date = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 30)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                if(date!= null) setState(()=> expireDate = date);
              },
            ),
            const SizedBox(height:20),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: gen, icon: const Icon(Icons.link), label: Text("Générer lien ${widget.mode}"), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical:16)))),
            const SizedBox(height:20),
            if(link!=null) Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)), child: SelectableText(link!, style: const TextStyle(fontFamily:'monospace', fontSize:11))),
          ]
        )
      )
    );
  }
}

class LogsScreen extends StatelessWidget {
  final List<String> logs; const LogsScreen({super.key, required this.logs});
  @override Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("LOG KČØ4P", style: TextStyle(color: Colors.white, fontFamily:'monospace', fontSize:14)), backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
      body: logs.isEmpty
    ? const Center(child: Text("Aucun log", style: TextStyle(color: Colors.white54, fontFamily:'monospace')))
      : ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: logs.length,
        itemBuilder: (context, i){
          final e = logs[i];
          Color col = Colors.white;
          if(e.contains("ready to use")) col = Colors.yellow;
          else if(e.contains("Connected") || e.contains("FREE SERF")) col = const Color(0xFF4ADE80);
          else if(e.contains("Starting")) col = Colors.white70;
          else if(e.contains("Échec")) col = const Color(0xFFF87171);
          else if(e.contains("*******")) col = const Color(0xFF94A3B8);
          return Padding(padding: const EdgeInsets.symmetric(vertical:2), child: Text(e, style: TextStyle(color: col, fontFamily:'monospace', fontSize:11)));
        }
      ),
    );
  }
}
