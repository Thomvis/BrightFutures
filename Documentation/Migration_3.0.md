# Migrating from 2.0.0 to 3.0.0

- The 'Box' dependency is no longer needed. If you're using a dependency manager, you'll probably won't have to do anything.
- The 'Result' dependency has been updated to a newer version. As a result the static `Result.success` and `Result.failure` methods are no longer available. Use `Result(value:)` and `Result(error:)` instead.
- The static methods on `Future` to create a Future are removed in favor of new initializers: `Future.succeeded` becomes `Future(value:)`, `Future.failed` becomes `Future(failure:)`, `Future.never` becomes `Future()`.
- It should no longer be needed to pass the execution context with an explicit parameter name. E.g. `onSuccess(context: q) {` now is `onSuccess(q) {`
- Many free functions that used to take a Future (e.g. `flatten`, `promoteError`, `promoteValue`) are now methods on the Future itself (thanks to protocol extensions)
- Completion handlers on a future no longer retain that future. If there are no references to a future (meaning that it cannot be completed), it will now be deallocated, regardless of it having completion handlers.

There are some slight syntactical changes going from Swift 1.2 to Swift 2. Most of them can be fixed by Xcode automatically.

Tip: use GitHub to generate a diff between the version you're using and the version you want to upgrade to and check out the changes made to the tests.
