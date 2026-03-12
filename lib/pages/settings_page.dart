import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color _bgColor = Color(0xff1A1A2E);
const Color _accentColor = Color(0xff16213E);
const Color _highlightColor = Color(0xffE94560);

class SettingsPage extends StatefulWidget {
  final int currentGoal;

  const SettingsPage({super.key, required this.currentGoal});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const String _keyStepGoal = 'step_goal';

  late TextEditingController _goalController;
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _goalController =
        TextEditingController(text: widget.currentGoal.toString());
  }

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _saveGoal() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final goal = int.parse(_goalController.text.trim());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyStepGoal, goal);

    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Step goal saved!'),
        duration: Duration(seconds: 2),
      ),
    );

    Navigator.of(context).pop(goal);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _accentColor,
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Daily Step Goal',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Set the number of steps required to unlock your phone each morning.',
                  style: TextStyle(fontSize: 14, color: Colors.white54),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _goalController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  decoration: InputDecoration(
                    labelText: 'Step goal',
                    labelStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(
                      Icons.directions_walk,
                      color: _highlightColor,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _highlightColor),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.redAccent),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.redAccent),
                    ),
                    filled: true,
                    fillColor: _accentColor,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a step goal';
                    }
                    final parsed = int.tryParse(value.trim());
                    if (parsed == null || parsed <= 0) {
                      return 'Please enter a valid positive number';
                    }
                    if (parsed > 100000) {
                      return 'Step goal seems too high (max 100,000)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _saveGoal,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _highlightColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
