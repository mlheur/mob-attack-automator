--------------------------------------------------------------------------------
function onDrop(x,y,oDragInfo)
	parentcontrol.window.onDropOnVictim(x,y,oDragInfo)
end
--------------------------------------------------------------------------------
function onValueChanged()
	MobManager.dbg("++maa_actor:onValueChanged()")
	local sNewFrame = "ctentrybox"
	local sClass,sCTNode = parentcontrol.getValue()
	MobManager.dbg("maa_actor:onValueChanged(): sClass=["..sClass.."] sCTNode=["..sCTNode.."]")
	local sFaction = DB.getValue(sCTNode..".friendfoe","")
	if sFaction ~= "" then sNewFrame = sNewFrame.."_"..sFaction end
	self.setFrame(sNewFrame)
	MobManager.dbg("--maa_actor:onValueChanged(): normal exit, sFaction=["..sFaction.."] sNewFrame=["..sNewFrame.."]")
end
--------------------------------------------------------------------------------
function onInit()
	MobManager.dbg("++maa_actor:onInit()")
	local sActorType = parentcontrol.getName()
	local sActorLabel = Interface.getString(MobManager.sModName.."_label_"..sActorType,"")
	label.setValue(sActorLabel)
	self.onValueChanged()
	MobManager.dbg("--maa_actor:onInit(): normal exit, sActorLabel=["..sActorLabel.."]")
end
--------------------------------------------------------------------------------
