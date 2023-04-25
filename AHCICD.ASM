        .model tiny
	.586p

CODE    SEGMENT
	ASSUME  CS:CODE
        ORG     0

BASE    DD      -1
        DW      0C800H,STRAT,ENTRY
        DB      '-       '
        DW      0
        DB      0
COUNT   DB      0
        DB      'AHCI CD/DVD DOS Driver',0

STRAT:  MOV     CS:[HDROFF],BX
	MOV     CS:[HDRSEG],ES
        RETF

ENTRY:  CLD
        PUSHAD
	PUSH    DS
	PUSH    ES
	LDS     BX,DWORD PTR CS:[HDROFF]
	MOV     AL,DS:[BX+2]
        AND     AL,AL
        JZ      NOUNIT
        MOV     AL,CS:[COUNT]
        CMP     DS:[BX+1],AL
        MOV     AL,1
        JNC     ERRORX
NOUNIT: SUB     AH,AH
	MOV     AL,DS:[BX+2]
        ADD     AL,AL
        JC      HIGHV
        CMP     AL,30
        JNC     ERROR3
	MOV     SI,OFFSET VECTOR
LOWVEC: ADD     SI,AX
        JMP     WORD PTR CS:[SI]
HIGHV:  CMP     AL,6
        JNC     ERROR3
        MOV     SI,OFFSET VECT2
        JMP     LOWVEC

ERROR3: MOV     AL,3
ERRORX: MOV     AH,81H
        STC
        JMP     EXIT1
EXIT:   MOV     AX,100H
        CLC
EXIT1:  LDS     BX,DWORD PTR CS:[HDROFF]
        MOV     DS:[BX+3],AX
        MOV     CS:[EXVAL],AX
	POP     ES
	POP     DS
        POPAD
        MOV     AX,CS:[EXVAL]
        RETF

IOCTLI: LES     SI,FAR PTR DS:[BX+14]
        MOV     AL,ES:[SI]
        CMP     AL,10
        JNC     ERROR3
        MOV     DI,OFFSET IVEC
IOCTL:  ADD     AL,AL
        SUB     AH,AH
        ADD     DI,AX
        JMP     WORD PTR CS:[DI]

GETHDR: MOV     WORD PTR ES:[SI+1],0
        MOV     ES:[SI+3],CS
        JMP     EXIT

DEVST:  MOV     DWORD PTR ES:[SI+1],2           ;DOOR LOCK ? OPEN=1 UNLOCK=2
        JMP     EXIT

SECSIZ: MOV     WORD PTR ES:[SI+2],2048
        JMP     EXIT

MEDIA:
        PUSH    SI
        CALL    SETUP
        MOV     EAX,EDI
        ADD     EAX,40H
        MOV     ECX,14AH
        CALL    PUTMEM
        MOV     EAX,EDI
        ADD     EAX,44H
        MOV     ECX,10H
        CALL    PUTMEM
        MOV     EAX,EDI
        ADD     EAX,48H
        MOV     ECX,8
        CALL    PUTMEM
        CALL    REQ8
        POP     SI
        AND     AL,AL
        JNZ     MEDCHG
        PUSH    DS
        MOV     AX,CS:[BUFFSEG]
        MOV     DS,AX
        MOV     AX,DS:[4]
        POP     DS
        AND     AL,AL
        JNZ     MEDCHG
        TEST    AH,2
        JZ      MEDCHG
        MOV     BYTE PTR ES:[SI+1],1
        JMP     MEDEND
MEDCHG: MOV     BYTE PTR ES:[SI+1],0
MEDEND: PUSH    SI
        CALL    SETUP
        CALL    REQSEN
        POP     SI
        PUSH    DS
        MOV     AX,CS:[BUFFSEG]
        MOV     DS,AX
        MOV     AL,DS:[2]
        POP     DS
        AND     AL,15
        JZ      EXIT
        MOV     BYTE PTR ES:[SI+1],0
        CMP     AL,6
        JZ      MEDEND
        JMP     EXIT

;       +1=UNIT +14=ADDRESS +18=SEC COUNT +20=START SEC

