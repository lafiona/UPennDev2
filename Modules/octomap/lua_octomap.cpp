/*
 Lua Octomap Wrapper
(c) 2013 Stephen McGill
    2014 Qin He
*/

#include <lua.hpp>
#include "torch/luaT.h"
#include "torch/TH/TH.h"

#include <stdio.h>
#include <vector>
#include <string>

#include <octomap/octomap.h>
#include <octomap/math/Utils.h>

#include <sstream>

using namespace std;
using namespace octomap;

// TODO: Make a metatable with a pointer to each tree\

#define DEFAULT_RESOLUTION 0.01
#define DEFAULT_MIN_RANGE 0.05
#define DEFAULT_MAX_RANGE 10


double min_range = DEFAULT_MIN_RANGE; //TODO: do we use it?
double max_range = DEFAULT_MAX_RANGE;

/* Initialize the tree (1cm) */
static OcTree tree (DEFAULT_RESOLUTION);
/* Gloabl Origin */
static point3d origin (0.0f,0.0f,0.3f);


static int lua_set_resolution(lua_State *L) {
  double res = luaL_checknumber(L, 1);
  tree.setResolution(res);
  return 0;
}

static int lua_set_range(lua_State *L) {
  min_range = luaL_checknumber(L, 1);
  max_range = luaL_checknumber(L, 2);
  return 0;
}

static int lua_set_origin( lua_State *L ) {
	static float ox,oy,oz;
	const THDoubleTensor * origin_t =
		(THDoubleTensor *) luaT_checkudata(L, 1, "torch.DoubleTensor");
	ox = (float)THTensor_fastGet1d( origin_t, 0);
	oy = (float)THTensor_fastGet1d( origin_t, 1);
	oz = (float)THTensor_fastGet1d( origin_t, 2);
	origin = point3d(ox,oy,oz);
	return 0;
}

static int lua_add_scan( lua_State *L ) {
	/* Grab the points from the last laser scan*/
	const THFloatTensor * points_t =
		(THFloatTensor *) luaT_checkudata(L, 1, "torch.FloatTensor");
	// Check contiguous
	THArgCheck(points_t->stride[1] == 1, 1, "Point cloud not contiguous (j)");  
	const long nps = points_t->size[0];
	const long points_istride = points_t->stride[0];
	THArgCheck(points_istride == points_t->size[1], 1, "Improper point cloud layout (i)"); 
  
	/* Check to optionally use raycasting from the origin */
  // int use_raycast = luaL_optint(L, 2, 0);
	
  float *points_ptr = (float *)(points_t->storage->data + points_t->storageOffset);  
	float x,y,z;
	Pointcloud cloud;
	for (long p=0; p<nps; p++) {
    x = *(points_ptr);
    y = *(points_ptr+1);
    z = *(points_ptr+2);
    points_ptr += points_istride;
    
    // update tree ray by ray
    // tree.insertRay(origin, point3d(x,y,z), max_range, true);
    
		/* Add point to the cloud */
    cloud.push_back(x,y,z);
	}  
  // tree.updateInnerOccupancy();
  
	// Update tree chunk by chunk
  tree.insertPointCloud(cloud, origin, max_range, true);
	
	/*
	lua_pushnumber(L, tree.memoryUsage());
	return 1;
	*/
	return 0;
}

static int lua_get_pruned_data( lua_State *L ) {
	stringstream ss;
	if ( !tree.writeBinary( ss ) )
		return luaL_error(L,"Bad writing of the octomap!");
	string tree_str = ss.str();
	lua_pushlstring(L, tree_str.c_str(), tree_str.length() );
	return 1;
}

static int lua_get_data( lua_State *L ) {
	stringstream ss;
	if ( !tree.writeBinaryConst( ss ) )
		return luaL_error(L,"Bad writing of the octomap!");
	string tree_str = ss.str();
	lua_pushlstring(L, tree_str.c_str(), tree_str.length() );
	return 1;
}

static int lua_save_tree( lua_State *L ) {
	const char* filename = luaL_checkstring(L,1);
	tree.writeBinary(filename);
	return 0;
}

// TODO: query nodes, connected components for plane fitting

static const struct luaL_Reg octomap_lib [] = {
  {"set_resolution", lua_set_resolution},
	{"set_origin", lua_set_origin},
  {"set_range", lua_set_range},
	{"add_scan", lua_add_scan},
	{"get_data", lua_get_data},
	{"get_pruned_data", lua_get_pruned_data},
	{"save_tree", lua_save_tree},
	{NULL, NULL}
};

extern "C" int luaopen_octomap(lua_State *L) {
#if LUA_VERSION_NUM == 502
	luaL_newlib(L, octomap_lib);
#else
	luaL_register(L, "octomap", octomap_lib);
#endif
	return 1;
}
