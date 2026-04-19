import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logbook_app_020/features/logbook/log_controller.dart';
import 'package:logbook_app_020/features/logbook/log_editor_page.dart';
import 'package:logbook_app_020/features/logbook/models/log_model.dart';
import 'package:logbook_app_020/features/auth/login_view.dart';
import 'package:logbook_app_020/services/mongo_service.dart';
import 'package:logbook_app_020/services/access_control_service.dart';
import 'package:logbook_app_020/features/vision/vision_view.dart'; // ← Modul 6
import 'package:logbook_app_020/features/pcd/pcd_view.dart';       // ← PCD

class LogView extends StatefulWidget {
  final Map<String, String> currentUser;
  const LogView({super.key, required this.currentUser});

  @override
  State<LogView> createState() => _LogViewState();
}

class _LogViewState extends State<LogView> {
  late final LogController _controller;
  bool _isLoading = false;
  bool _isRefreshing = false;

  // Speed-dial FAB state
  bool _isFabExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = LogController();
    _initDatabase();
    _controller.isOnline.addListener(_onConnectivityChanged);
  }

  bool? _lastOnlineStatus;

  void _onConnectivityChanged() {
    final online = _controller.isOnline.value;
    if (_lastOnlineStatus == online) return;
    _lastOnlineStatus = online;
    if (!mounted) return;

    if (!online) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            Icon(Icons.wifi_off, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Koneksi terputus — beralih ke mode offline'),
          ]),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            Icon(Icons.wifi, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Koneksi pulih — data sedang disinkronkan'),
          ]),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.isOnline.removeListener(_onConnectivityChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initDatabase() async {
    setState(() => _isLoading = true);
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

  Future<void> _refreshLogs() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await _controller.loadLogs(widget.currentUser['teamId']!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [
              Icon(Icons.cloud_done, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Data berhasil diperbarui dari cloud'),
            ]),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal memperbarui data'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

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
            leading: ValueListenableBuilder<bool>(
              valueListenable: _controller.isOnline,
              builder: (context, online, _) {
                return Tooltip(
                  message: online ? 'Online' : 'Offline',
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
                    decoration: BoxDecoration(
                      color: online
                          ? Colors.green.withOpacity(0.15)
                          : Colors.red.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      online ? Icons.wifi : Icons.wifi_off,
                      color: online ? Colors.green : Colors.white,
                      size: 20,
                    ),
                  ),
                );
              },
            ),
            actions: [
              if (online)
                _isRefreshing
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _refreshLogs,
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
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Batal")),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const LoginView()),
                            (route) => false,
                          );
                        },
                        child: const Text("Ya, Keluar",
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ─── Tap luar FAB untuk collapse ───
          body: GestureDetector(
            onTap: () {
              if (_isFabExpanded) setState(() => _isFabExpanded = false);
            },
            child: Column(
              children: [
                // Banner Offline
                if (!online)
                  Container(
                    width: double.infinity,
                    color: Colors.orange.shade100,
                    padding: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_off,
                            color: Colors.orange, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            "Mode Offline — Catatan baru disimpan lokal & akan otomatis sync saat online",
                            style: TextStyle(
                                fontSize: 12, color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Info role & tim
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    children: [
                      Icon(
                        currentRole == 'Ketua'
                            ? Icons.admin_panel_settings
                            : Icons.person,
                        size: 15,
                        color: currentRole == 'Ketua'
                            ? Colors.orange
                            : Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "$currentRole · Tim: ${widget.currentUser['teamId']}",
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),

                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: TextField(
                    onChanged: (v) => _controller.searchLog(v),
                    decoration: InputDecoration(
                      hintText: "Cari judul...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                  ),
                ),

                // List
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
                                return Center(
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(24),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade50,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.cloud_off,
                                            size: 64,
                                            color: Colors.orange.shade400),
                                      ),
                                      const SizedBox(height: 20),
                                      const Text("Tidak ada koneksi",
                                          style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      Text(
                                        "Belum ada catatan tersimpan lokal.\nCatatan baru akan disimpan di perangkat\ndan otomatis sync saat online.",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                            height: 1.5),
                                      ),
                                      const SizedBox(height: 24),
                                      ElevatedButton.icon(
                                        onPressed: () => _goToEditor(),
                                        icon: const Icon(Icons.edit_note),
                                        label: const Text(
                                            "Tulis Catatan Offline"),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Colors.orange.shade400,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return Center(
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.note_alt_outlined,
                                          size: 64,
                                          color: Colors.blue.shade300),
                                    ),
                                    const SizedBox(height: 20),
                                    const Text("Belum ada catatan",
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    Text(
                                      "Mulai catat aktivitas dan progres\nproyek timmu di sini.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade600,
                                          height: 1.5),
                                    ),
                                    const SizedBox(height: 24),
                                    ElevatedButton.icon(
                                      onPressed: () => _goToEditor(),
                                      icon: const Icon(Icons.add),
                                      label: const Text(
                                          "Buat Catatan Pertama"),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return ListView.builder(
                              itemCount: list.length,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16),
                              itemBuilder: (context, index) {
                                final log = list[index];
                                final bool isOwner =
                                    log.authorId == currentUid;

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
                                  cloudTooltip =
                                      "Pending — belum tersinkron";
                                }

                                return Card(
                                  color: _getBgColor(log.category),
                                  margin: const EdgeInsets.symmetric(
                                      vertical: 6),
                                  child: ListTile(
                                    leading: Tooltip(
                                      message: cloudTooltip,
                                      child: Icon(cloudIcon,
                                          color: cloudColor),
                                    ),
                                    title: Text(
                                      log.title,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (log.description.isNotEmpty)
                                          Text(
                                            log.description,
                                            maxLines: 1,
                                            overflow:
                                                TextOverflow.ellipsis,
                                          ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2),
                                          decoration: BoxDecoration(
                                            color:
                                                _getCategoryTextColor(
                                                        log.category)
                                                    .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            log.category,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: _getCategoryTextColor(
                                                  log.category),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _formatDate(log.date),
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.black45),
                                        ),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (AccessControlService.canPerform(
                                          currentRole,
                                          AccessControlService.actionUpdate,
                                          isOwner: isOwner,
                                        ))
                                          IconButton(
                                            icon: const Icon(Icons.edit,
                                                color: Colors.blue),
                                            onPressed: () => _goToEditor(
                                                log: log, index: index),
                                          ),
                                        if (AccessControlService.canPerform(
                                          currentRole,
                                          AccessControlService.actionDelete,
                                          isOwner: isOwner,
                                        ))
                                          IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: Colors.red),
                                            onPressed: () =>
                                                _controller.removeLog(log),
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
          ),

          // ─── Speed-Dial FAB ───────────────────────────────────────────
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [

              if (_isFabExpanded)
                _SpeedDialItem(
                  icon: Icons.image_search,
                  label: "PCD Operation",
                  color: Colors.deepPurple,
                  onTap: () {
                    setState(() => _isFabExpanded = false);

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PcdView(),
                      ),
                    );
                  },
                ),

              if (_isFabExpanded) const SizedBox(height: 10),

              if (_isFabExpanded)
                _SpeedDialItem(
                  icon: Icons.psychology,
                  label: "AI Detection",
                  color: Colors.green,
                  onTap: () {
                    setState(() => _isFabExpanded = false);

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const VisionView(),
                      ),
                    );
                  },
                ),

              const SizedBox(height: 10),

              FloatingActionButton(
                heroTag: 'camera_fab',
                onPressed: () {
                  setState(() => _isFabExpanded = !_isFabExpanded);
                },
                tooltip: 'Vision Tools',
                child: AnimatedRotation(
                  turns: _isFabExpanded ? 0.125 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.camera_alt),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Speed Dial Item Widget ─────────────────────────────────────────────────
class _SpeedDialItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SpeedDialItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label chip
        Material(
          elevation: 2,
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                label,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: color),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Mini FAB
        FloatingActionButton.small(
          heroTag: label,
          onPressed: onTap,
          backgroundColor: color,
          child: Icon(icon, color: Colors.white),
        ),
      ],
    );
  }
}