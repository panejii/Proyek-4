import 'package:flutter/material.dart';
import 'package:logbook_app_020/features/logbook/log_controller.dart';
import 'package:logbook_app_020/features/auth/login_view.dart';
import 'package:logbook_app_020/features/logbook/models/log_model.dart';

class LogView extends StatefulWidget {
  final String username;
  const LogView({super.key, required this.username});

  @override
  State<LogView> createState() => _LogViewState();
}

class _LogViewState extends State<LogView> {
  final LogController _controller = LogController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  
  String _tempCategory = 'Pribadi';
  final List<String> _categories = ['Pekerjaan', 'Pribadi', 'Urgent'];

  // 1. Warna Latar Belakang Kartu
  Color _getBgColor(String cat) {
    if (cat == 'Urgent') return Colors.red.shade50;
    if (cat == 'Pekerjaan') return Colors.blue.shade50;
    return Colors.green.shade50;
  }

  // 2. Warna Teks Label Prioritas
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

  void _showAddDialog() {
    _titleController.clear();
    _contentController.clear();
    _tempCategory = 'Pribadi';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text("Catatan Baru"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _titleController, decoration: const InputDecoration(hintText: "Judul")),
              TextField(controller: _contentController, decoration: const InputDecoration(hintText: "Deskripsi")),
              const SizedBox(height: 15),
              DropdownButton<String>(
                value: _tempCategory,
                isExpanded: true,
                items: _categories.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) => setDialogState(() => _tempCategory = val!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
            ElevatedButton(
              onPressed: () {
                if (_titleController.text.trim().isEmpty) return;
                _controller.addLog(_titleController.text, _contentController.text, _tempCategory);
                Navigator.pop(ctx);
              },
              child: const Text("Simpan"),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(int index, LogModel log) {
    _titleController.text = log.title;
    _contentController.text = log.description;
    _tempCategory = log.category;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text("Edit Catatan"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _titleController),
              TextField(controller: _contentController),
              const SizedBox(height: 15),
              DropdownButton<String>(
                value: _tempCategory,
                isExpanded: true,
                items: _categories.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) => setDialogState(() => _tempCategory = val!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
            ElevatedButton(
              onPressed: () {
                _controller.updateLog(index, _titleController.text, _contentController.text, _tempCategory);
                Navigator.pop(ctx);
              },
              child: const Text("Update"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Log: ${widget.username}"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout), 
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginView()))
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) => _controller.searchLog(v),
              decoration: InputDecoration(
                hintText: "Cari judul...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<List<LogModel>>(
              valueListenable: _controller.filteredLogs,
              builder: (ctx, list, _) {
                if (list.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_late_outlined, size: 60, color: Colors.grey),
                        Text("Tidak ada catatan ditemukan", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: list.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (ctx, index) {
                    final log = list[index];
                    return Dismissible(
                      key: Key(log.timestamp),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => _controller.removeLog(index),
                      background: Container(
                        color: Colors.red, 
                        alignment: Alignment.centerRight, 
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      child: Card(
                        color: _getBgColor(log.category),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12), 
                          side: BorderSide(color: Colors.grey.shade200)
                        ),
                        child: ListTile(
                          leading: Icon(_getIcon(log.category)),
                          title: Text(log.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Deskripsi (Tampil jika tidak kosong)
                              if (log.description.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(log.description),
                              ],
                              const SizedBox(height: 8),
                              // Label Tingkat Urgensi
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  "Prioritas: ${log.category}",
                                  style: TextStyle(
                                    fontSize: 10, 
                                    fontWeight: FontWeight.bold,
                                    color: _getCategoryTextColor(log.category)
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Timestamp paling bawah
                              Text(log.timestamp, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit_outlined), 
                            onPressed: () => _showEditDialog(index, log)
                          ),
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
      floatingActionButton: FloatingActionButton(onPressed: _showAddDialog, child: const Icon(Icons.add)),
    );
  }
}