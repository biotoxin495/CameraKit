--!strict

--   ____                                _  ___ _ _
--  / ___|__ _ _ __ ___   ___ _ __ __ _| |/ (_) |_
-- | |   / _` | '_ ` _ \ / _ \ '__/ _` | ' /| | __|
-- | |__| (_| | | | | | |  __/ | | (_| | . \| | |_
--  \____\__,_|_| |_| |_|\___|_|  \__,_|_|\_\_|\__|

-- made with ❤️ by biotoxin495

-- A lightweight client-side camera utility for Roblox.
--
-- CameraKit temporarily owns Workspace.CurrentCamera for scripted transitions,
-- cinematic paths, subject changes, and field-of-view effects while leaving
-- Roblox's default camera controller in charge during normal gameplay.
-- Additive VFX such as shake and recoil can run over either camera mode.

--//////////////////////////////////////////////////////////////////////////////
-- Services and constants
--//////////////////////////////////////////////////////////////////////////////

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local DEFAULT_SPEED = 24
local DEFAULT_MIN_DURATION = 0.1
local DEFAULT_MAX_DURATION = 8
local DEFAULT_FOCUS_DISTANCE = 32
local DEFAULT_FOV_DURATION = 0.2

local DEFAULT_SHAKE_DURATION = 0.5
local DEFAULT_SHAKE_MAGNITUDE = 0.15
local DEFAULT_SHAKE_ROTATION = 1.5
local DEFAULT_SHAKE_FREQUENCY = 18
local DEFAULT_SHAKE_FADE_OUT = 0.2

local DEFAULT_RECOIL_DURATION = 0.25
local DEFAULT_RECOIL_POSITION = Vector3.new(0, 0, 0.12)
local DEFAULT_RECOIL_ROTATION = Vector3.new(-4, 0, 0)

local DEFAULT_FOV_PULSE_ATTACK = 0.08
local DEFAULT_FOV_PULSE_RELEASE = 0.22

--//////////////////////////////////////////////////////////////////////////////
-- Exported types
--//////////////////////////////////////////////////////////////////////////////

export type ActionResult = "Completed" | "Cancelled"
export type CameraTarget = CFrame | BasePart | Attachment

export type CameraState = {
	CameraType: Enum.CameraType,
	CameraSubject: Instance?,
	CFrame: CFrame,
	Focus: CFrame,
	FieldOfView: number,
	FieldOfViewMode: Enum.FieldOfViewMode,
	CameraMinZoomDistance: number,
	CameraMaxZoomDistance: number,
}

export type Config = {
	DefaultSpeed: number?,
	MinDuration: number?,
	MaxDuration: number?,
	FocusDistance: number?,
}

export type TransitionOptions = {
	Duration: number?,
	Speed: number?,
	MinDuration: number?,
	MaxDuration: number?,
	TweenInfo: TweenInfo?,
	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,
	CaptureState: boolean?,
}

export type PathPointOptions = {
	Target: CameraTarget,
	Duration: number?,
	Delay: number?,
	TweenInfo: TweenInfo?,
}

export type PathPoint = CameraTarget | PathPointOptions

export type PathOptions = {
	Speed: number?,
	MinDuration: number?,
	MaxDuration: number?,
	TweenInfo: TweenInfo?,
	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,
	Loop: boolean?,
	StartFromCurrent: boolean?,
	RestoreOnComplete: boolean?,
	CaptureState: boolean?,
	OnPointReached: ((index: number, point: PathPoint) -> ())?,
}

export type RestoreOptions = {
	Duration: number?,
	TweenInfo: TweenInfo?,
	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,
	ClearSavedState: boolean?,
}

export type SubjectOptions = {
	CameraType: Enum.CameraType?,
	CaptureState: boolean?,
	MinZoomDistance: number?,
	MaxZoomDistance: number?,
}

export type FieldOfViewOptions = {
	Duration: number?,
	CaptureState: boolean?,
	TweenInfo: TweenInfo?,
	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,
}

export type ShakeOptions = {
	Duration: number?,
	Magnitude: number?,
	RotationMagnitude: number?,
	Frequency: number?,
	FadeIn: number?,
	FadeOut: number?,
	Seed: number?,
}

export type RecoilOptions = {
	Duration: number?,
	Position: Vector3?,
	Rotation: Vector3?,
	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,
}

export type FieldOfViewPulseOptions = {
	AttackDuration: number?,
	HoldDuration: number?,
	ReleaseDuration: number?,
	CaptureState: boolean?,
	AttackEasingStyle: Enum.EasingStyle?,
	AttackEasingDirection: Enum.EasingDirection?,
	ReleaseEasingStyle: Enum.EasingStyle?,
	ReleaseEasingDirection: Enum.EasingDirection?,
}

export type StopOptions = {
	Restore: boolean?,
	RestoreOptions: RestoreOptions?,
	StopFieldOfView: boolean?,
	StopEffects: boolean?,
}

export type CameraAction = {
	Completed: RBXScriptSignal,
	Cancel: (self: CameraAction) -> (),
	Await: (self: CameraAction) -> ActionResult,
	IsPlaying: (self: CameraAction) -> boolean,
	GetResult: (self: CameraAction) -> ActionResult?,
	Destroy: (self: CameraAction) -> (),
}

type ActionInternal = CameraAction & {
	_event: BindableEvent,
	_result: ActionResult?,
	_cancelCallback: (() -> ())?,
	_destroyed: boolean,
	_finish: (self: ActionInternal, result: ActionResult) -> (),
}

type EffectInternal = {
	Action: ActionInternal,
	StartedAt: number,
	Duration: number,
	Update: (elapsed: number, deltaTime: number) -> CFrame,
}

--//////////////////////////////////////////////////////////////////////////////
-- CameraAction
--//////////////////////////////////////////////////////////////////////////////

local CameraActionImpl = {}
CameraActionImpl.__index = CameraActionImpl

function CameraActionImpl.new(cancelCallback: (() -> ())?): ActionInternal
	local event = Instance.new("BindableEvent")

	local self = setmetatable({
		Completed = event.Event,
		_event = event,
		_result = nil,
		_cancelCallback = cancelCallback,
		_destroyed = false,
	}, CameraActionImpl)

	return self :: any
end

function CameraActionImpl:_finish(result: ActionResult)
	if self._destroyed or self._result ~= nil then
		return
	end

	self._result = result
	self._cancelCallback = nil
	self._event:Fire(result)
end

function CameraActionImpl:Cancel()
	if self._destroyed or self._result ~= nil then
		return
	end

	local cancelCallback = self._cancelCallback
	if cancelCallback then
		cancelCallback()
	else
		self:_finish("Cancelled")
	end
end

function CameraActionImpl:Await(): ActionResult
	if self._result then
		return self._result
	end

	return self.Completed:Wait() :: ActionResult
end

function CameraActionImpl:IsPlaying(): boolean
	return not self._destroyed and self._result == nil
end

function CameraActionImpl:GetResult(): ActionResult?
	return self._result
end

function CameraActionImpl:Destroy()
	if self._destroyed then
		return
	end

	if self._result == nil then
		self:Cancel()
	end

	self._destroyed = true
	self._cancelCallback = nil
	self._event:Destroy()
end

--//////////////////////////////////////////////////////////////////////////////
-- CameraKit
--//////////////////////////////////////////////////////////////////////////////

local CameraKit = {}
CameraKit.__index = CameraKit
CameraKit.Version = "1.1.0"

export type CameraKit = typeof(setmetatable(
	{} :: {
		_player: Player,
		_defaultSpeed: number,
		_minDuration: number,
		_maxDuration: number,
		_focusDistance: number,
		_renderStepName: string,
		_effectRenderStepName: string,
		_focusBound: boolean,
		_effectBound: boolean,
		_ownsCamera: boolean,
		_destroyed: boolean,
		_savedState: CameraState?,
		_cameraAction: ActionInternal?,
		_cameraTween: Tween?,
		_cameraThread: thread?,
		_fovAction: ActionInternal?,
		_fovTween: Tween?,
		_fovThread: thread?,
		_effects: { EffectInternal },
		_effectLastOffset: CFrame,
		_effectAppliedCFrame: CFrame?,
		_currentCameraConnection: RBXScriptConnection?,
	},
	CameraKit
))

local function assertPositiveNumber(value: number, name: string)
	assert(value > 0, string.format("CameraKit: %s must be greater than zero", name))
end

local function assertNonNegativeNumber(value: number, name: string)
	assert(value >= 0, string.format("CameraKit: %s cannot be negative", name))
end

local function resolveTarget(target: CameraTarget): CFrame
	if typeof(target) == "CFrame" then
		return target
	end

	if target:IsA("Attachment") then
		return target.WorldCFrame
	end

	if target:IsA("BasePart") then
		return target.CFrame
	end

	error("CameraKit: target must be a CFrame, BasePart, or Attachment", 3)
end

local function unpackPathPoint(point: PathPoint): (CameraTarget, number?, number?, TweenInfo?)
	if typeof(point) == "CFrame" or typeof(point) == "Instance" then
		return point :: CameraTarget, nil, nil, nil
	end

	local pointOptions = point :: PathPointOptions
	assert(pointOptions.Target ~= nil, "CameraKit: path point table is missing Target")

	return pointOptions.Target, pointOptions.Duration, pointOptions.Delay, pointOptions.TweenInfo
end

local function getEffectEnvelope(elapsed: number, duration: number, fadeIn: number, fadeOut: number): number
	local envelope = 1

	if fadeIn > 0 then
		envelope = math.min(envelope, elapsed / fadeIn)
	end

	if fadeOut > 0 then
		envelope = math.min(envelope, (duration - elapsed) / fadeOut)
	end

	return math.clamp(envelope, 0, 1)
end

function CameraKit.new(config: Config?): CameraKit
	assert(RunService:IsClient(), "CameraKit can only be constructed on the client")

	local resolvedConfig: Config = config or {}
	local player = Players.LocalPlayer
	assert(player, "CameraKit requires Players.LocalPlayer")

	local defaultSpeed = resolvedConfig.DefaultSpeed or DEFAULT_SPEED
	local minDuration = resolvedConfig.MinDuration or DEFAULT_MIN_DURATION
	local maxDuration = resolvedConfig.MaxDuration or DEFAULT_MAX_DURATION
	local focusDistance = resolvedConfig.FocusDistance or DEFAULT_FOCUS_DISTANCE

	assertPositiveNumber(defaultSpeed, "DefaultSpeed")
	assertNonNegativeNumber(minDuration, "MinDuration")
	assert(maxDuration >= minDuration, "CameraKit: MaxDuration must be at least MinDuration")
	assertPositiveNumber(focusDistance, "FocusDistance")

	local guid = HttpService:GenerateGUID(false)
	local self: CameraKit = setmetatable({
		_player = player,
		_defaultSpeed = defaultSpeed,
		_minDuration = minDuration,
		_maxDuration = maxDuration,
		_focusDistance = focusDistance,
		_renderStepName = "CameraKitFocus_" .. guid,
		_effectRenderStepName = "CameraKitEffects_" .. guid,
		_focusBound = false,
		_effectBound = false,
		_ownsCamera = false,
		_destroyed = false,
		_savedState = nil,
		_cameraAction = nil,
		_cameraTween = nil,
		_cameraThread = nil,
		_fovAction = nil,
		_fovTween = nil,
		_fovThread = nil,
		_effects = {},
		_effectLastOffset = CFrame.new(),
		_effectAppliedCFrame = nil,
		_currentCameraConnection = nil,
	}, CameraKit) :: any

	self._currentCameraConnection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		if self._destroyed then
			return
		end

		self:_cancelCameraAction()
		self:_cancelFieldOfViewAction()
		self:_cancelAllEffects()
		self:_stopFocusTracking()
		self._savedState = nil
	end)

	return self
end

function CameraKit:_assertAlive()
	assert(not self._destroyed, "CameraKit: this instance has been destroyed")
end

function CameraKit:_getCamera(): Camera
	local camera = Workspace.CurrentCamera
	assert(camera, "CameraKit: Workspace.CurrentCamera is unavailable")
	return camera
end

function CameraKit:_getCurrentHumanoid(): Humanoid?
	local character = self._player.Character
	if not character then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid")
end

function CameraKit:_getBaseCameraCFrame(camera: Camera): CFrame
	if self._effectAppliedCFrame and camera.CFrame == self._effectAppliedCFrame then
		return camera.CFrame * self._effectLastOffset:Inverse()
	end

	return camera.CFrame
end

function CameraKit:_startFocusTracking()
	if self._focusBound then
		return
	end

	self._ownsCamera = true
	self._focusBound = true

	RunService:BindToRenderStep(self._renderStepName, Enum.RenderPriority.Camera.Value + 1, function()
		if not self._ownsCamera or self._destroyed then
			return
		end

		local camera = Workspace.CurrentCamera
		if camera then
			camera.Focus = camera.CFrame * CFrame.new(0, 0, -self._focusDistance)
		end
	end)
end

function CameraKit:_stopFocusTracking()
	self._ownsCamera = false

	if self._focusBound then
		self._focusBound = false
		RunService:UnbindFromRenderStep(self._renderStepName)
	end
end

function CameraKit:_unbindEffectTracking()
	if self._effectBound then
		self._effectBound = false
		RunService:UnbindFromRenderStep(self._effectRenderStepName)
	end
end

function CameraKit:_clearAppliedEffectOffset()
	local camera = Workspace.CurrentCamera
	if camera and self._effectAppliedCFrame and camera.CFrame == self._effectAppliedCFrame then
		camera.CFrame = camera.CFrame * self._effectLastOffset:Inverse()

		if self._ownsCamera then
			camera.Focus = camera.CFrame * CFrame.new(0, 0, -self._focusDistance)
		end
	end

	self._effectLastOffset = CFrame.new()
	self._effectAppliedCFrame = nil
end

function CameraKit:_stopEffectTracking()
	self:_clearAppliedEffectOffset()
	self:_unbindEffectTracking()
end

function CameraKit:_renderEffects(deltaTime: number)
	local now = os.clock()
	local completedActions: { ActionInternal } = {}

	for index = #self._effects, 1, -1 do
		local effect = self._effects[index]
		if now - effect.StartedAt >= effect.Duration then
			table.remove(self._effects, index)
			table.insert(completedActions, effect.Action)
		end
	end

	local camera = Workspace.CurrentCamera
	if camera then
		local baseCFrame = self:_getBaseCameraCFrame(camera)

		if #self._effects == 0 then
			camera.CFrame = baseCFrame

			if self._ownsCamera then
				camera.Focus = camera.CFrame * CFrame.new(0, 0, -self._focusDistance)
			end

			self._effectLastOffset = CFrame.new()
			self._effectAppliedCFrame = nil
			self:_unbindEffectTracking()
		else
			local combinedOffset = CFrame.new()

			for _, effect in ipairs(self._effects) do
				local elapsed = now - effect.StartedAt
				combinedOffset = combinedOffset * effect.Update(elapsed, deltaTime)
			end

			camera.CFrame = baseCFrame * combinedOffset
			self._effectLastOffset = combinedOffset
			self._effectAppliedCFrame = camera.CFrame

			if self._ownsCamera then
				camera.Focus = camera.CFrame * CFrame.new(0, 0, -self._focusDistance)
			end
		end
	elseif #self._effects == 0 then
		self._effectLastOffset = CFrame.new()
		self._effectAppliedCFrame = nil
		self:_unbindEffectTracking()
	end

	for _, action in ipairs(completedActions) do
		action:_finish("Completed")
	end
end

function CameraKit:_startEffectTracking()
	if self._effectBound then
		return
	end

	self._effectBound = true
	RunService:BindToRenderStep(self._effectRenderStepName, Enum.RenderPriority.Camera.Value + 2, function(deltaTime)
		if self._destroyed then
			return
		end

		self:_renderEffects(deltaTime)
	end)
end

function CameraKit:_cancelEffect(effectToCancel: EffectInternal)
	for index, effect in ipairs(self._effects) do
		if effect == effectToCancel then
			table.remove(self._effects, index)

			if #self._effects == 0 then
				self:_stopEffectTracking()
			end

			effect.Action:_finish("Cancelled")
			return
		end
	end

	effectToCancel.Action:_finish("Cancelled")
end

function CameraKit:_cancelAllEffects()
	local effects = self._effects
	self._effects = {}
	self:_stopEffectTracking()

	for _, effect in ipairs(effects) do
		effect.Action:_finish("Cancelled")
	end
end

function CameraKit:_addEffect(duration: number, update: (elapsed: number, deltaTime: number) -> CFrame): CameraAction
	if duration == 0 then
		local action = CameraActionImpl.new(nil)
		action:_finish("Completed")
		return action
	end

	local effect: EffectInternal? = nil
	local action = CameraActionImpl.new(function()
		local currentEffect = effect
		if currentEffect then
			self:_cancelEffect(currentEffect)
		end
	end)

	local createdEffect: EffectInternal = {
		Action = action,
		StartedAt = os.clock(),
		Duration = duration,
		Update = update,
	}
	effect = createdEffect

	table.insert(self._effects, createdEffect)
	self:_startEffectTracking()

	return action
end

function CameraKit:_captureIfNeeded(shouldCapture: boolean?)
	if shouldCapture == false or self._savedState ~= nil then
		return
	end

	self._savedState = self:CaptureState()
end

function CameraKit:_calculateDuration(
	fromCFrame: CFrame,
	toCFrame: CFrame,
	explicitDuration: number?,
	speed: number?,
	minDuration: number?,
	maxDuration: number?
): number
	if explicitDuration ~= nil then
		assertNonNegativeNumber(explicitDuration, "Duration")
		return explicitDuration
	end

	local resolvedSpeed = speed or self._defaultSpeed
	local resolvedMin = minDuration or self._minDuration
	local resolvedMax = maxDuration or self._maxDuration

	assertPositiveNumber(resolvedSpeed, "Speed")
	assertNonNegativeNumber(resolvedMin, "MinDuration")
	assert(resolvedMax >= resolvedMin, "CameraKit: MaxDuration must be at least MinDuration")

	local distance = (toCFrame.Position - fromCFrame.Position).Magnitude
	return math.clamp(distance / resolvedSpeed, resolvedMin, resolvedMax)
end

function CameraKit:_buildTweenInfo(
	duration: number,
	explicitTweenInfo: TweenInfo?,
	easingStyle: Enum.EasingStyle?,
	easingDirection: Enum.EasingDirection?
): TweenInfo
	if explicitTweenInfo then
		return explicitTweenInfo
	end

	return TweenInfo.new(duration, easingStyle or Enum.EasingStyle.Quint, easingDirection or Enum.EasingDirection.Out)
end

function CameraKit:_prepareScriptableCamera()
	local camera = self:_getCamera()
	camera.CameraType = Enum.CameraType.Scriptable
	self:_startFocusTracking()
end

function CameraKit:_cancelCameraAction()
	local action = self._cameraAction
	self._cameraAction = nil

	local tween = self._cameraTween
	self._cameraTween = nil
	if tween then
		tween:Cancel()
		tween:Destroy()
	end

	local runningThread = self._cameraThread
	self._cameraThread = nil
	if runningThread and runningThread ~= coroutine.running() then
		pcall(task.cancel, runningThread)
	end

	if action then
		action:_finish("Cancelled")
	end
end

function CameraKit:_cancelFieldOfViewAction()
	local action = self._fovAction
	self._fovAction = nil

	local tween = self._fovTween
	self._fovTween = nil
	if tween then
		tween:Cancel()
		tween:Destroy()
	end

	local runningThread = self._fovThread
	self._fovThread = nil
	if runningThread and runningThread ~= coroutine.running() then
		pcall(task.cancel, runningThread)
	end

	if action then
		action:_finish("Cancelled")
	end
end

function CameraKit:_runCameraTween(
	action: ActionInternal,
	goal: { [string]: any },
	tweenInfo: TweenInfo
): Enum.PlaybackState
	local camera = self:_getCamera()
	local tween = TweenService:Create(camera, tweenInfo, goal)
	self._cameraTween = tween

	tween:Play()
	local playbackState = tween.Completed:Wait()

	if self._cameraTween == tween then
		self._cameraTween = nil
	end

	tween:Destroy()

	if self._cameraAction ~= action then
		return Enum.PlaybackState.Cancelled
	end

	return playbackState
end

function CameraKit:_runFieldOfViewTween(
	action: ActionInternal,
	fieldOfView: number,
	tweenInfo: TweenInfo
): Enum.PlaybackState
	local camera = self:_getCamera()

	if tweenInfo.Time == 0 then
		camera.FieldOfView = fieldOfView
		return Enum.PlaybackState.Completed
	end

	local tween = TweenService:Create(camera, tweenInfo, { FieldOfView = fieldOfView })
	self._fovTween = tween
	tween:Play()
	local playbackState = tween.Completed:Wait()

	if self._fovTween == tween then
		self._fovTween = nil
	end

	tween:Destroy()

	if self._fovAction ~= action then
		return Enum.PlaybackState.Cancelled
	end

	return playbackState
end

function CameraKit:_resolveRestoredSubject(subject: Instance?): Instance?
	if subject and subject.Parent then
		return subject
	end

	return self:_getCurrentHumanoid()
end

function CameraKit:_applyState(state: CameraState)
	local camera = self:_getCamera()
	local subject = self:_resolveRestoredSubject(state.CameraSubject)

	self:_stopFocusTracking()

	self._player.CameraMinZoomDistance = state.CameraMinZoomDistance
	self._player.CameraMaxZoomDistance = state.CameraMaxZoomDistance

	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = state.CFrame
	camera.Focus = state.Focus
	camera.FieldOfView = state.FieldOfView
	camera.FieldOfViewMode = state.FieldOfViewMode
	camera.CameraSubject = subject
	camera.CameraType = state.CameraType
end

--//////////////////////////////////////////////////////////////////////////////
-- Public state and movement API
--//////////////////////////////////////////////////////////////////////////////

function CameraKit:CaptureState(): CameraState
	self:_assertAlive()

	local camera = self:_getCamera()
	local cframe = self:_getBaseCameraCFrame(camera)
	local focus = camera.Focus

	if self._ownsCamera and cframe ~= camera.CFrame then
		focus = cframe * CFrame.new(0, 0, -self._focusDistance)
	end

	return {
		CameraType = camera.CameraType,
		CameraSubject = camera.CameraSubject,
		CFrame = cframe,
		Focus = focus,
		FieldOfView = camera.FieldOfView,
		FieldOfViewMode = camera.FieldOfViewMode,
		CameraMinZoomDistance = self._player.CameraMinZoomDistance,
		CameraMaxZoomDistance = self._player.CameraMaxZoomDistance,
	}
end

function CameraKit:GetSavedState(): CameraState?
	self:_assertAlive()
	return self._savedState
end

function CameraKit:TweenTo(target: CameraTarget, options: TransitionOptions?): CameraAction
	self:_assertAlive()

	local resolvedOptions: TransitionOptions = options or {}
	local targetCFrame = resolveTarget(target)

	self:_captureIfNeeded(resolvedOptions.CaptureState)
	self:_cancelCameraAction()
	self:_prepareScriptableCamera()

	local camera = self:_getCamera()
	local duration: number
	if resolvedOptions.TweenInfo then
		duration = resolvedOptions.TweenInfo.Time
	else
		duration = self:_calculateDuration(
			self:_getBaseCameraCFrame(camera),
			targetCFrame,
			resolvedOptions.Duration,
			resolvedOptions.Speed,
			resolvedOptions.MinDuration,
			resolvedOptions.MaxDuration
		)
	end
	local tweenInfo = self:_buildTweenInfo(
		duration,
		resolvedOptions.TweenInfo,
		resolvedOptions.EasingStyle,
		resolvedOptions.EasingDirection
	)

	local action: ActionInternal
	action = CameraActionImpl.new(function()
		if self._cameraAction == action then
			self:_cancelCameraAction()
		else
			action:_finish("Cancelled")
		end
	end)

	self._cameraAction = action
	self._cameraThread = task.spawn(function()
		if tweenInfo.Time == 0 then
			camera.CFrame = targetCFrame
		else
			local playbackState = self:_runCameraTween(action, { CFrame = targetCFrame }, tweenInfo)
			if playbackState ~= Enum.PlaybackState.Completed then
				return
			end
		end

		if self._cameraAction ~= action then
			return
		end

		self._cameraAction = nil
		self._cameraThread = nil
		action:_finish("Completed")
	end)

	return action
end

function CameraKit:PlayPath(points: { PathPoint }, options: PathOptions?): CameraAction
	self:_assertAlive()
	assert(#points > 0, "CameraKit: PlayPath requires at least one point")

	local resolvedOptions: PathOptions = options or {}
	local loopPath = resolvedOptions.Loop == true
	local startFromCurrent = resolvedOptions.StartFromCurrent ~= false

	self:_captureIfNeeded(resolvedOptions.CaptureState)
	self:_cancelCameraAction()
	self:_prepareScriptableCamera()

	local action: ActionInternal
	action = CameraActionImpl.new(function()
		if self._cameraAction == action then
			self:_cancelCameraAction()
		else
			action:_finish("Cancelled")
		end
	end)

	self._cameraAction = action
	self._cameraThread = task.spawn(function()
		local camera = self:_getCamera()
		local firstPass = true

		repeat
			local firstIndex = 1

			if firstPass and not startFromCurrent then
				local firstTarget, _, firstDelay = unpackPathPoint(points[1])
				camera.CFrame = resolveTarget(firstTarget)
				firstIndex = 2

				if resolvedOptions.OnPointReached then
					task.spawn(resolvedOptions.OnPointReached, 1, points[1])
				end

				if firstDelay and firstDelay > 0 then
					task.wait(firstDelay)
				end
			end

			for index = firstIndex, #points do
				if self._cameraAction ~= action then
					return
				end

				local target, pointDuration, pointDelay, pointTweenInfo = unpackPathPoint(points[index])
				local targetCFrame = resolveTarget(target)
				local explicitTweenInfo = pointTweenInfo or resolvedOptions.TweenInfo
				local duration: number
				if explicitTweenInfo then
					duration = explicitTweenInfo.Time
				else
					duration = self:_calculateDuration(
						self:_getBaseCameraCFrame(camera),
						targetCFrame,
						pointDuration,
						resolvedOptions.Speed,
						resolvedOptions.MinDuration,
						resolvedOptions.MaxDuration
					)
				end
				local tweenInfo = self:_buildTweenInfo(
					duration,
					explicitTweenInfo,
					resolvedOptions.EasingStyle or Enum.EasingStyle.Linear,
					resolvedOptions.EasingDirection or Enum.EasingDirection.InOut
				)

				if tweenInfo.Time == 0 then
					camera.CFrame = targetCFrame
				else
					local playbackState = self:_runCameraTween(action, { CFrame = targetCFrame }, tweenInfo)
					if playbackState ~= Enum.PlaybackState.Completed then
						return
					end
				end

				if resolvedOptions.OnPointReached then
					task.spawn(resolvedOptions.OnPointReached, index, points[index])
				end

				if pointDelay and pointDelay > 0 then
					task.wait(pointDelay)
				end
			end

			firstPass = false
		until not loopPath

		if self._cameraAction ~= action then
			return
		end

		self._cameraAction = nil
		self._cameraThread = nil

		if resolvedOptions.RestoreOnComplete and self._savedState then
			local savedState = self._savedState
			self._savedState = nil
			self:_cancelAllEffects()
			self:_applyState(savedState)
		end

		action:_finish("Completed")
	end)

	return action
end

function CameraKit:SetSubject(subject: Instance, options: SubjectOptions?)
	self:_assertAlive()
	assert(
		subject:IsA("Humanoid") or subject:IsA("BasePart"),
		"CameraKit: CameraSubject must be a Humanoid or BasePart"
	)

	local resolvedOptions: SubjectOptions = options or {}
	self:_captureIfNeeded(resolvedOptions.CaptureState)
	self:_cancelCameraAction()
	self:_stopFocusTracking()

	local minZoomDistance = resolvedOptions.MinZoomDistance or self._player.CameraMinZoomDistance
	local maxZoomDistance = resolvedOptions.MaxZoomDistance or self._player.CameraMaxZoomDistance
	assertNonNegativeNumber(minZoomDistance, "MinZoomDistance")
	assertNonNegativeNumber(maxZoomDistance, "MaxZoomDistance")
	assert(minZoomDistance <= maxZoomDistance, "CameraKit: MinZoomDistance cannot exceed MaxZoomDistance")

	local camera = self:_getCamera()
	camera.CameraSubject = subject
	camera.CameraType = resolvedOptions.CameraType or Enum.CameraType.Custom
	self._player.CameraMinZoomDistance = minZoomDistance
	self._player.CameraMaxZoomDistance = maxZoomDistance
end

--//////////////////////////////////////////////////////////////////////////////
-- Public field-of-view API
--//////////////////////////////////////////////////////////////////////////////

function CameraKit:SetFieldOfView(fieldOfView: number, options: FieldOfViewOptions?): CameraAction
	self:_assertAlive()
	assert(fieldOfView >= 1 and fieldOfView <= 120, "CameraKit: FieldOfView must be between 1 and 120")

	local resolvedOptions: FieldOfViewOptions = options or {}
	if resolvedOptions.CaptureState == true then
		self:_captureIfNeeded(true)
	end

	local duration = resolvedOptions.Duration or DEFAULT_FOV_DURATION
	assertNonNegativeNumber(duration, "FieldOfView duration")

	self:_cancelFieldOfViewAction()

	local tweenInfo = self:_buildTweenInfo(
		duration,
		resolvedOptions.TweenInfo,
		resolvedOptions.EasingStyle,
		resolvedOptions.EasingDirection
	)

	local action: ActionInternal
	action = CameraActionImpl.new(function()
		if self._fovAction == action then
			self:_cancelFieldOfViewAction()
		else
			action:_finish("Cancelled")
		end
	end)

	self._fovAction = action
	self._fovThread = task.spawn(function()
		local playbackState = self:_runFieldOfViewTween(action, fieldOfView, tweenInfo)
		if playbackState ~= Enum.PlaybackState.Completed or self._fovAction ~= action then
			return
		end

		self._fovAction = nil
		self._fovThread = nil
		action:_finish("Completed")
	end)

	return action
end

function CameraKit:PulseFieldOfView(amount: number, options: FieldOfViewPulseOptions?): CameraAction
	self:_assertAlive()

	local resolvedOptions: FieldOfViewPulseOptions = options or {}
	if resolvedOptions.CaptureState == true then
		self:_captureIfNeeded(true)
	end

	local attackDuration = resolvedOptions.AttackDuration or DEFAULT_FOV_PULSE_ATTACK
	local holdDuration = resolvedOptions.HoldDuration or 0
	local releaseDuration = resolvedOptions.ReleaseDuration or DEFAULT_FOV_PULSE_RELEASE

	assertNonNegativeNumber(attackDuration, "AttackDuration")
	assertNonNegativeNumber(holdDuration, "HoldDuration")
	assertNonNegativeNumber(releaseDuration, "ReleaseDuration")

	self:_cancelFieldOfViewAction()

	local camera = self:_getCamera()
	local startingFieldOfView = camera.FieldOfView
	local peakFieldOfView = math.clamp(startingFieldOfView + amount, 1, 120)
	local attackTweenInfo = TweenInfo.new(
		attackDuration,
		resolvedOptions.AttackEasingStyle or Enum.EasingStyle.Quad,
		resolvedOptions.AttackEasingDirection or Enum.EasingDirection.Out
	)
	local releaseTweenInfo = TweenInfo.new(
		releaseDuration,
		resolvedOptions.ReleaseEasingStyle or Enum.EasingStyle.Quint,
		resolvedOptions.ReleaseEasingDirection or Enum.EasingDirection.Out
	)

	local action: ActionInternal
	action = CameraActionImpl.new(function()
		if self._fovAction == action then
			self:_cancelFieldOfViewAction()
		else
			action:_finish("Cancelled")
		end
	end)

	self._fovAction = action
	self._fovThread = task.spawn(function()
		local playbackState = self:_runFieldOfViewTween(action, peakFieldOfView, attackTweenInfo)
		if playbackState ~= Enum.PlaybackState.Completed or self._fovAction ~= action then
			return
		end

		if holdDuration > 0 then
			task.wait(holdDuration)
			if self._fovAction ~= action then
				return
			end
		end

		playbackState = self:_runFieldOfViewTween(action, startingFieldOfView, releaseTweenInfo)
		if playbackState ~= Enum.PlaybackState.Completed or self._fovAction ~= action then
			return
		end

		self._fovAction = nil
		self._fovThread = nil
		action:_finish("Completed")
	end)

	return action
end

--//////////////////////////////////////////////////////////////////////////////
-- Public additive VFX API
--//////////////////////////////////////////////////////////////////////////////

function CameraKit:Shake(options: ShakeOptions?): CameraAction
	self:_assertAlive()

	local resolvedOptions: ShakeOptions = options or {}
	local duration = resolvedOptions.Duration or DEFAULT_SHAKE_DURATION
	local magnitude = resolvedOptions.Magnitude or DEFAULT_SHAKE_MAGNITUDE
	local rotationMagnitude = resolvedOptions.RotationMagnitude or DEFAULT_SHAKE_ROTATION
	local frequency = resolvedOptions.Frequency or DEFAULT_SHAKE_FREQUENCY
	local fadeIn = resolvedOptions.FadeIn or 0
	local fadeOut = resolvedOptions.FadeOut or math.min(DEFAULT_SHAKE_FADE_OUT, duration)
	local seed = resolvedOptions.Seed or Random.new():NextNumber(-1000, 1000)

	assertNonNegativeNumber(duration, "Shake Duration")
	assertNonNegativeNumber(magnitude, "Shake Magnitude")
	assertNonNegativeNumber(rotationMagnitude, "Shake RotationMagnitude")
	assertPositiveNumber(frequency, "Shake Frequency")
	assertNonNegativeNumber(fadeIn, "Shake FadeIn")
	assertNonNegativeNumber(fadeOut, "Shake FadeOut")

	return self:_addEffect(duration, function(elapsed)
		local envelope = getEffectEnvelope(elapsed, duration, fadeIn, fadeOut)
		local phase = elapsed * frequency

		local position = Vector3.new(
			math.noise(seed, phase, 0),
			math.noise(seed + 17.17, phase, 0),
			math.noise(seed + 41.73, phase, 0)
		) * magnitude * envelope

		local rotation = Vector3.new(
			math.noise(seed + 73.11, phase, 0),
			math.noise(seed + 101.91, phase, 0),
			math.noise(seed + 149.37, phase, 0)
		) * rotationMagnitude * envelope

		return CFrame.new(position)
			* CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))
	end)
