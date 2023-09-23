--- A li'l game engine for Playdate.
-- @module Noble

--
-- https://noblerobot.com/
--

-- Playdate libraries
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/animation"
import "CoreLibs/animator"
import "CoreLibs/object"
import "CoreLibs/ui"
import "CoreLibs/math"
import "CoreLibs/timer"
import "CoreLibs/frameTimer"
import "CoreLibs/crank"

-- We create aliases for both fun and performance reasons.
Graphics = playdate.graphics
Display = playdate.display
Geometry = playdate.geometry
Ease = playdate.easingFunctions
UI = playdate.ui
File = playdate.file
Datastore = playdate.datastore
Timer = playdate.timer

-- In lua, variables are global by default, but having a "Global" object to put
-- variables into is useful for maintaining sanity if you're coming from an OOP language.
-- It's included here for basically no reason at all. Noble Engine doesn't use it. (◔◡◔)
Global = {}

-- It all fits inside this table, oooo!
Noble = {}

-- Third-party libraries
import 'libraries/noble/libraries/Signal'
import 'libraries/noble/libraries/Sequence'

-- Noble libraries, modules, and classes.
import 'libraries/noble/utilities/Utilities'
import 'libraries/noble/modules/Noble.Animation.lua'
import 'libraries/noble/modules/Noble.Bonk.lua'
import 'libraries/noble/modules/Noble.GameData.lua'
import 'libraries/noble/modules/Noble.Input.lua'
import 'libraries/noble/modules/Noble.Settings.lua'
import 'libraries/noble/modules/Noble.Text.lua'
import 'libraries/noble/modules/Noble.Transition.lua'
import 'libraries/noble/modules/Noble.Menu.lua'
import 'libraries/noble/modules/NobleScene'
import 'libraries/noble/modules/NobleSprite'

--- Check to see if the game is transitioning between scenes.
-- Useful to control game logic that lives outside of a scene's `update()` method.
-- @field bool
Noble.isTransitioning = false

--- Show/hide the Playdate SDK's FPS counter.
-- @field bool
Noble.showFPS = false;

local currentScene = nil
local engineInitialized = false

--- Engine initialization. Run this once in your main.lua file to begin your game.
-- @tparam NobleScene StartingScene This is the scene your game begins with, such as a title screen, loading screen, splash screen, etc. **NOTE: Pass the scene's class name, not an instance of the scene.**
-- @number[opt=0] __launcherTransitionDuration If you want to transition from the final frame of your launch image sequence, enter a duration in seconds here.
-- @tparam[opt=Noble.Transition.CROSS_DISSOLVE] Noble.TransitionType __launcherTransitionType If a transition duration is set, use this transition type.
-- @tparam table[optional] __configuration Provide a table of Noble Engine configuration values. This will run `Noble.setConfig` for you at launch.
-- @see NobleScene
-- @see Noble.TransitionType
-- @see setConfig
function Noble.new(StartingScene, __launcherTransitionDuration, __launcherTransitionType, __configuration)

	math.randomseed(playdate.getSecondsSinceEpoch()) -- Set a new random seed at runtime.

	if (engineInitialized) then
		error("BONK: You can only run Noble.new() once.")
		return
	end

	-- If the user supplies a config object, we use it, otherwise, we set default values.
	if (__configuration ~= nil) then
		Noble.setConfig(__configuration)
	else
		Noble.resetConfig()
	end

	-- Screen drawing: see the Playdate SDK for details on these methods.
	Graphics.sprite.setBackgroundDrawingCallback(
		function (x, y, width, height)
			if (currentScene ~= nil) then
				-- Each scene has its own method for this. We only want to run one at a time.
                currentScene:drawBackground(x, y, width, height)
            else
				Graphics.clear(playdate.graphics.kColorBlack)
			end
		end
	)
	-- Override Playdate methods we've used already, and don't want to be used again, with Bonks!
	Graphics.sprite.setBackgroundDrawingCallback = function(callback)
		error("BONK: Don't call Graphics.sprite.setBackgroundDrawingCallback() directly. Put background drawing code in your scenes' drawBackground() methods instead.")
	end

	local transitionType = Noble.TransitionType.CUT
	if (__launcherTransitionDuration ~= nil) then
		transitionType = __launcherTransitionType or Noble.TransitionType.CROSS_DISSOLVE
	end

	-- Now that everything is set, let's-a go!
	engineInitialized = true
	Noble.transition(StartingScene, __launcherTransitionDuration, transitionType)
