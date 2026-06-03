# Changelog

All notable changes relevant to publishing this benchmark artifact are documented in this file.

## Unreleased

### Added
- Publication audit in `PUBLISH_AUDIT.md` to map `TODO_publish.md` items to the current repository state.
- Reproducibility issue template under `.github/ISSUE_TEMPLATE/` for post-publication problem reports.

### Changed
- Refreshed publication metadata in `README.md`, `benchmark_ui/docs/article.md`, and `TODO_publish.md` to point at the current publish-candidate commit and artifact hashes.

## 2026-04-22

### Added
- Standalone publication audit file for humans and LLMs.
- Repository-level changelog for release hygiene.

### Changed
- Reordered the final publication-prep commits so the Python worker endpoint compatibility change appears before regenerated benchmark artifacts.
- Updated benchmark artifact validation metadata to match the current publish candidate.

## 2026-03-11

### Added
- Canonical validated run record and artifact hashes captured in `TODO_publish.md`.
- Benchmark CSV and SVG artifacts checked into the repository for archival publication.