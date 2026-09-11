#!/usr/bin/env python3
"""Regenerate the Xcode app project after adding/removing source files."""
from pathlib import Path
import hashlib

root = Path(__file__).resolve().parent.parent
objects = {}
def ident(value):
    return hashlib.sha1(value.encode()).hexdigest()[:24].upper()
def add(key, body):
    value = ident(key)
    objects[value] = body
    return value
def quoted(value):
    return '"' + value.replace('"', '\\"') + '"'
def array(values):
    return '(' + ', '.join(values) + ', )' if values else '()'

source_builds = []
def group(path):
    children = []
    for child in sorted(path.iterdir(), key=lambda p: (p.is_file(), p.name)):
        if child.is_dir():
            children.append(group(child))
        elif child.suffix == '.swift':
            ref = add(str(child.relative_to(root)), '{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ' + quoted(child.name) + '; sourceTree = "<group>"; }')
            source_builds.append(add('build:' + str(child.relative_to(root)), '{isa = PBXBuildFile; fileRef = ' + ref + '; }'))
            children.append(ref)
    return add('group:' + str(path.relative_to(root)), '{isa = PBXGroup; children = ' + array(children) + '; path = ' + quoted(path.name) + '; sourceTree = "<group>"; }')

sources = group(root / 'ShimKit')
product = add('product', '{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = ShimKit.app; sourceTree = BUILT_PRODUCTS_DIR; }')
products = add('products', '{isa = PBXGroup; children = ' + array([product]) + '; name = Products; sourceTree = "<group>"; }')
info = add('info', '{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Resources/Info.plist; sourceTree = "<group>"; }')
license_ref = add('sparkle-license', '{isa = PBXFileReference; lastKnownFileType = text; path = Resources/Sparkle-LICENSE.txt; sourceTree = "<group>"; }')
license_build = add('sparkle-license-build', '{isa = PBXBuildFile; fileRef = ' + license_ref + '; }')
icon_ref = add('app-icon', '{isa = PBXFileReference; lastKnownFileType = image.icns; path = Resources/AppIcon.icns; sourceTree = "<group>"; }')
icon_build = add('app-icon-build', '{isa = PBXBuildFile; fileRef = ' + icon_ref + '; }')
resources = add('resources', '{isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ' + array([license_build, icon_build]) + '; runOnlyForDeploymentPostprocessing = 0; }')
main = add('main', '{isa = PBXGroup; children = ' + array([sources, info, license_ref, icon_ref, products]) + '; sourceTree = "<group>"; }')
phase = add('sources', '{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ' + array(source_builds) + '; runOnlyForDeploymentPostprocessing = 0; }')
sparkle_package = add('sparkle-package', '{isa = XCRemoteSwiftPackageReference; repositoryURL = "https://github.com/sparkle-project/Sparkle"; requirement = {kind = exactVersion; version = 2.9.6; }; }')
sparkle_product = add('sparkle-product', '{isa = XCSwiftPackageProductDependency; package = ' + sparkle_package + '; productName = Sparkle; }')
sparkle_link = add('sparkle-link', '{isa = PBXBuildFile; productRef = ' + sparkle_product + '; }')
frameworks = add('frameworks', '{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = ' + array([sparkle_link]) + '; runOnlyForDeploymentPostprocessing = 0; }')
configs = []
project_configs = []
for name in ['Debug', 'Release']:
    settings = {
        'PRODUCT_NAME': 'ShimKit', 'PRODUCT_BUNDLE_IDENTIFIER': 'com.shimkit.app',
        'INFOPLIST_FILE': 'Resources/Info.plist', 'SWIFT_VERSION': '5.0',
        'MACOSX_DEPLOYMENT_TARGET': '14.0', 'SDKROOT': 'macosx',
        'CODE_SIGN_STYLE': 'Manual', 'CODE_SIGN_IDENTITY': 'Apple Development' if name == 'Debug' else 'Developer ID Application',
        'DEVELOPMENT_TEAM': 'WZJ4ZPRH72',
        'ENABLE_APP_SANDBOX': 'NO', 'ENABLE_HARDENED_RUNTIME': 'YES',
        'COMBINE_HIDPI_IMAGES': 'YES', 'SWIFT_EMIT_LOC_STRINGS': 'NO',
        'LD_RUNPATH_SEARCH_PATHS': '$(inherited) @executable_path/../Frameworks',
        'SWIFT_OPTIMIZATION_LEVEL': '-Onone' if name == 'Debug' else '-O',
        'SWIFT_COMPILATION_MODE': 'singlefile' if name == 'Debug' else 'wholemodule',
        'DEBUG_INFORMATION_FORMAT': 'dwarf' if name == 'Debug' else 'dwarf-with-dsym',
        'ENABLE_TESTABILITY': 'YES' if name == 'Debug' else 'NO',
    }
    body = ' '.join(k + ' = ' + quoted(v) + ';' for k, v in settings.items())
    configs.append(add('config:' + name, '{isa = XCBuildConfiguration; buildSettings = {' + body + '}; name = ' + name + '; }'))
    project_configs.append(add('projectconfig:' + name, '{isa = XCBuildConfiguration; buildSettings = {CLANG_ENABLE_MODULES = YES; }; name = ' + name + '; }'))
config_list = add('configs', '{isa = XCConfigurationList; buildConfigurations = ' + array(configs) + '; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }')
project_list = add('projectconfigs', '{isa = XCConfigurationList; buildConfigurations = ' + array(project_configs) + '; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }')
target = add('target', '{isa = PBXNativeTarget; buildConfigurationList = ' + config_list + '; buildPhases = ' + array([phase, frameworks, resources]) + '; buildRules = (); dependencies = (); packageProductDependencies = ' + array([sparkle_product]) + '; name = ShimKit; productName = ShimKit; productReference = ' + product + '; productType = "com.apple.product-type.application"; }')
project = add('project', '{isa = PBXProject; attributes = {LastUpgradeCheck = 1600; }; buildConfigurationList = ' + project_list + '; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = ' + main + '; packageReferences = ' + array([sparkle_package]) + '; productRefGroup = ' + products + '; projectDirPath = ""; projectRoot = ""; targets = ' + array([target]) + '; }')
destination = root / 'ShimKit.xcodeproj'
destination.mkdir(exist_ok=True)
(destination / 'project.pbxproj').write_text('// !$*UTF8*$!\n{archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n' + '\n'.join(key + ' = ' + body + ';' for key, body in objects.items()) + '\n}; rootObject = ' + project + '; }\n')
schemes = destination / 'xcshareddata/xcschemes'
schemes.mkdir(parents=True, exist_ok=True)
reference = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="ShimKit.app" BlueprintName="ShimKit" ReferencedContainer="container:ShimKit.xcodeproj"/>'
(schemes / 'ShimKit.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" shouldUseLaunchSchemeArgsEnv="YES"/>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/>
<ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''')
print('Generated ShimKit.xcodeproj')
