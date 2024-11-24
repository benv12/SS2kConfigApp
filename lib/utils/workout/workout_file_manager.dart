import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:file_picker/file_picker.dart';
import 'workout_storage.dart';
import 'workout_controller.dart';

class WorkoutFileManager {
  static Future<String?> captureWorkoutThumbnail(GlobalKey workoutGraphKey) async {
    try {
      final boundary = workoutGraphKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      return base64Encode(byteData.buffer.asUint8List());
    } catch (e) {
      print('Error capturing thumbnail: $e');
      return null;
    }
  }

  static Future<void> pickAndLoadWorkout({
    required BuildContext context,
    required WorkoutController workoutController,
    required GlobalKey workoutGraphKey,
    required Function(String) onWorkoutLoaded,
  }) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        
        if (file.bytes == null) {
          throw Exception('Unable to read file data');
        }

        final content = String.fromCharCodes(file.bytes!);
        
        if (!content.trim().contains('<workout_file>')) {
          throw Exception('Invalid workout file format. Expected .zwo file content.');
        }
        
        // Load the workout to generate the graph, ensuring it starts in stopped state
        workoutController.loadWorkout(content, isResume: false);
        onWorkoutLoaded(content);
        
        // Wait for the graph to be rendered
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Capture thumbnail
        final thumbnail = await captureWorkoutThumbnail(workoutGraphKey);
        if (thumbnail == null) {
          throw Exception('Failed to generate workout thumbnail');
        }
        
        // Save to library
        await WorkoutStorage.saveWorkoutToLibrary(
          workoutContent: content,
          workoutName: workoutController.workoutName ?? 'Unnamed Workout',
          thumbnailData: thumbnail,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Workout imported successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading workout file: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}
