import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../theme.dart';
import 'format.dart';

class ChartPoint {
  const ChartPoint({required this.date, required this.value});

  final DateTime date;
  final double value;
}

class TrainingLineChart extends StatelessWidget {
  const TrainingLineChart({
    super.key,
    required this.points,
    required this.unit,
    this.color = ember,
    this.height = 130,
  });

  final List<ChartPoint> points;
  final String unit;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'No data yet',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: muted),
          ),
        ),
      );
    }
    final maxValue = points.map((point) => point.value).reduce(math.max);
    final minValue = points.map((point) => point.value).reduce(math.min);
    return Semantics(
      label:
          'Chart of ${points.length} sessions from ${_value(minValue)} to '
          '${_value(maxValue)} $unit',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _value(maxValue),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: cream,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: muted),
              ),
              const Spacer(),
              Text(
                '${points.length} ${points.length == 1 ? 'session' : 'sessions'}',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: height,
            width: double.infinity,
            child: CustomPaint(
              painter: _LinePainter(
                points: points,
                minValue: minValue,
                maxValue: maxValue,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                formatDate(points.first.date),
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: muted, fontSize: 9),
              ),
              const Spacer(),
              Text(
                formatDate(points.last.date),
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: muted, fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class TrainingSparkline extends StatelessWidget {
  const TrainingSparkline({
    super.key,
    required this.values,
    this.color = ember,
    this.height = 34,
  });

  final List<double> values;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return SizedBox(height: height);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparkPainter(values: values, color: color),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.points,
    required this.minValue,
    required this.maxValue,
    required this.color,
  });

  final List<ChartPoint> points;
  final double minValue;
  final double maxValue;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = hairline
      ..strokeWidth = 1;
    for (var index = 0; index <= 2; index++) {
      final y = size.height * index / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (points.isEmpty) return;
    final range = math.max(0.0001, maxValue - minValue);
    final top = 8.0;
    final bottom = size.height - 8;
    final left = 3.0;
    final right = size.width - 3;
    Offset offsetFor(int index) {
      final x = points.length == 1
          ? (left + right) / 2
          : left + (right - left) * index / (points.length - 1);
      final ratio = (points[index].value - minValue) / range;
      final y = bottom - (bottom - top) * ratio;
      return Offset(x, y);
    }

    final line = Path()..moveTo(offsetFor(0).dx, offsetFor(0).dy);
    for (var index = 1; index < points.length; index++) {
      line.lineTo(offsetFor(index).dx, offsetFor(index).dy);
    }
    final fill = Path.from(line)
      ..lineTo(offsetFor(points.length - 1).dx, size.height)
      ..lineTo(offsetFor(0).dx, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.22), Colors.transparent],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    if (points.length <= 24) {
      final dot = Paint()..color = color;
      final ring = Paint()..color = panelHigh;
      for (var index = 0; index < points.length; index++) {
        final offset = offsetFor(index);
        canvas.drawCircle(offset, 3.4, ring);
        canvas.drawCircle(offset, 2.1, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.minValue != minValue ||
      oldDelegate.maxValue != maxValue ||
      oldDelegate.color != color;
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final min = values.reduce(math.min);
    final max = values.reduce(math.max);
    final range = math.max(0.0001, max - min);
    Offset pointAt(int index) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * index / (values.length - 1);
      final y =
          size.height - 3 - (size.height - 6) * (values[index] - min) / range;
      return Offset(x, y);
    }

    final path = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var index = 1; index < values.length; index++) {
      path.lineTo(pointAt(index).dx, pointAt(index).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    final last = pointAt(values.length - 1);
    canvas.drawCircle(last, 2.4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}

String _value(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1);
}
