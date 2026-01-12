sModName = "maa"
--------------------------------------------------------------------------------
function getInstructions()
	local sModTitle = Interface.getString("maa_window_title")
	local sModDesc = MobActionsManager.tSkipTurnEffect.sName
	local sInstructions = "<p><b>These instructions will dissapear when the conditions are right.</b></p>"
	sInstructions = sInstructions .. "<p>The Combat Tracker must have an NPC as the Active Combatant.</p>"
	sInstructions = sInstructions .. "<p>The NPC must be targetting <b>one</b> creature.  "..sModTitle.." will count the NPCs that share the same base npc record, have the same initiative, and are also targetting the same target.</p>"
	sInstructions = sInstructions .. "<p>Use the action selector to cycle through the Active NPC's actions.</p>"
	sInstructions = sInstructions .. "<p>Using any method, initiate the mob attack (or cast, or saving throw, ...) on the Active Combatant.  Some methods are: double click the ATK: string in the Mobbers window; double click the SAVEVS: string the Combat Tracker's active NPC's Spells list; drag and drop from the NPC's record onto the victim's token on the combat map image.</p>"
	sInstructions = sInstructions .. "<p>Opening and re-opening the "..sModTitle.." window resets all tracked attacks.</p>"
--	sInstructions = sInstructions .. "<p><b>Feature:</b> The modifier stack will be locked and applied to every roll performed during a "..sModDesc.."  For ADV/DIS on Attack rolls, this works how one would expect.  For +/- 2/5 on Attack rolls, the Damage has the same modifier applied.</p>"
	return sInstructions
end
--------------------------------------------------------------------------------
bDebug = true
_sPadding = ""
function dbg(...)
	if self.bDebug and Session.IsHost then
		local sDebugString = unpack(arg)
		if (string.sub(sDebugString,1,2) == "--" ) then
			_sPadding = string.sub(_sPadding,1,(string.len(_sPadding))-2)

		end
		print("["..self.sModName.."] ".._sPadding..sDebugString)
		if (string.sub(sDebugString,1,2) == "++" ) then
			_sPadding = _sPadding .. "  "
		end
	end
end
function dump(sMsg,xVar,sKey,sIndent)
	if not self.bDebug then return end
	local sKey    = sKey       or "_"
	local sIndent = sIndent    or ""
	local sType   = type(xVar) or "nil"
	self.dbg(sMsg..sIndent.." sKey=["..sKey.."] type(xVar)=["..sType.."] tostring(xVar)=["..tostring(xVar).."]")
	if sType == "table" then
		local k,v; for k,v in pairs(xVar) do
			self.dump(sMsg,v,sKey.."."..k,sIndent.." ")
		end
	end
end
function chat(...)
	if self.bDebug and Session.IsHost then
		Comm.addChatMessage({text="["..self.sModName.."] "..unpack(arg)})
	end
end
--------------------------------------------------------------------------------
-- ToDo: this can be refactored using self["OOBMSG_".."..."] because self is a dict.
OOBMSG_TokenWidgetManager = "OOBMSG_"..sModName.."_TokenWidgetManager"
OOBMSG_AutoEndTurn        = "OOBMSG_"..sModName.."_AutoEndTurn"
function initOOB()
	OOBManager.registerOOBMsgHandler(self.OOBMSG_TokenWidgetManager, self.recvTokenCommand)
	OOBManager.registerOOBMsgHandler(self.OOBMSG_AutoEndTurn,        self.recvAutoEndTurn)
end
--------------------------------------------------------------------------------
local function __packTokenVisibility(tData,tInto)
	local sCTNode,iVisible
	tInto.sCTNodeList  = ""
	tInto.sVisibleList = ""
	for sCTNode,iVisible in pairs(tData) do
		tInto.sCTNodeList  = tInto.sCTNodeList..sCTNode  .."|"
		tInto.sVisibleList = tInto.sVisibleList..iVisible.."|"
	end
end
--------------------------------------------------------------------------------
local function __unpackTokenVisibility(tData,tFrom)
	local i
	local aCTNodeList  = StringManager.split((tFrom.sCTNodeList  or ""), "|", true)
	local aVisibleList = StringManager.split((tFrom.sVisibleList or ""), "|", true)
	if aCTNodeList == nil or #aCTNodeList == 0 then return end
	for i = 1,#aCTNodeList do
		local iVisible = tonumber(aVisibleList[i])
		if iVisible ~= nil then
			tData[aCTNodeList[i]] = iVisible
		end
	end
end
--------------------------------------------------------------------------------
function recvTokenCommand(msgOOB)
	local tokenCT,bVisible
	if msgOOB and msgOOB.type and msgOOB.type == OOBMSG_TokenWidgetManager and msgOOB.instr then
		if msgOOB.instr == "resetTokenWidgets" then
			local k,n
			for k,n in pairs(DB.getChildren(CombatManager.getTrackerPath())) do
				tokenCT = CombatManager.getTokenFromCT(n)
				if tokenCT then
					bVisible = CombatManager.isActive(n)
					TokenManager.setActiveWidget(tokenCT,nil,bVisible)
				end
			end
		elseif msgOOB.instr == "setTokenWidgets" then
			local tVisibility = {}
			__unpackTokenVisibility(tVisibility,msgOOB)
			for sActorPath,iVisible in pairs(tVisibility) do
				local bVisible = iVisible == 1
				tokenCT = CombatManager.getTokenFromCT(DB.findNode(sActorPath))
				if tokenCT then
					if Session.IsHost then tokenCT.setPublicVision(bVisible) end
					TokenManager.setActiveWidget(tokenCT,nil,bVisible)
				end
			end
		end
	end
end
--------------------------------------------------------------------------------
function sendTokenUpdate(tVisibility)
	local msgOOB = {}
	msgOOB.type = OOBMSG_TokenWidgetManager
	if type(tVisibility) ~= "table" then
		msgOOB.instr = "resetTokenWidgets"
	else
		msgOOB.instr = "setTokenWidgets"
		__packTokenVisibility(tVisibility,msgOOB)
	end
	Comm.deliverOOBMessage(msgOOB)
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
function recvAutoEndTurn()
	CombatManager.nextActor()
end
--------------------------------------------------------------------------------
function sendAutoEndTurn()
	Comm.deliverOOBMessage({type = OOBMSG_AutoEndTurn, recipients = ""})
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
function onInit()
	self.dbg("++MobManager:onInit()")
	if super and super.onInit then super.onInit() end
	self.initOOB()
	if Session.IsHost then
		DesktopManager.registerSidebarToolButton({
			tooltipres = "maa_window_title",
			path       = self.sModName,
			class      = self.sModName,
			sIcon      = "button_action_attack",
		})
	end
	self.dbg("--MobManager:onInit(): normal exit")
end
--------------------------------------------------------------------------------
function onClose()
	self.dbg("++MobManager:onClose()")
	DB.deleteNode(self.sModName)
	self.dbg("--MobManager:onClose(): normal exit")
end
--------------------------------------------------------------------------------
