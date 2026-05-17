#!/bin/sh

#
#  ci_post_clone.sh
#  Xcode Cloud automatically runs this after cloning the repo, before the
#  build. It recreates the gitignored Secrets.xcconfig (the project's
#  baseConfigurationReference) from Xcode Cloud *environment variables*, so
#  the Archive action can resolve it. Mirrors .github/workflows/testflight.yml.
#
#  REQUIRED Xcode Cloud environment variables (App Store Connect → Xcode Cloud
#  → Manage Workflows → [workflow] → Environment → Environment Variables;
#  mark each Secret). Set the VALUES to exactly what your local
#  Secrets.xcconfig contains — including the `https:/$()/` escaping on URLs
#  (xcconfig treats `//` as a comment), same as the GitHub Actions secrets:
#
#    SUPABASE_URL        e.g.  https:/$()/<project>.supabase.co
#    SUPABASE_ANON_KEY
#    POSTHOG_API_KEY
#    POSTHOG_HOST        e.g.  https:/$()/eu.i.posthog.com
#    SENTRY_DSN          e.g.  https:/$()/<key>@<org>.ingest.de.sentry.io/<id>
#

set -e

# Xcode Cloud clones into /Volumes/workspace/repository — the build config
# expects Secrets.xcconfig at the repo root, which is one level up from
# ci_scripts/.
REPO_ROOT="$CI_PRIMARY_REPOSITORY_PATH"
if [ -z "$REPO_ROOT" ]; then
  REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fi

CONFIG="$REPO_ROOT/Secrets.xcconfig"

cat > "$CONFIG" <<EOF
SUPABASE_URL = ${SUPABASE_URL}
SUPABASE_ANON_KEY = ${SUPABASE_ANON_KEY}
POSTHOG_API_KEY = ${POSTHOG_API_KEY}
POSTHOG_HOST = ${POSTHOG_HOST}
SENTRY_DSN = ${SENTRY_DSN}
EOF

# Fail fast with a clear message if a required secret wasn't configured in
# the Xcode Cloud workflow — better than a confusing archive error later.
# (Never echoes the values.)
test -s "$CONFIG" || { echo "ci_post_clone: Secrets.xcconfig is empty"; exit 1; }
grep -q "^SUPABASE_URL = ." "$CONFIG"      || { echo "ci_post_clone: SUPABASE_URL env var missing in Xcode Cloud workflow"; exit 1; }
grep -q "^SUPABASE_ANON_KEY = ." "$CONFIG" || { echo "ci_post_clone: SUPABASE_ANON_KEY env var missing in Xcode Cloud workflow"; exit 1; }

echo "ci_post_clone: wrote $CONFIG ($(wc -l < "$CONFIG") lines, values not shown)"
