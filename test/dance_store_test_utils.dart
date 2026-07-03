/// Shared timer durations for tests that construct a `DanceGradeStore` or
/// `DanceCuesStore`: deliberately long so a test's debounced autosave / poll
/// timer never fires on its own — every test drives `flush()`/`pollOnce()`
/// explicitly instead. Every store-owning test file previously hand-rolled
/// its own copy of these two literals.
library;

const kTestStoreSaveDebounce = Duration(minutes: 1);
const kTestStorePollInterval = Duration(minutes: 1);
