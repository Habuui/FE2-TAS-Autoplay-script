local TAS_LIBRARY = {}

function TAS_LIBRARY.getTAS(mapName)
    local tasData = nil
    -- Cole aqui os blocos EXPORTADOS pelo seu script, por exemplo:
    if mapName == "lobby_parkour" then
        tasData = { -- O bloco do TAS que você exportou vai aqui }
    elseif mapName == "outro_mapa" then
        tasData = { -- Outro bloco de TAS exportado }
    end
    return tasData
end

return TAS_LIBRARY
