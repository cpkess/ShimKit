import importlib.util
from pathlib import Path
import plistlib
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("release", ROOT / "scripts/release.py")
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        with (ROOT / "Resources/Info.plist").open("rb") as file:
            self.info = plistlib.load(file)
        self.info["CFBundleIdentifier"] = "com.shimkit.app"

    def test_requires_expected_developer_id_timestamp_and_runtime(self):
        valid = "Authority=Developer ID Application: Gamergrams LLC (WZJ4ZPRH72)\nTeamIdentifier=WZJ4ZPRH72\nTimestamp=Sep 10, 2026\nflags=0x10000(runtime)"
        release.validate_signature(valid)
        for value in ["Authority=Developer ID Application: Gamergrams LLC (WZJ4ZPRH72)",
                      "TeamIdentifier=WZJ4ZPRH72", "Timestamp=", "(runtime)"]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                release.validate_signature(valid.replace(value, ""))

    def test_notarization_must_be_explicitly_accepted(self):
        release.validate_notarization({"id": "submission", "status": "Accepted"})
        for status in ["Invalid", "Rejected", "In Progress", None]:
            with self.subTest(status=status), self.assertRaises(ValueError):
                release.validate_notarization({"id": "submission", "status": status})

    def test_dmg_requires_app_correct_version_and_applications_shortcut(self):
        with tempfile.TemporaryDirectory() as directory:
            mount = Path(directory)
            contents = mount / "ShimKit.app/Contents"
            contents.mkdir(parents=True)
            with (contents / "Info.plist").open("wb") as file:
                plistlib.dump(self.info, file)
            version, build = release.validate_metadata(self.info)
            with self.assertRaises(ValueError):
                release.validate_dmg_contents(mount, version, build)
            (mount / "Applications").symlink_to("/tmp")
            with self.assertRaises(ValueError):
                release.validate_dmg_contents(mount, version, build)
            (mount / "Applications").unlink()
            (mount / "Applications").symlink_to("/Applications")
            self.assertEqual(release.validate_dmg_contents(mount, version, build), mount / "ShimKit.app")
            with self.assertRaises(ValueError):
                release.validate_dmg_contents(mount, version, build + 1)

    def test_release_metadata_and_matching_tag(self):
        version, build = release.validate_metadata(self.info)
        self.assertGreater(build, 2)
        self.assertEqual(release.validate_metadata(self.info, "v" + version), (version, build))

    def test_rejects_changed_feed_key_and_missing_security_checks(self):
        for key, value in [("SUFeedURL", "https://example.com/feed.xml"), ("SUPublicEDKey", "different"),
                           ("SURequireSignedFeed", False), ("SUVerifyUpdateBeforeExtraction", False)]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                release.validate_metadata({**self.info, key: value})

    def test_rejects_invalid_versions_and_mismatched_tags(self):
        for key, value in [("CFBundleVersion", "0"), ("CFBundleVersion", "abc"),
                           ("CFBundleShortVersionString", "v1.0.0")]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                release.validate_metadata({**self.info, key: value})
        with self.assertRaises(ValueError):
            release.validate_metadata(self.info, "v99.0.0")

    def test_appcast_rejects_mutable_download_url_and_wrong_archive_size(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / "ShimKit-0.2.0.zip"
            archive.write_bytes(b"fixture")
            feed = Path(directory) / "appcast.xml"
            xml = '''<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel><item>
                <sparkle:version>3</sparkle:version><sparkle:shortVersionString>0.2.0</sparkle:shortVersionString>
                <enclosure url="https://github.com/cpkess/ShimKit/releases/download/v0.2.0/ShimKit-0.2.0.zip"
                length="7" sparkle:edSignature="fixture-signature"/></item></channel></rss>'''
            feed.write_text(xml)
            release.validate_appcast(feed, "0.2.0", 3, archive)
            feed.write_text(xml.replace("download/v0.2.0", "latest/download"))
            with self.assertRaises(ValueError):
                release.validate_appcast(feed, "0.2.0", 3, archive)
            feed.write_text(xml.replace('length="7"', 'length="8"'))
            with self.assertRaises(ValueError):
                release.validate_appcast(feed, "0.2.0", 3, archive)