end

function CameraKit:Recoil(options: RecoilOptions?): CameraAction
	self:_assertAlive()

	local resolvedOptions: RecoilOptions = options or {}
	local duration = resolvedOptions.Duration or DEFAULT_RECOIL_DURATION
	local position = resolvedOptions.Position or DEFAULT_RECOIL_POSITION
	local rotation = resolvedOptions.Rotation or DEFAULT_RECOIL_ROTATION
	local easingStyle = resolvedOptions.EasingStyle or Enum.EasingStyle.Quad
	local easingDirection = resolvedOptions.EasingDirection or Enum.EasingDirection.Out

	assertNonNegativeNumber(duration, "Recoil Duration")

	return self:_addEffect(duration, function(elapsed: number)
		local alpha = math.clamp(elapsed / duration, 0, 1)
		local weight = 1 - TweenService:GetValue(alpha, easingStyle, easingDirection)
		local currentPosition = position * weight
		local currentRotation = rotation * weight

		return CFrame.new(currentPosition)
			* CFrame.Angles(
				math.rad(currentRotation.X),
				math.rad(currentRotation.Y),
				math.rad(currentRotation.Z)
			)
	end)
end

function CameraKit:StopEffects()
	self:_assertAlive()
	self:_cancelAllEffects()
end

--//////////////////////////////////////////////////////////////////////////////
-- Restore and lifecycle
--//////////////////////////////////////////////////////////////////////////////

