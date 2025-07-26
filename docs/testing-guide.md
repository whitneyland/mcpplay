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

    See ./scripts

## Running Tests

### Unit Tests
```bash
# Run all tests
xcodebuild test -scheme RiffMCP -destination platform=macOS

# Run specific test suite
xcodebuild test -scheme RiffMCP -destination platform=macOS -only-testing:RiffMCPTests/ServerConfigUtilsTests
```


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

