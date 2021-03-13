local heroes = false
local checkCount = 0 
local menu = 1
local Orb
local _OnWaypoint = {}
local _OnVision = {}
local castSpell = {state = 0, tick = GetTickCount(), casting = GetTickCount() - 1000, mouse = mousePos}
local spellcast = {state = 1, mouse = mousePos}
local ItemHotKey = {[ITEM_1] = HK_ITEM_1, [ITEM_2] = HK_ITEM_2,[ITEM_3] = HK_ITEM_3, [ITEM_4] = HK_ITEM_4, [ITEM_5] = HK_ITEM_5, [ITEM_6] = HK_ITEM_6, [ITEM_7] = HK_ITEM_7,}
local barHeight, barWidth, barXOffset, barYOffset = 8, 103, 0, 0
local Allies, Enemies, Turrets, Units = {}, {}, {}, {}
local TEAM_ALLY = myHero.team
local TEAM_ENEMY = 300 - myHero.team
local TEAM_JUNGLE = 300
local charging = false
local wClock = 0
local clock = os.clock
local Latency = Game.Latency
local ping = Latency() * 0.001
local MyHeroRange = myHero.range + myHero.boundingRadius * 2
local DrawCircle = Draw.Circle
local DrawColor = Draw.Color
local DrawText = Draw.Text
local ControlCastSpell = Control.CastSpell
local GameCanUseSpell = Game.CanUseSpell
local GameTimer = Game.Timer
local GameHeroCount = Game.HeroCount
local GameHero = Game.Hero
local GameMinionCount = Game.MinionCount
local GameMinion = Game.Minion
local GameTurretCount = Game.TurretCount
local GameTurret = Game.Turret
local GameObjectCount = Game.ObjectCount
local GameObject = Game.Object
local GameParticleCount = Game.ParticleCount
local GameParticle = Game.Particle
local GameMissileCount = Game.MissileCount
local GameMissile = Game.Missile
local GameIsChatOpen = Game.IsChatOpen
local TEAM_ALLY = myHero.team
local TEAM_ENEMY = 300 - myHero.team
local TEAM_JUNGLE = 300
local MathSqrt = math.sqrt
local MathHuge = math.huge
local TableInsert = table.insert
local TableRemove = table.remove
_G.LATENCY = 0.05


function LoadUnits()
	for i = 1, GameHeroCount() do
		local unit = GameHero(i); Units[i] = {unit = unit, spell = nil}
		if unit.team ~= myHero.team then TableInsert(Enemies, unit)
		elseif unit.team == myHero.team and unit ~= myHero then TableInsert(Allies, unit) end
	end
	for i = 1, GameTurretCount() do
		local turret = GameTurret(i)
		if turret and turret.isEnemy then TableInsert(Turrets, turret) end
	end
end

local function CheckLoadedEnemyies()
	local count = 0
	for i, unit in ipairs(Enemies) do
        if unit and unit.isEnemy then
		count = count + 1
		end
	end
	return count
end
		
local function ConvertToHitChance(menuValue, hitChance)
    return menuValue == 1 and _G.PremiumPrediction.HitChance.High(hitChance)
    or menuValue == 2 and _G.PremiumPrediction.HitChance.VeryHigh(hitChance)
    or _G.PremiumPrediction.HitChance.Immobile(hitChance)
end

local function IsValid(unit)
    if (unit and unit.valid and unit.isTargetable and unit.alive and unit.visible and unit.networkID and unit.pathing and unit.health > 0) then
        return true;
    end
    return false;
end

local function Ready(spell)
    return myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0 and myHero:GetSpellData(spell).mana <= myHero.mana and GameCanUseSpell(spell) == 0
end

function GetMode()   	
    if _G.SDK then
        return 
		_G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] and "Combo"
        or 
		_G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] and "Harass"
        or 
		_G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] and "Clear"
        or 
		_G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_JUNGLECLEAR] and "Clear"
        or 
		_G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] and "LastHit"
        or 
		_G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] and "Flee"
		or nil
    
	elseif _G.PremiumOrbwalker then
		return _G.PremiumOrbwalker:GetMode()
	end
	return nil	