function CameraKit:Restore(state: CameraState?, options: RestoreOptions?): CameraAction
	self:_assertAlive()

	local restoreState = state or self._savedState
	assert(restoreState, "CameraKit: no camera state is available to restore")

	local resolvedOptions: RestoreOptions = options or {}
	local duration = resolvedOptions.Duration
		or (resolvedOptions.TweenInfo and resolvedOptions.TweenInfo.Time)
		or 0
	assertNonNegativeNumber(duration, "restore Duration")

	self:_cancelCameraAction()
	self:_cancelFieldOfViewAction()
	self:_cancelAllEffects()

	local action: ActionInternal
	action = CameraActionImpl.new(function()
		if self._cameraAction == action then
			self:_cancelCameraAction()
		else
			action:_finish("Cancelled")
		end
	end)

	self._cameraAction = action

	local tweenInfo = self:_buildTweenInfo(
		duration,
		resolvedOptions.TweenInfo,
		resolvedOptions.EasingStyle,
		resolvedOptions.EasingDirection
	)

	if tweenInfo.Time == 0 then
		self:_applyState(restoreState)
		self._cameraAction = nil

		if resolvedOptions.ClearSavedState ~= false and restoreState == self._savedState then
			self._savedState = nil
		end

		action:_finish("Completed")
		return action
	end

	self:_prepareScriptableCamera()

	self._cameraThread = task.spawn(function()
		local playbackState = self:_runCameraTween(action, {
			CFrame = restoreState.CFrame,
			FieldOfView = restoreState.FieldOfView,
		}, tweenInfo)

		if playbackState ~= Enum.PlaybackState.Completed or self._cameraAction ~= action then
			return
		end

		self._cameraAction = nil
		self._cameraThread = nil
		self:_applyState(restoreState)

		if resolvedOptions.ClearSavedState ~= false and restoreState == self._savedState then
			self._savedState = nil
		end

		action:_finish("Completed")
	end)

	return action
end

function CameraKit:Stop(options: StopOptions?): CameraAction?
	self:_assertAlive()

	local resolvedOptions: StopOptions = options or {}
	self:_cancelCameraAction()

	if resolvedOptions.StopFieldOfView ~= false then
		self:_cancelFieldOfViewAction()
	end

	if resolvedOptions.StopEffects ~= false then
		self:_cancelAllEffects()
	end

	if resolvedOptions.Restore then
		return self:Restore(nil, resolvedOptions.RestoreOptions)
	end

	return nil
end

function CameraKit:IsActive(): boolean
	self:_assertAlive()
	return self._cameraAction ~= nil or self._fovAction ~= nil or #self._effects > 0
end

function CameraKit:Destroy(restoreCamera: boolean?)
	if self._destroyed then
		return
	end

	self._destroyed = true

	self:_cancelCameraAction()
	self:_cancelFieldOfViewAction()
	self:_cancelAllEffects()

	if restoreCamera ~= false and self._savedState then
		self:_applyState(self._savedState)
	else
		self:_stopFocusTracking()
	end

	self._savedState = nil

	if self._currentCameraConnection then
		self._currentCameraConnection:Disconnect()
		self._currentCameraConnection = nil
	end
end

return CameraKit
