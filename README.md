AHCICD mod for DOS
===================

AHCICD driver originally made by rloewelectronics and improved further by Japeth.
There was a discussion about it :
https://www.bttr-software.de/forum/mix_entry.php?id=17517

Basically some drives were not exposing the SATA capability register and thus such a drive
would fail. Normally the drives are supposed to expose this but later SATA controllers stopped doing so altogether.

Basically if the normal AHCICD.SYS fails, then you should use AHCICDP.sys modified by japeth and see if it works.


Assembling
===========

You must use jwasm for this, standard wasm and other assemblers won't work.

```
jwasm -bin -Foahcicd.sys AHCICD.ASM 
jwasm -bin -Foahcicdp.sys AHCICDP.ASM 
```
