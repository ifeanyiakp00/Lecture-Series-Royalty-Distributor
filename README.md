# Lecture Series Royalty Distributor

Distribute STX royalties for lecture series to registered recipients based on shares. Simple, minimal, and deterministic. ✨

## Features
- Create series with an admin 👤
- Add/update/remove recipients with shares 🧮
- Distribute STX immediately to recipients in one call 💸
- Remainder from integer division goes to the series admin ➕
- Read-only helpers to inspect series state 🔎

## Clarity version
- Uses Clarity v3 and expects stacks-block-height and get-stacks-block-info naming in the environment.

## Contract
- Path: `contracts/Lecture-Series-Royalty-Distributor.clar`
- Deploy in a Clarinet project and run checks: `clarinet check`

## Quick start
1. Install Clarinet: https://docs.hiro.so/clarinet
2. Create a new project and place this repo’s files in it.
3. Normalize line endings to LF:
   - PowerShell:
     ```powershell
     (Get-Content "contracts/Lecture-Series-Royalty-Distributor.clar" -Raw).Replace("`r`n", "`n") | Set-Content "contracts/Lecture-Series-Royalty-Distributor.clar" -NoNewline
     (Get-Content "README.md" -Raw).Replace("`r`n", "`n") | Set-Content "README.md" -NoNewline
     ```
4. Check: `clarinet check`

## Usage
- Create a series:
  ```clarity
  (contract-call? .Lecture-Series-Royalty-Distributor create-series)
  ```
  Returns the new series id `u1`, `u2`, ...

- Add a recipient (admin only):
  ```clarity
  (contract-call? .Lecture-Series-Royalty-Distributor add-recipient u1 'SP… u50)
  ```

- Update shares (admin only):
  ```clarity
  (contract-call? .Lecture-Series-Royalty-Distributor update-recipient-shares u1 'SP… u60)
  ```

- Remove a recipient (admin only):
  ```clarity
  (contract-call? .Lecture-Series-Royalty-Distributor remove-recipient u1 'SP…)
  ```

- Distribute STX to all recipients in one call:
  Provide recipients and their shares as parallel lists that exactly match registered shares. The function transfers from the transaction sender to recipients and sends any remainder to the series admin.
  ```clarity
  (contract-call? .Lecture-Series-Royalty-Distributor distribute
    u1
    u1000000
    (list 'SP2C2… 'SP3ABC…)
    (list u60 u40)
  )
  ```

- Read-only helpers:
  ```clarity
  (contract-call? .Lecture-Series-Royalty-Distributor series-info u1)
  (contract-call? .Lecture-Series-Royalty-Distributor get-share-of u1 'SP…)
  (contract-call? .Lecture-Series-Royalty-Distributor can-distribute u1)
  (contract-call? .Lecture-Series-Royalty-Distributor preview-splits u1 u1000000 (list 'SP… 'SP…) (list u… u…))
  ```

## Notes
- Shares are uints summed per series; total must equal the provided shares when distributing.
- Distribution is immediate from `tx-sender` to recipients; the contract does not custody STX.
- If any transfer fails, the whole distribution aborts.

## Testing
- Run `clarinet check` ✅
