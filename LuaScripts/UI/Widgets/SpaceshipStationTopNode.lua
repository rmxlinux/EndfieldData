local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')

SpaceshipStationTopNode = HL.Class('SpaceshipStationTopNode', UIWidgetBase)

SpaceshipStationTopNode.m_roomId = HL.Field(HL.String) << ""

SpaceshipStationTopNode.m_roomColor = HL.Field(HL.Userdata)

SpaceshipStationTopNode._OnFirstTimeInit = HL.Override() << function(self)
end

SpaceshipStationTopNode.InitSpaceshipStationTopNode = HL.Method(HL.Table) << function(self, args)
    self:_FirstTimeInit()

    local roomId = args.roomId
    self.m_roomId = roomId
    local spaceship = GameInstance.player.spaceship
    
    local room = spaceship.rooms:get_Item(roomId)
    local roomType = SpaceshipUtils.getRoomTypeByRoomId(roomId)
    local roomTypeData = Tables.spaceshipRoomTypeTable[roomType]

    self.view.nameTxt.text = roomTypeData.name
    self.view.iconImg:LoadSprite(UIConst.UI_SPRITE_SPACESHIP_ROOM, roomTypeData.icon)

    local color = UIUtils.getColorByString(roomTypeData.color)
    self.m_roomColor = color
    self.view.colorBg.color = color

    self.view.lvDotNode:InitLvDotNode(room.lv, spaceship:GetRoomMaxLvByType(room.type), color)

    if args.onClose then
        self.view.closeBtn.onClick:AddListener(args.onClose)
    end
end

SpaceshipStationTopNode.UpdateRoomEffectInfo = HL.Method(HL.Table) << function(self, attrInfoList)
    self.view.ssRoomEffectInfoNode:InitSSRoomEffectInfoNode({
        attrInfoList = attrInfoList,
        color = self.m_roomColor,
    })
end

SpaceshipStationTopNode.UpdateRoomEffectInfoFromCS = HL.Method(HL.Userdata) << function(self, attrsMap)
    self.view.ssRoomEffectInfoNode:InitSSRoomEffectInfoNode({
        attrsMap = attrsMap,
        roomType = SpaceshipUtils.getRoomTypeByRoomId(self.m_roomId),
        color = self.m_roomColor,
    })
end

SpaceshipStationTopNode.GetRoomColor = HL.Method().Return(HL.Userdata) << function(self)
    return self.m_roomColor
end

HL.Commit(SpaceshipStationTopNode)
return SpaceshipStationTopNode

