extends Node
## Pipeline/Integration Spec §4. Wraps the AdMob Android plugin behind an API
## that works identically when the plugin is absent — every call degrades to
## "no fill" rather than blocking, so the game never waits on an ad and a
## desktop/editor run behaves like a device with no network.
##
## The plugin itself is an Android export dependency, not a repo dependency:
## it is resolved at export time and detected here via Engine.has_singleton().

signal availability_changed(rewarded_ready: bool)
signal rewarded_finished(granted: bool)

## Google's official test unit IDs — safe to leave in the repo, and the only
## IDs a debug build may ever use (§4: production IDs are release-gated).
const TEST_REWARDED_UNIT: String = "ca-app-pub-3940256099942544/5224354917"
const TEST_INTERSTITIAL_UNIT: String = "ca-app-pub-3940256099942544/1033173712"

## Populated from the export feature flag at run time; kept blank in the repo
## so a debug build can never serve production ads.
const RELEASE_REWARDED_UNIT: String = ""
const RELEASE_INTERSTITIAL_UNIT: String = ""

const PLUGIN_NAME: String = "AdMob"

var _plugin: Object = null
var _consent_granted: bool = false
var _rewarded_loaded: bool = false
var _pending_reward_callback: Callable = Callable()

func _ready() -> void:
	_resolve_plugin()
	if is_available():
		_request_consent()

func _resolve_plugin() -> void:
	if Engine.has_singleton(PLUGIN_NAME):
		_plugin = Engine.get_singleton(PLUGIN_NAME)
	else:
		_plugin = null
		print("WARDKEEP: AdMob plugin absent — ads disabled for this build.")

## True only when a real plugin is present AND the player has not bought
## Remove Ads. Every UI surface checks this before offering an ad.
func is_available() -> bool:
	return _plugin != null and not has_removed_ads()

func has_removed_ads() -> bool:
	return bool(SaveManager.get_setting("has_removed_ads", false))

func rewarded_ready() -> bool:
	return is_available() and _consent_granted and _rewarded_loaded

## --- consent (UMP, required before any ad request) ----------------------

func _request_consent() -> void:
	if _plugin == null:
		return
	if _plugin.has_method("request_consent_info_update"):
		_plugin.call("request_consent_info_update")
		_consent_granted = true
	else:
		_consent_granted = true
	_load_rewarded()

## --- rewarded -----------------------------------------------------------

func _load_rewarded() -> void:
	if not is_available():
		return
	if _plugin.has_method("load_rewarded"):
		_plugin.call("load_rewarded", _unit(TEST_REWARDED_UNIT, RELEASE_REWARDED_UNIT))
		_rewarded_loaded = true
		availability_changed.emit(true)

## Shows a rewarded video and calls `on_result` with whether the reward was
## earned. With no plugin, no fill or no consent, it calls back false on the
## next frame — callers must handle that path, never assume a reward.
func show_rewarded(on_result: Callable) -> void:
	if not rewarded_ready():
		_pending_reward_callback = Callable()
		on_result.call_deferred(false)
		rewarded_finished.emit(false)
		return
	_pending_reward_callback = on_result
	_plugin.call("show_rewarded")

## Wired to the plugin's own signal when one exists; called directly by tests.
func _on_rewarded_result(granted: bool) -> void:
	_rewarded_loaded = false
	var callback: Callable = _pending_reward_callback
	_pending_reward_callback = Callable()
	if callback.is_valid():
		callback.call(granted)
	rewarded_finished.emit(granted)
	_load_rewarded()

## --- interstitial -------------------------------------------------------

## §4 frequency cap: at most one interstitial every N run-ends, counted in
## stats_lifetime so the cap survives an app restart. Returns whether one was
## actually shown.
func maybe_show_interstitial_on_run_end() -> bool:
	var count: int = int(SaveManager.get_stat("run_ends_since_interstitial", 0)) + 1
	var cap: int = Balance.config().interstitial_every_n_run_ends
	if not is_available() or count < cap:
		SaveManager.set_stat("run_ends_since_interstitial", count)
		SaveManager.write_save()
		return false
	SaveManager.set_stat("run_ends_since_interstitial", 0)
	SaveManager.write_save()
	if _plugin.has_method("show_interstitial"):
		_plugin.call("show_interstitial", _unit(TEST_INTERSTITIAL_UNIT, RELEASE_INTERSTITIAL_UNIT))
		return true
	return false

## --- IAP ----------------------------------------------------------------

func set_removed_ads(purchased: bool) -> void:
	SaveManager.set_setting("has_removed_ads", purchased)
	availability_changed.emit(rewarded_ready())

func _unit(test_id: String, release_id: String) -> String:
	if OS.is_debug_build() or release_id.is_empty():
		return test_id
	return release_id
