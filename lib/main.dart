// ignore_for_file: unnecessary_to_list_in_spreads

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart'; 
import 'package:audioplayers/audioplayers.dart';
import 'notifications_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MamApp());
}

class MamApp extends StatelessWidget {
  const MamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Quản lí cây',
      theme: ThemeData(
        primarySwatch: Colors.green,
        fontFamily: 'Arial',
      ),
      home: const MainPage(),
    );
  }
}

/// ---------------- TRANG CHÍNH (Bottom Nav) ----------------
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 1;

  final List<Widget> _pages = [
    const Center(child: Text("Tìm kiếm")),
    const PlantTabPage(),
    const Center(child: Text("Cộng đồng")),
    const Center(child: Text("Trang cá nhân")),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF7ED957),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "Tìm kiếm"),
          BottomNavigationBarItem(icon: Icon(Icons.local_florist), label: "Cây của tôi"),
          BottomNavigationBarItem(icon: Icon(Icons.groups), label: "Cộng đồng"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Tôi"),
        ],
      ),
    );
  }
}

/// ---------------- TAB BAR (Cây của tôi <-> Thông báo) ----------------
class PlantTabPage extends StatelessWidget {
  const PlantTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: const Color(0xFF7ED957),
          elevation: 0,
          toolbarHeight: 100,
          flexibleSpace: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              SizedBox(height: 20),
              Text("MẦM",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
              SizedBox(height: 8),
            ],
          ),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            unselectedLabelStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.normal),
            tabs: [
              Tab(text: "Cây của tôi"),
              Tab(text: "Thông báo"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            MyPlantsPage(),
            AllNotificationsPage(),
          ],
        ),
      ),
    );
  }
}

/// ---------------- CÂY CỦA TÔI (Firebase-backed) ----------------
class MyPlantsPage extends StatefulWidget {
  const MyPlantsPage({super.key});

  @override
  State<MyPlantsPage> createState() => _MyPlantsPageState();
}

class _MyPlantsPageState extends State<MyPlantsPage> {
  final DatabaseReference groupsRef = FirebaseDatabase.instance.ref("groups");

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: groupsRef.onValue,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Lỗi: ${snapshot.error}"));
        }
        if (!snapshot.hasData || (snapshot.data as DatabaseEvent).snapshot.value == null) {
          // Nếu không có dữ liệu, giữ giao diện cũ hoặc hiển thị thông báo
          return const Center(child: Text("Chưa có cây nào"));
        }

        final data = Map<String, dynamic>.from(
          (snapshot.data! as DatabaseEvent).snapshot.value as Map,
        );

        // --- build: sau khi đã parse `data` từ snapshot ---
        final trees = data.entries.map((e) {
          final treeId = e.key;
          final treeData = Map<String, dynamic>.from(e.value);
          final sensor = Map<String, dynamic>.from(treeData['sensor'] ?? {});
          final image = treeData['image'] ??
              (treeId == "tree1"
                  ? "assets/images/hinh1.png"
                  : treeId == "tree2"
                      ? "assets/images/hinh2.png"
                      : "assets/images/hinh3.png");
          final messagesMap = Map<String, dynamic>.from(treeData['messages'] ?? {});
          return {
            "id": treeId,
            "name": treeData["plantName"] ?? "Chưa đặt tên",
            "autoMode": treeData["autoMode"] ?? false,
            "threshold": treeData["threshold"] ?? 0,
            "sensor": sensor,
            "image": image,
            "messages": messagesMap,
          };
        }).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: trees.length,
          itemBuilder: (context, i) {
            final tree = trees[i];
            final sensor = tree["sensor"] as Map<String, dynamic>;
            final imagePath = tree["image"] as String;
            final messagesMap = tree['messages'] as Map<String, dynamic>;

            // build list of messages and pick latest
            List<Map<String, dynamic>> messageList = [];
            if (messagesMap.isNotEmpty) {
              messageList = messagesMap.entries.map((me) {
                final m = Map<String, dynamic>.from(me.value);
                return {
                  "key": me.key,
                  "user": m["user"] ?? "Hệ thống",
                  "text": m["text"] ?? "",
                  "date": m["date"] ?? "",
                  "time": m["time"] ?? ""
                };
              }).toList();

              messageList.sort((a, b) {
                final ad = "${a["date"]} ${a["time"]}";
                final bd = "${b["date"]} ${b["time"]}";
                return bd.compareTo(ad);
              });
            }

            final latest = messageList.isNotEmpty ? messageList.first : null;

            // image widget: support network, asset, local file
            Widget imageWidget;
            if (imagePath.startsWith("http") || imagePath.startsWith("https")) {
              imageWidget = Image.network(imagePath, fit: BoxFit.cover);
            } else if (imagePath.startsWith("assets/")) {
              imageWidget = Image.asset(imagePath, fit: BoxFit.cover);
            } else {
              imageWidget = Image.file(File(imagePath), fit: BoxFit.cover);
            }

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlantPage(treeId: tree["id"] as String),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 15),
                decoration: BoxDecoration(
                  color: const Color(0xFFD6F5D6),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.black12),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(15),
                        bottomLeft: Radius.circular(15),
                      ),
                      child: SizedBox(width: 120, height: 120, child: imageWidget),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tree["name"] as String,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                            Text("Ngưỡng: ${tree["threshold"]}%"),
                            const SizedBox(height: 6),
                            Text("🌱 Độ ẩm đất: ${sensor["soilMoisture"] ?? "--"}%"),
                            Text("🌡 ${sensor["temperature"] ?? "--"}°C  💧 ${sensor["humidity"] ?? "--"}%"),
                            // latest message (if có)
                            if (latest != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                "🔔 ${latest["text"]}",
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black87),
                              ),
                              const SizedBox(height: 2),
                              Text("${latest["date"]} ${latest["time"]}", style: const TextStyle(color: Colors.black45, fontSize: 12)),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// ---------------- CHI TIẾT CÂY (subscription-based) ----------------