end

--- This checks to see if `Noble.new` has been run. It is used internally to ward off bonks.
-- @treturn bool
-- @see Noble.Bonk
function Noble.engineInitialized()
	return engineInitialized
end

-- configuration
--

local defaultConfiguration = {
	defaultTransitionDuration = 1,
	defaultTransitionHoldDuration = 0.2,
	defaultTransitionType = Noble.TransitionType.DIP_TO_BLACK,
	enableDebugBonkChecking = false,
	alwaysRedraw = true,
}
local configuration = Utilities.copy(defaultConfiguration)

--- Miscellaneous Noble Engine configuration options / default values.
-- This table cannot be edited directly. Use `Noble.getConfig` and `Noble.setConfig`.
-- @table configuration
-- @number[opt=1] defaultTransitionDuration When running `Noble.transition` if the scene transition duration is unspecified, it will take this long in seconds.
-- @number[opt=0.2] defaultTransitionHoldDuration When running `Noble.transition` (and using a hold-type transition type) if the scene transition hold duration is unspecified, it will take this long in seconds.
-- @tparam[opt=Noble.TransitionType.CROSS_DISSOLVE] Noble.TransitionType defaultTransitionType When running `Noble.transition` if the transition type is unspecified, it will use this one.
-- @bool[opt=false] enableDebugBonkChecking Noble Engine-specific errors are called "Bonks." You can set this to true during development in order to check for more of them. However, it uses resources, so you will probably want to turn it off before release.
-- @bool[opt=true] alwaysRedraw This sets the Playdate SDK method `playdate.graphics.sprite.setAlwaysRedraw`. See the Playdate SDK for details on how this function works, and the reasons you might want to set it as true or false for your project.
-- @see Noble.getConfig
-- @see Noble.setConfig
-- @see Noble.Bonk.startCheckingDebugBonks

--- Retrieve miscellaneous Noble Engine configuration options / default values
-- @return A table of all configuration values
-- @see configuration
-- @see setConfig
function Noble.getConfig()
	return configuration
end

--- Optionally customize miscellaneous Noble Engine configuration options / default values. You may run this method to change these values during runtime.
-- @tparam table __configuration This is a table with your configuration values in it.
-- @see configuration
-- @see getConfig
function Noble.setConfig(__configuration)

	if (__configuration == nil) then
		error("BONK: You cannot pass a nil value to Noble.setConfig(). If you want to reset to default values, use Noble.resetConfig().")
	end

	if (__configuration.defaultTransitionDuration ~= nil) then configuration.defaultTransitionDuration = __configuration.defaultTransitionDuration end
	if (__configuration.defaultTransitionHoldDuration ~= nil) then configuration.defaultTransitionHoldDuration = __configuration.defaultTransitionHoldDuration end
	if (__configuration.defaultTransitionType ~= nil) then configuration.defaultTransitionType = __configuration.defaultTransitionType end
	if (__configuration.enableDebugBonkChecking ~= nil) then
		configuration.enableDebugBonkChecking = __configuration.enableDebugBonkChecking
		if (configuration.enableDebugBonkChecking == true) then Noble.Bonk.enableDebugBonkChecking() end
	end
	if (__configuration.alwaysRedraw ~= nil) then
		configuration.alwaysRedraw = __configuration.alwaysRedraw
		Graphics.sprite.setAlwaysRedraw(configuration.alwaysRedraw)
	end

