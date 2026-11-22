import 'dart:async';

import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../data/platform/file_access.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/widgets/glass.dart';
import '../common/error_text.dart';
import 'avatar_photo_crop_screen.dart';
import 'member_avatar_view.dart';

/// Abschnitt „Eigenes Foto“ im Avatar-Bildschirm (#434, E-111): Foto wählen, zuschneiden, speichern und entfernen.
/// Der Abschnitt erscheint nur, wenn die Funktion freigegeben ist (`AvatarPhotoFlags.enabled`) und Dienst, Zwischenspeicher
/// und Sync des Kalenders vorhanden sind.
///
/// Vor jeder Auswahl steht ein Hinweis, den man bestätigen muss (E-11, Kinder): Alle Familienmitglieder sehen das Foto,
/// der Server sieht nur Chiffretext, Moderatoren können es ausblenden.
class AvatarPhotoSection extends StatefulWidget {
  const AvatarPhotoSection({
    super.key,
    required this.services,
    this.preview = defaultAvatarPreview,
    this.prepare = defaultAvatarPrepare,
  });

  final AppServices services;
  final AvatarPreviewBuilder preview;
  final AvatarPhotoPreparer prepare;

  @override
  State<AvatarPhotoSection> createState() => _AvatarPhotoSectionState();
}

class _AvatarPhotoSectionState extends State<AvatarPhotoSection> {
  bool _busy = false;
  bool _wasReset = false;
  bool _pending = false;

  String get _me => widget.services.gateway.family?.myUserId ?? widget.services.gateway.userId ?? '';

  @override
  void initState() {
    super.initState();
    widget.services.calendar?.avatarPhotoImages?.addListener(_refresh);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    widget.services.calendar?.avatarPhotoImages?.removeListener(_refresh);
    super.dispose();
  }

  /// Gemerkt wird, ob das eigene Foto zurückgesetzt wurde und ob noch Ungesendetes wartet (Hinweise).
  Future<void> _refresh() async {
    final photos = widget.services.calendar?.avatarPhotos;
    if (photos == null) return;
    final reset = await photos.isResetFor(_me);
    final pending = (await photos.store.pendingPhotos(photos.roomId)).any((p) => p.photo.owner == _me);
    if (!mounted || (reset == _wasReset && pending == _pending)) return;
    setState(() {
      _wasReset = reset;
      _pending = pending;
    });
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final l = AppLocalizations.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(action)),
            ],
          ),
        ) ??
        false;
  }

  void _done() {
    final c = widget.services.calendar;
    c?.avatarPhotoImages?.invalidate();
    c?.avatarPhotoSync?.kick();
    unawaited(_refresh());
  }

  Future<void> _choose() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final photos = widget.services.calendar?.avatarPhotos;
    if (photos == null || _busy) return;
    if (!await _confirm(l.avatarPhotoNoticeTitle, l.avatarPhotoNoticeBody, l.avatarPhotoNoticeConfirm) || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      final file = await widget.services.files.pickImage();
      if (file == null || !mounted) return;
      final jpeg = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute<Uint8List>(
          builder: (_) => AvatarPhotoCropScreen(bytes: file.bytes, preview: widget.preview, prepare: widget.prepare),
        ),
      );
      if (jpeg == null || !mounted) return;
      await photos.setOwn(jpeg);
      _done();
      messenger.showSnackBar(SnackBar(content: Text(l.avatarPhotoSaved)));
    } on FileTooLargeException {
      messenger.showSnackBar(SnackBar(content: Text(l.avatarPhotoErrTooLarge)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final photos = widget.services.calendar?.avatarPhotos;
    if (photos == null || _busy) return;
    if (!await _confirm(l.avatarPhotoRemove, l.avatarPhotoRemoveConfirm, l.avatarPhotoRemove) || !mounted) return;
    setState(() => _busy = true);
    try {
      await photos.clearOwn();
      _done();
      messenger.showSnackBar(SnackBar(content: Text(l.avatarPhotoRemoved)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final calendar = widget.services.calendar;
    final images = calendar?.avatarPhotoImages;
    final sync = calendar?.avatarPhotoSync;
    if (calendar?.avatarPhotos == null || images == null || sync == null || !sync.enabled) {
      return const SizedBox.shrink();
    }
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: images,
      builder: (context, _) {
        final name = widget.services.gateway.family?.member(_me)?.displayName ?? '';
        final hasPhoto = images.imageOf(_me) != null;
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    MemberAvatarView(
                      userId: _me,
                      size: 64,
                      colorIndex: personColorOf(widget.services, _me),
                      fallbackName: name,
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Text(l.avatarPhotoSection, style: Theme.of(context).textTheme.titleMedium)),
                  ],
                ),
                if (_wasReset) ...<Widget>[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(Icons.info_outline, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(l.avatarPhotoWasReset, key: const ValueKey<String>('avatar-photo-reset-note')),
                      ),
                    ],
                  ),
                ],
                if (_pending) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(l.avatarPhotoPending, style: Theme.of(context).textTheme.bodySmall),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    FilledButton.tonal(
                      key: const ValueKey<String>('avatar-photo-choose'),
                      onPressed: _busy ? null : _choose,
                      child: Text(hasPhoto ? l.avatarPhotoChange : l.avatarPhotoChoose),
                    ),
                    if (hasPhoto)
                      TextButton(
                        key: const ValueKey<String>('avatar-photo-remove'),
                        onPressed: _busy ? null : _remove,
                        child: Text(l.avatarPhotoRemove),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
