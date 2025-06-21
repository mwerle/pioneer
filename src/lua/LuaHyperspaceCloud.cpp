// Copyright © 2008-2025 Pioneer Developers. See AUTHORS.txt for details
// Licensed under the terms of the GPL v3. See licenses/GPL-3.txt

#include "EnumStrings.h"
#include "Game.h"
#include "HyperspaceCloud.h"
#include "LuaConstants.h"
#include "LuaObject.h"
#include "LuaUtils.h"
#include "Pi.h"
#include "SectorView.h"
#include "Ship.h"
#include "galaxy/Galaxy.h"
/*
 * Class: HyperspaceCloud
 *
 * Class representing a hyperspace cloud. Inherits from <Body>
 */

/* Method: IsArrival
 *
 * Return true if this is an arrival cloud.
 *
 * Returns:
 *
 *    true if this is an arrival cloud.
 *
 */
static int l_hyperspace_cloud_is_arrival(lua_State *l)
{
	HyperspaceCloud *cloud = LuaObject<HyperspaceCloud>::CheckFromLua(1);
	LuaPush(l, cloud->IsArrival());
	return 1;
}

/* Method: GetShip
 *
 * Return the <Ship> that created this cloud, or nil.
 *
 * Returns:
 *
 *    the <Ship> that created this cloud, or nil.
 *
 */
static int l_hyperspace_cloud_get_ship(lua_State *l)
{
	HyperspaceCloud *cloud = LuaObject<HyperspaceCloud>::CheckFromLua(1);
	Ship *ship = cloud->GetShip();
	if (ship == nullptr)
		lua_pushnil(l);
	else
		LuaPush(l, ship);
	return 1;
}

/* Method: GetDueDate
 *
 * Return the date when a ship has entered / will exit this cloud.
 *
 * Returns:
 *
 *    the date when a ship has entered / will exit this cloud
 *
 */
static int l_hyperspace_cloud_get_due_date(lua_State *l)
{
	HyperspaceCloud *cloud = LuaObject<HyperspaceCloud>::CheckFromLua(1);
	LuaPush(l, cloud->GetDueDate());
	return 1;
}

/* Method: SetHyperspaceOrigin
 *
 * Set the source system for the hyperspace cloud.
 *
 * Returns:
 *
 */
static int l_hyperspace_cloud_set_origin(lua_State *l)
{
	HyperspaceCloud *cloud = LuaObject<HyperspaceCloud>::CheckFromLua(1);
	SystemPath *path = LuaObject<SystemPath>::CheckFromLua(2);
	cloud->SetHyperspaceSource(path);
	return 0;
}

/* Method: GetHyperspaceOrigin
 *
 * Return the system in which the ship entered hyperspace.
 *
 * Returns:
 *
 *    path - the <SystemPath> of the origin system
 *    name - a string of the name of the origin system
 *
 */
static int l_hyperspace_cloud_get_origin(lua_State *l)
{
	HyperspaceCloud *cloud = LuaObject<HyperspaceCloud>::CheckFromLua(1);
	const SystemPath &path = cloud->GetHyperspaceSource();
	RefCountedPtr<const Sector> s = Pi::game->GetGalaxy()->GetSector(path);
	LuaObject<SystemPath>::PushToLua(path);
	LuaPush(l, s->m_systems[path.systemIndex].GetName());
	return 2;
}

/* Method: GetHyperspaceDestination
 *
 * Return the system in which the ship has exited / will exit hyperspace.
 *
 * Returns:
 *
 *    path - the <SystemPath> of the destination system
 *    name - a string of the name of the destination system
 *
 */
static int l_hyperspace_cloud_get_destination(lua_State *l)
{
	HyperspaceCloud *cloud = LuaObject<HyperspaceCloud>::CheckFromLua(1);
	const SystemPath &path = cloud->GetHyperspaceDest();
	RefCountedPtr<const Sector> s = Pi::game->GetGalaxy()->GetSector(path);
	LuaObject<SystemPath>::PushToLua(path);
	LuaPush(l, s->m_systems[path.systemIndex].GetName());
	return 2;
}

template <>
const char *LuaObject<HyperspaceCloud>::s_type = "HyperspaceCloud";

template <>
void LuaObject<HyperspaceCloud>::RegisterClass()
{
	static const char *l_parent = "Body";

	static const luaL_Reg l_methods[] = {
		{ "IsArrival", l_hyperspace_cloud_is_arrival },
		{ "GetShip", l_hyperspace_cloud_get_ship },
		{ "GetDueDate", l_hyperspace_cloud_get_due_date },

		{ "SetHyperspaceOrigin", l_hyperspace_cloud_set_origin },
		{ "GetHyperspaceOrigin", l_hyperspace_cloud_get_origin },
		{ "GetHyperspaceDestination", l_hyperspace_cloud_get_destination },

		{ 0, 0 }
	};

	LuaObjectBase::CreateClass(s_type, l_parent, l_methods, 0, 0);
	LuaObjectBase::RegisterPromotion(l_parent, s_type, LuaObject<HyperspaceCloud>::DynamicCastPromotionTest);
}
