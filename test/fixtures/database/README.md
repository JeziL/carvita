# Database migration fixtures

`carvita_v1.db` is a maintainer-provided, anonymized schema-v1 CarVita
database used only by migration and backup compatibility tests.

- SHA-256:
  `6C2020B6516B2DB5A0AA9530925C94298C8534AD7C41F1B193F45353E20EFEF4`
- SQLite `integrity_check`: `ok`
- Rows before migration: 1 vehicle, 9 plan items, 12 service logs, and
  38 performed-item links
- Known v1 consistency issues: none
- Explicit secondary indexes: none

Tests must copy the fixture before opening it with the current
`DatabaseHelper`, because opening a v1 database performs an in-place upgrade.
Synthetic fixtures cover orphan cleanup and migration failure paths; do not
mutate this file to create corrupted-data cases.
