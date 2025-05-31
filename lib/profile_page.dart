import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:mime/mime.dart';
import 'cluster_page.dart';
import 'login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _supabase = Supabase.instance.client;
  final _picker = ImagePicker();
  final _searchController = TextEditingController();
  final _clusterNameController = TextEditingController();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isClusterPublic = true;
  File? _selectedImage;
  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _clusters = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

Future<void> _signOut() async {
  try {
    setState(() => _isLoading = true);
    await _supabase.auth.signOut();
    
    // Перенаправляем на LoginPage и полностью очищаем стек
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (Route<dynamic> route) => false,
    );
  } catch (e) {
    _showErrorSnackbar('Failed to sign out: ${e.toString()}');
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([_loadUserData(), _loadClusters()]);
    } catch (e) {
      _showErrorSnackbar('Failed to load data: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUserData() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final response = await _supabase
        .from('users')
        .select('name, username, profile_image_url')
        .eq('id', userId)
        .single();

    final followingCount = await _supabase
        .from('subscriptions')
        .select('count', const FetchOptions(count: CountOption.exact))
        .eq('subscriber_id', userId);

    setState(() {
      _userData = {
        ...response as Map<String, dynamic>,
        'following_count': followingCount.count ?? 0,
      };
    });
  }

  Future<void> _loadClusters() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final response = await _supabase
        .from('clusters')
        .select('id, name, created_at, is_public')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    final clusters = await Future.wait(
      (response as List).map((cluster) async {
        final count = await _supabase
            .from('cluster_photos')
            .select('count', const FetchOptions(count: CountOption.exact))
            .eq('cluster_id', cluster['id']);

        final cover = await _supabase
            .from('cluster_photos')
            .select('photos(url)')
            .eq('cluster_id', cluster['id'])
            .order('added_at', ascending: false)
            .limit(1);

        return {
          'id': cluster['id'],
          'name': cluster['name'],
          'count': count.count ?? 0,
          'cover_url': cover.isNotEmpty ? cover[0]['photos']['url'] : null,
          'is_public': cluster['is_public'],
        };
      }),
    );

    setState(() => _clusters = clusters);
  }

  Future<void> _uploadProfileImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (pickedFile == null) return;

      setState(() => _isSaving = true);

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final bytes = await pickedFile.readAsBytes();
      final fileExt = pickedFile.path.split('.').last.toLowerCase();
      final fileName = 'profile_$userId.$fileExt';
      const bucketName = 'avatars';

      await _supabase.storage
          .from(bucketName)
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(
              contentType: lookupMimeType(pickedFile.path) ?? 'image/jpeg',
              upsert: true,
            ),
          );

      final imageUrl = _supabase.storage
          .from(bucketName)
          .getPublicUrl(fileName);

      await _supabase
          .from('users')
          .update({'profile_image_url': imageUrl})
          .eq('id', userId);

      if (mounted) {
        setState(() {
          _selectedImage = null;
        });
        await _loadUserData();
        _showSuccessSnackbar('Profile image updated successfully!');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Failed to update profile image: ${e.toString()}');
      }
      debugPrint('Error uploading profile image: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _createCluster() async {
    if (_clusterNameController.text.isEmpty) return;
    
    try {
      setState(() => _isSaving = true);
      await _supabase.from('clusters').insert({
        'user_id': _supabase.auth.currentUser?.id,
        'name': _clusterNameController.text,
        'is_public': _isClusterPublic,
      });
      _clusterNameController.clear();
      await _loadClusters();
      _showSuccessSnackbar('Cluster created successfully');
    } catch (e) {
      _showErrorSnackbar('Failed to create cluster: ${e.toString()}');
    } finally {
      setState(() => _isSaving = false);
      Navigator.pop(context);
    }
  }

  Future<void> _updateProfile() async {
    try {
      setState(() => _isSaving = true);
      await _supabase.from('users').update({
        'name': _nameController.text,
        'username': _usernameController.text,
      }).eq('id', _supabase.auth.currentUser?.id);
      
      await _loadUserData();
      _showSuccessSnackbar('Profile updated successfully');
    } catch (e) {
      _showErrorSnackbar('Failed to update profile: ${e.toString()}');
    } finally {
      setState(() => _isSaving = false);
      Navigator.pop(context);
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showCreateClusterDialog() {
    showDialog(
      context: context,
      builder: (context) => _buildClusterDialog(),
    );
  }

  void _showEditProfileDialog() {
    _nameController.text = _userData?['name'] ?? '';
    _usernameController.text = _userData?['username'] ?? '';
    showDialog(
      context: context,
      builder: (context) => _buildProfileDialog(),
    );
  }

  Widget _buildClusterDialog() {
    return AlertDialog(
      backgroundColor: const Color(0xFF151515),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('New Cluster', style: TextStyle(color: Colors.white)),
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
              const Text('Public', style: TextStyle(color: Colors.white)),
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
          child: const Text('Cancel', style: TextStyle(color: Colors.white)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFECECE6)),
          onPressed: _isSaving ? null : _createCluster,
          child: _isSaving
              ? const CircularProgressIndicator()
              : const Text('Create', style: TextStyle(color: Color(0xFF151515))),
        ),
      ],
    );
  }

  Widget _buildProfileDialog() {
    return AlertDialog(
      backgroundColor: const Color(0xFF151515),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Edit Profile', style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                filled: true,
                fillColor: const Color(0xFFD9D9D9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Username',
                filled: true,
                fillColor: const Color(0xFFD9D9D9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFECECE6)),
          onPressed: _isSaving ? null : _updateProfile,
          child: _isSaving
              ? const CircularProgressIndicator()
              : const Text('Save', style: TextStyle(color: Color(0xFF151515))),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> get _filteredClusters {
    if (_searchQuery.isEmpty) return _clusters;
    return _clusters.where((cluster) => 
      cluster['name'].toLowerCase().contains(_searchQuery)).toList();
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTap: _uploadProfileImage,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: _buildProfileImage(),
                child: _buildProfilePlaceholder(),
              ),
            ),
            if (_isSaving) _buildLoadingOverlay(),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          _userData?['name'] ?? 'No name',
          style: const TextStyle(
            color: Color(0xFF151515),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        _buildUserInfoRow(),
        const SizedBox(height: 20),
        _buildEditProfileButton(),
        const SizedBox(height: 30),
      ],
    );
  }

  ImageProvider? _buildProfileImage() {
    if (_selectedImage != null) return FileImage(_selectedImage!);
    if (_userData?['profile_image_url'] != null) {
      return NetworkImage(_userData!['profile_image_url']);
    }
    return null;
  }

  Widget? _buildProfilePlaceholder() {
    if (_selectedImage == null && _userData?['profile_image_url'] == null) {
      return const Icon(Icons.person, size: 50);
    }
    return null;
  }

  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(50),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildUserInfoRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '@${_userData?['username'] ?? 'username'}',
          style: const TextStyle(color: Color(0x7F151515), fontSize: 14),
        ),
        const SizedBox(width: 8),
        _buildInfoDivider(),
        const SizedBox(width: 8),
        Text(
          '${_userData?['following_count'] ?? 0} Following',
          style: const TextStyle(color: Color(0x7F151515), fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildInfoDivider() {
    return Container(
      width: 5,
      height: 5,
      decoration: const ShapeDecoration(
        color: Color(0xFF767673),
        shape: OvalBorder(),
      ),
    );
  }

  Widget _buildEditProfileButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFECECE6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF151515)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
      ),
      onPressed: _showEditProfileDialog,
      child: const Text(
        'Edit Profile',
        style: TextStyle(color: Color(0xFF151515), fontSize: 14),
      ),
    );
  }

  Widget _buildClustersGrid() {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 0.75,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == _filteredClusters.length) {
            return _buildNewClusterButton();
          }
          return _buildClusterItem(_filteredClusters[index]);
        },
        childCount: _filteredClusters.length + 1,
      ),
    );
  }

  Widget _buildNewClusterButton() {
    return GestureDetector(
      onTap: _showCreateClusterDialog,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFD9D9D9),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Center(child: Icon(Icons.add, size: 50)),
          ),
          const SizedBox(height: 8),
          const Text(
            'New Cluster',
            style: TextStyle(
              color: Color(0xFF151515),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClusterItem(Map<String, dynamic> cluster) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ClusterPage(
              clusterId: cluster['id'],
              clusterName: cluster['name'],
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFD9D9D9),
                borderRadius: BorderRadius.circular(30),
                image: cluster['cover_url'] != null
                    ? DecorationImage(
                        image: NetworkImage(cluster['cover_url']),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                cluster['name'],
                style: const TextStyle(
                  color: Color(0xFF151515),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Icon(
                cluster['is_public'] ? Icons.public : Icons.lock_outline,
                size: 16,
                color: const Color(0xFF767673),
              ),
            ],
          ),
          Text(
            '${cluster['count']} elements',
            style: const TextStyle(
              color: Color(0x7F151515),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _userData == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFECECE6),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFECECE6),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: const Color(0xFFECECE6),
            title: Container(
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
            centerTitle: true,
            pinned: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout, color: Color(0xFF151515)),
                onPressed: _signOut,
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: _buildProfileHeader(),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: _buildClustersGrid(),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
    );
  }
}