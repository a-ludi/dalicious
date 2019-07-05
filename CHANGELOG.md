# Changelog

All notable changes to this project will be documented in this file.

The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## [Unreleased]
### Added
- Created a CHANGELOG
- Convert strings to `dash-case` at runtime
- Added `dalicious.dependency.enforceExternalDepencenciesAvailable` as a
  replacement for `dalicious.dependency.enforceExternalToolsAvailable`

### Changed
- Avoid warning about unreachable statement but print an info message instead
- Fixed Ddoc warning in `dalicious.dependency.ExternalDependencyMissing`

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
