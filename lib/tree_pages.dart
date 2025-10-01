import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

/// ---------------- DANH SÁCH CÂY ----------------
class TreeListPage extends StatelessWidget {
  const TreeListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final groupsRef = FirebaseDatabase.instance.ref("groups");

    return Scaffold(
      appBar: AppBar(title: const Text("Danh sách cây")),
      body: StreamBuilder(
        stream: groupsRef.onValue,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
            return const Center(child: Text("Chưa có cây nào"));
          }

          final data = Map<String, dynamic>.from(
            (snapshot.data! as DatabaseEvent).snapshot.value as Map,
          );

          final trees = data.entries.map((e) {
            final treeId = e.key;
            final treeData = Map<String, dynamic>.from(e.value);
            return {
              "id": treeId,
              "name": treeData["plantName"] ?? "Chưa đặt tên",
              "autoMode": treeData["autoMode"] ?? false,
              "threshold": treeData["threshold"] ?? 0,
              "sensor": Map<String, dynamic>.from(treeData["sensor"] ?? {}),
            };
          }).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: trees.length,
            itemBuilder: (_, i) {
              final tree = trees[i];
              final sensor = tree["sensor"];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(tree["name"]),
                  subtitle: Text(
                    "🌡 ${sensor["temperature"]}°C | "
                    "💧 ${sensor["humidity"]}% | "
                    "🌱 ${sensor["soilMoisture"]}%",
                  ),
                  trailing: Icon(
                    tree["autoMode"] ? Icons.autorenew : Icons.handyman,
                    color: tree["autoMode"] ? Colors.green : Colors.orange,
                  ),
                  onTap: () {
                    // 👉 Chuyển sang trang chi tiết cây
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TreeDetailPage(treeId: tree["id"]),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// ---------------- CHI TIẾT CÂY ----------------
class TreeDetailPage extends StatelessWidget {
  final String treeId;
  const TreeDetailPage({super.key, required this.treeId});

  @override
  Widget build(BuildContext context) {
    final treeRef = FirebaseDatabase.instance.ref("groups/$treeId");

    return Scaffold(
      appBar: AppBar(title: Text("Chi tiết $treeId")),
      body: StreamBuilder(
        stream: treeRef.onValue,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
            return const Center(child: Text("Không có dữ liệu"));
          }
          final treeData = Map<String, dynamic>.from(
            (snapshot.data! as DatabaseEvent).snapshot.value as Map,
          );
          final sensor = Map<String, dynamic>.from(treeData["sensor"] ?? {});
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("🌱 Tên cây: ${treeData["plantName"]}",
                    style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 8),
                Text("⚙️ Chế độ tự động: ${treeData["autoMode"] ? "Bật" : "Tắt"}"),
                Text("💧 Ngưỡng tưới: ${treeData["threshold"]}%"),
                const Divider(height: 24),
                Text("🌡 Nhiệt độ: ${sensor["temperature"]}°C"),
                Text("💧 Độ ẩm không khí: ${sensor["humidity"]}%"),
                Text("🌱 Độ ẩm đất: ${sensor["soilMoisture"]}%"),
              ],
            ),
          );
        },
      ),
    );
  }
}
