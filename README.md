# Battle Buddy Network Database

This repository is the canonical source of truth for the Battle Buddy Network Supabase database.

## Supabase project

- Organization: Socialfy
- Project: Battle Buddy Network
- Project reference: `tsfzpmyrxhmcnxxepchw`
- Supabase configuration: `supabase/config.toml`
- Active schema changes belong in ordered SQL migrations in `supabase/migrations/`.

## Consumers

- `socialfy-battlebuddynetwork-app`
- `socialfy-battlebuddynetwork-support`

Both applications use the same Supabase project URL and publishable key through their own environment configuration. Never place a service-role or secret key in a browser application.

## Migration ownership

All database schema changes are maintained here. Consumer application repositories do not maintain independent migration histories.

## Legacy schema reference

The original ten migrations from the former app-builder-generated implementation are retained under `supabase/reference/legacy_migrations/` for analysis only. They are not the active migration baseline and must not be applied as-is.

The legacy implementation is a reference for feature intent and data relationships. Recreated schema must be reviewed for data exposure, row-level security, function privileges, and application compatibility before deployment.
