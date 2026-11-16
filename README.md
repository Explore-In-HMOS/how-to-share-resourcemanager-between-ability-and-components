> **Note:** To access all shared projects, get information about environment setup, and view other guides, please visit [Explore-In-HMOS Index](https://github.com/Explore-In-HMOS/hmos-index).

# How to Share ResourceManager Between Ability and Components

A practical ResourceManager sharing sample for HarmonyOS Next smart wearables. The ability passes its ResourceManager directly to AudioService, while pages and components access their host context through `getUIContext().getHostContext()`. The application plays a packaged rawfile tone through a singleton AudioService. The codelab also demonstrates initialization guards, concurrent initialization handling, retry after failure, and lifecycle aware cleanup.

# Preview

<div>
  <img src="screenshots/s1.png" width="24%" alt="Shared Audio application preview">
</div>

# Use Cases

- **Shared ResourceManager**: Passes the ability ResourceManager into AudioService and obtains the host context in components, keeping context access within its owning ability.
- **Guarded Audio Initialization**: Uses an initialized flag and a shared pending promise to prevent duplicate AudioService initialization, including concurrent calls from the ability and page.
- **Rawfile Resource Access**: Reads `tone.wav` from a component with `getRawFileContent` and opens the same packaged resource in AudioService with `getRawFd`.
- **Lifecycle Aware Cleanup**: Pauses playback in the background, releases the player before closing its rawfile descriptor when its owning ability is destroyed.
- **Retry After Failure**: Cleans up partial initialization and allows another attempt when the rawfile or player is unavailable.

**Target APIs**

| Module | Method | Role |
|---|---|---|
| UIAbility | `onCreate` / `context` | Passes the ability ResourceManager to AudioService before page loading |
| UIContext | `getHostContext` | Obtains the component host context with an undefined check |
| Context | `resourceManager` | Provides resource access from the ability and its hosted components |
| ResourceManager | `getRawFileContent` | Reads the packaged tone from the ResourceInfo component |
| ResourceManager | `getRawFd` / `closeRawFd` | Opens and closes the rawfile descriptor used for playback |
| Media Kit | `media.createAVPlayer` | Creates the single audio player managed by AudioService |
| AVPlayer | `fdSrc` / `on` / `prepare` / `play` | Sets the descriptor source, waits for state changes, prepares, and plays audio |
| AVPlayer | `pause` / `release` | Pauses background playback and releases player resources |
| Promise | `all` / `finally` | Demonstrates concurrent initialization and clears the pending-operation guard |
| UIAbility lifecycle | `onForeground` / `onBackground` / `onDestroy` | Controls foreground playback and final resource cleanup |

# Technology

## Stack

- **Languages**: ArkTS, ArkUI
- **Frameworks**: HarmonyOS SDK 6.0.1(21) compatibility
- **Tools**: DevEco Studio
- **Libraries & Kits**:
  - `@kit.AbilityKit` — UIAbility lifecycle and UIAbilityContext
  - `@kit.LocalizationKit` — Shared ResourceManager and rawfile access
  - `@kit.MediaKit` — AVPlayer creation, preparation, playback, and release
  - `@kit.ArkUI` — Wearable interface, resource information, and page lifecycle
  - `@kit.BasicServicesKit` — Typed platform errors
  - `@kit.PerformanceAnalysisKit` — Ability and audio lifecycle diagnostics

## Required Permissions

No additional permissions are required to read and play the packaged rawfile audio.

# Directory Structure

```
entry/src/main/
├── ets/
│   ├── components/
│   │   └── ResourceInfo.ets           // Component access to the shared ResourceManager
│   ├── entryability/
│   │   └── EntryAbility.ets           // ResourceManager injection and service lifecycle
│   ├── pages/
│   │   └── Index.ets                  // Playback, retry, and initialization counter
│   └── service/
│       └── AudioService.ets          // Singleton, initialization guards, and player cleanup
└── resources/
    ├── base/
    │   ├── element/
    │   │   ├── color.json            // UI color resources
    │   │   └── string.json           // Labels, status text, and resource information
    │   └── profile/
    │       └── main_pages.json       // Application page registration
    └── rawfile/
        └── tone.wav                 // Original one-second PCM audio
scripts/
├── generate-tone.mjs                 // Reproduces the packaged tone
└── test-audio-service.mjs            // Injected ResourceManager and service guard tests
```

# Constraints and Restrictions

## Supported Device

- HarmonyOS wearable with AVPlayer audio playback support

## Requirements

- HarmonyOS API level 21 or higher
- DevEco Studio compatible with HarmonyOS SDK 6.0.1 or later
- A signing profile matching `com.hmosdemos.wearable.how_to_share_resourcemanager_between_ability_and_components`
- A physical wearable for playback, audio routing, and lifecycle verification
- The sample has one UIAbility and one AudioService instance; the service is released when that ability is destroyed
- Components obtain their host context with `this.getUIContext().getHostContext()` and check for `undefined` before resource access
- AudioService receives a ResourceManager parameter instead of retaining a global UIAbilityContext; all application code is in `.ets` files
- Initialization completes only after AVPlayer reaches `prepared`; concurrent callers share one promise, and preparation times out after ten seconds
- The rawfile descriptor stays open until the player is released and is closed through the same ResourceManager that opened it
- Playback pauses when the application enters the background and does not resume automatically
- Pressing **Initialize again** should keep the initialization count at `1` during a healthy session; the packaged resource size is `44144` bytes
- Generate the audio with `node scripts/generate-tone.mjs`
- Run automated checks with `node scripts/test-audio-service.mjs "<DevEco Studio SDK directory>"`; tests cover the injected ResourceManager, concurrent initialization, retry, cleanup, and background pause
- ArkTS compilation, automated checks, and unsigned HAP packaging passed; signing requires a profile matching the bundle name, and physical-device playback has not been verified

# License

**How to Share ResourceManager Between Ability and Components** is distributed under the terms of the MIT License. See the [LICENSE](LICENSE) for more information.
