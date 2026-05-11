-- =========================================================
-- AutoGemStore - PS99 Mailbox Receiver Bot (Production)
-- Domain: https://autogemstore.online/
-- =========================================================

local CONFIG = {
    BASE_URL = "https://autogemstore.online",
    API_REPORT = "https://autogemstore.online/api/report_received_mail.php",
    API_PING = "https://autogemstore.online/api/bot_ping.php",
    BOT_SECRET = "AGS_2026_9fK2xQm7Rz1Lp4Vn8Tw6Yc3Hd0Sb5Ju",
    WEBHOOK = "https://discord.com/api/webhooks/1502609152025952338/9TmUzZ2jRGfdu0tNYMz7lci6s42oYO1Pxj6MvlAU_x8qiMTxcU2awczwsHeYb3SaCDsD",
    PING_INTERVAL = 10,
    SCAN_INTERVAL = 6,
    CLAIM_DELAY = 0.7,
}

local Http = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local plr = Players.LocalPlayer
local Net = RS.Network
local network = require(RS.Library.Client.Network)

if _G.AutoGemStoreMailboxReaderRunning then
    return
end
_G.AutoGemStoreMailboxReaderRunning = true

local seenUUIDs = {}
local processingUUIDs = {}
local lastDebugLog = 0

local function sleep(sec)
    if task and task.wait then
        task.wait(sec)
    else
        wait(sec)
    end
end

-- Detect request function
local req = (request or http_request or syn.request or (http and http.request))
if not req then
    warn("❌ Executor không hỗ trợ gửi HTTP Request!")
end

local function safeRequest(payload)
    if not req then return nil, "request_not_supported" end
    local ok, res = pcall(function()
        return req(payload)
    end)
    if not ok then
        return nil, tostring(res)
    end
    return res, nil
end

local function notify(title, text)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title or "AutoGemStore",
            Text = text or "",
            Duration = 5
        })
    end)
end

local function logToDiscord(msg, color)
    if not CONFIG.WEBHOOK or CONFIG.WEBHOOK == "" then return end
    local res, err = safeRequest({
        Url = CONFIG.WEBHOOK,
        Method = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Body = Http:JSONEncode({embeds = {{description = tostring(msg), color = color or 0x00ccff}}})
    })
    if err or not res then
        warn("Discord log fail: " .. tostring(err or "no_response"))
    end
end

local function reportError(title, err, extra)
    local text = "❌ **" .. tostring(title or "Error") .. "**\n" ..
        "• Bot: `" .. plr.Name .. "`\n" ..
        "• Lỗi: `" .. tostring(err or "unknown") .. "`"
    if extra and tostring(extra) ~= "" then
        text = text .. "\n• Chi tiết: `" .. tostring(extra):sub(1, 250) .. "`"
    end
    logToDiscord(text, 0xff4444)
end

local function getDiamondUIDAndBalance()
    local ok, save = pcall(function()
        return require(RS.Library.Client.Save).Get()
    end)
    if not ok or not save or type(save.Inventory) ~= "table" then return nil, 0 end
    for uid, item in pairs(save.Inventory.Currency or {}) do
        if item.id == "Diamonds" then return uid, tonumber(item._am or 0) or 0 end
    end
    return nil, 0
end

local function pingBot()
    local _, balance = getDiamondUIDAndBalance()
    local res, err = safeRequest({
        Url = CONFIG.API_PING,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/x-www-form-urlencoded",
            ["X-Bot-Key"] = CONFIG.BOT_SECRET
        },
        Body = "bot_username=" .. Http:UrlEncode(plr.Name) .. "&stock_gems=" .. tostring(balance or 0) .. "&type=RECEIVE&bot_key=" .. CONFIG.BOT_SECRET
    })
    if err or not res then
        reportError("Ping fail", err or "no_response", "stock_gems=" .. tostring(balance or 0))
        return false
    end
    return true
end

