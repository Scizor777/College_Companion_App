import 'package:flutter/material.dart';
import 'database/database_helper.dart';

class SubjectDetailsPage extends StatelessWidget {
  final int batchId;
  final String subjectName;

  const SubjectDetailsPage({
    super.key,
    required this.batchId,
    required this.subjectName,
  });

  double calculateAttendancePercent(List<Map<String, dynamic>> lectures) {
    if (lectures.isEmpty) return 0.0;
    int presentCount = lectures.where((l) => l['status'].toLowerCase() == 'present').length;
    return (presentCount / lectures.length) * 100;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("$subjectName Details"),
        backgroundColor: Colors.indigo[700],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: DatabaseHelper.instance.getLecturesForSubject(batchId, subjectName),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final lectures = snapshot.data!;
          final attendancePercent = calculateAttendancePercent(lectures);

          if (lectures.isEmpty) return const Center(child: Text("No lectures found"));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Circular Attendance Indicator
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: attendancePercent / 100),
                  duration: const Duration(seconds: 1),
                  builder: (context, value, _) => Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: CircularProgressIndicator(
                          value: value,
                          strokeWidth: 10,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            attendancePercent >= 75
                                ? Colors.green
                                : attendancePercent >= 50
                                    ? Colors.amber
                                    : Colors.red,
                          ),
                        ),
                      ),
                      Text(
                        "${attendancePercent.toInt()}%",
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Lecture list
                ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: lectures.length,
                  itemBuilder: (context, index) {
                    final lec = lectures[index];
                    final status = lec['status'] ?? 'absent';
                    final isPresent = status.toLowerCase() == 'present';
                    final statusColor = isPresent ? Colors.green : Colors.red;

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.indigo[50],
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            blurRadius: 4,
                            spreadRadius: 2,
                            offset: const Offset(2, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: statusColor,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lec['date'],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Status: ${status[0].toUpperCase()}${status.substring(1)}",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: statusColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            isPresent ? Icons.check_circle : Icons.cancel,
                            color: statusColor,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
