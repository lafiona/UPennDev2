#ifdef __cplusplus
extern "C"
{
#endif
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#ifdef __cplusplus
}
#endif

#include <OccMap.h>

//OccMap map;

static int lua_occmap_reset(lua_State *L) {
//  map.randomize_map();
	return 1;
}

static int lua_occmap_odometry_update(lua_State *L) {
//  double odomX = luaL_checknumber(L, 1);
//  double odomY = luaL_checknumber(L, 2);
//  double odomA = luaL_checknumber(L, 3);
//  map.odometry_update(odomX, odomY, odomA);
	return 1;
}

static int lua_occmap_vision_update(lua_State *L) {
//  double *free_bound = (double *) lua_touserdata(L, 1);
//  if ((free_bound == NULL) || !lua_islightuserdata(L, 1)) {
//    return luaL_error(L, "Input freespace bound not light user data");
//  }
//  int width = luaL_checkint(L, 2);
//  map.vision_update(free_bound, width);
	return 1;
}

static int lua_occmap_get_map(lua_State *L) {
//	lua_createtable(L, 0, 2);
//
//  vector<double> cur_map = map.get_map();
//	lua_pushstring(L, "map");
//	lua_createtable(L, cur_map.size(), 0);
//	lua_pushlightuserdata(L, &cur_map[0]);
//	lua_settable(L, -3);

//	lua_pushstring(L, "robot_pos");
//	lua_createtable(L, 2, 0);
//	lua_pushinteger(L, map.get_robot_pos_x());
//	lua_rawseti(L, -2, 1);
//	lua_pushinteger(L, map.get_robot_pos_y());
//	lua_rawseti(L, -2, 2);
//	lua_settable(L, -3);

	return 1;
}

static const struct luaL_reg OccMap_lib [] = {
	{"reset", lua_occmap_reset},
	{"get", lua_occmap_get_map},
	{"vision_update", lua_occmap_vision_update},
	{"odometry_update", lua_occmap_odometry_update},
  {NULL, NULL}
};

#ifdef __cplusplus
extern "C"
#endif
int luaopen_OccMap (lua_State *L) {
  luaL_register(L, "OccMap", OccMap_lib);
  return 1;
}
