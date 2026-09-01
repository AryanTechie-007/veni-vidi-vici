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
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Oversized Serif Brand Title
                    Text(
                      'MeshSync',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 34,
                        fontWeight: FontWeight.normal,
                        letterSpacing: -0.5,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Decentralized Offline Emergency Network',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: isDark ? MeshTheme.darkTextMuted : MeshTheme.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 36),

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
                              label: 'Citizen',
                              icon: Icons.person_outline,
                              selected: _selectedRole == MeshRole.victim,
                              onTap: () => setState(() => _selectedRole = MeshRole.victim),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _RoleTabButton(
                              label: 'Search & Rescue',
                              icon: Icons.medical_services_outlined,
                              selected: _selectedRole == MeshRole.responder,
                              onTap: () => setState(() => _selectedRole = MeshRole.responder),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Role Notice
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color,
                        border: Border(
                          left: BorderSide(
                            color: _selectedRole == MeshRole.victim
                                ? MeshTheme.terracottaRed
                                : MeshTheme.sageGreen,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Text(
                        _selectedRole == MeshRole.victim
                            ? 'Citizen portal: Broadcast emergency distress signals and confirm your safety with search teams.'
                            : 'Responder portal: Receive inbound victim signals, casualty counts, and coordinate rescue triage.',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 12,
                          height: 1.4,
                          color: isDark ? MeshTheme.darkText : MeshTheme.lightText,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Auth Mode Switcher (Sign In vs Sign Up)
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
                                  fontFamily: 'Georgia',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: !_isSignUp ? theme.colorScheme.onSurface : (isDark ? MeshTheme.darkTextMuted : MeshTheme.lightTextMuted),
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
                                'Register',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Georgia',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: _isSignUp ? theme.colorScheme.onSurface : (isDark ? MeshTheme.darkTextMuted : MeshTheme.lightTextMuted),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Form Fields
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(fontFamily: 'Georgia', fontSize: 14),
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline, size: 18),
                      ),
                      validator: (val) => val == null || val.isEmpty ? 'Name required' : null,
                    ),
                    const SizedBox(height: 16),

                    if (_selectedRole == MeshRole.victim) ...[
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(fontFamily: 'Georgia', fontSize: 14),
                        decoration: const InputDecoration(
                          labelText: 'Mobile Number / Emergency ID',
                          prefixIcon: Icon(Icons.phone_outlined, size: 18),
                        ),
                        validator: (val) => val == null || val.isEmpty ? 'Identifier required' : null,
                      ),
                    ] else ...[
                      TextFormField(
                        controller: _badgeController,
                        style: const TextStyle(fontFamily: 'Georgia', fontSize: 14),
                        decoration: const InputDecoration(
                          labelText: 'Responder Badge / Official ID',
                          prefixIcon: Icon(Icons.badge_outlined, size: 18),
                        ),
                        validator: (val) => val == null || val.isEmpty ? 'Badge ID required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _unitController,
                        style: const TextStyle(fontFamily: 'Georgia', fontSize: 14),
                        decoration: const InputDecoration(
                          labelText: 'SAR Unit / Squad Code (e.g. SAR-ALPHA)',
                          prefixIcon: Icon(Icons.shield_outlined, size: 18),
                        ),
                        validator: (val) => val == null || val.isEmpty ? 'Unit code required' : null,
                      ),
                    ],

                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _pinController,
                      obscureText: true,
                      style: const TextStyle(fontFamily: 'Georgia', fontSize: 14),
                      decoration: const InputDecoration(
                        labelText: 'Security PIN / Password',
                        prefixIcon: Icon(Icons.lock_outline, size: 18),
                      ),
                      validator: (val) => val == null || val.length < 4 ? 'Min 4 characters required' : null,
                    ),

                    const SizedBox(height: 28),
                    // Strong Primary Action Button
                    FilledButton(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: _selectedRole == MeshRole.victim
                            ? MeshTheme.terracottaRed
                            : theme.colorScheme.onSurface,
                        foregroundColor: _selectedRole == MeshRole.victim
                            ? Colors.white
                            : theme.scaffoldBackgroundColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        _isSignUp
                            ? (_selectedRole == MeshRole.victim ? 'Register Citizen Profile' : 'Register SAR Profile')
                            : (_selectedRole == MeshRole.victim ? 'Access Citizen Portal' : 'Access Responder Command'),
                        style: const TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
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
                  : (isDark ? MeshTheme.darkTextMuted : MeshTheme.lightTextMuted),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: selected
                    ? (isDark ? Colors.black : Colors.white)
                    : (isDark ? MeshTheme.darkTextMuted : MeshTheme.lightTextMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
