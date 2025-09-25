-- TODO
-- Implement get status button to request status of any current death rolls
-- Possible new idea - for mode: everyone who joins rolls, single round only, and then lowest roll pays the highest roll
DeathRollsRoyceOptions = {}

--------------------------------------------------------------------------------------------------
-- Defines
--------------------------------------------------------------------------------------------------

local OUTPUT_HEADER = "|cFF673AB7DRR|r "
local MAX_AMOUNT = 1000

-- Addon ID for SendAddonMessage
local ADDON_ID = "DEATHROLLS"

-- Options
local OPTION_DEBUG = "Debug"
local OPTION_ENABLED = "Enabled"

-- Status
local STATUS_AMOUNT = "Amount"
local STATUS_PLAYER_STARTED = "PlayerStarted"
local STATUS_PLAYERS = "Players"
local STATUS_PLAYER_COUNT = "PlayerCount"
local STATUS_PLAYERS_LOSERS = "PlayersLosers"
local STATUS_ROLLS = "Rolls"
local STATUS_ROLLED = "Rolled"
local STATUS_ROUND = "Round"
local STATUS_RUNNING = "Running"
local STATUS_WINNER = "Winner"

-- Commands
local COMMAND_START = "start"
local COMMAND_RUNNING = "running"
local COMMAND_JOIN = "join"
local COMMAND_LEAVE = "leave"
local COMMAND_LOSER = "loser"
local COMMAND_STOP = "stop"
local COMMAND_CLEAR = "clear"

-- Colors
local RESET_COLOR_TEXT = "|r"
local GREEN_TEXT = "|cFF55A630"
local RED_TEXT = "|cFFEF233C"

-- Frame
local BUTTON_WIDTH = 32
local BUTTON_COUNT = 4
local BUTTON_PADING = 5
local FONT_NAME = "Fonts\\FRIZQT__.TTF"
local FONT_SIZE = 12
local FONT_OUTLINE = "OUTLINE"

--------------------------------------------------------------------------------------------------
-- State management variables
--------------------------------------------------------------------------------------------------

local DeathRollsRoyceInitialized = false
local DeathRollsRoyceStatus = {}
local DeathRollsRoyceRollFrame = nil

--------------------------------------------------------------------------------------------------
-- Helper functions
--------------------------------------------------------------------------------------------------

local function CommandOptionStatus(option, text, command)
    if (command == nil) then
        command = string.lower(text)
    end
    PrintMessage(text .. ": " .. GetOptionBoolText(option))
    PrintMessage(" - Change with /drr " .. command .. " [on | off]")
end

local function IsEnabled()
    if (DeathRollsRoyce_GetOption(OPTION_ENABLED) == 1) then
        return true
    else
        return false
    end
end

local function IsDebugEnabled()
    return DeathRollsRoyceOptions[Realm][Player][OPTION_DEBUG]
end

local function DisableOption(option)
    DeathRollsRoyceOptions[Realm][Player][option] = 0
    DeathRollsRoyce_OptionsChanged()
end

local function EnableOption(option)
    DeathRollsRoyceOptions[Realm][Player][option] = 1
    DeathRollsRoyce_OptionsChanged()
end

function DeathRollsRoyce_GetOption(option)
    return DeathRollsRoyceOptions[Realm][Player][option]
end

local function GetOptionBoolText(option)
    if DeathRollsRoyceOptions[Realm][Player][option] == 1 then
        return GREEN_TEXT .. "on" .. RESET_COLOR_TEXT
    else
        return RED_TEXT .. "off" .. RESET_COLOR_TEXT
    end
end

local function PrintMessage(msg)
    DEFAULT_CHAT_FRAME:AddMessage(OUTPUT_HEADER .. msg)
end

local function PrintDebug(msg)
    local ok, debug_enabled = pcall(IsDebugEnabled)
    if (not ok) then
        do return end
    end
    if (debug_enabled ~= 1) then
        do return end
    end

    DEFAULT_CHAT_FRAME:AddMessage(OUTPUT_HEADER .. " DEBUG " .. msg)
end

local function GetTableIndex(table, element)
    local i = 1
    for _, value in pairs(table) do
        if value == element then
            return i
        end
        i = i + 1
    end
    return nil
