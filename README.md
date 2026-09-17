# CameraKit — Lightweight client-side camera utility for Roblox

**CameraKit** is a lightweight, strictly typed Luau camera utility for Roblox. It handles temporary scripted camera ownership, cinematic movement, camera paths, subject changes, field-of-view transitions, additive camera shake, recoil, and restoration back to Roblox's normal camera controller.

CameraKit is client-only. Positional camera actions, FOV actions, and additive VFX use separate channels so effects can overlap intentionally—for example, a camera can follow a cinematic path while a shake and recoil effect are layered on top.

## Quick example

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraKit = require(ReplicatedStorage:WaitForChild("CameraKit"))
local cameraKit = CameraKit.new()

cameraKit:TweenTo(workspace.CameraPoints.Shop, {
	Speed = 30,
})

cameraKit:Shake({
	Duration = 0.45,
	Magnitude = 0.18,
	RotationMagnitude = 2,
})

cameraKit:PulseFieldOfView(8)

-- Return control to the captured gameplay camera later.
cameraKit:Restore(nil, {
	Duration = 0.45,
})
```

The first scripted positional action captures the current camera state by default. `Restore()` returns the camera type, subject, transform, focus, FOV, FOV mode, and player zoom limits to that captured state.

## 🚀 Features

- Tween the camera to a `CFrame`, `BasePart`, or `Attachment`
- Calculate transition duration automatically from distance and movement speed
- Play ordered or looping cinematic paths
- Configure duration, delay, and `TweenInfo` per path point
- Run FOV effects independently from positional movement
- Add procedural camera shake without taking over the base camera controller
- Stack recoil impulses with shake and scripted camera movement
- Play temporary FOV punches that automatically return to the starting FOV
- Change camera subjects while preserving the previous state
- Capture and restore camera state reliably
- Cancel running actions without stale tweens reclaiming control
- Receive `Completed` or `Cancelled` action results
- Handle `Workspace.CurrentCamera` replacement
- Recover when a previously captured camera subject is destroyed during respawn
- Maintain `Camera.Focus` while CameraKit owns a scriptable camera
- Strict Luau public API
- No external runtime dependencies

## 🛠️ Installation

### ModuleScript

Place `init.luau` in a client-accessible `ModuleScript`, such as `ReplicatedStorage.CameraKit`, then require it from a `LocalScript`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CameraKit = require(ReplicatedStorage:WaitForChild("CameraKit"))
```

### Wally

```toml
[dependencies]
CameraKit = "biotoxin495/camerakit@1.1.0"
```

CameraKit must be constructed on the client.

## Basic usage

```lua
local cameraKit = CameraKit.new({
	DefaultSpeed = 24,
	MinDuration = 0.1,
	MaxDuration = 8,
	FocusDistance = 32,
})
```

Every constructor field is optional. One long-lived CameraKit instance per owning client controller is recommended.

When the controller is no longer needed:

```lua
cameraKit:Destroy()
```

By default, destruction restores the saved camera state.

---

# API reference

## `CameraKit.new(config?)`

Creates a CameraKit controller.

| Option | Type | Default | Description |
| --- | --- | ---: | --- |
| `DefaultSpeed` | `number?` | `24` | Default positional movement speed in studs per second. |
| `MinDuration` | `number?` | `0.1` | Minimum automatically calculated movement duration. |
| `MaxDuration` | `number?` | `8` | Maximum automatically calculated movement duration. |
| `FocusDistance` | `number?` | `32` | Distance used while maintaining `Camera.Focus` during scripted movement. |

## `TweenTo(target, options?) -> CameraAction`

Tweens the current camera to a `CFrame`, `BasePart`, or `Attachment`. Attachments use `WorldCFrame`.

```lua
cameraKit:TweenTo(workspace.CameraPoint, {
	Duration = 1.2,
	EasingStyle = Enum.EasingStyle.Quint,
	EasingDirection = Enum.EasingDirection.Out,
})
```

