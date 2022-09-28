local addonName, ns = ...

local MAX_TEAMS_COUNT = 8
local captains = {}
local countdownValue = 10
local teamMembersCount = 1
local readyMembersCount = 0
local spectator = nil
local countdownTimer = nil
local AceTimer = LibStub("AceTimer-3.0")
local captainsList = {}
local completedTeams = {}
local startedTeams = {}
local winner = nil
local gameStarted = false
local teamsReadiness = {}
local panel = nil
local addonPrefix = "tst123"
local defaultfont = [[Fonts\FRIZQT__.TTF]]
local TST = LibStub("AceAddon-3.0"):NewAddon("TST", "AceTimer-3.0")
local f = CreateFrame("Frame")

f:SetScript("OnEvent", function(self, event, ...)
	return self[event] and self[event](self, event, ...)
end)

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("CHAT_MSG_ADDON")
f:RegisterEvent("READY_CHECK_FINISHED")
f:RegisterEvent("READY_CHECK_CONFIRM")
f:RegisterEvent("CHAT_MSG_WHISPER")
f:RegisterEvent("CHALLENGE_MODE_COMPLETED")
f:RegisterEvent("CHALLENGE_MODE_START")

local function myChatFilter(self, event, msg, author, ...)
  if msg:find(addonPrefix) then
    return true
  end
end

ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", myChatFilter)

local style = {
    popup = {
        title = {
            color = {1, 1, 1, 1},
            size = 22,
            font = defaultfont
        },
        message = {
            color = {1, 1, 1, 1},
            size = 12,
            font = defaultfont
        },
        backdrop = {
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, 
            tileSize = 16, 
            edgeSize = 16,
            insets = {left = 2, right = 2, top = 2, bottom = 2}
        },
        backdropcolor = {0, 0, 0, 0.5},
        size = {
            width = 600,
            height = 400
        }
    }
}

