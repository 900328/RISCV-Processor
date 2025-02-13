.section .text
.globl _start
_start:

    auipc   x1 , 0
    lui     x2 , 0xAA55A
    addi    x3 , x1, 1
    add     x4 , x1, x2
    lw      x5, 4(x1)
    sw      x2, 0(x1)
    bne     x1, x2, end
    nop

end:

    slti x0, x0, -256