Or let CameraKit calculate the duration from distance:

```lua
cameraKit:TweenTo(workspace.CameraPoint, {
	Speed = 28,
})
```

| Option | Type | Description |
| --- | --- | --- |
| `Duration` | `number?` | Explicit duration in seconds. Overrides speed-based timing. |
| `Speed` | `number?` | Movement speed when `Duration` is omitted. |
| `MinDuration` | `number?` | Per-action minimum calculated duration. |
| `MaxDuration` | `number?` | Per-action maximum calculated duration. |
| `TweenInfo` | `TweenInfo?` | Complete TweenInfo override. |
| `EasingStyle` | `Enum.EasingStyle?` | Defaults to `Quint`. |
| `EasingDirection` | `Enum.EasingDirection?` | Defaults to `Out`. |
| `CaptureState` | `boolean?` | Captures the current state if one has not already been saved. Defaults to `true`. |

If `TweenInfo` is supplied, its timing and easing settings take precedence.

## `PlayPath(points, options?) -> CameraAction`

Plays an ordered array of camera points.

```lua
cameraKit:PlayPath({
	workspace.CameraPoints.Start,
	workspace.CameraPoints.Middle,
	workspace.CameraPoints.End,
}, {
	Speed = 35,
	RestoreOnComplete = true,
})
```