end

function GetTarget(range) 
	if _G.SDK then
		if myHero.ap > myHero.totalDamage then
			return _G.SDK.TargetSelector:GetTarget(range, _G.SDK.DAMAGE_TYPE_MAGICAL);
		else
			return _G.SDK.TargetSelector:GetTarget(range, _G.SDK.DAMAGE_TYPE_PHYSICAL);
		end
	elseif _G.PremiumOrbwalker then
		return _G.PremiumOrbwalker:GetTarget(range)
	end	
end

local function SetAttack(bool)
	if _G.EOWLoaded then
		EOW:SetAttacks(bool)
	elseif _G.SDK then                                                        
		_G.SDK.Orbwalker:SetAttack(bool)
	elseif _G.PremiumOrbwalker then
		_G.PremiumOrbwalker:SetAttack(bool)	
	else
		GOS.BlockAttack = not bool
	end

end

local function SetMovement(bool)
	if _G.EOWLoaded then
		EOW:SetMovements(bool)
	elseif _G.SDK then
		_G.SDK.Orbwalker:SetMovement(bool)
	elseif _G.PremiumOrbwalker then
		_G.PremiumOrbwalker:SetMovement(bool)	
	else
		GOS.BlockMovement = not bool
	end
end

local function GetDistanceSqr(p1, p2)
	if not p1 then return MathHuge end
	p2 = p2 or myHero
	local dx = p1.x - p2.x
	local dz = (p1.z or p1.y) - (p2.z or p2.y)
	return dx*dx + dz*dz
end

local function GetDistance(p1, p2)
	p2 = p2 or myHero
	return MathSqrt(GetDistanceSqr(p1, p2))
end

local function GetDistance2D(p1,p2)
	return MathSqrt((p2.x - p1.x)*(p2.x - p1.x) + (p2.y - p1.y)*(p2.y - p1.y))
end

local function IsRecalling(unit)
	for i = 1, 63 do
	local buff = unit:GetBuff(i) 
		if buff.count > 0 and buff.name == "recall" and Game.Timer() < buff.expireTime then
			return true
		end
	end 
	return false
end 
	
local function MyHeroNotReady()
    return myHero.dead or GameIsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or IsRecalling(myHero)
end

--[[
local currSpell = myHero.activeSpell
if currSpell and currSpell.valid and myHero.isChanneling then
print ("Width:  "..myHero.activeSpell.width)
print ("Speed:  "..myHero.activeSpell.speed)
print ("Delay:  "..myHero.activeSpell.animation)
print ("range:  "..myHero.activeSpell.range)
print ("Name:  "..myHero.activeSpell.name)
end
]]
--[[
for i = 0, myHero.buffCount do
	local buff = myHero:GetBuff(i)
	if buff.name == "" then
	--print(buff.name)
		print("Typ:  "..buff.type)
		print("Name:  "..buff.name)
		print("Start:  "..buff.startTime)
		print("Expire:  "..buff.expireTime)
		print("Dura:  "..buff.duration)
		print("Stacks:  "..buff.stacks)
		print("Count:  "..buff.count)
		print("Id:  "..buff.sourcenID)
		print("SouceName:  "..buff.sourceName)	
	end
end
]]
local IsLoaded = false
Callback.Add("Tick", function()  
	if heroes == false then 
		local EnemyCount = CheckLoadedEnemyies()			
		if EnemyCount < 1 then
			LoadUnits()
		else
			heroes = true
		end
	else	
		if not IsLoaded then
			LoadScript()
			DelayAction(function()
				if not Menu.Pred then return end
				if Menu.Pred.Change:Value() == 1 then
					require('GamsteronPrediction')
				elseif Menu.Pred.Change:Value() == 2 then
					require('PremiumPrediction')
				else
					require('GGPrediction')
				end	
			end, 1)
			IsLoaded = true
		end	
	end	
end)

