# MIOServerKit Development Guide

## Build & Test Commands
- Build: `swift build`
- Test all: `swift test`
- Run specific test: `swift test --filter MIOServerKitTests/testSpecificName`
- Generate Xcode project: `swift package generate-xcodeproj`

## Code Style Guidelines
- **Naming**: 
  - Use "MSK" prefix for Kitura-specific implementations (MSKServer, MSKRouter)
  - Prefix private/internal variables with underscore (_router, _settings)
  - Use descriptive function names that indicate purpose
  
- **Error Handling**: 
  - Use enum-based errors implementing LocalizedError
  - Provide meaningful error descriptions
  
- **Architecture**:
  - Maintain clear separation between interfaces and implementations
  - Use protocol-based design with extensions
  - Support method chaining with @discardableResult where appropriate
  
- **Documentation**:
  - Use Swift-style doc comments (///) for public APIs
  - Include usage examples for complex functions
  
- **Testing**:
  - Write descriptive test function names (test_functionName_scenario)
  - Use XCTest assertions appropriately