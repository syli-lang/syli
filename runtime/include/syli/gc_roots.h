#ifndef SYLI_GC_ROOTS_H
#define SYLI_GC_ROOTS_H

#include <stddef.h>
#include <stdint.h>

/*

From the official llvm website.
https://llvm.org/docs/StackMaps.html#stackmap-section

Header {
  uint8  : Stack Map Version (current version is 3)
  uint8  : Reserved (expected to be 0)
  uint16 : Reserved (expected to be 0)
}
uint32 : NumFunctions
uint32 : NumConstants
uint32 : NumRecords
StkSizeRecord[NumFunctions] {
  uint64 : Function Address
  uint64 : Stack Size (or UINT64_MAX if not statically known)
  uint64 : Record Count
}
Constants[NumConstants] {
  uint64 : LargeConstant
}
StkMapRecord[NumRecords] {
  uint64 : PatchPoint ID
  uint32 : Instruction Offset
  uint16 : Reserved (record flags)
  uint16 : NumLocations
  Location[NumLocations] {
    uint8  : Register | Direct | Indirect | Constant | ConstantIndex
    uint8  : Reserved (expected to be 0)
    uint16 : Location Size
    uint16 : Dwarf RegNum
    uint16 : Reserved (expected to be 0)
    int32  : Offset or SmallConstant
  }
  uint32 : Padding (only if required to align to 8 byte)
  uint16 : Padding
  uint16 : NumLiveOuts
  LiveOuts[NumLiveOuts]
    uint16 : Dwarf RegNum
    uint8  : Reserved
    uint8  : Size in Bytes
  }
  uint32 : Padding (only if required to align to 8 byte)
}

*/

typedef struct __attribute__((packed)) {
    uint8_t version;
    uint8_t pad1;
    uint16_t pad2;
    uint32_t num_functions;
    uint32_t num_constants;
    uint32_t num_records;
} SyliStackMap_Header;

typedef struct __attribute__((packed)) {
    uint64_t addr;
    uint64_t stack_size;
    uint64_t num_records;
} SyliStackMap_Function;

typedef struct __attribute__((packed)) {
    uint8_t kind;
    uint8_t pad1;
    uint16_t size;
    uint16_t dwarf_reg;
    uint16_t pad2;
    int32_t offset;
} SyliStackMap_Location;

typedef struct __attribute__((packed)) {
    uint64_t patchpoint_id;
    uint32_t instr_offset;
    uint16_t flags;
    uint16_t num_locations;
} SyliStackMap_Record;

typedef struct {
    uintptr_t pc;
    SyliStackMap_Record* record;
    SyliStackMap_Location* locations;
} SyliStackMap_Record_Entry;

void syli_build_stackmap_record_entry(const unsigned char* start);
SyliStackMap_Record_Entry syli_lookup_record_entry(uint64_t pc);

int syli_rt_stackmap_supported(
    const unsigned char* start, const unsigned char* stop);
void syli_rt_stackmap_check_version(void);

void syli_rt_collect_stack_roots(void);

#endif
