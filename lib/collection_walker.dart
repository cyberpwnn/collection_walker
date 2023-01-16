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

class CollectionWalker<T> {
  final int chunkSize;
  final CollectionEntryConverter<T> converter;
  final Query<Map<String, dynamic>> query;
  final List<DocumentSnapshot<Map<String, dynamic>>> _data =
      <DocumentSnapshot<Map<String, dynamic>>>[];
  final Lock _rollLock = Lock(reentrant: true);
  int? _cachedSize;

  CollectionWalker(
      {this.chunkSize = 8, required this.converter, required this.query}) {
    getSize();
  }

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
      return converter(_data[i].id, _data[i].data() ?? {});
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
            _data.addAll((await query.limit(chunkSize).get()).docs);
          } else {
            _data.addAll((await query
                    .limit(chunkSize)
                    .startAfterDocument(_data[_data.length - 1])
                    .get())
                .docs);
          }
        }
      } catch (e, es) {
        error(e);
        error(es);
      }
    });

    return converter(_data[i].id, _data[i].data() ?? {});
  }
}
