import 'package:flutter/material.dart';
import 'database/database_helper.dart';
import 'subjectdetails.dart';
import 'ModifySchedulePage.dart';
import 'addScheduleForm.dart';
import 'batchdetails.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> _batches = [];

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    final batches = await DatabaseHelper.instance.getAllBatches();

    for (var batch in batches) {
      await DatabaseHelper.instance.autoFillLectures(batch['id']);
    }

    final refreshed = await DatabaseHelper.instance.getAllBatches();
    setState(() {
      _batches = refreshed;
    });
  }

  double calculateAttendancePercent(List<Map<String, dynamic>> lectures) {
    if (lectures.isEmpty) return 0.0;
    int presentCount = lectures.where((l) => l['status'] == 'present').length;
    return (presentCount / lectures.length) * 100;
  }

  Future<List<double>> _calculateSubjectPercents(
    int batchId,
    List<Map<String, dynamic>> subjects,
  ) async {
    List<double> percents = [];
    for (var sub in subjects) {
      final lectures = await DatabaseHelper.instance.getLecturesForSubject(
        batchId,
        sub['name'],
      );
      percents.add(calculateAttendancePercent(lectures));
    }
    return percents;
  }

  Future<bool> _confirmStopSemester() async {
    return await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Stop Semester"),
            content: const Text(
              "Are you sure you want to stop auto-fill for this semester?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("Confirm"),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Dashboard'),
        backgroundColor: Colors.indigo[700],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.indigo),
              child: const Text(
                'Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              title: const Text("Add Schedule"),
              leading: const Icon(Icons.add),
              onTap: () async {
                Navigator.pop(context);
                final added = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AddScheduleForm()),
                );
                if (added == true) _loadBatches();
              },
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: Text(
                "Saved Timetables",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            if (_batches.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text("No timetables added yet"),
              )
            else
              ..._batches.map((batch) {
                return ListTile(
                  leading: const Icon(Icons.book),
                  title: Text(
                    "${batch['name']} - ${batch['className']} (${batch['startDate']})",
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final deleted = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BatchDetailsPage(batch: batch),
                      ),
                    );
                    if (deleted == true) _loadBatches();
                  },
                );
              }).toList(),
          ],
        ),
      ),
      body: _batches.isEmpty
          ? const Center(child: Text("No semesters added yet"))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _batches.length,
              itemBuilder: (context, index) {
                final batch = _batches[index];
                return Card(
                  elevation: 5,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${batch['name']} - ${batch['className']}",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: DatabaseHelper.instance.getSubjectsForBatch(
                            batch['id'],
                          ),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData)
                              return const Center(
                                child: CircularProgressIndicator(),
                              );

                            var subjects = snapshot.data!;
                            subjects = {
                              for (var s in subjects) s['name']: s,
                            }.values.toList();
                            if (subjects.isEmpty)
                              return const Text("No subjects added");

                            return FutureBuilder<List<double>>(
                              future: _calculateSubjectPercents(
                                batch['id'],
                                subjects,
                              ),
                              builder: (context, snap) {
                                if (!snap.hasData) return const SizedBox();
                                final subjectPercents = snap.data!;
                                return Column(
                                  children: List.generate(subjects.length, (i) {
                                    final sub = subjects[i];
                                    final percent = subjectPercents[i];
                                    Color percentColor;
                                    if (percent >= 75) {
                                      percentColor = Colors.green;
                                    } else if (percent >= 50) {
                                      percentColor = Colors.amber[700]!;
                                    } else {
                                      percentColor = Colors.red;
                                    }

                                    return GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => SubjectDetailsPage(
                                              batchId: batch['id'],
                                              subjectName: sub['name'],
                                            ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.indigo[50],
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.grey.withOpacity(
                                                0.2,
                                              ),
                                              spreadRadius: 2,
                                              blurRadius: 5,
                                              offset: const Offset(2, 3),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                SizedBox(
                                                  width: 50,
                                                  height: 50,
                                                  child: TweenAnimationBuilder<double>(
                                                    tween: Tween<double>(
                                                      begin: 0,
                                                      end: percent / 100,
                                                    ),
                                                    duration: const Duration(
                                                      milliseconds: 1000,
                                                    ),
                                                    builder: (context, value, _) =>
                                                        CircularProgressIndicator(
                                                          value: value,
                                                          backgroundColor:
                                                              Colors.grey[300],
                                                          valueColor:
                                                              AlwaysStoppedAnimation<
                                                                Color
                                                              >(percentColor),
                                                          strokeWidth: 6,
                                                        ),
                                                  ),
                                                ),
                                                TweenAnimationBuilder<double>(
                                                  tween: Tween<double>(
                                                    begin: 0,
                                                    end: percent,
                                                  ),
                                                  duration: const Duration(
                                                    milliseconds: 1000,
                                                  ),
                                                  builder:
                                                      (
                                                        context,
                                                        value,
                                                        _,
                                                      ) => Text(
                                                        "${value.toInt()}%",
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Text(
                                                sub['name'],
                                                style: const TextStyle(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            const Icon(
                                              Icons.arrow_forward_ios,
                                              size: 18,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                );
                              },
                            );
                          },
                        ),
                        const Divider(height: 30),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              onPressed: () async {
                                bool confirmed = await _confirmStopSemester();
                                if (confirmed) {
                                  await DatabaseHelper.instance.stopSemester(
                                    batch['id'],
                                  );
                                  _loadBatches();
                                }
                              },
                              child: const Text("Stop Auto-Fill"),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () async {
                                final updated = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ModifySchedulePage(
                                      batchId: batch['id'],
                                    ),
                                  ),
                                );
                                if (updated == true) _loadBatches();
                              },
                              child: const Text("Make Changes"),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
