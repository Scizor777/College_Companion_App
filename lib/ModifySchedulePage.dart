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

  // selections
  final Set<String> selectedSubjects = {}; // for Absent/Present/Canceled
  String? switchFromSubject; // lecture to cancel in Lecture Switch
  String? switchToSubject;   // lecture to add in Lecture Switch
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
        selectedSubjects.clear();
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
    if (selectedAction == 'Absent' || selectedAction == 'Canceled' || selectedAction == 'Lecture Switch') {
      return lecturesForDate.where((l) => l['status'] == 'present').toList();
    } else if (selectedAction == 'Present') {
      return lecturesForDate.where((l) => l['status'] == 'absent').toList();
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
        for (var sub in selectedSubjects) {
          await db.markNextLectureAbsent(widget.batchId, sub, dateStr);
        }
        break;

      case 'Present':
        for (var sub in selectedSubjects) {
          final lectures = await db.getLecturesForSubject(widget.batchId, sub);
          final lectureToUpdate = lectures.firstWhere(
              (l) => l['date'] == dateStr && l['status'] == 'absent',
              orElse: () => {});
          if (lectureToUpdate.isNotEmpty) {
            await db.updateLectureStatus(lectureToUpdate['id'], 'present');
          }
        }
        break;

      case 'Canceled':
        for (var sub in selectedSubjects) {
          await db.cancelNextLecture(widget.batchId, sub, dateStr);
        }
        break;

      case 'Lecture Switch':
        if (switchFromSubject != null && switchToSubject != null) {
          final lectures = await db.getLecturesForSubject(widget.batchId, switchFromSubject!);
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
        if (extraLectureSubject != null) {
          await db.insertLecture(widget.batchId, extraLectureSubject!, dateStr, 'present');
        }
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Changes applied")));
    Navigator.pop(context,true);
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
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (val) {
              setState(() {
                selectedAction = val!;
                selectedSubjects.clear();
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
                      children: filteredLectures
                          .map((l) => CheckboxListTile(
                                title: Text(l['subject'] as String),
                                value: selectedSubjects.contains(l['subject']),
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      selectedSubjects.add(l['subject']);
                                    } else {
                                      selectedSubjects.remove(l['subject']);
                                    }
                                  });
                                },
                              ))
                          .toList(),
                    ),
            ),

          // Lecture Switch
          if (selectedAction == 'Lecture Switch')
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Lecture to Cancel:"),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _getLecturesForSelectedDate('present'),
                    builder: (context, snapshot) {
                      final lectures = snapshot.data ?? [];
                      final uniqueSubjects = lectures.map((l) => l['subject'] as String).toSet().toList();
                      return Expanded(
                        child: ListView(
                          children: uniqueSubjects
                              .map((subjectName) => CheckboxListTile(
                                    title: Text(subjectName),
                                    value: switchFromSubject == subjectName,
                                    onChanged: (val) {
                                      setState(() {
                                        switchFromSubject = val! ? subjectName : null;
                                      });
                                    },
                                  ))
                              .toList(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text("Lecture to Add:"),
                  Expanded(
                    child: ListView(
                      children: subjects
                          .map((s) => s['name'] as String)
                          .toSet()
                          .map((subjectName) => CheckboxListTile(
                                title: Text(subjectName),
                                value: switchToSubject == subjectName,
                                onChanged: (val) {
                                  setState(() {
                                    switchToSubject = val! ? subjectName : null;
                                  });
                                },
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),

          // Extra Lecture
          if (selectedAction == 'Extra Lecture')
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Select Subject for Extra Lecture:"),
                  Expanded(
                    child: ListView(
                      children: subjects
                          .map((s) => s['name'] as String)
                          .toSet()
                          .map((subjectName) => CheckboxListTile(
                                title: Text(subjectName),
                                value: extraLectureSubject == subjectName,
                                onChanged: (val) {
                                  setState(() {
                                    extraLectureSubject = val! ? subjectName : null;
                                  });
                                },
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ),
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

  // helper to get lectures for Lecture Switch cancel
  Future<List<Map<String, dynamic>>> _getLecturesForSelectedDate(String status) async {
    if (selectedDate == null) return [];
    final dateStr = selectedDate!.toIso8601String().split('T')[0];
    final lectures = await DatabaseHelper.instance.getLecturesForDate(widget.batchId, dateStr);
    return lectures.where((l) => l['status'] == status).toList();
  }
}
