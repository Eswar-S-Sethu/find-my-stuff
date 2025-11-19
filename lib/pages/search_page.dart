import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import '../data/app_database.dart';
import 'database_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with SingleTickerProviderStateMixin {
  static const List<String> _placeholders = ['Watch', 'Passport', 'Toy box'];
  int _placeholderIndex = 0;
  Timer? _timer;

  late final AnimationController _controller;
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  bool _searchPerformed = false;
  List<_SearchResult> _results = [];
  String? _notFoundQuery;

  // Controllers for mini Add window
  final TextEditingController _addWhatController = TextEditingController();
  final TextEditingController _addWhereController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Cycle placeholder every 2 seconds
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      setState(() {
        _placeholderIndex = (_placeholderIndex + 1) % _placeholders.length;
      });
    });

    // Animated background blobs
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    // Make sure DB gets opened at least once
    AppDatabase.instance.database;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _searchController.dispose();
    _addWhatController.dispose();
    _addWhereController.dispose();
    super.dispose();
  }

  // -------- SEARCH (READ) --------

  Future<void> _performSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _searchQuery = '';
        _searchPerformed = false;
        _results = [];
        _notFoundQuery = null;
      });
      return;
    }

    try {
      final items = await AppDatabase.instance.searchItems(trimmed);

      setState(() {
        _searchQuery = trimmed;
        _searchPerformed = true;
        _results = items
            .map(
              (item) => _SearchResult(
            id: item.id!,
            name: item.name,
            location: item.location,
          ),
        )
            .toList();
        _notFoundQuery = _results.isEmpty ? trimmed : null;
      });
    } catch (e) {
      // If something goes wrong with DB, at least show a message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('DB error while searching: $e')),
        );
      }
      setState(() {
        _searchPerformed = true;
        _results = [];
        _notFoundQuery = trimmed;
      });
    }
  }

  void _resetToStartupState() {
    FocusScope.of(context).unfocus();
    if (!_searchPerformed && _notFoundQuery == null) return;

    setState(() {
      _searchPerformed = false;
      _results = [];
      _notFoundQuery = null;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  void _openRecordsPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const DatabasePage(),
      ),
    );
  }

  // -------- ADD (CREATE) --------

  void _openAddDialog({String? initialWhat}) {
    _addWhatController.text = initialWhat ?? '';
    _addWhereController.clear();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  width: MediaQuery.of(dialogContext).size.width * 0.8,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.5)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Add a New Record",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // WHAT IS IT?
                      TextField(
                        controller: _addWhatController,
                        decoration: InputDecoration(
                          hintText: "What is it?",
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.85),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // WHERE IS IT? (BIGGER BOX)
                      TextField(
                        controller: _addWhereController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: "Where is it?",
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.85),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            final what = _addWhatController.text.trim();
                            final where = _addWhereController.text.trim();

                            if (what.isEmpty || where.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Please fill both fields."),
                                ),
                              );
                              return;
                            }

                            try {
                              await AppDatabase.instance.insertItem(
                                Item(name: what, location: where),
                              );
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'DB error while inserting: $e',
                                    ),
                                  ),
                                );
                              }
                              return;
                            }

                            if (!mounted) return;
                            Navigator.pop(dialogContext);

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '"$what" stored at "$where".',
                                ),
                              ),
                            );

                            // Refresh search if there's a query now
                            if (_searchController.text.trim().isNotEmpty) {
                              await _performSearch(_searchController.text);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text("Add to Record"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Called from the "not found" card's Add button
  void _handleAddToDatabase(String value) {
    _openAddDialog(initialWhat: value);
    setState(() {
      _notFoundQuery = null;
    });
  }

  // -------- UI HELPERS --------

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: 45,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            borderRadius: BorderRadius.circular(999),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: Colors.grey[700]),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[800],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------- BUILD --------

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _resetToStartupState,
        child: Stack(
          children: [
            // animated color blobs background
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final t = _controller.value;

                  Offset blobOffset(double sx, double sy, double phase) {
                    return Offset(
                      math.sin(2 * math.pi * (t + phase)) * sx,
                      math.cos(2 * math.pi * (t + phase)) * sy,
                    );
                  }

                  final baseSize = size.width * 0.9;

                  return Stack(
                    children: [
                      // lilac blob
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
                      // light blue blob
                      Align(
                        alignment: Alignment.center,
                        child: Transform.translate(
                          offset: blobOffset(60, 40, 0.33),
                          child: _Blob(
                            size: baseSize,
                            color:
                            const Color(0xFF64B5F6).withOpacity(0.6),
                            t: t,
                            phase: 0.33,
                          ),
                        ),
                      ),
                      // light red blob
                      Align(
                        alignment: Alignment.center,
                        child: Transform.translate(
                          offset: blobOffset(50, 50, 0.66),
                          child: _Blob(
                            size: baseSize,
                            color:
                            const Color(0xFFEF9A9A).withOpacity(0.6),
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

            // FULL-SCREEN GLASS BLUR LAYER
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  color: Colors.white.withOpacity(0.25),
                ),
              ),
            ),

            // centered search bar + action buttons + results
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: size.width * 0.9,
                  maxHeight: size.height * 0.78,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Search your things',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Search bar
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search,
                            size: 20,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                isCollapsed: true,
                                border: InputBorder.none,
                                hintText: _placeholders[_placeholderIndex],
                                hintStyle: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 16,
                                ),
                              ),
                              style: const TextStyle(
                                color: Color(0xFF111827),
                                fontSize: 16,
                              ),
                              textInputAction: TextInputAction.search,
                              onChanged: (value) => _performSearch(value),
                              onSubmitted: _performSearch,
                              onTap: () {
                                // Let user type without resetting on tap
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward),
                            color: Colors.grey,
                            onPressed: () =>
                                _performSearch(_searchController.text),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Action buttons row: Add / Records
                    Row(
                      children: [
                        _buildActionButton(
                          icon: Icons.add,
                          label: 'Add',
                          onTap: _openAddDialog,
                        ),
                        const SizedBox(width: 12),
                        _buildActionButton(
                          icon: Icons.storage,
                          label: 'Records',
                          onTap: _openRecordsPage,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Results / Not-found area
                    if (_searchPerformed)
                      Expanded(
                        child: _results.isNotEmpty
                            ? ListView.builder(
                          itemCount: _results.length,
                          shrinkWrap: true,
                          itemBuilder: (context, index) {
                            final result = _results[index];
                            return Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                              margin: const EdgeInsets.symmetric(
                                vertical: 8,
                              ),
                              child: ListTile(
                                leading: const Icon(
                                  Icons.inventory_2_rounded,
                                  color: Color(0xFF4F46E5),
                                ),
                                title: Text(
                                  result.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding:
                                  const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    result.location,
                                    style: const TextStyle(
                                      color: Color(0xFF4B5563),
                                    ),
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () async {
                                    try {
                                      await AppDatabase.instance
                                          .deleteItem(result.id);
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'DB error while deleting: $e',
                                            ),
                                          ),
                                        );
                                      }
                                      return;
                                    }

                                    if (!mounted) return;
                                    setState(() {
                                      _results.removeAt(index);
                                      if (_results.isEmpty) {
                                        _searchPerformed = true;
                                        _notFoundQuery =
                                        _searchQuery.isEmpty
                                            ? null
                                            : _searchQuery;
                                      }
                                    });
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '"${result.name}" deleted.',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        )
                            : _notFoundQuery != null
                            ? Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                          margin: const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                          child: Padding(
                            padding:
                            const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'No results found for "${_notFoundQuery!}".',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Would you like to add this to the database?',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF4B5563),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _notFoundQuery = null;
                                          _searchPerformed = false;
                                        });
                                      },
                                      child: const Text('Cancel'),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () =>
                                          _handleAddToDatabase(
                                            _notFoundQuery!,
                                          ),
                                      child: const Text('Add'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        )
                            : const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------- BLOBS --------

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

// -------- MODEL FOR UI --------

class _SearchResult {
  final int id;
  final String name;
  final String location;

  _SearchResult({
    required this.id,
    required this.name,
    required this.location,
  });
}
