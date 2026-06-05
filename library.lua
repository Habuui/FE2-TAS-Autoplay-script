local TAS_LIBRARY = {}

function TAS_LIBRARY.getTAS(mapName)
    local tasData = nil
    -- Cada mapa que você quiser adicionar:
    if mapName == "nome_do_mapa_1" then
        tasData = {
            -- Bloco exportado pelo seu script (use o botão "📤 EXPORTAR TAS")
        }
    elseif mapName == "nome_do_mapa_2" then
        tasData = {
            -- Outro bloco
        }
    end
    return tasData
end

return TAS_LIBRARY
