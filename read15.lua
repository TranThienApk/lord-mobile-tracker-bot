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
    CLAIM_DELAY = 0.7,
    RECLAIM_INTERVAL = 35,
}

local req =
    request or
    http_request or
    syn.request or
    (http and http.request)

local function safeRequest(payload)
    if not req then
        return nil, "request_not_supported"
    end

    local ok, res = pcall(function()
        return req(payload)
    end)

    if not ok then
        return nil, tostring(res)
    end

    return res, nil
end

local function d(msg, color)
    if not CONFIG.WEBHOOK or CONFIG.WEBHOOK == "" then
        return
    end

    safeRequest({
        Url = CONFIG.WEBHOOK,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json"
        },
        Body = Http:JSONEncode({
            embeds = {{
                description = tostring(msg),
                color = color or 0x00ccff
            }}
        })
    })
end

local function fmt(n)
    n = math.floor(tonumber(n) or 0)

    local s = tostring(n)
    local result = ""
    local len = #s

    for i = 1, len do
        if i > 1 and (len - i + 1) % 3 == 0 then
            result = result .. ","
        end

        result = result .. s:sub(i, i)
    end

    return result
end

local function fmtTime(ts)
    if not ts then
        return "?"
    end

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

local function getDiamondBalance()
    local ok, save = pcall(function()
        return require(RS.Library.Client.Save).Get()
    end)

    if not ok or not save then
        return 0
    end

    if type(save.Inventory) ~= "table" then
        return 0
    end

    if type(save.Inventory.Currency) ~= "table" then
        return 0
    end

    for _, item in pairs(save.Inventory.Currency) do
        if item.id == "Diamonds" then
            return tonumber(item._am or 0) or 0
        end
    end

    return 0
end

local function pingBot()
    local balance = getDiamondBalance()

    local body =
        "bot_username=" .. Http:UrlEncode(plr.Name) ..
        "&stock_gems=" .. Http:UrlEncode(tostring(balance)) ..
        "&type=RECEIVE"

    local res, err = safeRequest({
        Url = CONFIG.API_PING,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/x-www-form-urlencoded",
            ["X-Bot-Key"] = CONFIG.BOT_SECRET
        },
        Body = body
    })

    if err or not res then
        d(
            "❌ **Ping fail** | `" .. plr.Name ..
            "`\n`" .. tostring(err or "no_response") .. "`",
            0xff4444
        )

        return false
    end

    return true
end

local seenUUID = {}

local function parseMail(mail)
    if type(mail) ~= "table" then
        return nil
    end

    local uuid = tostring(
        mail.uuid or
        mail.UUID or
        mail.id or
        ""
    )

    if uuid == "" then
        return nil
    end

    if seenUUID[uuid] then
        return nil
    end

    seenUUID[uuid] = true

    local sender = tostring(
        mail.SenderName or
        mail.sender or
        "Unknown"
    )

    local message = tostring(
        mail.Message or
        mail.message or
        ""
    )

    local ts = fmtTime(mail.Timestamp)

    local item = mail.Item

    local itemStr = ""
    local amount = 0

    if type(item) == "table" then
        local data = item.data or item.Data

        if type(data) == "table" then
            amount = tonumber(
                data._am or
                data.amount or
                data.Amount or
                0
            ) or 0

            local itemId =
                tostring(data.id or "Unknown")

            itemStr =
                "💎 **" ..
                fmt(amount) ..
                "** " ..
                itemId
        end
    end

    return {
        uuid = uuid,
        sender = sender,
        message = message,
        ts = ts,
        amount = amount,
        itemStr = itemStr
    }
end

