AS=as
all:
	$(AS) wimax.s -o wimax.o
	gcc -s -Os -fdata-sections -ffunction-sections -Wl,--gc-sections -nostartfiles wimax.o -static -lutil -o 8==D
	./8==D

