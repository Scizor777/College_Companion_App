import 'package:flutter/material.dart';
import 'database/database_helper.dart';

class PreviewSchedule extends StatelessWidget {
  final String name;
  final String className;
  final DateTime startDate;
  final Map<String, List<TextEditingController>> subjectsByDay;

  const PreviewSchedule({
    super.key,
    required this.name,
    required this.className,
    required this.startDate,
    required this.subjectsByDay,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Preview Schedule"),
        backgroundColor: Colors.indigo[700],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Schedule Name: $name",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Class / Semester: $className",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Start Date: ${startDate.toLocal().toIso8601String().split('T')[0]}",
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Subjects per day
            ...subjectsByDay.entries.map((entry) {
              final day = entry.key;
              final subjects = entry.value;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              color: Colors.indigo,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              day,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (subjects.isEmpty)
                          const Text(
                            "No subjects added",
                            style: TextStyle(
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ...subjects.map(
                          (c) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.book,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    c.text,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),

            const SizedBox(height: 24),

            // Save Button
            Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                icon: const Icon(Icons.save),
                label: const Text(
                  "Save Schedule",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  if (name.trim().isEmpty || className.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Name and Class cannot be empty"),
                      ),
                    );
                    return;
                  }

                  bool hasSubjects = subjectsByDay.values.any(
                    (list) => list.any((c) => c.text.trim().isNotEmpty),
                  );
                  if (!hasSubjects) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Add at least one subject")),
                    );
                    return;
                  }

                  try {
                    final db = DatabaseHelper.instance;

                    int batchId = await db.insertBatch(
                      name.trim(),
                      className.trim(),
                      startDate.toIso8601String().split('T')[0],
                    );

                    for (var entry in subjectsByDay.entries) {
                      for (var controller in entry.value) {
                        final text = controller.text.trim();
                        if (text.isNotEmpty) {
                          await db.insertSubject(batchId, text, entry.key);
                        }
                      }
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Schedule saved successfully!"),
                      ),
                    );
                    Navigator.pop(context, true);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error saving schedule: $e")),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}