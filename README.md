# CameraKit — Lightweight client-side camera utility for Roblox

**CameraKit**, a lightweight client-side camera utility for Roblox and Luau.

Building a temporary scripted camera usually means coordinating ownership, transitions, paths, field-of-view effects, cancellation, and restoration by hand—and making sure Roblox's normal camera controller can safely take over again afterward.

**CameraKit** handles that lifecycle for you. It temporarily owns `Workspace.CurrentCamera` for cutscenes, menus, showcases, reward sequences, map flyovers, product previews, and lobby cameras, while leaving Roblox's default camera controller in charge during normal gameplay.

## Quick Example

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraKit = require(ReplicatedStorage:WaitForChild("CameraKit"))
local cameraKit = CameraKit.new()

local action = cameraKit:TweenTo(workspace.CameraPoints.Shop, {
	Speed = 30,
	EasingStyle = Enum.EasingStyle.Quint,
	EasingDirection = Enum.EasingDirection.Out,
})

action.Completed:Connect(function(result)
	print("Camera transition:", result)
end)

-- Return control to the captured camera state later.
cameraKit:Restore(nil, {
	Duration = 0.45,
})
```

The first scripted positional action captures the current camera state by default. `Restore` returns the camera type, subject, transform, focus, FOV, FOV mode, and player zoom limits to that captured state.

## 🚀 Features

- Tween the camera to a `CFrame`, `BasePart`, or `Attachment`
- Calculate transition duration automatically from distance and movement speed
- Use explicit transition durations when needed
- Play ordered or looping cinematic camera paths
- Configure duration, delay, and `TweenInfo` per path point
- Run FOV effects independently from positional camera movement
- Change the camera subject while preserving the previous state
- Capture and restore camera state reliably
- Cancel running actions without stale tweens or callbacks reclaiming control
- Receive `Completed` or `Cancelled` action results
- Handle `Workspace.CurrentCamera` replacement
- Recover when a previously captured camera subject is destroyed during a respawn
- Maintain `Camera.Focus` while CameraKit owns a scriptable camera
- Use strict Luau types throughout the public API
- No external runtime dependencies

## 🛠️ Installation

Add `CameraKit` as a ModuleScript somewhere accessible to the client code using it, such as `ReplicatedStorage`:

```text
ReplicatedStorage
└── CameraKit
```

Then require it from a `LocalScript`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraKit = require(ReplicatedStorage:WaitForChild("CameraKit"))
```

CameraKit is client-only and must be constructed on the client.

## 📖 Basic Usage

Create a controller by supplying an optional configuration table:

```lua
local cameraKit = CameraKit.new({
	DefaultSpeed = 24,
	MinDuration = 0.1,
	MaxDuration = 8,
	FocusDistance = 32,
})
```

Every field is optional. For most games, one long-lived CameraKit instance should act as the authoritative camera controller for the owning client system.

CameraKit does not replace Roblox's normal player camera controller. It takes direct ownership only during scripted camera work, then restores the previous state when requested.

When the controller is no longer needed, call `Destroy`:

```lua
cameraKit:Destroy()
```

By default, destruction restores the saved camera state.

## ⚙️ API Reference

### `CameraKit.new(config?)`

Creates a CameraKit controller.

| Option | Type | Default | Description |
| --- | --- | ---: | --- |
| `DefaultSpeed` | `number?` | `24` | Default movement speed in studs per second. |
| `MinDuration` | `number?` | `0.1` | Minimum automatically calculated transition duration. |
| `MaxDuration` | `number?` | `8` | Maximum automatically calculated transition duration. |
| `FocusDistance` | `number?` | `32` | Distance used when maintaining `Camera.Focus` during scripted movement. |

### `TweenTo(target, options?) -> CameraAction`

Tweens the current camera to a target.

Accepted targets:

- `CFrame`
- `BasePart`
- `Attachment`

Attachments use their `WorldCFrame`.

```lua
cameraKit:TweenTo(workspace.CameraPoint, {
    Duration = 1.2,
})
```

Or let CameraKit determine duration from distance:

```lua
cameraKit:TweenTo(workspace.CameraPoint, {
    Speed = 28,
})
```

#### Transition options

| Option | Type | Description |
| --- | --- | --- |
| `Duration` | `number?` | Explicit duration in seconds. Overrides speed-based timing. |
| `Speed` | `number?` | Movement speed in studs per second when duration is omitted. |
| `MinDuration` | `number?` | Per-action minimum calculated duration. |
| `MaxDuration` | `number?` | Per-action maximum calculated duration. |
| `TweenInfo` | `TweenInfo?` | Complete TweenInfo override. |
| `EasingStyle` | `Enum.EasingStyle?` | Defaults to `Quint`. |
| `EasingDirection` | `Enum.EasingDirection?` | Defaults to `Out`. |
| `CaptureState` | `boolean?` | Captures the current state if one has not already been saved. Defaults to `true`. |

