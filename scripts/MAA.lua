DEBUG = true
VALID_CT = true

--------------------------------------------------------------------------------
-- internal functions
--------------------------------------------------------------------------------

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
	if nActiveCT == nil then
		MAA.VALID_CT = false
		MAA.dbg("--MAA:initAttackAction(): FATAL, nActiveCT is nil")
		return
	end

	local nActions = nActiveCT.getChild("actions")
	if nActions == nil then
		MAA.VALID_CT = false
		MAA.dbg("--MAA:initAttackAction(): FATAL, PC has no actions to choose from")
		return
	end

	local sAction = ""
	for k,v in pairs(nActions.getChildren()) do
		sAction = v.getChild("name").getValue()
		hSubWnd.addItem(sAction)
	end
	if MAA.VALID_CT then
		hSubWnd.setValue(sAction)
	end

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
			local sValue = v.getChild("value").getValue()
			
			local nStart,nEnd = string.find(sValue, "ATK: ([-+]?%d)")
			nStart = nStart + 5
			local sAtkBonus = string.sub(sValue,nStart,nEnd)
			MAA.dbg("  MAA:updateAttackBonus(): nStart=["..nStart.."] nEnd=["..nEnd.."] sAtkBonus=["..sAtkBonus.."]")

			if MAA.VALID_CT then
				hWnd["MAA_attacker"].subwindow["atk_bonus"].setValue(sAtkBonus)
			end
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
		MAA.VALID_CT = false
		MAA.dbg("--MAA:initSubwindow(): FAILED: nActor is nil")
		return
	end

	local sActor = nActor.getPath()
	if sActor == nil then
		MAA.VALID_CT = false
		MAA.dbg("--MAA:initSubwindow(): FAILED: sActor is nil")
		return
	end

	local nAttackers = 1
	if sName == "MAA_target" then
		local sTargetCT = nil
		local nActiveCT_targets = nActor.getChild("targets")
		if nActiveCT_targets == nil then
			MAA.VALID_CT = false
			MAA.dbg("--MAA:initSubwindow(): FAILED: nActiveCT_targets is nil")
			return
		end
		for sID,sNode in pairs(nActiveCT_targets.getChildren()) do
			MAA.dbg("  MAA:initSubwindow(): sID=["..sID.."], sNode=["..sNode.getPath().."]")
			sTargetCT = DB.getValue(sNode,"noderef")
			break
		end
		if sTargetCT == nil then
			MAA.VALID_CT = false
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

	if MAA.VALID_CT then
		hWnd["qty_attackers"].setValue(nAttackers)
		hSubWnd.setValue(oClass,sActor)
	end

	MAA.dbg("  MAA:initSubwindow(): oClass=["..oClass.."] sActor=["..sActor.."]")
	MAA.dbg("--MAA:initSubwindow(): Success")
end

--------------------------------------------------------------------------------
-- Main Entry Point
--------------------------------------------------------------------------------
function onInit()
	MAA.dbg("++MAA:onInit()")
	MAA.VALID_CT = true
	if User.isHost() then
		local tButton = {}
		tButton["tooltipres"] = "MAA_window_title"
		tButton["class"]      = "MAA"
		tButton["path"]       = "MAA"
		tButton["sIcon"]      = "button_action_attack"
		DesktopManager.registerSidebarToolButton(tButton)
		if MAA.DEBUG then Interface.openWindow("MAA", "MAA") end
		DB.addHandler(DB.getPath(CombatManager.CT_LIST, "*.active"),  "onUpdate", RefreshAll)
		DB.addHandler(DB.getPath(CombatManager.CT_LIST, "*.targets"), "onUpdate", RefreshAll)
	end
	MAA.dbg("--MAA:onInit()")
end

function RefreshAll()
	MAA.dbg("++MAA:RefreshAll()")
	MAA.VALID_CT = true
	hWnd = Interface.findWindow("MAA","MAA")
	if hWnd == nil then
		MAA.dbg("--MAA:RefreshAll(): FAILED, hWnd is nil")
		return
	end
	initSubwindow(hWnd["MAA_attacker"],hWnd)
	initSubwindow(hWnd["MAA_target"],hWnd)
	initAttackAction(hWnd["MAA_attack_options"],hWnd)
	MAA.dbg("--MAA:RefreshAll(): Success")
end