READL:  CMP     BYTE PTR DS:[BX+13],0
        JNZ     ERROR3
        CMP     BYTE PTR DS:[BX+24],0
        JNZ     ERROR3
        MOV     EAX,DS:[BX+14]
        MOV     CS:[XFERAD],EAX
        MOV     AX,DS:[BX+18]
        MOV     CS:[SECCNT],AX
        MOV     EAX,DS:[BX+20]
        MOV     CS:[SECTOR],EAX
READLP: CMP     WORD PTR CS:[SECCNT],0
        JZ      EXIT
        CALL    SETUP
        MOV     EAX,EDI
        ADD     EAX,40H
        MOV     ECX,CS:[SECTOR]
        SHR     ECX,16
        XCHG    CL,CH
        SHL     ECX,16
        MOV     CX,28H
        CALL    PUTMEM
        MOV     EAX,EDI
        ADD     EAX,44H
        MOVZX   ECX,WORD PTR CS:[SECTOR]
        XCHG    CL,CH
        CALL    PUTMEM
        MOV     EAX,EDI
        ADD     EAX,48H
        MOV     ECX,1
        CALL    PUTMEM
        MOV     EAX,EDI
        ADD     EAX,8CH
        MOV     ECX,800007FFH
        CALL    PUTMEM
        CALL    DOIT
        AND     AL,AL
        JZ      GOOD
        CALL    SETUP
        CALL    REQSEN
        AND     AL,AL
        JNZ     ERRORX
        MOV     CX,CS:[BUFFSEG]
        MOV     DS,CX
        MOV     AL,DS:[2]
        AND     AL,15
        PUSH    CS
        POP     DS
        LEA     BX,OFFSET ERRTAB
        XLAT
        JMP     ERRORX

GOOD:   PUSH    DS
        MOV     CX,200H
        LES     DI,CS:[XFERAD]
        MOV     AX,CS:[BUFFSEG]
        MOV     DS,AX
        XOR     SI,SI
        CLD
        REP     MOVSD
        POP     DS
        ADD     WORD PTR CS:[XFERAD+2],80H
        INC     DWORD PTR CS:[SECTOR]
        DEC     WORD PTR CS:[SECCNT]
        JMP     READLP

SETUP:  XOR     AH,AH
        MOV     AL,DS:[BX+1]
        ADD     AL,AL
        MOV     BP,OFFSET PORT
        ADD     BP,AX
        MOV     BP,CS:[BP]
        ADD     AL,AL
        MOV     SI,OFFSET ACL
        MOV     DI,OFFSET ACT
        ADD     SI,AX
        ADD     DI,AX
        MOV     ESI,CS:[SI]
        MOV     EDI,CS:[DI]
        MOV     EAX,ESI
        MOV     ECX,10025H
        CALL    PUTMEM
        MOV     EAX,ESI
        ADD     EAX,4
        XOR     ECX,ECX
        CALL    PUTMEM
        MOV     EAX,EDI
        MOV     ECX,1A08027H
        CALL    PUTMEM
        MOV     EAX,EDI
        ADD     EAX,4
        MOV     ECX,0FFFF00H
        CALL    PUTMEM
        MOV     EAX,EDI
        ADD     EAX,8
        XOR     ECX,ECX
        CALL    PUTMEM
        MOV     EAX,EDI
        ADD     EAX,12
        MOV     ECX,1
        CALL    PUTMEM
        MOV     ECX,CS:[PBUFF]
        MOV     EAX,EDI
        ADD     EAX,80H
        CALL    PUTMEM
        MOV     EAX,EDI
        ADD     EAX,84H
        XOR     ECX,ECX
        CALL    PUTMEM
        MOV     EAX,EDI
        ADD     EAX,88H
        CALL    PUTMEM
        MOV     AX,BP
        ADD     AX,14H
        XOR     ECX,ECX
        CALL    PUTHBA
        MOV     AX,BP
        ADD     AX,10H
        MOV     ECX,-1
        CALL    PUTHBA
        MOV     AX,BP
        ADD     AX,30H
        CALL    PUTHBA
        MOV     AX,BP
        ADD     AX,18H
        CALL    GETHBA
        MOV     ECX,EAX
        OR      CL,10H
        MOV     AX,BP
        ADD     AX,18H
        CALL    PUTHBA
        OR      CL,1
        MOV     AX,BP
        ADD     AX,18H
        CALL    PUTHBA