end

--- Reset miscellaneous Noble Engine configuration values to their defaults.
-- @see getConfig
-- @see setConfig
function Noble.resetConfig()
	Noble.setConfig(Utilities.copy(defaultConfiguration))
end

-- Transition stuff
--
local transitionSequence = nil
local previousSceneScreenCapture = nil

local currentTransition = nil

local dipToBlackPanel = Graphics.image.new(400,240, Graphics.kColorBlack)
local dipToWhitePanel = Graphics.image.new(400,240, Graphics.kColorWhite)

local metroNexusPanels = {
	Graphics.image.new(80,240, Graphics.kColorWhite),
	Graphics.image.new(80,240, Graphics.kColorWhite),
	Graphics.image.new(80,240, Graphics.kColorWhite),
	Graphics.image.new(80,240, Graphics.kColorWhite),
	Graphics.image.new(80,240, Graphics.kColorWhite)
}

local widgetSatchelPanels = {
	Graphics.image.new(400,48, Graphics.kColorWhite),
	Graphics.image.new(400,48, Graphics.kColorWhite),
	Graphics.image.new(400,48, Graphics.kColorWhite),
	Graphics.image.new(400,48, Graphics.kColorWhite),
	Graphics.image.new(400,48, Graphics.kColorWhite)
}
Graphics.lockFocus(widgetSatchelPanels[1])
Graphics.setDitherPattern(0.4, Graphics.image.kDitherTypeScreen)
Graphics.fillRect(0,0,400,48)
Graphics.lockFocus(widgetSatchelPanels[2])
Graphics.setDitherPattern(0.7, Graphics.image.kDitherTypeScreen)
Graphics.fillRect(0,0,400,48)
Graphics.lockFocus(widgetSatchelPanels[3])
Graphics.setDitherPattern(0.25, Graphics.image.kDitherTypeBayer8x8)
Graphics.fillRect(0,0,400,48)
Graphics.lockFocus(widgetSatchelPanels[4])
Graphics.setDitherPattern(0.5, Graphics.image.kDitherTypeDiagonalLine)
Graphics.fillRect(0,0,400,48)
Graphics.lockFocus(widgetSatchelPanels[5])
Graphics.setDitherPattern(0.8, Graphics.image.kDitherTypeHorizontalLine)
Graphics.fillRect(0,0,400,48)
Graphics.unlockFocus()

local queuedTransition = nil

--- Transition to a new scene (at the end of this frame).
--- This method will create a new scene, mark the previous one for garbage collection, and animate between them.
--- Additional calls to this method within the same frame (before the already-called transition begins), will override previous calls. Any calls to this method once a transtion begins will be ignored until the transition completes.
-- @tparam NobleScene NewScene The scene to transition to. Pass the scene's class, not an instance of the scene. You always transition from `Noble.currentScene`
-- @number[opt=1] __duration The length of the transition, in seconds.
-- @tparam[opt=Noble.TransitionType.DIP_TO_BLACK] Noble.TransitionType __transitionType If a transition duration is set, use this transition type.
-- @number[opt=0.2] __holdDuration For `DIP` transitions, the time spent holding at the transition midpoint. Does not increase the total transition duration, but is taken from it. So, don't make it longer than the transition duration.
-- @see Noble.isTransitioning
-- @see NobleScene
-- @see Noble.TransitionType
function Noble.transition(NewScene, __duration, __transitionType, __holdDuration)
	if (Noble.isTransitioning) then
		-- This bonk no longer throws an error (compared to previous versions of Noble Engine), but maybe it still should?
		warn("BONK: You can't start a transition in the middle of another transition, silly!")
		return -- Let's get otta here!
	elseif (queuedTransition ~= nil) then
		-- Calling this mothod multiple times between Noble.update() calls is probably not intentional behavior.
		warn("BONK: You are calling Noble.transition() multiple times within the same frame. Did you mean to do that?")
		-- We don't return here because maybe the developer *did* intened to override a previous call to Noble.transition().
	end

	-- Okay, let's pass this method's arguments into a table which we hold onto until the next Noble.update() call.
	queuedTransition = {
		NewScene = NewScene,
		duration = __duration,
		holdDuration = __holdDuration,
		transitionType = __transitionType,
	}
