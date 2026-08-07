#!/usr/bin/env python3
"""生成 Sub-Store-Module 的 CHANGELOG.md / release notes。

用法:
  gen-changelog.py                  # 完整 CHANGELOG (默认最近 4 个 tag)
  gen-changelog.py --tag v2.0.4     # 只输出该 tag 的提交区块 (release notes 用)
  gen-changelog.py --stable-only    # CHANGELOG 只保留稳定版 tag
  gen-changelog.py --tags 4         # 控制 CHANGELOG 保留的 tag 数
"""
import argparse
import subprocess
import sys


def git(*args):
    return subprocess.run(["git", *args], capture_output=True, text=True, check=True).stdout


def repo_slug():
    url = git("remote", "get-url", "origin").strip().rstrip("/")
    if url.endswith(".git"):
        url = url[:-4]
    if url.startswith("git@"):
        url = url.split(":", 1)[1]
    elif "github.com/" in url:
        url = url.split("github.com/", 1)[1]
    return url


def tag_section(tag, prev, build_type=None):
    """输出单个 tag 的区块: ## vX.Y.Z (CODE-SHA-release) + 提交列表"""
    code = git("rev-list", tag, "--count").strip()
    sha = git("rev-parse", "--short", tag).strip()
    build_type = build_type or ("prerelease" if "-" in tag else "release")
    lines = [f"## {tag} ({code}-{sha}-{build_type})"]
    rng = f"{prev}..{tag}" if prev else tag
    raw = git("log", "--format=%x1e%h%x1f%s%x1f%b", rng)
    for rec in raw.split("\x1e"):
        rec = rec.strip("\n")
        if not rec:
            continue
        parts = rec.split("\x1f")
        subject = parts[1]
        body = parts[2] if len(parts) > 2 else ""
        lines.append(f"- {subject}")
        # chore(deps): 打头的 (dependabot 等依赖更新) 不展开 body
        if subject.startswith("chore(deps):"):
            continue
        for bl in body.splitlines():
            bl = bl.strip()
            if not bl:
                continue
            if bl.startswith("- "):
                bl = bl[2:]
            elif bl.startswith("* "):
                bl = bl[2:]
            lines.append(f"  - {bl}")
    return lines


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tag", help="只输出该 tag 的提交区块")
    ap.add_argument("--build-type", help="覆盖区块标题中的构建类型 (release/prerelease)")
    ap.add_argument("--stable-only", action="store_true", help="CHANGELOG 只保留无预发布后缀的 tag")
    ap.add_argument("--tags", type=int, default=4, help="CHANGELOG 保留的 tag 数 (默认 4)")
    args = ap.parse_args()

    all_tags = git("tag", "--sort=v:refname").split()
    if not all_tags:
        sys.exit("仓库没有 tag")

    tags = [tag for tag in all_tags if "-" not in tag] if args.stable_only else all_tags

    if args.tag:
        if args.tag not in tags:
            sys.exit(f"tag 不存在: {args.tag}")
        idx = tags.index(args.tag)
        prev = tags[idx - 1] if idx > 0 else None
        print("\n".join(tag_section(args.tag, prev, args.build_type)))
        return

    window = tags[-args.tags:] if args.tags > 0 else tags
    out = ["# Changelog", ""]
    for tag in reversed(window):
        idx = tags.index(tag)
        prev = tags[idx - 1] if idx > 0 else None
        out += tag_section(tag, prev)
        out.append("")
    out += [
        "### Full Changelog",
        f"- [Commit history](https://github.com/{repo_slug()}/commits/main/)",
        "",
    ]
    print("\n".join(out))


if __name__ == "__main__":
    main()
