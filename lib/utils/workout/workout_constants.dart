import 'package:flutter/material.dart';

/// Padding and spacing constants used throughout the workout UI
class WorkoutPadding {
  /// Standard edge padding for cards and containers
  static const double standard = 8.0;
  
  /// Small padding for tight spaces
  static const double small = 6.0;
  
  /// Horizontal padding for metric boxes
  static const double metricHorizontal = 4.0;
}

/// Vertical spacing constants
class WorkoutSpacing {
  /// Extra extra small vertical spacing
  static const double xxsmall = 4.0;
  
  /// Extra small vertical spacing
  static const double xsmall = 8.0;
  
  /// Small vertical spacing
  static const double small = 16.0;
  
  /// Medium vertical spacing
  static const double medium = 20.0;
}

/// Size constants for various UI elements
class WorkoutSizes {
  /// Width of the FTP input field
  static const double ftpFieldWidth = 80.0;
  
  /// Width of the progress indicator line
  static const double progressIndicatorWidth = 3.0;
  
  /// Height of the cadence indicator
  static const double cadenceIndicatorHeight = 20.0;

  /// Radius of the actual power dot
  static const double actualPowerDotRadius = 2.0;
}

/// Font size constants
class WorkoutFontSizes {
  /// Font size for grid labels and small text
  static const double small = 12.0;
}

/// Duration constants for animations and intervals
class WorkoutDurations {
  /// Duration for fade animations
  static const Duration fadeAnimation = Duration(milliseconds: 500);
  
  /// Interval for progress updates
  static const Duration progressUpdateInterval = Duration(milliseconds: 100);
}

/// Grid constants for the workout graph
class WorkoutGrid {
  /// Interval for power grid lines (in watts)
  static const double powerLineInterval = 100.0;
  
  /// Interval for time grid lines (in seconds)
  static const double timeLineInterval = 300.0; // 5 minutes
}

/// Opacity values for various UI elements
class WorkoutOpacity {
  /// Opacity for segment colors
  static const double segmentColor = 0.7;
  
  /// Opacity for grid lines
  static const double gridLines = 0.5;
  
  /// Opacity for segment borders
  static const double segmentBorder = 0.1;

  /// Opacity for actual power line
  static const double actualPowerLine = 0.8;
}

/// Stroke width constants for lines and borders
class WorkoutStroke {
  /// Width for standard borders
  static const double border = 1.0;
  
  /// Width for cadence indicator
  static const double cadenceIndicator = 2.0;

  /// Width for actual power line
  static const double actualPowerLine = 1.5;
}

/// FTP percentage zones for power-based coloring
class WorkoutZones {
  /// Recovery zone (< 55% FTP)
  static const double recovery = 0.55;
  
  /// Endurance zone (55-75% FTP)
  static const double endurance = 0.75;
  
  /// Tempo zone (76-87% FTP)
  static const double tempo = 0.87;
  
  /// Threshold zone (88-95% FTP)
  static const double threshold = 0.95;
  
  /// VO2Max zone (96-105% FTP)
  static const double vo2max = 1.05;
  
  /// Anaerobic zone (106-120% FTP)
  static const double anaerobic = 1.20;
  
  /// Neuromuscular zone (> 120% FTP)
  static const double neuromuscular = 1.50;
}
