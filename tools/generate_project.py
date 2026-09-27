#!/usr/bin/env python3
"""Generate FrostSlide.xcodeproj, shared scheme, and arcade WAV stingers."""

from __future__ import annotations

import math
import struct
import wave
from pathlib import Path

ROOT = Path("/workspace/FrostSlide")
APP = ROOT / "FrostSlide"
PROJ = ROOT / "FrostSlide.xcodeproj"
SOUNDS = APP / "Resources" / "Sounds"

SWIFT_FILES = [
    "FrostSlideApp.swift",
    "App/AppModel.swift",
    "Core/GameModels.swift",
    "Core/GamePersistence.swift",
    "Core/AudioHaptics.swift",
    "Core/LevelCatalog.swift",
    "Engine/TrackPath.swift",
    "Engine/RacerSimulation.swift",
    "Engine/GameEngine.swift",
    "Reality/RKMaterials.swift",
    "Reality/RKMesh.swift",
    "Reality/WorldController.swift",
    "Reality/PenguinFactory.swift",
    "Reality/WorldFactory.swift",
    "Reality/EffectsFactory.swift",
    "Ads/AdConfig.swift",
    "Ads/AdManager.swift",
    "Ads/BannerAdView.swift",
    "UI/FrostTheme.swift",
    "UI/MainMenuView.swift",
    "UI/LevelSelectView.swift",
    "UI/GameContainerView.swift",
    "UI/RaceHUDView.swift",
    "UI/PauseView.swift",
    "UI/ResultsView.swift",
    "UI/SettingsView.swift",
]

RESOURCE_FILES = [
    "Assets.xcassets",
    "Info.plist",
    "PrivacyInfo.xcprivacy",
    "Resources/Sounds/collect.wav",
    "Resources/Sounds/boost.wav",
    "Resources/Sounds/crash.wav",
    "Resources/Sounds/finish.wav",
    "Resources/Sounds/tick.wav",
    "Resources/Sounds/go.wav",
    "Resources/Sounds/whoosh.wav",
    "Resources/Sounds/power.wav",
]


def hid(n: int) -> str:
    return f"A1{n:022X}"


def write_wav(path: Path, samples: list[float], rate: int = 22050) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        frames = b"".join(
            struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in samples
        )
        w.writeframes(frames)


def tone(freq: float, dur: float, vol: float = 0.5, rate: int = 22050, decay: bool = True) -> list[float]:
    n = int(rate * dur)
    out = []
    for i in range(n):
        t = i / rate
        env = (1 - i / n) if decay else 1.0
        env *= min(1.0, i / (0.01 * rate))
        out.append(math.sin(2 * math.pi * freq * t) * vol * env)
    return out


def noise(dur: float, vol: float = 0.35, rate: int = 22050) -> list[float]:
    n = int(rate * dur)
    seed = 12345
    out = []
    for i in range(n):
        seed = (1103515245 * seed + 12345) & 0x7FFFFFFF
        v = (seed / 0x7FFFFFFF) * 2 - 1
        env = 1 - i / n
        out.append(v * vol * env)
    return out


def generate_sounds() -> None:
    write_wav(SOUNDS / "collect.wav", tone(880, 0.09, 0.45) + tone(1320, 0.08, 0.35))
    write_wav(SOUNDS / "boost.wav", tone(220, 0.18, 0.3) + tone(330, 0.16, 0.28) + tone(440, 0.12, 0.22))
    write_wav(SOUNDS / "crash.wav", noise(0.22, 0.4))
    finish = []
    for f in (523, 659, 784, 1046):
        finish += tone(f, 0.12, 0.38)
    write_wav(SOUNDS / "finish.wav", finish)
    write_wav(SOUNDS / "tick.wav", tone(660, 0.08, 0.32))
    write_wav(SOUNDS / "go.wav", tone(392, 0.1, 0.4) + tone(784, 0.16, 0.42))
    whoosh = []
    for i in range(int(22050 * 0.2)):
        f = 180 + i * 6
        whoosh.append(math.sin(2 * math.pi * f * i / 22050) * 0.22 * (1 - i / (22050 * 0.2)))
    write_wav(SOUNDS / "whoosh.wav", whoosh)
    write_wav(SOUNDS / "power.wav", tone(494, 0.08, 0.36) + tone(740, 0.12, 0.34))


