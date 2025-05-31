import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lume/photo_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

enum FeedType { forYou, following }

class _HomePageState extends State<HomePage> {
  FeedType selectedFeed = FeedType.forYou;
  List<String> photos = [];
  bool isLoading = true;
  bool _hasSubscriptions = false;
  bool _isLoadingMore = false;
  int _page = 1;
  bool _hasMore = true;

  final supabase = Supabase.instance.client;
  final ScrollController _scrollController = ScrollController();
  final String unsplashAccessKey = 'eFV3DKjVfXYpht4wejCQKkfmhuQisFl9o7Cq9X4Fd7g';

  @override
  void initState() {
    super.initState();
    _checkSubscriptions();
    _loadInitialPhotos();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialPhotos() async {
    setState(() {
      isLoading = true;
      photos = [];
      _page = 1;
      _hasMore = true;
    });
    await _fetchPhotos();
  }

  Future<void> _checkSubscriptions() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      
      final response = await supabase
          .from('subscriptions')
          .select('count', const FetchOptions(count: CountOption.exact))
          .eq('subscriber_id', userId);

      setState(() {
        _hasSubscriptions = (response.count ?? 0) > 0;
      });
    } catch (e) {
      debugPrint('Error checking subscriptions: $e');
    }
  }

  Future<void> _fetchPhotos() async {
    if (!_hasMore) return;
    
    try {
      if (selectedFeed == FeedType.forYou) {
        final url = Uri.https('api.unsplash.com', '/photos/random', {
          'count': '20',
          'client_id': unsplashAccessKey,
          'page': _page.toString(),
        });
        
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = json.decode(response.body) as List;
          final newPhotos = data.map<String>((e) => e['urls']['regular'] as String).toList();
          
          setState(() {
            photos.addAll(newPhotos);
            isLoading = false;
            _hasMore = newPhotos.isNotEmpty;
          });
        }
      } else {
        final url = Uri.https('api.unsplash.com', '/photos/random', {
          'count': '20',
          'client_id': unsplashAccessKey,
          'page': _page.toString(),
        });
        
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = json.decode(response.body) as List;
          final newPhotos = data.map<String>((e) => e['urls']['regular'] as String).toList();
          
          setState(() {
            photos.addAll(newPhotos);
            isLoading = false;
            _hasMore = newPhotos.isNotEmpty;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching photos: $e');
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load photos: ${e.toString()}')),
      );
    }
  }

  Future<void> _loadMorePhotos() async {
    if (_isLoadingMore || !_hasMore) return;
    
    setState(() => _isLoadingMore = true);
    _page++;

    await _fetchPhotos();
    setState(() => _isLoadingMore = false);
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent * 0.8) {
      _loadMorePhotos();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECECE6),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildToggleButton('For you', FeedType.forYou),
                  const SizedBox(width: 20),
                  _buildToggleButton('Following', FeedType.following),
                ],
              ),
            ),

            Expanded(
              child: _hasSubscriptions || selectedFeed == FeedType.forYou
                  ? NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (!_isLoadingMore && 
                            notification.metrics.pixels >= 
                            notification.metrics.maxScrollExtent * 0.8) {
                          _loadMorePhotos();
                        }
                        return true;
                      },
                      child: _buildPhotoGrid(),
                    )
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "You don't have any subscriptions yet",
                              style: TextStyle(
                                color: Color(0xFF151515),
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "Discover and follow users to see their public photos here",
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
            ),

            if (_isLoadingMore)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton(String text, FeedType type) {
    final bool isSelected = selectedFeed == type;
    return GestureDetector(
      onTap: () {
        if (isSelected) return;
        setState(() {
          selectedFeed = type;
          _loadInitialPhotos();
          if (type == FeedType.following && !_hasSubscriptions) {
            _checkSubscriptions();
          }
        });
      },
      child: Container(
        width: 100,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF151515) : const Color(0x19151515),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: Color(0xFF151515),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoGrid() {
    if (isLoading && photos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (photos.isEmpty) {
      return const Center(
        child: Text(
          'No photos available',
          style: TextStyle(color: Color(0xFF151515)),
        ),
      );
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: photos.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= photos.length) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final photoUrl = photos[index];
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
            borderRadius: BorderRadius.circular(10),
            child: Hero(
              tag: photoUrl,
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
          ),
        );
      },
    );
  }
}