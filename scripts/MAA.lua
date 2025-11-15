DEBUG = false;

function dbg(...) if MAA.DEBUG then print("[MAA] "..unpack(arg)) end end

--------------------------------------------------------------------------------
-- Main Entry Point
--------------------------------------------------------------------------------
function onInit()
	MAA.dbg("++MAA:onInit()");
	if User.isHost() then
		tButton = {}
		tButton["tooltipres"] = "MAA_window_title"
		tButton["class"]      = "maa_wndclass_results"
		tButton["path"]       = "MAA"
		tButton["sIcon"]      = "button_action_attack"
		DesktopManager.registerSidebarToolButton(tButton)
		Interface.openWindow("maa_wndclass_results", "MAA")
	end
	MAA.dbg("--MAA:onInit()");
end
