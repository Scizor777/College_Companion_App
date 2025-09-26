import 'package:flutter/material.dart';
import 'database/database_helper.dart';

class BatchDetailsPage extends StatefulWidget {
  final Map<String, dynamic> batch;
  const BatchDetailsPage({super.key, required this.batch});

  @override
  State<BatchDetailsPage> createState() => _BatchDetailsPageState();
}

class _BatchDetailsPageState extends State<BatchDetailsPage>
    with SingleTickerProviderStateMixin {
  late Future<List<Map<String, dynamic>>>? subjectsFuture;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // First auto-fill lectures for this batch
    DatabaseHelper.instance.autoFillLectures(widget.batch['id']).then((_) {
      // After auto-filling, load subjects
      setState(() {
        subjectsFuture = DatabaseHelper.instance.getSubjectsForBatch(
          widget.batch['id'],
        );
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void confirmDelete() async {
    final confirmed = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Schedule"),
        content: const Text(
          "Are you sure you want to delete this timetable? This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseHelper.instance.deleteBatch(widget.batch['id']);
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "${widget.batch['name']} - ${widget.batch['className']} (${widget.batch['startDate']})",
        ),
        actions: [
          IconButton(icon: const Icon(Icons.delete), onPressed: confirmDelete),
        ],
        backgroundColor: Colors.indigo[700],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: subjectsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final subjects = snapshot.data!;

          if (subjects.isEmpty) {
            return const Center(child: Text("No subjects added"));
          }

          // group by day
          final Map<String, List<String>> subjectsByDay = {};
          for (var s in subjects) {
            subjectsByDay.putIfAbsent(s['dayOfWeek'], () => []);
            subjectsByDay[s['dayOfWeek']]!.add(s['name']);
          }

          final days = subjectsByDay.entries.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: days.length,
            itemBuilder: (context, index) {
              final entry = days[index];
              final animation =
                  Tween<Offset>(
                    begin: const Offset(0, 0.3),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: _controller, curve: Curves.easeOut),
                  );

              _controller.forward();

              return FadeTransition(
                opacity: _controller,
                child: SlideTransition(
                  position: animation,
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...entry.value.map(
                            (sub) => Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4.0,
                              ),
                              child: Text(
                                "- $sub",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}