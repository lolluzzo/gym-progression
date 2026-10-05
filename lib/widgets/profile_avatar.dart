import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gym_progression/models/profile.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.profile, this.radius = 20});

  final Profile profile;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final imagePath = profile.imagePath;
    final name = profile.name.trim();

    return CircleAvatar(
      radius: radius,
      backgroundImage: imagePath == null ? null : FileImage(File(imagePath)),
      child: imagePath == null
          ? Text(
              name.isEmpty ? '?' : name.characters.first.toUpperCase(),
              style: TextStyle(fontSize: radius * 0.8),
            )
          : null,
    );
  }
}
