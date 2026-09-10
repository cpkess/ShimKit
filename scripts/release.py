#!/usr/bin/env python3
"""Build, sign, optionally notarize, and publish a GitHub-hosted Sparkle update.

Signing keys stay in the local login Keychain. This script never exports them.
"""
import argparse
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
REPO = "cpkess/ShimKit"
FEED_URL = f"https://github.com/{REPO}/releases/latest/download/appcast.xml"
PUBLIC_KEY = "+Z5b/VcaTvcVw/ySdyZ+bkiwcST/ddLbRhwXAtEgy38="
SIGNING_ACCOUNT = "com.shimkit.app"
SPARKLE_NAMESPACE = "http://www.andymatuschak.org/xml-namespaces/sparkle"


def run(*args, **kwargs):
    return subprocess.run([str(arg) for arg in args], cwd=ROOT, check=True, **kwargs)


def validate_metadata(info, expected_tag=None):
    version = info.get("CFBundleShortVersionString", "")
    build = info.get("CFBundleVersion", "")
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise ValueError("Release version must have the form major.minor.patch")
    if not isinstance(build, str) or not build.isdigit() or int(build) < 1:
        raise ValueError("CFBundleVersion must be a positive, increasing integer")
    if expected_tag and expected_tag != f"v{version}":
        raise ValueError("Release tag must match CFBundleShortVersionString")
    if info.get("CFBundleIdentifier") != "com.shimkit.app":
        raise ValueError("Unexpected bundle identifier")
    if info.get("SUFeedURL") != FEED_URL or info.get("SUPublicEDKey") != PUBLIC_KEY:
        raise ValueError("Update feed or signing key does not match ShimKit")
    if not info.get("SURequireSignedFeed") or not info.get("SUVerifyUpdateBeforeExtraction"):
        raise ValueError("Signed feeds and verification before extraction must remain enabled")
    return version, int(build)


