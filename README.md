Walk collections in firestore with ease

## Features

* Get the size of the collection / query
* Get any document by index within a query

## Usage

```import 'package:collection_walker/collection_walker.dart';```

```dart
class SomeScreen extends StatefulWidget {
  const SomeScreen({Key? key}) : super(key: key);

  @override
  State<SomeScreen> createState() => _SomeScreenState();
}

// The state should hold the walker
class _SomeScreenState extends State<SomeScreen> {
  late CollectionWalker<SomeData> _walker;

  @override
  void initState() {
    // Create the walker in initState
    _walker = CollectionWalker(
        chunkSize: 32, // Define a chunk size (usually 1.5x the number of items on screen)
        converter: (id, json) => SomeData.fromJson(json)..id = id, // Define a converter (see json_serializable)
        query: FirebaseFirestore.instance // Define a query
            .collection('some_collection')
            .orderBy('some_field'));
    // You do not need to dispose the walker as it only contains cached documents, when the state disposes
    // The objects cached will be disposed by GC
    super.initState();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    // Use a FutureBuilder to get the size of the collection so we can use a listview builder
    body: FutureBuilder<int>(
      future: _walker.getSize(), // Get the size future of the collection from the walker
      builder: (context, snap) => snap.hasData
          ? ListView.builder( // If we have the size, use a listview builder
        itemBuilder: (context, index) => FutureBuilder<SomeData?>(
          // Use a future builder to get the data at the index
          future: _walker.getAt(index),
          // Build it!
          builder: (context, snapshot) => snapshot.hasData
              ? Text(snapshot.data!.name)
              : const CircularProgressIndicator(),
        ),
      )
          : const Center(child: CircularProgressIndicator()),
    ),
  );
}
```
