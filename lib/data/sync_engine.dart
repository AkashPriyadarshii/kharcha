import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'remote_transaction.dart';
import 'transaction_repository.dart';

/// Pushes local dirty rows up and pulls remote rows down (LWW by updated_at).
/// Offline failures leave rows dirty; the next trigger retries.
class SyncEngine {
  SyncEngine(this._repo, this._client, this._userId);

  final TransactionRepository _repo;
  final SupabaseClient _client;
  final String _userId;

  bool _running = false;

  /// Re-entrancy guard: one sync at a time, concurrent callers no-op.
  Future<void> syncNow() async {
    if (_running) return;
    _running = true;
    try {
      await _push();
      await _pull();
    } finally {
      _running = false;
    }
  }

  Future<void> _push() async {
    // Deletes first: removes remote rows before anything could re-pull them.
    // A tombstone survives any failure (offline, transient) and retries next
    // sync; it clears only when the DELETE succeeded (a no-op on an already-
    // gone row also succeeds). Keeps a stale pull from resurrecting the row.
    final tombstones = await _repo.deletedRemoteIds();
    for (final remoteId in tombstones) {
      await _client.from('transactions').delete().eq('id', remoteId);
      await _repo.clearDeletedRow(remoteId);
    }
    final dirty = await _repo.dirtyRows();
    for (final t in dirty) {
      final json = localToRemoteJson(t, _userId);
      try {
        if (t.remoteId != null) {
          await _client.from('transactions').update(json).eq('id', t.remoteId!);
        } else {
          final resp = await _client
              .from('transactions')
              .insert(json)
              .select()
              .single();
          await _repo.markSynced(t.id, resp['id'] as int);
        }
      } on PostgrestException catch (e) {
        if (e.code == '23505') {
          // Unique (user_id, upi_ref) hit — the remote already has this
          // payment (e.g. retry after a lost ack). Claim its id, keep going.
          final ref = t.upiRef;
          if (ref != null) {
            final existing = await _client
                .from('transactions')
                .select('id')
                .eq('upi_ref', ref)
                .maybeSingle();
            if (existing != null) {
              await _repo.markSynced(t.id, existing['id'] as int);
            }
          }
        } else {
          rethrow;
        }
      }
    }
  }

  Future<void> _pull() async {
    final rows = await _client
        .from('transactions')
        .select()
        .order('updated_at', ascending: false)
        .limit(1000);
    final tombstones = await _repo.deletedRemoteIds().then((ids) => ids.toSet());
    for (final r in rows) {
      final remote = RemoteTransaction.fromRemoteJson(r);
      // Skip rows the user deleted locally — the DELETE may not have reached
      // the server yet, but the row must not come back.
      if (remote.id != null && tombstones.contains(remote.id)) continue;
      await _repo.applyRemote(remote);
    }
  }
}

/// The sync engine for the signed-in user. Builds only when a session exists.
final syncEngineProvider = Provider<SyncEngine>((ref) {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) {
    throw StateError('syncEngineProvider read without a signed-in user');
  }
  return SyncEngine(ref.watch(transactionRepositoryProvider), client, user.id);
});

/// Fire-and-forget sync when signed in; silent no-op when not / offline.
/// Offline is the expected case — rows stay dirty and flush on the next
/// trigger (app start, login, or a later write).
Future<void> syncIfSignedIn(ProviderContainer container) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return;
  try {
    await container.read(syncEngineProvider).syncNow();
  } catch (e) {
    debugPrint('sync deferred (offline or transient): $e');
  }
}
