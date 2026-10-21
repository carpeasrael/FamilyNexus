import 'package:flutter/foundation.dart';

import '../../data/sync/shopping_sync.dart';
import '../../domain/shopping.dart';
import '../../domain/shopping_store.dart';

/// Zustand und Aktionen der Einkaufsliste für die Oberfläche.
class ShoppingController extends ChangeNotifier {
  ShoppingController({required this.service, required this.store, required this.sync});

  final ShoppingService service;
  final ShoppingStore store;
  final ShoppingSync sync;

  List<ShoppingItem> _items = const <ShoppingItem>[];
  bool _started = false;
  bool _disposed = false;

  String get me => service.myUserId;

  /// Aktive Einträge: offene zuerst (älteste zuerst), danach abgehakte (zuletzt abgehakte zuerst).
  List<ShoppingItem> get items => _items;
  List<ShoppingItem> get open => <ShoppingItem>[for (final i in _items) if (!i.checked) i];
  List<ShoppingItem> get done => <ShoppingItem>[for (final i in _items) if (i.checked) i];
  int get openCount => _items.where((i) => !i.checked).length;

  void start() {
    if (_started) return;
    _started = true;
    sync.onChanged = () => load().ignore();
    sync.start();
    load().ignore();
  }

  @override
  void dispose() {
    _disposed = true;
    sync.onChanged = null;
    sync.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final all = await store.all();
    if (_disposed) return;
    final active = all.where((i) => !i.deleted).toList();
    final open = active.where((i) => !i.checked).toList()..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    final done = active.where((i) => i.checked).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _items = <ShoppingItem>[...open, ...done];
    notifyListeners();
  }

  Future<void> add(String title, {String quantity = ''}) async {
    await service.add(title, quantity: quantity);
    await _changed();
  }

  Future<void> setChecked(String id, bool checked) async {
    await service.setChecked(id, checked);
    await _changed();
  }

  Future<void> edit(String id, {required String title, String quantity = ''}) async {
    await service.edit(id, title: title, quantity: quantity);
    await _changed();
  }

  Future<void> remove(String id) async {
    await service.remove(id);
    await _changed();
  }

  Future<int> clearChecked() async {
    final n = await service.clearChecked();
    await _changed();
    return n;
  }

  Future<void> _changed() async {
    await load();
    sync.kick();
  }
}
