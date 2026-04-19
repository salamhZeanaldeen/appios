import 'package:flutter/material.dart';

Widget getPlatformImage(String path, {BoxFit fit = BoxFit.contain}) {
  return Image.network(
    path,
    fit: fit,
    errorBuilder: (context, error, stackTrace) => Container(
      height: 200, 
      color: Colors.white10, 
      child: const Center(child: Icon(Icons.broken_image, color: Colors.white24))
    ),
  );
}
