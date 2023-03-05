--// Module Stuff
local HitboxManager = {}
HitboxManager.CurrentHitboxes = {}

--// Services
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Modules
local ReplicatedModules = ReplicatedStorage:WaitForChild("Modules")
local UtilityModule = require(ReplicatedModules:WaitForChild("UtilityModule"))

--// Instances
local MouseIgnore = workspace:WaitForChild("MouseIgnore")

--// Events
local RemoteFunctions = ReplicatedStorage:WaitForChild("RemoteFunctions")
local GetMouse = RemoteFunctions:WaitForChild("GetMouse")

--// Values
local Rate = 0.1
local LastTick = 0

--// Functions 
function GetTouchingParts(MainPart: Part,SourceCharacter : Model)
	local OverlapParms =  OverlapParams.new()
	OverlapParms.FilterType = Enum.RaycastFilterType.Blacklist
	OverlapParms.FilterDescendantsInstances = {SourceCharacter, MouseIgnore}
	OverlapParms.MaxParts = 1000
	
	if MainPart.Shape == Enum.PartType.Ball then
		return workspace:GetPartBoundsInRadius(MainPart.Position, MainPart.Size.Y/2, OverlapParms)
	else
		return workspace:GetPartsInPart(MainPart, OverlapParms)
	end
end

export type HitboxType = {
	OriginPlayer: Player,
	OriginVector3: Vector3,
	
	Part: Instance,
	Duration: number, 
	
	Destroyed: BindableEvent;
	CharacterDetected: BindableEvent;
	PartDetected: BindableEvent;
	FollowMouseIntensity: number;
}

--// MetaMethods
local Hitbox = {}
Hitbox.__index = Hitbox

function Hitbox:Spawn(): any?
	assert(self.OriginVector3~=nil,"Hitbox's OriginVector3 is nil")
	assert(self.Duration~=nil,"Hitbox's Duration is nil")
	
	Debris:AddItem(self.Part,self.Duration)
	

	self.Part.Position = self.OriginVector3
	self.Part.Parent = MouseIgnore

	table.insert(HitboxManager.CurrentHitboxes,self)
	
	self.Part.Destroying:Connect(function()
		self.Destroyed:Fire(true)
		self = nil 
		table.remove(HitboxManager.CurrentHitboxes,self)
	end)
end

--// Hitbox Creation
function HitboxManager:New(): any?
	local HitboxMetaTable: HitboxType = setmetatable({},Hitbox)
	HitboxMetaTable.Destroyed = Instance.new("BindableEvent")
	HitboxMetaTable.CharacterDetected = Instance.new("BindableEvent")
	HitboxMetaTable.PartDetected = Instance.new("BindableEvent")
	
	return HitboxMetaTable
end

--// Hitbox Signal Management
RunService.Heartbeat:Connect(function()
	if tick()-LastTick < Rate then return end
	LastTick = tick()
	if HitboxManager.CurrentHitboxes ~= nil then
		for i,HitboxTable: HitboxType in pairs(HitboxManager.CurrentHitboxes) do
			local SourcePlayer = HitboxTable.OriginPlayer
			local TouchingParts = GetTouchingParts(HitboxTable.Part, HitboxTable.OriginPlayer.Character)
			local DetectedCharacters = {}
			local DetectedParts = {}
			
			if HitboxTable.FollowMouseIntensity ~= nil then 
				local Attachment = HitboxTable.Part:FindFirstChild("FollowMouse")
				local MousePosition = GetMouse:InvokeClient(SourcePlayer)
				local RealPosition = Vector3.new(MousePosition.X,MousePosition.Y+HitboxTable.Part.Size.Y/2,MousePosition.Z)
				
				if HitboxTable.Part:FindFirstChild("FollowMouse") == nil then 
					Attachment = UtilityModule:CreateAttachment("FollowMouse",HitboxTable.Part) 
					local AlignPosition = UtilityModule:CreateAlignPosition(Attachment,RealPosition,HitboxTable.FollowMouseIntensity)
					local AlignOrientation = UtilityModule:CreateAlignOrientation(Attachment,nil,nil,true)
				end
				
				local AlignPosition = Attachment:WaitForChild("AlignPosition")
				AlignPosition.Position = RealPosition
			end
			
			for _, Part in pairs(TouchingParts) do
				if Part.Parent.Name == SourcePlayer.Name then continue end 
				if DetectedCharacters[Part.Parent.Name] ~= nil then continue end
				if Part.Parent:IsA("Model") and Part.Parent:FindFirstChild("Humanoid") then
					local Target = Part.Parent
					DetectedCharacters[Target.Name] = true
					HitboxTable.CharacterDetected:Fire(Target)
				else 
					if DetectedParts[Part.Parent.Name] ~= nil then continue end
					DetectedParts[Part.Name] = true
					HitboxTable.PartDetected:Fire(Part)
				end
			end
		end
	end
end)

return HitboxManager
