import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/services/ad_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/animated_card.dart';
import '../../../settings/presentation/providers/ad_provider.dart';
import '../../../settings/presentation/providers/app_settings_provider.dart';
import '../providers/quiz_schedule_provider.dart';

// Helper to safely parse hex colors from JSON
Color _parseHexColor(String hex) {
  try {
    final cleanHex = hex.replaceAll('#', '');
    if (cleanHex.length == 6) {
      return Color(int.parse('FF$cleanHex', radix: 16));
    }
    return Color(int.parse(cleanHex, radix: 16));
  } catch (_) {
    return Colors.grey;
  }
}

// Custom Painter to draw circles split into sections
class CirclePatternPainter extends CustomPainter {
  final int sections;
  final List<Color> sliceColors;
  final int? questionMarkIndex;
  final int? dotIndex;

  CirclePatternPainter({
    required this.sections,
    required this.sliceColors,
    this.questionMarkIndex,
    this.dotIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final sweepAngle = (2 * math.pi) / sections;
    final paint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = Colors.grey.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (int i = 0; i < sections; i++) {
      paint.color = i < sliceColors.length ? sliceColors[i] : Colors.white;
      final startAngle = -math.pi / 2 + i * sweepAngle;

      canvas.drawArc(rect, startAngle, sweepAngle, true, paint);
      canvas.drawArc(rect, startAngle, sweepAngle, true, borderPaint);

      if (questionMarkIndex == i) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: '?',
            style: GoogleFonts.outfit(
              fontSize: size.width > 50 ? 24 : 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final angle = startAngle + sweepAngle / 2;
        final labelRadius = radius * 0.55;
        final x = center.dx + labelRadius * math.cos(angle) - textPainter.width / 2;
        final y = center.dy + labelRadius * math.sin(angle) - textPainter.height / 2;
        textPainter.paint(canvas, Offset(x, y));
      }

      if (dotIndex == i) {
        final dotPaint = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.fill;
        final angle = startAngle + sweepAngle / 2;
        final dotRadius = radius * 0.55;
        final x = center.dx + dotRadius * math.cos(angle);
        final y = center.dy + dotRadius * math.sin(angle);
        canvas.drawCircle(Offset(x, y), size.width > 50 ? 8 : 4, dotPaint);
      }
    }

    canvas.drawCircle(center, radius, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class CirclePatternWidget extends StatelessWidget {
  final double size;
  final int sections;
  final List<Color> sliceColors;
  final int? questionMarkIndex;
  final int? dotIndex;

  const CirclePatternWidget({
    super.key,
    required this.size,
    required this.sections,
    required this.sliceColors,
    this.questionMarkIndex,
    this.dotIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: CustomPaint(
        size: Size(size, size),
        painter: CirclePatternPainter(
          sections: sections,
          sliceColors: sliceColors,
          questionMarkIndex: questionMarkIndex,
          dotIndex: dotIndex,
        ),
      ),
    );
  }
}

// 3x3 Matrix cell painter supporting Circles, Triangles, Houses, Stars, Squares
class MatrixCellPainter extends CustomPainter {
  final String shapeType;
  final Map<String, dynamic> attributes;
  final bool isDark;

  MatrixCellPainter({
    required this.shapeType,
    required this.attributes,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = isDark ? Colors.white10 : Colors.black.withOpacity(0.03)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = isDark ? Colors.white60 : Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final center = Offset(size.width / 2, size.height / 2);

    if (shapeType == 'circle') {
      final radius = size.width / 2;

      // concentric rings
      if (attributes.containsKey('rings')) {
        final count = attributes['rings'] as int;
        final step = radius / count;
        for (int i = 1; i <= count; i++) {
          canvas.drawCircle(center, i * step, strokePaint);
        }
        return;
      }

      // sliced / colored sections
      final sections = attributes['sections'] as int? ?? 4;
      final rawColors = attributes['sliceColors'] as List<dynamic>?;
      final sweepAngle = (2 * math.pi) / sections;
      final rect = Rect.fromCircle(center: center, radius: radius);

      for (int i = 0; i < sections; i++) {
        final paint = Paint()..style = PaintingStyle.fill;
        if (rawColors != null && i < rawColors.length) {
          paint.color = _parseHexColor(rawColors[i] as String);
        } else {
          paint.color = Colors.white;
        }
        final startAngle = -math.pi / 2 + i * sweepAngle;
        canvas.drawArc(rect, startAngle, sweepAngle, true, paint);
        canvas.drawArc(rect, startAngle, sweepAngle, true, strokePaint);
      }

      if (attributes.containsKey('innerShape')) {
        canvas.drawCircle(center, radius, strokePaint);
        _drawInnerShape(canvas, center, radius * 0.5, attributes['innerShape'] as String, strokePaint);
      } else {
        canvas.drawCircle(center, radius, strokePaint);
      }
    } else if (shapeType == 'triangle') {
      final dir = attributes['direction'] as String? ?? 'up';
      final path = Path();
      if (dir == 'up') {
        path.moveTo(size.width / 2, 0);
        path.lineTo(size.width, size.height);
        path.lineTo(0, size.height);
      } else if (dir == 'right') {
        path.moveTo(0, 0);
        path.lineTo(size.width, size.height / 2);
        path.lineTo(0, size.height);
      } else if (dir == 'down') {
        path.moveTo(0, 0);
        path.lineTo(size.width, 0);
        path.lineTo(size.width / 2, size.height);
      } else { // 'left'
        path.moveTo(size.width, 0);
        path.lineTo(0, size.height / 2);
        path.lineTo(size.width, size.height);
      }
      path.close();
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, strokePaint);

      if (attributes.containsKey('dots')) {
        final dotCount = attributes['dots'] as int;
        _drawDots(canvas, center, size.width * 0.15, dotCount);
      }
    } else if (shapeType == 'house') {
      final roof = attributes['roof'] as String? ?? 'triangular';
      final door = attributes['door'] as String? ?? 'rectangular';
      final colorStr = attributes['color'] as String? ?? '#FFEF4444';
      final houseColor = _parseHexColor(colorStr);

      final bodyPaint = Paint()..color = houseColor..style = PaintingStyle.fill;
      final bodyRect = Rect.fromLTRB(size.width * 0.15, size.height * 0.4, size.width * 0.85, size.height * 0.95);
      canvas.drawRect(bodyRect, bodyPaint);
      canvas.drawRect(bodyRect, strokePaint);

      final roofPaint = Paint()..color = Colors.brown..style = PaintingStyle.fill;
      final roofPath = Path();
      if (roof == 'triangular') {
        roofPath.moveTo(size.width / 2, size.height * 0.05);
        roofPath.lineTo(size.width * 0.9, size.height * 0.4);
        roofPath.lineTo(size.width * 0.1, size.height * 0.4);
      } else if (roof == 'flat') {
        roofPath.moveTo(size.width * 0.15, size.height * 0.25);
        roofPath.lineTo(size.width * 0.85, size.height * 0.25);
        roofPath.lineTo(size.width * 0.85, size.height * 0.4);
        roofPath.lineTo(size.width * 0.15, size.height * 0.4);
      } else { // 'curved'
        roofPath.moveTo(size.width * 0.1, size.height * 0.4);
        roofPath.quadraticBezierTo(size.width / 2, size.height * 0.05, size.width * 0.9, size.height * 0.4);
      }
      roofPath.close();
      canvas.drawPath(roofPath, roofPaint);
      canvas.drawPath(roofPath, strokePaint);

      final doorPaint = Paint()..color = isDark ? Colors.white38 : Colors.black87..style = PaintingStyle.fill;
      final doorRect = Rect.fromLTRB(size.width * 0.4, size.height * 0.65, size.width * 0.6, size.height * 0.95);
      if (door == 'rectangular' || door == 'square') {
        canvas.drawRect(doorRect, doorPaint);
        canvas.drawRect(doorRect, strokePaint);
      } else { // 'arched'
        final doorPath = Path();
        doorPath.moveTo(size.width * 0.4, size.height * 0.95);
        doorPath.lineTo(size.width * 0.4, size.height * 0.75);
        doorPath.arcToPoint(Offset(size.width * 0.6, size.height * 0.75), radius: Radius.circular(size.width * 0.15), clockwise: true);
        doorPath.lineTo(size.width * 0.6, size.height * 0.95);
        doorPath.close();
        canvas.drawPath(doorPath, doorPaint);
        canvas.drawPath(doorPath, strokePaint);
      }
    } else if (shapeType == 'star') {
      final points = attributes['points'] as int? ?? 5;
      final outerRadius = size.width / 2;
      final innerRadius = size.width / 4;
      final path = Path();
      final double angleStep = math.pi / points;

      for (int i = 0; i < 2 * points; i++) {
        final double r = i.isEven ? outerRadius : innerRadius;
        final double angle = -math.pi / 2 + i * angleStep;
        final x = center.dx + r * math.cos(angle);
        final y = center.dy + r * math.sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, strokePaint);
    } else if (shapeType == 'square') {
      final rect = Rect.fromLTWH(0, 0, size.width, size.height);
      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect, strokePaint);

      if (attributes.containsKey('innerShape')) {
        _drawInnerShape(canvas, center, size.width * 0.25, attributes['innerShape'] as String, strokePaint);
      } else if (attributes.containsKey('lines')) {
        final lines = attributes['lines'] as int;
        final direction = attributes['direction'] as String? ?? 'vertical';
        if (direction == 'vertical') {
          final double step = size.width / (lines + 1);
          for (int i = 1; i <= lines; i++) {
            canvas.drawLine(Offset(i * step, 0), Offset(i * step, size.height), strokePaint);
          }
        } else if (direction == 'horizontal') {
          final double step = size.height / (lines + 1);
          for (int i = 1; i <= lines; i++) {
            canvas.drawLine(Offset(0, i * step), Offset(size.width, i * step), strokePaint);
          }
        } else { // 'diagonal'
          final double step = size.width / (lines + 1);
          for (int i = 1; i <= lines; i++) {
            canvas.drawLine(Offset(i * step, 0), Offset(0, i * step), strokePaint);
          }
        }
      }
    }
  }

  void _drawInnerShape(Canvas canvas, Offset center, double sizeVal, String shape, Paint paint) {
    if (shape == 'square') {
      final rect = Rect.fromCenter(center: center, width: sizeVal * 2, height: sizeVal * 2);
      canvas.drawRect(rect, paint);
    } else if (shape == 'triangle') {
      final path = Path();
      path.moveTo(center.dx, center.dy - sizeVal);
      path.lineTo(center.dx + sizeVal, center.dy + sizeVal);
      path.lineTo(center.dx - sizeVal, center.dy + sizeVal);
      path.close();
      canvas.drawPath(path, paint);
    } else if (shape == 'circle') {
      canvas.drawCircle(center, sizeVal, paint);
    }
  }

  void _drawDots(Canvas canvas, Offset center, double dotSize, int count) {
    final paint = Paint()..color = isDark ? Colors.white70 : Colors.black87..style = PaintingStyle.fill;
    if (count == 1) {
      canvas.drawCircle(center, 4, paint);
    } else if (count == 2) {
      canvas.drawCircle(Offset(center.dx - 6, center.dy), 3, paint);
      canvas.drawCircle(Offset(center.dx + 6, center.dy), 3, paint);
    } else if (count == 3) {
      canvas.drawCircle(Offset(center.dx, center.dy - 6), 3, paint);
      canvas.drawCircle(Offset(center.dx - 6, center.dy + 6), 3, paint);
      canvas.drawCircle(Offset(center.dx + 6, center.dy + 6), 3, paint);
    } else if (count == 4) {
      canvas.drawCircle(Offset(center.dx - 6, center.dy - 6), 3, paint);
      canvas.drawCircle(Offset(center.dx + 6, center.dy - 6), 3, paint);
      canvas.drawCircle(Offset(center.dx - 6, center.dy + 6), 3, paint);
      canvas.drawCircle(Offset(center.dx + 6, center.dy + 6), 3, paint);
    } else {
      canvas.drawCircle(center, 3, paint);
      canvas.drawCircle(Offset(center.dx - 8, center.dy - 8), 3, paint);
      canvas.drawCircle(Offset(center.dx + 8, center.dy - 8), 3, paint);
      canvas.drawCircle(Offset(center.dx - 8, center.dy + 8), 3, paint);
      canvas.drawCircle(Offset(center.dx + 8, center.dy + 8), 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Matrix cell widget rendering either shapes or a question mark
class MatrixCellWidget extends StatelessWidget {
  final String shapeType;
  final Map<String, dynamic> attributes;
  final double size;

  const MatrixCellWidget({
    super.key,
    required this.shapeType,
    required this.attributes,
    this.size = 50,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (shapeType == 'question') {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.05),
          border: Border.all(color: Colors.red, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            '?',
            style: GoogleFonts.outfit(
              fontSize: size * 0.45,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      child: CustomPaint(
        size: Size(size, size),
        painter: MatrixCellPainter(
          shapeType: shapeType,
          attributes: attributes,
          isDark: isDark,
        ),
      ),
    );
  }
}

// Grid representing the 3x3 progressive matrix puzzle
class PatternMatrixGridWidget extends StatelessWidget {
  final List<dynamic> matrixData;

  const PatternMatrixGridWidget({
    super.key,
    required this.matrixData,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 250,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        children: List.generate(9, (index) {
          if (index >= matrixData.length) return const SizedBox.shrink();
          final cell = matrixData[index];
          return Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.bgDark : AppColors.bgLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
            ),
            padding: const EdgeInsets.all(8),
            child: MatrixCellWidget(
              shapeType: cell['shapeType'] as String,
              attributes: (cell['attributes'] as Map<String, dynamic>?) ?? const {},
              size: 46,
            ),
          );
        }),
      ),
    );
  }
}

// 1. Fixed Sliding Window Visualizer
class SlidingWindowVisualizer extends StatefulWidget {
  final List<dynamic> array;
  final int windowSize;
  final Color themeColor;

  const SlidingWindowVisualizer({
    super.key,
    required this.array,
    required this.windowSize,
    required this.themeColor,
  });

  @override
  State<SlidingWindowVisualizer> createState() => _SlidingWindowVisualizerState();
}

class _SlidingWindowVisualizerState extends State<SlidingWindowVisualizer> {
  int _startIndex = 0;

  @override
  void didUpdateWidget(covariant SlidingWindowVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.array.length != oldWidget.array.length || widget.windowSize != oldWidget.windowSize) {
      _startIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<int> elements = widget.array.map((e) => e as int).toList();
    final int safeWindowSize = math.min(widget.windowSize, elements.length);
    final int endIdx = _startIndex + safeWindowSize;

    int currentSum = 0;
    if (elements.isNotEmpty) {
      for (int i = _startIndex; i < math.min(endIdx, elements.length); i++) {
        currentSum += elements[i];
      }
    }

    final maxPossibleIndex = elements.length - safeWindowSize;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'FIXED SLIDING WINDOW VISUALIZER (MAX SUM OF SIZE K)',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: widget.themeColor,
            ),
          ),
          const SizedBox(height: 16),
          if (elements.isEmpty)
            const Text('Enter elements in the controller to visualize')
          else ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(elements.length, (index) {
                  final inWindow = index >= _startIndex && index < endIdx;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: inWindow
                          ? widget.themeColor.withOpacity(0.12)
                          : (isDark ? AppColors.bgDark : AppColors.bgLight),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: inWindow ? widget.themeColor : (isDark ? AppColors.borderDark : AppColors.borderLight),
                        width: inWindow ? 2.5 : 1.0,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${elements[index]}',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: inWindow ? FontWeight.bold : FontWeight.normal,
                          color: inWindow
                              ? widget.themeColor
                              : (isDark ? Colors.white70 : AppColors.textPrimaryLight),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.bgDark : AppColors.bgLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Window Elements:',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        '${elements.sublist(_startIndex, endIdx)}',
                        style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Window Sum (K=$safeWindowSize):',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        '${elements.sublist(_startIndex, endIdx).join(' + ')} = $currentSum',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: widget.themeColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                  onPressed: _startIndex > 0
                      ? () {
                          setState(() {
                            _startIndex--;
                          });
                        }
                      : null,
                ),
                Text(
                  'Window Position: ${_startIndex + 1} of ${maxPossibleIndex + 1}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                  onPressed: _startIndex < maxPossibleIndex
                      ? () {
                          setState(() {
                            _startIndex++;
                          });
                        }
                      : null,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// 2. Variable Sliding Window Visualizer
class VariableWindowVisualizer extends StatefulWidget {
  final List<dynamic> array;
  final int targetSum;
  final Color themeColor;

  const VariableWindowVisualizer({
    super.key,
    required this.array,
    required this.targetSum,
    required this.themeColor,
  });

  @override
  State<VariableWindowVisualizer> createState() => _VariableWindowVisualizerState();
}

class _VariableWindowVisualizerState extends State<VariableWindowVisualizer> {
  int _left = 0;
  int _right = 0;
  int _currentSum = 0;
  int _minLen = 999999;
  List<int> _elements = [];
  bool _isFinished = false;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(covariant VariableWindowVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reset();
  }

  void _reset() {
    setState(() {
      _elements = widget.array.map((e) => e as int).toList();
      _left = 0;
      _right = 0;
      _currentSum = 0;
      _minLen = 999999;
      _isFinished = false;
    });
  }

  void _stepForward() {
    if (_isFinished || _elements.isEmpty) return;

    setState(() {
      if (_currentSum < widget.targetSum) {
        if (_right < _elements.length) {
          _currentSum += _elements[_right];
          _right++;
        } else {
          _isFinished = true;
        }
      } else {
        final currentLen = _right - _left;
        if (currentLen < _minLen) {
          _minLen = currentLen;
        }
        _currentSum -= _elements[_left];
        _left++;
      }

      if (_currentSum < widget.targetSum && _right >= _elements.length) {
        _isFinished = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final int minLenVal = _minLen == 999999 ? 0 : _minLen;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'VARIABLE SLIDING WINDOW VISUALIZER (SUM >= TARGET)',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: widget.themeColor,
            ),
          ),
          const SizedBox(height: 16),
          if (_elements.isEmpty)
            const Text('Enter elements in the controller')
          else ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_elements.length, (index) {
                  final inWindow = index >= _left && index < _right;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: inWindow
                          ? widget.themeColor.withOpacity(0.12)
                          : (isDark ? AppColors.bgDark : AppColors.bgLight),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: inWindow ? widget.themeColor : (isDark ? AppColors.borderDark : AppColors.borderLight),
                        width: inWindow ? 2.5 : 1.0,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${_elements[index]}',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: inWindow ? FontWeight.bold : FontWeight.normal,
                          color: inWindow
                              ? widget.themeColor
                              : (isDark ? Colors.white70 : AppColors.textPrimaryLight),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_elements.length, (index) {
                final isL = index == _left;
                final isR = index == _right;

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 44,
                  alignment: Alignment.center,
                  child: isL && isR
                      ? Text('L,R', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: widget.themeColor))
                      : isL
                          ? Text('L (Left)', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: widget.themeColor))
                          : isR
                              ? Text('R (Right)', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey))
                              : const SizedBox(height: 12),
                );
              }),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.bgDark : AppColors.bgLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Active Window:', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                      Text(
                        '${_elements.sublist(_left, _right)}',
                        style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Window Sum:', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                      Text(
                        '$_currentSum (Target: ${widget.targetSum})',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _currentSum >= widget.targetSum ? AppColors.success : widget.themeColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Min Subarray Length found:', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                      Text(
                        minLenVal == 0 ? 'None' : '$minLenVal',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Reset'),
                  onPressed: _reset,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                  label: const Text('Next Step'),
                  onPressed: !_isFinished ? _stepForward : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.themeColor,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// 3. Opposite Ends Two Pointers Visualizer
class TwoPointersVisualizer extends StatefulWidget {
  final List<dynamic> array;
  final int targetSum;
  final Color themeColor;

  const TwoPointersVisualizer({
    super.key,
    required this.array,
    required this.targetSum,
    required this.themeColor,
  });

  @override
  State<TwoPointersVisualizer> createState() => _TwoPointersVisualizerState();
}

class _TwoPointersVisualizerState extends State<TwoPointersVisualizer> {
  int _leftIndex = 0;
  int _rightIndex = 0;
  bool _isFinished = false;

  @override
  void initState() {
    super.initState();
    _resetPointers();
  }

  @override
  void didUpdateWidget(covariant TwoPointersVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _resetPointers();
  }

  void _resetPointers() {
    _leftIndex = 0;
    _rightIndex = widget.array.isNotEmpty ? widget.array.length - 1 : 0;
    _isFinished = false;
  }

  void _stepForward() {
    if (_isFinished || widget.array.isEmpty) return;

    final List<int> elements = widget.array.map((e) => e as int).toList();
    final int currentSum = elements[_leftIndex] + elements[_rightIndex];

    setState(() {
      if (currentSum == widget.targetSum) {
        _isFinished = true;
      } else if (currentSum > widget.targetSum) {
        if (_rightIndex > _leftIndex + 1) {
          _rightIndex--;
        } else {
          _isFinished = true;
        }
      } else {
        if (_leftIndex < _rightIndex - 1) {
          _leftIndex++;
        } else {
          _isFinished = true;
        }
      }
    });
  }

  void _reset() {
    setState(() {
      _resetPointers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final List<int> elements = widget.array.map((e) => e as int).toList();

    if (elements.isEmpty) {
      return const Center(child: Text('Enter elements in the controller'));
    }

    if (_leftIndex >= elements.length) _leftIndex = 0;
    if (_rightIndex >= elements.length) _rightIndex = elements.length - 1;

    final int currentSum = elements[_leftIndex] + elements[_rightIndex];
    final bool found = currentSum == widget.targetSum;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'OPPOSITE POINTERS VISUALIZER (TWO SUM SORTED)',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: widget.themeColor,
            ),
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(elements.length, (index) {
                  final isLeft = index == _leftIndex;
                  final isRight = index == _rightIndex;
                  final isActive = isLeft || isRight;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isActive
                          ? widget.themeColor.withOpacity(0.12)
                          : (isDark ? AppColors.bgDark : AppColors.bgLight),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isActive 
                            ? (found ? AppColors.success : widget.themeColor) 
                            : (isDark ? AppColors.borderDark : AppColors.borderLight),
                        width: isActive ? 2.5 : 1.0,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${elements[index]}',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          color: isActive
                              ? (found ? AppColors.success : widget.themeColor)
                              : (isDark ? Colors.white70 : AppColors.textPrimaryLight),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(elements.length, (index) {
                  final isLeft = index == _leftIndex;
                  final isRight = index == _rightIndex;

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 44,
                    alignment: Alignment.center,
                    child: isLeft && isRight
                        ? Text(
                            'L,R',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: widget.themeColor,
                            ),
                          )
                        : isLeft
                            ? Text(
                                'L (Left)',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: widget.themeColor,
                                ),
                              )
                            : isRight
                                ? Text(
                                    'R (Right)',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: widget.themeColor,
                                    ),
                                  )
                                : const SizedBox(height: 12),
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.bgDark : AppColors.bgLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pointers State:',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      'L index: $_leftIndex (Val: ${elements[_leftIndex]}), R index: $_rightIndex (Val: ${elements[_rightIndex]})',
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Current Sum:',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      '${elements[_leftIndex]} + ${elements[_rightIndex]} = $currentSum (Target: ${widget.targetSum})',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: found
                            ? AppColors.success
                            : (currentSum > widget.targetSum ? AppColors.error : widget.themeColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Reset'),
                onPressed: _reset,
              ),
              if (found)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Target Found! 🎉',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                  label: const Text('Next Step'),
                  onPressed: _leftIndex < _rightIndex ? _stepForward : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.themeColor,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// 4. Fast & Slow Pointers Visualizer (Cycle detection)
class FastSlowVisualizer extends StatefulWidget {
  final int nodeCount;
  final int cycleStart;
  final Color themeColor;

  const FastSlowVisualizer({
    super.key,
    required this.nodeCount,
    required this.cycleStart,
    required this.themeColor,
  });

  @override
  State<FastSlowVisualizer> createState() => _FastSlowVisualizerState();
}

class _FastSlowVisualizerState extends State<FastSlowVisualizer> {
  int _slow = 0;
  int _fast = 0;
  int _steps = 0;
  bool _met = false;
  bool _isFinished = false;

  late Map<int, int> _connections;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(covariant FastSlowVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reset();
  }

  void _reset() {
    _connections = {};
    for (int i = 0; i < widget.nodeCount - 1; i++) {
      _connections[i] = i + 1;
    }
    final loopBackIdx = math.max(0, math.min(widget.cycleStart - 1, widget.nodeCount - 1));
    _connections[widget.nodeCount - 1] = loopBackIdx;

    setState(() {
      _slow = 0;
      _fast = 0;
      _steps = 0;
      _met = false;
      _isFinished = false;
    });
  }

  void _stepForward() {
    if (_isFinished) return;

    setState(() {
      _slow = _connections[_slow] ?? 0;
      final fastMid = _connections[_fast] ?? 0;
      _fast = _connections[fastMid] ?? 0;
      _steps++;

      if (_slow == _fast) {
        _met = true;
        _isFinished = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'FAST & SLOW POINTERS (CYCLE DETECTION)',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: widget.themeColor,
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.nodeCount, (index) {
                final isSlow = index == _slow;
                final isFast = index == _fast;
                final hasCycle = index == widget.cycleStart - 1;

                return Row(
                  children: [
                    Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (isSlow && isFast)
                                ? Colors.purple.withOpacity(0.12)
                                : isSlow
                                    ? Colors.orange.withOpacity(0.12)
                                    : isFast
                                        ? Colors.blue.withOpacity(0.12)
                                        : (isDark ? AppColors.bgDark : AppColors.bgLight),
                            border: Border.all(
                              color: (isSlow && isFast)
                                  ? Colors.purple
                                  : isSlow
                                      ? Colors.orange
                                      : isFast
                                          ? Colors.blue
                                          : (isDark ? AppColors.borderDark : AppColors.borderLight),
                              width: (isSlow || isFast) ? 2.5 : 1.0,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 14,
                          child: (isSlow && isFast)
                              ? Text('S,F', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple))
                              : isSlow
                                  ? Text('Slow', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange))
                                  : isFast
                                      ? Text('Fast', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blue))
                                      : hasCycle
                                          ? const Icon(Icons.loop_rounded, size: 12, color: Colors.grey)
                                          : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                    if (index < widget.nodeCount - 1)
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: isDark ? Colors.white30 : Colors.black26,
                      ),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cycle connects Node ${widget.nodeCount} back to Node ${widget.cycleStart}',
            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.bgDark : AppColors.bgLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Steps Count:', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                    Text('$_steps steps', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Slow Pointer index (1x speed):', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                    Text('Node ${_slow + 1}', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orange)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Fast Pointer index (2x speed):', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                    Text('Node ${_fast + 1}', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Reset'),
                onPressed: _reset,
              ),
              if (_met)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.flash_on_rounded, color: Colors.purple, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Pointers Met at Node ${_slow + 1}! Loop Detected 🏁',
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple),
                      ),
                    ],
                  ),
                )
              else
                ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                  label: const Text('Next Step'),
                  onPressed: !_isFinished ? _stepForward : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.themeColor,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// 5. Reader & Writer Pointers (Remove Duplicates)
class ReaderWriterVisualizer extends StatefulWidget {
  final List<dynamic> array;
  final Color themeColor;

  const ReaderWriterVisualizer({
    super.key,
    required this.array,
    required this.themeColor,
  });

  @override
  State<ReaderWriterVisualizer> createState() => _ReaderWriterVisualizerState();
}

class _ReaderWriterVisualizerState extends State<ReaderWriterVisualizer> {
  int _writer = 1;
  int _reader = 1;
  List<int> _elements = [];
  List<bool> _modified = [];
  bool _isFinished = false;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(covariant ReaderWriterVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reset();
  }

  void _reset() {
    setState(() {
      _elements = widget.array.map((e) => e as int).toList();
      _modified = List.filled(_elements.length, false);
      _writer = 1;
      _reader = 1;
      _isFinished = false;
    });
  }

  void _stepForward() {
    if (_isFinished || _elements.isEmpty) return;

    setState(() {
      if (_reader < _elements.length) {
        if (_elements[_reader] != _elements[_writer - 1]) {
          _elements[_writer] = _elements[_reader];
          _modified[_writer] = true;
          _writer++;
        }
        _reader++;
      }

      if (_reader >= _elements.length) {
        _isFinished = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'READER & WRITER POINTERS (REMOVE DUPLICATES)',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: widget.themeColor,
            ),
          ),
          const SizedBox(height: 16),
          if (_elements.isEmpty)
            const Text('Enter elements in the controller')
          else ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_elements.length, (index) {
                  final isW = index == _writer;
                  final isR = index == _reader;
                  final wasWritten = _modified[index];
                  final isDuplicateExceeded = index >= _writer && _isFinished;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDuplicateExceeded
                          ? (isDark ? Colors.grey.withOpacity(0.05) : Colors.grey.withOpacity(0.1))
                          : wasWritten
                              ? AppColors.success.withOpacity(0.12)
                              : (isDark ? AppColors.bgDark : AppColors.bgLight),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDuplicateExceeded
                            ? Colors.grey.withOpacity(0.2)
                            : isW
                                ? widget.themeColor
                                : isR
                                    ? Colors.blue
                                    : (isDark ? AppColors.borderDark : AppColors.borderLight),
                        width: (isW || isR) ? 2.5 : 1.0,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${_elements[index]}',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          decoration: isDuplicateExceeded ? TextDecoration.lineThrough : null,
                          fontWeight: (isW || isR) ? FontWeight.bold : FontWeight.normal,
                          color: isDuplicateExceeded
                              ? Colors.grey
                              : wasWritten
                                  ? AppColors.success
                                  : (isDark ? Colors.white70 : AppColors.textPrimaryLight),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_elements.length, (index) {
                final isW = index == _writer;
                final isR = index == _reader;

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 44,
                  alignment: Alignment.center,
                  child: isW && isR
                      ? Text('W,R', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple))
                      : isW
                          ? Text('W (Write)', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.bold, color: widget.themeColor))
                          : isR
                              ? Text('R (Read)', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.blue))
                              : const SizedBox(height: 12),
                );
              }),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.bgDark : AppColors.bgLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Writer Pointer (tracks unique insert idx):', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                      Text('Index $_writer', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: widget.themeColor)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Reader Pointer (scanning elements):', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                      Text('Index $_reader', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Unique Count Found:', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                      Text('$_writer elements', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.success)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Reset'),
                  onPressed: _reset,
                ),
                if (_isFinished)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Completed! Unique subset length: $_writer',
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.success),
                        ),
                      ],
                    ),
                  )
                else
                  ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow_rounded, size: 16),
                    label: const Text('Next Step'),
                    onPressed: _reader < _elements.length ? _stepForward : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.themeColor,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class DetailScreen extends ConsumerStatefulWidget {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final List<dynamic> questions;

  const DetailScreen({
    super.key,
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.questions = const [],
  });

  @override
  ConsumerState<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends ConsumerState<DetailScreen> {
  // Modes: 'landing', 'sandbox', 'test'
  String _currentMode = 'landing';

  // Test mode quiz variables
  int _currentQuestionIndex = 0;
  int? _selectedOptionIndex;
  bool _hasAnswered = false;
  int _score = 0;
  bool _isQuizCompleted = false;

  // Sandbox controllers
  final TextEditingController _arrayController = TextEditingController(text: '2, 1, 5, 1, 3, 2');
  final TextEditingController _paramController = TextEditingController(text: '3');
  String _sandboxAlgo = 'fixed_window';

  // Parsed values for Sandbox
  List<int> _sandboxArray = [2, 1, 5, 1, 3, 2];
  int _sandboxParam = 3;

  // Question Timer State
  Timer? _questionTimer;
  int _questionTimerSeconds = 30;
  int _maxTimerSeconds = 30;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.id == 'dsa' ? 'landing' : 'test';
    _resetQuiz();
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
    _arrayController.dispose();
    _paramController.dispose();
    super.dispose();
  }

  void _startQuestionTimer() {
    _questionTimer?.cancel();
    final appSettings = ref.read(appSettingsProvider);
    _questionTimerSeconds = appSettings.questionTimerSeconds;
    _maxTimerSeconds = appSettings.questionTimerSeconds;
    if (_isQuizCompleted) return;
    _questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _hasAnswered) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_questionTimerSeconds > 1) {
          _questionTimerSeconds--;
        } else {
          _questionTimerSeconds = 0;
          timer.cancel();
          _onQuestionTimeout();
        }
      });
    });
  }

  void _onQuestionTimeout() {
    if (_hasAnswered) return;
    setState(() {
      _hasAnswered = true;
      HapticFeedback.vibrate();
    });
    _showExplanationBottomSheet(isTimeout: true);
  }

  void _resetQuiz() {
    setState(() {
      _currentQuestionIndex = 0;
      _selectedOptionIndex = null;
      _hasAnswered = false;
      _score = 0;
      _isQuizCompleted = false;
    });
    _startQuestionTimer();
  }

  void _submitAnswer() {
    if (_selectedOptionIndex == null || _hasAnswered) return;
    _questionTimer?.cancel();

    final question = widget.questions[_currentQuestionIndex];
    final correctIndex = question['correctOptionIndex'] as int;

    setState(() {
      _hasAnswered = true;
      if (_selectedOptionIndex == correctIndex) {
        _score++;
      } else {
        // Vibrate when user selects wrong answer
        HapticFeedback.vibrate();
      }
    });

    _showExplanationBottomSheet();
  }

  void _showExplanationBottomSheet({bool isTimeout = false}) {
    final question = widget.questions[_currentQuestionIndex];
    final correctIndex = question['correctOptionIndex'] as int;
    final isCorrect = !isTimeout && _selectedOptionIndex == correctIndex;
    final options = (question['options'] as List<dynamic>?) ?? [];
    final correctOptionText = correctIndex < options.length ? options[correctIndex].toString() : '';
    final explanation = (question['explanation'] as String?) ?? 'No detailed explanation available.';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isCorrect ? AppColors.success : AppColors.error).withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isCorrect ? Icons.check_circle_rounded : (isTimeout ? Icons.timer_off_rounded : Icons.cancel_rounded),
                        color: isCorrect ? AppColors.success : AppColors.error,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isCorrect ? 'Correct Answer!' : (isTimeout ? 'Time\'s Up!' : 'Incorrect'),
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isCorrect ? AppColors.success : AppColors.error,
                            ),
                          ),
                          Text(
                            'Correct: $correctOptionText',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'EXPLANATION',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.info,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.3,
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      explanation,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.45,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _nextQuestion();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.color,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _currentQuestionIndex + 1 == widget.questions.length
                          ? 'Finish Quiz'
                          : 'Next Question',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.white,
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
  }

  void _nextQuestion() {
    if (_currentQuestionIndex + 1 < widget.questions.length) {
      setState(() {
        _currentQuestionIndex++;
        _selectedOptionIndex = null;
        _hasAnswered = false;
      });
      _startQuestionTimer();
    } else {
      _questionTimer?.cancel();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final adState = ref.read(adProvider);
        final showAd = AppConfig.enableAds && !adState.isAdFreePurchased;

        void onQuizFinished() {
          if (!mounted) return;
          final double percent = widget.questions.isNotEmpty ? (_score / widget.questions.length) : 0.0;
          setState(() {
            _isQuizCompleted = true;
          });
          // Run clapping sound when user completes quiz successfully (score >= 50%)
          if (percent >= 0.5) {
            try {
              final player = AudioPlayer();
              player.setAsset('assets/audio/applause.wav').then((_) => player.play());
            } catch (_) {}
          }

          ref.read(quizScheduleProvider.notifier).addResult(
            TestResult(
              id: 'res-${DateTime.now().millisecondsSinceEpoch}',
              categoryTitle: widget.title,
              score: _score,
              totalQuestions: widget.questions.length,
              date: DateTime.now(),
            ),
          );
        }

        if (showAd) {
          AdService().showInterstitialAd(context, onQuizFinished);
        } else {
          onQuizFinished();
        }
      });
    }
  }

  // Parse controller data for Sandbox
  void _updateSandboxData() {
    final arrText = _arrayController.text;
    final paramText = _paramController.text;

    List<int> parsedArr = [];
    try {
      parsedArr = arrText.split(',').map((e) => int.parse(e.trim())).toList();
    } catch (_) {
      parsedArr = [];
    }

    final parsedParam = int.tryParse(paramText) ?? 3;

    setState(() {
      _sandboxArray = parsedArr;
      _sandboxParam = parsedParam;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: _buildBody(context, isDark),
    );
  }

  Widget _buildBody(BuildContext context, bool isDark) {
    switch (_currentMode) {
      case 'sandbox':
        return _buildSandboxState(context, isDark);
      case 'test':
        return widget.questions.isEmpty
            ? _buildEmptyState(context, isDark)
            : _isQuizCompleted
                ? _buildCompletionState(context, isDark)
                : _buildQuizState(context, isDark);
      case 'landing':
      default:
        return _buildLandingState(context, isDark);
    }
  }

  // Landing Page layout selection: Sandbox vs Test
  Widget _buildLandingState(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          // Category Header Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [widget.color, widget.color.withOpacity(0.75)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Icon(widget.icon, size: 56, color: Colors.white),
                const SizedBox(height: 16),
                Text(
                  widget.title,
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.description,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.95),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),

          Text(
            'CHOOSE YOUR PREFERENCE',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 16),

          // Option A: Interactive Sandbox Card
          AnimatedCard(
            delay: const Duration(milliseconds: 100),
            child: Card(
              elevation: 0,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _currentMode = 'sandbox';
                    _sandboxAlgo = 'fixed_window';
                    _arrayController.text = '2, 1, 5, 1, 3, 2';
                    _paramController.text = '3';
                    _updateSandboxData();
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.science_rounded, color: AppColors.secondary, size: 28),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Interactive Sandbox',
                              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Visualise all 5 algorithmic pointer patterns dynamically with customizable arrays.',
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Option B: Practice Test Card
          AnimatedCard(
            delay: const Duration(milliseconds: 200),
            child: Card(
              elevation: 0,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _currentMode = 'test';
                    _resetQuiz();
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.quiz_rounded, color: AppColors.primary, size: 28),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Start Graded Test',
                              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Solve ${widget.questions.length} problems with instant scoring and detailed code explanations.',
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Interactive sandbox state representation
  Widget _buildSandboxState(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Algorithm pattern selection row dropdown/chip-selector
          Text(
            'SELECT POINTER PATTERN ALGORITHM',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _sandboxAlgo,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: const [
              DropdownMenuItem(value: 'fixed_window', child: Text('Fixed Sliding Window')),
              DropdownMenuItem(value: 'variable_window', child: Text('Variable Sliding Window')),
              DropdownMenuItem(value: 'opposite_pointers', child: Text('Opposite Pointers (Two Sum)')),
              DropdownMenuItem(value: 'fast_slow', child: Text('Fast & Slow Pointers (Cycle)')),
              DropdownMenuItem(value: 'reader_writer', child: Text('Reader & Writer (Remove Duplicates)')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _sandboxAlgo = val;
                  if (val == 'fixed_window') {
                    _arrayController.text = '2, 1, 5, 1, 3, 2';
                    _paramController.text = '3';
                  } else if (val == 'variable_window') {
                    _arrayController.text = '2, 1, 5, 1, 3, 2';
                    _paramController.text = '7';
                  } else if (val == 'opposite_pointers') {
                    _arrayController.text = '2, 7, 11, 15';
                    _paramController.text = '9';
                  } else if (val == 'fast_slow') {
                    _arrayController.text = '6';
                    _paramController.text = '3';
                  } else if (val == 'reader_writer') {
                    _arrayController.text = '1, 1, 2, 2, 3';
                    _paramController.text = '';
                  }
                  _updateSandboxData();
                });
              }
            },
          ),
          const SizedBox(height: 20),

          // Render active animation visualizer
          if (_sandboxAlgo == 'fixed_window')
            SlidingWindowVisualizer(
              array: _sandboxArray,
              windowSize: _sandboxParam,
              themeColor: widget.color,
            )
          else if (_sandboxAlgo == 'variable_window')
            VariableWindowVisualizer(
              array: _sandboxArray,
              targetSum: _sandboxParam,
              themeColor: widget.color,
            )
          else if (_sandboxAlgo == 'opposite_pointers')
            TwoPointersVisualizer(
              array: _sandboxArray,
              targetSum: _sandboxParam,
              themeColor: widget.color,
            )
          else if (_sandboxAlgo == 'fast_slow')
            FastSlowVisualizer(
              nodeCount: int.tryParse(_arrayController.text) ?? 6,
              cycleStart: _sandboxParam,
              themeColor: widget.color,
            )
          else if (_sandboxAlgo == 'reader_writer')
            ReaderWriterVisualizer(
              array: _sandboxArray,
              themeColor: widget.color,
            ),

          const SizedBox(height: 20),

          // Sandbox parameters modification card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SANDBOX PARAMETERS CONTROLLER',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _arrayController,
                  decoration: InputDecoration(
                    labelText: _sandboxAlgo == 'fast_slow'
                        ? 'Total Node Count (Linked List)'
                        : 'Array Elements (comma separated)',
                    hintText: _sandboxAlgo == 'fast_slow' ? 'e.g. 6' : 'e.g. 2, 1, 5, 1, 3, 2',
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: _sandboxAlgo == 'fast_slow' ? TextInputType.number : TextInputType.text,
                ),
                if (_sandboxAlgo != 'reader_writer') ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _paramController,
                    decoration: InputDecoration(
                      labelText: _sandboxAlgo == 'fixed_window'
                          ? 'Window Size K'
                          : _sandboxAlgo == 'fast_slow'
                              ? 'Cycle Starts at Node Number'
                              : 'Target Sum',
                      hintText: _sandboxAlgo == 'fixed_window'
                          ? 'e.g. 3'
                          : _sandboxAlgo == 'fast_slow'
                              ? 'e.g. 3'
                              : 'e.g. 9',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _updateSandboxData,
                    icon: const Icon(Icons.sync_rounded),
                    label: const Text('Update & Visualize'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.color,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.help_outline_rounded, size: 64, color: widget.color.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              'No Questions Available',
              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'There are no questions configured for this category.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Builder dispatcher for circular diagrams, progressive matrices, sliding windows
  Widget _buildVisualizer(Map<String, dynamic> question, bool isDark) {
    final String visualType = (question['visualType'] ?? '') as String;

    if (visualType == 'matrix') {
      return PatternMatrixGridWidget(
        matrixData: question['matrixData'] as List<dynamic>,
      );
    }

    if (visualType == 'sliding_window') {
      return SlidingWindowVisualizer(
        array: question['arrayData'] as List<dynamic>,
        windowSize: question['windowSize'] as int,
        themeColor: widget.color,
      );
    }

    if (visualType == 'two_pointers') {
      return TwoPointersVisualizer(
        array: question['arrayData'] as List<dynamic>,
        targetSum: question['targetSum'] as int,
        themeColor: widget.color,
      );
    }

    // Default: circular diagrams
    final int sections = (question['sections'] ?? 4) as int;
    final List<dynamic>? rawSliceColors = question['sliceColors'] as List<dynamic>?;
    final List<Color> sliceColors = rawSliceColors != null
        ? rawSliceColors.map((c) => _parseHexColor(c as String)).toList()
        : const [];
    final int? questionMarkIndex = question['questionMarkIndex'] as int?;
    final int? dotIndex = question['dotIndex'] as int?;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: CirclePatternWidget(
        size: 140,
        sections: sections,
        sliceColors: sliceColors,
        questionMarkIndex: questionMarkIndex,
        dotIndex: dotIndex,
      ),
    );
  }

  Widget _buildQuizState(BuildContext context, bool isDark) {
    final question = widget.questions[_currentQuestionIndex];
    final questionText = question['questionText'] as String;
    final options = question['options'] as List<dynamic>;
    final correctIndex = question['correctOptionIndex'] as int;
    final explanation = question['explanation'] as String;

    final bool hasVisual = question['hasVisual'] == true;

    final progress = (_currentQuestionIndex + 1) / widget.questions.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'QUESTION ${_currentQuestionIndex + 1} OF ${widget.questions.length}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: widget.color,
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (_questionTimerSeconds <= 5 ? AppColors.error : AppColors.primary).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (_questionTimerSeconds <= 5 ? AppColors.error : AppColors.primary).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 13,
                          color: _questionTimerSeconds <= 5 ? AppColors.error : AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_questionTimerSeconds}s',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _questionTimerSeconds <= 5 ? AppColors.error : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Score: $_score',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _questionTimerSeconds / _maxTimerSeconds.toDouble(),
              backgroundColor: isDark ? AppColors.borderDark : AppColors.borderLight,
              valueColor: AlwaysStoppedAnimation<Color>(
                _questionTimerSeconds <= 5 ? AppColors.error : widget.color,
              ),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 32),

          // Question Card
          AnimatedCard(
            delay: const Duration(milliseconds: 50),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Text(
                questionText,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Diagram illustration if configured
          if (hasVisual)
            AnimatedCard(
              delay: const Duration(milliseconds: 100),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  child: _buildVisualizer(question, isDark),
                ),
              ),
            ),

          // Options List
          Column(
            children: List.generate(options.length, (index) {
              final optionText = options[index] as String;
              return _buildOptionButton(index, optionText, correctIndex, question, isDark);
            }),
          ),
          const SizedBox(height: 24),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildOptionButton(
      int index, String optionText, int correctIndex, Map<String, dynamic> question, bool isDark) {
    final isSelected = _selectedOptionIndex == index;
    final isCorrect = index == correctIndex;

    Color optionBgColor = isDark ? AppColors.surfaceDark : Colors.white;
    Color optionBorderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    Color textColor = isDark ? Colors.white : AppColors.textPrimaryLight;

    if (_hasAnswered) {
      if (isCorrect) {
        optionBgColor = AppColors.success.withOpacity(0.12);
        optionBorderColor = AppColors.success;
        textColor = AppColors.success;
      } else if (isSelected) {
        optionBgColor = AppColors.error.withOpacity(0.12);
        optionBorderColor = AppColors.error;
        textColor = AppColors.error;
      }
    } else if (isSelected) {
      optionBgColor = widget.color.withOpacity(0.08);
      optionBorderColor = widget.color;
      textColor = widget.color;
    }

    // Render option miniature shapes if configured
    Widget? miniDiagram;
    if (question['hasVisual'] == true && question['optionVisuals'] != null) {
      try {
        final optVisual = question['optionVisuals'][index];
        if (optVisual is Map && optVisual.containsKey('shapeType')) {
          miniDiagram = MatrixCellWidget(
            shapeType: optVisual['shapeType'] as String,
            attributes: (optVisual['attributes'] as Map<String, dynamic>?) ?? const {},
            size: 34,
          );
        } else {
          final int sections = (question['sections'] ?? 4) as int;
          if (optVisual is List) {
            final List<Color> optColors = optVisual.map((c) => _parseHexColor(c as String)).toList();
            miniDiagram = CirclePatternWidget(
              size: 34,
              sections: sections,
              sliceColors: optColors,
            );
          } else if (optVisual is Map) {
            final int? optDotIndex = optVisual['dotIndex'] as int?;
            final List<dynamic>? rawColors = question['sliceColors'] as List<dynamic>?;
            final List<Color> mainColors = rawColors != null
                ? rawColors.map((c) => _parseHexColor(c as String)).toList()
                : const [];
            miniDiagram = CirclePatternWidget(
              size: 34,
              sections: sections,
              sliceColors: mainColors,
              dotIndex: optDotIndex,
            );
          }
        }
      } catch (_) {}
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: _hasAnswered
            ? null
            : () {
                setState(() {
                  _selectedOptionIndex = index;
                });
                _submitAnswer();
              },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: optionBgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: optionBorderColor, width: isSelected || (_hasAnswered && (isCorrect || isSelected)) ? 2 : 1),
          ),
          child: Row(
            children: [
              if (miniDiagram != null) ...[
                miniDiagram,
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  optionText,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_hasAnswered) ...[
                if (isCorrect)
                  const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20)
                else if (isSelected)
                  const Icon(Icons.cancel_rounded, color: AppColors.error, size: 20)
              ] else ...[
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? widget.color : (isDark ? AppColors.borderDark : AppColors.borderLight),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: widget.color,
                            ),
                          ),
                        )
                      : null,
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletionState(BuildContext context, bool isDark) {
    final double percent = _score / widget.questions.length;
    String scoreTitle = 'Keep Practicing!';
    String scoreDesc = 'You scored $_score out of ${widget.questions.length}. Focus on analyzing the patterns and try again!';

    if (percent == 1.0) {
      scoreTitle = 'Perfect Genius! 🏆';
      scoreDesc = 'Outstanding! You correctly solved all questions. Your logic and pattern detection is flawless.';
    } else if (percent >= 0.6) {
      scoreTitle = 'Great Job! ⚡';
      scoreDesc = 'Excellent score of $_score out of ${widget.questions.length}. You have sharp analytic skills.';
    }

    return Stack(
      children: [
        if (percent >= 0.5) const Positioned.fill(child: GlitterParticleOverlay()),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
            AnimatedCard(
              delay: const Duration(milliseconds: 50),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  percent >= 0.6 ? Icons.emoji_events_rounded : Icons.psychology_rounded,
                  color: widget.color,
                  size: 80,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              scoreTitle,
              style: GoogleFonts.outfit(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                scoreDesc,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.45,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Score circular meter representation
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Final Score: ',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '$_score / ${widget.questions.length}',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: widget.color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _resetQuiz,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: BorderSide(color: widget.color, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Try Again',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: widget.color,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.color,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Back to Home',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  ],
);
  }
}

class GlitterParticleOverlay extends StatefulWidget {
  const GlitterParticleOverlay({super.key});

  @override
  State<GlitterParticleOverlay> createState() => _GlitterParticleOverlayState();
}

class _GlitterParticleOverlayState extends State<GlitterParticleOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = List.generate(50, (i) => _Particle());

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _GlitterPainter(progress: _controller.value, particles: _particles),
        );
      },
    );
  }
}

class _Particle {
  final double x = math.Random().nextDouble();
  final double speed = 0.6 + math.Random().nextDouble() * 0.7;
  final double size = 5 + math.Random().nextDouble() * 7;
  final Color color = [
    const Color(0xFFFFD60A), // Gold
    const Color(0xFF3B82F6), // Blue
    const Color(0xFFEC4899), // Pink
    const Color(0xFF10B981), // Green
    const Color(0xFFA855F7), // Purple
  ][math.Random().nextInt(5)];
  final double rotationSpeed = (math.Random().nextDouble() - 0.5) * 6;
}

class _GlitterPainter extends CustomPainter {
  final double progress;
  final List<_Particle> particles;

  _GlitterPainter({required this.progress, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final y = (progress * p.speed * size.height) % (size.height + 40) - 20;
      final x = p.x * size.width + math.sin(progress * 6 + p.x * 10) * 15;
      final opacity = (1.0 - (y / size.height)).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = p.color.withOpacity(opacity * 0.9)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * p.rotationSpeed);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _GlitterPainter oldDelegate) => true;
}