end

local function TableContains(table, element)
    if (GetTableIndex(table, element) ~= nil) then
        return true
    else
        return false
    end
end

-- Stolen from https://github.com/sica42/RollFor
local function CreateActionButton(frame, button_text, tooltip_text, index, onclick_function)
    local panel_width = frame:GetWidth()
    local spacing = (panel_width - (BUTTON_COUNT * BUTTON_WIDTH)) / (BUTTON_COUNT + 1)
    local button = CreateFrame("Button", nil, frame, UIParent)
    button:SetWidth(BUTTON_WIDTH)
    button:SetHeight(BUTTON_WIDTH)
    button:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", index * spacing + (index-1)*BUTTON_WIDTH, BUTTON_PADING)

    -- Set button text
    button:SetText(button_text)
    local font = button:GetFontString()
    font:SetFont(FONT_NAME, FONT_SIZE, FONT_OUTLINE)

    -- Add background 
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(button)
    bg:SetTexture(1, 1, 1, 1) -- White texture
    bg:SetVertexColor(0.2, 0.2, 0.2, 1) -- Dark gray background

    button:SetScript("OnMouseDown", function(self)
        bg:SetVertexColor(0.6, 0.6, 0.6, 1) -- Even lighter gray when pressed
    end)

    button:SetScript("OnMouseUp", function(self)
        bg:SetVertexColor(0.4, 0.4, 0.4, 1) -- Lighter gray on release
    end)

    -- Add tooltip
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetText(tooltip_text, nil, nil, nil, nil, true)
        bg:SetVertexColor(0.4, 0.4, 0.4, 1) -- Lighter gray on hover
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function(self)
        bg:SetVertexColor(0.2, 0.2, 0.2, 1) -- Dark gray when not hovered
        GameTooltip:Hide()
    end)

    -- Add functionality to the button
    button:SetScript("OnClick", function()
        onclick_function()
    end)
end

-- Stolen from https://github.com/sica42/RollFor
local function CreateCloseButton(frame)
    -- Add a close button
    local close_button = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close_button:SetWidth(32) -- Button size
    close_button:SetHeight(32) -- Button size
    close_button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5) -- Position at the top right

    -- Set textures if you want to customize the appearance
    close_button:SetNormalTexture("Interface/Buttons/UI-Panel-MinimizeButton-Up")
    close_button:SetPushedTexture("Interface/Buttons/UI-Panel-MinimizeButton-Down")
    close_button:SetHighlightTexture("Interface/Buttons/UI-Panel-MinimizeButton-Highlight")

    -- Hide the frame when the button is clicked
    close_button:SetScript("OnClick", function()
        frame:Hide()
    end)
end

-- Stolen from https://github.com/sica42/RollFor
local function CreateRollFrame()
    local frame = CreateFrame("Frame", "RollFrame", UIParent)
    frame:SetWidth(165) -- Adjust size as needed
    frame:SetHeight(220)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0) -- Position at center of the parent frame
    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(0, 0, 0, 1) -- Black background with full opacity

    frame:SetMovable(true)
    frame:EnableMouse(true)

    frame:RegisterForDrag("LeftButton") -- Only start dragging with the left mouse button
    frame:SetScript("OnDragStart", function () frame:StartMoving() end)
    frame:SetScript("OnDragStop", function () frame:StopMovingOrSizing() end)
    -- CreateCloseButton(frame)
    CreateActionButton(frame, "Join", "Join the death roll (if already started, start the death roll for someone who wasn't in the group).", 1, DeathRollsRoyce_Join)
    CreateActionButton(frame, "Leave", "Leave the death roll.", 2, DeathRollsRoyce_Leave)
    CreateActionButton(frame, "Roll", "Do the death roll.", 3, DeathRollsRoyce_Roll)

    local text_area = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text_area:SetFont("Interface\\AddOns\\LootBlare\\MonaspaceNeonFrozen-Regular.ttf", 12, "")
    text_area:SetHeight(150)
    -- text_area:SetWidth(150)
    text_area:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10)
    text_area:SetJustifyH("LEFT")
    text_area:SetJustifyV("TOP")
    frame.text_area = text_area

    frame:Hide()

    return frame
