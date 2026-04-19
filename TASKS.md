# Amber CLI Tasks

## Completed (2025-12-26)
- [x] Changed default template from slang to ECR
- [x] Removed recipes feature (deprecated liquid.cr)
- [x] Verified CLI builds successfully
- [x] Tested --version flag
- [x] Tested new command (generates ECR templates)
- [x] Tested generate model command
- [x] Tested generate controller command
- [x] Tested generate scaffold command (generates ECR views)
- [x] GitHub Actions CI/CD already configured for Ubuntu + macOS

## Remaining Work
- [ ] Run full test suite: `crystal spec`
- [ ] Update homebrew-amber formula after publishing
- [ ] Create GitHub release for v2.0.0
- [ ] Add integration tests that validate generated app compiles
- [ ] Consider Docker testing for Linux validation

## Notes
- CI workflow exists at `.github/workflows/ci.yml`
- Runs on ubuntu-latest and macos-latest
- Integration test job will skip if no spec/integration folder exists