WAITST: MOV     AX,BP
        ADD     AX,18H
        CALL    GETHBA
        TEST    AX,8000H
        JZ      WAITST
        RET

REQSEN: MOV     EAX,EDI
        ADD     EAX,40H
        MOV     ECX,3
        CALL    PUTMEM
        MOV     EAX,EDI
        ADD     EAX,44H
        MOV     CL,8
        CALL    PUTMEM
        MOV     EAX,EDI
        ADD     EAX,48H
        MOV     CL,0
        CALL    PUTMEM
REQ8:   MOV     EAX,EDI
        ADD     EAX,8CH
        MOV     ECX,80000007H
        CALL    PUTMEM
DOIT:   MOV     AX,BP
        ADD     AX,38H
        MOV     ECX,1
        CALL    PUTHBA
WAITEN: MOV     AX,BP
        ADD     AX,38H
        CALL    GETHBA
        AND     EAX,EAX
        JZ      FIN
        MOV     AX,BP
        ADD     AX,10H
        CALL    GETHBA
        TEST    EAX,40000000H
        JNZ     FINERR
        MOV     AX,BP
        ADD     AX,30H
        CALL    GETHBA
        AND     EAX,EAX
        JZ      WAITEN
FINERR: CALL    STOP
        MOV     AL,12
        JMP     PROCER
FIN:    MOV     AX,BP
        ADD     AX,20H
        CALL    GETHBA
        TEST    AL,1
        JNZ     FINERR
        CALL    STOP
        XOR     AX,AX
PROCER: RET

STOP:   MOV     AX,BP
        ADD     AX,18H
        CALL    GETHBA
        MOV     ECX,EAX
        OR      CL,8
        AND     CL,0EEH
        MOV     AX,BP
        ADD     AX,18H
        CALL    PUTHBA
        RET

GETPCI: PUSH    EDX                      ;EDX = ADDR+80000000
        PUSH    EBX
        PUSH    EDX
        MOV     DX,0CF8H
        IN      EAX,DX
        MOV     EBX,EAX
        POP     EAX
        OUT     DX,EAX
        MOV     DL,0FCH
        IN      EAX,DX
        MOV     DL,0F8H
        PUSH    EAX
        MOV     EAX,EBX
        OUT     DX,EAX
        POP     EAX
        POP     EBX
        POP     EDX
        RET

PUTPCI: PUSH    EDX                      ;EDX = ADDR+80000000  EAX = VALUE
        PUSH    EBX
        PUSH    EAX
        PUSH    EDX
        MOV     DX,0CF8H
        IN      EAX,DX
        MOV     EBX,EAX
        POP     EAX
        OUT     DX,EAX
        MOV     DL,0FCH
        POP     EAX
        OUT     DX,EAX
        MOV     DL,0F8H
        MOV     EAX,EBX
        OUT     DX,EAX
        POP     EBX
        POP     EDX
        RET

GETHBA: PUSH    EDX                     ;AX = ADDR
        MOV     EDX,CS:[HBA]
        AND     EDX,EDX
        JS      GHP
        OUT     DX,AX
        ADD     DX,4
        IN      EAX,DX
        JMP     GHE
GHP:    CALL    PUTPCI
        ADD     EDX,4
        CALL    GETPCI
GHE:    POP     EDX
        RET

PUTHBA: PUSH    EDX                     ;AX = ADDR  ECX = VALUE
        MOV     EDX,CS:[HBA]
        AND     EDX,EDX
        JS      PHP
        OUT     DX,AX
        ADD     DX,4
        MOV     EAX,ECX
        OUT     DX,EAX
        JMP     PHE
PHP:    CALL    PUTPCI
        ADD     EDX,4
        MOV     EAX,ECX
        CALL    PUTPCI