local DrawTime = false
Callback.Add("Draw", function() 
	if heroes == false then
		Draw.Text(myHero.charName.." is Loading (Search Enemies) !!", 24, myHero.pos2D.x - 50, myHero.pos2D.y + 195, Draw.Color(255, 255, 0, 0))
	else
		if not DrawTime then
			Draw.Text(myHero.charName.." is Ready !!", 24, myHero.pos2D.x - 50, myHero.pos2D.y + 195, Draw.Color(255, 0, 255, 0))
			DelayAction(function()
			DrawTime = true
			end, 4.0)
		end	
	end
end)
local function GetEnemyHeroes()
	local _EnemyHeroes = {}
	for i = 1, GameHeroCount() do
		local unit = GameHero(i)
		if unit.team ~= myHero.team then
			TableInsert(_EnemyHeroes, unit)
		end
	end
	return _EnemyHeroes
end

local function GetAllyHeroes() 
	local _AllyHeroes = {}
	for i = 1, GameHeroCount() do
		local unit = GameHero(i)
		if unit.isAlly and not unit.isMe then
			TableInsert(_AllyHeroes, unit)
		end
	end
	return _AllyHeroes
end

local function GetBuffData(unit, buffname)
  for i = 0, unit.buffCount do
    local buff = unit:GetBuff(i)
    if buff.name == buffname and buff.count > 0 then 
      return buff
    end
  end
  return {type = 0, name = "", startTime = 0, expireTime = 0, duration = 0, stacks = 0, count = 0}
end

local function HasBuff(unit, buffname)
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff.name == buffname and buff.count > 0 then 
			return true
		end
	end
	return false
end

local function GetMinionCount(range, pos)
    local pos = pos.pos
	local count = 1
	for i = 1,GameMinionCount() do
	local hero = GameMinion(i)
	local Range = range * range
		if hero.team ~= TEAM_ALLY and hero.dead == false and GetDistanceSqr(pos, hero.pos) < Range then
		count = count + 1
		end
	end
	return count
end	

local function GetEnemyCount(range, pos)
    local pos = pos.pos
	local count = 0
	for i, hero in ipairs(GetEnemyHeroes()) do
	local Range = range * range
		if GetDistanceSqr(pos, hero.pos) < Range and IsValid(hero) then
		count = count + 1
		end
	end
	return count
end

local function GetAllyCount(range, pos)
    local pos = pos.pos
	local count = 0
	for i, hero in ipairs(GetAllyHeroes()) do
	local Range = range * range
		if GetDistanceSqr(pos, hero.pos) < Range and IsValid(hero) then
		count = count + 1
		end
	end
	return count
end

local function IsUnderTurret(unit)
    for i = 1, GameTurretCount() do
        local turret = GameTurret(i)
        local range = (turret.boundingRadius + 750 + unit.boundingRadius / 2)
        if turret.isEnemy and not turret.dead then
            if turret.pos:DistanceTo(unit.pos) < range then
                return true
            end
        end
    end
    return false
end

local function CastSpellMM(spell,pos,range,delay)
	local range = range or MathHuge
	local delay = delay or 250
	local ticker = GetTickCount()
	if castSpell.state == 0 and GetDistance(myHero.pos,pos) < range and ticker - castSpell.casting > delay + Latency() then
		castSpell.state = 1
		castSpell.mouse = mousePos
		castSpell.tick = ticker
	end
	if castSpell.state == 1 then
		if ticker - castSpell.tick < Latency() then
			local castPosMM = pos:ToMM()
			Control.SetCursorPos(castPosMM.x-5,castPosMM.y-5)
			Control.KeyDown(spell)
			Control.KeyUp(spell)
			castSpell.casting = ticker + delay
			DelayAction(function()
				if castSpell.state == 1 then
					Control.SetCursorPos(castSpell.mouse)
					castSpell.state = 0
				end
			end,Latency()/1000)
		end
		if ticker - castSpell.casting > Latency() then
			Control.SetCursorPos(castSpell.mouse)
			castSpell.state = 0
		end
	end
