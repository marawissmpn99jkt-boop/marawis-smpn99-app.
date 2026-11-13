import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({
    super.key,
    required this.user,
    required this.profile,
  });

  final User user;
  final Map<String, dynamic> profile;

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _classController = TextEditingController();
  final _bioController = TextEditingController();
  final _picker = ImagePicker();

  String? _avatarUrl;
  Uint8List? _newAvatarBytes;
  String? _newAvatarExtension;
  bool _saving = false;
  bool _removingAvatar = false;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _nameController.text = (widget.profile['full_name'] ?? '').toString();
    _avatarUrl = widget.profile['avatar_url']?.toString();

    _loadMemberDetails();
  }

  Future<void> _loadMemberDetails() async {
    try {
      final row = await _client
          .from('members')
          .select('class_name, bio')
          .eq('id', widget.user.id)
          .maybeSingle();
      if (!mounted || row == null) return;
      _classController.text = (row['class_name'] ?? '').toString();
      _bioController.text = (row['bio'] ?? '').toString();
      setState(() {});
    } catch (_) {
      // Form tetap bisa dipakai; kegagalan ditampilkan saat penyimpanan.
    }
  }

  Future<void> _chooseAvatar() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1200,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      final extension = image.name.toLowerCase().endsWith('.png')
          ? 'png'
          : image.name.toLowerCase().endsWith('.webp')
              ? 'webp'
              : 'jpg';
      if (!mounted) return;
      setState(() {
        _newAvatarBytes = bytes;
        _newAvatarExtension = extension;
        _removingAvatar = false;
      });
    } catch (error) {
      _showMessage('Tidak bisa membuka foto: $error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<String?> _uploadAvatar() async {
    final bytes = _newAvatarBytes;
    final extension = _newAvatarExtension;
    if (bytes == null || extension == null) return _avatarUrl;

    final path = '${widget.user.id}/${DateTime.now().millisecondsSinceEpoch}.$extension';
    final contentType = extension == 'png'
        ? 'image/png'
        : extension == 'webp'
            ? 'image/webp'
            : 'image/jpeg';

    await _client.storage.from('profile-avatars').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: contentType, upsert: true),
    );
    return _client.storage.from('profile-avatars').getPublicUrl(path);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final avatarUrl = _removingAvatar ? null : await _uploadAvatar();

      await _client.from('profiles').update({
        'full_name': _nameController.text.trim(),
        'avatar_url': avatarUrl,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', widget.user.id);

      await _client.from('members').update({
        'class_name': _classController.text.trim().isEmpty
            ? null
            : _classController.text.trim(),
        'bio': _bioController.text.trim().isEmpty
            ? null
            : _bioController.text.trim(),
      }).eq('id', widget.user.id);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      _showMessage('Gagal menyimpan profil: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _classController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasNewImage = _newAvatarBytes != null;
    final hasCurrentImage = !_removingAvatar &&
        (hasNewImage || (_avatarUrl != null && _avatarUrl!.isNotEmpty));

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Profil',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 55,
                          backgroundColor: const Color(0xFFE0F2EC),
                          backgroundImage: hasNewImage
                              ? MemoryImage(_newAvatarBytes!)
                              : hasCurrentImage
                                  ? NetworkImage(_avatarUrl!) as ImageProvider
                                  : null,
                          child: !hasCurrentImage
                              ? const Icon(
                                  Icons.person_rounded,
                                  size: 54,
                                  color: Color(0xFF167D68),
                                )
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Material(
                            color: const Color(0xFF167D68),
                            shape: const CircleBorder(),
                            child: IconButton(
                              onPressed: _saving ? null : _chooseAvatar,
                              tooltip: 'Pilih foto',
                              icon: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: _saving
                          ? null
                          : () => setState(() {
                                _newAvatarBytes = null;
                                _newAvatarExtension = null;
                                _removingAvatar = true;
                              }),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Hapus foto profil'),
                    ),
                    const Text(
                      'JPG, PNG, atau WebP • Maksimal 5 MB',
                      style: TextStyle(color: Color(0xFF78877F), fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              _fieldLabel('Nama tampilan'),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: _decoration('Masukkan nama tampilan'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nama tidak boleh kosong.';
                  }
                  if (value.trim().length > 80) return 'Maksimal 80 karakter.';
                  return null;
                },
              ),
              const SizedBox(height: 18),
              _fieldLabel('Kelas'),
              TextFormField(
                controller: _classController,
                textCapitalization: TextCapitalization.characters,
                decoration: _decoration('Contoh: 8F'),
                maxLength: 10,
              ),
              const SizedBox(height: 8),
              _fieldLabel('Bio'),
              TextFormField(
                controller: _bioController,
                textCapitalization: TextCapitalization.sentences,
                decoration: _decoration('Ceritakan sedikit tentang dirimu'),
                minLines: 3,
                maxLines: 4,
                maxLength: 160,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF4EF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        color: Color(0xFF167D68), size: 19),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Email dan hak akses akun tidak dapat diubah dari halaman ini. Jabatan dan role dikelola admin.',
                        style: TextStyle(
                          color: Color(0xFF45665A),
                          fontSize: 11,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _saving ? null : _saveProfile,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF167D68),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 21,
                          height: 21,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Simpan perubahan',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
      );

  InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        counterStyle: const TextStyle(fontSize: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE8EEEA)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE8EEEA)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF167D68), width: 1.5),
        ),
      );
}
