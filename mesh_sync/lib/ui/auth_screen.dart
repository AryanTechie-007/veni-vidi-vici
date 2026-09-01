import 'package:flutter/material.dart';
import '../device_identity.dart';
import 'theme/mesh_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.onAuthenticated});

  final void Function(MeshRole role, String name, String id) onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isSignUp = false;
  MeshRole _selectedRole = MeshRole.victim;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _badgeController = TextEditingController();
  final _unitController = TextEditingController();
  final _pinController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _badgeController.dispose();
    _unitController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final id = _selectedRole == MeshRole.responder
        ? _badgeController.text.trim()
        : _phoneController.text.trim();

    widget.onAuthenticated(_selectedRole, name, id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand
                    const Text(
                      'MESHSYNC',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Arial',
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Decentralized Offline Emergency Network',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Arial',
                        fontSize: 12,
                        color: isDark ? MeshTheme.darkTextDim : MeshTheme.lightTextDim,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Role Selector
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color,
                        border: Border.all(color: theme.dividerColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _RoleTabButton(
                              label: 'Citizen / Victim',
                              icon: Icons.person,
                              selected: _selectedRole == MeshRole.victim,
                              onTap: () => setState(() => _selectedRole = MeshRole.victim),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _RoleTabButton(
                              label: 'Search & Rescue',
                              icon: Icons.medical_services,
                              selected: _selectedRole == MeshRole.responder,
                              onTap: () => setState(() => _selectedRole = MeshRole.responder),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Role Notice
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color,
                        border: Border.all(
                          color: _selectedRole == MeshRole.victim
                              ? MeshTheme.emergencyRed
                              : theme.dividerColor,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _selectedRole == MeshRole.victim
                            ? 'CITIZEN PORTAL: Send emergency SOS distress signals and notify rescuers when you are safe.'
                            : 'RESPONDER PORTAL: Receive live victim distress packets, casualty counts, and coordinate rescue triage.',
                        style: TextStyle(
                          fontFamily: 'Arial',
                          fontSize: 11,
                          height: 1.3,
                          color: isDark ? MeshTheme.darkText : MeshTheme.lightText,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Auth Type Toggle (Login vs Sign Up)
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _isSignUp = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: !_isSignUp ? theme.colorScheme.onSurface : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: Text(
                                'Sign In',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Arial',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: !_isSignUp ? theme.colorScheme.onSurface : (isDark ? MeshTheme.darkTextDim : MeshTheme.lightTextDim),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _isSignUp = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: _isSignUp ? theme.colorScheme.onSurface : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: Text(
                                'Create Account',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Arial',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: _isSignUp ? theme.colorScheme.onSurface : (isDark ? MeshTheme.darkTextDim : MeshTheme.lightTextDim),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Fields
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(fontFamily: 'Arial', fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline, size: 18),
                      ),
                      validator: (val) => val == null || val.isEmpty ? 'Name required' : null,
                    ),
                    const SizedBox(height: 12),

                    if (_selectedRole == MeshRole.victim) ...[
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(fontFamily: 'Arial', fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Mobile Number / Emergency ID',
                          prefixIcon: Icon(Icons.phone_outlined, size: 18),
                        ),
                        validator: (val) => val == null || val.isEmpty ? 'Phone number required' : null,
                      ),
                    ] else ...[
                      TextFormField(
                        controller: _badgeController,
                        style: const TextStyle(fontFamily: 'Arial', fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Responder Badge / Official ID',
                          prefixIcon: Icon(Icons.badge_outlined, size: 18),
                        ),
                        validator: (val) => val == null || val.isEmpty ? 'Badge ID required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _unitController,
                        style: const TextStyle(fontFamily: 'Arial', fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'SAR Unit / Squad Code (e.g. SAR-ALPHA)',
                          prefixIcon: Icon(Icons.shield_outlined, size: 18),
                        ),
                        validator: (val) => val == null || val.isEmpty ? 'Unit code required' : null,
                      ),
                    ],

                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _pinController,
                      obscureText: true,
                      style: const TextStyle(fontFamily: 'Arial', fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Security PIN / Password',
                        prefixIcon: Icon(Icons.lock_outline, size: 18),
                      ),
                      validator: (val) => val == null || val.length < 4 ? 'Min 4 characters required' : null,
                    ),

                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: _selectedRole == MeshRole.victim
                            ? MeshTheme.emergencyRed
                            : theme.colorScheme.primary,
                        foregroundColor: _selectedRole == MeshRole.victim
                            ? Colors.white
                            : theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        _isSignUp
                            ? (_selectedRole == MeshRole.victim ? 'REGISTER AS CITIZEN' : 'REGISTER AS RESPONDER')
                            : (_selectedRole == MeshRole.victim ? 'SIGN IN AS CITIZEN' : 'SIGN IN AS SAR RESPONDER'),
                        style: const TextStyle(
                          fontFamily: 'Arial',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleTabButton extends StatelessWidget {
  const _RoleTabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? (isDark ? Colors.white : Colors.black) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected
                  ? (isDark ? Colors.black : Colors.white)
                  : (isDark ? MeshTheme.darkTextDim : MeshTheme.lightTextDim),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Arial',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: selected
                    ? (isDark ? Colors.black : Colors.white)
                    : (isDark ? MeshTheme.darkTextDim : MeshTheme.lightTextDim),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