end

function LoadScript()
	
	Menu = MenuElement({type = MENU, id = "PussyAIO".. myHero.charName, name = myHero.charName})
	Menu:MenuElement({name = " ", drop = {"Version 0.07"}})

	--AutoUlt
	Menu:MenuElement({type = MENU, id = "Ult", name = "Auto Ultimate"})	
	Menu.Ult:MenuElement({id = "UseR", name = "[R] if Allys >= near Immobile Enemy", value = true})
	Menu.Ult:MenuElement({id = "HP", name = "Min HP Kaisa to use [R]", value = 50, min = 0, max = 100, identifier = "%"})	
	
	--ComboMenu  
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "UseQ", name = "[Q]", value = true})		
	Menu.Combo:MenuElement({id = "UseW", name = "[W]", value = true})
	Menu.Combo:MenuElement({id = "Range", name = "Max Range for use [W]", value = 1400, min = 0, max = 3000, identifier = "Range"})	
	Menu.Combo:MenuElement({id = "UseE", name = "[E]", value = true})

	--HarassMenu
	Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})	
	Menu.Harass:MenuElement({id = "UseQ", name = "[Q]", value = true})
	Menu.Harass:MenuElement({id = "Mana", name = "Min Mana to Harass", value = 40, min = 0, max = 100, identifier = "%"})
  
	--LaneClear Menu
	Menu:MenuElement({type = MENU, id = "Clear", name = "LaneClear"})	
	Menu.Clear:MenuElement({id = "UseQ", name = "[Q]", value = true})		
	Menu.Clear:MenuElement({id = "Count", name = "Min Minions", value = 3, min = 1, max = 7, step = 1, identifier = "Minion/s"})
	Menu.Clear:MenuElement({id = "UseW", name = "LastHit[W]Cannon [if out of AA range]", value = true})  	
	Menu.Clear:MenuElement({id = "Mana", name = "Min Mana to Clear", value = 40, min = 0, max = 100, identifier = "%"})
  
	--JungleClear
	Menu:MenuElement({type = MENU, id = "JClear", name = "JungleClear"})
	Menu.JClear:MenuElement({id = "UseQ", name = "[Q]", value = true})
	Menu.JClear:MenuElement({id = "UseW", name = "[W]", value = true})	
	Menu.JClear:MenuElement({id = "Mana", name = "Min Mana to JungleClear", value = 40, min = 0, max = 100, identifier = "%"})  
 
	--LastHit
	Menu:MenuElement({type = MENU, id = "last", name = "Lasthit"})
	Menu.last:MenuElement({id = "UseQ", name = "[Q]", value = true})
	Menu.last:MenuElement({id = "UseW", name = "LastHit[W]Cannon [if out of range]", value = true})	
	Menu.last:MenuElement({id = "Mana", name = "Min Mana to LastHit", value = 40, min = 0, max = 100, identifier = "%"}) 
 
	--KillSteal
	Menu:MenuElement({type = MENU, id = "ks", name = "KillSteal"})
	Menu.ks:MenuElement({id = "UseQ", name = "[Q]", value = true})
	Menu.ks:MenuElement({id = "UseW", name = "[W]", value = true})
	Menu.ks:MenuElement({id = "Range", name = "Max Range for use [W]", value = 3000, min = 0, max = 3000, identifier = "Range"})	
	Menu.ks:MenuElement({id = "UseR", name = "[R] if out of range only 1vs1", value = true})	
	Menu.ks:MenuElement({id = "Rrange", name = "[R] Check Range for no Enemies around Target", value = 1500, min = 0, max = 3000, identifier = "Range"})
	
	--Prediction
	Menu:MenuElement({type = MENU, id = "Pred", name = "Prediction"})
	Menu.Pred:MenuElement({name = " ", drop = {"After change Pred.Typ reload 2x F6"}})
	Menu.Pred:MenuElement({id = "Change", name = "Change Prediction Typ", value = 3, drop = {"Gamsteron Prediction", "Premium Prediction", "GGPrediction"}})	
	Menu.Pred:MenuElement({id = "PredW", name = "Hitchance[W]", value = 1, drop = {"Normal", "High", "Immobile"}})		

	--Drawing 
	Menu:MenuElement({type = MENU, id = "Drawing", name = "Drawings"})
	Menu.Drawing:MenuElement({id = "DrawQ", name = "Draw [Q] Range", value = false})
	Menu.Drawing:MenuElement({id = "DrawW", name = "Draw [W] Range", value = false})
	Menu.Drawing:MenuElement({id = "DrawR", name = "Draw [R] Range", value = false})

	WData =
	{
	Type = _G.SPELLTYPE_LINE, Delay = 0.4, Radius = 100, Range = 3000, Speed = 1750, Collision = true, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION} 
	}
  	  
	WspellData = {speed = 1750, range = 3000, delay = 0.4, radius = 100, collision = {"minion"}, type = "linear"}
	  
	Callback.Add("Tick", function() Tick() end)
	
	Callback.Add("Draw", function()
		
		if Menu.Drawing.DrawR:Value() and Ready(_R) then
		DrawCircle(myHero, 1000 + 500 * myHero:GetSpellData(_R).level, 1, DrawColor(255, 225, 255, 10))
		end                                                 
		if Menu.Drawing.DrawQ:Value() and Ready(_Q) then
		DrawCircle(myHero, 600, 1, DrawColor(225, 225, 0, 10))
		end
		if Menu.Drawing.DrawW:Value() and Ready(_W) then
		DrawCircle(myHero, 3000, 1, DrawColor(225, 225, 125, 10))
		end
	end)	
