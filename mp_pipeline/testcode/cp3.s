.section .data
memory_location:
_start:
ADDI x0, x0, 12      
ADDI x2, x0, 20  
OR x21, x0, x0   
ADDI x17, x0, 42             
SW x2, 0(x1)          
LW x20, 0(x1)         
          
OR x21, x20, x1    
ANDI x22, x2, 15        
BLT x1, x2, label4    
BGE x2, x1, label5    


ADDI x1, x0, 10 
      
label4: 
ADDI x23, x0, 1        

label5: # PC = 0x1eceb070
ADDI x24, x0, 2       

slti x0, x0, -256 # this is the magic instruction to end the simulation
