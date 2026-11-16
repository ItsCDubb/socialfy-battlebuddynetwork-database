# Battle Buddy Network Database

This repository is the canonical source of truth for the Battle Buddy Network Supabase database.

## Supabase project

- Project reference: `szqxrqlybhwoniizgrjb`
- Supabase configuration: `supabase/config.toml`
- Schema changes are maintained as ordered SQL migrations in `supabase/migrations/`.

## Consumers

- `socialfy-battlebuddynetwork-app`
- `socialfy-battlebuddynetwork-support`

Both applications must use the same Supabase project URL and publishable key through their own environment configuration. Do not place service-role or secret keys in browser applications.

## Migration ownership

All schema changes belong in this repository. Application repositories consume the shared database; they do not maintain independent schema migration histories.

## Current baseline

The initial migrations are being transferred from the application repository to establish the database repository as the canonical migration history. Before applying them to the hosted project, compare the remote schema and migration history to avoid replaying already-applied changes.
