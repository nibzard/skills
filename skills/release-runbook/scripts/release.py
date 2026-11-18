#!/usr/bin/env python3
"""Prepare a local release; publish only with --publish. Python 3.11+."""

import argparse
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import tempfile
import tomllib


def command(*args, capture=False):
    return subprocess.run(args, check=True, text=True, capture_output=capture)


def git(*args):
    return command("git", *args, capture=True).stdout.strip()


def detect(root):
    versions = [p for p in ("package.json", "pyproject.toml", "Cargo.toml", "VERSION")
                if (root / p).is_file()]
    checks, languages = [], []
    if (root / "Makefile").exists() and re.search(
            r"^test\s*:", (root / "Makefile").read_text(), re.M):
        checks.append("make test")
    if (root / "package.json").exists():
        languages.append("node")
        if json.loads((root / "package.json").read_text()).get("scripts", {}).get("test"):
            checks.append("npm test")
    if (root / "pyproject.toml").exists() or (root / "setup.py").exists():
        languages.append("python")
        config = (root / "pyproject.toml").read_text() if (root / "pyproject.toml").exists() else ""
        if "pytest" in config or (root / "pytest.ini").exists():
            checks.append("python3 -m pytest")
        elif (root / "tests").is_dir():
            checks.append("python3 -m unittest discover -s tests")
    for manifest, language, check in (
        ("go.mod", "go", "go test ./..."), ("Cargo.toml", "rust", "cargo test"),
        ("pom.xml", "java", "mvn test"), ("build.gradle", "java", "gradle test"),
        ("build.gradle.kts", "java", "gradle test"), ("Rakefile", "ruby", "rake test"),
        ("phpunit.xml", "php", "phpunit"),
    ):
        if (root / manifest).exists():
            languages.append(language)
            checks.append(check)
    if list(root.glob("*.csproj")) or list(root.glob("*.fsproj")):
        languages.append("dotnet")
        checks.append("dotnet test")
    return {"version_files": versions, "languages": list(dict.fromkeys(languages)),
            "test_commands": list(dict.fromkeys(checks))}


def toml_version(text, filename):
    data = tomllib.loads(text)
    candidates = (("package", data.get("package", {})),
                  ("workspace.package", data.get("workspace", {}).get("package", {}))) if filename == "Cargo.toml" else (
                      ("project", data.get("project", {})),
                      ("tool.poetry", data.get("tool", {}).get("poetry", {})))
    for section, mapping in candidates:
        if "version" in mapping:
            if isinstance(mapping["version"], str):
                return section, mapping["version"]
            raise ValueError("Inherited versions need the workspace's own release workflow")
    raise ValueError(f"No static package version in {filename}; use the project's version tool")


def current_version(path):
    text = path.read_text()
    if path.name in ("package.json", "package-lock.json"):
        return json.loads(text)["version"]
    if path.name in ("Cargo.toml", "pyproject.toml"):
        return toml_version(text, path.name)[1]
    if path.name == "VERSION":
        return text.strip()
    raise ValueError(f"Unsupported version file: {path}; use the ecosystem's tool")


def replace_version(path, version):
    text = path.read_text()
    current_version(path)
    if path.name in ("package.json", "package-lock.json"):
        data = json.loads(text)
        data["version"] = version
        if path.name == "package-lock.json" and "" in data.get("packages", {}):
            data["packages"][""]["version"] = version
        return json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    if path.name == "VERSION":
        return version + "\n"
    section, _ = toml_version(text, path.name)
    lines = text.splitlines(keepends=True)
    active = replaced = False
    for index, line in enumerate(lines):
        header = re.match(r"^\s*\[([^\]]+)\]\s*(?:#.*)?$", line)
        if header:
            active = header[1].strip() == section
        if active and re.match(r"^\s*version\s*=", line):
            lines[index], count = re.subn(
                r"^(\s*version\s*=\s*)([\"'])(.*?)(\2)",
                lambda m: f'{m[1]}{m[2]}{version}{m[2]}', line, count=1)
            replaced = bool(count)
            break
    result = "".join(lines)
    if not replaced or toml_version(result, path.name)[1] != version:
        raise ValueError(f"Cannot safely update {path}")
    return result


def atomic_write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    mode = path.stat().st_mode & 0o777 if path.exists() else 0o644
    fd, temporary = tempfile.mkstemp(dir=path.parent, prefix=".release-")
    try:
        with os.fdopen(fd, "w") as handle:
            handle.write(text)
        os.chmod(temporary, mode)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--detect", type=Path, help="Print shell-quoted detection results and exit")
    parser.add_argument("--version")
    bumps = parser.add_mutually_exclusive_group()
    for bump in ("major", "minor", "patch"):
        bumps.add_argument("--" + bump, action="store_true")
    parser.add_argument("--pre-release", metavar="LABEL")
    for option in ("version-file", "test-command", "build-command", "asset"):
        parser.add_argument("--" + option, action="append", default=[])
    for option in ("skip-tests", "dry-run", "publish", "draft"):
        parser.add_argument("--" + option, action="store_true")
    parser.add_argument("--notes", type=Path)
    parser.add_argument("--title")
    parser.add_argument("--message", help="Release commit subject; follow the target repository's rules")
    return parser.parse_args()


SEMVER = r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?"


