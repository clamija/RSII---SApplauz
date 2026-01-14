import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/show.dart';
import '../../models/institution.dart';
import '../../models/genre.dart';
import '../../models/show_list_response.dart';
import '../../services/api_service.dart';
import '../../main.dart';
import '../../utils/role_helper.dart';

class ShowsManagementScreen extends StatefulWidget {
  final int? initialInstitutionId;

  const ShowsManagementScreen({super.key, this.initialInstitutionId});

  @override
  State<ShowsManagementScreen> createState() => _ShowsManagementScreenState();
}

class _ShowsManagementScreenState extends State<ShowsManagementScreen> {
  List<Show> _shows = [];
  List<Institution> _institutions = [];
  List<Genre> _genres = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  int? _selectedInstitutionFilter;
  int? _selectedGenreFilter;
  bool _isSuperAdmin = false;

  @override
  void initState() {
    super.initState();
    final user = globalAuthService.currentUser;
    _isSuperAdmin = user != null && RoleHelper.isSuperAdmin(user.roles);
    if (_isSuperAdmin) {
      _selectedInstitutionFilter = widget.initialInstitutionId;
    }
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final user = globalAuthService.currentUser;
      final effectiveInstitutionId =
          (_isSuperAdmin ? null : (user?.institutionId ?? RoleHelper.tryGetInstitutionIdFromRoles(user?.roles ?? const [])));

      final results = await Future.wait([
        ApiService.getShowsForManagement(
          pageNumber: 1,
          pageSize: 1000,
          institutionId: _isSuperAdmin ? _selectedInstitutionFilter : effectiveInstitutionId,
        ),
        _isSuperAdmin ? ApiService.getInstitutions() : Future.value(<Institution>[]),
        ApiService.getGenres(),
      ]);

      setState(() {
        _shows = (results[0] as ShowListResponse).shows;
        _institutions = results[1] as List<Institution>;
        _genres = results[2] as List<Genre>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showCreateDialog() {
    _showShowDialog();
  }

  void _showEditDialog(Show show) {
    _showShowDialog(show: show);
  }

  void _showShowDialog({Show? show}) {
    final titleController = TextEditingController(text: show?.title ?? '');
    final descriptionController = TextEditingController(text: show?.description ?? '');
    final durationController = TextEditingController(text: show?.durationMinutes.toString() ?? '');
    final imagePathController = TextEditingController(text: show?.imagePath ?? '');
    final user = globalAuthService.currentUser;
    final effectiveInstitutionId = _isSuperAdmin
        ? null
        : (user?.institutionId ?? RoleHelper.tryGetInstitutionIdFromRoles(user?.roles ?? const []));
    int? selectedInstitutionId = show?.institutionId ?? effectiveInstitutionId;
    int? selectedGenreId = (show != null && show.genres.isNotEmpty) ? show.genres.first.id : null;
    bool isActive = show?.isActive ?? true;
    String? validationError;
    bool isUploadingImage = false;

    double dialogWidth(BuildContext context) {
      final w = MediaQuery.of(context).size.width;
      return w >= 1100 ? 860 : (w * 0.92).clamp(360.0, 860.0);
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(show == null ? 'Nova predstava' : 'Uredi predstavu'),
          content: SizedBox(
            width: dialogWidth(context),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                if (validationError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
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
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Naziv *',
                    prefixIcon: Icon(Icons.title),
                    border: OutlineInputBorder(),
                    helperText: 'Obavezno polje. Maksimalno 200 karaktera.',
                  ),
                  onChanged: (_) {
                    if (validationError != null) {
                      setDialogState(() {
                        validationError = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Opis',
                    prefixIcon: Icon(Icons.description),
                    border: OutlineInputBorder(),
                    helperText: 'Opis predstave. Maksimalno 2000 karaktera.',
                  ),
                  maxLines: 4,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: durationController,
                  decoration: const InputDecoration(
                    labelText: 'Trajanje (minute) *',
                    prefixIcon: Icon(Icons.access_time),
                    border: OutlineInputBorder(),
                    helperText: 'Trajanje predstave u minutama. Mora biti između 1 i 600 minuta.',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) {
                    if (validationError != null) {
                      setDialogState(() {
                        validationError = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                if (_isSuperAdmin)
                  DropdownButtonFormField<int>(
                    value: selectedInstitutionId,
                    decoration: const InputDecoration(
                      labelText: 'Institucija *',
                      prefixIcon: Icon(Icons.business),
                      border: OutlineInputBorder(),
                      helperText: 'Obavezno polje. Odaberite instituciju.',
                    ),
                    items: _institutions.map((i) {
                      return DropdownMenuItem<int>(
                        value: i.id,
                        child: Text(i.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedInstitutionId = value;
                        if (validationError != null) {
                          validationError = null;
                        }
                      });
                    },
                  )
                else
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Institucija',
                      prefixIcon: Icon(Icons.business),
                      border: OutlineInputBorder(),
                      helperText: 'Institucija je automatski postavljena prema vašem nalogu.',
                    ),
                    child: Text(
                      effectiveInstitutionId != null ? 'ID: $effectiveInstitutionId' : '-',
                    ),
                  ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: selectedGenreId,
                  decoration: const InputDecoration(
                    labelText: 'Žanr *',
                    prefixIcon: Icon(Icons.category),
                    border: OutlineInputBorder(),
                    helperText: 'Obavezno polje. Odaberite žanr predstave.',
                  ),
                  items: _genres.map((genre) {
                    return DropdownMenuItem<int>(
                      value: genre.id,
                      child: Text(genre.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedGenreId = value;
                      if (validationError != null) {
                        validationError = null;
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: imagePathController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Slika',
                          prefixIcon: Icon(Icons.image),
                          border: OutlineInputBorder(),
                          helperText: 'Odaberite sliku sa računara (upload na server)',
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
                                if (path == null || path.isEmpty) return;

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
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Greška pri upload-u slike: ${e.toString()}'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
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
                CheckboxListTile(
                  title: const Text('Aktivna'),
                  value: isActive,
                  onChanged: (value) {
                    setDialogState(() {
                      isActive = value ?? true;
                    });
                  },
                ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Odustani'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                // Validacija
                String? error;
                if (titleController.text.trim().isEmpty) {
                  error = 'Naziv predstave je obavezan.';
                } else if (titleController.text.length > 200) {
                  error = 'Naziv predstave ne može biti duži od 200 karaktera.';
                } else if (durationController.text.trim().isEmpty) {
                  error = 'Trajanje je obavezno.';
                } else {
                  final duration = int.tryParse(durationController.text.trim());
                  if (duration == null || duration <= 0) {
                    error = 'Trajanje mora biti pozitivan broj.';
                  } else if (duration > 600) {
                    error = 'Trajanje ne može biti duže od 600 minuta (10 sati).';
                  }
                }

                if (selectedInstitutionId == null) {
                  error = 'Institucija je obavezna.';
                }

                if (selectedGenreId == null) {
                  error = 'Žanr je obavezan.';
                }

                if (error != null) {
                  setDialogState(() {
                    validationError = error;
                  });
                  return;
                }

                try {
                  final data = {
                    'title': titleController.text.trim(),
                    'description': descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
                    'durationMinutes': int.parse(durationController.text.trim()),
                    'institutionId': selectedInstitutionId!,
                    'genreId': selectedGenreId!,
                    'imagePath': imagePathController.text.trim().isEmpty ? null : imagePathController.text.trim(),
                    'isActive': isActive,
                  };

                  if (show == null) {
                    await ApiService.createShow(data);
                  } else {
                    await ApiService.updateShow(show.id, data);
                  }

                  if (!mounted) return;
                  
                  // Auto-clear forma nakon uspješnog save-a (samo ako je create)
                  if (show == null) {
                    titleController.clear();
                    descriptionController.clear();
                    durationController.clear();
                    imagePathController.clear();
                    selectedInstitutionId = _isSuperAdmin ? null : effectiveInstitutionId;
                    selectedGenreId = null;
                    isActive = true;
                    validationError = null;
                  }
                  
                  // Auto-refresh liste
                  _loadData();
                  
                  Navigator.pop(context);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(show == null ? 'Predstava uspješno kreirana!' : 'Predstava uspješno ažurirana!'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  final errorMessage = e.toString().contains('400') || e.toString().contains('Validation')
                      ? 'Greška pri validaciji. Provjerite unesene podatke.'
                      : 'Greška: ${e.toString()}';
                  
                  setDialogState(() {
                    validationError = errorMessage;
                  });
                }
              },
              icon: Icon(show == null ? Icons.add : Icons.save),
              label: Text(show == null ? 'Kreiraj' : 'Sačuvaj'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(Show show) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red[700], size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Brisanje predstave',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Jeste li sigurni da želite obrisati predstavu?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Predstava: ${show.title}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red[900]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '⚠️ Ova radnja je nepovratna!',
                    style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ovo će obrisati sve termine vezane za ovu predstavu.',
                    style: TextStyle(color: Colors.red[700], fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Odustani'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ApiService.deleteShow(show.id);
                if (!mounted) return;
                Navigator.pop(context);
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Predstava uspješno obrisana'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Greška: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Obriši'),
          ),
        ],
      ),
    );
  }

  List<Show> get _filteredShows {
    final searchTerm = _searchController.text.toLowerCase();
    
    return _shows.where((s) {
      // Pretraga po nazivu
      final matchesSearch = searchTerm.isEmpty ||
          s.title.toLowerCase().contains(searchTerm) ||
          (s.description?.toLowerCase().contains(searchTerm) ?? false) ||
          s.institutionName.toLowerCase().contains(searchTerm);
      
      // Filter po instituciji
      final matchesInstitution = _selectedInstitutionFilter == null ||
          s.institutionId == _selectedInstitutionFilter;
      
      // Filter po žanru
      final matchesGenre = _selectedGenreFilter == null ||
          s.genres.any((g) => g.id == _selectedGenreFilter);
      
      return matchesSearch && matchesInstitution && matchesGenre;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upravljanje predstavama'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and filters
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 980;

                final searchField = SizedBox(
                  width: isNarrow ? constraints.maxWidth : 520,
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
                                setState(() {});
                              },
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                );

                final createButton = ElevatedButton.icon(
                  onPressed: _showCreateDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Nova predstava'),
                );

                Widget institutionFilter() => SizedBox(
                      width: isNarrow ? constraints.maxWidth : 320,
                      child: DropdownButtonFormField<int?>(
                        value: _selectedInstitutionFilter,
                        decoration: const InputDecoration(
                          labelText: 'Institucija',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('Sve institucije')),
                          ..._institutions.map((i) => DropdownMenuItem<int?>(value: i.id, child: Text(i.name))),
                        ],
                        onChanged: (value) => setState(() => _selectedInstitutionFilter = value),
                      ),
                    );

                Widget genreFilter() => SizedBox(
                      width: isNarrow ? constraints.maxWidth : 320,
                      child: DropdownButtonFormField<int?>(
                        value: _selectedGenreFilter,
                        decoration: const InputDecoration(
                          labelText: 'Žanr',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('Svi žanrovi')),
                          ..._genres.map((g) => DropdownMenuItem<int?>(value: g.id, child: Text(g.name))),
                        ],
                        onChanged: (value) => setState(() => _selectedGenreFilter = value),
                      ),
                    );

                final hasFilters = _selectedInstitutionFilter != null || _selectedGenreFilter != null;

                if (isNarrow) {
                  return Column(
                    children: [
                      Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        children: [
                          searchField,
                          createButton,
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        children: [
                          if (_isSuperAdmin) institutionFilter(),
                          genreFilter(),
                          if (hasFilters)
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _selectedInstitutionFilter = null;
                                  _selectedGenreFilter = null;
                                });
                              },
                              icon: const Icon(Icons.clear),
                              label: const Text('Očisti filtere'),
                            ),
                        ],
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: searchField),
                        const SizedBox(width: 16),
                        createButton,
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (_isSuperAdmin) ...[
                          institutionFilter(),
                          const SizedBox(width: 16),
                        ],
                        genreFilter(),
                        const Spacer(),
                        if (hasFilters)
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _selectedInstitutionFilter = null;
                                _selectedGenreFilter = null;
                              });
                            },
                            icon: const Icon(Icons.clear),
                            label: const Text('Očisti filtere'),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          // Shows list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Greška: $_error', style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadData,
                              child: const Text('Pokušaj ponovo'),
                            ),
                          ],
                        ),
                      )
                    : _filteredShows.isEmpty
                        ? const Center(
                            child: Text('Nema predstava'),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(8.0),
                            itemCount: _filteredShows.length,
                            itemBuilder: (context, index) {
                              final show = _filteredShows[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: show.isActive
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.grey,
                                    child: const Icon(Icons.theaters, color: Colors.white),
                                  ),
                                  title: Text(
                                    show.title,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(show.institutionName),
                                      if (show.description != null)
                                        Text(
                                          show.description!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      Text('Trajanje: ${show.durationFormatted}'),
                                      if (show.genres.isNotEmpty)
                                        Text('Žanrovi: ${show.genresString}'),
                                      Text('Termini: ${show.performancesCount}'),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed: () => _showEditDialog(show),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => _showDeleteDialog(show),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

