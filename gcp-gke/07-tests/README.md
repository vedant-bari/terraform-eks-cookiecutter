# Test structure

This directory defines the intended validation layout for the GKE platform repository.

- `unit/`: isolated tests for helper logic and reusable module behavior
- `validation/`: formatting, YAML/HCL parsing, static reference checks
- `integration/`: cloud-backed tests that require an explicitly provisioned test environment
- `fixtures/`: non-sensitive test inputs and expected outputs

No automated tests are being represented as implemented by this structural migration. Add tests alongside the component they validate and keep cloud-backed tests opt-in.