end

--------------------------------------------------------------------------------------------------
-- Command helper functions
--------------------------------------------------------------------------------------------------

function DeathRollsRoyce_Start(amount)
    if (DeathRollsRoyceStatus[STATUS_PLAYER_STARTED] ~= nil) then
        PrintMessage("There is already a death roll running, started by: " .. DeathRollsRoyceStatus[STATUS_PLAYER_STARTED] .. ". Finish that one before starting another. If something has gone wrong, to clear current death roll status: /dr clear")
    elseif (amount > MAX_AMOUNT) then
        PrintMessage("The max death roll amount is " .. MAX_AMOUNT)
    else
        PrintMessage("You started a death roll for " .. amount .. " gold.")
        SendAddonMessage(ADDON_ID, COMMAND_START .. ":" .. Player .. ":" .. amount, "RAID")
    end
end

function DeathRollsRoyce_Join()
    if (IsEnabled() == false) then
        PrintMessage("Please enable the addon first, /dr on")
        do return end
    end

    if (DeathRollsRoyceStatus[STATUS_PLAYER_STARTED] == nil) then
        PrintMessage("There isn't a death roll running at the moment.")
    elseif (DeathRollsRoyceStatus[STATUS_PLAYER_STARTED] == Player) then
        SendAddonMessage(ADDON_ID, COMMAND_START .. ":" .. Player .. ":" .. DeathRollsRoyceStatus[STATUS_AMOUNT], "RAID")
    elseif (DeathRollsRoyceStatus[STATUS_RUNNING] ~= 0) then
        PrintMessage("Too late. The death roll is already running.")
    else
        SendAddonMessage(ADDON_ID, COMMAND_JOIN .. ":" .. Player, "RAID")
    end

    DeathRollsRoyce_UpdatePlayers()
end

function DeathRollsRoyce_Leave()
    if (IsEnabled() == false) then
        PrintMessage("Please enable the addon first, /dr on")
        do return end
    end

    if (DeathRollsRoyceStatus[STATUS_PLAYER_STARTED] == nil) then
        PrintMessage("There isn't a death roll running at the moment.")
    elseif (DeathRollsRoyceStatus[STATUS_RUNNING] ~= 0) then
        PrintMessage("Too late. The death roll is already running.")
    else
        SendAddonMessage(ADDON_ID, COMMAND_LEAVE .. ":" .. Player, "RAID")
    end

    DeathRollsRoyce_UpdatePlayers()
end

function DeathRollsRoyce_Clear()
    DeathRollsRoyceStatus = {}

    DeathRollsRoyceRollFrame.text_area:SetText("")
    DeathRollsRoyceRollFrame:Hide()

    PrintMessage("Cleared death roll status.")
end

function DeathRollsRoyce_Roll()
    if (DeathRollsRoyceStatus[STATUS_WINNER] ~= nil) then
        PrintMessage("The death roll is over. The winner is: " .. DeathRollsRoyceStatus[STATUS_WINNER])
        do return end
    end

    if (DeathRollsRoyceStatus[STATUS_PLAYER_STARTED] == nil) then
        PrintMessage("There isn't a death roll running at the moment.")
        do return end
    end

    if (DeathRollsRoyceStatus[STATUS_ROLLED] == 1) then
        PrintMessage("You can only roll once per round.")
        do return end
    end

    local lost = TableContains(DeathRollsRoyceStatus[STATUS_PLAYERS_LOSERS], Player)

    -- Lost a previous round and not the person who started the death roll? Report you can't roll after you lost
    -- Note: We don't report this for the person who started the death roll because they still need to start future rounds
    if (lost and (Player ~= DeathRollsRoyceStatus[STATUS_PLAYER_STARTED])) then
        PrintMessage("You lost in a previous round - you're out. You can't roll on this or future rounds.")
        do return end
    end

    -- Start the round?
    if (DeathRollsRoyceStatus[STATUS_RUNNING] == 0) then
        if (Player == DeathRollsRoyceStatus[STATUS_PLAYER_STARTED]) then
            PrintMessage("Starting round " .. (DeathRollsRoyceStatus[STATUS_ROUND] + 1))
            SendAddonMessage(ADDON_ID, COMMAND_RUNNING .. ":" .. Player, "RAID")

            -- Update to running state immediately to simplify logic below
            DeathRollsRoyceStatus[STATUS_RUNNING] = 1
        else
            PrintMessage("Only the person who started the death roll can start the round.")
            do return end
        end
    end

    -- Sanity check - lost prevoius round? Can't roll, exit here
    -- Note: We get to this state when the person who started the death roll lost a previous round but still needs to start future rounds
    if lost then
        do return end
    end

    DeathRollsRoyceStatus[STATUS_ROLLED] = 1

    -- Round started, do the roll
    if (DeathRollsRoyceStatus[STATUS_RUNNING] == 1) then
        RandomRoll(1, DeathRollsRoyceStatus[STATUS_AMOUNT] * 10)
    end
