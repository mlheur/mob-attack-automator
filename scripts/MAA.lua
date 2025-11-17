DEBUG = true;

function dbg(...) if MAA.DEBUG then print("[MAA] "..unpack(arg)) end end

function initSubwindow(hSubWnd, hWnd)
	MAA.dbg("++MAA:initSubwindow()");

	local sName = hSubWnd.getName()
	MAA.dbg("  MAA:initSubwindow(): sName=hSubWnd.getName()==["..sName.."]");
	local oClass,oValue = hSubWnd.getValue()

	local sActiveCT = CombatManager.getActiveCT().getPath()
	local sActor = sActiveCT

	if sActiveCT == nil then
		MAA.dbg("--MAA:initSubwindow(): FAILED: sActiveCT is nil");
		return
	end

	if sName == "MAA_target" then
		local sTargetCT = nil
		local nActiveCT_targets = DB.findNode(sActiveCT).getChild("targets")
		if nActiveCT_targets == nil then
			MAA.dbg("--MAA:initSubwindow(): FAILED: nActiveCT_targets is nil");
			return
		end
		for sName,sNode in pairs(nActiveCT_targets.getChildren()) do
			MAA.dbg("  MAA:initSubwindow(): sName=["..sName.."], sNode=["..sNode.getPath().."]")
			sTargetCT = DB.getValue(sNode,"noderef")
			break
		end
		if sTargetCT == nil then
			MAA.dbg("--MAA:initSubwindow(): FAILED: sTargetCT is nil");
			return
		end
		sActor = sTargetCT
	end

	hSubWnd.setValue(oClass,sActor)
	MAA.dbg("  MAA:initSubwindow(): oClass=["..oClass.."] sActor=["..sActor.."]");

	MAA.dbg("--MAA:initSubwindow(): Success");
end

--------------------------------------------------------------------------------
-- Main Entry Point
--------------------------------------------------------------------------------
function onInit()
	MAA.dbg("++MAA:onInit()");
	if User.isHost() then
		local tButton = {}
		tButton["tooltipres"] = "MAA_window_title"
		tButton["class"]      = "MAA"
		tButton["path"]       = "MAA"
		tButton["sIcon"]      = "button_action_attack"
		DesktopManager.registerSidebarToolButton(tButton)
		if MAA.DEBUG then Interface.openWindow("MAA", "MAA") end
	end
	MAA.dbg("--MAA:onInit()");
end