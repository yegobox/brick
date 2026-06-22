/// Behaviors for how the repository should handle delete requests
enum OfflineFirstDeletePolicy {
  /// Delete local results before waiting for the remote provider to respond
  optimisticLocal,

  /// Delete local results after remote responds; local results are not deleted if remote responds with any exception
  requireRemote,

  /// Delete local results only; do not send any request to the remote provider
  localOnly,
}

/// Data will **always** be returned from local providers and never directly
/// from a remote provider(s)
enum OfflineFirstGetPolicy {
  /// Returns local results immediately, then refreshes in the background: Turso cloud
  /// pull (when using an embedded replica) followed by remote provider hydration.
  /// The refresh is unawaited and is not guaranteed to complete before results are returned.
  /// This can be expensive for some queries; see [awaitRemoteWhenNoneExist]
  /// for a more performant option or [awaitRemote] to await the hydration before returning results.
  alwaysHydrate,

  /// Ensures results must be updated from the remote proivder(s) before returning if the app is online.
  /// An empty array will be returned if the app is offline.
  awaitRemote,

  /// Retrieves from the remote provider(s) if the query returns no results from the local provider(s).
  ///
  /// When using a Turso embedded replica, a Turso cloud pull is attempted first so rows
  /// seeded on Turso Cloud become visible locally before falling back to the remote provider.
  awaitRemoteWhenNoneExist,

  /// Do not request from the remote provider(s)
  localOnly,
}

/// Behaviors for how the repository should handle upsert requests
enum OfflineFirstUpsertPolicy {
  /// Save results to local before waiting for the remote provider to respond
  optimisticLocal,

  /// Save results to local after remote responds;
  /// local results are not saved if remote responds with any exception
  requireRemote,

  /// Save results to local only; do not send any request to the remote provider
  localOnly,
}
