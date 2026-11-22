#ifndef WATTBAR_SMC_READER_H
#define WATTBAR_SMC_READER_H

#include <IOKit/IOKitLib.h>
#include <stdbool.h>

typedef struct {
    bool hasBattery;
    int millivolts;
    int milliamps;
    bool hasInput;
    double inputWatts;
} WattBarSMCSnapshot;

bool WattBarSMCSupportsCurrentMac(void);
io_connect_t WattBarSMCOpen(void);
WattBarSMCSnapshot WattBarSMCRead(io_connect_t connection);

#endif
