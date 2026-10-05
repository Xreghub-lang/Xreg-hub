loadstring([==[
--// Xreg Hub | Defusal (CN Entertainment)
--// Key: XREG-2025
--// Insert = toggle UI | RMB = aimbot

local KEY = "XREG-2025"
local KEY_LINK = "https://jnkie.com/flow/b4619717-919b-40f8-9bcc-f68b6857ec00"

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local Camera     = workspace.CurrentCamera
local LP         = Players.LocalPlayer
local floor, clamp = math.floor, math.clamp

local PlayerGui = LP:WaitForChild("PlayerGui", 10)
if not PlayerGui then return end

local CFG = {
    ESP_ENABLED=true, ESP_BOX=true, ESP_NAME=true,
    ESP_DISTANCE=true, ESP_HEALTH_BAR=true, ESP_TRACER=false,
    BOX_THICKNESS=1.5, TEXT_SIZE=13, TEAM_COLORS=true,
    BOMB_MODEL_NAME="Bomb",
    AIM_ENABLED=false, AIM_SMOOTH=0.15, AIM_FOV=150,
    AIM_SHOW_FOV=true, AIM_BONE="Head",
    NO_MUZZLE=false, FOV_VALUE=70,
    COLOR_CT    = Color3.fromRGB( 80,160,255),
    COLOR_T     = Color3.fromRGB(255, 80, 80),
    COLOR_SELF  = Color3.fromRGB(100,255,100),
    COLOR_BOMB  = Color3.fromRGB(255,220,  0),
    COLOR_TEXT  = Color3.fromRGB(255,255,255),
    COLOR_SHADOW= Color3.fromRGB(  0,  0,  0),
}

local function newLine(t,c)
    local l=Drawing.new("Line") l.Thickness=t or 1 l.Color=c or Color3.new(1,1,1)
    l.Transparency=1 l.Visible=false l.ZIndex=5 return l
end
local function newText(s,c,ce)
    local t=Drawing.new("Text") t.Size=s or 13 t.Color=c or Color3.new(1,1,1)
    t.Outline=true t.Center=ce or false t.Visible=false t.Font=Drawing.Fonts.UI t.ZIndex=6 return t
end
local function newQuad(c,t)
    local ok,q=pcall(function() return Drawing.new("Quad") end)
    if not ok then return setmetatable({},{__index=function() return function()end end,__newindex=function()end}) end
    q.Color=c or Color3.new(1,0,0) q.Thickness=t or 1.5 q.Filled=false q.Visible=false q.ZIndex=5 return q
end
local function newRect(f,c,tr)
    local r=Drawing.new("Square") r.Filled=f~=false r.Color=c or Color3.new(0,0,0)
    r.Transparency=tr or 0.5 r.Visible=false r.ZIndex=4 return r
end
local function newCircle(r,c,t)
    local ci=Drawing.new("Circle") ci.Radius=r or 100 ci.Color=c or Color3.new(1,1,1)
    ci.Thickness=t or 1 ci.Filled=false ci.Visible=false ci.ZIndex=7 return ci
end

local function w2s(pos)
    local sp,on=Camera:WorldToViewportPoint(pos) return Vector2.new(sp.X,sp.Y),on,sp.Z
end
local function getHPColor(f)
    return Color3.fromRGB(floor(clamp(2*(1-f),0,1)*220),floor(clamp(2*f,0,1)*200),40)
end
local function getTeamColor(p)
    if p==LP then return CFG.COLOR_SELF end
    if not CFG.TEAM_COLORS then return CFG.COLOR_T end
    local t=p.Team
    if t then local n=t.Name:lower()
        if n:find("counter") or n:find("ct") or n:find("defend") or n:find("blue") then return CFG.COLOR_CT end
    end
    return CFG.COLOR_T
end
local function getCharBounds(char)
    local hrp=char:FindFirstChild("HumanoidRootPart") if not hrp then return nil end
    local tp=hrp.Position+Vector3.new(0,3.5,0)
    local bp=hrp.Position+Vector3.new(0,-3,0)
    local tsp,ton,tz=w2s(tp) local bsp=w2s(bp)
    if (not ton) or tz<0 then return nil end
    local h=math.abs(tsp.Y-bsp.Y) local hw=h*0.45/2
    return{TL=Vector2.new(tsp.X-hw,tsp.Y),TR=Vector2.new(tsp.X+hw,tsp.Y),
           BR=Vector2.new(bsp.X+hw,bsp.Y),BL=Vector2.new(bsp.X-hw,bsp.Y),
           top=tsp,bot=bsp,cx=tsp.X,h=h,hw=hw,dist=tz}
end
local function findBomb()
    local b=workspace:FindFirstChild(CFG.BOMB_MODEL_NAME,true) if not b then return nil end
    if b:IsA("BasePart") then return b end return b:FindFirstChildOfClass("BasePart")
end

local ESPPool={}
local function allocESP(p)
    local c=getTeamColor(p)
    return{boxOut=newQuad(CFG.COLOR_SHADOW,CFG.BOX_THICKNESS+1.5),box=newQuad(c,CFG.BOX_THICKNESS),
           name=newText(CFG.TEXT_SIZE,CFG.COLOR_TEXT,true),
           dist=newText(CFG.TEXT_SIZE-1,Color3.fromRGB(180,180,180),true),
           hpBg=newRect(true,Color3.fromRGB(20,20,20),0.5),hpBar=newRect(true,Color3.fromRGB(50,200,80),1),
           tracer=newLine(1,c)}
end
local function hideESP(o) for _,v in pairs(o) do v.Visible=false end end
local function freeESP(o) for _,v in pairs(o) do v:Remove() end end

local BombESP={label=newText(CFG.TEXT_SIZE,CFG.COLOR_BOMB,true),tracer=newLine(1.5,CFG.COLOR_BOMB)}
local fovCircle=newCircle(CFG.AIM_FOV,Color3.fromRGB(255,255,255),1)

local aiming=false
UIS.InputBegan:Connect(function(i,gpe)
    if not gpe and i.UserInputType==Enum.UserInputType.MouseButton2 then aiming=true end
end)
UIS.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton2 then aiming=false end
end)
local function getAimTarget()
    local vp=Camera.ViewportSize
    local center=Vector2.new(vp.X/2,vp.Y/2)
    local best,bestDist=nil,CFG.AIM_FOV
    for _,p in ipairs(Players:GetPlayers()) do
        if p==LP then continue end
        local char=p.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        if not char or not hum or hum.Health<=0 then continue end
        local bone=char:FindFirstChild(CFG.AIM_BONE) or char:FindFirstChild("HumanoidRootPart")
        if not bone then continue end
        local sp,on,z=w2s(bone.Position)
        if not on or z<0 then continue end
        local d=(sp-center).Magnitude
        if d<bestDist then bestDist=d best=bone end
    end
    return best
end

local muzzleT=0
local function disableMuzzle()
    local char=LP.Character if not char then return end
    for _,obj in ipairs(char:GetDescendants()) do
        if obj:IsA("ParticleEmitter") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
            local pn=(obj.Parent and obj.Parent.Name:lower()) or ""
            local on=obj.Name:lower()
            if pn:find("muzzle") or on:find("flash") or on:find("muzzle") or on:find("smoke") then
                obj.Enabled=false
            end
        end
    end
end
local function enableMuzzle()
    local char=LP.Character if not char then return end
    for _,obj in ipairs(char:GetDescendants()) do
        if obj:IsA("ParticleEmitter") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
            obj.Enabled=true
        end
    end
end

-- ══════════════════════════════════════════════════════════════
-- GUI
-- ══════════════════════════════════════════════════════════════
local function makeGui()
    local old=PlayerGui:FindFirstChild("XregHub") if old then old:Destroy() end

    local gui=Instance.new("ScreenGui")
    gui.Name="XregHub" gui.ResetOnSpawn=false
    gui.IgnoreGuiInset=true
    gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    gui.Parent=PlayerGui

    -- ── KEY SCREEN ─────────────────────────────────────────
    local kf=Instance.new("Frame")
    kf.Name="KeyFrame"
    kf.Size=UDim2.new(0,360,0,240)
    kf.Position=UDim2.new(0.5,-180,0.5,-120)
    kf.BackgroundColor3=Color3.fromRGB(14,14,14)
    kf.BorderSizePixel=0 kf.Visible=true kf.Parent=gui

    -- yellow accent bar
    local accent=Instance.new("Frame")
    accent.Size=UDim2.new(1,0,0,3)
    accent.BackgroundColor3=Color3.fromRGB(255,220,60)
    accent.BorderSizePixel=0 accent.Parent=kf

    -- title bar
    local ktb=Instance.new("Frame")
    ktb.Position=UDim2.new(0,0,0,3) ktb.Size=UDim2.new(1,0,0,36)
    ktb.BackgroundColor3=Color3.fromRGB(20,20,20) ktb.BorderSizePixel=0 ktb.Parent=kf

    local ktitle=Instance.new("TextLabel")
    ktitle.Size=UDim2.new(1,0,1,0) ktitle.BackgroundTransparency=1
    ktitle.Text="🔑  Xreg Hub — Key System"
    ktitle.TextSize=15 ktitle.TextColor3=Color3.fromRGB(255,220,60)
    ktitle.Font=Enum.Font.GothamBold ktitle.Parent=ktb

    -- instruction
    local kinst=Instance.new("TextLabel")
    kinst.Position=UDim2.new(0,0,0,48) kinst.Size=UDim2.new(1,0,0,18)
    kinst.BackgroundTransparency=1
    kinst.Text="Complete the checkpoint below to receive your key"
    kinst.TextSize=12 kinst.TextColor3=Color3.fromRGB(150,150,150)
    kinst.Font=Enum.Font.Gotham kinst.Parent=kf

    -- GET KEY button
    local gkb=Instance.new("TextButton")
    gkb.Position=UDim2.new(0,12,0,74) gkb.Size=UDim2.new(1,-24,0,38)
    gkb.BackgroundColor3=Color3.fromRGB(255,220,60) gkb.BorderSizePixel=0
    gkb.Text="🔗  Get Key" gkb.TextSize=14
    gkb.TextColor3=Color3.fromRGB(14,14,14) gkb.Font=Enum.Font.GothamBold gkb.Parent=kf

    local gcopy=Instance.new("TextLabel")
    gcopy.Position=UDim2.new(0,0,0,116) gcopy.Size=UDim2.new(1,0,0,14)
    gcopy.BackgroundTransparency=1 gcopy.Text=""
    gcopy.TextSize=11 gcopy.TextColor3=Color3.fromRGB(100,220,100)
    gcopy.Font=Enum.Font.Gotham gcopy.Parent=kf

    -- copy link to clipboard on click
    gkb.MouseButton1Click:Connect(function()
        pcall(function() setclipboard(KEY_LINK) end)
        gcopy.Text="✔  Link copied to clipboard — paste in browser"
        gkb.Text="🔗  Copied!"
        gkb.BackgroundColor3=Color3.fromRGB(70,190,70)
        gkb.TextColor3=Color3.fromRGB(255,255,255)
        task.delay(3, function()
            gkb.Text="🔗  Get Key"
            gkb.BackgroundColor3=Color3.fromRGB(255,220,60)
            gkb.TextColor3=Color3.fromRGB(14,14,14)
            gcopy.Text=""
        end)
    end)

    -- divider
    local kdiv=Instance.new("Frame")
    kdiv.Position=UDim2.new(0,12,0,138) kdiv.Size=UDim2.new(1,-24,0,1)
    kdiv.BackgroundColor3=Color3.fromRGB(35,35,35) kdiv.BorderSizePixel=0 kdiv.Parent=kf

    -- input row
    local kb=Instance.new("TextBox")
    kb.Position=UDim2.new(0,12,0,148) kb.Size=UDim2.new(0,240,0,34)
    kb.BackgroundColor3=Color3.fromRGB(24,24,24) kb.BorderSizePixel=0
    kb.Text="" kb.PlaceholderText="Paste key here..."
    kb.TextColor3=Color3.fromRGB(255,255,255) kb.PlaceholderColor3=Color3.fromRGB(70,70,70)
    kb.Font=Enum.Font.Gotham kb.TextSize=13 kb.ClearTextOnFocus=false kb.Parent=kf

    local ksb=Instance.new("TextButton")
    ksb.Position=UDim2.new(0,260,0,148) ksb.Size=UDim2.new(0,88,0,34)
    ksb.BackgroundColor3=Color3.fromRGB(255,220,60) ksb.BorderSizePixel=0
    ksb.Text="Unlock" ksb.TextSize=13
    ksb.TextColor3=Color3.fromRGB(14,14,14) ksb.Font=Enum.Font.GothamBold ksb.Parent=kf

    local kerr=Instance.new("TextLabel")
    kerr.Position=UDim2.new(0,0,0,188) kerr.Size=UDim2.new(1,0,0,16)
    kerr.BackgroundTransparency=1 kerr.Text=""
    kerr.TextSize=12 kerr.TextColor3=Color3.fromRGB(255,80,80)
    kerr.Font=Enum.Font.Gotham kerr.Parent=kf

    local kver=Instance.new("TextLabel")
    kver.Position=UDim2.new(0,0,0,216) kver.Size=UDim2.new(1,0,0,12)
    kver.BackgroundTransparency=1 kver.Text="Xreg Hub v1.0  |  Defusal by CN Entertainment"
    kver.TextSize=10 kver.TextColor3=Color3.fromRGB(40,40,40)
    kver.Font=Enum.Font.Gotham kver.Parent=kf

    -- ── MAIN PANEL ─────────────────────────────────────────
    local mf=Instance.new("Frame")
    mf.Name="MainFrame"
    mf.Size=UDim2.new(0,400,0,320)
    mf.Position=UDim2.new(0.5,-200,0.5,-160)
    mf.BackgroundColor3=Color3.fromRGB(14,14,14)
    mf.BorderSizePixel=0 mf.Active=true mf.Draggable=true
    mf.Visible=false mf.Parent=gui

    local accent2=Instance.new("Frame")
    accent2.Size=UDim2.new(1,0,0,3)
    accent2.BackgroundColor3=Color3.fromRGB(255,220,60)
    accent2.BorderSizePixel=0 accent2.Parent=mf

    local mtb=Instance.new("Frame")
    mtb.Position=UDim2.new(0,0,0,3) mtb.Size=UDim2.new(1,0,0,34)
    mtb.BackgroundColor3=Color3.fromRGB(20,20,20) mtb.BorderSizePixel=0 mtb.Parent=mf

    local mtl=Instance.new("TextLabel")
    mtl.Position=UDim2.new(0,12,0,0) mtl.Size=UDim2.new(1,-40,1,0)
    mtl.BackgroundTransparency=1 mtl.Text="Xreg Hub"
    mtl.TextSize=15 mtl.TextColor3=Color3.fromRGB(255,220,60)
    mtl.Font=Enum.Font.GothamBold mtl.TextXAlignment=Enum.TextXAlignment.Left mtl.Parent=mtb

    local mcb=Instance.new("TextButton")
    mcb.Position=UDim2.new(1,-34,0,0) mcb.Size=UDim2.new(0,34,1,0)
    mcb.BackgroundTransparency=1 mcb.Text="✕" mcb.TextSize=14
    mcb.TextColor3=Color3.fromRGB(180,180,180) mcb.Font=Enum.Font.GothamBold mcb.Parent=mtb
    mcb.MouseButton1Click:Connect(function() mf.Visible=false end)

    local tabBarF=Instance.new("Frame")
    tabBarF.Position=UDim2.new(0,0,0,37) tabBarF.Size=UDim2.new(1,0,0,30)
    tabBarF.BackgroundColor3=Color3.fromRGB(18,18,18) tabBarF.BorderSizePixel=0 tabBarF.Parent=mf

    local tdiv=Instance.new("Frame")
    tdiv.Position=UDim2.new(0,0,0,67) tdiv.Size=UDim2.new(1,0,0,1)
    tdiv.BackgroundColor3=Color3.fromRGB(30,30,30) tdiv.BorderSizePixel=0 tdiv.Parent=mf

    local ca=Instance.new("Frame")
    ca.Position=UDim2.new(0,0,0,68) ca.Size=UDim2.new(1,0,1,-68)
    ca.BackgroundTransparency=1 ca.Parent=mf

    local tabFrames,tabBtns={},{}
    local tabNames={"ESP","Aimbot","Visuals"}
    local tw=1/#tabNames

    local function setTab(name)
        for n,f in pairs(tabFrames) do f.Visible=(n==name) end
        for n,b in pairs(tabBtns) do
            if n==name then
                b.BackgroundColor3=Color3.fromRGB(255,220,60)
                b.TextColor3=Color3.fromRGB(14,14,14)
            else
                b.BackgroundColor3=Color3.fromRGB(18,18,18)
                b.TextColor3=Color3.fromRGB(160,160,160)
            end
        end
    end

    for i,name in ipairs(tabNames) do
        local tb=Instance.new("TextButton")
        tb.Position=UDim2.new(tw*(i-1),0,0,0) tb.Size=UDim2.new(tw,0,1,0)
        tb.BackgroundColor3=Color3.fromRGB(18,18,18) tb.BorderSizePixel=0
        tb.Text=name tb.TextSize=13 tb.TextColor3=Color3.fromRGB(160,160,160)
        tb.Font=Enum.Font.GothamBold tb.Parent=tabBarF
        tabBtns[name]=tb
        tb.MouseButton1Click:Connect(function() setTab(name) end)
        local sf=Instance.new("ScrollingFrame")
        sf.Size=UDim2.new(1,0,1,0) sf.BackgroundTransparency=1 sf.BorderSizePixel=0
        sf.ScrollBarThickness=3 sf.CanvasSize=UDim2.new(0,0,0,0)
        sf.Visible=false sf.Parent=ca
        tabFrames[name]=sf
    end

    local function mkToggle(parent,label,y,get,set)
        local row=Instance.new("Frame")
        row.Position=UDim2.new(0,10,0,y) row.Size=UDim2.new(1,-20,0,28)
        row.BackgroundTransparency=1 row.Parent=parent
        local lbl=Instance.new("TextLabel")
        lbl.Size=UDim2.new(1,-54,1,0) lbl.BackgroundTransparency=1
        lbl.Text=label lbl.TextSize=13 lbl.TextColor3=Color3.fromRGB(210,210,210)
        lbl.Font=Enum.Font.Gotham lbl.TextXAlignment=Enum.TextXAlignment.Left lbl.Parent=row
        local tog=Instance.new("TextButton")
        tog.Position=UDim2.new(1,-48,0.5,-12) tog.Size=UDim2.new(0,48,0,24)
        tog.BorderSizePixel=0 tog.Font=Enum.Font.GothamBold tog.TextSize=11 tog.Parent=row
        local function ref()
            local v=get()
            tog.BackgroundColor3=v and Color3.fromRGB(70,190,70) or Color3.fromRGB(48,48,48)
            tog.TextColor3=v and Color3.fromRGB(14,14,14) or Color3.fromRGB(130,130,130)
            tog.Text=v and "ON" or "OFF"
        end
        ref()
        tog.MouseButton1Click:Connect(function() set(not get()) ref() end)
        return y+32
    end

    local function mkSlider(parent,label,y,mn,mx,get,set)
        local row=Instance.new("Frame")
        row.Position=UDim2.new(0,10,0,y) row.Size=UDim2.new(1,-20,0,48)
        row.BackgroundTransparency=1 row.Parent=parent
        local lbl=Instance.new("TextLabel")
        lbl.Size=UDim2.new(1,0,0,18) lbl.BackgroundTransparency=1
        lbl.Text=label..": "..get() lbl.TextSize=13 lbl.TextColor3=Color3.fromRGB(210,210,210)
        lbl.Font=Enum.Font.Gotham lbl.TextXAlignment=Enum.TextXAlignment.Left lbl.Parent=row
        local trackBg=Instance.new("Frame")
        trackBg.Position=UDim2.new(0,0,0,26) trackBg.Size=UDim2.new(1,0,0,8)
        trackBg.BackgroundColor3=Color3.fromRGB(36,36,36) trackBg.BorderSizePixel=0 trackBg.Parent=row
        local fill=Instance.new("Frame")
        fill.Size=UDim2.new((get()-mn)/(mx-mn),0,1,0)
        fill.BackgroundColor3=Color3.fromRGB(255,220,60) fill.BorderSizePixel=0 fill.Parent=trackBg
        local dragging=false
        trackBg.InputBegan:Connect(function(inp)
            if inp.UserInputType==Enum.UserInputType.MouseButton1 then
                dragging=true
                local frac=clamp((inp.Position.X-trackBg.AbsolutePosition.X)/trackBg.AbsoluteSize.X,0,1)
                local val=math.round(mn+frac*(mx-mn))
                set(val) fill.Size=UDim2.new(frac,0,1,0) lbl.Text=label..": "..val
            end
        end)
        UIS.InputEnded:Connect(function(inp)
            if inp.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
        end)
        UIS.InputChanged:Connect(function(inp)
            if dragging and inp.UserInputType==Enum.UserInputType.MouseMovement then
                local frac=clamp((inp.Position.X-trackBg.AbsolutePosition.X)/trackBg.AbsoluteSize.X,0,1)
                local val=math.round(mn+frac*(mx-mn))
                set(val) fill.Size=UDim2.new(frac,0,1,0) lbl.Text=label..": "..val
            end
        end)
        return y+54
    end

    do
        local t=tabFrames["ESP"] local y=8
        y=mkToggle(t,"ESP Enabled",  y,function() return CFG.ESP_ENABLED    end,function(v) CFG.ESP_ENABLED=v    end)
        y=mkToggle(t,"Box ESP",      y,function() return CFG.ESP_BOX        end,function(v) CFG.ESP_BOX=v        end)
        y=mkToggle(t,"Name ESP",     y,function() return CFG.ESP_NAME       end,function(v) CFG.ESP_NAME=v       end)
        y=mkToggle(t,"Distance",     y,function() return CFG.ESP_DISTANCE   end,function(v) CFG.ESP_DISTANCE=v   end)
        y=mkToggle(t,"Health Bar",   y,function() return CFG.ESP_HEALTH_BAR end,function(v) CFG.ESP_HEALTH_BAR=v end)
        y=mkToggle(t,"Tracers",      y,function() return CFG.ESP_TRACER     end,function(v) CFG.ESP_TRACER=v     end)
        y=mkToggle(t,"Team Colors",  y,function() return CFG.TEAM_COLORS    end,function(v) CFG.TEAM_COLORS=v    end)
        t.CanvasSize=UDim2.new(0,0,0,y+10)
    end
    do
        local t=tabFrames["Aimbot"] local y=8
        y=mkToggle(t,"Aimbot (RMB)", y,function() return CFG.AIM_ENABLED  end,function(v) CFG.AIM_ENABLED=v  end)
        y=mkToggle(t,"Show FOV",     y,function() return CFG.AIM_SHOW_FOV end,function(v) CFG.AIM_SHOW_FOV=v end)
        y=mkSlider(t,"Smoothness",   y,1,30,
            function() return math.round(CFG.AIM_SMOOTH*100) end,
            function(v) CFG.AIM_SMOOTH=v/100 end)
        y=mkSlider(t,"FOV Radius",   y,50,400,
            function() return CFG.AIM_FOV end,
            function(v) CFG.AIM_FOV=v fovCircle.Radius=v end)
        t.CanvasSize=UDim2.new(0,0,0,y+10)
    end
    do
        local t=tabFrames["Visuals"] local y=8
        y=mkToggle(t,"No Muzzle Flash",y,function() return CFG.NO_MUZZLE end,function(v)
            CFG.NO_MUZZLE=v
            if v then disableMuzzle() else enableMuzzle() end
        end)
        y=mkSlider(t,"Camera FOV",y,50,120,
            function() return CFG.FOV_VALUE end,
            function(v) CFG.FOV_VALUE=v Camera.FieldOfView=v end)
        t.CanvasSize=UDim2.new(0,0,0,y+10)
    end

    setTab("ESP")

    local function tryKey()
        local input=kb.Text:gsub("%s","")
        if input==KEY then
            kerr.Text="" kf.Visible=false mf.Visible=true
            print("[Xreg Hub] unlocked")
        else
            kerr.Text="✖  Invalid key — click Get Key above"
            kb.Text=""
        end
    end
    ksb.MouseButton1Click:Connect(tryKey)
    kb.FocusLost:Connect(function(enter) if enter then tryKey() end end)

    UIS.InputBegan:Connect(function(inp,gpe)
        if gpe then return end
        if inp.KeyCode==Enum.KeyCode.Insert then
            if not kf.Visible then mf.Visible=not mf.Visible end
        end
    end)

    print("[Xreg Hub] loaded — click Get Key to get your key")
end

-- ══════════════════════════════════════════════════════════════
-- RENDER LOOP
-- ══════════════════════════════════════════════════════════════
RunService.RenderStepped:Connect(function()
    local vp=Camera.ViewportSize
    local sb=Vector2.new(vp.X/2,vp.Y-5)
    local sc=Vector2.new(vp.X/2,vp.Y/2)

    fovCircle.Position=sc fovCircle.Radius=CFG.AIM_FOV
    fovCircle.Visible=CFG.AIM_ENABLED and CFG.AIM_SHOW_FOV

    if CFG.AIM_ENABLED and aiming then
        local target=getAimTarget()
        if target then
            Camera.CFrame=Camera.CFrame:Lerp(
                CFrame.new(Camera.CFrame.Position,target.Position),CFG.AIM_SMOOTH)
        end
    end

    local now=tick()
    if CFG.NO_MUZZLE and now-muzzleT>0.1 then muzzleT=now disableMuzzle() end

    for _,player in ipairs(Players:GetPlayers()) do
        if player==LP then continue end
        if not ESPPool[player] then ESPPool[player]=allocESP(player) end
        local obj=ESPPool[player]
        local char=player.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        if not char or not hum or hum.Health<=0 then hideESP(obj) continue end
        local b=getCharBounds(char)
        if not b or not CFG.ESP_ENABLED then hideESP(obj) continue end
        local color=getTeamColor(player)
        local hp=clamp(hum.Health/hum.MaxHealth,0,1)
        local pad=Vector2.new(1,1)
        obj.boxOut.PointA=b.TL-pad obj.boxOut.PointB=b.TR+Vector2.new(1,-1)
        obj.boxOut.PointC=b.BR+pad obj.boxOut.PointD=b.BL+Vector2.new(-1,1)
        obj.boxOut.Visible=CFG.ESP_BOX
        obj.box.PointA=b.TL obj.box.PointB=b.TR obj.box.PointC=b.BR obj.box.PointD=b.BL
        obj.box.Color=color obj.box.Visible=CFG.ESP_BOX
        obj.name.Text=player.Name obj.name.Color=color
        obj.name.Position=Vector2.new(b.cx,b.TL.Y-16) obj.name.Visible=CFG.ESP_NAME
        obj.dist.Text=floor(b.dist).."m"
        obj.dist.Position=Vector2.new(b.cx,b.BL.Y+2) obj.dist.Visible=CFG.ESP_DISTANCE
        if CFG.ESP_HEALTH_BAR then
            local bx=b.TL.X-6 local bh=b.h local fh=bh*hp
            obj.hpBg.Position=Vector2.new(bx,b.TL.Y) obj.hpBg.Size=Vector2.new(4,bh) obj.hpBg.Visible=true
            obj.hpBar.Position=Vector2.new(bx,b.TL.Y+(bh-fh)) obj.hpBar.Size=Vector2.new(4,fh)
            obj.hpBar.Color=getHPColor(hp) obj.hpBar.Visible=true
        else obj.hpBg.Visible=false obj.hpBar.Visible=false end
        obj.tracer.From=sb obj.tracer.To=b.bot obj.tracer.Color=color obj.tracer.Visible=CFG.ESP_TRACER
    end

    for player,obj in pairs(ESPPool) do
        if not Players:FindFirstChild(player.Name) then freeESP(obj) ESPPool[player]=nil end
    end

    local bombPart=findBomb()
    if CFG.ESP_ENABLED and bombPart then
        local sp,on,dist=w2s(bombPart.Position)
        if on and dist>0 then
            BombESP.label.Position=Vector2.new(sp.X,sp.Y-14)
            BombESP.label.Text=string.format("◆ BOMB  %.0fm",dist)
            BombESP.label.Visible=true
            BombESP.tracer.From=sb BombESP.tracer.To=sp BombESP.tracer.Visible=true
        else
            local ex=clamp(sp.X,30,vp.X-30) local ey=clamp(sp.Y,30,vp.Y-30)
            BombESP.label.Position=Vector2.new(ex,ey)
            BombESP.label.Text=string.format("▶ BOMB  %.0fm",dist or 0)
            BombESP.label.Visible=true BombESP.tracer.Visible=false
        end
    else BombESP.label.Visible=false BombESP.tracer.Visible=false end
end)

makeGui()
]==])()
