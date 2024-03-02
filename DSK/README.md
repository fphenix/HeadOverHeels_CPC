DSK file used (Amstrad CPC, load in WinApe for instance).

Note : In this DSK, the HEADOVER.III file is missing 16 "00" bytes at the end.
(should be loaded at ADB0-ADBF then moved during init at B888-B897)

Thus I can see a glitch at the bottom of the pillars (below high doors).
In another DSK version we see it should be 16 "00" bytes and indeed it gets rid of the glich.
To fix this, poke these values when you are on the game main menu (WinApe)
   B888 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
