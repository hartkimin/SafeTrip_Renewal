import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import '../constants/app_tokens.dart';

/// 재사용 가능한 아바타 위젯
/// 프로필 이미지를 로컬 파일 시스템과 Firebase Storage에서 로드합니다.
class AvatarWidget extends StatefulWidget {

  const AvatarWidget({
    super.key,
    required this.userId,
    this.userName,
    this.profileImageUrl,
    double? radius,
    double? size,
    this.shape = 'circle',
    this.borderRadius,
    this.borderWidth = 1,
    this.borderColor = AppTokens.line05,
    this.backgroundColor = AppTokens.bgBasic01,
    this.fallbackAsset = 'assets/images/avata_df.png',
  }) : size = radius != null ? radius * 2 : (size ?? 24);
  final String userId;
  final String? userName;
  final String? profileImageUrl;
  final double size;
  final String shape; // 'circle' or 'rounded'
  final double? borderRadius;
  final double borderWidth;
  final Color borderColor;
  final Color backgroundColor;
  final String fallbackAsset;

  @override
  State<AvatarWidget> createState() => _AvatarWidgetState();
}

class _AvatarWidgetState extends State<AvatarWidget> {
  File? _localImageFile;
  bool _isLoading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }

  /// 프로필 이미지 로드 (로컬 → 서버 → fallback)
  Future<void> _loadProfileImage() async {
    // profileImageUrl이 없으면 기본 이미지만 표시
    if (widget.profileImageUrl == null || widget.profileImageUrl!.isEmpty) {
      if (mounted) {
        setState(() {
          _localImageFile = null;
          _isLoading = false;
          _loadFailed = true;
        });
      }
      return;
    }

    try {
      // 1. 로컬 파일 확인
      final localFile = await _getLocalImageFile();
      if (localFile != null && await localFile.exists()) {
        if (mounted) {
          setState(() {
            _localImageFile = localFile;
            _isLoading = false;
            _loadFailed = false;
          });
        }
        return;
      }

      // 2. Firebase Storage에서 다운로드 (profileImageUrl이 있을 때만)
      try {
        final downloadedFile = await _downloadFromFirebase();
        if (downloadedFile != null && await downloadedFile.exists()) {
          if (mounted) {
            setState(() {
              _localImageFile = downloadedFile;
              _isLoading = false;
              _loadFailed = false;
            });
          }
          return;
        }
      } catch (e) {
        // Firebase Storage 에러는 조용히 처리 (404 등)
      }

      // 3. 실패 시 fallback
      if (mounted) {
        setState(() {
          _localImageFile = null;
          _isLoading = false;
          _loadFailed = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _localImageFile = null;
          _isLoading = false;
          _loadFailed = true;
        });
      }
    }
  }

  /// 로컬 파일 경로 가져오기
  Future<File?> _getLocalImageFile() async {
    if (widget.profileImageUrl == null || widget.profileImageUrl!.isEmpty) {
      return null;
    }

    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final profilesDir = Directory(path.join(documentsDir.path, 'profiles'));
      
      // profiles 디렉토리가 없으면 생성
      if (!await profilesDir.exists()) {
        await profilesDir.create(recursive: true);
      }

      // profileImageUrl에서 파일명 추출
      // 예: https://firebasestorage.googleapis.com/.../profiles/user123456.jpg
      // -> user123456.jpg
      String fileName = '${widget.userId}.jpg';
      try {
        final uri = Uri.parse(widget.profileImageUrl!);
        final pathSegments = uri.pathSegments;
        if (pathSegments.isNotEmpty) {
          final lastSegment = pathSegments.last;
          if (lastSegment.contains('profiles/')) {
            fileName = lastSegment.split('profiles/').last.split('?').first;
          } else if (lastSegment.endsWith('.jpg')) {
            fileName = lastSegment.split('?').first;
          }
        }
      } catch (e) {
        // URL 파싱 실패 시 기본 파일명 사용
      }

      final imagePath = path.join(profilesDir.path, fileName);
      return File(imagePath);
    } catch (e) {
      return null;
    }
  }

  /// Firebase Storage에서 이미지 다운로드
  /// profileImageUrl이 있을 때만 다운로드
  Future<File?> _downloadFromFirebase() async {
    if (widget.profileImageUrl == null || widget.profileImageUrl!.isEmpty) {
      return null;
    }

    try {
      final storage = FirebaseStorage.instance;
      
      // profileImageUrl에서 경로 추출
      // 예: https://firebasestorage.googleapis.com/v0/b/.../o/profiles%2Fuser123456.jpg?alt=media
      // -> profiles/user123456.jpg
      String? storagePath;
      try {
        final uri = Uri.parse(widget.profileImageUrl!);
        final pathSegments = uri.pathSegments;
        final oIndex = pathSegments.indexOf('o');
        if (oIndex != -1 && oIndex + 1 < pathSegments.length) {
          storagePath = Uri.decodeComponent(pathSegments[oIndex + 1]);
        }
      } catch (e) {
        debugPrint('[AvatarWidget] URL 파싱 실패: $e');
        // URL 파싱 실패 시 전체 URL을 경로로 사용 시도
        if (widget.profileImageUrl!.contains('profiles/')) {
          final match = RegExp(r'profiles/[^?]+').firstMatch(widget.profileImageUrl!);
          if (match != null) {
            storagePath = match.group(0);
          }
        }
      }

      if (storagePath == null || storagePath.isEmpty) {
        debugPrint('[AvatarWidget] 경로 추출 실패: ${widget.profileImageUrl}');
        return null;
      }

      final ref = storage.ref().child(storagePath);
      debugPrint('[AvatarWidget] Firebase Storage 접근 시도: userId=${widget.userId}, path=$storagePath');

      final localFile = await _getLocalImageFile();
      if (localFile == null) {
        debugPrint('[AvatarWidget] 로컬 파일 경로 생성 실패');
        return null;
      }

      try {
        final data = await ref.getData();
        if (data != null && data.isNotEmpty) {
          await localFile.writeAsBytes(data);
          debugPrint('[AvatarWidget] Firebase Storage 다운로드 성공: path=$storagePath, size=${data.length} bytes');
          return localFile;
        } else {
          debugPrint('[AvatarWidget] Firebase Storage 데이터가 비어있음: path=$storagePath');
        }
      } on FirebaseException catch (e) {
        debugPrint('[AvatarWidget] Firebase Storage 에러: code=${e.code}, message=${e.message}, path=$storagePath, userId=${widget.userId}');
        return null;
      } catch (e) {
        debugPrint('[AvatarWidget] 예상치 못한 에러: $e, path=$storagePath, userId=${widget.userId}');
        return null;
      }
      return null;
    } catch (e) {
      debugPrint('[AvatarWidget] 최상위 레벨 에러: $e, userId=${widget.userId}');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;

    if (_isLoading) {
      // 로딩 중: fallback 이미지 표시
      imageWidget = Image.asset(
        widget.fallbackAsset,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
      );
    } else if (_localImageFile != null && !_loadFailed) {
      // 로컬 파일 사용
      imageWidget = Image.file(
        _localImageFile!,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // 파일 읽기 실패 시 fallback
          return Image.asset(
            widget.fallbackAsset,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
          );
        },
      );
    } else {
      // fallback 이미지 사용
      imageWidget = Image.asset(
        widget.fallbackAsset,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
      );
    }

    // 모양에 따라 클리핑
    Widget clippedWidget;
    if (widget.shape == 'circle') {
      clippedWidget = ClipOval(child: imageWidget);
    } else {
      // 둥근 사각형
      clippedWidget = ClipRRect(
        borderRadius: BorderRadius.circular(
          widget.borderRadius ?? AppTokens.radius16,
        ),
        child: imageWidget,
      );
    }

    // 테두리와 배경색이 있는 Container로 감싸기
    if (widget.shape == 'circle') {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          shape: BoxShape.circle,
          border: Border.all(
            width: widget.borderWidth,
            color: widget.borderColor,
          ),
        ),
        child: clippedWidget,
      );
    } else {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: ShapeDecoration(
          color: widget.backgroundColor,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              width: widget.borderWidth,
              color: widget.borderColor,
            ),
            borderRadius: BorderRadius.circular(
              widget.borderRadius ?? AppTokens.radius16,
            ),
          ),
        ),
        child: clippedWidget,
      );
    }
  }
}
