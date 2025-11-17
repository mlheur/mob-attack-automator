DEBUG = true

function dbg(...) if MAA.DEBUG then print("[MAA] "..unpack(arg)) end end

function CountAttackers(nActor)
	MAA.dbg("++MAA:CountAttackers()")
	local sClass,sLink = nActor.getChild("sourcelink").getValue()
	local nInit        = nActor.getChild("initresult").getValue()
	MAA.dbg("  MAA:CountAttackers(): sClass=["..sClass.."] sLink=["..sLink.."] nInit=["..nInit.."]")
	local nAttackers = 0
	for sNodeID,nNPC in pairs(DB.getChildren("combattracker.list")) do
		local sClassNPC  = nNPC.getChild("link").getValue()
		if sClassNPC == "npc" then
			local _,sLinkNPC = nNPC.getChild("sourcelink").getValue()
			local nInitNPC   = nNPC.getChild("initresult").getValue()
			if sClassNPC == nil then sClassNPC = "nil" end
			if sLinkNPC == nil then sLinkNPC = "nil" end
			if nInitNPC == nil then nInitNPC = "nil" end
			MAA.dbg("  MAA:CountAttackers(): sClassNPC=["..sClassNPC.."] sLinkNPC=["..sLinkNPC.."] nInitNPC=["..nInitNPC.."]")
			if sClassNPC == sClass and sLinkNPC == sLink and nInitNPC == nInit then
				MAA.dbg("  MAA:CountAttackers(): BUMP!")
				nAttackers = nAttackers + 1
			end
		end
	end

	MAA.dbg("--MAA:CountAttackers(): nAttackers=["..nAttackers.."]")
	return nAttackers
end

--------------------------------------------------------------------------------
-- onButtonPressed
--------------------------------------------------------------------------------
function processRoll(hSubWnd, hWnd)
	MAA.dbg("++MAA:processRoll()")
	MAA.dbg("--MAA:processRoll()")
end

--------------------------------------------------------------------------------
-- Handling the combobox for the attack actions on the NPC
--------------------------------------------------------------------------------
function initAttackAction(hSubWnd, hWnd)
	MAA.dbg("++MAA:initAttackAction()")
	local nActiveCT = CombatManager.getActiveCT()
	local nActions = nActiveCT.getChild("actions")
	if nActions == nil then
		MAA.dbg("--MAA:initAttackAction(): FATAL, PC has no actions to choose from")
		return
	end
	local sAction = ""
	for k,v in pairs(nActions.getChildren()) do
		sAction = v.getChild("name").getValue()
		hSubWnd.addItem(sAction)
	end
	hSubWnd.setValue(sAction)
	MAA.dbg("--MAA:initAttackAction()")
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

	local nActor = CombatManager.getActiveCT()
	if nActor == nil then
		MAA.dbg("--MAA:initSubwindow(): FAILED: nActor is nil")
		return
	end

	local sActor = nActor.getPath()
	if sActor == nil then
		MAA.dbg("--MAA:initSubwindow(): FAILED: sActor is nil")
		return
	end

	local nAttackers = 1
	if sName == "MAA_target" then
		local sTargetCT = nil
		local nActiveCT_targets = nActor.getChild("targets")
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
	else
		sClass = nActor.getChild("link").getValue()
		if sClass == "npc" then
			nAttackers = CountAttackers(nActor)
		end
	end

	hWnd["qty_attackers"].setValue(nAttackers)

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