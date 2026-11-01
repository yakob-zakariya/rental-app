/// For a provider's `retry:` parameter. Riverpod 3 retries failing providers
/// automatically by default; ours don't — the user retries (Retry button,
/// pull-to-refresh), and the screens show the error meanwhile.
Duration? noAutomaticRetry(int retryCount, Object error) => null;
