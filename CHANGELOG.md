# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.4] - 2024-07-22

### Fixed

- Fix interrupt program not killing child process

## [0.0.3] - 2024-07-06

### Add

- A text message that infos the user when the compilation finished and the compilation buffer/window is not present

### Fixed

- Fix auto-scroll throws error when the compilation buffer/window is not present

## [0.0.2] - 2024-06-24

### Added

- toggle function, toggle the open/close of compilation buffer/window

### Changed

- Use vim.uv.spawn() instead of vim.fn.jobstart()

## [0.0.1] - 2024-06-21

### Added

- compile, recompile, open commands
- highlight on the compilation buffer
- jump to error location functionality