PHE:    POP     EDX
        RET

GETMEM: PUSH    EDX                     ;EAX = ADDR
        PUSH    ES
        MOV     EDX,EAX
        SHR     EDX,4
        MOV     ES,DX
        AND     EAX,0FH
        MOV     EAX,ES:[EAX]
        POP     ES
        POP     EDX
        RET

PUTMEM: PUSH    EDX                     ;EAX = ADDR  ECX = VALUE
        PUSH    ES
        MOV     EDX,EAX
        SHR     EDX,4
        MOV     ES,DX
        AND     EAX,0FH
        MOV     ES:[EAX],ECX
        POP     ES
        POP     EDX
        RET

VECTOR  DW      INIT,ERROR3,ERROR3,IOCTLI,ERROR3,ERROR3,ERROR3,ERROR3
        DW      ERROR3,ERROR3,ERROR3,ERROR3,ERROR3,EXIT,EXIT

VECT2   DW      READL,ERROR3,EXIT

IVEC    DW      GETHDR,ERROR3,ERROR3,ERROR3,ERROR3,ERROR3,DEVST,SECSIZ
        DW      ERROR3,MEDIA

HDROFF  DW      0
HDRSEG  DW      0
EXVAL   DW      0
ERRTAB  DB      12,12,2,4,12,0,15,8,8,12,12,12,12,12,12,12
XFERAD  DD      0
SECCNT  DW      0
SECTOR  DD      0

HBA     DD      0
PORT    DW      0,0,0,0,0,0
ACL     DD      0,0,0,0,0,0
ACT     DD      0,0,0,0,0,0
PBUFF   DD      0
BUFFSEG DW      0

        ALIGN   16

INIT:   MOV     WORD PTR DS:[BX+14],OFFSET INIT
        MOV     AX,CS
        ADD     AX,80H
        MOV     DS:[BX+16],AX
        PUSH    DS
        PUSH    CS
        POP     DS
        MOV     DX,OFFSET MESS
        MOV     AH,9
        INT     21H
        POP     DS
        LDS     SI,DS:[BX+12H]
ARG:    LODSB
        CMP     AL,32
        JC      BADARG
        CMP     AL,'/'
        JNZ     ARG
        LODSB
        CMP     AL,'d'
        JZ      LARG
        CMP     AL,'D'
        JNZ     ARG
LARG:   LODSB
        CMP     AL,':'
        JNZ     ARG
        PUSH    CS
        POP     ES
        MOV     DI,10
        MOV     CX,8
ARG1:   LODSB
        CMP     AL,33
        JC      DONE
        CMP     AL,61H
        JC      ARG2
        CMP     AL,7BH
        JNC     ARG2
        SUB     AL,20H
ARG2:   STOSB
        LOOP    ARG1
DONE:   LDS     BX,DWORD PTR CS:[HDROFF]
        LDS     SI,DS:[BX+12H]
        MOV     BP,1
ARGC:   LODSB
        CMP     AL,32
        JC      NOARG
        CMP     AL,'/'
        JNZ     ARGC
        LODSB
        CMP     AL,'c'
        JZ      LARG2
        CMP     AL,'C'
        JNZ     ARGC
LARG2:  LODSB
        CMP     AL,':'
        JNZ     ARGC
        LODSB
        CMP     AL,30H
        JC      BADARG
        CMP     AL,3AH
        JNC     BADARG
        SUB     AL,2FH
        MOV     AH,0
        MOV     BP,AX
NOARG:  PUSH    CS
        POP     DS
        MOV     EDX,80000008H
FNDHBA: CALL    GETPCI
        AND     EAX,0FFFFFF00H
        CMP     EAX,1060100H
        JZ      GOTHBA
NXTHBA: ADD     EDX,100H
        CMP     EDX,81000008H
        JC      FNDHBA
        JMP     NG
GOTHBA: DEC     BP
        JNZ     NXTHBA
        MOV     DL,34H
        CALL    GETPCI
GETCAP: AND     AL,AL
        JZ      NG
        MOV     DL,AL
        CALL    GETPCI
        CMP     AL,12H
        JZ      GOTCAP
        MOV     AL,AH
        JMP     GETCAP