If `TweenInfo` is supplied, its timing and easing settings take precedence.

### `PlayPath(points, options?) -> CameraAction`

Plays an ordered array of camera points.

```lua
local points = workspace.CameraPoints

cameraKit:PlayPath({
    points.Start,
    points.Middle,
    points.End,
}, {
    Speed = 35,
    RestoreOnComplete = true,
})
```

CameraKit preserves array order when traversing paths.

#### Configured path points

A path point can also contain its own timing information:

```lua
cameraKit:PlayPath({
    workspace.CameraPoints.Start,
    {
        Target = workspace.CameraPoints.Middle,
        Duration = 2,
        Delay = 0.5,
    },
    {
        Target = workspace.CameraPoints.End,
        TweenInfo = TweenInfo.new(
            1.5,
            Enum.EasingStyle.Quint,
            Enum.EasingDirection.Out
        ),
    },
})
```

A configured point supports:

| Option | Type | Description |
| --- | --- | --- |
| `Target` | `CFrame \| BasePart \| Attachment` | Destination for the segment. |
| `Duration` | `number?` | Explicit segment duration. |
| `Delay` | `number?` | Delay after reaching the point. |
| `TweenInfo` | `TweenInfo?` | Complete TweenInfo override for the segment. |

#### Path options

| Option | Type | Default | Description |
| --- | --- | ---: | --- |
| `Speed` | `number?` | Constructor default | Speed used for segments without explicit durations. |
| `MinDuration` | `number?` | Constructor default | Minimum calculated segment duration. |
| `MaxDuration` | `number?` | Constructor default | Maximum calculated segment duration. |
| `TweenInfo` | `TweenInfo?` | `nil` | Default TweenInfo for path segments. |
| `EasingStyle` | `Enum.EasingStyle?` | `Linear` | Default path easing style. |
| `EasingDirection` | `Enum.EasingDirection?` | `InOut` | Default path easing direction. |
| `Loop` | `boolean?` | `false` | Repeats the path until cancelled. |
| `StartFromCurrent` | `boolean?` | `true` | Tweens from the current camera to the first point. When false, snaps to point one first. |
| `RestoreOnComplete` | `boolean?` | `false` | Restores the saved state after a non-looping path completes. |
| `CaptureState` | `boolean?` | `true` | Captures the current state if one has not already been saved. |
| `OnPointReached` | `function?` | `nil` | Called asynchronously when a point is reached. |

#### Looping flyover

```lua
local flyover = cameraKit:PlayPath({
    workspace.FlyoverPoints.Point1,
    workspace.FlyoverPoints.Point2,
    workspace.FlyoverPoints.Point3,
}, {
    Speed = 50,
    Loop = true,
    EasingStyle = Enum.EasingStyle.Linear,
})

-- Later:
flyover:Cancel()
cameraKit:Restore()
```

### `SetFieldOfView(fieldOfView, options?) -> CameraAction`

Sets or tweens `Camera.FieldOfView`.

```lua
cameraKit:SetFieldOfView(55, {
    Duration = 0.3,
})
```

FOV actions use a separate action channel from positional camera movement. This means a path and a FOV tween can run at the same time.

Valid field-of-view values are `1` through `120`.

| Option | Type | Default | Description |
| --- | --- | ---: | --- |
| `Duration` | `number?` | `0.2` | Transition duration. Set to `0` for an immediate change. |
| `CaptureState` | `boolean?` | `false` | Captures the full camera state if one has not already been saved. |
| `TweenInfo` | `TweenInfo?` | `nil` | Complete TweenInfo override. |
| `EasingStyle` | `Enum.EasingStyle?` | `Quint` | Easing style when TweenInfo is omitted. |
| `EasingDirection` | `Enum.EasingDirection?` | `Out` | Easing direction when TweenInfo is omitted. |

Starting a new FOV action cancels the previous FOV action.

### `SetSubject(subject, options?)`

Changes `CameraSubject` to a `Humanoid` or `BasePart`.

```lua
cameraKit:SetSubject(workspace.DisplayCharacter.Humanoid, {
    CameraType = Enum.CameraType.Custom,
    MinZoomDistance = 18,
    MaxZoomDistance = 35,
})
```

Use `Restore()` to return to the previous subject and zoom limits.

| Option | Type | Default | Description |
| --- | --- | ---: | --- |
| `CameraType` | `Enum.CameraType?` | `Custom` | Camera type applied after changing the subject. |
| `CaptureState` | `boolean?` | `true` | Captures the previous camera state if needed. |
| `MinZoomDistance` | `number?` | unchanged | Optional player minimum zoom distance. |
| `MaxZoomDistance` | `number?` | unchanged | Optional player maximum zoom distance. |

