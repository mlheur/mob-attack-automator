
function onInit()
    MAA.dbg("++MAA_target:onInit()")
    local nodeActive = CombatManager.getActiveCT();
    if nodeActive == nil then return end
    nodeActiveTargetting = nodeActive.getChild("targets")
    nodeRefActiveTargetting = (nodeActiveTargetting.getChildren())[0]
    if nodeRefActiveTargetting == nil then return end
    string_nodeOfTarget = nodeRefActiveTargetting.getChild("noderef")
    nodeTarget = DB.findNode(string_nodeOfTarget)
	Interface.findWindow("MAA_target","MAA").setValue("MAA_target", nodeTarget)
end
