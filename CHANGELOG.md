# 1.0.1
- Updated README to reflect the pre-1.0.0 change from FutureUtils functions to free functions

# 1.0.0
- The FutureUtils class has been removed in favor of a collection of free functions. This allows for a nicer function type signature (e.g. accepting all sequences instead of just arrays)

# 1.0.0-beta.3
Note: The overview for this release is incomplete
- Changed `ExecutionContext` from a protocol to a function type. This allows for better composition. It does mean that a Queue cannot be used directly as an `ExecutionContext`, instead use the `context` property (e.g. `Queue.main.context`) or the `toContext` function (e.g. `toContext(Queue.main)`).

# 1.0.0-beta.2
Note: this overview is incomplete
- `TaskResultValueWrapper` has been renamed to the conventional name `Box`
- `TaskResult` has been renamed to the conventional name `Result`

# 1.0.0-beta.1
This release marks the state of the project before this changelog was kept up to date.