class PlantPage extends StatefulWidget {
  final String treeId;
  const PlantPage({super.key, required this.treeId});

  @override
  State<PlantPage> createState() => _PlantPageState();
}

class _PlantPageState extends State<PlantPage> {
  DatabaseReference? _groupRef;
  DatabaseReference? _manualRef;
  DatabaseReference? _thresholdRef;
  DatabaseReference? _autoModeRef;
  DatabaseReference? _plantNameRef;

  StreamSubscription<DatabaseEvent>? _groupSub;
  String? _listeningTreeId;

  double? temperature;
  double? humidity;
  double? soilMoisture;
  int threshold = 40;
  bool autoMode = false;
  String plantName = "Cây chưa đặt tên";
  String? _imagePath;

  final _thresholdController = TextEditingController();
  final _plantNameController = TextEditingController();

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPlantNameOffline();
    _listenToTree(widget.treeId);
  }

  @override
  void didUpdateWidget(covariant PlantPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.treeId != widget.treeId) {
      _listenToTree(widget.treeId);
    }
  }

  void _listenToTree(String id) {
    if (_groupSub != null) {
      debugPrint("◀️ Cancelling listener for $_listeningTreeId");
      _groupSub!.cancel();
      _groupSub = null;
    }

    _listeningTreeId = id;
    _groupRef = FirebaseDatabase.instance.ref("groups/$id");
    _manualRef = FirebaseDatabase.instance.ref("groups/$id/pump/manual");
    _thresholdRef = FirebaseDatabase.instance.ref("groups/$id/threshold");
    _autoModeRef = FirebaseDatabase.instance.ref("groups/$id/autoMode");
    _plantNameRef = FirebaseDatabase.instance.ref("groups/$id/plantName");

    debugPrint("▶️ Start listening to groups/$id");

    _groupSub = _groupRef!.onValue.listen((event) {
      final raw = event.snapshot.value;
      if (raw == null) {
        setState(() {
          _loading = false;
        });
        return;
      }

      final data = Map<String, dynamic>.from(raw as Map);
      final sensorRaw = Map<String, dynamic>.from(data['sensor'] ?? {});
      final t = double.tryParse((sensorRaw['temperature'] ?? sensorRaw['nhietdo'] ?? "").toString());
      final h = double.tryParse((sensorRaw['humidity'] ?? sensorRaw['doam'] ?? "").toString());
      final sm = double.tryParse((sensorRaw['soilMoisture'] ?? sensorRaw['doamdat'] ?? "").toString());

      final newPlantName = data['plantName']?.toString() ?? plantName;
      final newAutoMode = data['autoMode'] == true;
      final newThreshold = (data['threshold'] is num) ? (data['threshold'] as num).toInt() : threshold;
      final imageFromDb = data['image']?.toString() ?? "";

      setState(() {
        temperature = t;
        humidity = h;
        soilMoisture = sm;
        plantName = newPlantName;
        autoMode = newAutoMode;
        threshold = newThreshold;
        _imagePath = imageFromDb;
        _plantNameController.text = plantName;
        _thresholdController.text = threshold.toString();
        _loading = false;
      });

      debugPrint("🔔 [${widget.treeId}] sensor update: t=$t h=$h soil=$sm");
    }, onError: (err) {
      debugPrint("Listener error for $id: $err");
    });
  }

  Future<void> _loadPlantNameOffline() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('plantName_${widget.treeId}');
    if (saved != null && saved.isNotEmpty) {
      setState(() {
        plantName = saved;
        _plantNameController.text = plantName;
      });
    }
  }

  Future<void> _savePlantNameOffline(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('plantName_${widget.treeId}', name);
  }

 Future<void> _pickAndUploadImage() async {
  try {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (picked == null) return;

    final filePath = picked.path; // chỉ lấy path local thôi

    await _groupRef?.child("image").set(filePath); 
    await _addMessage("🖼️ Cập nhật ảnh cây");

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đã lưu ảnh (local path) vào DB")),
      );
    }

    setState(() {
      _imagePath = filePath; // cập nhật state
    });
  } catch (e) {
    debugPrint("pick image error: $e");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lỗi khi chọn ảnh")),
      );
    }
  }
}

  Future<void> _addMessage(String message) async {
  try {
    final now = DateTime.now();

    // format ngày giờ (giống NotificationsPage đang parse)
    final dateStr = DateFormat("dd/MM/yyyy").format(now);
    final timeStr = DateFormat("HH:mm").format(now);

    final msgData = {
      "text": message,
      "date": dateStr,
      "time": timeStr,
      "timestamp": now.millisecondsSinceEpoch,
    };

    // 🔹 1. Lưu vào Realtime Database (realtime hiển thị trong app)
    await _groupRef?.child("messages").push().set(msgData);

    // 🔹 2. Lưu vào Firestore (lưu lâu dài để query & backup)
    final docRef = FirebaseFirestore.instance
        .collection("notifications")
        .doc(widget.treeId) // mỗi cây 1 doc
        .collection("messages");

    await docRef.add(msgData);

    // 🔹 3. Xoá log cũ hơn 30 ngày trong Firestore
    final cutoff = now.subtract(const Duration(days: 30));
    final oldLogs = await docRef
        .where("timestamp", isLessThan: cutoff.millisecondsSinceEpoch)
        .get();

    for (var doc in oldLogs.docs) {
      await doc.reference.delete();
    }

  } catch (e) {
    debugPrint("Lỗi khi thêm message: $e");
  }
}

  Future<void> _triggerManualPump() async {
    try {
      await _manualRef?.set(true);
      await _addMessage("💦 Tưới thủ công");
      Future.delayed(const Duration(seconds: 3), () async {
        try {
          await _manualRef?.set(false);
        } catch (_) {}
      });
    } catch (e) {
      debugPrint("triggerManualPump error: $e");
    }
  }

  Future<void> _setAutoMode(bool value) async {
    await _autoModeRef?.set(value);
    await _addMessage(value ? "🔁 Bật tưới tự động" : "✋ Tắt tưới tự động");
  }

  Future<void> _setThresholdFromController() async {
    final v = _thresholdController.text;
    final intVal = int.tryParse(v);
    if (intVal != null && intVal >= 0 && intVal <= 100) {
      await _thresholdRef?.set(intVal);
      await _addMessage("⚙️ Cập nhật ngưỡng: $intVal%");
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🔴 Ngưỡng phải từ 0 đến 100")));
    }
  }

  Future<void> _updatePlantNameFromController() async {
    final v = _plantNameController.text.trim();
    if (v.isNotEmpty) {
      await _plantNameRef?.set(v);
      await _savePlantNameOffline(v);
      await _addMessage("✏️ Đổi tên cây: $v");
    }
  }

  String _statusFromSoil(double? sm, int threshold) {
    if (sm == null) return "Chưa có dữ liệu";
    if (sm > 90) return "Đất quá ướt 🌊";
    if (sm > threshold) return "Tốt ✅";
    if (sm >= 20) return "Đất khô 🏜️";
    return "⚠️ Cần tưới ngay!";
  }

  @override
  void dispose() {
    _groupSub?.cancel();
    _thresholdController.dispose();
    _plantNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text("🌱 ${widget.treeId}")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("🌱 $plantName"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_camera_outlined),
            onPressed: () async {
              await _pickAndUploadImage();
            },
            tooltip: "Thay ảnh cây",
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsPage(treeId: widget.treeId)));
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Center(
              child: Container(
                height: 200,
                width: 200,
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Builder(builder: (_) {
                    final imagePath = _imagePath ?? "";
                    if (imagePath.startsWith("http")) {
                      return Image.network(imagePath, fit: BoxFit.cover);
                    } else if (imagePath.startsWith("assets/")) {
                      return Image.asset(imagePath, fit: BoxFit.cover);
                    } else if (imagePath.isNotEmpty && File(imagePath).existsSync()) {
                      return Image.file(File(imagePath), fit: BoxFit.cover);
                    }
                    // fallback -> lấy trực tiếp từ DB
                    return FutureBuilder(
                      future: _groupRef?.child("image").get(),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (!snap.hasData || snap.data == null) {
                          return const Center(child: Icon(Icons.local_florist, size: 80, color: Colors.green));
                        }
                        final dbSnapshot = snap.data as DataSnapshot;
                        final dbPath = dbSnapshot.value?.toString() ?? "";
                        if (dbPath.startsWith("http")) {
                          return Image.network(dbPath, fit: BoxFit.cover);
                        } else if (dbPath.startsWith("assets/")) {
                          return Image.asset(dbPath, fit: BoxFit.cover);
                        } else {
                          try {
                            final file = File(dbPath);
                            if (file.existsSync()) return Image.file(file, fit: BoxFit.cover);
                          } catch (_) {}
                        }
                        return const Center(child: Icon(Icons.local_florist, size: 80, color: Colors.green));
                      },
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(child: Text(plantName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold))),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.grey),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) {
                        return AlertDialog(
                          title: const Text("Đổi tên cây"),
                          content: TextField(controller: _plantNameController, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Nhập tên cây mới")),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
                            ElevatedButton(onPressed: () {
                              _updatePlantNameFromController();
                              Navigator.pop(ctx);
                            }, child: const Text("Lưu")),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              color: Colors.green.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  const Text("Hệ thống theo dõi từ xa", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.green)),
                  const SizedBox(height: 8),
                  Text(_statusFromSoil(soilMoisture, threshold), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 20),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    Column(children: [const Text("🌡️ Nhiệt độ", style: TextStyle(color: Colors.black54)), const SizedBox(height: 5), Text("${temperature?.toStringAsFixed(1) ?? "--"} °C", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]),
                    Column(children: [const Text("💧 Độ ẩm", style: TextStyle(color: Colors.black54)), const SizedBox(height: 5), Text("${humidity?.toStringAsFixed(1) ?? "--"} %", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]),
                  ]),
                  const SizedBox(height: 20),
                  Column(children: [const Text("🌱 Độ ẩm đất", style: TextStyle(color: Colors.black54)), const SizedBox(height: 5), Text("${soilMoisture?.toStringAsFixed(1) ?? "--"} %", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _triggerManualPump, style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48), backgroundColor: Colors.green), child: const Text("💦 Tưới thủ công (3 giây)", style: TextStyle(color: Colors.white))),
            const SizedBox(height: 16),
            SwitchListTile(value: autoMode, onChanged: (v) => _setAutoMode(v), title: const Text("Tưới tự động"), activeThumbColor: Colors.green, activeTrackColor: Colors.greenAccent),
            const SizedBox(height: 8),
            Row(children: [
              const Text("Ngưỡng độ ẩm đất: "),
              Expanded(child: TextField(controller: _thresholdController, keyboardType: TextInputType.number, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "0 - 100"), onSubmitted: (_) => _setThresholdFromController())),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _setThresholdFromController, child: const Text("Cập nhật"))
            ]),
            const SizedBox(height: 8),
            Text("Độ ẩm tự động tưới: $threshold%", style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

class AllNotificationsPage extends StatefulWidget {
  const AllNotificationsPage({super.key});

  @override
  State<AllNotificationsPage> createState() => _AllNotificationsPageState();
}

class _AllNotificationsPageState extends State<AllNotificationsPage> {
  final groupsRef = FirebaseDatabase.instance.ref("groups");
  late final AudioPlayer _audioPlayer;
  int _lastNotificationCount = 0;
  String _filterTreeId = 'all';

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  DateTime _parseDateTime(String date, String time) {
    try {
      return DateFormat("dd/MM/yyyy HH:mm").parse("$date $time");
    } catch (_) {
      try {
        return DateFormat("dd/MM/yyyy").parse(date);
      } catch (_) {
        return DateTime.fromMillisecondsSinceEpoch(0);
      }
    }
  }

  Future<void> _cleanupOldMessages(DatabaseReference ref, String treeId, List<Map<String, dynamic>> items) async {
    final now = DateTime.now();
    for (final item in items) {
      final key = item['key']?.toString() ?? "";
      final DateTime dt = item['dt'] as DateTime;
      if (key.isEmpty) continue;

      final diffDays = now.difference(dt).inDays;
      if (diffDays > 30) {
        try {
          await ref.child(treeId).child("messages").child(key).remove();
          debugPrint("AllNotificationsPage: removed old message $key of $treeId (>$diffDays days)");
        } catch (e) {
          debugPrint("AllNotificationsPage: cleanup error $e");
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: groupsRef.onValue,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Lỗi: ${snapshot.error}"));
        if (!snapshot.hasData || (snapshot.data! as DatabaseEvent).snapshot.value == null) {
          return const Center(child: Text("Chưa có thông báo"));
        }

        final groups = Map<String, dynamic>.from((snapshot.data! as DatabaseEvent).snapshot.value as Map);

        // build dropdown list of trees
        final treeOptions = <Map<String, String>>[];
        groups.forEach((treeId, treeDataRaw) {
          final treeData = Map<String, dynamic>.from(treeDataRaw);
          final plantName = treeData["plantName"]?.toString() ?? treeId;
          treeOptions.add({"id": treeId, "name": plantName});
        });

        List<Map<String, dynamic>> notifications = [];

        // collect notifications
        groups.forEach((treeId, treeDataRaw) {
          final treeData = Map<String, dynamic>.from(treeDataRaw);
          final plantName = treeData["plantName"]?.toString() ?? treeId;
          if (treeData["messages"] != null) {
            final msgs = Map<String, dynamic>.from(treeData["messages"]);
            msgs.forEach((k, v) {
              final n = Map<String, dynamic>.from(v);
              final date = n["date"] ?? "";
              final time = n["time"] ?? "";
              final dt = _parseDateTime(date, time);
              notifications.add({
                "treeId": treeId,
                "plantName": plantName,
                "user": n["user"] ?? "Hệ thống",
                "text": n["text"] ?? "",
                "date": date,
                "time": time,
                "dt": dt,
                "key": k,
              });
            });

            // cleanup từng cây
            Future.microtask(() => _cleanupOldMessages(groupsRef, treeId, notifications.where((n) => n['treeId'] == treeId).toList()));
          }
        });

        if (notifications.isEmpty) return const Center(child: Text("Chưa có thông báo"));

        // sort toàn bộ (mới nhất -> cũ nhất)
        notifications.sort((a, b) => (b["dt"] as DateTime).compareTo(a["dt"] as DateTime));

        // play sound nếu có thông báo mới
        if (_lastNotificationCount != 0 && notifications.length > _lastNotificationCount) {
          try {
            _audioPlayer.play(AssetSource('assets/sounds/notify.mp3'));
          } catch (e) {
            debugPrint("Audio play error: $e");
          }
        }
        _lastNotificationCount = notifications.length;

        // apply filter
        final visibleNotifications = (_filterTreeId == 'all')
            ? notifications
            : notifications.where((n) => n['treeId'] == _filterTreeId).toList();

        // group by ngày
        final today = DateTime.now();
        final yesterday = today.subtract(const Duration(days: 1));
        final df = DateFormat("dd/MM/yyyy");
        final grouped = <String, List<Map<String, dynamic>>>{};
        for (final n in visibleNotifications) {
          final dt = n["dt"] as DateTime;
          String label;
          if (df.format(dt) == df.format(today)) {
            label = "Hôm nay";
          } else if (df.format(dt) == df.format(yesterday)) {
            label = "Hôm qua";
          } else {
            label = df.format(dt);
          }
          grouped.putIfAbsent(label, () => []);
          grouped[label]!.add(n);
        }

        return Column(
          children: [
            // filter row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Text("Lọc cây: "),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: _filterTreeId,
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text("Tất cả cây")),
                        ...treeOptions.map((t) => DropdownMenuItem(value: t['id'], child: Text(t['name']!)))
                      ],
                      onChanged: (v) => setState(() { _filterTreeId = v ?? 'all'; }),
                      decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã làm mới danh sách thông báo")));
                    },
                    child: const Text("Làm mới"),
                  )
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: grouped.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                        ),
                      ),
                      ...entry.value.map((n) {
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => PlantPage(treeId: n['treeId'])));
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(1, 2))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("🌱 ${n["plantName"]}: ${n["text"]}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 4),
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                  Text(n["time"], style: const TextStyle(color: Colors.black45)),
                                  Text(n["user"], style: const TextStyle(color: Colors.black45)),
                                ])
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  );
                }).toList(),
              ),
            )
          ],
        );
      },
    );
  }
}
