import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/blocked_user.dart';
import '../../domain/entities/last_seen_visibility.dart';
import 'settings_repository_impl.dart';

class SettingsRepositorySupabase extends SettingsRepositoryImpl {
  SettingsRepositorySupabase({
    required SupabaseClient client,
    required String accountId,
  }) : _client = client,
       _accountId = accountId;

  final SupabaseClient _client;
  final String _accountId;

  @override
  Future<void> blockUser(BlockedUser user) async {
    try {
      await _client.from('blocks').insert(<String, dynamic>{
        'blocker_account_id': _accountId,
        'blocked_account_id': user.id,
      });
    } catch (_) {
      return;
    }
    await super.blockUser(user);
  }

  @override
  Future<void> unblockUser(String id) async {
    try {
      await _client
          .from('blocks')
          .delete()
          .eq('blocker_account_id', _accountId)
          .eq('blocked_account_id', id);
    } catch (_) {
      return;
    }
    await super.unblockUser(id);
  }

  @override
  Future<void> setLastSeen(LastSeenVisibility value) async {
    await super.setLastSeen(value);
    try {
      await _client.rpc<void>(
        'set_last_seen_visibility',
        params: <String, dynamic>{'p_vis': value.storageValue},
      );
    } catch (_) {}
  }

  Future<void> syncBlockedFromServer() async {
    final List<dynamic> rows;
    try {
      rows = await _client
          .from('blocks')
          .select('blocked_account_id')
          .eq('blocker_account_id', _accountId);
    } catch (_) {
      return;
    }
    final ids = rows
        .map(
          (e) => (e as Map<String, dynamic>)['blocked_account_id'].toString(),
        )
        .toList(growable: false);
    await replaceBlockedFromServer(ids);
  }
}
