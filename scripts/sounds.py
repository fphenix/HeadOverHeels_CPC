from sounds_in import *
from os.path import dirname, realpath, join

cwd = dirname(realpath(__file__))

#---------------------------------------------------------------------------------------------------
def fwrite(filew, tablevel, txt = "", eol = True):
    eolstr = "\n" if eol else ""
    tablevel = tablevel if eol else 0
    tab = ("\t" * tablevel)
    filew.write(tab + txt + eolstr)

#---------------------------------------------------------------------------------------------------
def byteSplit(dataByte, splitAtBitNb):
    high = int(dataByte >> splitAtBitNb)
    low = dataByte % (pow(2, splitAtBitNb))
    return (high, low)

#---------------------------------------------------------------------------------------------------
def Parse_Sound_Data(fw, soundData):
    noiseRead = False
    func = False
    doEnvp = False
    fwrite(fw, 1, "Data : " + soundData)
    for idx, dataByte in enumerate(soundData.split(None)):
        dataByte = int(dataByte, 16)
        if noiseRead:
            noiseRead = False
            ## TODO
            continue
        elif func:
            if dataByte == 0:
                fwrite(fw, 2, "Loop")
                break
            elif dataByte == 0xFF:
                fwrite(fw, 2, "Stop")
                break
            else:
                doEnvp = True
        
        if idx == 0: # first byte
            referenceNote, mainVolumeLevel = byteSplit(dataByte, 2) # first byte[7:2] = ref Note in octave 0 ; # first byte[1:0] = global volume Level
            octave = int(referenceNote/12) + 1
            referenceNote = referenceNote % 12
            fwrite(fw, 2, f"Ref note : {referenceNote} : " + Note_name[referenceNote] + f" octave {octave}")
            fwrite(fw, 2, f"Main Volume Level : {mainVolumeLevel}")

        elif idx == 1 or doEnvp: # 2nd byte
            doEnvp = False
            h, l = byteSplit(dataByte, 4) # [7:4] ; # [3:0]
            h32, h10 = byteSplit(h, 2) # [7:2] ; # [1:0]
            if h10 == 0:
                fwrite(fw, 2, "No ???")
            else:
                h10 -= 1
                x, y = byteSplit(int(array_10AD[h10], 16), 4) # [7:4] ; # [3:0]
                div = int(max(x, y) / min(x, y))
                if x < y:
                    div += 0x80 # sound object [#10]
                fwrite(fw, 2, "Div ([#10]) = " + hex(div))

            x, y = byteSplit(int(array_10BE[l], 16), 4) # [7:4] ; # [3:0]
            fwrite(fw, 2, "SND_NB_FX_SLICES = " + hex(x))
            fwrite(fw, 2, "SND_CURR_FX_SLICE = " + hex(x))
            fwrite(fw, 2, "Volume_Envp_data index (SND_VOL_PTR_H, SND_VOL_PTR_L) = " + hex(y))
            envp_data = Volume_Envp_data[y]
            fwrite(fw, 2, "Envp data = " + envp_data)
            if (h32 >> 1):
                fwrite(fw, 2, "only if Voice 0 : ", eol = False)
                fwrite(fw, 0, "Noise ! (TODO from addr #1002)")
                # must read next byte
                noiseRead = True
        else:
            if dataByte == 0xFF:
                func = True
            else:
                noteOffset, duration =  byteSplit(dataByte, 3)
                note = referenceNote + noteOffset
                noteoctave = octave + int(note / 12)
                note = note % 12
                fwrite(fw, 2, f"Note = {Note_name[note]}\toctave {noteoctave}\t; Duration = {Note_duration_array[duration]} ({duration_Name_array[duration]})")

                
#---------------------------------------------------------------------------------------------------
def Unpack_Voice_Data(fw, soundId):
    fwrite(fw, 0, "Sound Title : " + VoiceData[soundId]["title"] + f" (ID #{soundId})")
    for voice in range(3):
        if str(voice) in VoiceData[soundId].keys():
            fwrite(fw, 1, f"Voice #{voice}")
            Parse_Sound_Data(fw, VoiceData[soundId][str(voice)])

#---------------------------------------------------------------------------------------------------

with open(join(cwd, "sounds.out.txt"), 'w') as fw:
	for soundID in VoiceData.keys():
		Unpack_Voice_Data(fw, soundID)

raise SystemExit
