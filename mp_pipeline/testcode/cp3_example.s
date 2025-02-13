.section .text
.globl _start
_start:
    addi x1, x0, 4
    addi x3, x1, 8

    slti x0, x0, -256 # this is the magic instruction to end the simulation
