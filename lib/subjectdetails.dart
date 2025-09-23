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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("$subjectName Details"),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: DatabaseHelper.instance.getLecturesForSubject(batchId, subjectName),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final lectures = snapshot.data!;
          if (lectures.isEmpty) return const Center(child: Text("No lectures found"));

          return ListView.builder(
            itemCount: lectures.length,
            itemBuilder: (context, index) {
              final lec = lectures[index];
              return ListTile(
                title: Text(lec['date']),
                trailing: Text(lec['status']),
              );
            },
          );
        },
      ),
    );
  }
}
