#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdio.h>

#include "bt9_reader.h"

typedef enum {
    bp_type_invalid = 0,
    bp_type_ret     = 1,
    bp_type_jmp     = 2,
    bp_type_call    = 3
} bp_type_t;

typedef struct __attribute__((packed)) {
    uint32_t  direct : 1;
    uint32_t  cond   : 1;
    bp_type_t type_  : 2;
} bp_opcode_t;

static bt9::BT9Reader* bt9_reader;
static bt9::BT9Reader::BranchInstanceIterator it;
static bool has_ended = 0;

extern "C" void bt9_shim_init(char* name){
    std::string trace_path = name;
    bt9_reader = new bt9::BT9Reader(trace_path);
    it = bt9_reader->begin();
    ++it;
    std::string key = "branch_instruction_count:";
    std::string value;
    bt9_reader->header.getFieldValueStr(key, value);
    uint64_t branch_instruction_count = std::stoull(value, nullptr, 0);
    printf("bt9: total branch count %lu\n", branch_instruction_count);
}

extern "C" uint32_t bt9_shim_get_type(void){
    if (has_ended) {
        return 0;
    }
    bt9::BrClass br_class = it->getSrcNode()->brClass();

    union {
        bp_opcode_t opType;
        uint8_t     b;
    } u;

    if        (br_class.type == bt9::BrClass::Type::RET) {
        u.opType.type_ = bp_type_ret;
    } else if (br_class.type == bt9::BrClass::Type::JMP) {
        u.opType.type_ = bp_type_jmp;
    } else if (br_class.type == bt9::BrClass::Type::CALL) {
        u.opType.type_ = bp_type_call;
    } else {
        u.opType.type_ = bp_type_invalid;
    }

    if        (br_class.conditionality == bt9::BrClass::Conditionality::CONDITIONAL){
        u.opType.cond = 1;
    } else if (br_class.conditionality == bt9::BrClass::Conditionality::UNCONDITIONAL) {
        u.opType.cond = 0;
    } else {
        u.opType.type_ = bp_type_invalid;
    }

    if        (br_class.directness == bt9::BrClass::Directness::DIRECT) {
        u.opType.direct = 1;
    } else if (br_class.directness == bt9::BrClass::Directness::INDIRECT) {
        u.opType.direct = 0;
    } else {
        u.opType.type_ = bp_type_invalid;
    }

    return u.b;
}

extern "C" uint32_t bt9_shim_get_pc(void){
    if (has_ended) {
        return 0;
    }

    // printf("bt9: pc %lx\n", it->getSrcNode()->brVirtualAddr());
    return it->getSrcNode()->brVirtualAddr();
}

extern "C" uint32_t bt9_shim_get_taken(void){
    if (has_ended) {
        return 0;
    }
    return it->getEdge()->isTakenPath();
}

extern "C" uint32_t bt9_shim_get_target(void){
    if (has_ended) {
        return 0;
    }
    return it->getEdge()->brVirtualTarget();
}

extern "C" uint32_t bt9_shim_advance(void){
    if (!has_ended) {
        ++it;
        has_ended = (it == bt9_reader->end());
    }
    return has_ended;
}
