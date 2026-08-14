#!/usr/bin/env bash
set -euo pipefail

source test/post_fixture_helpers.sh

tmp_dir="$(mktemp -d)"
tmp_override="${tmp_dir}/comments-test-override.yml"
tmp_site="${tmp_dir}/site"

cleanup() {
  cleanup_post_fixtures
  rm -rf "${tmp_dir}"
}
trap cleanup EXIT

create_post_fixture "2022-12-10-giscus-comments.md" <<'MARKDOWN'
---
layout: post
title: giscus comments integration fixture
date: 2022-12-10 11:59:00-0400
giscus_comments: true
related_posts: false
---

Temporary fixture for the comments integration test.
MARKDOWN

create_post_fixture "2015-10-20-disqus-comments.md" <<'MARKDOWN'
---
layout: post
title: disqus comments integration fixture
date: 2015-10-20 11:59:00-0400
disqus_comments: true
related_posts: false
---

Temporary fixture for the comments integration test.
MARKDOWN

cat >"${tmp_override}" <<'YAML'
giscus:
  repo: alshedivat/al-folio
  repo_id: R_kgDOExample
  category: Comments
  category_id: DIC_kwDOExample
YAML

bundle exec jekyll build --config "_config.yml,${tmp_override}" -d "${tmp_site}" >/dev/null

giscus_page="${tmp_site}/blog/2022/giscus-comments/index.html"
disqus_page="${tmp_site}/blog/2015/disqus-comments/index.html"

grep -q 'https://giscus.app/client.js' "${giscus_page}"
if grep -q 'giscus comments misconfigured' "${giscus_page}"; then
  echo "unexpected giscus misconfiguration warning in ${giscus_page}" >&2
  exit 1
fi

grep -q 'id="disqus_thread"' "${disqus_page}"
grep -q '.disqus.com/embed.js' "${disqus_page}"

echo "comments integration checks passed"