GOTCAP: ADD     DL,4
        CALL    GETPCI
        CMP     AL,0FH
        JNZ     IOPORT
        ADD     DL,4
        MOV     DS:[HBA],EDX
        JMP     ENDHBA
IOPORT: MOV     CX,AX
        SHR     CL,2
        AND     CL,0FCH
        AND     AL,0FH
        SHL     AL,2
        MOV     DL,AL
        CALL    GETPCI
        TEST    AL,1
        JZ      NG
        AND     AL,0FEH
        ADD     AX,CX
        MOV     DS:[HBA],EAX
ENDHBA:
        MOV     AX,4
        CALL    GETHBA
        TEST    EAX,80000000H
        JZ      INACT
        MOV     AX,0CH
        CALL    GETHBA
        MOV     ECX,EAX
        MOV     DX,100H
        XOR     SI,SI
        MOV     DI,OFFSET PORT
FNDPRT: AND     ECX,ECX
        JZ      ENDPRT
        TEST    CL,1
        JNZ     YESPRT
NOPORT: SHR     ECX,1
        ADD     DX,80H
        JMP     FNDPRT
YESPRT: MOV     AX,DX
        ADD     AX,24H
        CALL    GETHBA
        CMP     EAX,0EB140101H
        JNZ     NOPORT
        MOV     AX,DX
        ADD     AX,28H
        CALL    GETHBA
        AND     AL,0FH
        CMP     AL,3
        JNZ     NOPORT
        MOV     DS:[DI],DX
        ADD     DI,2
        INC     SI
        CMP     SI,6
        JC      NOPORT
ENDPRT: MOV     CX,SI
        MOV     DS:[COUNT],CL
        AND     CL,CL
        JZ      NG
        PUSH    CX
        MOV     SI,OFFSET PORT
        MOV     DI,OFFSET ACL
GETCL:  MOV     AX,DS:[SI]
        ADD     SI,2
        CALL    GETHBA
        MOV     DS:[DI],EAX
        ADD     DI,4
        LOOP    GETCL
        POP     CX
        MOV     SI,OFFSET ACL
        MOV     DI,OFFSET ACT
GETCT:  MOV     AX,DS:[SI]
        ADD     SI,2
        ADD     EAX,8
        CALL    GETMEM
        MOV     DS:[DI],EAX
        ADD     DI,4
        LOOP    GETCT
        MOV     AL,DS:[COUNT]
        ADD     AL,30H
        MOV     DS:[MESS4],AL
        MOV     DX,OFFSET MESS4
        MOV     AH,9
        INT     21H
        XOR     EAX,EAX
        XOR     EDX,EDX
        MOV     AX,CS
        SHL     EAX,4
        MOV     DX,OFFSET INIT
        ADD     EAX,EDX
        MOV     DS:[PBUFF],EAX
        SHR     EAX,4
        MOV     DS:[BUFFSEG],AX
        JMP     EXIT

INACT:  MOV     DX,OFFSET MESS5
        JMP     NG1

BADARG: MOV     DX,OFFSET MESS2
        JMP     NG1

NG:     MOV     DX,OFFSET MESS3
NG1:    PUSH    CS
        POP     DS
        MOV     AH,9
        INT     21H
        MOV     WORD PTR CS:[BASE+4],0
        JMP     ERROR3

MESS    DB      13,10,'AHCI Optical Drive Driver  Version 1.1',13,10
        DB      'Copyright (c) 2018, by Rudolph R. Loew',13,10
        DB      'All Rights Reserved',13,10,13,10,24H
MESS2   DB      'SYNTAX: DEVICE=AHCICD.SYS /D:devname /C:#',13,10,13,10,24H
MESS3   DB      'No AHCI Optical Disk Found',13,10,13,10,24H
MESS4   DB      '  AHCI Optical Disk(s) Found',13,10,13,10,24H
MESS5   DB      'AHCI Controller not in AHCI Mode',13,10,13,10,24H

CODE    ENDS
	END
