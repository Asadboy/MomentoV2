# Database incidents

Short post-mortems for production database issues, newest first. Each entry
points at the migration that fixed it (in `Supabase/migrations/`).

---

## 2026-06-16 — Photo uploads failed: "shots couldn't upload"

**Fix:** `migrations/20260616120000_photos_client_upload_id_full_unique.sql`

### Symptom
Creating an event and taking shots showed *"N shots couldn't upload"*. No
photo rows appeared. It had worked during the Fri/Sat showcase and broke
after installing the latest device build. Reproduced on event "Test"
(`893edb93…`): 2 shots, 0 rows.

### Root cause
Photo upload is two steps — (1) PUT the JPEG to the `momento-photos`
storage bucket, (2) insert the `photos` row. Step 1 succeeded; step 2
failed every time, and the orphaned storage objects were then auto-deleted.

The client inserts with PostgREST `?on_conflict=client_upload_id`
(`.upsert(..., ignoreDuplicates: true)` → `ON CONFLICT (client_upload_id)
DO NOTHING`) for idempotent retries. But the unique index on that column
was **partial**:

```sql
CREATE UNIQUE INDEX photos_client_upload_id_key
  ON photos (client_upload_id) WHERE client_upload_id IS NOT NULL;
```

Postgres will not use a **partial** unique index as an `ON CONFLICT`
arbiter unless the statement repeats the index predicate — which PostgREST
cannot emit. So every insert was rejected:

- PostgREST api log: `POST 400 /rest/v1/photos?on_conflict=client_upload_id`
- Postgres log: `ERROR 42P10: there is no unique or exclusion constraint
  matching the ON CONFLICT specification`

It was 100% deterministic, hence *both* shots failing.

### Why it regressed (the "two things changed")
- The partial index shipped with the idempotency work
  (`_migrations_archive/20260518120100_photo_idempotency.sql`).
- The client switched `.insert(photo)` → `.upsert(photo,
  onConflict: "client_upload_id")` in **PR #58** (`4efc351`).

The Fri/Sat build predated PR #58 (plain `.insert`, no `on_conflict`, so it
never hit the partial-index rule). Installing the post-#58 build is what
exposed the latent index problem.

### Fix
Replace the partial index with a **full** unique index. A full unique index
on a nullable column still allows unlimited `NULL`s (NULLS DISTINCT default,
so legacy rows are unaffected) **and** is a valid `ON CONFLICT` arbiter;
uniqueness of real `client_upload_id` values is unchanged.

```sql
DROP INDEX IF EXISTS public.photos_client_upload_id_key;
CREATE UNIQUE INDEX photos_client_upload_id_key ON public.photos (client_upload_id);
```

Applied to prod via MCP `apply_migration` (no app rebuild required — the fix
is server-side, so builds already on devices recovered immediately).

### Verification
- Temp-table repro: partial index → `42P10`; full index → succeeds, multiple
  NULLs allowed.
- Live `photos` table (rolled-back test row): `on_conflict` insert succeeds,
  idempotent retry is a clean no-op (exactly 1 row).
- Index confirmed full: `pg_index.indpred IS NULL`.
- On-device: a fresh shot saved; retry flushed the previously-queued failed
  shots; a new event ("game day") took 2 shots that saved.