end

function DeathRollsRoyce_UpdatePlayers()
    local text = "Rolling for: " .. DeathRollsRoyceStatus[STATUS_AMOUNT] .. " gold\n"
    text = text .. "Current pot split: " .. (DeathRollsRoyceStatus[STATUS_AMOUNT] / DeathRollsRoyceStatus[STATUS_PLAYER_COUNT]) .. "\n"
    text = text .. "Started by: " .. DeathRollsRoyceStatus[STATUS_PLAYER_STARTED] .. "\n\n"

    text = text .. "Players: (" .. DeathRollsRoyceStatus[STATUS_PLAYER_COUNT] .. ")\n"

    local total_players = 0
    local total_losers = 0
    local rolls_completed = 0
    local highest_roll = 0
    local highest_roll_player = nil
    local lowest_roll = DeathRollsRoyceStatus[STATUS_AMOUNT] * 10
    local lowest_roll_player = nil
    local winner = nil
    local winner_error = false

    -- Calculate total players, lowest roll, and loser count
    for _, player in pairs(DeathRollsRoyceStatus[STATUS_PLAYERS]) do
        total_players = total_players + 1

        -- Compute lowest roll
        if ((DeathRollsRoyceStatus[STATUS_RUNNING] == 1) and (DeathRollsRoyceStatus[STATUS_ROLLS][player] ~= nil)) then
            rolls_completed = rolls_completed + 1
            if (DeathRollsRoyceStatus[STATUS_ROLLS][player] < lowest_roll) then
                lowest_roll = DeathRollsRoyceStatus[STATUS_ROLLS][player]
                lowest_roll_player = player
            end
            if (DeathRollsRoyceStatus[STATUS_ROLLS][player] > highest_roll) then
                highest_roll = DeathRollsRoyceStatus[STATUS_ROLLS][player]
                highest_roll_player = player
            end
        
        -- If player already lost a previous round just count them as a completed roll to make the logic below determining if all rolls are complete simpler
        elseif (TableContains(DeathRollsRoyceStatus[STATUS_PLAYERS_LOSERS], player)) then
            rolls_completed = rolls_completed + 1
            total_losers = total_losers + 1
        end
    end

    -- If all players for the round have rolled and there is only 1 player left (total losers is equal to player count minus one), we need to determine the winner
    -- Note: Sanity check that we are in at least round 1 because start/clear goes to round 0 and round is incremented each time a round starts
    if ((DeathRollsRoyceStatus[STATUS_ROUND] > 0) and (total_losers == (total_players - 1))) then
        -- Determine winner
        for _, player in pairs(DeathRollsRoyceStatus[STATUS_PLAYERS]) do
            -- If this player isn't in the losers table, they are the winner
            if (TableContains(DeathRollsRoyceStatus[STATUS_PLAYERS_LOSERS], player) == false) then
                -- Sanity check that there shouldn't already be a winner defined
                if (winner == nil) then
                    winner = player
                else
                    PrintMessage("Ruh roh. Found multiple winners?! This shouldn't happen. I blame Esco. First winner found: " .. winner .. ". Another winner found: " .. player .. ".")
                    winner_error = true
                end
            end
        end
    end

    -- Winner error? Something wen't wrong, we can't define a winner
    if winner_error then
        winner = nil
    end

    -- Main loop to update player status text
    for _, player in pairs(DeathRollsRoyceStatus[STATUS_PLAYERS]) do
        -- Round is running, determine text color and roll number output
        if (DeathRollsRoyceStatus[STATUS_RUNNING] == 1) then
            local text_color = ""
            local text_roll = ""

            -- If the player has rolled, determine text output
            if (DeathRollsRoyceStatus[STATUS_ROLLS][player] ~= nil) then
                -- All rolls for the round complete? Determine the roll text color for losers and winners of the round
                if (rolls_completed == total_players) then
                    -- Loser of the round?
                    if (player == lowest_roll_player) then
                        text_color = RED_TEXT

                    else
                        text_color = GREEN_TEXT
                    end
                end

                -- Append roll to output
                text_roll = ": " .. DeathRollsRoyceStatus[STATUS_ROLLS][player]
            end

            -- If the player lost a previous round, their text color output is red
            if TableContains(DeathRollsRoyceStatus[STATUS_PLAYERS_LOSERS], player) then
                text_color = RED_TEXT
            end

            -- Winner of all rounds?
            if (player == winner) then
                text_color = GREEN_TEXT
            end

            text = text .. text_color .. player .. text_roll .. RESET_COLOR_TEXT .. "\n"

        -- No round is running, but player is in the losers list - mark them red
        elseif TableContains(DeathRollsRoyceStatus[STATUS_PLAYERS_LOSERS], player) then
            text = text .. RED_TEXT .. player .. RESET_COLOR_TEXT .. "\n"

        -- No round running and player isn't in the losers list - just output normal text for player name
        else
            text = text .. player .. "\n"
        end
    end

    DeathRollsRoyceRollFrame.text_area:SetText(text)

    -- TODO: move this somewhere else?
    -- If all rolls completed, send commands
    if (Player == DeathRollsRoyceStatus[STATUS_PLAYER_STARTED]) then

        -- All rolls completed for round?
        if ((DeathRollsRoyceStatus[STATUS_RUNNING] == 1) and (rolls_completed == total_players) and (Player == DeathRollsRoyceStatus[STATUS_PLAYER_STARTED])) then
            PrintDebug("All rolls completed, sending lowest roll player " .. lowest_roll_player)
            -- Send loser of round
            SendAddonMessage(ADDON_ID, COMMAND_LOSER .. ":" .. Player .. ":" .. lowest_roll_player .. ":" .. lowest_roll .. ":" .. highest_roll_player .. ":" .. highest_roll, "RAID")

        -- All rolls completed for all rounds, and no winner sent yet?
        elseif ((winner ~= nil) and (DeathRollsRoyceStatus[STATUS_WINNER] == nil)) then
            PrintDebug("All rounds completed, sending stop")
            -- Send winner
            pot_split = DeathRollsRoyceStatus[STATUS_AMOUNT] / DeathRollsRoyceStatus[STATUS_PLAYER_COUNT]
            SendAddonMessage(ADDON_ID, COMMAND_STOP .. ":" .. Player .. ":" .. winner .. ":" .. pot_split, "RAID")
        end
    end

