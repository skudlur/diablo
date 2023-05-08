# diablo

<p align="center">
  <img src="./assets/diablo2-02.png" width="500" height="500" title="diablo">
</p>

diablo is a Out-Of-Order 64 bit RISC-V processor.

## diablo single-cycle 

```
                                                                                                                                                                                                                         
                                                               diablo single-cycle version                                                                                                                               
                                                                                                                                                                                                                         
                                                                                                                                                                                                                         
                                                          -------------------------------------------------------------------------------------------|                                                                   
----------------------------------------------------------|----------------------------------------------------------                                |                                                                   
|                                                         |                                                         |                                |                                                                   
|                                                         | +------------------+                                    |                                |                                                                   
|                                                         |-|                  |                                    |      +--------------------+    |                                                                   
|                                                           |                  |             +-----------------+    |      |                    |    |                                                                   
|                                                           |                  |             |                 |    |      |                    |    |                                                                   
|                                    +-----------+          |      Integer     |-------------|                 -----|------|                    |----|                                                                   
|                 +------------+     |           |----------|   Register File  |-------------|   Arithmetic    |           |     Data Memory    |                                                                        
|   +----+        |            |     |           |----------|                  |             |     Logical     |           |                    |                                                                        
|-- | pc |--------|   Ins.r    ------|  Decoder  |----------|                  |    |--------|       Unit      |           |                    |                                                                        
    +----+        |   Memory   |     |           |---|      |                  |    |   |----|                 |         --|                    |                                                                        
                  |            |     |           |   |      |                  |    |   |    |                 |         | |                    |                                                                        
                  +------------+     +-----------+   |      +------------------+    |   |    +-----------------+         | +--------------------+                                                                        
                                                     | +---------+                  |   |                                |                                                                                               
                                                     --|         |------------------|----                                |                                                                                               
                                                       |Imm.     |                  |------------------------------------|                                                                                               
                                                       |Generator|                                                                                                                                
                                                       +---------+                                                                                                                                  
                                                                                                                                                                                                                         
                                                                                                                                                                                                                         
                                                                                                                                                                                                                         
                                                                                                                                                                                                                            
```

### What can diablo do?
- Run instructions out-of-order after resolving data dependencies between multiple operands.
- It can perform vector operations, floating-point operations and atomics.
- We want to have diablo run Linux.


- Currently under development
