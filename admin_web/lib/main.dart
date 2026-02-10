import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:web/web.dart' as web;

import 'firebase_options.dart';
import 'screens/admin/analytics_admin_tab.dart';
import 'screens/admin/contractor_admin_tab.dart';
import 'screens/admin/dispute_admin_tab.dart';
import 'screens/admin/job_admin_tab.dart';
import 'screens/admin/verification_admin_tab.dart';
import 'theme/admin_theme.dart';

void _hideElement(String id) {
  final el = web.document.getElementById(id) as web.HTMLElement?;
  el?.style.display = 'none';
}

void _showError(String msg) {
  final el = web.document.getElementById('app-error') as web.HTMLElement?;
  if (el != null) {
    el.style.display = 'block';
    el.textContent = msg;
  }
}

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Hide loading indicator
    _hideElement('loading');

    runApp(const AdminWebApp());
  } catch (e, st) {
    _showError('Init error: $e\n$st');
    _hideElement('loading');
    rethrow;
  }
}

// ─── App root ────────────────────────────────────────────────────────────────

class AdminWebApp extends StatelessWidget {
  const AdminWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ProServe Hub Admin',
      theme: AdminTheme.darkTheme(),
      home: const AdminGate(),
    );
  }
}

// ─── Auth gate (checks admin doc + role) ─────────────────────────────────────

class AdminGate extends StatelessWidget {
  const AdminGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }
        if (!snap.hasData) return const LoginScreen();

        final user = snap.data!;
        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection('admins')
              .doc(user.uid)
              .get(),
          builder: (context, adminSnap) {
            if (adminSnap.connectionState != ConnectionState.done) {
              return const _SplashScreen();
            }
            if (adminSnap.data?.exists != true) {
              return AccessDeniedScreen(email: user.email ?? '');
            }

            final adminData = adminSnap.data!.data() ?? {};
            final role = (adminData['role'] as String?)?.trim().toLowerCase();
            final adminRole = role == 'super_admin'
                ? AdminRole.superAdmin
                : role == 'viewer'
                ? AdminRole.viewer
                : AdminRole.admin;

            return AdminDashboard(role: adminRole);
          },
        );
      },
    );
  }
}

// ─── RBAC enum ───────────────────────────────────────────────────────────────

enum AdminRole { superAdmin, admin, viewer }

extension AdminRoleX on AdminRole {
  bool get canWrite => this != AdminRole.viewer;
  bool get canDelete => this == AdminRole.superAdmin;
  String get label {
    switch (this) {
      case AdminRole.superAdmin:
        return 'Super Admin';
      case AdminRole.admin:
        return 'Admin';
      case AdminRole.viewer:
        return 'Viewer';
    }
  }
}

// ─── Splash ──────────────────────────────────────────────────────────────────

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

