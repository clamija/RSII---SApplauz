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
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInstitutions();
  }

  Future<void> _loadInstitutions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final institutions = await ApiService.getInstitutions();
      setState(() {
        _institutions = institutions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteInstitution(Institution institution) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Brisanje institucije'),
        content: Text('Da li ste sigurni da želite obrisati instituciju "${institution.name}"?'),
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
        await ApiService.deleteInstitution(institution.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Institucija je uspješno obrisana')),
          );
          _loadInstitutions();
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

  void _showAddEditDialog({Institution? institution}) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: institution?.name ?? '');
    final addressController = TextEditingController(text: institution?.address ?? '');
    final capacityController = TextEditingController(text: institution?.capacity.toString() ?? '0');
    final imagePathController = TextEditingController(text: institution?.imagePath ?? '');
    bool isActive = institution?.isActive ?? true;
    bool isUploadingImage = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(institution == null ? 'Dodaj instituciju' : 'Uredi instituciju'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Naziv *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value?.isEmpty ?? true ? 'Molimo unesite naziv' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: addressController,
                    decoration: const InputDecoration(
                      labelText: 'Adresa',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: capacityController,
                    decoration: const InputDecoration(
                      labelText: 'Kapacitet *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Molimo unesite kapacitet';
                      if (int.tryParse(value!) == null) return 'Molimo unesite validan broj';
                      if (int.parse(value) <= 0) return 'Kapacitet mora biti veći od 0';
                      return null;
                    },
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
                            hintText: 'Odaberite sliku sa računara/uređaja (upload na server)',
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
                                    folder: 'institutions',
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
                  try {
                    final data = {
                      'name': nameController.text.trim(),
                      'address': addressController.text.trim().isEmpty 
                          ? null 
                          : addressController.text.trim(),
                      'capacity': int.parse(capacityController.text.trim()),
                      'imagePath': imagePathController.text.trim().isEmpty ? null : imagePathController.text.trim(),
                      'isActive': isActive,
                    };

                    if (institution == null) {
                      await ApiService.createInstitution(data);
                    } else {
                      await ApiService.updateInstitution(institution.id, data);
                    }

                    if (mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            institution == null 
                                ? 'Institucija je uspješno dodana' 
                                : 'Institucija je uspješno ažurirana',
                          ),
                        ),
                      );
                      _loadInstitutions();
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
              child: Text(institution == null ? 'Dodaj' : 'Sačuvaj'),
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
        title: const Text('Upravljanje Institucijama'),
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
                        onPressed: _loadInstitutions,
                        child: const Text('Pokušaj ponovo'),
                      ),
                    ],
                  ),
                )
              : _institutions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.business, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            'Nema institucija',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _showAddEditDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text('Dodaj instituciju'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadInstitutions,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _institutions.length,
                        itemBuilder: (context, index) {
                          final institution = _institutions[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: institution.isActive 
                                    ? Colors.green 
                                    : Colors.grey,
                                child: Icon(
                                  institution.isActive ? Icons.check : Icons.close,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                institution.name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                'Kapacitet: ${institution.capacity} | Predstave: ${institution.showsCount}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
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
                                    _showAddEditDialog(institution: institution);
                                  } else if (value == 'delete') {
                                    _deleteInstitution(institution);
                                  }
                                },
                              ),
                            ),
                          );
                        },
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
