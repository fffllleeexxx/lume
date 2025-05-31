import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lume/home_page.dart';
import 'package:lume/login_page.dart';
import 'package:lume/register_page.dart';
import 'package:lume/profile_page.dart';
import 'package:lume/app_bottom_nav.dart';
import 'package:lume/search_page.dart';
import 'package:lume/create_menu.dart';
import 'package:mime/mime.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://gleewuzsjyctzfwkhogh.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdsZWV3dXpzanljdHpmd2tob2doIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc2ODEyMjAsImV4cCI6MjA2MzI1NzIyMH0.CabKpUE8ZkPiMy5lT1PLZsImVIT65s2ftlDuybEXTNw',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lume',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFECECE6),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFD9D9D9),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF151515), width: 2),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          labelStyle: const TextStyle(
            color: Color(0xFF151515),
          ),
          hintStyle: const TextStyle(
            color: Color(0xFF151515),
          ),
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Color(0xFF151515),
          selectionColor: Color(0xFFD9D9D9),
          selectionHandleColor: Color(0xFF151515),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF151515),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF151515),
            foregroundColor: const Color(0xFFECECE6),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      home: const AuthWrapper(),
      routes: {
        '/main': (context) => const MainWrapper(),
      },
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginPage());
          case '/register':
            return MaterialPageRoute(builder: (_) => const RegisterPage());
          default:
            return MaterialPageRoute(
              builder: (_) => const AuthWrapper(),
            );
        }
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
    _setupAuthListener();
  }

  Future<void> _checkAuth() async {
    try {
      final session = _supabase.auth.currentSession;
      if (mounted) {
        setState(() {
          _isAuthenticated = session != null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _setupAuthListener() {
    _supabase.auth.onAuthStateChange.listen((event) {
      if (mounted) {
        setState(() {
          _isAuthenticated = event.session != null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return _isAuthenticated ? const MainWrapper() : const LoginPage();
  }
}

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _currentIndex = 0;
  final TextEditingController _clusterNameController = TextEditingController();
  bool _isClusterPublic = true;
  bool _isLoading = false;

  final List<Widget> _pages = const [
    HomePage(),
    SearchPage(),
    Placeholder(), // Add Page (будет заменен на меню создания)
    ProfilePage(),
  ];

  void _showCreateMenu(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => CreateMenu(
        onClusterSelected: () {
          Navigator.pop(context);
          _showCreateClusterDialog(context);
        },
        onElementSelected: () {
          Navigator.pop(context);
          _addToFavorites(context);
        },
      ),
    );
  }

  Future<void> _showCreateClusterDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF151515),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'New Cluster',
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _clusterNameController,
                    decoration: InputDecoration(
                      hintText: 'Cluster name',
                      filled: true,
                      fillColor: const Color(0xFFD9D9D9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text(
                        'Public',
                        style: TextStyle(color: Colors.white),
                      ),
                      const Spacer(),
                      Switch(
                        value: _isClusterPublic,
                        onChanged: (value) => setState(() => _isClusterPublic = value),
                        activeColor: const Color(0xFFECECE6),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFECECE6),
                  ),
                  onPressed: _isLoading
                      ? null
                      : () async {
                          if (_clusterNameController.text.isEmpty) return;
                          
                          setState(() => _isLoading = true);
                          try {
                            final userId = Supabase.instance.client.auth.currentUser?.id;
                            if (userId == null) return;

                            await Supabase.instance.client.from('clusters').insert({
                              'user_id': userId,
                              'name': _clusterNameController.text,
                              'is_public': _isClusterPublic,
                            });
                            
                            _clusterNameController.clear();
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Cluster created successfully')),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error creating cluster: ${e.toString()}')),
                            );
                          } finally {
                            setState(() => _isLoading = false);
                          }
                        },
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF151515),
                          ),
                        )
                      : const Text(
                          'Create',
                          style: TextStyle(color: Color(0xFF151515)),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

Future<void> _addToFavorites(BuildContext context) async {
  final picker = ImagePicker();
  final pickedFile = await picker.pickImage(source: ImageSource.gallery);
  if (pickedFile == null) return;

  setState(() => _isLoading = true);

  try {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final bytes = await pickedFile.readAsBytes();
    final fileExt = pickedFile.path.split('.').last.toLowerCase();
    final fileName = 'favorites/${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    const bucketName = 'user_uploads';

    debugPrint('Starting upload to $bucketName/$fileName');

    await supabase.storage
        .from(bucketName)
        .uploadBinary(
          fileName,
          bytes,
          fileOptions: FileOptions(
            contentType: lookupMimeType(pickedFile.path) ?? 'image/jpeg',
            upsert: false,
          ),
        );

    final imageUrl = supabase.storage
        .from(bucketName)
        .getPublicUrl(fileName);

    debugPrint('Image URL: $imageUrl');

    final clusterResponse = await supabase
        .from('clusters')
        .select('id')
        .eq('user_id', userId)
        .eq('name', 'Favorites')
        .maybeSingle();

    String clusterId;
    
    if (clusterResponse == null) {
      final newCluster = await supabase
          .from('clusters')
          .insert({
            'user_id': userId,
            'name': 'Favorites',
            'is_public': false,
          })
          .select('id')
          .single();
      
      clusterId = newCluster['id'] as String;
    } else {
      clusterId = clusterResponse['id'] as String;
    }

    final photoResponse = await supabase
        .from('photos')
        .insert({
          'url': imageUrl,
          'uploaded_by': userId,
          'created_at': DateTime.now().toIso8601String(),
        })
        .select('id')
        .single();

    await supabase.from('cluster_photos').insert({
      'cluster_id': clusterId,
      'photo_id': photoResponse['id'],
      'added_at': DateTime.now().toIso8601String(),
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Added to Favorites')),
      );
    }
  } catch (e) {
    debugPrint('Error adding to favorites: $e');
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: ${e.toString()}')),
      );
    }
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECECE6),
      body: _pages[_currentIndex],
      bottomNavigationBar: AppBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 2) {
            _showCreateMenu(context);
          } else {
            setState(() {
              _currentIndex = index;
            });
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _clusterNameController.dispose();
    super.dispose();
  }
}