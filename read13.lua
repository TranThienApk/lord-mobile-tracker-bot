-- PS99 Mailbox Reader FINAL - Đọc inbox + báo server
local W = "https://discord.com/api/webhooks/1502609152025952338/9TmUzZ2jRGfdu0tNYMz7lci6s42oYO1Pxj6MvlAU_x8qiMTxcU2awczwsHeYb3SaCDsD"
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

local CONFIG = {
    API_REPORT = "https://autogemstore.online/api/report_received_mail.php",
    API_PING = "https://autogemstore.online/api/bot_ping.php",
    BOT_SECRET = "AGS_2026_9fK2xQm7Rz1Lp4Vn8Tw6Yc3Hd0Sb5Ju",
    WEBHOOK = W,
    PING_INTERVAL = 10,
    SCAN_INTERVAL = 6,
    CLAIM_DELAY = 0.7,
}

local req = (request or http_request or syn.request or (http and http.request))
local function safeRequest(payload)
    if not req then return nil, "request_not_supported" end
    local ok, res = pcall(function() return req(payload) end)
    if not ok then return nil, tostring(res) end
    return res, nil
end

local function d(msg, c)
    if not CONFIG.WEBHOOK or CONFIG.WEBHOOK == "" then return false end
    local res, err = safeRequest({
        Url = CONFIG.WEBHOOK,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = Http:JSONEncode({ embeds = { { description = tostring(msg), color = c or 0x00ccff } } })
    })
    if err or not res then
        warn("Discord log fail: " .. tostring(err or "no_response"))
        return false
    end
    return true
end

local function fmt(n)
    n = math.floor(tonumber(n) or 0)
    local s = tostring(n)
    local result = ""
    local len = #s
    for i = 1, len do
        if i > 1 and (len - i + 1) % 3 == 0 then result = result .. "," end
        result = result .. s:sub(i, i)
    end
    return result
end

local function fmtTime(ts)
    if not ts then return "?" end
    local t = math.floor(tonumber(ts) or 0) + 7 * 3600
    local h = math.floor(t / 3600) % 24
    local m = math.floor(t / 60) % 60
    return string.format("%02d:%02d", h, m)
end

local function notify(title, text)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title or "Mailbox Reader",
            Text = text or "",
            Duration = 5
        })
    end)
end

local function getDiamondUIDAndBalance()
    local ok, save = pcall(function()
        return require(RS.Library.Client.Save).Get()
    end)
    if not ok or not save or type(save.Inventory) ~= "table" then return nil, 0 end
    for uid, item in pairs(save.Inventory.Currency or {}) do
        if item.id == "Diamonds" then
            return uid, tonumber(item._am or 0) or 0
        end
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
        Body = "bot_username=" .. Http:UrlEncode(plr.Name) ..
            "&stock_gems=" .. tostring(balance or 0) ..
            "&type=RECEIVE&bot_key=" .. CONFIG.BOT_SECRET
    })
    if err or not res then
        d("❌ **Ping fail** | `" .. plr.Name .. "`\n`" .. tostring(err or "no_response") .. "`", 0xff4444)
        return false
    end
    return true
end

local seenUUID = {}
local function parseMail(mail)
    if type(mail) ~= "table" then return nil end
    local uuid = tostring(mail.uuid or mail.UUID or mail.id or "")
    if uuid == "" or seenUUID[uuid] then return nil end
    seenUUID[uuid] = true

    local sender = tostring(mail.SenderName or mail.sender or "?")
    local message = tostring(mail.Message or mail.message or "")
    local ts = fmtTime(mail.Timestamp)
    local item = mail.Item

    local itemStr = ""
    local amount = 0
    if type(item) == "table" then
        local class = tostring(item.class or item.Class or "?")
        local data = item.data or item.Data
        if type(data) == "table" then
            local id = data.id or data.Id or class
            amount = tonumber(data._am or data.amount or data.Amount or data.Value or 0) or 0
            if amount > 0 then
                itemStr = "💎 **" .. fmt(amount) .. "** " .. tostring(id)
            else
                local sub = {}
                for k, v in pairs(data) do
                    table.insert(sub, tostring(k) .. "=" .. tostring(v):sub(1, 20))
                    if #sub >= 6 then break end
                end
                itemStr = class .. ": {" .. table.concat(sub, ", ") .. "}"
            end
        else
            itemStr = class
        end
    end

    return {
        uuid = uuid,
        sender = sender,
        message = message,
        ts = ts,
        itemStr = #itemStr > 0 and itemStr or "📦 No item",
        amount = amount
    }
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
            .. "&bot_key=" .. Http:UrlEncode(CONFIG.BOT_SECRET)
    })
    if err or not res then
        return false, "no_response", tostring(err or "")
    end

    local body = tostring(res.Body or "")
    local okDecode, data = pcall(function()
        return Http:JSONDecode(body)
    end)
    if not okDecode or type(data) ~= "table" then
        return false, "invalid_json", body
    end

    return data.success == true, tostring(data.action or "REJECT"), tostring(data.message or data.reason or ""), body
end

