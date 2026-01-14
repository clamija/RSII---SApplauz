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
  String? _errorMessage;

  String _err(Object e) => e
      .toString()
      .replaceFirst(RegExp(r'^Exception:\s*'), '')
      .trim();

  @override
  void initState() {
    super.initState();
    _loadGenres();
  }

  Future<void> _loadGenres() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final genres = await ApiService.getGenres();
      setState(() {
        _genres = genres;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteGenre(Genre genre) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Brisanje žanra'),
        content: Text('Da li ste sigurni da želite obrisati žanr "${genre.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Otkaži'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Obriši'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.deleteGenre(genre.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Žanr je uspješno obrisan')),
          );
          _loadGenres();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_err(e))),
          );
        }
      }
    }
  }

  void _showAddEditDialog({Genre? genre}) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: genre?.name ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(genre == null ? 'Dodaj žanr' : 'Uredi žanr'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Naziv žanra *',
              border: OutlineInputBorder(),
            ),
            validator: (value) => value?.isEmpty ?? true ? 'Molimo unesite naziv žanra' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Otkaži'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  final data = {
                    'name': nameController.text.trim(),
                  };

                  if (genre == null) {
                    await ApiService.createGenre(data);
                  } else {
                    await ApiService.updateGenre(genre.id, data);
                  }

                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          genre == null 
                              ? 'Žanr je uspješno dodan' 
                              : 'Žanr je uspješno ažuriran',
                        ),
                      ),
                    );
                    _loadGenres();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Greška: ${e.toString()}')),
                    );
                  }
                }
              }
            },
            child: Text(genre == null ? 'Dodaj' : 'Sačuvaj'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upravljanje Žanrovima'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Greška: $_errorMessage'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadGenres,
                        child: const Text('Pokušaj ponovo'),
                      ),
                    ],
                  ),
                )
              : _genres.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.category, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            'Nema žanrova',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _showAddEditDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text('Dodaj žanr'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadGenres,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _genres.length,
                        itemBuilder: (context, index) {
                          final genre = _genres[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.category),
                              ),
                              title: Text(
                                genre.name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              trailing: PopupMenuButton(
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, size: 20),
                                        SizedBox(width: 8),
                                        Text('Uredi'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete, size: 20, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Obriši', style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _showAddEditDialog(genre: genre);
                                  } else if (value == 'delete') {
                                    _deleteGenre(genre);
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

}