def generate_pbxproj() -> None:
    ids = {}
    n = 1

    def nid(name: str) -> str:
        nonlocal n
        if name not in ids:
            ids[name] = hid(n)
            n += 1
        return ids[name]

    project = nid("project")
    target = nid("target")
    sources_phase = nid("sources")
    resources_phase = nid("resources")
    frameworks_phase = nid("frameworks")
    main_group = nid("main_group")
    products_group = nid("products")
    app_group = nid("app_group")
    src_groups = {
        "App": nid("g_app"),
        "Core": nid("g_core"),
        "Engine": nid("g_engine"),
        "Reality": nid("g_reality"),
        "Ads": nid("g_ads"),
        "UI": nid("g_ui"),
        "Resources": nid("g_res"),
        "Resources/Sounds": nid("g_sounds"),
    }
    config_list_proj = nid("cl_proj")
    config_list_tgt = nid("cl_tgt")
    debug_proj = nid("debug_proj")
    release_proj = nid("release_proj")
    debug_tgt = nid("debug_tgt")
    release_tgt = nid("release_tgt")
    product_ref = nid("product_ref")

    file_refs = {}
    build_files = {}
    for rel in SWIFT_FILES + RESOURCE_FILES:
        file_refs[rel] = nid(f"ref_{rel}")
        build_files[rel] = nid(f"bf_{rel}")

    def fileref(rel: str) -> str:
        name = Path(rel).name
        path = rel
        if rel == "Assets.xcassets":
            utype = "folder.assetcatalog"
        elif rel.endswith(".plist"):
            utype = "text.plist.xml"
        elif rel.endswith(".wav"):
            utype = "audio.wav"
        else:
            utype = "sourcecode.swift"
        return (
            f"\t\t{file_refs[rel]} /* {name} */ = "
            f"{{isa = PBXFileReference; lastKnownFileType = {utype}; path = {name}; sourceTree = \"<group>\"; }};"
        )

    build_file_lines = []
    for rel in SWIFT_FILES + RESOURCE_FILES:
        if rel == "Info.plist":
            continue
        name = Path(rel).name
        phase = "Resources" if rel in RESOURCE_FILES else "Sources"
        build_file_lines.append(
            f"\t\t{build_files[rel]} /* {name} in {phase} */ = "
            f"{{isa = PBXBuildFile; fileRef = {file_refs[rel]} /* {name} */; }};"
        )

    def children(rels: list[str]) -> str:
        lines = []
        for rel in rels:
            lines.append(f"\t\t\t\t{file_refs[rel]} /* {Path(rel).name} */,")
        return "\n".join(lines)

    swift_by_dir: dict[str, list[str]] = {k: [] for k in ["", "App", "Core", "Engine", "Reality", "Ads", "UI"]}
    for rel in SWIFT_FILES:
        if "/" in rel:
            swift_by_dir[str(Path(rel).parent)].append(rel)
        else:
            swift_by_dir[""].append(rel)

    group_lines = [
        f"""\t\t{main_group} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{app_group} /* FrostSlide */,
\t\t\t\t{products_group} /* Products */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t}};""",
        f"""\t\t{products_group} /* Products */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{product_ref} /* FrostSlide.app */,
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t}};""",
        f"""\t\t{app_group} /* FrostSlide */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{children(swift_by_dir[""])}
\t\t\t\t{src_groups["App"]} /* App */,
\t\t\t\t{src_groups["Core"]} /* Core */,
\t\t\t\t{src_groups["Engine"]} /* Engine */,
\t\t\t\t{src_groups["Reality"]} /* Reality */,
\t\t\t\t{src_groups["Ads"]} /* Ads */,
\t\t\t\t{src_groups["UI"]} /* UI */,
\t\t\t\t{src_groups["Resources"]} /* Resources */,
\t\t\t\t{file_refs["Assets.xcassets"]} /* Assets.xcassets */,
\t\t\t\t{file_refs["Info.plist"]} /* Info.plist */,
\t\t\t);
\t\t\tpath = FrostSlide;
\t\t\tsourceTree = "<group>";
\t\t}};""",
    ]
    for folder in ["App", "Core", "Engine", "Reality", "Ads", "UI"]:
        group_lines.append(
            f"""\t\t{src_groups[folder]} /* {folder} */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{children(swift_by_dir[folder])}
\t\t\t);
\t\t\tpath = {folder};
\t\t\tsourceTree = "<group>";
\t\t}};"""
        )
    sound_rels = [r for r in RESOURCE_FILES if r.endswith(".wav")]
    group_lines.append(
        f"""\t\t{src_groups["Resources"]} /* Resources */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{src_groups["Resources/Sounds"]} /* Sounds */,
\t\t\t);
\t\t\tpath = Resources;
\t\t\tsourceTree = "<group>";
\t\t}};"""
    )
    group_lines.append(
        f"""\t\t{src_groups["Resources/Sounds"]} /* Sounds */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{children(sound_rels)}
\t\t\t);
\t\t\tpath = Sounds;
\t\t\tsourceTree = "<group>";
\t\t}};"""
    )

    source_build = "\n".join(
        f"\t\t\t\t{build_files[rel]} /* {Path(rel).name} in Sources */," for rel in SWIFT_FILES
    )
    resource_build = "\n".join(
        f"\t\t\t\t{build_files[rel]} /* {Path(rel).name} in Resources */,"
        for rel in RESOURCE_FILES
        if rel != "Info.plist"
    )
    file_ref_lines = [fileref(rel) for rel in SWIFT_FILES + RESOURCE_FILES]
    file_ref_lines.append(
        f"\t\t{product_ref} /* FrostSlide.app */ = "
        "{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = FrostSlide.app; sourceTree = BUILT_PRODUCTS_DIR; };"
    )

    pbx = f"""// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 56;
	objects = {{

/* Begin PBXBuildFile section */
{chr(10).join(build_file_lines)}
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
{chr(10).join(file_ref_lines)}
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		{frameworks_phase} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
{chr(10).join(group_lines)}
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		{target} /* FrostSlide */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {config_list_tgt} /* Build configuration list for PBXNativeTarget "FrostSlide" */;
			buildPhases = (
				{sources_phase} /* Sources */,
				{frameworks_phase} /* Frameworks */,
				{resources_phase} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = FrostSlide;
			productName = FrostSlide;
			productReference = {product_ref} /* FrostSlide.app */;
			productType = "com.apple.product-type.application";
		}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		{project} /* Project object */ = {{
			isa = PBXProject;
			attributes = {{
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1500;
				LastUpgradeCheck = 1500;
				TargetAttributes = {{
					{target} = {{
						CreatedOnToolsVersion = 15.0;
					}};
				}};
			}};
			buildConfigurationList = {config_list_proj} /* Build configuration list for PBXProject "FrostSlide" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = {main_group};
			productRefGroup = {products_group} /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				{target} /* FrostSlide */,
			);
		}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		{resources_phase} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{resource_build}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		{sources_phase} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{source_build}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		{debug_proj} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_TESTABILITY = YES;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_OPTIMIZATION_LEVEL = 0;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = iphoneos;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
				SWIFT_VERSION = 5.0;
			}};
			name = Debug;
		}};
		{release_proj} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				MTL_ENABLE_DEBUG_INFO = NO;
				SDKROOT = iphoneos;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_OPTIMIZATION_LEVEL = "-O";
				SWIFT_VERSION = 5.0;
				VALIDATE_PRODUCT = YES;
			}};
			name = Release;
		}};
		{debug_tgt} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = FrostSlide/Info.plist;
				INFOPLIST_KEY_CFBundleDisplayName = "Frost Slide";
				INFOPLIST_KEY_LSRequiresIPhoneOS = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UIStatusBarHidden = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait;
				LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks";
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.frostslide.FrostSlide;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				SUPPORTS_MACCATALYST = NO;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = 1;
			}};
			name = Debug;
		}};
		{release_tgt} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = FrostSlide/Info.plist;
				INFOPLIST_KEY_CFBundleDisplayName = "Frost Slide";
				INFOPLIST_KEY_LSRequiresIPhoneOS = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UIStatusBarHidden = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait;
				LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks";
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.frostslide.FrostSlide;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				SUPPORTS_MACCATALYST = NO;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = 1;
			}};
			name = Release;
		}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		{config_list_proj} /* Build configuration list for PBXProject "FrostSlide" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{debug_proj} /* Debug */,
				{release_proj} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{config_list_tgt} /* Build configuration list for PBXNativeTarget "FrostSlide" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{debug_tgt} /* Debug */,
				{release_tgt} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
/* End XCConfigurationList section */
	}};
	rootObject = {project} /* Project object */;
}}
"""
    PROJ.mkdir(parents=True, exist_ok=True)
    (PROJ / "project.pbxproj").write_text(pbx)
    scheme_dir = PROJ / "xcshareddata" / "xcschemes"
    scheme_dir.mkdir(parents=True, exist_ok=True)
    (scheme_dir / "FrostSlide.xcscheme").write_text(
        f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1500"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{target}"
               BuildableName = "FrostSlide.app"
               BlueprintName = "FrostSlide"
               ReferencedContainer = "container:FrostSlide.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{target}"
            BuildableName = "FrostSlide.app"
            BlueprintName = "FrostSlide"
            ReferencedContainer = "container:FrostSlide.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{target}"
            BuildableName = "FrostSlide.app"
            BlueprintName = "FrostSlide"
            ReferencedContainer = "container:FrostSlide.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""
    )
    print(f"Wrote project with target id {target}")


if __name__ == "__main__":
    generate_sounds()
    # Do not overwrite FrostSlide.xcodeproj — it is hand-maintained
    # (RealityKit sources + GoogleMobileAds SPM + PrivacyInfo).
    missing = []
    for rel in SWIFT_FILES + RESOURCE_FILES:
        path = APP / rel
        if not path.exists():
            missing.append(str(path))
    if missing:
        raise SystemExit("Missing files:\n" + "\n".join(missing))
    print("Sounds regenerated. Project files verified (pbxproj left untouched).")
