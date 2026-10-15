



local HyperTextNaviHelper = {}








function HyperTextNaviHelper.WrapHyperTextData(uiText)
    local textData = {
        uiText = uiText,
        
        linkDataList = {},
        curFocusIndex = 1,
        
        lineLinkDataListMap = {},
        lineOrderList = {},
    }
    local textInfo = uiText.textInfo
    local linkLength = textInfo.linkCount
    
    if linkLength > 0 then
        for luaIndex = 1, linkLength do
            local csIndex = CSIndex(luaIndex)
            local hyperlinkInfo = textInfo.linkInfo[csIndex]
            local _, linkId = uiText:TryGetLinkId(csIndex)
            
            local startCharIndex = hyperlinkInfo.linkTextfirstCharacterIndex
            local startCharInfo = textInfo.characterInfo[startCharIndex]
            local startLineNumber = startCharInfo.lineNumber
            local endCharIndex = startCharIndex + hyperlinkInfo.linkTextLength - 1
            local endCharInfo = textInfo.characterInfo[endCharIndex]
            local endLineNumber = endCharInfo.lineNumber
            
            local linkData = {
                index = luaIndex,
                linkId = linkId,
                lineOrder = 1,
                
                startCharIndex = startCharIndex,
                startLineNumber = startLineNumber,
                startXPos = startCharInfo.topLeft.x,
                
                endCharIndex = endCharIndex,
                endLineNumber = endLineNumber,
                endXPos = endCharInfo.topRight.x,
            }
            table.insert(textData.linkDataList, linkData)
            
            local lineLinkDataList = textData.lineLinkDataListMap[startLineNumber]
            if lineLinkDataList == nil then
                lineLinkDataList = {}
                textData.lineLinkDataListMap[startLineNumber] = lineLinkDataList
                table.insert(textData.lineOrderList, startLineNumber)
            end
            linkData.lineOrder = #textData.lineOrderList
            table.insert(lineLinkDataList, linkData)
            
            if startLineNumber ~= endLineNumber then
                lineLinkDataList = textData.lineLinkDataListMap[endLineNumber]
                if lineLinkDataList == nil then
                    lineLinkDataList = {}
                    textData.lineLinkDataListMap[endLineNumber] = lineLinkDataList
                    table.insert(textData.lineOrderList, endLineNumber)
                end
                table.insert(lineLinkDataList, linkData)
            end
        end
    end
    return textData
end



function HyperTextNaviHelper.GetNextLinkIndexDown(textData)
    local curFocusLinkData = textData.linkDataList[textData.curFocusIndex]
    if not curFocusLinkData then
        return -1
    end
    local nextLineOrder = curFocusLinkData.lineOrder + 1
    local nextIndex = -1
    
    if nextLineOrder > #textData.lineOrderList then
        return nextIndex    
    end
    
    for order = nextLineOrder, #textData.lineOrderList do
        local lineNumber = textData.lineOrderList[order]
        local lineLinkDataList = textData.lineLinkDataListMap[lineNumber]
        local cachedPosDelta = 0
        local curPosDelta = 0
        for _, linkData in pairs(lineLinkDataList) do
            
            if linkData.index ~= curFocusLinkData.index then
                
                if lineNumber == linkData.startLineNumber then
                    curPosDelta = math.abs(linkData.startXPos - curFocusLinkData.startXPos)
                else
                    curPosDelta = math.abs(linkData.endXPos - curFocusLinkData.startXPos)
                end
                
                if nextIndex < 1 or curPosDelta < cachedPosDelta then
                    nextIndex = linkData.index
                    cachedPosDelta = curPosDelta
                end
            end
        end
        
        if nextIndex > 0 then
            break
        end
    end
    return nextIndex
end



function HyperTextNaviHelper.GetNextLinkIndexUp(textData)
    local curFocusLinkData = textData.linkDataList[textData.curFocusIndex]
    if not curFocusLinkData then
        return -1
    end
    local nextLineOrder = curFocusLinkData.lineOrder - 1
    local nextIndex = -1
    
    if nextLineOrder < 1 then
        return nextIndex    
    end
    
    for order = nextLineOrder, 1, -1 do
        local lineNumber = textData.lineOrderList[order]
        local lineLinkDataList = textData.lineLinkDataListMap[lineNumber]
        local cachedPosDelta = 0
        local curPosDelta = 0
        for _, linkData in pairs(lineLinkDataList) do
            
            if linkData.index ~= curFocusLinkData.index then
                
                if lineNumber == linkData.startLineNumber then
                    curPosDelta = math.abs(linkData.startXPos - curFocusLinkData.startXPos)
                else
                    curPosDelta = math.abs(linkData.endXPos - curFocusLinkData.startXPos)
                end
                
                if nextIndex < 1 or curPosDelta < cachedPosDelta then
                    nextIndex = linkData.index
                    cachedPosDelta = curPosDelta
                end
            end
        end
        
        if nextIndex > 0 then
            break
        end
    end
    return nextIndex
end


_G.HyperTextNaviHelper = HyperTextNaviHelper
return HyperTextNaviHelper
