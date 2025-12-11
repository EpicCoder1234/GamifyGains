// lib/widgets/my_gallery_widget.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';
import '../models/user_photo.dart';
import '../screens/photo_gallery_screen.dart'; // Import your gallery screen

class MyGalleryWidget extends StatelessWidget {
  const MyGalleryWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final String? currentUserUid = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserUid == null) {
      return Container(); // Or a placeholder if no user is logged in
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: Colors.black.withOpacity(0.7), // Semi-transparent dark background
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: Colors.deepOrangeAccent, width: 2), // Orange border
      ),
      child: InkWell( // Make the entire card tappable
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const PhotoGalleryScreen()),
          );
        },
        borderRadius: BorderRadius.circular(15), // Match card border radius for InkWell ripple
        child: SizedBox(
          height: 200, // Fixed height for the widget
          child: FutureBuilder<UserPhoto?>(
            future: DatabaseHelper().getLatestUserPhoto(currentUserUid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.deepOrangeAccent));
              }
              if (snapshot.hasError) {
                print('MyGalleryWidget Error: ${snapshot.error}');
                return const Center(child: Text('Error loading photo.', style: TextStyle(color: Colors.redAccent)));
              }

              final UserPhoto? latestPhoto = snapshot.data;

              if (latestPhoto == null) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.photo_camera, size: 50, color: Colors.white38),
                    const SizedBox(height: 10),
                    const Text(
                      'No photos yet',
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const PhotoGalleryScreen()),
                        );
                      },
                      icon: const Icon(Icons.add_a_photo, color: Colors.white),
                      label: const Text('Add Photo', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                );
              } else {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect( // Clip image to card's rounded corners
                      borderRadius: BorderRadius.circular(15),
                      child: Image.network(
                        latestPhoto.imageUrl,
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
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.red, size: 60),
                      ),
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          color: Colors.black.withOpacity(0.4), // Slightly transparent black overlay
                        ),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'My Gallery',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Last updated: ${DateFormat('MMM d, yyyy').format(latestPhoto.timestamp.toDate())}; Add a new photo everyday!',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                              shadows: [
                                Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black),
                              ],
                            ),
                          ),
                          const SizedBox(height: 15),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (context) => const PhotoGalleryScreen()),
                              );
                            },
                            icon: const Icon(Icons.photo_library, color: Colors.white),
                            label: const Text('View Gallery', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepOrange, // Orange button
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }
            },
          ),
        ),
      ),
    );
  }
}
