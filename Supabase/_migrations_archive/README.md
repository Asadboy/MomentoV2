# Archived migrations (pre-baseline)

These 26 files are the **historical** migration chain, superseded on
2026-06-13 by `Supabase/migrations/20260613000000_baseline_schema.sql`.

They are kept for reference only. They live **outside** `Supabase/migrations/`
so the Supabase CLI never tries to replay them. **Do not edit them and do
not move them back** into the migrations directory.

## Why we rebaselined

The chain had drifted badly from production. A large amount of the
Momento → 10shots rebrand DDL was applied out-of-band (dashboard / MCP)
and never captured as files — and some files referenced columns that no
earlier file created. The result: a fresh `supabase db reset` could not
replay the chain to a working schema. The baseline restores the invariant
**“a fresh DB built from migrations == production.”**

Notably, two production migrations were never represented in the repo at
all before the baseline:

- `20260609214810 fix_lobby_roster_select_rls` — the `is_event_member()`
  helper + the event_members SELECT policy (lobby roster fix). PR #63.
- `20260609221339 scope_momento_photos_storage_rls` — the membership-scoped
  momento-photos storage policies (closed the bucket-wide read/write hole).
  PR #65.

Both are folded into the baseline. **PRs #63 and #65 should therefore be
closed as superseded** rather than merged (merging them would re-add
straggler files alongside the baseline). The Swift-only PR #64 (lobby
roster error surfacing) is independent and merges normally.

## Production migration history at the time of rebaseline

For recoverability, the full `supabase_migrations.schema_migrations`
contents as of 2026-06-13 (27 rows):

```
20241109000000  initial_schema
20241109000001  rls_policies
20260505224548  add_photos_username
20260506121301  drop_dead_count_triggers
20260506225017  fix_db_advisors
20260506232945  member_limit_default_and_cap
20260506234339  fix_lookup_event_by_code
20260506234832  drop_photos_pending_index
20260511134613  fix_event_members_insert_rls_deadlock
20260511135323  drop_cross_table_cap_from_rls
20260511224601  delete_my_account_rpc
20260512145005  drop_username_requirement
20260512145312  tighten_avatars_bucket_listing
20260512151854  enforce_photo_limit_per_user
20260512155002  backend_reconcile
20260512220539  avatar_policies_case_insensitive
20260512224125  archive_keepers_purge_test_events
20260512232442  debug_avatars_permissive_temp
20260512233101  avatars_debug_open_completely
20260512233830  avatar_policies_lock_back_down
20260513110712  enforce_member_limit_per_event
20260517132002  member_limit_unlimited_at_launch
20260518134206  20260518120000_photo_reports
20260518141535  20260518120100_photo_idempotency
20260518144236  20260518120200_photo_limit_exempt_idempotent_retry
20260609214810  fix_lobby_roster_select_rls
20260609221339  scope_momento_photos_storage_rls
```

## Reconciling the production history table (run AT MERGE TIME)

The baseline changes nothing in production (the schema already matches).
The only follow-up is to make the production migration-history table agree
with the new single-file migrations directory, so `supabase migration
list` / `db pull` stay sane. **Run this once, when the baseline PR merges
to `main`** (not before — running it earlier would make `main` and prod
disagree in the opposite direction during the open-PR window):

```sql
-- Replace the 27 historical version rows with the single baseline row.
DELETE FROM supabase_migrations.schema_migrations
WHERE version <> '20260613000000';

INSERT INTO supabase_migrations.schema_migrations (version, name)
VALUES ('20260613000000', 'baseline_schema')
ON CONFLICT (version) DO NOTHING;
```

(Equivalent via CLI: `supabase migration repair --status reverted <each old
version>` then `--status applied 20260613000000`.)

After this, `supabase migration list` shows exactly one local file and one
remote version, both `20260613000000`.
```
