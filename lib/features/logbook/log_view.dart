import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logbook_app_020/features/logbook/log_controller.dart';
import 'package:logbook_app_020/features/logbook/log_editor_page.dart';
import 'package:logbook_app_020/features/logbook/models/log_model.dart';
import 'package:logbook_app_020/features/auth/login_view.dart';
import 'package:logbook_app_020/services/mongo_service.dart';
import 'package:logbook_app_020/services/access_control_service.dart';

class LogView extends StatefulWidget {
  final Map<String, String> currentUser;
  const LogView({super.key, required this.currentUser});

  @override
  State<LogView> createState() => _LogViewState();
}

class _LogViewState extends State<LogView> {
  late final LogController _controller;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = LogController();
    _initDatabase();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initDatabase() async {
    setState(() => _isLoading = true);
    // Tunggu cek koneksi selesai dulu sebelum loadLogs
    // supaya isOnline sudah benar saat dipakai
    await _controller.waitForConnectivity();
    try {
      if (_controller.isOnline.value) {
        await MongoService().connect();
      }
    } catch (_) {}
    finally {
      await _controller.loadLogs(widget.currentUser['teamId']!);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToEditor({Logbook? log, int? index}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LogEditorPage(
          log: log, index: index,
          controller: _controller,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  // Format ISO string jadi "12 Jun 2025, 14:30"
  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      return DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(dt);
    } catch (_) {
      return isoDate;
    }
  }

  Color _getBgColor(String cat) {
    if (cat == 'Urgent') return Colors.red.shade50;
    if (cat == 'Pekerjaan') return Colors.blue.shade50;
    return Colors.green.shade50;
  }

  Color _getCategoryTextColor(String cat) {
    if (cat == 'Urgent') return Colors.red.shade900;
    if (cat == 'Pekerjaan') return Colors.blue.shade900;
    return Colors.green.shade900;
  }

  IconData _getIcon(String cat) {
    if (cat == 'Urgent') return Icons.warning_amber_rounded;
    if (cat == 'Pekerjaan') return Icons.business_center_outlined;
    return Icons.person_outline;
  }

  @override
  Widget build(BuildContext context) {
    final currentRole = widget.currentUser['role']!;
    final currentUid = widget.currentUser['uid']!;

    return ValueListenableBuilder<bool>(
      valueListenable: _controller.isOnline,
      builder: (context, online, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text("Logbook: ${widget.currentUser['username']}"),
            // Ikon status koneksi di AppBar
            leading: Padding(
              padding: const EdgeInsets.only(left: 10),
              child: online
                  ? const Icon(Icons.wifi, color: Colors.green)
                  : Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.wifi_off, color: Colors.white, size: 20),
                    ),
            ),
            actions: [
              // Refresh hanya berguna saat online
              if (online)
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => _controller.loadLogs(widget.currentUser['teamId']!),
                  tooltip: "Sync dari Cloud",
                ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text("Konfirmasi Logout"),
                    content: const Text("Apakah Anda yakin ingin keluar?"),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const LoginView()),
                            (route) => false,
                          );
                        },
                        child: const Text("Ya, Keluar", style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              // --- Banner Offline ---
              if (!online)
                Container(
                  width: double.infinity,
                  color: Colors.orange.shade100,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off, color: Colors.orange, size: 18),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          "Mode Offline — Catatan baru disimpan lokal & akan otomatis sync saat online",
                          style: TextStyle(fontSize: 12, color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),

              // --- Info role & tim ---
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    Icon(
                      currentRole == 'Ketua' ? Icons.admin_panel_settings : Icons.person,
                      size: 15,
                      color: currentRole == 'Ketua' ? Colors.orange : Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "$currentRole · Tim: ${widget.currentUser['teamId']}",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),

              // --- Search bar ---
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  onChanged: (v) => _controller.searchLog(v),
                  decoration: InputDecoration(
                    hintText: "Cari judul...",
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                  ),
                ),
              ),

              // --- List ---
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text("Memuat data..."),
                          ],
                        ),
                      )
                    : ValueListenableBuilder<List<Logbook>>(
                        valueListenable: _controller.filteredLogs,
                        builder: (context, list, _) {
                          if (list.isEmpty) {
                            if (!online) {
                              // Tampilan khusus offline + data kosong
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade50,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.cloud_off, size: 64, color: Colors.orange.shade400),
                                    ),
                                    const SizedBox(height: 20),
                                    const Text(
                                      "Tidak ada koneksi",
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "Belum ada catatan tersimpan lokal.\nCatatan baru akan disimpan di perangkat\ndan otomatis sync saat online.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.5),
                                    ),
                                    const SizedBox(height: 24),
                                    ElevatedButton.icon(
                                      onPressed: () => _goToEditor(),
                                      icon: const Icon(Icons.edit_note),
                                      label: const Text("Tulis Catatan Offline"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange.shade400,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            // Tampilan normal online + data kosong
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.note_alt_outlined, size: 64, color: Colors.blue.shade300),
                                  ),
                                  const SizedBox(height: 20),
                                  const Text(
                                    "Belum ada catatan",
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Mulai catat aktivitas dan progres\nproyek timmu di sini.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.5),
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton.icon(
                                    onPressed: () => _goToEditor(),
                                    icon: const Icon(Icons.add),
                                    label: const Text("Buat Catatan Pertama"),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            itemCount: list.length,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemBuilder: (context, index) {
                              final log = list[index];
                              final bool isOwner = log.authorId == currentUid;

                              // Tentukan ikon & warna cloud berdasarkan status sync dan koneksi
                              final IconData cloudIcon;
                              final Color cloudColor;
                              final String cloudTooltip;

                              if (!online) {
                                cloudIcon = Icons.cloud_off;
                                cloudColor = Colors.grey;
                                cloudTooltip = "Sedang offline";
                              } else if (log.isSynced) {
                                cloudIcon = Icons.cloud_done;
                                cloudColor = Colors.green;
                                cloudTooltip = "Tersimpan di Atlas";
                              } else {
                                cloudIcon = Icons.cloud_upload_outlined;
                                cloudColor = Colors.orange;
                                cloudTooltip = "Pending — belum tersinkron";
                              }

                              return Card(
                                color: _getBgColor(log.category),
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: ListTile(
                                  leading: Tooltip(
                                    message: cloudTooltip,
                                    child: Icon(cloudIcon, color: cloudColor),
                                  ),
                                  title: Text(
                                    log.title,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (log.description.isNotEmpty)
                                        Text(
                                          log.description,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      const SizedBox(height: 4),
                                      // Badge kategori
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _getCategoryTextColor(log.category).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          log.category,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: _getCategoryTextColor(log.category),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      // Tanggal di baris sendiri — tidak rebutan ruang dengan trailing
                                      Text(
                                        _formatDate(log.date),
                                        style: const TextStyle(fontSize: 11, color: Colors.black45),
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (AccessControlService.canPerform(
                                        currentRole, AccessControlService.actionUpdate,
                                        isOwner: isOwner,
                                      ))
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.blue),
                                          onPressed: () => _goToEditor(log: log, index: index),
                                        ),
                                      if (AccessControlService.canPerform(
                                        currentRole, AccessControlService.actionDelete,
                                        isOwner: isOwner,
                                      ))
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          onPressed: () => _controller.removeLog(log),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _goToEditor(),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}