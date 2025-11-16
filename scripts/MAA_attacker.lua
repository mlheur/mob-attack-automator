function onInit()
    MAA.dbg("++MAA_attacker:onInit()")
	local nodeActive = CombatManager.getActiveCT();
	if nodeActive == nil then return end
	Interface.findWindow("MAA_attacker","MAA").setValue("MAA_attacker", nodeActive)
end
