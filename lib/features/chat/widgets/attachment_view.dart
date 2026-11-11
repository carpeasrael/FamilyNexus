part of '../chat_screen.dart';

/// Anhänge werden nie automatisch geladen oder geöffnet.
class _AttachmentView extends StatefulWidget {
  const _AttachmentView({required this.message, required this.services, required this.threadId});
  final ChatMessage message;
  final AppServices services;
  final String threadId;

  @override
  State<_AttachmentView> createState() => _AttachmentViewState();
}

class _AttachmentViewState extends State<_AttachmentView> {
  Uint8List? _bytes;
  bool _loading = false;

  Future<Uint8List?> _load() async {
    if (_bytes != null) return _bytes;
    final l = AppLocalizations.of(context);
    setState(() => _loading = true);
    try {
      final b = await widget.services.gateway.loadAttachment(widget.message.id, threadId: widget.threadId);
      if (mounted) setState(() => _bytes = b);
      return b;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(l, e))));
      return null;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(l.attachmentSaveWarning),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.save)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final b = await _load();
    if (b == null) return;
    final a = widget.message.attachment!;
    try {
      await widget.services.files.saveFile(name: a.name, bytes: b, mimeType: a.mimeType);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(l, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final a = widget.message.attachment!;
    if (a.isImage && _bytes != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              _bytes!,
              height: 200,
              cacheHeight: 400, // begrenzt den Speicher (Bild-Bomben)
              fit: BoxFit.cover,
              semanticLabel: a.name,
              errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
            ),
          ),
          // Bilder lassen sich wie andere Anhänge speichern (#40).
          TextButton.icon(onPressed: _save, icon: const Icon(Icons.download_outlined), label: Text(l.chatSaveAttachment)),
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
        Icon(a.isImage ? Icons.image_outlined : Icons.insert_drive_file_outlined),
        const SizedBox(width: 6),
        Flexible(child: Text(a.name, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 6),
        if (_loading)
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
        else if (a.isImage) ...<Widget>[
          TextButton(onPressed: _load, child: Text(l.chatLoadAttachment)),
          TextButton(onPressed: _save, child: Text(l.chatSaveAttachment)),
        ] else
          TextButton(onPressed: _save, child: Text(l.chatSaveAttachment)),
      ]),
    );
  }
}
