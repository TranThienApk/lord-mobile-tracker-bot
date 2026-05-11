-- =========================================================
-- AutoGemStore - PS99 Mailbox Receiver Bot (FIXED)
-- =========================================================
-- Tính năng: Đọc mail, báo cáo về server, tự động nhận quà

local CONFIG = {
    BASE_URL = "https://autogemstore.online",
    API_REPORT = "https://autogemstore.online/api/report_received_mail.php",
    API_PING = "https://autogemstore.online/api/bot_ping.php",
    BOT_SECRET = "AGS_2026_9fK2xQm7Rz1Lp4Vn8Tw6Yc3Hd0Sb5Ju",
    WEBHOOK = "",
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

local seenUUIDs = {}

-- =========================================================
-- UTILITY: Request với error handling
-- =========================================================
local function safeRequest(payload)
    local ok, res = pcall(function()
        return request(payload)
    end)

    if not ok then
        warn("[REQUEST ERROR]", res)
        return nil, "request_failed"
    end

    return res, nil
end

-- =========================================================
-- HEARTBEAT: Gửi tín hiệu "bot còn sống" mỗi 20s
-- =========================================================
spawn(function()
    while true do
        pcall(function()
            safeRequest({
                Url = CONFIG.BASE_URL .. "/api/bot_heartbeat.php",
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/x-www-form-urlencoded"
                },
                Body = "bot_name=" .. Http:UrlEncode(plr.Name) .. "&type=read"
            })
        end)
        task.wait(20)
    end
end)

-- =========================================================
-- PING: Kiểm tra bot còn hoạt động không
-- =========================================================
local function pingBot()
    local res, err = safeRequest({
        Url = CONFIG.API_PING,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/x-www-form-urlencoded",
            ["X-Bot-Key"] = CONFIG.BOT_SECRET
        },
        Body = "bot_username=" .. Http:UrlEncode(plr.Name)
    })

    if err then
        warn("[PING ERROR]", err)
        return false
    end

    if res and res.StatusCode == 200 then
        print("[PING OK]", plr.Name)
        return true
    else
        warn("[PING FAILED]", res and res.StatusCode or "No response")
        return false
    end
end

-- =========================================================
-- REPORT: Gửi thông tin mail đến server để xác nhận
-- =========================================================
local function reportMail(sender, message, amount, uuid)
    -- Validate inputs
    if not sender or not uuid then
        warn("[REPORT] Invalid input: sender=" .. tostring(sender) .. ", uuid=" .. tostring(uuid))
        return false, "REJECT"
    end

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
            .. "&uuid=" .. Http:UrlEncode(tostring(uuid))
            .. "&bot_username=" .. Http:UrlEncode(plr.Name)
    })

    -- ✓ Check request error
    if err then
        warn("[REPORT ERROR]", err)
        return false, "REJECT"
    end

    -- ✓ Check response exists
    if not res then
        warn("[REPORT] No response from server")
        return false, "REJECT"
    end

    -- ✓ Check HTTP status code
    if res.StatusCode ~= 200 then
        warn("[REPORT] HTTP", res.StatusCode, "- Body:", res.Body)
        return false, "REJECT"
    end

    -- ✓ Try to parse JSON
    local okDecode, data = pcall(function()
        return Http:JSONDecode(res.Body)
    end)

    if not okDecode then
        warn("[REPORT] JSON Decode Error:", data)
        return false, "REJECT"
    end

    -- ✓ Validate response data structure
    if type(data) ~= "table" then
        warn("[REPORT] Invalid response type:", type(data))
        return false, "REJECT"
    end

    -- ✓ Extract action from server response
    local success = data.success == true
    local action = data.action or "REJECT"

    if success then
        print("[REPORT OK]", uuid:sub(1, 8) .. "...", "Action:", action)
    else
        warn("[REPORT REJECTED]", uuid:sub(1, 8) .. "...", "Reason:", data.reason or "Unknown")
    end

    return success, action
end

-- =========================================================
-- CLAIM: Nhận mail từ server
-- =========================================================
local function claimMail(uuid)
    if not uuid then
        warn("[CLAIM] Empty UUID")
        return
    end

    pcall(function()
        local result = network.Invoke("Mailbox: Claim", tostring(uuid))
        print("[CLAIM]", uuid:sub(1, 8) .. "...", "Result:", result)
    end)
end

-- =========================================================
-- PROCESS: Xử lý từng mail đơn lẻ
-- =========================================================
local function processMail(mail)
    if type(mail) ~= "table" then
        return
    end

    local uuid = tostring(mail.uuid or "")

    -- ✓ Kiểm tra UUID hợp lệ + không trùng lặp
    if uuid == "" or seenUUIDs[uuid] then
        return
    end

    local sender = tostring(mail.SenderName or mail.sender or "Unknown")
    local message = tostring(mail.Message or mail.message or "")
    local item = mail.Item

    -- ✓ Kiểm tra item có tồn tại và là Currency không
    if type(item) ~= "table" then
        seenUUIDs[uuid] = true
        return
    end

    local class = tostring(item.class or "")
    if class ~= "Currency" then
        seenUUIDs[uuid] = true
        return
    end

    -- ✓ Kiểm tra dữ liệu item
    local data = item.data
    if type(data) ~= "table" then
        seenUUIDs[uuid] = true
        return
    end

    -- ✓ Chỉ nhận Diamonds (id = "Diamonds")
    local itemId = tostring(data.id or "")
    if itemId ~= "Diamonds" then
        seenUUIDs[uuid] = true
        return
    end

    -- ✓ Lấy số lượng Diamonds
    local amount = math.floor(tonumber(data._am or 0))
    if amount <= 0 then
        seenUUIDs[uuid] = true
        return
    end

    print("[MAIL FOUND]", sender, "→", amount, "Diamonds, UUID:", uuid:sub(1, 8) .. "...")

    -- ✓ Báo cáo về server
    local ok, action = reportMail(sender, message, amount, uuid)

    -- ✓ Nếu server cho phép → claim mail
    if ok and action == "CLAIM" then
        task.wait(CONFIG.CLAIM_DELAY)
        claimMail(uuid)
    end

    seenUUIDs[uuid] = true
end

-- =========================================================
-- CHECKINBOX: Lấy toàn bộ inbox và xử lý từng mail
-- =========================================================
local function checkInbox()
    local response = nil

    pcall(function()
        response = network.Invoke("Mailbox: Get")
    end)

    if type(response) == "table" and type(response.Inbox) == "table" then
        local mailCount = 0
        for _, mail in pairs(response.Inbox) do
            processMail(mail)
            mailCount = mailCount + 1
        end
        if mailCount > 0 then
            print("[INBOX] Checked", mailCount, "mails")
        end
    else
        warn("[INBOX] Invalid response format")
    end
end

-- =========================================================
-- HOOK: Lắng nghe sự kiện "Inbox Updated"
-- =========================================================
pcall(function()
    Net["Inbox Updated"].OnClientEvent:Connect(function()
        print("[EVENT] Inbox Updated triggered")
        checkInbox()
    end)
end)

-- =========================================================
-- MAIN LOOP: Quét inbox & ping server
-- =========================================================
local lastPing = 0

while true do
    local now = os.time()

    -- ✓ Ping server mỗi 10 giây
    if now - lastPing >= CONFIG.PING_INTERVAL then
        pingBot()
        lastPing = now
    end

    -- ✓ Quét inbox mỗi 6 giây
    checkInbox()

    task.wait(CONFIG.SCAN_INTERVAL)
end
