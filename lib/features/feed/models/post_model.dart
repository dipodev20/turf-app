class PostModel {
  final String id;
  final String clanId;
  final String clanName;
  final String? clanFlagUrl;
  final String authorId;
  final String authorName;
  final String type; // capture, war, achievement, regular
  final String? content;
  final String? imageUrl;
  final Map<String, dynamic>? metadata;
  final int likeCount;
  final int commentCount;
  final bool isLiked;
  final String? city;
  final DateTime createdAt;

  const PostModel({
    required this.id,
    required this.clanId,
    required this.clanName,
    this.clanFlagUrl,
    required this.authorId,
    required this.authorName,
    required this.type,
    this.content,
    this.imageUrl,
    this.metadata,
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLiked = false,
    this.city,
    required this.createdAt,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'],
      clanId: json['clan_id'],
      clanName: json['clan_name'] ?? '',
      clanFlagUrl: json['clan_flag_url'],
      authorId: json['author_id'],
      authorName: json['author_name'] ?? '',
      type: json['type'] ?? 'regular',
      content: json['content'],
      imageUrl: json['image_url'],
      metadata: json['metadata'] as Map<String, dynamic>?,
      likeCount: json['like_count'] ?? 0,
      commentCount: json['comment_count'] ?? 0,
      isLiked: json['is_liked'] ?? false,
      city: json['city'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  PostModel copyWith({bool? isLiked, int? likeCount}) {
    return PostModel(
      id: id, clanId: clanId, clanName: clanName, clanFlagUrl: clanFlagUrl,
      authorId: authorId, authorName: authorName, type: type,
      content: content, imageUrl: imageUrl, metadata: metadata,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount,
      isLiked: isLiked ?? this.isLiked,
      city: city, createdAt: createdAt,
    );
  }
}

class CommentModel {
  final String id;
  final String postId;
  final String userId;
  final String username;
  final String? avatarUrl;
  final String content;
  final DateTime createdAt;

  const CommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.content,
    required this.createdAt,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'],
      postId: json['post_id'],
      userId: json['user_id'],
      username: json['username'] ?? '',
      avatarUrl: json['avatar_url'],
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
