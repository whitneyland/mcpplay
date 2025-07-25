# Testing Guide: App Startup Decision Tree

This document describes the comprehensive testing strategy for the RiffMCP app startup decision tree implementation.

## Overview

The app startup decision tree has two main scenarios:
1. **Normal GUI Launch** - User double-clicks the app
2. **--stdio Launch** - LLM client runs the command with `--stdio` flag

## Test Categories

### 1. Unit Tests (Swift Testing Framework)

Located in `RiffMCPTests/`, these tests verify individual components:

#### ServerConfigUtils Tests
- **File**: `RiffMCPTests/Utility/ServerConfigUtilsTests.swift`
- **Purpose**: Test server configuration reading/writing and process validation
- **Key Tests**:
  - Valid config file reading
  - Invalid/corrupted config handling
  - Process existence checking
  - Stale config cleanup

#### App Launch Tests
- **File**: `RiffMCPTests/App/AppLaunchTests.swift`
- **Purpose**: Test GUI launch scenarios and instance detection
- **Key Tests**:
  - Normal launch with no existing instance
  - Normal launch with stale config
  - Normal launch with existing running instance
  - Window focus behavior

#### StdioProxy Tests
- **File**: `RiffMCPTests/Services/StdioProxyTests.swift`
- **Purpose**: Test stdio proxy functionality and error handling
- **Key Tests**:
  - Server config detection
  - Process validation
  - HTTP request formatting
  - Error handling
  - Protocol compliance

### 2. Integration Tests

#### Manual Testing Scripts

##### Full Startup Scenarios
- **File**: `test_startup_scenarios.sh`
- **Purpose**: End-to-end testing of all startup scenarios
- **Tests**:
  1. Normal GUI launch with no existing instance
  2. Normal GUI launch with stale config cleanup
  3. Normal GUI launch with existing instance detection
  4. --stdio launch with running server
  5. --stdio launch with no server (Launch and Discover)
  6. --stdio launch with stale config

##### Simple --stdio Communication
- **File**: `test_stdio_simple.sh`
- **Purpose**: Basic JSON-RPC communication via stdio
- **Tests**:
  1. Basic initialize request
  2. List tools request
  3. Invalid JSON handling

## Running Tests

### Unit Tests
```bash
# Run all tests
xcodebuild test -scheme RiffMCP -destination platform=macOS

# Run specific test suite
xcodebuild test -scheme RiffMCP -destination platform=macOS -only-testing:RiffMCPTests/ServerConfigUtilsTests
```

### Integration Tests
```bash
# Run full startup scenario tests
./test_startup_scenarios.sh

# Run simple stdio communication tests
./test_stdio_simple.sh
```

## Test Scenarios Matrix

| Scenario | GUI Launch | --stdio Launch | Expected Behavior |
|----------|------------|----------------|-------------------|
| No existing instance | ✅ Start GUI | ✅ Launch GUI + Proxy | New instance starts |
| Stale config exists | ✅ Cleanup + Start | ✅ Launch GUI + Proxy | Stale config removed |
| Running instance exists | ✅ Focus + Terminate | ✅ Proxy to existing | No duplicate instances |
| Server running | N/A | ✅ Direct proxy | Immediate proxy mode |

## Key Test Validations

### Normal GUI Launch
- [ ] Only one GUI instance runs at a time
- [ ] Stale config files are cleaned up
- [ ] Existing windows are brought to front
- [ ] New instances terminate when duplicate detected
- [ ] server.json is created with correct format

### --stdio Launch
- [ ] Finds existing running server and proxies
- [ ] Launches GUI when no server found
- [ ] Waits for GUI to start (15-second timeout)
- [ ] Cleans up stale configs before launching
- [ ] **Always terminates with exit() - never returns normally**
- [ ] Forwards JSON-RPC messages correctly

### Important Note on --stdio Testing
The `StdioProxy.runAsProxyAndExitIfNeeded()` function **never returns normally** - it always calls `exit()`. This is intentional design but can be confusing:
- The `Bool` return type exists only to satisfy the compiler
- In `RiffMCPApp.init()`, the `if` statement and `shouldLaunchUI = false` are unreachable
- The function always terminates the process via `exit(0)` or `exit(1)`

### Error Handling
- [ ] Corrupted config files are removed
- [ ] Invalid JSON requests return proper errors
- [ ] Process validation works correctly
- [ ] Timeout scenarios are handled
- [ ] Network errors are handled gracefully

## Mock Objects and Test Utilities

### DummyAudioManager
- Used in tests to avoid actual audio operations
- Records method calls for verification

### Temporary File Management
- Tests use temporary directories to avoid conflicts
- Automatic cleanup after each test
- Isolated test environments

## Debugging Tests

### Common Issues
1. **Config file permissions**: Ensure test user has write access to Application Support
2. **Process conflicts**: Kill existing RiffMCP processes before testing
3. **Timing issues**: Increase timeouts for slow systems
4. **Bundle path detection**: Verify app is built before running tests

### Logging
- Tests output detailed logs showing decision tree steps
- Use `Log.server` statements to trace execution
- Check console output for error messages

## Continuous Integration

### Pre-commit Checks
- All unit tests must pass
- No compilation warnings
- Code formatting validation

### Test Coverage
- Aim for >90% coverage on startup logic
- Focus on edge cases and error conditions
- Verify all decision tree paths are tested

## Future Enhancements

1. **Automated UI Testing**: Add tests for AppleScript window focusing
2. **Performance Testing**: Measure startup times under various conditions
3. **Stress Testing**: Test with multiple concurrent --stdio launches
4. **Error Recovery**: Test recovery from partial failures
5. **Configuration Validation**: Test with various config file formats