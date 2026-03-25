import 'package:flutter/material.dart';
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

  Future<void> _initDatabase() async {
    setState(() => _isLoading = true);
    try {
      await MongoService().connect();
    } catch (_) {
      // Jika gagal konek, tetap lanjut (akan pakai data Hive lokal)
    } finally {
      await _controller.loadLogs(widget.currentUser['teamId']!);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Navigasi ke halaman editor (gantikan dialog lama)
  void _goToEditor({Logbook? log, int? index}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LogEditorPage(
          log: log,
          index: index,
          controller: _controller,
          currentUser: widget.currentUser,
        ),
      ),
    );
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

    return Scaffold(
      appBar: AppBar(
        title: Text("Logbook: ${widget.currentUser['username']} (${widget.currentUser['role']})"),
        actions: [
          // Tombol refresh
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.loadLogs(widget.currentUser['teamId']!),
            tooltip: "Sync dari Cloud",
          ),
          // Tombol logout
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Konfirmasi Logout"),
                  content: const Text("Apakah Anda yakin ingin keluar?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Batal"),
                    ),
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
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (v) => _controller.searchLog(v),
              decoration: InputDecoration(
                hintText: "Cari judul...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          // Indikator role
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Icon(
                  currentRole == 'Ketua' ? Icons.admin_panel_settings : Icons.person,
                  size: 16,
                  color: currentRole == 'Ketua' ? Colors.orange : Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  "Login sebagai: $currentRole · Tim: ${widget.currentUser['teamId']}",
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),

          // List logs
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
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.note_alt_outlined, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              const Text("Belum ada catatan."),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: () => _goToEditor(),
                                child: const Text("Buat Catatan Pertama"),
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

                          return Card(
                            color: _getBgColor(log.category),
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              // Ikon: cloud_done jika punya ID (sudah sync), cloud_upload jika belum
                              leading: Icon(
                                log.id != null ? Icons.cloud_done : Icons.cloud_upload_outlined,
                                color: log.id != null ? Colors.green : Colors.orange,
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
                                  Text(
                                    "Kategori: ${log.category}",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _getCategoryTextColor(log.category),
                                    ),
                                  ),
                                  Text(
                                    log.date,
                                    style: const TextStyle(fontSize: 10, color: Colors.black54),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // GATEKEEPER: Tombol Edit
                                  if (AccessControlService.canPerform(
                                    currentRole,
                                    AccessControlService.actionUpdate,
                                    isOwner: isOwner,
                                  ))
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () => _goToEditor(log: log, index: index),
                                    ),

                                  // GATEKEEPER: Tombol Delete
                                  if (AccessControlService.canPerform(
                                    currentRole,
                                    AccessControlService.actionDelete,
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
  }
}