local function fmtNumber(n)
    n = math.floor(tonumber(n) or 0)
    local s = tostring(n)
    local out = ""
    local len = #s
    for i = 1, len do
        if i > 1 and (len - i + 1) % 3 == 0 then
            out = out .. ","
        end
        out = out .. s:sub(i, i)
    end
    return out
end

local function reportMail(sender, message, amount, uuid, itemText)
    local res, err = safeRequest({
        Url = CONFIG.API_REPORT,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/x-www-form-urlencoded",
            ["X-Bot-Key"] = CONFIG.BOT_SECRET
        },
        Body = "sender=" .. Http:UrlEncode(sender)
            .. "&message=" .. Http:UrlEncode(message)
            .. "&amount=" .. tostring(amount)
            .. "&item=" .. Http:UrlEncode(itemText or "")
            .. "&uuid=" .. Http:UrlEncode(tostring(uuid))
            .. "&bot_account=" .. Http:UrlEncode(plr.Name)
            .. "&api_key=" .. Http:UrlEncode(CONFIG.BOT_SECRET)
    })

    if err then
        return false, "request_error", tostring(err), nil, nil
    end
    if not res then
        return false, "no_response", "no response", nil, nil
    end

    local body = tostring(res.Body or "")
    local okDecode, data = pcall(function()
        return Http:JSONDecode(body)
    end)
    if not okDecode or type(data) ~= "table" then
        return false, "invalid_json", body:sub(1, 180), res.StatusCode, body
    end

    local success = data.success == true
    local action = tostring(data.action or "REJECT")
    local reason = tostring(data.reason or data.message or "")
    return success, action, reason, res.StatusCode, body
end

local function claimMail(uuid)
    if not uuid then return end
    local ok, err = pcall(function()
        network.Invoke("Mailbox: Claim", tostring(uuid))
    end)
    if not ok then
        reportError("Claim fail", err, uuid)
    end
end

local function parseItemText(item)
    if type(item) ~= "table" then
        return "📦 No item", 0
    end

    local class = tostring(item.class or item.Class or "?")
    local data = item.data or item.Data

    if type(data) ~= "table" then
        return class, 0
    end

    local id = tostring(data.id or data.Id or class)
    local amount = tonumber(data._am or data.amount or data.Amount or data.Value or 0) or 0
    local prettyAmount = amount > 0 and fmtNumber(amount) or "?"

    if class == "Currency" and id == "Diamonds" then
        return "💎 " .. prettyAmount .. " Diamonds", amount
    end

    return class .. " · " .. id .. (amount > 0 and (" · x" .. prettyAmount) or ""), amount
end

local function processMail(mail)
    if type(mail) ~= "table" then return end

    local uuid = tostring(mail.uuid or mail.UUID or mail.id or "")
    if uuid == "" then
        reportError("Mail parse fail", "missing uuid", Http:JSONEncode(mail):sub(1, 200))
        return
    end
    if seenUUIDs[uuid] or processingUUIDs[uuid] then return end
    processingUUIDs[uuid] = true

    local sender = tostring(mail.SenderName or mail.sender or mail.From or "?")
    local message = tostring(mail.Message or mail.message or mail.Text or "")
    local itemText, amount = parseItemText(mail.Item)

    local mailText = "📬 **MAIL RECEIVED** | `" .. plr.Name .. "`\n" ..
        "👤 Sender: **" .. sender .. "**\n" ..
        "💬 Message: _" .. (message ~= "" and message or "[no message]") .. "_\n" ..
        "📦 Item: " .. itemText .. "\n" ..
        "🆔 `" .. uuid:sub(1, 8) .. "...`"

    logToDiscord(mailText, 0x00ccff)

    local ok, action, reason, statusCode, body = reportMail(sender, message, amount, uuid, itemText)
    if not ok then
        logToDiscord(
            "⚠️ **Report fail** | `" .. plr.Name .. "`\n" ..
            "UUID: `" .. uuid:sub(1, 8) .. "...`\n" ..
            "Status: `" .. tostring(statusCode or "?") .. "`\n" ..
            "Reason: `" .. tostring(reason or "unknown") .. "`\n" ..
            "Body: `" .. tostring(body or ""):sub(1, 180) .. "`",
            0xff8800
        )
        reportError("Mail report fail", reason or "unknown", body)
    elseif action == "CLAIM" then
        if amount > 0 then
            sleep(CONFIG.CLAIM_DELAY)
            claimMail(uuid)
        end
        logToDiscord("✅ **Mail accepted** | `" .. plr.Name .. "`\nSender: `" .. sender .. "`\nAmount: `" .. tostring(amount) .. "`", 0x00ff88)
    else
        logToDiscord("ℹ️ **Mail reported but not claimed** | `" .. plr.Name .. "`\nAction: `" .. action .. "`\nReason: `" .. tostring(reason or "") .. "`", 0xaaaaaa)
    end

    seenUUIDs[uuid] = true
    processingUUIDs[uuid] = nil
