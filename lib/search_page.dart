import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'photo_page.dart';
import 'public_profile_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  List<String> _photos = [];
  List<Map<String, dynamic>> _users = [];
  List<String> _tags = ['Featured', 'Graphic Design', 'Architecture', 'Nature', 'Art'];
  String _selectedTag = 'Featured';
  bool _isLoading = false;
  int _page = 1;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadFeaturedPhotos();
    _scrollController.addListener(_scrollListener);
    _searchController.addListener(_searchPhotos);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFeaturedPhotos() async {
    setState(() {
      _isLoading = true;
      _photos = [];
      _users = [];
      _page = 1;
      _hasMore = true;
    });
    await _fetchPhotos(query: 'minimalism');
  }

  Future<void> _fetchPhotos({String? query}) async {
    if (!_hasMore) return;

    try {
      final url = Uri.https(
        'api.unsplash.com',
        '/search/photos',
        {
          'query': query ?? _selectedTag.toLowerCase(),
          'page': _page.toString(),
          'per_page': '20',
          'client_id': 'eFV3DKjVfXYpht4wejCQKkfmhuQisFl9o7Cq9X4Fd7g',
        },
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newPhotos = (data['results'] as List)
            .map<String>((e) => e['urls']['regular'] as String)
            .toList();

        setState(() {
          _photos.addAll(newPhotos);
          _isLoading = false;
          _hasMore = newPhotos.length == 20;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error fetching photos: $e');
    }
  }

  Future<void> _searchUsers(String query) async {
    try {
      final response = await _supabase
          .from('users')
          .select('id, name, username, profile_image_url')
          .or('name.ilike.%$query%,username.ilike.%$query%')
          .limit(5);

      setState(() {
        _users = (response as List).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      debugPrint('Error searching users: $e');
    }
  }

  Future<void> _searchPhotos() async {
    if (_searchController.text.isEmpty) {
      await _loadFeaturedPhotos();
      return;
    }

    setState(() {
      _isLoading = true;
      _photos = [];
      _users = [];
      _page = 1;
      _hasMore = true;
    });

    await _searchUsers(_searchController.text);
    await _fetchPhotos(query: _searchController.text);
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent * 0.8) {
      _page++;
      _fetchPhotos();
    }
  }

  void _selectTag(String tag) {
    setState(() {
      _selectedTag = tag;
      _searchController.clear();
      _users = [];
    });
    _loadPhotosByTag(tag);
  }

  Future<void> _loadPhotosByTag(String tag) async {
    setState(() {
      _isLoading = true;
      _photos = [];
      _users = [];
      _page = 1;
      _hasMore = true;
    });
    await _fetchPhotos();
  }

  Widget _buildUserItem(Map<String, dynamic> user) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PublicProfilePage(
              userId: user['id'],
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 16.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: user['profile_image_url'] != null
                  ? NetworkImage(user['profile_image_url'])
                  : null,
              child: user['profile_image_url'] == null
                  ? const Icon(Icons.person, size: 30)
                  : null,
            ),
            const SizedBox(height: 4),
            Text(
              '@${user['username'] ?? 'username'}',
              style: const TextStyle(
                color: Color(0xFF151515),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoItem(String photoUrl) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PhotoPage(
              photoUrl: photoUrl,
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          photoUrl,
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECECE6),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFD9D9D9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search',
                    hintStyle: const TextStyle(color: Color(0x7F151515)),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF151515)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  style: const TextStyle(color: Color(0xFF151515)),
                ),
              ),
            ),

            // Tags
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _tags.length,
                itemBuilder: (context, index) {
                  final tag = _tags[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: GestureDetector(
                      onTap: () => _selectTag(tag),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: _selectedTag == tag 
                                  ? const Color(0xFF151515) 
                                  : Colors.transparent,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            color: const Color(0xFF151515),
                            fontWeight: _selectedTag == tag 
                                ? FontWeight.bold 
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Users List (only shown when searching)
            if (_users.isNotEmpty)
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _users.length,
                  itemBuilder: (context, index) => _buildUserItem(_users[index]),
                ),
              ),

            // Photos Grid
            Expanded(
              child: _isLoading && _photos.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (!_isLoading && 
                            notification.metrics.pixels >= 
                            notification.metrics.maxScrollExtent * 0.8) {
                          _page++;
                          _fetchPhotos();
                        }
                        return true;
                      },
                      child: GridView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.75,
                        ),
                        itemCount: _photos.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= _photos.length) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          return _buildPhotoItem(_photos[index]);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}