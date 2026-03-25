import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:logbook_app_020/features/logbook/models/log_model.dart';
import 'package:logbook_app_020/features/logbook/log_controller.dart';

class LogEditorPage extends StatefulWidget {
  final Logbook? log;
  final int? index;
  final LogController controller;
  final Map<String, String> currentUser;

  const LogEditorPage({
    super.key,
    this.log,
    this.index,
    required this.controller,
    required this.currentUser,
  });

  @override
  State<LogEditorPage> createState() => _LogEditorPageState();
}

class _LogEditorPageState extends State<LogEditorPage> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late String _selectedCategory;

  final List<String> _categories = ['Pekerjaan', 'Pribadi', 'Urgent'];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.log?.title ?? '');
    _descController = TextEditingController(text: widget.log?.description ?? '');
    _selectedCategory = widget.log?.category ?? 'Pribadi';

    // Listener agar tab Pratinjau terupdate otomatis saat mengetik
    _descController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Judul tidak boleh kosong")),
      );
      return;
    }

    if (widget.log == null) {
      // Tambah baru
      await widget.controller.addLog(
        _titleController.text.trim(),
        _descController.text,
        _selectedCategory,
        widget.currentUser['uid']!,
        widget.currentUser['teamId']!,
      );
    } else {
      // Update
      await widget.controller.updateLog(
        widget.index!,
        _titleController.text.trim(),
        _descController.text,
        _selectedCategory,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Catatan berhasil disimpan")),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.log == null ? "Catatan Baru" : "Edit Catatan"),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Editor"),
              Tab(text: "Pratinjau"),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _save,
              tooltip: "Simpan",
            ),
          ],
        ),
        body: TabBarView(
          children: [
            // Tab 1: Editor
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: "Judul",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: "Kategori",
                      border: OutlineInputBorder(),
                    ),
                    items: _categories
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedCategory = val!),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TextField(
                      controller: _descController,
                      maxLines: null,
                      expands: true,
                      keyboardType: TextInputType.multiline,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        hintText: "Tulis laporan dengan format Markdown...\n\n# Header\n**Bold** _italic_\n- List item\n`kode`",
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Tab 2: Markdown Preview
            _descController.text.isEmpty
                ? const Center(
                    child: Text(
                      "Mulai menulis di tab Editor\nuntuk melihat pratinjau di sini.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : Markdown(
                    data: _descController.text,
                    padding: const EdgeInsets.all(16),
                  ),
          ],
        ),
      ),
    );
  }
}