def validate_appcast(path, version, build, archive):
    # This checks metadata only; Sparkle's sign_update --verify validates the signature.
    root = ET.parse(path).getroot()
    items = root.findall("./channel/item")
    if len(items) != 1:
        raise ValueError("A release appcast must contain exactly one current release")
    item = items[0]
    if item.findtext(f"{{{SPARKLE_NAMESPACE}}}version") != str(build):
        raise ValueError("Appcast build number does not match the app")
    if item.findtext(f"{{{SPARKLE_NAMESPACE}}}shortVersionString") != version:
        raise ValueError("Appcast display version does not match the app")
    enclosure = item.find("enclosure")
    expected = f"https://github.com/{REPO}/releases/download/v{version}/{archive.name}"
    if enclosure is None or enclosure.get("url") != expected:
        raise ValueError("Appcast must reference the immutable versioned GitHub asset")
    if enclosure.get("length") != str(archive.stat().st_size):
        raise ValueError("Appcast size does not match the archive")
    if not enclosure.get(f"{{{SPARKLE_NAMESPACE}}}edSignature"):
        raise ValueError("Update archive signature is missing")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--publish", action="store_true", help="Publish to GitHub after validation; otherwise prepare locally")
    parser.add_argument("--notary-profile", default=os.getenv("SHIMKIT_NOTARY_PROFILE"), help="Existing notarytool Keychain profile")
    parser.add_argument("--allow-unnotarized", action="store_true", help="Explicitly allow publishing a development release without notarization")
    parser.add_argument("--derived-data", type=Path, default=Path(tempfile.gettempdir()) / "ShimKitDerivedData")
    parser.add_argument("--sparkle-tools", type=Path, help="Sparkle bin directory; by default use the resolved package artifacts")
    args = parser.parse_args()
    if args.publish and not args.notary_profile and not args.allow_unnotarized:
        parser.error("Publishing requires --notary-profile or explicit --allow-unnotarized for a development release")
    if args.publish:
        if run("git", "status", "--porcelain", capture_output=True, text=True).stdout.strip():
            parser.error("Commit all source changes before publishing")
        remote = run("git", "remote", "get-url", "origin", capture_output=True, text=True).stdout.strip()
        if remote not in (f"https://github.com/{REPO}.git", f"git@github.com:{REPO}.git"):
            parser.error("origin must point to cpkess/ShimKit")
        run("git", "fetch", "origin", "main")
        head = run("git", "rev-parse", "HEAD", capture_output=True, text=True).stdout.strip()
        remote_head = run("git", "rev-parse", "origin/main", capture_output=True, text=True).stdout.strip()
        if head != remote_head:
            parser.error("Push this commit to origin/main before publishing")
    else:
        head = None

    run("swift", "test")
    run("python3", "-m", "unittest", "discover", "-s", "Tests/ReleaseTests", "-v")
    # Xcode archive/export re-signs Sparkle's nested tools for our Developer ID team.
    archive_path = args.derived_data / "ShimKit.xcarchive"
    export_path = args.derived_data / "Export"
    run("xcodebuild", "-project", "ShimKit.xcodeproj", "-scheme", "ShimKit", "-configuration", "Release",
        "-derivedDataPath", args.derived_data, "-archivePath", archive_path, "archive")
    run("xcodebuild", "-exportArchive", "-archivePath", archive_path,
        "-exportPath", export_path, "-exportOptionsPlist", ROOT / "Resources/ExportOptions.plist")
    app = export_path / "ShimKit.app"
    run("codesign", "--verify", "--deep", "--strict", app)
    with (app / "Contents/Info.plist").open("rb") as file:
        info = plistlib.load(file)
    version, build = validate_metadata(info)
    tools = args.sparkle_tools or args.derived_data / "SourcePackages/artifacts/sparkle/Sparkle/bin"
    if not (tools / "generate_appcast").is_file():
        parser.error("Sparkle tools were not found; pass --sparkle-tools")
    # Confirm the Keychain contains the corresponding private key, without exporting it.
    key = run(tools / "generate_keys", "--account", SIGNING_ACCOUNT, "-p", capture_output=True, text=True).stdout.strip()
    if key != PUBLIC_KEY:
        parser.error("The local Sparkle signing key does not match this app")

    if args.publish:
        latest = subprocess.run(["gh", "api", f"repos/{REPO}/releases/latest"], capture_output=True, text=True)
        if latest.returncode == 0:
            latest_tag = json.loads(latest.stdout)["tag_name"]
            with tempfile.TemporaryDirectory(prefix="shimkit-previous-feed-") as folder:
                run("gh", "release", "download", latest_tag, "--repo", REPO, "--pattern", "appcast.xml", "--dir", folder)
                previous = ET.parse(Path(folder) / "appcast.xml").getroot()
                numbers = [int(node.text) for node in previous.findall(f"./channel/item/{{{SPARKLE_NAMESPACE}}}version")]
                if not numbers or build <= max(numbers):
                    parser.error("Increase CFBundleVersion above the latest published build")
        elif "HTTP 404" not in latest.stderr:
            raise RuntimeError("Cannot inspect the latest GitHub release: " + latest.stderr)

    with tempfile.TemporaryDirectory(prefix="shimkit-release-") as folder:
        stage = Path(folder)
        zip_path = stage / f"ShimKit-{version}.zip"
        run("ditto", "-c", "-k", "--keepParent", "--norsrc", "--noextattr", app, zip_path)
        if args.notary_profile:
            run("xcrun", "notarytool", "submit", zip_path, "--keychain-profile", args.notary_profile, "--wait")
            run("xcrun", "stapler", "staple", app)
            run("xcrun", "stapler", "validate", app)
            run("spctl", "--assess", "--type", "execute", app)
            run("ditto", "-c", "-k", "--keepParent", "--norsrc", "--noextattr", app, zip_path)
        run(tools / "generate_appcast", "--account", SIGNING_ACCOUNT,
            "--download-url-prefix", f"https://github.com/{REPO}/releases/download/v{version}/",
            "--maximum-deltas", "0", "--maximum-versions", "1", "--link", f"https://github.com/{REPO}", stage)
        feed = stage / "appcast.xml"
        validate_appcast(feed, version, build, zip_path)
        run(tools / "sign_update", "--account", SIGNING_ACCOUNT, "--verify", feed)
        enclosure = ET.parse(feed).find("./channel/item/enclosure")
        signature = enclosure.get(f"{{{SPARKLE_NAMESPACE}}}edSignature")
        run(tools / "sign_update", "--account", SIGNING_ACCOUNT, "--verify", zip_path, signature)
        destination = ROOT / "dist" / f"release-{version}"
        destination.mkdir(parents=True, exist_ok=True)
        run("ditto", zip_path, destination / zip_path.name)
        run("ditto", feed, destination / feed.name)
        notes = destination / "release-notes.md"
        notes.write_text(f"ShimKit {version} (build {build})\n\n"
            "Install ShimKit.app in /Applications. Versions before 0.2.0 require a one-time manual update. "
            "Future releases are checked and verified by Sparkle through GitHub Releases.\n\n"
            + ("Developer ID signed and notarized.\n" if args.notary_profile else
               "Development release: Developer ID signed, but not notarized. macOS may require explicit approval on first launch.\n"))
        if args.publish:
            # Upload both assets to a draft before making the feed visible via /latest/download/.
            run("gh", "release", "create", f"v{version}", str(destination / zip_path.name), str(destination / feed.name),
                "--repo", REPO, "--target", head, "--title", f"ShimKit {version}", "--notes-file", notes, "--draft")
            run("gh", "release", "edit", f"v{version}", "--repo", REPO, "--draft=false", "--latest")
        print(f"Prepared release: {destination}")


if __name__ == "__main__":
    main()