end

local function extractInbox(response)
    if type(response) ~= "table" then return nil end
    if type(response.Inbox) == "table" then return response.Inbox end
    if type(response.inbox) == "table" then return response.inbox end
    if type(response) == "table" and next(response) ~= nil then return response end
    return nil
end

local function checkInbox(data)
    local inbox = extractInbox(data)
    if not inbox then
        local ok, response = pcall(function()
            return network.Invoke("Mailbox: Get")
        end)
        if ok then
            inbox = extractInbox(response)
        else
            reportError("Mailbox get fail", response)
            return
        end
    end

    if type(inbox) ~= "table" then
        reportError("Inbox scan fail", "invalid inbox format")
        return
    end

    local count = 0
    for _, mail in pairs(inbox) do
        count = count + 1
        processMail(mail)
    end

    local now = os.time()
    if count == 0 and now - lastDebugLog >= 30 then
        lastDebugLog = now
        logToDiscord("ℹ️ **Inbox empty / scanner alive** | `" .. plr.Name .. "`", 0x888888)
    end
end

local eventTriggered = false
local okHook, hookErr = pcall(function()
    local inboxEvent = Net and (Net:FindFirstChild("Inbox Updated") or Net["Inbox Updated"])
    if inboxEvent and inboxEvent.OnClientEvent then
        inboxEvent.OnClientEvent:Connect(function(data)
            eventTriggered = true
            local okEvent, eventErr = pcall(function()
                checkInbox(data)
            end)
            if not okEvent then
                reportError("Inbox event fail", eventErr)
            end
        end)
        logToDiscord("✅ **Inbox hook OK** | `" .. plr.Name .. "`", 0x00ff88)
    else
        reportError("Hook fail", "Inbox Updated event missing")
    end
end)
if not okHook then
    reportError("Hook crash", hookErr)
end

logToDiscord("🤖 **Mailbox Reader Started:** `" .. plr.Name .. "`", 0x00ff00)
notify("Mailbox Reader", "Đang quét và đọc inbox...")

local lastPing = 0
local okPing, pingErr = pcall(function()
    return pingBot()
end)
if not okPing or pingErr ~= true then
    reportError("Startup ping fail", tostring(pingErr))
end
lastPing = os.time()

while true do
    local now = os.time()
    if now - lastPing >= CONFIG.PING_INTERVAL then
        local okNow, pingResult = pcall(function()
            return pingBot()
        end)
        if not okNow or pingResult ~= true then
            reportError("Periodic ping fail", tostring(pingResult))
        end
        lastPing = now
    end

    local okCheck, errCheck = pcall(function()
        checkInbox()
    end)
    if not okCheck then
        reportError("Inbox scan crash", errCheck)
    end

    if not eventTriggered and now - lastDebugLog >= 30 then
        lastDebugLog = now
        logToDiscord("ℹ️ **Scanner alive, waiting event/mail** | `" .. plr.Name .. "`", 0x888888)
    end

    sleep(CONFIG.SCAN_INTERVAL)
end