A point can also carry per-segment timing:

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
		TweenInfo = TweenInfo.new(1.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	},
})
```

Configured path points support:

| Option | Type | Description |
| --- | --- | --- |
| `Target` | `CFrame \| BasePart \| Attachment` | Segment destination. |
| `Duration` | `number?` | Explicit segment duration. |
| `Delay` | `number?` | Delay after reaching the point. |
| `TweenInfo` | `TweenInfo?` | Complete TweenInfo override for the segment. |

Path options:

| Option | Type | Default | Description |
| --- | --- | ---: | --- |
| `Speed` | `number?` | constructor default | Segment speed when no duration is supplied. |
| `MinDuration` | `number?` | constructor default | Minimum calculated segment duration. |
| `MaxDuration` | `number?` | constructor default | Maximum calculated segment duration. |
| `TweenInfo` | `TweenInfo?` | `nil` | Default TweenInfo for path segments. |
| `EasingStyle` | `Enum.EasingStyle?` | `Linear` | Default path easing style. |
| `EasingDirection` | `Enum.EasingDirection?` | `InOut` | Default path easing direction. |
| `Loop` | `boolean?` | `false` | Repeats the path until cancelled. |
| `StartFromCurrent` | `boolean?` | `true` | When false, snaps to point one before continuing. |
| `RestoreOnComplete` | `boolean?` | `false` | Restores the saved state after a non-looping path. |
| `CaptureState` | `boolean?` | `true` | Captures the current state if one is not already saved. |
| `OnPointReached` | `function?` | `nil` | Invoked asynchronously when a point is reached. |

## `SetSubject(subject, options?)`

Changes `CameraSubject` to a `Humanoid` or `BasePart`.

```lua
cameraKit:SetSubject(workspace.DisplayCharacter.Humanoid, {
	CameraType = Enum.CameraType.Custom,
	MinZoomDistance = 18,
	MaxZoomDistance = 35,
})
```

| Option | Type | Default | Description |
| --- | --- | ---: | --- |
| `CameraType` | `Enum.CameraType?` | `Custom` | Camera type applied after changing the subject. |
| `CaptureState` | `boolean?` | `true` | Captures the previous state if needed. |
| `MinZoomDistance` | `number?` | unchanged | Optional player minimum zoom distance. |
| `MaxZoomDistance` | `number?` | unchanged | Optional player maximum zoom distance. |

## `SetFieldOfView(fieldOfView, options?) -> CameraAction`

Sets or tweens `Camera.FieldOfView`.

```lua
cameraKit:SetFieldOfView(55, {
	Duration = 0.3,
})
```

Valid values are `1` through `120`.

| Option | Type | Default | Description |
| --- | --- | ---: | --- |
| `Duration` | `number?` | `0.2` | Transition duration. |
| `CaptureState` | `boolean?` | `false` | Captures the full camera state if needed. |
| `TweenInfo` | `TweenInfo?` | `nil` | Complete TweenInfo override. |
| `EasingStyle` | `Enum.EasingStyle?` | `Quint` | Easing style when TweenInfo is omitted. |
| `EasingDirection` | `Enum.EasingDirection?` | `Out` | Easing direction when TweenInfo is omitted. |

Starting another FOV action cancels the previous FOV action.

## `PulseFieldOfView(amount, options?) -> CameraAction`

Creates a temporary FOV punch, then returns to the FOV that was active when the pulse started. The peak value is clamped to Roblox's `1`–`120` FOV range.

```lua
cameraKit:PulseFieldOfView(10, {
	AttackDuration = 0.06,
	HoldDuration = 0.03,
	ReleaseDuration = 0.28,
})
```

Use a negative amount for a quick zoom-in punch:

```lua
cameraKit:PulseFieldOfView(-8)
```

| Option | Type | Default | Description |
| --- | --- | ---: | --- |
| `AttackDuration` | `number?` | `0.08` | Time to reach the peak FOV. |
| `HoldDuration` | `number?` | `0` | Optional time held at the peak. |
| `ReleaseDuration` | `number?` | `0.22` | Time to return to the starting FOV. |
| `CaptureState` | `boolean?` | `false` | Captures the full camera state if needed. |
| `AttackEasingStyle` | `Enum.EasingStyle?` | `Quad` | Attack easing style. |
| `AttackEasingDirection` | `Enum.EasingDirection?` | `Out` | Attack easing direction. |
| `ReleaseEasingStyle` | `Enum.EasingStyle?` | `Quint` | Release easing style. |
| `ReleaseEasingDirection` | `Enum.EasingDirection?` | `Out` | Release easing direction. |

`PulseFieldOfView` uses the same FOV channel as `SetFieldOfView`.

## `Shake(options?) -> CameraAction`

Adds procedural local-space translation and rotation on top of the current camera. It does **not** change the camera type and can run over Roblox's normal player camera, `TweenTo`, or `PlayPath`.

```lua
local shake = cameraKit:Shake({
	Duration = 0.6,
	Magnitude = 0.2,
	RotationMagnitude = 2.5,
	Frequency = 22,
	FadeOut = 0.25,
})
```

| Option | Type | Default | Description |
| --- | --- | ---: | --- |
| `Duration` | `number?` | `0.5` | Total shake duration. |
| `Magnitude` | `number?` | `0.15` | Local positional shake magnitude in studs. |
| `RotationMagnitude` | `number?` | `1.5` | Rotation magnitude in degrees. |
| `Frequency` | `number?` | `18` | Noise sampling frequency; higher values feel rougher/faster. |
| `FadeIn` | `number?` | `0` | Fade-in duration. |
| `FadeOut` | `number?` | `min(0.2, Duration)` | Fade-out duration. |
| `Seed` | `number?` | random | Optional deterministic noise seed. |

Shake uses smooth `math.noise` sampling rather than independent frame-by-frame randomness, avoiding jitter that changes character with frame rate.

## `Recoil(options?) -> CameraAction`

Adds a one-shot local-space kick that eases back to zero. Recoil is an additive effect, so multiple recoil actions can overlap and can also stack with `Shake()`.

```lua
cameraKit:Recoil({
	Rotation = Vector3.new(-5, 0.4, 0),
	Position = Vector3.new(0, 0, 0.14),
	Duration = 0.22,
})
```

`Rotation` is expressed in degrees around local X/Y/Z. `Position` is in local camera-space studs.

| Option | Type | Default | Description |
| --- | --- | ---: | --- |
| `Duration` | `number?` | `0.25` | Time for the kick to settle back to zero. |
| `Position` | `Vector3?` | `(0, 0, 0.12)` | Initial local positional kick. |
| `Rotation` | `Vector3?` | `(-4, 0, 0)` | Initial local rotational kick in degrees. |
| `EasingStyle` | `Enum.EasingStyle?` | `Quad` | Decay easing style. |
| `EasingDirection` | `Enum.EasingDirection?` | `Out` | Decay easing direction. |

## `StopEffects()`

Cancels all active additive `Shake` and `Recoil` actions and removes their currently applied camera offset.

```lua
cameraKit:StopEffects()
```

This does not cancel positional camera movement or FOV actions.

## `CaptureState() -> CameraState`

Returns a snapshot of the current camera and player zoom state:

```lua
local state = cameraKit:CaptureState()
```

The state contains:

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

When an additive VFX offset is currently applied, CameraKit captures the underlying base `CFrame` rather than baking the transient shake/recoil offset into the saved state.

## `GetSavedState() -> CameraState?`

Returns CameraKit's automatically captured state, if one exists.

## `Restore(state?, options?) -> CameraAction`

Restores an explicit `CameraState`, or the internally saved state when `state` is `nil`.

```lua
cameraKit:Restore(nil, {
	Duration = 0.5,
})
```

Restore cancels active positional, FOV, and additive VFX work before applying the target state.

| Option | Type | Default | Description |
| --- | --- | ---: | --- |
| `Duration` | `number?` | `0` | Duration for CFrame and FOV restoration. |
| `TweenInfo` | `TweenInfo?` | `nil` | Complete restoration TweenInfo override. |
| `EasingStyle` | `Enum.EasingStyle?` | `Quint` | Easing style when TweenInfo is omitted. |
| `EasingDirection` | `Enum.EasingDirection?` | `Out` | Easing direction when TweenInfo is omitted. |
| `ClearSavedState` | `boolean?` | `true` | Clears the internal saved state when restoring that same state. |

If a captured subject was destroyed, CameraKit attempts to use the current character's `Humanoid` instead.

## `Stop(options?) -> CameraAction?`

Cancels active work.

```lua
cameraKit:Stop({
	Restore = true,
	RestoreOptions = {
		Duration = 0.4,
	},
})
```

| Option | Type | Default | Description |
| --- | --- | ---: | --- |
| `Restore` | `boolean?` | `false` | Restores the saved camera state after stopping. |
| `RestoreOptions` | `RestoreOptions?` | `nil` | Options forwarded to `Restore()`. |
| `StopFieldOfView` | `boolean?` | `true` | Also cancels the active FOV action. |
| `StopEffects` | `boolean?` | `true` | Also cancels active shake/recoil effects. |

Stopping without restoration intentionally leaves the camera at its current base state.

## `IsActive() -> boolean`

Returns `true` while a positional action, FOV action, or additive VFX action is active.

## `Destroy(restoreCamera?)`

Cancels all work, removes render-step bindings, disconnects internal listeners, and destroys the controller. By default it restores the saved state first.

```lua
cameraKit:Destroy()
```

To leave the current camera unchanged:

```lua
cameraKit:Destroy(false)
```

A destroyed CameraKit instance cannot be reused.

---

# CameraAction

`TweenTo`, `PlayPath`, `SetFieldOfView`, `PulseFieldOfView`, `Shake`, `Recoil`, and `Restore` return a `CameraAction` handle.

```lua
local action = cameraKit:Shake()

