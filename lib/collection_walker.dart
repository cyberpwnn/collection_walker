library collection_walker;

import 'package:fast_log/fast_log.dart';
import 'package:fire_api/fire_api.dart';
import 'package:synchronized/synchronized.dart';

typedef CollectionEntryConverter<T> = Future<T> Function(
    String id, Map<String, dynamic> json);

typedef CollectionBatchListener = List<DocumentSnapshot> Function(
    List<DocumentSnapshot> batch);

typedef CollectionDocumentEntryConverter<T> = Future<T> Function(
    DocumentSnapshot doc);

class CollectionWalker<T> {
  final int chunkSize;
  final CollectionBatchListener? batchListener;
  final CollectionEntryConverter<T>? converter;
  final CollectionDocumentEntryConverter<T>? documentConverter;
  final CollectionReference query;
  final List<DocumentSnapshot> _data = <DocumentSnapshot>[];
  final Lock _rollLock = Lock(reentrant: true);
  int? _cachedSize;

  CollectionWalker(
      {this.chunkSize = 50,
      this.documentConverter,
      this.converter,
      this.batchListener,
      required this.query}) {
    getSize();
  }

  List<DocumentSnapshot> _batch(List<DocumentSnapshot> batch) =>
      batchListener?.call(batch) ?? batch;

  Future<T> _convert(DocumentSnapshot doc) =>
      documentConverter?.call(doc) ??
      converter?.call(doc.id, doc.data ?? {}) ??
      Future.value(null as T);

  Future<int> getSize() {
    if (_cachedSize != null) {
      return Future.value(_cachedSize);
    }
    return query.count().then((value) {
      _cachedSize = value;
      return value ?? 0;
    });
  }

  Future<T?> getAt(int i) async {
    if (_data.length > i) {
      return _convert(_data[i]);
    }

    if (i >= await getSize() || i < 0) {
      error(
          "OUT OF BOUNDS $i >= ${await getSize()} in collection ${query.toString()}");
      return null;
    }

    await _rollLock.synchronized(() async {
      try {
        while (_data.length < i + 1) {
          if (_data.isEmpty) {
            _data.addAll(_batch((await query.limit(chunkSize).get())));
          } else {
            _data.addAll(_batch((await query
                .limit(chunkSize)
                .startAfter(_data[_data.length - 1])
                .get())));
          }
        }
      } catch (e, es) {
        error(e);
        error(es);
      }
    });

    return _convert(_data[i]);
  }
}
