import 'package:flutter/material.dart';

import '../../models/genre.dart';
import '../../services/api_service.dart';

class GenresManagementScreen extends StatefulWidget {
  const GenresManagementScreen({super.key});

  @override
  State<GenresManagementScreen> createState() => _GenresManagementScreenState();
}

class _GenresManagementScreenState extends State<GenresManagementScreen> {
  List<Genre> _genres = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final genres = await ApiService.getGenres();
      setState(() {
        _genres = genres..sort((a, b) => a.name.compareTo(b.name));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _openDialog({Genre? genre}) {
    final controller = TextEditingController(text: genre?.name ?? '');
    String? validationError;

    double dialogWidth(BuildContext context) {
      final w = MediaQuery.of(context).size.width;
      return w >= 900 ? 640 : (w * 0.92).clamp(320.0, 640.0);
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(genre == null ? 'Novi žanr' : 'Uredi žanr'),
          content: SizedBox(
            width: dialogWidth(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (validationError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            validationError!,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Naziv *',
                    border: OutlineInputBorder(),
                    helperText: 'Obavezno. Maksimalno 100 karaktera.',
                  ),
                  onChanged: (_) {
                    if (validationError != null) {
                      setDialogState(() => validationError = null);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Odustani'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) {
                  setDialogState(() => validationError = 'Naziv žanra je obavezan.');
                  return;
                }
                if (name.length > 100) {
                  setDialogState(() => validationError = 'Naziv ne može biti duži od 100 karaktera.');
                  return;
                }

                try {
                  final data = {'name': name};
                  if (genre == null) {
                    await ApiService.createGenre(data);
                  } else {
                    await ApiService.updateGenre(genre.id, data);
                  }
                  if (!mounted) return;
                  Navigator.pop(context);
                  await _load();
                } catch (e) {
                  setDialogState(() => validationError = e.toString());
                }
              },
              child: Text(genre == null ? 'Kreiraj' : 'Sačuvaj'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Genre genre) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Brisanje žanra'),
        content: Text('Da li ste sigurni da želite obrisati žanr "${genre.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Odustani'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await ApiService.deleteGenre(genre.id);
                if (!mounted) return;
                Navigator.pop(context);
                await _load();
              } catch (e) {
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Greška: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Obriši'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Žanrovi'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(icon: const Icon(Icons.add), onPressed: () => _openDialog()),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Greška: $_error'))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _genres.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final g = _genres[index];
                    return ListTile(
                      title: Text(g.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Uredi',
                            icon: const Icon(Icons.edit),
                            onPressed: () => _openDialog(genre: g),
                          ),
                          IconButton(
                            tooltip: 'Obriši',
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmDelete(g),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

