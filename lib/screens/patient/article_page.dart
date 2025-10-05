import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import pour SystemUiOverlayStyle
import 'package:firebase_storage/firebase_storage.dart'; // Still needed if image URLs are from Storage but managed by Firestore
// import 'package:url_launcher/url_launcher.dart'; // Removed as it's not used in ArticlePage
// import 'package:permission_handler/permission_handler.dart'; // Removed as it's not used in ArticlePage
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shimmer/shimmer.dart'; // Ajout pour l'effet de shimmer
import 'full_screen_image_page.dart'; // Importer la nouvelle page
import 'package:google_fonts/google_fonts.dart'; // Import pour GoogleFonts
import 'package:intl/intl.dart'; // For date formatting
import 'package:hospital_virtuel/screens/settings/settings.dart'; // Importer la page des paramètres
import 'package:flutter/gestures.dart'; // For RichText tap gestures (optional)

class ArticleModel {
  final String id;
  final String title;
  final String imageUrl;
  int likes;
  int dislikes;
  final Timestamp createdAt;
  String? currentUserVote; // 'like', 'dislike', or null

  ArticleModel({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.likes,
    required this.dislikes,
    required this.createdAt,
    this.currentUserVote,
  });

  factory ArticleModel.fromFirestore(DocumentSnapshot doc, String? currentUserVote) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ArticleModel(
      id: doc.id,
      title: data['title'] ?? 'Titre non disponible',
      imageUrl: data['imageUrl'] ?? '',
      likes: data['likes'] ?? 0,
      dislikes: data['dislikes'] ?? 0,
      createdAt: data['createdAt'] ?? Timestamp.now(),
      currentUserVote: currentUserVote,
    );
  }
}

class CommentModel {
  final String id;
  final String userId;
  final String userName;
  final String text;
  final Timestamp timestamp;
  final String? replyToCommentId;
  final String? replyToUsername;
  int likes;
  int dislikes;
  String? currentUserVote; // 'like', 'dislike', or null
  final List<CommentModel> replies; // Sous-commentaires

  CommentModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.text,
    required this.timestamp,
    this.replyToCommentId,
    this.replyToUsername,
    this.likes = 0,
    this.dislikes = 0,
    this.currentUserVote,
    this.replies = const [],
  });

  factory CommentModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return CommentModel(
      id: doc.id,
      userId: data['userId'] ?? 'Utilisateur inconnu',
      userName: data['userName'] ?? 'Anonyme',
      text: data['text'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      replyToCommentId: data['replyToCommentId'] as String?,
      replyToUsername: data['replyToUsername'] as String?,
      likes: data['likes'] ?? 0,
      dislikes: data['dislikes'] ?? 0,
      currentUserVote: data['currentUserVote'],
      replies: [], // Sera rempli séparément
    );
  }

  // Créer une copie avec des réponses
  CommentModel copyWith({
    List<CommentModel>? replies,
    int? likes,
    int? dislikes,
    String? currentUserVote,
  }) {
    return CommentModel(
      id: id,
      userId: userId,
      userName: userName,
      text: text,
      timestamp: timestamp,
      replyToCommentId: replyToCommentId,
      replyToUsername: replyToUsername,
      likes: likes ?? this.likes,
      dislikes: dislikes ?? this.dislikes,
      currentUserVote: currentUserVote ?? this.currentUserVote,
      replies: replies ?? this.replies,
    );
  }
}

class ArticlePage extends StatefulWidget {
  final bool isDesktop;

  const ArticlePage({super.key, this.isDesktop = false});

  @override
  State<ArticlePage> createState() => _ArticlePageState();
}

class _ArticlePageState extends State<ArticlePage> {
  List<ArticleModel> _articles = [];
  bool _isLoading = true;
  String? _errorMessage;

  // For searching
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<ArticleModel> _filteredArticles = [];

  // For comments
  final Map<String, List<CommentModel>> _articleComments = {};
  final Map<String, bool> _isLoadingComments = {};
  final Map<String, TextEditingController> _commentControllers = {};
  final Map<String, bool> _showCommentsForArticle = {};
  final Map<String, int> _commentCounts = {}; // Ajout pour suivre le nombre de commentaires

  // For replying to comments
  final Map<String, String?> _replyingToCommentId = {}; // Key: articleId, Value: commentId
  final Map<String, String?> _replyingToUsername = {}; // Key: articleId, Value: username
  final Map<String, FocusNode> _commentFocusNodes = {}; // Key: articleId, Value: FocusNode

  // For showing replies
  final Map<String, bool> _showRepliesForComment = {};


  User? _currentUser;

