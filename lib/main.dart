import 'package:flutter/material.dart';
import 'database/database_helper.dart';

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

// ---------------- Home Page ----------------
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
    setState(() {
      _batches = batches;
    });
  }

  @override
  Widget build(BuildContext context) {
    final drawerWidth = MediaQuery.of(context).size.width * 0.8;

    return Scaffold(
      appBar: AppBar(title: const Text('My App')),
      drawer: Drawer(
        width: drawerWidth,
        child: SafeArea(
          child: Column(
            children: [
              const DrawerHeader(
                child: Text('Menu', style: TextStyle(fontSize: 24)),
              ),
              ListTile(
                leading: const Icon(Icons.punch_clock_rounded),
                title: const Text('Add Schedule'),
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddScheduleForm()),
                  );
                  _loadBatches(); // refresh after adding new timetable
                },
              ),
              const Divider(),
              const Text("Saved Timetables", style: TextStyle(fontSize: 18)),
              Expanded(
                child: _batches.isEmpty
                    ? const Center(child: Text("No timetables added yet"))
                    : ListView.builder(
                        itemCount: _batches.length,
                        itemBuilder: (context, index) {
                          final batch = _batches[index];
                          return ListTile(
                            leading: const Icon(Icons.book),
                            title: Text(
                                "${batch['name']} - ${batch['className']} (${batch['startDate']})"),
                            onTap: () async {
                              Navigator.pop(context);
                              final deleted = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BatchDetailsPage(batch: batch),
                                ),
                              );
                              if (deleted == true) {
                                _loadBatches();
                              }
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      body: ListTile(
        leading: const Icon(Icons.delete_forever),
        title: const Text('Reset Database'),
        onTap: () async {
          Navigator.pop(context); // close drawer
          await DatabaseHelper.instance.resetDatabase();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Database reset successfully!")),
          );
          _loadBatches(); // reload batches after reset
        },
      ),

    );
  }
}

// ---------------- Add Schedule Form ----------------
class AddScheduleForm extends StatefulWidget {
  const AddScheduleForm({super.key});
  @override
  State<AddScheduleForm> createState() => _AddScheduleFormState();
}

class _AddScheduleFormState extends State<AddScheduleForm> {
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

  void addSubjectField(String day) {
    setState(() {
      subjectsByDay[day]!.add(TextEditingController());
    });
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Please select a start date")));
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Schedule")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: classController,
              decoration: const InputDecoration(
                labelText: "Class / Semester",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: pickStartDate,
              child: Text(_selectedDate == null
                  ? "Select Start Date"
                  : "Start Date: ${_selectedDate!.toLocal().toIso8601String().split('T')[0]}"),
            ),
            const SizedBox(height: 20),
            ...subjectsByDay.keys.map((day) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(day, style: const TextStyle(fontSize: 18)),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => addSubjectField(day),
                        ),
                      ],
                    ),
                    Column(
                      children: subjectsByDay[day]!
                          .asMap()
                          .entries
                          .map(
                            (entry) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: TextField(
                                controller: entry.value,
                                decoration: InputDecoration(
                                  labelText: "Subject ${entry.key + 1}",
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                ),
                onPressed: confirm,
                child: const Text("Confirm"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- Preview Schedule ----------------
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
      appBar: AppBar(title: const Text("Preview Schedule")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Name: $name", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("Class: $className", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("Start Date: ${startDate.toLocal().toIso8601String().split('T')[0]}",
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            ...subjectsByDay.keys.map((day) {
              final subjects = subjectsByDay[day]!;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(day, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    if (subjects.isEmpty) const Text("No subjects"),
                    ...subjects.map((c) => Text("- ${c.text}")).toList(),
                  ],
                ),
              );
            }),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                onPressed: () async {
                  // Validate fields first
                  if (name.trim().isEmpty || className.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Name and Class cannot be empty")),
                    );
                    return;
                  }

                  bool hasSubjects = subjectsByDay.values.any((list) => list.any((c) => c.text.trim().isNotEmpty));
                  if (!hasSubjects) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Add at least one subject")),
                    );
                    return;
                  }

                  if (startDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Start date cannot be empty")),
                    );
                    return;
                  }

                  try {
                    final db = DatabaseHelper.instance;

                    // Insert batch
                    int batchId = await db.insertBatch(
                      name.trim(),
                      className.trim(),
                      startDate.toIso8601String().split('T')[0],
                    );

                    // Insert subjects
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

                    Navigator.pop(context); // Go back after saving
                    Navigator.pop(context); // Go back after saving
                  } catch (e) {
                    // Show any DB error
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error saving schedule: $e")),
                    );
                  }
                },
                child: const Text("Save"),
              ),
            ),

          ],
        ),
      ),
    );
  }
}

// ---------------- Batch Details Page ----------------
class BatchDetailsPage extends StatefulWidget {
  final Map<String, dynamic> batch;
  const BatchDetailsPage({super.key, required this.batch});

  @override
  State<BatchDetailsPage> createState() => _BatchDetailsPageState();
}

class _BatchDetailsPageState extends State<BatchDetailsPage> {
  late Future<List<Map<String, dynamic>>> subjectsFuture;

  @override
  void initState() {
    super.initState();
    subjectsFuture = DatabaseHelper.instance.getSubjectsForBatch(widget.batch['id']);
  }

  void confirmDelete() async {
    final confirmed = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Schedule"),
        content: const Text(
            "Are you sure you want to delete this timetable? This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
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
            "${widget.batch['name']} - ${widget.batch['className']} (${widget.batch['startDate']})"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: confirmDelete,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: subjectsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final subjects = snapshot.data!;

          if (subjects.isEmpty) return const Center(child: Text("No subjects added"));

          // group by day
          final Map<String, List<String>> subjectsByDay = {};
          for (var s in subjects) {
            subjectsByDay.putIfAbsent(s['dayOfWeek'], () => []);
            subjectsByDay[s['dayOfWeek']]!.add(s['name']);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: subjectsByDay.entries.map((entry) {
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.key,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ...entry.value.map((sub) => Text("- $sub")).toList(),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