local function has_value(tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end

    return false
end

local function Print(text, ...)
	text = tostring(text)
	if text then
		if text:match("%%[dfqs%d%.]") then
			DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00".. addonName ..":|r " .. format(text, ...))
		else
			DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00".. addonName ..":|r " .. strjoin(" ", text, tostringall(...)))
		end
	end
end

function indexOf(array, value)
    for i, v in ipairs(array) do
        if v == value then
            return i
        end
    end
    return nil
end

local function timeFormatMS(timeAmount)
	local seconds = floor(timeAmount / 1000)
	local ms = timeAmount - seconds * 1000
	local hours = floor(seconds / 3600)
	local minutes = floor((seconds / 60) - (hours * 60))
	seconds = seconds - hours * 3600 - minutes * 60

	if hours == 0 then
		return format("%d:%.2d.%.3d", minutes, seconds, ms)
	else
		return format("%d:%.2d:%.2d.%.3d", hours, minutes, seconds, ms)
	end
end

local function OpenPanel()
	if spectator ~= nil then return end

	if not panel then
        panel = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        panel:SetBackdrop(style.popup.backdrop)
        panel:SetBackdropColor(style.popup.backdropcolor)
        panel:SetSize(style.popup.size.width, style.popup.size.height)
        panel:SetPoint("CENTER", UIParent, "CENTER")
        panel:SetFrameStrata("HIGH")
		panel:RegisterForDrag("LeftButton")
        
		local titlestring = panel:CreateFontString(nil, "ARTWORK")
        titlestring:SetTextColor(unpack(style.popup.title.color))
        titlestring:SetFont(style.popup.title.font, style.popup.title.size)
        titlestring:SetMaxLines(2)
        titlestring:SetPoint("CENTER", 0, 0)
        titlestring:SetPoint("TOP", 0, -30)
        titlestring:SetWidth(style.popup.size.width - 50)
        titlestring:SetJustifyH("CENTER")
		titlestring:SetJustifyV("MIDDLE")
		titlestring:SetText("Tournament Synced Timers")
		
		local close = CreateFrame("Button", nil, panel)
        close:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
        close:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
        close:SetSize(50, 50)
        close:SetPoint("RIGHT", panel, "RIGHT", -15, -5)
        close:SetPoint("TOP", panel, "TOP", -5, -5)
        close:SetScript("OnClick", function(p) p:GetParent():Hide() end)
		
		local rc = CreateFrame("Button", nil, panel, 'UIPanelButtonTemplate')
        rc:SetSize(150, 50)
		rc:SetNormalFontObject("GameFontNormal");
		rc:SetText("READY CHECK")
        rc:SetPoint("CENTER", panel, "CENTER", -200, -120)
        rc:SetScript("OnClick", function(p) BeginReadyCheck() end)
		
		local start = CreateFrame("Button", nil, panel, 'UIPanelButtonTemplate')
        start:SetSize(150, 50)
		start:SetNormalFontObject("GameFontNormal");
		start:SetText("START")
        start:SetPoint("CENTER", panel, "CENTER", 0, -120)
        start:SetScript("OnClick", function(p) StartGame() end)
		
		local reset = CreateFrame("Button", nil, panel, 'UIPanelButtonTemplate')
        reset:SetSize(150, 50)
		reset:SetNormalFontObject("GameFontNormal");
		reset:SetText("RESET")
        reset:SetPoint("CENTER", panel, "CENTER", 200, -120)
        reset:SetScript("OnClick", function(p) ResetTeamsList() end)
		
		local captainsListTitle = panel:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
        captainsListTitle:SetTextColor(unpack(style.popup.title.color))
        captainsListTitle:SetFont(style.popup.message.font, style.popup.message.size)
        captainsListTitle:SetWordWrap(false)
        captainsListTitle:SetJustifyH("CENTER")
        captainsListTitle:SetPoint("CENTER", 0, 120)
        captainsListTitle:SetWidth(style.popup.size.width - 50)
        captainsListTitle:SetHeight(240)
		captainsListTitle:SetText("Captains list:")
		panel.titlestring = titlestring
		
		for i=1,MAX_TEAMS_COUNT do
			local captainEl = panel:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
			captainEl:SetTextColor(unpack(style.popup.title.color))
			captainEl:SetFont(style.popup.message.font, style.popup.message.size)
			captainEl:SetWordWrap(false)
			captainEl:SetJustifyH("CENTER")
			captainEl:SetPoint("CENTER", 0, 120 - 30 * i)
			captainEl:SetWidth(style.popup.size.width - 50)
			captainEl:SetHeight(240)
			captainEl:SetText("")
			captainsList[#captainsList + 1] = captainEl
			teamsReadiness[#teamsReadiness + 1] = false
			completedTeams[#completedTeams + 1] = false
			startedTeams[#startedTeams + 1] = false
		end
	end
	
	panel:Show()
	RefreshCaptainsListLabel()
end

function ClearCaptainLabels()
	for i=1,#captainsList do
		captainsList[i]:SetText("")
	end
end

function SetCaptainLabels()
	for i=1,#captainsList do
		if i <= #captains then
			if gameStarted == false then
				if teamsReadiness[i] == true then
					captainsList[i]:SetText(captains[i].."\124cff00FF00 READY\124r")
				else
					captainsList[i]:SetText(captains[i].."\124cffFF0000 NOT READY\124r")
				end
			else
				if winner == captains[i] then
					captainsList[i]:SetText(captains[i].."\124cff00FF00 WINNER\124r")
				elseif completedTeams[i] == false and startedTeams[i] == true then
					captainsList[i]:SetText(captains[i].."\124cffFFFF00 RUNNING...\124r")
				elseif completedTeams[i] == true and startedTeams[i] == true then
					captainsList[i]:SetText(captains[i].."\124cff00FF00 FINISHED\124r")
				else
					captainsList[i]:SetText(captains[i].."\124cffFF0000 PREPARING...\124r")
				end
			end
		end
	end
end

function f:ADDON_LOADED(event, addon)
	if addon == addonName then
		Print('Loaded')
		C_ChatInfo.RegisterAddonMessagePrefix(addonPrefix)
		C_ChatInfo.RegisterAddonMessagePrefix("D4")
		C_ChatInfo.RegisterAddonMessagePrefix("BigWigs")
	end
end

function f:CHALLENGE_MODE_COMPLETED()
	local mapID, level, time, onTime, keystoneUpgradeLevels = C_ChallengeMode.GetCompletionInfo()
	local name, _, timeLimit = C_ChallengeMode.GetMapUIInfo(mapID)
	SendAddonEvent(spectator, "We've completed "..name.."+"..level.." in "..timeFormatMS(time))
	SendAddonEvent(spectator, "complete")
	spectator = nil
end

function f:CHALLENGE_MODE_START(mapID)
	SendAddonEvent(spectator, "key_activated")
end

function f:CHAT_MSG_ADDON(prefix, msg, channel, sender)
	if prefix == addonPrefix then
		if msg == "rc" then
			spectator = sender
			readyMembersCount = 0
			teamMembersCount = GetNumGroupMembers()
			DoReadyCheck()
		elseif msg == "start" then
			spectator = sender
			TST:BeginCountdown()
			DoDBMPull()
		elseif msg == "ready" then
			Print(sender.."'s team READY!")
			local idx = indexOf(captains, sender)
			teamsReadiness[idx] = true
			RefreshCaptainsListLabel()
		elseif msg == "notready" then
			Print(sender.."'s team NOT ready!")
			local idx = indexOf(captains, sender)
			teamsReadiness[idx] = false
			RefreshCaptainsListLabel()
		elseif msg == "complete" then
			if winner == nil then
				winner = sender
			end
			local idx = indexOf(captains, sender)
			completedTeams[idx] = true
			RefreshCaptainsListLabel()
		elseif msg == "key_activated" then
			local idx = indexOf(captains, sender)
			startedTeams[idx] = true
			RefreshCaptainsListLabel()
		end
	end
end

function f:CHAT_MSG_WHISPER(_, msg, user)
	if msg == "tst123 start" then
		spectator = user
		TST:BeginCountdown()
		DoDBMPull()
	elseif msg == "tst123 rc" then
		spectator = user
		readyMembersCount = 0
		teamMembersCount = GetNumGroupMembers()
		DoReadyCheck()
	elseif msg == "tst123 ready" then
		Print(user.."'s team READY!")
		local idx = indexOf(captains, user)
		teamsReadiness[idx] = true
		RefreshCaptainsListLabel()
	elseif msg == "tst123 notready" then
		Print(user.."'s team NOT ready!")
		local idx = indexOf(captains, user)
		teamsReadiness[idx] = false
		RefreshCaptainsListLabel()
	elseif msg == "tst123 complete" then
		if winner == nil then
			winner = user
		end
		local idx = indexOf(captains, user)
		completedTeams[idx] = true
		RefreshCaptainsListLabel()
	elseif msg == "tst123 key_activated" then
		local idx = indexOf(captains, user)
		startedTeams[idx] = true
		RefreshCaptainsListLabel()
	elseif msg == "tst123" then
		RegisterCaptain(user, true)
	end
end

function f:READY_CHECK_FINISHED()
	if readyMembersCount >= teamMembersCount and spectator ~= nil then
		SendAddonEvent(spectator, "ready")
	elseif readyMembersCount < teamMembersCount and spectator ~= nil then
		SendAddonEvent(spectator, "notready")
	end
end

function f:READY_CHECK_CONFIRM(event,unit,status)
	if unit then
		if status == true then
			readyMembersCount = readyMembersCount + 1
		end
	end
end

function TST:BeginCountdown()
	countdownValue = 11
	self:PrintCountdown()
	countdownTimer = self:ScheduleRepeatingTimer("PrintCountdown", 1)
end

function TST:PrintCountdown()
	countdownValue = countdownValue - 1
	
	local inInstance, instanceType = IsInInstance()
	
	if countdownValue > 0 then
		if IsInRaid() then
			SendChatMessage(countdownValue, string.upper("raid"))
			if inInstance then
				SendChatMessage(countdownValue, string.upper("say"))
			end
		elseif IsInGroup() then
			SendChatMessage(countdownValue, string.upper("party"))
			if inInstance then
				SendChatMessage(countdownValue, string.upper("say"))
			end
		else
			Print(countdownValue)
		end
	elseif countdownValue == 0 then
		if IsInRaid() then
			SendChatMessage("START", string.upper("raid"))
			if inInstance then
				SendChatMessage("START", string.upper("say"))
			end
		elseif IsInGroup() then
			SendChatMessage("START", string.upper("party"))
			if inInstance then
				SendChatMessage("START", string.upper("say"))
			end
		else
			Print("START")
		end
	end
	
	if countdownValue == 0 then
		self:CancelTimer(countdownTimer)
		gameStarted = true
		RefreshCaptainsListLabel()
	end
end

function BeginReadyCheck()
	for i=1,#captains do
		SendAddonEvent(captains[i], "rc")
	end
end

function DoDBMPull()
	C_ChatInfo.SendAddonMessage("D4", ("PT\t%s\t%d"):format(10, 0), IsInGroup(2) and "INSTANCE_CHAT" or "RAID")
	C_ChatInfo.SendAddonMessage("BigWigs", "P^Pull^10", IsInGroup(2) and "INSTANCE_CHAT" or "RAID")
end

function SendAddonEvent(receiver, msg)
	if receiver == nil then return end

	if UnitInParty(receiver) then
		C_ChatInfo.SendAddonMessage(addonPrefix, msg, "WHISPER", receiver)
		
		if msg == "start" then
			C_ChatInfo.SendAddonMessage("D4", ("PT\t%s\t%d"):format(10, 0), "WHISPER", receiver)
			C_ChatInfo.SendAddonMessage("BigWigs", "P^Pull^10", "WHISPER", receiver)
		end
	else
		SendChatMessage(addonPrefix.." "..msg, "WHISPER", nil, receiver)
	end
end

function StartGame()
    Print("Starting game...")
	winner = nil
	TST:BeginCountdown()
	DoDBMPull()
	for i=1,#captains do
		startedTeams[i] = false
		SendAddonEvent(captains[i], "start")
	end
end

function ResetTeamsList()
	captains = {}
	startedTeams = {}
	teamsReadiness = {}
	winner = nil
	Print("Teams list has been cleared")
	RefreshCaptainsListLabel()
end

function RegisterCaptain(captainUnit, forced)
	if not UnitExists(captainUnit) and not forced then
		Print("Unit doesn't exist!")
		return
	end
	
	if not forced then
		Print("Trying to register "..UnitName(captainUnit))
	else
		Print("Trying to register "..captainUnit)
	end

	local isPlayer = UnitIsPlayer(captainUnit)

	if (isPlayer == nil or isPlayer == false) and not forced then
		Print("Selected unit is not player!")
		return
	end
	
	local captainName = forced and UnitName(captainUnit) or captainUnit
	local isLeader = UnitIsGroupLeader(captainUnit) or not UnitInParty(captainUnit)

	if not isLeader then
		Print("Selected player is not party leader!")
		if forced then
			SendChatMessage("TST: You are not party leader!", "WHISPER", nil, captainName)
		end
		return
	end
	
	if #captains >= MAX_TEAMS_COUNT - 1 then
		Print("Tournament table is full!")
		SendChatMessage("TST: Tournament table is full!", "WHISPER", nil, captainName)
		return
	end

	if not has_value(captains, captainName) then
		captains[#captains + 1] = captainName
		teamsReadiness[#captains + 1] = false
		startedTeams[#captains + 1] = false
		Print("Registered captain: "..captainName)
		RefreshCaptainsListLabel()
		SendChatMessage("TST: Your party has been registered!", "WHISPER", nil, captainName)
	else
		Print("You've already registered this captain!")
		if forced then
			SendChatMessage("TST: You are already registered!", "WHISPER", nil, captainName)
		end
	end
end

function RefreshCaptainsListLabel()
	ClearCaptainLabels()
	SetCaptainLabels()
end

-- Slash
SLASH_TOURNAMENTSYNCEDTIMERS1 = "/tst"

local SlashHandlers = {
	["captain"] = function(input)
		if input == "" or input == nil then
			local unitName = GetUnitName("target", true)

			if unitName ~= nil and unitName ~= "" then
				RegisterCaptain("target")
			end
		else
			RegisterCaptain(input)
		end
	end,
	["show"] = function()
		OpenPanel()
	end,
	["start"] = function()
		StartGame()
	end,
	["rc"] = function()
		BeginReadyCheck()
	end,
	["reset"] = function()
		spectator = nil
		ResetTeamsList()
	end,
	["help"] = function()
		Print(" /tst captain <<< registering a team via targeted player (he must be in your party or raid)")
		Print(" /tst captain PlayerName-RealmName <<< registering a team via its captain nickname and realm name")
		Print(" /tst start <<< sending start signal to all registered captains")
		Print(" /tst rc <<< doing ready check for all registered teams")
		Print(" /tst reset <<< clears your teams list")
	end
}

SlashCmdList["TOURNAMENTSYNCEDTIMERS"] = function(text)
	local command, params = strsplit(" ", text, 2)

	if SlashHandlers[command] then
		SlashHandlers[command](params)
	end
end