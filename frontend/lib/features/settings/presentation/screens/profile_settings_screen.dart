import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';

import 'package:frontend/core/widgets/custom_snackbar.dart';
import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:frontend/features/auth/model/user_model.dart';
import 'package:frontend/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

class ProfileSettingsScreen extends ConsumerStatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  ConsumerState<ProfileSettingsScreen> createState() =>
      _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends ConsumerState<ProfileSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();

  XFile? _pickedImage;
  Uint8List? _pickedImageBytes;
  bool _removePhoto = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authUser = ref.read(authStateProvider).asData?.value;
      final currentUser = ref.read(currentUserProvider);
      _nameController.text = currentUser?.displayName?.trim().isNotEmpty == true
          ? currentUser!.displayName!.trim()
          : (authUser?.displayName?.trim() ?? '');
      if (currentUser?.bio?.isNotEmpty == true) {
        _bioController.text = currentUser!.bio!.trim();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Photo Library'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked != null && mounted) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _pickedImage = picked;
        _pickedImageBytes = bytes;
        _removePhoto = false;
      });
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = ref.watch(themeNotifierProvider);
    final ColorScheme scheme = theme.colorScheme;
    final authUser = ref.watch(authStateProvider).asData?.value;
    final String? photoUrl = authUser?.photoURL?.trim();

    MemoryImage? avatarImage;
    if (_pickedImageBytes != null) {
      avatarImage = MemoryImage(_pickedImageBytes!);
    }
    final String? avatarNetworkUrl =
        _pickedImageBytes == null &&
            !_removePhoto &&
            photoUrl != null &&
            photoUrl.isNotEmpty
        ? photoUrl
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.primary,
                    ),
                  )
                : Text(
                    'Save',
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundImage: avatarImage,
                    backgroundColor: scheme.primaryContainer,
                    child: avatarImage == null
                        ? avatarNetworkUrl != null
                              ? ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: avatarNetworkUrl,
                                    width: 96,
                                    height: 96,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, _, _) => Text(
                                      (authUser?.displayName?.isNotEmpty == true
                                              ? authUser!.displayName![0]
                                              : '?')
                                          .toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 36,
                                        color: scheme.onPrimaryContainer,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                )
                              : Text(
                                  (authUser?.displayName?.isNotEmpty == true
                                          ? authUser!.displayName![0]
                                          : '?')
                                      .toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 36,
                                    color: scheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.scaffoldBackgroundColor,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          size: 16,
                          color: scheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (avatarImage != null) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => setState(() {
                    _pickedImage = null;
                    _pickedImageBytes = null;
                    _removePhoto = true;
                  }),
                  child: Text(
                    'Remove photo',
                    style: TextStyle(color: scheme.error),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                hintText: 'Enter your name',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bioController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Bio',
                hintText: 'Tell others a bit about yourself',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
