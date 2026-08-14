#!/usr/bin/env bash

fixture_posts_dir="_posts"
fixture_posts_dir_created=false
fixture_post_paths=()

create_post_fixture() {
  local filename="$1"
  local path="${fixture_posts_dir}/${filename}"

  if [ -e "${path}" ]; then
    return
  fi

  if [ ! -d "${fixture_posts_dir}" ]; then
    mkdir -p "${fixture_posts_dir}"
    fixture_posts_dir_created=true
  fi

  fixture_post_paths+=("${path}")
  cat >"${path}"
}

cleanup_post_fixtures() {
  local path

  for path in "${fixture_post_paths[@]}"; do
    rm -f "${path}"
  done

  if [ "${fixture_posts_dir_created}" = true ]; then
    rmdir "${fixture_posts_dir}" 2>/dev/null || true
  fi
}