end

--------------------------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------------------------

function DeathRollsRoyce_OnLoad()
	this:RegisterEvent("PLAYER_ENTERING_WORLD")

    SlashCmdList["DeathRollsRoyce"] = DeathRollsRoyce_Command
    SLASH_DeathRollsRoyce1 = "/dr"
    SLASH_DeathRollsRoyce2 = "/deathroll"
end

function DeathRollsRoyce_OnEvent(event)
	if (event == "PLAYER_ENTERING_WORLD") then
		DeathRollsRoyce_Initialize()
    elseif (event == "CHAT_MSG_ADDON") then
        DeathRollsRoyce_HandleAddonMessage(arg1, arg2)
    elseif (event == "CHAT_MSG_SYSTEM") then
        DeathRollsRoyce_HandleSystemMessage(arg1)
    end
end

--------------------------------------------------------------------------------------------------
-- Events Helpers
--------------------------------------------------------------------------------------------------

function DeathRollsRoyce_HandleAddonMessage(addon_id, user_data)
    if ((addon_id ~= ADDON_ID) or (IsEnabled() == false)) then
        do return end
    end

    PrintDebug("DeathRollsRoyce_HandleAddonMessage " .. user_data)

    local user_data_split = {}
    for s in string.gfind(user_data, "([^:]+)") do
        table.insert(user_data_split, s)
        PrintDebug("user_data_split: " .. s)
    end

    local message_from_player_started = false
    if (user_data_split[2] == DeathRollsRoyceStatus[STATUS_PLAYER_STARTED]) then
        message_from_player_started = true
    end

    if (user_data_split[1] == COMMAND_START) then
        if (DeathRollsRoyceStatus[STATUS_PLAYER_STARTED] ~= nil) then
            do return end
        end

        DeathRollsRoyceStatus[STATUS_PLAYER_STARTED] = user_data_split[2]
        DeathRollsRoyceStatus[STATUS_AMOUNT] = tonumber(user_data_split[3])
        DeathRollsRoyceStatus[STATUS_PLAYERS] = {}
        DeathRollsRoyceStatus[STATUS_PLAYER_COUNT] = 1
        DeathRollsRoyceStatus[STATUS_PLAYERS_LOSERS] = {}
        DeathRollsRoyceStatus[STATUS_ROLLS] = {}
        DeathRollsRoyceStatus[STATUS_RUNNING] = 0
        DeathRollsRoyceStatus[STATUS_ROUND] = 0
        DeathRollsRoyceStatus[STATUS_WINNER] = nil

        table.insert(DeathRollsRoyceStatus[STATUS_PLAYERS], user_data_split[2])

        if (DeathRollsRoyceStatus[STATUS_PLAYER_STARTED] ~= Player) then
            PrintMessage(DeathRollsRoyceStatus[STATUS_PLAYER_STARTED] .. " started a death roll for " .. DeathRollsRoyceStatus[STATUS_AMOUNT] .. " gold. To join the death roll: /dr join")
        end

        DeathRollsRoyceRollFrame:Show()
        DeathRollsRoyce_UpdatePlayers()

    elseif (user_data_split[1] == COMMAND_JOIN) then
        -- Sanity check - don't allow players to join who might have enabled the addon after the death roll rounds were already started
        if ((DeathRollsRoyceStatus[STATUS_ROUND] > 0) or (DeathRollsRoyceStatus[STATUS_RUNNING] ~= 0)) then
            do return end
        end
        if (user_data_split[2] ~= nil) and (TableContains(DeathRollsRoyceStatus[STATUS_PLAYERS], user_data_split[2]) == false) then
            table.insert(DeathRollsRoyceStatus[STATUS_PLAYERS], user_data_split[2])
            DeathRollsRoyceStatus[STATUS_PLAYER_COUNT] = DeathRollsRoyceStatus[STATUS_PLAYER_COUNT] + 1
            PrintMessage(user_data_split[2] .. " joined the death roll.")
            DeathRollsRoyce_UpdatePlayers()
        end

    elseif (user_data_split[1] == COMMAND_LEAVE) then
        if (user_data_split[2] == DeathRollsRoyceStatus[STATUS_PLAYER_STARTED]) then
            PrintMessage(DeathRollsRoyceStatus[STATUS_PLAYER_STARTED] .. " started the death roll but they left. Clearing.")
            DeathRollsRoyce_Clear()
        else
            local table_index = GetTableIndex(DeathRollsRoyceStatus[STATUS_PLAYERS], user_data_split[2])
            if (table_index ~= nil) then
                table.remove(DeathRollsRoyceStatus[STATUS_PLAYERS], table_index)
                DeathRollsRoyceStatus[STATUS_PLAYER_COUNT] = DeathRollsRoyceStatus[STATUS_PLAYER_COUNT] - 1
                PrintMessage(user_data_split[2] .. " left the death roll.")
                DeathRollsRoyce_UpdatePlayers()
            end
        end
    
    elseif ((user_data_split[1] == COMMAND_RUNNING) and message_from_player_started) then
        DeathRollsRoyceStatus[STATUS_ROLLS] = {}
        DeathRollsRoyceStatus[STATUS_ROUND] = DeathRollsRoyceStatus[STATUS_ROUND] + 1
        DeathRollsRoyceStatus[STATUS_RUNNING] = 1
        PrintMessage(DeathRollsRoyceStatus[STATUS_PLAYER_STARTED] .. " started the rolls. Round: " .. DeathRollsRoyceStatus[STATUS_ROUND])
    
    elseif ((user_data_split[1] == COMMAND_LOSER) and message_from_player_started) then
        table.insert(DeathRollsRoyceStatus[STATUS_PLAYERS_LOSERS], user_data_split[3])
        PrintMessage(user_data_split[3] .. " lost round " .. DeathRollsRoyceStatus[STATUS_ROUND] .. " with a roll of " .. user_data_split[4] .. ".")
        PrintMessage("Highest roll that round was " .. user_data_split[5] .. " with a roll of " .. user_data_split[6] .. ".")

        -- Round completed, reset running state
        DeathRollsRoyceStatus[STATUS_RUNNING] = 0
        DeathRollsRoyceStatus[STATUS_ROLLED] = 0

        DeathRollsRoyce_UpdatePlayers()
    
    elseif ((user_data_split[1] == COMMAND_STOP) and message_from_player_started) then

        DeathRollsRoyceStatus[STATUS_WINNER] = user_data_split[3]

        if (Player == user_data_split[3]) then
            PrintMessage("Mama mia! You won the death roll - Let's gooooooooooooooooooo")
            PrintMessage("Each player will pay you " .. user_data_split[4] .. " gold")
        else
            PrintMessage("Death roll over. The winner is: " .. DeathRollsRoyceStatus[STATUS_WINNER] .. ". You need to pay " .. user_data_split[4] .. " gold to that player.")
        end

        -- Round completed, clear rolls and reset running state
        DeathRollsRoyceStatus[STATUS_PLAYER_STARTED] = nil
        DeathRollsRoyceStatus[STATUS_ROLLS] = {}
        DeathRollsRoyceStatus[STATUS_RUNNING] = 0
        DeathRollsRoyceStatus[STATUS_ROLLED] = 0

        DeathRollsRoyce_UpdatePlayers()

    end
