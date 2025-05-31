import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cluster_page.dart';

class PublicProfilePage extends StatefulWidget {
  final String userId;

  const PublicProfilePage({Key? key, required this.userId}) : super(key: key);

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage> {
  final _supabase = Supabase.instance.client;
  
  bool _isLoading = false;
  bool _isFollowing = false;
  bool _isProcessingFollow = false;
  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _clusters = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkIfFollowing();
  }

  Future<void> _checkIfFollowing() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      final response = await _supabase
          .from('subscriptions')
          .select()
          .eq('subscriber_id', currentUserId)
          .eq('subscribed_to_id', widget.userId)
          .maybeSingle();

      setState(() {
        _isFollowing = response != null;
      });
    } catch (e) {
      debugPrint('Error checking follow status: $e');
    }
  }

  Future<void> _toggleFollow() async {
    try {
      setState(() => _isProcessingFollow = true);
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      if (_isFollowing) {
        await _supabase
            .from('subscriptions')
            .delete()
            .eq('subscriber_id', currentUserId)
            .eq('subscribed_to_id', widget.userId);
      } else {
        await _supabase.from('subscriptions').insert({
          'subscriber_id': currentUserId,
          'subscribed_to_id': widget.userId,
        });
      }

      setState(() => _isFollowing = !_isFollowing);
    } catch (e) {
      debugPrint('Error toggling follow: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isProcessingFollow = false);
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([_loadUserData(), _loadClusters()]);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load data: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUserData() async {
    final response = await _supabase
        .from('users')
        .select('id, name, username, profile_image_url')
        .eq('id', widget.userId)
        .single();

    final followingCount = await _supabase
        .from('subscriptions')
        .select('count', const FetchOptions(count: CountOption.exact))
        .eq('subscriber_id', widget.userId);

    setState(() {
      _userData = {
        ...response as Map<String, dynamic>,
        'following_count': followingCount.count ?? 0,
      };
    });
  }

  Future<void> _loadClusters() async {
    final response = await _supabase
        .from('clusters')
        .select('id, name, created_at')
        .eq('user_id', widget.userId)
        .eq('is_public', true) // Только публичные кластеры
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
        };
      }),
    );

    setState(() => _clusters = clusters);
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        const SizedBox(height: 20),
        CircleAvatar(
          radius: 50,
          backgroundImage: _userData?['profile_image_url'] != null
              ? NetworkImage(_userData!['profile_image_url'])
              : null,
          child: _userData?['profile_image_url'] == null
              ? const Icon(Icons.person, size: 50)
              : null,
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
        _buildFollowButton(),
        const SizedBox(height: 30),
      ],
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
        Container(
          width: 5,
          height: 5,
          decoration: const ShapeDecoration(
            color: Color(0xFF767673),
            shape: OvalBorder(),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${_userData?['following_count'] ?? 0} Following',
          style: const TextStyle(color: Color(0x7F151515), fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildFollowButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: _isFollowing 
            ? const Color(0xFF151515)
            : const Color(0xFFECECE6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF151515)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
      ),
      onPressed: _isProcessingFollow ? null : _toggleFollow,
      child: Text(
        _isFollowing ? 'Following' : 'Follow',
        style: TextStyle(
          color: _isFollowing 
              ? const Color(0xFFECECE6)
              : const Color(0xFF151515),
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildClustersGrid() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 0.75,
      ),
      itemCount: _clusters.length,
      itemBuilder: (context, index) {
        final cluster = _clusters[index];
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
              Text(
                cluster['name'],
                style: const TextStyle(
                  color: Color(0xFF151515),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
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
      },
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
      appBar: AppBar(
        backgroundColor: const Color(0xFFECECE6),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF151515)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _userData?['name'] ?? 'Profile',
          style: const TextStyle(color: Color(0xFF151515)),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildProfileHeader(),
            _clusters.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text(
                      'No public clusters yet',
                      style: TextStyle(color: Color(0xFF151515)),
                    ),
                  )
                : _buildClustersGrid(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}