end

local function executeTransition(__transition)
	Noble.isTransitioning = true

	Noble.Input.setHandler(nil)			-- Disable user input. (This happens after self:ext() so exit() can query input)

	if (currentScene ~= nil) then
		currentScene:exit()				-- The current scene runs its "goodbye" code. Sprites are taken out of the simulation.
	end

	local newScene = __transition.NewScene()			-- Creates new scene object. Its init() function runs.

	local onMidpoint = nil
	if currentScene ~= nil then
		onMidpoint = function()
			currentScene:finish()
			currentScene = nil			-- Allows current scene to be garbage collected.
			currentScene = newScene			-- New scene's update loop begins.
			newScene:enter()				-- The new scene runs its "hello" code.
		end
	end

    local onComplete = function()
		if currentScene == nil then			-- The new scene runs its "hello" code.
			currentScene = newScene			-- New scene's update loop begins.
			newScene:enter()				-- The new scene runs its "hello" code.
		end
		Noble.isTransitioning = false	-- Reset
		newScene:start()				-- The new scene is now active.
	end
	local duration = __transition.duration or configuration.defaultTransitionDuration
	local holdDuration = __transition.holdDuration or configuration.defaultTransitionHoldDuration
    currentTransition = (__transition.transitionType or configuration.defaultTransitionType)(
        onComplete,
        onMidpoint,
        duration * 1000,
		holdDuration * 1000
    )
end

local transitionCanvas = Graphics.image.new(400, 240)

local function transitionUpdate()
	transitionCanvas:clear(Graphics.kColorClear)
	Graphics.lockFocus(transitionCanvas)

	currentTransition:update()

    Graphics.unlockFocus()
	Graphics.setImageDrawMode(Graphics.kDrawModeCopy)
	transitionCanvas:drawIgnoringOffset(0,0)
end

--- Get the current scene object
-- @treturn NobleScene
function Noble.currentScene()
	return currentScene
end

--- Get the name of the current scene
-- @treturn string
function Noble.currentSceneName()
	return currentScene.name
end

local crankIndicatorActive = false
local crankIndicatorForced = false

-- Game loop
--
function playdate.update()
	Noble.Input.update()				-- Check for Noble Engine-specific input methods.

	Sequence.update()					-- Update all animations that use the Sequence library.

	Graphics.sprite.update()			-- Let's draw our sprites (and backgrounds).

	if (currentScene ~= nil) then
		currentScene:update()			-- Scene-specific update code.
	end

    if (Noble.isTransitioning) then
		transitionUpdate()
	end

	crankIndicatorActive, crankIndicatorForced = Noble.Input.getCrankIndicatorStatus()
	if (crankIndicatorActive) then
		if (playdate.isCrankDocked() or crankIndicatorForced) then
			UI.crankIndicator:update()	-- Draw crank indicator (if requested).
		end
	end

	playdate.timer.updateTimers()		-- Finally, update all SDK timers.
	playdate.frameTimer.updateTimers() 	-- Update all frame timers

	if (Noble.showFPS) then
		playdate.drawFPS(4, 4)
	end

	if (Noble.Bonk.checkingDebugBonks()) then	-- Checks for code that breaks the engine.
		Noble.Bonk.checkDebugBonks()
	end

	if (queuedTransition ~= nil) then
		executeTransition(queuedTransition)
		queuedTransition = nil;
	end
end

function playdate.gameWillPause()
	if (currentScene ~= nil) then
		currentScene:pause()
	end
end

function playdate.gameWillResume()
	if (currentScene ~= nil) then
		currentScene:resume()
	end
end
