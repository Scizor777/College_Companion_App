import 'package:flutter/material.dart';
import 'database/database_helper.dart';

class ModifySchedulePage extends StatefulWidget {
  final int batchId;
  const ModifySchedulePage({super.key, required this.batchId});

  @override
  State<ModifySchedulePage> createState() => _ModifySchedulePageState();
}

class _ModifySchedulePageState extends State<ModifySchedulePage> {
  String selectedAction = 'Absent';
  DateTime? selectedDate;

  List<Map<String, dynamic>> subjects = [];
  List<Map<String, dynamic>> lecturesForDate = [];

  final Set<int> selectedLectureIds = {};
  String? switchFromSubject;
  String? switchToSubject;
  String? extraLectureSubject;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    final subs = await DatabaseHelper.instance.getSubjectsForBatch(widget.batchId);
    setState(() => subjects = subs);
  }

  Future<void> pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        selectedDate = date;
        selectedLectureIds.clear();
        switchFromSubject = null;
        switchToSubject = null;
        extraLectureSubject = null;
      });
      await _loadLecturesForSelectedDate();
    }
  }

  Future<void> _loadLecturesForSelectedDate() async {
    if (selectedDate == null) return;
    final dateStr = selectedDate!.toIso8601String().split('T')[0];
    final lectures = await DatabaseHelper.instance.getLecturesForDate(
      widget.batchId,
      dateStr,
    );
    setState(() {
      lecturesForDate = lectures;
    });
  }

  List<Map<String, dynamic>> _filteredLecturesForAction() {
    if (selectedAction == 'Absent') {
      return lecturesForDate.where((l) => l['status'] == 'present').toList();
    } else if (selectedAction == 'Present') {
      return lecturesForDate.where((l) => l['status'] == 'absent').toList();
    } else if (selectedAction == 'Canceled' || selectedAction == 'Lecture Switch') {
      return List.from(lecturesForDate);
    }
    return [];
  }

  void applyChanges() async {
    if (selectedDate == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Select a date")));
      return;
    }

    final db = DatabaseHelper.instance;
    final dateStr = selectedDate!.toIso8601String().split('T')[0];

    switch (selectedAction) {
      case 'Absent':
        for (var lectureId in selectedLectureIds) {
          await db.updateLectureStatus(lectureId, 'absent');
          print(lectureId);
        }
        
        break;
      case 'Present':
        for (var lectureId in selectedLectureIds) {
          await db.updateLectureStatus(lectureId, 'present');
          print(lectureId);
        }
        break;
      case 'Canceled':
        for (var lectureId in selectedLectureIds) {
          await db.deleteLecture(lectureId);
          print(lectureId);
        }
        break;
      case 'Lecture Switch':
        if (switchFromSubject != null && switchToSubject != null) {
          final lectures = await db.getLecturesForDate(widget.batchId, dateStr);
          // Find the lecture to cancel for the chosen subject
          final lectureToCancel = lectures.firstWhere(
            (l) => l['subject'] == switchFromSubject,
            orElse: () => {},
          );

          if (lectureToCancel.isNotEmpty) {
            await db.deleteLecture(lectureToCancel['id'] as int);
            await db.insertLecture(
              widget.batchId,
              switchToSubject!,
              dateStr,
              'present',
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Lecture to cancel does not exist")),
            );
          }
        }
        break;

      case 'Extra Lecture':
        if (extraLectureSubject != null) {
          await db.insertLecture(widget.batchId, extraLectureSubject!, dateStr, 'present');
        }
        break;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Changes applied")));
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final filteredLectures = _filteredLecturesForAction();

    return Scaffold(
      appBar: AppBar(title: const Text("Modify Schedule"), backgroundColor: Colors.indigo[700]),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Action selector
            DropdownButtonFormField<String>(
              value: selectedAction,
              items: ['Absent', 'Present', 'Canceled', 'Lecture Switch', 'Extra Lecture']
                  .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  selectedAction = val ?? 'Absent';
                  selectedLectureIds.clear();
                  switchFromSubject = null;
                  switchToSubject = null;
                  extraLectureSubject = null;
                });
              },
              decoration: const InputDecoration(
                labelText: "Select Change Type",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Date selector
            TextButton(
              onPressed: pickDate,
              child: Text(
                selectedDate == null
                    ? "Select Date"
                    : "Date: ${selectedDate!.toIso8601String().split('T')[0]}",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),

            // Absent / Present / Canceled lectures
            if (selectedAction == 'Absent' ||
                selectedAction == 'Present' ||
                selectedAction == 'Canceled')
              Expanded(
                child: filteredLectures.isEmpty
                    ? const Center(child: Text("No lectures found for selected date"))
                    : ListView(
                        children: filteredLectures.map((l) {
                          final lectureId = l['id'] as int;
                          final status = l['status'] as String? ?? '';
                          final subjectName = l['subject'] as String;
                          final statusColor =
                              status.toLowerCase() == 'present' ? Colors.green : Colors.red;

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 3,
                            child: CheckboxListTile(
                              title: Text(subjectName, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                "Status: ${status[0].toUpperCase()}${status.substring(1)}",
                                style: TextStyle(color: statusColor),
                              ),
                              activeColor: statusColor,
                              value: selectedLectureIds.contains(lectureId),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    selectedLectureIds.add(lectureId);
                                  } else {
                                    selectedLectureIds.remove(lectureId);
                                  }
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
              ),

            // Lecture Switch
            if (selectedAction == 'Lecture Switch')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Lecture to Cancel:", style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: switchFromSubject,
                    items: lecturesForDate
                        .map((l) => l['subject'] as String)
                        .toSet()
                        .map((subjectName) => DropdownMenuItem<String>(
                              value: subjectName,
                              child: Text(subjectName),
                            ))
                        .toList(),
                    onChanged: (val) => setState(() => switchFromSubject = val),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: "Select subject to cancel",
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text("Lecture to Add:", style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: switchToSubject,
                    items: subjects
                        .map((s) => s['name'] as String)
                        .toSet()
                        .map((subjectName) => DropdownMenuItem<String>(
                              value: subjectName,
                              child: Text(subjectName),
                            ))
                        .toList(),
                    onChanged: (val) => setState(() => switchToSubject = val),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: "Select subject to add",
                    ),
                  ),
                ],
              ),

            // Extra Lecture
            if (selectedAction == 'Extra Lecture')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Select Subject for Extra Lecture:", style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: extraLectureSubject,
                    items: subjects
                        .map((s) => s['name'] as String)
                        .toSet()
                        .map((subjectName) => DropdownMenuItem<String>(
                              value: subjectName,
                              child: Text(subjectName),
                            ))
                        .toList(),
                    onChanged: (val) => setState(() => extraLectureSubject = val),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: "Select Subject",
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 12),
            Center(
              child: ElevatedButton(
                onPressed: applyChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                ),
                child: const Text("Confirm", style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