end

function Tick()
if MyHeroNotReady() then return end
local Mode = GetMode()
	if Mode == "Combo" then
		Combo()		
	elseif Mode == "Harass" then
		Harass()	
	elseif Mode == "Clear" then
		Clear()
		JungleClear()
	elseif Mode == "LastHit" then
		Lasthit()
	end	
	KillSteal()
	AutoR()
end

local function CheckQ()
	if HasBuff(myHero, "KaisaQEvolved") then 
		return 9 		
	else 
		return 5 
	end 
end

local function GetWDmg(unit)
	local Wdmg = getdmg("W", unit, myHero, 1)
	local W2dmg = getdmg("W", unit, myHero, 2)	
	local buff = GetBuffData(unit, "kaisapassivemarker")
	if buff and buff.count == 4 then
		return (Wdmg+W2dmg)		
	else		
		return Wdmg 
	end 
end

local function GetQDmg(unit)
	local count = GetEnemyCount(600, unit)
	local QDmg = getdmg("Q", unit, myHero)
	local QDmg2 = (CheckQ() * (getdmg("Q", unit, myHero)/100*25))
	if count >= 2 then 
		return QDmg+(QDmg2/count)
	else
		return QDmg+QDmg2
	end
end	

function AutoR()
	for i, target in ipairs(GetEnemyHeroes()) do
		if myHero.pos:DistanceTo(target.pos) > 500 and myHero.pos:DistanceTo(target.pos) < 1000 + 500 * myHero:GetSpellData(_R).level and IsValid(target) and Ready(_R) and Menu.Ult.UseR:Value() then
			if not IsUnderTurret(target) and HasBuff(target, "kaisapassivemarkerr") then
				for k, ally in ipairs(GetAllyHeroes()) do
				local CountEnemy = GetEnemyCount(1000, ally)
				local CountAlly = GetAllyCount(1000, target)	
					if CountEnemy <= CountAlly + 1 and myHero.health/myHero.maxHealth >= Menu.Ult.HP:Value() / 100 then
					local castPos = target.pos:Extended(myHero.pos, 300)
						if target.pos:To2D().onScreen then
							Control.CastSpell(HK_R, castPos)
						else 
							CastSpellMM(HK_R, target.pos, 1000 + 500 * myHero:GetSpellData(_R).level)
						end	
					end
				end	
			end
		end
	end
