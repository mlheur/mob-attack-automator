DEBUG = true;

function dbg(...) if MAA.DEBUG then print("[MAA] "..unpack(arg)) end end

--------------------------------------------------------------------------------
-- Main Entry Point
--------------------------------------------------------------------------------
function onInit()
	MAA.dbg("++MAA:onInit()");
	if User.isHost() then
		tButton = {}
		tButton["tooltipres"] = "MAA_window_title"
		tButton["class"]      = "MAA"
		tButton["path"]       = "MAA"
		tButton["sIcon"]      = "button_action_attack"
		DesktopManager.registerSidebarToolButton(tButton)
		if MAA.DEBUG then Interface.openWindow("MAA", "MAA") end
	end
	MAA.dbg("--MAA:onInit()");
end
