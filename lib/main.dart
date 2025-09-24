import 'package:flutter/material.dart';
import 'database/database_helper.dart';
import 'subjectdetails.dart';
import 'ModifySchedulePage.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Schedule App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
    );
  }
}

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
      int batchId, List<Map<String, dynamic>> subjects) async {
    List<double> percents = [];
    for (var sub in subjects) {
      final lectures =
          await DatabaseHelper.instance.getLecturesForSubject(batchId, sub['name']);
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
              child: Text("Saved Timetables",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                              color: Colors.indigo),
                        ),
                        const SizedBox(height: 16),
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: DatabaseHelper.instance.getSubjectsForBatch(batch['id']),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData)
                              return const Center(child: CircularProgressIndicator());

                            var subjects = snapshot.data!;
                            subjects = {for (var s in subjects) s['name']: s}.values.toList();
                            if (subjects.isEmpty) return const Text("No subjects added");

                            return FutureBuilder<List<double>>(
                              future: _calculateSubjectPercents(batch['id'], subjects),
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
                                        margin: const EdgeInsets.symmetric(vertical: 8),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.indigo[50],
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.grey.withOpacity(0.2),
                                              spreadRadius: 2,
                                              blurRadius: 5,
                                              offset: const Offset(2, 3),
                                            )
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
                                                        begin: 0, end: percent / 100),
                                                    duration:
                                                        const Duration(milliseconds: 1000),
                                                    builder: (context, value, _) =>
                                                        CircularProgressIndicator(
                                                      value: value,
                                                      backgroundColor: Colors.grey[300],
                                                      valueColor:
                                                          AlwaysStoppedAnimation<Color>(
                                                              percentColor),
                                                      strokeWidth: 6,
                                                    ),
                                                  ),
                                                ),
                                                TweenAnimationBuilder<double>(
                                                  tween: Tween<double>(begin: 0, end: percent),
                                                  duration:
                                                      const Duration(milliseconds: 1000),
                                                  builder: (context, value, _) => Text(
                                                    "${value.toInt()}%",
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold),
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
                                                    fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                            const Icon(Icons.arrow_forward_ios, size: 18),
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
                              style:
                                  ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              onPressed: () async {
                                bool confirmed = await _confirmStopSemester();
                                if (confirmed) {
                                  await DatabaseHelper.instance.stopSemester(batch['id']);
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
                                    builder: (_) =>
                                        ModifySchedulePage(batchId: batch['id']),
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





class AddScheduleForm extends StatefulWidget {
  const AddScheduleForm({super.key});
  @override
  State<AddScheduleForm> createState() => _AddScheduleFormState();
}

class _AddScheduleFormState extends State<AddScheduleForm>
    with SingleTickerProviderStateMixin {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController classController = TextEditingController();
  DateTime? _selectedDate;

  final Map<String, List<TextEditingController>> subjectsByDay = {
    'Monday': [],
    'Tuesday': [],
    'Wednesday': [],
    'Thursday': [],
    'Friday': [],
    'Saturday': [],
    'Sunday': [],
  };

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void addSubjectField(String day) {
    setState(() {
      subjectsByDay[day]!.add(TextEditingController());
    });
    _controller.forward(from: 0);
  }

  void pickStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  void confirm() {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a start date")),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PreviewSchedule(
          name: nameController.text,
          className: classController.text,
          startDate: _selectedDate!,
          subjectsByDay: subjectsByDay,
        ),
      ),
    ).then((added) {
      if (added == true) {
        Navigator.pop(context, true); // return true to HomePage
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Schedule"),
        backgroundColor: Colors.indigo[700],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: "Schedule Name",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: classController,
              decoration: InputDecoration(
                labelText: "Class / Semester",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.school),
              ),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: pickStartDate,
              icon: const Icon(Icons.calendar_today),
              label: Text(
                _selectedDate == null
                    ? "Select Start Date"
                    : "Start Date: ${_selectedDate!.toLocal().toIso8601String().split('T')[0]}",
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 20),
            ...subjectsByDay.keys.map((day) {
              final controllers = subjectsByDay[day]!;
              return Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(day,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo)),
                          IconButton(
                            icon: const Icon(Icons.add, color: Colors.green),
                            onPressed: () => addSubjectField(day),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...controllers.asMap().entries.map((entry) {
                        final i = entry.key;
                        final controller = entry.value;
                        return FadeTransition(
                          opacity: _controller,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: TextField(
                              controller: controller,
                              decoration: InputDecoration(
                                labelText: "Subject ${i + 1}",
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                prefixIcon: const Icon(Icons.book),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 16),
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: confirm,
                child: const Text(
                  "Confirm",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Schedule Name: $name",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Class / Semester: $className",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, color: Colors.indigo),
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
                          const Text("No subjects added",
                              style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic)),
                        ...subjects.map((c) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.book, size: 18, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      c.text,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ],
                              ),
                            )),
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
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      const SnackBar(content: Text("Name and Class cannot be empty")),
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
                      const SnackBar(content: Text("Schedule saved successfully!")),
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
        subjectsFuture =
            DatabaseHelper.instance.getSubjectsForBatch(widget.batch['id']);
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
              final animation = Tween<Offset>(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(
                  CurvedAnimation(parent: _controller, curve: Curves.easeOut));

              _controller.forward();

              return FadeTransition(
                opacity: _controller,
                child: SlideTransition(
                  position: animation,
                  child: Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
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
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Text(
                                "- $sub",
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87),
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