### `CaptureState() -> CameraState`

Returns a snapshot of the current camera and player zoom state.

```lua
local gameplayState = cameraKit:CaptureState()
```

The returned state contains:

```lua
{
    CameraType,
    CameraSubject,
    CFrame,
    Focus,
    FieldOfView,
    FieldOfViewMode,
    CameraMinZoomDistance,
    CameraMaxZoomDistance,
}
```

`CaptureState()` does not modify CameraKit's internally saved state.

This makes it useful when the caller wants to manage explicit snapshots:

```lua
local gameplayState = cameraKit:CaptureState()

cameraKit:TweenTo(workspace.CameraPoints.Shop)

-- Later:
cameraKit:Restore(gameplayState, {
    Duration = 0.4,
})
```

### `GetSavedState() -> CameraState?`

Returns the camera state automatically captured by CameraKit, if one exists.

```lua
local savedState = cameraKit:GetSavedState()
```

### `Restore(state?, options?) -> CameraAction`

Restores either:

- An explicit `CameraState`, or
- CameraKit's internally saved state when `state` is `nil`.

```lua
cameraKit:Restore(nil, {
    Duration = 0.5,
})
```

| Option | Type | Default | Description |
| --- | --- | ---: | --- |
| `Duration` | `number?` | `0` | Duration for CFrame and FOV restoration. |
| `TweenInfo` | `TweenInfo?` | `nil` | Complete restoration TweenInfo override. |
| `EasingStyle` | `Enum.EasingStyle?` | `Quint` | Easing style when TweenInfo is omitted. |
| `EasingDirection` | `Enum.EasingDirection?` | `Out` | Easing direction when TweenInfo is omitted. |
| `ClearSavedState` | `boolean?` | `true` | Clears the internal saved state when restoring that same state. |

When a captured camera subject no longer exists, CameraKit attempts to use the current character's `Humanoid` instead. This prevents a destroyed humanoid from being restored after a respawn.

### `Stop(options?) -> CameraAction?`

Cancels active work.

```lua
cameraKit:Stop({
    Restore = true,
    RestoreOptions = {
        Duration = 0.4,
    },
})
```

Options:

| Option | Type | Default | Description |
| --- | --- | ---: | --- |
| `Restore` | `boolean?` | `false` | Restores the saved camera state after stopping. |
| `RestoreOptions` | `RestoreOptions?` | `nil` | Options passed to `Restore()`. |
| `StopFieldOfView` | `boolean?` | `true` | Also cancels the active FOV action. |

Stopping without restoration intentionally leaves the camera at its current state. This is useful when another scripted camera action is about to take control immediately.

### `IsActive() -> boolean`

Returns `true` while either a positional camera action or an FOV action is active.

```lua
if cameraKit:IsActive() then
    print("CameraKit is currently running an action")
end
```

### `Destroy(restoreCamera?)`

Cleans up the CameraKit controller.

```lua
cameraKit:Destroy()
```

By default, `Destroy()` restores the saved camera state before cleanup.

To leave the current camera unchanged:

```lua
cameraKit:Destroy(false)
```

A destroyed CameraKit instance cannot be reused.

## CameraAction

`TweenTo`, `PlayPath`, `SetFieldOfView`, and `Restore` return a `CameraAction` handle.

The handle provides explicit control over the lifecycle of the operation.

### `action.Completed`

An `RBXScriptSignal` fired once with either:

```text
Completed
Cancelled
```

Example:

```lua
local action = cameraKit:TweenTo(workspace.CameraPoint)

action.Completed:Connect(function(result)
    if result == "Completed" then
        print("Finished normally")
    else
        print("The transition was interrupted")
    end
end)
```

### `action:Cancel()`

Cancels the action if it is still active.

```lua
action:Cancel()
```

Repeated calls are safe.

### `action:Await() -> ActionResult`

Yields until the action finishes.

```lua
local result = action:Await()
print(result)
```

If the action has already finished, the stored result is returned immediately.

### `action:IsPlaying() -> boolean`

Returns whether the action is still active.

### `action:GetResult() -> ActionResult?`

Returns:

- `"Completed"`
- `"Cancelled"`
- `nil` while the action is still running

### `action:Destroy()`

Cancels an unfinished action and destroys its internal completion event.

Destroy retained action handles when they are no longer needed.

## Ownership and Interruption Behavior

CameraKit maintains two independent action channels.

### Positional camera channel

Used by:

- `TweenTo`
- `PlayPath`
- Animated `Restore`

Starting a new positional action cancels the previous positional action.

### FOV channel

Used by:

- `SetFieldOfView`

Starting a new FOV action cancels the previous FOV action.

