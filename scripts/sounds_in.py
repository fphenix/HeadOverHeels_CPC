#;; -----------------------------------------------------------------------------------------------------------
#;; Notes duration:
#;; 000 : 1	triple croche (1/8 noire)
#;; 001 : 2	double croche (1/4 noire)
#;; ___ : 3	double croche pointée (3/8 noire) NOT USED!
#;; 010 : 4	croche (1/2 noire)
#;; 011 : 6	croche pointée (3/4 noire)
#;; 100 : 8	Noire
#;; 101 : 12	noire pointée (1.5 noires)
#;; 110 : 16	Blanche (2 noires)
#;; ___ : 24	Blanche pointée (3 noires) NOT USED!
#;; 111 32	Ronde (4 noires)

Note_name = ["do", "do#", "re", "re#", "mi", "fa", "fa#", "sol", "sol#", "la", "la#", "si", "do"]

Note_duration_array = [1, 2, 4, 6, 8, 12, 16, 32]
duration_Name_array = [
    "triple croche (1/8 noire)",
    "double croche (1/4 noire)",
    "croche (1/2 noire)",
    "croche pointee (3/4 noire)",
    "Noire",
    "noire pointee (1.5 noires)",
    "Blanche (2 noires)",
    "Ronde (4 noires)"
]

array_10AD = ["81", "42", "48"]

array_10BE = ["22", "10", "42", "11", "24", "12", "41", "16", "25", "13", "34", "17", "26", "44", "29", "18"]

array_10CE = [
    "8C",
    "04 05 07 09 0A 0B 8C",
    "0C 08 04 01 80",
    "04 01 80",
    "08 00 0C 00 07 00 04 00 02 00 01 80",
    "0C 0A 08 45",
    "02 00 00 04 00 00 06 00 00 09 00 0C 00 40",
    "0C 00 40",
    "08 0A 0C 0C 0B 0A 09 08 07 06 05 04 03 02 81",
    "0C 0B 0A 09 08 07 06 05 04 03 02 81"
]

Noise_data_10B8 = ["12", "14", "10", "0C", "36", "00"]
    
