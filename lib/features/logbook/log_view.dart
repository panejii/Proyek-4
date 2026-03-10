import 'package:flutter/material.dart';
import 'package:logbook_app_020/features/logbook/log_controller.dart';
import 'package:logbook_app_020/features/auth/login_view.dart';
import 'package:logbook_app_020/features/logbook/models/log_model.dart';
import 'package:logbook_app_020/services/mongo_service.dart';
import 'package:logbook_app_020/helpers/log_helper.dart';

class LogView extends StatefulWidget {
  final String username;

  const LogView({super.key, required this.username});

  @override
  State<LogView> createState() => _LogViewState();
}

class _LogViewState extends State<LogView> {

  late LogController _controller;

  bool _isLoading = false;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  String _tempCategory = 'Pribadi';

  final List<String> _categories = [
    'Pekerjaan',
    'Pribadi',
    'Urgent'
  ];

  @override
  void initState() {
    super.initState();
    _controller = LogController();
    
    // Tambahkan listener manual untuk memaksa rebuild jika diperlukan
    _controller.filteredLogs.addListener(() {
      if (mounted) setState(() {});
    });

    Future.microtask(() => _initDatabase());
  }

  Future<void> _initDatabase() async {

    setState(() => _isLoading = true);

    try {

      await MongoService().connect();

      await _controller.loadFromMongo();

    } catch (e) {

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }

    } finally {

      if (mounted) {
        setState(() => _isLoading = false);
      }

    }
  }

  Color _getBgColor(String cat) {

    if (cat == 'Urgent') {
      return Colors.red.shade50;
    }

    if (cat == 'Pekerjaan') {
      return Colors.blue.shade50;
    }

    return Colors.green.shade50;
  }

  Color _getCategoryTextColor(String cat) {

    if (cat == 'Urgent') {
      return Colors.red.shade900;
    }

    if (cat == 'Pekerjaan') {
      return Colors.blue.shade900;
    }

    return Colors.green.shade900;
  }

  IconData _getIcon(String cat) {

    if (cat == 'Urgent') {
      return Icons.warning_amber_rounded;
    }

    if (cat == 'Pekerjaan') {
      return Icons.business_center_outlined;
    }

    return Icons.person_outline;
  }

  void _showAddDialog() {

    _titleController.clear();
    _contentController.clear();

    _tempCategory = 'Pribadi';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {

          return AlertDialog(

            title: const Text("Catatan Baru"),

            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    hintText: "Judul",
                  ),
                ),

                TextField(
                  controller: _contentController,
                  decoration: const InputDecoration(
                    hintText: "Deskripsi",
                  ),
                ),

                const SizedBox(height: 15),

                DropdownButton<String>(
                  value: _tempCategory,
                  isExpanded: true,
                  items: _categories
                      .map((e) => DropdownMenuItem(
                            value: e,
                            child: Text(e),
                          ))
                      .toList(),
                  onChanged: (val) =>
                      setDialogState(() => _tempCategory = val!),
                ),
              ],
            ),

            actions: [

              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Batal"),
              ),

              ElevatedButton(
                onPressed: () {

                  if (_titleController.text.trim().isEmpty) return;

                  _controller.addLog(
                    _titleController.text,
                    _contentController.text,
                    _tempCategory,
                  );

                  Navigator.pop(ctx);
                },
                child: const Text("Simpan"),
              )
            ],
          );
        },
      ),
    );
  }

  void _showEditDialog(int index, Logbook log) {

    _titleController.text = log.title;
    _contentController.text = log.description;
    _tempCategory = log.category;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {

          return AlertDialog(

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
                  items: _categories
                      .map((e) => DropdownMenuItem(
                            value: e,
                            child: Text(e),
                          ))
                      .toList(),
                  onChanged: (val) =>
                      setDialogState(() => _tempCategory = val!),
                ),
              ],
            ),

            actions: [

              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Batal"),
              ),

              ElevatedButton(
                onPressed: () {

                  _controller.updateLog(
                    index,  
                    _titleController.text,
                    _contentController.text,
                    _tempCategory,
                  );

                  Navigator.pop(ctx);
                },
                child: const Text("Update"),
              )
            ],
          );
        },
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
            onPressed: () {

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const LoginView(),
                ),
              );
            },
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          Expanded(

            child: ValueListenableBuilder<List<Logbook>>(

              valueListenable: _controller.filteredLogs,

              builder: (context, list, child) {

                if (_isLoading) {

                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text("Menghubungkan ke MongoDB Atlas..."),
                      ],
                    ),
                  );
                }

                if (list.isEmpty) {

                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [

                        const Icon(
                          Icons.cloud_off,
                          size: 64,
                          color: Colors.grey,
                        ),

                        const SizedBox(height: 16),

                        const Text(
                          "Belum ada catatan di Cloud.",
                        ),

                        const SizedBox(height: 10),

                        ElevatedButton(
                          onPressed: _showAddDialog,
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

                    return Card(

                      color: _getBgColor(log.category),

                      child: ListTile(

                        leading: Icon(
                          _getIcon(log.category),
                        ),

                        title: Text(
                          log.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            if (log.description.isNotEmpty)
                              Text(log.description),

                            const SizedBox(height: 6),

                            Text(
                              "Prioritas: ${log.category}",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _getCategoryTextColor(log.category),
                              ),
                            ),

                            const SizedBox(height: 4),

                            Text(
                              log.date.toString(),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),

                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [

                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () =>
                                  _showEditDialog(index, log),
                            ),

                            IconButton(
                              icon: const Icon(Icons.delete),
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

      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}