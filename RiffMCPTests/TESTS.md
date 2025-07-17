
  Run All Tests

  xcodebuild test -scheme RiffMCP -destination 'platform=macOS,arch=arm64'

  Run Individual Tests

  # Test engrave tool recognition
  xcodebuild test -scheme RiffMCP -destination 'platform=macOS,arch=arm64'
  -only-testing:RiffMCPTests/HTTPServerTests/jsonRpcEngraveToolIsRecognized

  # Test play tool functionality  
  xcodebuild test -scheme RiffMCP -destination 'platform=macOS,arch=arm64'
  -only-testing:RiffMCPTests/HTTPServerTests/jsonRpcPlayToolWorks

  # Test basic server functionality
  xcodebuild test -scheme RiffMCP -destination 'platform=macOS,arch=arm64'
  -only-testing:RiffMCPTests/HTTPServerTests/serverStartsAndStops

  # Test simple non-network functionality
  xcodebuild test -scheme RiffMCP -destination 'platform=macOS,arch=arm64'
  -only-testing:RiffMCPTests/HTTPServerTests/mockAudioManagerWorks
  -only-testing:RiffMCPTests/HTTPServerTests/serverCanBeCreated

  Run Only HTTPServer Test Suite

  xcodebuild test -scheme RiffMCP -destination 'platform=macOS,arch=arm64'
  -only-testing:RiffMCPTests/HTTPServerTests

  Quick Reference - Working Tests

  These tests are confirmed working:
  - mockAudioManagerWorks ✅
  - serverCanBeCreated ✅
  - jsonRpcEngraveToolIsRecognized ✅

  Notes

  - Working Directory: Run from /Users/lee/RiffMCP
  - Port Conflicts: Some tests may fail when run together due to port 3001
  conflicts
  - Individual Testing: Run one network test at a time for best results
  - Build Time: First run takes longer due to Swift package dependencies

  The most reliable approach is to run individual tests or the simple
  non-network tests together.