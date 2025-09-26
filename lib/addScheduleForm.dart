import 'package:flutter/material.dart';
import 'previewSchedule.dart';

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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: classController,
              decoration: InputDecoration(
                labelText: "Class / Semester",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            day,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                            ),
                          ),
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
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 50,
                    vertical: 16,
                  ),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
