import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_saver/file_saver.dart';
import 'cluster_page.dart';

class PhotoPage extends StatefulWidget {
  final String photoUrl;
  final bool fromCluster;
  final String? clusterId;

  const PhotoPage({
    super.key,
    required this.photoUrl,
    this.fromCluster = false,
    this.clusterId,
  });

  @override
  State<PhotoPage> createState() => _PhotoPageState();
}

class _PhotoPageState extends State<PhotoPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _clusters = [];
  List<String> _photos = [];
  bool _isLoadingClusters = false;
  bool _isLoadingPhotos = true;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _clusterNameController = TextEditingController();
  bool _isClusterPublic = true;
  final ScrollController _scrollController = ScrollController();
  
  // Данные о пользователях, сохранивших фото
  List<Map<String, dynamic>> _savedByUsers = [];
  bool _isLoadingUsers = false;
  String? _photoId;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
    _loadClusters();
    _initializePhotoData();
  }

  Future<void> _initializePhotoData() async {
    await _getOrCreatePhotoId();
    await _loadSavedByUsers();
  }

  Future<void> _getOrCreatePhotoId() async {
    try {
      // Проверяем есть ли фото в базе
      final photoResponse = await _supabase
          .from('photos')
          .select('id')
          .eq('url', widget.photoUrl)
          .maybeSingle();

      if (photoResponse != null) {
        setState(() => _photoId = photoResponse['id'] as String);
      } else {
        // Создаем новую запись если фото не найдено
        final newPhoto = await _supabase
            .from('photos')
            .insert({
              'url': widget.photoUrl,
              'uploaded_by': _supabase.auth.currentUser?.id,
            })
            .select('id')
            .single();

        setState(() => _photoId = newPhoto['id'] as String);
      }
    } catch (e) {
      debugPrint('Error getting photo ID: $e');
    }
  }

  Future<void> _loadSavedByUsers() async {
  if (_photoId == null) return;

  setState(() => _isLoadingUsers = true);
  try {
    final response = await _supabase
        .from('cluster_photos')
        .select('''
          cluster:clusters!inner(
            user_id,
            user:users!inner(
              id,
              name,
              username,
              profile_image_url
            )
          )
        ''')
        .eq('photo_id', _photoId!)
        .eq('cluster.is_public', true);

    // Обрабатываем ответ правильно
    final users = (response as List)
        .where((e) => e['cluster'] != null && e['cluster']['user'] != null)
        .map((e) => e['cluster']['user'] as Map<String, dynamic>)
        .toList();

    // Удаляем дубликаты пользователей
    final uniqueUsers = users.fold<Map<String, Map<String, dynamic>>>(
      {},
      (map, user) => map..putIfAbsent(user['id'], () => user),
    ).values.toList();

    setState(() {
      _savedByUsers = uniqueUsers;
    });
  } catch (e) {
    debugPrint('Error loading saved by users: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading saved users: ${e.toString()}')),
      );
    }
  } finally {
    if (mounted) {
      setState(() => _isLoadingUsers = false);
    }
  }
}

  Future<void> _followUser(String userId) async {
    try {
      await _supabase.from('subscriptions').insert({
        'subscriber_id': _supabase.auth.currentUser!.id,
        'subscribed_to_id': userId,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully followed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error following: ${e.toString()}')),
        );
      }
    }
  }

  void _showSavedByUsersDialog() {
  if (_savedByUsers.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No users have saved this photo yet')),
    );
    return;
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF151515),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    isScrollControlled: true,
    builder: (context) {
      return Container(
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Saved by',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _savedByUsers.length,
                itemBuilder: (context, index) {
                  final user = _savedByUsers[index];
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundImage: user['profile_image_url'] != null
                          ? NetworkImage(user['profile_image_url'])
                          : null,
                      child: user['profile_image_url'] == null
                          ? const Icon(Icons.person, size: 20)
                          : null,
                    ),
                    title: Text(
                      user['name'] ?? 'No name',
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      '@${user['username'] ?? 'username'}',
                      style: const TextStyle(color: Color(0xFF767673)),
                    ),
                    trailing: _supabase.auth.currentUser?.id != user['id']
                        ? ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFECECE6),
                              minimumSize: const Size(100, 36),
                            ),
                            onPressed: () => _followUser(user['id']),
                            child: const Text(
                              'Follow',
                              style: TextStyle(color: Color(0xFF151515)),
                            ),
                          )
                        : null,
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFECECE6),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Color(0xFF151515)),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

  Future<void> _loadPhotos() async {
    try {
      final response = await http.get(Uri.https(
        'api.unsplash.com',
        '/photos/random',
        {
          'count': '100',
          'client_id': 'eFV3DKjVfXYpht4wejCQKkfmhuQisFl9o7Cq9X4Fd7g',
        },
      ));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _photos = (data as List)
              .map<String>((e) => e['urls']['regular'] as String)
              .toList();
          _isLoadingPhotos = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingPhotos = false);
    }
  }

  Future<void> _loadClusters() async {
    if (_supabase.auth.currentUser == null) return;
    
    setState(() => _isLoadingClusters = true);
    
    try {
      final response = await _supabase
          .from('clusters')
          .select('''
            id, 
            name, 
            is_public,
            cluster_photos(count)
          ''')
          .eq('user_id', _supabase.auth.currentUser!.id)
          .order('created_at', ascending: false);

      setState(() {
        _clusters = (response as List).map<Map<String, dynamic>>((cluster) {
          return {
            'id': cluster['id'],
            'name': cluster['name'],
            'is_public': cluster['is_public'],
            'count': cluster['cluster_photos'][0]['count'] ?? 0,
          };
        }).toList();
        _isLoadingClusters = false;
      });
    } catch (e) {
      debugPrint('Error loading clusters: $e');
      setState(() => _isLoadingClusters = false);
    }
  }

  Future<void> _downloadImage() async {
    try {
      if (!kIsWeb) {
        final status = await Permission.storage.request();
        if (!status.isGranted) return;
      }

      final directory = kIsWeb 
          ? null 
          : await getApplicationDocumentsDirectory();
      final fileName = 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savePath = kIsWeb ? fileName : '${directory!.path}/$fileName';

      final response = await http.get(Uri.parse(widget.photoUrl));
      
      if (kIsWeb) {
        await FileSaver.instance.saveFile(
          name: fileName,
          bytes: response.bodyBytes,
          mimeType: MimeType.jpeg,
        );
      } else {
        final file = File(savePath);
        await file.writeAsBytes(response.bodyBytes);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image saved ${kIsWeb ? '' : 'to $savePath'}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download: ${e.toString()}')),
        );
      }
      debugPrint('Download error: $e');
    }
  }

  Future<void> _addToCluster(String clusterId) async {
    if (_photoId == null) return;
    
    try {
      final existingLink = await _supabase
          .from('cluster_photos')
          .select()
          .eq('cluster_id', clusterId)
          .eq('photo_id', _photoId!)
          .maybeSingle();

      if (existingLink == null) {
        await _supabase.from('cluster_photos').insert({
          'cluster_id': clusterId,
          'photo_id': _photoId!,
        });

        await _loadClusters();
        await _loadSavedByUsers();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Added to cluster successfully')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo already in this cluster')),
          );
        }
      }

      if (mounted && widget.fromCluster && widget.clusterId != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ClusterPage(
              clusterId: widget.clusterId!,
              clusterName: _clusters.firstWhere(
                (c) => c['id'] == widget.clusterId)['name'],
            ),
          ),
        );
      } else if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding to cluster: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _createNewCluster() async {
    if (_clusterNameController.text.isEmpty) return;
    
    try {
      setState(() => _isLoadingClusters = true);
      
      final response = await _supabase
          .from('clusters')
          .insert({
            'user_id': _supabase.auth.currentUser?.id,
            'name': _clusterNameController.text,
            'is_public': _isClusterPublic,
          })
          .select('id, name, is_public');

      final newCluster = response[0] as Map<String, dynamic>;
      _clusterNameController.clear();
      
      setState(() {
        _clusters.insert(0, {
          ...newCluster,
          'count': 0,
        });
      });
      
      Navigator.pop(context);
      await _addToCluster(newCluster['id']);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating cluster: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoadingClusters = false);
    }
  }

  void _showAddToClusterDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151515),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add to Cluster',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFD9D9D9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search clusters',
                    prefixIcon: Icon(Icons.search),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoadingClusters
                    ? const Center(child: CircularProgressIndicator())
                    : _clusters.isEmpty
                        ? const Center(
                            child: Text(
                              'No clusters found',
                              style: TextStyle(color: Colors.white),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _clusters.length,
                            itemBuilder: (context, index) {
                              final cluster = _clusters[index];
                              return ListTile(
                                leading: const Icon(Icons.bookmark, color: Colors.white),
                                title: Text(
                                  cluster['name'],
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: Text(
                                  '${cluster['count']} elements',
                                  style: const TextStyle(color: Color(0xFF767673)),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.add, color: Colors.white),
                                  onPressed: () => _addToCluster(cluster['id']),
                                ),
                              );
                            },
                          ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFECECE6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _showCreateClusterDialog,
                  child: const Text(
                    'Create New Cluster',
                    style: TextStyle(color: Color(0xFF151515)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showCreateClusterDialog() {
    showDialog(
      context: context,
      builder: (context) {
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
              onPressed: _createNewCluster,
              child: const Text(
                'Create',
                style: TextStyle(color: Color(0xFF151515)),
              ),
            ),
          ],
        );
      },
    );
  }

 @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECECE6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFECECE6),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF151515)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isLoadingUsers)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
        ],
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverList(
            delegate: SliverChildListDelegate([
              Container(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.6,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD9D9D9),
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: NetworkImage(widget.photoUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildActionButton(Icons.download, 40, _downloadImage),
                    const SizedBox(width: 32),
                    _buildActionButton(Icons.add, 50, _showAddToClusterDialog, isWide: true),
                    const SizedBox(width: 32),
                    _buildActionButton(Icons.more_vert, 40, () {}),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20), // Добавлен отступ
                child: Text(
                  'More photos',
                  style: TextStyle(
                    color: Color(0xFF151515),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ]),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20), // Добавлены отступы
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.75,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PhotoPage(
                            photoUrl: _photos[index],
                            fromCluster: widget.fromCluster,
                            clusterId: widget.clusterId,
                          ),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _photos[index],
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: const Color(0xFFD9D9D9),
                            child: Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: const Color(0xFFD9D9D9),
                          child: const Center(child: Icon(Icons.broken_image)),
                        ),
                      ),
                    ),
                  );
                },
                childCount: _photos.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, double size, VoidCallback onPressed, {bool isWide = false}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: isWide ? size * 1.5 : size,
        height: size,
        decoration: BoxDecoration(
          shape: isWide ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: isWide ? BorderRadius.circular(size) : null,
          border: Border.all(color: const Color(0xFF151515)),
        ),
        child: Icon(icon, color: const Color(0xFF151515)),
      ),
    );
  }
}