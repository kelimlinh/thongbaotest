// lib/notifications_page.dart
// ignore: unused_import
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class NotificationsPage extends StatelessWidget {
  final String treeId;
  const NotificationsPage({super.key, required this.treeId});

  @override
  Widget build(BuildContext context) {
    final messagesRef = FirebaseDatabase.instance.ref("groups/$treeId/messages");

    return Scaffold(
      appBar: AppBar(
        title: Text("🔔 Thông báo ($treeId)"),
        centerTitle: true,
      ),
      body: StreamBuilder(
        stream: messagesRef.onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
            return const Center(child: Text("Chưa có thông báo nào"));
          }

          final data = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);

          // build list with parsed DateTime (take both date + time when có)
          final rawEntries = data.entries.map((e) {
            final m = Map<String, dynamic>.from(e.value);
            final dateStr = m['date']?.toString() ?? "";
            final timeStr = m['time']?.toString() ?? "";
            DateTime dt;
            try {
              dt = DateFormat("dd/MM/yyyy HH:mm").parse("$dateStr $timeStr");
            } catch (_) {
              try {
                dt = DateFormat("dd/MM/yyyy").parse(dateStr);
              } catch (_) {
                dt = DateTime.fromMillisecondsSinceEpoch(0);
              }
            }
            return {'key': e.key, 'data': m, 'dt': dt};
          }).toList();

          // sort newest -> oldest
          rawEntries.sort((a, b) => (b['dt'] as DateTime).compareTo(a['dt'] as DateTime));

          // cleanup (run async, don't block build)
          Future.microtask(() => _cleanupOldMessages(messagesRef, rawEntries));

          // group by date label
          final grouped = _groupByDate(rawEntries);

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: grouped.length,
            itemBuilder: (context, index) {
              final group = grouped[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    child: Text(
                      group['label'],
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  ...List<Widget>.from(group['items'].map<Widget>((msg) {
                    return _buildNotificationItem(msg, messagesRef);
                  })),
                ],
              );
            },
          );
        },
      ),
    );
  }

  /// Gom nhóm theo ngày (giữ thứ tự đã sort: mới -> cũ)
  List<Map<String, dynamic>> _groupByDate(List<Map<String, dynamic>> rawEntries) {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final DateFormat df = DateFormat("dd/MM/yyyy");

    final Map<String, List<Map<String, dynamic>>> groups = {};
    final List<String> order = [];

    for (final item in rawEntries) {
      final DateTime dt = item['dt'] as DateTime;
      final m = Map<String, dynamic>.from(item['data'] as Map);
      String label;
      if (df.format(dt) == df.format(today)) {
        label = "Hôm nay";
      } else if (df.format(dt) == df.format(yesterday)) {
        label = "Hôm qua";
      } else {
        label = df.format(dt);
      }

      if (!groups.containsKey(label)) {
        groups[label] = [];
        order.add(label);
      }

      groups[label]!.add({
        'key': item['key'],
        'text': m['text'] ?? "",
        'date': m['date'] ?? "",
        'time': m['time'] ?? "",
        'backedUp': m['backedUp'] ?? false,
        'raw': m,
      });
    }

    return order.map((label) => {'label': label, 'items': groups[label]!}).toList();
  }

  /// Hiển thị 1 item (card)
  Widget _buildNotificationItem(Map<String, dynamic> msg, DatabaseReference messagesRef) {
    final text = msg['text']?.toString() ?? "";
    final time = msg['time']?.toString() ?? "";

    IconData icon = Icons.notifications;
    Color color = Colors.grey.shade700;

    if (text.contains("💦") || text.toLowerCase().contains("tưới")) {
      icon = Icons.opacity;
      color = Colors.blueAccent;
    } else if (text.contains("✏️") || text.toLowerCase().contains("đổi tên")) {
      icon = Icons.edit;
      color = Colors.orange;
    } else if (text.contains("⚙️") || text.toLowerCase().contains("ngưỡng")) {
      icon = Icons.settings;
      color = Colors.teal;
    } else if (text.contains("🖼️") || text.toLowerCase().contains("ảnh")) {
      icon = Icons.photo;
      color = Colors.purple;
    } else if (text.toLowerCase().contains("khởi tạo")) {
      icon = Icons.playlist_add_check;
      color = Colors.green;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.5),
          child: Icon(icon, color: color),
        ),
        title: Text(
          text,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: color),
        ),
        subtitle: Text(time, style: const TextStyle(fontSize: 13, color: Colors.black54)),
        onTap: () {
          // Tùy bạn: khi bấm vào có thể mở PlantPage hoặc chi tiết — hiện để debug/expand
        },
      ),
    );
  }

  /// Cleanup: 
  /// - Nếu older than 30 days => xóa khỏi Realtime DB
  /// - Nếu older than 7 days and not yet backed up => upload file JSON lên Firebase Storage & đánh dấu {backedUp: true, backupUrl: ...}
  Future<void> _cleanupOldMessages(DatabaseReference ref, List<Map<String, dynamic>> rawEntries) async {
    final now = DateTime.now();
    for (final item in rawEntries) {
      final key = item['key']?.toString() ?? "";
      final Map<String, dynamic> msg = Map<String, dynamic>.from(item['raw'] ?? {});
      final DateTime dt = item['dt'] as DateTime;

      // nếu key rỗng bỏ qua
      if (key.isEmpty) continue;

      final diffDays = now.difference(dt).inDays;

      try {
        // quá 30 ngày => xóa luôn
        if (diffDays > 30) {
          await ref.child(key).remove();
          debugPrint("NotificationsPage: removed old message $key (>$diffDays days)");
          continue;
        }

        // từ >7 đến <=30 ngày => nếu chưa backup thì upload & đánh dấu
        if (diffDays > 7 && diffDays <= 30) {
          final already = msg['backedUp'] == true;
          if (already) continue;

          try {
            final backupRef = FirebaseFirestore.instance
              .collection("notifications_backup")
              .doc(treeId)
              .collection("messages")
              .doc(key);

            // upload trực tiếp object JSON vào Firestore
            await backupRef.set(msg);

            // đánh dấu trong Realtime DB để tránh upload lại
            await ref.child(key).child('backedUp').set(true);
            await ref.child(key).child('backupDocId').set(key);

            debugPrint("NotificationsPage: backed up message $key -> Firestore doc saved");
          } catch (e) {
            debugPrint("NotificationsPage: backup error for $key: $e");
            // nếu upload lỗi thì không xóa; lần sau sẽ thử lại
          }
        }
      } catch (e) {
        debugPrint("NotificationsPage: cleanup loop error for $key: $e");
      }
    }
  }
}
