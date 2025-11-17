DEBUG = true

function dbg(...) if MAA.DEBUG then print("[MAA] "..unpack(arg)) end end


--------------------------------------------------------------------------------
-- Handling the combobox for the attack actions on the NPC
--------------------------------------------------------------------------------
function initAttackBonus(hSubWnd, hWnd)
	MAA.dbg("++MAA:initAttackBonus()")
	local nActiveCT = CombatManager.getActiveCT()
	local nActions = nActiveCT.getChild("actions")
	for k,v in pairs(nActions.getChildren()) do
		sAction = v.getChild("name").getValue()
		hSubWnd.addItem(sAction)
	end
	updateAttackBonus(hSubWnd,hWnd)
	MAA.dbg("--MAA:initAttackBonus()")
end

function updateAttackBonus(hSubWnd, hWnd)
	MAA.dbg("++MAA:updateAttackBonus()")
	local nActiveCT = CombatManager.getActiveCT()
	local nActions = nActiveCT.getChild("actions")
	local sSelectedAction = hSubWnd.getValue()
	for k,v in pairs(nActions.getChildren()) do
		sAction = v.getChild("name").getValue()
		if sAction == sSelectedAction then
			sValue = v.getChild("value").getValue()
			
			local nStart,nEnd = string.find(sValue, "ATK: ([-+]?%d)")
			nStart = nStart + 5
			local sAtkBonus = string.sub(sValue,nStart,nEnd)

			MAA.dbg("  MAA:updateAttackBonus(): nStart=["..nStart.."] nEnd=["..nEnd.."] sAtkBonus=["..sAtkBonus.."]")

			hWnd["MAA_attacker"].subwindow["atk_bonus"].setValue(sAtkBonus)
			break
		end
	end
	MAA.dbg("--MAA:updateAttackBonus()")
end
--------------------------------------------------------------------------------
-- One function to init both Attacker and Target subwindow data from CT data.
--------------------------------------------------------------------------------
function initSubwindow(hSubWnd, hWnd)
	MAA.dbg("++MAA:initSubwindow()")

	local sName = hSubWnd.getName()
	MAA.dbg("  MAA:initSubwindow(): sName=hSubWnd.getName()==["..sName.."]")
	local oClass,oValue = hSubWnd.getValue()

	local sActor = CombatManager.getActiveCT().getPath()

	if sActor == nil then
		MAA.dbg("--MAA:initSubwindow(): FAILED: sActor is nil")
		return
	end

	if sName == "MAA_target" then
		local sTargetCT = nil
		local nActiveCT_targets = DB.findNode(sActor).getChild("targets")
		if nActiveCT_targets == nil then
			MAA.dbg("--MAA:initSubwindow(): FAILED: nActiveCT_targets is nil")
			return
		end
		for sID,sNode in pairs(nActiveCT_targets.getChildren()) do
			MAA.dbg("  MAA:initSubwindow(): sID=["..sID.."], sNode=["..sNode.getPath().."]")
			sTargetCT = DB.getValue(sNode,"noderef")
			break
		end
		if sTargetCT == nil then
			MAA.dbg("--MAA:initSubwindow(): FAILED: sTargetCT is nil")
			return
		end
		sActor = sTargetCT
	end

	hSubWnd.setValue(oClass,sActor)
	MAA.dbg("  MAA:initSubwindow(): oClass=["..oClass.."] sActor=["..sActor.."]")

	MAA.dbg("--MAA:initSubwindow(): Success")
end

--------------------------------------------------------------------------------
-- Main Entry Point
--------------------------------------------------------------------------------
function onInit()
	MAA.dbg("++MAA:onInit()")
	if User.isHost() then
		local tButton = {}
		tButton["tooltipres"] = "MAA_window_title"
		tButton["class"]      = "MAA"
		tButton["path"]       = "MAA"
		tButton["sIcon"]      = "button_action_attack"
		DesktopManager.registerSidebarToolButton(tButton)
		if MAA.DEBUG then Interface.openWindow("MAA", "MAA") end
	end
	MAA.dbg("--MAA:onInit()")
end