// ─── Login screen ────────────────────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  int _failedAttempts = 0;
  DateTime? _lockedUntil;
  static const _maxAttempts = 5;
  static const _lockDuration = Duration(minutes: 2);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _isLocked =>
      _lockedUntil != null && DateTime.now().isBefore(_lockedUntil!);

  Future<void> _signIn() async {
    if (_isLocked) {
      setState(() => _error = 'Too many attempts. Try again later.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final email = _emailController.text.trim();

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: _passwordController.text.trim(),
      );

      // Log successful sign-in
      _failedAttempts = 0;
      _lockedUntil = null;
      _logLoginAttempt(email: email, success: true);
    } on FirebaseAuthException catch (e) {
      _failedAttempts++;
      if (_failedAttempts >= _maxAttempts) {
        _lockedUntil = DateTime.now().add(_lockDuration);
        _failedAttempts = 0;
      }
      _logLoginAttempt(email: email, success: false, reason: e.code);
      setState(() => _error = e.message ?? 'Sign-in failed');
    } catch (e) {
      _failedAttempts++;
      _logLoginAttempt(email: email, success: false, reason: e.toString());
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _logLoginAttempt({
    required String email,
    required bool success,
    String? reason,
  }) {
    try {
      FirebaseFirestore.instance.collection('admin_login_log').add({
        'email': email,
        'success': success,
        'timestamp': FieldValue.serverTimestamp(),
        'reason': ?reason,
      });
    } catch (_) {
      // Fire-and-forget — don't block login flow
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AdminColors.bgDeep, AdminColors.bg, Color(0xFF0A1731)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo / brand
                    const Icon(
                      Icons.admin_panel_settings,
                      size: 48,
                      color: AdminColors.accent,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'PROSERVE HUB',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.bebasNeue(
                        fontSize: 28,
                        letterSpacing: 2,
                        color: AdminColors.ink,
                      ),
                    ),
                    Text(
                      'Admin Console',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        color: AdminColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 28),

                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _signIn(),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: scheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 18,
                              color: scheme.onErrorContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: scheme.onErrorContainer,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: (_isLoading || _isLocked) ? null : _signIn,
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isLocked ? 'Locked — wait 2 min' : 'Sign in'),
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

// ─── Access denied ───────────────────────────────────────────────────────────

class AccessDeniedScreen extends StatelessWidget {
  const AccessDeniedScreen({super.key, required this.email});
  final String email;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AdminColors.bgDeep, AdminColors.bg],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.block, size: 48, color: AdminColors.error),
                    const SizedBox(height: 12),
                    Text(
                      'Access Denied',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Signed in as $email\n\n'
                      'Your account does not have admin privileges.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AdminColors.muted),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => FirebaseAuth.instance.signOut(),
                      child: const Text('Sign out'),
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

// ─── Dashboard with sidebar ──────────────────────────────────────────────────

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key, required this.role});
  final AdminRole role;

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  // Session timeout — 30 min of inactivity
  Timer? _sessionTimer;
  static const _sessionTimeout = Duration(minutes: 30);

  // Badge counts
  int _pendingVerifications = 0;
  int _activeDisputes = 0;
  StreamSubscription<QuerySnapshot>? _verifSub;
  StreamSubscription<QuerySnapshot>? _disputeSub;

  @override
  void initState() {
    super.initState();
    _resetSessionTimer();
    _subscribeToBadgeCounts();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _verifSub?.cancel();
    _disputeSub?.cancel();
    super.dispose();
  }

  void _resetSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer(_sessionTimeout, () {
      FirebaseAuth.instance.signOut();
    });
  }

  void _subscribeToBadgeCounts() {
    // Pending verifications
    _verifSub = FirebaseFirestore.instance
        .collection('contractors')
        .snapshots()
        .listen((snap) {
          int count = 0;
          for (final doc in snap.docs) {
            final data = doc.data();
            if (data['idVerification']?['status'] == 'pending' ||
                data['licenseVerification']?['status'] == 'pending' ||
                data['insuranceVerification']?['status'] == 'pending') {
              count++;
            }
          }
          if (mounted) setState(() => _pendingVerifications = count);
        });

    // Active disputes
    _disputeSub = FirebaseFirestore.instance
        .collection('disputes')
        .where('status', whereIn: ['open', 'under_review'])
        .snapshots()
        .listen((snap) {
          if (mounted) setState(() => _activeDisputes = snap.docs.length);
        });
  }

  static const _navItems = <_NavDestination>[
    _NavDestination(
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
      label: 'Users',
    ),
    _NavDestination(
      icon: Icons.work_outline,
      selectedIcon: Icons.work,
      label: 'Jobs',
    ),
    _NavDestination(
      icon: Icons.verified_user_outlined,
      selectedIcon: Icons.verified_user,
      label: 'Verify',
    ),
    _NavDestination(
      icon: Icons.gavel_outlined,
      selectedIcon: Icons.gavel,
      label: 'Disputes',
    ),
    _NavDestination(
      icon: Icons.analytics_outlined,
      selectedIcon: Icons.analytics,
      label: 'Analytics',
    ),
  ];

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return const ContractorAdminTab();
      case 1:
        return const JobAdminTab();
      case 2:
        return const VerificationAdminTab();
      case 3:
        return const DisputeAdminTab();
      case 4:
        return const AnalyticsAdminTab();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    _resetSessionTimer(); // reset on every rebuild (user interaction)

    final isWide = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      // Mobile: use drawer
      drawer: isWide
          ? null
          : Drawer(
              backgroundColor: AdminColors.bgDeep,
              child: _buildDrawerContent(),
            ),
      appBar: AppBar(
        leading: isWide
            ? null
            : Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.admin_panel_settings,
              size: 22,
              color: AdminColors.accent,
            ),
            const SizedBox(width: 8),
            Text(
              'ProServe Hub Admin',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          // Role badge
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Chip(
              label: Text(
                widget.role.label,
                style: const TextStyle(fontSize: 11),
              ),
              visualDensity: VisualDensity.compact,
              side: BorderSide(
                color: AdminColors.accent.withValues(alpha: 0.3),
              ),
              backgroundColor: AdminColors.accent.withValues(alpha: 0.1),
            ),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout, size: 20),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // Desktop sidebar
          if (isWide)
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) => setState(() => _selectedIndex = i),
              labelType: NavigationRailLabelType.all,
              leading: const SizedBox(height: 8),
              destinations: _navItems.asMap().entries.map((e) {
                final i = e.key;
                final item = e.value;
                int? badge;
                if (i == 2 && _pendingVerifications > 0) {
                  badge = _pendingVerifications;
                }
                if (i == 3 && _activeDisputes > 0) {
                  badge = _activeDisputes;
                }
                return NavigationRailDestination(
                  icon: badge != null
                      ? Badge(label: Text('$badge'), child: Icon(item.icon))
                      : Icon(item.icon),
                  selectedIcon: badge != null
                      ? Badge(
                          label: Text('$badge'),
                          child: Icon(item.selectedIcon),
                        )
                      : Icon(item.selectedIcon),
                  label: Text(item.label),
                );
              }).toList(),
            ),
          if (isWide)
            const VerticalDivider(
              thickness: 1,
              width: 1,
              color: AdminColors.line,
            ),
          // Content
          Expanded(child: _buildBody()),
        ],
      ),

      // Mobile bottom nav
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              backgroundColor: AdminColors.bgDeep,
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) => setState(() => _selectedIndex = i),
              destinations: _navItems.asMap().entries.map((e) {
                final i = e.key;
                final item = e.value;
                int? badge;
                if (i == 2 && _pendingVerifications > 0) {
                  badge = _pendingVerifications;
                }
                if (i == 3 && _activeDisputes > 0) {
                  badge = _activeDisputes;
                }
                return NavigationDestination(
                  icon: badge != null
                      ? Badge(label: Text('$badge'), child: Icon(item.icon))
                      : Icon(item.icon),
                  selectedIcon: badge != null
                      ? Badge(
                          label: Text('$badge'),
                          child: Icon(item.selectedIcon),
                        )
                      : Icon(item.selectedIcon),
                  label: item.label,
                );
              }).toList(),
            ),
    );
  }

  Widget _buildDrawerContent() {
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 16),
          const Icon(
            Icons.admin_panel_settings,
            size: 40,
            color: AdminColors.accent,
          ),
          const SizedBox(height: 8),
          Text(
            'PROSERVE HUB',
            style: GoogleFonts.bebasNeue(
              fontSize: 22,
              letterSpacing: 2,
              color: AdminColors.ink,
            ),
          ),
          Text(
            'Admin Console',
            style: GoogleFonts.manrope(fontSize: 12, color: AdminColors.muted),
          ),
          const SizedBox(height: 24),
          ..._navItems.asMap().entries.map((e) {
            final i = e.key;
            final item = e.value;
            final selected = _selectedIndex == i;
            int? badge;
            if (i == 2 && _pendingVerifications > 0) {
              badge = _pendingVerifications;
            }
            if (i == 3 && _activeDisputes > 0) {
              badge = _activeDisputes;
            }

            return ListTile(
              leading: badge != null
                  ? Badge(
                      label: Text('$badge'),
                      child: Icon(
                        selected ? item.selectedIcon : item.icon,
                        color: selected
                            ? AdminColors.accent
                            : AdminColors.muted,
                      ),
                    )
                  : Icon(
                      selected ? item.selectedIcon : item.icon,
                      color: selected ? AdminColors.accent : AdminColors.muted,
                    ),
              title: Text(
                item.label,
                style: TextStyle(
                  color: selected ? AdminColors.accent : AdminColors.ink,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              selected: selected,
              selectedTileColor: AdminColors.accent.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onTap: () {
                setState(() => _selectedIndex = i);
                Navigator.pop(context);
              },
            );
          }),
          const Spacer(),
          const Divider(color: AdminColors.line),
          ListTile(
            leading: const Icon(Icons.logout, color: AdminColors.muted),
            title: const Text('Sign out'),
            onTap: () => FirebaseAuth.instance.signOut(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _NavDestination {
  const _NavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
