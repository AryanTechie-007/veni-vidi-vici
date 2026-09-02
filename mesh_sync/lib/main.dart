// MeshSync — offline SOS relay over Google Nearby Connections, P2P_CLUSTER.
//
// This file is the shell only: the sign-in gate and the two tabs. The radio
// lives in mesh_service.dart, the propagation rules in messages/mesh_router.dart,
// and mesh_app.dart wires them together.

import 'package:flutter/material.dart';

import 'auth.dart';
import 'mesh_app.dart';
import 'mesh_service.dart';
import 'device_identity.dart';
import 'ui/home_screen.dart';
import 'ui/login_screen.dart';
import 'ui/mesh_fault_ui.dart';
import 'ui/profile_screen.dart';
import 'ui/responder_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Identity and the persisted seq counter must be loaded before anything can
  // create a message, so this happens up front rather than in initState.
  final app = await MeshApp.create();
  runApp(MeshSyncApp(app: app));
}

class MeshSyncApp extends StatefulWidget {
  const MeshSyncApp({super.key, required this.app});

  final MeshApp app;

  @override
  State<MeshSyncApp> createState() => _MeshSyncAppState();
}

class _MeshSyncAppState extends State<MeshSyncApp> {
  MeshApp get _app => widget.app;

  final GlobalKey<NavigatorState> _navigator = GlobalKey<NavigatorState>();

  /// The fault the dialog last reported, so a rebuild does not raise it again.
  MeshFault? _reportedFault;

  @override
  void initState() {
    super.initState();
    _app.service.addListener(_onServiceChanged);
    // A returning user is already signed in, so the mesh should come up on
    // launch without waiting for a tap. Deferred a frame so a fault can raise
    // its dialog against a mounted navigator.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_app.isSignedIn) _startMesh();
    });
  }

  @override
  void dispose() {
    _app.service.removeListener(_onServiceChanged);
    _app.dispose();
    super.dispose();
  }

  /// Raises the dialog once per fault, from wherever the failure came from —
  /// launch, sign-in, or the Start button.
  void _onServiceChanged() {
    final fault = _app.service.fault;
    if (fault == MeshFault.none) {
      _reportedFault = null;
      return;
    }
    if (fault == _reportedFault) return;
    _reportedFault = fault;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _navigator.currentContext;
      if (context == null || !context.mounted) return;
      showMeshFaultDialog(context, _app.service);
    });
  }

  /// Brings the radio up. Nothing can be sent or relayed until it is.
  ///
  /// If permissions were refused, requestPermissions has already recorded the
  /// reason; starting anyway would fail and overwrite it with a vaguer one.
  Future<void> _startMesh() async {
    if (await _app.service.requestPermissions()) {
      await _app.service.start();
    }
  }

  Future<void> _signIn(Account account) async {
    await _app.signIn(account);
    await _startMesh();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MeshSync',
      navigatorKey: _navigator,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
      ),
      home: ListenableBuilder(
        // One builder covers both notifiers: the coordinator for messages,
        // role and session; the service for connection state.
        listenable: Listenable.merge([_app, _app.service]),
        builder: (context, _) => _app.isSignedIn
            ? MeshHomePage(app: _app)
            : LoginScreen(onSignedIn: _signIn),
      ),
    );
  }
}

class MeshHomePage extends StatefulWidget {
  const MeshHomePage({super.key, required this.app});

  final MeshApp app;

  @override
  State<MeshHomePage> createState() => _MeshHomePageState();
}

class _MeshHomePageState extends State<MeshHomePage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final responder = app.role == MeshRole.responder;

    // Home is the incident dashboard for a responder and the SOS screen for a
    // victim — the same tab, a different job.
    final pages = <Widget>[
      responder ? ResponderScreen(app: app) : HomeScreen(app: app),
      ProfileScreen(app: app),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(responder ? 'Responder' : 'MeshSync'),
        centerTitle: true,
      ),
      body: SafeArea(child: pages[_tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