local function claimAll()
    local resp, err = network.Invoke("Mailbox: Claim All")
    local retries = 0
    while err == "You must wait 30 seconds before using the mailbox!" and retries < 20 do
        wait(2)
        retries = retries + 1
        resp, err = network.Invoke("Mailbox: Claim All")
    end
    if resp == true then
        d("✅ **Claim All thành công!**", 0x00ff88)
    elseif err and #tostring(err) > 0 then
        d("⚠️ Claim All: `" .. tostring(err) .. "`", 0xff8800)
    end
    return resp, err
end

local function processInbox(data)
    if type(data) ~= "table" then return end
    local inbox = data.Inbox or data.inbox or data
    if type(inbox) ~= "table" then return end

    local mails = {}
    local totalDia = 0
    for _, mail in pairs(inbox) do
        local p = parseMail(mail)
        if p then
            table.insert(mails, p)
            totalDia = totalDia + math.floor(tonumber(p.amount or 0) or 0)
        end
    end
    if #mails == 0 then return end

    d("📬 **" .. #mails .. " mail(s)** | `" .. plr.Name .. "`\n💎 Tổng nhận: **" .. fmt(totalDia) .. "**", 0x5599ff)
    for _, m in ipairs(mails) do
        d(
            "👤 **" .. m.sender .. "** · ⏰ " .. m.ts .. "\n" ..
            "💬 _" .. (#m.message > 0 and m.message or "[no message]") .. "_\n" ..
            (m.itemStr ~= "" and m.itemStr or "📦 No item") .. "\n" ..
            "🆔 `" .. m.uuid:sub(1, 8) .. "...`",
            0x00ccff
        )

        local ok, action, reason, body = reportMail(m.sender, m.message, m.amount, m.uuid, m.itemStr)
        if not ok then
            local lowerReason = string.lower(tostring(reason or ""))
            if lowerReason:find("already processed", 1, true) or lowerReason:find("not found", 1, true) then
                d("ℹ️ **Duplicate/processed mail skipped** | `" .. plr.Name .. "`\nUUID: `" .. m.uuid:sub(1, 8) .. "...`\nReason: `" .. tostring(reason or "") .. "`", 0xaaaaaa)
            else
                d("⚠️ **Report fail** | `" .. plr.Name .. "`\nUUID: `" .. m.uuid:sub(1, 8) .. "...`\nReason: `" .. tostring(reason or "unknown") .. "`\nBody: `" .. tostring(body or ""):sub(1, 180) .. "`", 0xff8800)
            end
        elseif action == "CLAIM" and m.amount > 0 then
            wait(CONFIG.CLAIM_DELAY)
            pcall(function()
                network.Invoke("Mailbox: Claim", tostring(m.uuid))
            end)
            d("✅ **Mail accepted** | `" .. plr.Name .. "`\nSender: `" .. m.sender .. "`\nAmount: `" .. tostring(m.amount) .. "`", 0x00ff88)
        end
    end
end

local function checkInbox(data)
    if type(data) == "table" then
        local inbox = data.Inbox or data.inbox or data
        if type(inbox) == "table" then
            processInbox(data)
            return
        end
    end

    local ok, response = pcall(function()
        return network.Invoke("Mailbox: Get")
    end)
    if ok and type(response) == "table" then
        processInbox(response)
    end
end

local hooked = false
local okHook = pcall(function()
    local inboxEvent = Net and (Net:FindFirstChild("Inbox Updated") or Net["Inbox Updated"])
    if inboxEvent and inboxEvent.OnClientEvent then
        inboxEvent.OnClientEvent:Connect(function(data)
            hooked = true
            local okEvent = pcall(function()
                checkInbox(data)
            end)
            if not okEvent then
                d("❌ **Inbox event fail** | `" .. plr.Name .. "`", 0xff4444)
            end
        end)
    end
end)

local startedOk = d("📬 **MAILBOX READER** | `" .. plr.Name .. "`\n🔄 Đang hook...", 0xffaa00)
notify("Mailbox Reader", "Đang quét inbox...")
d("✅ **Hook " .. (okHook and "OK" or "FAIL") .. "** | `" .. plr.Name .. "`", 0x00ff88)

local lastPing = 0
local lastAlive = 0
local okPing = pingBot()
if not okPing then
    d("⚠️ **Startup ping fail** | `" .. plr.Name .. "`", 0xff8800)
end
lastPing = os.time()

wait(1)
d("🎁 **Auto Claim khi khởi động...**", 0xffaa00)
claimAll()

d("✅ **Auto-claim active**\n**Mở Hộp thư** để load inbox + tự nhận quà\n⏱️ Re-claim mỗi 35s", 0x00ff88)

while true do
    local now = os.time()

    if now - lastPing >= CONFIG.PING_INTERVAL then
        local okNow = pingBot()
        if not okNow then
            d("⚠️ **Periodic ping fail** | `" .. plr.Name .. "`", 0xff8800)
        end
        lastPing = now
    end

    local okScan, scanErr = pcall(function()
        checkInbox()
    end)
    if not okScan then
        d("❌ **Inbox scan crash** | `" .. plr.Name .. "`\n`" .. tostring(scanErr) .. "`", 0xff4444)
    end

    if not hooked and now - lastAlive >= 30 then
        lastAlive = now
        d("ℹ️ **Scanner alive, waiting event/mail** | `" .. plr.Name .. "`", 0x888888)
    end

    wait(35)
    claimAll()
end
