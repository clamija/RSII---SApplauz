import 'package:flutter/material.dart';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import '../../models/show.dart';
import '../../models/institution.dart';
import '../../models/genre.dart';
import '../../models/show_list_response.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../utils/role_helper.dart';

class ShowsManagementScreen extends StatefulWidget {
  const ShowsManagementScreen({super.key});

  @override
  State<ShowsManagementScreen> createState() => _ShowsManagementScreenState();
}

class _ShowsManagementScreenState extends State<ShowsManagementScreen> {
  ShowListResponse? _showListResponse;
  List<Institution> _institutions = [];
  List<Genre> _genres = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _currentPage = 1;
  final int _pageSize = 20;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    // Real-time pretraga sa debounce-om (isti UX kao korisnički "Predstave").
    // setState radi refresh suffixIcon (clear) bez čekanja na debounce.
    if (mounted) setState(() {});

    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _currentPage = 1;
      });
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final searchTerm = _searchController.text.trim().isEmpty ? null : _searchController.text.trim();
      final user = AuthService.instance.currentUser;
      final isInstitutionAdmin = user != null &&
          RoleHelper.isAdmin(user.roles) &&
          !RoleHelper.isSuperAdmin(user.roles) &&
          (user.institutionId != null || RoleHelper.tryGetInstitutionIdFromRoles(user.roles) != null);

      final results = await Future.wait([
        ApiService.getShowsForManagement(pageNumber: _currentPage, pageSize: _pageSize, searchTerm: searchTerm),
        // Institution adminu ne treba lista svih institucija (i ne smije birati druge).
        if (isInstitutionAdmin) Future.value(<Institution>[]) else ApiService.getInstitutions(),
        ApiService.getGenres(),
      ]);

      setState(() {
        _showListResponse = results[0] as ShowListResponse;
        _institutions = results[1] as List<Institution>;
        _genres = results[2] as List<Genre>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteShow(Show show) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Brisanje predstave'),
        content: Text('Da li ste sigurni da želite obrisati predstavu "${show.title}"?'),
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
        await ApiService.deleteShow(show.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Predstava je uspješno obrisana')),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Greška pri brisanju: ${e.toString()}')),
          );
        }
      }
    }
  }

  void _showAddEditDialog({Show? show}) {
    final user = AuthService.instance.currentUser;
    final isInstitutionAdmin = user != null &&
        RoleHelper.isAdmin(user.roles) &&
        !RoleHelper.isSuperAdmin(user.roles) &&
        (user.institutionId != null || RoleHelper.tryGetInstitutionIdFromRoles(user.roles) != null);
    final adminInstitutionId = isInstitutionAdmin
        ? (user.institutionId ?? RoleHelper.tryGetInstitutionIdFromRoles(user.roles))
        : null;

    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: show?.title ?? '');
    final descriptionController = TextEditingController(text: show?.description ?? '');
    final durationController = TextEditingController(text: show?.durationMinutes.toString() ?? '90');
    
    int? selectedInstitutionId = adminInstitutionId ??
        (show?.institutionId ?? (_institutions.isNotEmpty ? _institutions.first.id : null));
    int? selectedGenreId = show?.genreId ?? (_genres.isNotEmpty ? _genres.first.id : null);
    final imagePathController = TextEditingController(text: show?.imagePath ?? '');
    bool isActive = show?.isActive ?? true;
    bool isUploadingImage = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(show == null ? 'Dodaj predstavu' : 'Uredi predstavu'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Naziv *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value?.isEmpty ?? true ? 'Molimo unesite naziv' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Opis',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: durationController,
                    decoration: const InputDecoration(
                      labelText: 'Trajanje (minute) *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Molimo unesite trajanje';
                      if (int.tryParse(value!) == null) return 'Molimo unesite validan broj';
                      if (int.parse(value) <= 0) return 'Trajanje mora biti veće od 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  if (!isInstitutionAdmin) ...[
                    DropdownButtonFormField<int>(
                      value: selectedInstitutionId,
                      decoration: const InputDecoration(
                        labelText: 'Institucija *',
                        border: OutlineInputBorder(),
                      ),
                      items: _institutions.map((institution) {
                        return DropdownMenuItem(
                          value: institution.id,
                          child: Text(institution.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedInstitutionId = value;
                        });
                      },
                      validator: (value) => value == null ? 'Molimo odaberite instituciju' : null,
                    ),
                    const SizedBox(height: 16),
                  ],
                  DropdownButtonFormField<int>(
                    value: selectedGenreId,
                    decoration: const InputDecoration(
                      labelText: 'Žanr *',
                      border: OutlineInputBorder(),
                    ),
                    items: _genres.map((genre) {
                      return DropdownMenuItem(
                        value: genre.id,
                        child: Text(genre.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedGenreId = value;
                      });
                    },
                    validator: (value) => value == null ? 'Molimo odaberite žanr' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: imagePathController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Slika',
                            border: OutlineInputBorder(),
                            hintText: 'Odaberite sliku sa uređaja (upload na server)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: isUploadingImage
                            ? null
                            : () async {
                                try {
                                  final result = await FilePicker.platform.pickFiles(
                                    type: FileType.image,
                                    allowMultiple: false,
                                  );
                                  if (result == null || result.files.isEmpty) return;
                                  final picked = result.files.single;
                                  final path = picked.path;
                                  if (path == null || path.isEmpty) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Odabir slike nije podržan na ovoj platformi.'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                    return;
                                  }

                                  setDialogState(() => isUploadingImage = true);
                                  final uploadedPath = await ApiService.uploadImage(
                                    filePath: path,
                                    folder: 'shows',
                                  );
                                  setDialogState(() {
                                    imagePathController.text = uploadedPath;
                                    isUploadingImage = false;
                                  });
                                } catch (e) {
                                  setDialogState(() => isUploadingImage = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Greška pri upload-u slike: ${e.toString()}'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                        icon: isUploadingImage
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.upload),
                        label: Text(isUploadingImage ? 'Upload...' : 'Odaberi'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Aktivna'),
                    value: isActive,
                    onChanged: (value) {
                      setDialogState(() {
                        isActive = value;
                      });
                    },
                  ),
                ],
              ),
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
                  if (selectedInstitutionId == null || selectedGenreId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Molimo odaberite instituciju i žanr')),
                    );
                    return;
                  }

                  try {
                    // Institution admin: uvijek forsiraj institutionId na svoju instituciju
                    if (adminInstitutionId != null) {
                      selectedInstitutionId = adminInstitutionId;
                    }

                    final data = {
                      'title': titleController.text.trim(),
                      'description': descriptionController.text.trim().isEmpty 
                          ? null 
                          : descriptionController.text.trim(),
                      'durationMinutes': int.parse(durationController.text.trim()),
                      'institutionId': selectedInstitutionId,
                      'genreId': selectedGenreId,
                      'imagePath': imagePathController.text.trim().isEmpty 
                          ? null 
                          : imagePathController.text.trim(),
                      'isActive': isActive,
                    };

                    if (show == null) {
                      await ApiService.createShow(data);
                    } else {
                      await ApiService.updateShow(show.id, data);
                    }

                    if (mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            show == null 
                                ? 'Predstava je uspješno dodana' 
                                : 'Predstava je uspješno ažurirana',
                          ),
                        ),
                      );
                      _loadData();
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
              child: Text(show == null ? 'Dodaj' : 'Sačuvaj'),
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
        title: const Text('Upravljanje Predstavama'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Pretraži predstave...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _currentPage = 1;
                          });
                          _loadData();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              // onChanged se hvata preko listenera + debounce
            ),
          ),
        ),
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
                        onPressed: _loadData,
                        child: const Text('Pokušaj ponovo'),
                      ),
                    ],
                  ),
                )
              : _showListResponse == null || _showListResponse!.shows.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.event, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            'Nema predstava',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: Column(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _showListResponse!.shows.length,
                              itemBuilder: (context, index) {
                                final show = _showListResponse!.shows[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: show.isActive 
                                          ? Colors.green 
                                          : Colors.grey,
                                      child: const Icon(Icons.event, color: Colors.white),
                                    ),
                                    title: Text(
                                      show.title,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(show.institutionName),
                                        Text('Žanr: ${show.genreName}'),
                                        Text(
                                          'Trajanje: ${show.durationFormatted}',
                                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                        ),
                                      ],
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
                                          _showAddEditDialog(show: show);
                                        } else if (value == 'delete') {
                                          _deleteShow(show);
                                        }
                                      },
                                    ),
                                    isThreeLine: true,
                                  ),
                                );
                              },
                            ),
                          ),
                          if (_showListResponse!.totalPages > 1)
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chevron_left),
                                    onPressed: _currentPage > 1
                                        ? () {
                                            setState(() {
                                              _currentPage--;
                                            });
                                            _loadData();
                                          }
                                        : null,
                                  ),
                                  Text('Stranica $_currentPage od ${_showListResponse!.totalPages}'),
                                  IconButton(
                                    icon: const Icon(Icons.chevron_right),
                                    onPressed: _currentPage < _showListResponse!.totalPages
                                        ? () {
                                            setState(() {
                                              _currentPage++;
                                            });
                                            _loadData();
                                          }
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Dodaj'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }
}
