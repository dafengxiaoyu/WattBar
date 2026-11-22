#include "SMCReader.h"
#include <math.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>
#include <sys/sysctl.h>

#define FOURCC(a, b, c, d) ((uint32_t)(a) << 24 | (uint32_t)(b) << 16 | (uint32_t)(c) << 8 | (uint32_t)(d))

// The private AppleSMC user client expects this 80-byte request on the verified Mac.
typedef struct {
    uint32_t key;
    uint8_t versionAndLimits[24];
    uint32_t dataSize;
    uint32_t dataType;
    uint8_t attributes;
    uint8_t reserved[3];
    uint8_t result;
    uint8_t status;
    uint8_t operation;
    uint8_t padding;
    uint32_t index;
    uint8_t bytes[32];
} SMCRequest;

_Static_assert(sizeof(SMCRequest) == 80, "Unexpected AppleSMC request size");
_Static_assert(offsetof(SMCRequest, bytes) == 48, "Unexpected AppleSMC data offset");

enum {
    SMCSelector = 2,
    SMCReadBytes = 5,
    SMCGetKeyInfo = 9
};

static bool callSMC(io_connect_t connection, const SMCRequest *input, SMCRequest *output) {
    size_t size = sizeof(*output);
    return IOConnectCallStructMethod(connection, SMCSelector, input, sizeof(*input), output, &size) == KERN_SUCCESS
        && size == sizeof(*output) && output->result == 0;
}

static bool readKey(io_connect_t connection, uint32_t key, uint32_t type, uint32_t size, void *bytes) {
    SMCRequest input = {.key = key, .operation = SMCGetKeyInfo};
    SMCRequest info = {0};
    if (!callSMC(connection, &input, &info) || info.dataType != type || info.dataSize != size) {
        return false;
    }

    input.dataSize = size;
    input.operation = SMCReadBytes;
    SMCRequest output = {0};
    if (!callSMC(connection, &input, &output)) {
        return false;
    }
    memcpy(bytes, output.bytes, size);
    return true;
}

bool WattBarSMCSupportsCurrentMac(void) {
    char model[64] = {0};
    size_t length = sizeof(model);
    return sysctlbyname("hw.model", model, &length, NULL, 0) == 0
        && strcmp(model, "MacBookPro18,1") == 0;
}

io_connect_t WattBarSMCOpen(void) {
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    if (service == IO_OBJECT_NULL) {
        return IO_OBJECT_NULL;
    }

    io_connect_t connection = IO_OBJECT_NULL;
    kern_return_t result = IOServiceOpen(service, mach_task_self(), 0, &connection);
    IOObjectRelease(service);
    return result == KERN_SUCCESS ? connection : IO_OBJECT_NULL;
}

WattBarSMCSnapshot WattBarSMCRead(io_connect_t connection) {
    WattBarSMCSnapshot snapshot = {0};
    uint16_t millivolts;
    int16_t milliamps;
    if (readKey(connection, FOURCC('B','0','A','V'), FOURCC('u','i','1','6'), sizeof(millivolts), &millivolts)
        && readKey(connection, FOURCC('B','0','A','C'), FOURCC('s','i','1','6'), sizeof(milliamps), &milliamps)
        && millivolts >= 1000 && millivolts <= 30000 && milliamps >= -30000 && milliamps <= 30000) {
        snapshot.hasBattery = true;
        snapshot.millivolts = millivolts;
        snapshot.milliamps = milliamps;
    }

    float inputWatts;
    if (readKey(connection, FOURCC('P','D','T','R'), FOURCC('f','l','t',' '), sizeof(inputWatts), &inputWatts)
        && isfinite(inputWatts) && inputWatts >= 0 && inputWatts <= 240) {
        snapshot.hasInput = true;
        snapshot.inputWatts = inputWatts;
    }
    return snapshot;
}
