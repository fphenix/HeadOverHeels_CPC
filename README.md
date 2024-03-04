# HeadOverHeels_CPC
Disassembly of the Amstrad CPC game "Head Over Heels" (Ocean)
(Z80 assembly)

Still a work in progress.

Tools used : WinApe. ManageDsk (be careful of the disasm bugs if using this tool) and Notepad++!

A few Python3 scripts.

Thanks:
=======

A big thanks and credit must be given to **Simon Frankau**:
    https://github.com/simon-frankau/head-over-heels .
Simon Frankau did a similar work for the ZX-Spectrum version (from which the CPC version has been ported hence which is very similar).

Files:
======

Note : The files are intended to be view with a Tabs size of 4 defined in your "ProfileImage > Settings > Appearance > Tab Size preference".

The main file for this repo is Disasm/fileinfo_II.txt.
* DSK/HEADOVER.dsk : The WinApe compatible DSK file (Amstrad CPC disk image)
* scripts/hoh_rooms.py : Python3 script that decompacts the Rooms data to visualize the data we get. Result log file scripts/hoh_rooms.out.txt
* scripts/sounds.py : Python3 script that decompacts the Music/Sounds data. Result log file scripts/sounds.out.txt

Licence or rather lack thereof:
===============================

I do not own anything related to this game and this is some reverse-engineering of somebody else's work.
This is done as a hobby, for my own interest, as a study case.

I do not accept any responsability related to consulting or using the information in this repository.