Because the channels are separate, this is valid:

```lua
cameraKit:PlayPath(path, {
    Speed = 30,
})

cameraKit:SetFieldOfView(50, {
    Duration = 1,
})
```

The camera can move and change FOV simultaneously.

While CameraKit owns camera position, it:

1. Captures the previous state when requested.
2. Sets `Workspace.CurrentCamera.CameraType` to `Scriptable`.
3. Maintains `Camera.Focus` during scripted movement.
4. Runs the requested transition or path.
5. Remains at the final scripted position until restored unless `RestoreOnComplete` is enabled.

## Common Patterns

### Menu Camera

```lua
local menuAction = cameraKit:TweenTo(workspace.CameraPoints.Menu, {
    Duration = 0.8,
})

-- When the menu closes:
cameraKit:Restore(nil, {
    Duration = 0.5,
})
```

### Reward Reveal

```lua
cameraKit:TweenTo(workspace.CameraPoints.Reward, {
    Duration = 0.65,
})

cameraKit:SetFieldOfView(48, {
    Duration = 0.35,
})
```

### Cinematic Sequence

```lua
cameraKit:PlayPath({
    workspace.CutscenePoints.Intro,
    {
        Target = workspace.CutscenePoints.Focus,
        Duration = 2,
        Delay = 1,
    },
    workspace.CutscenePoints.Exit,
}, {
    Speed = 24,
    RestoreOnComplete = true,
    OnPointReached = function(index)
        print("Reached cutscene point", index)
    end,
})
```

### Looping Lobby Flyover

```lua
local lobbyFlyover = cameraKit:PlayPath({
    workspace.LobbyCameraPoints.A,
    workspace.LobbyCameraPoints.B,
    workspace.LobbyCameraPoints.C,
    workspace.LobbyCameraPoints.D,
}, {
    Loop = true,
    Speed = 45,
    EasingStyle = Enum.EasingStyle.Linear,
})

-- Player starts the game:
lobbyFlyover:Cancel()
cameraKit:Restore(nil, {
    Duration = 0.4,
})
```

### Interrupting an Existing Transition

Starting another positional action automatically cancels the previous one:

```lua
local firstAction = cameraKit:TweenTo(workspace.CameraPoints.A, {
    Duration = 5,
})

task.delay(1, function()
    cameraKit:TweenTo(workspace.CameraPoints.B, {
        Duration = 0.8,
    })
end)

firstAction.Completed:Connect(function(result)
    print(result) -- "Cancelled"
end)
```

## Recommended Lifecycle

Create CameraKit once when the owning client controller starts and destroy it when that controller shuts down.

```lua
local Controller = {}

function Controller:Start()
    self.cameraKit = CameraKit.new()
end

function Controller:Destroy()
    if self.cameraKit then
        self.cameraKit:Destroy()
        self.cameraKit = nil
    end
end
```

Avoid constructing a new CameraKit instance for every button press or cutscene. A shared instance keeps action ownership deterministic.

## 📝 Notes

CameraKit focuses on temporary scripted camera behavior.

It does not currently provide:

- Camera shake.
- Spline or Bézier interpolation.
- Shoulder-camera controllers.
- Lock-on camera controllers.
- First-person camera replacements.
- Camera collision avoidance.
- Zone-based camera systems.

Additional notes:

- CameraKit is client-only.
- Server systems should signal a client system to begin a camera action rather than controlling the camera directly.
- `BasePart` and `Attachment` targets are resolved when their path segment begins.
- A tween does not continuously follow a moving target.
- `StartFromCurrent = false` snaps to the first path point before continuing through the rest of the path.
- Cancelling an action does not automatically restore the player camera unless restoration is explicitly requested.
- Multiple CameraKit instances can technically exist, but they do not coordinate camera ownership with one another.

## Project Structure

```text
CameraKit/
├── src/
│   └── CameraKit/
│       └── init.luau
├── examples/
│   ├── BasicUsage.client.luau
│   └── DynamicDemo.client.luau
├── default.project.json
├── demo.project.json
├── wally.toml
├── selene.toml
├── .stylua.toml
├── CHANGELOG.md
├── LICENSE
└── README.md
```

### Development Checks

```sh
stylua --check src examples
selene src examples
rojo build default.project.json -o CameraKit.rbxlx
```

## Showcase

A separate CameraKit showcase project is included alongside the module release.

The showcase demonstrates:

- Camera transitions.
- Multi-point paths.
- Looping flyovers.
- FOV transitions.
- Subject switching.
- Action cancellation.
- State restoration.
- Interruption behavior.

The showcase generates its own environment and UI at runtime, making it useful as both a demonstration and an implementation reference.

## License

MIT — see [LICENSE](LICENSE).

---

made with ❤️ by biotoxin495
