#!/usr/bin/env python3
"""Generate a dependency-free Xcode project deterministically (no xcodegen needed)."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
def uid(key): return hashlib.sha1(key.encode()).hexdigest()[:24].upper()
def quoted(value): return json.dumps(str(value), ensure_ascii=False)
objects = {}
def obj(key, value): objects[uid(key)] = value; return uid(key)
def array(values): return '(' + ', '.join(values) + ')'

app_sources = sorted([*ROOT.glob('App/**/*.swift'), *ROOT.glob('Sources/MetroCore/*.swift')])
test_sources = sorted(ROOT.glob('UITests/*.swift'))
refs, app_build, test_build, resource_build = [], [], [], []
for path in app_sources + test_sources:
    name = str(path.relative_to(ROOT))
    ref = obj('ref:'+name, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {quoted(name)}; sourceTree = SOURCE_ROOT;')
    build = obj('build:'+name, f'isa = PBXBuildFile; fileRef = {ref};')
    refs.append(ref)
    (test_build if path in test_sources else app_build).append(build)
for name, kind in [('App/Resources/CityPack','folder'), ('App/Resources/Web','folder'), ('App/PrivacyInfo.xcprivacy','text.xml')]:
    ref = obj('ref:'+name, f'isa = PBXFileReference; lastKnownFileType = {kind}; path = {quoted(name)}; sourceTree = SOURCE_ROOT;')
    refs.append(ref)
    resource_build.append(obj('build:'+name, f'isa = PBXBuildFile; fileRef = {ref};'))
product = obj('product', 'isa = PBXFileReference; explicitFileType = wrapper.application; path = Underground.app; sourceTree = BUILT_PRODUCTS_DIR;')
test_product = obj('test-product', 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = UndergroundUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
products = obj('products', f'isa = PBXGroup; children = {array([product,test_product])}; name = Products; sourceTree = "<group>";')
main_group = obj('main', f'isa = PBXGroup; children = {array(refs+[products])}; sourceTree = "<group>";')

def phase(key, kind, files):
    return obj(key, f'isa = {kind}; buildActionMask = 2147483647; files = {array(files)}; runOnlyForDeploymentPostprocessing = 0;')
app_phases = [phase('sources','PBXSourcesBuildPhase',app_build),phase('frameworks','PBXFrameworksBuildPhase',[]),phase('resources','PBXResourcesBuildPhase',resource_build)]
test_phases = [phase('test-sources','PBXSourcesBuildPhase',test_build),phase('test-frameworks','PBXFrameworksBuildPhase',[]),phase('test-resources','PBXResourcesBuildPhase',[])]

def configs(key, settings):
    values=[]
    for name in ['Debug','Release']:
        current=dict(settings)
        current.update({'SWIFT_OPTIMIZATION_LEVEL':'-Onone' if name=='Debug' else '-O', 'DEBUG_INFORMATION_FORMAT':'dwarf' if name=='Debug' else 'dwarf-with-dsym'})
        if name=='Debug': current['SWIFT_ACTIVE_COMPILATION_CONDITIONS']='DEBUG'
        content=' '.join(f'{k} = {quoted(v)};' for k,v in current.items())
        values.append(obj(key+name, f'isa = XCBuildConfiguration; buildSettings = {{{content}}}; name = {name};'))
    return obj(key+'config-list',f'isa = XCConfigurationList; buildConfigurations = {array(values)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
project_config = configs('project',{'SDKROOT':'iphoneos','IPHONEOS_DEPLOYMENT_TARGET':'17.0','SWIFT_VERSION':'5.0','CLANG_ENABLE_MODULES':'YES','CLANG_ENABLE_OBJC_ARC':'YES','ENABLE_USER_SCRIPT_SANDBOXING':'YES'})
app_config = configs('app',{'PRODUCT_BUNDLE_IDENTIFIER':'local.phy.Underground','PRODUCT_NAME':'$(TARGET_NAME)','INFOPLIST_FILE':'App/Info.plist','TARGETED_DEVICE_FAMILY':'1','CODE_SIGN_STYLE':'Automatic','SUPPORTED_PLATFORMS':'iphoneos iphonesimulator','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks','SWIFT_EMIT_LOC_STRINGS':'YES'})
test_config = configs('test',{'PRODUCT_BUNDLE_IDENTIFIER':'local.phy.UndergroundUITests','PRODUCT_NAME':'$(TARGET_NAME)','GENERATE_INFOPLIST_FILE':'YES','TARGETED_DEVICE_FAMILY':'1','CODE_SIGN_STYLE':'Automatic','SUPPORTED_PLATFORMS':'iphoneos iphonesimulator','TEST_TARGET_NAME':'Underground','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks @loader_path/Frameworks'})
app_target = obj('app-target',f'isa = PBXNativeTarget; buildConfigurationList = {app_config}; buildPhases = {array(app_phases)}; buildRules = (); dependencies = (); name = Underground; productName = Underground; productReference = {product}; productType = "com.apple.product-type.application";')
proxy = obj('proxy',f'isa = PBXContainerItemProxy; containerPortal = {uid("project")}; proxyType = 1; remoteGlobalIDString = {app_target}; remoteInfo = Underground;')
dependency = obj('dependency',f'isa = PBXTargetDependency; target = {app_target}; targetProxy = {proxy};')
test_target = obj('test-target',f'isa = PBXNativeTarget; buildConfigurationList = {test_config}; buildPhases = {array(test_phases)}; buildRules = (); dependencies = ({dependency}); name = UndergroundUITests; productName = UndergroundUITests; productReference = {test_product}; productType = "com.apple.product-type.bundle.ui-testing";')
project = obj('project',f'isa = PBXProject; attributes = {{LastUpgradeCheck = 1600; TargetAttributes = {{{app_target} = {{CreatedOnToolsVersion = 16.0;}}; {test_target} = {{CreatedOnToolsVersion = 16.0; TestTargetID = {app_target};}};}};}}; buildConfigurationList = {project_config}; compatibilityVersion = "Xcode 14.0"; developmentRegion = zh-Hans; hasScannedForEncodings = 0; knownRegions = (en, Base, "zh-Hans"); mainGroup = {main_group}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = ({app_target}, {test_target});')
folder=ROOT/'Underground.xcodeproj'
folder.mkdir(exist_ok=True)
(folder/'project.pbxproj').write_text('// !$*UTF8*$!\n{archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+''.join(f'{key} = {{{value}}};\n' for key,value in objects.items())+f'}}; rootObject = {project};}}\n')
ref=lambda identifier,name,build: f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{identifier}" BuildableName="{build}" BlueprintName="{name}" ReferencedContainer="container:Underground.xcodeproj"/>'
app_ref=ref(app_target,'Underground','Underground.app')
test_ref=ref(test_target,'UndergroundUITests','UndergroundUITests.xctest')
scheme=f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{app_ref}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO" parallelizable="NO">{test_ref}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>'''
scheme_path=folder/'xcshareddata/xcschemes/Underground.xcscheme'
scheme_path.parent.mkdir(parents=True,exist_ok=True)
scheme_path.write_text(scheme)
print('Generated Underground.xcodeproj')
