# Changelog

All notable changes to this project will be documented in this file.

The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [unreleased]
### Added
- Encode/decode a pair of integers in a single integer.

### Fixed
- Compiler error due to non-constant `case` value


## [3.1.0] - 2020-02-27
### Added
- Added `quantiles`


## [3.0.0] - 2020-02-27
### Added
- Added `evenSlices` similar to `std.range.evenChunks`
- Added `stddev`
- Added `eliminateOutliers`

### Changed
- Extended `median` and `N!xx` with a `map`ping function
- Changed `median` and `N!xx` to return `undefined` value if the statistic is
  undefined; these changes are incompatible to previous versions


## [2.4.0] - 2020-01-14
### Added
- Added mean in `Histogram.toString`
- Added `isExecutable`

### Fixed
- Fixed check for external dependencies


## [2.3.0] - 2019-10-02
### Added
- Added possibility to replace `acc` and `category` function of a masker
- Added `coverageChanges` to `masker`
- Added histogram to `math` module
- Added some algebra for `TaggedPoint`

### Fixed
- Made `logIndex` and `inverseLogIndex` `@safe`
- Fixed type bug


## [2.2.0] - 2019-09-24
### Added
- Created `masker` algorithm

### Changed
- Restructured package `dalicious.algorithm` into several sub-packages

### Fixed
- Made `traceExecution` `@safe`


## [2.1.0] - 2019-09-09
### Added
- DUB badge to README
- `sliceBy` returns a forward range
- logarithmic indexing functions
- interval clustering and filtering
- ring buffer implementation

### Fixed
- typing bug in `math.mean`


## [2.0.0] - 2019-08-22
### Added
- Created a CHANGELOG
- Convert strings to `dash-case` at runtime
- Added `dalicious.dependency.enforceExternalDepencenciesAvailable` as a
  replacement for `dalicious.dependency.enforceExternalToolsAvailable`
- New type `BoundedArray`
- Added helper `charRange`
- Added execution helpers `executeCommand`, `executeShell`, `executeScript`
  that log their actions

### Changed
- Improved `traceExecution`; it now reports function names including template
  parameters
- Made `logJson` and friends more convenient
- Avoid warning about unreachable statement but print an info message instead
- Fixed Ddoc warning in `dalicious.dependency.ExternalDependencyMissing`
- Avoid naming conflict with `std.array.array`
- Other bug fixes and improvements

### Deprecated
- `dalicious.dependency.enforceExternalToolsAvailable` because the name does
  not match other names in the module


## [1.1.0] - 2019-07-04
### Added
- New module `dependency` for managing external dependencies


## [1.0.1] - 2019-07-04
### Changed
- Typos in README and embedded docs
- Avoid warning when compiling docs by using `$(RPAREN)`


## [1.0.0] - 2019-07-04
### Added
- Basic repository files including README and LICENSE
- All modules from [`dentist.util`](dentist-util) except for a few
  functionalities.


[dentist-util]: https://github.com/a-ludi/dentist/tree/ab1f3c65dc66e5f29d9209264433f89cb2a028b6/source/dentist/util
