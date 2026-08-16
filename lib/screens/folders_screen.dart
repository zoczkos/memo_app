import 'package:flutter/material.dart';

import '../database_helper.dart';
import '../models/folder.dart';
import 'folder_action_screen.dart';
import 'help_screen.dart';

class FoldersScreen extends StatefulWidget {
  const FoldersScreen({super.key});

  @override
  State<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends State<FoldersScreen> {
  List<Folder> _folders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    try {
      final data = await DatabaseHelper.instance.getFolders();
      if (!mounted) return;
      setState(() {
        _folders = data;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _folders = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _showFolderDialog({Folder? folder}) async {
    final controller = TextEditingController(text: folder?.name ?? '');
    final isEdit = folder != null;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isEdit ? 'Rename folder' : 'New folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Folder name (e.g. English B2)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;

              if (isEdit) {
                await DatabaseHelper.instance.updateFolder(
                  folder.copyWith(name: name),
                );
              } else {
                await DatabaseHelper.instance.insertFolder(name);
              }
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: Text(isEdit ? 'Save' : 'Add'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (saved == true) _loadFolders();
  }

  Future<void> _confirmDeleteFolder(Folder folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete folder'),
        content: Text(
          'Delete “${folder.name}” and all its words? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseHelper.instance.deleteFolder(folder.id);
      _loadFolders();
    }
  }

  void _showFolderActions(Folder folder) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Rename'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showFolderDialog(folder: folder);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red[600]),
                title: Text(
                  'Delete folder',
                  style: TextStyle(color: Colors.red[600]),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDeleteFolder(folder);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vocamio'),
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Help',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HelpScreen()),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFolderDialog(),
        tooltip: 'Add folder',
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _folders.isEmpty
          ? const Center(
              child: Text(
                'No folders yet. Tap + to create one.',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _folders.length,
              itemBuilder: (context, index) {
                final folder = _folders[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  elevation: 1,
                  child: ListTile(
                    leading: const Icon(
                      Icons.folder,
                      color: Colors.blue,
                      size: 36,
                    ),
                    title: Text(
                      folder.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.more_vert),
                      tooltip: 'Folder options',
                      onPressed: () => _showFolderActions(folder),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FolderActionScreen(folder: folder),
                        ),
                      ).then((_) => _loadFolders());
                    },
                    onLongPress: () => _showFolderActions(folder),
                  ),
                );
              },
            ),
    );
  }
}
