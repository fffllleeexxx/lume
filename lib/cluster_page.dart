import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'photo_page.dart';

class ClusterPage extends StatefulWidget {
  final String clusterId;
  final String clusterName;

  const ClusterPage({
    Key? key,
    required this.clusterId,
    required this.clusterName,
  }) : super(key: key);

  @override
  State<ClusterPage> createState() => _ClusterPageState();
}

class _ClusterPageState extends State<ClusterPage> {
  final _supabase = Supabase.instance.client;
  List<String> _photos = [];
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  int _page = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
    _scrollController.addListener(_scrollListener);
  }

  Future<void> _loadPhotos() async {
    if (!_hasMore) return;
    
    try {
      final response = await _supabase
          .from('cluster_photos')
          .select('photos(url)')
          .eq('cluster_id', widget.clusterId)
          .order('added_at', ascending: false)
          .range((_page - 1) * 20, _page * 20 - 1);

      final newPhotos = (response as List)
          .map<String>((e) => e['photos']['url'] as String)
          .toList();

      setState(() {
        _photos.addAll(newPhotos);
        _isLoading = false;
        _hasMore = newPhotos.length == 20;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading cluster photos: $e');
    }
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent * 0.8) {
      _page++;
      _loadPhotos();
    }
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
        title: Text(
          widget.clusterName,
          style: const TextStyle(color: Color(0xFF151515)),
        ),
      ),
      body: _isLoading && _photos.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
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
                final photoUrl = _photos[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PhotoPage(
                          photoUrl: photoUrl,
                          fromCluster: true,
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
              },
            ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}