def main():
    args = parse_args()
    root = Path.cwd().resolve()
    if args.detect:
        root = args.detect.resolve()
        data = detect(root)
        values = {"PROJECT_TYPE": data["languages"][0] if len(data["languages"]) == 1 else "multi" if data["languages"] else "unknown",
                  "LANGUAGES": ",".join(data["languages"]), "VERSION_FILES": ",".join(data["version_files"]),
                  "TEST_COMMANDS": ",".join(data["test_commands"]), "CURRENT_VERSION": "",
                  "BUILD_SYSTEMS": "", "BUILD_COMMANDS": "", "PACKAGE_MANAGERS": ""}
        if data["version_files"]:
            try:
                values["CURRENT_VERSION"] = current_version(root / data["version_files"][0])
            except (ValueError, KeyError):
                pass
        for key, value in values.items():
            print(f"{key}={shlex.quote(value)}")
        return
    if Path(git("rev-parse", "--show-toplevel")).resolve() != root:
        raise ValueError("Run the helper from the target repository root")
    detected = detect(root)
    files = args.version_file or detected["version_files"]
    if not files:
        raise ValueError("No supported version files; use the project's release workflow")
    paths = [root / name for name in dict.fromkeys(files)]
    for path in paths:
        if path.is_symlink() or path.resolve().parent != root:
            raise ValueError("Version files must be regular files in the repository root")
    currents = {current_version(path) for path in paths}
    if not args.version and len(currents) != 1:
        raise ValueError("Version files disagree; specify --version after review")
    current = current_version(paths[0])
    match = re.fullmatch(SEMVER, current)
    if not args.version and not match:
        raise ValueError("Current version is not a supported semantic version")
    if args.version:
        version = args.version
    else:
        major, minor, patch = map(int, match.groups())
        if args.major:
            major, minor, patch = major + 1, 0, 0
        elif args.minor:
            minor, patch = minor + 1, 0
        else:
            patch += 1
        version = f"{major}.{minor}.{patch}"
    if args.pre_release:
        version += "-" + args.pre_release
    if not re.fullmatch(SEMVER, version):
        raise ValueError("Invalid release version")
    if (root / "package-lock.json").exists() and root / "package.json" in paths:
        paths.append(root / "package-lock.json")
    for path in paths:
        if path.is_symlink() or path.resolve().parent != root:
            raise ValueError("Version files must stay in the repository root")
    if (root / "Cargo.lock").exists() and root / "Cargo.toml" in paths:
        if current_version(root / "Cargo.toml") != version:
            raise ValueError("Update Cargo.toml and Cargo.lock with the project's version tool first")
    changes = {path: replace_version(path, version) for path in paths}
    tests = args.test_command or detected["test_commands"]
    if not tests and not args.skip_tests:
        raise ValueError("No tests detected; specify --test-command or explicitly --skip-tests")
    previous = subprocess.run(["git", "describe", "--tags", "--abbrev=0"], text=True, capture_output=True)
    previous_tag = previous.stdout.strip() if previous.returncode == 0 else None
    tag = "v" + version
    if subprocess.run(["git", "rev-parse", "--verify", "refs/tags/" + tag], capture_output=True).returncode == 0:
        raise ValueError(f"Tag {tag} already exists; inspect the previous attempt before retrying")
    branch = git("branch", "--show-current")
    if args.publish and (not branch or git("status", "--porcelain")):
        raise ValueError("Publication requires an attached branch and clean tree; commit prepared changes first")
    if not args.publish:
        for path in paths:
            if git("status", "--porcelain", "--", str(path.relative_to(root))):
                raise ValueError(f"Review existing changes in {path.name} before preparation")
    log_range = f"{previous_tag}..HEAD" if previous_tag else "HEAD"
    notes = args.notes.read_text() if args.notes else (
        f"## Release {tag}\n\n" + (f"Changes since {previous_tag}\n\n" if previous_tag else "Initial release\n\n") +
        git("log", log_range, "--format=- %s (%h)", "-n", "50") + "\n")
    print(json.dumps({"version": version, "previous_tag": previous_tag,
                      "version_files": [p.name for p in paths], "tests": tests,
                      "skip_tests": args.skip_tests, "builds": args.build_command,
                      "assets": args.asset, "publish": args.publish, "dry_run": args.dry_run}, indent=2))
    if args.dry_run:
        return
    for path, text in changes.items():
        atomic_write(path, text)
    if not args.skip_tests:
        for check in tests:
            subprocess.run(check, shell=True, executable="/bin/sh", check=True)
    for build in args.build_command:
        subprocess.run(build, shell=True, executable="/bin/sh", check=True)
    for asset in args.asset:
        if not Path(asset).is_file():
            raise ValueError(f"Release asset does not exist: {asset}")
    notes_path = Path(git("rev-parse", "--git-path", "release-notes.md"))
    atomic_write(notes_path, notes)
    if not args.publish:
        print(f"Prepared {tag}. Review the diff and notes at {notes_path}. No tag or publication created.")
        return
    git("add", "--", *[str(p.relative_to(root)) for p in paths])
    if subprocess.run(["git", "diff", "--cached", "--quiet"]).returncode:
        command("git", "commit", "-m", args.message or f"Release {tag}")
    git("tag", "-a", tag, "-m", f"Release {version}")
    command("git", "push", "--atomic", "origin", branch, "refs/tags/" + tag)
    release = ["gh", "release", "create", tag, "--verify-tag", "--title", args.title or tag,
               "--notes-file", str(notes_path)]
    if args.draft:
        release.append("--draft")
    if "-" in version:
        release.append("--prerelease")
    command(*release, *args.asset)
    print(f"Published {tag}.")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, KeyError, subprocess.CalledProcessError) as error:
        print(f"Release stopped: {error}. Inspect local edits, tags, and remote state before retrying.", file=sys.stderr)
        sys.exit(1)
