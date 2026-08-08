#include "syli/gc_roots.h"
#include "syli/syli_state.h"

#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

/*
 * Synthetic .llvm_stackmaps (v3) section:
 *   1 function (addr 0x1000, stack 0x20), 0 constants, 3 records.
 *   r0 instr 0x00, 1 location (Indirect, rsp, off 0)   -> 40 bytes
 *   r1 instr 0x10, 2 locations                         -> 48 bytes
 *   r2 instr 0x20, 0 locations                         -> 24 bytes
 *   total 152 bytes.
 */
static unsigned char section[152];

static void init_section(void)
{
    memset(section, 0, sizeof(section));

    SyliStackMap_Header* h = (SyliStackMap_Header*)section;
    h->version             = 3;
    h->num_functions       = 1;
    h->num_constants       = 0;
    h->num_records         = 3;

    SyliStackMap_Function* f = (SyliStackMap_Function*)(section + 16);
    f->addr                  = 0x1000;
    f->stack_size            = 0x20;
    f->num_records           = 3;

    SyliStackMap_Record* r0   = (SyliStackMap_Record*)(section + 40);
    r0->patchpoint_id         = 1;
    r0->instr_offset          = 0x00;
    r0->num_locations         = 1;
    SyliStackMap_Location* l0 = (SyliStackMap_Location*)(r0 + 1);
    l0[0].kind                = 3;
    l0[0].size                = 8;
    l0[0].dwarf_reg           = 7; /* rsp */
    l0[0].offset              = 0;

    SyliStackMap_Record* r1   = (SyliStackMap_Record*)(section + 80);
    r1->patchpoint_id         = 2;
    r1->instr_offset          = 0x10;
    r1->num_locations         = 2;
    SyliStackMap_Location* l1 = (SyliStackMap_Location*)(r1 + 1);
    l1[0].kind                = 3;
    l1[0].dwarf_reg           = 7;
    l1[0].offset              = 8;
    l1[1].kind                = 4; /* constant */
    l1[1].offset              = 0;

    SyliStackMap_Record* r2 = (SyliStackMap_Record*)(section + 128);
    r2->patchpoint_id       = 3;
    r2->instr_offset        = 0x20;
    r2->num_locations       = 0;
}

static void test_version_supported(void)
{
    assert(syli_rt_stackmap_supported(section, section + sizeof(section)) == 1);

    assert(syli_rt_stackmap_supported(NULL, NULL) == 1);
    assert(syli_rt_stackmap_supported(section, section) == 1);

    unsigned char v2[sizeof(section)];
    memcpy(v2, section, sizeof(section));
    ((SyliStackMap_Header*)v2)->version = 2;
    assert(syli_rt_stackmap_supported(v2, v2 + sizeof(v2)) == 0);
}

static void test_build_and_lookup(void)
{
    assert(syli_state.stackmap_record_entry == NULL);

    syli_build_stackmap_record_entry(section);
    assert(syli_state.stackmap_record_entry != NULL);
    assert(syli_state.stackmap_record_entry_len == 3);

    assert(syli_state.stackmap_record_entry[0].pc == 0x1000);
    assert(syli_state.stackmap_record_entry[1].pc == 0x1010);
    assert(syli_state.stackmap_record_entry[2].pc == 0x1020);

    assert(syli_state.stackmap_record_entry[0].record->instr_offset == 0x00);
    assert(syli_state.stackmap_record_entry[0].locations != NULL);
    assert(syli_state.stackmap_record_entry[0].locations[0].kind == 3);
    assert(syli_state.stackmap_record_entry[1].locations != NULL);
    assert(syli_state.stackmap_record_entry[1].locations[1].kind == 4);

    /* one-shot: a second build is a no-op */
    ((SyliStackMap_Header*)section)->num_records = 2;
    syli_build_stackmap_record_entry(section);
    assert(syli_state.stackmap_record_entry_len == 3);

    const SyliStackMap_Record_Entry e = syli_lookup_record_entry(0x1000);
    assert(e.pc == 0x1000);
    assert(e.record->instr_offset == 0x00);
    assert(e.locations[0].kind == 3);

    assert(syli_lookup_record_entry(0x1010).record->instr_offset == 0x10);
    assert(syli_lookup_record_entry(0x1020).record->instr_offset == 0x20);

    assert(syli_lookup_record_entry(0x1002).record == NULL);
    assert(syli_lookup_record_entry(0x1015).record == NULL);
    assert(syli_lookup_record_entry(0x2000).record == NULL);
    assert(syli_lookup_record_entry(0x0fff).record == NULL);
}

int main(void)
{
    init_section();
    test_version_supported();
    test_build_and_lookup();
    printf("gc_roots: ok\n");
    return 0;
}