end

function DeathRollsRoyce_HandleSystemMessage(message)
    -- Not running? Nothing to do
    if (DeathRollsRoyceStatus[STATUS_RUNNING] ~= 1) then
        do return end
    end

    PrintDebug("DeathRollsRoyce_HandleSystemMessage " .. message)

    if (string.find(message, "rolls") and string.find(message, "(%d+)")) then
        local _, _, roller, roll, min_roll, max_roll = string.find(message, "(%S+) rolls (%d+) %((%d+)%-(%d+)%)")

        -- Sanity check for correct roll
        if ((tonumber(min_roll) ~= 1) or (tonumber(max_roll) ~= (DeathRollsRoyceStatus[STATUS_AMOUNT] * 10))) then
            PrintDebug("Ignoring random non-deathroll from: " .. roller)
            do return end
        end

        -- Ignore rolls from players who lost a previous round
        if (TableContains(DeathRollsRoyceStatus[STATUS_PLAYERS_LOSERS], roller)) then
            PrintDebug("Ignoring roll from loser: " .. roller)
            do return end
        end

        -- If the person who rolled joined the death roll, and they don't already already have a roll for this round? Register roll
        if (TableContains(DeathRollsRoyceStatus[STATUS_PLAYERS], roller) and (DeathRollsRoyceStatus[STATUS_ROLLS][roller] == nil)) then
            PrintDebug("Registering roll of " .. roll .. " for " .. roller)
            DeathRollsRoyceStatus[STATUS_ROLLS][roller] = tonumber(roll)

            DeathRollsRoyce_UpdatePlayers()
        end
    end
