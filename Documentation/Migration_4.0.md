# Migrating from 3.3.0 to 4.0.0

4.0.0 is a minor breaking release. When upgrading to BrightFutures 4, please perform the following steps:

- `SequenceType.fold(_:zero:f:)` and methods that use it (such as `SequenceType.traverse(_:f:)` and `SequenceType.sequence()`) are now slightly more asynchronous. Previously, these methods could return immediately in some cases. This is no longer the case. For all usages in your project, please check that there are no assumptions made on the synchronous execution of those operations.
- `NoError` has been removed from BrightFutures. Use Result's `NoError` instead. You'll have to add `import Result` in the files where you use `NoError`.