# Offline First Policies

Repository methods can be invoked with policies to prioritize data sources. For example, a request may need to skip the offline queue or the response must come from a remote source. It is strongly encouraged to use a policy (e.g. `Repository().get<User>(policy: .requireRemote))`) instead of directly accessing a provider (e.g. `Repository().restPovider.get<User>()`).

## OfflineFirstDeletePolicy

### `optimisticLocal` (default)

Delete local results before waiting for the remote provider to respond.

### `requireRemote`

Delete local results after remote responds; local results are not deleted if remote responds with any exception.

### `localOnly`

Delete local results only; do not send any request to the remote provider.

## OfflineFirstGetPolicy

### `alwaysHydrate`

Returns local results immediately, then refreshes in the background: **Turso cloud pull** (embedded replica) followed by **remote provider hydration**. The refresh is unawaited. See [Turso get policies](../sqlite/turso_get_policies.md).

### `awaitRemote`

Ensures results must be updated from the remote proivder(s) before returning if the app is online. An empty array will be returned if the app is offline.

### `awaitRemoteWhenNoneExist` (default)

Retrieves from the remote provider(s) if the query returns no results from the local provider(s). When using Turso, a **cloud pull** is attempted first, then Supabase hydrate if still empty. See [Turso get policies](../sqlite/turso_get_policies.md).

### `localOnly`

Do not request from the remote provider(s).

## OfflineFirstUpsertPolicy

### `optimisticLocal` (default)

Save results to local before waiting for the remote provider to respond.

### `requireRemote`

Save results to local after remote responds; local results are not saved if remote responds with any exception.

### `localOnly`

Save results to local only; do not send any request to the remote provider.