end

--------------------------------------------------------------------------------------------------
-- Initialize
--------------------------------------------------------------------------------------------------

function DeathRollsRoyce_Initialize()
    if (DeathRollsRoyceInitialized == true) then
        do return end
    end

    DeathRollsRoyceInitialized = true

    PrintDebug("DeathRollsRoyce_Initialize")
	Player = UnitName("player")
	Realm = GetRealmName()
	if DeathRollsRoyceOptions == nil then DeathRollsRoyceOptions = {} end
	if (DeathRollsRoyceOptions[Realm] == nil) then DeathRollsRoyceOptions[Realm] = {} end
	if (DeathRollsRoyceOptions[Realm][Player] == nil) then DeathRollsRoyceOptions[Realm][Player] = {} end
	if (DeathRollsRoyceOptions[Realm][Player][OPTION_DEBUG] == nil) then DeathRollsRoyceOptions[Realm][Player][OPTION_DEBUG] = 0 end
	if (DeathRollsRoyceOptions[Realm][Player][OPTION_ENABLED] == nil) then DeathRollsRoyceOptions[Realm][Player][OPTION_ENABLED] = 0 end
    PrintDebug("DeathRollsRoyce_Initialize DONE")

    DeathRollsRoyce_OptionsChanged()

    DeathRollsRoyceStatus[STATUS_PLAYER_STARTED] = nil

    PrintMessage("loaded. /dr for usage. Current status: " .. GetOptionBoolText(OPTION_ENABLED))

    DeathRollsRoyceRollFrame = CreateRollFrame()
