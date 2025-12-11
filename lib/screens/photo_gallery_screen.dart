// lib/screens/photo_gallery_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';
import '../models/user_photo.dart';

class PhotoGalleryScreen extends StatefulWidget {
  const PhotoGalleryScreen({super.key});

  @override
  State<PhotoGalleryScreen> createState() => _PhotoGalleryScreenState();
}

class _PhotoGalleryScreenState extends State<PhotoGalleryScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();
  String? _currentUserUid;

  @override
  void initState() {
    super.initState();
    _currentUserUid = _auth.currentUser?.uid;
    if (_currentUserUid == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not logged in.')),
        );
      });
    }
  }

  Future<void> _addPhoto() async {
    if (_currentUserUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to add photos.')),
      );
      return;
    }

    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (image != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading photo...')),
      );

      try {
        final String photoId = const Uuid().v4();
        final String imageUrl = await _dbHelper.uploadUserPhoto(_currentUserUid!, image, photoId);

        final UserPhoto newPhoto = UserPhoto(
          id: photoId,
          uid: _currentUserUid!,
          imageUrl: imageUrl,
          timestamp: Timestamp.now(),
        );

        await _dbHelper.saveUserPhotoMetadata(newPhoto);

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo uploaded successfully!')),
          );
        }
      } catch (e) {
        print('Error uploading or saving photo: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload photo: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _deletePhoto(String photoId, String imageUrl) async {
    if (_currentUserUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to delete photos.')),
      );
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Photo?'),
        content: const Text('Are you sure you want to delete this photo? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _dbHelper.deleteUserPhoto(_currentUserUid!, photoId, imageUrl);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo deleted successfully!')),
          );
        }
      } catch (e) {
        print('Error deleting photo: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete photo: ${e.toString()}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'My Gallery',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPhoto,
        label: const Text('Add Photo', style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.add_a_photo, color: Colors.white),
        backgroundColor: Colors.deepOrangeAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black, Colors.black87], // Dark gradient background
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _currentUserUid == null
            ? const Center(child: CircularProgressIndicator(color: Colors.deepOrangeAccent))
            : StreamBuilder<List<UserPhoto>>(
                stream: _dbHelper.getUserPhotosStream(_currentUserUid!),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.deepOrangeAccent));
                  }
                  if (snapshot.hasError) {
                    print('Gallery Stream Error: ${snapshot.error}');
                    return Center(child: Text('Error loading photos: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_library_outlined, size: 80, color: Colors.white38),
                          const SizedBox(height: 20),
                          const Text(
                            'Your gallery is empty!',
                            style: TextStyle(fontSize: 20, color: Colors.white70),
                            textAlign: TextAlign.center,
                          ),
                          const Text(
                            'Tap the + button to add your first progress photo.',
                            style: TextStyle(fontSize: 14, color: Colors.white54),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  final photos = snapshot.data!;
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 100, 16, 16), // Adjusted top padding for app bar
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, // 2 photos per row
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.0, // Square photos
                    ),
                    itemCount: photos.length,
                    itemBuilder: (context, index) {
                      final photo = photos[index];
                      return GestureDetector(
                        onLongPress: () => _deletePhoto(photo.id, photo.imageUrl), // Long press to delete
                        onTap: () {
                          // Optionally, view full-screen image
                          showDialog(
                            context: context,
                            builder: (ctx) => Dialog(
                              backgroundColor: Colors.transparent,
                              child: Stack(
                                children: [
                                  Center(
                                    child: Image.network(
                                      photo.imageUrl,
                                      fit: BoxFit.contain,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return Center(
                                          child: CircularProgressIndicator(
                                            value: loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!,
                                            color: Colors.deepOrangeAccent,
                                          ),
                                        );
                                      },
                                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.red, size: 80),
                                    ),
                                  ),
                                  Positioned(
                                    top: 10,
                                    right: 10,
                                    child: IconButton(
                                      icon: const Icon(Icons.close, color: Colors.white, size: 30),
                                      onPressed: () => Navigator.of(ctx).pop(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        child: Card(
                          clipBehavior: Clip.antiAlias, // Ensures image respects card border radius
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: photos.indexOf(photo) == 0 ? Colors.deepOrangeAccent : Colors.white12, // Orange border for the latest photo
                              width: 2,
                            ),
                          ),
                          color: Colors.transparent, // Make card background transparent for image
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                photo.imageUrl,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!,
                                      color: Colors.deepOrangeAccent,
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.red, size: 40),
                              ),
                              Positioned.fill(
                                child: Container(
                                  color: Colors.black.withOpacity(0.4), // Dim overlay
                                ),
                              ),
                              Align(
                                alignment: Alignment.bottomLeft,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    DateFormat('MMM d, yyyy').format(photo.timestamp.toDate()),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      shadows: [
                                        Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black),
                                      ],
                                    ),
                                  ),
                                ),
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
    );
  }
}
