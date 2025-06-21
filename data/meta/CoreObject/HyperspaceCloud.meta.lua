-- Copyright © 2008-2025 Pioneer Developers. See AUTHORS.txt for details
-- Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

-- This file implements type information about C++ classes for Lua static analysis

---@meta

---
---@class HyperspaceCloud : Body
---
---@class HyperspaceCloud : Body
local HyperspaceCloud = {}

-- Ensure the CoreImport field is visible to static analysis
package.core["HyperspaceCloud"] = HyperspaceCloud

---@return boolean
function HyperspaceCloud:IsArrival() end

---@return Ship
function HyperspaceCloud:GetShip() end

-- Returns the arrival date in the destination system
---@return type number
function HyperspaceCloud:GetDueDate() end

-- Return the current hyperspace origin.
---@return SystemPath path the destination system and body
---@return string name the name of the destination
function HyperspaceCloud:GetHyperspaceOrigin() end

-- Return the current hyperspace destination.
---@return SystemPath path the destination system and body
---@return string name the name of the destination
function HyperspaceCloud:GetHyperspaceDestination() end

-- TODO: document further methods as they are used