end	
         
function KillSteal()	
	for i, target in ipairs(GetEnemyHeroes()) do	
		if Ready(_R) and Menu.ks.UseR:Value() then		
			
			if myHero.pos:DistanceTo(target.pos) > 500 and myHero.pos:DistanceTo(target.pos) < 1000 + 500 * myHero:GetSpellData(_R).level and HasBuff(target, "kaisapassivemarkerr") and Menu.ks.UseQ:Value() and Ready(_Q) and IsValid(target) then
				local QDmg = GetQDmg(target)
				local WDmg = GetWDmg(target)
				if QDmg+WDmg >= target.health then
				local castPos = target.pos:Extended(myHero.pos, 300)
					if GetEnemyCount(Menu.ks.Rrange:Value(), target) == 1 and not IsUnderTurret(target) then
						if target.pos:To2D().onScreen then
							Control.CastSpell(HK_R, castPos)

						else 
							CastSpellMM(HK_R, target.pos, 1000 + 500 * myHero:GetSpellData(_R).level)
						end
					end	
				end
			end			
		end		

		if myHero.pos:DistanceTo(target.pos) < 600 and IsValid(target) and Menu.ks.UseQ:Value() and Ready(_Q) then
			local QDmg = GetQDmg(target) 
			if QDmg >= target.health then
				Control.CastSpell(HK_Q)	
			end
		end
		
		if myHero.pos:DistanceTo(target.pos) < Menu.ks.Range:Value() and IsValid(target) and Menu.ks.UseW:Value() and Ready(_W) then
			local WDmg = GetWDmg(target)
			if WDmg >= target.health then					
				if Menu.Pred.Change:Value() == 1 then
					local pred = GetGamsteronPrediction(target, WData, myHero)
					if pred.Hitchance >= Menu.Pred.PredW:Value()+1 then
						Control.CastSpell(HK_W, pred.CastPosition)
					end
				elseif Menu.Pred.Change:Value() == 2 then
					local pred = _G.PremiumPrediction:GetPrediction(myHero, target, WspellData)
					if pred.CastPos and ConvertToHitChance(Menu.Pred.PredW:Value(), pred.HitChance) then
						Control.CastSpell(HK_W, pred.CastPos)
					end
				else
					local WPrediction = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.4, Radius = 100, Range = 3000, Speed = 1750, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}})
					WPrediction:GetPrediction(target, myHero)
					if WPrediction:CanHit(Menu.Pred.PredW:Value() + 1) then
						Control.CastSpell(HK_W, WPrediction.CastPosition)
					end					
				end
			end
		end					
	end	
end	

function Combo()
local target = GetTarget(3000)
if target == nil then return end
	if IsValid(target) then
			
		if myHero.pos:DistanceTo(target.pos) > 525 and myHero.pos:DistanceTo(target.pos) < 1500 and Menu.Combo.UseE:Value() and Ready(_E) then			
			Control.CastSpell(HK_E)
		end			

		if myHero.pos:DistanceTo(target.pos) < 600 and Menu.Combo.UseQ:Value() and Ready(_Q) then			
			Control.CastSpell(HK_Q)
		end
		
		if myHero.pos:DistanceTo(target.pos) <= Menu.Combo.Range:Value() and Menu.Combo.UseW:Value() and Ready(_W) then
			if Menu.Pred.Change:Value() == 1 then
				local pred = GetGamsteronPrediction(target, WData, myHero)
				if pred.Hitchance >= Menu.Pred.PredW:Value()+1 then
					Control.CastSpell(HK_W, pred.CastPosition)
				end
			elseif Menu.Pred.Change:Value() == 2 then
				local pred = _G.PremiumPrediction:GetPrediction(myHero, target, WspellData)
				if pred.CastPos and ConvertToHitChance(Menu.Pred.PredW:Value(), pred.HitChance) then
					Control.CastSpell(HK_W, pred.CastPos)
				end
			else
				local WPrediction = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.4, Radius = 100, Range = 3000, Speed = 1750, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}})
				WPrediction:GetPrediction(target, myHero)
				if WPrediction:CanHit(Menu.Pred.PredW:Value() + 1) then
					Control.CastSpell(HK_W, WPrediction.CastPosition)
				end					
			end	
		end				
	end
