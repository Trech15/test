import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/emergency_contact_service.dart';
import '../theme/app_theme.dart';

/// Put this file in lib/widgets/emergency_contact_sheet.dart
///
/// The "Emergency contact" editor opened from the Profile sheet. The student
/// can change the contact's name, relationship and mobile number.
///
/// If the student has no saved contact yet, the consent box is shown too,
/// because ChaTress only calls a contact the student agreed to.
class EmergencyContactSheet {
  EmergencyContactSheet._();

  static Future<void> show(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);

    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _EmergencyContactBody(messenger: messenger),
    );
  }
}

class _EmergencyContactBody extends StatefulWidget {
  const _EmergencyContactBody({required this.messenger});

  final ScaffoldMessengerState messenger;

  @override
  State<_EmergencyContactBody> createState() => _EmergencyContactBodyState();
}

class _EmergencyContactBodyState extends State<_EmergencyContactBody> {
  // Same choices as the registration screen.
  static const List<String> _baseRelationships = [
    'Parent',
    'Guardian',
    'Sibling',
    'Other relative',
    'Friend',
    'Partner',
    'Other',
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  List<String> _relationships = List.of(_baseRelationships);
  String _relationship = '';

  bool _loading = true;
  bool _saving = false;
  bool _hasExisting = false;
  bool _consent = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final contact = await EmergencyContactService.load();
      if (!mounted) return;

      setState(() {
        if (contact != null) {
          _hasExisting = true;
          _nameController.text = contact['contact_name']?.toString() ?? '';
          _phoneController.text = contact['phone']?.toString() ?? '';

          final saved = contact['relationship']?.toString() ?? '';
          if (saved.isNotEmpty) {
            // Keep an older value that is not in the list selectable.
            if (!_relationships.contains(saved)) _relationships.add(saved);
            _relationship = saved;
          }
        }
        _loading = false;
      });
    } catch (e) {
      debugPrint('EMERGENCY CONTACT LOAD ERROR: $e');
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not load your emergency contact.';
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final navigator = Navigator.of(context);

    setState(() => _saving = true);

    try {
      final name = _nameController.text.trim();
      final phone = EmergencyContactService.normalizePhone(
        _phoneController.text,
      )!;

      if (_hasExisting) {
        // Consent was already given at registration; only the details change.
        await EmergencyContactService.updateDetails(
          name: name,
          relationship: _relationship,
          phone: phone,
        );
      } else {
        await EmergencyContactService.save(
          name: name,
          relationship: _relationship,
          phone: phone,
        );
      }

      widget.messenger.showSnackBar(
        const SnackBar(
          content: Text('Emergency contact updated'),
          backgroundColor: Colors.green,
        ),
      );
      navigator.pop();
    } catch (e) {
      debugPrint('EMERGENCY CONTACT SAVE ERROR: $e');
      widget.messenger.showSnackBar(
        SnackBar(content: Text('Could not save contact: $e')),
      );
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: _loading
              ? const SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator()),
                )
              : _loadError != null
              ? SizedBox(
                  height: 160,
                  child: Center(child: Text(_loadError!)),
                )
              : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Emergency contact',
            style: GoogleFonts.quicksand(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Someone we can call if you may be in danger. Choose a person '
            'you trust. It does not have to be family.',
            style: GoogleFonts.quicksand(
              fontSize: 13,
              height: 1.4,
              color: const Color(0xFF999999),
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _nameController,
            enabled: !_saving,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Contact name',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (value) {
              if (value?.trim().isEmpty ?? true) {
                return 'Please enter your contact\'s name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _relationship.isEmpty ? null : _relationship,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.family_restroom_outlined),
            ),
            hint: const Text('Relationship'),
            items: _relationships
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: _saving
                ? null
                : (value) => setState(() => _relationship = value ?? ''),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please choose a relationship';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            enabled: !_saving,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              hintText: 'Mobile number, e.g. 09171234567',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: (value) {
              if (EmergencyContactService.normalizePhone(value ?? '') == null) {
                return 'Enter a valid number, e.g. 09171234567 or +639171234567';
              }
              return null;
            },
          ),

          // Only when there is no saved contact yet.
          if (!_hasExisting) ...[
            const SizedBox(height: 8),
            FormField<bool>(
              initialValue: false,
              validator: (_) => _consent ? null : 'You need to agree to continue',
              builder: (state) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CheckboxListTile(
                      value: _consent,
                      onChanged: _saving
                          ? null
                          : (value) {
                              setState(() => _consent = value ?? false);
                              state.didChange(_consent);
                            },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppTheme.primaryColor,
                      title: Text(
                        'I agree that if I type or say something that suggests '
                        'I may hurt myself or end my life, ChaTress may call '
                        'my emergency contact and alert my campus guidance '
                        'office so they can check on me.',
                        style: GoogleFonts.quicksand(fontSize: 12, height: 1.45),
                      ),
                    ),
                    if (state.hasError)
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Text(
                          state.errorText ?? '',
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save changes'),
            ),
          ),
        ],
      ),
    );
  }
}