
.section .data
memory_location:
_start:

# Set initial register values (PC start address = 0x1eceb000)
# Test instruction set (about 40 lines)

# PC addresses
ADDI x1, x0, 10        # x1 = 10                    # PC = 0x1eceb000
ADDI x2, x0, 20        # x2 = 20                    # PC = 0x1eceb004
ADD x3, x1, x2         # x3 = x1 + x2 = 30           # PC = 0x1eceb008
SUB x4, x3, x1         # x4 = x3 - x1 = 20           # PC = 0x1eceb00c
XOR x5, x1, x2         # x5 = x1 ^ x2 = 30           # PC = 0x1eceb010
OR x6, x4, x5          # x6 = x4 | x5 = 30           # PC = 0x1eceb014
AND x7, x3, x4         # x7 = x3 & x4 = 10           # PC = 0x1eceb018
SLL x8, x2, x1         # x8 = x2 << x1 = 20480       # PC = 0x1eceb01c
SRL x9, x8, x1         # x9 = x8 >> x1 = 20          # PC = 0x1eceb020
SRA x10, x9, x1        # x10 = x9 >>> x1 = 0         # PC = 0x1eceb024
SLT x11, x1, x2        # x11 = (x1 < x2) ? 1 : 0 = 1 # PC = 0x1eceb028
SLTU x12, x1, x2       # x12 = (x1 < x2) ? 1 : 0 = 1 # PC = 0x1eceb02c
ADDI x13, x0, 5        # x13 = 5                    # PC = 0x1eceb030
XORI x14, x13, 3       # x14 = x13 ^ 3 = 6           # PC = 0x1eceb034
ORI x15, x1, 255       # x15 = x1 | 255              # PC = 0x1eceb038
ANDI x16, x2, 15       # x16 = x2 & 15               # PC = 0x1eceb03c
SLLI x17, x2, 2        # x17 = x2 << 2 = 80          # PC = 0x1eceb040
SRLI x18, x17, 2       # x18 = x17 >> 2 = 20         # PC = 0x1eceb044
SRAI x19, x18, 1       # x19 = x18 >>> 1 = 10        # PC = 0x1eceb048
SLTI x20, x1, 15       # x20 = (x1 < 15) ? 1 : 0 = 1 # PC = 0x1eceb04c
SLTIU x21, x2, 25      # x21 = (x2 < 25) ? 1 : 0 = 1 # PC = 0x1eceb050

# Test Load and Store instructions
SB x2, 2(x5)           # Store the lower 8 bits of x2 to memory address x1       # PC = 0x1eceb054
SH x3, 0(x4)           # Store the lower 16 bits of x3 to memory address x1 + 2   # PC = 0x1eceb058
SW x4, 2(x14)           # Store the value of x4 to memory address x1 + 4           # PC = 0x1eceb05c
LB x22, 3(x13)          # Load 8-bit value from memory address x1 to x22 (sign-extended) # PC = 0x1eceb060
LH x23, 0(x2)          # Load 16-bit value from memory address x1 + 2 to x23 (sign-extended) # PC = 0x1eceb064
LW x24, 3(x13)          # Load 32-bit value from memory address x1 + 4 to x24      # PC = 0x1eceb068

# Test branch instructions
BEQ x1, x2, label1     # If x1 == x2, jump to label1                             # PC = 0x1eceb06c
BNE x1, x13, label2    # If x1 != x13, jump to label2                            # PC = 0x1eceb070
BLT x1, x2, label1     # If x1 < x2, jump to label3                              # PC = 0x1eceb074

label1: # PC = 0x1eceb078
ADDI x25, x0, 42       # x25 = 42                                                # PC = 0x1eceb078


label2: # PC = 0x1eceb07c
SLLI x17, x2, 2         

SUB x4, x3, x1        
XOR x5, x1, x2        
OR x6, x4, x5 
# Special instruction to end the simulation
slti x0, x0, -256      # this is the magic instruction to end the simulation     # PC = 0x1eceb084

    slti x0, x0, -256 # this is the magic instruction to end the simulationS