end	

function Harass()
local target = GetTarget(600)
if target == nil then return end
	if IsValid(target) and myHero.mana/myHero.maxMana >= Menu.Harass.Mana:Value() / 100 then
		
		if myHero.pos:DistanceTo(target.pos) <= 600 and Menu.Harass.UseQ:Value() and Ready(_Q) then			
			Control.CastSpell(HK_Q)
		end
	end
end	

function Clear()
	for i = 1, GameMinionCount() do
    local minion = GameMinion(i)
	
		if myHero.pos:DistanceTo(minion.pos) <= 600 and minion.team == TEAM_ENEMY and IsValid(minion) and myHero.mana/myHero.maxMana >= Menu.Clear.Mana:Value() / 100 then					
			if Ready(_Q) and Menu.Clear.UseQ:Value() and GetMinionCount(400, minion) >= Menu.Clear.Count:Value() then
				Control.CastSpell(HK_Q)
			end	 
		end
		
		if myHero.pos:DistanceTo(minion.pos) > 550 and myHero.pos:DistanceTo(minion.pos) <= 3000 and minion.team == TEAM_ENEMY and minion.charName == "SRU_ChaosMinionSiege" and IsValid(minion) and Ready(_W) and Menu.Clear.UseW:Value() then
			local WDmg = getdmg("W", minion, myHero)
			if WDmg >= minion.health and minion.pos:To2D().onScreen then
				Control.CastSpell(HK_W, minion.pos)
			end
		end		
	end
end

function JungleClear()
	for i = 1, GameMinionCount() do
    local minion = GameMinion(i)	

		if myHero.mana/myHero.maxMana >= Menu.JClear.Mana:Value() / 100 then
			
			if myHero.pos:DistanceTo(minion.pos) <= 600 and minion.team == TEAM_JUNGLE and IsValid(minion) and Ready(_Q) and Menu.JClear.UseQ:Value() then	
				Control.CastSpell(HK_Q)  
			end
			
			if myHero.pos:DistanceTo(minion.pos) <= 3000 and minion.team == TEAM_JUNGLE and IsValid(minion) and Ready(_W) and Menu.JClear.UseW:Value() and minion.pos:To2D().onScreen then
				Control.CastSpell(HK_W, minion.pos)
			end		
		end
	end	
end

function Lasthit()
	for i = 1, GameMinionCount() do
    local minion = GameMinion(i)
	
	 if myHero.mana/myHero.maxMana >= Menu.last.Mana:Value() / 100 then
			
			if myHero.pos:DistanceTo(minion.pos) <= 600 and minion.team == TEAM_ENEMY and IsValid(minion) then					
				local QDmg = (getdmg("Q", minion, myHero)*2)
				if Ready(_Q) and Menu.last.UseQ:Value() and minion.health/minion.maxHealth < 0.35 and QDmg > minion.health then
					Control.CastSpell(HK_Q)
				end	 
			end
			
			if myHero.pos:DistanceTo(minion.pos) > 550 and myHero.pos:DistanceTo(minion.pos) <= 3000 and minion.team == TEAM_ENEMY and minion.charName == "SRU_ChaosMinionSiege" and IsValid(minion) and Ready(_W) and Menu.last.UseW:Value() then
				local WDmg = getdmg("W", minion, myHero)
				if WDmg > minion.health and minion.pos:To2D().onScreen then
					Control.CastSpell(HK_W, minion.pos)
				end
			end
		end
	end
end
