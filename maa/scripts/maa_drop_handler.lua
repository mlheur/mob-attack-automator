function onDrop(x,y,oDragInfo)
	MobManager.dbg("++maa_drop_handler:onDrop(x=["..x.."],y=["..y.."])")
	MobManager.dump("maa_drop_handler:onDrop() dump oDragInfo",oDragInfo)
	local bDropHandled = false
	if window.bValidCombatTracker then
		ActionsManager.actionDrop(oDragInfo,window.rVictim)
		bDropHandled = true
	end
	MobManager.dbg("--maa_drop_handler:onDrop(): normal exit")
	return bDropHandled
end

-- necessary side-effect-preventers
-- function onClickDown()    MobManager.dbg("+-maa_drop_handler:onClickDown()")    return false end
-- function onClickRelease() MobManager.dbg("+-maa_drop_handler:onClickRelease()") return false end
-- function onDoubleClick()  MobManager.dbg("+-maa_drop_handler:onDoubleClick()")  return false end
-- function onDragStart()    MobManager.dbg("+-maa_drop_handler:onDragStart()")    return false end
-- function onWheel()        MobManager.dbg("+-maa_drop_handler:onWheel()")        return false end


--function onInit()
--	MobManager.dbg("++maa_drop_handler:onInit()")
--	local sPerformFunctionKey = "fnPerform"
--	-- foreach action, find the game's built-in action handler;
--	--   replace their action handler with our own wrapper.
--	MobManager.dump("maa_drop_handler:onInit() GameSystem",ActionsManager.aResultsHandler)
--	MobManager.dump("maa_drop_handler:onInit() GameSystem",GameSystem)
--	MobManager.dbg("--maa_drop_handler:onInit(): normal exit")
--end