import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/institution.dart';
import '../../services/api_service.dart';

class InstitutionsManagementScreen extends StatefulWidget {
  const InstitutionsManagementScreen({super.key});

  @override
  State<InstitutionsManagementScreen> createState() => _InstitutionsManagementScreenState();
}

class _InstitutionsManagementScreenState extends State<InstitutionsManagementScreen> {
  List<Institution> _institutions = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInstitutions();
  }

  Future<void> _loadInstitutions() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final institutions = await ApiService.getInstitutions();
      setState(() {
        _institutions = institutions;
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
    _showInstitutionDialog();
  }

  void _showEditDialog(Institution institution) {
    _showInstitutionDialog(institution: institution);
  }

  void _showInstitutionDialog({Institution? institution}) {
    final nameController = TextEditingController(text: institution?.name ?? '');
    final descriptionController = TextEditingController(text: institution?.description ?? '');
    final addressController = TextEditingController(text: institution?.address ?? '');
    final capacityController = TextEditingController(text: institution?.capacity.toString() ?? '');
    final imagePathController = TextEditingController(text: institution?.imagePath ?? '');
    bool isActive = institution?.isActive ?? true;
    String? validationError;
    bool isUploadingImage = false;

    double dialogWidth(BuildContext context) {
      final w = MediaQuery.of(context).size.width;
      return w >= 900 ? 720 : (w * 0.92).clamp(320.0, 720.0);
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(institution == null ? 'Nova institucija' : 'Uredi instituciju'),
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
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Naziv *',
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
                    border: OutlineInputBorder(),
                    helperText: 'Opis institucije. Maksimalno 1000 karaktera.',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Adresa',
                    border: OutlineInputBorder(),
                    helperText: 'Adresa institucije. Maksimalno 500 karaktera.',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: capacityController,
                  decoration: const InputDecoration(
                    labelText: 'Kapacitet *',
                    border: OutlineInputBorder(),
                    helperText: 'Maksimalan broj mjesta u instituciji. Mora biti veći od 0.',
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
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: imagePathController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Slika',
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
                                  folder: 'institutions',
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
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Odustani'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Validacija
                String? error;
                if (nameController.text.trim().isEmpty) {
                  error = 'Naziv institucije je obavezan.';
                } else if (nameController.text.length > 200) {
                  error = 'Naziv institucije ne može biti duži od 200 karaktera.';
                } else if (capacityController.text.trim().isEmpty) {
                  error = 'Kapacitet je obavezan.';
                } else {
                  final capacity = int.tryParse(capacityController.text.trim());
                  if (capacity == null || capacity <= 0) {
                    error = 'Kapacitet mora biti pozitivan broj veći od 0.';
                  }
                }

                if (error != null) {
                  setDialogState(() {
                    validationError = error;
                  });
                  return;
                }

                try {
                  final data = {
                    'name': nameController.text.trim(),
                    'description': descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
                    'address': addressController.text.trim().isEmpty ? null : addressController.text.trim(),
                    'capacity': int.parse(capacityController.text.trim()),
                    'imagePath': imagePathController.text.trim().isEmpty ? null : imagePathController.text.trim(),
                    'isActive': isActive,
                  };

                  if (institution == null) {
                    await ApiService.createInstitution(data);
                  } else {
                    await ApiService.updateInstitution(institution.id, data);
                  }

                  if (!mounted) return;
                  
                  // Auto-clear forma nakon uspješnog save-a (samo ako je create)
                  if (institution == null) {
                    nameController.clear();
                    descriptionController.clear();
                    addressController.clear();
                    capacityController.clear();
                    isActive = true;
                    validationError = null;
                  }
                  
                  // Auto-refresh liste
                  _loadInstitutions();
                  
                  Navigator.pop(context);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(institution == null ? 'Institucija uspješno kreirana!' : 'Institucija uspješno ažurirana!'),
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
              child: Text(institution == null ? 'Kreiraj' : 'Sačuvaj'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(Institution institution) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Brisanje institucije'),
        content: Text('Da li ste sigurni da želite obrisati instituciju "${institution.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Odustani'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ApiService.deleteInstitution(institution.id);
                if (!mounted) return;
                Navigator.pop(context);
                _loadInstitutions();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Institucija obrisana'),
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

  List<Institution> get _filteredInstitutions {
    final searchTerm = _searchController.text.toLowerCase();
    if (searchTerm.isEmpty) return _institutions;
    return _institutions.where((i) {
      return i.name.toLowerCase().contains(searchTerm) ||
          (i.description?.toLowerCase().contains(searchTerm) ?? false) ||
          (i.address?.toLowerCase().contains(searchTerm) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upravljanje institucijama'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInstitutions,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Pretraži institucije...',
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
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _showCreateDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Nova institucija'),
                ),
              ],
            ),
          ),
          // Institutions list
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
                              onPressed: _loadInstitutions,
                              child: const Text('Pokušaj ponovo'),
                            ),
                          ],
                        ),
                      )
                    : _filteredInstitutions.isEmpty
                        ? const Center(
                            child: Text('Nema institucija'),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(8.0),
                            itemCount: _filteredInstitutions.length,
                            itemBuilder: (context, index) {
                              final institution = _filteredInstitutions[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: institution.isActive
                                        ? Colors.green
                                        : Colors.grey,
                                    child: const Icon(Icons.business, color: Colors.white),
                                  ),
                                  title: Text(
                                    institution.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (institution.description != null)
                                        Text(
                                          institution.description!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      if (institution.address != null)
                                        Text(institution.address!),
                                      Text('Predstave: ${institution.showsCount}'),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed: () => _showEditDialog(institution),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => _showDeleteDialog(institution),
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






