#ifndef __SPNAV_H__
#define __SPNAV_H__

#include "hidapi.h"
#include "stdio.h"
#include "stdlib.h"

enum {
  SPNAV_EVENT_EMPTY,
  SPNAV_EVENT_MOTION,
  SPNAV_EVENT_BUTTOM
};

typedef struct{
  hid_device * handle;
	unsigned char *buf;
} structSpnav;

int spnav_parse(structSpnav *ud, int len);

#endif