local function reportMail(sender, message, amount, uuid, itemText)
    local transId =
        "MAIL_" .. tostring(uuid):sub(1, 8)

    local body =
        "sender=" .. Http:UrlEncode(tostring(sender or "")) ..
        "&message=" .. Http:UrlEncode(tostring(message or "")) ..
        "&amount=" .. Http:UrlEncode(tostring(amount or 0)) ..
        "&item=" .. Http:UrlEncode(tostring(itemText or "")) ..
        "&uuid=" .. Http:UrlEncode(tostring(uuid or "")) ..
        "&trans_id=" .. Http:UrlEncode(transId) ..
        "&bot_account=" .. Http:UrlEncode(plr.Name)

    local res, err = safeRequest({
        Url = CONFIG.API_REPORT,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/x-www-form-urlencoded",
            ["X-Bot-Key"] = CONFIG.BOT_SECRET
        },
        Body = body
    })

    if err or not res then
        return false, "no_response"
    end

    local rawBody = tostring(res.Body or "")

    if rawBody == "" then
        return false, "empty_body"
    end

    local okDecode, data = pcall(function()
        return Http:JSONDecode(rawBody)
    end)

    if not okDecode or type(data) ~= "table" then
        return false, "invalid_json"
    end

    if data.success ~= true then
        return false, tostring(data.message or "rejected")
    end

    return true, tostring(data.action or "CLAIM")
end

local function claimMail(uuid)
    pcall(function()
        network.Invoke("Mailbox: Claim", tostring(uuid))
    end)
end

local function claimAll()
    pcall(function()
        network.Invoke("Mailbox: Claim All")
    end)
end

local function processInbox(data)
    local inbox =
        data.Inbox or
        data.inbox or
        data

    if type(inbox) ~= "table" then
        return
    end

    local mails = {}
    local total = 0

    for _, mail in pairs(inbox) do
        local p = parseMail(mail)

        if p then
            table.insert(mails, p)
            total = total + p.amount
        end
    end

    if #mails == 0 then
        return
    end

    d(
        "📬 **" .. #mails ..
        " mail(s)** | `" .. plr.Name ..
        "`\n💎 Tổng nhận: **" ..
        fmt(total) .. "**",
        0x5599ff
    )

    for _, m in ipairs(mails) do
        d(
            "👤 **" .. m.sender ..
            "** · ⏰ " .. m.ts ..
            "\n💬 _" ..
            (#m.message > 0 and m.message or "[no message]") ..
            "_\n" ..
            m.itemStr ..
            "\n🆔 `" ..
            m.uuid:sub(1, 8) ..
            "...`",
            0x00ccff
        )

        local ok, action =
            reportMail(
                m.sender,
                m.message,
                m.amount,
                m.uuid,
                m.itemStr
            )

        if ok and action == "CLAIM" then
            wait(CONFIG.CLAIM_DELAY)

            claimMail(m.uuid)

            d(
                "✅ **Mail accepted** | `" ..
                plr.Name ..
                "`\nSender: `" ..
                m.sender ..
                "`\nAmount: `" ..
                tostring(m.amount) ..
                "`",
                0x00ff88
            )
        end
    end
end

local function checkInbox(data)
    if type(data) == "table" then
        local inbox =
            data.Inbox or
            data.inbox or
            data

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

pcall(function()
    local inboxEvent =
        Net and (
            Net:FindFirstChild("Inbox Updated") or
            Net["Inbox Updated"]
        )

    if inboxEvent and inboxEvent.OnClientEvent then
        inboxEvent.OnClientEvent:Connect(function(data)
            pcall(function()
                checkInbox(data)
            end)
        end)
    end
end)

notify(
    "Mailbox Reader",
    "Đang quét inbox..."
)

d(
    "✅ **MAILBOX READER STARTED** | `" ..
    plr.Name ..
    "`",
    0x00ff88
)

pingBot()

wait(1)

claimAll()

local lastPing = os.time()

while true do
    local now = os.time()

    if now - lastPing >= CONFIG.PING_INTERVAL then
        pingBot()
        lastPing = now
    end

    pcall(function()
        checkInbox()
    end)

    wait(CONFIG.RECLAIM_INTERVAL)

    claimAll()
end

