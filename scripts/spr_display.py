import pygame

img1 = "00 00 00 00 3E 00 01 F9 C0 07 C6 F0 0F BE F8 0F C1 8C 1F FD AC 1B CF 76 07 97 46 3F BA 0A 3F A1 BC 7F 83 DC 77 9B D4 0F 7A BC 09 FC 68 02 EF 70 0F FB 0E 1F 6E FA 1F B9 6C 07 C7 B0 01 FD D0 00 76 C0 00 18 00 00 00 00"
msk1 = "FF C1 FF FE 3E 3F F9 F9 CF F7 C0 F7 EF 80 FB EF C1 8D DF FD 8D DB CF 36 C7 87 06 BF 9A 0A BF 80 3D 7F 80 1D 77 98 15 8F 78 3D E9 FC 6B F2 EF 71 EF FB 0E DF 6E FA DF B9 6D E7 C7 B3 F9 FD D7 FE 76 CF FF 99 3F FF E7 FF"

img2 = "00 00 00 00 7C 00 01 FF 00 03 FF 80 07 FE 40 07 F3 C0 0F EF E0 0F FF 78 0F FB 44 0F FB 82 17 FF 82 1B FF 02 37 FE 82 77 7E 04 2F 76 04 2E E7 1C 2F 38 FC 77 CF 98 1B B6 00 0C F8 00 08 58 00 00 30 00 00 00 00 00 00 00"
msk2 = "FF 83 FF FE 7C FF FD FF 7F FB FF BF F7 FE 5F F7 F3 DF EF EF EF EF FF 7F EF FB 47 EF FB 83 C7 FF 83 C3 FF 03 87 FE 83 07 7E 07 8F 76 07 8E E7 19 8F 38 E1 07 CF 83 83 86 67 E0 81 FF E3 03 FF F7 87 FF FF CF FF FF FF FF"

img3 = "00 00 00 00 1F 00 00 7F C0 00 FF E0 01 FF 20 01 F9 F0 03 F7 F0 03 FF BC 03 FD A2 25 FD C1 1D FF C1 0B FF 81 17 9F 41 37 3F 02 67 BF 02 1B 9B CE 0D 6C 3C 0A F6 60 10 B7 80 00 60 00 00 00 00 00 00 00 00 00 00 00 00 00"
msk3 = "FF E0 FF FF 9F 3F FF 7F DF FE FF EF FD FF 2F FD F9 F7 FB F7 F7 FB FF BF DB FD A3 81 FD C1 C1 FF C1 E3 FF 81 C7 9F 41 87 3F 03 07 BF 02 83 9B CC E1 0C 31 E0 06 63 C4 07 9F EF 08 7F FF 9F FF FF FF FF FF FF FF FF FF FF"

image_width = 3
image_height = 24

pygame.init()
window = pygame.display.set_mode((600, 600))
pygame.display.set_caption("HoH sprites")

scale = 4

def dosprite(img, msk, offset= 0):
    x = y = 0
    for img_byte, msk_byte in zip(img.split(None), msk.split(None)):
        ibyte = int(img_byte, 16)
        imask = int(msk_byte, 16)
        for bit in range(7, -1, -1):
            imgbitvalue = (ibyte >> bit) & 0x01
            mskbitvalue = (imask >> bit) & 0x01
            val = (imgbitvalue << 1) + mskbitvalue

            match val:
                case 0: col0r = 'black'
                case 1: col0r = 'grey'
                case 2: col0r = 'blue'
                case 3: col0r = '#F8F0A0'

            pygame.draw.rect(window, col0r, (offset + (x*scale), y*scale, scale, scale))
            x += 1
            if x == image_width * 8:
                x = 0
                y += 1

def draw():
    window.fill((30, 30, 30))
    dosprite(img1, msk1)
    dosprite(img2, msk2, 200)
    dosprite(img3, msk3, 400)

    pygame.display.update()

def run():
    while True:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                raise SystemExit
        draw()

run()