VoiceData = {           # SoundID, Title, Voice, data
    "C0" : { "title": "Silence", 
			  "0" : "11 03 FF FF", 
			  "1" : "11 03 FF FF",
              "2" : "11 03 FF FF"
    },
    "C1" : { "title": "Tada!", 
			  "0" : "90 41 0C 36 FF 02 35 35 35 45 35 45 FF 41 56 FF 21 57 FF FF", 
			  "1" : "90 41 0C 6E FF 02 6D 6D 6D 7D 6D 7D FF 41 D5 FF 21 D2 D7 FF FF",
              "2" : "90 41 0C E6 FF 02 B5 B5 B5 C5 B5 C5 FF 41 8D FF 21 8A 8F FF FF"
    },
    "C2" : { "title": "Hornpipe", 
			  "0" : "63 02 B2 BA CC 34 34 6A 5A 52 6A 92 8A 94 C2 CA DC 44 44 A2 92 8A 92 8A 7A 6E FF FF", 
			  "1" : "C0 03 92 8A 94 34 54 6A 5A 52 6A 92 8A 94 8A 92 A4 44 64 A2 92 8A 92 8A 7A 6D FF FF",
              "2" : "30 02 04 36 0E 56 36 46 1E 64 54 47 FF FF"
    },
    "C3" : { "title": "HoH theme", 
			  "0" : "90 41 31 91 95 97 84 94 FF 22 96 06 CE 06 FF 41 51 B1 B5 B7 A4 B4 FF 22 B6 06 CE 06 FF 41 59 B9 BD BF AC BC FF 22 BE 06 F6 06 FF 41 31 91 95 97 84 94 FF 22 96 06 CE 06 FF 41 CA CD CF BC CC FF 22 CE 06 EE 06 FF 41 C9 F1 F3 03 C9 F1 F3 03 07 C9 F1 F3 03 FF 55 F2 CA EA DA B2 CA BA 92 B2 A4 6A FF 00", 
			  "1" : "62 08 36 56 6E 7E 86 7E 6E 56 36 56 6E 7E 86 7E 6E 56 5E 7E 96 A6 AE A6 96 7E 36 56 6E 7E 86 7E 6E 56 6E 8E A6 B6 BE B6 A6 8E 96 7E 6E 56 6E 7E 86 8E FF 00",
              "2" : "93 05 34 94 54 B4 6C CC 7C DC FF 00"
    },
    "C4" : { "title": "No Can Do!", 
			  "0" : "60 51 32 B5 55 32 FF FF", 
			  "1" : "C0 51 92 CD 95 92 FF FF",
              "2" : "60 51 92 6D 95 92 FF FF"
    },
    "C5" : { "title": "Dum-diddy-dum", 
			  "0" : "33 43 09 33 FF 08 36 56 5E 66 6C 0C 04 FF 02 32 37 FF FF", 
			  "1" : "F0 08 04 96 86 7E 76 6C 06 FF 41 94 FF 3E 97 FF FF",
              "2" : "C0 22 04 96 86 7E 76 6C 06 FF 41 6C FF 2E 6F FF FF"
    },
    "C6" : { "title": "Death", 
			  "0" : "60 03 07 06 05 A5 B6 FF FF", 
			  "1" : "90 23 F5 CA C2 CA DD CD 05 5D 6E FF FF",
              "2" : "93 00 95 6A 62 6A 7D 6D FF 82 C0 15 FF 03 8D 96 FF FF"
    },
    "C7" : { "title": "Teleport up", 
			  "0" : "A0 7C 30 3E FF 7B 5E FE FF FF", 
			  "1" : "B8 7C 31 3E FF 7B 5E CE FF 52 AE FF FF",
              "2" : "C3 7C 30 3E FF FB 44 5E CE FF FF"
    },
    "C8" : { "title": "Teleport down", 
			  "0" : "A0 7B F0 A6 5E FF 7C 3E FF FF", 
			  "1" : "B8 7B C0 A6 5E FF 7C 3E FF 52 27 FF FF",
              "2" : "C3 FC 02 C0 A6 5E FF FB 44 3E FF FF"
    },
    "40" : { "title": "Blacktooth", 
			  "0" : "C0 0E 34 4E 5C 6C 74 6C 5E 44 26 FF FF"
    },
    "41" : { "title": "Market", 
			  "0" : "D0 0E 6E 96 6E 56 FF 01 34 36 FF 0E 7C 6C 54 6E 47 FF FF"
    },
    "42" : { "title": "Egyptus", 
			  "0" : "C3 03 94 8C 94 8C FF 26 76 FF 61 6A 72 8A FF 22 8A FF 03 94 8C 74 8C 94 AC A4 94 FF 26 8F FF 22 80 FF FF"
    },
    "43" : { "title": "Penitentiary", 
			  "0" : "60 02 6C 96 04 96 8C 96 94 96 FF 0F 8C FF 01 AA FF 41 B2 FF 22 B4 FF 02 04 96 FF FF"
    },
    "44" : { "title": "Moon base", 
			  "0" : "A8 0F 35 35 55 6D 6E 04 55 56 04 35 36 FF FF"
    },
    "45" : { "title": "Book world", 
			  "0" : "90 0E 0C 36 24 35 45 4E 44 4D 35 26 34 25 0D FF 0E 27 FF FF"
    },
    "46" : { "title": "Safari", 
			  "0" : "40 02 36 0C 24 36 0C 24 34 4C 0C 4C 36 FF FF"
    },
    "47" : { "title": "Teleport waiting", 
			  "0" : "F0 67 10 F6 06 16 07 FF FF"
    },
    "48" : { "title": "Donut firing", 
			  "0" : "27 50 51 BB FF 5D 97 FF FF"
    },
    "00" : { "title": "????????",
			  "0" : "03 86 41 11 03 FF FF"
    },
    "01" : { "title": "????????", 
			  "0" : "00 86 82 12 FF FF"
    },
    "02" : { "title": "????????", 
			  "0" : "FF 00 F3 EB E3 DB FF FF"
    },
    "03" : { "title": "Didididip", 
			  "0" : "A0 40 30 6C 31 6C 41 6C FF FF"
    },
    "04" : { "title": "GlouGlouGlou", 
			  "0" : "03 CA 44 F0 0F FF 8C 01 0C FF FF"
    },
    "05" : { "title": "Beep", 
			  "0" : "B3 47 10 43 00 FF FF"
    },
    "80" : { "title": "Walking", 
			  "0" : "D3 29 31 51 01 41 29 01 31 19 01 29 41 01 FF 00"
    },
    "81" : { "title": "Running", 
			  "0" : "D3 09 31 51 00 41 29 00 31 19 00 29 41 00 FF 00"
    },
    "82" : { "title": "descending sequence - faster", 
			  "0" : "D3 09 F3 EB E3 DB EB E3 DB D3 E3 DB D3 CB DB D3 CB C3 FF 00"
    },
    "83" : { "title": "Fall", 
			  "0" : "D3 09 BB A3 8B 73 5B 43 2B 23 FF 00"
    },
    "84" : { "title": "Repeated rising sequence", 
			  "0" : "D3 09 13 33 53 73 93 B3 D3 DB E3 EE FF 00"
    },
    "85" : { "title": "higher blip", 
			  "0" : "78 05 33 FF FF"
    },
    "86" : { "title": "high blip", 
			  "0" : "60 25 33 FF FF"
    },
    "87" : { "title": "sweep down and up", 
			  "0" : "D3 60 34 6A FF 09 01 BA BA FF FF"
    },
    "88" : { "title": "Menu blip", 
			  "0" : "90 44 10 43 00 FF FF"
    }
}

 