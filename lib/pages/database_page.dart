import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import '../data/app_database.dart';

class DatabasePage extends StatefulWidget {
  const DatabasePage({super.key});

  @override
  State<DatabasePage> createState() => _DatabasePageState();
}

class _DatabasePageState extends State<DatabasePage>
    with SingleTickerProviderStateMixin {
  int _totalRecords = 0;
  String _usedStorage = '0 MB';
  final String _totalStorage = '1 GB';

  List<String> _topSearchedItems = [
    'Toy Box',
    'Passport',
    'Car Keys',
    'Umbrella',
    'Watch',
  ];
  int _currentItemIndex = 0;
  Timer? _cycleTimer;

  AnimationController? _controller;

  @override
  void initState() {
    super.initState();

    _loadStats();

    _cycleTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted || _topSearchedItems.isEmpty) return;
      setState(() {
        _currentItemIndex =
            (_currentItemIndex + 1) % _topSearchedItems.length;
      });
    });

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _cycleTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final total = await AppDatabase.instance.getTotalRecords();
    final names = await AppDatabase.instance.getSomeItemNames(limit: 5);

    // simple pseudo storage usage: 0.5 MB per record, capped at 1000 MB
    final usedMB = (total * 0.5).clamp(0, 1000).toStringAsFixed(0);

    setState(() {
      _totalRecords = total;
      _usedStorage = '$usedMB MB';
      if (names.isNotEmpty) {
        _topSearchedItems = names;
        _currentItemIndex = 0;
      }
    });
  }

  Future<void> _clearAllRecords() async {
    // First warning
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all records?'),
        content: const Text(
          'This will remove all saved records from this app.\n\n'
              'Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes, continue'),
          ),
        ],
      ),
    ) ??
        false;

    if (!firstConfirm) return;

    // Second, stronger warning
    final secondConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('This cannot be undone'),
        content: const Text(
          'Clearing all records is permanent.\n\n'
              'Do you really want to erase everything?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Go back'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Yes, delete all',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    ) ??
        false;

    if (!secondConfirm) return;

    await AppDatabase.instance.deleteAllItems();
    await _loadStats();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All records cleared.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Records'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
      ),
      body: Stack(
        children: [
          if (controller != null)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: controller,
                builder: (context, child) {
                  final t = controller.value;

                  Offset blobOffset(double sx, double sy, double phase) {
                    return Offset(
                      math.sin(2 * math.pi * (t + phase)) * sx,
                      math.cos(2 * math.pi * (t + phase)) * sy,
                    );
                  }

                  final baseSize = size.width * 0.9;

                  return Stack(
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: Transform.translate(
                          offset: blobOffset(40, 60, 0.0),
                          child: _Blob(
                            size: baseSize,
                            color: const Color(0xFFBA68C8).withOpacity(0.6),
                            t: t,
                            phase: 0.0,
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.center,
                        child: Transform.translate(
                          offset: blobOffset(60, 40, 0.33),
                          child: _Blob(
                            size: baseSize,
                            color: const Color(0xFF64B5F6).withOpacity(0.6),
                            t: t,
                            phase: 0.33,
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.center,
                        child: Transform.translate(
                          offset: blobOffset(50, 50, 0.66),
                          child: _Blob(
                            size: baseSize,
                            color: const Color(0xFFEF9A9A).withOpacity(0.6),
                            t: t,
                            phase: 0.66,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

          // Glass blur overlay
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                color: Colors.white.withOpacity(0.25),
              ),
            ),
          ),

          // Foreground content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top two cards side by side
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Total records',
                          mainText: '$_totalRecords',
                          subtitle: 'items saved',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          title: 'Secure storage',
                          mainText: _usedStorage,
                          subtitle: 'of $_totalStorage secure storage',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Long card: Most searched items
                  if (_topSearchedItems.isNotEmpty)
                    _MostSearchedCard(
                      currentItem: _topSearchedItems[_currentItemIndex],
                    ),

                  const Spacer(),

                  // Clear all records button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _clearAllRecords,
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('Clear all records'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String mainText;
  final String subtitle;

  const _StatCard({
    required this.title,
    required this.mainText,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            mainText,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

class _MostSearchedCard extends StatelessWidget {
  final String currentItem;

  const _MostSearchedCard({
    required this.currentItem,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Most searched items',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4B5563),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.trending_up,
                color: Color(0xFF4F46E5),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.1, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    currentItem,
                    key: ValueKey<String>(currentItem),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final Color color;
  final double t;
  final double phase;

  const _Blob({
    required this.size,
    required this.color,
    required this.t,
    required this.phase,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _BlobPainter(
        color: color,
        t: t,
        phase: phase,
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  final Color color;
  final double t;
  final double phase;

  _BlobPainter({
    required this.color,
    required this.t,
    required this.phase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.35;
    final amplitude = size.width * 0.08;
    final points = <Offset>[];

    const int segments = 18;
    for (int i = 0; i < segments; i++) {
      final double angle = (2 * math.pi * i) / segments;
      final double noise =
          math.sin(angle * 2 + (t * 2 * math.pi) + phase * 2 * math.pi) *
              amplitude;

      final double r = baseRadius + noise;
      final dx = center.dx + r * math.cos(angle);
      final dy = center.dy + r * math.sin(angle);
      points.add(Offset(dx, dy));
    }

    final path = Path();
    if (points.isNotEmpty) {
      path.moveTo(points[0].dx, points[0].dy);

      for (int i = 1; i < points.length; i++) {
        final p0 = points[i - 1];
        final p1 = points[i];
        final mid = Offset(
          (p0.dx + p1.dx) / 2,
          (p0.dy + p1.dy) / 2,
        );
        path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
      }

      final pLast = points.last;
      final pFirst = points.first;
      final mid = Offset(
        (pLast.dx + pFirst.dx) / 2,
        (pLast.dy + pFirst.dy) / 2,
      );
      path.quadraticBezierTo(pLast.dx, pLast.dy, mid.dx, mid.dy);

      path.close();
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BlobPainter oldDelegate) {
    return oldDelegate.t != t ||
        oldDelegate.color != color ||
        oldDelegate.phase != phase;
  }
}
