import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/crypto/encrypted_blob_store.dart';
import '../../../../core/crypto/profile_cipher.dart';
import '../../../../core/storage/identity_vault.dart';
import '../../domain/entities/my_profile.dart';
import '../../domain/repositories/profile_repository.dart';

class ProfileRepositorySupabase implements ProfileRepository {
  ProfileRepositorySupabase({
    required SupabaseClient client,
    required String accountId,
    IdentityVault? vault,
    EncryptedBlobStore? blobStore,
  }) : _client = client,
       _accountId = accountId,
       _vault = vault ?? IdentityVault(),
       _blobStore = blobStore ?? EncryptedBlobStore(client: client);

  final SupabaseClient _client;
  final String _accountId;
  final IdentityVault _vault;
  final EncryptedBlobStore _blobStore;
  MyProfile? _cached;
  final _ctrl = StreamController<MyProfile>.broadcast();

  final Map<String, Uint8List> _avatarBytes = <String, Uint8List>{};

  @override
  void invalidateProfile() {
    _cached = null;
    _avatarBytes.clear();
  }

  @override
  Future<MyProfile> getMyProfile({bool forceRefresh = false}) async {
    if (forceRefresh) invalidateProfile();
    if (_cached != null) return _cached!;
    _cached = await _fetch();
    _ctrl.add(_cached!);
    return _cached!;
  }

  @override
  Stream<MyProfile> watchProfile() async* {
    if (_cached != null) yield _cached!;
    yield* _ctrl.stream;
  }

  @override
  Future<MyProfile> updateProfile({
    String? displayName,
    String? username,
    bool unsetUsername = false,
    String? bio,
    bool unsetBio = false,
    String? phoneDisplay,
    bool unsetPhoneDisplay = false,
  }) async {
    final current = await getMyProfile();
    await _persist(<String, dynamic>{
      'displayName': displayName ?? current.displayName,
      'bio': unsetBio ? null : (bio ?? current.bio),
      'avatarUrl': current.avatarUrl,
      if (current.avatarBlob != null) 'avatar': current.avatarBlob!.toJson(),
    }, username: unsetUsername ? null : username);
    return _refresh();
  }

  @override
  Future<MyProfile> updateAvatar(String localPath) async {
    final current = await getMyProfile();
    final bytes = await File(localPath).readAsBytes();
    final ref = await _blobStore.upload(bytes, mime: _mimeForPath(localPath));
    _avatarBytes[ref.objectKey] = bytes;
    await _persist(<String, dynamic>{
      'displayName': current.displayName,
      'bio': current.bio,
      'avatarUrl': '',
      'avatar': ref.toJson(),
    });
    return _refresh();
  }

  @override
  Future<MyProfile> removeAvatar() async {
    final current = await getMyProfile();
    final old = current.avatarBlob;
    if (old != null) {
      _avatarBytes.remove(old.objectKey);
      await _blobStore.remove(old.objectKey);
    }
    await _persist(<String, dynamic>{
      'displayName': current.displayName,
      'bio': current.bio,
      'avatarUrl': '',
    });
    return _refresh();
  }

  @override
  Future<Uint8List?> loadAvatarBytes(MyProfile profile) async {
    final ref = profile.avatarBlob;
    if (ref == null) return null;
    final cached = _avatarBytes[ref.objectKey];
    if (cached != null) return cached;
    try {
      final bytes = await _blobStore.download(ref);
      _avatarBytes[ref.objectKey] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Future<void> _persist(
    Map<String, dynamic> profile, {
    String? username,
  }) async {
    final material = await _vault.loadOrThrow();
    final cipher = await ProfileCipher.fromIdentitySeed(material.identitySeed);
    final ciphertext = await cipher.encrypt(profile);
    await _client.rpc<void>(
      'update_profile',
      params: <String, dynamic>{'p_cipher': ciphertext, 'p_username': username},
    );
  }

  Future<MyProfile> _refresh() async {
    _cached = await _fetch();
    _ctrl.add(_cached!);
    return _cached!;
  }

  Future<MyProfile> _fetch() async {
    final rows = await _client
        .from('accounts')
        .select('id, username, identity_public_key, profile_ciphertext')
        .eq('id', _accountId)
        .limit(1);
    final raw = rows.isNotEmpty ? rows.first : <String, dynamic>{};
    final material = await _vault.loadOrThrow();
    final cipher = await ProfileCipher.fromIdentitySeed(material.identitySeed);
    final profile = await cipher.decrypt(raw['profile_ciphertext'] as String?);
    final avatarJson = profile['avatar'];
    final avatarBlob = avatarJson is Map<String, dynamic>
        ? EncryptedBlobRef.fromJson(avatarJson)
        : null;
    return MyProfile(
      id: raw['id'] as String? ?? _accountId,
      displayName: profile['displayName'] as String? ?? 'You',
      username: raw['username'] as String?,
      bio: profile['bio'] as String?,
      avatarUrl: profile['avatarUrl'] as String? ?? '',
      avatarBlob: avatarBlob,
      phoneDisplay: null,
    );
  }

  String? _mimeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    return 'image/jpeg';
  }

  @override
  String shareLinkFor(MyProfile profile) {
    if (profile.username != null) {
      return 'yapp:@${profile.username}';
    }
    return 'yapp:account:${profile.id}';
  }
}
