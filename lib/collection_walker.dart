library collection_walker;

/*
 * Copyright (c) 2022.. MyGuide
 *
 * MyGuide is a closed source project developed by Arcane Arts.
 * Do not copy, share, distribute or otherwise allow this source file
 * to leave hardware approved by Arcane Arts unless otherwise
 * approved by Arcane Arts.
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fast_log/fast_log.dart';
import 'package:synchronized/synchronized.dart';

typedef CollectionEntryConverter<T> = Future<T> Function(
    String id, Map<String, dynamic> json);

typedef CollectionBatchListener = List<DocumentSnapshot<Map<String, dynamic>>>
    Function(List<DocumentSnapshot<Map<String, dynamic>>> batch);

typedef CollectionDocumentEntryConverter<T> = Future<T> Function(
    DocumentSnapshot<Map<String, dynamic>> doc);

class CollectionWalker<T> {
  final int chunkSize;
  final CollectionBatchListener? batchListener;
  final CollectionEntryConverter<T>? converter;
  final CollectionDocumentEntryConverter<T>? documentConverter;
  final Query<Map<String, dynamic>> query;
  final List<DocumentSnapshot<Map<String, dynamic>>> _data =
      <DocumentSnapshot<Map<String, dynamic>>>[];
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

  List<DocumentSnapshot<Map<String, dynamic>>> _batch(
          List<DocumentSnapshot<Map<String, dynamic>>> batch) =>
      batchListener?.call(batch) ?? batch;

  Future<T> _convert(DocumentSnapshot<Map<String, dynamic>> doc) =>
      documentConverter?.call(doc) ??
      converter?.call(doc.id, doc.data() ?? {}) ??
      Future.value(null as T);

  Future<int> getSize() {
    if (_cachedSize != null) {
      return Future.value(_cachedSize);
    }
    return query.count().get().then((value) => value.count).then((value) {
      _cachedSize = value;
      return value;
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
            _data.addAll(_batch((await query.limit(chunkSize).get()).docs));
          } else {
            _data.addAll(_batch((await query
                    .limit(chunkSize)
                    .startAfterDocument(_data[_data.length - 1])
                    .get())
                .docs));
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
