from pathlib import Path
import plistlib

root = Path(__file__).resolve().parents[1]
project = root / 'MoodLog.xcodeproj'
project.mkdir(exist_ok=True)
objects = []
counter = 0
def add(body):
    global counter
    counter += 1
    key = f'{counter:024X}'
    objects.append((key, body))
    return key
def config_list(settings):
    refs = []
    for name in ['Debug', 'Release']:
        extra = ' SWIFT_OPTIMIZATION_LEVEL = "-Onone"; SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;' if name == 'Debug' else ' SWIFT_OPTIMIZATION_LEVEL = "-O";'
        refs.append(add(f'isa = XCBuildConfiguration; name = {name}; buildSettings = {{ {settings} {extra} }};'))
    return add('isa = XCConfigurationList; buildConfigurations = (' + ','.join(refs) + '); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
def source_phase(paths):
    refs, builds = [], []
    for path in paths:
        ref = add(f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{path}"; sourceTree = "<group>";')
        refs.append(ref)
        builds.append(add(f'isa = PBXBuildFile; fileRef = {ref};'))
    phase = add('isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (' + ','.join(builds) + '); runOnlyForDeploymentPostprocessing = 0;')
    return refs, phase

common = 'CLANG_ENABLE_MODULES = YES; SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 17.0; SWIFT_VERSION = 5.0; TARGETED_DEVICE_FAMILY = 1; CODE_SIGN_STYLE = Automatic; DEVELOPMENT_TEAM = KD4SRHRFF6; SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"; SUPPORTS_MACCATALYST = NO; ENABLE_USER_SCRIPT_SANDBOXING = YES;'
global_config = config_list(common)
app_config = config_list('PRODUCT_NAME = "$(TARGET_NAME)"; PRODUCT_BUNDLE_IDENTIFIER = jp.abyos.MoodLog; INFOPLIST_FILE = App/Info.plist; CURRENT_PROJECT_VERSION = 19; MARKETING_VERSION = 0.1.18; ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;')
ui_config = config_list('PRODUCT_NAME = "$(TARGET_NAME)"; PRODUCT_BUNDLE_IDENTIFIER = jp.abyos.MoodLogUITests; GENERATE_INFOPLIST_FILE = YES; TEST_TARGET_NAME = MoodLog;')
app_refs, app_sources = source_phase([str(p.relative_to(root)) for p in sorted((root / 'App').glob('*.swift'))])
ui_refs, ui_sources = source_phase(['Tests/MoodLogUITests.swift'])
frameworks = add('isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
asset_ref = add('isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = App/Assets.xcassets; sourceTree = "<group>";')
asset_build = add(f'isa = PBXBuildFile; fileRef = {asset_ref};')
privacy_ref = add('isa = PBXFileReference; lastKnownFileType = text.xml; path = App/PrivacyInfo.xcprivacy; sourceTree = "<group>";')
privacy_build = add(f'isa = PBXBuildFile; fileRef = {privacy_ref};')
resources = add(f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({asset_build},{privacy_build}); runOnlyForDeploymentPostprocessing = 0;')
app_product = add('isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = MoodLog.app; sourceTree = BUILT_PRODUCTS_DIR;')
ui_product = add('isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = MoodLogUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
app_target = add(f'isa = PBXNativeTarget; buildConfigurationList = {app_config}; buildPhases = ({app_sources},{frameworks},{resources}); buildRules = (); dependencies = (); name = MoodLog; productName = MoodLog; productReference = {app_product}; productType = "com.apple.product-type.application";')
dependency = add(f'isa = PBXTargetDependency; target = {app_target};')
ui_target = add(f'isa = PBXNativeTarget; buildConfigurationList = {ui_config}; buildPhases = ({ui_sources},{frameworks}); buildRules = (); dependencies = ({dependency}); name = MoodLogUITests; productName = MoodLogUITests; productReference = {ui_product}; productType = "com.apple.product-type.bundle.ui-testing";')
products = add(f'isa = PBXGroup; children = ({app_product},{ui_product}); name = Products; sourceTree = "<group>";')
group = add('isa = PBXGroup; children = (' + ','.join(app_refs + ui_refs + [asset_ref, privacy_ref, products]) + '); sourceTree = "<group>";')
proj = add(f'isa = PBXProject; attributes = {{LastUpgradeCheck = 2600; }}; buildConfigurationList = {global_config}; compatibilityVersion = "Xcode 14.0"; developmentRegion = ja; knownRegions = (ja,en,Base); mainGroup = {group}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = ({app_target},{ui_target});')
(project / 'project.pbxproj').write_text('// !$*UTF8*$!\n{archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n' + '\n'.join(f'{key} = {{{body}}};' for key, body in objects) + f'\n}}; rootObject = {proj}; }}\n')
scheme_dir = project / 'xcshareddata/xcschemes'
scheme_dir.mkdir(parents=True, exist_ok=True)
def reference(target, name, product):
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="{product}" BlueprintName="{name}" ReferencedContainer="container:MoodLog.xcodeproj"/>'
app_ref = reference(app_target, 'MoodLog', 'MoodLog.app')
ui_ref = reference(ui_target, 'MoodLogUITests', 'MoodLogUITests.xctest')
(scheme_dir / 'MoodLog.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{app_ref}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB"><Testables><TestableReference skipped="NO">{ui_ref}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
info = {'CFBundleDisplayName': '気分ログ', 'CFBundleIdentifier': '$(PRODUCT_BUNDLE_IDENTIFIER)', 'CFBundleName': '$(PRODUCT_NAME)', 'CFBundleExecutable': '$(EXECUTABLE_NAME)', 'CFBundlePackageType': 'APPL', 'CFBundleShortVersionString': '$(MARKETING_VERSION)', 'CFBundleVersion': '$(CURRENT_PROJECT_VERSION)', 'LSRequiresIPhoneOS': True, 'UILaunchScreen': {}, 'UISupportedInterfaceOrientations': ['UIInterfaceOrientationPortrait'], 'UIApplicationSceneManifest': {'UIApplicationSupportsMultipleScenes': False}, 'NSMicrophoneUsageDescription': '話した内容をメモとして文字入力するためにマイクを使います。', 'NSSpeechRecognitionUsageDescription': '話した内容を日本語の文字に変換します。端末内で処理できない場合、音声はAppleの音声認識サービスで処理されます。', 'ITSAppUsesNonExemptEncryption': False}
(root / 'App/Info.plist').write_bytes(plistlib.dumps(info))
print('Generated MoodLog.xcodeproj')