  // Méthode utilitaire pour convertir en int de manière sécurisée
  int? _parseToInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      try {
        return int.parse(value);
      } catch (e) {
        return null;
      }
    }
    if (value is double) return value.toInt();
    return null;
  }

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _loadArticles();
    _searchController.addListener(_filterArticles);
  }

  Future<void> _loadArticles() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Charger d'abord tous les articles avec un timeout
      final articlesSnapshot = await FirebaseFirestore.instance
          .collection('articles')
          .orderBy('createdAt', descending: true)
          .get()
          .timeout(const Duration(seconds: 30), onTimeout: () {
        throw Exception('Délai d\'attente dépassé lors du chargement des articles');
      });

      if (!mounted) return;

      final List<ArticleModel> loadedArticles = [];
      final List<Future<void>> commentCountFutures = [];
      
      // Traiter les articles sans les votes utilisateur pour l'instant
      for (var doc in articlesSnapshot.docs) {
        try {
          loadedArticles.add(ArticleModel.fromFirestore(doc, null));
          _commentControllers[doc.id] = TextEditingController();
          _commentFocusNodes[doc.id] = FocusNode();
          
          // Ajouter le futur pour charger le nombre de commentaires
          commentCountFutures.add(_loadCommentCount(doc.id));
        } catch (e) {
          print("Erreur lors du traitement de l'article ${doc.id}: $e");
          // Continuer avec les autres articles
        }
      }

      if (!mounted) return;

      // Charger les votes utilisateur en parallèle
      if (_currentUser != null) {
        await _loadUserVotes(loadedArticles);
      }

      if (!mounted) return;

      // Attendre que tous les compteurs de commentaires soient chargés
      await Future.wait(commentCountFutures);

      if (mounted) {
        setState(() {
          _articles = loadedArticles;
          _filteredArticles = loadedArticles;
          _isLoading = false;
        });
      }
    } on FirebaseException catch (e) {
      print("Erreur Firebase lors du chargement des articles: ${e.code} - ${e.message}");
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (e.code == 'permission-denied') {
            _errorMessage = "Accès refusé. Vérifiez votre connexion.";
          } else if (e.code == 'unavailable') {
            _errorMessage = "Service temporairement indisponible. Réessayez plus tard.";
          } else if (e.code == 'not-found') {
            _errorMessage = "Aucun article trouvé.";
          } else {
            _errorMessage = "Erreur de chargement: ${e.message ?? e.code}";
          }
        });
      }
    } catch (e) {
      print("Erreur lors du chargement des articles: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (e.toString().contains('Délai d\'attente dépassé')) {
            _errorMessage = "Délai d'attente dépassé. Vérifiez votre connexion internet.";
          } else if (e.toString().contains('NetworkException') || e.toString().contains('SocketException')) {
            _errorMessage = "Problème de connexion réseau. Vérifiez votre connexion internet.";
          } else {
            _errorMessage = "Une erreur inconnue est survenue lors du chargement des articles.";
          }
        });
      }
    }
  }

  // Nouvelle méthode pour charger les votes utilisateur
  Future<void> _loadUserVotes(List<ArticleModel> articles) async {
    try {
      final futures = articles.map((article) async {
        try {
          final voteDoc = await FirebaseFirestore.instance
              .collection('articles')
              .doc(article.id)
              .collection('votes')
              .doc(_currentUser!.uid)
              .get();
          
          if (voteDoc.exists) {
            final voteType = voteDoc.data()?['voteType'];
            if (voteType != null) {
              article.currentUserVote = voteType;
            }
          }
        } catch (e) {
          print("Erreur lors du chargement du vote pour l'article ${article.id}: $e");
        }
      });
      
      await Future.wait(futures);
    } catch (e) {
      print("Erreur lors du chargement des votes utilisateur: $e");
    }
  }

  @override
  void dispose() {
    _commentControllers.forEach((_, controller) => controller.dispose());
    _commentFocusNodes.forEach((_, node) => node.dispose()); // Dispose focus nodes
    _searchController.dispose();
    super.dispose();
  }

  void _filterArticles() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filteredArticles = List.from(_articles);
      });
    } else {
      setState(() {
        _filteredArticles = _articles.where((article) {
          final cleanedTitle = article.title
              .replaceAll('_', ' ')
              .replaceAllMapped(RegExp(r'\.(jpg|jpeg|png)$', caseSensitive: false), (match) => '')
              .trim()
              .toLowerCase();
          // La recherche s'effectue sur le titre de l'article.
          return cleanedTitle.contains(query);
        }).toList();
      });
    }
  }

  // Nouvelle méthode pour charger le nombre de commentaires
  Future<void> _loadCommentCount(String articleId) async {
    try {
      final commentsSnapshot = await FirebaseFirestore.instance
          .collection('articles')
          .doc(articleId)
          .collection('comments')
          .get();
      
      if (mounted) {
        setState(() {
          _commentCounts[articleId] = commentsSnapshot.docs.length;
        });
      }
    } catch (e) {
      print("Erreur lors du chargement du nombre de commentaires pour l'article $articleId: $e");
      // Ne pas faire de setState ici pour éviter les erreurs de performance
      // Le compteur sera mis à jour plus tard si nécessaire
    }
  }

  Future<void> _refreshArticles() async {
    await _loadArticles();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: widget.isDesktop ? null : AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        title: _isSearching
            ? _buildSearchField()
            : Text(
                'Articles de santé',
                style: GoogleFonts.lato(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
        centerTitle: false,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade800, Colors.lightBlue.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 3.0,
        actions: _isSearching ? _buildSearchActions() : _buildDefaultActions(),
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _isLoading
          ? _buildLoadingShimmer(theme)
          : _errorMessage != null
              ? _buildErrorWidget(theme)
              : _buildArticlesList(theme),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      decoration: InputDecoration(
        hintText: 'Rechercher un article...',
        border: InputBorder.none,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
      ),
      style: const TextStyle(color: Colors.white, fontSize: 18.0),
      onChanged: (query) {
        setState(() {
          _filterArticles();
        });
      },
    );
  }

  List<Widget> _buildSearchActions() {
    return [
      IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: () {
          if (_searchController.text.isEmpty) {
            setState(() {
              _isSearching = false;
            });
          } else {
            _searchController.clear();
          }
        },
      ),
    ];
  }

  List<Widget> _buildDefaultActions() {
    return [
      IconButton(
        icon: const Icon(Icons.search, color: Colors.white),
        onPressed: () {
          setState(() {
            _isSearching = true;
          });
        },
        tooltip: 'Rechercher',
      ),
      PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'settings') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsPage()),
            );
          }
        },
        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
          const PopupMenuItem<String>(
            value: 'settings',
            child: ListTile(
              leading: Icon(Icons.settings_outlined),
              title: Text('Paramètres'),
            ),
          ),
        ],
        icon: const Icon(Icons.more_vert, color: Colors.white),
      ),
    ];
  }

  Widget _buildLoadingShimmer(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: theme.colorScheme.surfaceVariant,
          highlightColor: theme.colorScheme.surface,
          child: Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 20,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 16,
                        width: 200,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorWidget(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: theme.colorScheme.error.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            'Erreur: $_errorMessage',
            style: TextStyle(
              color: theme.colorScheme.error,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadArticles,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            label: const Text('Réessayer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArticlesList(ThemeData theme) {
    final articles = _isSearching ? _filteredArticles : _articles;
    
    if (articles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isSearching ? Icons.search_off_rounded : Icons.article_outlined,
              size: 80,
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _isSearching ? 'Aucun article trouvé' : 'Aucun article disponible',
              style: GoogleFonts.lato(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.titleMedium?.color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isSearching ? 'Essayez avec d\'autres mots-clés' : 'Revenez plus tard pour de nouveaux articles',
              style: GoogleFonts.roboto(
                fontSize: 14,
                color: theme.textTheme.bodySmall?.color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: articles.length,
      itemBuilder: (context, index) {
        return _buildArticleCard(articles[index], theme);
      },
    );
  }

  Widget _buildArticleCard(ArticleModel article, ThemeData theme) {
    final cleanedTitle = article.title
        .replaceAll('_', ' ')
        .replaceAllMapped(RegExp(r'\.(jpg|jpeg|png)$', caseSensitive: false), (match) => '')
        .trim();

    return Card(
      elevation: 3.0, // Ombre subtile
      margin: const EdgeInsets.symmetric(horizontal: 0), // Pas de marge horizontale, gérée par le padding du ListView
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: theme.colorScheme.outline, width: 1.0), // Ajout d'une bordure subtile
      ),
      clipBehavior: Clip.antiAliasWithSaveLayer, // Pour que l'image respecte les coins arrondis
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (article.imageUrl.isNotEmpty)
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => FullScreenImagePage(imageProvider: NetworkImage(article.imageUrl), tag: article.imageUrl))),
              child: Hero(
                tag: article.imageUrl,
                child: AspectRatio( // Assure un ratio pour l'image
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    article.imageUrl,
                    // height: 210, // Remplacé par AspectRatio
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) => progress == null
                        ? child // Affiche l'image une fois chargée
                        : Container(
                            color: theme.colorScheme.surfaceVariant, // Couleur de fond pendant le chargement
                            child: Center(
                              child: CircularProgressIndicator(
                                value: progress.expectedTotalBytes != null ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes! : null,
                                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                                strokeWidth: 2.5, // Épaisseur de l'indicateur
                              ),
                            ),
                          ), // Conteneur pour le shimmer ou le loader
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: theme.colorScheme.surfaceVariant,
                      child: Center(child: Icon(Icons.broken_image_outlined, size: 60, color: theme.textTheme.bodySmall?.color?.withOpacity(0.5)))
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0), // Padding ajusté
            child: Text(
              cleanedTitle.isNotEmpty ? cleanedTitle : "Titre de l'article",
              style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 19, color: theme.textTheme.titleMedium?.color),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              DateFormat('dd MMMM yyyy').format(article.createdAt.toDate()),
              style: GoogleFonts.roboto(fontSize: 13, color: theme.textTheme.bodySmall?.color),
              textAlign: TextAlign.end,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0), // Padding réduit pour les actions
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        article.currentUserVote == 'like' ? Icons.thumb_up_rounded : Icons.thumb_up_alt_outlined,
                        color: article.currentUserVote == 'like' ? theme.colorScheme.primary : theme.textTheme.bodySmall?.color,
                        size: 22,
                      ),
                      onPressed: _currentUser == null ? null : () => _handleVote(article, 'like'),
                      tooltip: "J'aime",
                    ), // Adjusted icon color
                    Text('${article.likes}', style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: Icon(
                        article.currentUserVote == 'dislike' ? Icons.thumb_down_rounded : Icons.thumb_down_alt_outlined,
                        color: article.currentUserVote == 'dislike' ? theme.colorScheme.error : theme.textTheme.bodySmall?.color,
                        size: 22,
                      ),
                      onPressed: _currentUser == null ? null : () => _handleVote(article, 'dislike'),
                      tooltip: "Je n'aime pas",
                    ), // Adjusted icon color
                    Text('${article.dislikes}', style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontWeight: FontWeight.w500)),
                  ],
                ),
                TextButton.icon(
                  icon: Icon(
                    _showCommentsForArticle[article.id] == true ? Icons.chat_rounded : Icons.chat_bubble_outline_rounded,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  label: Text( // Adjusted icon color
                    _showCommentsForArticle[article.id] == true ? "Masquer" : "Commentaires (${_commentCounts[article.id] ?? 0})",
                    style: GoogleFonts.roboto(color: theme.colorScheme.primary, fontWeight: FontWeight.w500),
                  ), // Adjusted icon color
                  onPressed: () => _toggleCommentsSection(article.id),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize( // Animation pour afficher/masquer les commentaires
            duration: const Duration(milliseconds: 300), // Durée de l'animation
            curve: Curves.easeInOut, // Courbe de l'animation
            child: _showCommentsForArticle[article.id] == true
                ? ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45), // Hauteur contrainte
                    child: _buildCommentsSection(article, theme),
                  )
                : Container(), // Widget vide quand les commentaires sont masqués
          ),
        ],
      ),
    );
  }

  void _toggleCommentsSection(String articleId) {
    setState(() {
      _showCommentsForArticle[articleId] = !(_showCommentsForArticle[articleId] ?? false);
    });
    if (_showCommentsForArticle[articleId] == true && (_articleComments[articleId] == null || _articleComments[articleId]!.isEmpty)) {
      _loadComments(articleId);
    }
  }

  Future<void> _handleVote(ArticleModel article, String voteType) async {
    if (_currentUser == null) return;

    final articleRef = FirebaseFirestore.instance.collection('articles').doc(article.id);
    final voteRef = articleRef.collection('votes').doc(_currentUser!.uid);

    FirebaseFirestore.instance.runTransaction((transaction) async {
      final voteSnapshot = await transaction.get(voteRef);
      final articleSnapshot = await transaction.get(articleRef);

      if (!articleSnapshot.exists) throw Exception("Article does not exist!");
      final articleData = articleSnapshot.data();
      if (articleData == null) throw Exception("Article data is null!");

      int newLikes = _parseToInt(articleData['likes']) ?? 0;
      int newDislikes = _parseToInt(articleData['dislikes']) ?? 0;
      String? newVoteStatus;

      if (voteSnapshot.exists) {
        String previousVote = (voteSnapshot.data() as Map<String, dynamic>)['voteType'] as String;
        if (previousVote == voteType) {
          if (voteType == 'like') newLikes--;
          if (voteType == 'dislike') newDislikes--;
          transaction.delete(voteRef);
          newVoteStatus = null;
        } else {
          if (previousVote == 'like') newLikes--;
          if (previousVote == 'dislike') newDislikes--;
          if (voteType == 'like') newLikes++;
          if (voteType == 'dislike') newDislikes++;
          transaction.set(voteRef, {'voteType': voteType});
          newVoteStatus = voteType;
        }
      } else {
        if (voteType == 'like') newLikes++;
        if (voteType == 'dislike') newDislikes++;
        transaction.set(voteRef, {'voteType': voteType});
        newVoteStatus = voteType;
      }
      transaction.update(articleRef, {'likes': newLikes, 'dislikes': newDislikes});

      if (mounted) {
        setState(() {
          article.likes = newLikes;
          article.dislikes = newDislikes;
          article.currentUserVote = newVoteStatus;
        });
      }
    }).catchError((error) {
      print("Transaction failed for voting: $error");
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur lors du vote: $error')));
      }
    });
  }

  Future<void> _loadComments(String articleId) async {
    if (!mounted) return;
    setState(() {
      _isLoadingComments[articleId] = true;
    });
    try {
      final commentsSnapshot = await FirebaseFirestore.instance
          .collection('articles')
          .doc(articleId)
          .collection('comments')
          .orderBy('timestamp', descending: true)
          .get();
      
      final List<CommentModel> allComments = [];
      
      for (var doc in commentsSnapshot.docs) {
        Map<String, dynamic> data = doc.data();
        
        // Charger les likes pour ce commentaire
        String? currentUserVote;
        if (_currentUser != null) {
          try {
            final voteDoc = await FirebaseFirestore.instance
                .collection('articles')
                .doc(articleId)
                .collection('comments')
                .doc(doc.id)
                .collection('votes')
                .doc(_currentUser!.uid)
                .get();
            if (voteDoc.exists) {
              currentUserVote = voteDoc.data()?['voteType'];
            }
          } catch (e) {
            print('Erreur lors du chargement du vote: $e');
          }
        }
        
        allComments.add(CommentModel(
          id: doc.id,
          userId: data['userId'] ?? 'Utilisateur inconnu',
          userName: data['userName'] ?? 'Anonyme',
          text: data['text'] ?? '',
          timestamp: data['timestamp'] ?? Timestamp.now(),
          replyToCommentId: data['replyToCommentId'] as String?,
          replyToUsername: data['replyToUsername'] as String?,
          likes: data['likes'] ?? 0,
          dislikes: data['dislikes'] ?? 0,
          currentUserVote: currentUserVote,
          replies: [],
        ));
      }
      
      // Organiser les commentaires en arborescence
      final organizedComments = _organizeCommentsIntoTree(allComments);
      
      if (mounted) {
        setState(() {
          _articleComments[articleId] = organizedComments;
          _isLoadingComments[articleId] = false;
          _commentCounts[articleId] = organizedComments.length;
        });
        
        // Debug: afficher le nombre de commentaires chargés
        print('Commentaires chargés pour l\'article $articleId: ${organizedComments.length}');
        for (var comment in organizedComments) {
          print('- ${comment.userName}: ${comment.text} (${comment.replies.length} réponses)');
        }
      }
    } catch (e) {
      print("Erreur lors du chargement des commentaires: $e");
      if (mounted) {
        setState(() {
          _isLoadingComments[articleId] = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur de chargement des commentaires: $e')));
      }
    }
  }

  // Fonction simple pour organiser les commentaires en arborescence
  List<CommentModel> _organizeCommentsIntoTree(List<CommentModel> allComments) {
    final Map<String, CommentModel> commentMap = {};
    final List<CommentModel> mainComments = [];
    
    // Créer une map de tous les commentaires
    for (var comment in allComments) {
      commentMap[comment.id] = comment;
    }
    
    // Organiser les commentaires
    for (var comment in allComments) {
      if (comment.replyToCommentId == null) {
        // Commentaire principal
        mainComments.add(comment);
      } else {
        // Réponse à un commentaire
        final parentComment = commentMap[comment.replyToCommentId];
        if (parentComment != null) {
          final updatedParent = parentComment.copyWith(
            replies: [...parentComment.replies, comment]
          );
          commentMap[comment.replyToCommentId!] = updatedParent;
          
          // Mettre à jour dans la liste principale
          final mainIndex = mainComments.indexWhere((c) => c.id == comment.replyToCommentId);
          if (mainIndex != -1) {
            mainComments[mainIndex] = updatedParent;
          }
        }
      }
    }
    
    return mainComments;
  }

  Future<void> _addComment(String articleId) async {
    if (_currentUser == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez vous connecter pour commenter.')));
      return;
    }
    final controller = _commentControllers[articleId];
    if (controller == null || controller.text.trim().isEmpty) return;

    final commentText = controller.text.trim();
    
    try {
      Map<String, dynamic> commentData = {
        'userId': _currentUser!.uid,
        'userName': _currentUser!.displayName ?? _currentUser!.email ?? 'Utilisateur Anonyme',
        'text': commentText,
        'timestamp': FieldValue.serverTimestamp(),
      };

      if (_replyingToCommentId[articleId] != null && _replyingToUsername[articleId] != null) {
        commentData['replyToCommentId'] = _replyingToCommentId[articleId]!;
        commentData['replyToUsername'] = _replyingToUsername[articleId]!;
      }

      final newCommentRef = await FirebaseFirestore.instance
          .collection('articles')
          .doc(articleId)
          .collection('comments')
          .add(commentData);

      final newCommentSnapshot = await newCommentRef.get();
      final newComment = CommentModel.fromFirestore(newCommentSnapshot);

      if (mounted) {
        setState(() {
          _articleComments[articleId]?.insert(0, newComment); // Add to top
          _commentCounts[articleId] = (_commentCounts[articleId] ?? 0) + 1; // Incrémenter le compteur
          _replyingToCommentId.remove(articleId); // Clear reply state
          _replyingToUsername.remove(articleId); // Clear reply state
          controller.clear(); // Clear text field after successful submission
          _commentFocusNodes[articleId]?.unfocus(); // Unfocus after sending
        });
      }
    } catch (e) {
      print("Erreur lors de l'ajout du commentaire: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur lors de l\'ajout du commentaire: $e')));
      }
      // Optionally, restore text: controller.text = commentText;
    }
  }

  Future<void> _confirmDeleteComment(String articleId, String commentId) async {
    final theme = Theme.of(context);
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: const Text('Êtes-vous sûr de vouloir supprimer ce commentaire ?'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.error, foregroundColor: Colors.white),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _deleteComment(articleId, commentId);
    }
  }

  // Fonction pour gérer les likes/dislikes des commentaires
  Future<void> _toggleCommentVote(String articleId, String commentId, String voteType) async {
    if (_currentUser == null) return;

    try {
      final commentRef = FirebaseFirestore.instance
          .collection('articles')
          .doc(articleId)
          .collection('comments')
          .doc(commentId);
      
      final voteRef = commentRef.collection('votes').doc(_currentUser!.uid);
      final voteDoc = await voteRef.get();
      
      String? newVoteType;
      int likeDelta = 0;
      int dislikeDelta = 0;
      
      if (voteDoc.exists) {
        final currentVote = voteDoc.data()?['voteType'];
        if (currentVote == voteType) {
          // Annuler le vote
          await voteRef.delete();
          if (voteType == 'like') {
            likeDelta = -1;
          } else {
            dislikeDelta = -1;
          }
        } else {
          // Changer le vote
          await voteRef.set({'voteType': voteType});
          newVoteType = voteType;
          
          if (currentVote == 'like') {
            likeDelta = -1;
          } else if (currentVote == 'dislike') {
            dislikeDelta = -1;
          }
          
          if (voteType == 'like') {
            likeDelta += 1;
          } else {
            dislikeDelta += 1;
          }
        }
      } else {
        // Nouveau vote
        await voteRef.set({'voteType': voteType});
        newVoteType = voteType;
        
        if (voteType == 'like') {
          likeDelta = 1;
        } else {
          dislikeDelta = 1;
        }
      }
      
      // Mettre à jour les compteurs dans Firestore
      await commentRef.update({
        'likes': FieldValue.increment(likeDelta),
        'dislikes': FieldValue.increment(dislikeDelta),
      });
      
      // Mettre à jour l'état local
      if (mounted) {
        setState(() {
          final comments = _articleComments[articleId];
          if (comments != null) {
            _updateCommentVote(comments, commentId, newVoteType, likeDelta, dislikeDelta);
          }
        });
      }
    } catch (e) {
      print("Erreur lors du vote: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du vote: $e'))
        );
      }
    }
  }

  // Fonction récursive pour mettre à jour le vote d'un commentaire
  void _updateCommentVote(List<CommentModel> comments, String commentId, String? newVoteType, int likeDelta, int dislikeDelta) {
    for (int i = 0; i < comments.length; i++) {
      if (comments[i].id == commentId) {
        final comment = comments[i];
        comments[i] = comment.copyWith(
          likes: comment.likes + likeDelta,
          dislikes: comment.dislikes + dislikeDelta,
          currentUserVote: newVoteType,
        );
        return;
      }
      
      // Chercher dans les réponses
      if (comments[i].replies.isNotEmpty) {
        _updateCommentVote(comments[i].replies, commentId, newVoteType, likeDelta, dislikeDelta);
      }
    }
  }

  Future<void> _deleteComment(String articleId, String commentId) async {
      try {
        await FirebaseFirestore.instance
            .collection('articles')
            .doc(articleId)
            .collection('comments')
            .doc(commentId)
            .delete();
        
        setState(() {
          _articleComments[articleId]?.removeWhere((c) => c.id == commentId);
          _commentCounts[articleId] = (_commentCounts[articleId] ?? 1) - 1; // Décrémenter le compteur
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Commentaire supprimé avec succès'), backgroundColor: Colors.green),
        );
      } catch (e) {
        print("Erreur lors de la suppression du commentaire: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la suppression: $e'), backgroundColor: Colors.red),
        );
    }
  }


  Widget _buildCommentsSection(ArticleModel article, ThemeData theme) {
    final comments = _articleComments[article.id] ?? [];
    final isLoading = _isLoadingComments[article.id] ?? false;
    final focusNode = _commentFocusNodes[article.id];
    final commentController = _commentControllers[article.id];

    return Material( // Ajout de Material pour la couleur de fond et l'élévation si besoin
      color: theme.colorScheme.surface, // Fond blanc pour la section des commentaires
      elevation: 0, // Ou une légère élévation si vous le souhaitez
      child: Column( // This is the Column that was missing a closing parenthesis
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Divider(height: 1),
            ),
            Expanded( 
              child: Builder(builder: (context) {
                if (isLoading) {
                  return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.blue)));
                }
                if (comments.isEmpty && !isLoading) {
                  return const Center(
                      child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text('Soyez le premier à commenter !', style: TextStyle(color: Colors.grey, fontSize: 15)),
                  ));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), 
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return _buildCommentItem(comment, article.id, focusNode, theme);
                  },
                );
              }),
            ),
            if (_currentUser != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface, // Ou Colors.grey[100]
                  border: Border(top: BorderSide(color: theme.colorScheme.outline, width: 0.5)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_replyingToUsername[article.id] != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6.0), 
                        child: Row( // Adjusted icon color
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                "En réponse à @${_replyingToUsername[article.id]}",
                                style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: theme.colorScheme.primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close_rounded, size: 20, color: theme.textTheme.bodySmall?.color),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: "Annuler la réponse",
                              onPressed: () {
                                setState(() {
                                  _replyingToCommentId.remove(article.id);
                                  _replyingToUsername.remove(article.id);
                                });
                              },
                            )
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: commentController,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              hintText: 'Écrire un commentaire...',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(25.0),
                                  borderSide: BorderSide(color: theme.colorScheme.outline)
                              ),
                              enabledBorder: OutlineInputBorder( // Bordure quand non focus
                                borderRadius: BorderRadius.circular(25.0),
                                borderSide: BorderSide(color: theme.colorScheme.outline),
                              ),
                              focusedBorder: OutlineInputBorder( // Bordure quand focus
                                borderRadius: BorderRadius.circular(25.0),
                                borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              filled: true,
                              fillColor: theme.colorScheme.surface, // Fond du champ de texte
                            ),
                            minLines: 1,
                            maxLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                            onSubmitted: (_) => _addComment(article.id), // Adjusted icon color
                          ),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(25),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(25),
                            onTap: () => _addComment(article.id), // Adjusted icon color
                            child: const Padding(
                              padding: EdgeInsets.all(10.0),
                              child: Icon(Icons.send_rounded, color: Colors.white, size: 22),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ), // Parenthèse fermante pour le Column principal
    );
  }

  Widget _buildCommentItem(CommentModel comment, String articleId, FocusNode? focusNode, ThemeData theme) {
    final commentsList = _articleComments[articleId] ?? [];
    final commentIndex = commentsList.indexOf(comment);
    final isLastComment = commentIndex == commentsList.length - 1;
    final hasReplies = comment.replies.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      comment.userName.isNotEmpty ? comment.userName[0].toUpperCase() : 'U',
                      style: GoogleFonts.lato(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    comment.userName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                  ),
                ],
              ),
              if (_currentUser?.uid == comment.userId)
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error, size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  tooltip: "Supprimer",
                  onPressed: () => _confirmDeleteComment(articleId, comment.id),
                ),
            ],
          ),
          if (comment.replyToUsername != null && comment.replyToUsername!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 40, top: 2.0, bottom: 4.0),
              child: RichText(
                text: TextSpan(
                  style: GoogleFonts.roboto(fontSize: 13, color: theme.textTheme.bodySmall?.color),
                  children: <TextSpan>[
                    const TextSpan(text: '↪ En réponse à '),
                    TextSpan(
                      text: '@${comment.replyToUsername}',
                      style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.only(left: comment.replyToUsername != null ? 40 : 0, top: 4.0, bottom: 6.0),
            child: Text(comment.text, style: GoogleFonts.roboto(color: Colors.black.withOpacity(0.75), fontSize: 14.5, height: 1.4)),
          ),
          
          // Section des actions (likes, réponses, etc.)
          Padding(
            padding: EdgeInsets.only(left: comment.replyToUsername != null ? 40 : 0),
            child: Column(
              children: [
                // Barre d'actions
                Row(
            children: [
                    // Bouton Like
                    InkWell(
                      onTap: () => _toggleCommentVote(articleId, comment.id, 'like'),
                      child: Row(
                        children: [
                          Icon(
                            comment.currentUserVote == 'like' ? Icons.thumb_up : Icons.thumb_up_outlined,
                            size: 18,
                            color: comment.currentUserVote == 'like' ? theme.colorScheme.primary : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${comment.likes}',
                            style: TextStyle(
                              fontSize: 12,
                              color: comment.currentUserVote == 'like' ? theme.colorScheme.primary : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Bouton Dislike
                    InkWell(
                      onTap: () => _toggleCommentVote(articleId, comment.id, 'dislike'),
                      child: Row(
                        children: [
                          Icon(
                            comment.currentUserVote == 'dislike' ? Icons.thumb_down : Icons.thumb_down_outlined,
                            size: 18,
                            color: comment.currentUserVote == 'dislike' ? theme.colorScheme.error : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${comment.dislikes}',
                            style: TextStyle(
                              fontSize: 12,
                              color: comment.currentUserVote == 'dislike' ? theme.colorScheme.error : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Bouton Répondre
              if (_currentUser != null)
                TextButton.icon(
                  icon: Icon(Icons.reply_rounded, size: 16, color: theme.colorScheme.primary),
                  label: Text("Répondre", style: GoogleFonts.roboto(fontSize: 13, color: theme.colorScheme.primary, fontWeight: FontWeight.w500)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    setState(() {
                      _replyingToCommentId[articleId] = comment.id;
                      _replyingToUsername[articleId] = comment.userName;
                      focusNode?.requestFocus();
                    });
                  },
                      ),
                    
                    const Spacer(),
                    
                    // Horodatage
                    Text(
                      DateFormat('dd MMM yy, HH:mm').format(comment.timestamp.toDate()),
                      style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 11),
                ),
            ],
          ),
                
                // Section des réponses
                if (hasReplies) ...[
                  const SizedBox(height: 8),
                  _buildRepliesSection(comment, articleId, focusNode, theme),
                ],
              ],
            ),
          ),
          
          if (!isLastComment) const Divider(height: 20, thickness: 0.5),
        ],
      ),
    );
  }

  // Nouvelle fonction pour afficher les réponses
  Widget _buildRepliesSection(CommentModel comment, String articleId, FocusNode? focusNode, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bouton pour afficher/masquer les réponses
        InkWell(
          onTap: () {
            setState(() {
              // Toggle l'état d'affichage des réponses
              if (_showRepliesForComment[comment.id] == true) {
                _showRepliesForComment.remove(comment.id);
              } else {
                _showRepliesForComment[comment.id] = true;
              }
            });
          },
          child: Row(
            children: [
              Icon(
                _showRepliesForComment[comment.id] == true ? Icons.expand_less : Icons.expand_more,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '${comment.replies.length} réponse${comment.replies.length > 1 ? 's' : ''}',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        
        // Affichage des réponses
        if (_showRepliesForComment[comment.id] == true) ...[
          const SizedBox(height: 8),
          Container(
            margin: const EdgeInsets.only(left: 20),
            padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: theme.colorScheme.outline.withOpacity(0.3), width: 2),
              ),
            ),
            child: Column(
              children: comment.replies.map((reply) => _buildReplyItem(reply, articleId, focusNode, theme)).toList(),
            ),
          ),
        ],
      ],
    );
  }

  // Nouvelle fonction pour afficher un élément de réponse
  Widget _buildReplyItem(CommentModel reply, String articleId, FocusNode? focusNode, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: theme.colorScheme.secondaryContainer,
                child: Text(
                  reply.userName.isNotEmpty ? reply.userName[0].toUpperCase() : 'U',
                  style: GoogleFonts.lato(
                    color: theme.colorScheme.onSecondaryContainer, 
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                reply.userName,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87),
              ),
              const Spacer(),
              if (_currentUser?.uid == reply.userId)
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                  tooltip: "Supprimer",
                  onPressed: () => _confirmDeleteComment(articleId, reply.id),
                ),
            ],
          ),
          
          Padding(
            padding: const EdgeInsets.only(left: 22, top: 4.0, bottom: 6.0),
            child: Text(reply.text, style: GoogleFonts.roboto(color: Colors.black.withOpacity(0.75), fontSize: 14, height: 1.4)),
          ),
          
          // Actions pour les réponses
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Row(
              children: [
                // Bouton Like
                InkWell(
                  onTap: () => _toggleCommentVote(articleId, reply.id, 'like'),
                  child: Row(
                    children: [
                      Icon(
                        reply.currentUserVote == 'like' ? Icons.thumb_up : Icons.thumb_up_outlined,
                        size: 16,
                        color: reply.currentUserVote == 'like' ? theme.colorScheme.primary : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${reply.likes}',
                        style: TextStyle(
                          fontSize: 11,
                          color: reply.currentUserVote == 'like' ? theme.colorScheme.primary : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                
                // Bouton Dislike
                InkWell(
                  onTap: () => _toggleCommentVote(articleId, reply.id, 'dislike'),
                  child: Row(
                    children: [
                      Icon(
                        reply.currentUserVote == 'dislike' ? Icons.thumb_down : Icons.thumb_down_outlined,
                        size: 16,
                        color: reply.currentUserVote == 'dislike' ? theme.colorScheme.error : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${reply.dislikes}',
                        style: TextStyle(
                          fontSize: 11,
                          color: reply.currentUserVote == 'dislike' ? theme.colorScheme.error : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                
                // Bouton Répondre
                if (_currentUser != null)
                  TextButton.icon(
                    icon: Icon(Icons.reply_rounded, size: 14, color: theme.colorScheme.primary),
                    label: Text("Répondre", style: GoogleFonts.roboto(fontSize: 12, color: theme.colorScheme.primary, fontWeight: FontWeight.w500)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      minimumSize: const Size(0, 24),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      setState(() {
                        _replyingToCommentId[articleId] = reply.id;
                        _replyingToUsername[articleId] = reply.userName;
                        focusNode?.requestFocus();
                      });
                    },
                  ),
                
                const Spacer(),
                
                // Horodatage
                Text(
                  DateFormat('dd MMM yy, HH:mm').format(reply.timestamp.toDate()),
                  style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