action.Completed:Connect(function(result)
	print(result) -- "Completed" or "Cancelled"
end)
```

Available methods and signals:

- `action.Completed` — fires once with `"Completed"` or `"Cancelled"`
- `action:Cancel()` — cancels the action if still active
- `action:Await()` — yields until completion and returns the result
- `action:IsPlaying()` — returns whether the action is still active
- `action:GetResult()` — returns the result or `nil` while running
- `action:Destroy()` — cancels an unfinished action and destroys its completion event

Repeated cancellation is safe.

# Action channels and VFX composition

CameraKit separates work into three categories.

### Positional channel

Used by `TweenTo`, `PlayPath`, and animated `Restore`. Starting a new positional action cancels the previous positional action.

### FOV channel

Used by `SetFieldOfView` and `PulseFieldOfView`. Starting a new FOV action cancels the previous FOV action.

### Additive VFX layer

Used by `Shake` and `Recoil`. These effects are not exclusive: multiple effects are composed together every render frame after the base camera has been updated.

This is valid:

```lua
cameraKit:PlayPath(path, {
	Speed = 30,
})

cameraKit:Shake({
	Duration = 1.2,
	Magnitude = 0.1,
})

cameraKit:Recoil({
	Rotation = Vector3.new(-3, 0, 0),
})

