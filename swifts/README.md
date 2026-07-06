# Swift Scaffold Scripts

This folder contains Swift-specific scaffold scripts and tests.

## Files

- `create_page_triplet_swift.sh`: create Swift page scaffold files.
- `test_create_page_triplet_swift.sh`: validation script for Swift scaffold behavior.

## Usage

```bash
cd scripts_reps
./swifts/create_page_triplet_swift.sh --dry-run --json ios/pages/order_detail
./swifts/create_page_triplet_swift.sh --json ios/pages/order_detail
```

## Test

```bash
cd scripts_reps
./swifts/test_create_page_triplet_swift.sh
```