end

--------------------------------------------------------------------------------------------------
-- Command
--------------------------------------------------------------------------------------------------

function DeathRollsRoyce_Command(args)
    local args = string.gsub(args, "%s{2,}", "")

    local args_split = {}
    PrintDebug("args_split")
    for s in string.gfind(args, "([^%s]+)") do
        table.insert(args_split, s)
        PrintDebug("args_split: " .. s)
    end

    PrintDebug("Command '" .. args .. "'")

    if (args == "") then
        PrintMessage("Death Rolls Royce: " .. GetOptionBoolText(OPTION_ENABLED))
        PrintMessage(" - Change with /dr [on | off]")
        PrintMessage("To start a death roll, /dr start <amount>")

    elseif (args == "on") then
        EnableOption(OPTION_ENABLED)
        PrintMessage("DeathRollsRoyce on.")
    elseif (args == "off") then
        DisableOption(OPTION_ENABLED)
        PrintMessage("DeathRollsRoyce off.")

    elseif (args == "debug") then
        PrintMessage("Debug: " .. GetOptionBoolText(OPTION_DEBUG))
        PrintMessage(" - Change with /dr debug [on | off]")
    elseif (args == "debug on") then
        EnableOption(OPTION_DEBUG)
        PrintMessage("Debug on.")
    elseif (args == "debug off") then
        DisableOption(OPTION_DEBUG)
        PrintMessage("Debug off.")
    
    elseif (args == COMMAND_CLEAR) then
        DeathRollsRoyce_Clear()

    elseif ((args == COMMAND_START) and (IsEnabled() == false)) then
        PrintMessage("Please enable the addon first, /dr on")

    elseif (args == COMMAND_START) then
        PrintMessage("Please enter an amount for the death roll, e.g. /dr start 100")
    elseif (args_split[1] == COMMAND_START) then
        if (tonumber(args_split[2]) == nil) then
            PrintMessage("Please enter an amount for the death roll, " .. args_split[2] .. " is not a number.")
        else
            DeathRollsRoyce_Start(tonumber(args_split[2]))
        end

    elseif (args == COMMAND_JOIN) then
        DeathRollsRoyce_Join()

    elseif (args == COMMAND_LEAVE) then
        DeathRollsRoyce_Leave()

    end
end

--------------------------------------------------------------------------------------------------
-- Options updated
--------------------------------------------------------------------------------------------------

local function OptionRegisterOrUnregister(option, event)
    if (DeathRollsRoyce_GetOption(option) == 1) then
        PrintDebug("Registered event: " .. event)
        DeathRollsRoyceFrame:RegisterEvent(event)
    else
        PrintDebug("Unregistered event: " .. event)
        DeathRollsRoyceFrame:UnregisterEvent(event)
    end
end

function DeathRollsRoyce_OptionsChanged()
    if (DeathRollsRoyce_GetOption(OPTION_ENABLED) == 1) then
        OptionRegisterOrUnregister(OPTION_ENABLED, "CHAT_MSG_ADDON")
        OptionRegisterOrUnregister(OPTION_ENABLED, "CHAT_MSG_SYSTEM")
    else
        PrintDebug("Unregistered all events")
        DeathRollsRoyceFrame:UnregisterAllEvents()
    end
end
