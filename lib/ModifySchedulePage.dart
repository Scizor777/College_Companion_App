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

  // selections — now using lecture IDs (unique)
  final Set<int> selectedLectureIds = {}; // for Absent/Present/Canceled
  String? switchFromSubject; // lecture to cancel in Lecture Switch (subject name)
  String? switchToSubject; // lecture to add in Lecture Switch (subject name)
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
    final lectures = await DatabaseHelper.instance.getLecturesForDate(widget.batchId, dateStr);
    setState(() {
      lecturesForDate = lectures;
    });
  }

  List<Map<String, dynamic>> _filteredLecturesForAction() {
    if (selectedAction == 'Absent') {
      return lecturesForDate.where((l) => l['status'] == 'present').toList();
    } else if (selectedAction == 'Present') {
      return lecturesForDate.where((l) => l['status'] == 'absent').toList();
    } else if (selectedAction == 'Canceled') {
      // Cancel only present lectures
      return lecturesForDate.where((l) => l['status'] == 'present').toList();
    }
    return [];
  }

  void applyChanges() async {
    if (selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select a date")));
      return;
    }
    final db = DatabaseHelper.instance;
    final dateStr = selectedDate!.toIso8601String().split('T')[0];

    switch (selectedAction) {
      case 'Absent':
        // Update selected lecture rows to 'absent'
        for (var lectureId in selectedLectureIds) {
          await db.updateLectureStatus(lectureId, 'absent');
        }
        break;

      case 'Present':
        // Update selected lecture rows to 'present'
        for (var lectureId in selectedLectureIds) {
          await db.updateLectureStatus(lectureId, 'present');
        }
        break;

      case 'Canceled':
        // Delete selected lecture rows
        for (var lectureId in selectedLectureIds) {
          await db.deleteLecture(lectureId);
        }
        break;

      case 'Lecture Switch':
        // Keep original behavior (cancel next lecture for subject and insert new lecture)
        if (switchFromSubject != null && switchToSubject != null) {
          final lectures =
              await db.getLecturesForSubject(widget.batchId, switchFromSubject!);
          final exists = lectures.any((l) => l['date'] == dateStr && l['status'] == 'present');
          if (exists) {
            await db.cancelNextLecture(widget.batchId, switchFromSubject!, dateStr);
            await db.insertLecture(widget.batchId, switchToSubject!, dateStr, 'present');
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Lecture to cancel does not exist")),
            );
          }
        }
        break;

      case 'Extra Lecture':
        // Insert a new lecture for chosen subject on the selected date
        if (extraLectureSubject != null) {
          await db.insertLecture(widget.batchId, extraLectureSubject!, dateStr, 'present');
        }
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Changes applied")));
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final filteredLectures = _filteredLecturesForAction();

    return Scaffold(
      appBar: AppBar(title: const Text("Modify Schedule")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
              selectedDate == null ? "Select Date" : "Date: ${selectedDate!.toIso8601String().split('T')[0]}",
            ),
          ),
          const SizedBox(height: 12),

          // Absent / Present / Canceled lectures — now select by lecture id
          if (selectedAction == 'Absent' ||
              selectedAction == 'Present' ||
              selectedAction == 'Canceled')
            Expanded(
              child: filteredLectures.isEmpty
                  ? const Center(child: Text("No lectures found for selected date"))
                  : ListView(
                      children: filteredLectures.map((l) {
                        final lectureId = (l['id'] is int) ? l['id'] as int : int.parse(l['id'].toString());
                        final subjectName = l['subject'] as String;
                        final status = l['status'] as String? ?? '';
                        return CheckboxListTile(
                          title: Text(subjectName),
                          subtitle: Text("Status: $status"),
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
                        );
                      }).toList(),
                    ),
            ),

          // Lecture Switch -> dropdowns (cancel from present lectures, add from subjects)
          if (selectedAction == 'Lecture Switch')
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Lecture to Cancel:"),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: switchFromSubject,
                  items: lecturesForDate
                      .where((l) => l['status'] == 'present')
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
                const Text("Lecture to Add:"),
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

          // Extra Lecture -> dropdown (single selection)
          if (selectedAction == 'Extra Lecture')
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Select Subject for Extra Lecture:"),
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
              child: const Text("Confirm"),
            ),
          ),
        ]),
      ),
    );
  }

  // helper to get lectures for Lecture Switch cancel — unchanged
  Future<List<Map<String, dynamic>>> _getLecturesForSelectedDate(String status) async {
    if (selectedDate == null) return [];
    final dateStr = selectedDate!.toIso8601String().split('T')[0];
    final lectures = await DatabaseHelper.instance.getLecturesForDate(widget.batchId, dateStr);
    return lectures.where((l) => l['status'] == status).toList();
  }
}
