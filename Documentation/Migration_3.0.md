# Migrating from 2.0.0 to 3.0.0-beta.1

- The 'Box' dependency is no longer needed. If you're using a dependency manager, you'll probably won't have to do anything.
- The 'Result' dependency has been updated to a newer version. As a result the static `Result.success` and `Result.failure` methods are no longer available. Use `Result(value:)` and `Result(error:)` instead.

There are some slight syntactical changes going from Swift 1.2 to Swift 2. Most of them can be fixed by Xcode automatically.
