// ignore_for_file: sort_child_properties_last

import 'package:flutter/material.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      child: const Center(
          child: CircularProgressIndicator(
        color: Colors.blue,
      )),
      color: Colors.white.withOpacity(0.8),
    );
  }
}