cameraKit:PulseFieldOfView(6)
```

The path remains responsible for the base transform, shake and recoil add temporary transform offsets, and the FOV pulse runs independently.

CameraKit tracks the last VFX offset it applied. If the base camera did not change between frames—for example after a scripted tween reaches a stationary `Scriptable` camera—it removes the previous offset before applying the next one. This prevents shake/recoil offsets from accumulating over time.

# Common patterns

## Explosion impact

```lua
cameraKit:Shake({
	Duration = 0.75,
	Magnitude = 0.28,
	RotationMagnitude = 3,
	Frequency = 20,
	FadeOut = 0.4,
})

cameraKit:PulseFieldOfView(7, {
	AttackDuration = 0.04,
	ReleaseDuration = 0.35,
})
```

## Weapon recoil

```lua
cameraKit:Recoil({
	Rotation = Vector3.new(-4.5, math.random(-10, 10) / 20, 0),
	Position = Vector3.new(0, 0, 0.1),
	Duration = 0.18,
})
```

Each shot can start another recoil action; the impulses overlap rather than cancelling each other.

## Cinematic hit during a path

```lua
local pathAction = cameraKit:PlayPath({
	workspace.CutscenePoints.Intro,
	workspace.CutscenePoints.Hit,
	workspace.CutscenePoints.Exit,
}, {
	Speed = 24,
	OnPointReached = function(index)
		if index == 2 then
			cameraKit:Shake({ Duration = 0.5 })
			cameraKit:PulseFieldOfView(8)
		end
	end,
})
```

## Looping lobby flyover

```lua
local flyover = cameraKit:PlayPath({
	workspace.LobbyCameraPoints.A,
	workspace.LobbyCameraPoints.B,
	workspace.LobbyCameraPoints.C,
}, {
	Loop = true,
	Speed = 45,
	EasingStyle = Enum.EasingStyle.Linear,
})

-- Player starts the game:
flyover:Cancel()
cameraKit:Restore(nil, {
	Duration = 0.4,
})
```

# Notes

- CameraKit is client-only.
- Server systems should signal a client to begin camera work rather than attempting to control `Workspace.CurrentCamera` from the server.
- `BasePart` and `Attachment` path targets are resolved when their segment begins.
- A tween does not continuously follow a moving target.
- Cancelling an action does not automatically restore the player camera unless restoration is explicitly requested.
- Cancelling an FOV tween leaves the camera at its current FOV, matching normal Tween cancellation semantics.
- Multiple CameraKit instances can technically exist, but they do not coordinate ownership with one another.
- CameraKit does not currently provide spline/Bézier interpolation, shoulder-camera controllers, lock-on systems, first-person replacements, collision avoidance, or zone-based camera systems.

# Project structure

```text
CameraKit/
├── init.luau
├── README.md
├── wally.toml
├── sourcemap.json
└── LICENSE
```

# License

MIT — see [LICENSE](LICENSE).

---

made with ❤️ by biotoxin495
