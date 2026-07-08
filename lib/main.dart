import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

void main() {
  runApp(const MoodDiaryApp());
}

class MoodDiaryApp extends StatelessWidget {
  const MoodDiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mood Diary',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      
      debugShowCheckedModeBanner: false,  // Correct parameter name
    );
  }
}

// ============= MODEL =============
class DiaryEntry {
  String id;
  String note;
  String mood;
  DateTime date;

  DiaryEntry({
    required this.id,
    required this.note,
    required this.mood,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'note': note,
    'mood': mood,
    'date': date.toIso8601String(),
  };

  factory DiaryEntry.fromJson(Map<String, dynamic> json) => DiaryEntry(
    id: json['id'],
    note: json['note'],
    mood: json['mood'],
    date: DateTime.parse(json['date']),
  );
}

// ============= DATABASE HELPER =============
class DiaryDatabase {
  static const String _key = 'diary_entries';

  static Future<List<DiaryEntry>> getEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_key);
    if (jsonString == null) return [];
    List<dynamic> jsonList = json.decode(jsonString);
    return jsonList.map((e) => DiaryEntry.fromJson(e)).toList();
  }

  static Future<void> saveEntries(List<DiaryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    String jsonString = json.encode(entries.map((e) => e.toJson()).toList());
    await prefs.setString(_key, jsonString);
  }

  static Future<void> addEntry(DiaryEntry entry) async {
    List<DiaryEntry> entries = await getEntries();
    entries.insert(0, entry);
    await saveEntries(entries);
  }

  static Future<void> updateEntry(DiaryEntry updatedEntry) async {
    List<DiaryEntry> entries = await getEntries();
    int index = entries.indexWhere((e) => e.id == updatedEntry.id);
    if (index != -1) {
      entries[index] = updatedEntry;
      await saveEntries(entries);
    }
  }

  static Future<void> deleteEntry(String id) async {
    List<DiaryEntry> entries = await getEntries();
    entries.removeWhere((e) => e.id == id);
    await saveEntries(entries);
  }
}

// ============= HOME SCREEN =============
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<DiaryEntry> _entries = [];
  String _filterMood = 'All';

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    List<DiaryEntry> entries = await DiaryDatabase.getEntries();
    if (mounted) {  // FIXED: Added mounted check
      setState(() {
        _entries = entries;
      });
    }
  }

  List<DiaryEntry> get _filteredEntries {
    if (_filterMood == 'All') return _entries;
    return _entries.where((e) => e.mood == _filterMood).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📔 Mood Diary'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_alt),
            onSelected: (value) {
              setState(() {
                _filterMood = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'All', child: Text('All Moods')),
              const PopupMenuItem(value: '😊', child: Text('😊 Happy')),
              const PopupMenuItem(value: '😐', child: Text('😐 Neutral')),
              const PopupMenuItem(value: '😢', child: Text('😢 Sad')),
              const PopupMenuItem(value: '😡', child: Text('😡 Angry')),
              const PopupMenuItem(value: '😴', child: Text('😴 Tired')),
            ],
          ),
        ],
      ),
      body: _entries.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('📝', style: TextStyle(fontSize: 64)),
                  SizedBox(height: 16),
                  Text(
                    'No entries yet!',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  Text(
                    'Tap + to add your first note',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _filteredEntries.length,
              itemBuilder: (context, index) {
                final entry = _filteredEntries[index];
                return _NoteCard(entry: entry, onRefresh: _loadEntries);
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddNoteScreen()),
          );
          if (result == true) _loadEntries();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ============= NOTE CARD (Custom Component) =============
class _NoteCard extends StatelessWidget {
  final DiaryEntry entry;
  final VoidCallback onRefresh;

  const _NoteCard({required this.entry, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        leading: Text(
          entry.mood,
          style: const TextStyle(fontSize: 32),
        ),
        title: Text(
          entry.note,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          DateFormat('MMM d, yyyy · hh:mm a').format(entry.date),
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditNoteScreen(entry: entry),
                  ),
                );
                if (result == true) onRefresh();
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
              onPressed: () => _showDeleteDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await DiaryDatabase.deleteEntry(entry.id);
              if (context.mounted) {  
                Navigator.pop(context);
                onRefresh();
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ============= ADD NOTE SCREEN =============
class AddNoteScreen extends StatefulWidget {
  const AddNoteScreen({super.key});

  @override
  State<AddNoteScreen> createState() => _AddNoteScreenState();
}

class _AddNoteScreenState extends State<AddNoteScreen> {
  final TextEditingController _noteController = TextEditingController();
  String _selectedMood = '😊';
  final List<String> _moods = ['😊', '😐', '😢', '😡', '😴'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Entry'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Mood Selector (Custom Component)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'How are you feeling?',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _moods.map((mood) {
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedMood = mood;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            // FIXED: Replaced deprecated withOpacity with withValues
                            color: _selectedMood == mood
                                ? Colors.deepPurple.withValues(alpha: 0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedMood == mood
                                  ? Colors.deepPurple
                                  : Colors.grey.shade300,
                              width: 2,
                            ),
                          ),
                          child: Text(
                            mood,
                            style: const TextStyle(fontSize: 32),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _noteController,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: 'How was your day? Write something...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveEntry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save Entry',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveEntry() async {
    if (_noteController.text.trim().isEmpty) {
      if (mounted) {  // FIXED: Added mounted check
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please write something!')),
        );
      }
      return;
    }

    final entry = DiaryEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      note: _noteController.text.trim(),
      mood: _selectedMood,
      date: DateTime.now(),
    );

    await DiaryDatabase.addEntry(entry);
    if (mounted) {  // FIXED: Added mounted check
      Navigator.pop(context, true);
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }
}

// ============= EDIT NOTE SCREEN =============
class EditNoteScreen extends StatefulWidget {
  final DiaryEntry entry;
  const EditNoteScreen({super.key, required this.entry});

  @override
  State<EditNoteScreen> createState() => _EditNoteScreenState();
}

class _EditNoteScreenState extends State<EditNoteScreen> {
  late TextEditingController _noteController;
  late String _selectedMood;
  final List<String> _moods = ['😊', '😐', '😢', '😡', '😴'];

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.entry.note);
    _selectedMood = widget.entry.mood;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Entry'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Mood Selector
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'How are you feeling?',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _moods.map((mood) {
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedMood = mood;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            // FIXED: Replaced deprecated withOpacity with withValues
                            color: _selectedMood == mood
                                ? Colors.deepPurple.withValues(alpha: 0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedMood == mood
                                  ? Colors.deepPurple
                                  : Colors.grey.shade300,
                              width: 2,
                            ),
                          ),
                          child: Text(
                            mood,
                            style: const TextStyle(fontSize: 32),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _noteController,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: 'Update your note...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _updateEntry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Update Entry',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateEntry() async {
    if (_noteController.text.trim().isEmpty) {
      if (mounted) {  
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please write something!')),
        );
      }
      return;
    }

    final updatedEntry = DiaryEntry(
      id: widget.entry.id,
      note: _noteController.text.trim(),
      mood: _selectedMood,
      date: widget.entry.date,
    );

    await DiaryDatabase.updateEntry(updatedEntry);
    if (mounted) { 
      Navigator.pop(context, true);
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }
}