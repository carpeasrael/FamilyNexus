import '../vault_key_store.dart';

/// Außerhalb des Browsers gibt es keinen Tresor.
VaultBackend? createWebVaultBackend() => null;
