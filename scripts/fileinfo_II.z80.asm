;; -----------------------------------------------------------------------------------------------------------
;; Disassembly of "Head over Heels" - Amstrad CPC
;; -----------------------------------------------------------------------------------------------------------
;; Author : Fred Limouzin (fphenix@hotmail.com)
;;
;; Tool used: mostly WinApe and Notepad++! (and a tiny bit of ManageDsk.exe (in spite of the bugs!) to get
;; the files from the ".dsk" file.
;; Note: This file is currently not compilable! It's mainly a text document. It shows
;; the addresses, the machine-codes and the assembly.
;;
;; -----------------------------------------------------------------------------------------------------------
;; Note: A big thanks and credit must be given to Simon Frankau (https://github.com/simon-frankau/head-over-heels)
;; who did a similar work for the ZX-Spectrum version (from which the CPC version has been ported hence
;; which is very similar). I inserted in here most of his findings to mines.
;; -----------------------------------------------------------------------------------------------------------

						org		&0100										;; Origin and entry point after loading screen
						run		Entry										;; for WinApe Assembly

Stack:																		;; Stack goes down from there (ie first stack addr will be &00FF, &00FE, ...)
Entry:
	JP		Reentry										;; entry point ; start of file HEADOVER.II
.Reentry
	LD 		SP,Stack									;; Stack pointer &0100 (which means the first stack byte used will be 00FF, then 00FE etc..)
	CALL 	Init_setup									;; Initialization
	CALL 	Keyboard_scanning_ending					;; Reset PSG Keyboard scanning
	JR 		Main										;; Continue at Main (011C)

;; -----------------------------------------------------------------------------------------------------------
.SaveRestore_Block1:										;; Save/Restore block 1 (4 bytes)
.current_Room_ID:
	DEFW 	&0000						;; Current room ID ; (eg. Head's first room = &8A40)
.Do_Objects_Phase:
	DEFB 	&00             			;; top bit toggles every "Do_Objects" loop

;; -----------------------------------------------------------------------------------------------------------
;; CFSLRDUJ user inputs and directions (Carry,Fire,Swop,Left,Right,Down,Up,Jump)
.Last_User_Inputs:
	DEFB 	&EF
.SaveRestore_Block1_end

.Current_User_Inputs:
	DEFB 	&FF

;; -----------------------------------------------------------------------------------------------------------
;; Special feature key press : for the following 3 bytes:
;;      bit0 = 'recently pressed' (if set)
;; 		bit1 = 'currently being pressed' (if set)
;;		bit2 (Swop key) will store which of Head or Heels will be selected
;;          			next time we swop; this is to have the cycle:
;;						"Heels, Both, Head, Both" when we swop with Head on top of Heels.
.special_key_pressed:
.CarryObject_Pressed:										;; special_key_pressed index 0 : Carry/Purse
	DEFB 	&00
.SwopChara_Pressed:											;; special_key_pressed index 1 : Swop
	DEFB 	&00
.FireDonuts_Pressed:										;; special_key_pressed index 2 : Fire Donut
	DEFB 	&00

;; -----------------------------------------------------------------------------------------------------------
Frame_counter:
	DEFB 	&01							;; used as Character speed (or rather how much delay you add)
Saved_Dir_ptr:
	DEFB 	&FB 						;; copy of Heels LRDU character_direction
	DEFB 	&FB							;; copy of Head LRDU character_direction

;; -----------------------------------------------------------------------------------------------------------
;; Main : Entry point and main loop
.Game_over:																	;; when "game over" branch here and continue at 'Main'
	CALL 	Game_over_screen
.Main:
	LD		SP,Stack									;; Make sure the SP is reset
	CALL 	Main_Screen									;; Draw main menu screen
	JR 		NC,Main_continue_game						;; if carry=0 (saved game available) goto Main_continue_game
	CALL 	Init_new_game								;; else Init a new game!
	JR 		Main_game_start								;; Start the game

.Main_continue_game:														;; If an old game existed (saved point fish), can continue it
	CALL 	Play_HoH_Tune								;; Play main HoH Theme
	CALL 	Init_Continue_game							;; Continue a saved (Fish) game
.Main_game_start:															;; Play the game
	CALL 	Show_World_Crowns_screen					;; show the Crowns/Worlds page
	LD 		A,&40										;; Delay Setting for the First cannon ball in the Victory room
	LD 		(delay_CannonBall),A						;; Update delay_CannonBall to &40 (64)
.Enter_New_Room:															;; "Entering a room" game loop
	XOR 	A											;; phase = 0
	LD 		(Do_Objects_Phase),A						;; init Do_Objects_Phase
	CALL 	Do_Enter_Room								;; Enter a Room
.Main_loop:																	;; Game Main loop within a room
	CALL 	WaitFrame_Delay								;; Sync with VSYNC
	CALL 	Check_User_Input							;; Check user inputs
	CALL 	Victory_Room								;; Check if in Victory Room and if so, do the Victory anim
	CALL 	Do_Objects									;; Manage the objects in the link list (draw the room)
	CALL 	Check_Pause									;; Check if ESC pressed to Pause the game
	CALL 	Check_Swop									;; Check if Swop key pressed
play_a_sound:																;; play a sound (if one exists)
	LD 		HL,Sound_ID									;; pointer on Sound_ID
	LD 		A,(HL)										;; get Sound_ID
	SUB 	1											;; set carry flag if Sound_ID was = 0, else carry is 0
	LD 		(HL),&00									;; reset Sound_ID
	LD 		B,A											;; B = Sound_ID
	CALL 	NC,Play_Sound								;; if carry=0 (Sound_ID not 0) then Play the Sound
	JR 		Main_loop									;; Loop Main game loop

;; -----------------------------------------------------------------------------------------------------------
RoomID_Victory			EQU		&8D30					;; we also see room 8E3 when in 8D3 ; although we can never go in 8E3, it is counted as one of the 301 rooms since we display it when in Victory room.
RoomID_Head_1st			EQU		&8A40					;; This is Head's first room ID (8A4)
RoomID_Heels_1st		EQU		&8940					;; This is Heels' first room ID (894)

;; -----------------------------------------------------------------------------------------------------------
;; Sub function of Victory_Room
;; Set Zero flag if in Victory room, else Zero is reset (ie. "NZ" set):
.Sub_Check_Victory_Room:
	LD 		HL,(current_Room_ID)						;; get current_Room_ID
	LD 		BC,RoomID_Victory							;; &8D30 is the Victory room ID (U=8,V=D,Z=3)
	XOR 	A											;; A = 0
	SBC 	HL,BC										;; test the difference "room_ID - victory_room_ID"
	RET													;; If in victory room then Zero set (NZ=0) else (ie. NOT in victory room) Zero reset (NZ=1)

;; -----------------------------------------------------------------------------------------------------------
;; If we are in Victory room, play the victory music, fire canon balls
;; and flash the "Freedom" text...
;; If not in Victory room then leave with Zero flag reset.
;; Note: The room &8D3 (Victory room) also display the far room &8E3.
;; The victory room defines 6 Cannon Balls objects of type "&3C" in ObjDefns:
;;    sprite = SPR_BALL, function = OBJFN_CANNONBALL (ObjFnCannonFire)
;; As long as one of these exist, the function ObjFnCannonFire will reset
;; delay_CannonBall to &60, thus preventing going to Game_over (see addr &0179).
;; When all 6 Cannon Balls have been processed by Do_Objects, then the
;; delay_CannonBall will be able to go to 0 and thus let it jump to Game_over.
.Victory_Room:
	CALL 	Sub_Check_Victory_Room						;; get Zero flag : Z set = in Victory room, Zero reset = any other room
	RET 	NZ											;; if not in Victory Room then RET, else:
	LD 		(SwopChara_Pressed),A						;; else, in Victory Room, reset SwopChara_Pressed = No swopping allowed (Note: Accu A was set to 0 at addr &0164 in Sub_Check_Victory_Room)
	DEC 	A											;; A = FF
	LD 		(Current_User_Inputs),A						;; reset Current_User_Inputs (FF = No movement/No inputs) CFSLRDUJ
	LD 		HL,delay_CannonBall							;; point delay_CannonBall
	DEC 	(HL)										;; count down delay value before we trigger fire a cannon ball
	LD 		A,(HL)										;; get current delay_CannonBall value; Note that delay_CannonBall value is reset back to &60 when a CannonBall is fired (see ObjFnCannonFire); When no more cannon ball, the value can reach 0
	INC 	A											;; A = prev(HL) ; if delay_CannonBall was FF (FF+1=0) then Zero is set
	JP 		Z,Game_over									;; if Zero set, then delay_CannonBall was FF (-1) so goto Game_over (only possible when all 6 Cannon Balls in the objects link list have been processed), else:
victory_song:																;; else:
	LD 		B,Sound_ID_Tada								;; prepare Sound_Id &C1 = "Tada!" song
	CP 		&30											;; compare delay with &30 (if < &30 Carry flag set, if = &30 Zero flag set)
	PUSH 	AF											;; save delay in (HL)+1 (prev delay value)
	CALL 	Z,Play_Sound	 							;; Play Sound_ID is in B = &C1 "Tada!"
victory_message:
	POP 	AF											;; restore prev_(HL)
	AND		%00000001									;; test bit0 (parity) of prev_(HL), set Zero flag if == 0 (Even)
	LD 		A,Print_StringID_Freedom					;; String ID &C9 = DoubleSize+Pos(12,22)+Rainbow+"FREEDOM"
	CALL 	Z,Print_String								;; if value prev(HL) was Even (every second frame) then Print_String (since "FREEDOM" % 3 != 0, the colors will change every time! Hence the flashing effect)
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Moving to a new room: Update the current UVZ room location based on
;; the value in "access_new_room_code":
;;   0 = stay same room
;;   1=Down (U-1), 2=Right (V-1), 3=Up (U+1), 4=Left (V+1)			; TODO : Need to check the consistency of the U/V usage thoughout this document
;;   5->8 = Below (Z+1), 6->&0E = Above (Z-1)
;;   7 = teleport (brand new UVZ altogether)
.Go_to_room:
	LD 		HL,current_Room_ID + 1						;; point on current_Room_ID high byte : UV (&010F = &010E+1)
	LD 		A,(access_new_room_code)					;; get access_new_room_code
	DEC 	A											;; realign values on 0 (Code 1: value 0, Code2, value 1, etc)
	CP 		7 - 1										;; if access_new_room_code was:
	JR 		Z,Teleport_to_new_room						;; ... 7 then Teleport_to_new_room
	JR 		NC,Long_move_to_new_room					;; else if was > 7 (or 0) then Goto Long_move_to_new_room, else:
	CP 		5 - 1										;; if access_new_room_code was:
	JR 		c,move_to_nextdoor_room						;; ... 1 to 4, then (normal move) goto move_to_nextdoor_room, else (5:Below or 6:Above)
	ADD 	A,A											;; These 2 lines convert Code 5 (Below) into value &A ...
	XOR 	%00000010									;; ... and (flip bit1) Code 6 into value 8
	DEC 	HL											;; To handle Above/Below, point on current_Room_ID low byte (Z in &010E)
move_to_nextdoor_room:
	;; bit1=0 for 0 (Code1=Down), 1 (Code2=Right), 8 (Code6=Above)  		; C=-1 (new coord = coord - 1)
	;; bit1=1 for 2 (Code3=Up),   3 (Code4=Left), &A (Code5=Below)  		; C=+1 (new coord = coord + 1)
	LD 		C,1											;; prepare return value C=1
	BIT 	1,A											;; test bit 1
	JR 		NZ,got_increment							;; if bit1 = 1 then C=1, else
	LD 		C,-1										;; else C=-1
got_increment:																;; at this point we have + or - 1 in C, now mod the appropriate coordinate to do the expected move
	RRA													;; bit0 goes in Carry flag
	JR 		c,move_to_RL_room							;; if carry '1' then (Right/Left) move_to_RL_room, else:
move_to_UD_BA_room:															;; else Modify U or Z coords
	;; A = 0 (code1 or code2), 1 (Code3 or 4), 4 (Code6) or 5 (Code5)
	;; (HL) = room ID high byte (4b U and 4b V) if normal move
	;; (HL) = room ID low byte (4b Z and 4b d/c) if Above or Below
	RLD													;; RLD = nibbles circular left rotation in the 12b value composed by A[3:0] and (HL)
	;; Now A = U of room ID; (HL) = 4b V + 4b if normal move
	;; Or  A = Z of room ID; (HL) = 4b dont care + 4b if Above or Below
	ADD 	A,C											;; coord in A +/- 1
	RRD													;; put back new room ID value in current_Room_ID ; RRD = nibbles circular right rotation in the 12b value composed by A[3:0] and (HL)
	JR 		Long_move_to_new_room						;; go new room

move_to_RL_room:															;; Modify V coord
	RRD													;; get V in A ; RRD = nibbles circular right rotation in the 12b value composed by A[3:0] and (HL)
	ADD 	A,C											;; +/- 1
	RLD													;; put back new room ID value in current_Room_ID ; RLD = nibbles circular left rotation in the 12b value composed by A[3:0] and (HL)
.Long_move_to_new_room:
	LD 		SP,Stack									;; reset Stack pointer
	JP 		Enter_New_Room								;; go to new room

;; -----------------------------------------------------------------------------------------------------------
;; This will look which room ID is on the other side of a Teleporter
;; and go to it by updating the current_Room_ID and Enter_New_Room
.Teleport_to_new_room:
	CALL 	Teleport_swap_room							;; find room at the other end of the teleport
	JR 		Long_move_to_new_room						;; "Energy!"

;; -----------------------------------------------------------------------------------------------------------
;; Controls the frame rate (FPS) by syncing with a number of VSYNC.
;; Frame_counter is updated in the Interrupt Handler and it
;; waits that it goes to 0 and sets it back to 4.
.WaitFrame_Delay:
	LD 		A,(Frame_counter)							;; Frame_counter
	AND 	A											;; test if 0
	JR 		NZ,WaitFrame_Delay							;; jump WaitFrame_Delay if not 0 (Wait; note: this value is modified in the Interrupt_Handler)
	LD 		A,4											;; else (finished waiting) update Frame_counter to 4
	LD 		(Frame_counter),A							;; Frame_counter (controls the FPS)
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Check if 'ESC' has been pressed for pause and, if so, pause the game.
;; Then wait any key and resume game.
.Check_Pause:
	CALL 	Keyboard_scanning_ESC						;; test ESC key pressed (Zero set if so)
	RET 	NZ											;; if not then RET, else:
	LD 		B,Sound_ID_Silence							;; else Sound id &C0 = Silence (pause)
	CALL 	Play_Sound									;; Quiet all voices
	CALL 	Wait_anykey_released						;; key debounce
	LD 		A,Print_StringID_Paused						;; String ID &AC = Paused Game message
	CALL 	Print_String	 							;; Display overlay pause message
pause_loop:
	CALL 	Test_Enter_Shift_keys						;; output : Carry set : no key pressed, else Carry reset and register C=0:Enter, C=1:Shift, C=2:other
	JR 		c,pause_loop								;; if no key then Wait (loop pause_loop), else (a key was pressed)
	DEC 	C											;; now register C=-1:Enter, C=0:Shift, C=1:other
	JP 		Z,Game_over									;; if Z set (Shift key = Finish) then goto Game_over, else:
leave_pause:
	CALL 	Wait_anykey_released						;; key debounce
	CALL 	Update_Screen_Periph						;; Update color scheme and periphery (the room was build in black, so apply real colors now)
	;; Redraw only the part over the pause message
	LD 		HL,&4C50									;; X extent &4C=76; &50=80 ; H contains start, L end, in double-pixels
pause_message_draw_over_loop:
	PUSH 	HL
	LD 		DE,&6088									;; Y extent &60=96; &88=136
	CALL 	Draw_View
	POP 	HL											;; restore X extent
	LD 		A,L
	LD 		H,A
	ADD 	A,20										;; move next block (+&14)
	LD 		L,A											;; H=L, L=L+20
	CP 		181											;; if L < &B5 (181) then loop (else we are off screen)
	JR 		c,pause_message_draw_over_loop				;; pause_message_draw_over_loop, else RET
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Depending on the Sensitivity settings (Sensitivity Menu) self-modifying
;; the code to use either the Routine_High_sensitivity or the
;; Routine_Low_sensitivity. This only has an impact when pressing two keys
;; to move diagonally.
.Sub_Update_Sensitivity:													;; A = sensitivity ; (self-modifying code at &0232):
	LD 		HL,Routine_High_sensitivity					;; HL = addr of Routine_High_sensitivity
	AND 	A											;; Update Z with selected sensitivity menu item (0 = High, 1 = Low)
	JR 		Z,us_skip									;; if High sensitivity goto 020E to use the addr of Routine_High_sensitivity
	LD 		HL,Routine_Low_sensitivity					;; else take addr value of Routine_Low_sensitivity
us_skip:
	LD 		(smc_sens_routine+1),HL						;; if High sensisivity, put addr of Routine_High_sensitivity in &0232, else if Low, put &0249 (addr of Routine_Low_sensitivity)
	RET

;; -----------------------------------------------------------------------------------------------------------
;; This will scan the keyboard and get the user inputs
;; The value A from Get_user_inputs is:
;;		bit7:Carry, Fire, Swop, Left, Right, Down, Up, bit0: Jump (active low)
.Check_User_Input:
	CALL 	Get_user_inputs								;; get user inputs in A (CFSLRDUJ)
	BIT 	7,A											;; was key corresponding to CarryObject feature pressed?
	LD 		HL,special_key_pressed						;; points on CarryObject_Pressed (index 0)
	CALL 	Update_key_pro_curr_idx						;; update CarryObject_Pressed from the key pressed in A
	BIT 	5,A											;; or was it the Swop key?
	CALL 	Update_key_pro_next_idx						;; if needed update SwopChara_Pressed (index 1)
	BIT 	6,A											;; or was if the FireDonuts key?
	CALL 	Update_key_pro_next_idx						;; if needed update FireDonuts_Pressed (index 2)
	LD 		C,A											;; in C bits are in order : CFSLRDUJ (Carry,Fire,Swop,Left,Right,Down,Up,Jump)
	RRA													;; in A put the "Left,Right,Down,Up" bitmap in bits [3:0]
	CALL 	DirCode_from_LRDU							;; get the resulting direction code 0 to 7 (or FF) from the LRDU (Left/Right/Down/Up) user input
	CP 		&FF											;; check vs "no move"
	JR 		Z,No_Key_pressed							;; if nothing pressed (C=FF) goto No_Key_pressed; will RET
	RRA													;; get in Carry the lsb of the direction code that will indicate if we go in diagonal (if 1)
smc_sens_routine:
	JP 		c,Routine_Low_sensitivity					;; If going in diagonal : do the Routine_High_sensitivity or Routine_Low_sensitivity ; will RET
	;;0232 DEFW 49 02														; by default : Routine_Low_sensitivity	(0249)
	LD 		A,C											;; (else one direction only): save key state : Carry,Fire,Swop,Left,Right,Down,Up,Jump
	LD 		(Last_User_Inputs),A						;; update Last_User_Inputs (CFSLRDUJ)
	LD 		(Current_User_Inputs),A						;; update Current_User_Inputs CFSLRDUJ
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Runs if HIGH Sensitivity is choosen in the menu (value set in smc_sens_routine)
;; If moving diagonaly, set the a direction each time (the other one in the pair creating the diag)
;; Input: C has the "Carry,Fire,Swop,Left,Right,Down,Up,Jump" state (active low)
.Routine_High_sensitivity:
	LD 		A,(Last_User_Inputs)						;; get Last_User_Inputs CFSLRDUJ code
	XOR 	C											;; compare last and current user input
	CPL													;; invert all bits of A
	XOR 	C
	AND 	&FE											;; Force reset the Jump
	XOR 	C											;; change value taken into account
	LD 		(Current_User_Inputs),A						;; update CFSLRDUJ Current_User_Inputs
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Runs if LOW Sensitivity is choosen in the menu (value set in smc_sens_routine)
;; if moving diagonaly, keep the old direction (the same one in the pair creating the diag)
;; Input: C has the "Carry,Fire,Swop,Left,Right,Down,Up,Jump" state (active low)
.Routine_Low_sensitivity:
	LD 		A,(Last_User_Inputs)						;; get Last_User_Inputs CFSLRDUJ
	XOR 	C
	AND 	&FE											;; force reset Jump
	XOR 	C
	LD 		B,A
	OR 		C
	CP 		B
	JR 		Z,rls_1										;; if last = curr, skip
	LD 		A,B											;; else keep last value
	XOR 	&FE
rls_1:
	LD 		(Current_User_Inputs),A						;; update CFSLRDUJ Current_User_Inputs
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Nothing pressed, update Current_User_Inputs with current CFSLRDUJ (active low)
;; Input: C has the "Carry,Fire,Swop,Left,Right,Down,Up,Jump" state
.No_Key_pressed:
	LD 		A,C											;; dir code was "FF", get the CFSLRDUJ direction from C
	LD 		(Current_User_Inputs),A						;; and refresh Current_User_Inputs CFSLRDUJ
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Provide 2 functions to update the variables in special_key_pressed array:
;; CarryObject_Pressed (index 0),  SwopChara_Pressed (index 1),
;; and FireDonuts_Pressed (index 2)
;;   * Update_key_pro_next_idx will first increment the index in HL (next special_key_pressed item)
;;   * Update_key_pro_curr_idx will use the current index in HL (curr index special_key_pressed)
;; Input : Z set = key pressed; Z reset = no key pressed
;; 		bit0 : a 1 means "key recently pressed" (not yet processed)
;; 		bit1 : a 1 means "key currently pressed"
;; 		bit2 used in Swop to cycle through the characters
;; Output : special_key_pressed array updated as needed.
;;          NZ: no or no new key pressed; Z: new key pressed
.Update_key_pro_next_idx:
	INC 	HL											;; next special_key_pressed index
.Update_key_pro_curr_idx:
	RES 	0,(HL)										;; reset current special_key_pressed index bit0 in (HL)
	JR 		Z,reg_key_feature_1							;; if key pressed (Zero set) then jump to reg_key_feature_1, else:
	RES 	1,(HL)										;; else reset (HL) bit1
	RET													;; no key pressed, both bits 1 and 0 are reset

reg_key_feature_1:
	BIT 	1,(HL)										;; test bit1:
	RET 	NZ											;; already registered so Return (bit0 was reset)
	SET 	1,(HL)										;; else set ...
	SET 	0,(HL)										;; ... both bits (new key pressed, not yet processed)
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Play the &C4 "Nope" sound used when we cannot do an action
.Play_Sound_NoCanDo:
	LD 		B,Sound_ID_Nope								;; Sound ID &C4 : "Nope!" (can't swop, can't fire, can't pickup, can't drop)
	JP 		Play_Sound									;; will RET

;; -----------------------------------------------------------------------------------------------------------
;; Provides 2 functions: (Note that in this game it is the verb "to swOp" (instead of "to swAp") that is used!)
;;   - Check_Swop : Check if we can swop, and if it is possible, swop!
;;   - Switch_Character : swop (no checks)
;; If the swop key pressed and not yet processed, try to swap.
;; Note: You cannot swop if:
;;     * the Dying anim is playing
;;     * the teleport anim is running
;;     * under a doorway
;;     * the other character has no more lives and we can't share lives with it
.Check_Swop:																;; Swop pressed? if so, try to swop
	LD 		A,(SwopChara_Pressed)						;; get SwopChara_Pressed
	RRA													;; shift swop key state (bit0) in Carry
	RET 	NC											;; leave if not being pressed, else:
	LD 		A,(Saved_Objects_List_index)				;; else get Saved_Objects_List_index; can't swap if under a doorway
	LD 		HL,DyingAnimFrameIndex						;; point on DyingAnimFrameIndex
	OR 		(HL)										;; can't swap if in the process of dying!
	LD 		HL,(Teleport_up_anim_length)				;; get Teleport_up_anim_length
	OR 		H
	OR 		L											;; can't swap if teleporting
	JR 		NZ,Play_Sound_NoCanDo						;; if not 0 (teleporting) then Play_Sound_NoCanDo and will RET, else:
	LD 		HL,(Characters_lives)						;; else get Characters_lives
	CP 		H											;; character 1 has no lives: can't swop
	JR 		Z,Play_Sound_NoCanDo						;; if Z Play_Sound_NoCanDo ; will RET
	CP 		L											;; character 2 has no lives: can't swop
	JR 		Z,Play_Sound_NoCanDo						;; if Z Play_Sound_NoCanDo ; will RET
.Switch_Character:															;; else can swop!
	CALL 	Get_Saved_direction_pointer					;; get Heels select state in Carry, pointer on Saved_Dir_ptr in HL, E = selected_characters and A is "selected_characters >> 1"
	LD 		BC,(character_direction)					;; get LRDU character_direction in C
	JR 		NC,swc_1									;; if Heels is NOT currently used so jump swc_1
	LD 		(HL),C										;; else Heels selected; save character_direction in Saved_Dir_ptr (Heels)
swc_1:
	INC 	HL											;; now points on Saved_Dir_ptr+1 (Head)
	RRA													;; get Head selection state in Carry
	JR 		NC,swc_2									;; if Head is NOT currently selected jump swc_2
	LD 		(HL),C										;; else Head selected; save character_direction in Saved_Dir_ptr+1 (Head)
swc_2:
	LD 		HL,SwopChara_Pressed						;; point on SwopChara_Pressed
	LD 		IY,Heels_variables							;; IY points on Heels variables
	LD 		A,E											;; get back selected_characters from E
	CP 		%00000011									;; Check if both are selected?
	JR 		Z,Swop_Head_or_Heels						;; Zero flag set = yes then Swop_Head_or_Heels, else:
	LD 		A,(both_in_same_room)						;; get both_in_same_room value
	AND 	A											;; test if both in same room
	JR 		Z,Swop_Head_or_Heels						;; Zero flag set = not in same room -> Swop_Head_or_Heels; will RET
	;; at this point Head and Heels are in the same room, and currently
	;; only one of them is selected, so test if Head is on the top of
	;; Heels and aligned and, if so, merge both characters.
	;; Else simply switch to the other character.
try_merge:																	;; else (same room)
	LD 		A,(IY+O_U)									;; get Heels U coordinate
	INC 	A											;; +1 (so deltaU -1,0,1 will become 0,1,2)
	SUB 	(IY+Head_offset+O_U)						;; sub Head's U coordinate (&17=&12+&05, the +&12 is to point on Heads_variables)
	CP 		3											;; diffU >= 3, too far, just switch
	JR 		NC,Swop_Head_or_Heels						;; if not close in U, then Swop_Head_or_Heels; will RET
	LD 		C,A											;; save Heels U+1 in C (deltaU 0,1,2 means original deltaU was within +/-1)
	LD 		A,(IY+O_V)									;; get Heels V coordinate
	INC 	A											;; +1 (so deltaV -1,0,1 will become 0,1,2)
	SUB 	(IY+Head_offset+O_V)						;; get Head V coordinate (&18=&12+&06, the +&12 is to point on Heads_variables)
	CP 		3											;; diffV >= 3, too far, just switch
	JR 		NC,Swop_Head_or_Heels						;; if apart V wise then Swop_Head_or_Heels; will RET
	LD 		B,A											;; save Heels V+1 in B (deltaV 0,1,2 means original deltaU was within +/-1)
	LD 		A,(IY+O_Z)									;; get Heels Z coordinate
	SUB 	6											;; substract one "character height"
	CP 		(IY+Head_offset+O_Z)						;; get Head Z coordinate (&19=&12+&07, the +&12 is to point on Heads_variables)
	JR 		NZ,Swop_Head_or_Heels						;; if Head not exactly on Heels then Swop_Head_or_Heels; will RET
merge_head_on_heels:														;; if all tests passed (Head is on Heels in +/-1 in U and V), then align if needed and merge
	LD 		E,&FF										;; E=-1
	RR 		B											;; Heels V+1 bit0 in Carry
	JR 		c,swop_3									;; if Carry = 1, V already aligned (B=1 means original deltaV of 0), jump swop_3, else:
	RR 		B											;; Heels V+1 bit1 in Carry (if reset then original deltaV was -1, if set then original deltaV was +1)
	CCF													;; invert Carry, now carry flag = 1 if B=0 and carry = 0 if B=2
	CALL 	Sub_Get_displacement						;; Update displacement in E
swop_3:
	RR 		C											;; Heels U+1 bit0 in Carry
	JR 		c,swop_4									;; if Carry = 1, U already aligned (C=1), else:
	RR 		C											;; Heels U+1 bit1 in Carry (0: C=0, 1: C=2)
	CALL 	Sub_Get_displacement						;; Update displacement in E
	JR 		swop_5										;; jump swop_5
swop_4:																		;; else
	RLC 	E											;; aligned in U, so put no movement into the next two bits of E.
	RLC 	E
swop_5:
	LD 		A,&03										;; both characters selected!
	INC 	E											;; test if E was FF
	JR 		Z,do_swop									;; if 0 (was FF = U and V aligned), do_swop immediately, else:
not_aligned:
	DEC 	E											;; get value of E back (displacement to apply to Head, see Sub_Get_displacement comment)
	;; If not aligned, put the movement into Head's movement flag,
    ;; and clear the flag that says we've seen the swap button be pressed
	LD 		(IY+Head_offset+&0C),E						;; &1E=&12+&0C (the +&12 is to point on Heads_variables); displacement to apply to Head so he is perfectly aligned with Heels
	RES 	1,(HL)										;; unselect swop key
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Switch Head or Heels
;; HL = pointer on SwopChara_Pressed
;; Note that bit2 stores which of Head or Heels will be selected next time
;; we swop; (cycle "Heels, Both, Head, Both").
.Swop_Head_or_Heels:
	LD 		A,%00000100									;; bit2 set so a Xor will invert the bit
	XOR 	(HL)										;; flip bit2 of SwopChara_Pressed (indicating next char to swop to)
	LD 		(HL),A										;; save new value
	AND 	%00000100									;; get NEW value of bit2 (inverted vs old)
	LD 		A,%00000010									;; prepare Head
	JR 		Z,do_swop									;; if new bit2 is 0 (old was 1), will use 2b10 (Head)
	DEC 	A											;; else (bit2 is 1 (old was 0) will use 2b01 (Heels)
.do_swop:
	LD 		(selected_characters),A						;; update selected_characters
	CALL 	Sub_Set_Character_Flags
	CALL 	Get_Saved_direction_pointer					;; HL = Saved_Dir_ptr; Carry set if using Heels, reset for Head
	JR 		c,swop_8									;; if Heels, skip
	INC 	HL											;; else (we are Head) HL point on Saved_Dir_ptr+1
swop_8:
	LD 		A,(HL)										;; get saved facing direction for current character
	LD 		(character_direction),A						;; update LRDU character_direction
	;; If both characters are on the same screen, we just redraw the
    ;; screen periphery (HUD). If they're not, we do restore all the state.
	LD 		A,(both_in_same_room)						;; get both_in_same_room
	AND 	A											;; test
	JP 		NZ,Draw_Screen_Periphery					;; in same room, only draw periphery; will RET
	JR 		Restore_Character_flags						;; else Restore_Character_flags; will RET

;; -----------------------------------------------------------------------------------------------------------
;; This is used to align Head and Heels when trying to merge them.                Up
;; Since it it Head that will be displaced, Carry set will produce a +1        F6 FE FA                     (-1,+1) (0,+1) (+1,+1)
;; displacement; Carry reset will produce a -1.                           Left F7 FF FB Right =>  V,U disp  (-1, 0) (0, 0) (+1, 0)
;; Once both U and V are done (Sub_Get_displacement called twice),       	   F5 FD F9                     (-1,-1) (0,-1) (+1,-1)
;; E will be updated with a displacement: E may have the following values:       Down
.Sub_Get_displacement:
	PUSH 	AF											;; Save Carry state
	RL 		E											;; E shifted left; Place Carry in bit0 (will be at bit1)
	POP 	AF											;; Recover Carry state
	CCF													;; Invert it (so we have either 2b'10 (+1) or 2b'b01 (-1)
	RL 		E											;; E shifted left; Place Invert-Carry in bit0
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Set the current character flags. This provides 2 functions:
;; * Set_Character_Flags
;; * Sub_Set_Character_Flags, expects IY on Heels variables,
;; 			and expects selected_characters in A
.Set_Character_Flags:
	LD 		IY,Heels_variables							;; init IY pointer on Heels variables
	LD 		A,(selected_characters)						;; get selected_characters
.Sub_Set_Character_Flags:													;; At this point IY must be a pointer on Heels variables and A = selected_characters
	LD 		(IY+O_FUNC),0								;; Clear Heels O_FUNC (0A)
	RES 	3,(IY+O_FLAGS)								;; Clear the 'tall' flag on Heels; OFLAGS (04)
	BIT 	0,A											;; test if Heels (bit0) active
	JR 		NZ,sscf_skip								;; if Heels selected, sscf_skip
	LD 		(IY+O_FUNC),1								;; else set Heels O_FUNC to 1
sscf_skip:
	LD 		(IY+Head_offset+O_FUNC),0					;; reset Head's O_FUNC; &1C=&12+O_FUNC;
	RES 	3,(IY+Head_offset+O_FLAGS)					;; Clear the 'tall' flag on Head; O_FLAGS (04) ; &16 = Heads_variable+04 O_FLAGS
	BIT 	1,A											;; test if Head active
	JR 		NZ,sscf_sk2									;; if Head selected, sscf_sk2
	LD 		(IY+Head_offset+O_FUNC),1					;; else set Head O_FUNC to 1 ; &1C = Heads_variable+O_FUNC (&12+&0A)
sscf_sk2
	RES 	1,(IY+Head_offset+O_SPRFLAGS) 				;; Clear double-height flag on Head ; &1B=&12+&09 ; sprite flags
	CP 		%00000011									;; both selected?
	RET 	NZ											;; no, then RET, else both selected:
	SET 	3,(IY+O_FLAGS)								;; Set the 'tall' flag on Heels ; O_FLAGS (04)
	SET 	1,(IY+Head_offset+O_SPRFLAGS)				;; and the double-height flag on Head. &1B = Heads_variable+09 ; sprite flags
	RET

;; -----------------------------------------------------------------------------------------------------------
;; This compares the current Character's room to the other Charaters's room.
;; Output: Zery flag set if they are in the same room
.Do_We_Share_Room:
	LD 		HL,(current_Room_ID)						;; get current_Room_ID
	LD 		DE,(Other_Character_state + MOVE_OFFSET)	;; get other char room; at this point, the first word is room ID
	AND 	A											;; reset flags, especially the Carry
	SBC 	HL,DE										;; compare room ID (by calculationg the difference)
	RET													;; Zero flag set if in same room (diff = 0)

;; -----------------------------------------------------------------------------------------------------------
;; Get the pointer on Saved_Dir_ptr in HL and selected_characters in E.
;; Output: E = selected_characters; and A = E >> 1
;;		Carry set = Heels selected, Carry reset = Heels not selected
;;		HL pointer on the saved facing direction for the characters
;;        (ie. pointer on Saved_Dir_ptr)
.Get_Saved_direction_pointer:
	LD 		A,(selected_characters)						;; get selected_character
	LD 		HL,Saved_Dir_ptr							;; point on Saved_Dir_ptr where we store the facing direction of the characters
	LD 		E,A											;; save A in E
	RRA													;; Carry is set if Hells selected, reset if not Heels
	RET

;; -----------------------------------------------------------------------------------------------------------
;; The following provides functions to Save and Restore the state of the characters:
;; * Save_array (everything is saved as one block in Other_Character_state) (used after Dying and as Init):
;;      Save current character room, phase and direction (4 bytes)
;;		Save ObjListIdx (&1D bytes)
;;		Save ????TODO??? (&19 bytes)
;;		Save Objects (&3F0 bytes)
;;		Save Other character variables (&12 bytes)
;; * Restore_array (restored from Other_Character_state block) (used when entering a room):
;;		Restore everything listed in Save_array above at their original location
;;		Clear_character_objects
;; * Restore_Character_flags (used when swopping but not in the same room)
;;		Swap everything listed in Save_array with what is in Other_Character_state
;;		Restore current character obj pointer from Other_Character_state (&12)
;;		Save other character variables into Other_Character_state
;;		Clear_character_objects
;;		FinishRestore
.Save_array:
	XOR 	A											;; A=0 "Save Mode"; Carry = 0
	JR 		copy_Character_array

.Restore_array:
	LD 		A,&FF										;; A=-1 "Restore Mode"
	LD 		HL,Clear_character_objects					;; HL = addr Clear_character_objects
	PUSH 	HL											;; push the addr of the Clear_character_objects function on the Stack so that at next RET, the PC will jump to it
.copy_Character_array:
	LD 		HL,Ldir_copy								;; pointer on Ldir_copy
	LD 		DE,Sub_Copy_Character_data					;; pointer on Sub_Copy_Character_data
	JR 		copy_array

.Restore_Character_flags:													;; when swopping but not in the same room
	XOR 	A
	LD 		HL,FinishRestore							;; Set the function addr to call after.
	PUSH 	HL											;; push on Stack (for RET; so PC will jump to the function addr il HL)
	LD 		HL,Swap_DE_and_HL_cont_xBC					;; points on Swap_DE_and_HL_cont_xBC function
	LD 		DE,Sub_Copy_characters_arrays				;; points on Sub_Copy_characters_arrays function
	;; it'll now flow into copy_array
.copy_array:
	PUSH 	DE											;; DE on Stack (for next RET (ie. PC will jump to it))
	LD 		(smc_copy_func+1),HL						;; HL=&0428 (Ldir_copy = copy (HL) to (DE)) ou &041E (Swap_DE_and_HL_cont_xBC) self mod code.
	CALL 	Get_other_character_var_HL					;; HL = pointer on NOT selected character's variables
	LD 		(arg_copy_character_variables),HL			;; self modifying code : Heels_variables or Head_variables
	AND 	A											;; test A
	LD 		HL,Other_Character_state + MOVE_OFFSET
	JR 		NZ,copy_array_direction						;; if A=0 then exchange DE and HL, if A=-1 keep values in DE and HL
	EX 		DE,HL										;; if A=0 ("Save Mode") : DE<-->HL
copy_array_direction:
	EX 		AF,AF'										;; Save or Restore "4 + &1D + &19 + &3F0" bytes to or from Other_Character_state
	CALL 	Copy_Data
	DEFW 	&0004										;; Argument 1: length &0004
	DEFW 	SaveRestore_Block1							;; Argument 2: current_Room_ID, Do_Objects_Phase, Last_User_Inputs
	CALL 	Copy_Data
	DEFW 	&001D										;; Argument 1: length &001D
	DEFW 	SaveRestore_Block2							;; Argument 2: ObjListIdx (39A2)
	CALL 	Copy_Data
	DEFW 	&0019										;; Argument 1: length &0019 (25 bytes)
	DEFW 	SaveRestore_Block3							;; Argument 2: ???? (2492), EntryPosn, Corrying, ??? (2496), FireObject
	CALL 	Copy_Data
	DEFW 	&03F0										;; Argument 1: length ObjectsLen (&03F0 = 56 x 18 bytes = 1008)
	DEFW 	SaveRestore_Block4							;; Argument 2: Objects (6A40)
	RET

;; -----------------------------------------------------------------------------------------------------------
;; This is the length of an object instance (as in OOP/Class "object")
;; Head, Heels, a FireObject and any other item in the room (using the TmpObj)
;; use the same data collection format, 18 bytes long.
OBJECT_LENGTH			EQU		&0012

;; -----------------------------------------------------------------------------------------------------------
;; Runs Copy_Data on a character object (either Head or Heels object).
.Sub_Copy_Character_data:
	CALL 	Copy_Data									;; call Copy_Data
arg_copy_character_size:
	DEFW 	OBJECT_LENGTH								;; Argument 1: length of the array &12 (18) bytes
arg_copy_character_variables:
	DEFW 	Heels_variables								;; Argument 2: self modifying code, word at &03C3 is updated at addr &0396, can be &24B0 (Heels_variables) or &24C2 (Head_variables)
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Copy the source into the currently selected variables array;
;; Then copy the Other character's vars into the initial source.
;; Finally it erases the ObjectLists array.
;; Input: DE = pointer on initial source of data (&12 bytes variables array)
.Sub_Copy_characters_arrays:
	PUSH 	DE
	CALL 	Get_curr_Char_variables						;; HL = pointer on current selected character's variables
	EX 		DE,HL										;; swap DE (now dest variables array) and HL (now source)
	LD 		BC,OBJECT_LENGTH							;; length of the array &12 = 18 bytes
	PUSH 	BC
	LDIR												;; Copy: repeat LD (DE),(HL); DE++, HL++, BC-- until BC=0
	CALL 	Get_other_character_var_HL					;; HL = pointer on NOT selected character's variables
	POP 	BC											;; BC = &12
	POP 	DE											;; DE = what was source
	LDIR												;; Copy: repeat LD (DE),(HL); DE++, HL++, BC-- until BC=0
Clear_character_objects:
	LD 		HL,(Saved_Object_Destination)				;; get Saved_Object_Destination
	LD 		(Object_Destination),HL						;; update Object_Destination
	LD 		HL,ObjectLists + 4							;; erase from &39AD (ObjectLists + 1*4)
	LD 		BC,&0008									;; for 8 bytes
	JP 		Erase_forward_Block_RAM						;; Continue on Erase_forward_Block_RAM (will have a RET)

;; -----------------------------------------------------------------------------------------------------------
;; Returns a HL pointer on the Character's variable that is **NOT**
;; currently selected
.Get_other_character_var_HL:
	LD 		HL,selected_characters						;; points on selected_characters
	BIT 	0,(HL)										;; test Heels
	LD 		HL,Heels_variables							;; HL point on Heels' variables
	RET 	Z											;; if current NOT Heels, then return its var pointer
	LD 		HL,Head_variables							;; else it is Heels, so return a pointer on Head's variables
	RET

;; -----------------------------------------------------------------------------------------------------------
;; This will get the 2 arguments below the call, and copy or Swap the
;; concerned blocks of data
.Copy_Data:
	POP 	IX											;; All this gets the first DEFW argument: (IX is the addr of Arg1)
	LD 		C,(IX+0)									;; ... In the code, Arg1 is placed after the "CALL Copy_Data".
	INC 	IX											;; ... Now, the supposed returned PC addr (addr just after the CALL)...
	LD 		B,(IX+0)									;; ... was put on the Stack by the "CALL", but here it is in fact Argument 1, not instructions to RET to)...
	INC 	IX											;; ... The value we get from it is the length to copy, put in BC.
	EX 		AF,AF'										;; restore mode (A = 0: "Save"; A=-1 : "Restore")
	AND 	A											;; test if copy_mode = 0
	JR 		Z,copy_Data_1								;; if 0 "Save Mode" jump Copy_Data_1, else:
	LD 		E,(IX+0)									;; if copy_mode != 0 ("Restore") then
	INC 	IX
	LD 		D,(IX+0)									;; get the second argument in DE
	JR 		copy_Data_end								;; and continue at copy_Data_end
copy_Data_1:
	LD 		L,(IX+0)									;; but if copy_mode == 0 ("Save"):
	INC 	IX											;; gets the second argument in HL
	LD		H,(IX+0)
copy_Data_end:
	INC		IX											;; IX = pointers after Arg2, which is the real return address (PC after next RET addr)
	EX 		AF,AF'
	PUSH 	IX											;; prepare return PC addr on stack (that the addr after Argument 2 DEFW).
	;; Continue to the currently-selected copy function, which may
	;; be either LDIR, or Swap_DE_and_HL_cont_xBC
smc_copy_func:
	JP 		Ldir_copy									;; self modifying code the addr at &041C changes in line &0390 ; default = &0428 (Ldir_copy)
	;;041C DEFW 28 04														; &0428 (Ldir_copy) by default; but could also be Swap_DE_and_HL_cont_xBC

;; -----------------------------------------------------------------------------------------------------------
;; Exchange (DE) and (HL); BC--; DE++; HL++ until BC = 0
;; Need HL and DE pointing on the arrays we want to swap; BC = the length.
.Swap_DE_and_HL_cont_xBC:
	LD 		A,(DE)										;; temp = (DE)
	LDI													;; do once : LD (DE),(HL); DE++, HL++, BC--
	DEC 	HL											;; note "DEC ss" (ss being a double reg) does NOT impact flags in F "register"
	LD 		(HL),A										;; (HL) = temp
	INC 	HL											;; note "INC ss" (ss being a double reg) does NOT impact flags in F "register"
	JP 		PE,Swap_DE_and_HL_cont_xBC					;; loop until BC reaches 0 (the OVerflow flag bit comes from LDI, because the DEC ss, LD and INC ss did not change the flags)
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Just a LDIR copy! (DE) <- (HL)
;; HL: begining of source array, DE: start of destination array; BC = length
.Ldir_copy:
	LDIR												;; Copy: repeat LD (DE),(HL); DE++, HL++, BC-- until BC=0
	RET

;; -----------------------------------------------------------------------------------------------------------
;; In sync with the Do_Objects_Phase, process the next object in the
;; linked list (CallObjFn : call object function) and point on next Object.
;; The phase mechanism allows an object to not get processed for one frame.
.Do_Objects:
	LD 		A,(Do_Objects_Phase)						;; get Do_Objects_Phase
	XOR 	%10000000									;; toggle b7
	LD 		(Do_Objects_Phase),A						;; update Do_Objects_Phase
	CALL 	Characters_Update
	LD 		HL,(ObjectLists+2)							;; get object pointer
	JR 		Sub_Do_Objects_entry

doob_loop:
	PUSH 	HL											;; save current object pointer
	LD 		A,(HL)
	INC 	HL
	LD 		H,(HL)
	LD 		L,A											;; get next object pointer in HL from (ObjectLists+2)
	EX 		(SP),HL										;; exchange object pointers (curr and next (next is now on the stack))
	EX 		DE,HL										;; put current pointer in DE
	LD 		HL,O_FUNC									;; O_FUNC = offset &0A in TmpObj_variables
	ADD 	HL,DE										;; HL = current + 10 (byte that has the phase in bit7)
	LD 		A,(Do_Objects_Phase)						;; get Do_Objects_Phase
	XOR 	(HL)										;; test bit7
	CP 		%10000000
	JR 		c,doob_skip									;; Skip if top bit doesn't match Phase
	LD 		A,(HL)										;; else...
	XOR 	%10000000
	LD 		(HL),A										;; ...flip top bit - will now mismatch Phase
	AND 	%01111111									;; test other bits = Object Function ID
	CALL 	NZ,CallObjFn 								;; if any other bits set, CallObjFn; DE is the current object pointer
doob_skip:
	POP 	HL											;; get next pointer from stack
Sub_Do_Objects_entry:
	LD 		A,H
	OR 		L											;; test if HL = 0
	JR 		NZ,doob_loop								;; loop until null pointer.
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Get door type from room data door value.
;; On CPC we have 3 types of doors (Note: on ZX-Spectrum all worlds use the 0 type door).
;;   0 is used for Prison,BlackTooth,Market and BookWorld
;;   1 is used for the Moon Base
;;   2 is used for Safari
;;  "3" is used (when decoding Room data) for Egyptus and Penitentiary
;;      but type 3 is redirected to 2. (so Egyptus and Penitentiary
;;      actually use the same door than Safari)
;; Input: A = Room data door type (0 to 3)
;; Output: A = Door sprite type to actually use (0, 1, 2 and 2 again)
.ToDoorId:
	CP 		3											;; if A < 3 return A (0,1,2 cases)
	RET 	c											;; < 3 ret
	DEC 	A											;; else return A-1 (note only "3" is the other case, so it returns 2)
	RET

;; -----------------------------------------------------------------------------------------------------------
;; &0AD8 is the offset between the pre-init (data) block from &6600-ADBF that is moved at &70D8-B897
;; in Init_table_and_crtc (see move_loaded_data_section)
MOVE_OFFSET				EQU		&B897 - &ADBF			;; &0AD8
JUMP_OPCODE				EQU		&C3						;; JP addr, used to generate RST7 (int handler) and 0 (reset to Entry)

;; -----------------------------------------------------------------------------------------------------------CPC
;; This will 1) Move a big block of loaded data 2) initialize some
;; Tables 3) set the interrupts/RST and 4) initialize the CRT (mode, colors, etc.).
.Init_table_and_crtc:
	DI													;; Disable Interrupts
move_loaded_data_section:
	LD 		DE,&B897									;; destination of the last byte of the destination array
	LD 		HL,&ADBF									;; Move block from 6600-ADBF to 70D8-B897 (offset: MOVE_OFFSET = #0AD8)
	LD 		BC,&47C0									;; length &47C0 bytes
	LDDR												;; repeats LD (DE), (HL); DE--, HL--, BC-- until BC==0
erase_buffer_6800:
	LD 		HL,DestBuff									;; array from &6800
	LD 		BC,&0100									;; length 256 bytes
	CALL 	Erase_forward_Block_RAM						;; Erase from &6800 to &68FF
inth_and_rst:
	LD 		A,JUMP_OPCODE								;; A = &C3 (will be a JP instruction)
	LD		HL,Interrupt_Handler						;; Interrupt jump addr = &04BC
	LD 		(&0038),A									;; override the RST7 interrupt handler...
	LD 		(&0039),HL									;; ...with the routine Interrupt_Handler
	LD 		HL,Entry									;; override the RST0 Reset with...
	LD 		(&0000),A									;; ...with a....
	LD 		(&0001),HL									;; ...Jump at Entry
	IM 		1											;; Interrupt Mode 1 = exec a RST7 (RST &38) when an Interrupt occurs
	CALL 	Init_6600_table
init_CTRC_and_screen:
	LD 		BC,&7F8D									;; Gate Array Access:
	OUT 	(C),C										;; Video Mode 1, Reset INT counter, Lower and upper ROM disabled
	LD 		HL,array_CRTC_init_values
	LD 		BC,&BC00									;; &BC00 CRTC Reg Index 0
init_CRTC_loop:
	OUT 	(C),C										;; Select reg
	LD 		A,(HL)										;; get reg value
	INC 	B											;; &BD00 : CRTC Data Out
	OUT 	(C),A										;; set reg value
	DEC 	B											;; &BC00 CRTC Reg Index
	INC 	HL											;; point on next value
	INC 	C											;; next Reg
	LD 		A,C
	CP 		16											;; finished init 16 CRTC reg values
	JR 		NZ,init_CRTC_loop							;; loop until finished, then:
	EI													;; Enable interrupts
	RET

;; -----------------------------------------------------------------------------------------------------------CPC
array_CRTC_init_values:
	DEFB 	&3F             	;; CRTC reg 0 value : Width of the screen, in characters. Should always be 63 (&3F) (64 characters). 1 character == 1μs
	DEFB 	&28 				;; CRTC reg 1 value : Displayed char value, 40 (&28) is the default!
	DEFB 	&2E					;; CRTC reg 2 value : 46; When to start the HSync signal.
	DEFB 	&8E					;; CRTC reg 3 value : 142 (128+14); HSync pulse width in characters
	DEFB 	&26					;; CRTC reg 4 value : 38; Height of the screen, in characters
	DEFB 	&00					;; CRTC reg 5 value : 0; Measured in scanlines
	DEFB 	&19					;; CRTC reg 6 value : 25; Height of displayed screen in characters
	DEFB 	&21					;; CRTC reg 7 value : 33 Note: default is 30; hen to start the VSync signal, in characters.
	DEFB 	&00					;; CRTC reg 8 value : 0 = No interlace
	DEFB 	&07					;; CRTC reg 9 value : 7; Maximum scan line address
	DEFB 	&0F					;; CRTC reg 10 value : Cursor Start Raster (0 is the default)
	DEFB 	&0F					;; CRTC reg 11 value : Cursor End Raster (0 is the default)
	DEFB 	&30					;; CRTC reg 12 value : 48 (&30) Display Start Address (High)
	DEFB 	&00					;; CRTC reg 13 value : Display Start Address (Low) (0 is the default)
	DEFB 	&30					;; CRTC reg 14 value : Cursor Address (High) (0 is the default)
	DEFB 	&00 				;; CRTC reg 15 value : Cursor Address (Low)

;; -----------------------------------------------------------------------------------------------------------
VSYNC_wait_value:
	DEFB 	&06

;; -----------------------------------------------------------------------------------------------------------CPC
;; The interrupt is only run every VSYNC_wait_value VSYNCs
.Interrupt_Handler:
	PUSH 	AF
	PUSH 	BC											;; Save all reg
	PUSH 	HL
	LD 		HL,VSYNC_wait_value							;; point on VSYNC_wait_value
	LD 		B,&F5										;; PortB
	IN 		C,(C)										;; Read PortB (VSYNC_active is at bit 0)
	RR 		C											;; Put bit0 of C in Carry (9-bit Rigth-Rotation, Carry goes in b7 and oldb0 goes in Carry) ; b0 or PortB = CRT interrupt VSYNC active (1) inactive (0)
	JR 		c,ih_0										;; jump if VSYNC active
	DEC 	(HL)										;; VSYNC_wait_value--
	JR 		NZ,exit_int_handler			 				;; jump exit_int_handler if VSYNC_wait_value != 0 else:
ih_0:
	PUSH 	DE
	LD 		(HL),6										;; reset VSYNC_wait_value to 6
	PUSH 	IX
	PUSH 	IY
	CALL 	sub_IntH_play_update						;; run actual interrupt code (music)
	POP 	IY
	POP 	IX
	LD 		A,(Frame_counter)							;; test Frame_counter
	AND 	A
	JR 		Z,ih_1										;; jump if A=0 to Skip_Write_Frame
	DEC 	A											;; else update
	LD 		(Frame_counter),A							;; Frame_counter
ih_1:
	POP 	DE
exit_int_handler:
	POP 	HL
	POP 	BC											;; restore state
	POP 	AF
	EI													;; Enable Int
	RET

;; -----------------------------------------------------------------------------------------------------------
;; This initialize a table for the blit routines from 6600 to 66FF:
;;    6600 : 00 10 20 30 ... E0 F0
;;    6610 : 01 11 21 31 ... E1 F1
;;    6620 : 02 12 22 32 ... E2 F2
;;     ...
;;    66E0 : 0E 1E 2E 3E ... EE EF
;;    66F0 : 0F 1F 2F 3F ... EF FF
.Init_6600_table:
	LD 		HL,BlitBuff									;; HL = &6600
init_fill_loop:
	LD 		A,L											;; A = 0
	RRCA												;; 8b rotation to the right of A, old b0 goes in Carry and in b7
	RRCA
	RRCA
	RRCA
	LD 		(HL),A
	INC 	L											;; 256 times
	JR 		NZ,init_fill_loop
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Draws the screen (in black) box per box. Hides the room drawing process (draw in black).
;; Draws screen in black with an X extent from 24 (&30/2 = 48/2 = 24)
;; to 208 (&40 + 6*24 = 208 < 209 (&D1)), Y extent from &40 to maxY.
X_START 				EQU 	&30
Y_START					EQU		&40
.DrawBlacked:
	LD 		A,8											;; set color scheme to 8 (all Black)
	CALL 	Set_colors
	LD 		HL,&3040									;; X extent (min=&30, first block up to &40, 16 pix, 4 bytes per block);
	LD 		DE,&4057									;; Y extent (min=&40, first block up to &57, 23 lines per block)
dbl_loop1:
	PUSH 	HL
	PUSH 	DE
	CALL 	DrawXSafe 									;; X extent known to be in range.
	POP 	DE
	POP 	HL
	LD 		H,L											;; get X for next block
	LD 		A,L
	ADD 	A,24										;; First window is 16 pix (&40-&30) wide, subsequent are 24 pix (&18).
	LD 		L,A
	CP 		209											;; &D1 = 209 pix ; Loop across the visible core of the screen.
	JR 		c,dbl_loop1
	LD 		HL,&3040									;; return to left to the screen : initial X extent
	LD 		D,E
	LD 		A,E											;; increment Y for next box down
	ADD 	A,42										;; First window is 17 (&57-&40), subsequent are &2A=42.
	LD 		E,A											;; Loop all the way to row 255!
	JR 		NC,dbl_loop1
	RET

;; -----------------------------------------------------------------------------------------------------------
;; This reconfigure the value of PEN 3 only from the color Scheme numer in A
;; Note : Apparently, this is &_NOT_USED_& !
Set_pen3_only:
	CALL 	Get_color_scheme_value						;; update HL on the first color in the current color scheme
	INC 	HL
	INC 	HL											;; HL+3 = pick the last of the 4 colors in the scheme
	INC 	HL
	LD 		BC,&7F03									;; select pen 3
	LD 		E,1											;; only 1 pen to setup
	JP 		program_Gate_array_colors					;; program_Gate_array_colors

;; -----------------------------------------------------------------------------------------------------------
;; Reconfigure the CRTC to setup the color Scheme, from the color Scheme
;; number in A.
;; 		Color Scheme 00 : Black, Blue, Red, Pastel_yellow
;; 		Color Scheme 01 : Black, Red, Mauve, Pastel_yellow
;; 		Color Scheme 02 : Black, Magenta, DarkGreen, Pastel_yellow
;; 		Color Scheme 03 : Black, Grey, Purple, Pastel_yellow
;; 		Color Scheme 04 : Black, DarkGreen, Red, White
;; 		Color Scheme 05 : Black, Red, DarkGreen, White
;; 		Color Scheme 06 : Black, DarkCyan, Orange, White
;; 		Color Scheme 07 : Black, Red, Blue, Pastel_yellow
;; 		Color Scheme 08 : Black, Black, Black, Black (Screen Off)
;; 		Color Scheme 09 : Grey, DarkBlue, DarkRed, Yellow
;; 		Color Scheme 0A : DarkRed, Yellow, Cyan, Pink
.Set_colors:
	CALL 	Get_color_scheme_value						;; HL = pointer on color Scheme data
	LD 		BC,&7F10									;; Gate array BORDER select
	LD 		E,1											;; number of colors to update (1 border)
	CALL 	program_Gate_array_colors					;; program_Gate_array_colors
	DEC 	HL											;; reuse last color (Border color), for pen 0
	LD 		E,4											;; need to set 4 pens (0 to 3)
	LD 		BC,&7F00									;; Select pen 0
program_Gate_array_colors:
	OUT 	(C),C										;; Tell Gate array which pen we want to setup
	INC 	C											;; prepare for next pen
	LD 		A,(HL)										;; get current color
	OR 		&40											;; convert HW color to firmware color
	OUT 	(C),A										;; write color value for current pen in GareArray
	INC 	HL											;; next data
	DEC 	E											;; nb_pens--
	JR 		NZ,program_Gate_array_colors				;; loop until we have done the 4 pens
	RET

;; -----------------------------------------------------------------------------------------------------------
;; This converts the color Scheme number in A to the pointer in HL
;; on the Color Scheme data.
.Get_color_scheme_value:
	ADD 	A,A
	ADD 	A,A											;; A*4 ;
	LD 		DE,array_Color_Schemes						;; pointer on array_Color_Schemes
	LD 		L,A
	LD 		H,&00										;; HL = A (index in array_Color_Schemes is color Scheme * 4)
	ADD 	HL,DE										;; HL points on the 4 bytes defining the colors in the scheme
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Table for the Color Scheme 4 colors
;; (Index = color Scheme number * 4)
array_Color_Schemes:
	DEFB 	&14, &15, &0C, &03			;; Color Scheme 00 : Black, Blue, Red, Pastel_yellow
	DEFB 	&14, &0C, &1D, &03			;; Color Scheme 01 : Black, Red, Mauve, Pastel_yellow (used in one before last room for exemple)
	DEFB 	&14, &18, &16, &03			;; Color Scheme 02 : Black, Magenta, DarkGreen, Pastel_yellow
	DEFB 	&14, &00, &05, &03			;; Color Scheme 03 : Black, Grey, Purple, Pastel_yellow
	DEFB 	&14, &16, &0C, &0B			;; Color Scheme 04 : Black, DarkGreen, Red, White
	DEFB 	&14, &0C, &16, &0B			;; Color Scheme 05 : Black, Red, DarkGreen, White
	DEFB 	&14, &06, &0E, &0B			;; Color Scheme 06 : Black, DarkCyan, Orange, White (Exemple : screen showing the worlds/crowns ("The Blacktooth Empire") or the "Salute you" screen); note DarkCyan is a vert-de-gris kinda color
	DEFB 	&14, &0C, &15, &03			;; Color Scheme 07 : Black, Red, Blue, Pastel_yellow (This is probably the one for Room 1)
	DEFB 	&14, &14, &14, &14			;; Color Scheme 08 : Black, Black, Black, Black (Screen Off)
	DEFB 	&00, &04, &1C, &0A			;; Color Scheme 09 : Grey, DarkBlue, DarkRed, Yellow (Exemple: Game, Controls, Sound and Sensitivity menues)
	DEFB 	&1C, &0A, &13, &07			;; Color Scheme 0A : DarkRed, Yellow, Cyan, Pink (Exemple: Main menu)

;; -----------------------------------------------------------------------------------------------------------
;; Look-up the char ID in A (note: this value already had a minus &20)
;; and make DE point to the char symbol data.
;; For exemple: A=&11 (char ID &11 => char code ("ASCII") &35) will
;; point DE on the symbol data at &B6B8 (charID &11 : "5")
;;   B630 charID &00 : Space
;;   B638 charID &01 (char code &21) : menu selected arrows left part
;;   B640 charID &02 (char code &22) : menu selected arrows right part
;;   B648 charID &03 (char code &23) : menu unselected arrows left part
;;   B650 charID &04 (char code &24) : menu unselected arrows right part
;;   B658 charID &05 (char code &25) : speed lightning icon
;;   B660 charID &06 (char code &26) : spring icon
;;   B668 charID &07 (char code &27) : shield icon
;;   B670 charID &08 : comma
;;   B678 charID &09 : Big Block
;;   B680 charID &0A : Small block
;;   B688 charID &0B : "/"
;;   B690 charID &0C (char code &30) : "0"
;;	...
;;   B6D8 charID &15 (char code &39) : "9"
;;   B6E0 charID &16 : ":"
;;   B6E8 charID &17 : ";"
;;   B6F0 charID &18 : "@"
;;   B6F8 charID &19 (char code &41) : "A"
;;	...
;;   B7C0 charID &32 (char code &5A) : "Z"
;;   B7C8 charID &33 : "["
;;   B7D0 charID &34 : "\"
;;   B7D8 charID &35 : "]"
;;   B7E0 charID &36 : Up arrow
;;   B7E8 charID &37 : Down arrow
;;   B7F0 charID &38 : Right arrow
;;   B7F8 charID &39 : Left arrow
;; -----------------------------------------------------------------------------------------------------------
;; To understand the value manipulation and comparison, use this "graph":
;; spc         icons                              "0""1""2""3""4""5""6""7""8""9"                     "A""B""C""D" ...
;; 20 21 22 23 24 25 26 27 28 29 2A 2B 2C 2D 2E 2F 30 31 32 33 34 35 36 37 38 39 3A 3B 3C 3D 3E 3F 40 41 42 43 44 ... ID
;; 0  1  2  3  4  5  6  7  8  9  A  B  C  D  E  F  10 11 12 13 14 15 16 17 18 19 1A 1B 1C 1D 1E 1F 20 21 22 23 24 ... A = ID - &20
;; C  C  C  C  C  C  C  C  Z																							CP 08
;;                         4  5  6  7  8  9  A  B  C  D  E  F  10 11 12 13 14 15 16 17 18 19 1A 1B 1C 1D 1E 1F 20 ... new A = A - &04
;;                         C  C  C  C  C  C  C  C  C  C  C  C  C  C  C  C  C  C  C  C  Z								CP 18
;;                                                                                     14 15 16 17 18 19 1A 1B 1C ... new A = A - &04
;; -----------------------------------------------------------------------------------------------------------
;; Convert the CharCode - &20 to Symbol data address in DE
.Char_code_to_Addr:
	CP 		&08											;; comp with 8 ("charcode - &20" compared with &08)
	JR 		c,cc2a_0									;; jump if charcode < ID&28 (icons) else:
	SUB 	4           	       						;; newA =  entryA-4 (for characters like numbers, convert char code into charID, eg. "1" &31->id&0D)
	CP 		&18											;; comp &18
	JR 		c,cc2a_0									;; jump if charcode < ID&3C else:
	SUB 	4											;; newA -= 4 (for characters like letters, convert char code into charID, eg. "A" &41->id&19)
cc2a_0:
	ADD 	A,A
	ADD 	A,A											;; A*4
	LD 		L,A
	LD 		H,&00
	ADD 	HL,HL										;; *2, char addr offset in HL
	LD 		DE,Char_symbol_data	+ MOVE_OFFSET			;; base addr for char data : Char_symbol_data; the MOVE_OFFSET is to get the addr after the 6600 block move at init
	ADD		HL,DE										;; base+offset
	EX 		DE,HL                						;; put the addr of the character symbol in DE
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Provides 2 functions:
;; 	* Clear_mem_array_at_6700: This will be implicitely CALLed by
;; 			the RET of the blit subroutines (blit_sub_subroutine_1 to 6)
;;			It erases the sprite buffer.
;;	* Clear_mem_array_256bytes: This will erase a memory block from the
;;			addr value in HL (Starts at HL, HL++ and until Lmax = &FF)
.Clear_mem_array_at_6700:
	LD 		HL,ViewBuff									;; init buffer addr
.Clear_mem_array_256bytes:
	XOR 	A											;; erase value = &00
cma_loop:
	LD 		(HL),A
	INC 	L
	LD 		(HL),A
	INC 	L
	LD 		(HL),A										;; erase 4 consecutive bytes
	INC 	L
	LD 		(HL),A
	INC 	L
	JR 		NZ,cma_loop									;; L overflowed back to 4? No, then loop.
	RET

;; -----------------------------------------------------------------------------------------------------------
;; BlitScreen copies from ViewBuff to the screen coordinates of
;; ViewYExtent and ViewXExtent. The X extent can be from 1 up to 6 bytes
;; (4 pix per bytes, 24 double pixels).
;; The "Extent" are Max,Min values.
;; At the end, the selected blit subroutine (having been pushed on the stack)
;; is implicitely CALLed by the RET (and so is the Erase function).
;;
;; ViewBuff is expected to be a 6 bytes wide, and the Y origin can
;; be adjusted by overwriting BlitYOffset. It is usually Y_START, but
;; is set to 0 during Draw_Sprite. The X origin is always fixed at 0x30
;; in double-width pixels.
.Blit_screen:
	LD 		HL,(ViewXExtent)							;; get x pos for the sprite ViewXExtent
	LD 		A,H
	SUB 	X_START										;; minus X origin
	LD 		C,A											;; topleft X
	LD 		A,L											;; minX
	SUB 	H											;; maxX - minX = X width
	RRA
	RRA													;; divided by 4 (4 pix per bytes in Mode 1)
	AND 	&07					 						;; Width = ((XHigh) - (XLow)) / 4
	DEC 	A											;; index in table = Width-1 : which blit subroutine (1 to 6)
	ADD 	A,A											;; *2 = word aligned (to get the addr in table)
	LD 		E,A
	LD 		D,&00										;; DE is the offset in the Sub_routines_table to get the addr of the blit subroutine to call
	LD 		HL,Sub_routines_table
	ADD 	HL,DE										;; HL points on the subroutine addr pointer
	LD 		DE,Clear_mem_array_at_6700					;; The addr of the Clear_mem_array_6700_256bytes routine
	PUSH 	DE											;; is put on the stack for next RET so that next ret will branch on it
	LD 		E,(HL)
	INC 	HL
	LD 		D,(HL)										;; DE now has the selected blit subroutine addr
	PUSH 	DE											;; Push that address on the Stack so next RET will return to it (so next RET will call the blit subroutine, RET and call the erase 6700 and RET!)
	LD		HL,(ViewYExtent)							;; get height extent (min and max Y) from ViewYExtent
	LD 		A,L											;; minY
	SUB 	H											;; Height: (YHigh) - (YLow)
	EX 		AF,AF'										;; save minY
	LD 		A,H											;; maxY
smc_BlitYOffset_value:
	SUB 	Y_START										;; minus origin ; value &40 by default, Draw_Sprite will self-modified code to change (and restore) that value
	;;05CD DEFB 40															; target of self-modifying code; default 40; modified by Draw_Sprite
	LD 		B,A											;; topleft Y
	CALL 	Get_screen_mem_addr							;; Screen address (from topleft point YX in BC) is now in DE
	EX 		AF,AF'										;; restore minY
	LD 		B,BlitBuff / 256							;; use the BC = &6600+X table index as input of the selected blit_sub_subroutine_1 to 6 that will be called at RET
	LD 		HL,ViewBuff									;; use the HL = Buffer at &6700 as input for the selected blit_sub_subroutine_1 to 6 that will be called at RET
	RET													;; This RET will CALL the selected blit subroutine pushed on the Stack!

;; -----------------------------------------------------------------------------------------------------------
;; This table will return the pointer address for the blit routine to
;; be used, with index = N-1; N being the byte width of the sprite.
.Sub_routines_table:
	DEFW 	blit_sub_subroutine_1      			;; address of blit_sub_subroutine_1 (05E5)
	DEFW 	blit_sub_subroutine_2      			;; address of blit_sub_subroutine_2 (061E)
	DEFW 	blit_sub_subroutine_3 				;; address of blit_sub_subroutine_3 (0669)
	DEFW 	blit_sub_subroutine_4 				;; address of blit_sub_subroutine_4 (06C6)
	DEFW 	blit_sub_subroutine_5 				;; address of blit_sub_subroutine_5 (0735)
	DEFW 	blit_sub_subroutine_6 				;; address of blit_sub_subroutine_6 (07B6)

;; -----------------------------------------------------------------------------------------------------------
;; All these (6 functions) provide Sprite Bliting functions.
;; They are implicitely CALLed by the final RET of Blit_screen.
;; The "blit_sub_subroutine_1 to 6" copies an N-byte-wide image
;; (in the buffer at HL) to the screen.
;; They use the table initialized at 6600-66FF and a buffer at 6700-67FF.
;; Input: HL = image location; DE = screen location, size in lines in B.
;; Note : HL buffer must be 6 bytes wide.
;; The RET will implicitely CALL the Clear_mem_array_at_6700 (that has
;; been pushed on the Stack)
.blit_sub_subroutine_1:
	EX 		AF,AF'
	LD 		C,(HL)											;; get C from 6700 buffer
	INC 	H
	LD 		A,(BC)											;; get the index in 6600 table from BC = table + X
	XOR 	(HL)
	AND 	&0F
	XOR 	(HL)
	LD 		(DE),A
	LD 		C,(HL)
	LD 		A,(BC)
	DEC 	H
	XOR 	(HL)
	AND 	&F0
	XOR 	(HL)
	INC 	E
	LD		(DE),A
	INC 	L
	INC 	L
	INC 	L
	INC 	L
	INC 	L
	INC 	L
	LD 		BC,&FFFF										;; -1
	EX 		DE,HL
	ADD 	HL,BC
	EX 		DE,HL
	LD 		B,BlitBuff / 256								;; Table values at &6600 + X (X in C)
	LD 		A,D
	ADD 	A,&08
	LD 		D,A
	JR 		c,blit_ss_1
	EX 		AF,AF'
	DEC 	A
	JR 		NZ,blit_sub_subroutine_1
	RET

blit_ss_1:
	LD 		A,E
	ADD 	A,&50
	LD 		E,A
	ADC 	A,D
	SUB 	E
	SUB 	&40
	LD 		D,A
	EX 		AF,AF'
	DEC 	A
	JR 		NZ,blit_sub_subroutine_1
	RET

;; -----------------------------------------------------------------------------------------------------------
.blit_sub_subroutine_2:
	EX 		AF,AF'
	LD 		C,(HL)
	INC 	H
	LD 		A,(BC)
	XOR 	(HL)
	AND 	&0F
	XOR 	(HL)
	LD 		(DE),A
	LD 		C,(HL)
	LD 		A,(BC)
	DEC 	H
	XOR 	(HL)
	AND 	&F0
	XOR 	(HL)
	INC 	E
	LD 		(DE),A
	INC		L
	INC 	DE
	LD 		C,(HL)
	INC 	H
	LD 		A,(BC)
	XOR 	(HL)
	AND 	&0F
	XOR 	(HL)
	LD 		(DE),A
	LD 		C,(HL)
	LD 		A,(BC)
	DEC		H
	XOR		(HL)
	AND		&F0
	XOR		(HL)
	INC		E
	LD 		(DE),A
	INC 	L
	INC 	L
	INC 	L
	INC 	L
	INC 	L
	LD 		BC,&FFFD
	EX 		DE,HL
	ADD 	HL,BC
	EX 		DE,HL
	LD 		B,BlitBuff / 256									;; Table values at &6600 + C
	LD 		A,D
	ADD 	A,&08
	LD 		D,A
	JR 		c,blit_ss_2
	EX 		AF,AF'
	DEC 	A
	JR 		NZ,blit_sub_subroutine_2
	RET

blit_ss_2:
	LD 		A,E
	ADD 	A,&50
	LD 		E,A
	ADC 	A,D
	SUB 	E
	SUB 	&40
	LD 		D,A
	EX 		AF,AF'
	DEC 	A
	JR 		NZ,blit_sub_subroutine_2
	RET

;; -----------------------------------------------------------------------------------------------------------
.blit_sub_subroutine_3:
	EX 		AF,AF'
	LD 		C,(HL)
	INC 	H
	LD 		A,(BC)
	XOR 	(HL)
	AND		&0F
	XOR 	(HL)
	LD 		(DE),A
	LD 		C,(HL)
	LD 		A,(BC)
	DEC 	H
	XOR 	(HL)
	AND 	&F0
	XOR 	(HL)
	INC 	E
	LD 		(DE),A
	INC 	L
	INC	 	DE
	LD 		C,(HL)
	INC 	H
	LD 		A,(BC)
	XOR 	(HL)
	AND 	&0F
	XOR 	(HL)
	LD 		(DE),A
	LD 		C,(HL)
	LD 		A,(BC)
	DEC 	H
	XOR 	(HL)
	AND 	&F0
	XOR 	(HL)
	INC 	E
	LD 		(DE),A
	INC 	L
	INC 	DE
	LD 		C,(HL)
	INC 	H
	LD 		A,(BC)
	XOR 	(HL)
	AND 	&0F
	XOR 	(HL)
	LD 		(DE),A
	LD 		C,(HL)
	LD 		A,(BC)
	DEC 	H
	XOR 	(HL)
	AND 	&F0
	XOR 	(HL)
	INC 	E
	LD 		(DE),A
	INC 	L
	INC 	L
	INC 	L
	INC 	L
	LD 		BC,&FFFB
	EX 		DE,HL
	ADD 	HL,BC
	EX 		DE,HL
	LD 		B,BlitBuff / 256									;; Table values at &6600 + C
	LD 		A,D
	ADD 	A,&08
	LD 		D,A
	JR 		c,blit_ss_3
	EX 		AF,AF'
	DEC 	A
	JR 		NZ,blit_sub_subroutine_3
	RET

blit_ss_3:
	LD 		A,E
	ADD 	A,&50
	LD 		E,A
	ADC 	A,D
	SUB 	E
	SUB 	&40
	LD 		D,A
	EX 		AF,AF'
	DEC 	A
	JR		NZ,blit_sub_subroutine_3
	RET

;; -----------------------------------------------------------------------------------------------------------
.blit_sub_subroutine_4:
	EX 		AF,AF'
	LD 		C,(HL)
	INC 	H
	LD 		A,(BC)
	XOR 	(HL)
	AND 	&0F
	XOR 	(HL)
	LD 		(DE),A
	LD 		C,(HL)
	LD 		A,(BC)
	DEC		H
	XOR 	(HL)
	AND 	&F0
	XOR 	(HL)
	INC 	E
	LD 		(DE),A
	INC 	L
	INC 	DE
	LD 		C,(HL)
	INC 	H
	LD 		A,(BC)
	XOR 	(HL)
	AND 	&0F
	XOR 	(HL)
	LD 		(DE),A
	LD 		C,(HL)
	LD 		A,(BC)
	DEC 	H
	XOR 	(HL)
	AND 	&F0
	XOR 	(HL)
	INC 	E
	LD 		(DE),A
	INC 	L
	INC 	DE
	LD 		C,(HL)
	INC 	H
	LD 		A,(BC)
	XOR 	(HL)
	AND 	&0F
	XOR 	(HL)
	LD 		(DE),A
	LD 		C,(HL)
	LD 		A,(BC)
	DEC		H
	XOR		(HL)
	AND		&F0
	XOR		(HL)
	INC		E
	LD 		(DE),A
	INC 	L
	INC 	DE
	LD 		C,(HL)
	INC 	H
	LD 		A,(BC)
	XOR 	(HL)
	AND 	&0F
	XOR 	(HL)
	LD 		(DE),A
	LD 		C,(HL)
	LD 		A,(BC)
	DEC 	H
	XOR 	(HL)
	AND 	&F0
	XOR 	(HL)
	INC 	E
	LD 		(DE),A
	INC 	L
	INC 	L
	INC 	L
	LD 		BC,&FFF9
	EX 		DE,HL
	ADD 	HL,BC
	EX 		DE,HL
	LD 		B,BlitBuff / 256								;; Table values at &6600 + C
	LD 		A,D
	ADD 	A,&08
	LD 		D,A
	JR 		c,blit_ss_4
	EX 		AF,AF'
	DEC 	A
	JR 		NZ,blit_sub_subroutine_4
	RET

blit_ss_4:
	LD 		A,E
	ADD 	A,&50
	LD 		E,A
	ADC 	A,D
	SUB 	E
	SUB 	&40
	LD 		D,A
	EX 		AF,AF'
	DEC 	A
	JR 		NZ,blit_sub_subroutine_4
	RET

;; -----------------------------------------------------------------------------------------------------------
.blit_sub_subroutine_5:
	EX 		AF,AF'
	LD 		C,(HL)
	INC 	H
	LD 		A,(BC)
	XOR 	(HL)
	AND 	&0F
	XOR 	(HL)
	LD 		(DE),A
	LD 		C,(HL)
	LD 		A,(BC)
	DEC 	H
	XOR 	(HL)
	AND 	&F0
	XOR 	(HL)
	INC 	E
	LD 		(DE),A
	INC 	L
	INC 	DE
	LD 		C,(HL)
	INC 	H
	LD 		A,(BC)
	XOR 	(HL)
	AND 	&0F
	XOR 	(HL)
	LD 		(DE),A
	LD 		C,(HL)
	LD 		A,(BC)
	DEC 	H
	XOR 	(HL)
	AND 	&F0
	XOR 	(HL)
	INC 	E
	LD 		(DE),A
	INC 	L
	INC 	DE
	LD 		C,(HL)
	INC 	H
	LD 		A,(BC)
	XOR 	(HL)
	AND 	&0F
	XOR 	(HL)
	LD 		(DE),A
	LD 		C,(HL)
	LD 		A,(BC)
	DEC 	H
	XOR 	(HL)
	AND 	&F0
	XOR 	(HL)
	INC 	E
	LD 		(DE),A
	INC 	L
	INC		DE
	LD 		C,(HL)
	INC 	H
	LD 		A,(BC)
	XOR 	(HL)
	AND 	&0F
	XOR 	(HL)
	LD 		(DE),A
	LD 		C,(HL)
	LD 		A,(BC)
	DEC 	H
	XOR 	(HL)
	AND 	&F0
	XOR 	(HL)
	INC 	E
	LD 		(DE),A
	INC 	L
	INC 	DE
	LD 		C,(HL)
	INC 	H
	LD 		A,(BC)
	XOR 	(HL)
	AND 	&0F
	XOR 	(HL)
	LD 		(DE),A
	LD 		C,(HL)
	LD 		A,(BC)
	DEC 	H
	XOR 	(HL)
	AND 	&F0
	XOR 	(HL)
	INC 	E
	LD 		(DE),A
	INC		L
	INC 	L
	LD 		BC,&FFF7
	EX 		DE,HL
	ADD 	HL,BC
	EX 		DE,HL
	LD 		B,BlitBuff / 256									;; Table values at &6600 + C
	LD 		A,D
	ADD 	A,&08
	LD 		D,A
	JR 		c,blit_ss_5
	EX 		AF,AF'
	DEC 	A
	JR 		NZ,blit_sub_subroutine_5
	RET

blit_ss_5:
	LD 		A,E
	ADD 	A,&50
	LD 		E,A
	ADC 	A,D
	SUB 	E
	SUB 	&40
	LD 		D,A
	EX 		AF,AF'
	DEC 	A
	JR 		NZ,blit_sub_subroutine_5
	RET

;; -----------------------------------------------------------------------------------------------------------
.blit_sub_subroutine_6:
	EX 		AF,AF'
	LD 		C,(HL)
	INC 	H
	LD 		A,(BC)
	XOR 	(HL)
	AND 	&0F
	XOR 	(HL)
	LD 		(DE),A
	LD 		C,(HL)
	LD 		A,(BC)
	DEC		H
	XOR		(HL)
	AND		&F0
	XOR		(HL)
	INC		E
	LD 		(DE),A
	INC 	L
	INC 	DE
	LD 		C,(HL)
	INC 	H
	LD 		A,(BC)
	XOR 	(HL)
	AND 	&0F
	XOR 	(HL)
	LD 		(DE),A
	LD 		C,(HL)
	LD 		A,(BC)
	DEC 	H
	XOR 	(HL)
	AND 	&F0
	XOR 	(HL)
	INC 	E
	LD 		(DE),A
	INC 	L
	INC 	DE
	LD 		C,(HL)
	INC 	H
	LD 		A,(BC)
	XOR 	(HL)
	AND 	&0F
	XOR 	(HL)
	LD 		(DE),A
	LD 		C,(HL)
	LD 		A,(BC)
	DEC 	H
	XOR 	(HL)
	AND 	&F0
	XOR 	(HL)
	INC 	E
	LD 		(DE),A
	INC 	L
	INC 	DE
	LD 		C,(HL)
	INC 	H
	LD 		A,(BC)
	XOR 	(HL)
	AND 	&0F
	XOR 	(HL)
	LD 		(DE),A
	LD 		C,(HL)
	LD 		A,(BC)
	DEC		H
	XOR		(HL)
	AND		&F0
	XOR		(HL)
	INC		E
	LD 		(DE),A
	INC 	L
	INC 	DE
	LD 		C,(HL)
	INC 	H
	LD 		A,(BC)
	XOR		(HL)
	AND		&0F
	XOR		(HL)
	LD 		(DE),A
	LD 		C,(HL)
	LD 		A,(BC)
	DEC		H
	XOR		(HL)
	AND		&F0
	XOR		(HL)
	INC		E
	LD 		(DE),A
	INC 	L
	INC 	DE
	LD 		C,(HL)
	INC 	H
	LD 		A,(BC)
	XOR 	(HL)
	AND 	&0F
	XOR 	(HL)
	LD 		(DE),A
	LD 		C,(HL)
	LD 		A,(BC)
	DEC 	H
	XOR 	(HL)
	AND 	&F0
	XOR 	(HL)
	INC 	E
	LD 		(DE),A
	INC 	L
	LD 		BC,&FFF5
	EX 		DE,HL
	ADD 	HL,BC
	EX 		DE,HL
	LD 		B,BlitBuff / 256									;; Table values at &6600 + C
	LD 		A,D
	ADD 	A,&08
	LD 		D,A
	JR 		c,blit_ss_6
	EX 		AF,AF'
	DEC 	A
	JP 		NZ,blit_sub_subroutine_6							;; loop if NZ todo_subroutine_6
	RET

blit_ss_6:
	LD 		A,E
	ADD 	A,&50
	LD 		E,A
	ADC 	A,D
	SUB 	E
	SUB 	&40
	LD 		D,A													;; DE = DE + 50 - 4000
	EX 		AF,AF'
	DEC 	A
	JP 		NZ,blit_sub_subroutine_6							;; loop if NZ todo_subroutine_6
	RET

;; -----------------------------------------------------------------------------------------------------------
;; This is the CPC screen mem address calculation from the pixel we target.
;; Input: B = y (line),
;;        C = x single-pixel coordinate (in mode 1 real x is double that value).
;; Note: top left coord is (0,0) at addr &C000. Mode 1 ppb (pix per byte) is 4
;; This will calculate the Output in DE:
;; 		DE = address = 0xC000 + ((y / 8) * 80) + ((y % 8) * &0800) + (x / ppb)
SCREEN_ADDR_START		EQU		&C000
SCREEN_LENGTH			EQU		&4000

.Get_screen_mem_addr:
	LD 		A,B											;; A = y coord = line number
	AND 	&F8											;; A= (y / 8) * 8
	LD 		E,A											;; tmp=A*1
	RRCA												;; A div by 2
	RRCA												;; A div by 4 (A * 0.25)
	ADD 	A,E											;; A*1.25 ((A * 1) + (A * 0.25))
	ADD 	A,A											;; A*2.5; overflow in Carry
	RL 		B											;; (y%128)*2+carry  (BC = (y%128) * &0200 + x)
	ADD 	A,A											;; A*5; overflow in Carry
	RL 		B											;; (y%64)*4+carry  (BC = (y%64) * &0200 + x)
	ADD 	A,A											;; A*10 = (y / 8) * 80; overflow in Carry
	RL 		B											;; (y%32)*8+carry  (BC = (y%32) * &0800 + x)
	SRL 	C											;; C=x/2  (BC = (y%32) * &0800 + x/2)
	ADD 	A,C											;; Then, all this...
	LD 		E,A
	ADC 	A,B											;; ...does...
	SUB 	E
	OR 		SCREEN_ADDR_START / 256
	LD 		D,A											;; ... DE = C000 + BC + A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Wipe screen with the spirals/snake effect
.Draw_wipe_and_Clear_Screen:
	LD 		E,&03
dwcs_0:
	LD 		HL,SCREEN_ADDR_START						;; screen address
	LD 		BC,SCREEN_LENGTH							;; screen length
	LD 		D,L											;; DE=3
dwcs_1:
	LD 		A,(HL)
	RRA
	AND 	&77
	RR 		D
	JR 		NC,dwcs_2
	OR 		&08
dwcs_2:
	BIT 	3,D
	JR 		Z,dwcs_3
	OR 		&80
dwcs_3:
	LD 		D,(HL)
	AND 	D
	LD 		(HL),A
	INC 	HL
	DEC 	BC
	LD 		A,B
	OR 		C
	JR 		NZ,dwcs_1
	LD 		D,C
	LD 		BC,SCREEN_LENGTH
dwcs_4:
	DEC 	HL
	LD 		A,(HL)
	RLA
	AND 	&EE
	RL 		D
	JR 		NC,dwcs_5
	OR 		&10
dwcs_5:
	BIT 	4,D
	JR 		Z,dwcs_6
	OR 		&01
dwcs_6:
	LD 		D,(HL)
	AND 	D
	LD 		(HL),A
	DEC 	BC
	LD 		A,B
	OR 		C
	JR 		NZ,dwcs_4
	DEC 	E
	JR 		NZ,dwcs_0
clr_screen:																	;; Finally clear the screen
	LD 		HL,SCREEN_ADDR_START						;; screen addr
	LD 		BC,SCREEN_LENGTH							;; screen length : Wipe screen
	JP 		Erase_forward_Block_RAM						;; Erase_forward_Block_RAM will have a RET

;; -----------------------------------------------------------------------------------------------------------
;; Draw a sprite (or char Symbol), with attributes in A (color style).
;; Source in DE, dest coords in BC, size in HL (H height, L width)
;; Attribute "color style" in A (1 = shadow mode, 3 = color mode)
;; (X measured in double-pixels, centered on &80)
;; Top of screen is Y = 0, for once.
.Draw_Sprite:
	PUSH 	DE											;; DE has the char symbol pointer or sprite source
	PUSH 	AF											;; A have the attribute (color style) number
	LD 		A,&F8										;; will produce a sub (-8) = add 8 in Blit_Screen???
	LD 		(smc_BlitYOffset_value+1),A					;; update the val in "SUB val" (BlitYoffset+1) at &05CC in Blit_Screen ; self mod code
	LD 		D,B
	LD 		A,B											;; Y
	ADD 	A,H											;; Y + height
	LD 		E,A											;; DE is now Y,Y+height = YExtent
	LD 		(ViewYExtent),DE							;; update ViewYExtent
	LD 		A,C
	LD 		B,C
	ADD 	A,L											;; same for XExtent
	LD 		C,A
	LD 		(ViewXExtent),BC							;; update ViewXExtent
	LD 		A,L											;; Width
	RRCA
	RRCA												;; div 4 (4 pix per byte)
	AND 	&07
	LD 		C,A											;; number of bytes
	POP 	AF											;; get back attribute (color style) number
	LD 		DE,ViewBuff									;; DE point on sprite buffer
	CP 		&03											;; is it 3 (color mode)? (no:Carry set, yes:Carry reset)
	CCF													;; inverts Carry flag (not 3: Carry reset; Pen3: Carry set)
	JR 		c,drwspr_1									;; if 3, then jump drwspr_1, else:
	CP 		&01											;; is attribute (color style) = 1? (attr 0: NZ,Carry, attr 1: Z,NC, attr 2: NZ,NC)
	JR 		NZ,drwspr_1									;; not attr 1, jump drwspr_1, else attribute (color style) is 1 = "Shadow" mode:
	INC 	D											;; if shadow mode, use buffer = 6800
drwspr_1:
	LD 		A,H											;; height
	EX 		AF,AF'										;; get flags, save height
	LD 		HL,DestBuff									;; clear 256 bytes buffer from &6800
	CALL 	Clear_mem_array_256bytes
	EX 		AF,AF'										;; save flags, get height
	EX 		DE,HL										;; DE<->HL
	POP 	DE											;; get sprite/symbol source (addr)
drwspr_2:
	EX 		AF,AF'
	LD 		B,C											;; nb of bytes in X direction
drwspr_3:
	LD 		A,(DE)										;; get byte of data
	LD 		(HL),A										;; draw it to buffer
	EX 		AF,AF'
	JR 		NC,drwspr_4
	INC 	H
	EX 		AF,AF'
	LD 		(HL),A
	EX 		AF,AF'
	DEC 	H
drwspr_4:
	EX 		AF,AF'
	INC 	L
	INC 	DE
	DJNZ 	drwspr_3
	LD 		A,6					 						;; ViewBuff is 6 bytes wide...
	SUB 	C
	ADD 	A,L
	LD 		L,A
	EX 		AF,AF'
	DEC 	A
	JR 		NZ,drwspr_2
	CALL 	Blit_screen									;; Blit the sprite in the buffer
	LD 		A,Y_START
	LD 		(smc_BlitYOffset_value+1),A					;; restore the val in "SUB val" (BlitYoffset+1) at &05CC in Blit_Screen
	RET

;; -----------------------------------------------------------------------------------------------------------
Delimiter 						EQU		&FF
Print_WipeScreen				EQU		&00
Print_NewLine					EQU		&01
Print_ClrEOL					EQU		&02
Print_SingleSize				EQU		&03
Print_DoubleSize				EQU		&04
Print_ColorAttr					EQU		&05
Print_Color_Attr_1				EQU		&81
Print_Color_Attr_2				EQU		&82
Print_Color_Attr_3				EQU		&83
Print_SetPosition				EQU		&06
Print_ColorScheme				EQU		&07
Print_Arrow_1					EQU		&21
Print_Arrow_2					EQU		&22
Print_Arrow_3					EQU		&23
Print_Arrow_4					EQU		&24
Print_Icon_Speed				EQU		&25
Print_Icon_Spring				EQU		&26
Print_Icon_Sheild				EQU		&27
Print_StrID_Title_Instr			EQU		&99
Print_StrID_Enter2Finish		EQU		&A5
Print_StrID_SelectKeys			EQU		&A6
Print_StrID_ShiftToFinish		EQU		&A7
Print_StrID_ChooseNewKey		EQU		&A8
Print_StrID_SoundMenu			EQU		&A9
Print_StrID_SensMenu			EQU		&AA
Print_StrID_PlayOldNew			EQU		&AB
Print_StringID_Paused 			EQU		&AC
Print_Wipe_DblSize_pos			EQU		&B0
Print_StringID_Icons			EQU		&B8
Print_SingleSize_at_pos			EQU		&B9
Print_StrID_TitleBanner			EQU		&BA
Print_StringID_Explored			EQU		&BB
Print_StringID_RoomsScore		EQU		&BC
Print_StringID_Liberated		EQU		&BD
Print_StringID_Planets			EQU		&BE
Print_Array_StrID_Rank			EQU		&BF
Print_StringID_Emperor			EQU		&C4
Print_StringID_Wipe_BTEmpire	EQU		&C6
Print_StringID_Freedom			EQU		&C9
Print_StringID_Wipe_Salute		EQU		&CA

;; -----------------------------------------------------------------------------------------------------------
;; Some keyboard related strings
.String_Table_Kb:
	DEFB 	Delimiter							;; Delimiter (ID &E0)
	DEFB 	"RETURN"     						;; String "RETURN"
	DEFB 	Delimiter							;; Delimiter (ID &E1)
	DEFB 	Print_Color_Attr_3					;; Pointer on String ID &83
	DEFB 	"LOCK"								;; String "LOCK"
	DEFB 	Delimiter							;; Delimiter (ID &E2)
	DEFB 	Print_Color_Attr_3					;; Pointer on String ID &83
	DEFB 	"ESC"								;; String "ESC"
	DEFB 	Delimiter							;; Delimiter (ID &E3)
	DEFB 	Print_Color_Attr_3					;; Pointer on String ID &83
	DEFB 	"TAB"								;; String "TAB"
	DEFB 	Delimiter							;; Delimiter (ID &E4)
	DEFB 	Print_Color_Attr_3					;; Pointer on String ID &83
	DEFB 	"DEL"								;; String "DEL"
	DEFB 	Delimiter							;; Delimiter (ID &E5)
	DEFB 	Print_Color_Attr_3					;; Pointer on String ID &83
	DEFB 	"CTRL"								;; String "CTRL"
	DEFB 	Delimiter							;; Delimiter (ID &E6)
	DEFB 	Print_Color_Attr_3					;; Pointer on String ID &83
	DEFB 	"COPY"								;; String "COPY"
	DEFB 	Delimiter							;; Delimiter (ID &E7)
	DEFB 	Print_Color_Attr_3					;; Pointer on String ID &83
	DEFB 	"CLR"								;; String "CLR"
	DEFB 	Delimiter							;; Delimiter (ID &E8)
	DEFB 	Print_Color_Attr_1					;; Pointer on String ID &81
	DEFB 	"JOY"								;; String "JOY"
	DEFB 	Delimiter							;; Delimiter (ID &E9)
	DEFB 	&E8									;; Pointer on String ID &E8 ("|JOY")
	DEFB 	"F"									;; String "F"
	DEFB 	Delimiter							;; Delimiter (ID &EA)
	DEFB 	&E8									;; Pointer on String ID &E8 ("|JOY")
	DEFB 	"U"									;; String "U"
	DEFB 	Delimiter							;; Delimiter (ID &EB)
	DEFB 	&E8									;; Pointer on String ID &E8 ("|JOY")
	DEFB 	"D"									;; String "D"
	DEFB 	Delimiter							;; Delimiter (ID &EC)
	DEFB 	&E8									;; Pointer on String ID &E8 ("|JOY")
	DEFB 	"R"									;; String "R"
	DEFB 	Delimiter							;; Delimiter (ID &ED)
	DEFB 	&E8									;; Pointer on String ID &E8 ("|JOY")
	DEFB 	"L"									;; String "L"
	DEFB 	Delimiter							;; Delimiter (ID &EE)
	DEFB 	Print_Color_Attr_3					;; Pointer on String ID &83
	DEFB 	"SPACE"								;; String "SPACE"
	DEFB 	Delimiter							;; Delimiter (ID &EF)

;; -----------------------------------------------------------------------------------------------------------
;; Reminder: ASCII table:
;;      0 1 2 3 4 5 6 7 8 9 A B C D E F
;; 20 :' '! " & $ % & ' ( ) * + , - . /
;; 30 : 0 1 2 3 4 5 6 7 8 9 : ; < = > ?
;; 40 : @ A B C D E F G H I J K L M N O
;; 50 : P Q R S T U V W X Y Z [ \ ] updw
;; 60 : RtLfb c d e f g h i j k l m n o
;; 70 : p q r s t u v w x y z { | ] ~
;;
;; Keyboard Matrix
;; Bit										Line Num
;; num 		0 			1 			2 		3 	4 	5 		6 				7 	8 			9
;; 7		f.			f0			Ctrl	>,	<.	Space	V				X	Z			Del
;; 6		Enter		f2			`\		?/	M	N		B				C	CapsLock	Unused
;; 5		f3			f1			Shift	*:	K	J		F  / Joy1Fire1	D	A			Joy0Fire1
;; 4		f6			f5			f4 		+;	L	H		G  / Joy1Fire2	S	Tab			Joy0Fire2
;; 3		f9			f8			}]		P	I	Y		T  / Joy1Right	W	Q			Joy0Right
;; 2		CursorDown	f7			Return	|@	O	U		R  / Joy1Left	E	Esc			Joy0Left
;; 1		CursorRight	Copy		{[		=-	)9	'7		%5 / Joy1Down	&3	"2			Joy0Down
;; 0		CursorUp	CursorLeft	Clr		Â£^	_0	(8		&6 / Joy1Up		$4	!1			Joy0Up

;; -----------------------------------------------------------------------------------------------------------
;; This table will be used to convert a keyboard key code to a printable char or string.
;; (scan line * 8) + bitnb, or can be seen as [7:3]=scan line and [2:0]=bitnb.
;; These are therefore listed in the keyboard scan order: line0 to line9 and bit 0 to 7
.Char_Set:		              												;;     bit:  0    1    2   3     4   5    6    7
	DEFB 	&5E, &60, &5F, &39, &36, &33, &8C, &2E		;; (line 0) "Up", "Right", "Down", "9", "6", "3", "|RETURN", "."
	DEFB 	&61, &E6, &37, &38, &35, &31, &32, &30		;; (line 1) "Left", "COPY", "7", "8", "5", "1", "2", 0"
	DEFB 	&E7, &5B, &8C, &5D, &34, &8D, &5C, &E5		;; (line 2) "CLR", "[", "|RETURN", "]", "4", "|SHIFT", "\", "CTRL"
	DEFB 	&5E, &2D, &40, &50, &3B, &3A, &2F, &2E		;; (line 3) "^", "-", "@", "P", ";", ":", "/", ","
	DEFB 	&30, &39, &4F, &49, &4C, &4B, &4D, &2C		;; (line 4) "0", "9", "O", "I", "L", "K", "M", "."
	DEFB 	&38, &37, &55, &59, &48, &4A, &4E, &EE		;; (line 5) "8", "7", "U", "Y", "H", "J", "N", "SPACE"
	DEFB 	&36, &35, &52, &54, &47, &46, &42, &56		;; (line 6) "6", "5", "R", "T", "G", "F", "B", "V"
	DEFB 	&34, &33, &45, &57, &53, &44, &43, &58		;; (line 7) "4", "3", "E", "W", "S", "D", "C", "X"
	DEFB 	&31, &32, &E2, &51, &E3, &41, &E1, &5A		;; (line 8) "1", "2", ESC, "Q", TAB, "A", LOCK, "Z"
	DEFB 	&EA, &EB, &ED, &EC, &E9, &E9, &58, &E4		;; (line 9) JOYU, JOYD, JOYL, JOYR, JOYF, JOYF, (unused), DEL

;; -----------------------------------------------------------------------------------------------------------
;; These are the map codes for the keyboard (CPC 6128) when scanning the
;; keyloard lines, in order to check if the wanted key is pressed or not.
;; For exemple, if, while scanning the keyboard lines, at line1, bit0,
;; (current offset = 1*8 + 0 = 8 (9th value)) the value returned by the
;; AY-3 is "FE", the matching (reg OR map) will result in "FE" (ie. non-FF)
;; indicating that the "Left" arrow key is being pressed. (active low)
.Array_Key_map:			;;		Lft  Rgt  Dwn  Up _ Jmp  Cry  Fir  Swp		;			Left  Rgt   Down  Up   Jump  Carry  Fire  Swop
	DEFB 	&FF, &FD, &FB, &FE, &FF, &1F, &EF, &F7		;; line 0 : ___ , RGT , DWN , UP  , ___ , RET3., F6 ,  F9
	DEFB 	&FE, &FF, &FF, &FF, &FD, &1F, &EF, &F3		;; line 1 : Left, ___ , ___ , ___ , Copy, F120,  F5 , F7F8
	DEFB 	&FF, &FF, &FF, &FF, &FF, &FF, &EF, &FF		;; line 2 : ___ , ___ , ___ , ___ , ___ , ___ ,  F4 , ___
	DEFB 	&FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF		;; line 3 : nothing
	DEFB 	&FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF		;; line 4 : nothing
	DEFB 	&FF, &FF, &FF, &FF, &7F, &7F, &FF, &FF		;; line 5 : ___ , ___ , ___ , ___ , SPC , SPC , ___ , ___
	DEFB 	&FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF		;; line 6 : nothing
	DEFB 	&FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF		;; line 7 : nothing
	DEFB 	&FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF		;; line 8 : nothing
	DEFB 	&FB, &F7, &FD, &FE, &EF, &FF, &FF, &FF		;; line 9 : JoyL, JoyR, JoyD, JoyU, JoF2, ___ , ___ , ___

;; -----------------------------------------------------------------------------------------------------------
;; Scan the keyboard;
;; Output: A = 0: a key was pressed;
;;         A != 0: no key pressed;
;; If a key has been pressed, the key map index is in B
;; (B[7:3] = line_number ; B[2:0] = active_bit_number)
.Scan_keyboard:
	LD 		HL,KeyScanningBuffer						;; buffer for scanned keys
	CALL 	Keyboard_scanning_setup						;; init key board scanning
	LD 		C,&40										;; Select keyboard line scanning 0 (BC=F740)
scan_loop_1:
	LD 		B,&F6										;; Setup PSG (Keyboard feature) for Read reg (BC=F640)
	OUT 	(C),C
	LD 		B,&F4										;; BC=F4xx
	IN 		A,(C)										;; ead line status (Read keyboard line 0)
	INC 	A
	JR 		NZ,find_key_pressed							;; if was not FF (something was pressed then find_key_pressed), else:
	INC 	HL											;; next line
	INC 	C											;; next key
	LD 		A,C
	AND 	&0F
	CP 		10											;; have we reached last keyboard line?
	JR 		c,scan_loop_1								;; no: scan_loop_1, else :
	CALL 	Keyboard_scanning_ending					;; end keyboard scanning
	INC 	A											;; Return with A != 0 : nothing pressed
	RET

find_key_pressed:
	DEC 	A											;; restore real line scan value (INC A done at 0A02)
	LD 		BC,&FF7F          							;; this will produce B=0 and C=FE
fkp_1:
	RLC 	C
	INC 	B
	RRA
	JR 		c,fkp_1										;; test every bit until we find an unset one, B will gave the bit number
	LD 		A,L											;; L = line number + &C0
	SUB 	&C0											;; A=line number
	ADD 	A,A
	ADD 	A,A
	ADD 	A,A											;; line number << 3 (*8)
	ADD 	A,B											;; A[7:3] = line_number ; A[2:0] = active_bit_number = index in key map table
	LD 		B,A											;; store value in B
	EXX
	CALL 	Keyboard_scanning_ending					;; end keyboard scanning
	EXX
	XOR 	A											;; Return with A = 0 : something pressed (value in B)
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Given a Char_Set key code index in B, get the printable character for it in A.
;; eg. B = &26 will return A = &4D ("M", keyboard scan line 4 in B[7:3],
;; bitnb=6 in B[2:0], or B=(4*8)+6 = 38 = &26)
.GetCharStrId:
	LD 		A,B
	ADD 	A,Char_Set and &00FF						;; &52 = Char_Set & &00FF
	LD 		L,A
	ADC 	A,Char_Set / 256							;; &09 = (Char_Set & &FF00) >> 8 + char_offset in B
	SUB 	L
	LD 		H,A											;; HL = Char_Set + char_offset
	LD 		A,(HL)										;; get printable code in A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Check if a key has been pressed and released.
.Wait_anykey_released:
	CALL 	Scan_keyboard								;; A = 0: a key was pressed; A != 0: no key pressed;
	JR 		Z,Wait_anykey_released						;; loop Wait_anykey_released if a key is still pressed
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Test if Enter of Shift has been pressed
;; Output: Carry=1 (and NZ): no key pressed, A=non-0
;;    else Carry=0 (and Z) and C=0: Enter, C=1: Shift, C=2: other, A=0
.Test_Enter_Shift_keys:
	CALL 	Scan_keyboard 								;; returns A=0 if a key is pressed and also B[7:3] = line_number ; B[2:0] = active_bit_number, hence B = keymap index
	SCF													;; Set Carry flag
	RET 	NZ											;; RET (with Carry=1) if nothing pressed
	LD 		A,B											;; key map index ((scanline*8)+bitnb)
	LD 		C,0											;; prepare output value C=0
	CP 		&12											;; test if line=B[7:3]=2 and bitnb=B[2:0]=2, in other words the "Enter/Return" key
	RET 	Z											;; if "Enter/Return" key pressed, exit with BC=xx00, Carry=0
	INC 	C											;; output value: C=1
	CP 		&15											;; test if line=B[7:3]=2 and bitnb=B[2:0]=5, in other word the "Shift" key
	RET 	Z											;; else if "Shift" key pressed, exit with BC=xx01, Carry=0
	INC 	C											;; output value: C=2
	XOR 	A											;; A=0, Carry = 0
	RET													;; else (any other key) return with A=0 and BC=xx02

;; -----------------------------------------------------------------------------------------------------------
;; Input: A = key map index we want to point ((scan line * 8) + bitnb)
;; Output: HL : the address of the key map data for the wanted key
.Get_Key_Map_Addr:
	LD 		DE,Array_Key_map							;; point on Array_Key_map
	LD 		L,A
	LD 		H,0											;; HL = A , offset in the table
	ADD 	HL,DE										;; HL = DE + A : add offset in A, HL points on wanted key in Array_Key_map
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Used by the "Controls" Menu to list all assigned keys.
.ListControls:
	CALL 	Get_Key_Map_Addr
	LD 		C,0
lc_3:
	LD 		A,(HL)
	LD 		B,&FF
lc_0:
	CP 		&FF
	JR 		Z,lc_2
lc_1:
	INC 	B
	SCF
	RRA
	JR 		c,lc_1
	PUSH 	HL
	PUSH 	AF
	LD 		A,C
	ADD 	A,B
	PUSH 	BC
	LD 		B,A
	CALL 	GetCharStrId
	CALL 	PrintCharAttr2									;; clear the end of line
	POP 	BC
	POP 	AF
	POP 	HL
	JR 		lc_0

lc_2:
	LD 		DE,&0008
	ADD 	HL,DE
	LD 		A,C
	ADD 	A,&08
	LD 		C,A
	CP 		&50
	JR 		c,lc_3
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Used by the "Controls" Menu to Edit the assigned keys.
.Edit_control:
	CALL 	Get_Key_Map_Addr
	PUSH 	HL
	CALL 	Wait_anykey_released
	LD 		HL,KeyScanningBuffer							;; buffer to erase
	LD 		E,&FF											;; erase value = &FF
	LD 		BC,&000A										;; 10 values
	CALL 	Erase_block_val_in_E
ec_wait:
	CALL 	Scan_keyboard 									;; (returns A=0 if a key is pressed; also BC=F740)
	JR 		NZ,ec_wait
	LD 		A,B
	CP 		&12
	JR 		Z,ec_1
ec_0:
	LD 		A,C
	AND 	(HL)
	CP 		(HL)
	LD 		(HL),A
	JR 		Z,ec_wait
	CALL 	GetCharStrId
	CALL 	PrintCharAttr2									;; clear end of line
	LD 		HL,(Char_cursor_pixel_position)
	PUSH 	HL
	LD 		A,Print_StrID_Enter2Finish						;; String_ID A5 "Press Enter to finish"
	CALL 	Print_String
	CALL 	Wait_anykey_released
	POP 	HL
	LD 		(Char_cursor_pixel_position),HL
	LD 		A,&C0
	SUB 	L
	CP 		&14
	JR 		NC,ec_wait
ec_1:
	EXX
	LD 		HL,KeyScanningBuffer							;; buffer
	LD 		A,&FF
	LD 		B,10											;; 10 scan lines
ec_1_loop:
	CP 		(HL)
	INC 	HL
	JR 		NZ,ec_2
	DJNZ 	ec_1_loop
	EXX
	LD 		A,&12
	JR 		ec_0

ec_2:
	POP 	HL
	LD 		BC,&0008
	LD 		A,10
	LD 		DE,KeyScanningBuffer							;; buffer
ec_3:
	EX 		AF,AF'
	LD 		A,(DE)
	LD 		(HL),A
	INC 	DE
	ADD 	HL,BC
	EX 		AF,AF'
	DEC 	A
	JR 		NZ,ec_3
	JP 		Wait_anykey_released

;; -----------------------------------------------------------------------------------------------------------
;; This is used on the "Select the keys" Menu;
;; Note that some of the keys have an attribute attached to them
;;     (eg. Char Id &8C = "|RETURN").
;; But most keys do not have an attribute attached, so this function
;; will attached a color attribute.
;;   &83 (yellow on that page) for the arrows, the numbers, the dot.
;;        (ie. all keyboard scanline 0 & 1, plus the "4" on scanline 2)
;;   &82 (darkblue) for anything else (again, except if they have an
;;       attribute attached)
;; Input: B = Key scan code index in Char_Set array
;;        A = corresponding printable Character
;; Output: None
.PrintCharAttr2:
	PUSH 	AF											;; save printable character
	LD 		A,B											;; get key code
	CP 		&14											;; compare it with &14 (key code for "4" on keyboard scan line 2 in [7:3], bitnb 4 in [2:0])
	JR 		Z,pca2_1									;; if keycode = &14 goto pca2_1 (use color attribute &83), else:
	CP 		&10											;; compare A >= &10 (scan lines 2 and above)
	LD 		A,Print_Color_Attr_2						;; default attribute &82
	JR 		NC,pca2_2									;; if A >= &10 goto pca2_2 (use attribute color &82 for anything on scan lines 2 and above), else:
pca2_1:																		;; scan lines 0 and 1 (arrows, numbers (except "4"), ".")
	LD 		A,Print_Color_Attr_3						;; use color attribute &83
pca2_2:
	CALL 	Print_String								;; Apply the color attribute
	POP 	AF											;; get back the printable character and print it
	JP 		Print_String								;; Print; will RET

;; -----------------------------------------------------------------------------------------------------------
;; Read user inputs, scan the keyboard and returns A so that
;; from MSb to LSb ("CFSLRDUJ" format, active low bits):
;; 		bit7:Carry, Fire, Swop, Left, Right, Down, Up, bit0: Jump
.Get_user_inputs:
	CALL 	Keyboard_scanning_setup						;; setup "PSG" for keyboard scanning
	LD 		C,&40										;; keyboard scan line 0
	LD 		A,&FF										;; init map code A=FF
	LD 		HL,Array_Key_map							;; point on Array_Key_map array
	EX 		AF,AF'										;; save init map code
gui_0:
	LD 		B,&F6										;; Set PSG for Read reg BC=F640 (to read keyboard)
	OUT 	(C),C
	LD 		B,&F4										;; BC=F4xx
	IN 		E,(C)										;; Read PSG reg E=key scan current line
	LD 		B,8											;; need to test each of the 8 bits in current line
gui_1:
	LD 		A,(HL)										;; get current keymap code
	OR 		E											;; if from reg read, a bit is 0: corresponding key pressed, else (not pressed) it"ll fill in the expected key code to "turn it off"
	CP 		&FF											;; result is &FF : Result has been fully filled with 1s (nothing pressed)
	CCF													;; Invert Carry bit (Carry set if nothing pressed, Carry reset if something pressed)
	RL 		D											;; rotate D Left and put Carry bit in D lowest bit
	INC 	HL											;; next keymap value
	DJNZ 	gui_1										;; loop all 8 bits
	EX 		AF,AF'										;; restore A (collecting all the keys pressed)
	AND 	D											;; each bit of D will represent a function (up, down ...) active low; accumulate all the keys found.
	EX 		AF,AF'										;; save A
	INC 	C											;; next line
	LD 		A,C
	CP 		&4A											;; until last line (&40 (scan line 0) + &0A (lastline+1))
	JR 		c,gui_0										;; loop next line
	EX 		AF,AF'										;; restore A : from MSb to LSb : Left, Right, Down, Up, Jump, Carry, Fire, Swop
	RRCA                    							;; bits are not in the order we want (they are in key scan order)
	RRCA												;; so rotate them 3x until we have:
	RRCA												;; from MSb to LSb : Carry, Fire, Swop, Left, Right, Down, Up, Jump (active low)
	JR 		Keyboard_scanning_ending					;; end the keyboard scanning

;; -----------------------------------------------------------------------------------------------------------
;; Test if the "ESC" key has been pressed
;; Note : Line 8 bit 2 = "ESC" key
;; Output: A = 0 if "ESC" pressed; not-0 : "ESC" is not pressed.
.Keyboard_scanning_ESC:
	CALL 	Keyboard_scanning_setup						;; Setup keyboard scanning
	LD 		BC,&F648									;; PortC, Read PSG reg, keyboard write, line select 8
	OUT 	(C),C
	LD 		B,&F4										;; PortA, Read keyboard Data
	IN 		A,(C)										;; Read Keyboard line value
	AND 	&04											;; test bit 2 of line 8; if A=0 : "ESC" Pressed else not pressed
	JR 		Keyboard_scanning_ending					;; End keyboard scanning

;; -----------------------------------------------------------------------------------------------------------
;; This will setup the PSG for keyboard scanning
.Keyboard_scanning_setup:
	DI													;; Disable Interrupt during keyboard scanning
	LD 		BC,&F40E									;; select PSG reg14 (Keyboard Reg)
	OUT 	(C),C
	LD 		BC,&F600									;; prepare PSG Control (Keyboard feature)
	LD 		A,&C0										;; line 0 + &C0
	OUT 	(C),A										;; PSG control : reg select (reg value on portA = reg14)
	OUT 	(C),C										;; Validate
	INC 	B				 							;; Port Control BC=F700
	LD 		A,&92										;; Port A in, Port C out
	OUT 	(C),A										;; Write config to PSG
	RET

;; -----------------------------------------------------------------------------------------------------------
;; This will end the keyboard scanning in the PSG
.Keyboard_scanning_ending:
	LD 		BC,&F782									;; PortA (PSG DATA) as Output
	OUT 	(C),C
	LD 		BC,&F600									;; PSG inactive
	OUT 	(C),C
	EI													;; Enable Interrupts
	RET

;; -----------------------------------------------------------------------------------------------------------
;; This will configure all 11 "Sound related" register in the AY-3 (PSG)
;; The data must be placed in the AY_Registers array
.Write_AY3_Registers:
	LD 		HL,AY_Registers
	LD 		D,0											;; reg number
wa3r_1:
	LD 		E,(HL)										;; reg data
	INC 	HL											;; point on next data
	CALL 	SubF_Write_AY3Reg
	INC		D											;; next reg
	LD 		A,D
	CP 		11											;; Last one?
	JR 		NZ,wa3r_1									;; no: loop, else RET
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Sub function for Write_AY3_Registers (write one AY-3 reg)
;; Input: D = reg number, E = value
.SubF_Write_AY3Reg:
	LD 		B,&F4										;; prepare PSG Data
	OUT 	(C),D										;; reg number in D  (F4dd)
	LD 		BC,&F600									;; prepare PSG Control
	LD 		A,&C0										;; PSG Reg select
	OUT 	(C),A										;; control byte = reg select (F6C0)
	OUT 	(C),C										;; PSG Control (F600)
	LD 		A,&80										;; PSG reg Write
	LD 		B,&F4										;; prepare PSG Data
	OUT 	(C),E										;; data in E  (F4ee)
	LD 		B,&F6										;; prepare PSG Control
	OUT 	(C),A										;; control byte=reg write (F680)
	OUT 	(C),C										;; PSG Control (F600)
	RET

;; -----------------------------------------------------------------------------------------------------------
;; This table will define the period value for the lowest octave
;; (octave 1, with the "standard A440 octave being 4).
;; The other octaves values are calculated from these base values
.Notes_periodes_Lowest_Octave:
	DEFW 	&0EEE  					;; &0EEE=3822  Do octave=1 num=0   	32.7Hz (lowest Bass note on CPC)
	DEFW 	&0E18 					;; &0E18=3608  Do#   oct=1 num=1   	34.6
	DEFW 	&0D4D 					;; &0D4D=3405  Re    oct=1 num=2   	36.7
	DEFW 	&0C8E 					;; &0C8E=3214  Re#   oct=1 num=3   	38.9
	DEFW 	&0BDA 					;; &0BDA=3034  Mi    oct=1 num=4   	41.2
	DEFW 	&0B2F 					;; &0B2F=2863  Fa    oct=1 num=5   	43.6
	DEFW 	&0A8F 					;; &0A8F=2703  Fa#   oct=1 num=6   	46.2
	DEFW 	&09F7 					;; &09F7=2551  Sol   oct=1 num=7   	49
	DEFW 	&0968 					;; &0968=2408  Sol#  oct=1 num=8   	51.9
	DEFW 	&08E1 					;; &08E1=2273  La    oct=1 num=9   	55
	DEFW 	&0861 					;; &0861=2145  La#   oct=1 num=0xA	58.3
	DEFW 	&07E9 					;; &07E9=2025  Si    oct=1 num=0xB	61.7
	DEFW 	&0777 					;; &0777=1911  Do    oct=2 num=0xC	65.4

;; -----------------------------------------------------------------------------------------------------------
;; Check if (Voice0) Sound is enable (bit7=0; disable if 1)
;; If enabled, then play Theme song.
.Play_HoH_Tune:
	LD 		A,(Sound_Voice0_status)						;; Get Sound_enable value for Voice0
	CP 		%10000000									;; is sound enabled? bit7 active low
	RET 	Z											;; No, then leave; else:
	LD 		B,Sound_ID_Theme							;; else Play Sound_ID &C3 = HeadOverHeels main theme
	JP 		Play_Sound									;; will RET

;; -----------------------------------------------------------------------------------------------------------
;; This will play some music by INTerrupts
.sub_IntH_play_update:
	LD 		A,(Sound_channels_enable)					;; bit7 = Sound_enable ; Sound Volume level/amount
	RLA													;; put bit7 in Carry (Sound_Enable)
	RET 	NC											;; if Sound not enabled, then leave
	CALL 	Sound_Update								;; else update sound
	XOR 	A											;; set voice 0
	LD 		(Current_sound_voice_number),A				;; update current voice number
	LD 		A,&3F										;; Disable all voices in mixer
	LD 		(AY_Registers+AY_MIXER),A					;; reg7 is AY3_Mixer_control, bits are active low
	LD 		HL,Current_sound_voice_number				;; point on Current sound voice number
loop_play_tune:
	LD 		B,(HL)										;; B = voice number
	CALL 	Get_enable_voice_in_B						;; if the voice in B enabled?
	JR 		c,play_tune_voice_skip						;; if voice NOT enabled (Carry set), skip voice (play_tune_voice_skip), else:
	CALL 	Get_current_Voice_data_in_HL
	PUSH	 HL											;; put data pointer...
	POP 	IX											;; ... in IX = Voice data array (19 bytes)
	BIT 	5,(HL)										;; test bit5 SND_FLAGS
	JR 		NZ,play_tune_voice_skip						;; if bit5 not set, then skip (play_tune_voice_skip)
	LD 		IY,AY_Registers								;; IY points on AY_Registers
	LD 		E,A											;; DE = current voice number (0, 1 or 2)
	LD 		D,0
	PUSH 	DE											;; store current voice number
	SLA 	E											;; E*2
	ADD 	IY,DE										;; IY = AY_Registers pointer + offset by voice_number*2 (pitch regs)
	LD 		HL,AY_Registers+AY_A_VOL					;; HL = reg8, Channel_A_Volume
	POP 	DE											;; restore current voice number
	ADD 	HL,DE										;; HL now point on Channel_A_Volume, B or C depending on voice number
	;; IX : Voice_channel_<N>_data
	;; IY : AY_Registers + Channel offset (0, 1 ro 2)
	LD 		A,(IX+SND_FINE)								;; get fine pitch value from data array for curr channel A+offset (Channel Tone Frequency Low 8bits)
	LD 		(IY+AY_A_FINE),A							;; set fine pitch value in reg array
	LD 		A,(IX+SND_COARSE)							;; get coarse pitch value from data array (Channel Tone Frequency High 4bits)
	LD 		(IY+AY_A_COARSE),A							;; set coarse pitch value in reg array
	LD 		B,D											;; B = current voice number
	LD 		E,(IX+SND_VOL_PTR_L)
	LD 		D,(IX+SND_VOL_PTR_H)						;; DE = array[2] and [1] = volume array pointer
	EX 		DE,HL										;; and put it in HL
	LD 		C,(IX+SND_VOL_INDEX)						;; get array[3] in C = volume array index
	ADD 	HL,BC										;; add it to HL
	EX 		DE,HL										;; and put it back in DE
	LD 		A,(DE)										;; get current volume value
	AND 	&0F											;; keep Bottom 4 bits only
	JR 		Z,lpt_1										;; if value not 0 do this (else jump lpt_1)
	ADD 	A,(IX+SND_VOL_LEVEL)						;; Add "volume addition" from array [11]
	CP 		&10											;; Compare A and &10
	JR 		c,lpt_1										;; if A < &10 then:
	LD 		A,&0F										;; clamp at &0F
lpt_1:
	LD 		(HL),A										;; write new value of volume into AYregister Channel_A_Volume, B or C depending on voice number
	LD 		A,(Current_sound_voice_number)				;; get Current sound voice number
only_this_voice_bitmask:
	LD 		B,A
	INC 	B											;; B now is the bit number corresponding to the current voice number (B=&01 means 1st bit therefore bit0)
	LD 		A,&FF										;; set the init mask
	AND 	A											;; this clears the Carry
otvb_loop:
	RLA													;; this will move a 0 bit at the location depending on the value in B (B=&01:A=&FE (bit 0 reset); B=&02:A=&FD (bit1 reset), etc.)
	DJNZ 	otvb_loop									;; loop B times
activate_current_voice:														;; mask in A enable (active low) the current channel in the mixer
	LD 		HL,AY_Registers+AY_MIXER					;; reg7 is AY3_Mixer_control
	AND 	(HL)										;; Notes are active_low, so read and activate current voice (mask in A)
	LD 		(HL),A										;; and update mixer reg7 value
.play_tune_voice_skip:
	LD 		HL,Current_sound_voice_number				;; point on Current sound voice number
	LD 		A,&02
	CP 		(HL)										;; test if current voice is 2 (3rd one)
	JP 		Z,continue_tune								;; Finish the 3 voices? if yes goto continue_tune
	INC 	(HL)										;; next voice
	JR 		loop_play_tune 								;; (loop the 3 channels)

continue_tune:
	LD 		HL,Voice_channel_0_data						;; points on current voice data array (19-bytes)
	LD 		A,&08										;; get value in current channel status flag reg ...
	XOR 	(HL)										;; and invert bit3 for test
	AND 	&28											;; keep bits 5 and 3; if voice0 first byte has "&20", write Sound state
	JP 		NZ,Write_AY3_Registers						;; if flag bits 5 and 3 were not 0 and 0, Write_AY3_Registers, will RET, else:
	;; else noise
	LD 		A,(Sound_channels_enable)					;; get Sound volume/amount
	RRA													;; bit0 goes in Carry
	JP 		c,Write_AY3_Registers						;; if bit0 was 1, then Write_AY3_Registers (write sound state), will RET, else:
	LD 		HL,AY_Registers+AY_NOISE					;; reg6 is AY3_Noise reg (5 bits)
	LD 		IY,Voice_Noise_data							;; IY = Voice_Noise_data (noise)
	LD 		A,(IY+&07)									;; get noise channel data IY[7] ???NOISE_COARSE???
	LD 		(HL),A										;; update noise data in reg array
	INC 	HL											;; point on next reg
	LD 		A,(IY+0)									;; get noise channel data IY[0]
	AND 	%00000001									;; keep value of bit0
	OR 		(HL)										;; ????TODO if bit0 was set then copy value in HL and set b0 ?????
	AND 	&F7											;; enable noise Channel A gen (keep the other bits as they are)
	LD 		(HL),A										;; update reg value
	JP 		Write_AY3_Registers							;; will RET

;; -----------------------------------------------------------------------------------------------------------
;; Run through all 3 voices. If a voice is enabled, call UpdateVoice.
.Sound_Update:
	XOR 	A											;; reset voice number to 0
	LD 		(Current_sound_voice_number),A				;; update Current sound voice number
sound_Update_next_voice:
	LD 		B,A											;; voice we want to check in B
	CALL 	Get_enable_voice_in_B						;; voice in reg B enabled?
	CALL 	NC,Update_Voice								;; Carry reset = voice enabled do Update_Voice, Carry set, do nothing
	LD 		HL,Current_sound_voice_number				;; point on Current sound voice number
	LD 		A,(HL)										;; A = current voice
	CP 		&02											;; is it 2 (last one)
	RET 	Z											;; if reached voiced 2 then RET
	INC 	A											;; else do it for next voice number
	LD 		(HL),A										;; update Current_sound_voice_number
	JR 		sound_Update_next_voice						;; loop

;; -----------------------------------------------------------------------------------------------------------
;; Read the Nth bit from Sound_channels_enable into the Carry flag.
;; Bit is active low (ie. enables if 0)
;; Input: B = bit number we want to read from Sound_channels_enable.
;; Output: Carry = value for that bit
.Get_enable_voice_in_B:
	LD 		A,(Sound_channels_enable)					;; A = Sound_enable, Sound volume/amount
	INC 	B											;; B is now bit_number current voice + 1, beacause to get bit nb 2 in Carry, we need to rotate right 3 times
gsebcv_loop:
	RRCA												;; loop until the chosen voice...
	DJNZ 	gsebcv_loop									;; ...Sound_Enable bit is in Carry flag
	RET													;; if Carry = reset then current voice enable, else if Carry set, voice disabled

;; -----------------------------------------------------------------------------------------------------------
.Update_Voice:
	LD 		HL,Current_sound_voice_number				;; point on Current sound voice number
	LD 		L,(HL)
	LD 		DE,curr_Voice_data_addr
	LD 		H,0											;; (H)L = current voice number
	ADD 	HL,HL										;; *2
	ADD 	HL,DE										;; add voice_num*2 offset to curr_Voice_data_addr
	LD 		(curr_Voice_data_pointer),HL				;; store curr_Voice_data_addr+voice_offset in curr_Voice_data_pointer (104E)
	LD 		E,(HL)
	INC 	HL
	LD 		D,(HL)										;; DE = data offset
	PUSH 	DE
	POP 	IX											;; store offset in IX
	CALL 	Get_current_Voice_data_in_HL				;; add voice number * 19 bytes as needed to point on raay we want
	PUSH 	HL
	POP 	IY											;; Voice_channel<n>_data pointer in IY (and in HL)
	BIT 	1,(HL)										;; test bit1 of SND_FLAGS for the current voice
	JP 		NZ,Parse_voice_data_begining				;; if '1' parse the 2 first bytes of the corresponding voice data
	DEC 	(IY+SND_NOTE_DURATION)						;; decr SND_NOTE_DURATION (+0D offset)
	JR 		NZ,uvoi_1									;; if duration is not 0
	CALL 	Sound_Continue_Parse_data					;; continue parsing voice data bytes
	BIT 	3,(IY+SND_FLAGS)							;; test bit3 of SND_FLAGS
	RET 	Z											;; if '0' leave, else noise:
	LD 		IY,Voice_Noise_data							;; continue to handle noise if necessary
	XOR 	A											;; A = 0
	LD 		(IY+SND_VOL_INDEX),A						;; reset Volume index
	JP 		Func_0D2A

uvoi_1:
	DEC 	(IY+SND_CURR_FX_SLICE)						;; dec value in array [4] (its init value is in [5])
	CALL 	Z,Parse_volume_Envp_data					;; if 0 get next volume envp data
	LD 		L,(IY+SND_FINE)								;; read note period low byte
	LD 		H,(IY+SND_COARSE)							;; read note period high byte
	BIT 	7,(IY+SND_FLAGS)							;; test status flag bit7
	JR 		Z,sub_uvoi_2								;; if 0 jump sub_uvoi_2, else
	LD 		A,1											;; A = 1
	BIT 	7,(IY+SND_EFFECT_TARGET)					;; test SND_EFFECT_TARGET bit 7
	JR 		Z,uvoi_2									;; if 0 jump sub_uvoi_2 with A=1, else
	LD 		A,-1										;; A = -1 (&FF)
uvoi_2:
	ADD 	A,(IY+SND_DELTA_COARSE)						;; incr or decr the delta
	LD 		(IY+SND_DELTA_COARSE),A						;; update the sound delta pitch high byte value in array[&F] (for bend or vibrato effect?)
	LD 		B,A
	LD 		A,(IY+SND_EFFECT_TARGET)					;; target value
	CP 		B
	JR 		NZ,uvoi_3
	NEG													;; A*(-1) (invert sign)
	LD 		(IY+SND_EFFECT_TARGET),A					;; update
	NEG													;; A*(-1) (invert sign)
uvoi_3:
	LD 		E,(IY+SND_DELTA_FINE)						;; delta pitch low byte (sound) for effects (bend/vibrato)
	LD 		D,0
	RLCA
	JR 		c,sub_uvoi_1
	SBC 	HL,DE										;; Note +/- delta (next note up or next note down)
	JR 		sub_uvoi_2

sub_uvoi_1:
	ADD 	HL,DE										;; update sound pitch with delta pitch
sub_uvoi_2:
	LD 		A,(IY+SND_FLAGS)							;; get status flag
	AND 	&50											;; look at bits 6 (noise 1, sound 0) and 4
	CP 		&40											;; test if noise
	JR 		NZ,sub_uvoi_3								;; if not noise jump (sound), else (bit6=1 noise; bit4 = 0)
	;; if Noise
	LD 		E,(IY+NOISE_DELTA_FINE)
	LD 		D,(IY+NOISE_DELTA_COARSE)					;; get noise delta pitch (for effects, bend/vibrato)
	ADD 	HL,DE
	LD 		D,H
	LD 		E,L
	LD 		C,(IY+NOISE_FINE)
	LD 		B,(IY+NOISE_COARSE)							;; and update noise pitch from it
	XOR 	A
	SBC 	HL,BC
	RLA
	XOR 	(IY+SND_FLAGS)
	AND 	%00000001									;; test bit0
	EX 		DE,HL
	JR 		NZ,sub_uvoi_3
	SET 	4,(IY+SND_FLAGS)
	XOR 	A
	LD 		(IY+SND_DELTA_COARSE),A						;; sound delta pitch high byte = 0
	LD 		L,(IY+NOISE_FINE)
	LD 		H,(IY+NOISE_COARSE)							;; HL = noise pitch
sub_uvoi_3:
	LD 		(IY+SND_FINE),L
	LD 		(IY+SND_COARSE),H							;; update note period
	BIT 	3,(IY+SND_FLAGS)							;; test bit 3 of status flag
	RET 	Z											;; leave if 0
	LD 		IY,Voice_Noise_data							;; else (noise array)
	DEC 	(IY+SND_CURR_FX_SLICE)						;; decrease current effect delta index
	RET 	NZ											;; ret if not 0, else:
.Func_0D2A:
	CALL 	Parse_volume_Envp_data						;; process volume enveloppe data; returns the number of effect slices
	AND 	A											;; test
	JR 		NZ,f_0a2a_1									;; if not 0, jump f_0a2a_1
	OR 		(IY+SND_VOL_INDEX)							;; if 0, get current index in volume array
	RET 	NZ											;; if index note reset, leave
f_0a2a_1:
	LD 		A,(HL)
	AND 	&0F
	BIT 	7,(IY+SND_FLAGS)							;; test bit7 of status flag
	JR 		Z,f_0a2a_2
	NEG													;; invert A sign (*(-1))
f_0a2a_2
	ADD 	A,(IY+NOISE_FINE)							;; update noise pitch
	LD 		(IY+NOISE_COARSE),A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Read selected Volume enveloppe current data
;; bit7 : stop if '1' (reached the end of the enveloppe data and stop there)
;; bit6 : loop back to start if '1' (reached the end of the enveloppe data
;;         and loop from start of data until all effect slices have been done)
;; bits 5:0 : volume level
;; Returns in A the number of effect slices
.Parse_volume_Envp_data:
	LD 		L,(IY+SND_VOL_PTR_L)
	LD 		H,(IY+SND_VOL_PTR_H)						;; HL = volume array pointer
	LD 		E,(IY+SND_VOL_INDEX)						;; E = index
	XOR 	A
	LD 		D,A											;; DE = index in that array
	ADD 	HL,DE										;; point on the value at that index
	BIT 	7,(HL)										;; test bit7 of the volume value
	JR 		NZ,vol_envp_end								;; jump vol_envp_end if bit7=1, else (bit7=0):
	BIT 	6,(HL)										;; test bit6 of the volume value
	JR 		Z,vol_envp_nextbyte							;; skip to vol_envp_nextbyte if 0, else:
	BIT 	2,(IY+SND_FLAGS)							;; test previous status flag bit2 state
	SET 	2,(IY+SND_FLAGS)							;; and set it
	JR 		Z,f_0d46_3									;; jump f_0d46_3 if was previously 0 else
	RES 	2,(IY+SND_FLAGS)							;; reset it
	LD 		(IY+SND_VOL_INDEX),A						;; reset index value to 0
	JR 		f_0d46_3									;; jump f_0d46_3

vol_envp_nextbyte:
	INC 	(IY+SND_VOL_INDEX)							;; increase index in volume envp array
f_0d46_3:
	LD 		A,(IY+SND_NB_FX_SLICES)						;; get init value of fx slices for volume envp
vol_envp_end:
	LD 		(IY+SND_CURR_FX_SLICE),A					;; reset current fx slices value for volume envp
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Disable_current_voice : Disable current sound voice
;; Disable_sound_bit : Disable sound voice, number in B
.Disable_current_voice:
	LD 		HL,Sound_Voice0_status						;; point on Sound_enable (Sound_Interrupt_data table)
	LD 		A,(Current_sound_voice_number)				;; get Current sound voice number
	LD 		E,A
	LD 		D,0
	ADD 	HL,DE										;; HL + offset voicenum
	LD 		(HL),&FF									;; put FF (disable)
	LD 		B,A
.Disable_sound_bit:															;; Convert voice number to corresponding bit number
	INC 	B											;; B = bit num for voice
	LD 		HL,Sound_channels_enable					;; pointer on Sound_enable ; HL = addr on Sound volume/amount
	XOR 	A											;; A = 0
	SCF													;; Set Carry
dsb_loop:
	RLA													;; Carry in b0 ; (b7 in carry)
	DJNZ 	dsb_loop									;; until voice number
	LD 		B,A
	OR 		(HL)										;; "Or" the mask into SndEnable.
	LD 		(HL),A										;; update Sound_enable
	RET

;; -----------------------------------------------------------------------------------------------------------
.Play_Sound:																;; B contains the sound Id to play.
	LD 		A,B											;; now A hold the Sound ID
	AND 	&3F											;; Mask off 0x3F, and if value is 0x3F, (re)make it 0xFF.
	CP 		&3F											;; 0x0?, 0x4?, 0x8? and 0xC? became 0x00 to 0x08
	JR 		NZ,play_sound_1								;; if sound ID [5:0] = &3F then make ID=&FF else goto play_Sound_1
	LD 		A,&FF
play_sound_1:
	LD 		C,A											;; C = 0 to 8 or &FF
	LD 		A,B											;; get back Sound_ID and Put bits [7:6] ...
	RLCA
	RLCA
	AND 	%00000011									;; ... in bits [1:0], clearing the other bits
	LD 		B,A
	CP 		&03											;; Sound_ID was 0xC<?> ?
	JR 		Z,Play_Sound_group_3						;; if it was, then jump Play_Sound_group_3, else:
	LD 		HL,Sound_Voice0_status						;; point on Sound_enable (Sound_Interrupt_data table)
	LD 		E,B											;; B = voice num?
	LD 		D,0											;; DE = voice num or ???? Sound group 0 (0x00-0x08), 1 (0x40-0x48) or 2 (0x80-0x88) as offset
	ADD 	HL,DE										;; Sound_Voice0_status+offset (0,1,2)
	LD 		A,(HL)
	CP 		C											;; C = 0 to 8 or &FF
	RET 	Z
	CP 		&80
	RET 	Z
	LD 		(HL),C
	LD 		A,C
	INC 	A
	JR 		Z,Disable_sound_bit
	LD 		HL,Sound_Groups								;; pointer on Sound_Groups
	SLA 	E
	ADD 	HL,DE
	LD 		A,(HL)
	INC 	HL
	LD 		H,(HL)
	LD 		L,A
	LD 		E,C
	SLA 	E
	ADD 	HL,DE
	LD 		A,(HL)
	INC 	HL
	LD 		H,(HL)
	LD 		L,A
	PUSH 	HL
	LD 		HL,Channels_voice_data_ptr					;; Pointer to voice data Channel0
	LD 		E,B
	SLA 	E
	ADD 	HL,DE
	PUSH 	HL
	LD		A,B
	CALL 	Get_Voice_data_in_HL
	LD 		D,H
	LD 		E,L
	LD 		B,A
	CALL 	Disable_sound_bit
	LD 		A,B
	POP 	HL
	POP 	BC
	LD 		(HL),C
	INC 	HL
	LD 		(HL),B
	EX 		DE,HL
	SET 	1,(HL)
	LD 		HL,Sound_channels_enable					;; HL = addr on Sound volume/amount
	XOR 	(HL)
	LD 		(HL),A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; HQ sound : 3-voice sounds
.Play_Sound_group_3:
	LD 		H,0
	LD 		L,C											;; HL=sound num in 0xC<num> group
	ADD 	HL,HL										;; *2
	LD 		D,H
	LD 		E,L											;; DE=HL
	ADD 	HL,HL										;; *4
	ADD 	HL,DE										;; HL = C * 6 (offset of 6 bytes = 3 * DEFWs)
	LD 		DE,Sound_High_table							;; Sound_High_table
	ADD 	HL,DE										;; Set HL to Sound_High_table + C * 6
	;; Read voice data pointer for next voice, push that and
    ;; updated Sound_High_table pointer.
	LD 		A,3											;; For each voice...
psid_3_loop:
	LD 		E,(HL)
	INC 	HL
	LD 		D,(HL)
	INC 	HL											;; get next DEFW in DE
	PUSH 	DE
	PUSH 	HL
	;; Get voice into HL.
	DEC 	A
	CALL 	Get_Voice_data_in_HL
	;; Bring Sound_High_table pointer back into DE, push voice pointer.
	POP 	DE
	PUSH 	HL
	;; HST pointer back in HL
	EX 		DE,HL
	AND 	A
	JR 		NZ,psid_3_loop
	;; Now we have 3 data/state pairs pushed on the stack.
    ;; Set bits [012] of SndEnable, to disable interrupt-driven
    ;; update while we modify.
	LD 		HL,Sound_channels_enable
	LD 		A,&07
	OR 		(HL)
	LD 		(HL),A
	;; Load &80 into the 3 elements of the IntSnd array.
	LD 		HL,Sound_Voice0_status						;; point on Sound_enable (Sound_Interrupt_data table)
	LD 		BC,&0380									;; write 3 times &80 from 1050 (Sound_Interrupt_data)
	LD 		A,B
psid_31:
	LD 		(HL),C
	INC 	HL
	DJNZ 	psid_31
	;; At this point the Stack has 3 pairs saved in it:
	;; pointer on Voice_channel_0_data, pointer on Voice_data_C?_V2
	;; pointer on Voice_channel_1_data, pointer on Voice_data_C?_V1
	;; pointer on Voice_channel_2_data, pointer on Voice_data_C?_V0
	LD 		HL,Channels_voice_data_ptr
psid_32:
	POP 	DE											;; pointer Voice_channel<n>_data
	POP 	BC											;; pointer Voice_data_C<s>_V<n>
	LD 		(HL),C
	INC 	HL
	LD 		(HL),B
	INC 	HL											;; Save Voice_data_C<s>_V<n> pointer in Channel<n>_voice_data_ptr
	;; Set bit 1 in first byte of the voice structure.
	EX 		DE,HL
	SET 	1,(HL)
	EX 		DE,HL
	DEC 	A
	JR 		NZ,psid_32									;; loop for the 3 channels
	;; And reset bits [012] of SndEnable, so they can be played.
	LD 		HL,Sound_channels_enable
	LD 		A,&F8
	AND 	(HL)										;; reset bits [2:0] = activate 3 channels
	LD 		(HL),A										;; in Sound_channels_enable
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Parse the first 2 bytes of the sound data:
;;
;; The first byte [7:2] is the reference Note number, [1:0] the global volume level
;; Ref note: 0 = lowest Do (C note) (octave 1, period &EEE)
;; Other exemples:
;;  50 : 010100 00 : &24|0 = num 36 : ref do (C) (octave 4)
;;  D0 : 110100 00 : &34|0 = num 52 : ref mi (E) (octave 5)
;;  C3 : 110000 11 : &30|3 = num 48 : ref do (C) (octave 5)
;;  C0 : 110000 00 : &30|0 = num 48 : ref do (C) (octave 5)
;;  A8 : 101010 00 : &2A|0 = num 42 : ref fa# (F#) (octave 4)
;; ten    : 00000000001111111111222222222233333333334444444444555555555566666666667777777777888888888899
;; unit   : 01234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901
;; note   : c#d#ef#g#a#bc#d#ef#g#a#bc#d#ef#g#a#bc#d#ef#g#a#bc#d#ef#g#a#bc#d#ef#g#a#bc#d#ef#g#a#bc#d#ef#g
;; octave : 11111111111122222222222233333333333344444444444455555555555566666666666677777777777788888888
;; exemple:										|___> 36=C oct4 |___> 52=E oct5
;;
;; The 2nd byte is (???TODO???) the volume/tone-enveloppe: [7:4][3:0]
.Parse_voice_data_begining:
	CALL 	Get_sound_data_pointer_in_IX				;; IX points on current voice data
	LD 		BC,&0203									;; B = 2 right shift ; C=03 mask
	CALL 	Read_IX_data_and_split						;; read first byte and split at bit 2 (eg: &93=100100_11 gets D=&24 ; E=&03)
	LD 		(IY+SND_REF_NOTE),D							;; reference Note number (eg. &24 = num 36 = Do octave 3)
	LD 		(IY+SND_VOL_LEVEL),E						;; (main volume level)
	INC 	IX											;; next data
	CALL 	Slice_VolumeEnvp_Effects					;; select volume/enveloppe ????
	INC 	IX											;; next data (first note)
	JP 		Sound_Continue_Parse_data					;; continue parsing sound data at 3rd byte

;; -----------------------------------------------------------------------------------------------------------
;; Get the pointer on sound data in IX
.Get_sound_data_pointer_in_IX:
	LD 		HL,(curr_Voice_data_pointer)				;; get curr_Voice_data_pointer
	LD 		DE,&FFFA									;; -6 (from index in "curr_Voice_data_addr", points on same index in "Channels_voice_data_ptr")
	ADD 	HL,DE										;; point on current voice in Channels_voice_data_ptr
	LD 		E,(HL)
	INC		HL
	LD 		D,(HL)										;; DE now points on the current voice data; for exemple = Voice_data_C3_V2
	PUSH 	DE
	POP 	IX											;; store it in IX (IX now points on current voice data)
	RET

;; -----------------------------------------------------------------------------------------------------------
;; The function entry is "Sound_Continue_Parse_data"; it parses sound data from the 3rd byte
;; Sound data format from 3rd byte:
;; FF FF : disable voice
;; FF nn : envp nn?
;; FF 00 : loop from the start (2nd byte : read volume/envp)
;; byte [7:3] = note offset, [2:0] duration index (in Note_duration_array)
snd_parse_loop:
	CALL 	Get_sound_data_pointer_in_IX				;; Get the pointer on current sound data in IX
	INC 	IX											;; points on next sound data (volume/envp)
	JR 		snd_parse_vol_envp							;; jump snd_parse_vol_envp

snd_parse_FF:																;; if data byte was FF
	INC 	IX											;; point next sound data byte
	CP 		(IX+0)										;; test if byte is 00 (after a previous FF)
	JR 		Z,snd_parse_loop							;; if so, jump snd_parse_loop and restart from the begining, else:
	DEC 	A											;; A back to FF
	CP 		(IX+0)										;; test if FF (after a previous FF)
	JP 		Z,Disable_current_voice						;; if so, goto Disable_current_voice (finished)
snd_parse_vol_envp:
	CALL 	Slice_VolumeEnvp_Effects					;; FF <nn> (nn ni 00 ni FF) : enveloppe?
	INC 	IX											;; point next sound data
.Sound_Continue_Parse_data:
	RES 	4,(IY+SND_FLAGS)							;; reset status flag bit4
	LD 		A,(IX+0)									;; get sound data
	INC 	A											;; test A=FF
	JP 		Z,snd_parse_FF								;; if A was FF jump snd_parse_FF, else:
	;; get 3rd byte note offset (from ref) and duration
	LD 		BC,&0307									;; B=3 right shifts; &07=mask for bits [2:0] : split at bit 3
	CALL 	Read_IX_data_and_split						;; get data and split in 2 (at bit 3)
	LD 		C,D											;; C = D = note offset from ref note; E = note_duration_index
	LD 		HL,Note_duration_array
	LD 		D,0
	ADD 	HL,DE										;; HL + note_duration_index
	LD 		A,(HL)										;; A = duration_value
	LD 		(IY+SND_NOTE_DURATION),A					;; write duration value in array[&0D]
	XOR 	A											;; A = 0
	CP 		C											;; test if C = 0 (note offset = 0 so curr note = ref note)
	JR 		NZ,Calc_Note_Ref_plus_Offset				;; no, then Calc_Note_Ref_plus_Offset (will do Sound_Prepare_Next_Note), else:
	SET 	5,(IY+SND_FLAGS)							;; else (note = ref + offset_of_0 = ref) set status flag bit 5
	JP 		Sound_Prepare_Next_Note						;; Sound_Prepare_Next_Note ; will RET

;; -----------------------------------------------------------------------------------------------------------
;; Provides 2 functions:
;;  * Get_current_Voice_data_in_HL
;;  * Get_Voice_data_in_HL; in this case the desired voice number must be in A
;; Output : HL points on the Voice_channel<N>_data pointer corresponding
;;          to the desired voice number
.Get_current_Voice_data_in_HL:
	LD 		A,(Current_sound_voice_number)				;; get Current sound voice number
.Get_Voice_data_in_HL:														;; Get the 19-byte structure for the voice in A (0-2), into HL.
	LD 		HL,Voice_channel_0_data 					;; points on a 3*19-byte array for channels data pointers
	AND 	A											;; test A
	RET 	Z											;; if A=0 then HL=Voice_channel_0_data and RET, else, A > 0:
	LD 		DE,&0013									;; DE = &13 = 19, size of sound data array
	LD 		B,A											;; B = voice number 1 or 2
gvd_loop:
	ADD 	HL,DE										;; update HL pointer on next channel data
	DJNZ 	gvd_loop									;; loop once or twice until the corresponding voice
	RET													;; HL points now on the pointers or Voice_channel_1_data or Voice_channel_2_data

;; -----------------------------------------------------------------------------------------------------------
;; From the reference note in SND_REF_NOTE and the offset in C
;; calculate the current desired note.
;; eg. ref note C oct4 (&24) + offset=6 gives F# oct4 (&2A)
;; so DE=&0151 (period of Fa# oct4) and also in A+C we have &013E
;; (period of G4, Sol oct4, the periode for the next chromatic note)
.Calc_Note_Ref_plus_Offset:
	RES 	5,(IY+SND_FLAGS)							;; reset status flag bit 5 ("got note"??)
	LD 		A,(IY+SND_REF_NOTE)							;; get ref Note
	ADD 	A,C											;; refNote in A + noteOffset in C --> A=note ???????
	LD 		BC,&FF0C									;; B will be 0; C=12 because 12 notes in the chromatic scale (one full octave)
;; from the note number, get in B the octave number and the note number in
;; that octave. eg. &2A = 42 ; B=int(42/12)=3 (ie. octave 4) ; A=(42%12)=6
f0eab_1:
	INC 	B											;; B is the integer division result (octave value-1)
	SUB 	C											;; modulo: sub C until value goes negative
	JR 		NC,f0eab_1
	ADD 	A,C											;; add back last C that's been sub to get result of modulo
	ADD 	A,A											;; *2 (to get a word-aligned offset)
	LD 		E,A
	LD 		D,0											;; in DE
	LD 		HL,Notes_periodes_Lowest_Octave
	ADD 	HL,DE										;; as offset in Notes_periodes_Lowest_Octave table
	LD 		E,(HL)
	INC 	HL
	LD 		D,(HL)
	INC 	HL											;; get note pitch values as if in octave 1 (fa# oct1 gets &0A8F)
	LD 		C,(HL)
	INC 	HL
	LD 		A,(HL)										;; get note + 1 semitone pitch (octave1) in A(high byte);C(lowbyte)
	INC 	B											;; now B has the value of the octave we want
	JR 		f0eab_2

f0eab_2loop:
	SRL 	A											;; AC/2
	RR 		C                                    		;; for each octaves we divide the period by 2 (in other words, mult the freq by 2)
	SRL 	D											;; DE/2
	RR 		E
f0eab_2:
	DJNZ 	f0eab_2loop									;; (loop B times) this calculate the periode of the note for the octave we want, because for each octave up, the periode is divided by 2 (hence freq x 2)
	;; for exemple at this point, ref note C oct4 &24 + noteoffset = 6,
	;; gives note &2A = Fa# oct4; Fa# in oct1 has a period of &0ABF in DE
	;; (and Sol, the next chromatic note upscale, in oct1 has a period of
	;; &09F7 in "AC") B was 3 (so 4 loops where we divide DE and "AC" by 2
	;; resulting in DE=&0151 (period of Fa# oct4) and in registers A and C
	;; AC=&013E (period of Sol in oct4)
	LD 		B,A											;; BC now has the value of the curr_note+semitone note
	LD 		A,(IY+SND_FLAGS)							;; get status flags
	AND 	%01000010									;; look bits 6 and 1
	CP 		%01000000									;; test if bit6 was 1 and bit1 was 0 (was it noise or sound)
	JR 		NZ,f0eab_3									;; if that was NOT the case (sound) jump f0eab_3, else (noise):
	LD 		(IY+NOISE_FINE),E							;; was a noise pitch
	LD 		(IY+NOISE_COARSE),D							;; save note periode in array[7] (high byte) and [6] (low byte)
	JR 		f0eab_4

f0eab_3:																	;; else it was a sound note
	LD 		(IY+SND_FINE),E								;; save it in array [9] and [8], note pitch
	LD 		(IY+SND_COARSE),D
f0eab_4:
	BIT 	7,(IY+SND_FLAGS)							;; test status flag bit7
	JR 		Z,f0eab_5									;; if it was 0 (snd disabled??), jump f0eab_5, else:
	;; would that be to cut the note duration in pieces to apply a
	;; enveloppe or volume modification across the full note duration
	EX 		DE,HL										;; HL = current note
	AND 	A											;; clear Carry
	SBC 	HL,BC										;; get the difference between the current_note period and its following one in the scale
	SRL 	L
	SRL 	L											;; divide it by 4
	LD 		A,(IY+&10)									;; array [&10]
	AND 	A											;; test it (Z set if 0, S bit set if bit7=1, Neg and Carry reset)
	JR 		Z,f0eab_6									;; if 0, then jump f0eab_6, else:
	LD 		H,A											;; H=array[&10] L=notegap/4
	LD 		A,L
	JP 		M,f0eab_7									;; jump f0eab_7 if S flag (arry[&10] bit7) is set, else (H bit7=0):
f0eab_9:
	RRC		H											;; this will multiply A by 2 depending on
	JR 		c,f0eab_8									;; which is the first bit of H set
	ADD 	A,A											;; x2
	JR 		f0eab_9										;; loop

f0eab_10:																	;; Carry=0 if we arrive here
	RRA													;; A parity/bit0 in Carry and A/2
f0eab_7:
	RRC 	H											;; this will divide A by 2 until we reach the first
	JR 		NC,f0eab_10									;; bit set in H
f0eab_8:
	LD 		L,A											;; update value in L
f0eab_6:
	LD 		(IY+SND_DELTA_FINE),L						;; store value in array[&E] (sound delta pitch for bend/vibrato effect)
	XOR 	A
	LD 		(IY+SND_DELTA_COARSE),A						;; put 0 in array[&F]
f0eab_5:
	LD 		A,(IY+SND_FLAGS)							;; read status flag reg
	BIT 	6,A											;; test bit6
	JR 		Z,f0eab_11									;; if 0, jump f0eab_11, else:
	BIT 	1,A											;; test bit 1
	JR 		Z,f0eab_12									;; if 0, jump f0eab_12, else:
	SET 	4,(IY+SND_FLAGS)							;; set status flag bit4
	JR 		f0eab_11									;; jump f0eab_11

f0eab_12:
	LD 		L,(IY+NOISE_FINE)
	LD 		H,(IY+NOISE_COARSE)							;; HL = noise note periode
	LD 		E,(IY+SND_FINE)
	LD 		D,(IY+SND_COARSE)							;; DE = sound note periode
	RR 		(IY+SND_FLAGS)								;; flags shift right
	XOR 	A											;; A=0, Carry cleared
	SBC 	HL,DE										;; diff between noise and sound periods in HL
	RL 		(IY+SND_FLAGS)								;; flags shift left, but carry reset, so flag bit0 was cleared
	LD 		C,(IY+SND_NOTE_DURATION)					;; note duration
	LD 		E,&80										;; put a "1" in bit7 to init
	LD 		B,8											;; test up to 8 bits
f0eab_13:
	LD 		A,E											;; A has a wandering "1", starting at bit7 downward
	AND 	C											;; test duration value
	JR 		NZ,f0eab_14									;; if found a 1 jump f0eab_14, else:
	RRC 	E											;; move "1" bit to the right
	DJNZ 	f0eab_13									;; jump up to test next bit
f0eab_14:																	;; we found the highest bit of duration set to 1, the 1 in A indicates which bit is it
	RRCA												;; A[0] goes in carry and A/2
	JR 		c,f0eab_15									;; if bit0 of A was 1 jump f0eab_15, else:
	SRA 	H
	RR 		L											;; divide HL (gap between noise and sound period) by 2
	JR 		f0eab_14									;; until we reach the bit set in A

f0eab_15:
	LD 		(IY+NOISE_DELTA_FINE),L
	LD 		(IY+NOISE_DELTA_COARSE),H					;; put result in array [&11] and [&12] (delta pitch for bend/vibrato effect)
	RES 	4,(IY+SND_FLAGS)							;; and reset status flag bit4
f0eab_11:
	LD 		(IY+SND_VOL_INDEX),0						;; init chosen volume array index
	LD 		A,(IY+SND_NB_FX_SLICES)						;; put array[5] in ...
	LD 		(IY+SND_CURR_FX_SLICE),A					;; ... array[4]
.Sound_Prepare_Next_Note:
	RES 	1,(IY+SND_FLAGS)							;; reset status flag bit1 = already started parsing sound data, next byte will be note or "FF" code and not the "header" refNote/duration+Envp
	PUSH 	IX
	POP 	DE											;; sound data pointer in DE
	INC 	DE											;; DE points on the next data for that voice
	LD		HL,(curr_Voice_data_pointer)				;; get which is the current curr_Voice_data_addr
	LD 		(HL),E
	INC 	HL
	LD 		(HL),D										;; and we save next data pointer it in the current curr_Voice_data_addr
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Split the byte in D in 2 nibbles, results in D and E.
;; Input: D = byte value to split											; ex:		DE=&6A
;; Output: D = high nibble value; E = low nibble value						; ex:		D=&06 ; E=&0A
.Get_nibbles_from_D_to_D_and_E:
	LD 		BC,&040F									;; B = 4 right shift, C = &0F mask
	JR 		rnsplt_1									;; will RET

;; -----------------------------------------------------------------------------------------------------------
;; Reads a byte of data pointed by IX and split in 2, depending on BC,
;; with B = bitnb where to split, C=bitmask.
;; Input: IX = Data pointer; B = number of right shift ; C = bitmask
;; Output D = high value; E = low value ; trucated depending on mask
;; Exemple:  (IX) data = &65 and BC=&37; then D=&0C and E=&05)
.Read_IX_data_and_split:
	LD 		D,(IX+0)									;; read the data again
rnsplt_1:
	LD 		A,D											;; put data byte to split it in A
	AND 	C											;; mask it to keep lower bits (if mask=&07, then bits [2:0] are kept)
	LD 		E,A											;; result in E
	LD 		A,C											;; A = bitmask
	CPL													;; invert all bits of A, so inverted mask (if mask=&07, then invmask=&F8)
	AND 	D											;; get high part data (if invmask=&F8, then get data[7:3])
	LD 		D,A											;; put result in in D
rnsplt_loop:																;; need to shift right so that the lsb bit od D is at bit0
	RRC 	D											;; shift right (if B=3, then data[7:3] become data[4:0]
	DJNZ 	rnsplt_loop									;; loop
	RET

;; -----------------------------------------------------------------------------------------------------------
;; IX : points on Data: Voice_data_C?_V?
;; IY : points on channel sound object : Voice_channel_?_data
.Slice_VolumeEnvp_Effects:
	LD BC,&040F											;; B = 4 right shifts; C = &0F mask which means split in two 4-bit nibbles
	CALL Read_IX_data_and_split							;; Read (IX) and split : D = high nibble, E = low nibble
	LD A,&02
	AND (IY+SND_FLAGS)									;; turn off bit7 (enable?) and keep bit1 from...
	LD (IY+SND_FLAGS),A									;; ... the status/flag byte in the Voice_channel<n>_data array
	BIT 2,D												;; test bit 2 of high nibble in D (Sound=0 or Noise=1 ????)
	JR Z,f0fa9_1										;; and effectively copy that bit (0 or 1)...
	SET 6,(IY+SND_FLAGS)								;; ...in the status/flags bit6, because b6 was reset before.
f0fa9_1:
	;; this will check if the 2nd byte bits [5:4] are 0, then skip all this;
	;; else if 1, 2 and 3, calc in A :
	;; max(x;y) / min(x;y) and A bit7 = '0' if x>=y else '1' if x<y with
	;; x and y from the Voice_data_10AD, index being [5:4]-1
	LD A,&03											;; this is to look at the (IX) data bits [5:4] or high nibble in D [1:0]
	AND D												;; keep D[1:0] (data high nibble) only and test if value = 0
	JR Z,f0fdc_1										;; if 0 then jump f0fdc_1, else D[1:0] is 1, 2 or 3
	PUSH DE												;; save DE (splited (IX) data byte (2nd byte of sound data))
	DEC A												;; D[1:0] value-1 (new value can be 0, 1 or 2)
	LD HL,Voice_data_10AD								;; points on ???? array
	LD E,A
	LD D,&00											;; DE = A is the index in the Voice_data_10AD array
	ADD HL,DE											;; add offset
	LD D,(HL)											;; get data from this 3byte array
	CALL Get_nibbles_from_D_to_D_and_E					;; split in 2 nibbles (eg.&81 gets D=&08 and E=&01)
	LD (IY+SND_EFFECT_TARGET),E							;; store low nibble value in Voice_channel<n>_data array byte &C (12)
	LD A,D												;; high nibble
	CP E												;; compare high nibble to low nibble
	LD A,0												;; A = 0
	JR Z,f0fd4_1										;; if high byte was = low byte, then jump f0fd4_1
	JR NC,f0fa9_2										;; if high > low then jump f0fa9_2 (A=0, Carry=0), else:
	LD A,D
	LD D,E												;; swap D and E
	LD E,A
	LD A,&80											;; and set A to &80, Carry = 1
f0fa9_2:
	RR E												;; put E parity in Carry and E/2, the previous Carry goes in E[7] (1 if we swapped high;low above)
	JR c,f0fa9_3										;; if E was Odd then jump f0fa9_3, else if Even:
	RRC D												;; divide high by 2
	JR f0fa9_2											;; and loop

f0fa9_3:
	OR D
	;; at this point: A = max(D;E) / min(D;E) and A bit7 = '0' if D>=E else '1' if D<E
	;; (can also be 0 if all this was skipped)
	;; 8|1 : D=8; E=0; A=8 		(8/1 = 8 and A bit7 = 0 : D>=E)
	;; 4|2 : D=2; E=0; A=2 		(4/2 = 2 and A bit7 = 0 : D>=E)
	;; 4|8 : D=2; E=&20; A=&82 	(8/4 = 2 and A bit7 = 1 : D<E)
f0fd4_1:
	LD (IY+&10),A										;; store that computed A value in array[&10]
	SET 7,(IY+SND_FLAGS)								;; and set bit7 of the status/flags
	POP DE												;; restore DE (splited 2nd data byte)
f0fdc_1:
	LD HL,Volume_Envp_Speed_n_Select_arr				;; points on Volume_Envp_Speed_n_Select_arr array
	LD D,0
	ADD HL,DE											;; add 2nd byte low nibble as an offset
	LD D,(HL)											;; and get corresponding data (eg. E=&05 get D=&12)
	CALL Get_nibbles_from_D_to_D_and_E					;; and split in 2 (eg; D=&12 gives D=&01; E=&02)
	LD (IY+SND_NB_FX_SLICES),D							;; Store D (is a value from 1 to 4) in both array[5] (TODO: init/max number of volume effect parts)
	LD (IY+SND_CURR_FX_SLICE),D							;; ... and array[4] (TODO: Current index volume effect)
	CALL Choose_Volume_envp								;; choose volume array (E offset from low byte of data from Volume_Envp_Speed_n_Select_arr, can be from 0 to 9)
	LD A,(Current_sound_voice_number)					;; get Current sound voice number
	AND A
	JR NZ,f0ff9_1										;; if not 0 skip to f0ff9_1, else
	RES 3,(IY+SND_FLAGS)								;; if channel 0 : reset status/flag bit3
f0ff9_1:
	BIT 7,(IX+0)										;; test 2nd byte of sound data bit7
	RET Z												;; if 0 (no noise), leave, else:
	INC IX												;; do noise: point on next data
	AND A												;; test Current sound voice number
	RET NZ												;; if voice not 0, leave; else:
	SET 3,(IY+SND_FLAGS)								;; set bit3 of status/flags
	PUSH IY												;; save pointer on Sound "object"
	LD IY,Voice_Noise_data								;; temporarily points on Noise array
	LD E,(IX+0)											;; read data byte
	LD A,&C0
	AND E												;; keep bits[7:6]
	RLCA												;; bit7 goes in Carry and bit0, bit6 goes in bit7
	LD (IY+NOISE_FLAGS),A								;; put that in Noise flags
	LD A,&0F											;; keep bit0 (previous bit7)
	AND E
	LD E,A
	LD HL,Noise_data_10B8								;; Noise enveloppe???
	RLC E
	LD D,0
	ADD HL,DE
	LD D,(HL)											;; get selected value from Noise_data_10B8 table
	CALL Get_nibbles_from_D_to_D_and_E
	LD (IY+NOISE_CURR_FX_SLICE),D
	LD (IY+NOISE_NB_FX_SLICES),D
	INC HL
	LD A,(HL)
	LD (IY+NOISE_FINE),A
	CALL Choose_Volume_envp
	ADD A,(HL)
	LD (IY+NOISE_COARSE),A
	XOR A
	LD (IY+NOISE_VOL_INDEX),A
	POP IY												;; get back pointer on Sound "object"
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Input: E has the offset from the data [3:0] in table at 10BE (can be 0 to 9 from the sound data)
;; The value in E comes from the low nibble in Volume_Envp_Speed_n_Select_arr, the index being the
;; low nibble of the 2nd data byte.
;; Output: HL was put in the Voice_Channel_<?>_data 19-byte array at offset +2 (H) and +1 (L)
.Choose_Volume_envp:
	LD 		HL,Volume_Envp_ptrs							;; points on Volume_Envp_ptrs array
	LD 		D,0
	ADD 	HL,DE										;; add E as an offset
	LD 		E,(HL)										;; get the offset value from that array
	ADD 	HL,DE										;; and add more offset
	LD 		(IY+SND_VOL_PTR_L),L						;; final value go in array[1]
	LD 		(IY+SND_VOL_PTR_H),H						;; and array[2] (chosen volume array pointer)
	RET

;; -----------------------------------------------------------------------------------------------------------
;; This is the pointer on the sound data to process next
.curr_Voice_data_pointer:
	DEFW 	&0000

Sound_Interrupt_data:
Sound_Voice0_status:
	DEFB	&FF			;; Voice0 : b7 = Sound_enable (active low) ; FF=nothing being played
Sound_Voice1_status:
	DEFB 	&FF			;; Voice1 : b7 = Sound_enable (active low) ; FF=nothing being played
Sound_Voice2_status:
	DEFB 	&FF			;; Voice2 : b7 = Sound_enable (active low) ; FF=nothing being played

;; -----------------------------------------------------------------------------------------------------------
Current_sound_voice_number:
	DEFB 	&00					;; Current voice id (0-2)
Sound_channels_enable:
	DEFB 	%11000111			;; &C7

.Channels_voice_data_ptr:
	DEFW 	&0000
	DEFW 	&0000
	DEFW 	&0000

.curr_Voice_data_addr:
	DEFW 	&0000
	DEFW 	&0000
	DEFW 	&0000

;; -----------------------------------------------------------------------------------------------------------
;; Sound data format:
;;	* 1st byte: data[7:2] = reference note number (array+A);
;;              data[1:0] = volume level (to increase general volume for channel) (array+B)
;;	* 2nd byte: data[7:4] ; data[3:0] : First volume/enveloppe/effect ????
;;		if bit 6 or 7???? = 1 (noise) then read one more byte to get the envp for noise.
;;      if bit 7 or 6 ??? : ???
;;      bits[5:4] : if 0, bits[3:0] will choose the envelope and nb of slices (array+4,5,2,1,3 updated)
;;	* then:
;;       byte: data[7:3]=note offset from ref note ; data[2:0]=duration index in table
;;	  or byte =  FF + function:
;;				 FF 00 : loop back from 2nd byte
;;				 FF FF : end
;;				 FF nn : new enveloppe
;;
;; note_duration_offset:  0  1  2  3  4  5  6  7
;;	    DEFB (hex)       01 02 04 06 08 0C 10 20
;;
;; Exemple:
;;	 D0 0E 6E 96 6E 56 FF 01 34 36 FF 0E 7C 6C 54 6E			; ID &41 = Market
;;	 47 FF FF
;;
;;	 55555555666666666666
;;	   # # #  # #  # # #
;;	 effggaabccddeffggaab		ref note = e (mi) octave 5
;;	 0123456789ABCDEF0123
;;
;;	 D0        110100 00	ref note num = &34 = 52 : reference note = mi (octave 5) ; volume level = 0 (no extra volume added to volume)
;;   0E		   0 0 00 0111	volume / envp?: Volume_Envp_Speed_n_Select_arr[7] = 1|6 (1 slice);
;;                          Volume_Envp_ptrs[6] = Volume_Envp_data[+20=10F4] points on this envp : "02 00 00 04 00 00 06 00 00 09 00 0C 00 40"
;;	 6E        01101 110	offset=&0D duration_index=blanche	note = fa (octave 6)
;;	 96        10010 110	offset=&12 duration_index=blanche	note = la# (octave 6)
;;	 6E        01101 110	offset=&0D duration_index=blanche	note = fa (octave 6)
;;	 56        01010 110	offset=&0A duration_index=blanche	note = re (octave 6)
;;	 FF 01		new volume/envp 01
;;	 34        00110 100	offset=&06 duration_index=noire		note = la# (octave 5)
;;	 36        00110 110	offset=&06 duration_index=blanche	note = la# (octave 5)
;;	 FF 0E		new volume/envp 0E
;;	 7C        01111 100	offset=&0F duration_index=noire		note = sol (octave 6)
;;	 6C        01101 100	offset=&0D duration_index=noire		note = fa (octave 6)
;;	 54        01010 100	offset=&0A duration_index=noire		note = re (octave 6)
;;	 6E        01101 110	offset=&0D duration_index=blanche	note = fa (octave 6)
;;	 47        01000 111	offset=&08 duration_index=ronde		note = do (octave 6)
;;	 FF FF		end
;; -----------------------------------------------------------------------------------------------------------

;; -----------------------------------------------------------------------------------------------------------
;; Channel data to compute the AY3 registers ; 19 bytes per voice
SND_FLAGS 				EQU		&00			;; flags & status
NOISE_FLAGS 			EQU		&00 		;; flags & status
SND_VOL_PTR_L			EQU		&01
SND_VOL_PTR_H			EQU		&02			;; Pointer to vol array
SND_VOL_INDEX			EQU		&03			;; current Index into vol array
NOISE_VOL_INDEX			EQU		&03			;; current Index into vol array
SND_CURR_FX_SLICE		EQU		&04			;; current value for in how many parts the current note duration id cut to apply effects (bend/vibrato))
NOISE_CURR_FX_SLICE		EQU		&04			;; current value for (maybe) in how many parts the current note duration id cut to apply effects (bend/vibrato))
SND_NB_FX_SLICES		EQU		&05			;; init value for in how many parts the current note duration id cut to apply effects (bend/vibrato))
NOISE_NB_FX_SLICES		EQU		&05			;; init value for (maybe) in how many parts the current note duration id cut to apply effects (bend/vibrato))
NOISE_FINE				EQU		&06
NOISE_COARSE	 		EQU		&07			;; Noise fine and coarse pitch
SND_FINE				EQU		&08
SND_COARSE				EQU		&09			;; Sound fine and coarse pitch
SND_REF_NOTE			EQU		&0A			;; Reference note number (first data byte [7:2]>>2)
SND_VOL_LEVEL			EQU		&0B			;; Volume addition (first data byte [1:0])
SND_EFFECT_TARGET		EQU		&0C			;; bit7 : bend/vibrato effect
SND_NOTE_DURATION 		EQU		&0D			;; note duration
SND_DELTA_FINE			EQU		&0E
SND_DELTA_COARSE		EQU		&0F			;; Sound delta pitch (fine and coarse) for bend/vibrato effects
SND_TODO				EQU		&10			;; ???? TODO ???
NOISE_DELTA_FINE		EQU		&11
NOISE_DELTA_COARSE		EQU		&12			;; Noise delta pitch (fine and coarse) for bend/vibrato effects

;; -----------------------------------------------------------------------------------------------------------
.Voice_channel_0_data:
	DEFS 	19, &00
.Voice_channel_1_data:
	DEFS 	19, &00
.Voice_channel_2_data:
	DEFS 	19, &00

;; -----------------------------------------------------------------------------------------------------------
;; Channel 0 data to compute the AY3 registers for noise ; 8 bytes
;; (same than Voice_channel_<?>_data, but for Noise)

.Voice_Noise_data:											;; (noise)
	DEFS 	8, &00

;; -----------------------------------------------------------------------------------------------------------
;; AY-3-8912 registers:
AY_A_FINE				EQU 	&00			;; Channel A fine pitch    8-bit (0-255)
AY_A_COARSE				EQU 	&01			;; Channel A coarse pitch  4-bit (0-15)
AY_B_FINE				EQU 	&02			;; Channel B fine pitch    8-bit (0-255)
AY_B_COARSE				EQU 	&03			;; Channel B coarse pitch  4-bit (0-15)
AY_C_FINE				EQU 	&04			;; Channel C fine pitch    8-bit (0-255)
AY_C_COARSE				EQU 	&05			;; Channel C coarse pitch  4-bit (0-15)
AY_NOISE				EQU 	&06			;; Noise pitch             5-bit (0-31)
AY_MIXER				EQU 	&07			;; Mixer                   8-bit
AY_A_VOL				EQU 	&08			;; Channel A volume        4-bit (0-15)
AY_B_VOL				EQU 	&09			;; Channel B volume        4-bit (0-15)
AY_C_VOL				EQU 	&0A			;; Channel C volume        4-bit (0-15)
;; -----------------------------------------------------------------------------------------------------------
;; Registers AY_<A|B|C>_<FINE&COARSE>:
;; Note freq = 440 * (2^((Octave -4) - ((10-N) / 12))
;; 			with N the note (do=1, do#=2, ... la=10, la#=11, si=12)
;;			and with "Octave" from 1 to 8, where Octave=4 is the A (A4:440Hz) reference octave (La international ; octave 4).
;; Note Tone = (Chip_Clk / 16) / freq = (2MHz / 16) / freq = 125000 / freq
;; It is the note Tone that will be programmed in the fine&coarse pitch registers.
;; eg. Tenor Middle C (C3 = do octave 3) is programmed with a Tone of 956,
;; hence producing a frequency of 125000/956 =~ 131Hz.
;; To calculate the tone from the frequency of C3 (do octave 3) :
;; 		freq = 440 * 2^((3 - 4) - ((10-1) / 12)) = 440 * 2^(-1.75) =~ 440 * 0.2973 =~ 130.8 Hz
;;      Tone = 125000 / 130.8 =~ 956   =>  0x3BC    =>   fine = 0xBC, coarse = 0x03
;; -----------------------------------------------------------------------------------------------------------
;; Register AY_NOISE:
;; For noise : Freq =  (Chip_Clk / 16) / Note_periode = (2MHz / 16) / Note_periode = 125000 / Note_periode
;; where Note_periode is the value in AY_NOISE[4:0]
;; -----------------------------------------------------------------------------------------------------------
;; Register AY_MIXER:
;; Mixer : bit0, 1, 2 = Channel A, B, C Tone : enable (if '0') / disable (if '1')
;; 		   bit3, 4, 5 = Channel A, B, C Noise : enable (if '0') / disable (if '1')
;; 		   bit6 = I/O PortA direction (not for Sounds/Noise/Music)
;; -----------------------------------------------------------------------------------------------------------
;; Registers AY_<A|B|C>_VOL:
;; 		  bits [3:0] = Amplitude (volume)
;;		  bit4 : '0' to use the value in bits [3:0]; '1' to use the Hardware Envelope registers
;;                 (here always '0' because it does Softawre-envp)
;; -----------------------------------------------------------------------------------------------------------
;; Other AY-3 registers:
;; This game will generate Software-Envelopes (ie. it won't use the Hardware registers
;; AY_ENVP_FINE (0B), AY_ENVP_COARSE (0C) and AY_ENVP_SHAPE (0D) but instead
;; will update the pitch registers, the volume or the duration to create sounds effects
;; like bends, vibratoes, etc.).
;; The register AY_IO_PORT (0E) is used for keyboard scanning, not for Sounds.
;; -----------------------------------------------------------------------------------------------------------

;; This array store the value to be written to the AY-3 PSG
.AY_Registers:																;; 11 registers (don't use the Envelope registers, will do Software ENV and ENT)
	DEFB 	&00, &00, &00, &00, &00, &00, &00, &3F, &00, &00, &00

;; -----------------------------------------------------------------------------------------------------------
.Voice_data_10AD:
	DEFB 	&81, &42, &48												;; this is 3 pairs of nibbles 8;1 4;2 4;8

;; -----------------------------------------------------------------------------------------------------------
;; Notes duration:
;; 000 : 1	triple croche (1/8 noire)
;; 001 : 2	double croche (1/4 noire)
;; ___ : 3	double croche pointée (3/8 noire) NOT USED!
;; 010 : 4	croche (1/2 noire)
;; 011 : 6	croche pointée (3/4 noire)
;; 100 : 8	Noire
;; 101 : 12	noire pointée (1.5 noires)
;; 110 : 16	Blanche (2 noires)
;; ___ : 24	Blanche pointée (3 noires) NOT USED!
;; 111 : 32	Ronde (4 noires)
.Note_duration_array:
	DEFB 	&01, &02, &04, &06, &08, &0C, &10, &20						;; note_durations

;; -----------------------------------------------------------------------------------------------------------
;; These are probably the Volume Enveloppes
.Noise_data_10B8:
	DEFB 	&12, &14, &10, &0C, &36, &00           						;; TODO: Noise ENV; nibbles   1;2  1;4 1;0; 0;c 3;6  0;0

.Volume_Envp_Speed_n_Select_arr:
	DEFB 	&22, &10, &42, &11, &24, &12, &41, &16
	DEFB 	&25, &13, &34, &17, &26, &44, &29, &18    					;; Sound envp parts and effect number ; nibbles  42: 4 volume effect parts; index 2 in volume effect pointers array

.Volume_Envp_ptrs:			;;    0    1    2    3    4    5    6    7   8    9				; Sound Volume effect pointers (offset pointer to volume (enveloppe) array)
	;; 					&10?? :  DE   D8   DF   E1   E4   F0   F4   FF  102  105
	DEFB 	&10, &09, &0F, &10, &12, &1D, &20, &2A, &2C, &2E

;; when bit7 is set it's the end (stay at last value in [5:0] ??)
;; when bit6 is set : loop over from first byte
.Volume_Envp_data:
	DEFB 	&04, &05, &07, &09, &0A, &0B								;; volume enveloppes effects per parts
	DEFB 	&8C
	DEFB 	&0C, &08
	DEFB 	&04, &01, &80
	DEFB 	&08, &00, &0C, &00, &07, &00, &04, &00, &02, &00, &01, &80
	DEFB 	&0C, &0A, &08, &45
	DEFB 	&02, &00, &00, &04, &00, &00, &06, &00, &00, &09, &00
	DEFB 	&0C, &00, &40
	DEFB 	&08, &0A, &0C
	DEFB 	&0C, &0B, &0A, &09, &08, &07, &06, &05, &04, &03, &02, &81	;; for exemple, this will decrease the note volume at each "tick", if SND_NB_FX_SLICES = 2, then it'll do "0c 0c 0b 0b 0a 0a etc."
																							;; Note that it may not reach the end of the data if the note is shorter.

;; -----------------------------------------------------------------------------------------------------------
;; Sounds ID 0x, 4x, 8x are 1 channel sounds
;; Sounds ID Cx are 3 channels sounds
;; Note that several 1-chan sounds may be played together: for exemple when
;; walking through a door, we will hear both the walking sound and the
;; current world tune playing at the same time.
;; -----------------------------------------------------------------------------------------------------------
Sound_ID_00					EQU 	&00			;; ????????
Sound_ID_01					EQU 	&01			;; ????????
Sound_ID_02					EQU 	&02			;; ????????
Sound_ID_Didididip			EQU 	&03			;; Di di di dip
Sound_ID_GlooGlouGLou		EQU 	&04 		;; GlooGlouGLou
Sound_ID_BeepCannon			EQU 	&05 		;; Beep / Cannon

Sound_ID_Worlds_arr			EQU 	&40			;; Worlds
Sound_ID_Blacktooth			EQU 	&40			;; Blacktooth
Sound_ID_Market				EQU 	&41			;; Market
Sound_ID_Egyptus			EQU 	&42			;; Egyptus
Sound_ID_Penitentiary		EQU 	&43			;; Penitentiary
Sound_ID_MoonBase			EQU 	&44			;; Moon base
Sound_ID_BookWorld			EQU 	&45			;; BookWorld
Sound_ID_Safari				EQU 	&46			;; Safari
Sound_ID_Teleport_waiting	EQU 	&47 		;; Teleport waiting
Sound_ID_Donut_Firing		EQU 	&48 		;; Donut firing

Sound_ID_Walking			EQU 	&80 		;; Walking
Sound_ID_Running			EQU 	&81 		;; Running
Sound_ID_Desc_seq			EQU 	&82 		;; (descending sequence - faster)
Sound_ID_Falling			EQU 	&83 		;; Fall
Sound_ID_Rise_seq			EQU 	&84 		;; (Repeated rising sequence)
Sound_ID_Higher_Blip		EQU 	&85 		;; (higher blip)
Sound_ID_High_Blip			EQU 	&86 		;; (high blip)
Sound_ID_Sweep_Tri			EQU 	&87 		;; (sweep down and up)
Sound_ID_Menu_Blip			EQU 	&88 		;; Menu blip

Sound_ID_Silence			EQU 	&C0 		;; Silence
Sound_ID_Tada				EQU 	&C1 		;; "Tada!"
Sound_ID_Hornpipe			EQU 	&C2 		;; Hornpipe
Sound_ID_Theme				EQU 	&C3 		;; HoH theme music
Sound_ID_Nope				EQU 	&C4 		;; "Nope!" (can't swop)
Sound_ID_DumDiddyDum		EQU 	&C5 		;; Dum-diddy-dum
Sound_ID_Death				EQU 	&C6 		;; Death
Sound_ID_Teleport_Up		EQU 	&C7 		;; Teleport up
Sound_ID_Teleport_Down		EQU 	&C8 		;; Teleport down

;; -----------------------------------------------------------------------------------------------------------
;; This array returns the pointers on the 3 channels data per HQ Sound ID Cx
.Sound_High_table:																					;; Sound_group_3 ID 0xCx
	DEFW 	Voice_data_Silence, Voice_data_Silence, Voice_data_Silence		;; Sound ID&C0 Silence		 134A 134A 134A
	DEFW 	Voice_data_C1_V0,	Voice_data_C1_V1, 	Voice_data_C1_V2		;; Sound ID&C1 "Tada!"		 13BE 13D2 13E7
	DEFW 	Voice_data_C2_V0,	Voice_data_C2_V1, 	Voice_data_C2_V2		;; Sound ID&C2 Hornpipe	     13FC 1418 1434
	DEFW 	Voice_data_C3_V0,	Voice_data_C3_V1, 	Voice_data_C3_V2		;; Sound ID&C3 HoH theme	 1191 11F4 1228
	DEFW 	Voice_data_C4_V0,	Voice_data_C4_V1, 	Voice_data_C4_V2		;; Sound ID&C4 "Nope!"	     1234 123C 1244
	DEFW 	Voice_data_C5_V0,	Voice_data_C5_V1, 	Voice_data_C5_V2		;; Sound ID&C5 Dum-diddy-dum 1442 1455 1466
	DEFW 	Voice_data_C6_V0,	Voice_data_C6_V1, 	Voice_data_C6_V2		;; Sound ID&C6 Death	     1188 117B 1169
	DEFW 	Voice_data_C7_V0,	Voice_data_C7_V1, 	Voice_data_C7_V2		;; Sound ID&C7 Teleport up	 1147 1151 115E
	DEFW 	Voice_data_C8_V0,	Voice_data_C8_V1, 	Voice_data_C8_V2		;; Sound ID&C8 Teleport down 1477 1481 148E

;; -----------------------------------------------------------------------------------------------------------
;; Sound/Music Data for HQ music ID (C7, C6, C3, C4, 3 voices V0 to V2).
.Voice_data_C7_V0:																	;; Sound ID &C7 Voice 0 Teleport up
	DEFB 	&A0, &7C, &30, &3E, &FF, &7B, &5E, &FE, &FF, &FF
.Voice_data_C7_V1:																	;; Sound ID &C7 Voice 1 Teleport up
	DEFB 	&B8, &7C, &31, &3E, &FF, &7B, &5E, &CE, &FF, &52, &AE, &FF, &FF
.Voice_data_C7_V2:																	;; Sound ID &C7 Voice 2 Teleport up
	DEFB 	&C3, &7C, &30, &3E, &FF, &FB, &44, &5E, &CE, &FF, &FF
.Voice_data_C6_V2:																	;; Sound ID &C6 Voice 2 Death
	DEFB 	&93, &00, &95, &6A, &62, &6A, &7D, &6D, &FF, &82, &C0, &15, &FF, &03, &8D, &96
	DEFB	&FF, &FF
.Voice_data_C6_V1:																	;; Sound ID &C6 Voice 1 Death
	DEFB 	&90, &23, &F5, &CA, &C2, &CA, &DD, &CD, &05, &5D, &6E, &FF, &FF
.Voice_data_C6_V0:																	;; Sound ID &C6 Voice 0 Death
	DEFB 	&60, &03, &07, &06, &05, &A5, &B6, &FF, &FF
.Voice_data_C3_V0:																	;; Sound ID &C3 Voice 0 HoH theme (melodie)
	DEFB 	&90, &41, &31, &91, &95, &97, &84, &94, &FF, &22, &96, &06, &CE, &06, &FF, &41
	DEFB 	&51, &B1, &B5, &B7, &A4, &B4, &FF, &22, &B6, &06, &CE, &06, &FF, &41, &59, &B9
	DEFB 	&BD, &BF, &AC, &BC, &FF, &22, &BE, &06, &F6, &06, &FF, &41, &31, &91, &95, &97
	DEFB 	&84, &94, &FF, &22, &96, &06, &CE, &06, &FF, &41, &CA, &CD, &CF, &BC, &CC, &FF
	DEFB 	&22, &CE, &06, &EE, &06, &FF, &41, &C9, &F1, &F3, &03, &C9, &F1, &F3, &03, &07
	DEFB 	&C9, &F1, &F3, &03, &FF, &55, &F2, &CA, &EA, &DA, &B2, &CA, &BA, &92, &B2, &A4
	DEFB 	&6A, &FF, &00
.Voice_data_C3_V1:																	;; Sound ID &C3 Voice 1 HoH theme (chords)
	DEFB 	&62, &08, &36, &56, &6E, &7E, &86, &7E, &6E, &56, &36, &56, &6E, &7E, &86, &7E
	DEFB 	&6E, &56, &5E, &7E, &96, &A6, &AE, &A6, &96, &7E, &36, &56, &6E, &7E, &86, &7E
	DEFB 	&6E, &56, &6E, &8E, &A6, &B6, &BE, &B6, &A6, &8E, &96, &7E, &6E, &56, &6E, &7E
	DEFB 	&86, &8E, &FF, &00
.Voice_data_C3_V2:																	;; Sound ID &C3 Voice 2 HoH theme (bass)
	DEFB 	&93, &05, &34, &94, &54, &B4, &6C, &CC, &7C, &DC, &FF, &00
.Voice_data_C4_V0:																	;; Sound ID &C4 Voice 0 "Nope!"
	DEFB 	&60, &51, &32, &B5, &55, &32, &FF, &FF
.Voice_data_C4_V1:																	;; Sound ID &C4 Voice 1 "Nope!"
	DEFB 	&C0, &51, &92, &CD, &95, &92, &FF, &FF
.Voice_data_C4_V2:																	;; Sound ID &C4 Voice 2 "Nope!"
	DEFB 	&60, &51, &92, &6D, &95, &92, &FF, &FF

;; -----------------------------------------------------------------------------------------------------------
;; Table of pointers on sound groups pointers!
.Sound_Groups:
	DEFW 	Sound_group0_pointer				;; 1276 Sound_group0_pointer (Sound ID 0x0x)
	DEFW 	Sound_group1_pointer 				;; 1264 Sound_group1_pointer (Sound ID 0x4x)
	DEFW 	Sound_group2_pointer 				;; 1252 Sound_group2_pointer (Sound ID 0x8x)

;; -----------------------------------------------------------------------------------------------------------
;; table of Sound data pointer for group 8x
.Sound_group2_pointer:							;; Sound ID &8x
	DEFW 	Voice_data_noise					;; &134E 80 Walking
	DEFW 	Voice_data_ID81 					;; &1364 81 Running
	DEFW 	Voice_data_ID82 					;; &1374 82 (descending sequence - faster)
	DEFW 	Voice_data_ID83 					;; &1388 83 Fall
	DEFW 	Voice_data_ID84 					;; &1394 84 (Repeated rising sequence)
	DEFW 	Voice_data_ID85 					;; &13A2 85 (higher blip)
	DEFW 	Voice_data_ID86 					;; &13A7 86 (high blip)
	DEFW 	Voice_data_ID87 					;; &13AC 87 (sweep down and up)
	DEFW 	Voice_data_ID88 					;; &13B7 88 Menu blip

;; -----------------------------------------------------------------------------------------------------------
;; table of Sound data pointer for group 4x
.Sound_group1_pointer:							;; Sound ID &4x
	DEFW 	Voice_data_ID40						;; &1282 40 Blacktooth
	DEFW 	Voice_data_ID41						;; &128F 41 Market
	DEFW 	Voice_data_ID42						;; &12A2 42 Egyptus
	DEFW 	Voice_data_ID43						;; &12C5 43 Penitentiary
	DEFW 	Voice_data_ID44						;; &12E1 44 Moon base
	DEFW 	Voice_data_ID45						;; &12F0 45 Book world
	DEFW 	Voice_data_ID46						;; &1304 46 Safari
	DEFW 	Voice_data_ID47						;; &1313 47 Teleport waiting
	DEFW 	Voice_data_ID48						;; &131C 48 Donut firing

;; -----------------------------------------------------------------------------------------------------------
;; table of Sound data pointer for group 0x
.Sound_group0_pointer:							;; Sound ID &0x
	DEFW 	Voice_data_ID00						;; &1347 00 ????????
	DEFW 	Voice_data_ID01						;; &1341 01 ????????
	DEFW 	Voice_data_ID02						;; &135C 02 ????????
	DEFW 	Voice_data_ID03						;; &1330 03 Didididip
	DEFW 	Voice_data_ID04						;; &1325 04 GlouGlouGlou
	DEFW 	Voice_data_ID05						;; &133A 05 Beep / Cannon

;; -----------------------------------------------------------------------------------------------------------
;; Sounds data for 1 channel sounds 4x, 0x, 8x
.Voice_data_ID40:																	;; 40 Blacktooth
	DEFB 	&C0, &0E, &34, &4E, &5C, &6C, &74, &6C, &5E, &44, &26, &FF, &FF
.Voice_data_ID41:																	;; 41 Market
	DEFB 	&D0, &0E, &6E, &96, &6E, &56, &FF, &01, &34, &36, &FF, &0E, &7C, &6C, &54, &6E
	DEFB 	&47, &FF, &FF
.Voice_data_ID42:																	;; 42 Egyptus
	DEFB 	&C3, &03, &94, &8C, &94, &8C, &FF, &26, &76, &FF, &61, &6A, &72, &8A, &FF, &22
	DEFB 	&8A, &FF, &03, &94, &8C, &74, &8C, &94, &AC, &A4, &94, &FF, &26, &8F, &FF, &22
	DEFB 	&80, &FF, &FF
.Voice_data_ID43:																	;; 43 Penitentiary
	DEFB 	&60, &02, &6C, &96, &04, &96, &8C, &96, &94, &96, &FF, &0F, &8C, &FF, &01, &AA
	DEFB 	&FF, &41, &B2, &FF, &22, &B4, &FF, &02, &04, &96, &FF, &FF
.Voice_data_ID44:																	;; 44 Moon base
	DEFB 	&A8, &0F, &35, &35, &55, &6D, &6E, &04, &55, &56, &04, &35, &36, &FF, &FF
.Voice_data_ID45:																	;; 45 Book world
	DEFB 	&90, &0E, &0C, &36, &24, &35, &45, &4E, &44, &4D, &35, &26, &34, &25, &0D, &FF
	DEFB 	&0E, &27, &FF, &FF
.Voice_data_ID46:																	;; 46 Safari
	DEFB 	&40, &02, &36, &0C, &24, &36, &0C, &24, &34, &4C, &0C, &4C, &36, &FF, &FF
.Voice_data_ID47:																	;; 47 Teleport waiting
	DEFB 	&F0, &67, &10, &F6, &06, &16, &07, &FF, &FF
.Voice_data_ID48:																	;; 48 Donut firing
	DEFB 	&27, &50, &51, &BB, &FF, &5D, &97, &FF, &FF
.Voice_data_ID04:																	;; 04 GlouGlouGlou
	DEFB 	&03, &CA, &44, &F0, &0F, &FF, &8C, &01, &0C, &FF, &FF
.Voice_data_ID03:																	;; 03 Didididip
	DEFB 	&A0, &40, &30, &6C, &31, &6C, &41, &6C, &FF, &FF
.Voice_data_ID05:																	;; 05 Beep
	DEFB 	&B3, &47, &10, &43, &00, &FF, &FF
.Voice_data_ID01:																	;; 01 ????????
	DEFB 	&00, &86, &82, &12, &FF, &FF
.Voice_data_ID00:																	;; 00 ????????
	DEFB 	&03, &86, &41
.Voice_data_Silence:																;; Sound ID &C0 (Silence) V0,1 and 2
	DEFB 	&11, &03, &FF, &FF
.Voice_data_noise:																	;; 80 Walking
	DEFB 	&D3, &29, &31, &51, &01, &41, &29, &01, &31, &19, &01, &29, &41, &01
.Voice_data_ID02:																	;; 02 ????????
	DEFB 	&FF, &00, &F3, &EB, &E3, &DB, &FF, &FF				;; The "FF 00" is the end of "80 Walking"
.Voice_data_ID81:																	;; 81 Running
	DEFB 	&D3, &09, &31, &51, &00, &41, &29, &00, &31, &19, &00, &29, &41, &00, &FF, &00
.Voice_data_ID82:																	;; 82 (descending sequence - faster)
	DEFB 	&D3, &09, &F3, &EB, &E3, &DB, &EB, &E3, &DB, &D3, &E3, &DB, &D3, &CB, &DB, &D3
	DEFB 	&CB, &C3, &FF, &00
.Voice_data_ID83:																	;; 83 Fall
	DEFB 	&D3, &09, &BB, &A3, &8B, &73, &5B, &43, &2B, &23, &FF, &00
.Voice_data_ID84:																	;; 84 (Repeated rising sequence)
	DEFB 	&D3, &09, &13, &33, &53, &73, &93, &B3, &D3, &DB, &E3, &EE, &FF, &00
.Voice_data_ID85:																	;; 85 (higher blip)
	DEFB 	&78, &05, &33, &FF, &FF
.Voice_data_ID86:																	;; 86 (high blip)
	DEFB 	&60, &25, &33, &FF, &FF
.Voice_data_ID87:																	;; 87 (sweep down and up)
	DEFB 	&D3, &60, &34, &6A, &FF, &09, &01, &BA, &BA, &FF, &FF
.Voice_data_ID88:																	;; 88 Menu blip
	DEFB 	&90, &44, &10, &43, &00, &FF, &FF

;; -----------------------------------------------------------------------------------------------------------
;; remaining data to HQ sounds C1, C2, C5, C8:
.Voice_data_C1_V0:																	;; Sound ID &C1 Voice 0 "Tada!"
	DEFB 	&90, &41, &0C, &36, &FF, &02, &35, &35, &35, &45, &35, &45, &FF, &41, &56, &FF
	DEFB 	&21, &57, &FF, &FF
.Voice_data_C1_V1:																	;; Sound ID &C1 Voice 1 "Tada!"
	DEFB 	&90, &41, &0C, &6E, &FF, &02, &6D, &6D, &6D, &7D, &6D, &7D, &FF, &41, &D5, &FF
	DEFB 	&21, &D2, &D7, &FF, &FF
.Voice_data_C1_V2:																	;; Sound ID &C1 Voice 2 "Tada!"
	DEFB 	&90, &41, &0C, &E6, &FF, &02, &B5, &B5, &B5, &C5, &B5, &C5, &FF, &41, &8D, &FF
	DEFB 	&21, &8A, &8F, &FF, &FF
.Voice_data_C2_V0:																	;; Sound ID &C2 Voice 0 Hornpipe
	DEFB 	&63, &02, &B2, &BA, &CC, &34, &34, &6A, &5A, &52, &6A, &92, &8A, &94, &C2, &CA
	DEFB 	&DC, &44, &44, &A2, &92, &8A, &92, &8A, &7A, &6E, &FF, &FF
.Voice_data_C2_V1:																	;; Sound ID &C2 Voice 1 Hornpipe
	DEFB 	&C0, &03, &92, &8A, &94, &34, &54, &6A, &5A, &52, &6A, &92, &8A, &94, &8A, &92
	DEFB 	&A4, &44, &64, &A2, &92, &8A, &92, &8A, &7A, &6D, &FF, &FF
.Voice_data_C2_V2:																	;; Sound ID &C2 Voice 2 Hornpipe
	DEFB 	&30, &02, &04, &36, &0E, &56, &36, &46, &1E, &64, &54, &47, &FF, &FF
.Voice_data_C5_V0:																	;; Sound ID &C5 Voice 0 Dum-diddy-dum
	DEFB 	&33, &43, &09, &33, &FF, &08, &36, &56, &5E, &66, &6C, &0C, &04, &FF, &02, &32
	DEFB 	&37, &FF, &FF
.Voice_data_C5_V1:																	;; Sound ID &C5 Voice 1 Dum-diddy-dum
	DEFB 	&F0, &08, &04, &96, &86, &7E, &76, &6C, &06, &FF, &41, &94, &FF, &3E, &97, &FF
	DEFB 	&FF
.Voice_data_C5_V2:																	;; Sound ID &C5 Voice 2 Dum-diddy-dum
	DEFB 	&C0, &22, &04, &96, &86, &7E, &76, &6C, &06, &FF, &41, &6C, &FF, &2E, &6F, &FF
	DEFB 	&FF
.Voice_data_C8_V0:																	;; Sound ID &C8 Voice 0 Teleport down
	DEFB 	&A0, &7B, &F0, &A6, &5E, &FF, &7C, &3E, &FF, &FF
.Voice_data_C8_V1:																	;; Sound ID &C8 Voice 1 Teleport down
	DEFB 	&B8, &7B, &C0, &A6, &5E, &FF, &7C, &3E, &FF, &52, &27, &FF, &FF
.Voice_data_C8_V2:																	;; Sound ID &C8 Voice 2 Teleport down
	DEFB 	&C3, &FC, &02, &C0, &A6, &5E, &FF, &FB, &44, &3E, &FF, &FF

;; -----------------------------------------------------------------------------------------------------------
;; BlitMaskNofM does a masked blit into a dest buffer assumed 6 bytes wide.
;; The blit is from a source N bytes wide in a buffer M bytes wide.
;; The height is in B.
;; Destination is BC', source image is in DE', mask is in HL'.
.BlitMask1of3:
	EXX
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC HL
	INC DE
	LD A,C
	ADD A,&06
	LD C,A
	INC HL
	INC DE
	INC HL
	INC DE
	EXX
	DJNZ BlitMask1of3
	RET

.BlitMask2of3:
	EXX
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC C
	INC HL
	INC DE
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC HL
	INC DE
	LD A,C
	ADD A,&05
	LD C,A
	INC HL
	INC DE
	EXX
	DJNZ BlitMask2of3
	RET

.BlitMask3of3:
	EXX
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC C
	INC HL
	INC DE
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC C
	INC HL
	INC DE
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC HL
	INC DE
	LD A,C
	ADD A,&04
	LD C,A
	EXX
	DJNZ BlitMask3of3
	RET

.BlitMask1of4:
	EXX
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC HL
	INC DE
	LD A,C
	ADD A,&06
	LD C,A
	INC HL
	INC DE
	INC HL
	INC DE
	INC HL
	INC DE
	EXX
	DJNZ BlitMask1of4
	RET

.BlitMask2of4:
	EXX
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC C
	INC HL
	INC DE
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC HL
	INC DE
	LD A,C
	ADD A,&05
	LD C,A
	INC HL
	INC DE
	INC HL
	INC DE
	EXX
	DJNZ BlitMask2of4
	RET

.BlitMask3of4:
	EXX
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC C
	INC HL
	INC DE
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC C
	INC HL
	INC DE
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC HL
	INC DE
	LD A,C
	ADD A,&04
	LD C,A
	INC HL
	INC DE
	EXX
	DJNZ BlitMask3of4
	RET

.BlitMask4of4:
	EXX
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC C
	INC HL
	INC DE
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC C
	INC HL
	INC DE
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC C
	INC HL
	INC DE
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC HL
	INC DE
	INC C
	INC C
	INC C
	EXX
	DJNZ BlitMask4of4
	RET

.BlitMask1of5:
	EXX
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC HL
	INC DE
	LD A,C
	ADD A,&06
	LD C,A
	INC HL
	INC DE
	INC HL
	INC DE
	INC HL
	INC DE
	INC HL
	INC DE
	EXX
	DJNZ BlitMask1of5
	RET

.BlitMask2of5:
	EXX
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC C
	INC HL
	INC DE
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC HL
	INC DE
	LD A,C
	ADD A,&05
	LD C,A
	INC HL
	INC DE
	INC HL
	INC DE
	INC HL
	INC DE
	EXX
	DJNZ BlitMask2of5
	RET

.BlitMask3of5:
	EXX
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC C
	INC HL
	INC DE
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC C
	INC HL
	INC DE
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC HL
	INC DE
	LD A,C
	ADD A,&04
	LD C,A
	INC HL
	INC DE
	INC HL
	INC DE
	EXX
	DJNZ BlitMask3of5
	RET

.BlitMask4of5:
	EXX
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC C
	INC HL
	INC DE
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC C
	INC HL
	INC DE
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC C
	INC HL
	INC DE
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC HL
	INC DE
	INC C
	INC C
	INC C
	INC HL
	INC DE
	EXX
	DJNZ BlitMask4of5
	RET

.BlitMask5of5:
	EXX
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC C
	INC HL
	INC DE
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC C
	INC HL
	INC DE
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC C
	INC HL
	INC DE
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC C
	INC HL
	INC DE
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC HL
	INC DE
	INC C
	INC C
	EXX
	DJNZ BlitMask5of5
	RET

;; -----------------------------------------------------------------------------------------------------------
;; When we need to draw pillar sprites below a Door, this is the height of the pillars.
;; In multiples of 6.
.PillarHeight:
	DEFB 	&00

;; -----------------------------------------------------------------------------------------------------------
;; Re-fills the Pillar sprite buffer. Preserves 16b registers.
.FillPillarBuf:
	PUSH 	DE
	PUSH 	BC
	PUSH 	HL
	LD 		A,(PillarHeight)
	CALL 	DrawPillarBuf
	POP 	HL
	POP 	BC
	POP 	DE
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Redraws the Pillar in PillarBuf, pillar height in A.
;; In function of the height, the middle part will be stacked as many times as needed
;; Output: pointer on result sprite in DE.
.SetPillarHeight:
	LD 		(PillarHeight),A							;; PillarHeight
.DrawPillarBuf:
	PUSH 	AF											;; preserve A
	LD 		HL,PillarBuf + MOVE_OFFSET
	LD 		BC,296										;; Erase from &B898 length &0128 (296) bytes ; 296 = 32 (btm) + 72 (top) + 4*48 (a max of 4 mid part)
	CALL 	Erase_forward_Block_RAM						;; clear pillar buffer
	XOR 	A
	LD 		(IsPillarBufFlipped),A						;; reset Flip bit
	DEC 	A											;; FF
	LD 		(hasPillarUnderDoor),A						;; reset "Has Under Door" bit
	POP 	AF											;; restore A
	AND 	A											;; test
	RET 	Z											;; if 0 (height of 0) RET Z set, else:
	;; Otherwise, draw in reverse from end of buffer PillarBuf...
	LD 		DE,PillarBuf+296 - 1 + MOVE_OFFSET			;; PillarBuf + PillarBufLen - 1 (B9A0 to B9BF)
	LD 		HL,image_pillar_btm+32 - 1 + MOVE_OFFSET	;; image_pillar_btm + 4 * 4 - 1 (last byte of image_pillar_btm) (B878 to B897)
	LD 		BC,32										;; length in bytes : 32 = 4 * 4 * 2
	LDDR												;; Copy Pillar Bottom in pillar buffer
drawPillarLoop:
	SUB 	6											;; add as many 6-row tall mid pillars as needed (1 to 4)
	JR 		Z,drawPillarTop
	LD 		HL,img_pillar_mid+48 - 1 + MOVE_OFFSET		;; img_pillar_mid + 4 * 6 - 1 (last byte of img_pillar_mid) (B848 to B877)
	LD 		BC,48										;; length in bytes : 48 = 4 * 6 * 2
	LDDR												;; Copy Pillar Mid in pillar buffer
	JR 		drawPillarLoop								;; until desired height is reached
drawPillarTop:
	LD 		HL,img_pillar_top+72 - 1 + MOVE_OFFSET		;; img_pillar_top + 4 * 9 - 1 (last byte of img_pillar_top) (B800 to B847)
	LD 		BC,72										;; length in bytes : 72 = 4 * 9 * 2
	LDDR												;; Copy Pillar Top in pillar buffer
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Given extents stored in ViewXExtent and ViewYExtent,
;; draw the appropriate piece of screen background into
;; ViewBuff (to be drawn over and blitted to display later)
;; Buffer to write to is assumed to be 6 bytes wide.
.DrawBkgnd:
	LD 		HL,(ViewXExtent)							;; ViewXExtent
	;; H contains start, L end, in double-pixels
	LD 		A,H											;; HL = x min and max
	RRA
	RRA													;; 4 pix per byte
	LD 		C,A											;; Start byte number stashed in C for later.
	AND 	&3E											;; Clear lowest bit to get 2x double column index...
	EXX
	LD 		L,A
	LD 		H,BackgrdBuff / 256							;; &6A = BackgrdBuff >> 8 ; BackgrdBuff is page-aligned. 6Aaa
	EXX													;; Set HL' to column info
	;; Calculate width to draw, in bytes
	LD 		A,L
	SUB 	H											;; delta Xmax-Xmin = X width
	RRA
	RRA
	AND 	&07
	SUB 	2
	LD		DE,DestBuff									;; destination buffer
	;; Below here, DE points at the sprite buffer, and HL' the
    ;; source data (two bytes per column pair). A contains number
    ;; of cols to draw, minus 2.
    ;; If index is initially odd, draw RHS of a column pair.
	RR		C
	JR		NC,dbg_1
	LD		IY,ClearOne
	LD		IX,OneColBlitR
	LD		HL,BlitFloorR
	CALL 	DrawBkgndCol
	CP 		&FF
	RET 	Z
	SUB 	1
	JR 		dbg_2

dbg_1:
	;; Draw two columns at a time.
	LD		IY,ClearTwo
	LD		IX,TwoColBlit
	LD		HL,BlitFloor
	CALL 	DrawBkgndCol
	INC 	E											;; We did 2 columns this time, so do one more.
	SUB 	2
dbg_2:
	JR 		NC,dbg_1
	;; One left-over column.
	INC 	A
	RET 	NZ
	LD		IY,ClearOne
	LD		IX,OneColBlitL
	LD		HL,BlitFloorL
	LD		(smc_blitfloor_fnptr+1),HL					;; value at &1849 ; self mod code of JP
	EXX
	JR		DrawBkgndCol2

;; -----------------------------------------------------------------------------------------------------------
;; ???TODO??? Performs register-saving and incrementing HL'/E. Not needed
;; for the last call from DrawBkgnd.
.DrawBkgndCol:
	LD 		(smc_blitfloor_fnptr+1),HL						;; value at &1849 ; self mod code of JP
	PUSH	DE
	PUSH	AF
	EXX
	PUSH	HL
	CALL 	DrawBkgndCol2
	POP		HL
	INC		L
	INC		L
	EXX
	POP		AF
	POP		DE
	INC		E
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Reads from ViewYExtent
;; * Takes in:
;;   HL' - Floor drawing function
;;   DE' - Destination buffer (only modified via IX, IY, etc.)
;;   IX  - Copying function (takes &rows in A, writes to DE' and updates it)
;;   IY  - Clearing function (takes &rows in A, writes to DE' and updates it)
;;   HL  - Pointer to BackgrdBuff array entry:
;;           Byte 0: Y of wall bottom (0 = clear)
;;           Byte 1: Id for wall panel sprite
;;                   (0-3 - world-specific, 4 - Pillar, 5 - blank, | &80 to flip)
;; Note that the Y coordinates are downward-increasing, matching memory.
;; The basic walls are 56 pixels high
SHORT_WALL     			EQU 	56				;; &38
;; Pillar/spaces (indices 4 and 5) are up to 74 pixels high, made up
;; of top, repeated middle and bottom section.
TALL_WALL	      		EQU 	74				;; &4A =  (9 + 24 + 4) * 2
EDGE_HEIGHT				EQU 	&0B

.DrawBkgndCol2:
	LD 		DE,(ViewYExtent)
	LD 		A,E
	SUB 	D
	LD 		E,A											;; E now contains height
	LD 		A,(HL)
	AND 	A
	JR 		Z,DBC_Clear									;; Baseline of zero? Clear full height, then
	LD 		A,D
	SUB 	(HL)
	LD 		D,A											;; D holds how many lines we are below the bottom of the wall
	JR 		NC,DBC_DoFloor								;; Positive? Then skip to drawing the floor.
	;; In this case, we handle the viewing window starting above
	;; the start of the floor.
	INC 	HL
	LD 		C,SHORT_WALL								;; Wall height for ids 0-3
	BIT 	2,(HL)
	JR 		Z,dbcflag
	LD 		C,TALL_WALL									;; pillar height for ids 4-5
.dbcflag:
	ADD 	A,C											;; Add the wall height on.
	;; Window Y start now relative to the top of the current wall panel.
	JR 		NC,DBC_TopSpace 							;; Still some space left above in window? Jump
	;; Start drawing some fraction through the wall panel
	ADD 	A,A
	CALL 	GetOffsetWall
	EXX
	LD 		A,D
	NEG
	JP 		DBC_Wall

;; We start before the top of the wall panel, so we'll start off by clearing above.
;; A holds -number of rows to top of wall panel, E holds number of rows to write.
.DBC_TopSpace:
	NEG
	CP 		E
	JR 		NC,DBC_Clear				    			;; If we're /only/ drawing space, do the tail call.
	;; Clear the appropriate amount of space.
	LD 		B,A
	NEG
	ADD 	A,E
	LD 		E,A
	LD 		A,B
	CALL 	DoJumpIY									;; call the Clear function in IY
	;; Get the pointer to the wall panel bitmap to copy in...
	LD 		A,(HL)
	EXX
	CALL 	GetWall
	EXX
	;; and the height to use
	LD 		A,SHORT_WALL
	BIT 	2,(HL)
	JR 		Z,DBC_Wall
	LD 		A,TALL_WALL
;; Now draw the wall. A holds number of lines of wall to draw, source in HL'
.DBC_Wall:
	CP 		E
	JR 		NC,dbc_copy					     			;; Window ends in the wall panel? Tail call
	;; Otherwise, copy the full wall panel, and then draw the floor etc.
	LD 		B,A
	NEG
	ADD 	A,E
	EX 		AF,AF'
	LD 		A,B
	CALL 	DoJumpIX
	EX 		AF,AF'
	LD 		D,0
	JR 		DBC_FloorEtc

.dbc_copy:
	LD		A,E
	JP 		(IX)										;; Copy A rows from HL' to DE'. TO CHECK : &1A67, &1A80, &1A6C

.DBC_Clear:
	LD 		A,E
	JP 		(IY)										;; Clear A rows at DE'. TO CHECK : &19B6, &19C5, &19B6

;; Point we jump to if we're initially below the top edge of the floor.
.DBC_DoFloor:
	LD 		A,E
	INC 	HL
;; Code to draw the floor, bottom edge, and any space below
;;
;; At this point, HL has been incremented by 1, A contains
;; number of rows to draw, D contains number of lines below
;; bottom of wall we're at.
;; First, calculate the position of the bottom edge.
.DBC_FloorEtc:
	LD 		B,A											;; Store height in B
	DEC 	HL											;; And go back to original pointer location
	LD 		A,L											;; L contained column number & ~1
	ADD		A,A
	ADD		A,A						 					;; The bottom edge goes down 4 pixels for each
	ADD		A,4											;; byte across, so multiply by 4 and add 4.
;; Compare A with the position of the corner, to determine the
;; play area edge graphic to use, by overwriting the smc_whichEdge
;; operand. A itself is adjusted around the corner position.
smc_CornerPos:
	CP 		&00
	;;1803 DEFB 00															; self-modifying code
	JR		c,DBC_Left
	LD 		E,&00										;; DBEdge_Right - DBEdge_Right = 0 ; Right edge graphic case
	JR 		NZ,DBC_Right
	LD 		E,DBEdge_Center - DBEdge_Right				;; DBEdge_Center - DBEdge_Right = 5 ; Corner edge graphic case
.DBC_Right:
	SUB 	4
.smc_RightAdj:
	ADD 	A,&00
	;;180F DEFB 00															; self-modifying code
	JR 		DBC_CrnrJmp
.DBC_Left:
	ADD 	A,4
	NEG
.smc_LeftAdj:
	ADD 	A,&00
	;;1817 DEFB 00															; self-modifying code. 1817
	LD 		E,DBEdge_Left - DBEdge_Right				;; DBEdge_Left - DBEdge_Right = 8 ; Left edge graphic case
;; Store coordinate of bottom edge in C, write out edge graphic
.DBC_CrnrJmp:
	NEG
	ADD 	A,EDGE_HEIGHT
	LD 		C,A
	LD 		A,E
	LD 		(smc_whichEdge+1),A							;; self mod code 186E, value of the relative displacement of the JR ???? (08 or 05)
	;; Find out how much remains to be drawn
	LD 		A,(HL)										;; Load Y baseline
	ADD 	A,D											;; Add to offset start to get original start again.
	INC 	HL
	SUB 	C											;; Calculate A (onscreen start) - C (screen end of image)
	JR 		NC,subclr				   					;; <= 0 -> Reached end, so clear buffer
	ADD 	A,EDGE_HEIGHT
	JR 		NC,dbcfloor									;; > 11 -> Some floor and edge
	 ;; 0 < Amount to draw <= 11
	LD 		E,A											;; Now we see if we'll reach the end of the bottom edge
	SUB 	EDGE_HEIGHT
	ADD 	A,B
	JR 		c,DBC_AllBottom								;; Does the drawing window extend to the edge and beyond?
	LD 		A,B					 						;; No, so only draw B lines of edge
	JR 		DrawBottomEdge

;; Case where we're drawing
.DBC_AllBottom:
	PUSH 	AF
	SUB 	B
	NEG													;; Draw the bottom edge, then any remaining lines cleared
    ;; Expects number of rows of edge in A, starting row in E,
    ;; draws bottom edge and remaining blanks in DE'. Number of
    ;; blank rows pushed on stack.
.DBC_Bottom:
	CALL 	DrawBottomEdge
	POP 	AF
	RET 	Z
	JP 		(IY)										;; Clear A rows at DE'

.subclr:
	LD 		A,B
	JP 		(IY)										;; Clear A rows at DE'

;; Draw some floor. A contains -height before reaching edge,
;; B contains drawing window height.
.dbcfloor:
	ADD 	A,B
	JR 		c,DBC_FloorNEdge							;; Need to draw some floor and also edge.
	LD 		A,B											;; Just draw a window-height of floor.
BlitFloorFnPtr:
smc_blitfloor_fnptr:
	JP 		&0000
	;;1849 DEFW	00 00       												; JP 0000 ; self-modifying code: is set during exec at BlitFloorR &1A31, BlitFloor &1A04, BlitFloorL &1A3E

;; Draw the floor and then edge etc.
.DBC_FloorNEdge:
	PUSH 	AF
	SUB 	B
	NEG
	CALL 	BlitFloorFnPtr
	POP 	AF
	RET 	Z
	;; Having drawn the floor, do the same draw edge/draw edge and blank space
    ;; test we did above for the no-floor case
	SUB 	EDGE_HEIGHT
	LD 		E,0
	JR 		NC,DBC_EdgeNSpace
	ADD 	A,EDGE_HEIGHT
	JR 		DrawBottomEdge

.DBC_EdgeNSpace:															;; Draw-the-edge-and-then-space case
	PUSH 	AF
	LD 		A,EDGE_HEIGHT
	JR 		DBC_Bottom

;; Takes starting row number in E, number of rows in A, destination in DE'
;; Returns an updated DE' pointer.
.DrawBottomEdge:
	PUSH 	DE
	EXX
	POP 	HL
	LD 		H,0
	ADD 	HL,HL
	ADD 	HL,HL
	LD 		BC,LeftEdge
smc_whichEdge:
	JR 		DBEdge_Left									;; DBEdge_Left by default, modified to DBEdge_Center
	;;186E DEFB 08															; Default JR 08= Jump to 1877 (DBEdge_Left) : JR 05= Jump to 1874 (DBEdge_Center); self-modifying code.
DBEdge_Right:
	LD 		BC,RightEdge
	JR 		DBEdge_Left
DBEdge_Center:
	LD 		BC,CornerEdge
DBEdge_Left:
	ADD 	HL,BC
	EXX													;; BC, DE, HL exchange with prime regs
	;; Copies from HL' to DE', number of rows in A.
	JP 		(IX)

;; -----------------------------------------------------------------------------------------------------------
;; Data to draw the edge of the rooms
.LeftEdge:
	;; 4 bytes * 11  interlaced :
	;;     2 bytes x 11 (height) mask and
	;;     2 bytes x 11 for image
	;; in memory : maskwall1 + wall1 + maskwall2 + wall2 (each are 1byte wide * 11 rows)
	DEFB 	&00, &40, &00, &00, &00, &70, &00, &00, &04, &74, &00, &00, &07, &77, &00, &00
	DEFB 	&07, &37, &00, &40, &07, &07, &00, &70, &03, &03, &04, &74, &00, &00, &07, &77
	DEFB 	&00, &00, &07, &37, &00, &00, &07, &07, &00, &00, &03, &03
	;; Displaying the images and masks as "mask1+mask2 wall1+wall2"
	;; (reminder: in mem it's mask1+wall1+mask2+wall2)
	;; so it is easier to see.
	;; To visualize the sprite&mask result, let's use this:
	;;	 bit	 bit
	;;	image	mask	result
	;;	0 (.)   0 (.)	Black (X)
	;;	1 (@)   0 (.)	Color (c) (touch of color, depends on current color scheme)
	;;	0 (.)   1 (@)	Transparent (_)
	;;	1 (@)   1 (@)	Cream (.) (main body color)
	;;
	;;	................ .@.............. XcXXXXXXXXXXXXXX
	;;  ................ .@@@............ XcccXXXXXXXXXXXX
	;;  .....@.......... .@@@.@.......... XcccX.XXXXXXXXXX
	;;  .....@@@........ .@@@.@@@........ XcccX...XXXXXXXX
	;;  .....@@@........ ..@@.@@@.@...... XXccX...XcXXXXXX
	;;  .....@@@........ .....@@@.@@@.... XXXXX...XcccXXXX
	;;  ......@@.....@.. ......@@.@@@.@.. XXXXXX..XcccX.XX
	;;  .............@@@ .........@@@.@@@ XXXXXXXXXcccX...
	;;  .............@@@ ..........@@.@@@ XXXXXXXXXXccX...
	;;  .............@@@ .............@@@ XXXXXXXXXXXXX...
	;;  ..............@@ ..............@@ XXXXXXXXXXXXXX..

.RightEdge:
	DEFB 	&00, &00, &03, &03, &00, &00, &0F, &0F, &00, &00, &1F, &1F, &00, &00, &5F, &1F
	DEFB 	&03, &03, &5C, &1C, &0F, &0F, &50, &10, &1F, &1F, &40, &00, &5F, &1F, &00, &00
	DEFB 	&5C, &1C, &00, &00, &50, &10, &00, &00, &40, &00, &00, &00

	;;  ..............@@ ..............@@ XXXXXXXXXXXXXX..
	;;  ............@@@@ ............@@@@ XXXXXXXXXXXX....
	;;  ...........@@@@@ ...........@@@@@ XXXXXXXXXXX.....
	;;  .........@.@@@@@ ...........@@@@@ XXXXXXXXXcX.....
	;;  ......@@.@.@@@.. ......@@...@@@.. XXXXXX..XcX...XX
	;;  ....@@@@.@.@.... ....@@@@...@.... XXXX....XcX.XXXX
	;;  ...@@@@@.@...... ...@@@@@........ XXX.....XcXXXXXX
	;;  .@.@@@@@........ ...@@@@@........ XcX.....XXXXXXXX
	;;  .@.@@@.......... ...@@@.......... XcX...XXXXXXXXXX
	;;  .@.@............ ...@............ XcX.XXXXXXXXXXXX
	;;  .@.............. ................ XcXXXXXXXXXXXXXX

.CornerEdge:
	DEFB 	&00, &40, &03, &03, &00, &70, &0F, &0F, &04, &74, &1F, &1F, &07, &77, &5F, &1F
	DEFB 	&07, &37, &5C, &1C, &07, &07, &50, &10, &03, &03, &40, &00, &00, &00, &00, &00
	DEFB 	&00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00

	;;  ..............@@ .@............@@ XcXXXXXXXXXXXX..
	;;  ............@@@@ .@@@........@@@@ XcccXXXXXXXX....
	;;  .....@.....@@@@@ .@@@.@.....@@@@@ XcccX.XXXXX.....
	;;  .....@@@.@.@@@@@ .@@@.@@@...@@@@@ XcccX...XcX.....
	;;  .....@@@.@.@@@.. ..@@.@@@...@@@.. XXccX...XcX...XX
	;;  .....@@@.@.@.... .....@@@...@.... XXXXX...XcX.XXXX
	;;  ......@@.@...... ......@@........ XXXXXX..XcXXXXXX
	;;  ................ ................ XXXXXXXXXXXXXXXX
	;;  ................ ................ XXXXXXXXXXXXXXXX
	;;  ................ ................ XXXXXXXXXXXXXXXX
	;;  ................ ................ XXXXXXXXXXXXXXXX

;; -----------------------------------------------------------------------------------------------------------
;; Takes the room origin in BC, and stores it, and then updates the edge patterns
;; to include a part of the floor pattern.
.TweakEdges:
	LD 		HL,(FloorAddr)
	;; ZX-spectrum has this here : "LD (RoomOrigin),BC"
	LD 		BC,&000A									;; 2*5
	ADD		HL,BC										;; Move 5 rows into the tile
	LD 		C,&10										;; 2*8
	LD 		A,(Has_Door)
	RRA
	PUSH 	HL											;; Push this address.
	JR 		NC,txedg_1									;; If bottom bit of Has_Door is set...
	ADD 	HL,BC
	EX 		(SP),HL										;; Move 8 rows further on the stack-saved pointer
txedg_1:
	ADD 	HL,BC										;; In any case, move 8 rows on HL...
	RRA
	JR 		NC,txedg_2									;; Unless the next bit of Has_Door was set
	AND 	A
	SBC 	HL,BC
	;; Copy some of the left column of the floor into the right edge.
txedg_2:
	LD 		DE,RightEdge    							;; Call once to tweak right edge
	CALL 	TweakEdgesInner
	;; Then copy some of the right column of the floor pattern to the left.
	POP 	HL
	INC 	HL
	LD 		DE,LeftEdge+2								;; then again to tweak left edge
;; Copy 4 bytes, skipping every second byte. Used to copy part of the
;; floor pattern into one side of the top of the edge pattern.
;; Edge pattern in DE, floor in HL.
.TweakEdgesInner:
	LD 		A,4
tei_1:
	LDI													;; do once : LD (DE),(HL); DE++, HL++, BC--
	INC		HL
	INC		DE
	INC		DE
	INC		DE
	DEC		A
	JR 		NZ,tei_1
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Wrap up a call to GetWall, and add in the starting offset from A.
;; TODO
.GetOffsetWall:
	PUSH 	AF											;; stack offset in A
	LD 		A,(HL)
	EXX
	CALL 	GetWall
	POP 	AF
	ADD 	A,A
	PUSH 	AF
	ADD 	A,L											;; this does...
	LD 		L,A
	ADC 	A,H
	SUB 	L
	LD 		H,A											;; ...HL = HL + A
	POP 	AF
	RET 	NC
	INC 	H
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Zero means Pillar buffer is zeroed, non-zero means filled with Pillar image.
hasPillarUnderDoor:
	DEFB 	&00

;; Returns PillarBuf in HL.
;; If hasPillarUnderDoor is non-zero, it zeroes the buffer, and the flag.
.GetEmptyPillarBuf:
	LD 		A,(hasPillarUnderDoor)						;; do we have pillar under the door?
	AND 	A											;; test
	LD 		HL,PillarBuf + MOVE_OFFSET					;; HL = &B898 = PillarBuf
	RET 	Z											;; leave if pillar buffer empty, else:
	PUSH 	HL
	PUSH 	BC
	PUSH 	DE
	LD 		BC,296										;; Erase block of &0128 bytes
	CALL 	Erase_forward_Block_RAM
	POP 	DE
	POP 	BC
	POP 	HL
	XOR 	A
	LD 		(hasPillarUnderDoor),A						;; reset hasPillarUnderDoor
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Called by GetWall for high-index sprites, to draw the space under a door
;;   A=5 -> blank space, A=4 -> Pillars
.GetUnderDoor:
	BIT 	0,A											;; Low bit nonzero?
	JR 		NZ,GetEmptyPillarBuf						;; we draw nothing below the door (clear buffer)
	LD 		L,A											;; else we'll draw a pillar; L = pillar id + flip bit7
	LD 		A,(hasPillarUnderDoor)						;; get pillar buffer flag (0=empty, none-0=not empty)
	AND 	A											;; test
	CALL 	Z,FillPillarBuf								;; if buffer empty, fill the buffer with pillar
	LD 		A,(IsPillarBufFlipped)						;; needs to be flipped? in bit7
	XOR 	L											;; match with pillar id bit7 (result bit7 = 0 means pillar id bit7 and IsPillarBufFlipped bit7 identical, result bit7 = 1, different)
	RLA													;; get result bit7 in Carry
	LD 		HL,PillarBuf + MOVE_OFFSET					;; HL = &B898 PillarBuf
	RET 	NC						 					;; Return PillarBuf if no flip required...
	LD 		A,(IsPillarBufFlipped)						;; Otherwise...
	XOR 	%10000000									;; flip IsPillarBufFlipped bit7.
	LD 		(IsPillarBufFlipped),A
	LD 		B,TALL_WALL									;; B = &4A
	JP 		FlipPillar									;; and Flip Pillar image

;; -----------------------------------------------------------------------------------------------------------
;; Get a wall section/panel (id 0 to 3, cases 4 and 5 are the space under
;; a door (blank or pillars) and handled by GetUnderDoor).
;; In A : 0-3 - world-specific, 4 - Pillar, 5 - blank, + &80 to flip.
;; Top bit represents whether flip is required.
;; Return: Pointer to data in HL. Panel id in A, Carry if flip required
.GetWall:
	BIT 	2,A											;; check bit2 for cases 4 and 5 handled by GetUnderDoor.
	JR 		NZ,GetUnderDoor								;; if bit2=1 (cases 4 or 5) goto GetUnderDoor
	PUSH 	AF											;; else stack A
	CALL 	NeedsFlip2					 				;; Check if panel flip is required
	EX 		AF,AF'										;; save Carry in F'
	POP 	AF											;; get panel id back
	CALL 	GetPanelAddr								;; HL = corresponding wall panel Sprite id (function of worldId and panel selection id in A)
	EX 		AF,AF'										;; get back Carry and panel id
	RET 	NC											;; no flip required, leave
	JP 		FlipPanel									;; else flip sprite ; will ret

;; -----------------------------------------------------------------------------------------------------------
;; Takes a Wall panel id in A.
;; If the top bit was set (bit7 = needs flip), we flip the bit in
;; corresponding PanelFlips if necessary,
;; Return: Carry if a modification in PanelFlips was needed.
;; Return: A the flip bitmap
.NeedsFlip2:
	LD 		C,A											;; In A : 0-3 - world-specific, 4 - Pillar, 5 - blank, + &80 to flip.
	LD 		HL,(Walls_PanelFlipsPtr)					;; get current wall "PanelFlips + WorldId"
	AND 	&03											;; wall panel id
	LD 		B,A											;; B = id
	INC 	B											;; B = id + 1
	LD 		A,%00000001									;; wandering bit starts at bit0
nf2_wander1loop:
	RRCA												;; circular right rotate ...
	DJNZ 	nf2_wander1loop								;; ... B times
	LD 		B,A											;; bitmap bit7: id0, bit6: id1, bit5: id2, bit4: id3
	AND 	(HL)										;; compare with Walls_PanelFlipsPtr
	JR 		NZ,nf2_2									;; if that bit is set then nf2_2
	RL 		C											;; else get bit7 in carry
	RET 	NC											;; if bit7 was 0, leave with NC, else:
	LD 		A,B											;; bitmap
	OR 		(HL)										;; add set flip bit corresponding to current panel id to "PanelFlips + WorldId"
	LD 		(HL),A										;; and update "PanelFlips + WorldId" value
	SCF													;; leave with Carry set in that case
	RET

nf2_2:
	RL 		C											;; get flip bit (bit7) in Carry
	CCF													;; invert it
	RET 	NC											;; it was 1, so return with NC
	LD 		A,B											;; else, get bitmap
	CPL													;; invert all bits in A
	AND 	(HL)
	LD 		(HL),A										;; and turn off the flipping bit for current panel id in "PanelFlips + WorldId"
	SCF													;; return with Carry set
	RET

;; -----------------------------------------------------------------------------------------------------------
.DoJumpIX:
	JP 		(IX)										;; Call the copying function
.DoJumpIY:
	JP 		(IY)										;; Call the clearing function

;; -----------------------------------------------------------------------------------------------------------
;; Zero a single column of the 6-byte-wide buffer at DE' (A rows).
.ClearOne:
	EXX
	LD 		B,A
	EX 		DE,HL
	LD 		E,0
clro_1:
	LD 		(HL),E
	LD 		A,L
	ADD 	A,6
	LD 		L,A
	DJNZ 	clro_1
	EX 		DE,HL
	EXX
	RET

;; Zero two columns of the 6-byte-wide buffer at DE' (A rows).
.ClearTwo:
	EXX
	LD 		B,A
	EX 		DE,HL
	LD 		E,0
clr2_1:
	LD 		(HL),E
	INC 	L
	LD 		(HL),E
	LD 		A,L
	ADD 	A,5
	LD 		L,A
	DJNZ 	clr2_1
	EX 		DE,HL
	EXX
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Set FloorAddr to the floor sprite indexed in A.
;; HL : pointer on the floor tile patterns selected; also copied into FloorAddr.
.SetFloorAddr:
	LD 		C,A											;; C = index
	ADD 	A,A											;; *2
	ADD 	A,C											;; *3
	ADD 	A,A											;; *6
	ADD 	A,A											;; *12
	ADD 	A,A											;; *24
	LD 		L,A
	LD 		H,0											;; HL=index*24
	ADD 	HL,HL										;; *48 = &30 (floor tile size in bytes)
	LD 		DE,floor_tile_pattern0 + MOVE_OFFSET		;; IMG_2x24 ; The floor tile images. Base addr for floor tile patterns is floor_tile_pattern0; the move offset is to get the addr after the init 6600 block move
	ADD 	HL,DE										;; base+tile_data_offset ; Add to floor tile base to get the pointer on the tile data we want.
	LD 		(FloorAddr),HL								;; store the addr in FloorAddr
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Address of the sprite data used to draw the floor.
;; This is updated by SetFloorAddr.
.FloorAddr:     															;; IMG_2x24 + 2 * &30
	DEFW 	floor_tile_pattern1 + MOVE_OFFSET			;; default = floor_tile_pattern1 + MOVE_OFFSET

;; -----------------------------------------------------------------------------------------------------------
;; HL' points to the floor sprite id.
;; If it's floor tile 5, we return a blank floor tile (no floor).
;; Otherwise we return the current tile address pointer, plus an
;; offset C (0 or 2*8), in BC.
.GetFloorAddr:
	PUSH 	AF
	EXX													;; get HL' (pointer on the floor sprite ID in the 6A?? buffer)
	LD 		A,(HL)										;; get floor sprite ID
	OR 		&FA											;; ~5; test if floor sprite ID = 5 (&FA or &05 + 1 = 0)
	INC 	A											;; If the wall sprite id is 5 (space) then A = 0 (Zero flag set) at this point
	EXX													;; Restore not prime 16b reg
	JR 		Z,Blank_Tile								;; Floor tile ID 5 = No floor, else:
	LD 		A,C											;; else:
	LD 		BC,(FloorAddr)								;; get the floor_tile_pattern<n> pointer
	ADD 	A,C											;; Add old C to FloorAddr and return in BC.
	LD 		C,A
	ADC		A,B
	SUB 	C
	LD 		B,A											;; BC = BC + A
	POP 	AF
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Use the empty floor tile (no floor) if floor sprite ID = 5
.Blank_Tile:
	LD 		BC,floor_tile_pattern7 + MOVE_OFFSET		;; IMG_2x24 + 7 * &30
	POP 	AF
	RET													;; Return the blank tile

;; -----------------------------------------------------------------------------------------------------------
;; Fill a 6-byte-wide buffer at DE' with both columns of a floor tile.
;; A contains the number of rows to generate.
;; D contains the initial offset in rows.
;; HL points to the floor sprite id.
;; The +0 or +16 in C below will align the left part (+0) and the right
;; part (+16 : flipped side) of the floor tiles in the Y axis:
;;    /|\
;;    \|/
.BlitFloor:
	LD 		B,A
	LD		A,D
	;; Move down 8 rows if top bit of (HL) is set,
    ;; i.e. if we're on the flipped side.
	BIT 	7,(HL)										;; Flip bit of the sprite ID
	EXX													;; The floor sprite ID is now pointed by HL'
	LD 		C,0											;; not flipped : C offset = 0
	JR 		Z,bf_1
	LD 		C,&10										;; Flipped : C offset = 2*8 : this will realign the right part of the floor tiles
bf_1:
	CALL 	GetFloorAddr								;; BC will point on floor tile data
	;; Construct offset in HL from original D. Double it as tile is 2 wide.
	AND 	&0F
	ADD 	A,A
	LD 		H,0
	LD 		L,A
	EXX
	;; At this point we have source in BC', destination in DE',
    ;; offset of source in HL', and number of rows to copy in B.
bf_2:
	EXX
	PUSH 	HL
	;; Copy both bytes of the current row into the 6-byte-wide buffer.
	ADD 	HL,BC
	LD 		A,(HL)
	LD 		(DE),A
	INC 	HL
	INC 	E
	LD 		A,(HL)
	LD 		(DE),A
	LD 		A,E
	ADD 	A,5
	LD 		E,A
	POP 	HL
	LD 		A,L
	ADD 	A,2
	;; Floor tiles are 24 pixels high. Depending on odd/even, we
    ;; start at offset 0 or 16 (8 rows in). So, if we read offsets
    ;; 0..31 (rows 0..15) from there, we get the right data, and
    ;; can safely wrap.
	AND 	&1F
	LD 		L,A
	EXX
	DJNZ 	bf_2
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Fill a 6-byte-wide buffer at DE' with the right column of background tile.
;; A  contains number of rows to generate.
;; D  contains initial offset in rows.
;; HL contains pointer to wall sprite id.
.BlitFloorR:
	LD 		B,A
	LD 		A,D
	;; Move down 8 rows if top bit of (HL) is set.
    ;; Do the second column of the image (the extra +1)
	BIT 	7,(HL)
	EXX
	LD 		C,&01
	JR 		Z,bfl_1
	LD 		C,&11										;; 2*8+1
	JR 		bfl_1

;; -----------------------------------------------------------------------------------------------------------
;; Fill a 6-byte-wide buffer at DE' with the left column of background tile.
;; A  contains number of rows to generate.
;; D  contains initial offset in rows.
;; HL contains pointer to wall sprite id.
;; (This is to refresh the background (floor tiles) when a sprite moves)
.BlitFloorL:
	LD 		B,A
	LD 		A,D
	;; Move down 8 rows if top bit of (HL) is set.
	BIT 	7,(HL)
	EXX
	LD 		C,&00
	JR 		Z,bfl_1
	LD 		C,&10											;; 2*8
	;; Get the address (using HL' for wall sprite id)
bfl_1:
	CALL 	GetFloorAddr
	;; Construct offset in HL from original D. Double it as tile is 2 wide.
	AND 	&0F
	ADD 	A,A
	LD 		H,0
	LD 		L,A
	EXX
	;; At this point we have source in BC', destination in DE',
    ;; offset of source in HL', and number of rows to copy in B.
bfl_2:
	EXX
	PUSH 	HL
	;; Copy 1 byte into 6-byte-wide buffer
	ADD 	HL,BC
	LD 		A,(HL)
	LD 		(DE),A
	LD 		A,E
	ADD 	A,6
	LD 		E,A
	POP 	HL
	LD 		A,L
	ADD 	A,2
	AND 	&1F
	LD 		L,A												;; Add 1 row to source offset pointer, mod 32
	EXX
	DJNZ 	bfl_2
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Blit from HL' to DE', right byte of a 2-byte-wide sprite in a 6-byte wide buffer.
;; Number of rows in A.
;; (This is to refresh the background (especially if in front of a wall) when a sprite moves)
.OneColBlitR:
	EXX
	INC 	HL
	INC 	HL
	JR 		ocbt_1
;; Blit from HL' to DE', left byte of a 2-byte-wide sprite in a 6-byte wide buffer.
;; Number of rows in A.
.OneColBlitL:
	EXX
ocbt_1:
	LD 		B,A
ocbt_2:
	LD 		A,(HL)
	LD 		(DE),A
	INC 	HL
	DEC 	D
	LD 		A,(HL)
	LD 		(DE),A
	INC		D
	INC		HL
	INC		HL
	INC		HL
	LD 		A,E
	ADD 	A,6
	LD 		E,A
	DJNZ 	ocbt_2
	EXX
	RET

;; Blit from HL' to DE', a 2-byte-wide sprite in a 6-byte wide buffer.
;; Number of rows in A.
.TwoColBlit:
	EXX
	LD 		B,A
tcbl_1:
	LD 		A,(HL)
	LD 		(DE),A
	INC		HL
	DEC 	D
	LD 		A,(HL)
	LD 		(DE),A
	INC 	HL
	LD 		C,(HL)
	INC 	HL
	INC 	E
	LD 		A,(HL)
	LD 		(DE),A
	INC 	HL
	INC 	D
	LD 		A,C
	LD 		(DE),A
	LD 		A,E
	ADD 	A,5
	LD 		E,A
	DJNZ 	tcbl_1
	EXX
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Reverse a two-byte-wide image.
;; * FlipPanel : pointer to data in HL
;; 		Flip a normal wall panel
;; 		Used to flip the wall sprite for the right side of the screen.
;; * FlipPillar : Height in B, pointer to data in HL.
.FlipPanel:
	LD 		B,SHORT_WALL								;; &38
.FlipPillar:
	PUSH 	DE
	LD 		D,RevTable / 256							;; &69 = RevTable >> 8
	PUSH 	HL
fcol_1:
	LD 		(smc_dest_addr2+1),HL						;; self mod code at 1AB8, value of LD (...),A
	LD 		E,(HL)
	LD 		A,(DE)
	INC 	HL
	LD 		E,(HL)
	LD 		(smc_dest_addr1+1),HL						;; self mod code at 1AB3, value of LD (...),A
	INC 	HL
	LD 		C,(HL)
	LD 		(HL),A
	INC 	HL
	LD 		A,(DE)
	LD 		E,(HL)
	LD 		(HL),A
	LD 		A,(DE)
smc_dest_addr1:
	LD 		(&0000),A									;; addr self modified at 1AA7
	;;1AB3 DEFW 00 00
	LD 		E,C
	LD 		A,(DE)
smc_dest_addr2:
	LD 		(&0000),A									;; addr self modified at 1AA0
	;;1AB8 DEFW 00 00
	INC 	HL
	DJNZ 	fcol_1
	POP 	HL
	POP 	DE
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Top bit is set if the column image buffer is flipped
IsPillarBufFlipped:
	DEFB 	&00

;; -----------------------------------------------------------------------------------------------------------
;; Return the wall panel address in HL, given panel index in A.
.GetPanelAddr:
	AND 	&03											;; Limit to 0-3
	ADD 	A,A											;; *2
	ADD 	A,A											;; *4
	LD 		C,A											;; =*4
	ADD 	A,A											;; *8
	ADD 	A,A											;; *16
	ADD 	A,A											;; *32
	SUB 	C											;; *28
	ADD 	A,A											;; *56
	LD 		L,A
	LD 		H,0
	ADD 	HL,HL										;; *112
	ADD 	HL,HL										;; = 2 x 112 (img and mask)
	LD 		BC,(Walls_PanelBase)						;; base addr
	ADD 	HL,BC										;; add offset to Walls_PanelBase in HL and return.
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Given sprite data, return a rotated version of it.
;;
;; A holds the rotation size (in 2-bit units).
;; At start, HL holds source image, DE hold mask image.
;; At end, HL holds dest image, DE holds mask image.
;; A' is incremented.
;; The sprite width and number of bytes are read from SpriteWidth and
;; SpriteRowCount. SpriteWidth is incremented. Uses 'Buffer'.
.BlitRot:
	DEC 	A
	ADD 	A,A
	EXX
	LD 		C,A
	LD 		B,0											;; Load rotation size into BC, and function table into HL.
	LD 		A,(Sprite_Width)							;; get Sprite_Width
	INC 	A											;; width + 1
	LD 		(Sprite_Width),A							;; update Sprite_Width
	CP 		&05
	LD 		HL,BlitRot3s								;; Default to BlitRot on 3 case.
	JR 		NZ,btrot_0
	LD 		HL,BlitRot4s								;; SpriteWidth was 4 -> Use the BlitRot on 4 case.
btrot_0
	ADD 	HL,BC
	;; Dereference function pointer into HL.
	LD 		A,(HL)
	INC 	HL
	LD		H,(HL)
	LD		L,A
	;; And modify the code.
	LD 		(smc_btrot_1+1),HL							;; Update the CALL addr at 1B06 (self modifying code)
	LD 		(smc_btrot_2+1),HL							;; Update the CALL addr at 1B11 (self modifying code)
	EXX
	EX 		AF,AF'
	PUSH 	AF
	;; Time to rotate the sprite.
	LD 		A,(SpriteRowCount)							;; get SpriteRowCount
	PUSH 	DE
	LD 		DE,&6FC0									;; Buffer
	LD 		B,&00										;; Blank space in the filler.
	DI
smc_btrot_1:
	CALL 	&0000										;; default : "CALL 0000" ; addr updated at line 1AF2 (self modifying code)
	;;1B06 DEFW 00 00														; modified 1AF2
	;; HL now holds the end of the destination buffer.
	EX 		DE,HL
	POP 	HL
	PUSH 	DE
	;; And to rotate the mask.
	LD 		A,(SpriteRowCount)							;; get SpriteRowCount
	LD 		B,&FF										;; Appropriate filler for the mask.
smc_btrot_2:
	CALL 	&0000										;; default "CALL 0000" ; addr updated at line 1AF5 (self modifying code)
	;;1B11 DEFW 00 00														; modified at 1AF5
	LD 		HL,&6FC0									;; buffer
	POP 	DE
	EI
	POP 	AF
	INC 	A
	EX 		AF,AF'
	RET

;; -----------------------------------------------------------------------------------------------------------
;; pointers on the BlitRot* function to use
BlitRot3s:
	DEFW 	BlitRot2on3					;; BlitRot2on3 1B2A
	DEFW 	BlitRot4on3					;; BlitRot4on3 1BE0
	DEFW 	BlitRot6on3					;; BlitRot6on3 1B85
BlitRot4s:
	DEFW 	BlitRot2on4					;; BlitRot2on4 1C03
	DEFW 	BlitRot4on4					;; BlitRot4on4 1C71
	DEFW 	BlitRot6on4					;; BlitRot6on4 1C3A

;; -----------------------------------------------------------------------------------------------------------
Save_Stack_ptr:
	DEFW 	&0000

;; -----------------------------------------------------------------------------------------------------------
;; Do a copy with 2-bit shift.
;; Source HL, width 3 bytes.
;; Destination DE, width 4 bytes.
;; A contains byte-count, B contains filler character
;; Returns next space after destination write in HL
.BlitRot2on3:
	LD		(Save_Stack_ptr),SP
	LD		C,&3E											;; C = &3E = "LD A,vv" ; vv (filler) in B
	LD		(smc_br23_1),BC									;; self mod the filler value in B in the instruction at 1B49
	LD		(smc_br23_2),BC									;; self mod the filler value in B in the instruction at 1B63
	LD		SP,HL
	EX		DE,HL
	SRL 	A
	JR 		NC,br23_1
	INC 	A
	EX 		AF,AF'
	POP 	BC
	LD 		B,C
	DEC 	SP
	JP 		br23_2

br23_1:
	EX 		AF,AF'
	POP 	DE
	POP		BC
smc_br23_1:
	LD 		A,&00											;; the value (contained in B) will be modified at 1B30; self mod code
	RRCA
	RR 		E
	RR 		D
	RR 		C
	RRA
	RR		E
	RR		D
	RR		C
	RRA
	LD 		(HL),E
	INC 	HL
	LD		(HL),D
	INC		HL
	LD 		(HL),C
	INC 	HL
	LD		(HL),A
	INC 	HL
br23_2:
	POP 	DE
smc_br23_2:
	LD 		A,&00											;; the value (contained in B) will be modified at 1B34 ; self mod code
	RRCA
	RR		B
	RR		E
	RR		D
	RRA
	RR		B
	RR		E
	RR		D
	RRA
	LD 		(HL),B
	INC 	HL
	LD 		(HL),E
	INC 	HL
	LD 		(HL),D
	INC 	HL
	LD 		(HL),A
	INC		HL
	EX		AF,AF'
	DEC		A
	JR		NZ,br23_1
	LD		SP,(Save_Stack_ptr)
	RET

;; Do a copy with 6-bit shift.
;; Source HL, width 3 bytes.
;; Destination DE, width 4 bytes.
;; A contains byte-count, B contains filler character
;; Returns next space after destination write in HL
.BlitRot6on3:
	LD		(Save_Stack_ptr),SP
	LD		C,&3E											;; C = &3E = "LD A,vv" ; vv (filler) in B
	LD		(smc_br63_1),BC									;; self mod the filler value in B in the instruction at 1BA4
	LD		(smc_br63_2),BC									;; self mod the filler value in B in the instruction at 1BBE
	LD		SP,HL
	EX		DE,HL
	SRL 	A
	JR 		NC,br63_1
	INC 	A
	EX 		AF,AF'
	POP 	BC
	LD 		B,C
	DEC 	SP
	JP 		br63_2

br63_1:
	EX 		AF,AF'
	POP 	DE
	POP 	BC
smc_br63_1:
	LD 		A,&00											;; the value (contained in B) will be modified at 1B8B ; self mod code
	RLCA
	RL		C
	RL		D
	RL		E
	RLA
	RL		C
	RL		D
	RL		E
	RLA
	LD 		(HL),A
	INC 	HL
	LD 		(HL),E
	INC 	HL
	LD 		(HL),D
	INC 	HL
	LD 		(HL),C
	INC		HL
br63_2:
	POP 	DE
smc_br63_2:
	LD 		A,&00											;; the value (contained in B) will be modified at 1B8F ; self mod code
	RLCA
	RL		D
	RL		E
	RL		B
	RLA
	RL		D
	RL		E
	RL		B
	RLA
	LD 		(HL),A
	INC		HL
	LD 		(HL),B
	INC		HL
	LD		(HL),E
	INC		HL
	LD		(HL),D
	INC		HL
	EX		AF,AF'
	DEC		A
	JR		NZ,br63_1
	LD		SP,(Save_Stack_ptr)
	RET

;; Do a copy with 4-bit shift.
;; Source HL, width 3 bytes.
;; Destination DE, width 4 bytes.
;; A contains byte-count, B contains filler character
;; Returns next space after destination write in HL
.BlitRot4on3:
	LD		C,B
	LD		B,A
	LD		A,C
	PUSH 	BC
	LD 		C,&FF
	PUSH 	DE
br43_1:
	LDI													;; do once : LD (DE),(HL); DE++, HL++, BC--
	LDI													;; do once : LD (DE),(HL); DE++, HL++, BC--
	LDI													;; do once : LD (DE),(HL); DE++, HL++, BC--
	LD 		(DE),A
	INC 	DE
	DJNZ 	br43_1
	POP 	HL
	POP		BC
	LD 		A,C
br43_2:
	RRD													;; RRD = nibbles circular right rotation in the 12b value composed by A[3:0] and (HL)
	INC		HL
	RRD													;; RRD = nibbles circular right rotation in the 12b value composed by A[3:0] and (HL)
	INC		HL
	RRD													;; RRD = nibbles circular right rotation in the 12b value composed by A[3:0] and (HL)
	INC		HL
	RRD													;; RRD = nibbles circular right rotation in the 12b value composed by A[3:0] and (HL)
	INC		HL
	DJNZ 	br43_2
	RET

;; Do a copy with 2-bit shift.
;; Source HL, width 3 bytes.
;; Destination DE, width 4 bytes.
;; A contains byte-count, B contains filler character
;; Returns next space after destination write in HL
.BlitRot2on4:
	LD		(Save_Stack_ptr),SP
	LD		C,&3E										;; C = &3E = "LD A,vv" ; vv (filler) in B
	LD		(smc_bt24_1),BC								;; self mod the filler value in B in the instruction at 1C12
	LD		SP,HL
	EX		DE,HL
br24_1:
	EX		AF,AF'
	POP 	DE
	POP 	BC
smc_bt24_1:
	LD 		A,&00										;; the value (contained in B) will be modified at 1C09 ; self mod code
	RRCA
	RR		E
	RR		D
	RR		C
	RR		B
	RRA
	RR		E
	RR		D
	RR		C
	RR		B
	RRA
	LD 		(HL),E
	INC 	HL
	LD 		(HL),D
	INC 	HL
	LD 		(HL),C
	INC		HL
	LD		(HL),B
	INC		HL
	LD		(HL),A
	INC		HL
	EX		AF,AF'
	DEC		A
	JR		NZ,br24_1
	LD		SP,(Save_Stack_ptr)
	RET

;; Do a copy with 6-bit shift.
;; Source HL, width 3 bytes.
;; Destination DE, width 4 bytes.
;; A contains byte-count, B contains filler character
;; Returns next space after destination write in HL
.BlitRot6on4:
	LD		(Save_Stack_ptr),SP
	LD		C,&3E										;; C = &3E = "LD A,vv" ; vv (filler) in B
	LD		(smc_br64_1),BC								;; self mod the filler value in B in the instruction at 1C49
	LD		SP,HL
	EX		DE,HL
bt64_1:
	EX		AF,AF'
	POP 	DE
	POP 	BC
smc_br64_1:
	LD 		A,&00										;; the value (contained in B) will be modified at 1C40 ; self mod code
	RLCA
	RL		B
	RL		C
	RL		D
	RL		E
	RLA
	RL		B
	RL		C
	RL		D
	RL		E
	RLA
	LD		(HL),A
	INC		HL
	LD		(HL),E
	INC		HL
	LD 		(HL),D
	INC 	HL
	LD 		(HL),C
	INC 	HL
	LD 		(HL),B
	INC		HL
	EX		AF,AF'
	DEC		A
	JR		NZ,bt64_1
	LD		SP,(Save_Stack_ptr)
	RET

;; Do a copy with 4-bit shift.
;; Source HL, width 3 bytes.
;; Destination DE, width 4 bytes.
;; A contains byte-count, B contains filler character
;; Returns next space after destination write in HL
.BlitRot4on4:
	LD		C,B
	LD		B,A
	LD		A,C
	PUSH 	BC
	LD 		C,&FF
	PUSH 	DE
brot44_1:
	LDI													;; do once : LD (DE),(HL); DE++, HL++, BC--
	LDI
	LDI
	LDI
	LD 		(DE),A
	INC		DE
	DJNZ 	brot44_1
	POP		HL
	POP		BC
brot44_2:
	RRD													;; RRD = nibbles circular right rotation in the 12b value composed by A[3:0] and (HL)
	INC		HL
	RRD													;; RRD = nibbles circular right rotation in the 12b value composed by A[3:0] and (HL)
	INC		HL
	RRD													;; RRD = nibbles circular right rotation in the 12b value composed by A[3:0] and (HL)
	INC		HL
	RRD													;; RRD = nibbles circular right rotation in the 12b value composed by A[3:0] and (HL)
	INC		HL
	RRD													;; RRD = nibbles circular right rotation in the 12b value composed by A[3:0] and (HL)
	INC		HL
	DJNZ 	brot44_2
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Sprite variables
;; LSB is upper extent, MSB is lower extent
;; X extent is in screen units (2 pixels per unit).
;; Units increase down and to the right.
ViewXExtent:
	DEFW	&6066
ViewYExtent:
	DEFW	&5070
SpriteXStart:
	DEFB	&00
SpriteRowCount:
	DEFB	&00
ObjXExtent:
	DEFW	&0000
ObjYExtent:
	DEFW	&0000
SpriteFlags:
	DEFB	&00

;; -----------------------------------------------------------------------------------------------------------
;; Update the object extent
;; Hl object pointer, calculate and store the object extents.
.StoreObjExtents:
	INC 	HL
	INC 	HL
	CALL 	GetObjExtents						;; calculate object extent
	LD 		(ObjXExtent),BC						;; store Xextent
	LD 		(ObjYExtent),HL						;; store Yextent
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Takes object in HL, gets union of the extents of that object and
;; Obj[XY]Extent. Returns X extent in HL, Y extent in DE.
.UnionExtents:
	INC 	HL
	INC 	HL
	CALL 	GetObjExtents
	LD 		DE,(ObjYExtent)
	LD 		A,H
	CP 		D
	JR 		NC,unext_1							;; D = min(D, H)
	LD 		D,H
unext_1:
	LD 		A,E
	CP 		L
	JR 		NC,unext_2							;; E = max(E, L)
	LD 		E,L
unext_2:
	LD 		HL,(ObjXExtent)
	LD 		A,B
	CP 		H
	JR 		NC,unext_3							;; H = min(B, H)
	LD 		H,B
unext_3:
	LD 		A,L
	CP 		C
	RET 	NC									;; L = max(C, L)
	LD 		L,C
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Takes X extent in HL, rounds it to the byte, and stores in ViewXExtent.
.PutXExtent:
	LD 		A,L									;; Round L up
	ADD 	A,&03								;; &03
	AND 	&FC									;; align on a mult of 4 value (bits[1:0] = 2b00)
	LD 		L,A
	LD 		A,H
	AND 	&FC									;; ~&03 ; Round H down
	LD 		H,A
	LD 		(ViewXExtent),HL
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Takes X extent in HL and Y extent in DE.
.DrawXSafe:
	CALL 	PutXExtent
	JR 		Draw_small_start

;; If the end's before Y_START, give up. Otherwise bump the start down
;; and continue.
.BumpYMinAndDraw:
	LD 		A,Y_START
	CP 		E
	RET 	NC
	LD 		D,Y_START
	JR 		DrawCore

.UnionAndDraw:
	CALL 	UnionExtents

;; -----------------------------------------------------------------------------------------------------------
;; Draw a given range of the screen, drawing into ViewBuff and then
;; blitting to the screen. This entry point sanity-checks the extents
;; first.
;; X extent in HL, Y extent in DE
.Draw_View:
	CALL 	PutXExtent
	;; Check the Y extent - give up if it's too far down.
	LD 		A,E
	CP 		&F1
	RET 	NC
;; Check the Y extent size - give up if it's negative.
;; If the start's less than Y_START, do a special case.
.Draw_small_start:
	LD 		A,D
	CP 		E
	RET 	NC
	CP 		Y_START
	JR 		c,BumpYMinAndDraw
;; The core drawing routine: Draw the background to the view buffer,
;; draw the sprites, and then copy it to the screen.
;; Y extent passed in through DE.
.DrawCore:
	LD 		(ViewYExtent),DE
	CALL 	DrawBkgnd
	LD 		A,(Has_no_wall)
	AND 	&0C
	JR 		Z,drwc_1
	;; Skip next room in V if &08 not set.
	LD 		E,A
	AND 	&08
	JR 		Z,drwc_2
	;; Next room in V appears on left of screen...
    ;; Skip if left of X extent is right of CornerX
	LD		BC,(ViewXExtent)
	LD		HL,Walls_CornerX
	LD		A,B
	CP		(HL)
	JR		NC,drwc_2
	;; Skip if min Y extent plus min X is greater than ScreenMaxV
	LD 		A,(ViewYExtent+1)
	ADD 	A,B
	RRA
	LD		D,A
	LD		A,(Walls_ScreenMaxV)
	CP		D
	JR		c,drwc_2
	;; Draw the next room in the V direction.
	LD 		HL,ObjectLists + 4									;; ObjectLists + 1*4
	PUSH 	DE
	CALL 	Blit_Objects
	POP 	DE
	;; Skip next room in U if &04 not set.
	BIT 	2,E
	JR		Z,drwc_1
	;; Next room in U appears on right of screen...
    ;; Skip if right of X extent is left of CornerX
drwc_2:
	LD 		BC,(ViewXExtent)
	LD 		A,(Walls_CornerX)
	CP 		C
	JR 		NC,drwc_1
	;; Skip if min Y minus max X is greater than Walls_ScreenMaxU
	LD 		A,(ViewYExtent+1)
	SUB 	C
	;; If it goes negative, top bit is reset, otherwise top bit is set.
    ;; Effectively, we add 128 as we RRA, allowing us to compare with Walls_ScreenMaxU.
	CCF
	RRA
	LD 		D,A
	LD 		A,(Walls_ScreenMaxU)
	CP 		D
	JR 		c,drwc_1
	;; Draw the next room in U direction.
	LD 		HL,ObjectLists + 8									;; ObjectLists + 2*4
	CALL 	Blit_Objects
drwc_1:
	LD 		HL,ObjectLists + 12									;; ObjectLists + 3*4 = Far
	CALL 	Blit_Objects
	LD 		HL,ObjectLists										;; Main object list
	CALL 	Blit_Objects
	LD 		HL,ObjectLists + 16  								;; ObjectLists + 4*4 = Near
	CALL 	Blit_Objects
	JP 		Blit_screen

;; -----------------------------------------------------------------------------------------------------------
;; Call Sub_BlitObject for each object in the linked list pointed to by
;; HL. Note that we're using the second link, so the passed HL is an
;; object + 2.
.Blit_Objects:
	LD 		A,(HL)
	INC 	HL
	LD 		H,(HL)												;; get new HL from curr HL
	LD 		L,A
	OR 		H													;; if new HL=0
	RET 	Z													;; then leave, else:
	LD 		(smc_CurrObject2+1),HL								;; self modify the value of LD HL,... at 1D70 (smc_CurrObject2+1)
	CALL 	Sub_BlitObject
smc_CurrObject2:
	LD 		HL,&0000											;; get next object in list ; addr at 1D71 is written above at 1D6A
	;;1D71 DEFW 00 00																; Self-modifying code
	JR 		Blit_Objects

;; -----------------------------------------------------------------------------------------------------------
;;  Set carry flag if there's overlap
;;  X adjustments in HL', X overlap in A'
;;  Y adjustments in HL,  Y overlap in A
.Sub_BlitObject:
	CALL 	IntersectObj
	RET 	NC													;; No intersection? Return
	LD 		(SpriteRowCount),A									;; update SpriteRowCount
	LD 		A,H
	;; Find sprite blit destination:
    ;; &ViewBuff[Y-low * 6 + X-low / 4]
    ;; (X coordinates are in 2-bit units, want byte coordinate)
	ADD 	A,A
	ADD 	A,H
	ADD 	A,A
	EXX
	SRL 	H
	SRL 	H
	ADD 	A,H
	LD 		E,A
	LD 		D,ViewBuff / 256									;; &67 = ViewBuff >> 8   ; &6700 + offset
	PUSH 	DE													;; Push destination.
	PUSH 	HL													;; Push X adjustments
	EXX
	;; A = SpriteWidth & 4 ? -L * 4 : -L * 3
    ;; (Where L is the Y-adjustment for the sprite)
	LD 		A,L
	NEG
	LD 		B,A
	LD 		A,(Sprite_Width)									;; get Sprite_Width
	AND 	&04
	LD 		A,B
	JR 		NZ,btobj_0
	ADD 	A,A
	ADD		A,B
	JR 		btobj_1
btobj_0:
	ADD 	A,A													;; *2
	ADD 	A,A													;; *4
btobj_1:
	PUSH 	AF
	;; Image and mask addressed loaded, and then adjusted by A.
	CALL 	Load_sprite_image_address_into_DE
	POP 	BC
	LD 		C,B
	LD 		B,0
	ADD 	HL,BC
	EX 		DE,HL
	ADD 	HL,BC
	;; Rotate the sprite if not byte-aligned.
	LD 		A,(SpriteXStart)
	AND 	&03
	CALL 	NZ,BlitRot
	;; Get X adjustment back.
	POP 	BC
	LD 		A,C
	NEG
	;; Rounded up divide by 4 to get byte adjustment...
	ADD 	A,&03
	RRCA
	RRCA
	;; and apply to image and mask.
	AND 	&07
	LD 		C,A
	LD 		B,0													;; BC = A
	ADD 	HL,BC
	EX 		DE,HL
	ADD 	HL,BC
	;; Set it so that destination is in BC', image and mask in HL' and DE'.
	POP 	BC
	EXX
	;; Load DE with an index from the blit functions table. This selects
    ;; the subtable based on the sprite width.
	LD 		A,(Sprite_Width)									;; get Sprite_Width
	SUB 	3
	ADD 	A,A
	LD 		E,A
	LD 		D,0
	LD 		HL,BlitMaskFns
	ADD 	HL,DE
	LD 		E,(HL)
	INC 	HL
	LD 		D,(HL)
	;; X overlap is still in A' from the IntersectObj call
	EX 		AF,AF'
	;; We use this to select the function within the subtable, which will
    ;; blit over n bytes worth, depending on the overlap size...
    ;; We convert the overlap in double-pixels into the overlap in bytes,
    ;; x2, to get the offset of the function in the table.
	DEC 	A
	RRA
	AND 	&0E
	LD 		L,A
	LD 		H,0
	ADD 	HL,DE
	LD 		A,(HL)
	INC 	HL
	LD 		H,(HL)
	LD 		L,A
	;; Call the blit function with number of rows in B, destination in
    ;; BC', source in DE', mask in HL'
	LD 		A,(SpriteRowCount)									;; get SpriteRowCount
	LD 		B,A
	JP 		(HL)					 							;; Tail call (ie. will RET) to blitter...

;; -----------------------------------------------------------------------------------------------------------
.BlitMaskFns:
	DEFW 	BlitMasksOf1				;; BlitMasksOf1 1DEB
	DEFW 	BlitMasksOf2				;; BlitMasksOf2 1DF1
	DEFW 	BlitMasksOf3				;; BlitMasksOf3 1DF9
.BlitMasksOf1:
	DEFW 	BlitMask1of3				;; BlitMask1of3 149A
	DEFW 	BlitMask2of3				;; BlitMask2of3 14B5
	DEFW 	BlitMask3of3				;; BlitMask3of3 14DD
.BlitMasksOf2:
	DEFW 	BlitMask1of4				;; BlitMask1of4 1512
	DEFW 	BlitMask2of4				;; BlitMask2of4 152F
	DEFW 	BlitMask3of4				;; BlitMask3of4 1559
	DEFW 	BlitMask4of4				;; BlitMask4of4 1590
.BlitMasksOf3:
	DEFW 	BlitMask1of5				;; BlitMask1of5 15D3
	DEFW 	BlitMask2of5				;; BlitMask2of5 15F2
	DEFW 	BlitMask3of5				;; BlitMask3of5 161E
	DEFW 	BlitMask4of5				;; BlitMask4of5 1657
	DEFW 	BlitMask5of5				;; BlitMask5of5 169C

;; -----------------------------------------------------------------------------------------------------------
;; Given an object, calculate the intersections with
;; ViewXExtent and ViewYExtent. Also saves the X start in SpriteXStart.
;;
;; Parameters: HL contains object+2
;; Returns:
;;  Set carry flag if there's overlap
;;  X adjustments in HL', X overlap in A'
;;  Y adjustments in HL,  Y overlap in A
.IntersectObj:
	CALL 	GetShortObjExt
	LD 		A,B
	LD		(SpriteXStart),A
	PUSH	HL
	LD 		DE,(ViewXExtent)
	CALL 	IntersectExtent
	EXX
	POP 	BC
	RET 	NC
	EX 		AF,AF'
	LD 		DE,(ViewYExtent)
	CALL 	IntersectExtent
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Like GetShortObjExt, except it copes with tall objects.
;; If bit5 is set, H is adjusted by -12, if bit5 not set then H adjusted by -16
;;
;; TODO: I expect bit 5 set means it's two chained objects, 6 Z units
;; (12 Y units) apart. I expect bit 5 reset means it's a 3x32 object,
;; so we include the other 16 height.
;;
;; Parameters: Object+2 in HL
;; Returns: X extent in BC, Y extent in HL
.GetObjExtents:
	INC 	HL
	INC 	HL
	LD 		A,(HL)
	BIT 	3,A												;; Tall bit set?
	JR 		Z,gsobjext_1										;; Tail call out if not tall.
	CALL 	gsobjext_1										;; Otherwise, call and return
	LD 		A,(SpriteFlags)
	BIT 	5,A												;; Chained object bit set?
	LD 		A,&F0											;; -16 ; Bit not set - add 16 to height.
	JR 		Z,goex_1
	LD 		A,&F4											;; -12 ; Bit set - add 12 to height.
goex_1:
	ADD 	A,H
	LD 		H,A												;; Bring min Y up.
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Sets SpriteFlags and generates extents for the object.
;; Parameters: Object+2 in HL
;; Returns: X extent in BC, Y extent in HL
.GetShortObjExt:
	INC 	HL
	INC 	HL												;; now HL points on O_FLAGS
	LD 		A,(HL)											;; get flags
	;; Put a flip flag in A if the "switched" bit is set on the object.
    ;; A = (object[4] & 0x10) ? 0x80 : 0x00
gsobjext_1:
	BIT 	4,A												;; test bit4
	LD 		A,&00
	JR 		Z,gsobjext_2
	LD 		A,&80
gsobjext_2:
	EX 		AF,AF'
	INC 	HL
	CALL 	UVZtoXY				 							;; Called with HL pointing on O_U
	INC 	HL
	INC 	HL												;; Now at object O_SPRFLAGS
	LD 		A,(HL)
	LD 		(SpriteFlags),A
	DEC 	HL												;; O_SPRITE
	EX 		AF,AF'
	XOR 	(HL)											;; Add extra horizontal flip to the sprite.
	JP 		GetSprExtents									;; will RET

;; -----------------------------------------------------------------------------------------------------------
;; Calculate parameters to do with overlapping extents
;; Parameters:
;;  BC holds extent of sprite
;;  DE holds current extent
;; Returns:
;;  Sets carry flag if there's any overlap.
;;  H holds the extent adjustment
;;  L holds the sprite adjustment
;;  A holds the overlap size.
.IntersectExtent:
    ;; Check overlap and return NC if there is none.
	LD 		A,D
	SUB 	C
	RET 	NC												;; C <= D, return
	LD 		A,B
	SUB 	E
	RET 	NC												;; E <= B, return
	;; There's overlap. Calculate it.
	NEG
	LD 		L,A												;; L = E - B
	LD 		A,B
	SUB 	D												;; A = B - D
	JR 		c,subIntersectExtent
	;; B >= D case
	LD 		H,A
	LD 		A,C
	SUB 	B
	LD 		C,L
	LD 		L,0
	CP 		C												;; Return A = min(C - B, E - B)
	RET 	c
	LD 		A,C
	SCF
	RET

.subIntersectExtent:
	LD		L,A
	LD		A,C
	SUB 	D
	LD 		C,A
	LD 		A,E
	SUB		D
	CP 		C
	LD 		H,0
	RET 	c					 							;; Return A = min(E - D, C - D)
	LD 		A,C
	SCF
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Given HP pointing to an Object + 5 (O_U)
;; Return X coordinate in C, Y coordinate in B.
;; Return: Increments HL by 2 (O_Z)
;; 		.----------> X
;; 		|  V   U							eg. U,V,Z = &24, &0C, &C0
;; 		|   \ /									BC = &CF98
;; 		|    |
;; 		|    Z
;; 		Y
.UVZtoXY:
	LD 		A,(HL)
	LD 		D,A											;; D = U coordinate
	INC 	HL
	LD 		E,(HL)										;; E = V coordinate
	SUB 	E
	ADD 	A,&80
	LD 		C,A											;; C = U - V + 128 = X coordinate
	INC 	HL
	LD 		A,(HL)										;; Z coordinate
	ADD 	A,A											;; x2 (note that, for exemple, ground level = &C0; &C0*2 = &80 because of the modulo 256)
	SUB 	E
	SUB 	D
	ADD 	A,&7F
	LD 		B,A						 					;; B = (2 * Z) - U - V + 127 = Y coordinate
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Pointer into stack for current origin coordinates
.DecodeOrgPtr:
	DEFW 	DecodeOrgStack	 							;; DecodeOrgStack pointer (1E8A)

;; Each stack entry contains UVZ coordinates
.DecodeOrgStack:
	DEFB 	&00, &00, &00
	DEFB 	&00, &00, &00
	DEFB 	&00, &00, &00
	DEFB 	&00, &00, &00

BaseFlags:																	;; object flags when builing a room
	DEFB 	&00
	DEFB 	&00

;; -----------------------------------------------------------------------------------------------------------
;; Offset 0&1: O_???? 'B' list next item pointer
;; Offset 2&3: O_???? 'A' list next item pointer
;; Offset 4: O_FLAGS : Some flags:
;;           	Bits 0-2: Object Dimensions - see GetUVZExtents
;;           	Bit 3: Tall (extra 6 height)
;;           	Bit 4: Holds switch status for a switch (from function 3rd byte bit7), the roller direction for rollers.
;;           	Bit 5: Used on doors by Case3x56.
;;           	For doors, bits 4 and 5 hold the direction.
;;           	Bit 6: Object is a special collectable item.
;;			 	bits 6 and 7 causes skipping.
;; Offset 5: O_U : U coordinate
;; Offset 6: O_V : V coordinate
;; Offset 7: O_Z : Z coordinate, C0 = ground
;; Offset 8: O_SPRITE : Sprite code
;; Offset 9: O_SPRFLAGS : Sprite flags:
;;           	Bit 0 - is it a playable character or an object/enemy?
;;           	Bit 1 - same thant bit0 but for 2ndpart double height? TODO????
;;           	Bit 2 = we're Head.
;;           	Bit 4 = TODO: 0:deadly, 1: harmless
;;           	Bit 5 = 0 single height (one sprite) ; 1 double size (i.e. 2 sprites, need to Animate and move both sprites together as a single object);
;;				bit 6 = Function disable : 0 = if object has function do it; 1 = do not do function
;;           	Bit 7 = hungry flag (may be stopped by a donut)
;;           	Gets loaded into SpriteFlags
;; Offset A: O_FUNC : Function and Phase
;;				Top bit is flag that's checked against Phase
;;			 	Lower 6 bits are object function.
;; Offset B: O_IMPACT
;;				Bottom 4 bits are roller direction... last move dir for updated things.
;; Offset C: O_????
;;				Some form of direction bitmask?
;;           	how we're being pushed.
;;				I think bit 5 means 'being stood on'.
;; Offset D&E: O_????
;;				Object we're resting on. zeroed on the floor. Forms a pointer?
;; Offset F: O_ANIM : Animation code
;;				top 5 bits [7:3] are the animation code ([7:0] = ((index in AnimTable * 2) + 2) << 2)
;;				bottom 3 bits [2:0] are the frame number.
;; Offset 10: O_DIRECTION : Direction code. (0:Down,1:South,2:Right,3:East,4:Up,5:North,6:Left,7:West or FF = don't move)
;; Offset 11: O_SPECIAL : This may be several things depending on context:
;;				Z limits for helipad (bit3 = 1:Ascent/0:Descent direction (note that, for instance, if set to 0, but already on the ground, it'll immediatly reverse direction), bit2:0 = low limit, bit7:4 = high limit)
;;				On/Off state for switch
;;				special indexd for specials items.
;; -----------------------------------------------------------------------------------------------------------
O_FLAGS					EQU 	&04
O_U						EQU 	&05
O_V						EQU 	&06
O_Z						EQU 	&07
O_SPRITE				EQU 	&08
O_SPRFLAGS				EQU 	&09
O_FUNC					EQU 	&0A
O_IMPACT				EQU		&0B
O_ANIM					EQU 	&0F
O_DIRECTION				EQU 	&10
O_SPECIAL				EQU 	&11

;; Buffer for an object used during unpacking
.TmpObj_variables:								;; 18 bytes
	DEFW 	&0000			;;	0&1 :
	DEFW 	&0000			;;	2&3 :
	DEFB 	&00				;;	4 : O_FLAGS
	DEFB 	&00				;;	5 : O_U coordinate
	DEFB 	&00				;;	6 : O_V coordinate
	DEFB 	&00				;;	7 : O_Z coordinate
	DEFB 	&00				;;	8 : O_SPRITE
	DEFB 	&00				;;	9 : O_SPRFLAGS
	DEFB 	&00				;;	A : O_FUNC
	DEFB 	&FF				;;	B :
	DEFB 	&FF				;;	C :
	DEFB 	&00				;;	D :
	DEFB 	&00				;;	E :
	DEFB 	&00				;;	F : O_ANIM
	DEFB 	&00				;;	10 : O_DIRECTION (dir code (0 to 7 or FF))
	DEFB 	&00				;;	11 : O_SPECIAL

;; Bit 0: Do we loop?
;; Bit 1: Are all the switch flags the same in the loop?
;; Bit 2: If they're the same, the value.
UnpackFlags:
	DEFB 	&00

DataPtr:
	DEFW 	&CD0E 					;; Current pointer to bit-packed data (FetchData) ; default data is a don't care
CurrData:
	DEFB	&05						;; The remaining bits to read at the current address.

ExpandDone:
	DEFB 	&00

DoorSprites:
	DEFB 	&00, &00				;; Sprites to use for L and R parts of the door.

;; -----------------------------------------------------------------------------------------------------------
;; Half-Door flags when building a room (the value will be copied in the object O_FLAGS).
;; Note that a door is composed of 2 half-doors objects.
;;
;; Bits [5:4] as follows (ie. which wall side):
;;   nw(left)=10/\01=ne(up)
;;   sw(down)=11\/00=se(right)
;; Bits [2:0]: UVZ extent:
;; 	      Umax Umin Vmax Vmin Zmax Zmin
;; 	* 7 : U+4, U,   V,   V-4, Z,   Z-18
;; 	* 6 : U,   U-4, V,   V-4, Z,   Z-18
;; 	* 5 : U+4, U,   V+4, V,   Z,   Z-18
;; 	* 4 : U,   U-4, V+4, V,   Z,   Z-18
Door_Obj_Flags: ;; L  R  L  R  L  R  L  R
	DEFB 	&27, &26, &17, &15, &05, &04, &36, &34

;; -----------------------------------------------------------------------------------------------------------
RoomDimensionsIdx:
	DEFB 	&00     					;; The room Dimensions for the main room.
RoomDimensionsIdxTmp:
	DEFB 	&00     					;; The room Dimensions for the room being processed.
FloorCode:
	DEFB 	&00							;; The index of the floor pattern to use.
FloorAboveFlag:
	DEFB 	&00     					;; Set if the room above has a floor.
SkipObj:
	DEFB 	&00     					;; 0: draw objects: not0: don't AddObject (used when restoring room state in BuildRoom*)
color_scheme:
	DEFB 	&00							;; current Color scheme
WorldId:
	DEFB 	&00							;; 0: "Blacktooth", 1: "Market", 2: "Egyptus", 3: "Penitentiary", 4: "Moon base", 5: "Book world", 6: "Safari", 7: "Prison"

;; -----------------------------------------------------------------------------------------------------------
;; Bit numbers for the doors:
;; 3/\2				8 = Extra_room in +V
;; 0\/1				4 = Extra room in +U
Has_no_wall:
	DEFB 	&00
Has_Door:
	DEFB 	&00

;; -----------------------------------------------------------------------------------------------------------
;; IY is pointed to MinU, and values are loaded in (based on RoomDimensions),
;; with IY incrementing to point after MaxV when loading is complete.
.Max_min_UV_Table:
	DEFB 	&3A							;; MinU Max_min_UV_Table+0 (don't care about these default values)
	DEFB 	&8A							;; MinV Max_min_UV_Table+1 (don't care about these default values)
	DEFB 	&40							;; MaxU Max_min_UV_Table+2 (don't care about these default values)
	DEFB 	&32							;; MaxV Max_min_UV_Table+3 (don't care about these default values)

;; AltLimits[12] are also used as IY for drawing extra rooms.
AltLimits1:
	DEFB 	&85, &40, &47, &C9			;; (these are supposed to be 00)
AltLimits2:
	DEFB 	&F5, &11, &2C, &41			;; (these are supposed to be 00)

;; -----------------------------------------------------------------------------------------------------------
;; Array of room Dimensions: Min U, Min V, Max U, Max V
;; Index into array is the RoomDimensionsIdx(Tmp)
.RoomDimensions:
	DEFB 	&08, &08, &48, &48					;; Room type 0 : Min U, Min V, Max U, Max V
	DEFB 	&08, &10, &48, &40
	DEFB 	&08, &18, &48, &38
	DEFB 	&08, &20, &48, &30
	DEFB 	&10, &08, &40, &48					;; ...
	DEFB 	&18, &08, &38, &48
	DEFB 	&20, &08, &30, &48
	DEFB 	&10, &10, &40, &40					;; Room type 7 : Min U, Min V, Max U, Max V

GROUND_LEVEL			EQU 	&C0

;; -----------------------------------------------------------------------------------------------------------
;; Heights of the 4 doors, for the main room.
;; 0/\1
;; 3\/2
.DoorHeights:
	DEFB 	&00, &00, &00, &00					;; nw ne se sw doors

;; Locations of the 4 doors along their respective
;; walls, for the room currently being processed.
.DoorHeightsTmp:
	DEFB 	&00, &00, &00, &00					;; nw ne se sw doors

;; The height of the highest door present.
.HighestDoor:
	DEFB 	GROUND_LEVEL							;; The height of the highest door present. reset value = GROUND_LEVEL

;; -----------------------------------------------------------------------------------------------------------
;; 2 Functions:
;; * BuildRoom : reset room, read room data and rebuild evreything (including objects).
;; * BuildRoomNoObj : Like BuildRoom, but we skip calling AddObject on the
;; main room. ; Used when restoring previously-stashed room state.
;; SkipObj will be reset by BuildRoom soon afterwards
.BuildRoomNoObj:
	LD 		A,&FF
	LD 		(SkipObj),A									;; SkipObj=-1 : Skip buildin Objects (already in memory)
.BuildRoom:
	LD 		IY,Max_min_UV_Table							;; points on MinU
	LD 		HL,&30D0									;; ViewXExtent full screen X
	LD 		(ViewXExtent),HL
	LD 		HL,&00FF									;; ViewXExtent full screen Y
	LD 		(ViewYExtent),HL
	LD 		HL,GROUND_LEVEL * 256 + GROUND_LEVEL		;; reset values for doors height; &C0 is GROUND_LEVEL
	LD 		(DoorHeightsTmp),HL							;; nw ne doors; init value
	LD 		(DoorHeightsTmp+2),HL						;; se sw doors; init value
	LD 		HL,&0000									;; UV origin (0,0) for ReadRoom
	LD 		BC,(current_Room_ID)						;; get current_Room_ID in BC
	CALL 	ReadRoom									;; read room data
	XOR 	A											;; A = 0
	LD 		(SkipObj),A									;; Reset SkipObj to 0 (reset to "Build room AND the objects")
	LD 		(HighestDoor),A								;; reset highest door
	LD 		HL,(Object_Destination)						;; get Object_Destination buffer pointer
	LD 		(Saved_Object_Destination),HL				;; update Saved_Object_Destination
	LD 		A,(RoomDimensionsIdxTmp)					;; copy temp room dimension
	LD 		(RoomDimensionsIdx),A						;; into RoomDimensionsIdx
	LD 		DE,DoorHeights								;; copy 4 doors heights from ...
	LD 		HL,DoorHeightsTmp							;; ... tmp to object array
	LD 		BC,&0004									;; ... (nw ne se sw)
	LDIR												;; repeat LD (DE),(HL); DE++, HL++, BC-- until BC=0
	LD 		HL,BackgrdBuff								;; BackgrdBuff buffer
	LD 		BC,&0040									;; BackgrdBuff Len ; erase &0040 (64) bytes from &6A00
	CALL 	Erase_forward_Block_RAM						;; Erase BackgrdBuff buffer
	CALL 	DoConfigWalls								;; do Walls
	CALL 	HasFloorAbove								;; check if Floor Above (Carry set = no Floor Above)
	LD 		A,&00
	RLA													;; get Carry into bit0 of FloorAboveFlag
	LD 		(FloorAboveFlag),A							;; bit0: if 0: Floor above or No room above; if 1: room with no floor above
	CALL 	StoreCorner									;; get where the far corner would be
	LD 		HL,(Has_no_wall)							;; get Has_no_wall (in L) and Has_Door (in H) values
	PUSH 	HL											;; save it
	LD 		A,L											;; A = Has_no_wall
	AND 	&08											;; test bit3 (Nw wall)
test_if_wall_far_V:
	JR 		Z,test_if_wall_far_U						;; if 0 then has Nw wall jump test_if_wall_far_U, else:
	;; Draw the room in V direction (Nw side)								;; current room has no Nw wall (can see further in next room)
	LD A,&01
	CALL 	SetObjList									;; index 1 in obj list
	LD 		BC,(current_Room_ID)						;; get current_Room_ID
	LD 		A,B											;; Room ID UV
	INC 	A											;; V+1
	XOR 	B
	AND 	&0F											;; ignore the carry that could have impacted U (get back real U and roll over V if needed)
	XOR 	B
	LD 		B,A											;; BC = id of the next room Nw side
	LD 		A,(Max_min_UV_Table+3)						;; MaxV
	LD 		H,A
	LD 		L,&00										;; Set HL to MaxV value (UV origin)
	CALL 	ReadRoom									;; Read that other room; ; IY pointing to AltLimits1.
	CALL 	DoConfigWalls								;; and add wall config to current room config
test_if_wall_far_U:
	LD 		IY,AltLimits2
	POP 	HL											;; restore Has_no_wall (in L) and Has_Door (in H) values
	PUSH 	HL											;; save them again
	LD 		A,L
	AND 	&04											;; test bit2 (Ne wall)
	JR 		Z,bldroom_2									;; if Ne side has a wall, jump bldroom_2, else:
	;; Draw the room in U direction (Ne side)								; current room has no Ne wall (can see further in next room)
	LD 		A,&02										;; object list 2
	CALL 	SetObjList
	LD 		BC,(current_Room_ID)						;; get current_Room_ID
	LD 		A,B											;; BC = room id UV
	ADD 	A,&10										;; U+1 (next far room in Ne)
	XOR 	B
	AND 	&F0											;; make sure V has not been touched, rool over U if needed
	XOR 	B
	LD 		B,A											;; BC = next room Ne side
	LD 		A,(Max_min_UV_Table+2)						;; MaxU
	LD 		L,A
	LD 		H,0											;; Set HL offset to MaxU (UV origin)
	CALL 	ReadRoom									;; Read that room IY pointing to AltLimits2.
	CALL 	DoConfigWalls								;; and add it ti current to visualize
bldroom_2:																	;; now do Doors
	LD 		A,(HighestDoor)
	LD 		HL,(DoorSprites)
	PUSH 	AF
	CALL 	OccludeDoorway					 			;; Occlude edge of door sprites at the back.
	POP 	AF
	CALL 	SetPillarHeight 							;; pillar is as high as the tallest door
	POP 	HL
	LD 		(Has_no_wall),HL							;; Restore value from first pass
	XOR 	A											;; Switch back to usual object list (index 0).
	JP 		SetObjList

;; -----------------------------------------------------------------------------------------------------------
;; Unpacks a room, adds all its sprites to the lists.
;; See "Room_list1" comments for the Room data format.
;; Inputs: IY points to where we stash the room size.
;; 		   BC = Room Id
;; 		   HL = UV origin of the room
.ReadRoom:
	LD 		(DecodeOrgStack),HL				  			;; Initialize UV origin.
	XOR 	A
	LD 		(DecodeOrgStack+2),A						;; and Z origin (to 0)
	PUSH 	BC
	CALL 	FindVisitRoom								;; find Room ID in BC and set the "visited" bit; DataPtr and CurrData point on the begining of the room data.
	LD 		B,3											;; number of bit to fetch from CurrData
	CALL 	FetchData									;; Fetch room dimension code
	LD 		(RoomDimensionsIdxTmp),A					;; 3 first bits are "Room dimensions"
	ADD 	A,A											;; *2
	ADD 	A,A											;; *4  (4 bytes min u,v max u,v)
	ADD 	A,RoomDimensions and &00FF					;; &CE = (RoomDimensions & &00FF) + (room index offset * 4)
	LD 		L,A
	ADC 	A,RoomDimensions / 256						;; &1E = (RoomDimensions & &FF00) >> 8
	SUB 	L
	LD 		H,A											;; HL = RoomDimensions + (4*RoomDimensionsIdxTmp)
	LD 		B,&02										;; U, then V
	LD 		IX,DecodeOrgStack							;; Origin: IX:U, IX+1:V, IX+2:Z ; Load U, then V room Dimensions and origin.
rdroom_1:
	LD 		C,(HL)										;; read min dimension
	LD 		A,(IX+0)									;; get origin (U at 1st loop, V at 2nd loop)
	AND 	A											;; test origin
	JR 		Z,rdroom_jump								;; if 0 jump rdroom_jump (use min), else:
    ;; subtracting C and dividing by 8 to create grix
    ;; coordinates, and store the unadjusted value in IY.
	SUB 	C											;; orig - min
	LD 		E,A											;; save that value
	RRA
	RRA
	RRA													;; div8
	AND 	&1F											;; mod32
	LD 		(IX+0),A									;; update origin (U, then V at 2nd loop)
	LD 		A,E											;; restore saved value so orig will be calculated as equal the previous/original one
rdroom_jump:
	ADD 	A,C											;; orig + min
	LD 		(IY+0),A									;; update coord
	INC 	HL											;; Then do "V" dimension
	INC 	IX											;; next orig coord value
	INC 	IY											;; next coord byte in result
	DJNZ 	rdroom_1									;; loop a 2nd time for V
	LD 		B,&02
rdroom_2:																	;; Take previous origin, multiply by 8 and add max U/V.
	LD 		A,(IX-2)									;; IX-2 (recently updated orig U, then V at 2nd loop)
	ADD 	A,A
	ADD 	A,A
	ADD 	A,A											;; *8
	ADD 	A,(HL)										;; add max
	LD 		(IY+0),A									;; Then save it.
	INC 	IY											;; next byte in coords
	INC 	IX											;; next orig value
	INC 	HL											;; redo it for maxV
	DJNZ 	rdroom_2									;; loop again
	;; Read the room Color Scheme, WorldId and FloorCode:
	LD 		B,3											;; number of bit to fetch from CurrData
	CALL 	FetchData									;; Fetch color scheme
	LD 		(color_scheme),A							;; update color scheme
	LD 		B,3											;; number of bit to fetch from CurrData
	CALL 	FetchData									;; Fetch World ID
	LD 		(WorldId),A									;; update the current world identifier
	CALL 	DoWallsnDoors								;; this will fetch 3+4*3 bits to setup the Walls and Doors
	LD 		B,3											;; number of bit to fetch from CurrData
	CALL 	FetchData									;; Fetch Floor Tile Id
	LD 		(FloorCode),A								;; update the floor pattern to use
	CALL 	SetFloorAddr								;; update FloorAddr
rdroom_loop:
	CALL 	ProcEntry									;; Loop to process objects in the room.
	JR 		NC,rdroom_loop								;; until all data have been processed
	POP 	BC
	JP 		AddSavedCrowns_and_SpecialItems				;; now add the special items and update saved worlds ?? TODO ; will RET

;; -----------------------------------------------------------------------------------------------------------
;; value going in are 3-bit signed value (-4 to +3)
;; we add that value to the value in (HL)
;; Return result in A
.Add3Bit:
	BIT 	2,A											;; is 3b value negative?
	JR 		Z,add3b_1									;; no (0 to +3), so jump add3b_1, else:
	OR 		&F8											;; gen negative value on 8bit (-4 to -1)
add3b_1:
	ADD 	A,(HL)										;; add A to (HL)
	RET													;; return A

;; -----------------------------------------------------------------------------------------------------------
;; Recursively do ProcEntry. Macro code is in A.
.RecProcEntry:
	EX 		AF,AF'
    ;; When processing recursively, we read local UVZ values to adjust the
    ;; origin for the macro-expanded processing (so a Macro can be played
    ;; at any position you like).
    ;; Read values UVZ into B, C, A
	CALL 	FetchData333								;; from CurrData ; fetch 3*3bits (UVZ) : 3bits going in B, 3 in C and 3 in A to adjust origin
	LD 		HL,(DecodeOrgPtr)							;; get room origin
	PUSH 	AF
	LD 		A,B						 					;; Adjust U value
	CALL 	Add3Bit
	LD 		B,A
	INC 	HL
	LD 		A,C											;; Adjust V value
	CALL 	Add3Bit
	LD 		C,A
	INC 	HL
	POP 	AF
	SUB 	&07
	ADD 	A,(HL)										;; Adjust Z value (slightly different)
	INC 	HL
	LD 		(DecodeOrgPtr),HL							;; Write out origin values, update pointer
	LD 		(HL),B
	INC 	HL
	LD 		(HL),C
	INC 	HL
	LD 		(HL),A
	LD 		A,(CurrData)								;; save the current read pointer.
	LD 		HL,(DataPtr)
	PUSH 	AF											;; save CurrData and DataPtr
	PUSH 	HL
	CALL 	FindMacro									;; find the Macro in Room_Macro_data
	LD 		(DataPtr),HL								;; update DataPtr with MacroData
rpent_loop:
	CALL 	ProcEntry
	JR 		NC,rpent_loop
	LD 		HL,(DecodeOrgPtr)							;; origin
	DEC 	HL
	DEC 	HL
	DEC 	HL
	LD 		(DecodeOrgPtr),HL
	POP 	HL
	POP 	AF
	LD 		(DataPtr),HL								;; And restore the read pointer.
	LD 		(CurrData),A
	;; flow into ProcEntry
;; -----------------------------------------------------------------------------------------------------------
;; Process one entry in the room description array. Returns carry when done.
.ProcEntry:
	LD 		B,8											;; number of bit to fetch from CurrData
	CALL 	FetchData									;; Get object ID, or Macro Id or FF
	CP 		&FF											;; is it FF
	SCF													;; Carry = 1
	RET 	Z											;; if was FF leave with Z and Carry=1, else:
	CP 		&C0											;; Code >= &C0 means Macro (recurse).
	JR 		NC,RecProcEntry								;; if fetched byte was >= &C0 go Recurse RecProcEntry (macro), else:
	PUSH 	IY											;; save the room size pointer in IY
	LD 		IY,TmpObj_variables							;; IY points on 18-byte temp variable
	CALL 	InitObj										;; Init the Object
	POP 	IY											;; get back room size pointer
	LD 		B,2											;; number of bit to fetch from CurrData
	CALL	FetchData									;; get next 2bits:
	;; The 2 bits fetched are:
	;; Bit0, if 0 : only one object with current object code;
	;;       if 1 : several objects to create with current object code.
	;; Bit1, if 0 : we will need to fetch one bit before every coord-set to get the per-object orientation bit.
	;;       if 1 : the next fetched bit will serve as orientation bit for all onjects in that group.
	BIT 	1,A											;; test bit1 (mode one-bit for all or read-new-bit-each-time)
	JR 		NZ,global_orientation_bit					;; if set (global orientation bit), jump global_orientation_bit, else:
	LD 		A,%00000001									;; set A to 3b001
	JR 		pent_1										;; jump pent_1

global_orientation_bit:														;; Read once and store in the bit2.
	PUSH 	AF											;; save value in A
	LD 		B,1											;; number of bit to fetch from CurrData
	CALL 	FetchData									;; get one more bit (global orientation bit : "0"=NO Flip; "1"=Flip)
	POP 	BC											;; restore saved AF value in BC
	RLCA
	RLCA												;; Shift left twice the global orientation bit (put in bit2)
	OR 		B											;; in A we have 3b'<orientation_bit_value>01
pent_1:
	LD 		(UnpackFlags),A								;; save 3b flag value from A in UnpackFlags
pent_loop:
	CALL 	SetTmpObjFlags								;; update object flags
	CALL 	SetTmpObjUVZEx								;; get its coordinates ; 3*3 bits fetched per object for UVZ
	LD 		A,(UnpackFlags)								;; load 3b flag value in A
	RRA													;; A >> 1 : bit0 in Carry
	JR 		NC,pent_one_obj								;; if bit0 was 0 (one object) jump pent_one_obj, else:
	LD 		A,(ExpandDone)								;; get ExpandDone (UVZ = "770" put "FF" in ExpandDone which is a code for stop)
	INC 	A											;; +1 (if FF will be 0)
	AND 	A											;; test
	RET 	Z											;; if 0 (in other words if it was "FF") then RET, else:
	CALL 	AddObjOpt									;; else AddObjOpt and
	JR 		pent_loop									;; loop to (try to) create another object with same code ID.

pent_one_obj:
	CALL 	AddObjOpt									;; AddObjOpt and
	AND 	A											;; test A
	RET													;; Return (update Z and Carry)

;; -----------------------------------------------------------------------------------------------------------
;; If SkipObj is zero, do an "AddObject"; else skip AddObject
.AddObjOpt:
	LD 		HL,TmpObj_variables							;; point on tmp Object array
	LD 		BC,OBJECT_LENGTH							;; length &12 bytes
	PUSH 	IY
	LD 		A,(SkipObj)									;; if SkipObj...
	AND 	A											;; ...test SkipObj...
	CALL 	Z,AddObject									;; is 0 then do AddObject (else don't)
	POP 	IY
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Initialise the doors. IY is pointing a byte after Max_min_UV_Table (IY = Max_min_UV_Table+4)
;; and will be accessed with negative offsets.
.DoWallsnDoors:
	LD 		B,3											;; number of bit to fetch from CurrData
	CALL 	FetchData									;; A = DoorId (theorically 0 to 7, but only 0 to 3 is used)
	CALL 	ToDoorId									;; if A<3 get A, else A-1 (since only 0,1,2,3 is used as input, it returns 0,1,2,2)
	ADD 	A,A											;; *2
	LD 		L,A											;; Left part of the door
	LD 		H,A
	INC 	H											;; Right part of the door
	LD 		(DoorSprites),HL							;; store the pointer on the door sprite data
	LD 		IX,Door_Obj_Flags
	LD 		HL,DoorHeightsTmp							;; nw door ; 1EF2+0 ; Door heights are stored in DoorHeightsTmp.
	EXX
	LD 		A,(IY-1)									;; nw door ; IY-1 = Max_min_UV_Table+3 ; MaxV
	ADD 	A,4											;; tmp obj V = MaxV + 4
	CALL 	DoWallnDoorU								;; calc tmp obj U and place Door sprites
	LD 		HL,DoorHeightsTmp+1  						;; ne door ; 1EF2+1
	EXX
	LD 		A,(IY-2)									;; ne door ; IY-2 = Max_min_UV_Table+2 ; MaxU
	ADD 	A,4											;; tmp obj U = MaxU + 4
	CALL 	DoWallnDoorV								;; calc tmp obj V and place Door sprites
	LD 		HL,DoorHeightsTmp+2							;; se door ; 1EF2+2
	EXX
	LD 		A,(IY-3)									;; se door ; IY-3 = Max_min_UV_Table+1 ; MinV
	SUB 	4											;; tmp obj V = MinV - 4
	CALL 	DoWallnDoorU								;; calc tmp obj U and place Door sprites
	LD 		HL,DoorHeightsTmp+3							;; sw door ; 1EF2+3
	EXX
	LD 		A,(IY-4)									;; sw door ; IY-4 = Max_min_UV_Table+0 ; MinU
	SUB 	4											;; tmp obj U = MinU - 4
	JP 		DoWallnDoorV								;; calc tmp obj V and place Door sprites

;; -----------------------------------------------------------------------------------------------------------
;; Update flags into Has_no_vall and Has_Door; this will be called for all 4 walls/doors
;; so both Has_no_vall and Has_Door will have 4 meaningful bits [3:0] for Nw,Ne,Se,Sw
;; if needed; sets the door Z coord in TmpObj_variables and HL' (DoorHeightsTmp pointer).
;; Read value:
;;  0 : Wall, No door
;;  1 : No wall, No door.
;;  2..7 :  Door; Door Height &A2 to &C0 (GROUND_LEVEL)
;; Return: Has_no_vall and Has_Door updated
;;         Carry reset = has no door; Carry set = has door
.FetchWallnDoor:
	LD 		B,3											;; number of bit to fetch from CurrData
	CALL 	FetchData									;; (value 0 to 7)
	LD 		HL,Has_no_wall								;; HL points on Has_no_vall (HL) and Has_Door (HL+1) bytes
	SUB 	2											;; test if data if < 2
	JR 		c,FetchedNoDoor								;; if data = 0 or 1 jump "FetchedNoDoor", else Carry=0 (has door):
fetchedDoor:
	RL 		(HL)										;; put Carry=0 into "Has_no_wall" bit0 (has door, hence has wall?) and push left the other bits (other walls)
	INC 	HL											;; move on "Has_Door"
	SCF													;; Carry=1
	RL 		(HL)										;; put a 1 into bit0 of "Has_Door" (has door) and push left the other bits (other doors)
	SUB 	7											;; these 2 lines convert...
	NEG													;; ...initial data height 2..7 to value 7..2, so initial data of 7 becomes ground level (&C0)
	LD 		C,A											;; *1
	ADD 	A,A											;; *2
	ADD 	A,C											;; *3
	ADD 	A,A											;; *6
	ADD 	A,&96										;; +&96 : an initial data of 2 gives &C0=ground level, for a data of 7 we have a max value &A2
	LD 		(TmpObj_variables+O_Z),A					;; update object A
	SCF													;; Return with Carry set = Door found
	EXX
	LD 		(HL),A										;; update DoorHeightsTmp
	RET

;; -----------------------------------------------------------------------------------------------------------
;; If no door is found on the current side, update the corresponding bit in:
;;  * Has_no_vall (0  = Wall or 1 NoWall);
;;  * Has_Door (0 = No Door)
FetchedNoDoor:																;; No door case:
	CP 		&FF											;; test if FF (FF, Carry=0 : data was 1 = NoWall/NoDoor; FE, Carry=1: data was 0 = Wall/NoDoor)
	CCF													;; flip Carry flag, so now Carry=data (1 = NoWall/NoDoor; 0 = Wall/NoDoor)
	RL 		(HL)										;; Rotate Carry into Has_no_vall bit0 (0 (Wall/NoDoor = has wall) or 1 (NoWall/NoDoor = has no door)) and push left the other bits (other walls)
	AND 	A											;; refresh Carry bit with 0
	INC 	HL											;; HL now points on Has_Door
	RL 		(HL)										;; put a Carry=0 into Has_Door bit0 (No door) and push left the other bits (other doors)
	AND 	A											;; refresh Carry with 0
	RET													;; Return with Carry reset

;; -----------------------------------------------------------------------------------------------------------
;; Build a Door on the U or V axis:
;; DoWallnDoorV : Build a door parallel to the V axis (Nw and Se sides).
;; DoWallnDoorU : Build a door parallel to the U axis (Ne and Sw sides).
;; Coordinate of the wall plane in A
;; HL' point on the coordinates
;; IX points to flags to use (Door_Obj_Flags).
.DoWallnDoorV:
	LD 		(TmpObj_variables+O_U),A
	LD 		HL,TmpObj_variables+O_V						;; V
	LD 		A,(DecodeOrgStack+1)				  		;; V orig offset
	JP 		DoWallnDoorAux								;; will RET

.DoWallnDoorU:
	LD 		(TmpObj_variables+O_V),A
	LD 		HL,TmpObj_variables+O_U						;; U
	LD 		A,(DecodeOrgStack)					  		;; U orig offset
	;; will flow into DoWallnDoorAux
;; -----------------------------------------------------------------------------------------------------------
;; HL points to the object's coordinate field to write to
;; A holds the origin value in that dimension.
;; Takes extra parameters in IX
;; IX (object flags) and HL' (pointer to relevant DoorHeightsTmp entry).
;; 		V   U
;; 		 \ /
;; 		  |
;; 		  Z
.DoWallnDoorAux:
	ADD 	A,A											;; orig coord *2
	ADD 	A,A											;; *4
	ADD 	A,A											;; *8 => grid to pix
	PUSH 	AF
	ADD 	A,&24										;; &24 in the coordinate offset of the left part of the door sprite
	LD 		(HL),A										;; TmpObj_var coord
	PUSH 	HL
	;; Get the door Z coordinate set up, return if no object to add.
	CALL 	FetchWallnDoor								;; note: it does a EXX
	JR 		NC,NoDoorRet								;; no door leave, else:
	;; Draw the first half of the door
	LD 		A,(IX+0)									;; get Door_Obj_Flags
	LD 		(TmpObj_variables+O_FLAGS),A				;; Set the TmpObj flags
	INC 	IX											;; next index in Door_Obj_Flags
	LD 		A,(DoorSprites)								;; first half door sprite
	LD 		(TmpObj_variables+O_SPRITE),A				;; Set the sprite.
	CALL 	AddHalfDoorObj								;; Add the first half door object
	;; Draw the other half of the door
	LD 		A,(IX+0)									;; next door's flag
	LD 		(TmpObj_variables+O_FLAGS),A				;; update tmp object flag
	INC 	IX											;; point on next flag byte
	LD 		A,(DoorSprites+1)							;; get sprite code for the other half of the door
	LD 		(TmpObj_variables+O_SPRITE),A				;; update tmp obj sprite
	POP 	HL
	POP 	AF
	ADD 	A,&2C										;; need to add a coord offset of &2C for the right part of the door; note that to create the 3D effect, that sprite overlaps the left part by a third
	LD 		(HL),A										;; Update coord
.AddHalfDoorObj:
	;; Adds the current object in TmpObj_variables
	CALL 	AddObjOpt									;; Add current object.
	;; Return early for the far doors. Only add ledges for the near doors.
	LD 		A,(TmpObj_variables+O_FLAGS)				;; recover the current flag
	LD 		C,A											;; get door flags
	AND 	&30											;; test bits [5:4]
	RET 	PO											;; if both bits 5 and 4 are different (01 or 10 = far walls side) leave (no need for a door step), else if equal (00 or 11 = near walls side):
	;; If the door is at ground level, then can leave.
	AND 	&10											;; keep only bit4
	OR 		&01											;; set bit0 (A can be &01 or &11)
	LD 		(TmpObj_variables+O_FLAGS),A				;; update flags
	LD 		A,(TmpObj_variables+O_Z)					;; get height
	CP 		GROUND_LEVEL								;; compare with ground level
	RET 	Z											;; &C0 is GROUND_LEVEL, don't need to put anything underneath (leave).
	;; Otherwise, add a doorstep under the doorway (6 down)
	PUSH 	AF											;; else, the door is on the near side, and not on ground level, so need to draw a doorstep underneath
	ADD 	A,6											;; Z "minus" 6 (Z axis goes down)
	LD 		(TmpObj_variables+O_Z),A          			;; Update Z coord
	LD 		A,SPR_DOORSTEP
	LD 		(TmpObj_variables+O_SPRITE),A     			;; Update sprite code to doorstep
	CALL 	AddObjOpt									;; Add the step to the object list
	POP 	AF
	LD 		(TmpObj_variables+O_Z),A          			;; And restore Z.
	RET

;; -----------------------------------------------------------------------------------------------------------
;; No door case - unwind variables and return
.NoDoorRet:
	POP		HL
	POP 	AF
	INC 	IX
	INC 	IX
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Finds a Macro used to Build a room
;; Reset CurrData. Macro id we are searching is passed in A'.
;; Returns a pointer to a specific room description macro in Room_Macro_data
.FindMacro:
	LD 		A,&80
	LD 		(CurrData),A								;; Clear buffered byte with value &80.
	LD 		HL,Room_Macro_data							;; point on Macro table
	EX 		AF,AF'										;; recover the Macro ID stared in A'
	LD 		D,0
fm_loop:
	LD 		E,(HL)										;; DE=first byte = macro length
	INC 	HL											;; next byte, is macro Id
	CP 		(HL)										;; Have we found the macro Id in A' we are looking for?
	RET 	Z											;; yes, leave with Macro pointer in HL
	ADD 	HL,DE										;; jump to next macro
	JR 		fm_loop										;; loop

;; -----------------------------------------------------------------------------------------------------------
;; Checks if the room above the current one exists and has no floor (so we can get in by going up)
;; Returns with Carry set if the room above has a floor.
;; Returns with Carry reset if the room above has No floor.
.HasFloorAbove:
	LD 		BC,(current_Room_ID)						;; get current_Room_ID
	LD 		A,C
	DEC 	A											;; C is low byte of RoomID; 4msb=Z, lsb=0. For exemple : &40-1 = &3F; &3F and &F0 = &30 so new Z=3
	AND 	&F0											;; room Z-1 = room above
	LD 		C,A
	CALL 	FindRoom									;; Look if a room ID U,V,Z-1 exists
	RET 	c											;; if Carry set=room not found, so leave, else:
check_floorid_above:
    ;; Room Data Format (excluding size byte) is:
	;; 12b roomID UVZ, 3b roomDimensions, 3b colorScheme,
	;; 3b WorldId, 15b door data, 3b floorId, 8b Object, etc.
	;; 		uuuuvvvv_zzzzdddc_ccwwwDDD_pppDDDpp_pDDDfffo_ooooooo..
	;; DE currently pointing on the second byte, so +3 points on the
	;; byte with the floorId. ORing &F1 checks if floorId is 7 (no floor).
	INC 	DE
	INC		DE
	INC		DE											;; DE+3 = point on the data byte with FloorId
	LD 		A,(DE)										;; get data
	OR 		&F1											;; test bits [3:1]
	INC 	A											;; if bits were 3b111, A is now 0 (Floor code 7 means "no floor")
	RET 	Z											;; Return with Z set and Carry reset if that room has no floor.
	SCF													;; else:
	RET													;; Return with Carry set if there's a floor

;; -----------------------------------------------------------------------------------------------------------
;; Like FindRoom, but set the "visited" bit (in RoomMask_buffer) as well.
;; Input: Takes room Id in BC.
;; Return: First data byte in A, and room bit mask & location (in RoomMask_buffer) in C' and HL'.
;; Return: Carry set=not found or Carry reset=found)
;; If found, DataPtr and CurrData are updated, and pointing on the
;; begining of the room actual data (after room ID)
.FindVisitRoom:
	CALL 	FindRoom									;; Calls FindRoom
	EXX													;; get the room bit mask & location (in RoomMask_buffer) in C' and HL'.
	LD 		A,C											;; get current RoomMask (indicating which bit to set)
	OR 		(HL)										;; add it to the value already in RoomMask_buffer
	LD 		(HL),A										;; and update RoomMask_buffer
	EXX													;; return to not-prime registers
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Find room data if room exist.
;; Input: Takes room id in BC.
;; Return: First data byte in A, and room bit mask & location (in RoomMask_buffer) in C' and HL'.
;; Return: Carry set=not found or Carry reset=found)
;; If found, DataPtr and CurrData are updated, and pointing on the
;; begining of the room actual data (after room ID)
.FindRoom:
	LD 		D,0
	LD 		HL,Room_list1
	CALL 	Sub_FindRoom								;; init and look in first list
	RET 	NC											;; found, leave
	LD 		HL,Room_List2								;; else (Carry set=not found) look in 2nd list
	JR 		Sub_FindRoom_more							;; return Carry set=not found of reset=found)

;; -----------------------------------------------------------------------------------------------------------
;; Finds an entry in the room list.
;; The data structure is:
;;  -  1 byte = size (excluding this byte); a size of zero terminates the list.
;;  -  1.5 bytes = room id "UVZ" (Bottom nibble is ignored for matching),
;;							 eg. "8A 43" means Room &8A40, also note these are
;;							    in big_endian format: U=8,V=&A,Z=4 (3=don't care)
;;  -  0.5 + N bytes of Data
;; Input:
;;   HL pointing to the start of the tagged list
;;   BC is the room id we're looking for (eg. &8A40 for Head's first room)
;;   HL' and C' are incremented as the address in RoomMask_buffer and
;;      bit mask for a bitfield associated with the Nth entry.
;; Return:
;;   DE will be the entry size (D should be zero)
;; 	 The carry flag is set if nothing's found.
;; 	 If the room is found, you can read data with FetchData:
;;      Current byte to process in CurrData;
;;      Addr pointer on data in DataPtr
.Sub_FindRoom:
	EXX
	LD 		HL,RoomMask_buffer							;; HL' points on a 301 bytes buffer (1 per room)
	LD 		C,%00000001									;; wandering 1 bit mask start bit 0
	EXX													;; Save as HL' and C', get back HL= pointer on room list 1
.Sub_FindRoom_more:
	LD 		E,(HL)										;; read first byte = length for current room block of data (including room id)
	INC 	E
	DEC 	E											;; test if value in E (data block length) = 0
	SCF													;; Return with Carry if length byte = 0 (not found and end of list reached)
	RET 	Z											;; so if E = 0 leave; else:
	INC 	HL											;; point on next byte (id high byte) (UV)
	LD 		A,B											;; compare the id in B...
	CP 		(HL)										;; ... with that byte
	JR 		Z,frin_b_matched							;; if identical jump frin_b_matched, else:
frin_2:																		;; (B did't match)
	ADD 	HL,DE										;; skip until next data block
	EXX													;; get C' (bitmask)
	RLC 	C											;; move the wandering 1 left; C' bit7 goes in Carry
	JR 		NC,frin_1									;; if bit7 = 0 jump frin_1, else (moved 8 times):
	;; We only need 301 bits (a 1 indicating we visited it) but the
	;; RoomMask_buffer is 301 bytes because of the function used to
	;; count visited rooms that is shared with other functionalities.
	INC 	HL											;; increment RoomMask_buffer addr in HL'
frin_1:																		;; save C',HL' and ...
	EXX													;; ...recover C (id low byte) and HL (data pointer)
	JR 		Sub_FindRoom_more							;; loop at Sub_FindRoom_more

frin_b_matched:																;; B was a match so now check C
	INC 	HL											;; next byte
	DEC 	E											;; so decrement DE
	LD 		A,(HL)										;; get id low byte
	AND 	&F0											;; and only look at bits [7:4] (Z)
	CP 		C											;; compare with id low byte in C (Z part of the roomId)
	JR		 NZ,frin_2									;; no match, jump to skip to next data block; else found!
	DEC 	HL											;; Matched room ID! point back on ID high byte (because of the INC HL in FetchData)
	LD 		(DataPtr),HL								;; store pointer on data block in DataPtr
	LD 		A,&80										;; init CurrData with &80 (will make FetchData jump to the is low byte)
	LD 		(CurrData),A								;; to init the fetching pointer by skipping the 4 upper bits and pointing on the low nibble
	LD 		B,4											;; dummy read first nibble of id low byte
	JP 		FetchData									;; will point on low nibble of id low byte ; will RET

;; -----------------------------------------------------------------------------------------------------------
.SetTmpObjFlags:
	LD 		A,(UnpackFlags)								;; get orientation 3b flag value
	RRA
	RRA													;; get bit1 from saved flags in Carry
	JR 		c,stof_1									;; if bit1 set then don't read a new bit (global value is in bit2), else do:
	LD 		B,1											;; if bit1 = 0 then read 1 new bit per object:
	CALL 	FetchData									;; per-object orientation bit fetched from CurrData
stof_1:
	AND 	&01											;; look at (what was before) bit2 only (because of the 2 RRA above, the bit2 orientation (flipped or not) flag is currently at bit0!)
	RLCA
	RLCA
	RLCA
	RLCA
	AND 	&10											;; shift it to bit 4
	LD 		C,A
	LD 		A,(BaseFlags+1)								;; get current flag
	XOR 	C											;; if SPR_FLIP set, then invert the orientation bit set by the Rooms data
	LD 		(TmpObj_variables+O_FLAGS),A				;; and update tmp flags; this bit indicated if the sprite needs flip or not
	LD 		BC,(BaseFlags)
	BIT 	4,A											;; test bit4 SPR_FLIP???
	JR 		Z,stof_end									;; If bit4 reset then jump stof_end, else (bit4 set):
	BIT 	1,A											;; test bit1
	JR 		Z,stof_2									;; if bit1 reset then jump stof_2, else (bit1 rest):
	XOR 	%00000001									;; flip bit 0
	LD 		(TmpObj_variables+O_FLAGS),A				;; update Flags
stof_2:
	DEC 	C
	DEC 	C
stof_end:
	LD 		A,C
	LD 		(TmpObj_variables+O_DIRECTION),A			;; dir code (0 to 7 or FF)
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Read (ie. FetchData) U, V, Z coords (3 bits each), and
;; set TmpObj_variables's location
.SetTmpObjUVZEx:
	CALL 	FetchData333								;; Fectch 3*3b U,V,Z in B,C,A
.SetTmpObjUVZ:
	EX 		AF,AF'
	LD 		HL,(DecodeOrgPtr)							;; get origin
	LD 		DE,TmpObj_variables+O_U						;; DE points on Obj U
;; Calculates U, V and Z coordinates
;;  DE points to where we will write the U, V and Z coordinates
;;  HL points to the address of the origin data.
;;  We pass in coordinates: B contains U, C contains V, A' contains Z
;;  U/V coordinates are built on a grid of * 8 + 12
;;  Z coordinate is built on a grid of * 6 + 0x96 (0..7 will return &96 to &C0=GROUND_LEVEL)
;;  Sets ExpandDone to 0xFF (done) if "B = 7, C = 7, A' = 0"
.Set_UVZ:
	LD 		A,B											;; U
	CALL 	CalcGridPos									;; Calc U grid and HL++
	LD 		(DE),A										;; Set Obj U coordinate = ((OriginU+U) * 8) + 12
	LD 		A,C											;; V
	CALL 	CalcGridPos									;; Calc V grid and HL++
	INC 	DE
	LD 		(DE),A										;; Set Obj V coordinate = ((OriginV+V) * 8) + 12
	EX 		AF,AF'										;; get Z from A'
	PUSH 	AF
	ADD 	A,(HL)										;; OriginZ+Z
	LD 		L,A											;; *1
	ADD 	A,A											;; *2
	ADD 	A,L											;; *3
	ADD 	A,A											;; *6
	ADD 	A,&96										;; +&96
	INC 	DE
	LD 		(DE),A										;; Set Z coordinate = ((OriginZ+Z) * 6) + &96
	POP 	AF											;; get Z back
	CPL													;; invert bits (if Z=0 (3b000) we will get 3b111)
	AND 	C											;; if V=7, A[2:0] is still 3b111
	AND 	B											;; if U=7, A[2:0] is still 3b111
	OR 		&F8											;; make sure A[7:3] are set
	LD 		(ExpandDone),A								;; ExpandDone will be &FF is UVZ = 7,7,0 (else ExpandDone not &FF)
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Add curr coord (U or V) to the Origin (U or V) from (HL) and
;; calculate the resulting pixel position.
;; Input: A = U or V current value;
;;        HL : pointer on U or V origin value.
;; Output: A = ((coord+origin) * 8) + 12
;;         HL is incremented
.CalcGridPos:
	ADD 	A,(HL)										;; coord (U or V) + origin (U or V)
	INC 	HL											;; move pointer on next coord
	RLCA
	RLCA
	RLCA												;; A*8
	ADD 	A,&0C										;; +12
	RET

;; -----------------------------------------------------------------------------------------------------------
;; This will fetch (see FetchData) 3 values of 3-bits.
;; Output: First value in B, next in C and Last in A.
;;         CurrData and DataPtr are updated as needed
;; It is used to get the UVZ coords from the Room data.
.FetchData333:
	LD 		B,3
	CALL 	FetchData									;; fetch 3 bits (U will go in B)
	PUSH 	AF
	LD 		B,3
	CALL 	FetchData									;; fetch 3 bits (V will go in H and copied in C)
	PUSH 	AF
	LD 		B,3
	CALL 	FetchData									;; fetch 3 bits (Z will be in A)
	POP 	HL
	POP 	BC
	LD 		C,H
	RET													;; Return first 3 bits in B, next 3 bits in C, final 3 bits in A

;; -----------------------------------------------------------------------------------------------------------
;; Fetch a value from bit-packed data.
;; Input: Number of bits in B.
;;        Also the current byte of data must be in CurrData;
;;        and current data pointer in DataPtr
;; Output: DataPtr and CurrData updated
;;         Fetched B-bit value in A
;; Exemple: From the 2 consecutive bytes "B1" and "72" ("101|1_000|1_0|111_00|10"),
;;     if we FetchData with B being 3 then 4, 2 and finaly 5 we get in A
;;     respectively &05, then &08, &02 and finaly &1C, with CurrData being &80
;;     and DataPtr increase by 1.
.FetchData:
	LD 		DE,CurrData									;; pointer on current data processed
	LD 		A,(DE)										;; get data
	LD 		HL,(DataPtr)								;; get addr for the data
	LD 		C,A											;; byte of data in C
	XOR 	A											;; A = 0; Carry = 0
fetchd_0:
	RL 		C											;; Left rotate C, leaving bit goes in Carry
	JR 		Z,fdta_next									;; if remaining data = 0, jump fdta_next, else:
fetchd:
	RLA													;; rotate A and insert Carry at bit 0
	DJNZ 	fetchd_0									;; fetch B bits
	EX 		DE,HL
	LD 		(HL),C										;; update CurrData with what's left after extracting B bits from it
	RET

fdta_next:																	;; we can get next byte, as we emptied the current one!
	INC 	HL											;; next byte
	LD 		(DataPtr),HL								;; update data pointer in DataPtr
	LD 		C,(HL)										;; get next byte
	SCF													;; set Carry
	RL 		C											;; Rotate left C, bit7 goes in Carry, and the old Carry (1) goes in bit0
	JP 		fetchd										;; continue fetching bits with that new byte

;; -----------------------------------------------------------------------------------------------------------
;; Configure the walls for the current room
.DoConfigWalls:
	LD 		HL,(DoorHeightsTmp)							;; Get the heights of the doors on the back walls.
	LD 		A,L											;; compare the 2 doors, take the lowest:
	CP 		H											;; H < L ?
	JR		c,dcwll_1									;; if H < L skip using L (lowest), else:
	LD 		A,H											;; use H as it is the lowest
dcwll_1:
	NEG
	ADD 	A,GROUND_LEVEL								;; &C0 (GROUND_LEVEL) - height of the lowest of the 2 back doors.
	LD 		HL,HighestDoor								;; test if the highest door
	CP 		(HL)										;; is below "&C0-height of the lowest of the 2 back doors"
	JR 		c,dcwll_2									;; if it is the case skip, else:
	LD 		(HL),A										;; update the value for the highest door
dcwll_2:
	LD 		A,(HL)										;; in all case takse the value of the heiest door (updated or not)
	JP 		ConfigWalls									;; do ConfigWalls ; will RET

;; -----------------------------------------------------------------------------------------------------------
;; Calls all the initialization functions
.Init_setup:
	CALL 	Init_table_and_crtc							;; Tables, Interrupts and CRTC
	JP 		Init_table_rev								;; Continue at Init_table_rev ; will have a RET

;; -----------------------------------------------------------------------------------------------------------
;; Initialization of a new game
.Init_new_game:
	XOR 	A											;; A=0
	LD 		(saved_World_Mask),A						;; reset saved_World_Mask
	LD 		(access_new_room_code),A					;; init access_new_room_code to 0 ("stay same room" Code)
	LD 		(Save_point_value),A						;; Initialize the save point value to 0
	LD 		A,&18										;; Init Heels' anim sprite
	LD 		(Heels_variables+O_SPRITE),A
	LD 		A,&1F										;; Init Head's anim sprite
	LD 		(Head_variables+O_SPRITE),A
	CALL 	Erase_visited_room							;; Erase "visited room" bits from mem &4261 length 012D (301 bytes (for 301 rooms) : in fact only 38 are used!)
	CALL 	Reinitialise								;; Reinitialise with:
	DEFW 	StatusReinit  								;; Argument StatusReinit 2471 (counters)
	CALL 	ResetSpecials								;; reset the "picked up" bit for the special items
	LD 		HL,RoomID_Heels_1st							;; This is Heels initial room id (&8940)
	LD 		(current_Room_ID),HL						;; update current_Room_ID
	LD 		A,%00000001									;; init selected character
	CALL 	InitOtherChar								;; this will first load Heels room, build it, and create Heels and Objects; then we'll switch the Head (1st room we see when starting the game), so that if we Swop, the other character (Heels) is already defined.
	LD 		HL,RoomID_Head_1st							;; This is Head initial room id (&8A40)
	LD 		(current_Room_ID),HL						;; update current_Room_ID
	XOR 	A											;; A=0
	LD 		(access_new_room_code),A					;; reset access_new_room_code with 0 ("stay same room" Code)
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Initialize the character in A (1=Heels, 2=Head) to create the "other"
;; character so then if we swop, everything needed (other char, other char's room, objects) already exist.
.InitOtherChar:
	LD 		(selected_characters),A						;; update selected_characters with value in A
	PUSH 	AF
	LD 		(Other_Character_state + MOVE_OFFSET),A
	CALL 	EnterRoom									;; enter first room
	XOR 	A											;; A=0
	LD 		(Teleport_down_anim_length),A				;; Init Teleport anim
	CALL 	CharThing15
	JR 		initth_sub

initth_loop:
	CALL 	Characters_Update
initth_sub:
	LD 		A,(Saved_Objects_List_index)				;; get Saved_Objects_List_index
	AND 	A											;; test A
	JR 		NZ,initth_loop								;; if not 0 jump loop, else:
	POP 	AF
	XOR 	%00000011									;; switch bits 1 and 0 (change selected character)
	LD 		(selected_characters),A						;; update selected_characters
	CALL 	CharThing3									;; init bit2 of SwopChara_Pressed
	JP 		Save_array									;; save other character

;; -----------------------------------------------------------------------------------------------------------
.Init_Continue_game:
	CALL 	Reinitialise								;; Reinitialise with:
	DEFW 	StatusReinit								;; Argument StatusReinit 2471 (counters)
	LD 		A,8											;; "All Black" color scheme
	CALL 	Set_colors									;; set color scheme
	JP 		DoContinue									;; continue at DoContinue

;; -----------------------------------------------------------------------------------------------------------
.FinishRestore:
	CALL 	BuildRoomNoObj
	CALL 	Reinitialise								;; Reinitialise with:
	DEFW 	ReinitThing           						;; Argument ReinitThing 248A
	CALL 	Set_Character_Flags
	CALL 	GetScreenEdges
	CALL 	DrawBlacked
	XOR 	A											;; A = 0
	LD 		(both_in_same_room),A						;; reset both_in_same_room
	JR 		Update_Screen_Periph						;; Update HUD

;; -----------------------------------------------------------------------------------------------------------
TODO_236e:
	DEFB 	&00

WorldIdSnd:
	DEFB 	&00											;; Sound ID of the current World (&40 to &46)

;; -----------------------------------------------------------------------------------------------------------
.Do_Enter_Room:
	CALL 	EnterRoom
	LD 		A,(Sound_menu_data)							;; get Sound_menu_data
	AND 	A
	JR 		NZ,br_238C
	LD 		A,(WorldId)									;; get WorldId
	CP 		&07											;; Compare with 7: "Prison"
	JR 		NZ,br_2383									;; if not prison, skip, else:
	LD 		A,(WorldIdSnd)								;; get current (or default = 0) WorldIdSnd: this will set the "Prison" sound to "Blacktooth" (ID &40)
br_2383
	LD 		(WorldIdSnd),A								;; save WorldIdSnd
	OR 		Sound_ID_Worlds_arr							;; add &40 to get a Worlds Sound ID (they start at ID &40)
	LD 		B,A											;; &40 + WorldId = World music
	CALL 	Play_Sound									;; Play world music
br_238C
	CALL 	DrawBlacked
	CALL 	CharThing15
.Update_Screen_Periph:
	LD 		A,(color_scheme)							;; get color_scheme
	CALL 	Set_colors									;; Set color scheme
	CALL 	PrintStatus									;; Print the HUD counters values
	JP 		Draw_Screen_Periphery						;; Draw HUD ; will RET

;; -----------------------------------------------------------------------------------------------------------
.EnterRoom:
	CALL 	Reinitialise								;; Reinitialise with:
	DEFW 	ObjVars  									;; Argument ObjVars 3986
	CALL 	Reinitialise								;; Reinitialise with:
	DEFW 	ReinitThing									;; Argument ReinitThing 248A
	LD 		A,(selected_characters)						;; get selected_characters
	CP 		&03
	JR 		NZ,br_23BB
	LD 		HL,Other_Character_state + MOVE_OFFSET
	SET 	0,(HL)
	CALL 	BuildRoom
	LD 		A,&01
	JR 		br_23F3

br_23BB
	CALL 	Do_We_Share_Room
	JR 		NZ,br_23EF
	CALL 	Restore_array
	CALL 	BuildRoomNoObj
	LD 		HL,Heels_variables
	CALL 	GetUVZExtents_Blst
	EXX
	LD 		HL,Head_variables
	CALL 	GetUVZExtents_Blst
	CALL 	CheckOverlap
	JR 		NC,br_23EB
	LD 		A,(selected_characters)						;; get selected_characters
	RRA
	JR 		c,br_23DF
	EXX
br_23DF
	LD 		A,B
	ADD 	A,&05
	EXX
	CP 		B
	JR 		c,br_23EB
	LD 		A,&FF
	LD 		(&236E),A
br_23EB
	LD 		A,&01
	JR 		br_23F3

br_23EF
	CALL 	BuildRoom
	XOR 	A
br_23F3
	LD 		(both_in_same_room),A						;; reset both_in_same_room
	JP 		GetScreenEdges

;; -----------------------------------------------------------------------------------------------------------
.GetScreenEdges:
	LD HL,(Max_min_UV_Table)							;; MinU; MinU in L, MinV in H.
	LD A,(Has_Door)										;; Has_Door
	PUSH AF
	BIT 1,A
	JR Z,br_2408
	;; If there's a door, bump up MinV.
	DEC H
	DEC H
	DEC H
	DEC H
br_2408
	RRA
	LD A,L												;; MinU
	JR NC,br_240F
	;; If there's the other door, reduce MinU.
	SUB 4
	LD L,A
	;; Find MinU - MinV
br_240F
	SUB H
	;; And use this to set the X coordinate of the corner.
	ADD A,&80
	LD (smc_CornerPos+1),A								;; self_mod code &1803 (value of CP ...)
	LD C,A												;; Save in C for TweakEdges
	;; Then set the Y coordinate of the corner, taking into
    ;; account various fudge factors.
	LD A,&FC											;; Y_START + &C0 - EDGE_HEIGHT - 1
	SUB H
	SUB L
	;; Save Y coordinate of the corner in B for TweakEdges
	LD B,A
	;; Then generate offsets to convert from screen X coordinates to
    ;; associated Y coordinates.
	NEG
	LD E,A												;; E = MinU + MinV - &FC
	ADD A,C
	LD (smc_LeftAdj+1),A								;; 1817 ; E + CornerPos, value of ADD A,??? ; self mod
	LD A,C
	NEG
	ADD A,E
	LD (smc_RightAdj+1),A								;; 180F:  E - CornerPos, value of ADD A,??? ; self mod
	CALL TweakEdges
	;; Then, inspect Has_Doors to see if we need to remove
	;; a column panel or two.
	POP AF
	RRA
	PUSH AF
	CALL NC,NukeColL
	POP AF
	RRA
	RET c
;; Scan from the right for the first drawn column
NukeColR:
	LD HL,BackgrdBuff + 62								;; BackgrdBuff + 31*2
.ScanR:
	LD A,(HL)
	AND A
	JR NZ,NukeCol
	DEC HL
	DEC HL
	JR ScanR

;; If the current screen column sprite is a blank, delete it.
.NukeCol:
	INC HL
	LD A,(HL)
	OR &FA												;; ~5
	INC A
	RET NZ
	LD (HL),A
	DEC HL
	LD (HL),A
	RET

;; Scan from the left for the first drawn column
.NukeColL:
	LD HL,BackgrdBuff									;; BackgrdBuff buffer
ScanL:
	LD A,(HL)
	AND A
	JR NZ,NukeCol
	INC HL
	INC HL
	JR ScanL

;; -----------------------------------------------------------------------------------------------------------
;; This copies a block of data to another block in order to reset the
;; values of the destination block.
;; The "CALL Reinitialise" must be followed by a DEFW argument with
;; the address of the byte indicating both block length.
;; Then the first byte of data to copy is the addr after it up to the
;; block length.
;; The destination block is the contiguous block after that.
.Reinitialise:
	;; Dereference top of stack into HL, incrementing pointer
	;; hence the CALL if followed by a DEFW argument
	POP 	HL											;; get PC from Stack; it is pointing on the byte after the CALL, which is an argument
	LD 		E,(HL)
	INC		HL
	LD 		D,(HL)										;; DE = Argument value
	INC 	HL											;; HL points on the byte after the Word argument
	PUSH 	HL											;; Push that addr as the RETurn addr
	EX 		DE,HL										;; argument now in HL
	LD 		C,(HL)										;; get the value at addr in HL (argument)
	LD 		B,0											;; put value in BC (length)
	INC 	HL											;; point on next byte (argument addr +1)
	LD 		D,H
	LD 		E,L											;; DE = "arg affr value + 1"
	ADD 	HL,BC										;; HL = arg+1 + length
	EX 		DE,HL										;; DE = "arg+1 + length"; HL = "arg + 1"
	LDIR												;; repeat LD (DE),(HL); DE++, HL++, BC-- until BC=0
	RET

;; -----------------------------------------------------------------------------------------------------------
;; 2 available functions to Erase a block of memory.
;; Erase_forward_Block_RAM will erase using the value 00
;; Erase_block_val_in_E will erase using the value in E
;; Input: HL=start addr, BC=length, E (erase value for Erase_block_val_in_E only)
.Erase_forward_Block_RAM:
	LD 		E,0											;; default erase value is 0
.Erase_block_val_in_E:														;; if entering directly here; E will have the erase value
	LD 		(HL),E										;; Start at HL, fill with value in E
	INC 	HL											;; next HL
	DEC 	BC											;; BC counter - 1
	LD 		A,B
	OR 		C											;; test if BC = 0
	JR 		NZ,Erase_block_val_in_E						;; no? then loop until finished
	RET

;; -----------------------------------------------------------------------------------------------------------
;; These are the init/default values for the Inventory (see 247B) and
;; Counters (see 247C). First byte is the length of the array (9).
;; Then the reset values to initialize the variables.
;; The Reinitialise call with 2471 as argument will copy the 9 bytes of
;; StatusReinit_reset_data into the Inventory (247B) & after
StatusReinit:
	DEFB 	9             			;; Number of bytes (length) to reinit with
StatusReinit_reset_data:
	DEFB 	&00						;; Inventory reset value; Indicates what objects we have; a &FF here gives us all the objects!
	DEFB 	0             			;; Speed reset value
	DEFB 	0             			;; Springs reset value
	DEFB 	0             			;; Heels invulnerable reset value
	DEFB 	0             			;; Head invulnerable reset value
	DEFB 	8             			;; Heels lives reset value
	DEFB 	8             			;; Head lives reset value
	DEFB 	0             			;; Donuts reset value
	DEFB 	0             			;; TODO : jump force reset value

;; -----------------------------------------------------------------------------------------------------------
;; This will indicate the available character inventory.
;; A '1' means that the item has been picked up.
;;		bit0 : Purse (Heels)
;;		bit1 : Hooter (Head)
;;		bit2 : Tray of Donuts (Head)
.Inventory:
	DEFB 	0

;; -----------------------------------------------------------------------------------------------------------
;; These are the main counters (Lives, Invuln, Speed, Spring, Donuts)
.Counters:
.Speed:
	DEFB 	0							;; speed
.Spring:
	DEFB 	0							;; number of extra jumps
.Heels_invulnerability:
	DEFB 	0							;; Head's invulnerable
.Head_s_invulnerability:
	DEFB 	0							;; Heels' invulnerable
Characters_lives:
	DEFB 	4							;; Heels' lives
	DEFB 	4                     		;; Head's lives
nb_donuts:
	DEFB 	0							;; Number of Donuts available

jump_force____to_be_checked:
	DEFB 	0             				;; Number of boosted Jumps

;; -----------------------------------------------------------------------------------------------------------
selected_characters:
	DEFB 	3 	    					;; Note: both can be selected! ; bit0=Heels, Bit1=Head; Bit2=Next character to swop to (0 Heels, 1 Head)
both_in_same_room:
	DEFB 	1							;; True/False

.Teleport_up_anim_length:
	DEFB 	0
.Teleport_down_anim_length:
	DEFB 	0

.InvulnModulo:
	DEFB 	3         	    			;; InvulnModulo
.SpeedModulo:
	DEFB 	2 	            			;; SpeedModulo

;; -----------------------------------------------------------------------------------------------------------
;; Reinitialisation size of the array
;; The Reinitialise call with 248A as argument will copy the 3 bytes of
;; ReinitThing_reset_data into the ???_248E & after
ReinitThing:
	DEFB 	3             				;; Three bytes to reinit with:
ReinitThing_reset_data:
	DEFB 	&00, &00, &FF

;; -----------------------------------------------------------------------------------------------------------
TODO_248e:
	DEFB 	&00
TODO_248f:
	DEFB 	&00
.IsStill:
	DEFB 	&FF     					;; IsStill; &00 if moving, &FF if still

;; -----------------------------------------------------------------------------------------------------------
.TickTock:
	DEFB 	&02							;; TickTock; Phase for moving

;; -----------------------------------------------------------------------------------------------------------
.SaveRestore_Block3:										;; Save/Restore Block 3 : &19 (25 bytes)
TODO_2492:
	DEFB 	&00							;; ??? a stored value of room access code (0=Stay,1=Down,2=Right,3=Up,4=Left,5=Below,6=Above,7=Teleport)
.EntryPosn:
	DEFB 	&00, &00, &00				;; Where we entered the room (for when we die).
TODO_2496:
	DEFB 	&03  					    ;; ???

Carrying:
	DEFW 	&0000  		           		;; Pointer to carried object.

;; -----------------------------------------------------------------------------------------------------------
;; Fired Donut Object
FiredObj_variables:  										;; &12 = 18
	DEFW	&0000						;;	0&1 :
	DEFW	&0000						;;	2&3 :
	DEFB	&20							;;	4 : O_FLAGS
	DEFB	&28							;;	5 : O_U coordinate
	DEFB	&0B							;;	6 : O_V coordinate
	DEFB	GROUND_LEVEL				;;	7 : O_Z coordinate
	DEFB	&24							;;	8 : O_SPRITE
	DEFB	&08							;;	9 : Sprite flags (bit5: set = double size)
	DEFB	&12							;;	A : O_FUNC
	DEFB	&FF							;;	B : O_IMPACT
	DEFB	&FF							;;	C :
	DEFB	&00							;;	D :
	DEFB	&00							;;	E :
	DEFB	&08							;;	F : O_ANIM
	DEFB	&00							;;	10 : O_DIRECTION (dir code 0 to 7 or FF)
	DEFB	&00							;;	11 :
.SaveRestore_Block3_end

;; -----------------------------------------------------------------------------------------------------------
character_direction:
	DEFB 	&0F             			;; LRDU direction [3:0] = Left,Right,Down,Up (active low)
Saved_Objects_List_index:
	DEFB 	&00
Other_sound_ID:
	DEFB 	&00							;; &80 will be added to this ID value before playing
Sound_ID:
	DEFB 	&00       					;; Id of sound, +1 (0 = no sound)
Movement:
	DEFB 	&FF

Head_offset 			EQU 	OBJECT_LENGTH

Heels_variables:											;; &12 = 18
	DEFW 	&0000						;;	0&1 :
	DEFW 	&0000						;;	2&3 :
	DEFB 	&08							;;	4 : O_FLAGS
	DEFB 	&28							;;	5 : O_U coordinate
	DEFB 	&0B							;;	6 : O_V coordinate
	DEFB 	GROUND_LEVEL				;;	7 : O_Z coordinate
	DEFB 	&18							;;	8 : O_SPRITE
	DEFB 	&21							;;	9 : Sprite flags (bit5: set = double size)
	DEFB 	&00							;;	A : O_FUNC
	DEFB 	&FF							;;	B : O_IMPACT
	DEFB 	&FF							;;	C :
	DEFB 	&00							;;	D :
	DEFB 	&00							;;	E :
	DEFB 	&00							;;	F : O_ANIM
	DEFB 	&00							;;	10 : O_DIRECTION (dir code 0 to 7 or FF)
	DEFB 	&00							;;	11 :

;; Head_variables addr = Heels_variables + Head_offset
Head_variables:												;; &12 = 18
	DEFW	&0000						;;	0&1 :
	DEFW	&0000						;;	2&3 :
	DEFB	&08							;;	4 : O_FLAGS
	DEFB	&28							;;	5 : O_U coordinate
	DEFB	&0B							;;	6 : O_V coordinate
	DEFB	GROUND_LEVEL				;;	7 : O_Z coordinate
	DEFB	&1F							;;	8 : O_SPRITE
	DEFB	&25							;;	9 : Sprite flags (bit5: set = double size)
	DEFB	&00							;;	A : O_FUNC
	DEFB	&FF							;;	B : O_IMPACT
	DEFB	&FF							;;	C : (displacement when trying to merge (when swop to both))
	DEFB	&00							;;	D :
	DEFB	&00							;;	E :
	DEFB	&00							;;	F : O_ANIM
	DEFB	&00							;;	10 : O_DIRECTION (dir code 0 to 7 or FF)
	DEFB	&00							;;	11 :

;; -----------------------------------------------------------------------------------------------------------
;; This defines the sprites list that compose an animation for
;; Head and Heels (facing and rearward) and also for the "Vape"
;; animations (Dying, Teleporting, Vanishing (hushpuppies), etc.).
;; The first byte is the current index in the animation (which is
;; the current sprite in the anim). The list is 0-terminated.
;; If the bit7 of the sprite code is set, the sprite is mirrored.
.HeelsLoop:
	DEFB 	&00, SPR_HEELS1, SPR_HEELS2, SPR_HEELS1, SPR_HEELS3, &00					;; Frame_index, SPR_HEELS1,SPR_HEELS2,SPR_HEELS1,SPR_HEELS3, end
.HeelsBLoop:
	DEFB 	&00, SPR_HEELSB1, SPR_HEELSB2, SPR_HEELSB1, SPR_HEELSB3, &00				;; Frame_index, SPR_HEELSB1,SPR_HEELSB2,SPR_HEELSB1,SPR_HEELSB3, end
.HeadLoop:
	DEFB 	&00, SPR_HEAD1, SPR_HEAD2, SPR_HEAD1, SPR_HEAD3, &00						;; Frame_index, SPR_HEAD1,SPR_HEAD2,SPR_HEAD1,SPR_HEAD3, end
.HeadBLoop:
	DEFB 	&00, SPR_HEADB1, SPR_HEADB2, SPR_HEADB1, SPR_HEADB3, &00					;; Frame_index, SPR_HEADB1,SPR_HEADB2,SPR_HEADB1,SPR_HEADB3, end
.Vapeloop1:
	DEFB 	&00, SPR_VAPE1, SPR_FLIP or SPR_VAPE1, SPR_FLIP or SPR_VAPE2				;; Frame_index, SPR_VAPE1, &80 | SPR_VAPE1, &80 | SPR_VAPE2
	DEFB	SPR_VAPE2, SPR_FLIP or SPR_VAPE2, SPR_FLIP or SPR_VAPE3						;; SPR_VAPE2, &80 | SPR_VAPE2, &80 | SPR_VAPE3
	DEFB 	SPR_VAPE3, SPR_VAPE3, SPR_FLIP or SPR_VAPE3									;; SPR_VAPE3, SPR_VAPE3, &80 | SPR_VAPE3
	DEFB 	SPR_FLIP or SPR_VAPE3, SPR_VAPE3, SPR_VAPE3, &00             				;; &80 | SPR_VAPE3, SPR_VAPE3, SPR_VAPE3, end
.VapeLoop2:
	DEFB 	&00, SPR_VAPE3, SPR_FLIP or SPR_VAPE3, SPR_VAPE3, SPR_FLIP or SPR_VAPE3   	;; Frame_index, SPR_VAPE3, &80 | SPR_VAPE3, SPR_VAPE3, &80 | SPR_VAPE3
	DEFB 	SPR_FLIP or SPR_VAPE2, SPR_VAPE2, SPR_VAPE1, SPR_FLIP or SPR_VAPE2, &00		;; &80 | SPR_VAPE2, SPR_VAPE2, SPR_VAPE1, &80 | SPR_VAPE2, end

;; -----------------------------------------------------------------------------------------------------------
;; These are the variable and function to make a facing Head blink!
;; Note that redoing Xor a second time cancel the result (ie. revert back to the original image)
.BlinkEyesState:															;; bit7 = eyes state : 1 (closed) or 0 (open) (for BlinkEyes)
	DEFB 	&00
.BlinkEyesCounter:															;; (for BlinkEyes)
	DEFB 	&40

;; -----------------------------------------------------------------------------------------------------------
;; Blinks Head eyes if facing us
.BlinkEyes:
	LD 		HL,BlinkEyesState							;; point on BlinkEyesState
	LD 		A,&80
	XOR 	(HL)										;; read, toggle bit7 and....
	LD 		(HL),A										;; ...update BlinkEyesState
	LD 		A,(SpriteFlips_buffer + 3 + MOVE_OFFSET) 	;; check if the sprite is flipped or not
	BIT 	0,A											;; test bit0 (Zero set (bit0=0) = facing right, Zero reset (bit0=1) = facing left)
	LD 		HL,img_head_1f + &0D + MOVE_OFFSET			;; SPR_HEAD2 addr + &0D offset (&8FCD start of the eyes in Head's image)
	LD 		DE,Blink_XOR_facing_right					;; load Xor Right
	JR 		Z,weybw_doit								;; if bit0 was previously Zero then jump weybw_doit with Xor2
	DEC 	HL											;; else HL points on &8FCC
	LD 		DE,Blink_XOR_facing_Left					;; and use Xor Left instead of Xor Right
weybw_doit:
	PUSH 	DE
	PUSH 	HL
	CALL 	BlinkEyes_XORify							;; do it on the 3x24 SPR_HEAD2 image
weybw_also_do_mask:
	LD 		DE,3*24										;; then redo it &48 bytes further (72=3x24) which is the ...
	POP 	HL											;; ... mask part (SPR_HEAD2+spritelength + &0D)
	ADD 	HL,DE
	POP 	DE
.BlinkEyes_XORify:
	LD 		C,6											;; 6 lines (SPR_HEAD2 sprite is 3x24)
wgxor_1:
	LD 		B,2											;; do 2 bytes in a row
wgxor_2:
	LD 		A,(DE)										;; read XOR value
	XOR 	(HL)										;; Xor sprite byte
	LD 		(HL),A										;; and update it
	INC 	DE											;; next xor byte
	INC 	HL											;; next data byte
	DJNZ 	wgxor_2										;; loop 2 consecutive bytes
	INC 	HL											;; skip next byte (nothing needed to be xored)
	DEC 	C											;; next line
	JR 		NZ,wgxor_1									;; loop all 6 lines
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Xor table to invert chosen bits and blink Head's eyes;
;; One set is used if Head is facing left, the other for facing right.
;; For exemple, if facing right, the xoring result on the image SPR_HEAD2 (&8FC0) is this:
;; (the effect is more obvious in game!)
;;         ........................                               ........................
;;         .........@@@@@..........        Xor:                   .........@@@@@..........
;;         .......@@@@@@@@@........		  03 00 1B 80 38 00       .......@@@@@@@@@........
;;         ......@@@@@@@@@@@.......		  21 00 08 00 04 00       ......@@@@@@@@@@@.......
;;         .....@@@@@@@@@..@.......	   8FCD : ......FF ........   .....@@@@@@@@@&&@.......
;;         .....@@@@@@..@@@@@......   ________...FF.FF F.......   .....@@@@@@&&@,,,@......
;;         ....@@@@@@.@@@@@@@......   ________..FFF... ........   ....@@@@@@&,,@@@@@......
;;         ....@@@@@@@@@@@.@@@@....   ________..F....F ........   ....@@@@@@,@@@@&@@@@....
;;         ....@@@@@@@@.@@.@...@...   ________....F... ........   ....@@@@@@@@&@@.@...@...
;;         ....@@@@@@@@.@@@.....@..   ________.....F.. ........   ....@@@@@@@@.,@@.....@..
;;         ...@.@@@@@@@@@@@.....@..                               ...@.@@@@@@@@@@@.....@..
;;         .@@@.@@@@@@@@@@......@..                               .@@@.@@@@@@@@@@......@..
;;         ..@.@@@@@@@@@@.@.....@..       F = bit flipped         ..@.@@@@@@@@@@.@.....@..
;;         ..@.@@@.@@@@@@......@...                               ..@.@@@.@@@@@@......@...
;;         ..@.@@@.@@@.@@......@@..                               ..@.@@@.@@@.@@......@@..
;;         .@.@@@.@@@..@@@@..@@@@@.                               .@.@@@.@@@..@@@@..@@@@@.
;;         ...@@@@.@@@@....@@.@@@@.                               ...@@@@.@@@@....@@.@@@@.
;;         ....@@@@..@@@@@@@...@@..                               ....@@@@..@@@@@@@...@@..
;;         ...@.@@.@@.@@@@.........                               ...@.@@.@@.@@@@.........
;;         ...@@.@@@@@.............                               ...@@.@@@@@.............
;;         .....@.@.@@.............                               .....@.@.@@.............
;;         ........@@..............                               ........@@..............
;;         ........................                               ........................
;;         ........................                               ........................
;; and on the mask (&9008) it'll be this:
;;         @@@@@@@@@.....@@@@@@@@@@                              @@@@@@@@@.....@@@@@@@@@@
;;         @@@@@@@..@@@@@..@@@@@@@@        Xor:                  @@@@@@@..@@@@@..@@@@@@@@
;;         @@@@@@.@@@@@@@@@.@@@@@@@		  03 00 1B 80 38 00      @@@@@@.@@@@@@@@@.@@@@@@@
;;         @@@@@.@@@@@@@@@@@.@@@@@@		  21 00 08 00 04 00      @@@@@.@@@@@@@@@@@.@@@@@@
;;         @@@@.@@@@@@@@@..@.@@@@@@	   9015 : ......FF ........  @@@@.@@@@@@@@@&&@.@@@@@@
;;         @@@@.@@@@@@..@@@@@.@@@@@   ________...FF.FF F.......  @@@@.@@@@@@&&@,,,@.@@@@@
;;         @@@.@@@@@@.@@@@@@@.@@@@@   ________..FFF... ........  @@@.@@@@@@&,,@@@@@.@@@@@
;;         @@@.@@@@@@@@@@@.@@@@@@@@   ________..F....F ........  @@@.@@@@@@,@@@@&@@@@@@@@
;;         @@@.@@@@@@@@.@@.@...@@@@   ________....F... ........  @@@.@@@@@@@@&@@.@...@@@@
;;         @@@.@@@@@@@@.@@@.....@@@   ________.....F.. ........  @@@.@@@@@@@@.,@@.....@@@
;;         @....@@@@@@@@@@@.....@@@                              @....@@@@@@@@@@@.....@@@
;;         .....@@@@@@@@@@......@@@                              .....@@@@@@@@@@......@@@
;;         @...@@@@@@@@@@.@.....@@@        F = bit flipped       @...@@@@@@@@@@.@.....@@@
;;         @...@@@.@@@@@@......@.@@                              @...@@@.@@@@@@......@.@@
;;         @...@@@.@@@.@@......@..@                              @...@@@.@@@.@@......@..@
;;         ...@@@.@@@..@@@@..@@....                              ...@@@.@@@..@@@@..@@....
;;         @..@@@@.@@@@....@@......                              @..@@@@.@@@@....@@......
;;         @@@.@@@@..@@@@@@@.@....@                              @@@.@@@@..@@@@@@@.@....@
;;         @@...@@....@@@@..@@@..@@                              @@...@@....@@@@..@@@..@@
;;         @@....@........@@@@@@@@@                              @@....@........@@@@@@@@@
;;         @@@.........@@@@@@@@@@@@                              @@@.........@@@@@@@@@@@@
;;         @@@@@.@....@@@@@@@@@@@@@                              @@@@@.@....@@@@@@@@@@@@@
;;         @@@@@@@@..@@@@@@@@@@@@@@                              @@@@@@@@..@@@@@@@@@@@@@@
;;         @@@@@@@@@@@@@@@@@@@@@@@@                              @@@@@@@@@@@@@@@@@@@@@@@@
Blink_XOR_facing_Left:
	DEFB 	&00, &C0, &01, &D8, &00, &1C, &00, &84, &00, &10, &00, &20
Blink_XOR_facing_right:
	DEFB 	&03, &00, &1B, &80, &38, &00, &21, &00, &08, &00, &04, &00

;; -----------------------------------------------------------------------------------------------------------
;; Blink Head eyes, checks if need to play teleport anims, check Death anim
;; Decrease invuln counter if needed,
.Characters_Update:
	LD 		A,(BlinkEyesState)
	RLA													;; put bit7 in carry (1 = eyes closed, 0 = opened)
	CALL 	c,BlinkEyes 								;; If currently blinked, unblink it!
	LD 		HL,DyingAnimFrameIndex						;; get DyingAnimFrameIndex
	LD 		A,(HL)										;; read DyingAnimFrameIndex
	AND 	A											;; test
	JR 		Z,ct_tp										;; if Zero flag set (DyingAnimFrameIndex = 0) then skip further, else:
	EXX													;; dying and the vape/dying anim is being played
	LD 		HL,selected_characters						;; points on selected_characters
	LD 		A,(Dying)									;; get Dying
	AND 	(HL)										;; compare with char selected
	EXX
	JP 		NZ,HandleDeath								;; if NZ (DyingAnimFrameIndex != 0) then HandleDeath and RET, else
	CALL 	HandleDeath									;; also do HandleDeath but after do this as well:
ct_tp
	LD 		HL,Teleport_up_anim_length
	LD 		A,(HL)										;; get where we are at in the teleport anim
	AND 	A											;; test
	JP 		NZ,teleport_up_playing						;; if not 0 the jump teleport_up_playing, else:
	INC		HL											;; Teleport anim up not/no-longer playing : point on Teleport_down_anim_length
	OR 		(HL)										;; test if Teleport_down_anim_length = 0
	JP 		NZ,teleport_down_playing					;; no then jump teleport_up_playing
	;; Deal with invuln counter every 3 frames.
	LD 		HL,InvulnModulo								;; else, HL points on InvulnModulo value
	DEC 	(HL)										;; -1
	JR 		NZ,ct_mvt									;; not yet 0, skip the invuln update
	LD 		(HL),3										;; else, reset back to 3
	LD 		HL,(selected_characters)					;; get selected_characters in L and both_in_same_room in H
	LD 		A,H											;; both_in_same_room in A
	ADD 	A,A											;; *2 or << 1 (bit1)
	OR 		H
	OR 		L											;; A=3 if both in same room, A=2 if Head only, A=1 if Heels only
	RRA													;; Heels value in carry (in the rooom=1, not in=0)
	PUSH AF												;; save
decr_heels_invuln:
	LD 		A,CNT_HEELS_INVULN
	CALL 	c,Decrement_counter_and_display				;; if Heels in the room, decr invul counter
	POP 	AF
	RRA													;; Head value in carry (in the room=1, not in=0)
decr_head_invuln:
	LD 		A,CNT_HEAD_INVULN
	CALL 	c,Decrement_counter_and_display				;; if Head in the room, decr invul counter
ct_mvt
	LD 		A,&FF
	LD 		(Movement),A								;; stop movement
	LD 		A,(access_new_room_code)					;; get access_new_room_code (0=Stay,1=Down,2=Right,3=Up,4=Left,5=Below,6=Above,7=Teleport)
	AND 	A											;; test
	JR 		Z,br_25B6									;; if 0 (stay same room) skip to br_25B6, else (change room):
change_room:
	LD 		A,(Saved_Objects_List_index)				;; else	get Saved_Objects_List_index
	AND 	A											;; test
	JR 		Z,br_25B3									;; if 0 skip to br_25B3, else:
	LD 		A,(character_direction)						;; else get LRDU character_direction
	SCF													;; set Carry
	RLA													;; rotate left and set bit0 to 1 (convert LRDU to LRDU1 = CFSLRDUJ format, with jump reset (active low))
	LD 		(Current_User_Inputs),A						;; update Current_User_Inputs ; CFSLRDUJ
	JR 		br_25B6										;; skip to br_25B6

br_25B3
	LD 		(access_new_room_code),A					;; update access_new_room_code (0=Stay,1=Down,2=Right,3=Up,4=Left,5=Below,6=Above,7=Teleport)
br_25B6
	CALL 	CharThing4

br_25B9:
	CALL Get_curr_Char_variables						;; HL = pointer on current selected character's variables
	PUSH HL
	POP IY
	LD A,(IY+O_Z)
	CP &84
	JR NC,CheckFired
	XOR A
	LD (&248F),A
	LD A,(FloorAboveFlag)
	AND A
	JR NZ,CheckFired
	LD A,&06											;; code 6 = "go room Above"
	LD (access_new_room_code),A							;; update access_new_room_code (0=Stay,1=Down,2=Right,3=Up,4=Left,5=Below,6=Above,7=Teleport)
.CheckFired:
	;; Check for Fire being pressed
	LD A,(FireDonuts_Pressed)							;; get FireDonuts_Pressed
	RRA													;; get bit0 in Carry
	JR NC,CheckDying									;; Carry reset so not pressed, jump to CheckDying, else:
	LD A,(selected_characters)							;; get selected_characters
	OR &FD												;; ~&02 test for Head
	INC A												;; if bit1 was 1, then A is now 0
	LD HL,Saved_Objects_List_index						;; point on Saved_Objects_List_index
	OR (HL)
	JR NZ,CantFireDonut 								;; Skips if not Head (alone)
	LD A,(Inventory)									;; get inventory
	OR &F9												;; ~&06 test bits 2 (Donuts) and 1 (Hooter)
	INC A												;; A is now 0 if we have both Hotter and donuts
	JR NZ,CantFireDonut 								;; Skips to CantFireDonut if don't have donuts and a hooter, else:
	LD A,(FiredObj_variables+O_ANIM)					;; [7:3] = anim code, [2:0] = frame
	CP &08												;; anim code 1; frame 0
	JR NZ,CantFireDonut									;; if there is an Anim loop jump CantFireDonut, else:
	LD HL,Head_variables+O_U							;; Head U
	LD DE,FiredObj_variables+O_U						;; FiredObj U
	LD BC,&0003											;; U,V and Z
	LDIR												;; Copies X/Y/Z coordinate from Head to fired donut. repeat LD (DE),(HL); DE++, HL++, BC-- until BC=0
	LD HL,FiredObj_variables
	PUSH HL
	POP IY												;; Sets IY to FiredObj_variables
	LD A,(Do_Objects_Phase)								;; get Do_Objects_Phase
	OR OBJFN_FIRE
	LD (FiredObj_variables+O_FUNC),A
	LD (IY+O_FLAGS),0									;; Init fire obj flags ;
	LD A,(character_direction)							;; get LRDU character_direction
	LD (FiredObj_variables+O_IMPACT),A
	LD (IY+&0C),&FF										;; ??? displacement if merges ???
	LD (IY+O_ANIM),&20									;; anim code in [7:3] = &04 (index3 in AminTable = ANIM_VAPE2) and frame = 0
	CALL EnlistAux
	;; Use up a donut
	LD A,CNT_DONUTS
	CALL Decrement_counter_and_display
	LD B,Sound_ID_Donut_Firing							;; Sound ID &48 = Donut use
	CALL Play_Sound
	LD A,(nb_donuts)
	AND A												;; To test if A==0
	JR NZ,CheckDying									;; if A > 0 then can shoot Donut  ; if we put a &18 0D (JR CheckDying) then we have infinite Shoots
	LD HL,Inventory										;; point on inventory
	RES 2,(HL)
	CALL Draw_Screen_Periphery
	JR CheckDying

.CantFireDonut:
	CALL Play_Sound_NoCanDo
.CheckDying:
	LD HL,access_new_room_code							;; point on access_new_room_code
	LD A,(HL)											;; get access_new_room_code (0=Stay,1=Down,2=Right,3=Up,4=Left,5=Below,6=Above,7=Teleport)
	AND &7F												;; ignore bit7
	RET Z												;; if (&80 () or &00 (staying in same room)) leave, else (change room):
	LD A,(DyingAnimFrameIndex)							;; get DyingAnimFrameIndex
	AND A												;; test
	JR Z,FinishedDying									;; if 0 (finished dying) continue at FinishedDying, else (Dying):
	LD (HL),0											;; indicate we stay in the room, we can't change room when dying
	RET

;; -----------------------------------------------------------------------------------------------------------
FinishedDying:
	LD A,(both_in_same_room)							;; get both_in_same_room
	AND A												;; test
	JR Z,nfc_end										;; no? then jump nfc_end, else:
	CALL Get_curr_Char_variables						;; HL = pointer on current selected character's variables
	PUSH HL
	POP IY
	CALL Unlink
	LD A,(selected_characters)							;; get selected_characters
	CP &03
	JR Z,nfc_end
	LD HL,&2496											;; TODO???
	CP (HL)
	JR Z,br_2672
	XOR &03
	LD (HL),A
	JR br_267D

br_2672
	LD HL,&BB31											;; copy the 5 bytes in the buffer in the 3 variables from 2492
	LD DE,&2492											;; SaveRestore_Block3
	LD BC,&0005
	LDIR												;; repeat LD (DE),(HL); DE++, HL++, BC-- until BC=0

br_267D
	LD HL,&0000
	LD (Heels_variables+&0D),HL							;; reset Heels item &D and &E
	LD (Head_variables+&0D),HL							;; reset Head item &D and &E
	CALL Save_array										;; SaveStuff
nfc_end:
	LD HL,&0000											;; reset Carrying
	LD (Carrying),HL
	JP Go_to_room										;; Change room

teleport_down_playing:
	DEC (HL)
	LD HL,(selected_characters)							;; get selected_characters and both_in_same_room
	JP CharThing18

teleport_up_playing:
	DEC (HL)
	LD HL,(selected_characters)							;; get selected_characters and both_in_same_room
	JP NZ,CharThing19
	LD A,&07											;; code 7 = Teleport Code
	LD (access_new_room_code),A							;; update access_new_room_code (0=Stay,1=Down,2=Right,3=Up,4=Left,5=Below,6=Above,7=Teleport)
	JP br_25B9

;; -----------------------------------------------------------------------------------------------------------
.HandleDeath:
	DEC (HL)											;; decrease DyingAnimFrameIndex
	JP NZ,CharThing20									;; in the process of dying go CharThing20, else dead:
end_of_death:
	LD HL,&0000
	LD (Carrying),HL
	LD HL,Characters_lives								;; point on Characters_lives
	LD BC,(Dying)
	LD B,&02
	LD D,&FF
hded_loop:
	RR C
	JR NC,br_26CA
	LD A,(HL)											;; Sub 1 to a base10 value in HL (1st time : Characters_lives = Heels lives; 2nd time : Characters_lives + 1)
	SUB 1
	DAA													;; This subroutine is used to decrease Head's or Heels' lives
	LD (HL),A											;; a 00 (NOP) here, gives infinite lives
	JR NZ,br_26CA
	LD D,0												;; D updated to &00 if any lives reduced.
br_26CA
	INC HL												;; points on Head's lives
	DJNZ hded_loop
	;; If no lives left, game over.
	DEC HL
	LD A,(HL)
	DEC HL
	OR (HL)
	JP Z,Game_over										;; if Z set then Game_over
	;; No lives lost, then skip to the end.
	LD A,D
	AND A
	JR NZ,HD_8
	LD HL,Characters_lives								;; point on Characters_lives
	LD A,(both_in_same_room)							;; get both_in_same_room
	AND A												;; test A
	JR Z,HD_6											;; if 0 (not in same room) jump HD_6, else (same room):
	LD A,(&2496)
	CP &03												;; TODO is this to share a life when one has 0, borrow 1 life to the other char.
	JR NZ,hddth_1
	LD A,(HL)
	AND A
	LD A,&01
	JR NZ,br_26EF
	INC A
br_26EF
	LD (&2496),A
	JR HD_8

hddth_1:
	RRA
	JR		c,hddth_skip_inc
	INC HL
hddth_skip_inc:
	LD A,(HL)
	AND A
	JR NZ,br_270E
	LD (both_in_same_room),A							;; update both_in_same_room; InSameRoom

HD_6:
	;; Current character has no more lives, switch to other character"
	CALL Switch_Character
	LD HL,&0000
	LD (DyingAnimFrameIndex),HL							;; reset DyingAnimFrameIndex and Dying
HD_7:
	LD HL,Other_Character_state + MOVE_OFFSET
	SET 0,(HL)
	RET

br_270E
	CALL HD_7
HD_8
	LD A,(&2496)
	LD (selected_characters),A							;; update selected_characters
	CALL CharThing3
	CALL Get_curr_Char_variables						;; HL = pointer on current selected character's variables
	LD DE,&0005											;; object link list is 5 bytes per element
	ADD HL,DE											;; update pointer
	EX DE,HL
	LD HL,EntryPosn
	LD BC,&0003
	LDIR												;; repeat LD (DE),(HL); DE++, HL++, BC-- until BC=0
	LD A,(&2492)
	LD (access_new_room_code),A							;; update access_new_room_code (0=Stay,1=Down,2=Right,3=Up,4=Left,5=Below,6=Above,7=Teleport)
	JP Long_move_to_new_room

CharThing18:
	PUSH HL
	LD HL,VapeLoop2										;; VapeLoop2 anim
	JR CharThing21

CharThing20:
	LD HL,(Dying)
CharThing19:
	PUSH HL
	LD HL,Vapeloop1										;; Vapeloop1 anim index
CharThing21:
	LD IY,Heels_variables
	CALL Read_Loop_byte
	POP HL
	PUSH HL
	BIT 1,L
	JR Z,br_2762
	PUSH AF
	LD (Head_variables+O_SPRITE),A
	RES 3,(IY+Head_offset+O_FLAGS)						;; &16 = &12 + &04
	LD HL,Head_variables
	CALL StoreObjExtents
	LD HL,Head_variables
	CALL UnionAndDraw
	POP AF
br_2762
	POP HL
	RR L
	RET NC
	XOR %10000000
	LD (Heels_variables+O_SPRITE),A
	RES 3,(IY+O_FLAGS)
	LD HL,Heels_variables
	CALL StoreObjExtents
	LD HL,Heels_variables
	JP UnionAndDraw

;; -----------------------------------------------------------------------------------------------------------
;; Put bit 0 of A into bit 2 (next char to swop to) of SwopPressed
CharThing3:
	AND 	&01											;; keep bit0 (Carry=0)
	RLCA
	RLCA												;; and put it in bit2
	LD 		HL,SwopChara_Pressed						;; point on SwopChara_Pressed
	RES 	2,(HL)										;; reset bit 2 of SwopChara_Pressed
	OR 		(HL)										;; keep the other bits as is
	LD 		(HL),A										;; and put the new value of bit2 = value from bit0
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Looks like more movement stuff
CharThing4:
	CALL Get_curr_Char_variables						;; HL = pointer on current selected character's variables
	PUSH HL
	POP IY
	LD A,&3F											;; Stop 0x0X noise
	LD (Other_sound_ID),A								;; update Other_sound_ID &3F+&80 = &BF
	LD A,(Saved_Objects_List_index)						;; get Saved_Objects_List_index
	CALL SetObjList
	CALL Get_curr_Char_variables						;; HL = pointer on current selected character's variables
	CALL StoreObjExtents
	LD HL,&248F
	LD A,(HL)
	AND A
	JR Z,br_27F8
	LD A,(Saved_Objects_List_index)						;; get Saved_Objects_List_index
	AND A
	JR Z,br_27AF
	LD (HL),&00
	JR br_27F8

br_27AF
	DEC (HL)
	CALL Get_curr_Char_variables						;; HL = pointer on current selected character's variables
	CALL ChkSatOn
	JR		c,br_27C2
	DEC (IY+O_Z)
	LD A,Sound_ID_Rise_seq								;; TODO: Repeated rising sequence
	CALL SetOtherSound
	JR br_27D3

br_27C2
	EX AF,AF'
	LD A,Sound_ID_Menu_Blip								;; TODO: Menu blip
	BIT 4,(IY+O_IMPACT)
	SET 4,(IY+O_IMPACT)
	CALL Z,SetOtherSound
	EX AF,AF'
	JR Z,br_27DE
br_27D3
	RES 4,(IY+O_IMPACT)
	SET 5,(IY+O_IMPACT)
	DEC (IY+O_Z)
br_27DE
	LD A,(selected_characters)							;; get selected_characters
	AND &02
	JR NZ,br_27EB
br_27E5
	LD A,(character_direction)							;; get LRDU character_direction
	JP HandleMove

br_27EB
	LD 		A,(Current_User_Inputs)						;; get Current_User_Inputs CFWLRDUJ
	RRA													;; Move LRDU in bits [3:0] (= LRDU dir)
	CALL 	DirCode_from_LRDU							;; get dir code (0 to 7 or FF), from LRDU
	INC 	A											;; was it FF (don't move)?
	JP 		NZ,br_2855									;; no, then moving, goto br_2855
	JR 		br_27E5										;; else not moving goto br_27E5

br_27F8
	SET 4,(IY+O_IMPACT)
	SET 5,(IY+&0C)
	CALL Get_curr_Char_variables						;; HL = pointer on current selected character's variables
	LD A,(access_new_room_code)							;; get access_new_room_code (0=Stay,1=Down,2=Right,3=Up,4=Left,5=Below,6=Above,7=Teleport)
	AND A												;; test
	JR NZ,br_2812
	CALL DoorContact
	JP NC,CharThing23
	JP NZ,CharThing22
br_2812
	LD A,(access_new_room_code)							;; get access_new_room_code (0=Stay,1=Down,2=Right,3=Up,4=Left,5=Below,6=Above,7=Teleport)
	RLA
	JR NC,br_281C
	LD (IY+&0C),&FF
br_281C
	LD A,Sound_ID_High_Blip
	BIT 5,(IY+O_IMPACT)
	SET 5,(IY+O_IMPACT)
	CALL Z,SetOtherSound
	BIT 4,(IY+&0C)
	SET 4,(IY+&0C)
	JR NZ,br_284B
	CALL Get_curr_Char_variables						;; HL = pointer on current selected character's variables
	CALL ChkSatOn
	JR NC,EPIC_40
	JR NZ,EPIC_40
	LD A,Sound_ID_Menu_Blip								;; TODO Menu blip
	CALL SetOtherSound
	JR br_284B

EPIC_40:
	DEC (IY+O_Z)
	RES 4,(IY+O_IMPACT)
br_284B
	XOR A
	LD (&248E),A
	CALL DoCarry
	CALL DoJump
br_2855
	LD A,(Current_User_Inputs)							;; get Current_User_Inputs CFSLRDUJ
	RRA													;; get LRDU in bits [3:0] = LRDU dir
.HandleMove:																;; Do the movement with LRDU direction in A.
	CALL MoveChar
	CALL Orient
	EX AF,AF'
	LD A,(IsStill)
	INC A
	JR NZ,br_288C
	;; Character-is-still case.
    ;; Reset the animation loops for whichever Character is running now.
	XOR A
	LD HL,selected_characters							;; points on selected_characters
	BIT 0,(HL)
	JR Z,br_2874
	LD (HeelsLoop),A									;; HeelsLoop anim index
	LD (HeelsBLoop),A									;; HeelsBLoop anim index
br_2874
	BIT 1,(HL)
	JR Z,br_287E
	LD (HeadLoop),A										;; HeadLoop anim index
	LD (HeadBLoop),A									;; HeadBLoop anim index
br_287E
	;; If Head is facing towards us, do blink. Set BC appropriately.
	EX AF,AF'
	LD BC,SPR_HEELSB1 * 256 + SPR_HEADB1				;; BC,SPR_HEELSB1 << 8 | SPR_HEADB1
	JR c,br_28BC
	CALL DoBlinkHeadEyes
	LD BC,SPR_HEELS1 * 256 + SPR_HEAD2					;; BC,SPR_HEELS1 << 8 | SPR_HEAD2
	JR br_28BC

br_288C
	;; Choose animation frame for movement.
    ;; A' carry -> facing away.
	EX AF,AF'
	LD HL,HeelsLoop										;; HeelsLoop anim index
	LD DE,HeadLoop										;; HeadLoop anim index
	JR NC,br_289B
	LD HL,HeelsBLoop									;; HeelsBLoop anim index
	LD DE,HeadBLoop										;; HeadBLoop anim index
br_289B
	PUSH DE
	LD A,(selected_characters)							;; get selected_characters
	RRA
	JR NC,br_28A8
	CALL Read_Loop_byte
	LD (Heels_variables+O_SPRITE),A
br_28A8
	POP HL
	;; Update Head sprite (Head_variables+O_SPRITE) if Character contains Head.
	LD A,(selected_characters)							;; get selected_characters
	AND &02
	JR Z,br_28B6
	CALL Read_Loop_byte
	LD (Head_variables+O_SPRITE),A
br_28B6
	SET 5,(IY+O_IMPACT)
	JR UpdateChar
br_28BC
	SET 5,(IY+O_IMPACT)
	;; Update the character animation frames to values in BC, and then
	;; call UpdateChar.
.UpdateCharFrame:
	LD A,(selected_characters)							;; get selected_characters
	RRA
	JR NC,br_28C9
	;; Heels case.
	LD (IY+&08),B
br_28C9
	LD A,(selected_characters)							;; get selected_characters
	AND &02
	JR Z,UpdateChar
	;; Head case.
	LD A,C
	LD (Head_variables+O_SPRITE),A
;; Actually resort and redraw the character in IY.
.UpdateChar:
	LD A,(Movement)
	LD (IY+&0C),A
	CALL Get_curr_Char_variables						;; HL = pointer on current selected character's variables
	CALL Relink
	CALL SaveObjListIdx
	XOR A
	CALL SetObjList 									;; Switch to default object list
	CALL Get_curr_Char_variables						;; HL = pointer on current selected character's variables
	CALL UnionAndDraw
	JP Also_Play_Movement_sound

;; -----------------------------------------------------------------------------------------------------------
;; Update the blink counter, checks it, and blink or unblink Head's eyes.
.DoBlinkHeadEyes:
	LD 		HL,BlinkEyesCounter
	DEC 	(HL)										;; decrease blink counter
	LD 		A,&03
	SUB 	(HL)
	RET 	c											;; if blink couter > 3, RET with Carry set, else:

	JR 		Z,do_blink									;; if blink couter == 3, jump to do_blink, else:
	CP 		&03											;; that's "compare blink counter to 0"
	RET 	NZ											;; no? RET Z reset, else:
	LD 		(HL),&40									;; this resets blink counter and "unblink" by recalling do_blink:
do_blink:
	JP 		BlinkEyes									;; Blink Head's eyes (or unblink if done again).

;; -----------------------------------------------------------------------------------------------------------
CharThing22:
	LD HL,&248E
	LD A,(HL)
	AND A
	LD (HL),&FF
	JR Z,CharThing24
	CALL DoCarry
	CALL DoJump
	XOR A
	JR CharThing24

CharThing23:
	XOR A
	LD (&248E),A
	INC A
CharThing24:
	LD C,A
	CALL ResetTickTock
	RES 5,(IY+O_IMPACT)
	LD A,(selected_characters)							;; get selected_characters
	AND &02
	JR NZ,br_292E
	DEC C
	JR NZ,br_2946
	INC (IY+O_Z)
br_292E
	INC (IY+O_Z)
	AND A
	JR NZ,br_2949
	LD A,Sound_ID_Desc_seq								;; TODO: Faster falling noise
	CALL SetOtherSound
	LD HL,jump_force____to_be_checked
	LD A,(HL)
	AND A
	JR Z,br_2955
	DEC (HL)
	LD A,(character_direction)							;; get LRDU character_direction
	JR br_2952

br_2946
	INC (IY+O_Z)
br_2949
	LD A,Sound_ID_Falling								;; TODO: Slower falling noise
	CALL SetOtherSound
	LD A,(Current_User_Inputs)							;; get Current_User_Inputs CFSLRDUJ
	RRA													;; get LRDU in bits [3:0] = LRDU dir
br_2952
	CALL MoveChar
br_2955
	CALL Orient
	LD BC,SPR_HEELSB1 * 256 + SPR_HEADB1				;; SPR_HEELSB1 << 8 | SPR_HEADB1
	JP c,UpdateCharFrame
	LD BC,SPR_HEELS1 * 256 + SPR_HEAD_FLYING			;; SPR_HEELS1 << 8 | SPR_HEAD_FLYING
	JP UpdateCharFrame

;; -----------------------------------------------------------------------------------------------------------
;; Sprite orientation (flip/no-flip and Front/Back)
;; Reset bit4 of O_FLAGS if bit1 is set (U)
;; set bit4 of O_FLAGS if bit1 is reset (V) (sprite needs flip)
;; returns with carry set if facing away or Carry reset if rearward.
.Orient:
	LD 		A,(character_direction)						;; get LRDU character_direction
	CALL 	DirCode_from_LRDU							;; get dir code (0 to 7 or FF), from LRDU
	RRA													;; dir code bit0 in Carry (1=diag, 0=axial)
	RES 	4,(IY+O_FLAGS)
	RRA													;; dir code bit1 in Carry (1: U (Left/Right direction), 0: V (Up/Down direction))
	JR		c,br_2976
	SET 	4,(IY+O_FLAGS)								;; Set Flag bit4 if U dir, reset if V dir
br_2976
	RRA													;; get bit 2 in Carry (0: Front; 1: Back)
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Move the character.
.MoveChar:
	OR &F0
	CP &FF
	LD (IsStill),A
	JR Z,br_2993
	EX AF,AF'
	XOR A
	LD (IsStill),A
	LD A,Sound_ID_Walking								;; Slower walking sound
	CALL SetOtherSound
	EX AF,AF'
	LD HL,character_direction							;; points on LRDU character_direction
	CP (HL)
	LD (HL),A
	JR Z,br_2998
br_2993
	CALL ResetTickTock
	LD A,&FF
br_2998
	PUSH AF
	AND (IY+&0C)
	CALL 	DirCode_from_LRDU							;; get dir code (0 to 7 or FF), from LRDU
	CP &FF
	JR Z,br_29B6
	CALL Get_curr_Char_variables						;; HL = pointer on current selected character's variables
	CALL Move
	JR NC,Sub_Move_Char
	LD A,(IY+O_IMPACT)
	OR &F0
	INC A
	LD A,Sound_ID_Menu_Blip								;; TODO: Menu blip
	CALL NZ,SetOtherSound
br_29B6
	POP AF
	LD A,(IY+O_IMPACT)
	OR &0F
	LD (IY+O_IMPACT),A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Direction bitmask is on stack. "Move" has been called.
;; Update position and do the speed-related movement when when
;; TickTock hits zero.
.Sub_Move_Char
	CALL 	Get_curr_Char_variables						;; HL = pointer on current selected character's variables
	CALL	UpdatePos
	POP 	BC
	LD 		HL,TickTock
	LD 		A,(HL)
	AND 	A
	JR 		Z,Slide
	DEC 	(HL)
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Do a bit more movement if we're Heels or have speed.
;; Direction bitmask is in B
.Slide:
	LD HL,Speed
	LD A,(selected_characters)							;; get selected_characters
	AND &01
	OR (HL)
	RET Z
	LD HL,SpeedModulo
	DEC (HL)
	PUSH BC
	JR NZ,br_29EE
	LD (HL),&02
	LD A,(selected_characters)							;; get selected_characters
	RRA
	JR c,br_29EE
	;; Use up speed if heels not present
	LD A,CNT_SPEED
	CALL Decrement_counter_and_display
br_29EE
	LD A,Sound_ID_Running
	CALL SetOtherSound
	;; Convert bitmap to direction.
	POP AF
	CALL 	DirCode_from_LRDU							;; get dir code (0 to 7 or FF), from LRDU
	;; Return if not moving...
	CP &FF
	RET Z
	;; And do a bit of movement.
	CALL Get_curr_Char_variables						;; HL = pointer on current selected character's variables
	PUSH HL
	CALL Move
	POP HL
	JP NC,UpdatePos
	;; Failing to move...
	LD A,Sound_ID_Menu_Blip								;; TODO: Menu blip
	JP SetOtherSound

;; -----------------------------------------------------------------------------------------------------------
;; The TickTock counter cycles down from 2. Reset it.
.ResetTickTock:
	LD 		A,&02
	LD 		(TickTock),A
	RET

;; -----------------------------------------------------------------------------------------------------------
.DoJump:
	LD A,(selected_characters)							;; get selected_characters
	;; Zero if it's Heels
	LD B,A
	DEC A												;; if selected_characters was not Heels (not 2b01)
	JR NZ,djmp_skip										;; then skip, else (Head):
	XOR A												;; A = 0
	LD (jump_force____to_be_checked),A					;; reset jump force
djmp_skip:
	LD A,(Saved_Objects_List_index)						;; get Saved_Objects_List_index
	AND A
	RET NZ
	LD A,(Current_User_Inputs)							;; get Current_User_Inputs CFSLRDUJ
	RRA													;; move LRDU in bits [3:0] = LRDU dir (active low)
	RET c												;; Jump in Carry (active low, Carry set = No jump, then leave
	;; Jump button handling case
	LD C,0
	LD L,(IY+&0D)
	LD H,(IY+&0E)
	LD A,H
	OR L
	JR Z,br_2A53
	PUSH HL
	POP IX
	BIT 0,(IX+O_SPRFLAGS)
	JR Z,br_2A41
	LD A,(IX+O_IMPACT)
	OR &CF
	INC A
	RET NZ
br_2A41
	LD A,(IX+O_SPRITE)
	AND &7F
	CP SPR_TELEPORT										;; &57 SPR_TELEPORT + jump will Teleport
	JR Z,OnTeleport										;; ???jumping while on a teleporter: teleport????
	CP SPR_SPRING
	JR Z,br_2A52
	CP SPR_SPRUNG
	JR NZ,br_2A53
br_2A52
	INC C
br_2A53
	LD A,(selected_characters)							;; get selected_characters
	AND &02												;; test if Head
	JR NZ,br_2A63										;; if Head skip, else (Heels)
	;; No Head - use up a spring
	PUSH BC
	LD A,CNT_SPRING											;; Spring index
	CALL Decrement_counter_and_display					;; Use one Spring
	POP BC
	JR Z,br_2A64
br_2A63
	;; Head
	INC C
br_2A64
	LD A,C
	ADD A,A
	ADD A,A
	ADD A,4
	CP &0C
	JR NZ,br_2A6F
	LD A,&0A
br_2A6F
	LD (&248F),A
	LD A,Sound_ID_Higher_Blip
	DEC B
	JR NZ,br_2A7C
	LD HL,jump_force____to_be_checked
	LD (HL),&07											;; Head's Jump force?
br_2A7C
	JP SetOtherSound

;; -----------------------------------------------------------------------------------------------------------
OnTeleport:
	LD 		HL,&080C									;; Teleport_up_anim_length and Teleport_down_anim_length
	LD 		(Teleport_up_anim_length),HL				;; init 2 lengths of the teleport vape anim, beaming up and down
	LD 		B,Sound_ID_Teleport_Up						;; Sound_ID &C7 ; Teleporter beam up noise
	JP 		Play_Sound	 								;; will RET

;; -----------------------------------------------------------------------------------------------------------
.DoCarry:
	LD A,(CarryObject_Pressed)							;; get CarryObject_Pressed
	RRA													;; Carry key pressed?
	RET NC												;; no : leave with NC, else:
	LD A,(Inventory)									;; get inventory ; Check if we have the purse
	RRA													;; do we have the Purse?
purseNope:
	JP NC,Play_Sound_NoCanDo							;; no then leave to Play_Sound_NoCanDo, else:
	LD A,(selected_characters)							;; get selected_characters
	AND &01												;; Heels?
	JR Z,purseNope										;; No, then jump back to purseNope (Play Nope sound and leave)
	LD A,Sound_ID_Sweep_Tri								;; else: Sound ID Sweep down and up
	CALL SetOtherSound
	LD A,(Carrying+1)
	AND A												;; test
	JR NZ,DropCarried									;; If holding something, drop it
	CALL Get_curr_Char_variables						;; HL = pointer on current selected character's variables
	CALL GetStoodUpon
	JR NC,purseNope
	LD A,(IX+O_SPRITE)									;; Load sprite of thing carried
	PUSH HL
	LD (Carrying),HL
	LD BC,&D8B0											;; CARRY_POSN = 216 << 8 | 176
	PUSH AF
	CALL Draw_sprite_3x24								;; Draw the item now carried
	POP AF
	POP HL
	JP RemoveObject

;; -----------------------------------------------------------------------------------------------------------
.DropCarried:
	LD A,(Saved_Objects_List_index)						;; get Saved_Objects_List_index
	AND A
	JP NZ,Play_Sound_NoCanDo							;; if NZ Play_Sound_NoCanDo
	LD C,(IY+O_Z)
	LD B,&03
carryLoop:
	CALL Get_curr_Char_variables						;; HL = pointer on current selected character's variables
	PUSH BC
	CALL ChkSatOn
	POP BC
	JR		c,NoDrop
	DEC (IY+O_Z)
	DEC (IY+O_Z)
	DJNZ carryLoop
	LD HL,(Carrying)
	PUSH HL
	LD DE,&0007
	ADD HL,DE
	PUSH HL
	CALL Get_curr_Char_variables						;; HL = pointer on current selected character's variables
	LD DE,&0006											;; curr Char variables+6 = V coord
	ADD HL,DE
	EX DE,HL											;; CharObj + 6 (V) in DE
	POP HL												;; Object + 7 in HL
	LD (HL),C											;; Overwrite id thing with C...
	EX DE,HL
	DEC DE
	LDD
	LDD
	POP HL
	CALL InsertObject
	LD HL,&0000
	LD (Carrying),HL
	LD BC,&D8B0											;; ARRY_POSN = 216 << 8 | 176
	CALL Clear_3x24										;; Clear out the what's-carried display
	CALL Get_curr_Char_variables						;; HL = pointer on current selected character's variables
	CALL DoorContact
	CALL Get_curr_Char_variables						;; HL = pointer on current selected character's variables
	JP StoreObjExtents

.NoDrop:
	LD (IY+O_Z),C										;; Restore old value
	JP Play_Sound_NoCanDo								;; will RET

.SetSound:
	LD HL,Sound_ID										;; pointer on Sound_ID
	JR BumpUp

.SetOtherSound:
	LD HL,Other_sound_ID								;; pointer on Other_sound_ID
.BumpUp:
	CP (HL)												;; compare A and (HL)
	RET c												;; if A < (HL) leave, else:
	LD (HL),A											;; update (HL) with A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; This will add the movement sound to any other music playing
;; (for exemple when going though a door : walking+World music)
.Also_Play_Movement_sound:
	LD 		A,(Other_sound_ID)							;; get Other_sound_ID
	OR 		&80											;; add &80 (if needed) to the Other_sound_ID to make sure values start at &80
	LD 		B,A
	CP 		&85											;; >= &85? (some bip and blips)
	JP 		NC,Play_Sound								;; yes, then play (will RET), else (&80 to &84 = movement sounds):
	LD 		A,(Sound_menu_data)							;; else get Sound_menu_data
	AND 	A											;; test
	RET 	NZ											;; if Sound_menu_data != 0 leave, else play sound in B (movement sounds)
	JP 		Play_Sound									;; will RET

;; -----------------------------------------------------------------------------------------------------------
;; Get a pointer in HL on the selected character's variables
;; ie. if Heels selected HL = Heels_variables else Head_variables
.Get_curr_Char_variables:
	LD 		HL,selected_characters						;; points on selected_characters
	BIT 	0,(HL)										;; is Heels selected?
	LD 		HL,Heels_variables							;; prepare return HL = Heels var
	RET 	NZ											;; if Heels selected then return pointer on Heels_variables
	LD		 HL,Head_variables
	RET													;; else return pointer on Head_variables

;; -----------------------------------------------------------------------------------------------------------
CharThing15:
	XOR A												;; A=0
	LD (Vapeloop1),A									;; set anim index of "Vapeloop1" to 0
	LD (Teleport_up_anim_length),A						;; set Teleport_up_anim_length to 0
	LD (VapeLoop2),A									;; set anim index of "Vapeloop2" to 0
	LD A,&08
	LD (&24A8),A										;; set ??? to 8 Fired_Obj+&0F
	CALL Set_Character_Flags
	LD A,(selected_characters)							;; get selected_characters
	LD (&2496),A										;; update
	CALL Get_curr_Char_variables						;; HL = pointer on current selected character's variables
	PUSH HL
	PUSH HL
	PUSH HL
	POP IY
	LD A,(access_new_room_code)							;; get access_new_room_code (0=Stay,1=Down,2=Right,3=Up,4=Left,5=Below,6=Above,7=Teleport)
	LD (&2492),A										;; store ???
	PUSH AF
	SUB 1												;; at this point the value in A is (0=Down,1=Right,2=Up,3=Left,4=Below,5=Above,6=Teleport)
	PUSH AF
	CP &04												;; if access_new_room_code-1 >=4 (Below,Above,Teleport)
	JR NC,EPIC_86										;; ...then jump EPIC_86, else (A 0 to 3 correspond to access_new_room_code 1 to 4):
	XOR %00000001										;; flip bit0 (invert ???)
	LD E,A
	LD D,0												;; DE=A
	LD HL,DoorHeights
	ADD HL,DE											;; HL = DoorHeights+offset, with offset=A
	LD C,(HL)
	LD HL,WallSideBitmap								;; point on WallSideBitmap
	ADD HL,DE											;; HL = WallSideBitmap+offset, with offset=A
	LD A,(Has_no_wall)									;; get walls status
	AND (HL)											;; apply bitmask
	JR NZ,EPIC_86										;; NZ jump EPIC_86
	LD (IY+O_Z),C
EPIC_86:
	CALL Get_curr_Char_variables						;; HL = pointer on current selected character's variables
	LD DE,&0005
	ADD HL,DE											;; Curr Char Variable+5 (U coord)
	EX DE,HL											;; in DE
	POP AF
	JR c,EPIC_93
	CP &06
	JR Z,EPIC_90
	JR NC,EPIC_92
	CP &04
	JR NC,EPIC_88
	LD HL,Max_min_UV_Table								;; pointer on MinU
	LD C,&FD
	RRA
	JR NC,EPIC_87
	INC DE
	INC HL
EPIC_87:
	RRA
	JR		c,EPIC_95
	LD C,&03
	INC HL
	INC HL
	JR EPIC_95

EPIC_88:
	INC DE
	INC DE
	RRA
	LD A,&84
	JR NC,EPIC_89
	LD A,(&236E)
	AND A
	LD A,&BA
	JR Z,EPIC_89
	LD A,&B4
EPIC_89:
	LD (DE),A
	POP AF
	JR EPIC_97

EPIC_90:
	INC DE
	INC DE
	LD A,(&236E)
	AND A
	JR Z,EPIC_91
	LD A,(DE)
	SUB 6												;; if teleport index 0 in Facing_Entering_new_Room_tab???
	LD (DE),A
EPIC_91:
	LD B,Sound_ID_Teleport_Down							;; Sound_ID &C8 ; Teleport beam down noise
	CALL Play_Sound
	JR EPIC_96

EPIC_92:
	LD HL,UVZ_coord_Set_UVZ
	JR EPIC_94

EPIC_93:
	LD HL,&2C54											;; DE points on the curr Char U (*_variables+5)
EPIC_94:
	LDI													;; copy U ; do : LD (DE),(HL); DE++, HL++, BC--
	LDI													;; copy V
	LDI													;; copy Z
	JR EPIC_96											;; HL now points on Facing_Entering_new_Room_tab

EPIC_95:
	LD A,(HL)
	ADD A,C
	LD (DE),A
EPIC_96:
	POP AF												;; A has the room access code-1 (0==Down,1=Right,2=Up,3=Left,4=Below,5=Above,6=Teleport)
	ADD A,Facing_Entering_new_Room_tab and &00FF		;; &57 = Facing_Entering_new_Room_tab & &00FF + offset
	LD L,A
	ADC A,Facing_Entering_new_Room_tab / 256			;; &2C = (Facing_Entering_new_Room_tab & &FF00 ) >> 8
	SUB L
	LD H,A												;; HL = Facing_Entering_new_Room_tab + A
	LD A,(HL)
	LD (character_direction),A							;; update LRDU character_direction when entering the new room (LRDU format)
EPIC_97:
	LD A,&80
	LD (access_new_room_code),A							;; update access_new_room_code
	POP HL
	LD DE,&0005
	ADD HL,DE
	LD DE,EntryPosn
	LD BC,&0003
	LDIR												;; repeat LD (DE),(HL); DE++, HL++, BC-- until BC=0
	LD (IY+&0D),&00
	LD (IY+&0E),&00
	LD (IY+O_IMPACT),&FF
	LD (IY+&0C),&FF
	POP HL
	CALL Enlist
	CALL SaveObjListIdx
	XOR A
	LD (DyingAnimFrameIndex),A							;; reset DyingAnimFrameIndex
	LD (Dying),A										;; reset Dying
	LD (&236E),A
	JP SetObjList										;; Switch to default object list

.SaveObjListIdx:
	LD A,(ObjListIdx)
	LD (Saved_Objects_List_index),A						;; update Saved_Objects_List_index
	RET

;; -----------------------------------------------------------------------------------------------------------
.Draw_carried_objects:
	LD A,(selected_characters)							;; get selected_characters
	LD HL,both_in_same_room								;; points on both_in_same_room ; InSameRoom
	RRA
	OR (HL)
	RRA
	RET NC												;; Return if low bit not set on InSameRoom and not head
	LD HL,(Carrying)
	INC H
	DEC H
	RET Z												;; Return if high byte zero...
	LD DE,&0008
	ADD HL,DE
	LD A,(HL)											;; Get sprite from object pointed to...
	LD BC,&D8B0											;; CARRY_POSN = 216 << 8 | 176
	JP Draw_sprite_3x24

;; -----------------------------------------------------------------------------------------------------------
TODO_2c54:											;; UVZ for ???
	DEFB 	&28, &28, GROUND_LEVEL

;; -----------------------------------------------------------------------------------------------------------
;; From access_new_room_code (but with teleport put at index 0),
;; get the facing direction when entering a new room from:
;;		 0 : Teleport then facing Down (south-West side of the screen)
;;  1 to 4 : Down, Right, Up, Left then resp. facing Down, Right, Up, Left
;; 5 and 6 : Below,Above then resp. facing Down, Down
Facing_Entering_new_Room_tab:
	DEFB 	&FD, &FD, &FB, &FE, &F7, &FD, &FD

WallSideBitmap: 									;; index 0 = 8 = bit3, index 1 = 4 = bit2 etc.
	DEFB	&08, &04, &02, &01

;; -----------------------------------------------------------------------------------------------------------
;; Takes object (character?) in IY
.ObjContact:
	DEFW 	&0000

.DoorContact:
	CALL GetDoorHeight
	LD A,(IY+O_Z)
	SUB C
	;; Call with A containing height above door.
	JP DoContact

;; Takes object in IY, returns height of relevant door.
.GetDoorHeight:
    ;; Return &C0 if SavedObjListIdx == 0.
	LD C,&C0
	LD A,(Saved_Objects_List_index)						;; get Saved_Objects_List_index
	AND A												;; test
	RET Z												;; if index = 0 leave, else:
	LD IX,DoorHeights
	LD C,(IX+0) 										;; return IX+&00 if near MaxV
	LD A,(Max_min_UV_Table+3)							;; MaxV
	SUB &03
	CP (IY+O_V)
	RET c
	LD C,(IX+2)											;; return IX+&02 if near MinV
	LD A,(Max_min_UV_Table+1)							;; MinV
	ADD A,&02
	CP (IY+O_V)
	RET NC
	LD C,(IX+1)											;; Return IX+&01 if near MaxU
	LD A,(Max_min_UV_Table+2)							;; MaxU
	SUB &03
	CP (IY+O_U)
	RET c
	LD C,(IX+3)											;; Otherwise, return IX+&03
	RET

;; -----------------------------------------------------------------------------------------------------------
.NearHitFloor:
	CP &FF												;; This way, only get the start.
	;; A is zero. We've hit, or nearly hit, the floor.
.HitFloor:
	SCF
	LD (IY+&0D),A
	LD (IY+&0E),A
	RET NZ
	;; Called HitFloor, not NearHitFloor.
	BIT 0,(IY+O_SPRFLAGS)								;; sprite flag bit0
	JR Z,FloorCheck					 					;; Floor check for non-player objects
    ;; else it is the player who has hit floor.
	LD A,(Saved_Objects_List_index)						;; get Saved_Objects_List_index ; SavedObjListIdx
	AND A												;; test
	JR NZ,RetZero_Cset									;; not 0 the leave with NZ and C, else:
	LD A,(FloorCode)
	CP &06												;; Deadly floor?
	JR Z,DeadlyFloorCase
	CP &07												;; No floor?
	JR NZ,RetZero_Cset
	;; Code to handle no floor...
	CALL Get_curr_Char_variables						;; HL = pointer on current selected character's variables
	PUSH IY
	POP DE
	AND A
	SBC HL,DE
	JR Z,HF_1
	LD HL,SwopChara_Pressed								;; point on SwopChara_Pressed; SwopPressed
	LD A,(HL)
	OR &03												;; force Swop????
	LD (HL),A
	JR RetZero_Cset

HF_1:
	LD A,&05											;; code 5 = "Next room below"
	LD (access_new_room_code),A							;; update access_new_room_code (0=Stay,1=Down,2=Right,3=Up,4=Left,5=Below,6=Above,7=Teleport)
	AND A
	RET

;; -----------------------------------------------------------------------------------------------------------
.DeadlyFloorCase:
	LD 		C,(IY+O_SPRFLAGS)
	LD 		B,(IY+O_FLAGS)
	CALL 	DeadlyContact
.RetZero_Cset:
	XOR 	A
	SCF
	RET													;; Return with 0 in A, Z set and carry flag set.

;; -----------------------------------------------------------------------------------------------------------
;; A non-player object has hit the floor.
;; If room has no floor, then the object disappear
.FloorCheck:
	LD 		A,(FloorCode)
	CP 		&07											;; No floor?
	JR 		NZ,RetZero_Cset
	LD 		(IY+O_FUNC),OBJFN_DISAPPEAR					;; Func = OBJFN_DISAPPEAR ; Then it disappears.
	JR 		RetZero_Cset

;; -----------------------------------------------------------------------------------------------------------
;; Object (character?) in IY.
.DoContact2:
	LD A,(IY+O_Z)
	SUB GROUND_LEVEL
	;; A contains height difference
.DoContact:
	;; Clear what's on character so far.
	LD BC,&0000
	LD (ObjContact),BC
	;; If we've hit the floor, go to that case
	JR Z,HitFloor
	;; Just above floor? Still call through
	INC A
	JR Z,NearHitFloor
	;; Set C to high-Z plus one (i.e. what we're resting on)
	CALL GetUVZExtents_AdjustLowZ
	LD C,B
	INC C
	;; Looks like we use what we were on previously as our current
    ;; "on" object - avoid recomputation and keeps the object
    ;; consistent?
    ;;
    ;; Load the object character's on into IX. Go to ChkSitOn if null.
	EXX
	LD A,(IY+&0E)
	AND A
	JR Z,ChkSitOn
	LD H,A
	LD L,(IY+&0D)
	PUSH HL
	POP IX
	;; Various other tests where we switch over to ChkSitOn.
	BIT 7,(IX+O_FLAGS)
	JR NZ,ChkSitOn
	;; Check we're still on it.
	LD A,(IX+O_Z)
	SUB 6
	EXX
	CP B
	EXX
	JR NZ,ChkSitOn
	CALL CheckWeOverlap
	JR NC,ChkSitOn
;; We're still standing on the object
;; Deal with contact between a character and a thing.
;; IY is the character, IX is what it's resting on.
.DoObjContact:
    ;; If it's the second part of a double-height...
	BIT 1,(IX+O_SPRFLAGS)
	JR Z,DOC_1
	;; Reset bit 5 of Offset C
	RES 5,(IX-6)										;; (IX-06)
	;; Load Offset B
	LD A,(IX-7)											;; (IX-07)
	JR DOC_2

;; Otherwise, do the same, but single-height.
DOC_1:
	RES 5,(IX+&0C)
	LD A,(IX+O_IMPACT)
;; Mask Offset C of IY with top 3 bits of Offset C of stood-on object.
DOC_2:
	OR &E0
	LD C,A
	LD A,(IY+&0C)
	AND C
	LD (IY+&0C),A
.DoAltContact:
	XOR A
	SCF
	JP ProcContact

;; -----------------------------------------------------------------------------------------------------------
;; Run through all the objects in the main object list and check their
;; contact with our object in IY, see if it's sitting on them or
;; touching them.
;;
;; Object extents should be in primed registers.
.ChkSitOn:
	LD HL,ObjectLists + 2
CSIT_1:
	LD A,(HL)
	INC HL
	LD H,(HL)
	LD L,A
	OR H
	JR Z,CSIT_4											;; Done - exit list.
	PUSH HL
	POP IX
	BIT 7,(IX+O_FLAGS)
	JR NZ,CSIT_1										;; Bit set? Skip this item
	LD A,(IX+O_Z)										;; Check Z coord of top of obj against bottom of IY
	SUB 6
	EXX
	CP B
	JR NZ,CSIT_3										;; Go to differing height case.
	EXX
	PUSH HL
	CALL CheckWeOverlap
	POP HL
	JR NC,CSIT_1										;; Same height, overlap? Skip
CSIT_2:
	LD (IY+&0D),L										;; Record what we're sitting on.
	LD (IY+&0E),H
	JR DoObjContact 									;; Hit!

CSIT_3:
	CP C
	EXX
	JR NZ,CSIT_1										;; Differs other way? Continue.
	;; Same height instead.
	LD A,(ObjContact+1)
	AND A
	JR NZ,CSIT_1										;; Some test makes us skip...
	PUSH HL
	CALL CheckWeOverlap
	POP HL
	JR NC,CSIT_1										;; If we don't overlap, skip
	LD (ObjContact),HL									;; Store the object we're touching, carry on.
	JR CSIT_1

	;; Completed object list traversal
CSIT_4:
	LD A,(Saved_Objects_List_index)						;; get Saved_Objects_List_index
	AND A
	JR Z,CSIT_7
	CALL GetCharObjIX
	;; Get Z coord of top of the character into A.
	LD A,(selected_characters)							;; get selected_characters
	CP &03
	LD A,&F4											;; -12
	JR Z,CSIT_5
	LD A,&FA											;; -6
CSIT_5:
	ADD A,(IX+O_Z)
	EXX
	;; Compare against bottom of us.
	CP B
	JR NZ,CSIT_6
	;; We're on it, if we overlap.
	EXX
	PUSH HL
	CALL CheckWeOverlap
	POP HL
	JR NC,CSIT_7
	JR CSIT_2

CSIT_6:
	CP C
	EXX
	JR NZ,CSIT_7
	;; Same height, making it pushable.
	LD A,(ObjContact+1)
	AND A
	JR NZ,CSIT_7										;; Give up if already in contact.
	CALL GetCharObjIX
	CALL CheckWeOverlap
	JR NC,CSIT_7
	LD (IY+&0D),0
	LD (IY+&0E),0
	JR CSIT_11

CSIT_7:
	LD HL,(ObjContact)
	LD (IY+&0D),0
	LD (IY+&0E),0
	LD A,H
	AND A
	RET Z
	PUSH HL
	POP IX
	BIT 1,(IX+O_SPRFLAGS)
	JR Z,CSIT_9
	BIT 4,(IX-7)										;; (IX-07)
	JR CSIT_10
CSIT_9:
	BIT 4,(IX+O_IMPACT)
CSIT_10:
	JR NZ,CSIT_11
	RES 4,(IY+&0C)
CSIT_11:
	XOR A
	SUB 1
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Called by the purse routine to find something to pick up.
;; Carry flag set if something is found, and thing returned in HL.
;;
;; Loop through all items, finding ones which match on B or C
;; Then call CheckWeOverlap to see if ok candidate. Return it
;; in HL if it is.
.GetStoodUpon:
	CALL GetUVZExtents_AdjustLowZ						;; Perhaps getting height as a filter?
	LD A,B
	ADD A,6
	LD B,A
	INC A
	LD C,A
	EXX
	;; Traverse list of objects in main object list
	LD HL,ObjectLists + 2
gsu_1:
	LD A,(HL)
	INC HL
	LD H,(HL)
	LD L,A
	OR H
	RET Z
	PUSH HL
	POP IX
	BIT 6,(IX+O_FLAGS)
	JR Z,gsu_1
	LD A,(IX+O_Z)
	EXX
	CP B
	JR Z,gsu_2
	CP C
gsu_2:
	EXX
	JR NZ,gsu_1
	PUSH HL
	CALL CheckWeOverlap
	POP HL
	JR NC,gsu_1
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Object in IY, extents in primed registers.
;; Very similar to ChkSitOn. Checks to see if stuff is on us.
.ChkSatOn:
    ;; Put top of object in B'
	CALL GetUVZExtents_AdjustLowZ
	LD B,C
	DEC B
	EXX
	;; Clear the thing on top of us
	XOR A
	LD (ObjContact),A
	LD HL,ObjectLists + 2
CSAT_1:
	LD A,(HL)
	INC HL
	LD H,(HL)
	LD L,A
	OR H
	JR Z,CSAT_4											;; Reached end?
	PUSH HL
	POP IX
	BIT 7,(IX+O_FLAGS)
	JR NZ,CSAT_1										;; Skip if bit set
	LD A,(IX+O_Z)
	EXX
	CP C												;; Compare IY top with bottom of this object.
	JR NZ,CSAT_3										;; Jump if not at same height
	EXX
	PUSH HL
	CALL CheckWeOverlap
	POP HL
	JR NC,CSAT_1
    ;; Top of us = bottom of them, we have a thing on top.
    ;; Copy our movement over to the block on top.
CSAT_2:
	LD A,(IY+O_IMPACT)
	OR &E0
	AND &EF
	LD C,A
	LD A,(IX+&0C)
	AND C
	LD (IX+&0C),A
	JP DoAltContact

;; Not stacked
CSAT_3:
	CP B
	EXX
	JR NZ,CSAT_1
	;; Same height instead
	LD A,(ObjContact)
	AND A
	JR NZ,CSAT_1										;; Continue if we're already in contact
	PUSH HL
	CALL CheckWeOverlap
	POP HL
	JR NC,CSAT_1
	LD A,&FF
	LD (ObjContact),A									;; Set ObjContact to &FF and carry on.
	JR CSAT_1

;; Finished traversing list. Check the character object.
CSAT_4:
	LD A,(Saved_Objects_List_index)						;; get Saved_Objects_List_index; Are we in the same list?
	AND A
	JR Z,CSAT_7									 		;; If not, give up.
	CALL GetCharObjIX 									;; Is the character sitting on us?
	LD A,(IX+O_Z)
	EXX
	CP C
	JR NZ,CSAT_5										;; If no, go to CSAT_5
	EXX
	CALL CheckWeOverlap
	JR NC,CSAT_7										;; Nothing on top
	JR CSAT_2											;; Thing is on top.

.GetCharObjIX:
	CALL Get_curr_Char_variables						;; HL = pointer on current selected character's variables
	PUSH HL
	POP IX
	RET

CSAT_5:
	CP B
	EXX
	JR NZ,CSAT_7										;; Nothing on top case
	LD A,(ObjContact)
	AND A
	JR NZ,CSAT_7										;; Nothing on top case.
	CALL GetCharObjIX
	CALL CheckWeOverlap
	JR NC,CSAT_7
	LD A,&FF
	JR CSAT_8

CSAT_7:
	LD A,(ObjContact)
CSAT_8:
	AND A												;; Rather than setting ObjContact, we return it?
	RET Z
	SCF
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Takes object point in IX and checks to see if we overlap with it.
;; Assumes our extents are in DE',HL'.
.CheckWeOverlap:
	CALL GetUVExt
;; Assuming X and Y extents in DE,HL and DE',HL', check two boundaries overlap.
;; Sets carry flag if they do.
.CheckOverlap:
    ;; Check E < D' and E' < D
	LD A,E
	EXX
	CP D
	LD A,E
	EXX
	RET NC
	CP D
	RET NC
	;; Check L < H' and L' < H
	LD A,L
	EXX
	CP H
	LD A,L
	EXX
	RET NC
	CP H
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Given an object in IX, returns its U and V centered extents.
;; Very like GetUVZExtents, but for UV.
;;
;; Values are based on the bottom 2 flag bits ([1:0])
;; Flag   U      V
;; 00   +3 -3  +3 -3
;; 01   +4 -4  +4 -4		DE = high,low U
;; 10   +4 -4  +1 -1		HL = high,low V
;; 11   +1 -1  +4 -4
.GetUVExt:
	LD 		A,(IX+O_FLAGS)								;; get object flags byte ; bits[2:0] : dimensions???
	BIT 	1,A											;; test bit 1
	JR 		NZ,sub_GetUV_Ext							;; if 1 goto sub_GetUV_Ext
	;; Case 0 and 1 (flags bits [1:0] = 2b'0x)
	RRA													;; get bit0 in Carry (bit1=0 case)
	LD 		A,&03
	ADC 	A,0											;; Add Carry : A = bit0 + 3
	LD 		C,A											;; store in C = bit0 + 3
	ADD 	A,(IX+O_U)									;; add object U
	LD 		D,A											;; D = U + (bit0 + 3)
	SUB 	C
	SUB 	C
	LD 		E,A											;; E = U - (bit0 + 3)
	LD 		A,C
	ADD 	A,(IX+O_V)
	LD 		H,A											;; H = V + (bit0 + 3)
	SUB 	C
	SUB 	C
	LD 		L,A											;; L = V - (bit0 + 3)
	RET

.sub_GetUV_Ext:
	RRA													;; get bit0 in Carry (bit1=1 case)
	JR 		c,sub2_GetUV_Ext							;; if bit0 = 1 jump sub2_GetUV_Ext, else bit0=0
    ;; Case 2 (flags bits [1:0] = 2b'10)
	LD 		A,(IX+O_U)
	ADD 	A,4
	LD 		D,A											;; D = U + 4
	SUB 	8
	LD 		E,A											;; E = U - 4
	LD 		L,(IX+O_V)
	LD 		H,L
	INC 	H											;; H = V + 1
	DEC		L											;; L = V -1
	RET

.sub2_GetUV_Ext:
    ;; Case 3 (flags bits [1:0] = 2b'11)
	LD 		A,(IX+O_V)
	ADD 	A,4
	LD 		H,A											;; H = V + 4
	SUB 	8
	LD 		L,A											;; L = V - 4
	LD 		E,(IX+O_U)
	LD 		D,E
	INC 	D											;; D = U + 1
	DEC 	E											;; E = U - 1
	RET

;; -----------------------------------------------------------------------------------------------------------
MENU_CURR_SEL 			EQU		&00							;; Which_selected in menu ; 0 = first
MENU_NB_ITEMS			EQU		&01							;; Number of items
MENU_INIT_COL			EQU		&02							;; Initial column
MENU_INIT_ROW			EQU		&03							;; Initial row
MENU_SEL_STRINGID		EQU		&04							;; Selected item; default: String ID STR_PLAY_THE_GAME

;; -----------------------------------------------------------------------------------------------------------
;; Menu global variables (cursor position)
MenuCursor:
	DEFW 	&0000     					;; Variable : Location of the menu cursor pointer (row,col)

;; -----------------------------------------------------------------------------------------------------------
;; Defines the sprites ID and position to be used on some of the pages:
;;	* Main Menu page (only the first two entries are used (Head and Heels)).
;;  * The Emperor proclamation page (all 4, (Head, Heels and 2 crowns) are used).
.EmperorPageSpriteList:
.MainMenuSpriteList:
	DEFB 	&1E, &60, &60		     	;; Sprite_Head_1; pos x,y &60,&60
	DEFB 	&98, &8C, &60				;; Sprite_Heels_1 | Sprite_Flipped; pos x,y
	DEFB 	&2F, &60, &48				;; Sprite_Crown; pos x,y
	DEFB 	&AF, &8C, &48				;; Sprite_Crown | Sprite_Flipped; pos x,y

;; -----------------------------------------------------------------------------------------------------------
;; This is the Main Menu
;; Return with Carry set if new game or with Carry reset for "Continue"
.Main_Screen:
	LD 		A,Print_StrID_Title_Instr					;; String ID &99 is the Wipe+Title+Instructions (press any key to....)
	CALL 	Print_String
	LD 		IX,Main_menu_data							;; IX points on first data in Main_menu_data
	LD 		(IX+MENU_CURR_SEL),0						;; Current selected item in menu : the first one
	CALL 	Blit_Head_Heels_on_menu      				;; Draw Head and Heels sprites
	CALL 	Draw_Menu
fms_1:
	CALL 	Random_gen									;; Shuffle the Random Gen
	CALL 	Step_Menu									;; Wait for a new selected menu item
	JR 		c,fms_1										;; loop until we moved to next menu item
	LD 		A,(IX+MENU_CURR_SEL)						;; get currently selected item in menu
	CP 		&01											;; Compare with 1
	JP 		c,Play_Game_menu							;; if A < 1 then go to Play_Game_menu which will RET
	JR 		NZ,fms_2									;; else if A > 1 go fms_2 (Sound or Sensitivity), else:
	CALL 	Control_menu								;; A == 1 so call Control_menu
	JR 		Main_Screen									;; loop
fms_2:
	CP 		&03											;; test current selection with the value 3
	LD 		HL,Main_Screen								;; put Main_Screen address ...
	PUSH 	HL											;; ... on stack so that the next RET in the jump below returns to Main_Screen
	JP 		Z,Sensitivity_Menu							;; if A == 3 then Sensitivity_Menu ; will RET
	JP 		Sound_Menu									;; else Sound_Menu ; will RET

;; -----------------------------------------------------------------------------------------------------------
;; This will blit Head and Heels sprites on the Main Menu page.
.Blit_Head_Heels_on_menu:
	LD 		E,&03										;; bit mask for 1st (bit0) and 2nd (bit1) in the list, in other words draw them both
	LD 		HL,MainMenuSpriteList						;; Sprite list to use (Head and Heels)
	JP 		Draw_sprites_from_list						;; call Draw_sprites_from_list (3x24); will RET

;; -----------------------------------------------------------------------------------------------------------
;; Data for the Menu "Main"
;; This is the "Play/Controls/sound/Sensitivity" menu
.Main_menu_data:
	DEFB 	0     				;; MENU_CURR_SEL : Which_selected in menu ; 0 = first
	DEFB 	4  					;; MENU_NB_ITEMS : Number of items
	DEFB 	&05    				;; MENU_INIT_COL : Initial column
	DEFB 	&89    				;; MENU_INIT_ROW : Initial row
	DEFB 	&9A					;; MENU_SEL_STRINGID : Selected item; default: String ID STR_PLAY_THE_GAME

;; -----------------------------------------------------------------------------------------------------------
;; This handle the Sound Menu
.Sound_Menu:
	LD 		A,Print_StrID_SoundMenu						;; String ID &A9 is the Sound Menu
	CALL 	Print_String
	LD 		IX,Sound_menu_data							;; IX points on Sound_menu_data
	CALL 	Draw_Menu
smstp_1:
	CALL 	Step_Menu									;; Wait for a new selected menu item
	JR 		c,smstp_1									;; if selection moved then:
	LD 		A,(Sound_menu_data)							;; get current selected menu item from Sound_menu_data
	CP 		&02											;; compare with value 2
	LD 		HL,Sound_channels_enable					;; HL points on Sound_channels_enable
	SET 	7,(HL)										;; set bit7 of the Sound volume/amount
	RET 	NZ											;; if sound menu item was not the 3rd one, then RET
	RES 	7,(HL)										;; else ("PARDON" option selected), reset bit7 of the Sound volume/amount (kills sounds)
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Data for the Menu "Sound"
.Sound_menu_data:
	DEFB	0     				;; MENU_CURR_SEL : Which_selected_in_menu ; 0 = first
	DEFB	3 	   				;; MENU_NB_ITEMS : Number of items
	DEFB	&07    				;; MENU_INIT_COL : Initial column
	DEFB	&08    				;; MENU_INIT_ROW : Initial row
	DEFB	&96					;; MENU_SEL_STRINGID : Current Selected item; default String ID STR_LOTS

;; -----------------------------------------------------------------------------------------------------------
;; Handle the Controls Menu
.Control_menu:
	LD 		A,Print_StrID_SelectKeys					;; String for Title (wipe+) "select keys"
	CALL 	Print_String
	LD 		IX,Control_menu_data						;; IX points on Control_menu_data
	CALL 	Draw_Menu
	LD 		B,8											;; 8 times (8 lines : Left,Right,Down,Up,Jump,Carry,Fire,Swop)
ctrlme_loop:
	PUSH 	BC
	LD 		A,B
	DEC 	A
	CALL 	PrepCtrlEdit								;; Edit Controls
	POP 	BC
	PUSH 	BC
	LD 		A,B
	DEC 	A
	CALL 	ListControls								;; Display list of current Controls
	POP 	BC
	DJNZ 	ctrlme_loop
cmloop:
	CALL 	Menu_step_Control_Edit
	JR 		c,cmloop									;; Wait that a control is selected
	RET 	NZ
	LD 		A,Print_StrID_ChooseNewKey					;; String ID &A8
	CALL	Print_String
	LD 		A,(IX+MENU_CURR_SEL)						;; get selected item
	ADD 	A,(IX+MENU_SEL_STRINGID)					;; update the String ID with the Base value
	CALL 	Print_String
	LD 		A,Print_ClrEOL								;; Blank end fo line
	CALL 	Print_String
	LD 		A,(IX+MENU_CURR_SEL)						;; get selected item
	CALL 	PrepCtrlEdit
	LD 		A,(IX+MENU_CURR_SEL)						;; get selected item
	CALL 	Edit_control
	LD 		A,Print_StrID_ShiftToFinish					;; String ID &A7 "PRESS SHIFT TO FINISH"
	CALL 	Print_String
	JR 		cmloop

;; -----------------------------------------------------------------------------------------------------------
;; Data for the Menu "Controls"
.Control_menu_data:
	DEFB	0     					;; MENU_CURR_SEL : Which_selected in menu ; 0 = first
	DEFB	8	    				;; MENU_NB_ITEMS : Number of items
	DEFB	&00    					;; MENU_INIT_COL : Initial column
	DEFB	&85    					;; MENU_INIT_ROW : Initial row (05|80)
	DEFB	&8E						;; MENU_SEL_STRINGID : Selected item String ID

;; -----------------------------------------------------------------------------------------------------------
;; Handle the Sensitivity Menu
.Sensitivity_Menu:
	LD 		A,Print_StrID_SensMenu						;; String ID &AA of first selected item
	CALL 	Print_String
	LD 		IX,Sensitivity_menu_data					;; IX points on Sensitivity_menu_data
	CALL 	Draw_Menu
sensmenu_1
	CALL 	Step_Menu									;; Wait for a new selected menu item
	JR 		c,sensmenu_1								;; When a new item selected do:
	LD 		A,(IX+MENU_CURR_SEL)						;; get selected menu item (0 = High, 1 = Low)
	JP 		Sub_Update_Sensitivity						;; jump Sub_Update_Sensitivity on will RET

;; -----------------------------------------------------------------------------------------------------------
;; Data for the Menu "Sensitivity"
.Sensitivity_menu_data:
	DEFB	1     					;; MENU_CURR_SEL : Which_selected in menu ; 0 = first
	DEFB	2 	   					;; MENU_NB_ITEMS : Number of items
	DEFB	&05    					;; MENU_INIT_COL : Initial column
	DEFB	&09    					;; MENU_INIT_ROW : Initial row
	DEFB	&9E						;; MENU_SEL_STRINGID : Selected item String ID

;; -----------------------------------------------------------------------------------------------------------
;; Menu "Old game/New game/Main menu"; only available if we consumed
;; a living fish in a previous game. (RET if Save_point_value = 0)
;; Output: Z reset: No saved game (go to new Game)
;;         Z set and C reset : Play Old game (saved game)
;;         Z set and C set : Play New game (even though a save exists)
.Play_Game_menu:
	LD 		A,(Save_point_value)						;; Get the "Fish" value (current Save point)
	CP 		&01											;; compare with 1
	RET 	c											;; If A=0, then we do not have an old game to reload, hence no need to display this menu, can go straight to a new game, RET Carry and NZ
	LD 		A,Print_StrID_PlayOldNew					;; else draw menu, String ID &AB is the PLAY saved point game menu
	CALL 	Print_String
	LD 		IX,Play_Game_menu_data						;; IX = pointer on Play_Game_menu_data
	LD 		(IX+MENU_CURR_SEL),0						;; set current selected item to the first
	CALL 	Draw_menu
pgmen_1:
	CALL 	Step_menu									;; Wait for a new selected menu item
	JR 		c,pgmen_1									;; when a new item has been selected:
	LD 		A,(IX+MENU_CURR_SEL)						;; get current selected item
	CP 		&02											;; If selected 3rd item, then...
	JP 		Z,Main_Screen	 							;; ...return to main menu
	RRA													;; else bit0 of (0=old or 1=new) is put in Carry, Z set.
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Data for the Menu "Play" (only shown if a previous game has been saved = "Fish")
.Play_Game_menu_data:
	DEFB	0     					;; MENU_CURR_SEL : Which_selected in menu ; 0 = first
	DEFB	3 	   					;; MENU_NB_ITEMS : Number of items
	DEFB	&09    					;; MENU_INIT_COL : Initial column
	DEFB	&09    					;; MENU_INIT_ROW : Initial row
	DEFB	&A0						;; MENU_SEL_STRINGID : Selected item ; default String ID (&A0 = "OLD GAME")

;; -----------------------------------------------------------------------------------------------------------
;; Game over Screen
;; Note on the score: After GetScore it is saved in HL as a BCD value without the
;; rightmost 0 (ie. score/10):
;;   value:    0 to  999 = Dummy, index 0 (score 0 to 9990)
;;   value: 1000 to 2999 = Novice, index 1 (score 10000 to 29990)
;;   value: 3000 to 4999 = Spy, index 2 (score 30000 to 49990)
;;   value: 5000 to 6999 = Master Spy, index 3 (score 50000 to 69990)
;;   value: 7000 to 8999 = Hero, index 4 (score 70000 to 89990)
;;   value: 9000 and above = Emperor, index 5 (score 90000 and above)
;; Independently of the score, we are Emperor if all 5 crowns have been picked up.
.Game_over_screen:
	CALL 	Play_HoH_Tune								;; Play main tune
	CALL 	Draw_wipe_and_Clear_Screen					;; do the Wipe effect to clear the screen
	LD 		A,Print_StrID_TitleBanner					;; Draw the Title
	CALL 	Print_String
	CALL 	Blit_Head_Heels_on_menu						;; Draw Head and Heels sprites
	CALL 	GetScore									;; get the score (in HL BCD value, without the last 0 (score/10))
	PUSH 	HL											;; save score on stack
	LD 		A,(saved_World_Mask)						;; get saved_World_Mask
	OR 		&E0											;; force higher bits of ~&1F
	INC 	A											;; if all 5 world are saved, this would make A=0
	LD 		A,Print_StringID_Emperor					;; prepare string STR_EMPEROR
	JR 		Z,goverscr_2								;; if Z set then all worlds saved, jump goverscr_2
	LD 		A,H											;; get high byte of score ; A = int(score / 256)
	ADD 	A,&10										;; Add 16 (ou Add BCD 10)
	JR 		NC,goverscr_1								;; if no overflow keep that new value
	LD 		A,H											;; else take back the real value
goverscr_1:
	RLCA												;; these 4 lines (with the +&10)...
	RLCA												;; ...convert the score high byte
	RLCA												;; ...to a index value 0 to 5
	AND 	&07											;; 0:Dummy, 1:Novice, 2:Spy, 3:Master, 4:Hero or 5:Emperor
	ADD 	A,Print_Array_StrID_Rank					;; Get String for the rank
goverscr_2:
	CALL 	Print_String								;; print rank, double size, rainbow mode
	LD 		A,Print_StringID_Explored					;; String "EXPLORED"
	CALL 	Print_String
	CALL 	RoomCount									;; get number of visited rooms
	CALL 	Print_4Digits_LeftAligned					;; and (value in DE) print it
	LD 		A,Print_StringID_RoomsScore					;; String "ROOMS" and "SCORE"
	CALL 	Print_String
	POP 	DE											;; get back score from stack
	CALL 	Print_4Digits_LeftAligned					;; print BCD score value in DE (in fact score/10 ; the final 0 will be hard coded in the string below)
	LD 		A,Print_StringID_Liberated					;; String "0|LIBERATED"
	CALL 	Print_String
	CALL 	SavedWorldCount								;; count number of saved worlds
	LD 		A,E											;; get number from E
	CALL 	Print_2Digits_LeftAligned					;; print value in A (left aligned)
	LD		 A,Print_StringID_Planets					;; String "PLANETS
	CALL 	Print_String
goverscr_3
	CALL 	Play_HoH_Tune								;; Play main Theme
	CALL 	Test_Enter_Shift_keys						;; wait key press : Carry=1 (no key pressed), else Carry=0
	JR 		c,goverscr_3								;; when a key was pressed:
	LD 		B,Sound_ID_Silence							;; Sound ID &C0 Silence
	JP 		Play_Sound									;; will RET

;; -----------------------------------------------------------------------------------------------------------
;; Clear out the screen area and move the cursor for editing a
;; keyboard control setting
.PrepCtrlEdit:
	ADD 	A,A
	ADD 	A,(IX+MENU_INIT_ROW)
	AND 	&7F
	LD 		B,A
	LD 		C,&0B
	PUSH 	BC
	CALL 	Set_Cursor_position
	LD 		A,Print_ClrEOL								;; blank the end of line
	CALL 	Print_String
	POP 	BC
	JP 		Set_Cursor_position 						;; will have a RET

;; -----------------------------------------------------------------------------------------------------------
.Menu_step_Control_Edit:
	CALL 	Test_Enter_Shift_keys						;; output : Carry=1 : no key pressed, else Carry=0 and C=0:Enter, C=1:Shift, C=2:other
	RET 	c
	LD 		A,C
	CP 		&01
	JR 		NZ,MenuStepCore								;; Call if the key pressed /wasn't/ Enter
	AND 	A
	RET

;; -----------------------------------------------------------------------------------------------------------
.Step_Menu:
	CALL Test_Enter_Shift_keys							;; output : Carry=1 : no key pressed, else Carry=0 and C=0:Enter, C=1:Shift, C=2:other
	RET c
	LD A,C
.MenuStepCore:
	AND A
	RET Z
	LD A,(IX+MENU_CURR_SEL)
	INC A
	CP (IX+MENU_NB_ITEMS)								;; if reached last then
	JR c,mstepc_1
	XOR A												;; loop over
mstepc_1
	LD (IX+MENU_CURR_SEL),A
	PUSH IX
	LD B,Sound_ID_Menu_Blip								;; &88 Menu blip
	CALL Play_Sound
	POP IX
.Draw_Menu:
	LD B,(IX+MENU_INIT_ROW)								;; B = row number
	RES 7,B												;; make sure bit 7 is 0
	LD C,(IX+MENU_INIT_COL)								;; C = col number
	LD (&2F16),BC										;; store current cursor position
	CALL Set_Cursor_position
	LD B,(IX+MENU_NB_ITEMS)								;; number of menu items
	LD C,(IX+MENU_CURR_SEL)								;; currently selected item
	INC C
drwmen_loop:
	LD A,&AF											;; STR_ARROW_NONSEL
	DEC C
	PUSH BC
	JR NZ,br_30EE
	BIT 7,(IX+MENU_INIT_ROW)
	JR NZ,br_30E7
	LD A,Print_DoubleSize								;; Text_double_size
	CALL Print_String
	LD A,&AE											;; Arrows for Selected item
	JR br_30EE

br_30E7
	LD A,Print_SingleSize								;; Text_single_size
	CALL Print_String
	LD A,&AE											;; Arrows for Selected item
br_30EE
	CALL Print_String
	LD A,(IX+MENU_NB_ITEMS)
	POP BC
	PUSH BC
	SUB B
	ADD A,(IX+MENU_SEL_STRINGID)						;; Currently selected item String
	CALL Print_String
	POP HL
	PUSH HL
	LD BC,(&2F16)										;; restore current cursor position
	LD A,L
	AND A
	JR NZ,br_310E
	BIT 7,(IX+MENU_INIT_ROW)
	JR NZ,br_310E
	INC B
br_310E
	INC B
	PUSH BC
	CALL Set_Cursor_position
	LD A,Print_SingleSize								;; Text_single_size
	CALL Print_String
	BIT 7,(IX+MENU_INIT_ROW)
	JR NZ,br_3123
	LD A,Print_ClrEOL									;; String ID 02 = Clear end of line
	CALL Print_String
br_3123
	POP BC
	INC B
	LD (&2F16),BC										;; next cursor position
	CALL Set_Cursor_position
	POP BC
	DJNZ drwmen_loop
	SCF
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Main Strings data
.String_Table_Main:
	DEFB 	Delimiter        							;; Delimiter (ID &80)
	DEFB 	"PLAY"										;; String "PLAY"
	DEFB 	Delimiter        							;; Delimiter (String ID &81)
	DEFB 	Print_ColorAttr, &01						;; String Attribute 2 Color_code_1
	DEFB 	Delimiter									;; Delimiter (String ID &82)
	DEFB 	Print_ColorAttr, &02      					;; String Attribute 2 Color_code_2
	DEFB 	Delimiter       							;; Delimiter (String ID &83)
	DEFB 	Print_ColorAttr, &03 						;; String Attribute 2 Color_code_3
	DEFB 	Delimiter        							;; Delimiter (ID &84)
	DEFB 	" THE "										;; String " THE "
	DEFB 	Delimiter      								;; Delimiter (ID &85)
	DEFB 	"GAME"										;; String "GAME"
	DEFB 	Delimiter       							;; Delimiter (ID &86)
	DEFB 	"SELECT"									;; String "SELECT"
	DEFB 	Delimiter      								;; Delimiter (ID &87)
	DEFB 	"KEY"										;; String "KEY"
	DEFB 	Delimiter        							;; Delimiter (ID &88)
	DEFB 	"ANY "										;; String "ANY "
	DEFB 	&87											;; Pointer on string ID &87 ("KEY")
	DEFB 	Delimiter     								;; Delimiter (ID &89)
	DEFB 	"SENSITIVITY"								;; String "SENSITIVITY"
	DEFB 	Delimiter									;; Delimiter (ID &8A)
	DEFB 	Print_Color_Attr_2							;; Macro item ID &82
	DEFB 	"PRESS "									;; String "PRESS "
	DEFB 	Delimiter									;; Delimiter (ID &8B)
	DEFB 	Print_Color_Attr_2							;; Macro item ID &82
	DEFB 	" TO "										;; String " TO "
	DEFB 	Delimiter  									;; Delimiter (ID &8C)
	DEFB 	Print_Color_Attr_3							;; Macro item ID &83
	DEFB 	&E0             							;; Pointer on string ID &E0 ("RETURN")
	DEFB 	Delimiter									;; Delimiter (ID &8D)
	DEFB 	Print_Color_Attr_3							;; Macro item ID &83
	DEFB 	"SHIFT"										;; String "SHIFT"
	DEFB 	Delimiter									;; Delimiter (ID &8E)
	DEFB 	"LEFT"										;; String "LEFT"
	DEFB 	Delimiter									;; Delimiter (ID &8F)
	DEFB 	"RIGHT"										;; String "RIGHT"
	DEFB 	Delimiter									;; Delimiter (ID &90)
	DEFB 	"DOWN"										;; String "DOWN"
	DEFB 	Delimiter									;; Delimiter (ID &91)
	DEFB 	"UP"										;; String "UP"
	DEFB 	Delimiter									;; Delimiter (ID &92)
	DEFB 	"JUMP"										;; String "JUMP"
	DEFB 	Delimiter									;; Delimiter (ID &93)
	DEFB 	"CARRY"										;; String "CARRY"
	DEFB 	Delimiter									;; Delimiter (ID &94)
	DEFB 	"FIRE"										;; String "FIRE"
	DEFB 	Delimiter									;; Delimiter (ID &95)
	DEFB 	"SWOP"										;; String "SWOP" ; Note: it is "SWOP" not "SWAP"!
	DEFB 	Delimiter									;; Delimiter (ID &96)
	DEFB 	"LOTS OF IT"								;; String "LOTS OF IT"
	DEFB 	Delimiter									;; Delimiter (ID &97)
	DEFB 	"NOT SO MUCH"								;; String "NOT SO MUCH"
	DEFB 	Delimiter									;; Delimiter (ID &98)
	DEFB 	"PARDON"									;; String "PARDON"
	DEFB 	Delimiter        							;; Delimiter (ID &99)
	DEFB 	Print_WipeScreen 							;; Screen_Wipe_Code
	DEFB 	&C5             							;; Title_Screen_Code
	DEFB 	&A3             							;; String Code "|PRESS..."
	DEFB 	Delimiter      								;; Delimiter (ID &9A)
	DEFB 	&80, &84, &85     							;; Pointer on the ID &80,&84,&85 strings ("PLAY"," THE ","GAME")
	DEFB 	Delimiter   								;; Delimiter (ID &9B)
	DEFB 	&86, &84, &87, "S"     						;; Pointer on the ID &86,&84,&87 strings ("SELECT"," THE ","KEY"+"S")
	DEFB 	Delimiter     								;; Delimiter (ID &9C)
	DEFB 	"ADJUST"									;; String "ADJUST"
	DEFB 	&84											;; Pointer on the ID &84 string (" THE ")
	DEFB 	"SOUND"										;; String "SOUND"
	DEFB 	Delimiter        							;; Delimiter (ID &9D)
	DEFB 	"CONTROL "									;; String "CONTROL "
	DEFB 	&89											;; Pointer on the ID &89 string ("SENSITIVITY")
	DEFB 	Delimiter     								;; Delimiter (ID &9E)
	DEFB 	"HIGH "										;; String "HIGH "
	DEFB 	&89											;; Pointer on the ID &89 string ("SENSITIVITY")
	DEFB 	Delimiter    								;; Delimiter (ID &9F)
	DEFB 	"LOW "										;; String "LOW "
	DEFB 	&89											;; Pointer on the ID &89 string ("SENSITIVITY")
	DEFB 	Delimiter  									;; Delimiter (ID &A0)
	DEFB 	"OLD "										;; String "OLD "
	DEFB 	&85											;; Pointer on the ID &85 string ("GAME")
	DEFB 	Delimiter   								;; Delimiter (ID &A1)
	DEFB 	"NEW "										;; String "NEW "
	DEFB 	&85											;; Pointer on the ID &85 string ("GAME")
	DEFB 	Delimiter     								;; Delimiter (ID &A2)
	DEFB 	"MAIN MENU"									;; String "MAIN MENU"
	DEFB 	Delimiter  									;; Delimiter (ID &A3)
	DEFB 	Print_SingleSize_at_pos, &02, &15			;; Macro ID &B9 Text_col Text_row
	DEFB 	&8A             							;; Pointer on the ID &8A string ("|PRESS")
	DEFB 	Print_Color_Attr_3							;; Macro ID &83 (color 3)
	DEFB 	&88, &8B          							;; Pointer on the ID &88,&8B strings ("ANY " + "KEY", " TO ")
	DEFB 	"MOVE CURSOR"								;; String "MOVE CURSOR"
	DEFB 	Print_SetPosition, &01, &17					;; Set_Text_Position Text_col Text_row
	DEFB 	" "											;; String " "
	DEFB 	&8A, &8C, &8B, &86							;; Pointer on the ID &8A,&8C,&8B,&86 strings ("|PRESS","|RETURN"," TO ","SELECT")
	DEFB 	" OPTION"									;; String " OPTION"
	DEFB 	Print_ClrEOL             					;; Clr_EOL
	DEFB 	Delimiter    								;; Delimiter (ID &A4)
	DEFB 	Print_SetPosition, &05, &03					;; Set_Text_Position Text_col Text_row
	DEFB 	&8A, &8D, &8B, &C8							;; Pointer on the ID &8A,&8D,&8B,&C8 strings ("|PRESS","|SHIFT"," TO ","FINISH")
	DEFB 	Print_ClrEOL             					;; Clr_EOL
	DEFB 	Delimiter      								;; Delimiter (ID &A5)
	DEFB 	Print_SetPosition, &05, &03					;; Set_Text_Position Text_col Text_row
	DEFB 	&8A, &8C, &8B, &C8            				;; Pointer on the ID &8A,&8C,&8B,&C8 strings ("|PRESS","|RETURN"," TO ","FINISH")
	DEFB 	Print_ClrEOL           						;; Clr_EOL
	DEFB 	Delimiter     								;; Delimiter (ID &A6)
	DEFB 	Print_Wipe_DblSize_pos, &08, &00			;; Macro ID &B0 Text_col Text_row
	DEFB 	Print_Color_Attr_1							;; Macro ID &81
	DEFB 	&9B             							;; Pointer on the ID &8C string ("SELECT THE KEYS")
	DEFB 	&A7             							;; Pointer on the ID &A7
	DEFB 	Delimiter       							;; Delimiter (ID &A7)
	DEFB 	&A3             							;; Pointer on the ID &A3
	DEFB 	Print_SetPosition, &05, &03					;; Set_Text_Position Text_col Text_row
	DEFB 	&8A             							;; Pointer on the ID &8A string ("|PRESS")
	DEFB 	Print_Color_Attr_1							;; Macro ID &81
	DEFB 	&8D, &8B              						;; Pointer on the ID &8D,&8B strings ("|SHIFT"," TO ")
	DEFB 	&C8             							;; Pointer on the ID &C8 string ("FINISH")
	DEFB 	Print_ClrEOL        						;; Clr_EOL
	DEFB 	Delimiter      								;; Delimiter (ID &A8)
	DEFB 	Print_SetPosition, &05, &03					;; Set_Text_Position Text_col Text_row
	DEFB 	Print_ClrEOL          						;; Clr_EOL
	DEFB 	Print_SetPosition, &01, &15					;; Set_Text_Position Text_col Text_row
	DEFB 	Print_ClrEOL          						;; Clr_EOL
	DEFB 	Print_SetPosition, &01, &17					;; Set_Text_Position Text_col Text_row
	DEFB 	&8A             							;; Pointer on the ID &8A string ("|PRESS")
	DEFB 	Print_Color_Attr_3							;; Macro ID &83
	DEFB 	&87, "S"             						;; Pointer on the ID &87 string ("KEY"+"S")
	DEFB 	Print_Color_Attr_2							;; Macro ID &82
	DEFB 	" REQUIRED FOR "							;; String " REQUIRED FOR "
	DEFB 	Print_Color_Attr_3							;; Macro ID &83
	DEFB 	Delimiter       							;; Delimiter (ID &A9)
	DEFB 	Print_Wipe_DblSize_pos, &08, &00			;; Pointer on item ID &B0 Text_col Text_row
	DEFB 	Print_Color_Attr_2							;; Macro ID &82
	DEFB 	&9C             							;; Pointer on the ID &9C string ("ADJUST THE SOUND")
	DEFB 	&A3             							;; Pointer on item ID &A3
	DEFB 	Print_SetPosition, &06, &03					;; Set_Text_Position Text_col Text_row
	DEFB 	Print_ColorAttr, &00             			;; Color_code Color_code_Rainbow
	DEFB 	"MUSIC BY GUY STEVENS"						;; String "MUSIC BY GUY STEVENS"
	DEFB 	Delimiter       							;; Delimiter (ID &AA)
	DEFB 	Print_Wipe_DblSize_pos, &06, &00			;; Macro ID &B0 Text_col Text_row
	DEFB 	Print_Color_Attr_2							;; Macro ID &82
	DEFB 	&9D             							;; Pointer on item ID &9D ("CONTROL SENSITIVITY")
	DEFB 	&A3             							;; Pointer on item ID &A3
	DEFB 	Delimiter       							;; Delimiter (ID &AB)
	DEFB 	Print_Wipe_DblSize_pos, &09, &00			;; Macro ID &B0 Text_col Text_row
	DEFB 	Print_Color_Attr_2							;; Macro ID &82
	DEFB 	&9A             							;; Pointer on item ID &9A ("PLAY THE GAME")
	DEFB 	&A3             							;; Pointer on item ID &A3
	DEFB 	Delimiter      								;; Delimiter (ID &AC = Paused Game message)
	DEFB 	Print_DoubleSize      						;; Text_double_size
	DEFB 	Print_Color_Attr_2							;; Macro ID &82
	DEFB 	Print_SetPosition, &03, &03					;; Set_Text_Position Text_col Text_row
	DEFB 	&8A             							;; Pointer on item ID &8A ("|PRESS")
	DEFB 	Print_Color_Attr_3							;; Macro ID &83
	DEFB 	&8D, &8B, &C8            					;; Pointer on item ID &8A,&8B,&C8 ("|SHIFT"," TO ","FINISH")
	DEFB 	" "											;; String " "
	DEFB 	&85											;; Pointer on the ID &85 string ("GAME")
	DEFB 	Print_SetPosition, &04, &06					;; Set_Text_Position Text_col Text_row
	DEFB 	&8A             							;; Pointer on item ID &8A ("|PRESS")
	DEFB 	Print_Color_Attr_3							;; Macro ID &83
	DEFB 	&88, &8B            						;; Pointer on the ID &88,&8B strings ("ANY " + "KEY"," TO ")
	DEFB 	"RESTART"									;; String "RESTART"
	DEFB 	Delimiter       							;; Delimiter (ID &AD) : Spaces
	DEFB 	"   "										;; String "   "
	DEFB 	Delimiter      								;; Delimiter (ID &AE) : Arrows for Selected item
	DEFB 	Print_Color_Attr_3							;; Macro ID &83
	DEFB 	Print_Arrow_1, Print_Arrow_2				;; Arrow1_code Arrow2_code
	DEFB 	&AD             							;; Pointer on item ID &AD String ("   ")
	DEFB 	Delimiter       							;; Delimiter (ID &AF) : Arrows for non-selected items
	DEFB 	Print_SingleSize							;; Text_single_size
	DEFB 	Print_Color_Attr_1							;; Macro ID &81
	DEFB 	Print_Arrow_3, Print_Arrow_4				;; Arrow3_code Arrow4_code
	DEFB 	&AD             							;; Pointer on item ID &AD String ("   ")
	DEFB 	Delimiter       							;; Delimiter (ID &B0) ; needs to be followed by the 2 bytes argument of the &06 macro at the end
	DEFB 	Print_WipeScreen							;; Screen_Wipe_Code
	DEFB 	Print_ColorScheme, &09            			;; Select color scheme nb 09
	DEFB 	Print_DoubleSize 							;; Text_double_size
	DEFB 	Print_SetPosition							;; Set_Text_Position (&B0 will need to be followed by the 2 argument bytes for Text_col Text_row)
	DEFB 	Delimiter     								;; Delimiter (ID &B1)
	DEFB 	Print_SingleSize_at_pos, &05, &14			;; Macro ID &B9 Text_col Text_row
	DEFB 	Delimiter       							;; Delimiter (ID &B2)
	DEFB 	Print_SingleSize_at_pos, &19, &14			;; Macro ID &B9 Text_col Text_row
	DEFB 	Delimiter     								;; Delimiter (ID &B3)
	DEFB 	Print_SingleSize_at_pos, &19, &17			;; Macro ID &B9 Text_col Text_row
	DEFB 	Delimiter       							;; Delimiter (ID &B4)
	DEFB 	Print_SingleSize_at_pos, &05, &17			;; Macro ID &B9 Text_col Text_row
	DEFB 	Delimiter        							;; Delimiter (ID &B5)
	DEFB 	Print_DoubleSize 							;; Text_double_size
	DEFB 	Print_SetPosition, &12, &16					;; Set_Text_Position Text_col Text_row
	DEFB 	Delimiter        							;; Delimiter (ID &B6)
	DEFB 	Print_DoubleSize 							;; Text_double_size
	DEFB 	Print_SetPosition, &0C, &16					;; Set_Text_Position Text_col Text_row
	DEFB 	Delimiter        							;; Delimiter (ID &B7)
	DEFB 	Print_SingleSize_at_pos, &01, &11			;; Macro ID &B9 Text_col Text_row
	DEFB 	Delimiter     								;; Delimiter (ID &B8)
	DEFB 	Print_SingleSize							;; Text_single_size
	DEFB 	Print_Color_Attr_2							;; Macro ID &82 (color 2)
	DEFB 	Print_SetPosition, &1A, &13					;; Set_Text_Position Text_col Text_row
	DEFB 	Print_Icon_Spring							;; Item_Spring_code
	DEFB 	Print_SetPosition, &1A, &16					;; Set_Text_Position Text_col Text_row
	DEFB 	Print_Color_Attr_2							;; Macro ID &82 (color 2)
	DEFB 	Print_Icon_Sheild							;; Item_Shield_code
	DEFB 	Print_SetPosition, &06, &13					;; Set_Text_Position Text_col Text_row
	DEFB 	Print_Color_Attr_2							;; Macro ID &82 (color 2)
	DEFB 	Print_Icon_Speed							;; Item_LightningSpeed_code
	DEFB 	Print_SetPosition, &06, &16					;; Set_Text_Position Text_col Text_row
	DEFB 	Print_Color_Attr_2							;; Macro ID &82 (color 2)
	DEFB 	Print_Icon_Sheild							;; Item_Shield_code
	DEFB 	Delimiter      								;; Delimiter (ID &B9) ; needs to be followed by the 2 bytes argument of the &06 macro at the end
	DEFB 	Print_SingleSize							;; Text_single_size
	DEFB 	Print_SetPosition							;; Set_Text_Position (&B9 will need to be followed by the 2 argument bytes for Text_col Text_row)
	DEFB 	Delimiter      								;; Delimiter (ID &BA)
	DEFB 	&C5             							;; Pointer on item ID &C5 : Title_Screen_Code
	DEFB 	Print_SetPosition, &0A, &08					;; Set_Text_Position Text_col Text_row
	DEFB 	Print_Color_Attr_2							;; Macro ID &82
	DEFB 	Print_DoubleSize             				;; Text_double_size
	DEFB 	Print_ColorAttr, &00						;; Color_code Color_Rainbow
	DEFB 	Delimiter   								;; Delimiter (ID &BB)
	DEFB 	Print_SingleSize_at_pos, &06, &11			;; Macro ID &B9 Text_col Text_row
	DEFB 	Print_Color_Attr_1							;; Macro ID &81
	DEFB 	"EXPLORED "									;; String "EXPLORED "
	DEFB 	Delimiter     								;; Delimiter (ID &BC)
	DEFB 	" ROOMS"             						;; String " ROOMS"
	DEFB 	Print_SetPosition, &09, &0E					;; Set_Text_Position Text_col Text_row
	DEFB 	Print_Color_Attr_2							;; Macro ID &82
	DEFB 	"SCORE "									;; String "SCORE "
	DEFB 	Delimiter       							;; Delimiter (ID &BD)
	DEFB 	"0"											;; String "0"
	DEFB 	Print_SetPosition, &05, &14					;; Set_Text_Position Text_col Text_row
	DEFB 	Print_Color_Attr_3							;; Macro ID &83
	DEFB 	"LIBERATED "								;; String "LIBERATED "
	DEFB 	Delimiter        							;; Delimiter (ID &BE)
	DEFB 	" PLANETS"             						;; String " PLANETS"
	DEFB 	Delimiter        							;; Delimiter (ID &BF)
	DEFB 	"  DUMMY"             						;; String "  DUMMY"
	DEFB 	Delimiter         							;; Delimiter (ID &C0)
	DEFB 	"  NOVICE"             						;; String "  NOVICE"
	DEFB 	Delimiter       							;; Delimiter (ID &C1)
	DEFB 	"   SPY    "								;; String "   SPY    "
	DEFB 	Delimiter      								;; Delimiter (ID &C2)
	DEFB 	"MASTER SPY"								;; String "MASTER SPY"
	DEFB 	Delimiter       							;; Delimiter (ID &C3)
	DEFB 	"   HERO"             						;; String "   HERO"
	DEFB 	Delimiter      								;; Delimiter (ID &C4)
	DEFB 	" EMPEROR"             						;; String " EMPEROR"
	DEFB 	Delimiter      								;; Delimiter (ID &C5)
	DEFB 	Print_ColorScheme, &0A						;; Select color scheme nb 0A
	DEFB 	Print_DoubleSize          					;; Text_double_size
	DEFB 	Print_SetPosition, &08, &00					;; Set_Text_Position Text_col Text_row
	DEFB 	Print_Color_Attr_2							;; Macro ID &82
	DEFB 	"HEAD      "								;; String "HEAD      "
	DEFB 	"HEELS"										;; String "HEELS"
	DEFB 	Print_SingleSize_at_pos, &0C, &01			;; Macro ID &B9 Text_col Text_row
	DEFB 	Print_ColorAttr, &00						;; Color_attr_code Color_rainbow
	DEFB 	" OVER "            						;; String " OVER "
	DEFB 	Print_SetPosition, &01, &00					;; Set_Text_Position Text_col Text_row
	DEFB 	" JON"       								;; String " JON"
	DEFB 	Print_SetPosition, &01, &02					;; Set_Text_Position Text_col Text_row
	DEFB 	"RITMAN"             						;; String "RITMAN"
	DEFB 	Print_SetPosition, &19, &00					;; Set_Text_Position Text_col Text_row
	DEFB 	"BERNIE"	         						;; String "BERNIE"
	DEFB 	Print_SetPosition, &18, &02					;; Set_Text_Position Text_col Text_row
	DEFB 	"DRUMMOND"		             				;; String "DRUMMOND"
	DEFB 	Delimiter    								;; Delimiter (ID &C6)
	DEFB 	Print_WipeScreen  			    			;; Screen_Wipe_Code
	DEFB 	Print_ColorScheme, &06						;; Select color scheme nb 06
	DEFB 	Print_SetPosition, &05, &00					;; Set_Text_Position Text_col Text_row
	DEFB 	Print_DoubleSize             				;; Text_double_size
	DEFB 	Print_Color_Attr_3							;; Macro ID &83
	DEFB 	&84											;; Pointer on item ID &84 : String " THE "
	DEFB 	&C7             							;; Pointer on item ID &C7 : String "BLACKTOOTH"
	DEFB 	" EMPIRE"									;; String " EMPIRE"
	DEFB 	Print_SingleSize							;; Text_single_size
	DEFB 	Print_SetPosition, &03, &09					;; Set_Text_Position Text_col Text_row
	DEFB 	Print_Color_Attr_1							;; Macro ID &81
	DEFB 	"EGYPTUS"     								;; String "EGYPTUS"
	DEFB 	Print_SetPosition, &15, &17					;; Set_Text_Position Text_col Text_row
	DEFB 	"BOOK WORLD"								;; String "BOOK WORLD"
	DEFB 	Print_SetPosition, &03, &17					;; Set_Text_Position Text_col Text_row
	DEFB 	"SAFARI"             						;; String "SAFARI"
	DEFB 	Print_SetPosition, &14,	&09					;; Set_Text_Position Text_col Text_row
	DEFB 	"PENITENTIARY"								;; String "PENITENTIARY"
	DEFB 	Print_SetPosition, &0B, &10					;; Set_Text_Position Text_col Text_row
	DEFB 	&C7             							;; Pointer on item ID &C7 : String "BLACKTOOTH"
	DEFB 	Delimiter     								;; Delimiter (ID &C7)
	DEFB 	"BLACKTOOTH"								;; String "BLACKTOOTH"
	DEFB 	Delimiter     								;; Delimiter (ID &C8)
	DEFB 	"FINISH"             						;; String "FINISH"
	DEFB 	Delimiter       							;; Delimiter (ID &C9)
	DEFB 	&B6											;; Pointer on item ID &B6
	DEFB 	Print_ColorAttr, &00						;; Color_attr_code Color_Rainbow
	DEFB 	"FREEDOM "									;; String "FREEDOM "
	DEFB 	Delimiter    								;; Delimiter (ID &CA)
	DEFB 	Print_WipeScreen        					;; Screen_Wipe_Code
	DEFB 	Print_ColorScheme, &06						;; Select color scheme nb 06
	DEFB 	Print_SingleSize_at_pos, &00, &0A			;; Macro ID &B9 Text_col Text_row
	DEFB 	Print_Color_Attr_2							;; Macro ID &82
	DEFB 	&84											;; Pointer on item ID &84 : String " THE "
	DEFB 	"PEOPLE SALUTE YOUR HEROISM"      			;; String "PEOPLE SALUTE YOUR HEROISM"
	DEFB 	Print_SetPosition, &08, &0C					;; Set_Text_Position Text_col Text_row
	DEFB 	"AND PROCLAIM YOU"							;; String "AND PROCLAIM YOU"
	DEFB 	Print_DoubleSize   							;; Text_double_size
	DEFB 	Print_SetPosition, &0B, &10					;; Set_Text_Position Text_col Text_row
	DEFB 	Print_ColorAttr, &00						;; Color_attr_code Color_Rainbow
	DEFB 	Print_StringID_Emperor						;; Pointer on item ID &C4 : String " EMPEROR"
	DEFB 	Delimiter       							;; Delimiter (ID &CB)

;; -----------------------------------------------------------------------------------------------------------
;; Swap RoomId with the room at the other end of the teleport.
.Teleport_swap_room:
	LD 		BC,(current_Room_ID)  						;; get current_Room_ID in BC
	LD 		HL,Teleport_data							;; HL points on Teleport_data
	CALL 	Scan_teleport_pairs							;; Scan_teleport_pairs, DE will have the destination room ID
	LD 		(current_Room_ID),DE						;; update current_Room_ID with teleport destination room ID
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Scans array from HL, looking for BC, scanning in pairs. If the
;; first is equal, it returns the second in DE. If the second is equal,
;; it returns the first.
.Scan_teleport_pairs:
    ;; match current room with teleport_data "left" room,
	;; return "right" room if match
	CALL 	get_teleport_pair_in_DE						;; compare_teleport "left" room
	JR 		Z,get_teleport_pair_in_DE					;; if match, get_teleport_pair_in_DE, will RET, else (no match):
	;; match current room with teleport_data "right" room,
	;; return "left" room if match
	PUSH 	DE											;; store current scanned room
	CALL 	get_teleport_pair_in_DE						;; compare_teleport
	POP 	DE											;; restore previous scanned room
	;; still no match continue searching, else DE has the destination
	JR 		NZ,Scan_teleport_pairs						;; loop Scan_teleport_pairs if no match else found!
	RET													;; DE has the destination room

;; Loads (HL) into DE, incrementing HL.
;; Compares BC with DE, sets Z if equal.
get_teleport_pair_in_DE:													;; look for the BC room ID in the Teleport_data table at HL
	LD 		A,C
	LD 		E,(HL)
	INC 	HL											;; next databyte
	LD 		D,(HL)										;; DE has the scanned room ID in the table
	INC 	HL											;; next databyte
	CP 		E											;; E = C?
	RET 	NZ											;; if lowbyte not what we are looking for Z=0 and exit (no need to go further)
	LD 		A,B											;; D = B?
	CP 		D											;; else compare highbyte
	RET													;; Z=1 if match, DE=destination-room, Z=0 if no match

;; -----------------------------------------------------------------------------------------------------------
;; TELEPORT pairs
;; The room ID is [grid on 8 axis][grid on V axis][grid in Z (increase going down)]
;; for exemple Head and Heels inital rooms are respectively 8,A,8 and 8,9,8 (these rooms are next to each other)
Teleport_data:
	DEFW 	RoomID_Head_1st, &7150		;; Room ID 8A40 end up at Room ID 7150 : Head's first room (prison) to first escape room (both way)
	DEFW 	RoomID_Heels_1st, &0480		;; Room ID 8940 end up at Room ID 0480 : Heels' first room (prison) to first escape room (both way)
	DEFW 	&BA70, &1300 				;; Room ID BA70 end up at Room ID 1300 : Market to Moonbase () and then Moonbase to Moonbase Upper ???
	DEFW 	&4100, &2980 				;; Room ID 4100 end up at Room ID 2980 : Blacktooth to Moonbase (2 in one room) (heels only) (both way)
	DEFW 	&A100, &2600 				;; Room ID A100 end up at Room ID 2600 : Moonbase to Moonbase Main (both way)
	DEFW 	&8100, &E980 				;; Room ID 8100 end up at Room ID E980 : Blacktooth to Moonbase (head only) (both way)
	DEFW 	&8400, &B100 				;; Room ID 8400 end up at Room ID B100 : Moonbase Main to Penitentiary (both way)
	DEFW 	&8500, &EF20 				;; Room ID 8500 end up at Room ID EF20 : Moonbase Main to Bookworld (both way)
	DEFW 	&A400, &00F0 				;; Room ID A400 end up at Room ID 00F0 : Moonbase Main to Safari (both way)
	DEFW 	&A500, &88D0 				;; Room ID A500 end up at Room ID 88D0 : Moonbase Main to Egyptus (both way)
	DEFW 	&BCD0, &DED0 				;; Room ID BCD0 end up at Room ID DED0 : Egyptus mid to Egyptus early
	DEFW 	&2DB0, &8BD0 				;; Room ID 2DB0 end up at Room ID 8BD0 : Egyptus just before crown to Egyptus beginning
	DEFW 	&1190, &E1C0 				;; Room ID 1190 end up at Room ID E1C0 : Penitentiary Crown room () to Penitentiary mid1
	DEFW 	&00B0, &E2C0 				;; Room ID 00B0 end up at Room ID E2C0 : Penitentiary Far in () to Penitentiary mid2
	DEFW 	&10B0, &C100 				;; Room ID 10B0 end up at Room ID C100 : Penitentiary just before crown to Begining Penitentiary
	DEFW 	&8BF0, &00F0 				;; Room ID 8BF0 end up at Room ID 00F0 : Safari (Egyptus???) Far room to Safari begining
	DEFW 	&9730, &EF20 				;; Room ID 9730 end up at Room ID EF20 : Bookworld just before crown to Bookworld beginning
	DEFW 	&1D00, &A800 				;; Room ID 1D00 end up at Room ID A800 : Moonbase Main to Moonbase Upper (both way)
	DEFW 	&BA70, &4E00 				;; Room ID BA70 end up at Room ID 4E00 : Moonbase Upper to Market (both way)
	DEFW 	&8800, &1B30 				;; Room ID 8800 end up at Room ID 1B30 : Moonbase Main to Castle (both way)
	DEFW 	&4C00, &3930 				;; Room ID 4C00 end up at Room ID 3930 : Moonbase Upper to Castle (both way)
	DEFW 	&8B30, RoomID_Victory		;; Room ID 8B30 end up at Room ID 8D30 : Castle to Freedom (Victory room! 8D30 game over)

;; -----------------------------------------------------------------------------------------------------------
;; Takes sprite codes in HL and a height in A, and applies truncation
;; of the third column A * 2 + from the top of the column. This
;; performs removal of the bits of the door hidden by the walls.
;; If the door is raised, more of the frame is visible, so A is
;; the height of the door.
.OccludeDoorway:
    ;; Copy the sprite (and mask) indexed by L to DoorwayBuf
	PUSH AF
	LD A,L
	LD H,0
	LD (Sprite_Code),A									;; update sprite code
	CALL Sprite3x56
	EX DE,HL
	LD DE,DoorwayBuf + MOVE_OFFSET
	PUSH DE
	LD BC,&0150											;; 56 * 3 * 2
	LDIR												;; repeat LD (DE),(HL); DE++, HL++, BC-- until BC=0
	POP HL
	POP AF
	;; A = Min(A * 2 + 8, 0x38)
	ADD A,A
	ADD A,8
	CP &39
	JR c,occdw_1
	LD A,&38
	;; A *= 3
occdw_1:
	LD B,A
	ADD A,A
	ADD A,B
	;; DE = Top of sprite + A
    ;; HL = Top of mask + A
	LD E,A
	LD D,0
	ADD HL,DE
	EX DE,HL
	LD HL,&00A8											;; 56 * 3
	ADD HL,DE
	LD A,B
	NEG
	ADD A,&39
	LD B,A												;; B = &39 - A
	LD C,&FC											;; C = ~&03
	JR occdw_2

	;; This loop then cuts off a wedge from the right-hand side,
    ;; presumably to give a nice trunction of the image?
occdw_3:
	LD A,(DE)
	AND C
	LD (DE),A
	INC DE
	INC DE
	INC DE
	LD A,C
	CPL
	OR (HL)
	LD (HL),A
	INC HL
	INC HL
	INC HL
	AND A
	RL C
	AND A
	RL C
occdw_2:
	DJNZ occdw_3
	;; Clear the flipped flag for this copy.
	XOR A
	LD (DoorwayFlipped),A
	RET

;; -----------------------------------------------------------------------------------------------------------
.Sprite_Width:
	DEFB 	4								;; width of sprite in bytes

.Sprite_Code:
	DEFB	&00             				;; Variable for sprite code

;; -----------------------------------------------------------------------------------------------------------
;; This will init another table in 6900-69FF used as a look-up table
;; for byte reverses (RevTable).
;; The final table is:
;;  6900 : 00 80 40 C0 20 A0 60 E0 10 90 50 D0 30 B0 70 F0
;;  6910 : 08 88 48 C8    ....                       78 F8
;;  6920 : 04 84 44 C4    ....                       74 F4
;;  ...    ...            ....                       ...
;;  69E0 : 07 87 47 C7    ....                       77 F7
;;  69F0 : 0F 8F 4F CF 2F AF 6F EF 1F 9F 5F DF 3F BF 7F FF
.Init_table_rev:
	LD 		HL,RevTable									;; RevTable addr
table2_next_idx:
	LD 		C,L											;; C = current table index (L = 0 to 255)
	LD 		A,1											;; A=1
	AND 	A											;; Clear Carry
table2_decomp:
	RRA													;; bit shifting between A...
	RL 		C											;; ...and C (via Carry)
	JR 		NZ,table2_decomp							;; C not 0, loop
	LD 		(HL),A										;; else write resulting A in current HL
	INC 	L											;; next HL
	JR 		NZ,table2_next_idx							;; loop until L goes back to 0
	RET

;; -----------------------------------------------------------------------------------------------------------
;; For a given sprite code, generates the X and Y extents, and sets
;; the current sprite code and sprite width.
;;
;; Parameters: Sprite code is passed in in A.
;;             X coordinate in C, Y coordinate in B
;; Returns: X extent in BC, Y extent in HL
.GetSprExtents:
	LD (Sprite_Code),A									;; update sprite code
	AND &7F
	CP &10
	JR c,Case3x56										;; Codes < &10 are 3x56 so go Case3x56, else:
	LD DE,&0606											;; 3x24 or 3x32 (3x32 will be modified)
	LD H,&12
	CP &54
	JR c,gsext_1
	LD DE,&0808					 						;; Codes >= &54 are 4x28
	LD H,&14
gsext_1:
	CP &18
	JR NC,SSW_2
	LD A,(SpriteFlags)
	AND &02												;; bit1 of stored SPRFLAGS
	LD D,&04
	LD H,&0C
	JR Z,SSW_2
	LD D,&00
	LD H,&10
    ;; All cases but 3x56 join up here:
    ;; D is Y extent down, H is Y extent up
    ;; E is half-width (in double-pixels)
    ;;
    ;; 4x28: D = 8, E = 8, H = 20
    ;; 3x24: D = 6, E = 6, H = 18
    ;; 3x32: D = 0, E = 6, H = 16 if flags & 2
    ;; 3x32: D = 4, E = 6, H = 12 otherwise
    ;;
    ;; The 3x32 case is split into 2 parts of height 16 each.
SSW_2:
	LD A,B
	ADD A,D
	LD L,A
	SUB D
	SUB H
	LD H,A
	LD A,C
	ADD A,E
	LD C,A
	SUB E
	SUB E
	LD B,A						 						;; B = C - 2*E
	LD A,E
	AND A
	RRA													;; And save width in bytes to SpriteWidth
	LD (Sprite_Width),A									;; update Sprite_Width
	RET

;; -----------------------------------------------------------------------------------------------------------
.Case3x56:
    ;; Horrible hack to get the current object - we're usually
    ;; called via Blit_Objects, which sets this.
    ;;
    ;; However, IntersectObj is also called via AddObject, so err...
    ;; either something clever's going on, or the extents can be
    ;; slightly wrong in the AddObject case for doors.
    ;;
    ;; TODO: Tie these into the object definitions and flags
	LD HL,(smc_CurrObject2+1)
	INC HL
	INC HL
	BIT 5,(HL)											;; Bit 5 = is LHS door
	EX AF,AF'
	LD A,(HL)
	SUB &10												;; NC for < 9 or > 30 - ie near doors
	CP &20
	LD L,&04
	JR NC,br_359A
	LD L,&08
br_359A
	LD A,B					 							;; L = (Flag - &10) >= &20 ? 8 : 4
	ADD A,L
	LD L,A
	SUB &38
	LD H,A
	EX AF,AF'
	LD A,C
	LD B,&08
	JR NZ,br_35A8
	LD B,&04
br_35A8
	;; Use 8 for left doors, 4 for right.
	ADD A,B												;; B = (Flag & 0x20) ? 8 : 4
	LD C,A
	SUB &0C
	LD B,A
	LD A,&03											;; Always 3 bytes wide.
	LD (Sprite_Width),A									;; update Sprite_Width
	RET

;; -----------------------------------------------------------------------------------------------------------
SPR_first_4x28_sprite	EQU		SPR_DOORSTEP		;; &54
SPR_first_3x24_sprite	EQU		SPR_HEELS1			;; &18
SPR_first_3x32_sprite	EQU		SPR_VISOROHALF		;; &10

;; -----------------------------------------------------------------------------------------------------------
;; Looks up based on SpriteCode. Top bit set means flip horizontally.
;; Return height in B, image in DE, mask in HL.
.Load_sprite_image_address_into_DE:
	LD A,(Sprite_Code)									;; get sprite code
	AND &7F												;; Top bit holds 'reverse?'. Ignore.
	CP SPR_first_4x28_sprite							;; >= 0x54 -> 4x28 (&54 is the SPR_DOORSTEP, the first of the 4x28 sprites)
	JP NC,Sprite4x28
	CP SPR_first_3x24_sprite							;; >= 0x18 -> 3x24 (&18 is the SPR_HEELS1, the first of the 3x24 sprites)
	JR NC,Sprite3x24
	CP SPR_first_3x32_sprite							;; >= 0x10 -> 3x32
	LD H,&00
	JR NC,Sprite3x32
	LD L,A
	LD DE,(smc_CurrObject2+1)
	INC DE
	INC DE
	;; Normal case if the object's flag & 3 != 3
	LD A,(DE)
	OR &FC												;; ~&03
	INC A
	JR NZ,Sprite3x56
	;; flag & 3 == 3 case:
	LD A,(Sprite_Code)									;; get sprite code
	LD C,A
	RLA
	LD A,(RoomDimensionsIdx)
	JR c,br_35E2										;; Flip bit set?
	CP &06												;; Narrow-in-U-direction room?
	JR br_35E4

br_35E2
	CP &03												;; Narrow-in-V-direction room?
br_35E4
	JR Z,Sprite3x56
	;; Use DoorwayBuf.
	LD A,(DoorwayFlipped)
	XOR C
	RLA
	LD DE,DoorwayImgBuf + MOVE_OFFSET
	LD HL,DoorwayMaskBuf + MOVE_OFFSET					;; DoorwayMaskBuf : DoorwayBuf + 56 * 3
	RET NC
	;; And flip it if necessary.
	LD A,C
	LD (DoorwayFlipped),A
	LD B,&70											;; 56*2
	JR FlipSprite3

;; Deal with a 3 byte x sprite 56 pixels high.
;; Same parameters/return as Load_sprite_image_address_into_DE.
.Sprite3x56:
	LD A,L
	LD E,A												;; *1
	ADD A,A												;; *2
	ADD A,A												;; *4
	ADD A,E												;; *5
	ADD A,A												;; *10
	LD L,A
	ADD HL,HL											;; *20
	ADD HL,HL											;; *40
	ADD HL,HL											;; 80x
	LD A,E												;; *1
	ADD A,H												;; *256
	LD H,A												;; finally 336x = 3x56x2x
	LD DE,&8270											;; IMG_3x56
	ADD HL,DE
	LD DE,&00A8											;; 56*3 ; Point to mask
	LD B,&70											;; 56*2 ; Height of image + height of mask
	JR Sprite3Wide

;; Deal with a 3 byte x 32 pixel high sprite.
;; Same parameters/return as Load_sprite_image_address_into_DE.
;;
;; Returns a half-height offset sprite if bit 2 is not set, since the
;; 3x32 sprites are broken into 2 16-bit-high chunks.
.Sprite3x32:
	SUB &10
	LD L,A
	ADD A,A
	ADD A,L
	LD L,A
	ADD HL,HL
	ADD HL,HL
	ADD HL,HL
	ADD HL,HL
	ADD HL,HL
	ADD HL,HL											;; 3x32x2x
	LD DE,&8A50											;; IMG_3x32
	ADD HL,DE
	LD DE,&0060											;; 32*3 : number of bytes in image
	LD B,&40											;; 32*2 : height image + height mask
	EX DE,HL
	ADD HL,DE
	EXX
	CALL NeedsFlip
	EXX
	CALL NC,FlipSprite3
	;; If bit 2 is not set, move half a sprite down.
	LD A,(SpriteFlags)
	AND &02
	RET NZ
	LD BC,&0030
	ADD HL,BC
	EX DE,HL
	ADD HL,BC
	EX DE,HL
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Deal with a 3 byte x 24 pixel high sprite
;; Same parameters/return as Load_sprite_image_address_into_DE.
;; Return : height image+mask in B, image in DE, mask in HL.
.Sprite3x24:
	SUB SPR_first_3x24_sprite							;; Sprite code was >= &18, realign number at &00 for 1st sprite (SPR_HEELS1) and so on
	LD D,A												;; A = D = sprite number in img_3x24 table
	LD E,&00											;; DE = sprite number * 256
	LD H,E												;; init H = E = 0
	ADD A,A												;; *2
	ADD A,A												;; *4
	LD L,A												;; L=A
	ADD HL,HL											;; *8
	ADD HL,HL											;; HL = sprite number x16
	SRL D												;; Carry=Dbit0 ; int(D/2);
	RR E												;; Ebit7=Carry; these 2 lines do a DE/2, DE= sprite number * 128
	ADD HL,DE											;; HL = sprite number * 144 ; 144x = 2x3x24
	LD DE,&8BD0											;; IMG_3x24 base addr
	ADD HL,DE											;; from base addr, add the offset of the sprite we want
	LD DE,&0048											;; &48=72=24*3 (offset for mask = number of bytes in image)
	LD B,&30											;; &30=48=24*2 (height image + height mask)
.Sprite3Wide:
	EX DE,HL											;; HL = offset mask, DE = img addr
	ADD HL,DE											;; HL = mask addr
	EXX													;; DE = mask addr, HL = img addr, save BC
	CALL NeedsFlip
	EXX													;; HL = mask addr, DE = img addr, restore B=height*2
	RET c												;; if Carry set, no need to flip, else flip
;; Flip a 3-character-wide sprite. Height in B, source in DE.
.FlipSprite3:
	PUSH HL
	PUSH DE
	EX DE,HL
	LD D,RevTable / 256									;; &69 = RevTable >> 8
fspr3_loop:
	LD C,(HL)
	LD (smc_flipsprite3+1),HL							;; Self-modifying code! will put the value in the "LD (???),A"
	INC HL
	LD E,(HL)
	LD A,(DE)
	LD (HL),A
	INC HL
	LD E,(HL)
	LD A,(DE)
smc_flipsprite3:
	LD (&0000),A										;; Target of self-modifying code. value is set at &3666
	;;3671 DEFW 00 00
	LD E,C
	LD A,(DE)
	LD (HL),A
	INC HL
	DJNZ fspr3_loop
	POP DE
	POP HL
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Looks up a 4x28 sprite.
;; Same parameters/return as Load_sprite_image_address_into_DE.
.Sprite4x28:
	SUB SPR_first_4x28_sprite							;; SPR_DOORSTEP ID &54 becomes id 0 and so on
	LD D,A
	RLCA
	RLCA
	LD H,&00
	LD L,A
	LD E,H
	ADD HL,HL
	ADD HL,HL
	ADD HL,HL
	EX DE,HL
	SBC HL,DE											;; 224x = 4x28x2x
	LD DE,&AA30											;; IMG_4x28
	ADD HL,DE
	LD DE,&0070											;; 28*4 = number of bytes in image
	LD B,&38											;; 28*2 = height of image + height of mask
	EX DE,HL
	ADD HL,DE
	EXX
	CALL NeedsFlip
	EXX
	RET c
;; Flip a 4-character-wide sprite. Height in B, source in DE.
flipSprite4:
	PUSH HL
	PUSH DE
	EX DE,HL
	LD D,RevTable / 256									;; &69 = RevTable >> 8
fspr4_loop:
	LD C,(HL)
	LD (smc_fs_addr+1),HL								;; Self-modifying code at 3683
	INC HL
	LD E,(HL)
	INC HL
	LD A,(DE)
	LD E,(HL)
	LD (HL),A
	DEC HL
	LD A,(DE)
	LD (HL),A
	INC HL
	INC HL
	LD E,(HL)
	LD A,(DE)
smc_fs_addr:
	LD (&0000),A										;; Target of self-modifying code
	;;3683 DEFW 00 00														; modified at addr 36A2
	LD E,C
	LD A,(DE)
	LD (HL),A
	INC HL
	DJNZ fspr4_loop
	POP DE
	POP HL
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Look up the sprite in the bitmap, returns with C set if the top bit of
;; SpriteCode matches the bitmap, otherwise updates the bitmap (assumes
;; that the caller will flip the sprite if we return NC). In effect, a
;; simple cache.
.NeedsFlip:
	LD A,(Sprite_Code)									;; get sprite code
	LD C,A
	AND &07
	INC A
	LD B,A
	LD A,&01
ndflp_1:
	RRCA												;; right shift B times
	DJNZ ndflp_1
	LD B,A												;; B now contains bitmask from low 3 bits of SpriteCode
	LD A,C
	RRA
	RRA
	RRA
	AND &0F
	LD E,A
	LD D,0
	LD HL,SpriteFlips_buffer + MOVE_OFFSET				;; buffer 16 bytes to flip sprite
	ADD HL,DE
	LD A,B
	AND (HL)											;; Perform bit-mask look-up
	JR Z,SubNeedsFlip									;; Bit set?
	RL C												;; Bit was non-zero
	RET c
	LD A,B
	CPL
	AND (HL)
	LD (HL),A											;; If top bit of SpriteCode wasn't set, reset bit mask
	RET

.SubNeedsFlip:
	RL C												;; Bit was zero
	CCF
	RET c
	LD A,B
	OR (HL)
	LD (HL),A											;; If top bit of SpriteCode was set, set bit mask
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Are the contents of DoorwayBuf flipped?
.DoorwayFlipped:
	DEFB 	&00

;; -----------------------------------------------------------------------------------------------------------
.CurrObject:
	DEFW	&230B
.ObjDir:
	DEFB 	&FF

;; The sprite used in the bottom half of a double-height sprite.
.BottomSprite:
	DEFB 	&00
;; In the ObjDefns, if the 2nd byte ("function") bits [7:6] are not 0, then the object
;; has another object attached to it ("double height" object).
.Bottoms_array:
	DEFB	SPR_TAP						;; top 2 bits of ObjDefns "function" byte (2nd byte) = 2b'01
	DEFB	ANIM_VAPE3					;; top 2 bits of ObjDefns "function" byte (2nd byte) = 2b'10
	DEFB	SPR_TAP						;; top 2 bits of ObjDefns "function" byte (2nd byte) = 2b'11

;; -----------------------------------------------------------------------------------------------------------
;; Takes an object pointer in IY, an object code in A, and initialises it.
;; Doesn't set flags, direction code, or coordinates.
;; Must then call AddObject to copy it into the room.
.InitObj:
	LD 		(IY+O_SPRFLAGS),&00							;; reset Sprite flags
	;; Look up A in the ObjDefns table.
	LD 		L,A
	LD 		E,A
	LD 		D,0											;; DE = object code
	LD 		H,D											;; HL=DE=object id code
	ADD 	HL,HL										;; *2
	ADD 	HL,DE										;; *3 : HL = offset = 3 * object id
	LD 		DE,ObjDefns									;; DE = pointer on Object definition Table (ObjDefns: 3 bytes per entry : <sprite-code> <function> <flag>)
	ADD		HL,DE										;; HL = pointer on ObjDefns + (objectid * 3)
	LD 		B,(HL)										;; get sprite code in B
	INC 	HL											;; next byte
	LD 		A,(HL)										;; A = double height flag + object function
	AND 	&3F											;; keep object function (in bits[5:0])
	LD 		(IY+O_FUNC),A
	LD 		A,(HL)										;; get 2nd byte again
	INC 	HL											;; prepare for next byte (flags)
	RLCA
	RLCA												;; rotate "left" to get 2 upper bits (double height code) in [1:0]
	AND 	&03											;; get them and only them
	JR 		Z,initobj_1									;; if they are 0 (normal height), skip to initobj_1, else:
Bottoms_array_m1		EQU		Bottoms_array - 1
	ADD		A,Bottoms_array_m1 and &00FF				;; &F1 = (Bottoms_array-1) & &00FF ; + A (can be 1to3, hence the minus 1)
	LD		E,A
	ADC		A,Bottoms_array_m1 / 256					;; DE = (Bottoms_array-1) >> 8 + offset ; &36F1 + offset (can be +1, 2 or 3, this is why we have "Bottoms_array-1")
	SUB		E
	LD		D,A
	LD		A,(DE)										;; get bottom sprite in A
	SET		5,(IY+O_SPRFLAGS)							;; Sprite flag bit5 = double sprites
	;; if bit 2 of the third byte is set, swap A and B.
    ;; (i.e. Stash current sprite in the bottom, and use bottom
    ;; sprite for the current object.)
	BIT 	2,(HL)										;; 3rd byte (flags), bit2 (SWAPPED)
	JR 		Z,initobj_1									;; if 0, skip initobj_1, else:
	LD 		C,B											;; else is a double sized obj
	LD 		B,A											;; swap sprites codes of the 2 parts composing the object
	LD 		A,C
initobj_1:
	LD 		(BottomSprite),A							;; save sprite code as bottom; 0 if single height
	LD 		A,B											;; get the other sprite code
	CALL 	SetObjSprite
	LD 		A,(HL)										;; read 3rd byte in ObjDefns array (flags)
	OR 		&9F											;; ~&60 (test bits6:5 of A are both 1 (HUNGRY))
	INC 	A											;; test if value was &60 (HUNGRY) (&9F + bits6:5 to 1 = FF, +1 is 0)
	LD 		A,(HL)										;; read the 3rd byte again
	JR 		NZ,initobj_2								;; if bit6:5 not 2b'11, jump initobj_2 (PORTABLE or DEADLY or NONE), else:
	SET 	7,(IY+O_SPRFLAGS)							;; else HUNGRY (will stop on Donuts): set sprite flag bit7
	AND 	%10111111									;; make it DEADLY : reset bit6 of the value from ObjDefns (it should be &20=DEADLY now)
initobj_2:
	AND 	%11111011									;; reset bit2 of the value from ObjDefns
	CP 		&80											;; compare to &80 (bit7 of 3rd byte set or not)
	RES 	7,A											;; reset bit7 from ObjDefns
	LD 		(IY-1),A									;; TmpObj_variables-1 = BaseFlags+1
	LD 		(IY-2),&02									;; TmpObj_variables-2 = BaseFlags
	RET 	c											;; if was < &80 leave, else 3rd byte bit7 = 1:
	SET 	4,(IY+O_SPRFLAGS)							;; set sprite flag bit4
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Set the sprite or animation up for an object.
;; Object pointer in IY, sprite/animation code in A
.SetObjSprite:
    ;; Clear animation code, and set sprite code.
	LD 		(IY+O_ANIM),0								;; anim reset (code = 0, frame = 0)
	LD 		(IY+O_SPRITE),A								;; set sprite code
	CP 		&80											;; test bit7 of sprite code
	RET 	c											;; if anim bit not set then leave, else if anim bit set (sprite code > &80 = not a static sprite, but an animation)
	ADD 	A,A
	ADD 	A,A
	ADD 	A,A											;; anim code << 3
	LD 		(IY+O_ANIM),A								;; put the current sprite ID in [7:3] (anim code) and frame [2:0] = 0
	PUSH 	HL
	CALL 	Animate										;; Animate
	POP 	HL
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Takes an object pointer in DE (From Objects buffer 6A40-...), and
;; index the object function in A.
;; Note that the function ID starts at 1, so to align on the ObjFnTbl
;; table, need to do a -1.
;; The object is of the same format that TmpObj_variables.
.CallObjFn:
	LD 		(CurrObject),DE								;; update curr object
	PUSH 	DE
	POP 	IY											;; current object pointer in IY
	DEC 	A											;; Function ID (-1 to align on table)
	ADD 	A,A											;; *2 (word align as it is addr that are stored in this table)
	ADD 	A,ObjFnTbl and &00FF						;; &7F = ObjFnTbl & &00FF
	LD 		L,A
	ADC 	A,ObjFnTbl / 256							;; &38 = ObjFnTbl >> 8	; &387F+object_num_offset
	SUB 	L
	LD 		H,A											;; HL = pointer on the function pointer
	LD 		A,(HL)										;; get the function pointer...
	INC 	HL
	LD 		H,(HL)
	LD 		L,A											;; ...(function address) in HL
	XOR 	A											;; A=0
	LD 		(DrawFlags),A								;; reset drawing flags
	LD 		A,(IY+O_IMPACT)								;; ??TODO?? get object facing direction
	LD 		(ObjDir),A									;; current Object is flipped or not?
	LD 		(IY+O_IMPACT),&FF							;; reset the object direction
	BIT 	6,(IY+O_SPRFLAGS)							;; test object flag bit6 = function disable (don't do object function if 1)
	RET 	NZ											;; if bit6 is 1 leave, else call object function
	JP 		(HL)										;; if SpriteFlags bit6 is 0, then call the object function

;; -----------------------------------------------------------------------------------------------------------
.AnimateObj:
	BIT 	5,(IY+O_SPRFLAGS)							;; test object sprite flag bit5 (single/double sprite)
	JR 		Z,Animate									;; if 0 Animate and RET (single sprite), else:
	CALL 	Animate										;; Need to Move and Animate both stacked sprites (double height)
	EX 		AF,AF'										;; save flags (carry)
	LD 		C,(IY+O_DIRECTION)							;; C=facing direction (0 to 7 or FF)
	LD 		DE,OBJECT_LENGTH							;; points on ...
	PUSH 	IY
	ADD 	IY,DE										;; ...next object (the 2nd object in the double stacked/height)
	CALL 	SetFacingDir
	CALL 	Animate
	POP 	IY											;; get back curr object pointer
	RET 	c											;; Animate returned with Carry set if anim, else NC
	EX 		AF,AF'										;; get flags -carry) of first sprite and return Carry set (anim) or NC (not anim)
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Update the animation. IY points to an object.
;; Returns with carry flag set if it's an animation. (NC if not)
.Animate:
    ;; Extract the animation id (top 5 bits)
	LD C,(IY+O_ANIM)									;; get anim code [7:3] and frame [2:0]
	LD A,C												;; save full anim code
	AND &F8												;; sprite is in [7:3]; frame index in [2:0]
	CP &08												;; compare with the value 8
	CCF													;; invert Carry
	RET NC												;; if value < 8 (which means value == 0 here due to the AND F8), leave (no anim) with NC, else:
	RRCA												;; Right shift twice,  values from 08 to F8
	RRCA												;; become from 02 to 3E
	SUB 2												;; minus 2 gives : 00 to 3C, which is anim ID (0 to 1E) multiplied by 2
	ADD A,AnimTable and &00FF							;; &F3 = AnimTable & &00FF
	LD L,A
	ADC A,AnimTable / 256								;; &37 = (AnimTable >> 8) + anim code * 2 ; &37F3+offset
	SUB L
	LD H,A												;; HL = points on the anim pointer
	LD A,C												;; get back the full anim code
	INC A												;; frame_nb + 1
	AND &07												;; frame_nb MOD 8
	LD B,A												;; B = (frame_nb + 1) MOD 8
	ADD A,(HL)											;; This does: ...
	LD E,A
	INC HL
	ADC A,(HL)
	SUB E
	LD D,A												;; ... DE = (HL) + A, which points on the new current animation sprite ID in AnimTable_data
	LD A,(DE)											;; get current anim sprite
	AND A												;; test
	JR NZ,Anim1											;; if not 0, jump Anim1, else value = 0 : reached the end of the animation sprite list, so need to restart from the begining:
	LD B,0												;; frame_nb = 0
	LD A,(HL)											;; From the pointer on the AnimTable_data pointer ...
	DEC HL
	LD L,(HL)
	LD H,A												;; ... get in HL the AnimTable_data pointer (first image on the anim list)
	LD A,(HL)											;; A = 1st sprite in the anim list
.Anim1:
	LD (IY+O_SPRITE),A									;; update sprite value
	LD A,B												;; current frame_nb
	XOR C
	AND &07
	XOR C												;; insert the anim code to the frame_nb
	LD (IY+O_ANIM),A									;; and update the O_ANIM (code in [7:3], frame in [2:0])
	;; the AND F0 and CP 80 checks for :
	;; ANIM_ROBOMOUSE (&0E)  &80 : 1000.0|000 = &10|0, &10-2 = &0E and
	;; ANIM_ROBOMOUSEB (&0F) &81 : 1000.1|000 = &11|0, &11-2 = &0F
	;; because of the AND &F0 both anim codes &0E and &0F match &80
	AND &F0
	CP &80
	LD C,&02											;; ROBOMOUSE sound set to Sound ID &02
	JR Z,anim_setsound									;; if match ROBOMOUSE then go set the sound, else:
	;; In the same way, &90 will match ANIM_BEE and ANIM_BEEB
	CP &90
	LD C,&01											;; in that case set Sound ID &01
.anim_setsound:
	LD A,C
	CALL Z,SetSound
	SCF													;; Return with Carry set (anim updated)
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Pointers on the anim sprites list from the anim codes [7:3] code and [2:0] frame
;; Note : The 'B' version is the moving-away-from-viewers version (Back/rear view).
;; The code &00 = no anim.
.AnimTable:
	DEFW 	AnimVape1					;; code &08 + frame ; ANIM_VAPE1:     	&81 3831
	DEFW 	AnimVisorO					;; code &10 + frame ; ANIM_VISORO:    	&82 3836
	DEFW 	AnimVisorC					;; code &18 + frame ; ANIM_VISORC:    	&83 3838
	DEFW 	AnimVape2					;; code &20 + frame ; ANIM_VAPE2:     	&84 383A
	DEFW 	AnimVape2					;; code &28 + frame ; ANIM_VAPE2B:    	&85 383A
	DEFW 	AnimFish					;; code &30 + frame ; ANIM_FISH:      	&86 383F
	DEFW 	AnimFish					;; code &38 + frame ; ANIM_FISHB:     	&87 383F
	DEFW 	AnimTeleport				;; code &40 + frame ; ANIM_TELEPORT:  	&88 3844
	DEFW 	AnimTeleport				;; code &48 + frame ; ANIM_TELEPORTB: 	&89 3844
	DEFW 	AnimSpring					;; code &50 + frame ; ANIM_SPRING:    	&8A 3847
	DEFW 	AnimSpring					;; code &58 + frame ; ANIM_SPRINGB:   	&8B 3847
	DEFW 	AnimMonocat					;; code &60 + frame ; ANIM_MONOCAT:   	&8C 384D
	DEFW 	AnimMonocatB				;; code &68 + frame ; ANIM_MONOCATB:  	&8D 3852
	DEFW 	AnimVape3					;; code &70 + frame ; ANIM_VAPE3:     	&8E 3857
	DEFW 	AnimVape3					;; code &78 + frame ; ANIM_VAPE3B:    	&8F 3857
	DEFW 	AnimRobomouse				;; code &80 + frame ; ANIM_ROBOMOUSE: 	&90 385E
	DEFW 	AnimRobomouseB				;; code &88 + frame ; ANIM_ROBOMOUSEB:	&91 3860
	DEFW 	AnimBee						;; code &90 + frame ; ANIM_BEE:       	&92 3862
	DEFW 	AnimBee						;; code &98 + frame ; ANIM_BEEB:      	&93 3862
	DEFW 	AnimBeacon					;; code &A0 + frame ; ANIM_BEACON:    	&94 3867
	DEFW 	AnimBeacon					;; code &A8 + frame ; ANIM_BEACONB:   	&95 3867
	DEFW 	AnimFace					;; code &B0 + frame ; ANIM_FACE:      	&96 386A
	DEFW 	AnimFaceB					;; code &B8 + frame ; ANIM_FACEB:     	&97 386C
	DEFW 	AnimChimp					;; code &C0 + frame ; ANIM_CHIMP:     	&98 386E
	DEFW 	AnimChimpB					;; code &C8 + frame ; ANIM_CHIMPB:    	&99 3870
	DEFW 	AnimCharles					;; code &D0 + frame ; ANIM_CHARLES:   	&9A 3872
	DEFW 	AnimCharlesB				;; code &D8 + frame ; ANIM_CHARLESB:  	&9B 3874
	DEFW 	AnimTrunk					;; code &E0 + frame ; ANIM_TRUNK:     	&9C 3876
	DEFW 	AnimTrunkB					;; code &E8 + frame ; ANIM_TRUNKB:    	&9D 3878
	DEFW 	AnimHeliplat				;; code &F0 + frame ; ANIM_HELIPLAT:    &9E 387A
	DEFW 	AnimHeliplat				;; code &F8 + frame ; ANIM_HELIPLATB:   &9F 387A

;; -----------------------------------------------------------------------------------------------------------
.AnimTable_data:
AnimVape1:
	DEFB 	SPR_FLIP or SPR_VAPE1, SPR_VAPE1, SPR_VAPE2, SPR_VAPE3, &00   					;; &80|SPR_VAPE1,SPR_VAPE1,SPR_VAPE2,SPR_VAPE3,&00
AnimVisorO:
	DEFB 	SPR_VISOROHALF, &00																;; SPR_VISOROHALF,&00
AnimVisorC:
	DEFB 	SPR_VISORCHALF, &00																;; SPR_VISORCHALF,&00
AnimVape2:
	DEFB 	SPR_VAPE1, SPR_VAPE2, SPR_VAPE2, SPR_VAPE1, &00        							;; SPR_VAPE1,SPR_VAPE2,SPR_VAPE2,SPR_VAPE1,&00
AnimFish:
	DEFB 	SPR_FISH1, SPR_FISH1, SPR_FISH2, SPR_FISH2, &00        							;; SPR_FISH1,SPR_FISH1,SPR_FISH2,SPR_FISH2,&00
AnimTeleport:
	DEFB 	SPR_TELEPORT, SPR_FLIP or SPR_TELEPORT, &00		         						;; SPR_TELEPORT,&80|SPR_TELEPORT,&00
AnimSpring:
	DEFB 	SPR_SPRING, SPR_SPRING, SPR_SPRUNG, SPR_SPRING, SPR_SPRUNG, &00					;; SPR_SPRING,SPR_SPRING,SPR_SPRUNG,SPR_SPRING,SPR_SPRUNG,&00
AnimMonocat:
	DEFB 	SPR_MONOCAT1, SPR_MONOCAT1, SPR_MONOCAT2, SPR_MONOCAT2, &00        				;; SPR_MONOCAT1,SPR_MONOCAT1,SPR_MONOCAT2,SPR_MONOCAT2,&00
AnimMonocatB:
	DEFB 	SPR_MONOCATB1, SPR_MONOCATB1, SPR_MONOCATB2, SPR_MONOCATB2, &00        			;; SPR_MONOCATB1,SPR_MONOCATB1,SPR_MONOCATB2,SPR_MONOCATB2,&00
AnimVape3:
	DEFB 	SPR_VAPE3, SPR_VAPE2, SPR_VAPE3, SPR_FLIP or SPR_VAPE3							;; SPR_VAPE3,SPR_VAPE2,SPR_VAPE3,&80|SPR_VAPE3
	DEFB	SPR_FLIP or SPR_VAPE2, SPR_FLIP or SPR_VAPE3, &00									;; &80|SPR_VAPE2,&80|SPR_VAPE3,&00
AnimRobomouse:
	DEFB 	SPR_ROBOMOUSE, &00         														;; SPR_ROBOMOUSE,&00
AnimRobomouseB:
	DEFB 	SPR_ROBOMOUSEB, &00             												;; SPR_ROBOMOUSEB,&00
AnimBee:
	DEFB 	SPR_BEE1, SPR_BEE2, SPR_FLIP or SPR_BEE2, SPR_FLIP or SPR_BEE1, &00       		;; SPR_BEE1,SPR_BEE2,&80|SPR_BEE2,&80|SPR_BEE1,&00
AnimBeacon:
	DEFB 	SPR_BEACON, SPR_FLIP or SPR_BEACON, &00       									;; SPR_BEACON,&80|SPR_BEACON,&00
AnimFace:
	DEFB 	SPR_FACE, &00          															;; SPR_FACE,&00
AnimFaceB:
	DEFB 	SPR_FACEB, &00          														;; SPR_FACEB,&00
AnimChimp:
	DEFB 	SPR_CHIMP, &00          														;; SPR_CHIMP,&00
AnimChimpB:
	DEFB 	SPR_CHIMPB, &00          														;; SPR_CHIMPB,&00
AnimCharles:
	DEFB 	SPR_CHARLES, &00          														;; SPR_CHARLES,&00
AnimCharlesB:
	DEFB 	SPR_CHARLESB, &00          														;; SPR_CHARLESB,&00
AnimTrunk:
	DEFB 	SPR_TRUNK, &00          														;; SPR_TRUNK,&00
AnimTrunkB:
	DEFB 	SPR_TRUNKB, &00          														;; SPR_TRUNKB,&00
AnimHeliplat:
	DEFB 	SPR_HELIPLAT1, SPR_HELIPLAT2, SPR_FLIP or SPR_HELIPLAT2							;; SPR_HELIPLAT1,SPR_HELIPLAT2,&80|SPR_HELIPLAT2
	DEFB	SPR_FLIP or SPR_HELIPLAT1, &00													;; &80|SPR_HELIPLAT1,&00

;; -----------------------------------------------------------------------------------------------------------
;; Table has base index of 1 in CallObjFn
OBJFN_PUSHABLE			EQU		&01
OBJFN_ROLLERS1			EQU		&02
OBJFN_ROLLERS2			EQU		&03
OBJFN_ROLLERS3			EQU		&04
OBJFN_ROLLERS4			EQU		&05
OBJFN_VISOR1			EQU		&06
OBJFN_MONOCAT			EQU		&07
OBJFN_ANTICLOCK			EQU		&08
OBJFN_RANDB				EQU		&09
OBJFN_BALL				EQU		&0A
OBJFN_BEE				EQU		&0B
OBJFN_RANDQ				EQU		&0c
OBJFN_RANDR				EQU		&0d
OBJFN_SWITCH  			EQU		&0E
OBJFN_HOMEIN			EQU		&0f
OBJFN_HELIPLAT3			EQU 	&10
OBJFN_FADE				EQU		&11
OBJFN_HELIPLAT			EQU		&12
OBJFN_COLAPSE			EQU		&13
OBJFN_DISSOLVE2			EQU		&14
OBJFN_SQPATROL			EQU		&15
OBJFN_LNPATROL			EQU		&16
OBJFN_HELIPLAT2			EQU		&17
OBJFN_DISSOLVE			EQU		&18
OBJFN_FIRE				EQU		&19
OBJFN_SPECIAL			EQU 	&1A
OBJFN_TELEPORT			EQU		&1b
OBJFN_SPRING			EQU		&1c
OBJFN_JCTRLED			EQU		&1d
OBJFN_JOYSTICK			EQU		&1e
OBJFN_HUSHPUPPY			EQU		&1f
OBJFN_RADARBEAM			EQU		&20
OBJFN_BOXRADAR			EQU		&21
OBJFN_DISAPPEAR			EQU		&22
OBJFN_DRIVEN			EQU		&23
OBJFN_CANNONBALL		EQU		&24
OBJFN_RESPECT			EQU		&25

;; -----------------------------------------------------------------------------------------------------------
.ObjFnTbl:
	DEFW	ObjFnPushable		;; OBJFN_PUSHABLE: 	01 ObjFnPushable   4DDC
	DEFW 	ObjFnRollers1		;; OBJFN_ROLLERS1: 	02 ObjFnRollers1	4D46
	DEFW 	ObjFnRollers2		;; OBJFN_ROLLERS2: 	03 ObjFnRollers2	4D4A
	DEFW 	ObjFnRollers3		;; OBJFN_ROLLERS3: 	04 ObjFnRollers3	4D4E
	DEFW 	ObjFnRollers4		;; OBJFN_ROLLERS4: 	05 ObjFnRollers4	4D52
	DEFW 	ObjFnVisor1			;; OBJFN_VISOR1:   	06 ObjFnVisor1	4DF3
	DEFW 	ObjFnMonocat		;; OBJFN_MONOCAT:  	07 ObjFnMonocat	4DF8
	DEFW 	ObjFnAnticlock		;; OBJFN_ANTICLOCK:	08 ObjFnAnticlock	4DFD
	DEFW 	ObjFnRandB			;; OBJFN_RANDB:    	09 ObjFnRandB	4E11
	DEFW 	ObjFnBall			;; OBJFN_BALL:     	0A ObjFnBall	4C86
	DEFW 	ObjFnBee			;; OBJFN_BEE:      	0B ObjFnBee	4E02
	DEFW 	ObjFnRandQ			;; OBJFN_RANDQ:    	0c ObjFnRandQ	4E07
	DEFW 	ObjFnRandR			;; OBJFN_RANDR:    	0d ObjFnRandR	4E0C
	DEFW 	ObjFnSwitch			;; OBJFN_SWITCH:   	0e ObjFnSwitch	4CD6
	DEFW 	ObjFnHomeIn			;; OBJFN_HOMEIN:   	0f ObjFnHomeIn 4E16
	DEFW 	ObjFnHeliplat3		;; OBJFN_HELIPLAT3:	10 ObjFnHeliplat3 4E82
	DEFW 	ObjFnFade			;; OBJFN_FADE:     	11 ObjFnFade 4D80
	DEFW 	ObjFnHeliplat		;; OBJFN_HELIPLAT: 	12 ObjFnHeliplat 4D31
	DEFW 	ObjFnColapse		;; OBJFN_COLAPSE:   13 ObjFnColapse 4D3B
	DEFW 	ObjFnDissolve2		;; OBJFN_DISSOLVE2:	14 ObjFnDissolve2 4D66
	DEFW 	ObjFnSquarePatrol	;; OBJFN_SQPATROL:  15 ObjFnSquarePatrol 4DED
	DEFW 	ObjFnLinePatrol		;; OBJFN_LNPATROL: 	16 ObjFnLinePatrol 4DE7
	DEFW 	ObjFnHeliplat2		;; OBJFN_HELIPLAT2:	17 ObjFnHeliplat2 4D2E
	DEFW 	ObjFnDissolve		;; OBJFN_DISSOLVE: 	18 ObjFnDissolve 4D63
	DEFW 	ObjFnFire			;; OBJFN_FIRE:     	19 ObjFnFire 4C76
	DEFW 	ObjFnSpecial		;; OBJFN_SPECIAL: 	1a ObjFnSpecial 4DCF
	DEFW 	ObjFnTeleport		;; OBJFN_TELEPORT: 	1b ObjFnTeleport 4C18
	DEFW 	ObjFnSpring			;; OBJFN_SPRING:   	1c ObjFnSpring 4D98
	DEFW 	ObjFnJoyControlled	;; OBJFN_JCTRLED:   1d ObjFnJoyControlled 4BFB
	DEFW 	ObjFnJoystick		;; OBJFN_JOYSTICK: 	1e ObjFnJoystick 4BEB
	DEFW 	ObjFnHushPuppy		;; OBJFN_HUSHPUPPY:	1f ObjFnHushPuppy 4D5C
	DEFW 	ObjFnRadarBeams		;; OBJFN_RADARBEAM 	20 ObjFnRadarBeams 4C5E
	DEFW 	ObjFnBoxRadar		;; OBJFN_BOXRADAR:	21 ObjFnBoxRadar 4F36
	DEFW 	ObjFnDisappear		;; OBJFN_DISAPPEAR:	22 ObjFnDisappear 4D92
	DEFW 	ObjFnDriven			;; OBJFN_DRIVEN:   	23 ObjFnDriven 4C3F
	DEFW 	ObjFnCannonFire		;; OBJFN_CANNONBALL: 24 ObjFnCannonFire 4C29 (victory room)
	DEFW 	ObjFnRespectful		;; OBJFN_RESPECT:   25 ObjFnRespectful	4E1B (Emperor's Guard)

;; -----------------------------------------------------------------------------------------------------------
ANIM_VAPE1				EQU		&81
ANIM_VISORO				EQU		&82
ANIM_VISORC				EQU		&83
ANIM_VAPE2				EQU		&84
ANIM_VAPE2B				EQU		&85
ANIM_FISH				EQU		&86
ANIM_FISHB				EQU		&87
ANIM_TELEPORT			EQU		&88
ANIM_TELEPORTB			EQU		&89
ANIM_SPRING				EQU		&8A
ANIM_SPRINGB			EQU		&8B
ANIM_MONOCAT			EQU		&8C
ANIM_MONOCATB			EQU		&8D
ANIM_VAPE3				EQU		&8E
ANIM_VAPE3B				EQU		&8F
ANIM_ROBOMOUSE			EQU		&90
ANIM_ROBOMOUSEB			EQU		&91
ANIM_BEE				EQU		&92
ANIM_BEEB				EQU		&93
ANIM_BEACON				EQU		&94
ANIM_BEACONB			EQU		&95
ANIM_FACE				EQU		&96
ANIM_FACEB				EQU		&97
ANIM_CHIMP				EQU		&98
ANIM_CHIMPB				EQU		&99
ANIM_CHARLES			EQU		&9A
ANIM_CHARLESB			EQU		&9B
ANIM_TRUNK				EQU		&9C
ANIM_TRUNKB				EQU		&9D
ANIM_HELIPLAT			EQU		&9E
ANIM_HELIPLATB			EQU		&9F

;; -----------------------------------------------------------------------------------------------------------
;; Flags for double-height objects (enemies)
DBL_SPR_TAP_1     	 	EQU 	%01000000			;; &40 bottom part (or top if SWAPPED bit set) is the first item in Bottom_array (SPR_TAP)
DBL_SPR_VAPE3     	 	EQU 	%10000000			;; &80 bottom part (or top if SWAPPED bit set) is the 2nd item in Bottom_array (SPR_VAPE3)
DBL_SPR_TAP_2     	 	EQU 	%11000000			;; &C0 bottom part (or top if SWAPPED bit set) is the 3rd item in Bottom_array (SPR_TAP)
;;
;; Guessing the flags...
WIDER					EQU		%00000001			;; bit0 : &01 ; bit0=0 for 3x32 or 3x24 sprites, bit0=1 for 4x28 sprites
THINER					EQU		%00000010			;; TODO????? bit1 : &02 ; ?? but only Gratings have this bit set to 1, maybe "thin" (can enter the square it sits in) to be confirmed!!!!
SWAPPED       			EQU 	%00000100			;; bit2 : &04 ; Double height object swap its top&bottom parts
TALL_OBJ				EQU		%00001000			;; bit3 : &08 ; if set is a TALL object (double height, 2 sprites, or one 3x32 sprite for VISORO) TO BE CONFIRMED?????
ROLLER_FLIP	   			EQU 	%00010000 			;; bit4 : &10 ; only for Rollers, Seems to invert (if set) the sprite orientation bit from the rooms data. In other words, apparently the rollers orientation are set in software rather that in data. 180° flip?
DEADLY      			EQU 	%00100000			;; bit5 : &20
PORTABLE	     		EQU 	%01000000			;; bit6 : &40
;; an object cannot be PORTABLE (ie. CARRY-able by Heels' Purse) and DEADLY at the same time, so when both are set, it means "HUNGRY" (includes DEADLY):
HUNGRY      			EQU 	%01100000			;; bits6:5 &60 ; TODO : indicates that if the enemy collides with a donut shot its movement and function disabled

;; Still unknown: &01, &02 (thin??? only Gratings)

;; -----------------------------------------------------------------------------------------------------------
;; Define the objects that can appear in a room definition
;; "sprite codes" >= &81 are animations
.ObjDefns:				;;		<sprite code> 	<function> 						<flag>
	DEFB 	ANIM_TELEPORT, 	OBJFN_TELEPORT,					WIDER							;; &00
	DEFB 	SPR_SPRING, 	OBJFN_SPRING,					PORTABLE						;; &01
	DEFB 	SPR_GRATING, 	&00,							THINER							;; &02
	DEFB 	SPR_TRUNKS, 	OBJFN_PUSHABLE,					PORTABLE						;; &03
	DEFB 	ANIM_HELIPLAT, 	OBJFN_HELIPLAT2,				&00								;; &04
	DEFB 	SPR_BOOK, 		&00,							WIDER							;; &05
	DEFB 	SPR_ROLLERS, 	OBJFN_ROLLERS1,					ROLLER_FLIP or WIDER			;; &06
	DEFB 	SPR_ROLLERS, 	OBJFN_ROLLERS2,					ROLLER_FLIP or WIDER			;; &07
	DEFB 	SPR_ROLLERS, 	OBJFN_ROLLERS3,					WIDER							;; &08
	DEFB 	SPR_ROLLERS, 	OBJFN_ROLLERS4,					WIDER							;; &09
	DEFB 	SPR_BONGO, 		OBJFN_PUSHABLE,					PORTABLE						;; &0A
	DEFB 	SPR_DECK, 		OBJFN_PUSHABLE,					PORTABLE						;; &0B
	DEFB 	ANIM_ROBOMOUSE, DBL_SPR_VAPE3 or OBJFN_HOMEIN,	HUNGRY or SWAPPED or TALL_OBJ	;; &0C
	DEFB 	SPR_BALL, 		OBJFN_BALL,						&00								;; &0D
	DEFB 	SPR_LAVAPIT, 	&00,							DEADLY or WIDER					;; &0E
	DEFB 	SPR_TOASTER, 	&00,							DEADLY or WIDER					;; &0F
	DEFB 	SPR_SWITCH, 	OBJFN_SWITCH,					&00								;; &10
	DEFB 	ANIM_BEACON, 	OBJFN_RANDB,					HUNGRY							;; &11
	DEFB 	ANIM_FACE, 		DBL_SPR_TAP_1 or OBJFN_HOMEIN,	HUNGRY or SWAPPED or TALL_OBJ	;; &12
	DEFB 	ANIM_CHARLES, 	DBL_SPR_TAP_2 or OBJFN_JCTRLED,	SWAPPED or TALL_OBJ				;; &13
	DEFB 	SPR_STICK, 		OBJFN_JOYSTICK,					&00								;; &14
	DEFB 	SPR_ANVIL, 		OBJFN_PUSHABLE,					WIDER							;; &15
	DEFB 	SPR_CUSHION, 	&00,							WIDER							;; &16
	DEFB 	SPR_CUSHION, 	OBJFN_DISSOLVE2,				WIDER							;; &17
	DEFB 	SPR_WELL, 		&00,							&00								;; &18
	DEFB 	ANIM_BEE, 		OBJFN_BEE,						HUNGRY							;; &19
	DEFB 	SPR_GRATING, 	OBJFN_DISSOLVE,					THINER							;; &1A
	DEFB 	ANIM_VISORO, 	OBJFN_VISOR1,					HUNGRY or TALL_OBJ				;; &1B
	DEFB 	ANIM_VAPE2, 	DBL_SPR_TAP_2 or OBJFN_RANDQ,	HUNGRY or SWAPPED or TALL_OBJ	;; &1C
	DEFB 	SPR_DRUM, 		OBJFN_BALL,						DEADLY							;; &1D
	DEFB 	SPR_HUSHPUPPY, 	OBJFN_HUSHPUPPY,				WIDER							;; &1E
	DEFB 	SPR_SANDWICH, 	OBJFN_SQPATROL,					WIDER							;; &1F
	DEFB 	ANIM_FACE, 		DBL_SPR_TAP_2 or OBJFN_RANDR,	HUNGRY or SWAPPED or TALL_OBJ	;; &20
	DEFB 	SPR_SPIKES, 	&00,							DEADLY or WIDER					;; &21
	DEFB 	SPR_BOOK, 		OBJFN_DISSOLVE2,				WIDER							;; &22
	DEFB 	SPR_PAD, 		OBJFN_DISSOLVE2,				WIDER							;; &23
	DEFB 	SPR_PAD, 		&00, 							WIDER							;; &24
	DEFB 	SPR_TAP, 		OBJFN_RADARBEAM, 				HUNGRY							;; &25
	DEFB 	ANIM_BEE, 		OBJFN_BOXRADAR, 				HUNGRY							;; &26
	DEFB 	ANIM_HELIPLAT, 	OBJFN_HELIPLAT, 				&00								;; &27
	DEFB 	SPR_SANDWICH, 	OBJFN_PUSHABLE, 				WIDER							;; &28
	DEFB 	SPR_CUSHION, 	OBJFN_COLAPSE, 					WIDER							;; &29
	DEFB 	ANIM_MONOCAT, 	OBJFN_MONOCAT, 					HUNGRY							;; &2A
	DEFB 	SPR_ANVIL, 		OBJFN_LNPATROL, 				WIDER							;; &2B
	DEFB 	SPR_BOOK, 		OBJFN_ANTICLOCK, 				WIDER							;; &2C
	DEFB 	SPR_SANDWICH, 	OBJFN_DRIVEN, 					WIDER							;; &2D
	DEFB 	ANIM_TRUNK, 	DBL_SPR_TAP_2 or OBJFN_RANDR, 	HUNGRY or SWAPPED or TALL_OBJ	;; &2E
	DEFB 	SPR_TRUNK, 		&00, 							DEADLY							;; &2F
	DEFB 	SPR_DRUM, 		OBJFN_BALL, 					&00								;; &30
	DEFB 	SPR_FISH1, 		&00, 							DEADLY							;; &31
	DEFB 	SPR_ROLLERS, 	OBJFN_DISSOLVE2, 				WIDER							;; &32
	DEFB 	SPR_BOOK,		OBJFN_BALL, 					WIDER							;; &33
	DEFB 	SPR_BOOK,		OBJFN_PUSHABLE, 				WIDER							;; &34
	DEFB 	ANIM_CHIMP, 	DBL_SPR_TAP_1 or OBJFN_HOMEIN, 	HUNGRY or SWAPPED or TALL_OBJ	;; &35
	DEFB 	ANIM_CHIMP, 	DBL_SPR_TAP_2 or OBJFN_RANDR, 	HUNGRY or SWAPPED or TALL_OBJ	;; &36
	DEFB 	ANIM_VISORO, 	OBJFN_ANTICLOCK, 				HUNGRY or TALL_OBJ				;; &37
	DEFB 	SPR_ROBOMOUSE, 	&00,							DEADLY							;; &38
	DEFB 	SPR_ROBOMOUSEB, &00,							DEADLY							;; &39
	DEFB 	SPR_HEAD1, 		&00,							&00								;; &3A
	DEFB 	SPR_HEELS1, 	&00,							&00								;; &3B
	DEFB 	SPR_BALL, 		OBJFN_CANNONBALL, 				&00								;; &3C
	DEFB 	SPR_BALL, 		DBL_SPR_VAPE3 or OBJFN_RESPECT,	DEADLY or SWAPPED or TALL_OBJ	;; &3D
	DEFB 	ANIM_VAPE2, 	OBJFN_BOXRADAR, 				HUNGRY							;; &3E ; Emperor!

;; -----------------------------------------------------------------------------------------------------------
;; Reinitialisation size of the array
;; The Reinitialise call with 3986 as argument will copy the 27 bytes of
;; ObjVars_reset_data into the ObjListIdx & after
ObjVars:
	DEFB 	&1B								;; length : 27 bytes
ObjVars_reset_data:
	DEFB 	&00								;; reset for idx Objects
	DEFW 	Objects         				;; reset for dest Objects 6A40
	DEFW 	ObjectLists      				;; reset for ALstPtr ObjectLists + 0	39A9
	DEFW 	ObjectLists + 2 				;; reset for BLstPtr ObjectLists + 2  	39AB
	DEFW 	&0000							;; reset for AList
	DEFW 	&0000							;; reset for BList
	DEFW 	&0000, &0000					;; reset for Next V room
	DEFW 	&0000, &0000					;; reset for Next U room
	DEFW 	&0000, &0000					;; reset for Next Far room
	DEFW 	&0000, &0000					;; reset for Next Near room

;; -----------------------------------------------------------------------------------------------------------
;; The index into ObjectLists.
.SaveRestore_Block2:											;; Save/Restore block 2 : &1D (29 bytes)
.ObjListIdx:
	DEFB 	&00								;; list index
Object_Destination:												;; Current pointer for where we write objects into (6A40 buffer)
	DEFW 	Objects
.ObjListAPtr:													;; 'A' list item pointers are offset +2 from 'B' list pointers.
	DEFW 	ObjectLists 					;; ObjectLists + 0 : 39A9
.ObjListBPtr:
	DEFW 	ObjectLists + 2					;; ObjectLists + 2 : 39AB
;; Each list consists of a pair of pointers to linked lists of
;; objects (ListA and ListB). They're opposite directions in a
;; doubly-linked list, and each side has a head node, it seems.
ObjectLists:
	DEFW 	&0000 							;; ObjectLists + 0   ; Usual list
	DEFW 	&0000             				;; ObjectLists + 2   ; Usual list
	DEFW 	&0000, &0000            		;; ObjectLists + 1*4 ; Next room in V direction
	DEFW 	&0000, &0000            		;; ObjectLists + 2*4 ; Next room in U direction
	DEFW 	&0000, &0000            		;; ObjectLists + 3*4 ; Far
	DEFW 	&0000, &0000            		;; ObjectLists + 4*4 ; Near

Saved_Object_Destination:
	DEFW 	Objects							;; Objects : 6A40
.SaveRestore_Block2_end

;; -----------------------------------------------------------------------------------------------------------
.SortObj:
	DEFW 	&0000

;; -----------------------------------------------------------------------------------------------------------
;; Given an index in A, set the object list index and pointers.
.SetObjList:
	LD		(ObjListIdx),A								;; object id
	ADD		A,A											;; *2
	ADD		A,A											;; *4
	ADD		A,ObjectLists and &00FF						;; &A9 = (ObjectLists & &00FF) + (4 * object id)
	LD		L,A
	ADC		A,ObjectLists / 256							;; &39 = ObjectLists >> 8 ; &39A9+offset
	SUB		L
	LD		H,A											;; HL = ObjectLists + 4*index
	LD		(ObjListAPtr),HL							;; pointer A
	INC		HL
	INC		HL											;; next word in list
	LD		(ObjListBPtr),HL							;; pointer B
	RET

;; -----------------------------------------------------------------------------------------------------------
;; DE contains an 'A' object pointer. Assumes the other half of the object
;; is in the next slot (+0x12). Syncs the object state.
.SyncDoubleObject:
    ;; Copy 5 bytes, from the pointer location onwards:
    ;; Next pointer, flags, U & V coordinates.
	LD HL,OBJECT_LENGTH
	ADD HL,DE
	PUSH HL
	EX DE,HL
	LD BC,&0005
	LDIR												;; repeat LD (DE),(HL); DE++, HL++, BC-- until BC=0
	;; Copy across Z coordinate, sutracting 6.
	LD A,(HL)
	SUB 6
	LD (DE),A
	;; If bit 5 of byte 9 is set on first object, we're done.
	INC DE
	INC HL
	INC HL
	BIT 5,(HL)
	JR NZ,snkdblob_1
	;; Otherwise, copy the sprite over (byte 8).
	DEC HL
	LDI													;; do once : LD (DE),(HL); DE++, HL++, BC--
snkdblob_1:
	POP HL
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Copy an object into the object buffer, add a second object if it's
;; doubled, and link it into the depth-sorted lists.
;;
;; HL is a 'B' pointer to an object.
;; BC contains the size of the object (18 bytes).
.AddObject:
    ;; First, just return if there's no intersection with the view window.
	PUSH HL
	PUSH BC
	INC HL
	INC HL
	CALL IntersectObj   								;; HL now contains an 'A' ptr to object.
	POP BC
	POP HL
	RET NC
	;; Copy BC bytes of object to what ObjDest pointer, updating ObjDest
	LD DE,(Object_Destination)							;; get Object_Destination buffer pointer
	PUSH DE
	LDIR												;; repeat LD (DE),(HL); DE++, HL++, BC-- until BC=0
	LD (Object_Destination),DE							;; update Object_Destination
	POP HL
	;; HL now points at copied object
	PUSH HL
	POP IY
	;; If it's not a double object, just call Enlist.
	BIT 3,(IY+O_FLAGS)									;; Check bit 3 of flags...
	JR Z,Enlist
	;; Bit 3 set = tall object. Make the second object like the
    ;; first, copying the first 9 bytes.
	LD BC,&0009
	PUSH HL
	;; Copy byte at offset 9 over, setting bit 1.
	LDIR												;; repeat LD (DE),(HL); DE++, HL++, BC-- until BC=0
	EX DE,HL
	LD A,(DE)											;; Load A with offset 9 of original
	OR &02
	LD (HL),A											;; Set bit 1, write out.
	;; Write 0 for byte at offset 10.
	INC HL
	LD (HL),&00
	;; And update ObjDest to point past newly constructed object (offset 18).
	LD DE,&0008
	ADD HL,DE
	LD (Object_Destination),HL							;; update Object_Destination
	;; If bit 5 of offset 9 set, set the sprite on this second object.
	BIT 5,(IY+O_SPRFLAGS)								;; single/double spitre object
	JR Z,addob_1
	PUSH IY
	LD DE,OBJECT_LENGTH									;; array size
	ADD IY,DE
	LD A,(BottomSprite)
	CALL SetObjSprite
	POP IY
addob_1:
	POP HL
;; HL points at an object, as does IY.
.Enlist:
	LD A,(ObjListIdx)
	;; If the current object list is >= 3, use EnlistAux directly.
	DEC A
	CP &02
	JR NC,EnlistAux
	;; If it's not double-height, insert on the current list.
	INC HL
	INC HL
	BIT 3,(IY+O_FLAGS)
	JR Z,EnlistObj
	PUSH HL
	CALL EnlistObj
	POP DE
	CALL SyncDoubleObject
	PUSH HL
	CALL GetUVZExtents_Alst
	EXX
	PUSH IY
	POP HL
	INC HL
	INC HL
	JR DepthInsert

;; Put the object in HL into its depth-sorted position in the list.
.EnlistObj:
	PUSH HL
	CALL GetUVZExtents_Alst
	EXX
	JR DepthInsertHd

;; Takes a B pointer in HL/IY. Enlists it, and its other half if it's a
;; double-size object. Inserts inthe the appropriate list.
.EnlistAux:
	INC HL
	INC HL
	;; Easy path if it's a single object.
	BIT 3,(IY+O_FLAGS)
	JR Z,EnlistObjAux
	;; Otherwise, do one half...
	PUSH HL
	CALL EnlistObjAux
	POP DE
	CALL SyncDoubleObject
	;; and insert the other half, on the same object list.
	PUSH HL
	CALL GetUVZExtents_Alst
	EXX
	PUSH IY
	POP HL
	INC HL
	INC HL
	JR DepthInsert

;; Object in HL. Inserts object into appropriate object list
;; based on coordinates.
;;
;; List 3 is far away, 0 in middle, 4 is near.
.EnlistObjAux:
	PUSH HL
	CALL GetUVZExtents_Alst
	;; If object is beyond high U boundary, put on list 3.
	LD A,&03
	EX AF,AF'
	LD A,(Max_min_UV_Table+2)							;; MaxU
	CP D
	JR c,elonjax_1
	;; If object is beyond high V boundary, put on list 3.
	LD A,(Max_min_UV_Table+3)							;; MaxV
	CP H
	JR c,elonjax_1
	;; If object is beyond low U boundary, put on list 4.
	LD A,&04
	EX AF,AF'
	LD A,(Max_min_UV_Table)								;; MinU
	DEC A
	CP E
	JR NC,elonjax_1
	;; If object is beyond low V boundary, put on list 4.
	LD A,(Max_min_UV_Table+1)							;; MinV
	DEC A
	CP L
	JR NC,elonjax_1
	;; Otherwise, put on list 0.
	XOR A
	EX AF,AF'
elonjax_1:
	EXX
	EX AF,AF'
	;; And then insert into the appropriate place on that list.
	CALL SetObjList
;; Does DepthInsert on the list pointed to by ObjListAPtr
.DepthInsertHd:
	LD HL,(ObjListAPtr)
;; Object extents in alt registers, 'A' pointer in HL.
;; Object to insert is on the stack.
;;
;; I believe this traverses a list sorted far-to-near, and
;; loads up HL with the nearest object further away from our
;; object.
.DepthInsert:
	LD (SortObj),HL
.DepIns2:
	LD A,(HL)											;; Load next object into HL...
	INC HL
	LD H,(HL)
	LD L,A
	OR H
	JR Z,DepIns3										;; Zero? Done!
	PUSH HL
	CALL GetUVZExtents_Alst
	CALL DepthCmp
	POP HL
	JR NC,DepthInsert  									;; Update SortObj if current HL is far away
	AND A
	JR NZ,DepIns2										;; Break out of loop if past point of caring
.DepIns3:
	LD HL,(SortObj)
	;; Insert the stack-stored object after SortObj.
    ;; Load our object in DE, HL contains object to chain after.
	POP DE
	;; Copy HL obj's 'next' pointer into DE obj's.
	LD A,(HL)
	LDI													;; do once : LD (DE),(HL); DE++, HL++, BC--
	LD C,A
	LD A,(HL)
	LD (DE),A
	;; Now copy address of DE into HL's 'next' pointer.
	DEC DE
	LD (HL),D
	DEC HL
	LD (HL),E
	;; Now links in the other direction:
    ;; Put DE's new 'next' pointer into HL.
	LD L,C
	LD H,A
	;; And if it's zero, load HL with pointer referred to by ObjListBPtr
	OR C
	JR NZ,br_3ADF
	LD HL,(ObjListBPtr)
	INC HL
	INC HL
br_3ADF
	;; Link DE after HL
	DEC HL
	DEC DE
	LDD
	LD A,(HL)
	LD (DE),A
	LD (HL),E
	INC HL
	LD (HL),D
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Take an object out of the list, and reinserts it in the
;; appropriate list.
.Relink:
	PUSH 	HL
	CALL 	Unlink
	POP 	HL
	JP 		EnlistAux

;; -----------------------------------------------------------------------------------------------------------
;; Unlink the object in HL. If bit 3 of IY+4 is set, it's an
;; object made out of two subcomponents, and both must be
;; unlinked.
.Unlink:
	BIT 3,(IY+O_FLAGS)
	JR Z,UnlinkObj
	PUSH HL
	CALL UnlinkObj
	POP DE
	LD HL,OBJECT_LENGTH
	ADD HL,DE
;; Takes a 'B' pointer in HL, and removes the pointed object
;; from the list.
;;
;; In C-like pseudocode:
;;
;; if (obj->b_next == null) {
;;   a_head = obj->a_next;
;; } else {
;;   obj->b_next->a_next = obj->a_next;
;; }
;;
;; if (obj->a_next == null) {
;;   b_head = obj->b_next;
;; } else {
;;   obj->a_next->b_next = obj->b_next;
;; }
.UnlinkObj:
    ;; Load DE with next object after HL, save it.
	LD E,(HL)
	INC HL
	LD D,(HL)
	INC HL
	PUSH DE
	;; If zero, get first object on List A, else offset DE by 2 to
    ;; create an 'A' pointer.
	LD A,D
	OR E
	INC DE
	INC DE
	JR NZ,ulnk_1
	LD DE,(ObjListAPtr)
	;; HL pointer at 'A' pointer now. Copy *HL to *DE, saving
    ;; value in HL.
ulnk_1:
	LD A,(HL)
	LDI													;; do once : LD (DE),(HL); DE++, HL++, BC--
	LD C,A
	LD A,(HL)
	LD (DE),A
	LD H,A
	LD L,C
	;; If the pointer was null, put the head of the B list in HL.
	OR C
	DEC HL
	JR NZ,br_3B1F
	LD HL,(ObjListBPtr)
	INC HL
br_3B1F
	;; Make HL's next B object the saved DE B pointer.
	POP DE
	LD (HL),D
	DEC HL
	LD (HL),E
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Like GetUVZExtents_Blst, but applies extra height adjustment.
;; A has the object flags.
;; increases height by 6 if flag bit 3 is set.
.GetUVZExtents_AdjustLowZ:
	CALL 	GetUVZExtents_Blst
	AND 	%00001000									;; test bit3
	RET 	Z											;; no need for adjustement if bit3 = 0
	LD 		A,C
	SUB 	6
	LD 		C,A											;; else adjust C (lowZ) with -6
	RET

;; -----------------------------------------------------------------------------------------------------------
;; * GetUVZExtents_Alst :  At entry, HL points on the object variables array + 2 (ie. A list pointer)
;; 	  Then first thing, HL will be updated to point on Object O_FLAGS
;; * GetUVZExtents_Blst : At entry, HL points on the object variables array + 0 (ie. B list pointer)
;;    (Apparently GetUVZExtents_Blst is only used by Heels_variables and Head_variables).
;;    Then first thing, HL will be updated to point on Object O_FLAGS
;; So given an object (variables array) in HL, returns its U, V and Z extents.
;; Moves in a particular direction:
;;
;; Values are based on the bottom 3 flag bits [2:0]
;; Flag   U      V      Z
;; 000	+3 -3  +3 -3  0  -6
;; 001	+4 -4  +4 -4  0  -6
;; 010	+4 -4  +1 -1  0  -6		DE = high,low U
;; 011	+1 -1  +4 -4  0  -6		HL = high,low V
;; 100	+4  0  +4  0  0 -18		BC = high,low Z
;; 101	 0 -4  +4  0  0 -18
;; 110	+4  0   0 -4  0 -18		It returns flags in A.
;; 111	 0 -4   0 -4  0 -18
.GetUVZExtents_Blst:
	INC 	HL
	INC 	HL
.GetUVZExtents_Alst:
	INC 	HL
	INC 	HL
	LD 		A,(HL)										;; A = object O_FLAGS
	INC 	HL											;; HL points on object O_U
	LD 		C,A											;; flags in C
	EX 		AF,AF'										;; save flags in A'
	LD 		A,C											;; also flags in A
	BIT 	2,A											;; test bit2
	JR 		NZ,GUVZE_1xx								;; If bit2 set jump GUVZE_1xx
	;; case 0??
	BIT 	1,A											;; test bit 1
	JR 		NZ,GUVZE_01x								;; If bit1 set jump GUVZE_01x
	;; case 00?
	AND 	%00000001									;; A = bit0
	ADD 	A,3
	LD 		B,A											;; B = (bit0 + 3)
	ADD 	A,A											;; x2
	LD 		C,A											;; C = 2 x (bit0 + 3)
	LD 		A,(HL)										;; read O_U
	ADD 	A,B
	LD 		D,A											;; D = U + (bit0 + 3)
	SUB 	C
	LD 		E,A											;; E = U - (bit0 + 3)
	INC 	HL											;; points on O_V
	LD 		A,(HL)					 					;; Load V coord
	INC 	HL											;; point on O_Z
	ADD 	A,B
	LD 		B,(HL)										;; B = Z
	LD 		H,A						 					;; H = V + (bit0 + 3)
	SUB 	C
	LD 		L,A						 					;; L = V - (bit0 + 3)
GUVZE_z_zm6:
	LD 		A,B											;; B = Z
	SUB 	6
	LD 		C,A											;; C = Z - 6
	EX 		AF,AF'										;; get back flags in A
	RET

	;; case 01x
GUVZE_01x:
	RRA													;; bit0 in Carry
	JR 		c,GUVZE_011									;; if bit0 = 1 jump GUVZE_011, else:
	;; case 010
	LD 		A,(HL)
	ADD 	A,4
	LD 		D,A											;; D = U + 4
	SUB 	8
	LD 		E,A											;; E = U - 4
	INC 	HL											;; point on V
	LD 		A,(HL)										;; A = V
	INC 	HL											;; point on Z
	LD 		B,(HL)										;; B = Z
	LD 		H,A
	LD 		L,A											;; temp H = L = A = V
	INC 	H											;; H = V + 1
	DEC 	L											;; L = V - 1
	JR 		GUVZE_z_zm6									;; BC = Z ; Z-6

	;; case 011
GUVZE_011:
	LD 		D,(HL)										;; temp D = U
	LD 		E,D											;; temp E = U
	INC 	D											;; D = U + 1
	DEC 	E											;; E = U - 1
	INC 	HL											;; point on V
	LD 		A,(HL)										;; A = V
	INC 	HL											;; point on Z
	ADD 	A,4											;; A = V + 4
	LD 		B,(HL)										;; B = Z
	LD 		H,A											;; H = V + 4
	SUB 	8
	LD 		L,A											;; L = V - 4
	JR 		GUVZE_z_zm6									;; BC = Z ; Z-6

    ;; case 1??
GUVZE_1xx:
	LD 		A,(HL)										;; A = U coord
	RR 		C											;; flags bit0 in Carry
	JR 		c,GUVZE_1x1									;; if bit0 = 1 jump GUVZE_1x1
	LD 		E,A											;; else bit0=0, E = U
	ADD 	A,4
	LD 		D,A											;; D = U + 4
	JR 		GUVZE_1xA

	;; case 1?1
GUVZE_1x1:
	LD 		D,A											;; D = U
	SUB 	4
	LD 		E,A											;; E = U - 4
GUVZE_1xA:
	INC 	HL											;; points on V
	LD 		A,(HL)										;; A = V coord
	INC 	HL											;; points on Z
	LD 		B,(HL)										;; B = Z
	RR 		C											;; flags bit1 in Carry
	JR 		c,GUVZE_11A									;; bit1 = 1 jump GUVZE_11A, else bit1 = 0:
	;; case 100 and 101
	LD 		L,A											;; L = V
	ADD 	A,4
	LD 		H,A											;; H = V + 4
	JR 		GUVZE_z_zm18

	;; case 110 and 111
GUVZE_11A:																	;; bit1 = 1
	LD 		H,A											;; H = V
	SUB 	4
	LD 		L,A											;; L = V - 4
GUVZE_z_zm18:
	LD 		A,B											;; B = Z
	SUB 	&12
	LD 		C,A											;; C = Z - 18
	EX 		AF,AF'										;; gets back flags in A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Provides a single, long-winded function to depth-order two set of
;; UVZ extents.
;; Two set of UVZ extents (as returned from GetUVZExtents), in main
;; and EXX'd registers.
;;
;; Returns:
;;  Carry set if EXX'd registers represent a further-away object.
;;  A = 0 if there's an overlap in 2 dimensions, &FF otherwise
.DepthCmp:
    ;; L < H' && H > L' -> U Overlap
	LD A,L
	EXX
	CP H
	LD A,L
	EXX
	JR NC,NoUOverlap
	CP H
	JR c,UOverlap
.NoUOverlap:
    ;; E < D' && D > E' -> V Overlap
	LD A,E
	EXX
	CP D
	LD A,E
	EXX
	JR NC,dpth_1
	CP D
	JR c,VNoUOverlap
dpth_1
	LD A,C
	EXX
	CP B
NoUVOverlap:
    ;; C < B' && B > C' -> Z Overlap
	LD A,C
	EXX
	JR NC,NoUVZOverlap
	CP B
	JR c,ZNoUVOverlap
.NoUVZOverlap:
    ;; No overlaps at all - simple depth comparison
    ;; HL = U + V + Z (lower coords)
	LD A,L
	ADD A,E													;; HL = L + E + C
	ADD A,C
	LD L,A
	ADC A,0													;; Add Carry
	SUB L
	LD H,A
	;; DE = U' + V' + Z' (lower co-ords)
	EXX
	LD A,L
	ADD A,E
	ADD A,C
	EXX
	LD E,A
	ADC A,0													;; Add Carry
	SUB E
	LD D,A
	;; Compare depths
	SBC HL,DE
	LD A,&FF
	RET

;; -----------------------------------------------------------------------------------------------------------
.ZNoUVOverlap:
    ;; Overlaps in Z, not U or V. In this case, we compare on U + V
	LD A,L
	ADD A,E
	LD L,A
	EXX
	LD A,L
	ADD A,E
	EXX
	CP L
	CCF
	LD A,&FF
	RET

;; -----------------------------------------------------------------------------------------------------------
.UOverlap:
    ;; E < D' && D > E' -> V Overlap
	LD A,E
	EXX
	CP D
	LD A,E
	EXX
	JR NC,UNoVOverlap
	CP D
	JR c,UVOverlap
.UNoVOverlap:
    ;; C < B' && B > C' -> Z Overlap
	LD A,C
	EXX
	CP B
	LD A,C
	EXX
	JR NC,UNoVZOverlap
	CP B
	JR c,UZNoVOverlap
.UNoVZOverlap:
    ;; Compare on Z  + V
	EXX
	ADD A,E
	EXX
	LD L,A
	ADC A,0													;; Add Carry
	SUB L
	LD H,A
	LD A,C
	ADD A,E
	LD E,A
	ADC A,0													;; Add Carry
	SUB E
	LD D,A
	SBC HL,DE
	CCF
	LD A,&FF
	RET

;; -----------------------------------------------------------------------------------------------------------
.UZNoVOverlap:
    ;; Compare on V
	LD A,E
	EXX
	CP E
	EXX
	LD A,&00
	RET

;; -----------------------------------------------------------------------------------------------------------
.UVOverlap:
    ;; Compare on Z
	LD A,C
	EXX
	CP C
	EXX
	LD A,&00
	RET

;; -----------------------------------------------------------------------------------------------------------
.VNoUOverlap:
    ;; C < B' && B > C' -> Z Overlap
	LD A,C
	EXX
	CP B
	LD A,C
	EXX
	JR NC,VNoUZOverlap
	CP B
	JR c,VZNoUOverlap
.VNoUZOverlap:
    ;; Compare on U + Z
	EXX
	ADD A,L
	EXX
	LD E,A
	ADC A,0													;; Add Carry
	SUB E
	LD D,A
	LD A,C
	ADD A,L
	LD L,A
	ADC A,0													;; Add Carry
	SUB L
	LD H,A
	SBC HL,DE
	LD A,&FF
	RET

;; -----------------------------------------------------------------------------------------------------------
.VZNoUOverlap:
    ;; Compare on U
	LD A,L
	EXX
	CP L
	EXX
	LD A,&00
	RET

;; -----------------------------------------------------------------------------------------------------------
Walls_PanelBase:
	DEFW 	&0000
Walls_PanelFlipsPtr:
	DEFW 	&0000 					;; Pointer to byte full of whether walls need to flip
Walls_ScreenMaxV:
	DEFB 	&00
Walls_ScreenMaxU:
	DEFB 	&00
Walls_CornerX:
	DEFB 	&00
Walls_DoorZ:
	DEFB 	&00   					;; Height of highest door.

;; -----------------------------------------------------------------------------------------------------------
;; Set the various variables used to work out the edges of the walls.
.StoreCorner:
	CALL 	GetCorner									;; BC = XY; HL points on BackgrdBuff
	LD 		A,C											;; C = Y
	SUB 	6											;; -6
	LD 		C,A
	ADD 	A,B											;; B = X
	RRA													;; div 2
	LD 		(Walls_ScreenMaxV),A						;; Store (Y + X - 6) / 2
	LD 		A,B
	NEG													;; -X ou 256-X
	ADD 	A,C											;; Y - X ou 256 - X + Y
	RRA													;; div 2
	LD 		(Walls_ScreenMaxU),A						;; Store 128 - ((X - Y) / 2)
	LD 		A,B
	LD 		(Walls_CornerX),A							;; Store B in Walls_CornerX
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Configure the walls.
;; Height of highest door in A.
.ConfigWalls:
	LD (Walls_DoorZ),A									;; door height
	CALL VWall
    ;; Skip if there's an extra room visible in the U dir.
	LD A,(Has_no_wall)
	AND 4												;; test bit 2 : wall U side (ne)
	RET NZ												;; if there is a wall, leave (else can see further into next room
	;; Put the wall mask in B' and stash the reflection flag at smc_OWFlag.
    ;; Step size in DE, direction extent in A.
	LD B,4
	EXX
	LD A,&80
	LD (smc_OWFlag+1),A									;; self mode code, value of "OR ..."
	CALL GetCorner
	LD DE,&0002
	LD A,(IY-1)											;; (IY-&01) ; MaxV
	SUB (IY-3)											;; (IY-&03) ; MinV
	JR OneWall

;; Draw wall parallel to U axis.
.VWall:
    ;; Skip if there's an extra room in the V direction.
	LD A,(Has_no_wall)
	AND &08
	RET NZ
	;; Put the wall mask in B' and stash the reflection flag at smc_OWFlag.
    ;; Step size in DE, direction extent in A.
	LD B,&08
	EXX
	XOR A
	LD (smc_OWFlag+1),A									;; self mode code, value of "OR ..."
	CALL GetCorner
	DEC L
	DEC L
	LD DE,&FFFE											;; -2
	LD A,(IY-2)											;; (IY-&02) ; MaxU
	SUB (IY-4)											;; (IY-&04)   ; MinU
;; Room extent in A, movement step in DE, BackgrdBuff pointer in HL, X/Y in B/C
;; The flag for this wall in B'
.OneWall:
    ;; Divide wall extent by 16 (one panel?)
	RRA
	RRA
	RRA
	RRA
	AND &0F
	;; Move BackgrdBuff pointer to IX.
	PUSH HL
	POP IX
	EXX
	;; Updated extent in C, check if this wall has a door.
	LD C,A
	LD A,(Has_Door)										;; Has_Door
	AND B
	CP &01
	;; Carry set means no door. Stash it in F'
	EX 		AF,AF'
	LD 		A,(WorldId)									;; which world? (for panels selection)
	LD 		B,A
PanelFlips_after_move	EQU		PanelFlips + MOVE_OFFSET
	ADD 	A,PanelFlips_after_move and &00FF			;; &D8 = (PanelFlips & &FF)
	LD 		L,A
	ADC 	A,PanelFlips_after_move / 256				;; &70 = (PanelFlips >> 8)	; &70D8+offset
	SUB 	L
	LD 		H,A											;; HL = PanelFlips + WorldId
	LD 		(Walls_PanelFlipsPtr),HL					;; in Walls_PanelFlipsPtr
	LD 		A,B											;; WorldId
	ADD 	A,A											;; A= WorldId x2
	LD 		B,A											;; B= WorldId x2
	ADD		A,A
	ADD 	A,A											;; A = WorldId x 8
Panel_WorldData_m1		EQU		Panel_WorldData - 1							;; = &3DA9; minus 1 so that the FetchData2b (using DataPtr and dummy CurrData) will start at Panel_WorldData
	ADD 	A,Panel_WorldData_m1 and &00FF				;; ((A + Panel_WorldData - 1) & FF)
	LD 		L,A
	ADC 	A,Panel_WorldData_m1 / 256					;; ((A + Panel_WorldData - 1) >> 8) ; &3DA9+offset
	SUB 	L
	LD 		H,A											;; HL is (Panel_WorldData) + (8 x WorldId) - 1
	LD 		(DataPtr),HL
	LD 		A,&80										;; dummy data so that first read will start at "Panel_WorldData + (8 x worldID)"
	LD 		(CurrData),A
	LD 		A,PanelsBaseAddr and &00FF					;; &9A = PanelsBaseAddr & FF
	ADD		A,B											;; add WorldId x2
	LD 		L,A
	ADC 	A,PanelsBaseAddr / 256						;; &3D = PanelsBaseAddr >> 8 ; &3D9A
	SUB 	L
	LD 		H,A											;; HL = PanelsBaseAddr + 2 x WorldId
	LD 		A,(HL)
	INC 	HL
	LD 		H,(HL)
	LD 		L,A											;; HL = Panels Base Addr for current WorldId
	LD 		(Walls_PanelBase),HL						;; Set the panel codes for the current world.
	LD A,&FF
	;; Recover the no door flag, stick the extent in A, push A and flag.
	EX AF,AF'
	LD A,C
	PUSH AF
	;; Find the location of the panel info we care about.
    ;; Extent = 4 -> B = &01
	SUB 4
	LD B,&01
	JR Z,owctd_1
	;; Extent = 5 -> B = &0F
	LD B,&0F
	INC A
	JR Z,owctd_1
	;; Extent = 6 -> B = &19
	LD B,&19
	INC A
	JR Z,owctd_1
	;; Otherwise, B = &1F
	LD B,&1F
owctd_1:
	POP AF
	JR c,owctd_2										;; No door? A' is &FF and we jump.
	;; We have a door
	LD A,C
	ADD A,A
	ADD A,B
	LD B,A												;; Add 2xC to B
	LD A,C
	EX AF,AF'											;; And put C (extent) in A'
	;; Skip B entries, to get the panels we want.
owctd_2:
	CALL FetchData2b
	DJNZ owctd_2
	;; Put 2x extent in B.
	LD B,C
	SLA B
	;; Then enter the wall-panel-processing loop.
.OWPanel:
	EX AF,AF'
	;; Loop through A panels, then hit OWDoor.
	DEC A
	JR Z,OWDoor
	;; Otherwise update entries in BackgrdBuff.
	EX AF,AF'
.smc_OWFlag:
	OR &00
	;;3D11 DEFB 00															; self-modifying code at 3D32, 3D51, 3C74, 3C8F adds a flip if needed.
	LD (IX+1),A											;; Set the wall-panel sprite
	EXX
	LD A,C
	ADD A,&08
	LD (IX+0),C											;; Y start of wall (0 = clear)
	LD C,A
	ADD IX,DE											;; Move to next panel (L or R)
	EXX
	CALL FetchData2b
.OWPanelLoop:
	DJNZ OWPanel
	EXX
	PUSH IX
	POP HL
	LD A,L
	CP &40
	RET NC
	;; If last entry is not clear, return
	LD A,(IX+0)
	AND A
	RET NZ
	;; If it is, add some Pillar.
	LD A,(smc_OWFlag+1)									;; read value of "OR ..." ; self mod code
	OR &05
	LD (IX+1),A
	LD A,C
	SUB &10
	LD (IX+0),A
	RET

.OWDoor:
	EXX
	LD A,(Walls_DoorZ)									;; DoorZ
	AND A
	LD A,C
	JR Z,br_3D4C
	ADD A,&10
	LD C,A
br_3D4C
	SUB &10
	LD (IX+0),A											;; Set height.
	LD A,(smc_OWFlag+1)									;; read value of "OR ..." ; self mod
	OR &04
	LD (IX+1),A											;; Set wall to blank.
	ADD IX,DE
	LD (IX+1),A											;; Ditto next slot.
	LD A,C
	SUB 8
	LD (IX+0),A											;; And lower for the next slot.
	ADD A,&18
	LD C,A
	LD A,(Walls_DoorZ)									;; DoorZ
	AND A
	JR Z,br_3D71
	LD A,C
	SUB &10
	LD C,A
br_3D71
	ADD IX,DE
	LD A,&FF
	EX AF,AF'
	EXX
	DEC B
	JR OWPanelLoop

;; -----------------------------------------------------------------------------------------------------------
;; Fetch 2 bits from data in CurrData, returned in A
;; CurrData and DataPtr updated as needed
.FetchData2b:
	PUSH 	BC
	LD 		B,&02										;; number of bit to fetch from CurrData
	CALL 	FetchData									;; fetch 2 bits in A
	POP 	BC
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Gets values associated with the far back corner of the screen.
;; IY must point just after Max_min_UV_Table. (IY=Max_min_UV_Table+4)
;; Returns X in B, Y in C, BackgrdBuff pointer in HL
.GetCorner:
	LD 		A,(IY-2)									;; IY-&02 = Max_min_UV_Table+2 = MaxU
	LD 		D,A
	LD 		E,(IY-1)									;; IY-&01 = Max_min_UV_Table+3 = MaxV ; DE = MaxU;MaxV
	SUB 	E											;; A = difference between those 2 values
	ADD 	A,&80
	LD 		B,A											;; B = &80 + (MaxU - MaxV) = X coord
	RRA
	RRA													;; A = B/4
	AND 	&3E											;; align on even value (word align)
	LD 		L,A											;; L can be &20 to &3E
	LD 		H,BackgrdBuff / 256							;; &6A = H = BackgrdBuff >> 8; HL = BackgrdBuff buffer word address
	LD 		A,&07
	SUB 	E
	SUB 	D											;; 7 - (MaxV + MaxU)
	LD 		C,A											;; return that value in C = Y coord
	RET

;; -----------------------------------------------------------------------------------------------------------
;; This table returns a pointer on the base wall panel for the current
;; world. From that base value, the Panel_WorldData will add an offset
;; to pick the wall panel we want for each part of the wall.
.PanelsBaseAddr:								;; panel images base addr
	DEFW 	img_blacktooth_walls + MOVE_OFFSET			;; img_wall_deco + &70 * 0  + MOVE_OFFSET ; 70F0 Blacktooth		; worldID 0
	DEFW 	img_market_walls + MOVE_OFFSET				;; img_wall_deco + &70 * 3  + MOVE_OFFSET ; 7390 Market			; worldID 1
	DEFW 	img_egyptus_walls + MOVE_OFFSET				;; img_wall_deco + &70 * 6  + MOVE_OFFSET ; 7630 Egyptus		; worldID 2
	DEFW 	img_penitentiary_walls + MOVE_OFFSET		;; img_wall_deco + &70 * 8  + MOVE_OFFSET ; 77F0 Penitentiary	; worldID 3
	DEFW 	img_moonbase_walls + MOVE_OFFSET			;; img_wall_deco + &70 * 10 + MOVE_OFFSET ; 79B0 Moon base		; worldID 4
	DEFW 	img_bookworld_walls	+ MOVE_OFFSET			;; img_wall_deco + &70 * 14 + MOVE_OFFSET ; 7D30 Book world		; worldID 5
	DEFW 	img_safari_walls + MOVE_OFFSET				;; img_wall_deco + &70 * 16 + MOVE_OFFSET ; 7EF0 Safari			; worldID 6
	DEFW 	img_prison_walls + MOVE_OFFSET				;; img_wall_deco + &70 * 19 + MOVE_OFFSET ; 8190 Prison			; worldID 7

;; -----------------------------------------------------------------------------------------------------------
;; Used when Wall building.
;; These data consists of packed 2-bit values to choose the panel sprite
;; to pick for each part of the wall. It is essentially an index to add
;; to PanelsBaseAddr
.Panel_WorldData:
	DEFB 	&46, &91, &65, &94, &A1, &69, &69, &AA    		;; 1 0 1 2 2 1 0 1 ...  Blacktooth	; worldID 0
	DEFB 	&49, &24, &51, &49, &12, &44, &92, &A4    		;; 1 0 2 1 0 2 1 0 ...  Market		; worldID 1
	DEFB 	&04, &10, &10, &41, &04, &00, &44, &00    		;; 0 0 1 0 0 1 0 0 ...  Egyptus		; worldID 2
	DEFB 	&04, &10, &10, &41, &04, &00, &10, &00    		;; 0 0 1 0 0 1 0 0 ...  Penitentiary; worldID 3
	DEFB 	&4E, &31, &B4, &E7, &4E, &42, &E4, &99    		;; 1 0 3 2 0 3 0 1 ...  Moon base	; worldID 4
	DEFB 	&45, &51, &50, &51, &54, &55, &55, &55    		;; 1 0 1 1 1 1 0 1 ...  Book world	; worldID 5
	DEFB 	&64, &19, &65, &11, &A4, &41, &28, &55    		;; 1 2 1 0 0 1 2 1 ...  Safari		; worldID 6
	DEFB 	&00, &00, &00, &00, &00, &00, &00, &00	 		;; in the Prison we always use the same wall panel 0; worldId 7

;; -----------------------------------------------------------------------------------------------------------
;; Bit mask of worlds saved (5 bits : "1" means got crown for corresponding world).
;; This will be used to count how many worlds have been saved.
.saved_World_Mask:
	DEFB 	&00

;; -----------------------------------------------------------------------------------------------------------
;; Special collectible items.
;; The first word is the little-endian roomID, the next word is the little-endian
;; representation of "UVY + SpriteID". Sprite ID is the index in SpecialSprites.
;; Note: the first byte (room id low byte), will be added "1" (bit0 set) when
;; the item has been picked up, so can no longer be found during search when
;; building the room.
;; There are 47 special items in ths table. Adding the victoryRoom_Crowns 5 crowns
;; to this, it reaches 52 (&34) special objects.
.tab_Specials_collectible:
	;; <roomID word little-endian> <low byte : Z|SPR&> <high byte : UV> x 47
	DEFW 	&1470, &7200				;; speId 0 : room id 1470 : U,V,Z = 7,2,0 + sprite Id 0 in SpecialSprites = SPR_PURSE
	DEFW 	&3060, &4001				;; Hooter
	DEFW 	&2EB0, &3409				;; Egyptus Crown
	DEFW 	&00B0, &001A				;; Penitentiary Crown
	DEFW 	&9AF0, &700B				;; Safari Crown
	DEFW 	&A740, &441C				;; Book World Crown
	DEFW 	&3730, &377D				;; Emperor Crown
	DEFW 	&1570, &3468				;; Fish
	DEFW 	&8960, &4748
	DEFW 	&C560, &7668
	DEFW 	&1B80, &7668
	DEFW 	&BCD0, &3528
	DEFW 	&1CD0, &7128				;; ...
	DEFW 	&87F0, &7438
	DEFW 	&FB20, &7128
	DEFW 	&3160, &0548
	DEFW 	&E2C0, &5438
	DEFW 	&6920, &0768				;; Fish
	DEFW 	&5260, &7762				;; Donuts Tray
	DEFW 	&4760, &2772
	DEFW 	&E3C0, &0742
	DEFW 	&63F0, &7012				;; ...
	DEFW 	&AA20, &0522
	DEFW 	&6C30, &4622				;; Donuts Tray
	DEFW 	&4760, &5773				;; Bunny Speed
	DEFW 	&FA80, &6763				;; ...
	DEFW 	&70F0, &6013
	DEFW 	&7B10, &3173				;; Bunny Speed
	DEFW 	&6460, &7074				;; Bunny Spring
	DEFW 	&1A80, &4544				;; ...
	DEFW 	&46F0, &7474				;; Bunny Spring
	DEFW 	&C560, &7466				;; Bunny Lives
	DEFW 	&9870, &0076
	DEFW 	&3200, &5076
	DEFW 	&2980, &4076				;; ...
	DEFW 	&E0A0, &4016
	DEFW 	&0FA0, &4766
	DEFW 	&03B0, &4426
	DEFW 	&83F0, &1736
	DEFW 	RoomID_Head_1st, &0606	;; speId 39 roomID &8A40 : UVZ=060 + Sprite6 in SpecialSprites = BUNNY (lives); Initial Head's Room
	DEFW 	&9920, &1476				;; Bunny Lives
	DEFW 	&C560, &7565				;; Bunny Shield
	DEFW 	&7760, &4475
	DEFW 	&3600, &6675
	DEFW 	&FEA0, &2275				;; ...
	DEFW 	&42F0, &6165
	DEFW 	&AE20, &0475				;; speId 46 : Bunny Shield

;; -----------------------------------------------------------------------------------------------------------
;; This is used when drawing the Victory Room to show (or not) a crown
;; corresponding to the saved worlds.
;; Therfore, the room ID is always &8D30 (victory room ID). However, the bit0
;; of the roomID will be updated by AddSavedCrowns_and_SpecialItems depending on
;; if the corresponding world has been saved (0) or not (1).
;; If not saved, roomID bit0 will therfore be '1' so that it is not found
;; during the search in Find_Specials (hence not displayed in victory room).
;; Second data word is the little-endian representation of UVZ+SpriteCode.
;; The SpriteCode always is &E so from SpecialSprites+&E we get SPR_CROWN (&2F).
;; Also note that this table is part of the tab_Specials_collectible table, hence
;; the first item below (Egyptus Crown in Victory room), is the special item n°47
;; because Ids 0 to 46 are in the tab_Specials_collectible table.
.victoryRoom_Crowns:
	;; <roomID word little-endian> <low byte : Z|SPR&> <high byte : UV>
	DEFW 	RoomID_Victory, &477E 				;; speid47 : Egyptus            : 477E = U=4, V=7, Z=7, SPR_CROWN
	DEFW 	RoomID_Victory, &176E 				;; speid48 : Penitentiary       : 176E = U=1, V=7, Z=6, SPR_CROWN
	DEFW 	RoomID_Victory, &077E 				;; speid49 : Safari             : 077E = U=0, V=7, Z=7, SPR_CROWN
	DEFW 	RoomID_Victory, &376E 				;; speid50 : Book World         : 376E = U=3, V=7, Z=6, SPR_CROWN
	DEFW 	RoomID_Victory, &273E 				;; speid51 : BlackTooth Emperor : 273E = U=2, V=7, Z=3, SPR_CROWN

;; -----------------------------------------------------------------------------------------------------------
;; These are the sprites ID associated with special collectible objects.
;; e.g. Special obj Id &02 is "Donuts"
.SpecialSprites:
	DEFB 	SPR_PURSE, SPR_HOOTER, SPR_DONUTS, SPR_BUNNY	;; SPR_PURSE, SPR_HOOTER, SPR_DONUTS, SPR_BUNNY (Speed)
	DEFB 	SPR_BUNNY, SPR_BUNNY, SPR_BUNNY, &00			;; SPR_BUNNY (Spring), SPR_BUNNY (invuln), SPR_BUNNY (lives), 0
	DEFB 	ANIM_FISH, SPR_CROWN, SPR_CROWN, SPR_CROWN		;; ANIM_FISH, SPR_CROWN (Egyptus), SPR_CROWN (Penitentiary), SPR_CROWN (Safari)
	DEFB 	SPR_CROWN, SPR_CROWN, SPR_CROWN					;; SPR_CROWN (book world), SPR_CROWN (emperor), SPR_CROWN (victory room)

;; -----------------------------------------------------------------------------------------------------------
;; Looking for the room Id in the special items table and point HL
;; on the special item in it
;; 2 Functions:
;;  * Find_Specials_current
;;  * Find_Specials : this one will need the room ID in BC.
;; Output: Found:     Z=1, Carry=0 ; HL pointing on 2nb byte of object in tab_Specials_collectible
;;         Not Found: Z=0; Carry=1
.Find_Specials_current:
	LD BC,(current_Room_ID)								;; BC = current_Room_ID
.Find_Specials:																;; if branching directly here BC must have the roomID we want
	LD HL,tab_Specials_collectible
	LD E,&34											;; number of special items (&34=52) in tab_Specials_collectible+victoryRoom_Crowns tables
findspec_loop:
	LD A,C												;; low byte room ID
	CP (HL)												;; compare byte in table with roomid we are lloking for
	INC HL												;; next byte
	JR NZ,FindSpecCont									;; no match, skip to FindSpecCont, else:
	LD A,B												;; low byte matched so match the high byte room id part
	CP (HL)												;; compare
	RET Z												;; Found! Ret Z set Carry reset
.FindSpecCont:																;; else not yet found
	INC HL
	INC HL
	INC HL												;; skip 3 bytes to next room ID in table
	DEC E												;; dec E
	JR NZ,findspec_loop									;; if E not 0, loop, else:
	DEC E												;; Nothing found; E=FF, Z = reset, Carry = set
special_found_end_2:
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Takes a pointer in HL, increase it, and extracts the nibbles in E, D, B and C.
;; RLD : if A = 0000aaaa, (HL) = hhhhllll, then after RLD we have:
;;          A = 0000hhhh, (HL) = llllaaaa
.GetNibbles:
	INC 	HL
	XOR 	A
	RLD													;; RLD = nibbles circular left rotation in the 12b value composed by A[3:0] and (HL)
	LD 		E,A											;; E gets high 4 bits of *(HL+1).
	RLD													;; RLD = nibbles circular left rotation in the 12b value composed by A[3:0] and (HL)
	LD 		D,A     									;; D gets next 4 bits of *(HL+1).
	RLD													;; RLD = nibbles circular left rotation in the 12b value composed by A[3:0] and (HL)
	INC 	HL
	RLD													;; RLD = nibbles circular left rotation in the 12b value composed by A[3:0] and (HL)
	LD 		B,A		    								;; B gets high 4 bits of *(HL+2).
	RLD													;; RLD = nibbles circular left rotation in the 12b value composed by A[3:0] and (HL)
	LD 		C,A	     									;; C gets next 4 bits of *(HL+2).
	RLD													;; RLD = nibbles circular left rotation in the 12b value composed by A[3:0] and (HL)
	RET

;; -----------------------------------------------------------------------------------------------------------
;; This updates which of the 5 crowns will be shown in the victory room
;; from the saved_World_Mask value.
.AddSavedCrowns_and_SpecialItems:
	PUSH 	BC											;; save curr room_ID
	LD 		HL,victoryRoom_Crowns						;; point on the 5 crowns in the victory room
	LD 		A,(saved_World_Mask)						;; get saved_World_Mask
	CPL													;; invert all bits of A (so we get 0=saved=match, and 1=not-saved=no-match)
	LD 		B,5											;; 5 crowns
	LD 		DE,&0004									;; 4 bytes per entry in the victoryRoom_Crowns table
addcrowns_loop:
	RR 		(HL)										;; This loop replaces the bit 0 of (HL) n°i (i 0 to 4) [= low byte of room ID in the crown search table]....
	RRA													;; ...with the bit n°i in A (saved world (complement))...
	RL 		(HL)										;; ...to indicate if we saved the corresponding world (currbit=0, will match during search in victoryRoom_Crowns table)
	ADD 	HL,DE										;; ...or if we did not save it (currbit=1 will no longer match during search)
	DJNZ 	addcrowns_loop								;; ...so that, in the victory room, only the saved worlds crowns will be shown.
	POP 	BC											;; When the 5 worlds have been updated, restore curr room id
	CALL 	Find_Specials								;; Add special items in the room; if found HL points on 2nd byte in tab_Specials_collectible
addspe_loop:
	RET 	NZ											;; RET if not found, else:
	;; special item found:
	PUSH 	HL
	PUSH 	DE
	PUSH 	BC											;; Save everything (so we can relaunch a search if multiple special items in the room)
	PUSH 	IY
	CALL 	GetNibbles									;; Fills in E, D from (HL+1) and B, C from (HL+2); HL will be incremented by 2 ; since HL was pointing on 2nd byte of object in tab_Specials_collectible, it gets E = Z, D = SPR, B = U, C = V
	LD 		IY,TmpObj_variables
	LD 		A,D											;; Special Sprite ID in D ; (E = Z, D = SPR, B = U, C = V)
	CP 		&0E											;; 0E is the Victory room SPR_CROWN sprite id in SpecialSprites, other special sprites are Purse, Hooter, Donut tray, Fish, Bunnies and World crowns. Note that the worlds crowns are not the victory room crowns.
	LD 		A,&60
	JR 		NZ,br_3F25									;; if Victory room Crown then O_FLAGS = 0, else O_FLAGS = &60
	XOR		A
br_3F25
	LD 		(IY+O_FLAGS),A            					;; Set or reset (for victory room crowns) flags
	LD 		(IY+O_SPECIAL),D        					;; Set special item sprite index in SpecialSprites.
	LD 		(IY+O_FUNC),OBJFN_SPECIAL					;; Set the object function OBJFN_SPECIAL
	LD		A,D											;; index of special item in SpecialSprites
	ADD 	A,SpecialSprites and &00FF					;; &BB = SpecialSprites & FF
	LD 		L,A
	ADC 	A,SpecialSprites / 256						;; &3E = SpecialSprites >> 8  ; 3EBB+offset
	SUB 	L
	LD 		H,A											;; HL = pointer on sprite code in SpecialSprites ; HL = SpecialSprites + sprite_index
	LD 		A,(HL)										;; A = Sprite code for special item
	PUSH 	BC											;; save UV
	PUSH 	DE											;; and SPR + Z
	CALL 	SetObjSprite
	POP 	DE
	POP 	BC											;; restore UVZ+SPR, BC = UV, DE=SPR,Z
	POP 	IY
	LD 		A,E											;; A = Z
	CALL 	SetTmpObjUVZ
	CALL 	AddObjOpt

	POP 	BC
	POP 	DE											;; Restore state and carry on.
	POP 	HL
	CALL 	FindSpecCont
	JR 		addspe_loop

;; -----------------------------------------------------------------------------------------------------------
;; Reset the "collected" flag (bit0) on all the specials.
.ResetSpecials:
	LD HL,tab_Specials_collectible						;; in special collectible table
	LD DE,&0004											;; every 4 bytes in the table is the low byte for roomID
	LD B,&34											;; &34=52 special obj
rstspe_loop:																;; when the item was picked up, the bit0 was set (so we could not pick it up again)
	RES 0,(HL)											;; so reset it to reinit it
	ADD HL,DE
	DJNZ rstspe_loop									;; and do it for all 52 special objects
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Get a special item. Id in A
.GetSpecial:
	LD 		D,A											;; store special we want in D
	CALL 	Find_Specials_current						;; Find Specials in current_Room_ID (HL points on 2bd byte of object in tab_Specials_collectible)
getspe_1:
	RET 	NZ											;; leave if not found, else:
	INC		HL											;; point on special object <low byte : Z|SPR&>  (<high byte : UV)
	LD 		A,(HL)										;; get special obj value
	DEC 	HL											;; this is just to realign HL if we loop
	AND 	&0F											;; only look at bits [3:0] : Sprite ID in Special items
	CP 		D											;; compare witch the one we want
	JR 		Z,getspe_found								;; jump getspe_found if found, else:
	CALL 	FindSpecCont								;; not the one we want, go to the next items until "00"
	JR 		getspe_1									;; loop

getspe_found:
	DEC 	HL											;; point back on room ID in table
	SET 	0,(HL)										;; set bit 0 of room ID low byte; so this item is no longer available (we picked it up already)
	ADD 	A,A											;; *2 (word align)
	ADD 	A,SpecialFns and &00FF						;; &89 : SpecialFns & &FF
	LD 		L,A
	ADC 	A,SpecialFns / 256							;; &3F : SpecialFns >> 8 : &3F89 + special obj offset
	SUB 	L
	LD 		H,A											;; SpecialFns + 2A
	LD 		E,(HL)
	INC 	HL
	LD 		H,(HL)
	LD 		L,E											;; get in HL the addr of the special function from SpecialFns table
	LD 		IX,special_found_end_1						;; Set IX to the continuation point after the JP (HL) is done
	JP 		(HL)										;; jump to the selected special function (PickUp2, Boost*, SaveContinue, GetCrown)

special_found_end_1:
	LD 		B,Sound_ID_DumDiddyDum						;; Sound ID Dum-diddy-dum
	JP 		Play_Sound									;; will RET

;; -----------------------------------------------------------------------------------------------------------
;; Array of functions pointers when picking up a special item.
;; For exemple when picking up the special item 'Donuts', we will
;; run the function at address "3FB4" : BoostDonuts.
.SpecialFns:
	DEFW 	PickUp2					;; 0 : Purse PickUp2	3FA5
	DEFW 	PickUp2					;; 1 : Hooter PickUp2	3FA5
	DEFW 	BoostDonuts				;; 2 : Donuts BoostDonuts 3FB4
	DEFW 	BoostSpeed				;; 3 : Bunny BoostSpeed 3FC3
	DEFW 	BoostSpring				;; 4 : Bunny BoostSpring 3FCC
	DEFW 	BoostInvuln				;; 5 : Bunny BoostInvuln 3FD8
	DEFW 	BoostLives				;; 6 : Bunny BoostLives 3FDC
	DEFW 	&0000					;; 7 :
	DEFW 	SaveContinue			;; 8 : Fish SaveContinue 4025
	DEFW 	GetCrown				;; 9 : Crown GetCrown 4014
	DEFW 	GetCrown				;; &A : Crown GetCrown 4014
	DEFW 	GetCrown				;; &B : Crown GetCrown 4014
	DEFW 	GetCrown				;; &C : Crown GetCrown 4014
	DEFW 	GetCrown				;; &D : Crown GetCrown 4014 (Emperor)

;; -----------------------------------------------------------------------------------------------------------
;; Pickup Purse or Hooter, update Inventory and update HUD
;; PickUp2 : D has the bitnb for the item: Purse bit 0, Hooter bit 1
;; Pick_it_up : item bitnb in A (eg. bit 2 = donut tray)
.PickUp2:
	LD 		A,D											;; item bir nb
.Pick_it_up:
	LD 		HL,Inventory								;; point on Inventory
	CALL 	Set_bit_nb_A_in_content_HL					;; add item bit to Inventory
	CALL 	Draw_Screen_Periphery						;; update HUD
	LD 		B,Sound_ID_Hornpipe							;; Sound ID HornPipe
	JP 		Play_Sound									;; will RET

;; -----------------------------------------------------------------------------------------------------------
;; pick up a donut tray
.BoostDonuts:
	LD 		A,(selected_characters)						;; get selected_characters
	AND 	&02											;; test if Head
	RET 	Z											;; if not Head, then leave
	LD 		A,CNT_DONUTS
	CALL 	BoostCountPlus								;; boost counter
	LD 		A,&02										;; bit2 in Inventory for pick-up a donuts tray
	JR 		Pick_it_up									;; add it to inventory and update HUD

;; -----------------------------------------------------------------------------------------------------------
;; Pick up a Bunny. 4 types of Bunnies : lives, invulnerability, speed, extra jump.
.BoostSpeed:
	LD 		A,(selected_characters)						;; get selected_characters
	AND 	&02											;; test if Head
	RET 	Z											;; if not Head, then leave
	XOR		A											;; code for CNT_SPEED
	JR 		BoostCountPlus								;; Boost!

.BoostSpring:
	LD 		A,(selected_characters)						;; get selected_characters
	AND 	&01											;; test if Heels
	RET 	Z											;; if not Heels, then leave
	JR 		BoostCountPlus								;; A = 01, code for CNT_SPRING, boost

;; heels : c=2; a=b01 a=0 cy=1 a=2 push a ret
;; head : c=2 a=b10 a=1 cy=0 a=3 push a ret
;; both : c=2 a=b11 a=2 call boostcount (boost heels invul and refresh HUD) a=3 push a ret
.BoostInvuln2:
	LD 		IX,special_found_end_2						;; the DoJumpIX will just RET
.BoostInvuln:
	LD 		C,CNT_HEELS_INVULN
	JR 		BoostMaybeDbl

.BoostLives:
	LD 		C,CNT_HEELS_LIVES
;; Boosts both characters counts if they're joined. Only works for
;; invuln and lives.
.BoostMaybeDbl:
	LD 		A,(selected_characters)						;; get selected_characters
	CP 		&03											;; both Head and Heels?
	JR 		Z,BoostCountDbl								;; if yes, then increment both (invuln if coming from BoostInvuln or lives if coming from BoostLives) (BoostCountDbl), else:
	RRA													;; bit Head in bit0, bit Heels in Carry
	AND 	1											;; if Head increment, if Heels add 0
	ADD 	A,C											;; coming from BoostLives : either CNT_HEELS_LIVES or CNT_HEAD_LIVES ; coming from BoostInvuln : either CNT_HEELS_INVULN or CNT_HEAD_INVULN
	JR 		BoostCountPlus								;; boost

;; Head and Heels are joined : increment both counters
;; This can come from BoostLives (lives) or BoostInvuln (invuln)
.BoostCountDbl:
	LD 		A,C											;; counter for Heels
	PUSH 	AF
	CALL 	BoostCount									;; boost
	POP 	AF
	INC 	A											;; counter for Head
.BoostCountPlus:
	PUSH 	AF
	CALL 	DoJumpIX									;; this does a JP (IX); coming from BoostInvuln2 it'll just RET (special_found_end_2), or a Sound+RET (special_found_end_1) if coming from a Special item function
	POP 	AF
.BoostCount:
	;; Boosts whichever count index is provided in A, and displays it.
	;; 0: speed, 1: spring, 2:Heels Invul, 3: Head Invul,
	;; 4:Heels Lives, 5:Head Lives, 6:Donuts
	CALL 	Get_Count_pointer							;; HL=pointer on counter at index in A; output A=increment
	CALL 	Boost_HLcontent_base10_clamp99 				;; AddBCD clamped
.Show_Num:
	;; Number to print in A, location in C.
	PUSH 	AF
	PUSH 	BC
	AND 	A
	LD 		A,Print_Color_Attr_1						;; color1 when printing 0
	JR 		Z,fsnum_1									;; was "0" else:
	LD 		A,Print_Color_Attr_3						;; color3 if not 0
fsnum_1:
	CALL 	Print_String								;; Print new count on HUD
	POP 	BC
	LD 		A,C
	ADD 	A,&B1										;; B1 = Ligthning ; Position indexed into array...
	CALL 	Print_String
	POP 	AF
	JP 		Print_2Digits_RightAligned					;; print value in A, right aligned; will RET

;; -----------------------------------------------------------------------------------------------------------
;; Pick up a crown; WorldId in D
.GetCrown:
	LD 		A,D											;; special item ID
	SUB 	9											;; in SpecialFns the GetCrown are items 9 to &E so align it at 0 (world nb)
	LD 		HL,saved_World_Mask							;; points on saved_World_Mask
	CALL 	Set_bit_nb_A_in_content_HL					;; set the bit N (N in A) in (HL) corresponding to the world we saved.
	LD 		B,Sound_ID_Tada								;; Sound_ID &C1 = "Tada!"
	CALL 	Play_Sound									;; play
	JP 		Emperor_Screen_Cont							;; display the "Emperor" screen if we got 5 crowns

;; -----------------------------------------------------------------------------------------------------------
;; Pick up a Fish (save points)
.SaveContinue:
	LD B,Sound_ID_Hornpipe								;; Sound_ID &C2 = Hornpipe
	CALL Play_Sound
	CALL GetContinueData								;; get current save array (18 bytes)
	LD IX,tab_Specials_collectible
	LD DE,&0004
	LD B,&06
savecont_1:
	LD (HL),&80
savecont_2:
	LD A,(IX+0)
	ADD IX,DE
	RRA
	RR (HL)
	JR NC,savecont_2
	INC HL
	DJNZ savecont_1
	EX DE,HL
	LD HL,Save_point_value								;; Save point value (Continues)
	INC (HL)											;; incr the number of active save point
	LD HL,selected_characters							;; points on selected_characters
	LD A,(HL)											;; save selected char first byte
	LDI													;; do once : LD (DE),(HL); DE++, HL++, BC--
	LD HL,Characters_lives								;; point on Characters_lives
	LDI													;; do once : LD (DE),(HL); DE++, HL++, BC--
	LDI													;; do once : LD (DE),(HL); DE++, HL++, BC--
	CP &03
	JR Z,SaveContinue_3
	LD HL,&2496											;; ???
	CP (HL)
	JR NZ,SaveContinue_3
	LD HL,&BB31											;; save 4 bytes in buffer
	LD BC,&0004
	LDIR												;; repeat LD (DE),(HL); DE++, HL++, BC-- until BC=0
	LD HL,Other_Character_state + MOVE_OFFSET
	JR SaveContinue_4
.SaveContinue_3
	LD HL,&2492											;; SaveRestore_Block3
	LD BC,&0004
	LDIR												;; repeat LD (DE),(HL); DE++, HL++, BC-- until BC=0
	LD HL,current_Room_ID								;; point on current_Room_ID
.SaveContinue_4:
	LDI													;; do once : LD (DE),(HL); DE++, HL++, BC--
	LDI													;; do once : LD (DE),(HL); DE++, HL++, BC--
	LD HL,current_Room_ID								;; point on current_Room_ID
	LDI													;; do once : LD (DE),(HL); DE++, HL++, BC--
	LDI													;; do once : LD (DE),(HL); DE++, HL++, BC--
	RET

;; -----------------------------------------------------------------------------------------------------------
.DoContinue:
	LD HL,Save_point_value								;; Save point value
	DEC (HL)											;; use a save point
	CALL GetContinueData
	LD A,(HL)
	AND &03
	LD (Inventory),A									;; update inventory
	LD A,(HL)
	RRA
	RRA
	AND &1F
	LD (saved_World_Mask),A								;; update saved_World_Mask
	PUSH HL
	POP IX
	LD HL,tab_Specials_collectible
	LD DE,&0004
	LD B,&2F
	RR (HL)
	JR br_40B3

doco_loop:
	RR (HL)
	SRL (IX+0)
	JR NZ,br_40B8
	INC IX
br_40B3
	SCF
	RR (IX+0)
br_40B8
	RL (HL)
	ADD HL,DE
	DJNZ doco_loop
	PUSH IX
	POP HL
	INC HL
	LD DE,selected_characters							;; points on selected_characters
	LD A,(HL)
	LDI													;; do once : LD (DE),(HL); DE++, HL++, BC--
	LD DE,Characters_lives								;; point on Characters_lives
	LDI													;; do once : LD (DE),(HL); DE++, HL++, BC--
	LDI													;; do once : LD (DE),(HL); DE++, HL++, BC--
	LD DE,access_new_room_code							;; point on access_new_room_code
	LDI													;; do once : LD (DE),(HL); DE++, HL++, BC--
	BIT 0,A
	LD DE,Heels_variables+O_U							;; ??? Heels U?
	JR Z,br_40DD
	LD DE,Head_variables+O_U							;; ??? Head U?
br_40DD
	LD BC,&0003
	LDIR												;; repeat LD (DE),(HL); DE++, HL++, BC-- until BC=0
	LD DE,current_Room_ID								;; point on current_Room_ID
	LDI													;; do once : LD (DE),(HL); DE++, HL++, BC--
	LDI													;; do once : LD (DE),(HL); DE++, HL++, BC--
	CP &03
	JR Z,dconti_1
	LD BC,(Characters_lives)							;; get Characters_lives
	DEC B
	JP M,dconti_1
	DEC C
	JP M,dconti_1
	XOR &03
	LD (Other_Character_state + MOVE_OFFSET),A
	PUSH HL
	CALL InitOtherChar
	POP HL
dconti_1:
	LD DE,current_Room_ID								;; point on current_Room_ID
	LDI													;; do once : LD (DE),(HL); DE++, HL++, BC--
	LDI													;; do once : LD (DE),(HL); DE++, HL++, BC--
	LD BC,(current_Room_ID)								;; get current_Room_ID
	SET 0,C
	CALL Find_Specials
	CALL GetNibbles										;; Fills in E, D from (HL+1) and B, C from (HL+2); HL will be incremented by 2
	LD A,E
	EX AF,AF'
	LD DE,UVZ_coord_Set_UVZ
	LD HL,UVZ_origin
	CALL Set_UVZ
	LD A,&08											;; room access code 8 = ???
	LD (access_new_room_code),A							;; update access_new_room_code
	LD (Teleport_down_anim_length),A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Output : HL points on the Continue_Data data for the Save point in Save_point_value
.GetContinueData:
	LD 		A,(Save_point_value)						;; Continues Save point value
	LD 		B,A
	INC 	B											;; get which save point we need to restore
	LD 		HL,Continue_Data - OBJECT_LENGTH			;; Continue_Data (4195) - &12 (because it'll get added &12 just next)
	LD 		DE,OBJECT_LENGTH							;; Character obj size
gcdta_loop:
	ADD 	HL,DE										;; (Continue_Data + &12) B times
	DJNZ 	gcdta_loop									;; loop until HL points on the data
	RET

;; -----------------------------------------------------------------------------------------------------------
;; This function will set a bit (bit number in A) in a byte pointed by HL, leaving the
;; other bits in (HL) untouched.
;; Input: A: the bit number to set
;;        HL: the pointer on the data byte where to set the bit.
.Set_bit_nb_A_in_content_HL:
	LD 		B,A											;; bit numbrer to set
	INC 	B											;; converted as number of rotations
	LD 		A,&80										;; start with wandering bit in bit7
fsbn_loop:
	RLCA
	DJNZ 	fsbn_loop									;; left rotate B times to put the 1 in bit n°A
	OR 		(HL)										;; read value in (HL) and set a 1 in bit n°A
	LD 		(HL),A										;; write the result back in (HL)
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Decrement one of the core counters and re-display it.
;; Input : A can be: 0: speed, 1: spring, 2:Heels Invul, 3: Head Invul, 4:Heels Lives, 5:Head Lives, 6:Donuts
.Decrement_counter_and_display:
	CALL 	Get_Count_pointer							;; HL=pointer on Counter corresponding to the index in A when calling; output A=increment
	CALL 	Sub_1_HLcontent_base10_clamp0				;; minus 1
	RET 	Z											;; if was already 0, then leave with Z set, else:
	LD 		A,(HL)										;; get new val after "minus 1"
	CALL 	Show_Num									;; display it
	OR 		&FF											;; Ret with Z reset
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Re-prints all the Counters values on the HUD.
.PrintStatus:
	LD 		A,Print_StringID_Icons						;; String code B8 = shield, spring, shield, lightning icons
	CALL 	Print_String								;; print icons
	LD 		A,7											;; 7 Counters
prntstat_1:
	PUSH 	AF
	DEC 	A											;; foreach counter starting at n° 6
	CALL 	Get_Count_pointer							;; HL = pointer on counter
	LD 		A,(HL)										;; Counter value
	CALL 	Show_Num									;; print value
	POP 	AF
	DEC 	A											;; next counter
	JR 		NZ,prntstat_1								;; loop counters id 6 to 0
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Increment the Counter pointer by HL with the increment value in A.
;; Output: Carry reset: counter incremented;
;;         Carry set: counter incremented and clamped at 99
.Boost_HLcontent_base10_clamp99:
	ADD 	A,(HL)										;; add selected increment to counter pointed by HL
	DAA													;; base10 adjust
	LD 		(HL),A										;; update value
	RET 	NC											;; if not overflowed 99 leave with Carry reset, else:
	LD 		A,&99										;; clamp at 99
	LD 		(HL),A										;; update the value to reflect this
	RET													;; Ret with Carry set

;; -----------------------------------------------------------------------------------------------------------
;; Input: HL = pointer on the counter we want to decrement (by 1)
;; Output: A=0/Zset : was already 0 (clapmed at 0);
;;         A=-1/Zreset : value in (HL) decremented by 1
.Sub_1_HLcontent_base10_clamp0:
	LD 		A,(HL)										;; get value
	AND 	A											;; test
	RET 	Z											;; if 0, leave with A=0 and Z set, else:
	SUB 	1											;; minus 1
	DAA													;; base10 adjusted
	LD 		(HL),A										;; update counter value
	OR 		&FF											;; leave with A=-1 and Z reset
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Given a count index in A, return the corresponding counter increment
;; and Counters address in HL.
;; Input: A can be 0: speed, 1: spring, 2:Heels Invul, 3: Head Invul, 4:Heels Lives, 5:Head Lives, 6:Donuts
;; If access_new_room_code is non-zero, return 3 as the increment. (dec invulnr counters by 3 if changing room ???)
;; Output: A increment value
;;        HL selected Counter pointer
;; Leaves the counter index in BC.
.Get_Count_pointer:
	LD 		C,A
	LD 		B,0											;; BC=index in A
	LD 		HL,CounterIncrements
	ADD 	HL,BC										;; add BC as offset of CounterIncrements table
	LD 		A,(access_new_room_code)					;; get access_new_room_code
	AND 	A											;; test it
	LD 		A,(HL)										;; get counter increment value
	JR 		Z,gcnt_1									;; if access_new_room_code = 0 (stay same room) return counter increment from table
	LD 		A,3											;; else (access a new room) return increment of 3 in A
gcnt_1:
	LD 		HL,Counters									;; Points on start of array Counters
	ADD 	HL,BC										;; and add item offset, now points on the counter
	RET

;; -----------------------------------------------------------------------------------------------------------
CNT_SPEED				EQU 	0
CNT_SPRING				EQU 	1
CNT_HEELS_INVULN		EQU 	2
CNT_HEAD_INVULN			EQU 	3
CNT_HEELS_LIVES			EQU 	4
CNT_HEAD_LIVES			EQU 	5
CNT_DONUTS				EQU 	6

;; -----------------------------------------------------------------------------------------------------------
;; These are the BCD values by how much the corresponding counters
;; are increased when picking up a Bunny or Donuts tray
CounterIncrements:
	DEFB 	&99        		;; 00 CNT_SPEED			+99 time
	DEFB 	&10				;; 01 CNT_SPRING		+10 amount
	DEFB 	&99       		;; 02 CNT_HEELS_INVULN	+99 time
	DEFB 	&99   			;; 03 CNT_HEAD_INVULN	+99 time
	DEFB 	2    			;; 04 CNT_HEELS_LIVES	+2 amount
	DEFB 	2   			;; 05 CNT_HEAD_LIVES	+2 amount
	DEFB 	6				;; 06 CNT_DONUTS		+6 amount

;; -----------------------------------------------------------------------------------------------------------
.Save_point_value:
	DEFB 	&00				;; (Continues) Save-point value (living fish comsumed)

;; A bunch of &12 (18) bytes arrays for save points
;; (up to 11 Living Fish are defined in the room data hence the 11*18 size)
;; The default values are probably "don't care"
.Continue_Data:
	;; Default Values do not matter, they'll be overwritten :
	;; should do a  DEFS 18*11,&00
	DEFB 	&FF, &21, &00, &F8, &CD, &41, &4D, &F6, &01, &D1, &C9, &CD, &17, &28, &C3, &4, &6C, &CD
	DEFB 	&67, &1D, &21, &DA, &76, &CD, &AD, &6A, &CD, &87, &55, &CD, &67, &1D, &CD, &8, &43, &CD
	DEFB 	&AF, &5F, &21, &00, &00, &22, &73, &76, &C3, &67, &1D, &3A, &74, &76, &B7, &A, &D6, &4B
	DEFB 	&3A, &73, &76, &FE, &F3, &DA, &D6, &4B, &37, &C9, &E6, &7F, &E5, &21, &73, &6, &CD, &00
	DEFB 	&00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &0, &00, &00
	DEFB 	&00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &0, &00, &00
	DEFB 	&00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &0, &00, &00
	DEFB 	&00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &0, &00, &00
	DEFB 	&00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &0, &00, &00
	DEFB 	&00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &0, &00, &00
	DEFB 	&00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &0, &00, &00

;; -----------------------------------------------------------------------------------------------------------
.UVZ_origin:
	DEFB 	&00, &00, &00

.UVZ_coord_Set_UVZ:
	DEFB 	&00, &00, &00

;; -----------------------------------------------------------------------------------------------------------
;; This will keep up with which of the 301 (&012D) rooms have been visited.
;; 301 rooms = 301 bits ; a 1 indicates a room in the Room_List1+Room_List2 lists has been visited.
;;    eg.: a 06 in 4266 (from start at &4261), indicates that the 42nd and 43rd rooms
;;         in the lists have been visited, which is Head's 1st and Heels 1st rooms!)
;;    eg.: a 01 at 4261 means that the first room in the list (room ID &1200) has been
;;         visited (and none of the 7 following ones in the list)
;; Note: 301 rooms should only required 38 bytes! (37*8=296 + 5 lsb bits in the 38th byte)
;; 		The way "countBits" is defined to count how many rooms have been visited
;; 		requires 301 bytes! (unless we modify the value at "43A2 01 2D 01 LD BC,012D"
;; 		with "43A2 01 26 00 LD BC,0026" to only check 38 bytes!). BUT countBits is used
;; 		by other parts of the code, so it does require a 301-byte RoomMask_buffer, off
;;      which most will always be "00".
.RoomMask_buffer:
	DEFS 	301, &00

;; -----------------------------------------------------------------------------------------------------------
;; This provides 3 bitpacked Counters, ie. they count how many "1"s are
;; set in the number of bytes defined whitin the functions:
;; PurseHooterCount:
;; 		* Clears donut bit from Inventory and then count number of items remaining.
;;        In other words, count the number of items owned in the list "Purse, Hooter".
;; SavedWorldCount:
;;		* Count how many of the 5 worlds we have saved.
;; RoomCount:
;;	    * Count how many of the 301 rooms we have visited.
;;        By starting the game, we automatically visit 2 rooms (even if we do not swop):
;;           Heels' 1st room and Head's first room.
;;           Indeed, it actually count how many rooms have been Build. Now, when the
;;           game starts, Heels' room is built to init Heels, then Head room is built
;;           and displayed.
;;        Note that the victory room counts for 2 because both are Built when entering
;;        the Victory room. This is because the main room does not have a far wall,
;;        therefore the next room is visible and displayed (even if we can never go in it
;;        as we cannot move in the Victory room!. This is also the case with any
;;        other room with no wall letting us see the next room.
;; Output: result in DE
.PurseHooterCount:
	LD 		HL,Inventory								;; pointer on Inventory
	RES 	2,(HL)										;; Lose Donut tray (empty tray)
edo1:
	EXX
	LD 		BC,&0001									;; will count the "1" bits in 1 byte (Inventory byte)
	JR 		countBits									;; count how many bits are set in the item inventory (Purse+Hooter)

.SavedWorldCount:
	LD 		HL,saved_World_Mask							;; points on saved_World_Mask
	JR 		edo1										;; count how many bits are set in the byte at saved_World_Mask

.RoomCount:
	LD 		HL,RoomMask_buffer							;; point on RoomMask_buffer
	EXX
	;; Due to the way RoomMask_buffer is bitpacked we could set BC to
	;; 38 (&26) (RoomMask_buffer should always be null from the 39th byte.)
	LD 		BC,301										;; BC=301 (nb max of bytes to check = rooms (although &0026 (38 bytes) should be fine; see the way RoomMask_buffer is bit packed)
.countBits:
	EXX
	LD 		DE,&0000									;; init counter
	EXX
cbi1:
	EXX
	LD 		C,(HL)										;; read bitmask (a bit to 1 = item owned, room visited or world saved)
	SCF													;; filler Carry set
	RL 		C											;; rotate left bitmask value leaving bit in Carry, old carry in bit0
cbi2:
	LD 		A,E
	ADC		A,0											;; add Carry
	DAA
	LD 		E,A
	LD 		A,D
	ADC 	A,0											;; DE will be BCD corrected immediately
	DAA
	LD		D,A
	SLA 	C											;; get next bit
	JR 		NZ,cbi2										;; if rest of the byte is null, then leave, else loop upto 8 bits
	INC		HL											;; next byte
	EXX
	DEC 	BC											;; do it for all rooms
	LD 		A,B
	OR 		C
	JR 		NZ,cbi1										;; untils last room
	EXX
	RET													;; result in DE

;; -----------------------------------------------------------------------------------------------------------
.Erase_visited_room:
	LD 		HL,RoomMask_buffer
	LD 		BC,301										;; Erase &012D bytes from addr &4261 (301 rooms)
	JP 		Erase_forward_Block_RAM						;; continue on Erase_forward_Block_RAM (will have a RET)

;; -----------------------------------------------------------------------------------------------------------
;; Gets the score and puts it in HL (BCD).
;; Note that a "0" will be appended to make the score 10x when displayed.
;; The score in HL (BCD) is:
;;     16 * visited rooms (up to 301)
;;     + 500 if purse
;;     + 500 if hooter
;;     + 636 * crowns (up to 5)
;;     + 501 if Head is in the Victory room
;;     + 501 if Heels is in the Victory room (make sure to enter the last room together!)
;;    That's 99980 max pts!
.GetScore:
	CALL 	Sub_Check_Victory_Room						;; Zero set if Victory room reached.
	PUSH 	AF											;; save flags
	CALL 	RoomCount									;; Count number of visited rooms in DE
	POP 	AF											;; restore flags
	LD 		HL,&0000									;; score = 0
	JR 		NZ,gs_1										;; if not in victory room, skip to gs_1, else:
	LD 		HL,&0501									;; points = 501 (BCD)
	LD 		A,(both_in_same_room)						;; get both_in_same_room
	AND 	A											;; test
	JR 		Z,gs_1										;; if only one reached the end, skip, else:
	LD 		HL,&1002									;; points = 1002 (BCD)
gs_1:
	LD 		BC,&0010									;; BC= 16 (&10 not BCD)
	CALL 	MulAccBCD									;; HL = DE (BCD) * BC
	PUSH 	HL
	CALL 	PurseHooterCount							;; Count Purse and Hooter in DE
	POP 	HL
	LD 		BC,500										;; 500 points per item (0 to 2 items)
	CALL 	MulAccBCD
	PUSH 	HL
	CALL 	SavedWorldCount								;; Count saved crowns.
	POP 	HL
	LD 		BC,636										;; &027C = 636 points per world saved (0 to 5 crowns)
	;; this flow in MulAccBCD
;; The function MulAccBCD adds to HL (BCD), the product
;; of DE (BCD) and BC (not in BCD) :  HL = HL + (DE * BC)
.MulAccBCD:																	;; HL and DE are in BCD. BC is not.
	LD 		A,E
	ADD 	A,L
	DAA
	LD 		L,A
	LD 		A,H
	ADC 	A,D
	DAA
	LD 		H,A
	DEC 	BC
	LD 		A,B
	OR 		C
	JR 		NZ,MulAccBCD
	RET													;; result in HL : HL = HL + (DE * BC)

;; -----------------------------------------------------------------------------------------------------------
;; Get the direction code from a LRDU user input in A (and ignore conflicting inputs).
;; In other words: LRDU -> Dir code (0 to 7 and FF)
;; Input: a 4-bit bitmask Left,Right,Down,Up (active low)
;; North is the far corner on the game screen, South the near corner
;; 		Let's take "A"=active (0), "I"=inactive (1)
;;  	(note: we must ignore conflicting inputs (eg. L+R = no move))              (Back)
;;		LRDU : return_code					LRDU : return_code			  (Back)	 Up    East (?)
;;		AAAA : FF	(no move)				IAAA : 02	(Right)				North __________> U
;;  	AAAI : 00	(Down)					IAAI : 01	(Down and Right)		 |05 04 03
;;		AAIA : 04	(Up)					IAIA : 03	(Up and Right)		Left |06 FF 02 Right (Front)
;;  	AAII : FF 	(no move)				IAII : 02	(Right)			  (Back) |07 00 01
;;		AIAA : 06	(Left)					IIAA : FF 	(no move)				 |  Down   South
;;  	AIAI : 07	(Down and Left)			IIAI : 00	(Down)          West     Y  (Front)  (Front)
;;		AIIA : 05	(Up and Left)			IIIA : 04	(Up)			(?)	    V
;;  	AIII : 06 	(Left)					IIII : FF 	(no move)
;; Output in A: the validated direction as described above
.DirCode_from_LRDU:
	AND		&0F											;; Only care about 4 lsb : Left,Right,Down,Up
	ADD 	A,Array_direction_table and &00FF			;; &1A = Array_direction_table & FF
	LD		L,A
	ADC 	A,Array_direction_table / 256				;; &44 = Array_direction_table >> 8
	SUB 	L
	LD 		H,A											;; ... HL = Array_direction_table + A
	LD 		A,(HL)										;; get direction code depending on input direction keys
	RET													;; return code FF (no move) or 00 to 07 (direction)

.Array_direction_table:
	DEFB 	&FF, &00, &04, &FF, &06, &07, &05, &06
	DEFB 	&02, &01, &03, &02, &FF, &00, &04, &FF

;; -----------------------------------------------------------------------------------------------------------
;; A has a direction, returns Y delta in C, X delta in B, and
;; third entry goes in A and is the DirTable inverse mapping.
.DirDeltas:
	LD 		L,A
	ADD 	A,A											;; *2
	ADD 	A,L											;; *3 (groups of 3 bytes)
	ADD 	A,DirTable2 and &00FF						;; &3A = DirTable2 & &00FF
	LD 		L,A
	ADC 	A,DirTable2 / 256							;; &44 = (DirTable2 & &FF00) >> 8 ; &443A+(dir*3) ; DirTable2 addr = &443A
	SUB 	L
	LD 		H,A											;; HL = DirTable2 + 3*A
	LD 		C,(HL)										;; C = 1st byte = Ydelta
	INC 	HL
	LD 		B,(HL)										;; B = 2nb byte = Xdelta
	INC 	HL
	LD 		A,(HL)										;; A = DirTable inverse mapping
	RET

;; -----------------------------------------------------------------------------------------------------------
;; First byte is Y delta, second X, third is reverse lookup
;; (Only DirTable[3:0] give direction; DirTable inverse mapping?)
.DirTable2:
	DEFB 	-1,  0, &0D          	;; Ydelta, Xdelta, DirTable FD ; 0:down
	DEFB 	-1, -1, &09          	;; Ydelta, Xdelta, DirTable F9 ; 1:south
	DEFB 	 0, -1, &0B          	;; Ydelta, Xdelta, DirTable FB ; 2:right
	DEFB 	 1, -1, &0A       		;; Ydelta, Xdelta, DirTable FA ; 3:east
	DEFB 	 1,  0, &0E       		;; Ydelta, Xdelta, DirTable FE ; 4:up
	DEFB 	 1,  1, &06       		;; Ydelta, Xdelta, DirTable F6 ; 5:north
	DEFB 	 0,  1, &07       		;; Ydelta, Xdelta, DirTable F7 ; 6:left
	DEFB 	-1,  1, &05				;; Ydelta, Xdelta, DirTable F5 ; 7:west

;; -----------------------------------------------------------------------------------------------------------
.UpdateCurrPos:
	LD HL,(CurrObject)
	;; Takes direction in A.
.UpdatePos:
	PUSH HL
	CALL DirDeltas
	;; Store the bottom 4 bits of A (dir bitmap) in Object + O_IMPACT
	LD DE,&000B
	POP HL
	ADD HL,DE
	XOR (HL)
	AND &0F
	XOR (HL)
	LD (HL),A
	;; Update U coordinate with Y delta
	LD DE,&FFFA											;;-&06
	ADD HL,DE
	LD A,(HL)
	ADD A,C
	LD (HL),A
	;; Update V coordinate with X delta.
	INC HL
	LD A,(HL)
	ADD A,B
	LD (HL),A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Takes a pointer in HL to an index which is incremented into a byte
;; array that follows it. Next item is returned in A. Array is
;; terminated with 0, at which point we read the first item again.
.Read_Loop_byte:
	INC 	(HL)										;; next item
	LD 		A,(HL)										;; index_offset = (HL)
	ADD 	A,L											;; Then this does...
	LD 		E,A
	ADC 	A,H
	SUB 	E
	LD 		D,A											;; ... DE = HL + index_offset
	LD 		A,(DE)										;; get value in (DE)
	AND 	A											;; test
	RET 	NZ											;; value at DE != 0, return, else:
	LD 		(HL),&01									;; update index to 1
	INC 	HL											;; point on next byte
	LD 		A,(HL)										;; get and return in A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Word version of ReadLoop. Apparently unused?
ReadLoopW:
unused_Read_Loop_word:														;; same than Read_Loop_byte, but for word (NOT USED!)
	LD A,(HL)											;; A = (HL)
	INC (HL)											;; (HL)++
	ADD A,A												;; This does...
	ADD A,L
	LD E,A
	ADC A,H
	SUB E
	LD D,A												;; ... DE = HL + 2*A
	INC DE
	LD A,(DE)
	AND A
	JR Z,unused_Read_Loop_word_sub1
	EX DE,HL
	LD E,A
	INC HL
	LD D,(HL)
	RET

;; Loop-to-start: Set next time to index 1, return first entry.
unused_Read_Loop_word_sub1:
	LD (HL),&01
	INC HL
	LD E,(HL)
	INC HL
	LD D,(HL)
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Pseudo random generator
;; value in HL
.Random_gen:
	LD 		HL,(Rand_seed_2)
	LD 		D,L
	ADD 	HL,HL
	ADC 	HL,HL
	LD 		C,H
	LD 		HL,(Rand_seed_1)
	LD 		B,H
	RL 		B
	LD 		E,H
	RL 		E
	RL 		D
	ADD 	HL,BC
	LD 		(Rand_seed_1),HL
	LD 		HL,(Rand_seed_2)
	ADC 	HL,DE
	RES 	7,H
	LD 		(Rand_seed_2),HL
	JP 		M,rg_2
	LD 		HL,Rand_seed_1
rg_1:
	INC 	(HL)
	INC 	HL
	JR 		Z,rg_1
rg_2:
	LD 		HL,(Rand_seed_1)
	RET

Rand_seed_1:
	DEFW 	&6F4A
Rand_seed_2:
	DEFW 	&216E

;; -----------------------------------------------------------------------------------------------------------
;; Pointer to object in HL
.RemoveObject:
	PUSH HL
	PUSH HL
	PUSH IY
	PUSH HL
	POP IY
	CALL Unlink
	POP IY
	POP HL
	CALL DrawObject
	POP IX
	SET 7,(IX+O_FLAGS)
	;; Transfer top bit of Phase to IX+&0A
	LD A,(Do_Objects_Phase)								;; get Do_Objects_Phase
	LD C,(IX+O_FUNC)
	XOR C
	AND &80												;; get function and flip the bit7 (phase)
	XOR C
	LD (IX+O_FUNC),A
	RET

;; -----------------------------------------------------------------------------------------------------------
.DrawObject:
	PUSH	IY
	;; Bump to an obj+2 pointer for call to GetObjExtents.
	INC		HL
	INC		HL
	CALL	GetObjExtents
	;; Move X extent from BC to HL, Y extent from HL to DE.
	EX		DE,HL
	LD		H,B
	LD		L,C
	;; Then draw where the thing is.
	CALL	Draw_View
	POP		IY
	RET

;; -----------------------------------------------------------------------------------------------------------
.InsertObject:
	PUSH 	HL
	PUSH 	HL
	PUSH 	IY
	PUSH 	HL
	POP 	IY
	CALL 	EnlistAux
	POP 	IY
	POP 	HL
	CALL 	DrawObject
	POP 	IX
	RES 	7,(IX+O_FLAGS)
	LD 		(IX+O_IMPACT),&FF
	LD 		(IX+&0C),&FF
	RET

;; -----------------------------------------------------------------------------------------------------------
;; When getting a crown, check that we have all crowns (5).
;; If so, show the page that shows we are proclaimed Emperor.
;; Then show the Worlds/Crowns page.
.Emperor_Screen_Cont:
	LD 		A,(saved_World_Mask)						;; get saved_World_Mask
	CP 		&1F											;; Got all 5 crowns?
	JR 		NZ,fcsc_skip								;; no then skip to fcsc_skip, else:
	LD 		A,Print_StringID_Wipe_Salute				;; Get proclaimed Emperor! STR_WIN_SCREEN
	CALL 	Print_String
	CALL 	Play_HoH_Tune								;; Play Main Theme
	LD 		DE,&040F									;; 4 items (Head, Heels and their crowns); draw all
	LD 		HL,EmperorPageSpriteList					;; pointer on sprite table
	CALL 	Draw_from_list								;; draw them (must be 3x24)
	CALL 	WaitKey										;; Wait key and then Wipe Screen
fcsc_skip:
	CALL 	Show_World_Crowns_screen					;; and Show Worlds/Crown screen (will also wait, then Wipe)
	CALL 	DrawBlacked									;; redraw the game screen
	JP 		Update_Screen_Periph						;; and the Periphery (HUD)

;; -----------------------------------------------------------------------------------------------------------
;; This is the World/Crowns/Planets screen
;; It also provides an function that waits a key press and wipe screen.
.Show_World_Crowns_screen:
	LD 		A,Print_StringID_Wipe_BTEmpire				;; String ID &C6 STR_EMPIRE_BLURB
	CALL 	Print_String
	CALL 	Play_HoH_Tune								;; Play HoH Theme
	LD 		HL,Planet_Sprites_list						;; pointer on Planet_Sprites_list
	LD 		DE,&05FF									;; 5 planets items to draw, FF = draw all
	CALL 	Draw_from_list								;; draw them (3x24)
	LD 		HL,Crown_sprites_list						;; pointer on Crown_sprites_list
	LD 		DE,(saved_World_Mask)						;; get saved_World_Mask in E as bitmask indicating it item correspongin to bit n will be draw or not
	LD 		D,5											;; up to 5 crowns to draw
	CALL 	Draw_from_list								;; draw them (3x24)
.WaitKey:
	CALL 	Wait_anykey_released						;; debounce key
	CALL 	Wait_key_pressed							;; Wait key press or count down over
	CALL 	Draw_wipe_and_Clear_Screen					;; then Wipe and clear screen
	LD		B,Sound_ID_Tada								;; Play; Sound ID &C1 = "Tada"
	JP 		Play_Sound									;; will RET

;; -----------------------------------------------------------------------------------------------------------
;; Wait a key press to leave the screen shown (crown/worlds screen)
;; but leave automatically after a while (about 18-20 sec)
.Wait_key_pressed:
	LD 		HL,&A800									;; delay value (show the screen (crown, ..) about 19sec if no key pressed)
waitkp_loop:
	PUSH 	HL
	CALL 	Play_HoH_Tune								;; Play Theme
	CALL 	Test_Enter_Shift_keys						;; output : Carry=1 : no key pressed, else Carry=0 and C=0:Enter, C=1:Shift, C=2:other
	POP		HL
	RET 	NC											;; RET if a key was pressed
	DEC 	HL											;; A7FF, A7FE....
	LD 		A,H
	OR 		L											;; test H=L=0
	JR 		NZ,waitkp_loop								;; loop if not yet 0
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Data for the "Crowns/Worlds" screen. Defines the Sprite id and position
;; the the planets and crowns sprites on that screen.
.Planet_Sprites_list:
	DEFB 	&4C, &54, &78								;; Sprite_ID_Ball (&4C), pix x,y coordinates : Egyptus
	DEFB 	&4C, &A4, &78								;; Sprite_ID_Ball (&4C), pix x,y coordinates : Penitentiary
	DEFB 	&4C, &54, &E8								;; Sprite_ID_Ball (&4C), pix x,y coordinates : Safari
	DEFB 	&4C, &A4, &E8								;; Sprite_ID_Ball (&4C), pix x,y coordinates : Book World
	DEFB 	&4C, &7C, &B0								;; Sprite_ID_Ball (&4C), pix x,y coordinates : Blacktooth
.Crown_sprites_list:
	DEFB 	&2F, &54, &60								;; Sprite_ID_Crown (&2F), pix x,y coordinates : Egyptus
	DEFB 	&2F, &A4, &60								;; Sprite_ID_Crown (&2F), pix x,y coordinates : Penitentiary
	DEFB 	&2F, &54, &D0								;; Sprite_ID_Crown (&2F), pix x,y coordinates : Safari
	DEFB 	&2F, &A4, &D0								;; Sprite_ID_Crown (&2F), pix x,y coordinates : Book World
	DEFB 	&2F, &7C, &98								;; Sprite_ID_Crown (&2F), pix x,y coordinates : Blacktooth

;; -----------------------------------------------------------------------------------------------------------
;; This draws the game HUD, called the "Periphery".
;; It also provide an entry for drawing Head and Heels (Draw_sprites_from_list).
.Draw_Screen_Periphery:
	CALL 	Draw_carried_objects
	LD		HL,Inventory_sprite_list					;; pointer on Inventory_sprite_list
	LD 		DE,(Inventory)								;; E = bitmask based on Inventory (which are drawn or not)
	LD 		D,3											;; 3 sprites to draw (Purse, Hooter, Donuts)
	CALL 	Draw_from_list								;; draw them (3x24)
	LD 		DE,(selected_characters)					;; DE = pointer on selected_characters
Draw_sprites_from_list														;; E is the bitmask, HL points to Inventory_sprite_list + index3 * 3 (Heels sprite)
	LD 		D,2											;; nb of sprites to draw: 2 characters, Head and Heels!
	;; here it does an implicit "JP Draw_from_list" (with the list
	;; Head and Heels sprites), as it falls in it:
;; -----------------------------------------------------------------------------------------------------------
;; Draw a list of 3x24 sprites.
;; Inputs: D: number of sprites
;; 		   E: bitmask indicating to drawn the nth sprite or to shadow it
;; 		   HL: pointer on Sprites list/array (like Inventory_sprite_list, EmperorPageSpriteList, Planet_Sprites_list, Crown_sprites_list, etc.)
;; The sprites array data should contain for each entry:
;;         a Sprite code (1 byte), the Coordinates (2 bytes)
;; Important Note: if the bitmap is 0, a sprite is still drawn, but without the
;;                 vibrant color, to give a shadowed effect.
.Draw_from_list:
	LD 		A,(HL)										;; get sprite code of the first sprite
	INC 	HL											;; point on pix coord word
	LD 		C,(HL)
	INC 	HL
	LD 		B,(HL)										;; get coord in BC = YX
	INC 	HL											;; point on data for next sprite
	PUSH 	HL											;; save it
	RR 		E											;; get current bitmap bit
	PUSH 	DE
	JR 		NC,dfl_2									;; if 0, then "shadow" this sprite
	CALL 	Draw_sprite_3x24							;; else draw it
dfl_1:
	POP 	DE
	POP 	HL
	DEC 	D											;; count down
	JR 		NZ,Draw_from_list							;; if not finished, Draw next one
	RET

dfl_2:
	LD 		D,&01										;; attribute1:shadow: if the bitmap is 0, we still draw the sprite
	CALL 	Draw_sprite_3x24_and_attribute				;; but with a shadow effect. Attribute 1
	JR 		dfl_1										;; loop to next sprite.

;; -----------------------------------------------------------------------------------------------------------
;; This defines the Sprites IDs and coordinates for the "Periphery"
;; part of the game screen (ie. HUD)
.Sprite_Flipped 		EQU  	&80

.Inventory_sprite_list:
	DEFB 	&27, &B0, &F0								;; Sprite_ID_Purse, pix x,y coordinates
	DEFB 	&28, &44, &F0								;; Sprite_ID_Hooter, pix coordinates
	DEFB 	&29, &44, &D8								;; Sprite_ID_Donuts, pix coordinates
	DEFB 	&98, &94, &F0								;; Sprite_ID_Heels1 | Sprite_Flipped, pix coordinates
	DEFB 	&1E, &60, &F0								;; Sprite_ID_Head1, pix coordinates

;; -----------------------------------------------------------------------------------------------------------
;; Draw a 3 byte x 24 row sprite on clear background, complete with
;; attributes in D, via Draw_Sprite.
;; Input: Sprite code in A.
;;        position the sprite in BC - bottomleft corner
;;        Attribute style in D:
;;				1 = "Shadow" mode
;;				3 = "Color" mode (this is the one used if using "Draw_sprite_3x24_attr3")
;; If entering directly at Draw_sprite_3x24_and_attribute, we
;; expect the attribute in D.
.Draw_sprite_3x24_attr3:
	LD 		D,&03										;; attribute=3 for Draw_sprite_3x24_and_attribute ("Color" mode)
.Draw_sprite_3x24_and_attribute:
	LD 		(Sprite_Code),A								;; update current Sprite Code
	LD 		A,B											;; Y
	SUB 	&48											;; minus 3*24 bytes to get the topleft corner
	LD 		B,A											;; now BC is the topleft-left point
	PUSH 	DE
	PUSH 	BC
	CALL 	Load_sprite_image_address_into_DE			;; get sprite image pinter in DE, B=height, HL=mask data
	LD 		HL,&180C									;; Size = 24 rows (&18), 24 pix (&0C * 2)
	POP 	BC
	POP 	AF											;; get the attribute code in A
	AND 	A											;; if 0 set Z
	JP 		Draw_Sprite									;; Draw the sprite with color attribute in A; will RET

;; -----------------------------------------------------------------------------------------------------------
;; Draw a 3-byte * 24 rows sprite on clear background
;; BC=bottomleft origin (without attribute)
.Draw_sprite_3x24:
	LD 		L,&01										;; L is 1 on CPC, 0 on Spectrum
	DEC 	L											;; This inc/dec is to ...
	INC 	L											;; ... update the Z flag
	JR 		Z,Draw_sprite_3x24_attr3					;; If L = 0 then go to Draw_sprite_3x24_attr3 (it seems it is never on CPC, but always on Spectrum!)
	LD 		(Sprite_Code),A								;; update Sprite Code
	CALL 	Calculate_Extents_3x24						;; get min and max for x and y 3x24 sprite
	CALL 	Clear_view_buffer							;; empty the buffer
	CALL 	Load_sprite_image_address_into_DE			;; DE = image data
	LD 		BC,ViewBuff									;; buffer 6700
	EXX
	LD 		B,&18										;; height = 24=&18
	CALL 	BlitMask3of3								;; blit mask 3of3
	JP 		Blit_screen									;; blit to screen

;; -----------------------------------------------------------------------------------------------------------
;; Clear a 3x24 area
.Clear_3x24:
	CALL 	Calculate_Extents_3x24						;; get min and max for x and y 3x24 sprite
	CALL 	Clear_view_buffer							;; empty the buffer
	JP 		Blit_screen									;; blit to erase

;; -----------------------------------------------------------------------------------------------------------
;; Calculate the X and Y Extent for a 3x24 sprite
;; Input: coordinate (bottom left) : y in B, x in C
.Calculate_Extents_3x24:
	LD 		H,C
	LD 		A,H
	ADD 	A,&0C										;; +12
	LD 		L,A
	LD 		(ViewXExtent),HL							;; update the ViewXExtent with X,X+&0C
	LD 		A,B
	ADD 	A,&18										;; +24
	LD 		C,A
	LD 		(ViewYExtent),BC							;; update the ViewYExtent with Y+&18,Y
	RET

;; -----------------------------------------------------------------------------------------------------------
;; how is this used? if it is used? &_NOTUSED_& ???
;; Draw a 3-byte * 32 rows sprite on clear background
;; BC=bottomleft origin (without attribute)
Draw_sprite_3x32:
	LD 		(Sprite_Code),A								;; update sprite code
	CALL 	Calculate_Extents_3x24						;; update ViewYExtent min and ViewXExtent min and max
	LD 		A,B
	ADD 	A,&20										;; +32
	LD 		(ViewYExtent),A								;; update ViewYExtent max with Y+32
	CALL 	Clear_view_buffer							;; erase buffer
	LD 		A,&02										;; set bit1, reset others in stored SPRFLAGS
	LD 		(SpriteFlags),A								;; sprite flag bit1 set
	CALL 	Load_sprite_image_address_into_DE			;; DE = image data
	LD 		BC,ViewBuff									;; buffer 6700
	EXX
	LD 		B,&20										;; Height = 32
	CALL 	BlitMask3of3								;; blit mask 3of3
	JP 		Blit_screen									;; blit screen

;; -----------------------------------------------------------------------------------------------------------
;; Clear the 6800 buffer
.Clear_view_buffer:
	LD 		HL,DestBuff
	LD		BC,&0100									;; erase 256 bytes (&0100) from &6800
	JP 		Erase_forward_Block_RAM						;; Continue on Erase_forward_Block_RAM (will have a RET)

;; -----------------------------------------------------------------------------------------------------------
TBD_4657:
	DEFB 	&00							;; ????

;; -----------------------------------------------------------------------------------------------------------
;; access_new_room_code:
;; 0 = staying in the current room
;; 1 = Down, 2 = Right, 3 = Up, 4 = Left
;; 5 = Below, 6 = Above, 7 = Teleport
;; 8 = ?? ; &80=??
access_new_room_code:
	DEFB 	&00          				;; access_new_room_code
DyingAnimFrameIndex:
	DEFB 	&00							;; When Dying will count down from &c to 0 while the vape anim is played
.Dying:
	DEFB 	&00       					;; Dying ; Mask of the characters who are dying
NR_Direction:
	DEFB 	&00

;; -----------------------------------------------------------------------------------------------------------
;; HL contains an object, A contains a direction
;; TODO: I guess IY holds the character object?
.Move:
	PUSH 	AF
	CALL 	GetUVZExtents_AdjustLowZ
	EXX
	POP 	AF
	LD 		(NR_Direction),A
;; Called from Move and recursively from the functions in movement.asm.
;; Expects UV extents in DE', HL', and movement direction in A.
;; Sets C flag if there's collision.
.DoMove:
	CALL 	DoMoveAux
	LD 		A,(NR_Direction)
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Takes direction in A, and UV extents in DE', HL'.
;;
;; It indexes into the move table, pulls out first
;; function entry into HL, and calls the second, having EXX'd,
;; arranging to return to PostMove.
.DoMoveAux:
	LD 		DE,PostMove									;; addr of PostMove 468B for next RET
	;; Stick this on the stack to be called upon return.
	PUSH 	DE
	LD 		C,A											;; direction code???
	ADD		A,A
	ADD 	A,A
	ADD 	A,C											;; A*5
	ADD 	A,MoveTbl and &00FF							;; &B7 = MoveTbl & &FF
	LD 		L,A
	ADC 	A,MoveTbl / 256								;; &47 = MoveTbl >> 8 ; &47B7 + offset
	SUB 	L
	LD 		H,A											;; HL = MoveTbl + A*5
	LD 		A,(HL)
	LD 		(&4657),A					 				;; Load first value here LRDU direct of ????
	INC 	HL
	LD 		E,(HL)
	INC 	HL
	LD 		D,(HL)										;; Next two in DE (Move)
	INC 	HL
	LD 		A,(HL)
	INC		HL
	LD		H,(HL)
	LD		L,A											;; Next two in HL (Collide)
	PUSH	DE
	EXX													;; Save regs in prime and...
	RET													;; Call PostMove (addr was on Stack)

;; -----------------------------------------------------------------------------------------------------------
;; Called after the call to the function in DoMoveAux.
;; The second movement function is in HL', the direction in C'.
.PostMove:
	EXX
	;; Can't move in that direction? Return.
	RET Z												;; Sets C (collision).
	;; Put the second movement function from MoveTbl into IX.
	PUSH HL
	POP IX
	;; There are two similar loops, based on which direction we
    ;; want to traverse the object list:
	BIT 2,C
	JR NZ,PM_Alt
    ;; Down or right case. Traverse the object list.
	LD HL,ObjectLists
.PM_ALoop:
	LD A,(HL)
	INC HL
	LD H,(HL)
	LD L,A												;; HL = (ObjectLists)
	OR H												;; test if HL = 0
	JR Z,PM_ABreak					 					;; if End of list - break.
	PUSH HL												;; else save HL
	CALL DoJumpIX				 						;; Call the function in IX ; from MoveTbl.
	POP HL
	JR c,PM_AFound										;; Found case
	JR NZ,PM_ALoop					 					;; Loop case
	JR PM_ABreak										;; Break case

;; Up or left case. Traverse the object list in opposite direction.
.PM_Alt:
	LD HL,ObjectLists + 2
.PM_BLoop:
	LD A,(HL)
	INC HL
	LD H,(HL)
	LD L,A
	OR H
	JR Z,PM_BBreak										;; End of list - break.
	PUSH HL
	CALL DoJumpIX				 						;; Call the function from MoveTbl.
	POP HL
	JR c,PM_BFound					 					;; Other found case
	JR NZ,PM_BLoop										;; Loop case
.PM_BBreak:
	CALL Get_curr_Char_variables						;; HL = pointer on current selected character's variables
	LD E,L
	JR PM_Break

.PM_ABreak:
	CALL Get_curr_Char_variables						;; HL = pointer on current selected character's variables
	LD E,L
	INC HL
	INC HL
;; Both "Break" cases end up here.
;; HL points 2 into object
;; TODO: ??? I think it may be checking if the other character
;; is relevant? Or the main character???
.PM_Break:
	BIT 0,(IY+O_SPRFLAGS)								;; playable char or obj/enemy?
	JR Z,PM_Break2
	LD A,IYl											;; IY low byte
	CP E
	RET Z
.PM_Break2:
	LD A,(Saved_Objects_List_index)						;; get Saved_Objects_List_index
	AND A
	RET Z												;; Sets NC (no collision).
	CALL DoJumpIX
	RET NC												;; Sets NC (no collision).
	;; Adjust pointer and fall through...
	CALL Get_curr_Char_variables						;; HL = pointer on current selected character's variables
	INC HL
	INC HL
.PM_AFound:
	DEC HL
	DEC HL
.PM_BFound:
	PUSH HL
	POP IX
	LD A,(&4657)
	BIT 1,(IX+O_SPRFLAGS)								;; Second part of double-height is character or object?
	JR Z,PM_Found2
    ;; Adjust first, then.
	AND (IX-6)										;; (IX+&0C-18) ; -6
	LD (IX-6),A										;; (IX+&0C-18) ; -6
	JR PM_Found3

;; Otherwise, adjust it.
.PM_Found2:
	AND (IX+&0C)
	LD (IX+&0C),A
;; Call "ProcContact" with &FF in A.
.PM_Found3:
	XOR A
	SUB 1												;; Sets C (collided).
;; Handle contact between a pair of objects in IX and IY
.ProcContact:
	PUSH AF
	PUSH IX
	PUSH IY
	CALL ContactAux
	POP IY
	POP IX
	POP AF
	RET

;; -----------------------------------------------------------------------------------------------------------
;; IX and IY are both objects, may be characters.
;; Something is in A.
.ContactAux:
	BIT 0,(IY+O_SPRFLAGS)								;; 1st object: test if playable char or not
	JR NZ,Contact_Player_Obj							;; yes, jump Contact_Player_Obj, else:
	BIT 0,(IX+O_SPRFLAGS)								;; 2nd object: test if playable char or not
	JR Z,Contact_Obj_vs_Obj								;; no? then 2 object collides ; goto Contact_Obj_vs_Obj, else:
	PUSH IY
	EX (SP),IX											;; these 3 lines swap IY and IX so we have the player in IY and the obj in IX
	POP IY
Contact_Player_Obj:
	LD C,(IY+O_SPRFLAGS)								;; player sprite flags in C.
	LD B,(IY+O_FLAGS)									;; player flags in B.
	BIT 5,(IX+O_FLAGS)									;; test bit5 in obj flags
	RET Z												;; if bit5=0 then leave, else:
	BIT 6,(IX+O_FLAGS)									;; if bit6 of obj flags
	JR NZ,CollectSpecial								;; is set then go CollectSpecial, else:
	AND A												;; test value in A????
	JR Z,DeadlyContact									;; if 0 then DeadlyContact (deadly floor or object), else:
	BIT 4,(IX+O_SPRFLAGS)								;; test bit4 of O_SPRFLAGS = 0:object is deadly, 1:object harmless
	RET NZ												;; leave if set, else:
;; IY holds character sprite. We've hit a deadly floor or object.
;; C is character's sprite flags (IY offset 9)
;; B is character's other flags (IY offset 4)
.DeadlyContact:
	BIT 3,B												;; test char flag if bit3=00 : joined Heels+Head
	LD B,&03											;; B[1:0] = 2b11
	JR NZ,dco_1											;; not joined, jump over this, else do:
	DEC B												;; B[1:0] = 2b10
	BIT 2,C												;; test sprite flag bit 2
	JR NZ,dco_1											;; if bit2=1, then only Head
	DEC B												;; else we are Heels, so B[1:0]=2b01
dco_1:																		;; updating flag bits based on invulnerability...
	XOR A												;; A=0
	LD HL,Heels_invulnerability							;; a &C9 (RET) here make invulnerable!
	CP (HL)												;; compare Heels' invul with 0 (active low)
	JR Z,dco_2											;; if it is 0 (Heels is invuln), don't do the RES below, else do
	RES 0,B												;; char flag bit 0=Heels invul (0=invul)
dco_2:
	INC HL												;; Head_s_invulnerability
	CP (HL)												;; compare Head's invul with 0 (active low)
	JR Z,dco_3											;; if it is 0 (Head is invuln), don't do the RES below, else do
	RES 1,B												;; char flag bit 1=Head invul (0=invul)
dco_3:
	LD A,B												;; final invul setting in A
	AND A												;; test it
	RET Z												;; if 0, then invulnerability is active, so leave. Else, death!
	LD HL,Dying											;; point on Dying mask (which char is dying)
	OR (HL)												;; based on the value of B (invulnerabilities)...
	LD (HL),A											;; ...refresh mask value at 'Dying'
	DEC HL												;; points on DyingAnimFrameIndex (frame of Vape animation effect when dying)
	LD A,(HL)											;; get value
	AND A												;; test if 0
	RET NZ												;; if not 0 (dying anim) return, else:
	LD A,(saved_World_Mask)								;; get saved_World_Mask
	CP &1F												;; if all worlds saved (then we are Emperor)
	RET Z												;; then Return (invulnerable as Emperor), else
	LD (HL),&0C											;; Set value of DyingAnimFrameIndex to &0C (dying, will count down to 0 while the vape/dying anim is played)
	LD A,(access_new_room_code)							;; get access_new_room_code
	AND A												;; test if 0 (stay same room)
	CALL NZ,BoostInvuln2								;; ??? if merged HnH, then heels boost invuln ??? ; call BoostInvuln2 if access_new_room_code not 0 (changing room)
	LD B,Sound_ID_Death									;; Sound_ID &C6 ; Death noise
	JP Play_Sound										;; will RET

;; -----------------------------------------------------------------------------------------------------------
;; Make the special object disappear when picking it up
;; and call the associated function.
.CollectSpecial:
    ;; Set flags etc. for fading
	LD 		(IX+O_ANIM),&08								;; anim code [7:3] = 1 (index0 in AnimTable = ANIM_VAPE1), frame = 0 ([2:0])
	LD 		(IX+O_FLAGS),&80
	LD 		A,(IX+O_FUNC)								;; get func code
	AND 	&80											;; keep phase bit
	OR 		OBJFN_FADE									;; set Fade function (to make it disappear)
	LD 		(IX+O_FUNC),A
	RES 	6,(IX+O_SPRFLAGS)							;; enable item function
	LD 		A,(IX+O_SPECIAL)							;; Extract the item id for the call to GetSpecial.
	JP 		GetSpecial

;; -----------------------------------------------------------------------------------------------------------
;; Contact between two objects (non-character)
;; This will also handle a contact between a "Donut" fired and an enemy
;; First object in IX, second in IY
.Contact_Obj_vs_Obj:
	BIT 	3,(IY+O_SPRFLAGS)							;; TODO ???? is IY a tall obj? (maybe double height sprites can be touched by a donut fired from the ground level, and from one unit above it (if Head if on Heels or an object).
	JR 		NZ,cnc_1									;; if yes skip to cnc_1
	BIT 	3,(IX+O_SPRFLAGS)							;; else, is the 2nd object tall?
	RET 	Z											;; no, then leave (nothing more to do for obj collision????)
	;; TODO : HL=IX firedObj; IY obj fired at
	PUSH 	IY											;; else
	POP 	IX											;; get the object in IX
	;; IX has the object
cnc_1:																		;; get the first (or only) part of the object:
	BIT 	1,(IX+O_SPRFLAGS)							;; IX obj bit1 : if 0:1st part of a double sprite object; if 1:2nd part of a double sprite object
	JR 		Z,cnc_2										;; if 1st part then skip to cnc_2, else get 1st part
	LD 		DE,-18										;; adding &FFEE is substracting 18 (the length of an object variables array)
	ADD 	IX,DE										;; Take the object before in the list (1st part of a double height sprite)
cnc_2:
	BIT 	7,(IX+O_SPRFLAGS)							;; test HUNGRY flag : if set, turn off the object function (movement) and impact.
	RET 	Z
	;; if it reaches here it is a Donut in IY and
	;; the "Hungry" enemy in IX (turns it off)
	SET 	6,(IX+O_SPRFLAGS)							;; object function (movement for concerned objects) disabled
	LD 		(IX+O_IMPACT),&FF							;; impact disabled
	RET

;; -----------------------------------------------------------------------------------------------------------
;; MoveTbl is indexed on a direction, as per LookupDir.
;; First element is LRDU bit mask for directions.
;; Second is the function to move in that direction.
;; Third element is the function to check collisions.
.MoveTbl:
	DEFB	&FD          					;; dir code 0 : Moving Down (south west)
	DEFW	MoveT_Down, CollideT_Down  		;; 				MoveT_Down 48FE, CollideT_Down 48C4
	DEFB	&FF     						;; dir code 1 (diag) : Stop (South = Down/Right)
	DEFW	MoveT_DownRight, &0000			;; 				MoveT_DownRight 47DF, 0
	DEFB	&FB           					;; dir code 2 : Moving Right (south east)
	DEFW	MoveT_Right, CollideT_Right		;; 				MoveT_Right 4955, CollideT_Right 48E2
	DEFB	&FF     						;; dir code 3 (diag) : Stop (East = Up/Right)
	DEFW	MoveT_UpRight, &0000         	;; 				MoveT_UpRight 4800, 0
	DEFB	&FE        						;; dir code 4 : Moving Up (north east)
	DEFW	MoveT_Up, CollideT_Up      		;; 				MoveT_Up 49A5, CollideT_Up 4868
	DEFB	&FF           					;; dir code 5 (diag) : Stop (North = Up/Left)
	DEFW 	MoveT_UpLeft, &0000        		;; 				MoveT_UpLeft 4824, 0
	DEFB	&F7           					;; dir code 6 : Moving Left (north west)
	DEFW	MoveT_Left, CollideT_Left		;; 				MoveT_Left 49ED, CollideT_Left 48A9
	DEFB	&FF           					;; dir code 7 (diag) : Stop (West = Down/Left)
	DEFW	MoveT_DownLeft, &0000           ;; 				MoveT_DownLeft 4847, 0

;; The diagonal movement functions rearrange things:
;; * They remove two elements of the stack, removing the call to
;;   PostMove and the return into DoMove (which puts (Direction) into A).
;; * They call DoMove, and check the resultant carry flag. Carry means
;;   failure to move in that direction. They move one direction, then the
;;   other.
;; * If the first move succeeds, the extents are updated to represent the
;;   successful move, before the second check is attempted.
;; * Depending on what works, they generate a movement direction in A,
;;   and success/failure in the carry flag.
MoveT_DownRight:
	EXX
	;; Remove original return path, hit DoMove again.
	POP HL
	POP DE
	XOR A
	;; Call Down
	CALL DoMove
	JR c,drght_1
	;; Update extents in DE
	EXX
	DEC D
	DEC E
	EXX
	;; Call Right
	LD A,&02
	CALL DoMove
	LD A,&01
	RET NC
	XOR A
	RET

;; Call Right
drght_1:
	LD A,&02
	CALL DoMove
	RET c
	AND A
	LD A,&02
	RET

;; -----------------------------------------------------------------------------------------------------------
.MoveT_UpRight:
	EXX
	;; Remove original return path, hit DoMove again.
	POP HL
	POP DE
	;; Call Up
	LD A,&04
	CALL DoMove
	JR c,urght_1
	;; Update extents in DE
	EXX
	INC D
	INC E
	EXX
	;; Call Right
	LD A,&02
	CALL DoMove
	LD A,&03
	RET NC
	LD A,&04
	AND A
	RET

;; Call Right
urght_1:
	LD A,&02
	CALL DoMove
	RET c
	AND A
	LD A,&02
	RET

;; -----------------------------------------------------------------------------------------------------------
.MoveT_UpLeft:
	EXX
	;; Remove original return path, hit DoMove again.
	POP HL
	POP DE
	LD A,&04
	CALL DoMove
	JR c,ulft_1
	;; Update extents in DE
	EXX
	INC D
	INC E
	EXX
	;; Call Left
	LD A,&06
	CALL DoMove
	LD A,&05
	RET NC
	LD A,&04
	AND A
	RET

;; Call Left
ulft_1:
	LD A,&06
	CALL DoMove
	RET c
	LD A,&06
	RET

;; -----------------------------------------------------------------------------------------------------------
.MoveT_DownLeft:
	EXX
	;; Remove original return path, hit DoMove again.
	POP HL
	POP DE
	;; Call Down
	XOR A
	CALL DoMove
	JR c,dlft_1
	;; Update extents in DE
	EXX
	DEC D
	DEC E
	EXX
	;; Call Left
	LD A,&06
	CALL DoMove
	LD A,&07
	RET NC
	XOR A
	RET

;; Call Left
dlft_1:
	LD A,&06
	CALL DoMove
	RET c
	AND A
	LD A,&06
	RET

;; -----------------------------------------------------------------------------------------------------------
;; *Collide functions take an object in HL, and check it against the
;; character whose extents are in DE' and HL'
;;
;; Returned flags are:
;;  Carry = Collided
;;  NZ = No collision, but further collisions are possible.
;;  Z = Stop now, no further collisions possible.
.CollideT_Up:
	INC HL
	INC HL
	CALL GetSimpleSize
	;; Check U coordinate
	LD A,(HL)
	SUB C
	EXX
	CP D
	EXX
	JR c,CollideContinue 								;; Too far? Skip.
	JR NZ,ChkBack										;; Are we done yet?
	;; U coordinate matches.
	INC HL
;; U coordinate matches. Check V overlaps.
.ChkVCollide:
	LD A,(HL)
	SUB B
	EXX
	CP H
	LD A,L
	EXX
	JR NC,CollideContinue
	SUB B
	CP (HL)
	JR NC,CollideContinue
	;; If we reached here, there's a V overlap.
.ChkZCollide:
	INC HL
	EXX
	LD A,C
	EXX
	CP (HL)
	JR NC,CollideContinue
	LD A,(HL)
	SUB E
	EXX
	CP B
	EXX
	JR NC,CollideContinue
	;; If we reached here, there's a Z overlap.
	SCF
	RET

;; -----------------------------------------------------------------------------------------------------------
.ChkBack:
    ;; Check V coordinate
	INC HL
	LD A,(HL)
	SUB B
	EXX
	CP H
	EXX
	JR c,CollideContinue
	;; Check Z coordinate
	INC HL
	LD A,(HL)
	SUB E
	EXX
	CP B
	EXX
	JR c,CollideContinue
	;; Passed our object, can stop now.
	XOR A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; No carry = no collision, non-zero = keep searching.
;; return -1, no Z and no Carry
.CollideContinue:
	LD A,&FF
	AND A
	RET

;; -----------------------------------------------------------------------------------------------------------
.CollideT_Left:
	INC HL
	INC HL
	CALL GetSimpleSize
	;; Check U coordinates overlap...
	LD A,(HL)
	SUB C
	EXX
	CP D
	LD A,E
	EXX
	JR NC,ChkBack
	SUB C
	CP (HL)
	JR NC,CollideContinue
	;; U overlaps, check V for contact.
	INC HL
	LD A,(HL)
	SUB B
	EXX
	CP H
	EXX
	JR Z,ChkZCollide   									;; U and V match.
	JR CollideContinue 									;; Not a collision.

;; -----------------------------------------------------------------------------------------------------------
.CollideT_Down:
	CALL GetSimpleSize
	;; Check U coordinate.
	EXX
	LD A,E
	EXX
	SUB C
	CP (HL)
	JR c,CollideContinue 								;; Past it? Skip
	INC HL
	JR Z,ChkVCollide    								;; Are we done yet?
	;; U coordinate matches.
.ChkFront:
    ;; Check U coordinate.
	EXX
	LD A,L
	EXX
	SUB B
	CP (HL)
	JR c,CollideContinue
	;; Check Z coordinate.
	INC HL
	LD A,(HL)
	ADD A,E
	EXX
	CP B
	EXX
	JR NC,CollideContinue
	;; Passed our object, can stop now.
	XOR A
	RET

;; -----------------------------------------------------------------------------------------------------------
.CollideT_Right:
	CALL GetSimpleSize
	;; Check U coordinate overlap...
	EXX
	LD A,E
	EXX
	SUB C
	CP (HL)
	INC HL
	JR NC,ChkFront
	DEC HL
	LD A,(HL)
	SUB C
	EXX
	CP D
	LD A,L
	EXX
	JR NC,CollideContinue
	;; U overlaps, checks V for contact.
	INC HL
	SUB B
	CP (HL)
	JP Z,ChkZCollide						   			;; U and V match.
	JR CollideContinue

;; -----------------------------------------------------------------------------------------------------------
;; Up, Down, Left and Right
;;
;; Takes U extent in DE, V extent in HL.
;; U/D work in U direction, L/R work in V direction. ???????Check if this is right?????????TODO
;;
;; Sets NZ and C if you can move in a direction.
;; Sets Z and C if you cannot.
;; Leaving room sets direction in NextRoom, sets C and Z.
.MoveT_Down:
	CALL ChkCantLeave
	JR Z,D_NoExit
	;; Inside the door frame to the side? Check a limited extent, then.
	CALL UD_InOtherDoor
	LD A,&24											;; DOOR_LOW
	JR c,D_NoExit2
	;; If the wall has a door, and
    ;; we're the right height to fit through, and
    ;; we're lined up to go through the frame,
    ;; set 'A' to be the far side of the door.
	BIT 0,(IX-1)										;; Has_Door?
	JR Z,D_NoDoor
	LD A,(DoorHeights+3)								;; sw door
	CALL DoorHeightCheck
	JR c,D_NoExit
	CALL UD_InFrame
	JR c,D_NearDoor
	LD A,(Max_min_UV_Table)								;; MinU
	SUB 4
	JR D_Exit

;; If there's no wall, put the room end coordinate into 'A'...
.D_NoDoor
	BIT 0,(IX-2)										;; Has_no_vall
	JR Z,D_NoExit
	LD A,(Max_min_UV_Table)								;; MinU
;; Case where we can exit the room.
.D_Exit:
	CP E
	RET NZ
	LD A,&01
.LeaveRoom:
	LD (access_new_room_code),A							;; update access_new_room_code
	SCF													;; set Carry
	RET

;; -----------------------------------------------------------------------------------------------------------
;; The case where we can't exit the room, but may hit the wall.
.D_NoExit:
	LD A,(Max_min_UV_Table)								;; MinU
;; (or some other value given in A).
.D_NoExit2:
	CP E
	RET NZ
	SCF
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Handle the near-door case: If we're not near the door frame,
;; we do the normal "not door" case. Otherwise, we do that and
;; then nudge into the door.
.D_NearDoor:
	CALL UD_InFrameW
	JR c,D_NoExit
	CALL D_NoExit
	;; Choose a direction to move based on which side of the door
    ;; we're trying to get through.
.UD_Nudge:
	RET NZ
	LD A,L
	CP &25												;; DOOR_LOW + 1
	LD A,&F7											;; ~&08
	JR c,Nudge
	LD A,&FB											;; ~&04
;; Update the direction with they way to go to get through the door.
.Nudge:
	LD (Movement),A
	XOR A
	SCF
	RET

;; -----------------------------------------------------------------------------------------------------------
.MoveT_Right:
	CALL ChkCantLeave
	JR Z,R_NoExit
	;; Inside the door frame to the side? Check a limited extent, then.
	CALL LR_InOtherDoor
	LD A,&24											;; DOOR_LOW
	JR c,R_NoExit2
	;; If the wall has a door, and
    ;; we're the right height to fit through, and
    ;; we're lined up to go through the frame,
    ;; set 'A' to be the far side of the door.
	BIT 1,(IX-1)										;; Has_Door
	JR Z,R_NoDoor
	LD A,(DoorHeights+2)								;; se door
	CALL DoorHeightCheck
	JR c,R_NoExit
	CALL LR_InFrame
	JR c,R_NearDoor
	LD A,(Max_min_UV_Table+1)							;; MinV
	SUB 4
	JR R_Exit

;; If there's no wall, put the room end coordinate into 'A'...
.R_NoDoor:
	BIT 1,(IX-2)										;; (IX-&02) ; Has_no_vall
	JR Z,R_NoExit
	LD A,(Max_min_UV_Table+1)							;; MinV
;; Case where we can exit the room.
.R_Exit:
	CP L
	RET NZ
	LD A,&02
	JR LeaveRoom

.R_NoExit:
	LD A,(Max_min_UV_Table+1)							;; MinV
;; (or some other value given in A).
.R_NoExit2:
	CP L
	RET NZ
	SCF
	RET

;; -----------------------------------------------------------------------------------------------------------
;; The case where we can't exit the room, but may hit the wall.
.R_NearDoor:
	CALL LR_InFrameW
	JR c,R_NoExit
	CALL R_NoExit
;; Choose a direction to move based on which side of the door
;; we're trying to get through.
.LR_Nudge:
	RET NZ
	LD A,E
	CP &25
	LD A,&FE
	JR c,Nudge
	LD A,&FD
	JR Nudge

;; -----------------------------------------------------------------------------------------------------------
.MoveT_Up:
	CALL ChkCantLeave
	JR Z,U_NoExit
	;; Inside the door frame to the side? Check a limited extent, then.
	CALL UD_InOtherDoor
	LD A,&2C											;; DOOR_HIGH
	JR c,U_NoExit2
	;; If the wall has a door, and
    ;; we're the right height to fit through, and
    ;; we're lined up to go through the frame,
    ;; set 'A' to be the far side of the door.
	BIT 2,(IX-1)										;; (IX-&01) ; Has_Door
	JR Z,U_NoDoor
	LD A,(DoorHeights+1)								;; ne door
	CALL DoorHeightCheck
	JR c,U_NoExit
	CALL UD_InFrame
	JR c,U_NearDoor
	LD A,(Max_min_UV_Table+2)							;; MaxU
	ADD A,4
	JR U_Exit

;; If there's no wall, put the room end coordinate into 'A'...
.U_NoDoor:
	BIT 2,(IX-2)										;; Has_no_vall
	JR Z,U_NoExit
	LD A,(Max_min_UV_Table+2)							;; MaxU
;; Case where we can exit the room.
.U_Exit:
	CP D
	RET NZ
	LD A,&03
	JP LeaveRoom

;; The case where we can't exit the room, but may hit the wall.
.U_NoExit:
	LD A,(Max_min_UV_Table+2)							;; MaxU
.U_NoExit2
	CP D												;; (or some other value given in A).
	RET NZ
	SCF
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Handle the near-door case: If we're not near the door frame,
;; we do the normal "not door" case. Otherwise, we do that and
;; then nudge into the door.
.U_NearDoor:
	CALL UD_InFrameW
	JR c,U_NoExit
	CALL U_NoExit
	JP UD_Nudge

;; -----------------------------------------------------------------------------------------------------------
.MoveT_Left:
	CALL ChkCantLeave
	JR Z,L_NoExit
	;; Inside the door frame to the side? Check a limited extent, then.
	CALL LR_InOtherDoor
	LD A,&2C											;; DOOR_HIGH
	JR c,L_NoExit2
	;; If the wall has a door, and
    ;; we're the right height to fit through, and
    ;; we're lined up to go through the frame,
    ;; set 'A' to be the far side of the door.
	BIT 3,(IX-1)										;; (IX-&01) ; Has_Door
	JR Z,L_NoDoor
	LD A,(DoorHeights)									;; nw door
	CALL DoorHeightCheck
	JR c,L_NoExit
	CALL LR_InFrame
	JR c,L_NearDoor
	LD A,(Max_min_UV_Table+3)							;; MaxV
	ADD A,4
	JR L_Exit

;; If there's no wall, put the room end coordinate into 'A'...
.L_NoDoor:
	BIT 3,(IX-2)										;; (IX-&02) ; Has_no_vall
	JR Z,L_NoExit
	LD A,(Max_min_UV_Table+3)							;; MaxV
;; Case where we can exit the room.
.L_Exit:
	CP H
	RET NZ
	LD A,&04
	JP LeaveRoom

;; The case where we can't exit the room, but may hit the wall.
.L_NoExit
	LD A,(Max_min_UV_Table+3)							;; MaxV
	;; (or some other value given in A).
.L_NoExit2:
	CP H
	RET NZ
	SCF
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Handle the near-door case: If we're not near the door frame,
;; we do the normal "not door" case. Otherwise, we do that and
;; then nudge into the door.
.L_NearDoor:
	CALL LR_InFrameW
	JR c,L_NoExit
	CALL L_NoExit
	JP LR_Nudge

;; -----------------------------------------------------------------------------------------------------------
;; If we're not inside the V extent, we must be in the doorframes to
;; the side. Set C if this is the case.
.UD_InOtherDoor:
	LD A,(Max_min_UV_Table+3)							;; MaxV
	CP H
	RET c
	LD A,L
	CP (IX+1)											;; (IX+&01) ; MinV
	RET

;; -----------------------------------------------------------------------------------------------------------
;; If we're not inside the U extent, we must be in the doorframes to
;; the side. Set C if this is the case.
.LR_InOtherDoor:
	LD A,(Max_min_UV_Table+2)							;; MaxU
	CP D
	RET c
	LD A,E
	CP (IX+0)											;; (IX+&00) ; MinU
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Return NC if within the interval associated with the door.
;; Specifically, returns NC if D <= DOOR_HIGH and E >= DOOR_LOW
.LR_InFrame:
	LD A,&2C											;; DOOR_HIGH
	CP D
	RET c
	LD A,E
	CP &24												;; DOOR_LOW
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Same, but for the whole door, not just the inner arch
.LR_InFrameW:
	LD A,&30											;; DOOR_HIGH + 4
	CP D
	RET c
	LD A,E
	CP &20												;; DOOR_LOW - 4
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Return NC if within the interval associated with the door.
;; Specifically, returns NC if H <= DOOR_HIGH and L >= DOOR_LOW
.UD_InFrame:
	LD A,&2C											;; DOOR_HIGH
	CP H
	RET c
	LD A,L
	CP &24												;; DOOR_LOW
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Same, but for the whole door, not just the inner arch
.UD_InFrameW:
	LD A,&30											;; DOOR_HIGH + 4
	CP H
	RET c
	LD A,L
	CP &20												;; DOOR_LOW - 4
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Door height check.
;;
;; Checks to see if the character Z coord (in A) is between B
;; and either B + 3 or B + 9 (depending on if you're both head
;; and heels currently). Returns NC if the character is in the right
;; height range to go through door.
.DoorHeightCheck:
	SUB B
	RET c
	PUSH AF
	LD A,(selected_characters)							;; get selected_characters
	CP &03
	JR NZ,dhc_1
	POP AF
	CP &03
	CCF
	RET
dhc_1:
	POP AF
	CP &09
	CCF
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Points IX at the room boundaries, sets zero flag (can't leave room) if:
;; Bit 0 of IY+O_SPRFLAGS is not zero, or bottom 7 bits of IY+0A are not zero.
;;
;; Assumes IY points at the object.
;; Returns with zero flag set if it can't leave the room.
;; Also points IX at the room boundaries.
;;
;; TODO: Can't leave room if it's a not a player, or the object
;; function is zero'd.
.ChkCantLeave:
	LD 		IX,Max_min_UV_Table							;; MinU
	BIT 	0,(IY+O_SPRFLAGS)							;; Is it a player?
	RET 	Z											;; If it's not the player, can't leave room.
	LD 		A,(IY+O_FUNC)								;; else, Check the object function...
	AND 	&7F											;; don't look phase bit
	SUB 	1											;; test if function was 0
	RET 	c											;; If func was 0, C set, leave with FF
	XOR 	A											;; else leave with 0
	RET													;; in other cases, can.

;; -----------------------------------------------------------------------------------------------------------
;; HL points to the object to check + 2.
;; Assumes flags are in range 0-3.
;; Returns fixed height of 6 in E.
;; Returns V extent in B, U extent in C.
;; Leaves HL pointing at the U coordinate.
.GetSimpleSize:
	INC HL
	INC HL
	LD A,(HL)											 ;; Load flags into A.
	INC HL
	LD E,&06											 ;; Fixed height of 6.
	BIT 1,A
	JR NZ,GSS_1
	;; Cases 0, 1:
	RRA
	LD A,&03
	ADC A,&00
	LD B,A
	LD C,A
	RET													;; Either 3x3 or 4x4.

GSS_1:																		;; Cases 2, 3:
	RRA
	JR c,GSS_2
	;; Case 2:
	LD BC,&0104
	RET													;; 1x4

GSS_2:
	LD BC,&0401
	RET													;; 4x1

;; -----------------------------------------------------------------------------------------------------------
.Double_size_char_buffer:
	DEFS 	16, 0						;; 16 bytes Buffer for the double-height characters

;; -----------------------------------------------------------------------------------------------------------
.current_pen_number:
	DEFB 	&02							;; (02 by default)
.Char_cursor_pixel_position:
	DEFW 	&8040 						;; low byte = x(col) ; high byte = y(row)
.text_size:
	DEFB 	&00     					;; Text height size variable (0:single; none-0:double)
.rainbow_mode:
	DEFB 	&FF							;; Rainbow mode On (00) or Off ("not 00")

;; -----------------------------------------------------------------------------------------------------------
;; This will Print a string and in the meantime handles the attribute
;; codes inserted within the string data.
;; -----------------------------------------------------------------------------------------------------------
;; If the string code is >= &80, then use the string data defined in the string tables:
;;  * String ID &80 to &CB come from String_Table_Main index 0 to &4B;
;;  * String ID &E0 to &FF come from String_Table_Kb index 0 to &1F.
;; But we can also use the following codes:
;; 	 00 : Wipe Screen effect
;; 	 01 : New Line
;; 	 02 : Space to erase until the end of the line
;;   03 : Text_single_size (double height Off)
;;   04 : Text_double_size (double height On)
;;   05 xx : Color attribute
;;			xx = 00 : Rainbow (each letter changes the color)
;;				 else : color (1, 2 or 3)
;; 	 06 xx yy : Set_Text_Position col xx, row yy
;; 	 07 xx : Color scheme
;; Char symbols:
;;   21 : Menu Arrow type 1
;;   22 : Menu Arrow type 2
;;   23 : Menu Arrow type 3
;;   24 : Menu Arrow type 4
;;   25 : Lightning icon (speed)
;;   26 : Spring icon (jump)
;;   27 : Shield icon
;; Also, we can use these Macros:
;;   B0 xx yy : macro for 00 + 07 09 + 04 + 06, hence must also be followed by xx yy
;;	 B1 : macro for B9 05 14
;;	 B2 : macro for B9 19 14
;;	 B3 : macro for B9 19 17
;;	 B4 : macro for B9 05 17
;;   B5 : macro for 04 06 12 16
;;   B6 : macro for 04 06 0C 16
;;   B7 : macro for B9 01 11
;;   B8 : macro for 03 82 06 1A 13 followed by the 4 items (Spring, Shield, Speed, Shield)
;;	 B9 xx yy : macro for 03 + 06, hence must also be followed by xx yy
;; -----------------------------------------------------------------------------------------------------------
.Print_String:
	;; The jump address (function reentry) at 4AC3 will be updated in Control_Codes_more:
	;; Can be either:
	;; * Control_Code_attribute_5, 6 or 7 (will be followed by parameters (resp. 1, 2 and 1));
	;; * or, at the end of Control_Codes_more, reset back to Print_Char_base (with no parameter).
smc_print_string_routine:
	JP 		Print_Char_base								;; self modified code, the addr is set at Control_Codes_more;
	;;4AC3 DEFW C5 4A														; default Print_Char_base (4AC5) else (Control_Code_attribute_5, 6 or 7)
.Print_Char_base:
	CP 		&80											;; compare A with &80; if A < &80 then Carry is set, else Carry is reset
	JR 		NC,Sub_Print_String							;; Continue on Sub_Print_String if A >= &80 (will RET), else:
	SUB 	&20											;; to test if was below or above &20
	JR 		c,Control_Codes								;; if code was below 20 go to Control_Codes; will RET
	CALL 	Char_code_to_Addr							;; else it is a plain char, go to Char_code_to_Addr addr in DE (reminder: a "SUB 20" was done)
	LD 		HL,&0804									;; sprite size : x=2x4 (2 pix per byte) ; y=8
	LD 		A,(text_size)								;; get Text height size (0:single (Z=1) or 1:double (NZ=1))
	AND 	A											;; check if size was 0 or 1
	CALL 	NZ,Double_sized_char						;; if Double size, then call Double_sized_char input:DE=symbol data, output:DE=buffer where the zoomed sprite is, HL=new size
	LD 		BC,(Char_cursor_pixel_position)				;; get Char cursor addr position B=y, C=x
	LD 		A,C
	ADD 	A,&04										;; col+4 (next pixel x position)
	LD 		(Char_cursor_pixel_position),A				;; write new Char cursor addr position
	LD 		A,(rainbow_mode)							;; get rainbowmode On/Off
	AND 	A											;; test it
	LD 		A,(current_pen_number)						;; get current pen number
	JR 		NZ,pcb_end									;; if Rainbow mode Off, then jump pcb_end
	INC 	A											;; else Rainbow mode is On so loop color to the next one
	AND 	&03											;; clamping it if needed (0,1,2,3 then back to 0 (at this point))
	SCF													;; set carry flag
	JR 		NZ,pcb_notr									;; if new color not 0, then go pcb_notr
	INC 	A											;; else +1 so we are in fact looping 1,2,3,1,2,3...
pcb_notr:
	LD 		(current_pen_number),A						;; store current pen number
pcb_end:
	JP 		Draw_Sprite									;; will RET

.Sub_Print_String:
	AND 	&7F											;; A was >= &80, clear bit7 ("substract" &80)
	CALL 	Get_String_code_A
print_char_until_delimiter
	LD 		A,(HL)										;; get current Cursor_position_code
	CP 		Delimiter									;; has reached Delimiter? (A == &FF?)
	RET 	Z											;; if Delimiter reached then RET
	INC 	HL											;; else: next char position
	PUSH 	HL											;; store new char position
	CALL 	Print_String
	POP 	HL											;; restores surrent char position
	JR 		print_char_until_delimiter					;; loop

;; -----------------------------------------------------------------------------------------------------------
;; Available string attribute codes:
;; 	 00 : Wipe Screen effect
;; 	 01 : New Line
;; 	 02 : Space to erase until the end of the line
;;   03 : Text_single_size (double height Off)
;;   04 : Text_double_size (double height On)
;;   05 xx : Color attribute
;;			xx = 00 : Rainbow (each letter changes the color)
;;				 else : color (1, 2 or 3)
;; 	 06 xx yy : Set_Text_Position col xx, row yy
;; 	 07 xx : Color scheme
;; -----------------------------------------------------------------------------------------------------------
;; First part of the string attributes parsing. Handles the codes
;; 0 to 4. It'll jump to Control_Codes_more for codes 5 to 7
.Control_Codes:																;; Handles Codes 0 to 4
	ADD 	A,&20										;; We did a SUB 20 before, so add it back!
	CP 		&05											;; test if A < 5
	JR 		NC,Control_Codes_more						;; jump Control_Codes_more if A >= 5
	AND 	A											;; A == 0?
	JP 		Z,Draw_wipe_and_Clear_Screen				;; if Code 0 jump Draw_wipe_and_Clear_Screen ; will RET
	SUB 	2											;; Test codes 1 (C set) and 2 (Z set)
	JR 		c,Control_Code_new_line						;; if Code = 1 jump Control_Code_new_line; will RET; else:
	JR 		Z,Control_Code_space_erase_end				;; if Code = 2 jump Control_Code_space_erase_end; will RET, else:
	DEC 	A											;; Test if codes 3 (A=0) or 4 (A=1)
	LD 		(text_size),A								;; Set Text size 0 = single height or 1 = double height
	RET

;; -----------------------------------------------------------------------------------------------------------
;; This is the string attribute 02: clear the line from current cursor
;; position to the end of line (erase any old character that could
;; remain when text has changed)
Control_Code_space_erase_end:
	LD 		A,(Char_cursor_pixel_position)				;; Char cursor addr position
	CP 		&C0											;; has reached right border?
	RET 	NC											;; if yes, RET
	LD 		A,&20										;; else : String " "
	CALL 	Print_String
	JR 		Control_Code_space_erase_end				;; loop

;; -----------------------------------------------------------------------------------------------------------
;; This is the string attribute 01: "New line" (go to begining of next line)
.Control_Code_new_line:
	LD 		HL,(Char_cursor_pixel_position)				;; Char cursor addr position H=y, L=x
	LD 		A,(text_size)								;; get Text height size
	AND 	A											;; test if single size (0) or double (1)
	LD 		A,H											;; A = row
	JR 		Z,ccnewln_single							;; jump over one of the ADD below if single height, else do both!
	ADD 	A,&08										;; Next char pixel row   (if double size do it twice)
ccnewln_single:
	ADD 	A,&08										;; Next char pixel row (if single size do it once)
	LD 		H,A											;; refresh cursor address ...
	LD 		L,&40										;; ... position to ...
	LD 		(Char_cursor_pixel_position),HL				;; ...newline position
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Next part of the string attributes parsing. Here it'll handle the
;; codes 5, 6 and 7; these are followed by parameters
.Control_Codes_more:														;; Handles Codes 5, 6 and 7
	LD 		HL,Control_Code_attribute_5_setmode			;; prepare jump address Control_Code_attribute_5_setmode
	JR 		Z,Update_attribute_jump_address				;; if Code = 5 jump Color_attribute ; Update_attribute_jump_address
	CP 		&07											;; test if Code 7
	LD 		HL,Control_Code_attribute_7_setscheme		;; prepare jump address Control_Code_attribute_7_setscheme
	JR 		Z,Update_attribute_jump_address				;; if Code 7 : Update_attribute_jump_address
	LD 		HL,Control_Code_attribute_6_getcol			;; else code 6 : jump address Control_Code_attribute_6_getcol
.Update_attribute_jump_address:
	LD 		(smc_print_string_routine+1),HL				;; update entry jump address of Print_String self mod code
	RET

;; -----------------------------------------------------------------------------------------------------------
.Control_Code_attribute_7_setscheme:
	CALL 	Set_colors
	JR 		Control_Code_attribute_funnel				;; back to default jump address Print_Char_base

.Control_Code_attribute_5_setmode:
	AND 	A											;; test color attribute
	LD 		(rainbow_mode),A							;; update rainbow mode (00 or "not 0")
	JR 		Z,Control_Code_attribute_funnel				;; if we had the "05 00" rainbow mode on attribute, then can leave
	LD 		(current_pen_number),A						;; else need to set the pen number 1, 2, or 3
.Control_Code_attribute_funnel:
	LD 		HL,Print_Char_base							;; back to default jump address Print_Char_base
	JR 		Update_attribute_jump_address

.Control_Code_attribute_6_getcol:
	LD 		HL,Control_Code_attribute_6_getrow			;; next jump address will be Control_Code_attribute_6_getrow
	ADD 	A,A
	ADD 	A,A
	ADD 	A,&40										;; next pix pos = 4xcol+&40  (&40 is the minX in pix coord, *4 : 4 pix per bytes)
	LD 		(Char_cursor_pixel_position),A				;; update char pix X address
	JR 		Update_attribute_jump_address

.Control_Code_attribute_6_getrow:
	ADD 	A,A
	ADD 	A,A
	ADD 	A,A											;; next pix pox = 8 * row
	LD 		(Char_cursor_pixel_position+1),A			;; update char pix Y address
	JR 		Control_Code_attribute_funnel				;; back to default jump address Print_Char_base

;; -----------------------------------------------------------------------------------------------------------
;; Produce a String attribute 06 (position "LOCATE")
;; Input: BC is the position;
;; Output: HL = pointer on Cursor_position_code string attribute.
.Set_Cursor_position:
	LD 		(Cursor_position_code+1),BC					;; Update Cursor_position_code position from BC
	LD		HL,Cursor_position_code						;; point Cursor_position_code
	JP 		print_char_until_delimiter					;; (will end up with a RET)

;; -----------------------------------------------------------------------------------------------------------
;; This produce a "String" attribute code 06 (position).
;; the position is set by Set_Cursor_position
.Cursor_position_code:
	DEFB	&06											;; cursor_position code
	DEFW	&0000										;; Will be updated at address 4B7C
	DEFB	Delimiter									;; delimiter code

;; -----------------------------------------------------------------------------------------------------------
;; This will find the pointer on the String we are looking for.
;; The "String ID AND &7F" is in A.
;;  * String ID &80 to &CB come from String_Table_Main index 0 to &4B;
;;  * String ID &E0 to &FF come from String_Table_Kb index 0 to &1F.
;; Output: HL = pointer on the wanted String data.
.Get_String_code_A:
	LD 		B,A											;; B = Index of the String in the table (ID&80 -> B=0, ID&81 -> B=1, etc..)
	LD 		HL,String_Table_Main						;; String_Table_Main base addr (ID &80 to &CB)
	SUB 	&60											;; test if code was >= &E0 (reminder: (ID AND 7F) SUB 60)
	JR 		c,got_tab									;; If code was not from String_Table_Kb, then (is from String_Table_Main) jump got_tab
	LD 		HL,String_Table_Kb							;; change to table String_Table_Kb base addr (ID &E0 to &FF)
	LD 		B,A
got_tab:
	INC 	B											;; jump over 1rst Delimiter (tables start with FF)
search_nth_Delimiter:
	LD 		A,Delimiter									;; code to look for (Delimiter)
loop_search_nth_Delimiter
	LD 		C,A
	CPIR												;; Repeat CPI (CP (HL) ; INC HL ; DEC BC) until BC=0 or A=(HL); find first occurance.
	DJNZ 	loop_search_nth_Delimiter					;; B-- ; Jump if B!=0
	RET

;; -----------------------------------------------------------------------------------------------------------
;; This creates a zoomed char sprite from the original char
;; Output: DE will point on the double sized char buffer
.Double_sized_char:
	LD 		B,&08										;; 8 original lines in char symbol
	LD 		HL,Double_size_char_buffer					;; Double_size_char_buffer
dsc_loop:
	LD 		A,(DE)										;; get char symbol byte
	LD 		(HL),A										;; put it once
	INC 	HL
	LD 		(HL),A										;; put it twice!
	INC 	HL
	INC 	DE											;; next byte
	DJNZ 	dsc_loop
	LD 		HL,&1004									;; sprite size : x=2x4 (2 pix per byte) ; y=16 (&10)
	LD 		DE,Double_size_char_buffer					;; Double_size_char_buffer
	RET

;; -----------------------------------------------------------------------------------------------------------
;; This will define the following functions:
;;  * Print_2Digits_LeftAligned : 2-digits, Left aligned, No leading "0" (but if 0 print "0 ")
;;  * Print_2Digits_RightAligned : 2-digits, Right aligned (Pad with spaces), No leading "0" (but if 0 print " 0")
;;  * Print_4Digits_LeftAligned : 4-digits, Left aligned, No leading "0" (but if 0 print "0 ")
;; Input: A = BCD 2-digit value to print (DE is a "don't care" here)
;;     OR DE = = BCD 4-digit value to print (A is a "don't care" here)
;;		  C = bitmap for the leading "0"s so that the lsb bit controls the highest power-of-10 digit
;;			  In that bitmap, a "1" means "prints a leading 0", a "0" means "look at bitmap in B.
;;		  B = bitmap used if the corresponding bit in C is 0;
;;			  In that bitmap, a "1" means print a Space instead of the corresponding 0 or as a padding;
;;                            a "0" means break (no leading 0, so do not need to continue parsing); RET with NC
.Print_4Digits_LeftAligned:
	;; Left align, no leading zero.
	LD 		BC,&00F8									;; 4 digits Left aligned, No leading "0" (but if 0 print "0 ")
	PUSH 	DE
	LD 		A,D
	CALL 	print_2Digits								;; print higher digits
	POP 	DE
	LD 		A,E
	JR 		print_2Digits								;; print lower digits

.Print_2Digits_RightAligned:
	LD 		BC,&FFFE									;; Right aligned (Pad with spaces), No leading "0" (but if 0 print " 0")
	JR 		print_2Digits
.Print_2Digits_LeftAligned:
	LD 		BC,&00FE									;; Left aligned, No leading "0" (but if 0 print "0 ")
.print_2Digits:
	PUSH 	AF											;; save A
	RRA
	RRA
	RRA
	RRA													;; int(A >> 4) (get high BCD nibble)
	CALL 	Sub_PrintDigit								;; print it
	POP 	AF											;; restore value in A and print the low BCD nibble:
.Sub_PrintDigit:
	AND 	&0F											;; A MOD 16 (get low BCD nibble)
	JR 		NZ,print_it									;; if not 0 jump print_it, else:
	RRC 	C											;; get bit0 of C in Carry and Circular Right rotate C
	JR 		c,print_it									;; if Carry=1, print the "0" out, else:
	RRC 	B											;; get bit0 of B in Carry and Circular Right rotate B
	RET 	NC											;; if Carry=0, leave with Carry reset, else print out a "Space"
	LD 		A,&F0										;; A = &F0 (after the add 30, it'll become &20 = " ")
print_it:
	LD 		C,&FF										;; if Sub_PrintDigit recalled, we will print the "0"s from now ()
	ADD 	A,&30										;; Convert number (0 to 9) to corresponding ASCII, and &F0 to " "so if value is "00" we will always at least print "0"
	PUSH 	BC
	CALL 	Print_String								;; Print it!
	POP 	BC
	SCF													;; leave with Carry set
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Bit 0 set = have updated object extents
;; Bit 1 set = needs redraw
DrawFlags:
	DEFB	&00

Collided:
	DEFB 	&FF

;; -----------------------------------------------------------------------------------------------------------
;; Used to store the force direction when controlling something with
;; a Joystick (ie. in game object "joystick" SPR_STICK)
ObjJoystickDir:
	DEFB 	&FF

;; -----------------------------------------------------------------------------------------------------------
;; Get the (in game object SPR_STICK) Joystick direction and save its
;; direction in ObjJoystickDir
ObjFnJoystick:
	LD 		A,(IY+&0C)									;; get object direction
	LD 		(IY+&0C),&FF								;; reset it
	OR 		&F0
	CP 		&FF											;; was the object direction &FF?
	RET 	Z											;; leave if so
	LD 		(ObjJoystickDir),A							;; else save that direction in ObjJoystickDir
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Charles is ontrolled by (in game object SPR_STICK) Joysticks. eg. Room &B87
;; Charles follows the direction of the force applied to the joystick, if that
;; direction is available to it.
ObjFnJoyControlled:
	CALL 	ObjAgain8
	LD 		HL,ObjJoystickDir							;; points on...
	LD 		A,(HL)										;; ...and get ObjJoystickDir direction value
	LD 		(HL),&FF									;; and reset it
	PUSH 	AF											;; save inital ObjJoystickDir direction
	CALL 	DirCode_from_LRDU							;; get dir code (0 to 7 or FF), from initial LRDU direction
	INC 	A
	SUB 	1											;; test value, if it was FF then Carry set, else (real direction) Carry=NC
	CALL 	NC,MoveDir									;; if a dir is set, then MoveDir
	POP 	AF											;; restore inital ObjJoystickDir direction
	CALL 	ObjAgain6									;; TODO ????
	CALL 	FaceAndAnimate
	JP 		ObjDraw

;; -----------------------------------------------------------------------------------------------------------
ObjFnTeleport:
	BIT 	5,(IY+&0C)
	RET 	NZ
	CALL 	FaceAndAnimate
	CALL 	ObjDraw
	LD 		B,Sound_ID_Teleport_waiting					;; Sound_ID &47 : Teleporter waiting noise
	JP 		Play_Sound	 								;; will RET

;; -----------------------------------------------------------------------------------------------------------
;; Function OBJFN_CANNONBALL &24 associated to the ObjDefns object &3C :
;; Cannon Balls (Sprite SPR_BALL) in the Victory room.
;; It launches a new Cannon ball when delay_CannonBall reaches 0 and
;; resets it to &60, so that, as long as a Cannon Ball exists,
;; delay_CannonBall won't be able to be 0, thus preventing the
;; Game_over in Victory_Room.
;; A launched cannon ball will have the behaviour of a fired Donut
;; (function id &19) and will get destroyed. When all Cannon Balls in
;; the Victory room have been destroyed, delay_CannonBall will reach
;; 0 and the Victory room celebration will end and go to Game_over.
delay_CannonBall:
	DEFB 	&60							;; delay_CannonBall &60 by default, receives &40 at init, then &60 in ObjFnCannonFire

ObjFnCannonFire:
	LD		HL,delay_CannonBall							;; delay_CannonBall
	LD 		A,(HL)										;; read value
	AND 	A											;; and test
	RET 	NZ											;; if not 0 leave; else:
	LD 		(HL),&60									;; reset delay before firing next Canon Ball;
	LD 		(IY+O_IMPACT),&F7							;; update (IY+&0B),~&08
	LD 		(IY+O_FUNC),OBJFN_FIRE						;; update object function &19 = OBJFN_FIRE (cannon ball is similar to firing a donut: fired then destroyed)
	LD 		A,Sound_ID_BeepCannon						;; play Cannon fired sound
	JP 		SetSound									;; will RET

;; -----------------------------------------------------------------------------------------------------------
;; Used by some of the sandwiches (eg. Room &239). It is immobile by default.
;; When the player stands on it, the sandwich will move in the same direction
;; the player is facing until an obstacle and stops. Seems to ignore any new
;; direction until it reached a stopping point.
ObjFn35Bool:
	DEFB	&00											;; can be 0 or FF (FF during Sub_FnDriven is processed, else 0)

ObjFnDriven:
	LD HL,ObjFn35Bool
	LD (HL),&FF
	PUSH HL
	CALL Sub_FnDriven
	POP HL
	LD (HL),&00
	RET

Sub_FnDriven:
	LD A,(ObjDir)
	INC A
	JR NZ,ObjFnEnd2
	LD A,(IY+&0C)
	AND &20												;; test bit 5
	RET NZ
	LD BC,(character_direction)							;; get character_direction LRDU in C
	JR ObjFnEnd

;; -----------------------------------------------------------------------------------------------------------
;; Used by TAP in the room &220 or &320, they activate (ie. moves forward
;; until an obstacle) only when passing "in front" of them (raytracing
;; radar beams on all 4 sides).
;; If we are standing in their diagonal we are invisible to them)
ObjFnRadarBeams:
	LD A,(ObjDir)
	INC A
	JR NZ,ObjFnEnd2
	CALL CharDistAndDir
	OR &F3												;; ~&0C ; Clear one axis of direction bits
	CP C
	JR Z,ObjFnEnd
	LD A,C
	OR &FC
	CP C
	RET NZ
ObjFnEnd:
	LD (IY+&0C),C
	JR ObjFnEnd2

;; -----------------------------------------------------------------------------------------------------------
;; The function associated with a firing donut object.
ObjFnFire:
	CALL AnimateMe
	CALL ObjFnSub
	JR c,ObjFF2
	CALL ObjFnSub
ObjFF2:
	JP c,Fadeify
	JR ObjDraw2

;; -----------------------------------------------------------------------------------------------------------
;; when pushed, the object will "roll" like a ball until it collides with something.
;; can be pushed by playable characters or moving enemies
ObjFnBall:
	LD A,(ObjDir)										;; get diraction
	INC A
	JR NZ,ObjFnEnd2										;; if not FF jump ObjFnEnd2
	LD A,(IY+&0C)										;; else:
	INC A
	JR Z,ObjFnEnd4
ObjFnEnd2:
	CALL ObjAgain8
	CALL ObjFnSub
ObjDraw2:
	JP ObjDraw

ObjFnEnd4:
	PUSH IY
	CALL ObjFnPushable
	POP IY
	LD (IY+O_IMPACT),&FF
	RET

ObjFnSub:
	LD A,(ObjDir)
	AND (IY+&0C)
	CALL 	DirCode_from_LRDU							;; get dir code (0 to 7 or FF), from LRDU
	CP &FF
	SCF
	RET Z
	CALL MoveCurr
	RET c
	PUSH AF
	CALL UpdateObjExtents
	POP AF
	PUSH AF
	CALL UpdateCurrPos
	POP AF
	LD HL,(ObjFn35Bool)									;; L = ObjFn35Bool boolean (0 or FF)
	INC L												;; +1 to test if was FF
	RET Z												;; RET if was FF, else:
	CALL MoveCurr
	RET c
	CALL UpdateCurrPos
	AND A
	RET

;; -----------------------------------------------------------------------------------------------------------
.MoveCurr:
	LD HL,(CurrObject)
	JP Move

;; -----------------------------------------------------------------------------------------------------------
;; Switch button object.
;; It'll turn on/off the movement and flip the function disable bit (O_SPRFLAGS bit6)
;; of all objects in the room.
;; (eg. a Dissolve2 object will become undissolvable if in the same room)
ObjFnSwitch:
    ;; First check if we're touched. If not, clear &11 and return.
	LD A,(IY+&0C)
	OR &C0
	INC A
	JR NZ,objfnsw_1
	LD (IY+O_SPECIAL),A
	RET

;; Otherwise, check if there was a previous touch.
;; If so, clear &0C and return.
objfnsw_1:
	LD A,(IY+O_SPECIAL)
	AND A
	JR Z,objfnsw_2
	LD (IY+&0C),&FF
	RET

;; Mark as previously touched...
objfnsw_2:
	DEC (IY+O_SPECIAL)
	CALL ObjAgain7
	;; Call PerObj on each object in the main object list...
	LD HL,ObjectLists + 2
objfnsw_loop:
	LD A,(HL)
	INC HL
	LD H,(HL)
	LD L,A
	OR H
	JR Z,objfnsw_3
	PUSH HL
	PUSH HL
	POP IX
	CALL PerObjSwitch							    	;; Call with the object in HL and IX
	POP HL
	JR objfnsw_loop

;; End part, mark for redraw and toggle the switch state flag.
objfnsw_3:
	CALL MarkToDraw
	LD A,(IY+O_FLAGS)
	XOR %00010000										;; flip bit4 of O_FLAGS
	LD (IY+O_FLAGS),A
	JP ObjDraw

;; for each object in the room (ObjectLists + 2 list), that is not
;; the switch itself, neither is fading, apply the switch if needed
.PerObjSwitch:
	LD 		A,(IX+O_FUNC)								;; get function code
	AND 	%01111111									;; ignore phase bit
	CP 		OBJFN_SWITCH								;; is it OBJFN_SWITCH?
	RET 	Z											;; leave if yes
	CP 		OBJFN_FADE									;; else is it OBJFN_FADE?
	RET 	Z											;; leave if yes
	;; If neither bit 3 or 1 of O_SPRFLAGS is set, toggle bit6.
	LD 		A,(IX+O_SPRFLAGS)							;; read O_SPRFLAGS
	LD 		C,A											;; stash value in C
	AND 	%00001001
	RET 	NZ											;; leave if either bit3 or bit0 are set
	LD 		A,C											;; recover O_SPRFLAGS
	XOR 	%01000000									;; flip bit6 of the object O_SPRFLAGS : object function disabled/enabled
	LD 		(IX+O_SPRFLAGS),A							;; update value
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Heliplat are used to lift the player upwards.
;; Peculiarity: If comming from ObjFnHeliplat, the LD A,&52 is done.
;; But if coming from ObjFnHeliplat2, the 01 at 4D30 will take the "3E 52"
;; as data in a dummy instruction "LD BC,&523E" to cancel the "LD A,&52".
ObjFnHeliplat2: ;; room 616
	LD 		A,&90										;; low limit = 0, high limit = 9, dir = 0 (decent)
	DEFB 	&01		;;LD BC,...							; LD BC,nnnn, to cancel the next instruction "LD,&52"!
ObjFnHeliplat:
	;; if comming from ObjFnHeliplat2, the "LD A,&52" does not exist
	;; as it became a dummy "LD BC,&523E"
	LD 		A,&52										;; low limit = 2, high limit = 5, dir = 0 (decent)
	LD 		(IY+O_SPECIAL),A							;; for heliplat, the O_SPECIAL is the limit heigths & dir flags
	LD 		(IY+O_FUNC),OBJFN_HELIPLAT3					;; &10 = OBJFN_HELIPLAT3
	RET

;; -----------------------------------------------------------------------------------------------------------
;; This makes an elevated object - on which the player stands - gently
;; colapse to the ground (in other words it loses altitude as pressure is applied on it).
;; It does not go back up when pressure is released.
;; The cushions around the room &ABD (all but the ones under the doors)
;; use this feature.
ObjFnColapse:
	BIT		5,(IY+&0C)
	RET		NZ
	CALL	ObjAgain9
	JP		ObjDraw

;; -----------------------------------------------------------------------------------------------------------
;; Rollers in the various LRDU directions (bits are active low)
ObjFnRollers1
	LD 		A,&FE										;; Moving Up
	JR 		writeRollerDir
ObjFnRollers2:
	LD 		A,&FD										;; Moving Down
	JR 		writeRollerDir
ObjFnRollers3:
	LD 		A,&F7										;; Moving Left
	JR 		writeRollerDir
ObjFnRollers4:
	LD 		A,&FB										;; Moving Right
.writeRollerDir:
	LD 		(IY+O_IMPACT),A								;; Rollers direction in &0B, will impact the direction of who or what is on the rollers
	LD 		(IY+O_FUNC),0								;; reset function
	RET

;; -----------------------------------------------------------------------------------------------------------
;; HushPuppies disappear if Head is in the room
ObjFnHushPuppy:
	LD 		A,(selected_characters)						;; get selected_characters
	AND 	&02											;; Test bit1 if we have Head (TestAndFade returns early if not)
	JR 		TestAndFade

;; -----------------------------------------------------------------------------------------------------------
;; Make an object dissolve upon contact
;; * ObjFnDissolve: : dissolving grating (eg. room 476)
;; * ObjFnDissolve2: : dissolving cushion, pad, book and rollers
;;		Note: 2 cushions in the room 526 are set as Dissolve2, but when
;;	 	the switch in the room is turned off, it freezes the Beacon, but
;;	 	also makes the cushions no longer dissolvable.
;; * TestAndFade : dissolving hushpuppies if Head is in the room (no contact needed here, just entering)
ObjFnDissolve:
	LD 		A,&C0
	DEFB 	&01 	;;LD BC,...
ObjFnDissolve2: ;; dissolving cushion, pad, book and rollers
	;; if comming from ObjFnDissolve, the "LD A,&CF" does not exist
	;; as it became a dummy "LD BC,&CF3E"
	LD		A,&CF										;; LD BC,nn , NOPs next instruction! ; ObjFnDissolve2: LD	A,&CF
	OR 		(IY+&0C)
	INC 	A											;; test and leave if bits 5&4 (if coming from ObjFnDissolve2) or bits 5:0 (if from ObjFnDissolve) were all 1s
.TestAndFade:
	RET 	Z											;; if comming from ObjFnHushPuppy if it is Heels, then nothing to do, else:
Fadeify:																	;; Make the HushPuppies disappear if Head enters the room
	LD 		A,Sound_ID_BeepCannon						;; cannon sound
	CALL 	SetSound
	LD 		A,(IY+O_FUNC)								;; get object function code but...
	AND 	&80											;; ...keep phase bit (only)
	OR 		OBJFN_FADE									;; set function as Fade
	LD 		(IY+O_FUNC),A
	LD 		(IY+O_ANIM),&08								;; ANIM_VAPE1 : anim code [7:3] = 1 (index0 in AnimTable = ANIM_VAPE1); frame [2:0]=0
ObjFnFade:
	LD 		(IY+O_FLAGS),&80
	CALL 	UpdateObjExtents
	CALL	AnimateMe
	LD 		A,(IY+O_ANIM)								;; [7:3] = anim code, [2:0] = frame
	AND 	&07											;; keep frame index
	JP 		NZ,ObjDraw									;; if not 0, draw
ObjFnDisappear:
	LD		HL,(CurrObject)								;; HL point on curr object
	JP 		RemoveObject								;; remove it from the objects list

;; -----------------------------------------------------------------------------------------------------------
;;The Spring stool will give the player extra jumping force
ObjFnSpring:
	LD B,(IY+O_SPRITE)
	BIT 5,(IY+&0C)										;; test bit5
	SET 5,(IY+&0C)										;; and set it
	LD A,SPR_SPRUNG
	JR Z,ofn_spring_end									;; if previous bit5 was 0, jump to ofn_spring_end
	LD A,(IY+O_ANIM)									;; else : [7:3] = anim code, [2:0] = frame
	AND A
	JR NZ,br_4DBD
	LD A,SPR_SPRUNG
	CP B
	JR NZ,ObjFnPushable
	LD (IY+O_ANIM),&50									;; [7:3] = anim code = &0A (index9 in AnimTable = ANIM_SPRING), [2:0] = frame = 0
	LD A,&04											;; noise when we land on the spring?
	CALL SetSound
	JR ObjFnStuff

br_4DBD
	AND &07
	JR NZ,ObjFnStuff
	LD A,SPR_SPRING
ofn_spring_end
	LD (IY+O_SPRITE),A
	LD (IY+O_ANIM),0									;; reset [7:3] = anim code = 0, [2:0] = frame = 0
	CP B
	JR Z,ObjFnPushable
	JR ObjFnStuff

;; -----------------------------------------------------------------------------------------------------------
ObjFnSpecial:
	LD A,(IY+O_ANIM)									;; [7:3] = anim code, [2:0] = frame
	AND &F0
	JR Z,ObjFnPushable
ObjFnStuff:
	CALL UpdateObjExtents
	CALL AnimateMe
.ObjFnPushable:		;; can be pushed
	CALL ObjAgain8
	LD A,&FF
	CALL ObjAgain6
	JP ObjDraw

;; -----------------------------------------------------------------------------------------------------------
;; The Different ways an object can move.
ObjFnLinePatrol:	;; used by the Anvil : Moves formard until an obstacle, then turns around (180° turn), and starts advancing again.
	LD HL,HalfTurn
	JP ObjFnStuff2
ObjFnSquarePatrol:	;; used by sandwich room &240 : it moves forward clockwise until an obstacle, then makes a 90° turn clockwise and starts advancing again.
	LD HL,Clockwise
	JP ObjFnStuff2
ObjFnVisor1: 		;; ObjFnLinePatrol but ???? TODO ; eg. robot in room &786, it moves back and forth on one lane.
	LD HL,HalfTurn
	JR TurnOnCollision
ObjFnMonocat:		;; ObjFnSquarePatrol but ???? TODO
	LD HL,Clockwise
	JR TurnOnCollision
ObjFnAnticlock:		;; ObjFnMonocat but in the other direction
	LD HL,Anticlockwise
	JR TurnOnCollision
ObjFnBee			;; used by bee (eg. room 476), move to any random direction
	LD HL,DirAny
	JR TurnOnCollision
ObjFnRandQ:			;; Random direction change (any like a Chess King)
	LD HL,DirAny
	JR TurnRandomly
ObjFnRandR:			;; Random direction change, axially (like a Chess Rook).
	LD HL,DirAxes
	JR TurnRandomly
ObjFnRandB:			;; Random direction change, in diagonal (like a Chess Bishop). ; eg. Beacon room 516
	LD HL,DirDiag
	JR TurnRandomly
ObjFnHomeIn:		;; Home in, like a robomouse (attracted by the player if close enough, but can also go in lines, like a rook).
	LD HL,HomeIn
	JR GoThatWay

;; -----------------------------------------------------------------------------------------------------------
;; if we saved the 4 worlds, it gives us the capability to frighten the Emperor Guard.
;; (ie. the BALL+VAPE enemy, one room BEFORE the Emperor's Room (NOT the BEACON within the Emperor's room))
;; When we arrive with less than 4 worlds saved, it "attacks" (MoveTowards). But if we saved 4 worlds
;; the Emperor's guard moves out of our way (MoveAway).
ObjFnRespectful:
	LD A,(saved_World_Mask)								;; get saved_World_Mask
	OR &F0												;; look at the 4 first crowns only
	INC A												;; if &0F then become 0
	LD HL,MoveAway
	JR Z,respect_1										;; if we have 4 crowns then make it MoveAway
	LD HL,MoveTowards									;; else make it MoveTowards
respect_1:
	JR GoThatWay										;; move it the selected way

;; -----------------------------------------------------------------------------------------------------------
ObjFnStuff2:
	PUSH HL
	CALL FaceAndAnimate
	JR ObjFnStuff5

;; -----------------------------------------------------------------------------------------------------------
.TurnOnCollision:
	PUSH HL
.TurnOnColl2:
	CALL FaceAndAnimate
	CALL ObjAgain8
	LD A,&FF
	JR c,ObjFnStuff6
ObjFnStuff5:
	CALL DirCode_to_LRDU
ObjFnStuff6:
	CALL ObjAgain6
	POP HL
	LD A,(Collided)
	INC A
	JP Z,ObjDraw										;; not collided, just Draw
	CALL DoTurn											;; else turn
	JP ObjDraw											;; and draw

;; Call the turning function provided earlier.
.DoTurn:
	JP (HL)

.GoThatWay:
	PUSH HL
	CALL ObjAgain8
	POP HL
	CALL DoTurn
.Collision33:
	CALL FaceAndAnimate
	CALL DirCode_to_LRDU
	CALL ObjAgain6
	JP ObjDraw

;; Turn randomly. If not turning randomly, act like TurnOnCollision.
.TurnRandomly:
	PUSH HL
	;; Pick a number. If not lucky, follow TurnOnCollision case.
	CALL Random_gen										;; rnd value in HL
	LD A,L
	AND &0F
	JR NZ,TurnOnColl2
	CALL ObjAgain8
	POP HL
	CALL DoTurn
	CALL FaceAndAnimate
	CALL DirCode_to_LRDU
	CALL ObjAgain6
	JP ObjDraw

;; -----------------------------------------------------------------------------------------------------------
.HeliPadDir:
	DEFB 	&00

;; Running heliplat
ObjFnHeliplat3:
	LD A,&01											;; Sound_ID 01
	CALL SetSound
	CALL FaceAndAnimate
	LD A,(IY+O_SPECIAL)									;; height limits and dir
	LD B,A
	BIT 3,A												;; test Up/Down direction
	JR Z,ofn_hp3_descent								;; if bit3 = 0, jump ofn_hp3_descent
ofn_hp3_ascent:																;; else ascent (b3 = 1) : get high limit from O_SPECIAL byte
	RRA
	RRA
	AND %00111100
	LD C,A												;; C = (4 * high nibble) of O_SPECIAL
	RRCA												;; (4 * high nibble)/2
	ADD A,C												;; A = 1,5 (4 * high nibble) = 6 * high nibble
	NEG													;; invert sign
	ADD A,GROUND_LEVEL									;; &C0 - (6 * high nibble) = Z coord; 6 is the objects unit height, &C0 the ground level
	CP (IY+O_Z)											;; compare with O_Z
	JR NC,ofn_hp3_limit									;; if A >=O_Z jump ofn_hp3_limit, else
	LD HL,(CurrObject)
	CALL ChkSatOn										;; character or object on it? (if so, also need to update their height accordingly)
	RES 4,(IY+O_IMPACT)									;; TODO : maybe check if blocked by something??
	JR NC,hp3_do_ascent
	JR Z,ofn_h3_draw_end
	;; Ascend.
hp3_do_ascent
	CALL UpdateObjExtents								;; convert UVZ into pixel x,y
	DEC (IY+O_Z)										;; going up (Z axis goes Down, so the higher, the smaller Z is)
	JR ofn_h3_draw_end

ofn_hp3_limit:
	LD HL,HeliPadDir									;; if reached a limit (high or low), flip the direction bit
	LD A,(HL)											;; it waits to go one further before reversing
	AND A
	JR NZ,br_4EC1
	LD (HL),2											;; reset to 2
br_4EC1
	DEC (HL)											;; get either 1 or 0
	JR NZ,ofn_h3_draw_end
ofn_hp3_flipdir:
	LD A,B
	XOR %00001000
	LD (IY+O_SPECIAL),A									;; flip O_SPECIAL bit3 : for HELIPLAT it is the direction (ascent/decent)
	AND %00001000
	JR ofn_h3_draw_end

ofn_hp3_descent
	AND %00000111										;; get low limit from O_SPECIAL byte
	ADD A,A												;; low 3bits * 2
	LD C,A
	ADD A,A												;; low 3bits * 4
	ADD A,C												;; A = low 3bits * 6
	NEG													;; invert sign
	ADD A,GROUND_LEVEL - 1								;; A = &C0 - (6 * low 3bits) - 1 = Z ccord
	CP (IY+O_Z)											;; reached low limit?
	JR c,ofn_hp3_limit
	LD HL,(CurrObject)
	CALL DoContact2										;; is it blocked by something? (even if it didn't reach the low limit, a character may be under or something has been pushed below)
	JR NC,hp3_do_descent
	JR Z,ofn_h3_draw_end
hp3_do_descent
	;; Descend
	CALL UpdateObjExtents
	RES 5,(IY+O_IMPACT)
	INC (IY+O_Z)										;; going down (Z axis goes down on the screen, so increasing Z makes visually go down)
ofn_h3_draw_end
	JP ObjDraw

;; -----------------------------------------------------------------------------------------------------------
;; Go to a NEW axial direction (different to the current one).
;; Axial direction is the Up-Down (V axis) and Left-Right (U axis) directions.
DirAxes:
	CALL 	Random_gen									;; rnd value in HL
	LD 		A,L
	AND 	&06											;; select a axial move only
	CP 		(IY+O_DIRECTION)							;; compare with dir code (0 to 7 or FF)
	JR 		Z,DirAxes									;; if same then pick another one
	JR 		MoveDir										;; else move to new dir

;; -----------------------------------------------------------------------------------------------------------
;; Go to a NEW diagonal direction (different to the current one).
;; Diagonal are the axis North-South and West-East
.DirDiag:
	CALL 	Random_gen									;; rnd value in HL
	LD 		A,L
	AND 	&06
	OR 		&01											;; select a diag direction
	CP 		(IY+O_DIRECTION)							;; compare with current dir code (0 to 7 or FF)
	JR 		Z,DirDiag									;; if same then pick another one
	JR 		MoveDir										;; else move to new dir

;; -----------------------------------------------------------------------------------------------------------
;; Turn to any NEW direction.
.DirAny:
	CALL 	Random_gen									;; rnd value in HL
	LD		 A,L
	AND 	&07											;; L mod 8
	CP 		(IY+O_DIRECTION)							;; compare with current dir code (0 to 7 or FF)
	JR 		Z,DirAny									;; if same, then choose another one
	JR 		MoveDir										;; else move to new dir

;; -----------------------------------------------------------------------------------------------------------
;; Turn 90 degrees clockwise.
;; 		0 (Down), 1 (South), 2 (Right), 3 (East),  4 (Up),    5 (North), 6 (Left), 7 (West)
;; -2 : 6 (Left), 7 (West),  0 (Down),  1 (South), 2 (Right), 3 (East),  4 (Up),   5 (North)
.Clockwise:
	LD 		A,(IY+O_DIRECTION)							;; dir code (0 to 7 or FF)
	SUB 	2											;; minus 2 if a clockwise 90° turn
	JR 		Mod8MoveDir									;; move to new dir

;; -----------------------------------------------------------------------------------------------------------
;; Turn 90 degrees anticlockwise.
;; 		0 (Down),  1 (South), 2 (Right), 3 (East),  4 (Up),   5 (North), 6 (Left), 7 (West)
;; +2 : 2 (Right), 3 (East),  4 (Up), 	 5 (North), 6 (Left), 7 (West),  0 (Down), 1 (South)
.Anticlockwise:
	LD 		A,(IY+O_DIRECTION)							;; dir code (0 to 7 or FF)
	ADD 	A,2											;; plus 2 to turn anti-clockwise 90°
.Mod8MoveDir:
	AND		 &07										;; Modulo 8
.MoveDir:
	LD 		(IY+O_DIRECTION),A							;; update dir : move to new dir
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Turn 180 degree (half-turn).
;; 		0 (Down), 1 (South), 2 (Right), 3 (East), 4 (Up), 	5 (North), 6 (Left),  7 (West)
;; +4 : 4 (Up),   5 (North), 6 (Left),  7 (West), 0 (Down), 1 (South), 2 (Right), 3 (East)
.HalfTurn:
	LD 		A,(IY+O_DIRECTION)							;; dir code (0 to 7 or FF)
	ADD 	A,&04										;; plus 4 gives a 180° turn
	JR 		Mod8MoveDir									;; move to new dir

;; -----------------------------------------------------------------------------------------------------------
;; Move towards the player but only if we enter a box centered around it.
;; eg. used by the BEE in room &DB7 or &1A8 or by the Emperor in room &373!
;; Stay far enough to remain undetected.
RadarRadius				EQU		&18

ObjFnBoxRadar:
	CALL ObjAgain8
	;; Check for collision
	CALL CharDistAndDir
	LD A,RadarRadius
	CP D
	JR c,rdr_undetected									;; if neither U nor V distance is below the "RadarRadius", we remain undetected
	CP E
	JP c,rdr_undetected
	LD A,C												;; else detected, moveTowards the player
	CALL 	DirCode_from_LRDU							;; get dir code (0 to 7 or FF), from LRDU
	LD (IY+O_DIRECTION),A								;; dir code (0 to 7 or FF)
	JP Collision33

.rdr_undetected:
	CALL FaceAndAnimate									;; undetected, don't move, but animate/draw
	JP ObjDraw

;; -----------------------------------------------------------------------------------------------------------
;; Find the direction number associated with zeroing the
;; smaller distance, and then working towards the other dimension.
.HomeIn:
	CALL 	CharDistAndDir								;; get LRDU direction vector and distance in DE between object in IY and curr Char
	LD 		A,D
	CP 		E											;; compare deltaV and deltaU (to get the min)
	LD 		B,&F3										;; (invert D/U if needed)
	JR 		c,hmin_1									;; if deltaU > deltaV, jump hmin_1 with B = &F3 and A=deltaV
	LD 		A,E											;; else B = &FC and A=deltaU
	LD 		B,&FC										;; (invert L/R if needed)
hmin_1:
	AND 	A											;; test min(deltaU, deltaV)
	LD 		A,B											;; A = current bitmap we have in B thus far
	JR 		NZ,hmin_2									;; if not 0, jump hmin_2, else
	XOR 	&0F											;; invert bitmap
hmin_2:
	OR 		C
.MoveToDirMask:
	CALL 	DirCode_from_LRDU							;; get dir code (0 to 7 or FF), from LRDU
	JR 		MoveDir

;; -----------------------------------------------------------------------------------------------------------
;; Compare Enemy and character and get the enemy direction LRDU vector in A
;; "Distance" in DE (deltaV,deltaU)
;; MoveAway : Invert bitmap and Move enemy away from target
;; MoveTowards : Move enemy towards target
.MoveAway:
	CALL 	CharDistAndDir								;; get enemy direction towards character
	XOR 	&0F											;; invert it (flip all [3:0] bits; note that for exemple, a ??11 will become ??00, thus producing a confliction Down/Up hence (probably) ignored as it it were ??11)
	JR 		MoveToDirMask								;; Move away

.MoveTowards:
	CALL 	CharDistAndDir								;; get enemy direction towards character
	JR 		MoveToDirMask								;; Move towards

;; -----------------------------------------------------------------------------------------------------------
;; From an object/Enemy in IY (rather the ref to its variables)
;; get the direction vector to the current character.
;; Return: A is of type LRDU (Left/Right/Down/Up) active low
;; Return: DE has the distance (deltaV in D, deltaU in E)
.CharDistAndDir:
	CALL 	Get_curr_Char_variables						;; HL = pointer on current selected character's variables
	LD 		DE,&0005
	ADD 	HL,DE										;; Curr Char O_U
	LD 		A,(HL)
	INC 	HL											;; Curr Char O_V
	LD 		H,(HL)
	LD 		L,A											;; HL = char V and U
	;; this will prepare the Left/Right info (active low)
	;; that will end up in bits 3 and 2 resp.
	LD 		C,&FF
	LD 		A,H											;; O_V
	SUB 	(IY+O_V)									;; D = deltaV distance Char to object/enemy in V
	LD 		D,A
	JR 		Z,VCoordMatch								;; if 0, jump VCoordMatch, with C=&FF
	JR 		NC,VCoordDiff								;; else if deltaV > 0, jump VCoordDiff with Carry=0
	NEG													;; else D = deltaV = abs(deltaV)
	LD 		D,A
	SCF													;; Carry set
.VCoordDiff:																;; Absolute coord diff in D...
	PUSH 	AF											;; save flag
	RL 		C											;; Update the left bit that will end up in bit pos 3
	POP 	AF											;; get Carry back
	CCF													;; invert it
	RL 		C											;; Update the Right bit that will end up in bit pos 2
.VCoordMatch:
	;; Now add in bits 1 and 0 the Down/up info (active low)
	LD 		A,(IY+O_U)									;; object/enemy O_U
	SUB 	L											;; minus char O_U
	LD 		E,A											;; E = deltaU distance object/enemy to char in U
	JR 		Z,UCoordMatch								;; if deltaU = 0 jump UCoordMatch
	JR 		NC,UCoordDiff								;; else if deltaU > 0, jump UCoordDiff
	NEG													;; E = deltaU = abs(deltaU)
	LD 		E,A
	SCF													;; Carry Set
.UCoordDiff:
	PUSH 	AF											;; save Carry
	RL 		C											;; Update the Down bit that will go to bit pos 1
	POP 	AF											;; restore Carry
	CCF													;; invert it
	RL 		C											;; Update the Up bit that will go to bit pos 0
	LD 		A,C											;; in A we have the LRDU info (active low)
	RET

.UCoordMatch:
	RLC 	C											;; no delta in U, so just push the Left/right
	RLC 	C											;; bits in bit position 3 and 2
	LD 		A,C											;; in A we have the LRDU info (active low)
	RET													;; Direction flag now in A.

;; -----------------------------------------------------------------------------------------------------------
;; If bit 0 of DrawFlags is not set, set it and update the object extents.
.UpdateObjExtents:
	LD 		A,(DrawFlags)								;; get DrawFlags
	BIT 	0,A											;; test bit 0 (object extent set or to be set)
	RET 	NZ											;; if 1 (already set, leave)
	OR 		&01											;; else set it
	LD 		(DrawFlags),A								;; update DrawFlags bit0
	LD 		HL,(CurrObject)								;; get current object
	JP 		StoreObjExtents								;; store object extents

;; -----------------------------------------------------------------------------------------------------------
;; Clear &0C and if any of DrawFlags are set, draw the thing.
.ObjDraw:
	LD 		(IY+&0C),&FF
	LD 		A,(DrawFlags)								;; get DrawFlags (bit1 = needs redraw, bit0 = Extent set)
	AND 	A											;; test
	RET 	Z											;; if 0 (doesn't need redraw)
	CALL 	UpdateObjExtents							;; else if needs redraw ot need new extent, then Update extents
	LD 		HL,(CurrObject)								;; get current object
	CALL 	Relink
	LD 		HL,(CurrObject)
	JP 		UnionAndDraw

;; -----------------------------------------------------------------------------------------------------------
;; From how the object in IY moves, update the anim sprite (forward/backward)
;; and animate + MarkToDraw if it's an animation.
.FaceAndAnimate:
	CALL 	SetFacingDirEx
.AnimateMe
	CALL 	AnimateObj
	RET 	NC
.MarkToDraw:
	LD 		A,(DrawFlags)
	OR 		&02											;; Sets bit 1 of DrawFlags (needs redraw)
	LD 		(DrawFlags),A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; collision check?
ObjAgain6:
	AND (IY+&0C)
	CP &FF
	LD (Collided),A
	RET Z
	CALL 	DirCode_from_LRDU							;; get dir code (0 to 7 or FF), from LRDU
	CP &FF
	LD (Collided),A
	RET Z
	PUSH AF
	LD (Collided),A
	CALL MoveCurr
	POP BC
	CCF
	JP NC,br_501F
	PUSH AF
	CP B
	JR NZ,br_5016
	LD A,&FF
	LD (Collided),A
br_5016:
	CALL UpdateObjExtents
	POP AF
	CALL UpdateCurrPos
	SCF
	RET

br_501F:
	LD A,(ObjDir)
	INC A
	RET Z
ObjAgain7:
	LD A,&06											;; Sound_ID 06
	JP SetSound											;; will RET

;; -----------------------------------------------------------------------------------------------------------
;; check something and return Carry or NotCarry.
;; also deals with object falling or goind up.
;;
;; For exemple, this will turn ObjFnVisor1 into ObjFnLinePatrol (or ObjFnMonocat into ObjFnSquarePatrol)
;; when the result is NC (will reconvert DirCode_to_LRDU).
;; Else the ObjFnVisor1 (or ObjFnMonocat) won't get the new dirCode.
ObjAgain8:
	BIT 4,(IY+&0C)
	JR Z,ObjAgain10
ObjAgain9:
	LD HL,(CurrObject)
	CALL DoContact2
	JR NC,OA9c
	CCF
	JR NZ,OA9b
	BIT 4,(IY+&0C)
	RET NZ
	JR ObjAgain10

OA9b:
	BIT 4,(IY+&0C)
	SCF
	JR NZ,OA9c
	RES 4,(IY+O_IMPACT)
	RET

OA9c:
	PUSH AF												;; save Carry
	CALL UpdateObjExtents
	RES 5,(IY+O_IMPACT)
	INC (IY+O_Z)										;; increase Z coord (goes down)
	LD A,Sound_ID_Didididip								;; falling
	CALL SetSound
	POP AF												;; Restore Carry
	RET c												;; leave if Carry set
	INC (IY+O_Z)										;; else increase Z coord (down) again
	SCF													;; leave with Carry set
	RET

ObjAgain10:
	LD HL,(CurrObject)
	CALL ChkSatOn
	RES 4,(IY+O_IMPACT)
	JR NC,br_5072
	CCF
	RET Z
br_5072
	CALL UpdateObjExtents
	DEC (IY+O_Z)
	SCF
	RET

;; -----------------------------------------------------------------------------------------------------------
;; From direction code in O_DIRECTION (0 to 7 or FF), returns               Up   east
;; the coresponding LRDU (Left/Right/Down/Up) value (active low)   north __________> U              Up
;;             															|05 04 03         	     F6 FE FA
;;                                                                 Left |06 FF 02 Right     Left F7    FB Right
;; This is pretty much the reverse of DirCode_from_LRDU					|07 00 01         	     F5 FD F9
;; Note : "Up" is the far corner, "Down" the near corner           west |  Down  south     	       Down
;;                                                                    V Y
DirCode_to_LRDU:
	LD 		A,(IY+O_DIRECTION)							;; dir code (0 to 7 or FF)
	ADD 	A,DirCode2LRDU_table and &00FF				;; &86 = DirCode2LRDU_table low byte + drection_offset
	LD 		L,A
	ADC 	A,DirCode2LRDU_table / 256					;; &50 = DirCode2LRDU_table high byte
	SUB 	L
	LD 		H,A											;; HL = DirCode2LRDU_table + direction_offset
	LD 		A,(HL)
	RET

.DirCode2LRDU_table:
	;;       					Down south Rght east  Up north left west
	DEFB 	&FD, &F9, &FB, &FA, &FE, &F6, &F7, &F5

;; -----------------------------------------------------------------------------------------------------------
;; This will keep or flip the anim sprite to the forward/backward sprite
;; as required by how the object moves.
;; IY points on the object's object (variables)
.SetFacingDirEx:
	LD 		C,(IY+O_DIRECTION)							;; Read direction code (0 to 7 or FF)
	BIT 	1,C											;; Heading along the V axis if 0 (Up-Down (sw<->ne) or n<->s), or along the U axis if 1 (Left-Right (nw<->se) or e<->w)
	RES 	4,(IY+O_FLAGS)								;; Set bit 4 of flags, as NOT(bit1) of direction code.
	JR 		NZ,SetFacingDir
	SET 	4,(IY+O_FLAGS)								;; roughly Flag[4] = 0 : U axis Left/Right; if 1 : V axis Down/Up
.SetFacingDir:
	LD 		A,(IY+O_ANIM)				 				;; Load [7:3] = anim code, [2:0] = frame
	AND 	A											;; test
	RET 	Z											;; Return if not animated
	BIT 	2,C											;; Heading roughly away (Up,North,Left,West) if 1; or towards us (Down,South,Right,East) if 0
	LD 		C,A											;; anim code [7:3] + frame [2:0] in C
	JR 		Z,sfd_2										;; if Front towards us, goto sfd_2
	BIT 	3,C											;; anim code bit 3 if 0: forward sprite, if 1: backward version
	RET 	NZ											;; leave if backward
	LD 		A,&08										;; else (if forward sprite) A = 8
	JR 		sfd_1										;; skip to sfd_1
sfd_2:
	BIT 	3,C											;; test bit3 of anim code if 0: forward sprite, if 1: backward version
	RET 	Z											;; leave if forward
	XOR 	A											;; else (backward sprite) A = 0
sfd_1:
	XOR 	C											;; flip the forward/backward sprite as required
	AND 	&0F
	XOR 	C
	LD 		(IY+O_ANIM),A								;; [7:3] = anim code, [2:0] = frame
	RET

;; -----------------------------------------------------------------------------------------------------------
;; This is most likely a left over copy of some code (see 503A-504F)
;; Maybe was compiled at this addr at some point and this stayed in mem or on the dsk???
;; Anyway, this is most likely garbage data in the "HEADOVER.I" loaded data;
;; Section not used apparently. It is most likely a gap between the 1) the code upto 50B9
;; and 2) the block composed of data (50D0 to 65FF), buffers (6600-70EF), gfx (70F0-B897)
;; and savebuff (B898-...). Reminder : the block from 6600 to ADBF after loading is
;; moved by init routine to 70D8-B897 (+0AD8)
;;
;;.Garbage:
	;; 50BA DEFB FD CB 0C 66 C0 18
	;; 50C0 DEFB 23 FD CB 0C 66 37 20 05 FD CB	0B A6 C9 F5 CD B6
	;;
	;; Notice how these bytes are a copy of addr 503A-504F
	;; 50BA FD CB 0C 66 	; bit 4,(IY+&0C)			; same as 503A
	;; 50BE C0				; ret nz					; same as 503E
	;; 50BF 18 23			; jr ObjAgain10				; same as 503F
	;; 50C1 FD CB 0C 66		; bit 4,(IY+&0C)
	;; 50C5 37				; scf
	;; 50C6 20 05			; jr nz,OA9c				; ...
	;; 50C8 FD CB 0B A6		; res 4,(IY+&0B)
	;; 50CC C9				; ret
	;; 50CD F5				; push af					; same as 504D
	;; 50CE CD B6 ??		; call &<??0c??>b6 (UpdateObjExtents)


						org		&50D0

;; -----------------------------------------------------------------------------------------------------------
;; These macros are used when processing the Room_list1 and 2 data to build a room
;; They define groups of objects that can be imported as a block. See algo in Room_list1 below.
Room_Macro_data: 														;; MacroID &C0 to &DB
	;; <Length> <macroID> <Macro data N bytes>
	;; note: the length includes the MacroID byte but not the length byte
	DEFB &0C, &C0, &02, &CE, &77, &33, &96, &4F, &26, &92, &FE, &3F, &C0					;; Macro C0: 2*3 Gratings
	DEFB &07, &C1, &C0, &43, &E0, &01, &FF, &C0											;; Macro C1: 4*3 Gratings
	DEFB &12, &C2, &16, &D2, &FB, &3C, &7D, &CF, &27, &FC, &0A, &69, &75, &9A, &3C, &E6, &FC, &7F, &80	;; etc.
	DEFB &08, &C3, &16, &CA, &77, &3C, &9F, &F1, &FE
	DEFB &0B, &C4, &C3, &23, &E1, &E1, &C5, &B6, &9F, &CF, &F8, &FF
	DEFB &0C, &C5, &0E, &C6, &75, &3B, &9E, &4F, &67, &D3, &FE, &3F, &C0
	DEFB &08, &C6, &17, &D2, &79, &34, &97, &F1, &FE
	DEFB &0E, &C7, &0E, &CB, &73, &79, &5D, &1F, &4F, &CB, &EB, &EE, &FF, &8F, &F0
	DEFB &0E, &C8, &0E, &CA, &74, &FB, &5E, &2F, &5F, &B3, &CB, &DD, &FF, &8F, &F0
	DEFB &0C, &C9, &C8, &03, &87, &62, &79, &DF, &6F, &8F, &FC, &7F, &80
	DEFB &08, &CA, &18, &D2, &79, &34, &97, &F1, &FE
	DEFB &09, &CB, &00, &CE, &79, &3C, &7D, &BF, &F8, &FF
	DEFB &0C, &CC, &16, &D0, &F8, &BC, &7E, &4F, &2F, &9B, &FE, &3F, &C0
	DEFB &0F, &CD, &02, &F2, &F9, &74, &B6, &3F, &1E, &8E, &C9, &E4, &D2, &5F, &C7, &F8
	DEFB &08, &CE, &1E, &D1, &F9, &34, &B7, &F1, &FE
	DEFB &10, &CF, &30, &CC, &F7, &BA, &BD, &DF, &2F, &33, &D9, &DC, &ED, &F6, &BF, &E3, &FC
	DEFB &12, &D0, &CA, &AB, &E5, &5B, &F2, &95, &F9, &49, &70, &DD, &B4, &C6, &13, &0E, &9F, &8F, &F0
	DEFB &08, &D1, &24, &D2, &79, &34, &97, &F1, &FE
	DEFB &0B, &D2, &CC, &63, &E6, &41, &F1, &03, &F8, &82, &7F, &F0
	DEFB &0E, &D3, &0E, &D0, &F8, &BC, &7E, &4F, &2F, &9B, &CF, &E0, &FF, &8F, &F0
	DEFB &08, &D4, &05, &D2, &79, &34, &93, &F1, &FE
	DEFB &0A, &D5, &0F, &4E, &75, &9F, &1F, &CB, &DF, &8F, &F0
	DEFB &0E, &D6, &38, &F1, &E9, &34, &BB, &F0, &1F, &A3, &F2, &79, &7F, &E3, &FC
	DEFB &0E, &D7, &39, &F1, &E9, &34, &BB, &F0, &1F, &A3, &F2, &79, &7F, &E3, &FC
	DEFB &0B, &D8, &D7, &8B, &EB, &CB, &F5, &9D, &FA, &CD, &7F, &F0
	DEFB &10, &DA, &39, &CA, &67, &34, &9A, &CD, &F8, &0F, &EA, &77, &3C, &9E, &CF, &F8, &FF
	DEFB &10, &D9, &38, &CA, &67, &34, &9A, &CD, &F8, &0F, &EA, &77, &3C, &9E, &CF, &F8, &FF
	DEFB &10, &DB, &3A, &FC, &EE, &B6, &5F, &4F, &F8, &3B, &FD, &EF, &36, &3F, &3F, &F8, &FF
	DEFB &00

;; -----------------------------------------------------------------------------------------------------------
;; Room_list1 + Room_list2 = 230 + 71 rooms = 301 rooms
;; 		Note that the victory room is in fact composed of 2 rooms : &8D30 and &8E30.
;; Format:
;; <length> <high_id> <low_id in [7:4]; data in [3:0]> <data n bytes>
;; until length = 0. (Note that the room ID is in Big-Endian format)
;;
;; The data is shifted by one nibble in the roomID low byte.
;; For exemple, looking at Head's first room data at address 54C7:
;; 		54C7 10 8A 43 F8 01 02 01 3E E0 58 62 33 1A 8D FF 1F E0
;; Length = &10 (16 bytes of data not including length byte)
;; RoomID = &8A4  (1.5 bytes: "8A 4X" with low nibble ignored because it is data)
;; So the data are:  X3 F8 01 02 01 3E E0 58 62 33 1A 8D FF 1F E0
;;         0011_1111_1000_0000_0001_0000_0010_0000_0001_0011_1110_1110...
;;
;; The data is bit packed: 001_111_111_000_000_000_010_000_001_00000000__10_0_111_110_111_...
;; First 3 bits = Room Dimensions (see RoomDimensions table at addr 1ECE)
;; 			here "001" = "MinU=8, MinV=16, MaxU=72, MaxV=64"
;; Next 3 bits is Color Scheme (see array_Color_Schemes at addr 0554)
;;			here "111" = 7 (Black, Red, Blue, Pastel_yellow)
;; Next 3 bits is WorldId (see WorldId at 1EBF), to choose the walls sprites
;;			here "111" = 7 (Prison)
;; Next 3 bits is Door sprite Id (see ToDoorId at 045D) can be 0 to 3
;;   although ToDoorId will convert it to 0 to 2 to use one of the 3 types
;;   of door sprites. Here "000" = 0 : Doorway type 0.
;; Next 4x3 bits are the Walls&Doors data for FarLeft, FarRight, NearRight and  NearLeft sides
;; 			here "000 000 010 000" means Wall/NoDoor, Wall/NoDoor, Wall+Door at ground level, Wall/NoDoor
;; Next 3 bits defines the Floor tile to use.
;;			here "001" = 1 : uses floor_tile_pattern1
;; Then it will loop over the objects in the room or the Macros to use.
;; 	 * 8 bits = Object ID (as defined in the ObjDefns table at 38C9)
;;                 or (if value >= &C0) Macro ID in the Room_Macro_data table at 50D0).
;;				Here "00000000" = object ID 0 = ANIM_TELEPORT (the Teleport_data at addr 3490 says that
;;				room "8A4" goes to room "715")
;;		if Object:
;;			* 2 bits : controls how many objects of current type will be inserted ("?0" = 1; "?1" = several)
;;              and how orientation flag will be applied to the object(s) ("1?"=global, "0?"=per object);
;;				So we can have:
;;					only 1b more fetched to be used as the global orientation flag (no other bit inserted
;; 						between coordinates if several objects to get);
;;					or 1b orientation flag fetched before each set of coordinates.
;;						Here 2b flag = "10" : 1 object of current type ANIM_TELEPORT and 1b more to fetch.
;;          Loop (1 time or until coordinates = "7, 7, 0" (which means "end") as defined in the 2bit flag):
;;				1b : NoFlip/Flip bit. Global (only first loop) or per-object flag (every loop)
;;					Here 1b flag = "0" (NO Flip; if it is "1" then flip the sprite)
;;				3x3 bits: UVZ coordinates;
;;					Here "111 110 111" = U=7, V=6, Z=7 (ground level). Because only 1 object needed to be
;;						fetched (2b flag "?0"), it goes back to fetching next object/macro Id, which here is
;;                      SPR_GRATING, flag "11" (several/global), global orientation flag = "0" (No Flip)
;;                      and 4 coords fetched 0;6;1 0;6;3 0;6;5 0;6;7 (then the ending code 7;7;0).
;;						That finishes the data for that room.
;;						Note that the Special object "SPR_BUNNY (lives)" at 0;6;0 is added in another routine
;;						and is not part of the room data.
;;		if Macro:
;;			* 3x3 bits for origin offset coordinate added to all objects in the macro;
;;				Then it loops to fetching 8b object id or Macro id until the code is "FF" to leave
;;				the macro and go back where we were in the room data.
Room_list1: ;; 230 rooms
	;; <length> <high_id> <low_id in [7:4]; data in [3:0]> <next data N bytes>
	;; until length = 0
	DEFB &1A, &12, &01, &61, &FC, &05, &92, &07, &20, &CA, &FA, &BF, &E0, &93, &0F, &CF, &CB, &D7, &E7, &33, &A9, &DC, &E7, &73, &FF, &1F, &E0		;; RoomID "120"
	DEFB &0B, &1D, &01, &E1, &08, &05, &B0, &07, &CB, &03, &FF, &80													;; RoomID "1D0"
	DEFB &0C, &22, &05, &21, &08, &24, &4B, &95, &F1, &7D, &7F, &E3, &FC
	DEFB &1D, &24, &00, &E1, &10, &3C, &3F, &38, &E2, &73, &FC, &03, &3C, &F8, &57, &72, &1D, &16, &87, &11, &FF, &FF, &81, &6D, &17, &0F, &89, &FF, &1F, &E0
	DEFB &08, &26, &0F, &A1, &08, &05, &96, &07, &FF
	DEFB &10, &2D, &03, &A1, &04, &25, &B4, &2F, &0C, &97, &70, &FB, &77, &D9, &EB, &FF, &80
	DEFB &1A, &32, &00, &E1, &08, &24, &4B, &AF, &F0, &7F, &C0, &76, &EB, &D3, &D9, &EC, &76, &FC, &7E, &BF, &A7, &D7, &CB, &E7, &FF, &8F, &F0
	DEFB &12, &35, &0F, &E1, &21, &85, &8A, &3E, &C5, &1F, &85, &64, &79, &3C, &CE, &6F, &FC, &7F, &80
	DEFB &09, &36, &0F, &E1, &00, &A4, &25, &0E, &FF, &E0
	DEFB &0B, &3C, &03, &A1, &28, &05, &B4, &2F, &D9, &0B, &FF, &80
	DEFB &12, &3D, &03, &A1, &40, &94, &19, &36, &E7, &10, &ED, &B4, &2F, &0F, &E7, &7D, &BF, &E3, &FC
	DEFB &08, &3E, &0B, &61, &09, &05, &B2, &1F, &FF
	DEFB &10, &43, &0C, &21, &C1, &05, &9D, &D7, &CE, &0B, &8F, &69, &EC, &DA, &5F, &F8, &FF
	DEFB &0E, &45, &09, &32, &40, &0B, &81, &87, &C1, &03, &80, &EC, &3F, &E3, &FC
	DEFB &0F, &46, &0E, &72, &41, &0A, &5D, &09, &E5, &FB, &4F, &1F, &53, &FE, &3F, &C0
	DEFB &1F, &47, &08, &32, &01, &0A, &09, &37, &E2, &33, &5E, &15, &33, &E3, &B0, &CF, &82, &07, &0E, &C9, &F4, &BF, &E0, &0B, &19, &8C, &AA, &55, &32, &9F, &F1, &FE
	DEFB &0D, &4C, &0E, &21, &00, &25, &B2, &17, &DA, &17, &E5, &81, &FF, &C0
	DEFB &0D, &4E, &0F, &21, &00, &25, &B2, &17, &DA, &17, &E5, &81, &FF, &C0
	DEFB &08, &81, &0F, &61, &40, &05, &96, &07, &FF
	DEFB &10, &82, &01, &E1, &1F, &8C, &1F, &38, &24, &9B, &85, &C4, &F2, &31, &3F, &1F, &E0
	DEFB &0D, &84, &03, &E1, &08, &05, &AF, &0F, &D7, &9B, &E5, &81, &FF, &C0									;; Room ID "840" Moon Base Teleporters to Penitentiary "B10"
	DEFB &0B, &85, &01, &A1, &08, &05, &B0, &07, &CB, &0F, &FF, &80											;; Room ID "850" Moon Base Teleporters to Book World "EF2"
	DEFB &06, &87, &0F, &E1, &48, &05, &FE
	DEFB &08, &88, &0F, &A1, &01, &05, &96, &07, &FF
	DEFB &06, &92, &07, &61, &48, &25, &FE
	DEFB &08, &93, &0C, &61, &41, &05, &AF, &C7, &FF
	DEFB &08, &94, &00, &A1, &49, &25, &9E, &47, &FF															;; Room ID "940" first Moon Base "Arrow" room (access to rooms 840 and A40)
	DEFB &08, &95, &00, &E1, &49, &25, &9E, &47, &FF															;; Room ID "950" 2nd Moon Base "Arrow" room (access to rooms 850 and A50)
	DEFB &0B, &96, &0D, &21, &41, &04, &1F, &1A, &FA, &FC, &7F, &F0
	DEFB &06, &97, &07, &61, &09, &25, &FE
	DEFB &08, &A1, &0F, &61, &40, &05, &96, &07, &FF
	DEFB &0D, &A2, &00, &21, &03, &25, &86, &24, &CC, &9E, &67, &45, &FF, &C0
	DEFB &0D, &A4, &02, &61, &00, &25, &AC, &CF, &D6, &7B, &E5, &81, &FF, &C0									;; Room ID "A40" Moon Base Teleporters to Safari "00F"
	DEFB &0B, &A5, &01, &61, &00, &25, &B0, &07, &CB, &03, &FF, &80											;; Room ID "A50" Moon Base Teleporters to Egyptus "88D"
	DEFB &0B, &A7, &0E, &21, &C0, &24, &19, &31, &F9, &C0, &FF, &F0
	DEFB &0B, &A8, &00, &61, &01, &05, &B0, &07, &CB, &03, &FF, &80
	DEFB &08, &B1, &02, &5B, &08, &07, &96, &07, &FF
	DEFB &19, &C1, &00, &1B, &FC, &26, &23, &1E, &B9, &CF, &72, &4C, &C7, &83, &B3, &E1, &F3, &CF, &23, &F1, &E8, &F7, &7B, &7E, &3F, &C0
	DEFB &1A, &C2, &01, &5B, &81, &8C, &3F, &08, &E1, &F8, &FC, &7F, &FC, &08, &6F, &F8, &1F, &F0, &49, &BC, &EF, &F9, &FC, &1D, &8F, &F8, &FF
	DEFB &14, &C3, &0F, &1B, &01, &06, &43, &A6, &EF, &7F, &C1, &26, &38, &3C, &4E, &6B, &5D, &76, &D7, &F1, &FE
	DEFB &1E, &D1, &0B, &DB, &00, &26, &03, &2A, &01, &F9, &2E, &8F, &B3, &FE, &08, &F2, &59, &1D, &65, &B7, &7E, &09, &35, &46, &85, &4B, &BF, &D7, &3F, &1F, &E0
	DEFB &19, &89, &41, &78, &40, &02, &1D, &38, &E0, &10, &0F, &82, &47, &C1, &A3, &83, &68, &3E, &1E, &8E, &C7, &43, &91, &FF, &1F, &E0			;; Heels' 1st room, id &8940
	DEFB &10, &8A, &43, &F8, &01, &02, &01, &3E, &E0, &58, &62, &33, &1A, &8D, &FF, &1F, &E0							;; Head's 1st room, id &8A40
	DEFB &0B, &61, &59, &38, &14, &0E, &2D, &B3, &FA, &7F, &C7, &F8													;; Head's 3rd room, id &6150
	DEFB &0E, &64, &51, &78, &10, &0E, &2D, &3B, &E2, &F3, &DE, &09, &3F, &FF, &E0
	DEFB &09, &71, &53, &40, &00, &22, &01, &3E, &FF, &E0																;; Head's 2nd room, id &7150
	DEFB &11, &74, &54, &80, &04, &3C, &03, &A3, &E9, &FF, &C0, &B6, &CF, &F7, &C3, &FF, &8F, &F0
	DEFB &0F, &84, &54, &80, &80, &1C, &2F, &13, &E2, &DA, &5F, &1F, &0F, &FE, &3F, &C0
	DEFB &06, &85, &5E, &00, &09, &03, &FE
	DEFB &11, &95, &55, &00, &08, &22, &1B, &0A, &E2, &13, &AE, &37, &9D, &F2, &7A, &BF, &E3, &FC
	DEFB &0B, &A5, &5E, &F8, &00, &3E, &2D, &8B, &E6, &7F, &C7, &F8
	DEFB &0E, &24, &6F, &00, &A4, &03, &8E, &07, &16, &CF, &79, &BB, &DB, &F1, &FE
	DEFB &08, &25, &62, &78, &01, &8F, &88, &2F, &FF
	DEFB &15, &30, &61, &C0, &80, &0D, &8C, &FF, &C6, &1F, &E2, &07, &C5, &B7, &F7, &FD, &07, &83, &41, &7F, &1F, &E0
	DEFB &0D, &31, &65, &40, &11, &02, &03, &1D, &F9, &50, &F1, &18, &EE, &FF
	DEFB &0D, &34, &6F, &00, &14, &13, &8E, &07, &0A, &CD, &F9, &3F, &E3, &FC
	DEFB &06, &41, &66, &40, &48, &23, &FE
	DEFB &08, &42, &6E, &00, &21, &03, &8A, &07, &FF
	DEFB &08, &43, &6E, &00, &40, &83, &8A, &3F, &FF
	DEFB &13, &44, &61, &F8, &49, &2B, &88, &05, &C4, &1E, &E2, &03, &F1, &01, &D8, &83, &6C, &41, &BF, &F8
	DEFB &12, &45, &6C, &C0, &E3, &8C, &2F, &9C, &92, &4F, &C0, &B6, &7E, &4F, &18, &90, &4F, &C7, &F8
	DEFB &08, &46, &6F, &C0, &49, &03, &8E, &07, &FF
	DEFB &16, &47, &69, &80, &01, &02, &33, &1F, &E3, &51, &4D, &82, &07, &02, &CA, &55, &39, &94, &CC, &67, &FC, &7F, &80
	DEFB &0B, &51, &66, &C0, &48, &22, &1F, &94, &E9, &FF, &C7, &F8
	DEFB &19, &52, &60, &80, &01, &8C, &23, &03, &C2, &10, &6C, &2F, &BB, &FC, &7F, &C0, &B6, &FF, &8D, &C3, &E0, &76, &3C, &1F, &F1, &FE
	DEFB &06, &54, &67, &00, &08, &23, &FE
	DEFB &06, &56, &67, &40, &08, &23, &FE
	DEFB &09, &61, &69, &00, &00, &22, &09, &33, &FF, &E0
	DEFB &0E, &64, &61, &40, &00, &22, &19, &18, &E2, &32, &7E, &09, &3F, &FF, &E0
	DEFB &11, &66, &61, &00, &40, &22, &39, &C7, &FF, &FE, &3F, &E0, &77, &37, &E4, &FF, &8F, &F0
	DEFB &0B, &67, &6F, &C0, &25, &02, &33, &0C, &F9, &00, &7F, &F0
	DEFB &08, &68, &6F, &C0, &40, &83, &90, &07, &FF
	DEFB &1C, &69, &61, &80, &1D, &02, &0D, &16, &80, &91, &1F, &95, &B7, &CA, &CB, &8A, &E4, &DA, &8D, &57, &F8, &16, &C9, &44, &E2, &91, &59, &F8, &FF
	DEFB &08, &77, &6F, &C0, &40, &13, &90, &07, &FF
	DEFB &10, &78, &68, &80, &C1, &02, &37, &64, &E1, &72, &3A, &0B, &A3, &F1, &EF, &C7, &F8
	DEFB &06, &79, &6F, &C0, &09, &23, &FE
	DEFB &15, &89, &60, &00, &10, &3C, &2F, &26, &F9, &41, &FC, &41, &38, &B6, &8F, &F9, &FB, &E2, &70, &FF, &E3, &FC
	DEFB &0B, &99, &6E, &78, &00, &4E, &2D, &8C, &E5, &FF, &C7, &F8
	DEFB &12, &A5, &6E, &C0, &FC, &02, &09, &0B, &E2, &32, &4E, &17, &92, &F5, &7B, &7A, &BF, &F1, &FE
	DEFB &06, &A6, &6D, &80, &41, &03, &FE
	DEFB &0B, &A7, &6D, &C0, &41, &02, &03, &21, &E3, &76, &3F, &FE
	DEFB &0B, &A8, &6E, &38, &01, &8E, &2D, &99, &F0, &FF, &C7, &F8
	DEFB &1D, &B5, &63, &40, &04, &3C, &0D, &A5, &F6, &FF, &7E, &BF, &F0, &13, &8B, &F1, &F8, &7F, &E0, &23, &13, &D9, &FF, &81, &6C, &1F, &13, &FE, &3F, &C0
	DEFB &1C, &C5, &63, &40, &00, &1C, &2D, &BE, &FE, &FF, &3F, &E0, &23, &69, &F3, &F9, &7C, &7C, &3D, &3E, &AF, &FC, &03, &64, &79, &BC, &5F, &F8, &FF
	DEFB &16, &05, &7F, &78, &10, &0E, &09, &0E, &E1, &3B, &6F, &9F, &D3, &EB, &FF, &00, &D9, &EF, &37, &BB, &FE, &3F, &C0
	DEFB &1A, &14, &70, &80, &80, &0C, &17, &39, &F8, &79, &7C, &3C, &7E, &20, &7C, &4E, &47, &C5, &21, &D8, &27, &75, &79, &BC, &5F, &C7, &F8
	DEFB &0B, &15, &74, &00, &15, &22, &15, &02, &E2, &B1, &CF, &FE
	DEFB &0B, &25, &72, &40, &00, &22, &19, &31, &E0, &93, &91, &FE
	DEFB &15, &98, &70, &C8, &48, &0A, &1D, &3F, &E2, &FB, &FC, &06, &FC, &0B, &60, &79, &1F, &7F, &F7, &FC, &7F, &80		;; Market Reunion room id &9870
	DEFB &06, &99, &7E, &48, &01, &0B, &FE
	DEFB &09, &A8, &7E, &08, &14, &2A, &17, &09, &FF, &E0
	DEFB &14, &B8, &70, &48, &10, &3C, &27, &38, &F8, &49, &7C, &2B, &78, &B6, &F3, &FB, &C2, &E1, &FF, &C7, &F8
	DEFB &08, &BA, &73, &F8, &08, &0B, &96, &07, &FF
	DEFB &06, &C8, &76, &C8, &40, &2B, &FE
	DEFB &10, &C9, &7D, &88, &41, &0A, &1D, &9B, &ED, &E8, &F4, &99, &CC, &E7, &FC, &7F, &80
	DEFB &0E, &CA, &70, &88, &41, &2A, &19, &3C, &E3, &38, &0E, &3F, &FC, &7F, &80
	DEFB &08, &CB, &7E, &08, &09, &0B, &92, &07, &FF
	DEFB &10, &DB, &72, &48, &08, &2A, &4D, &23, &E4, &39, &EF, &37, &2F, &E7, &FF, &1F, &E0
	DEFB &0B, &EB, &78, &38, &00, &3E, &2D, &8C, &E5, &FF, &C7, &F8
	DEFB &0B, &04, &81, &80, &A0, &02, &03, &24, &E0, &10, &0F, &FE
	DEFB &0E, &05, &8F, &40, &01, &02, &1D, &31, &E1, &33, &2C, &09, &0E, &1F, &E0
	DEFB &19, &09, &83, &B8, &10, &1C, &0D, &06, &F9, &8C, &71, &79, &4F, &25, &8E, &EC, &CA, &39, &0E, &67, &B3, &9D, &EA, &FF, &C7, &F8
	DEFB &19, &0B, &83, &38, &04, &3C, &2D, &39, &E0, &33, &1F, &99, &07, &06, &D3, &7B, &BF, &DF, &6F, &F8, &0B, &C4, &F4, &7F, &E3, &FC
	DEFB &1D, &19, &81, &F8, &48, &61, &99, &04, &0E, &C4, &92, &08, &1F, &F0, &0B, &89, &44, &22, &79, &38, &9A, &4C, &25, &B1, &D0, &C4, &52, &1F, &E3, &FC
	DEFB &17, &1A, &8D, &78, &E1, &01, &9C, &07, &CE, &E3, &93, &49, &39, &1E, &7E, &4F, &3F, &04, &99, &E9, &34, &FC, &7F, &80
	DEFB &18, &1B, &83, &38, &01, &9D, &88, &2F, &17, &87, &70, &68, &37, &01, &D3, &7F, &7F, &E0, &5B, &7D, &D6, &F1, &7F, &C7, &F8
	DEFB &0F, &29, &80, &80, &00, &21, &9B, &EF, &C1, &3F, &E5, &B7, &F2, &DD, &FF, &E0
	DEFB &08, &E9, &81, &00, &48, &01, &96, &07, &FF
	DEFB &15, &EA, &8C, &78, &43, &0A, &43, &98, &F0, &7F, &C0, &B6, &6F, &B7, &9B, &91, &D8, &E4, &7A, &3F, &F8, &FF
	DEFB &09, &EB, &88, &38, &09, &0A, &09, &0B, &FF, &E0
	DEFB &10, &F9, &8F, &B8, &24, &3C, &0D, &36, &E2, &D8, &BE, &67, &3B, &9B, &FF, &1F, &E0
	DEFB &19, &FA, &89, &B8, &00, &8C, &2F, &27, &F9, &88, &F2, &59, &0E, &C5, &17, &E6, &53, &C2, &36, &1F, &F0, &2D, &88, &FF, &8F, &F0
	DEFB &13, &FB, &84, &F8, &1C, &21, &9C, &FF, &11, &9E, &E0, &A9, &EF, &1E, &DE, &7F, &37, &7F, &F1, &FE
	DEFB &09, &03, &91, &9B, &0C, &0E, &09, &1C, &FF, &E0
	DEFB &11, &11, &9B, &1B, &08, &07, &98, &7C, &00, &94, &30, &3C, &BF, &A3, &DF, &FF, &1F, &E0
	DEFB &06, &13, &96, &9B, &08, &27, &FE
	DEFB &0F, &20, &9D, &DB, &A0, &0F, &99, &CF, &CC, &07, &8E, &E6, &B4, &5B, &F1, &FE
	DEFB &0E, &21, &90, &1B, &43, &67, &9D, &3F, &16, &CC, &76, &23, &1B, &F1, &FE
	DEFB &13, &22, &9D, &DB, &81, &8C, &5B, &1E, &E1, &DA, &3F, &1E, &6F, &7E, &05, &B3, &FD, &8F, &F8, &FF
	DEFB &13, &23, &91, &9B, &01, &BC, &5B, &0C, &E1, &D9, &FC, &FF, &E3, &7E, &05, &B4, &1C, &4F, &F8, &FF
	DEFB &11, &03, &A1, &99, &00, &0E, &09, &1C, &FA, &40, &71, &7D, &27, &B3, &E9, &FF, &1F, &E0
	DEFB &0C, &0D, &A3, &D3, &80, &0E, &2D, &86, &F3, &77, &BF, &E3, &FC
	DEFB &09, &0E, &A8, &53, &41, &28, &63, &24, &FF, &E0
	DEFB &0F, &0F, &A8, &93, &01, &28, &23, &77, &D8, &A0, &FC, &50, &BE, &28, &7F, &FC
	DEFB &14, &20, &AD, &DB, &00, &0E, &07, &21, &D9, &9F, &FC, &C1, &F8, &EE, &77, &3B, &65, &D2, &DF, &C7, &F8
	DEFB &0D, &D0, &A8, &D3, &09, &08, &23, &4C, &E3, &31, &CF, &82, &37, &FF
	DEFB &11, &DE, &A1, &D3, &80, &0E, &2F, &2F, &E2, &DA, &7E, &FF, &FF, &FB, &C7, &FF, &8F, &F0
	DEFB &06, &DF, &AD, &93, &41, &09, &FE
	DEFB &1F, &E0, &A8, &53, &08, &29, &8A, &37, &C5, &13, &E2, &8B, &C5, &E5, &0B, &31, &75, &8C, &9E, &21, &D7, &F7, &FF, &E0, &5B, &40, &B7, &EB, &E5, &FF, &E3, &FC
	DEFB &08, &F0, &AE, &93, &01, &29, &8E, &07, &FF
	DEFB &0D, &FE, &A0, &13, &90, &0C, &2F, &3E, &F9, &8F, &FC, &40, &FF, &F8
	DEFB &06, &FF, &AB, &53, &49, &09, &FE
	DEFB &18, &03, &B1, &99, &00, &0E, &47, &20, &1A, &40, &72, &4D, &1B, &91, &FE, &05, &F4, &26, &24, &E4, &52, &99, &BF, &1F, &E0
	DEFB &09, &0D, &B3, &D3, &00, &0E, &09, &06, &FF, &E0
	DEFB &0B, &10, &B0, &9B, &08, &27, &A0, &07, &CB, &17, &FF, &80
	DEFB &12, &20, &BD, &DB, &00, &26, &23, &20, &F9, &9C, &BC, &C0, &58, &EE, &69, &44, &BF, &1F, &E0
	DEFB &0C, &2C, &B7, &D3, &80, &0E, &47, &83, &EE, &79, &3F, &E3, &FC
	DEFB &0B, &2D, &B0, &13, &41, &09, &A0, &07, &CB, &03, &FF, &80
	DEFB &16, &2E, &B1, &93, &01, &08, &49, &1C, &21, &71, &B9, &A3, &C4, &D1, &FF, &E8, &F1, &C4, &77, &7C, &3F, &F8, &FF		;; Egyptus Crown room
	DEFB &17, &DE, &B1, &D3, &00, &0E, &09, &3D, &E0, &59, &FA, &F9, &7D, &FE, &05, &B7, &97, &AC, &38, &3F, &F1, &FF, &1F, &E0
	DEFB &1D, &03, &C1, &9B, &00, &3E, &55, &3E, &C1, &53, &FC, &2F, &09, &FA, &40, &71, &6C, &7C, &5E, &F0, &79, &7D, &3E, &EF, &73, &B6, &FD, &FC, &7F, &80
	DEFB &0B, &0C, &CD, &13, &E0, &0E, &2D, &9F, &93, &CF, &C7, &F8
	DEFB &0B, &0D, &C3, &D3, &01, &08, &39, &03, &E0, &90, &6F, &FE
	DEFB &0B, &2C, &C7, &D3, &00, &0E, &09, &03, &F8, &80, &7F, &F0
	DEFB &0B, &D1, &C1, &DB, &10, &0F, &88, &07, &C4, &1F, &FF, &80
	DEFB &0C, &D4, &C6, &5B, &10, &0E, &49, &BC, &FD, &F8, &FF, &E3, &FC
	DEFB &08, &DC, &CF, &93, &10, &0F, &98, &87, &FF
	DEFB &14, &DE, &C1, &D3, &14, &0E, &09, &38, &E2, &DB, &AC, &78, &1C, &BF, &47, &63, &FF, &37, &7B, &F1, &FE
	DEFB &10, &E1, &C8, &1B, &20, &26, &01, &28, &62, &D2, &F8, &2F, &2E, &99, &87, &CF, &F0
	DEFB &12, &E2, &C8, &1B, &80, &86, &07, &13, &E0, &12, &F7, &98, &7C, &17, &D7, &CB, &A7, &E3, &FC
	DEFB &12, &E3, &C0, &DB, &4B, &07, &A3, &1F, &C3, &12, &0F, &32, &20, &9B, &07, &00, &EF, &C7, &F8
	DEFB &0B, &E4, &CE, &1B, &01, &26, &63, &36, &9A, &29, &7F, &F0
	DEFB &12, &EC, &CF, &53, &20, &3C, &1D, &15, &E0, &70, &AC, &55, &56, &F9, &88, &7C, &CA, &3F, &F8
	DEFB &0E, &ED, &CF, &53, &80, &8D, &98, &87, &16, &C4, &F9, &BB, &DF, &F1, &FE
	DEFB &06, &EE, &CE, &D3, &03, &29, &FE
	DEFB &0E, &F3, &C4, &5B, &14, &26, &15, &1C, &E2, &39, &BF, &27, &FC, &7F, &80
	DEFB &16, &03, &DF, &99, &00, &06, &23, &23, &C0, &31, &CC, &17, &92, &F5, &75, &7B, &7E, &3F, &27, &73, &FE, &3F, &C0
	DEFB &06, &0C, &DD, &13, &08, &09, &FE
	DEFB &16, &1C, &D3, &93, &08, &28, &23, &26, &FA, &2E, &F0, &D8, &8E, &24, &DC, &CE, &5A, &3D, &9F, &8F, &FC, &7F, &80
	DEFB &1C, &2C, &D7, &D3, &00, &28, &03, &14, &41, &51, &BE, &1F, &AC, &5A, &3F, &27, &77, &F0, &49, &94, &6E, &39, &27, &9F, &4D, &65, &FC, &7F, &80
	DEFB &08, &88, &D0, &13, &40, &09, &96, &07, &FF
	DEFB &19, &89, &D1, &93, &E1, &88, &03, &1E, &79, &C0, &71, &1C, &D7, &8B, &FE, &09, &33, &1E, &0E, &F4, &9A, &3F, &27, &9F, &8F, &F0
	DEFB &09, &8A, &DC, &D3, &C1, &08, &03, &24, &FF, &E0
	DEFB &0F, &8B, &D0, &93, &09, &09, &A0, &07, &16, &CE, &79, &3B, &7E, &3F, &F8, &FF
	DEFB &08, &9B, &DF, &13, &48, &29, &8E, &07, &FF
	DEFB &0E, &9C, &D1, &93, &1D, &09, &95, &C7, &28, &CE, &44, &BA, &5B, &F1, &FE
	DEFB &15, &AB, &D1, &93, &E0, &6C, &53, &80, &94, &4F, &E7, &53, &89, &F8, &16, &CF, &C9, &E0, &90, &39, &F8, &FF
	DEFB &0D, &AC, &D1, &D3, &09, &29, &A0, &07, &11, &CA, &7B, &3F, &E3, &FC
	DEFB &10, &BC, &D4, &53, &08, &28, &07, &3A, &E2, &D0, &46, &01, &04, &58, &80, &BF, &F0
	DEFB &12, &CC, &D1, &53, &FC, &28, &3D, &3C, &99, &CF, &7C, &30, &E0, &B6, &5F, &2F, &FF, &1F, &E0
	DEFB &06, &CD, &DC, &93, &41, &09, &FE
	DEFB &18, &CE, &D1, &13, &1D, &08, &09, &07, &E5, &12, &66, &27, &17, &D8, &A1, &CC, &2F, &F8, &76, &9A, &2F, &CF, &FF, &8F, &F0
	DEFB &11, &D1, &D1, &DB, &00, &0E, &09, &03, &F8, &81, &F0, &BD, &FE, &DF, &5F, &BF, &1F, &E0
	DEFB &09, &D4, &D6, &5B, &00, &0E, &09, &23, &FF, &E0
	DEFB &19, &DC, &DF, &93, &00, &28, &43, &31, &E0, &33, &10, &2F, &B1, &BA, &3F, &C0, &B6, &C4, &E7, &32, &59, &6D, &BE, &9B, &F1, &FE
	DEFB &15, &DE, &D1, &D3, &00, &28, &2D, &07, &20, &30, &70, &2B, &01, &E4, &F0, &0A, &01, &04, &59, &90, &BF, &F0
	DEFB &17, &8A, &E0, &B2, &80, &0E, &43, &1C, &C2, &FA, &4F, &67, &7B, &FE, &05, &B6, &9D, &CE, &EF, &7F, &CF, &FF, &1F, &E0
	DEFB &10, &8B, &E0, &32, &01, &8F, &A6, &47, &2D, &97, &E1, &6D, &FF, &63, &FE, &3F, &C0
	DEFB &0F, &C3, &EF, &1B, &A0, &0E, &57, &4C, &D8, &A0, &72, &4D, &8F, &FC, &7F, &80
	DEFB &11, &C4, &E8, &1B, &1D, &06, &39, &B5, &F9, &FF, &C1, &26, &D3, &E9, &B4, &9F, &8F, &F0
	DEFB &1E, &D1, &E1, &DB, &00, &0F, &86, &9B, &17, &88, &E2, &A9, &FE, &D2, &03, &85, &E2, &61, &37, &F0, &2D, &BF, &8F, &A5, &D0, &E0, &F2, &4E, &FC, &7F, &80
	DEFB &14, &D4, &E6, &5B, &00, &26, &49, &A3, &15, &9C, &DF, &6D, &4B, &F8, &0A, &CA, &45, &32, &9F, &F1, &FE
	DEFB &08, &00, &F2, &72, &08, &0B, &96, &07, &FF
	DEFB &1E, &10, &F1, &B2, &14, &3C, &3F, &4F, &E2, &D8, &4E, &1F, &9F, &F9, &BB, &DF, &80, &EC, &06, &23, &01, &C7, &E3, &E1, &B7, &1D, &CE, &D7, &FC, &7F, &80
	DEFB &10, &20, &F5, &72, &1C, &7C, &09, &23, &E2, &DB, &BF, &E7, &13, &87, &FF, &1F, &E0
	DEFB &13, &30, &F0, &B2, &FC, &2A, &23, &27, &C2, &D9, &FB, &3F, &7F, &3F, &FB, &FD, &EE, &E7, &E3, &FC
	DEFB &0B, &31, &FA, &32, &C1, &0B, &9D, &D7, &CE, &0B, &FF, &80
	DEFB &13, &32, &FF, &B2, &25, &8C, &2F, &1C, &E2, &DB, &6E, &F7, &2F, &99, &C9, &F0, &F6, &7F, &E3, &FC
	DEFB &18, &33, &FF, &B2, &10, &8C, &2F, &8C, &F9, &FB, &7F, &E0, &5B, &63, &F5, &EE, &F7, &B9, &DC, &AE, &D7, &67, &FE, &3F, &C0
	DEFB &11, &40, &F6, &F2, &04, &5C, &2D, &BC, &FA, &7B, &3B, &75, &3A, &5D, &0E, &FE, &3F, &C0
	DEFB &11, &42, &FF, &B2, &80, &1C, &2F, &1C, &E2, &DB, &1F, &57, &6B, &BD, &CE, &FF, &8F, &F0
	DEFB &10, &43, &FE, &F2, &81, &BD, &98, &07, &17, &89, &F1, &6C, &DF, &2F, &FE, &3F, &C0
	DEFB &06, &44, &FD, &32, &61, &8B, &FE
	DEFB &10, &45, &F9, &32, &E3, &0E, &5B, &10, &9A, &78, &51, &6C, &FC, &62, &7E, &3F, &C0
	DEFB &15, &46, &F1, &B2, &41, &0A, &15, &3C, &A3, &BB, &DF, &DF, &FC, &0B, &6F, &77, &9B, &4F, &DE, &FC, &7F, &80
	DEFB &12, &47, &F8, &32, &12, &0E, &2F, &B5, &F8, &FF, &C0, &B6, &83, &E1, &F3, &FB, &FF, &C7, &F8
	DEFB &14, &50, &F6, &F2, &10, &1C, &2F, &A4, &FA, &7B, &3A, &9F, &F0, &2D, &BC, &EE, &73, &38, &9F, &F1, &FE
	DEFB &12, &57, &F4, &72, &04, &2A, &37, &B2, &F1, &F5, &3F, &E0, &3B, &6B, &E5, &EA, &FF, &C7, &F8
	DEFB &06, &60, &FB, &B2, &24, &2B, &FE
	DEFB &0D, &61, &FB, &B2, &40, &8A, &15, &14, &C2, &31, &4F, &83, &CF, &FF
	DEFB &06, &62, &F4, &B2, &49, &0B, &FE
	DEFB &17, &63, &F1, &F2, &01, &0A, &23, &24, &E2, &F3, &98, &4B, &AA, &F2, &F4, &FF, &E0, &5B, &70, &BC, &BF, &EF, &C7, &F8
	DEFB &13, &67, &F4, &72, &08, &1A, &23, &24, &C4, &3A, &AF, &AF, &93, &AB, &CC, &E5, &76, &FF, &E3, &FC
	DEFB &18, &70, &F9, &B2, &08, &1A, &03, &26, &D9, &4A, &4C, &A5, &38, &56, &BB, &3D, &BF, &02, &D9, &EF, &37, &BB, &FE, &3F, &C0
	DEFB &0B, &72, &F6, &72, &08, &2A, &23, &23, &F8, &A0, &7F, &F0
	DEFB &14, &77, &F4, &B2, &08, &2B, &8A, &0F, &1B, &BA, &70, &EC, &5F, &8B, &A7, &DB, &F5, &FC, &FF, &E3, &FC
	DEFB &0E, &80, &F1, &72, &A0, &5C, &2F, &23, &E2, &DA, &7E, &1F, &FC, &7F, &80
	DEFB &17, &81, &F9, &F2, &A1, &8C, &5B, &18, &E1, &DA, &CF, &66, &D3, &29, &CC, &CA, &6F, &C0, &B6, &67, &BF, &BF, &1F, &E0
	DEFB &08, &82, &FE, &32, &41, &2B, &92, &07, &FF
	DEFB &10, &83, &F9, &B2, &05, &0A, &2D, &0F, &81, &D3, &2F, &81, &87, &C1, &03, &FF, &80
	DEFB &0D, &87, &F0, &F2, &48, &6B, &9D, &EF, &C4, &1E, &62, &01, &3F, &C0
	DEFB &1A, &88, &F1, &32, &E1, &8C, &27, &36, &C1, &50, &4D, &84, &AF, &D3, &83, &E2, &85, &C5, &B5, &1D, &8F, &07, &9F, &3F, &BF, &1F, &E0
	DEFB &06, &89, &FC, &F2, &41, &0B, &FE
	DEFB &19, &8B, &F0, &32, &01, &0A, &15, &01, &F8, &80, &4C, &50, &38, &24, &FF, &80, &68, &FB, &7F, &F0, &1D, &84, &FE, &7F, &C7, &F8
	DEFB &17, &93, &F9, &B2, &40, &1A, &1B, &29, &F8, &18, &7C, &10, &38, &76, &CB, &D5, &DB, &ED, &E6, &EA, &3C, &AF, &F8, &FF
	DEFB &10, &94, &F8, &32, &C3, &0A, &5D, &24, &E0, &31, &BE, &33, &A3, &EE, &7F, &C7, &F8
	DEFB &0B, &95, &F0, &32, &41, &0A, &63, &1C, &C1, &D1, &CF, &FE
	DEFB &0F, &96, &F0, &72, &41, &0A, &19, &3F, &E1, &D8, &BE, &1F, &4B, &FE, &3F, &C0
	DEFB &06, &97, &F6, &B2, &03, &AB, &FE
	DEFB &11, &C3, &FF, &19, &00, &0E, &47, &33, &44, &9B, &11, &B5, &D9, &DD, &CE, &FF, &8F, &F0
	DEFB &1A, &D1, &F9, &D9, &00, &0E, &09, &10, &F9, &94, &7C, &C4, &38, &1E, &DB, &6F, &BF, &02, &DA, &AF, &BF, &C3, &91, &CF, &FF, &8F, &F0
	DEFB &0F, &41, &01, &E1, &40, &05, &AF, &2F, &D7, &8B, &E5, &B7, &F2, &DD, &FF, &E0
	DEFB &12, &42, &01, &21, &41, &65, &AC, &EF, &D6, &6B, &8B, &60, &E0, &50, &2E, &16, &FC, &7F, &80
	DEFB &0B, &44, &02, &61, &01, &25, &B2, &17, &25, &9D, &FF, &F0
	DEFB &08, &34, &04, &A1, &48, &25, &B4, &37, &FF
	DEFB &0D, &14, &09, &61, &19, &05, &B2, &1F, &11, &98, &7C, &E5, &FF, &F8
	DEFB &0B, &13, &01, &A1, &41, &05, &B0, &07, &CB, &03, &FF, &80
	DEFB &25, &9A, &F1, &B2, &00, &2A, &37, &17, &DA, &2E, &4D, &17, &38, &BC, &87, &E5, &75, &F3, &37, &F9, &80, &F1, &5D, &C1, &AF, &FE, &02, &B3, &FB, &F0, &2D, &A0, &EF, &F5, &BA, &FF, &F1, &FE		;; Safari Crown room
	DEFB &12, &8A, &F0, &B2, &FD, &0A, &5D, &24, &E2, &B8, &9F, &F8, &16, &CF, &D7, &FB, &FB, &F1, &FE
	DEFB &19, &00, &B1, &9B, &0C, &07, &A3, &24, &03, &9C, &42, &88, &FA, &D1, &93, &80, &4B, &D9, &26, &23, &F1, &67, &6F, &BF, &C7, &F8							;; Penitentiary Crown room
	DEFB &00

Room_List2:   ;; 71 more rooms
	;;    <length><high_id><low_id in [7:4]; data in [3:0]><data n bytes>
	DEFB &06, &79, &11, &E8, &60, &0F, &FE
	DEFB &0B, &7A, &18, &68, &21, &01, &8A, &0F, &C5, &1F, &FF, &80
	DEFB &0B, &7B, &18, &68, &40, &80, &6F, &0B, &F8, &A0, &7F, &F0
	DEFB &0B, &7C, &1A, &28, &82, &00, &23, &9C, &F1, &FF, &C7, &F8
	DEFB &0B, &7D, &11, &A8, &02, &8E, &09, &1B, &FA, &40, &7F, &F0
	DEFB &15, &77, &29, &28, &FC, &00, &23, &09, &E0, &B9, &FA, &FE, &7F, &FE, &00, &F6, &3D, &3F, &27, &FC, &7F, &80
	DEFB &14, &78, &21, &68, &43, &80, &03, &39, &62, &73, &D5, &85, &57, &05, &DC, &CE, &A7, &73, &D7, &F8, &FF
	DEFB &08, &79, &21, &E8, &19, &01, &9C, &F7, &FF
	DEFB &0F, &7D, &21, &A8, &04, &0D, &AB, &FF, &D5, &FF, &02, &46, &FE, &90, &1F, &FC
	DEFB &0D, &87, &26, &A8, &08, &20, &1F, &9C, &F2, &76, &FC, &7F, &F1, &FE
	DEFB &19, &89, &27, &A8, &04, &20, &69, &2B, &BA, &87, &FD, &42, &39, &16, &CE, &69, &3F, &00, &BA, &3F, &65, &EE, &79, &3F, &1F, &E0
	DEFB &06, &97, &21, &E8, &00, &7F, &FE
	DEFB &19, &99, &27, &A8, &08, &11, &A9, &87, &34, &D5, &E4, &F7, &E0, &17, &57, &CB, &81, &C3, &20, &91, &3A, &A5, &4F, &FE, &3F, &C0
	DEFB &08, &9D, &27, &28, &08, &61, &A9, &3F, &FF
	DEFB &08, &A9, &2E, &68, &48, &61, &9D, &7F, &FF
	DEFB &0D, &AA, &24, &E8, &41, &00, &23, &3D, &E0, &B0, &5F, &A9, &0E, &FF
	DEFB &06, &AB, &2D, &68, &41, &01, &FE
	DEFB &16, &AC, &28, &E8, &82, &0C, &5B, &1F, &E0, &B9, &BE, &C7, &FC, &07, &E3, &F1, &1B, &5D, &BF, &73, &FE, &3F, &C0
	DEFB &06, &AD, &2E, &A8, &E1, &21, &FE
	DEFB &17, &AE, &26, &68, &09, &00, &45, &03, &A0, &72, &BE, &1F, &03, &E0, &B8, &CA, &24, &2F, &17, &CC, &C6, &7F, &C7, &F8
	DEFB &12, &B9, &27, &E8, &08, &20, &37, &73, &E1, &FA, &4C, &E6, &B3, &C9, &DC, &EA, &7F, &C7, &F8
	DEFB &12, &BE, &20, &28, &08, &40, &4B, &20, &E6, &72, &9E, &0B, &AF, &EB, &76, &FE, &3F, &F1, &FE
	DEFB &14, &C9, &23, &28, &10, &4C, &45, &A9, &94, &DA, &75, &3F, &9D, &CF, &FC, &02, &E0, &FF, &9F, &F1, &FE
	DEFB &15, &CB, &24, &68, &B4, &00, &1F, &05, &E6, &75, &BC, &2B, &AC, &F2, &7F, &C0, &2E, &6F, &F7, &FF, &1F, &E0
	DEFB &09, &CD, &23, &E8, &61, &80, &6B, &23, &FF, &E0
	DEFB &09, &CE, &2B, &A8, &41, &20, &67, &23, &FF, &E0
	DEFB &12, &CF, &21, &68, &0B, &00, &17, &9B, &EE, &7F, &C0, &2E, &62, &21, &10, &A8, &7F, &C7, &F8
	DEFB &0E, &D8, &29, &A8, &C0, &00, &03, &1A, &E2, &3A, &0E, &DF, &FC, &7F, &80
	DEFB &06, &D9, &24, &A8, &09, &21, &FE
	DEFB &0B, &DB, &25, &A8, &08, &20, &33, &A4, &ED, &FF, &C7, &F8
	DEFB &08, &DF, &25, &28, &08, &61, &9D, &3F, &FF
	DEFB &11, &E9, &20, &28, &14, &5C, &45, &80, &EC, &7E, &3F, &E0, &17, &77, &C4, &FF, &8F, &F0
	DEFB &0B, &EB, &27, &28, &D8, &20, &0B, &BB, &DD, &FF, &C7, &F8
	DEFB &0B, &EC, &28, &E8, &42, &00, &6D, &B3, &E6, &7F, &C7, &F8
	DEFB &24, &ED, &2E, &A8, &22, &8C, &65, &0B, &E1, &F8, &DB, &B5, &26, &FE, &01, &F6, &BE, &DF, &2F, &57, &BB, &FF, &00, &D9, &9E, &8F, &27, &FE, &02, &71, &BC, &CE, &57, &DB, &FE, &3F, &C0
	DEFB &1E, &EE, &2E, &A8, &A0, &8C, &65, &34, &E1, &FB, &1B, &95, &BA, &ED, &7F, &01, &3B, &1F, &97, &CF, &EB, &F6, &FF, &80, &6D, &77, &9B, &BD, &FF, &1F, &E0
	DEFB &0B, &EF, &20, &68, &03, &21, &A9, &E7, &CB, &0F, &FF, &80
	DEFB &18, &F9, &21, &A8, &40, &21, &82, &17, &0F, &D1, &F7, &3F, &E0, &47, &37, &E4, &FF, &80, &2E, &BD, &5F, &2F, &FF, &1F, &E0
	DEFB &06, &FA, &2D, &E8, &41, &01, &FE
	DEFB &13, &FB, &23, &68, &01, &20, &17, &3E, &E2, &B2, &4E, &0B, &B9, &FC, &EE, &6F, &33, &97, &F8, &FF
	DEFB &1A, &97, &31, &E8, &00, &0E, &0D, &8F, &E3, &FF, &C0, &46, &03, &83, &C2, &E1, &F1, &38, &BC, &6F, &F8, &00, &CF, &F9, &FF, &E3, &FC
	DEFB &09, &97, &41, &E8, &08, &00, &09, &00, &FF, &E0
	DEFB &1C, &A7, &43, &A8, &00, &20, &05, &24, &E6, &72, &3F, &A8, &06, &11, &D0, &F9, &7F, &E0, &0F, &03, &F9, &FF, &80, &5D, &22, &92, &7E, &3F, &C0			;; Book World Crown room
	DEFB &06, &3B, &33, &00, &09, &23, &FE
	DEFB &08, &1B, &3F, &80, &08, &03, &96, &07, &FF
	DEFB &08, &39, &3E, &00, &40, &03, &96, &07, &FF
	DEFB &09, &2B, &37, &40, &08, &22, &55, &24, &FF, &E0
	DEFB &16, &4A, &37, &C0, &14, &23, &86, &FE, &C3, &63, &07, &6B, &2D, &92, &C7, &5B, &FC, &0B, &6A, &FD, &9F, &F1, &FE
	DEFB &15, &4B, &31, &40, &E0, &7D, &8C, &DF, &C6, &7B, &E3, &19, &F1, &A4, &E2, &DA, &78, &1C, &12, &7E, &3F, &C0
	DEFB &17, &4C, &30, &80, &09, &02, &55, &3A, &E6, &F1, &2F, &8E, &07, &0E, &CB, &6C, &B4, &7D, &CE, &BE, &EB, &7E, &3F, &C0
	DEFB &14, &5C, &32, &C0, &10, &33, &8A, &2F, &C5, &0B, &87, &67, &7C, &5F, &F0, &23, &A5, &ED, &7F, &C7, &F8
	DEFB &13, &6C, &3F, &40, &03, &A2, &6D, &24, &E2, &D1, &97, &98, &03, &0B, &C7, &76, &7E, &BF, &F1, &FE
	DEFB &24, &69, &31, &80, &FC, &02, &23, &24, &E2, &D0, &8E, &2B, &08, &C5, &70, &9C, &09, &09, &E2, &D9, &7E, &FD, &EE, &79, &08, &FF, &80, &EC, &0F, &07, &15, &CA, &C8, &F4, &77, &E3, &FC
	DEFB &1B, &8A, &39, &80, &41, &02, &37, &DA, &F2, &FF, &C0, &76, &B7, &39, &F3, &E6, &74, &B4, &7F, &2E, &97, &2B, &9B, &ED, &FA, &FF, &C7, &F8
	DEFB &17, &58, &30, &C0, &83, &0C, &17, &3C, &E2, &F8, &4E, &E7, &73, &7E, &05, &B4, &11, &88, &07, &7F, &CF, &FF, &1F, &E0
	DEFB &19, &57, &31, &00, &40, &72, &6D, &38, &C3, &12, &3A, &17, &A3, &5C, &7F, &C0, &B6, &11, &86, &E3, &71, &C8, &F4, &7F, &F1, &FE
	DEFB &09, &47, &34, &40, &08, &22, &7B, &1B, &FF, &E0
	DEFB &14, &3A, &31, &80, &DB, &82, &03, &00, &58, &82, &31, &6D, &3F, &7F, &BF, &9E, &F3, &D9, &F7, &E3, &FC
	DEFB &1D, &8E, &35, &F9, &00, &86, &76, &8D, &E5, &7A, &5E, &77, &AD, &FE, &FF, &AE, &FC, &1D, &23, &71, &5C, &97, &1D, &CB, &77, &AD, &EF, &3F, &1F, &E0	;; far corner of the victory room (can never go in,
																																									;; but is counted in the 301 anyway since we see it)
	DEFB &19, &5A, &38, &40, &0B, &22, &17, &30, &E2, &32, &2E, &2D, &A0, &8C, &4F, &C0, &76, &CB, &D5, &E3, &ED, &F4, &B9, &5F, &F1, &FE
	DEFB &2B, &8D, &31, &F9, &20, &06, &2B, &10, &E7, &55, &8C, &77, &58, &F9, &8F, &FD, &B0, &FE, &D8, &FC, &5B, &1F, &D7, &EB, &E7, &FF, &FF, &EF, &F8, &3C, &C8, &E4, &72, &39, &1C, &8E, &47, &7E, &09, &32, &19, &1D, &F8, &FF	;; Victory Room!
	DEFB &1B, &59, &3B, &80, &41, &02, &35, &14, &82, &B1, &BF, &80, &44, &C1, &E3, &85, &EA, &FA, &87, &F0, &05, &94, &4E, &25, &1B, &93, &F1, &FE
	DEFB &10, &79, &34, &00, &08, &22, &6F, &64, &F9, &00, &70, &ED, &57, &B7, &FE, &3F, &C0
	DEFB &0D, &69, &21, &80, &00, &0E, &2D, &07, &E2, &F0, &6F, &88, &2F, &FF
	DEFB &12, &6A, &38, &80, &C1, &62, &23, &AF, &F8, &7F, &C0, &B6, &7E, &CF, &6F, &DB, &FF, &C7, &F8
	DEFB &1A, &37, &31, &80, &0C, &02, &23, &1B, &E7, &D1, &EC, &1D, &8F, &E7, &7B, &FD, &DD, &EF, &36, &9F, &2D, &97, &CF, &D7, &F7, &E3, &FC					;; Emperor Crown room
	DEFB &22, &6B, &39, &00, &83, &0D, &98, &8F, &1E, &C8, &54, &74, &9D, &4E, &97, &FC, &07, &6D, &E6, &D7, &5B, &F8, &16, &D8, &F6, &24, &11, &FF, &3F, &CE, &E6, &F3, &DF, &8F, &F0
	DEFB &08, &CC, &2C, &28, &C1, &01, &9C, &17, &FF
	DEFB &19, &89, &31, &C0, &E0, &22, &23, &3E, &C2, &73, &88, &57, &3E, &E2, &D3, &8B, &88, &1F, &14, &C8, &FA, &7D, &9D, &4F, &F8, &FF
	DEFB &25, &8B, &30, &40, &01, &8D, &8D, &CF, &C6, &67, &E1, &89, &C0, &22, &F8, &7B, &01, &C3, &E3, &E1, &F8, &DF, &F0, &2D, &B8, &FC, &6E, &25, &1D, &7F, &F8, &24, &C7, &D5, &AB, &F7, &F1, &FE
	DEFB &08, &8D, &21, &A8, &14, &1D, &88, &07, &FF
	DEFB &00

;; -----------------------------------------------------------------------------------------------------------
;; The data block from 6600 to ADBF after loading is moved to 70D8-B897 (+0AD8) at
;; initialisation (Init_table_and_crtc function.
;; This move frees the gap 6600 to 70D7 for buffers and data tables
;; -----------------------------------------------------------------------------------------------------------

;; -----------------------------------------------------------------------------------------------------------
;; This block is not generated by DEFS, but instead by moving data 6600-AD8F to 70D8-B897 at init
;; hence leaving this memory area available for buffering:
BlitBuff:
	DEFS 	256				;; Table of values used by the blit routines
ViewBuff:
	DEFS 	256				;; buffer
DestBuff:
	DEFS 	256				;; buffer
RevTable:
	DEFS 	256				;; Table of values used by
BackgrdBuff:
	DEFS 	64				;; data???
.SaveRestore_Block4:					;; Save/Restore Block 4 : &3F0 bytes (1008 = 56 x 18, each Object is 18 byte-long)
Objects:
	DEFS 	&3F0			;; Objects buffer
.SaveRestore_Block4_end
TODO_6E30:
	DEFS 	&190 			;; ???
KeyScanningBuffer:
	DEFS 	10				;; Buffer (key scanning)
	DEFS 	&10E

;; -----------------------------------------------------------------------------------------------------------
;; Again, everything below this point has been moved by &0AD8 at init (70D8 was placed at 6600 before Entry).

				org 	&6600		;; but moved at 70D8 at init

.PanelFlips:
	DEFS	8, &00
.SpriteFlips_buffer:														;; flipped sprite
	DEFS 	16, &00

;; -----------------------------------------------------------------------------------------------------------
img_wall_deco:
img_blacktooth_walls:
img_blacktooth_wall_0:
	;; 4 bytes * 56 : interlaced : wall1 + maskwall1 + wall2 + maskwall2 (each are 1byte wide*56)
	DEFB &00, &00, &03, &03, &03, &03, &FF, &FF, &0E, &0E, &00, &00, &39, &38, &55, &00
	DEFB &E2, &E0, &2B, &00, &85, &80, &55, &00, &82, &98, &2B, &00, &01, &3C, &55, &00
	DEFB &00, &24, &00, &00, &49, &09, &15, &15, &9E, &1E, &80, &80, &57, &17, &55, &40
	DEFB &AF, &2F, &4B, &40, &33, &33, &A5, &A0, &AC, &2C, &AB, &A0, &2F, &2F, &45, &40
	DEFB &96, &16, &B3, &B0, &40, &00, &50, &50, &9E, &1E, &E9, &E9, &2F, &2F, &E8, &E8
	DEFB &6F, &6F, &6B, &68, &9F, &1F, &65, &60, &6F, &6F, &6B, &68, &6F, &6F, &65, &60
	DEFB &6F, &6F, &6B, &68, &5F, &5F, &49, &48, &9F, &1F, &48, &48, &4E, &4E, &89, &89
	DEFB &9E, &1E, &40, &40, &41, &41, &C9, &C8, &5F, &5F, &93, &90, &5F, &5F, &59, &58
	DEFB &42, &42, &C3, &C0, &1D, &1D, &C5, &C0, &5D, &5D, &CB, &C0, &2D, &2D, &C0, &C0
	DEFB &6D, &6D, &D5, &D5, &9D, &1D, &80, &80, &3C, &3C, &0B, &00, &39, &39, &95, &80
	DEFB &02, &02, &0B, &00, &1B, &1B, &95, &80, &23, &23, &80, &8A, &3B, &3B, &80, &95
	DEFB &3B, &3B, &80, &8B, &3B, &3B, &80, &95, &3B, &3B, &00, &2B, &38, &38, &C0, &C5
	DEFB &3B, &3B, &F0, &F0, &20, &20, &60, &60, &1C, &1C, &00, &00, &1E, &1E, &00, &00
	DEFB &0C, &0C, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
	;; displaying the images and masks as "wall1+wall2 mask1+mask2"
	;; so it is easier to see, we have the following results:
	;;
	;;	..............@@ ..............@@
	;;	......@@@@@@@@@@ ......@@@@@@@@@@
	;;	....@@@......... ....@@@.........
	;;	..@@@..@.@.@.@.@ ..@@@...........
	;;	@@@...@...@.@.@@ @@@.............
	;;	@....@.@.@.@.@.@ @...............
	;;	@.....@...@.@.@@ @..@@...........
	;;	.......@.@.@.@.@ ..@@@@..........
	;;	................ ..@..@..........
	;;	.@..@..@...@.@.@ ....@..@...@.@.@
	;;	@..@@@@.@....... ...@@@@.@.......
	;;	.@.@.@@@.@.@.@.@ ...@.@@@.@......
	;;	@.@.@@@@.@..@.@@ ..@.@@@@.@......
	;;	..@@..@@@.@..@.@ ..@@..@@@.@.....
	;;	@.@.@@..@.@.@.@@ ..@.@@..@.@.....
	;;	..@.@@@@.@...@.@ ..@.@@@@.@......
	;;	@..@.@@.@.@@..@@ ...@.@@.@.@@....
	;;	.@.......@.@.... .........@.@....
	;;	@..@@@@.@@@.@..@ ...@@@@.@@@.@..@
	;;	..@.@@@@@@@.@... ..@.@@@@@@@.@...
	;;	.@@.@@@@.@@.@.@@ .@@.@@@@.@@.@...
	;;	@..@@@@@.@@..@.@ ...@@@@@.@@.....
	;;	.@@.@@@@.@@.@.@@ .@@.@@@@.@@.@...
	;;	.@@.@@@@.@@..@.@ .@@.@@@@.@@.....
	;;	.@@.@@@@.@@.@.@@ .@@.@@@@.@@.@...
	;;	.@.@@@@@.@..@..@ .@.@@@@@.@..@...
	;;	@..@@@@@.@..@... ...@@@@@.@..@...
	;;	.@..@@@.@...@..@ .@..@@@.@...@..@
	;;	@..@@@@..@...... ...@@@@..@......
	;;	.@.....@@@..@..@ .@.....@@@..@...
	;;	.@.@@@@@@..@..@@ .@.@@@@@@..@....
	;;	.@.@@@@@.@.@@..@ .@.@@@@@.@.@@...
	;;	.@....@.@@....@@ .@....@.@@......
	;;	...@@@.@@@...@.@ ...@@@.@@@......
	;;	.@.@@@.@@@..@.@@ .@.@@@.@@@......
	;;	..@.@@.@@@...... ..@.@@.@@@......
	;;	.@@.@@.@@@.@.@.@ .@@.@@.@@@.@.@.@
	;;	@..@@@.@@....... ...@@@.@@.......
	;;	..@@@@......@.@@ ..@@@@..........
	;;	..@@@..@@..@.@.@ ..@@@..@@.......
	;;	......@.....@.@@ ......@.........
	;;	...@@.@@@..@.@.@ ...@@.@@@.......
	;;	..@...@@@....... ..@...@@@...@.@.
	;;	..@@@.@@@....... ..@@@.@@@..@.@.@
	;;	..@@@.@@@....... ..@@@.@@@...@.@@
	;;	..@@@.@@@....... ..@@@.@@@..@.@.@
	;;	..@@@.@@........ ..@@@.@@..@.@.@@
	;;	..@@@...@@...... ..@@@...@@...@.@
	;;	..@@@.@@@@@@.... ..@@@.@@@@@@....
	;;	..@......@@..... ..@......@@.....
	;;	...@@@.......... ...@@@..........
	;;	...@@@@......... ...@@@@.........
	;;	....@@.......... ....@@..........
	;;	................ ................
	;;	................ ................
	;;	................ ................

img_blacktooth_wall_1:
	DEFB &00, &00, &03, &03, &00, &00, &07, &07, &00, &00, &30, &30, &00, &00, &D7, &D0
	DEFB &03, &03, &D7, &D0, &0F, &0F, &17, &10, &3C, &3C, &D7, &10, &53, &50, &D7, &10
	DEFB &8F, &80, &DB, &18, &1F, &00, &D4, &14, &9F, &00, &33, &33, &9C, &00, &D4, &D0
	DEFB &93, &03, &17, &10, &8C, &0C, &D7, &10, &B3, &30, &D7, &10, &8F, &00, &D7, &10
	DEFB &1F, &00, &D7, &10, &9F, &80, &D3, &10, &1F, &00, &D4, &14, &9F, &00, &33, &33
	DEFB &9C, &00, &D4, &D0, &93, &03, &17, &10, &8C, &0C, &D7, &10, &B3, &30, &D7, &10
	DEFB &8F, &00, &D7, &10, &1F, &00, &D7, &10, &9F, &80, &D3, &10, &1F, &00, &D4, &14
	DEFB &9F, &00, &33, &33, &9C, &00, &D4, &D0, &93, &03, &17, &10, &8C, &0C, &D7, &10
	DEFB &B3, &30, &D7, &10, &8F, &00, &D7, &10, &1F, &00, &D7, &10, &9F, &80, &DB, &18
	DEFB &1F, &00, &D4, &14, &9F, &00, &33, &33, &9C, &00, &D4, &D0, &93, &03, &17, &10
	DEFB &8C, &0C, &D7, &10, &B3, &30, &D7, &10, &8F, &00, &D7, &10, &1F, &00, &C0, &00
	DEFB &9F, &80, &00, &0B, &1C, &00, &00, &2D, &90, &00, &00, &BD, &80, &02, &00, &DD
	DEFB &80, &0B, &00, &DA, &80, &2D, &00, &D8, &00, &3D, &00, &A0, &00, &DD, &00, &80
	DEFB &00, &DA, &00, &00, &00, &D8, &00, &00, &00, &A0, &00, &00, &00, &80, &00, &00
	;; displaying the images and masks as "wall1+wall2 mask1+mask2"
	;; so it is easier to see, we have the following results:
	;;
	;;	..............@@ ..............@@
	;;	.............@@@ .............@@@
	;;	..........@@.... ..........@@....
	;;	........@@.@.@@@ ........@@.@....
	;;	......@@@@.@.@@@ ......@@@@.@....
	;;	....@@@@...@.@@@ ....@@@@...@....
	;;	..@@@@..@@.@.@@@ ..@@@@.....@....
	;;	.@.@..@@@@.@.@@@ .@.@.......@....
	;;	@...@@@@@@.@@.@@ @..........@@...
	;;	...@@@@@@@.@.@.. ...........@.@..
	;;	@..@@@@@..@@..@@ ..........@@..@@
	;;	@..@@@..@@.@.@.. ........@@.@....
	;;	@..@..@@...@.@@@ ......@@...@....
	;;	@...@@..@@.@.@@@ ....@@.....@....
	;;	@.@@..@@@@.@.@@@ ..@@.......@....
	;;	@...@@@@@@.@.@@@ ...........@....
	;;	...@@@@@@@.@.@@@ ...........@....
	;;	@..@@@@@@@.@..@@ @..........@....
	;;	...@@@@@@@.@.@.. ...........@.@..
	;;	@..@@@@@..@@..@@ ..........@@..@@
	;;	@..@@@..@@.@.@.. ........@@.@....
	;;	@..@..@@...@.@@@ ......@@...@....
	;;	@...@@..@@.@.@@@ ....@@.....@....
	;;	@.@@..@@@@.@.@@@ ..@@.......@....
	;;	@...@@@@@@.@.@@@ ...........@....
	;;	...@@@@@@@.@.@@@ ...........@....
	;;	@..@@@@@@@.@..@@ @..........@....
	;;	...@@@@@@@.@.@.. ...........@.@..
	;;	@..@@@@@..@@..@@ ..........@@..@@
	;;	@..@@@..@@.@.@.. ........@@.@....
	;;	@..@..@@...@.@@@ ......@@...@....
	;;	@...@@..@@.@.@@@ ....@@.....@....
	;;	@.@@..@@@@.@.@@@ ..@@.......@....
	;;	@...@@@@@@.@.@@@ ...........@....
	;;	...@@@@@@@.@.@@@ ...........@....
	;;	@..@@@@@@@.@@.@@ @..........@@...
	;;	...@@@@@@@.@.@.. ...........@.@..
	;;	@..@@@@@..@@..@@ ..........@@..@@
	;;	@..@@@..@@.@.@.. ........@@.@....
	;;	@..@..@@...@.@@@ ......@@...@....
	;;	@...@@..@@.@.@@@ ....@@.....@....
	;;	@.@@..@@@@.@.@@@ ..@@.......@....
	;;	@...@@@@@@.@.@@@ ...........@....
	;;	...@@@@@@@...... ................
	;;	@..@@@@@........ @...........@.@@
	;;	...@@@.......... ..........@.@@.@
	;;	@..@............ ........@.@@@@.@
	;;	@............... ......@.@@.@@@.@
	;;	@............... ....@.@@@@.@@.@.
	;;	@............... ..@.@@.@@@.@@...
	;;	................ ..@@@@.@@.@.....
	;;	................ @@.@@@.@@.......
	;;	................ @@.@@.@.........
	;;	................ @@.@@...........
	;;	................ @.@.............
	;;	................ @...............

img_blacktooth_wall_2:
	DEFB &00, &00, &03, &03, &00, &00, &07, &07, &00, &00, &30, &30, &00, &00, &D7, &D0
	DEFB &03, &03, &D7, &D0, &0F, &0F, &17, &10, &3C, &3C, &D7, &10, &53, &50, &D7, &10
	DEFB &8F, &80, &DB, &18, &1F, &00, &D4, &14, &9F, &00, &33, &33, &9C, &00, &C4, &C0
	DEFB &93, &03, &17, &10, &8C, &0C, &C7, &00, &B3, &30, &17, &10, &8C, &00, &67, &60
	DEFB &10, &00, &87, &80, &87, &87, &83, &80, &1F, &1F, &84, &84, &99, &19, &83, &93
	DEFB &93, &13, &84, &B0, &9B, &1B, &07, &70, &9E, &1E, &07, &F0, &9C, &1D, &07, &E0
	DEFB &90, &13, &07, &C0, &00, &0F, &07, &80, &80, &9F, &03, &00, &00, &1E, &84, &84
	DEFB &81, &19, &83, &83, &87, &07, &84, &80, &9D, &1D, &87, &80, &9C, &1C, &87, &80
	DEFB &99, &19, &87, &80, &8D, &0D, &97, &90, &0F, &0F, &97, &90, &83, &83, &5B, &18
	DEFB &18, &00, &D4, &14, &9F, &00, &33, &33, &9C, &00, &D4, &D0, &93, &03, &17, &10
	DEFB &8C, &0C, &D7, &10, &B3, &30, &D7, &10, &8F, &00, &D7, &10, &1F, &00, &C0, &00
	DEFB &9F, &80, &00, &0B, &1C, &00, &00, &2D, &90, &00, &00, &BD, &80, &02, &00, &DD
	DEFB &80, &0B, &00, &DA, &80, &2D, &00, &D8, &00, &3D, &00, &A0, &00, &DD, &00, &80
	DEFB &00, &DA, &00, &00, &00, &D8, &00, &00, &00, &A0, &00, &00, &00, &80, &00, &00
	;; displaying the images and masks as "wall1+wall2 mask1+mask2"
	;; so it is easier to see, we have the following results:
	;;
	;;	..............@@ ..............@@
	;;	.............@@@ .............@@@
	;;	..........@@.... ..........@@....
	;;	........@@.@.@@@ ........@@.@....
	;;	......@@@@.@.@@@ ......@@@@.@....
	;;	....@@@@...@.@@@ ....@@@@...@....
	;;	..@@@@..@@.@.@@@ ..@@@@.....@....
	;;	.@.@..@@@@.@.@@@ .@.@.......@....
	;;	@...@@@@@@.@@.@@ @..........@@...
	;;	...@@@@@@@.@.@.. ...........@.@..
	;;	@..@@@@@..@@..@@ ..........@@..@@
	;;	@..@@@..@@...@.. ........@@......
	;;	@..@..@@...@.@@@ ......@@...@....
	;;	@...@@..@@...@@@ ....@@..........
	;;	@.@@..@@...@.@@@ ..@@.......@....
	;;	@...@@...@@..@@@ .........@@.....
	;;	...@....@....@@@ ........@.......
	;;	@....@@@@.....@@ @....@@@@.......
	;;	...@@@@@@....@.. ...@@@@@@....@..
	;;	@..@@..@@.....@@ ...@@..@@..@..@@
	;;	@..@..@@@....@.. ...@..@@@.@@....
	;;	@..@@.@@.....@@@ ...@@.@@.@@@....
	;;	@..@@@@......@@@ ...@@@@.@@@@....
	;;	@..@@@.......@@@ ...@@@.@@@@.....
	;;	@..@.........@@@ ...@..@@@@......
	;;	.............@@@ ....@@@@@.......
	;;	@.............@@ @..@@@@@........
	;;	........@....@.. ...@@@@.@....@..
	;;	@......@@.....@@ ...@@..@@.....@@
	;;	@....@@@@....@.. .....@@@@.......
	;;	@..@@@.@@....@@@ ...@@@.@@.......
	;;	@..@@@..@....@@@ ...@@@..@.......
	;;	@..@@..@@....@@@ ...@@..@@.......
	;;	@...@@.@@..@.@@@ ....@@.@@..@....
	;;	....@@@@@..@.@@@ ....@@@@@..@....
	;;	@.....@@.@.@@.@@ @.....@@...@@...
	;;	...@@...@@.@.@.. ...........@.@..
	;;	@..@@@@@..@@..@@ ..........@@..@@
	;;	@..@@@..@@.@.@.. ........@@.@....
	;;	@..@..@@...@.@@@ ......@@...@....
	;;	@...@@..@@.@.@@@ ....@@.....@....
	;;	@.@@..@@@@.@.@@@ ..@@.......@....
	;;	@...@@@@@@.@.@@@ ...........@....
	;;	...@@@@@@@...... ................
	;;	@..@@@@@........ @...........@.@@
	;;	...@@@.......... ..........@.@@.@
	;;	@..@............ ........@.@@@@.@
	;;	@............... ......@.@@.@@@.@
	;;	@............... ....@.@@@@.@@.@.
	;;	@............... ..@.@@.@@@.@@...
	;;	................ ..@@@@.@@.@.....
	;;	................ @@.@@@.@@.......
	;;	................ @@.@@.@.........
	;;	................ @@.@@...........
	;;	................ @.@.............
	;;	................ @...............

img_market_walls:
img_market_wall_0:
	;; 4 bytes * 56 : interlaced : wall1 + maskwall1 + wall2 + maskwall2 (each are 1byte wide*56)
	DEFB &00, &00, &03, &00, &00, &00, &0F, &00, &00, &00, &3E, &00, &00, &00, &D9, &00
	DEFB &03, &00, &67, &00, &0D, &00, &95, &00, &36, &00, &76, &00, &D9, &00, &F0, &01
	DEFB &E7, &00, &E0, &07, &97, &00, &80, &1F, &76, &00, &60, &6F, &D1, &01, &F0, &F7
	DEFB &67, &07, &F8, &FB, &9F, &1F, &FC, &FD, &0F, &6F, &FC, &FC, &07, &F7, &F2, &F2
	DEFB &03, &FB, &CE, &CE, &01, &FD, &3E, &3E, &00, &FC, &FE, &FE, &00, &F2, &FC, &FC
	DEFB &00, &CE, &79, &79, &00, &3E, &05, &05, &00, &FE, &1A, &1A, &00, &FC, &DD, &DD
	DEFB &00, &7A, &A3, &A3, &00, &01, &5D, &5D, &00, &00, &3A, &BA, &C0, &00, &1D, &5D
	DEFB &C0, &00, &0B, &2B, &DC, &1C, &03, &13, &DA, &1A, &01, &09, &DD, &1D, &C0, &C4
	DEFB &C3, &03, &A0, &A3, &DD, &1D, &C0, &CC, &DA, &1A, &02, &30, &DC, &1C, &0E, &C0
	DEFB &C0, &03, &2E, &00, &C0, &0C, &EE, &00, &C2, &10, &ED, &00, &CE, &00, &E1, &00
	DEFB &DE, &00, &C5, &00, &DE, &00, &05, &10, &DC, &00, &65, &00, &C1, &00, &F5, &00
	DEFB &C3, &00, &F5, &00, &C0, &00, &F1, &00, &C0, &00, &0D, &0C, &C0, &00, &39, &38
	DEFB &C0, &00, &E5, &E0, &C3, &03, &80, &80, &CE, &0E, &00, &00, &D8, &18, &00, &00
	DEFB &C0, &00, &00, &00, &C0, &00, &00, &00, &C0, &00, &00, &00, &80, &00, &00, &00
	;; displaying the images and masks as "wall1+wall2 mask1+mask2"
	;; so it is easier to see, we have the following results:
	;;
	;;	..............@@ ................
	;;	............@@@@ ................
	;;	..........@@@@@. ................
	;;	........@@.@@..@ ................
	;;	......@@.@@..@@@ ................
	;;	....@@.@@..@.@.@ ................
	;;	..@@.@@..@@@.@@. ................
	;;	@@.@@..@@@@@.... ...............@
	;;	@@@..@@@@@@..... .............@@@
	;;	@..@.@@@@....... ...........@@@@@
	;;	.@@@.@@..@@..... .........@@.@@@@
	;;	@@.@...@@@@@.... .......@@@@@.@@@
	;;	.@@..@@@@@@@@... .....@@@@@@@@.@@
	;;	@..@@@@@@@@@@@.. ...@@@@@@@@@@@.@
	;;	....@@@@@@@@@@.. .@@.@@@@@@@@@@..
	;;	.....@@@@@@@..@. @@@@.@@@@@@@..@.
	;;	......@@@@..@@@. @@@@@.@@@@..@@@.
	;;	.......@..@@@@@. @@@@@@.@..@@@@@.
	;;	........@@@@@@@. @@@@@@..@@@@@@@.
	;;	........@@@@@@.. @@@@..@.@@@@@@..
	;;	.........@@@@..@ @@..@@@..@@@@..@
	;;	.............@.@ ..@@@@@......@.@
	;;	...........@@.@. @@@@@@@....@@.@.
	;;	........@@.@@@.@ @@@@@@..@@.@@@.@
	;;	........@.@...@@ .@@@@.@.@.@...@@
	;;	.........@.@@@.@ .......@.@.@@@.@
	;;	..........@@@.@. ........@.@@@.@.
	;;	@@.........@@@.@ .........@.@@@.@
	;;	@@..........@.@@ ..........@.@.@@
	;;	@@.@@@........@@ ...@@@.....@..@@
	;;	@@.@@.@........@ ...@@.@.....@..@
	;;	@@.@@@.@@@...... ...@@@.@@@...@..
	;;	@@....@@@.@..... ......@@@.@...@@
	;;	@@.@@@.@@@...... ...@@@.@@@..@@..
	;;	@@.@@.@.......@. ...@@.@...@@....
	;;	@@.@@@......@@@. ...@@@..@@......
	;;	@@........@.@@@. ......@@........
	;;	@@......@@@.@@@. ....@@..........
	;;	@@....@.@@@.@@.@ ...@............
	;;	@@..@@@.@@@....@ ................
	;;	@@.@@@@.@@...@.@ ................
	;;	@@.@@@@......@.@ ...........@....
	;;	@@.@@@...@@..@.@ ................
	;;	@@.....@@@@@.@.@ ................
	;;	@@....@@@@@@.@.@ ................
	;;	@@......@@@@...@ ................
	;;	@@..........@@.@ ............@@..
	;;	@@........@@@..@ ..........@@@...
	;;	@@......@@@..@.@ ........@@@.....
	;;	@@....@@@....... ......@@@.......
	;;	@@..@@@......... ....@@@.........
	;;	@@.@@........... ...@@...........
	;;	@@.............. ................
	;;	@@.............. ................
	;;	@@.............. ................
	;;	@............... ................

img_market_wall_1:
	DEFB &00, &00, &03, &00, &00, &00, &0F, &00, &00, &00, &3E, &00, &00, &00, &D9, &00
	DEFB &03, &00, &67, &00, &0D, &00, &95, &00, &36, &00, &76, &00, &D9, &00, &F0, &01
	DEFB &E7, &00, &E0, &07, &97, &00, &80, &1F, &76, &00, &60, &6F, &D1, &01, &F0, &F7
	DEFB &67, &07, &F8, &FB, &9F, &1F, &FC, &FD, &0F, &6F, &FC, &FC, &07, &F7, &F2, &F2
	DEFB &03, &FB, &CE, &CE, &01, &FD, &3E, &3E, &00, &FC, &FE, &FE, &00, &F2, &FC, &FC
	DEFB &00, &CE, &79, &78, &00, &3E, &05, &00, &00, &FE, &05, &00, &00, &FC, &05, &00
	DEFB &00, &7A, &05, &00, &00, &01, &05, &00, &00, &00, &05, &80, &C0, &C0, &05, &40
	DEFB &A0, &A0, &05, &20, &DC, &DC, &05, &10, &3A, &3A, &01, &08, &DD, &DD, &C1, &C4
	DEFB &A3, &A3, &A0, &A2, &DD, &DD, &C0, &CC, &3A, &3A, &02, &30, &DC, &DC, &0E, &C0
	DEFB &A0, &A3, &2E, &00, &C0, &CC, &EE, &00, &02, &30, &ED, &00, &0E, &C0, &E1, &00
	DEFB &2E, &00, &C5, &00, &EE, &00, &05, &10, &EC, &00, &65, &00, &E1, &00, &F5, &00
	DEFB &C3, &00, &F5, &00, &00, &00, &F1, &00, &80, &00, &0D, &0C, &80, &00, &39, &38
	DEFB &80, &00, &E5, &E0, &83, &03, &80, &80, &8E, &0E, &00, &00, &B8, &38, &00, &00
	DEFB &A0, &20, &00, &00, &80, &00, &00, &00, &80, &00, &00, &00, &80, &00, &00, &00
	;; displaying the images and masks as "wall1+wall2 mask1+mask2"
	;; so it is easier to see, we have the following results:
	;;
	;;	..............@@ ................
	;;	............@@@@ ................
	;;	..........@@@@@. ................
	;;	........@@.@@..@ ................
	;;	......@@.@@..@@@ ................
	;;	....@@.@@..@.@.@ ................
	;;	..@@.@@..@@@.@@. ................
	;;	@@.@@..@@@@@.... ...............@
	;;	@@@..@@@@@@..... .............@@@
	;;	@..@.@@@@....... ...........@@@@@
	;;	.@@@.@@..@@..... .........@@.@@@@
	;;	@@.@...@@@@@.... .......@@@@@.@@@
	;;	.@@..@@@@@@@@... .....@@@@@@@@.@@
	;;	@..@@@@@@@@@@@.. ...@@@@@@@@@@@.@
	;;	....@@@@@@@@@@.. .@@.@@@@@@@@@@..
	;;	.....@@@@@@@..@. @@@@.@@@@@@@..@.
	;;	......@@@@..@@@. @@@@@.@@@@..@@@.
	;;	.......@..@@@@@. @@@@@@.@..@@@@@.
	;;	........@@@@@@@. @@@@@@..@@@@@@@.
	;;	........@@@@@@.. @@@@..@.@@@@@@..
	;;	.........@@@@..@ @@..@@@..@@@@...
	;;	.............@.@ ..@@@@@.........
	;;	.............@.@ @@@@@@@.........
	;;	.............@.@ @@@@@@..........
	;;	.............@.@ .@@@@.@.........
	;;	.............@.@ .......@........
	;;	.............@.@ ........@.......
	;;	@@...........@.@ @@.......@......
	;;	@.@..........@.@ @.@.......@.....
	;;	@@.@@@.......@.@ @@.@@@.....@....
	;;	..@@@.@........@ ..@@@.@.....@...
	;;	@@.@@@.@@@.....@ @@.@@@.@@@...@..
	;;	@.@...@@@.@..... @.@...@@@.@...@.
	;;	@@.@@@.@@@...... @@.@@@.@@@..@@..
	;;	..@@@.@.......@. ..@@@.@...@@....
	;;	@@.@@@......@@@. @@.@@@..@@......
	;;	@.@.......@.@@@. @.@...@@........
	;;	@@......@@@.@@@. @@..@@..........
	;;	......@.@@@.@@.@ ..@@............
	;;	....@@@.@@@....@ @@..............
	;;	..@.@@@.@@...@.@ ................
	;;	@@@.@@@......@.@ ...........@....
	;;	@@@.@@...@@..@.@ ................
	;;	@@@....@@@@@.@.@ ................
	;;	@@....@@@@@@.@.@ ................
	;;	........@@@@...@ ................
	;;	@...........@@.@ ............@@..
	;;	@.........@@@..@ ..........@@@...
	;;	@.......@@@..@.@ ........@@@.....
	;;	@.....@@@....... ......@@@.......
	;;	@...@@@......... ....@@@.........
	;;	@.@@@........... ..@@@...........
	;;	@.@............. ..@.............
	;;	@............... ................
	;;	@............... ................
	;;	@............... ................

img_market_wall_2:
	DEFB &00, &00, &03, &00, &00, &00, &0F, &00, &00, &00, &3E, &00, &00, &00, &D9, &00
	DEFB &03, &00, &67, &00, &0D, &00, &95, &00, &36, &00, &76, &00, &D9, &00, &F0, &01
	DEFB &E7, &00, &E0, &07, &8F, &00, &80, &1F, &6E, &00, &60, &6F, &C9, &01, &F0, &F7
	DEFB &67, &07, &F8, &FB, &9F, &1F, &FC, &FD, &0F, &6F, &FC, &FC, &07, &F7, &F2, &F2
	DEFB &03, &FB, &CE, &CE, &01, &FD, &3E, &3E, &00, &FC, &FE, &FE, &00, &F2, &FC, &FC
	DEFB &00, &CE, &78, &78, &00, &3E, &06, &00, &00, &FE, &06, &00, &00, &FC, &06, &00
	DEFB &00, &78, &36, &00, &00, &00, &76, &00, &01, &00, &36, &00, &85, &00, &C6, &00
	DEFB &85, &00, &E6, &00, &89, &00, &E6, &00, &AE, &00, &62, &00, &AF, &00, &04, &04
	DEFB &8F, &00, &4A, &0A, &B3, &00, &1C, &1C, &BC, &00, &6A, &68, &80, &00, &B6, &B0
	DEFB &DB, &1B, &66, &60, &AD, &2D, &96, &80, &DB, &1B, &36, &00, &80, &00, &16, &80
	DEFB &BE, &00, &06, &60, &BF, &00, &86, &10, &BF, &00, &E6, &00, &8F, &00, &F6, &00
	DEFB &83, &00, &F6, &00, &80, &00, &F6, &00, &80, &00, &36, &00, &80, &00, &08, &00
	DEFB &80, &00, &06, &00, &80, &00, &00, &00, &80, &00, &00, &00, &80, &00, &00, &00
	DEFB &80, &00, &00, &00, &80, &00, &00, &00, &80, &00, &00, &00, &80, &00, &00, &00
	;; displaying the images and masks as "wall1+wall2 mask1+mask2"
	;; so it is easier to see, we have the following results:
	;;
	;;	..............@@ ................
	;;	............@@@@ ................
	;;	..........@@@@@. ................
	;;	........@@.@@..@ ................
	;;	......@@.@@..@@@ ................
	;;	....@@.@@..@.@.@ ................
	;;	..@@.@@..@@@.@@. ................
	;;	@@.@@..@@@@@.... ...............@
	;;	@@@..@@@@@@..... .............@@@
	;;	@...@@@@@....... ...........@@@@@
	;;	.@@.@@@..@@..... .........@@.@@@@
	;;	@@..@..@@@@@.... .......@@@@@.@@@
	;;	.@@..@@@@@@@@... .....@@@@@@@@.@@
	;;	@..@@@@@@@@@@@.. ...@@@@@@@@@@@.@
	;;	....@@@@@@@@@@.. .@@.@@@@@@@@@@..
	;;	.....@@@@@@@..@. @@@@.@@@@@@@..@.
	;;	......@@@@..@@@. @@@@@.@@@@..@@@.
	;;	.......@..@@@@@. @@@@@@.@..@@@@@.
	;;	........@@@@@@@. @@@@@@..@@@@@@@.
	;;	........@@@@@@.. @@@@..@.@@@@@@..
	;;	.........@@@@... @@..@@@..@@@@...
	;;	.............@@. ..@@@@@.........
	;;	.............@@. @@@@@@@.........
	;;	.............@@. @@@@@@..........
	;;	..........@@.@@. .@@@@...........
	;;	.........@@@.@@. ................
	;;	.......@..@@.@@. ................
	;;	@....@.@@@...@@. ................
	;;	@....@.@@@@..@@. ................
	;;	@...@..@@@@..@@. ................
	;;	@.@.@@@..@@...@. ................
	;;	@.@.@@@@.....@.. .............@..
	;;	@...@@@@.@..@.@. ............@.@.
	;;	@.@@..@@...@@@.. ...........@@@..
	;;	@.@@@@...@@.@.@. .........@@.@...
	;;	@.......@.@@.@@. ........@.@@....
	;;	@@.@@.@@.@@..@@. ...@@.@@.@@.....
	;;	@.@.@@.@@..@.@@. ..@.@@.@@.......
	;;	@@.@@.@@..@@.@@. ...@@.@@........
	;;	@..........@.@@. ........@.......
	;;	@.@@@@@......@@. .........@@.....
	;;	@.@@@@@@@....@@. ...........@....
	;;	@.@@@@@@@@@..@@. ................
	;;	@...@@@@@@@@.@@. ................
	;;	@.....@@@@@@.@@. ................
	;;	@.......@@@@.@@. ................
	;;	@.........@@.@@. ................
	;;	@...........@... ................
	;;	@............@@. ................
	;;	@............... ................
	;;	@............... ................
	;;	@............... ................
	;;	@............... ................
	;;	@............... ................
	;;	@............... ................
	;;	@............... ................

img_egyptus_walls:
img_egyptus_wall_0:
	;; 4 bytes * 56 : interlaced : wall1 + maskwall1 + wall2 + maskwall2 (each are 1byte wide*56)
	DEFB &00, &00, &03, &03, &00, &00, &0E, &0E, &00, &00, &38, &38, &00, &00, &E0, &E6
	DEFB &03, &03, &80, &9E, &0E, &0E, &00, &7C, &38, &39, &02, &E0, &E0, &E7, &1E, &C0
	DEFB &80, &9E, &3C, &00, &01, &7C, &F2, &02, &03, &E0, &CC, &0C, &1F, &C0, &32, &30
	DEFB &3C, &00, &CE, &C0, &F3, &03, &3E, &00, &CC, &0C, &F2, &00, &33, &30, &F6, &00
	DEFB &CF, &C0, &3A, &00, &3E, &00, &16, &40, &FE, &00, &3A, &00, &EB, &00, &D6, &00
	DEFB &A7, &00, &3E, &00, &CF, &00, &DE, &00, &EF, &00, &3A, &00, &D7, &00, &FE, &00
	DEFB &DF, &00, &FC, &00, &F7, &00, &F2, &02, &CF, &00, &CC, &0C, &FF, &00, &32, &30
	DEFB &FC, &00, &CE, &C0, &F3, &03, &3E, &00, &CC, &0C, &FE, &00, &33, &30, &FE, &00
	DEFB &CF, &C0, &FE, &00, &3E, &00, &7E, &00, &FC, &00, &3E, &80, &F8, &00, &1E, &C0
	DEFB &F0, &01, &0E, &E0, &E0, &01, &06, &F0, &C0, &01, &06, &E0, &C0, &03, &1E, &80
	DEFB &E0, &02, &7C, &00, &F9, &00, &F2, &02, &FF, &00, &CC, &0C, &FF, &00, &32, &30
	DEFB &FC, &00, &CE, &C0, &F3, &03, &3E, &00, &CC, &0C, &FC, &00, &33, &30, &E0, &02
	DEFB &CF, &C0, &C0, &1E, &3E, &00, &00, &3C, &FC, &01, &00, &F0, &E0, &03, &00, &C0
	DEFB &C0, &1F, &00, &00, &00, &3C, &00, &00, &00, &F0, &00, &00, &00, &C0, &00, &00
	;; displaying the images and masks as "wall1+wall2 mask1+mask2"
	;; so it is easier to see, we have the following results:
	;;
	;;	..............@@ ..............@@
	;;	............@@@. ............@@@.
	;;	..........@@@... ..........@@@...
	;;	........@@@..... ........@@@..@@.
	;;	......@@@....... ......@@@..@@@@.
	;;	....@@@......... ....@@@..@@@@@..
	;;	..@@@.........@. ..@@@..@@@@.....
	;;	@@@........@@@@. @@@..@@@@@......
	;;	@.........@@@@.. @..@@@@.........
	;;	.......@@@@@..@. .@@@@@........@.
	;;	......@@@@..@@.. @@@.........@@..
	;;	...@@@@@..@@..@. @@........@@....
	;;	..@@@@..@@..@@@. ........@@......
	;;	@@@@..@@..@@@@@. ......@@........
	;;	@@..@@..@@@@..@. ....@@..........
	;;	..@@..@@@@@@.@@. ..@@............
	;;	@@..@@@@..@@@.@. @@..............
	;;	..@@@@@....@.@@. .........@......
	;;	@@@@@@@...@@@.@. ................
	;;	@@@.@.@@@@.@.@@. ................
	;;	@.@..@@@..@@@@@. ................
	;;	@@..@@@@@@.@@@@. ................
	;;	@@@.@@@@..@@@.@. ................
	;;	@@.@.@@@@@@@@@@. ................
	;;	@@.@@@@@@@@@@@.. ................
	;;	@@@@.@@@@@@@..@. ..............@.
	;;	@@..@@@@@@..@@.. ............@@..
	;;	@@@@@@@@..@@..@. ..........@@....
	;;	@@@@@@..@@..@@@. ........@@......
	;;	@@@@..@@..@@@@@. ......@@........
	;;	@@..@@..@@@@@@@. ....@@..........
	;;	..@@..@@@@@@@@@. ..@@............
	;;	@@..@@@@@@@@@@@. @@..............
	;;	..@@@@@..@@@@@@. ................
	;;	@@@@@@....@@@@@. ........@.......
	;;	@@@@@......@@@@. ........@@......
	;;	@@@@........@@@. .......@@@@.....
	;;	@@@..........@@. .......@@@@@....
	;;	@@...........@@. .......@@@@.....
	;;	@@.........@@@@. ......@@@.......
	;;	@@@......@@@@@.. ......@.........
	;;	@@@@@..@@@@@..@. ..............@.
	;;	@@@@@@@@@@..@@.. ............@@..
	;;	@@@@@@@@..@@..@. ..........@@....
	;;	@@@@@@..@@..@@@. ........@@......
	;;	@@@@..@@..@@@@@. ......@@........
	;;	@@..@@..@@@@@@.. ....@@..........
	;;	..@@..@@@@@..... ..@@..........@.
	;;	@@..@@@@@@...... @@.........@@@@.
	;;	..@@@@@......... ..........@@@@..
	;;	@@@@@@.......... .......@@@@@....
	;;	@@@............. ......@@@@......
	;;	@@.............. ...@@@@@........
	;;	................ ..@@@@..........
	;;	................ @@@@............
	;;	................ @@..............

img_egyptus_wall_1:
	DEFB &00, &00, &FF, &FF, &03, &03, &80, &80, &0E, &0E, &00, &2A, &38, &39, &00, &54
	DEFB &E0, &E2, &2A, &00, &81, &94, &54, &00, &8A, &A0, &2A, &00, &15, &40, &54, &00
	DEFB &20, &00, &2A, &2A, &1F, &1F, &94, &80, &7F, &7F, &CA, &C0, &7E, &7E, &54, &40
	DEFB &F9, &F8, &AA, &20, &F7, &F0, &24, &20, &F1, &F0, &AA, &20, &F7, &F0, &B0, &30
	DEFB &F7, &F0, &A2, &20, &F3, &F0, &00, &18, &30, &34, &02, &B8, &00, &C7, &00, &F8
	DEFB &00, &7F, &02, &F8, &00, &FF, &00, &F8, &00, &FF, &02, &78, &00, &FB, &00, &B8
	DEFB &00, &EF, &02, &BA, &00, &F7, &00, &78, &00, &EF, &02, &50, &00, &FF, &00, &E0
	DEFB &00, &FD, &02, &F0, &00, &FB, &04, &F0, &00, &FF, &0A, &E0, &00, &EF, &04, &E0
	DEFB &00, &7F, &0A, &E0, &00, &FF, &04, &E0, &00, &7F, &0A, &E0, &00, &BF, &14, &C0
	DEFB &00, &7F, &0A, &C0, &00, &BF, &14, &C0, &00, &7D, &0A, &C0, &00, &BF, &14, &C0
	DEFB &00, &7D, &0A, &CA, &00, &BF, &14, &C0, &00, &7D, &0A, &C0, &00, &BF, &14, &C0
	DEFB &00, &7D, &0A, &C0, &00, &BF, &04, &E0, &00, &7E, &00, &F2, &00, &BF, &00, &F4
	DEFB &00, &5F, &00, &F0, &00, &AF, &00, &F0, &00, &5F, &00, &E0, &00, &AF, &00, &80
	DEFB &00, &5E, &00, &00, &00, &18, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
	;; displaying the images and masks as "wall1+wall2 mask1+mask2"
	;; so it is easier to see, we have the following results:
	;;
	;;	........@@@@@@@@ ........@@@@@@@@
	;;	......@@@....... ......@@@.......
	;;	....@@@......... ....@@@...@.@.@.
	;;	..@@@........... ..@@@..@.@.@.@..
	;;	@@@.......@.@.@. @@@...@.........
	;;	@......@.@.@.@.. @..@.@..........
	;;	@...@.@...@.@.@. @.@.............
	;;	...@.@.@.@.@.@.. .@..............
	;;	..@.......@.@.@. ..........@.@.@.
	;;	...@@@@@@..@.@.. ...@@@@@@.......
	;;	.@@@@@@@@@..@.@. .@@@@@@@@@......
	;;	.@@@@@@..@.@.@.. .@@@@@@..@......
	;;	@@@@@..@@.@.@.@. @@@@@.....@.....
	;;	@@@@.@@@..@..@.. @@@@......@.....
	;;	@@@@...@@.@.@.@. @@@@......@.....
	;;	@@@@.@@@@.@@.... @@@@......@@....
	;;	@@@@.@@@@.@...@. @@@@......@.....
	;;	@@@@..@@........ @@@@.......@@...
	;;	..@@..........@. ..@@.@..@.@@@...
	;;	................ @@...@@@@@@@@...
	;;	..............@. .@@@@@@@@@@@@...
	;;	................ @@@@@@@@@@@@@...
	;;	..............@. @@@@@@@@.@@@@...
	;;	................ @@@@@.@@@.@@@...
	;;	..............@. @@@.@@@@@.@@@.@.
	;;	................ @@@@.@@@.@@@@...
	;;	..............@. @@@.@@@@.@.@....
	;;	................ @@@@@@@@@@@.....
	;;	..............@. @@@@@@.@@@@@....
	;;	.............@.. @@@@@.@@@@@@....
	;;	............@.@. @@@@@@@@@@@.....
	;;	.............@.. @@@.@@@@@@@.....
	;;	............@.@. .@@@@@@@@@@.....
	;;	.............@.. @@@@@@@@@@@.....
	;;	............@.@. .@@@@@@@@@@.....
	;;	...........@.@.. @.@@@@@@@@......
	;;	............@.@. .@@@@@@@@@......
	;;	...........@.@.. @.@@@@@@@@......
	;;	............@.@. .@@@@@.@@@......
	;;	...........@.@.. @.@@@@@@@@......
	;;	............@.@. .@@@@@.@@@..@.@.
	;;	...........@.@.. @.@@@@@@@@......
	;;	............@.@. .@@@@@.@@@......
	;;	...........@.@.. @.@@@@@@@@......
	;;	............@.@. .@@@@@.@@@......
	;;	.............@.. @.@@@@@@@@@.....
	;;	................ .@@@@@@.@@@@..@.
	;;	................ @.@@@@@@@@@@.@..
	;;	................ .@.@@@@@@@@@....
	;;	................ @.@.@@@@@@@@....
	;;	................ .@.@@@@@@@@.....
	;;	................ @.@.@@@@@.......
	;;	................ .@.@@@@.........
	;;	................ ...@@...........
	;;	................ ................
	;;	................ ................

img_penitentiary_walls:
img_penitentiary_wall_0:
	;; 4 bytes * 56 : interlaced : wall1 + maskwall1 + wall2 + maskwall2 (each are 1byte wide*56)
	DEFB &00, &00, &02, &02, &00, &00, &06, &06, &00, &00, &28, &28, &00, &00, &66, &60
	DEFB &02, &02, &9C, &80, &06, &06, &72, &00, &29, &28, &D4, &00, &67, &60, &AA, &00
	DEFB &9D, &80, &54, &00, &7A, &00, &A8, &00, &D5, &00, &50, &00, &AA, &00, &A6, &00
	DEFB &D5, &00, &1C, &00, &AA, &00, &7A, &00, &D0, &00, &C4, &00, &A6, &00, &92, &10
	DEFB &1C, &00, &64, &60, &71, &01, &80, &90, &C6, &06, &00, &70, &98, &19, &06, &F0
	DEFB &D0, &17, &04, &00, &90, &14, &02, &D0, &D1, &15, &00, &68, &90, &12, &80, &A8
	DEFB &10, &16, &80, &AC, &61, &0D, &00, &4C, &C0, &0C, &00, &0C, &80, &18, &A0, &0C
	DEFB &C1, &18, &00, &18, &80, &18, &42, &18, &C0, &18, &80, &30, &80, &0C, &02, &70
	DEFB &00, &0F, &04, &E0, &60, &07, &0A, &80, &D0, &00, &10, &00, &AA, &00, &A6, &00
	DEFB &D4, &00, &1C, &00, &AA, &00, &7A, &00, &D1, &00, &D4, &00, &A7, &00, &AA, &00
	DEFB &1D, &00, &04, &00, &78, &00, &00, &F0, &D0, &03, &00, &0C, &A0, &0C, &20, &24
	DEFB &C1, &19, &20, &2A, &81, &31, &20, &2A, &81, &21, &20, &2A, &09, &69, &20, &2A
	DEFB &09, &49, &20, &22, &09, &C9, &00, &4C, &08, &4A, &00, &30, &08, &C8, &00, &C0
	DEFB &00, &B3, &00, &00, &00, &8C, &00, &00, &00, &B0, &00, &00, &00, &C0, &00, &00
	;; displaying the images and masks as "wall1+wall2 mask1+mask2"
	;; so it is easier to see, we have the following results:
	;;
	;;	..............@. ..............@.
	;;	.............@@. .............@@.
	;;	..........@.@... ..........@.@...
	;;	.........@@..@@. .........@@.....
	;;	......@.@..@@@.. ......@.@.......
	;;	.....@@..@@@..@. .....@@.........
	;;	..@.@..@@@.@.@.. ..@.@...........
	;;	.@@..@@@@.@.@.@. .@@.............
	;;	@..@@@.@.@.@.@.. @...............
	;;	.@@@@.@.@.@.@... ................
	;;	@@.@.@.@.@.@.... ................
	;;	@.@.@.@.@.@..@@. ................
	;;	@@.@.@.@...@@@.. ................
	;;	@.@.@.@..@@@@.@. ................
	;;	@@.@....@@...@.. ................
	;;	@.@..@@.@..@..@. ...........@....
	;;	...@@@...@@..@.. .........@@.....
	;;	.@@@...@@....... .......@@..@....
	;;	@@...@@......... .....@@..@@@....
	;;	@..@@........@@. ...@@..@@@@@....
	;;	@@.@.........@.. ...@.@@@........
	;;	@..@..........@. ...@.@..@@.@....
	;;	@@.@...@........ ...@.@.@.@@.@...
	;;	@..@....@....... ...@..@.@.@.@...
	;;	...@....@....... ...@.@@.@.@.@@..
	;;	.@@....@........ ....@@.@.@..@@..
	;;	@@.............. ....@@......@@..
	;;	@.......@.@..... ...@@.......@@..
	;;	@@.....@........ ...@@......@@...
	;;	@........@....@. ...@@......@@...
	;;	@@......@....... ...@@.....@@....
	;;	@.............@. ....@@...@@@....
	;;	.............@.. ....@@@@@@@.....
	;;	.@@.........@.@. .....@@@@.......
	;;	@@.@.......@.... ................
	;;	@.@.@.@.@.@..@@. ................
	;;	@@.@.@.....@@@.. ................
	;;	@.@.@.@..@@@@.@. ................
	;;	@@.@...@@@.@.@.. ................
	;;	@.@..@@@@.@.@.@. ................
	;;	...@@@.@.....@.. ................
	;;	.@@@@........... ........@@@@....
	;;	@@.@............ ......@@....@@..
	;;	@.@.......@..... ....@@....@..@..
	;;	@@.....@..@..... ...@@..@..@.@.@.
	;;	@......@..@..... ..@@...@..@.@.@.
	;;	@......@..@..... ..@....@..@.@.@.
	;;	....@..@..@..... .@@.@..@..@.@.@.
	;;	....@..@..@..... .@..@..@..@...@.
	;;	....@..@........ @@..@..@.@..@@..
	;;	....@........... .@..@.@...@@....
	;;	....@........... @@..@...@@......
	;;	................ @.@@..@@........
	;;	................ @...@@..........
	;;	................ @.@@............
	;;	................ @@..............

img_penitentiary_wall_1:
	DEFB &00, &00, &22, &22, &02, &02, &76, &76, &06, &06, &88, &88, &29, &28, &54, &00
	DEFB &62, &60, &22, &00, &95, &80, &4C, &0C, &2A, &00, &1E, &1E, &51, &00, &0A, &2A
	DEFB &A6, &06, &00, &30, &5F, &1F, &80, &80, &3F, &3F, &D2, &D0, &BC, &BC, &98, &98
	DEFB &D8, &D8, &92, &90, &DD, &DD, &48, &48, &46, &46, &52, &50, &1B, &9B, &98, &98
	DEFB &08, &08, &50, &50, &87, &87, &B0, &B0, &C8, &C8, &26, &20, &64, &64, &C4, &C0
	DEFB &4B, &4B, &22, &20, &1D, &1D, &C4, &C0, &21, &21, &22, &20, &1D, &1D, &C4, &C0
	DEFB &21, &21, &20, &20, &1D, &1D, &C0, &C0, &22, &22, &0E, &00, &1C, &1C, &14, &00
	DEFB &00, &00, &2A, &00, &0C, &0C, &14, &00, &03, &03, &8A, &80, &1B, &1B, &C4, &C0
	DEFB &3E, &3E, &C8, &C0, &6E, &6E, &C0, &C0, &67, &67, &8E, &80, &7F, &7F, &14, &00
	DEFB &1A, &1A, &8A, &80, &69, &69, &84, &80, &31, &31, &CA, &C0, &38, &38, &C4, &C0
	DEFB &18, &18, &80, &80, &1C, &1C, &66, &60, &08, &88, &44, &40, &04, &64, &22, &20
	DEFB &0C, &4C, &C4, &C0, &10, &51, &0A, &00, &18, &1B, &14, &80, &10, &51, &0A, &00
	DEFB &02, &E2, &80, &80, &03, &43, &E0, &E0, &80, &80, &C0, &C0, &E0, &E0, &00, &00
	DEFB &78, &78, &00, &00, &30, &30, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
	;; displaying the images and masks as "wall1+wall2 mask1+mask2"
	;; so it is easier to see, we have the following results:
	;;
	;;	..........@...@. ..........@...@.
	;;	......@..@@@.@@. ......@..@@@.@@.
	;;	.....@@.@...@... .....@@.@...@...
	;;	..@.@..@.@.@.@.. ..@.@...........
	;;	.@@...@...@...@. .@@.............
	;;	@..@.@.@.@..@@.. @...........@@..
	;;	..@.@.@....@@@@. ...........@@@@.
	;;	.@.@...@....@.@. ..........@.@.@.
	;;	@.@..@@......... .....@@...@@....
	;;	.@.@@@@@@....... ...@@@@@@.......
	;;	..@@@@@@@@.@..@. ..@@@@@@@@.@....
	;;	@.@@@@..@..@@... @.@@@@..@..@@...
	;;	@@.@@...@..@..@. @@.@@...@..@....
	;;	@@.@@@.@.@..@... @@.@@@.@.@..@...
	;;	.@...@@..@.@..@. .@...@@..@.@....
	;;	...@@.@@@..@@... @..@@.@@@..@@...
	;;	....@....@.@.... ....@....@.@....
	;;	@....@@@@.@@.... @....@@@@.@@....
	;;	@@..@.....@..@@. @@..@.....@.....
	;;	.@@..@..@@...@.. .@@..@..@@......
	;;	.@..@.@@..@...@. .@..@.@@..@.....
	;;	...@@@.@@@...@.. ...@@@.@@@......
	;;	..@....@..@...@. ..@....@..@.....
	;;	...@@@.@@@...@.. ...@@@.@@@......
	;;	..@....@..@..... ..@....@..@.....
	;;	...@@@.@@@...... ...@@@.@@@......
	;;	..@...@.....@@@. ..@...@.........
	;;	...@@@.....@.@.. ...@@@..........
	;;	..........@.@.@. ................
	;;	....@@.....@.@.. ....@@..........
	;;	......@@@...@.@. ......@@@.......
	;;	...@@.@@@@...@.. ...@@.@@@@......
	;;	..@@@@@.@@..@... ..@@@@@.@@......
	;;	.@@.@@@.@@...... .@@.@@@.@@......
	;;	.@@..@@@@...@@@. .@@..@@@@.......
	;;	.@@@@@@@...@.@.. .@@@@@@@........
	;;	...@@.@.@...@.@. ...@@.@.@.......
	;;	.@@.@..@@....@.. .@@.@..@@.......
	;;	..@@...@@@..@.@. ..@@...@@@......
	;;	..@@@...@@...@.. ..@@@...@@......
	;;	...@@...@....... ...@@...@.......
	;;	...@@@...@@..@@. ...@@@...@@.....
	;;	....@....@...@.. @...@....@......
	;;	.....@....@...@. .@@..@....@.....
	;;	....@@..@@...@.. .@..@@..@@......
	;;	...@........@.@. .@.@...@........
	;;	...@@......@.@.. ...@@.@@@.......
	;;	...@........@.@. .@.@...@........
	;;	......@.@....... @@@...@.@.......
	;;	......@@@@@..... .@....@@@@@.....
	;;	@.......@@...... @.......@@......
	;;	@@@............. @@@.............
	;;	.@@@@........... .@@@@...........
	;;	..@@............ ..@@............
	;;	................ ................
	;;	................ ................

img_moonbase_walls:
img_moonbase_wall_0:
	;; 4 bytes * 56 : interlaced : wall1 + maskwall1 + wall2 + maskwall2 (each are 1byte wide*56)
	DEFB &00, &00, &0F, &00, &00, &00, &36, &30, &00, &00, &F8, &F9, &03, &03, &E0, &E7
	DEFB &0D, &01, &80, &9E, &1E, &00, &00, &58, &38, &01, &03, &D0, &60, &07, &0C, &80
	DEFB &80, &1E, &39, &00, &00, &58, &F2, &00, &03, &D0, &D0, &00, &0E, &80, &D4, &00
	DEFB &3F, &00, &B8, &00, &C7, &00, &F6, &00, &9B, &00, &B7, &00, &6D, &00, &EE, &00
	DEFB &3D, &00, &BE, &00, &B5, &00, &FD, &00, &99, &00, &F7, &00, &93, &00, &7F, &00
	DEFB &8F, &00, &C6, &00, &7B, &00, &3A, &00, &BE, &00, &F0, &01, &FC, &00, &20, &06
	DEFB &EB, &00, &01, &19, &F6, &00, &07, &67, &B0, &01, &07, &B7, &E0, &06, &43, &5B
	DEFB &81, &19, &E0, &EC, &07, &67, &F0, &F7, &07, &B7, &C0, &CE, &43, &5B, &01, &38
	DEFB &E0, &EC, &07, &E0, &F0, &F7, &1F, &80, &C0, &CE, &73, &00, &01, &38, &C3, &08
	DEFB &07, &E0, &03, &08, &1C, &80, &23, &28, &71, &01, &83, &88, &C2, &02, &23, &28
	DEFB &D9, &19, &83, &88, &C2, &02, &23, &28, &D9, &19, &83, &88, &C2, &02, &03, &30
	DEFB &D8, &18, &0F, &C0, &C0, &03, &3E, &00, &C0, &0C, &F9, &01, &C3, &10, &E6, &06
	DEFB &CF, &00, &98, &1B, &FE, &00, &60, &6C, &F9, &01, &80, &B0, &E6, &06, &00, &C0
	DEFB &98, &1B, &00, &00, &60, &6C, &00, &00, &80, &B0, &00, &00, &00, &C0, &00, &00
	;; displaying the images and masks as "wall1+wall2 mask1+mask2"
	;; so it is easier to see, we have the following results:
	;;
	;;	............@@@@ ................
	;;	..........@@.@@. ..........@@....
	;;	........@@@@@... ........@@@@@..@
	;;	......@@@@@..... ......@@@@@..@@@
	;;	....@@.@@....... .......@@..@@@@.
	;;	...@@@@......... .........@.@@...
	;;	..@@@.........@@ .......@@@.@....
	;;	.@@.........@@.. .....@@@@.......
	;;	@.........@@@..@ ...@@@@.........
	;;	........@@@@..@. .@.@@...........
	;;	......@@@@.@.... @@.@............
	;;	....@@@.@@.@.@.. @...............
	;;	..@@@@@@@.@@@... ................
	;;	@@...@@@@@@@.@@. ................
	;;	@..@@.@@@.@@.@@@ ................
	;;	.@@.@@.@@@@.@@@. ................
	;;	..@@@@.@@.@@@@@. ................
	;;	@.@@.@.@@@@@@@.@ ................
	;;	@..@@..@@@@@.@@@ ................
	;;	@..@..@@.@@@@@@@ ................
	;;	@...@@@@@@...@@. ................
	;;	.@@@@.@@..@@@.@. ................
	;;	@.@@@@@.@@@@.... ...............@
	;;	@@@@@@....@..... .............@@.
	;;	@@@.@.@@.......@ ...........@@..@
	;;	@@@@.@@......@@@ .........@@..@@@
	;;	@.@@.........@@@ .......@@.@@.@@@
	;;	@@@......@....@@ .....@@..@.@@.@@
	;;	@......@@@@..... ...@@..@@@@.@@..
	;;	.....@@@@@@@.... .@@..@@@@@@@.@@@
	;;	.....@@@@@...... @.@@.@@@@@..@@@.
	;;	.@....@@.......@ .@.@@.@@..@@@...
	;;	@@@..........@@@ @@@.@@..@@@.....
	;;	@@@@.......@@@@@ @@@@.@@@@.......
	;;	@@.......@@@..@@ @@..@@@.........
	;;	.......@@@....@@ ..@@@.......@...
	;;	.....@@@......@@ @@@.........@...
	;;	...@@@....@...@@ @.........@.@...
	;;	.@@@...@@.....@@ .......@@...@...
	;;	@@....@...@...@@ ......@...@.@...
	;;	@@.@@..@@.....@@ ...@@..@@...@...
	;;	@@....@...@...@@ ......@...@.@...
	;;	@@.@@..@@.....@@ ...@@..@@...@...
	;;	@@....@.......@@ ......@...@@....
	;;	@@.@@.......@@@@ ...@@...@@......
	;;	@@........@@@@@. ......@@........
	;;	@@......@@@@@..@ ....@@.........@
	;;	@@....@@@@@..@@. ...@.........@@.
	;;	@@..@@@@@..@@... ...........@@.@@
	;;	@@@@@@@..@@..... .........@@.@@..
	;;	@@@@@..@@....... .......@@.@@....
	;;	@@@..@@......... .....@@.@@......
	;;	@..@@........... ...@@.@@........
	;;	.@@............. .@@.@@..........
	;;	@............... @.@@............
	;;	................ @@..............

img_moonbase_wall_1:
	DEFB &00, &00, &0F, &00, &00, &00, &36, &30, &00, &00, &F8, &F9, &03, &03, &E0, &E7
	DEFB &0D, &01, &80, &9E, &1E, &00, &00, &58, &38, &01, &03, &D0, &60, &07, &0F, &80
	DEFB &80, &1E, &38, &00, &00, &58, &F6, &00, &03, &D0, &AF, &00, &00, &80, &E7, &00
	DEFB &17, &00, &22, &00, &49, &00, &D1, &00, &12, &00, &6B, &00, &48, &00, &25, &00
	DEFB &01, &00, &6B, &00, &00, &00, &DD, &00, &01, &00, &CF, &00, &03, &00, &36, &00
	DEFB &0E, &00, &DF, &00, &F4, &00, &FE, &00, &DA, &00, &E8, &01, &DB, &00, &60, &06
	DEFB &ED, &00, &81, &19, &FE, &00, &07, &67, &B8, &01, &07, &B7, &E0, &06, &43, &5B
	DEFB &81, &19, &E0, &EC, &07, &67, &F0, &F7, &07, &B7, &C0, &CE, &43, &5B, &01, &38
	DEFB &E0, &EC, &07, &E0, &F0, &F7, &1F, &80, &C0, &CE, &73, &00, &01, &38, &C3, &08
	DEFB &07, &E0, &03, &08, &1C, &80, &23, &28, &71, &01, &83, &88, &C2, &02, &23, &28
	DEFB &D9, &19, &83, &88, &C2, &02, &23, &28, &D9, &19, &83, &88, &C2, &02, &03, &30
	DEFB &D8, &18, &0F, &C0, &C0, &03, &3E, &00, &C0, &0C, &F9, &01, &C3, &10, &E6, &06
	DEFB &CF, &00, &98, &1B, &FE, &00, &60, &6C, &F9, &01, &80, &B0, &E6, &06, &00, &C0
	DEFB &98, &1B, &00, &00, &60, &6C, &00, &00, &80, &B0, &00, &00, &00, &C0, &00, &00
	;; displaying the images and masks as "wall1+wall2 mask1+mask2"
	;; so it is easier to see, we have the following results:
	;;
	;;	............@@@@ ................
	;;	..........@@.@@. ..........@@....
	;;	........@@@@@... ........@@@@@..@
	;;	......@@@@@..... ......@@@@@..@@@
	;;	....@@.@@....... .......@@..@@@@.
	;;	...@@@@......... .........@.@@...
	;;	..@@@.........@@ .......@@@.@....
	;;	.@@.........@@@@ .....@@@@.......
	;;	@.........@@@... ...@@@@.........
	;;	........@@@@.@@. .@.@@...........
	;;	......@@@.@.@@@@ @@.@............
	;;	........@@@..@@@ @...............
	;;	...@.@@@..@...@. ................
	;;	.@..@..@@@.@...@ ................
	;;	...@..@..@@.@.@@ ................
	;;	.@..@.....@..@.@ ................
	;;	.......@.@@.@.@@ ................
	;;	........@@.@@@.@ ................
	;;	.......@@@..@@@@ ................
	;;	......@@..@@.@@. ................
	;;	....@@@.@@.@@@@@ ................
	;;	@@@@.@..@@@@@@@. ................
	;;	@@.@@.@.@@@.@... ...............@
	;;	@@.@@.@@.@@..... .............@@.
	;;	@@@.@@.@@......@ ...........@@..@
	;;	@@@@@@@......@@@ .........@@..@@@
	;;	@.@@@........@@@ .......@@.@@.@@@
	;;	@@@......@....@@ .....@@..@.@@.@@
	;;	@......@@@@..... ...@@..@@@@.@@..
	;;	.....@@@@@@@.... .@@..@@@@@@@.@@@
	;;	.....@@@@@...... @.@@.@@@@@..@@@.
	;;	.@....@@.......@ .@.@@.@@..@@@...
	;;	@@@..........@@@ @@@.@@..@@@.....
	;;	@@@@.......@@@@@ @@@@.@@@@.......
	;;	@@.......@@@..@@ @@..@@@.........
	;;	.......@@@....@@ ..@@@.......@...
	;;	.....@@@......@@ @@@.........@...
	;;	...@@@....@...@@ @.........@.@...
	;;	.@@@...@@.....@@ .......@@...@...
	;;	@@....@...@...@@ ......@...@.@...
	;;	@@.@@..@@.....@@ ...@@..@@...@...
	;;	@@....@...@...@@ ......@...@.@...
	;;	@@.@@..@@.....@@ ...@@..@@...@...
	;;	@@....@.......@@ ......@...@@....
	;;	@@.@@.......@@@@ ...@@...@@......
	;;	@@........@@@@@. ......@@........
	;;	@@......@@@@@..@ ....@@.........@
	;;	@@....@@@@@..@@. ...@.........@@.
	;;	@@..@@@@@..@@... ...........@@.@@
	;;	@@@@@@@..@@..... .........@@.@@..
	;;	@@@@@..@@....... .......@@.@@....
	;;	@@@..@@......... .....@@.@@......
	;;	@..@@........... ...@@.@@........
	;;	.@@............. .@@.@@..........
	;;	@............... @.@@............
	;;	................ @@..............

img_moonbase_wall_2:
	DEFB &00, &00, &0F, &00, &00, &00, &36, &30, &00, &00, &F8, &F9, &03, &03, &E0, &E7
	DEFB &0D, &01, &80, &9E, &1E, &00, &00, &58, &38, &01, &03, &D0, &60, &07, &05, &80
	DEFB &80, &1E, &02, &00, &00, &58, &00, &00, &02, &D0, &01, &00, &0F, &80, &06, &00
	DEFB &36, &00, &DB, &00, &FD, &00, &BF, &00, &8F, &00, &F6, &00, &77, &00, &FD, &00
	DEFB &FA, &00, &E0, &00, &FB, &00, &D8, &00, &67, &00, &D1, &00, &47, &00, &40, &00
	DEFB &8D, &00, &E2, &00, &FF, &00, &FE, &00, &73, &00, &F8, &01, &ED, &00, &60, &06
	DEFB &DE, &00, &81, &19, &D8, &00, &07, &67, &E0, &01, &07, &B7, &E0, &06, &43, &5B
	DEFB &81, &19, &E0, &EC, &07, &67, &F0, &F7, &07, &B7, &C0, &CE, &43, &5B, &01, &38
	DEFB &E0, &EC, &07, &E0, &F0, &F7, &1F, &80, &C0, &CE, &73, &00, &01, &38, &C3, &08
	DEFB &07, &E0, &03, &08, &1C, &80, &23, &28, &71, &01, &83, &88, &C2, &02, &23, &28
	DEFB &D9, &19, &83, &88, &C2, &02, &23, &28, &D9, &19, &83, &88, &C2, &02, &03, &30
	DEFB &D8, &18, &0F, &C0, &C0, &03, &3E, &00, &C0, &0C, &F9, &01, &C3, &10, &E6, &06
	DEFB &CF, &00, &98, &1B, &FE, &00, &60, &6C, &F9, &01, &80, &B0, &E6, &06, &00, &C0
	DEFB &98, &1B, &00, &00, &60, &6C, &00, &00, &80, &B0, &00, &00, &00, &C0, &00, &00
	;; displaying the images and masks as "wall1+wall2 mask1+mask2"
	;; so it is easier to see, we have the following results:
	;;
	;;	............@@@@ ................
	;;	..........@@.@@. ..........@@....
	;;	........@@@@@... ........@@@@@..@
	;;	......@@@@@..... ......@@@@@..@@@
	;;	....@@.@@....... .......@@..@@@@.
	;;	...@@@@......... .........@.@@...
	;;	..@@@.........@@ .......@@@.@....
	;;	.@@..........@.@ .....@@@@.......
	;;	@.............@. ...@@@@.........
	;;	................ .@.@@...........
	;;	......@........@ @@.@............
	;;	....@@@@.....@@. @...............
	;;	..@@.@@.@@.@@.@@ ................
	;;	@@@@@@.@@.@@@@@@ ................
	;;	@...@@@@@@@@.@@. ................
	;;	.@@@.@@@@@@@@@.@ ................
	;;	@@@@@.@.@@@..... ................
	;;	@@@@@.@@@@.@@... ................
	;;	.@@..@@@@@.@...@ ................
	;;	.@...@@@.@...... ................
	;;	@...@@.@@@@...@. ................
	;;	@@@@@@@@@@@@@@@. ................
	;;	.@@@..@@@@@@@... ...............@
	;;	@@@.@@.@.@@..... .............@@.
	;;	@@.@@@@.@......@ ...........@@..@
	;;	@@.@@........@@@ .........@@..@@@
	;;	@@@..........@@@ .......@@.@@.@@@
	;;	@@@......@....@@ .....@@..@.@@.@@
	;;	@......@@@@..... ...@@..@@@@.@@..
	;;	.....@@@@@@@.... .@@..@@@@@@@.@@@
	;;	.....@@@@@...... @.@@.@@@@@..@@@.
	;;	.@....@@.......@ .@.@@.@@..@@@...
	;;	@@@..........@@@ @@@.@@..@@@.....
	;;	@@@@.......@@@@@ @@@@.@@@@.......
	;;	@@.......@@@..@@ @@..@@@.........
	;;	.......@@@....@@ ..@@@.......@...
	;;	.....@@@......@@ @@@.........@...
	;;	...@@@....@...@@ @.........@.@...
	;;	.@@@...@@.....@@ .......@@...@...
	;;	@@....@...@...@@ ......@...@.@...
	;;	@@.@@..@@.....@@ ...@@..@@...@...
	;;	@@....@...@...@@ ......@...@.@...
	;;	@@.@@..@@.....@@ ...@@..@@...@...
	;;	@@....@.......@@ ......@...@@....
	;;	@@.@@.......@@@@ ...@@...@@......
	;;	@@........@@@@@. ......@@........
	;;	@@......@@@@@..@ ....@@.........@
	;;	@@....@@@@@..@@. ...@.........@@.
	;;	@@..@@@@@..@@... ...........@@.@@
	;;	@@@@@@@..@@..... .........@@.@@..
	;;	@@@@@..@@....... .......@@.@@....
	;;	@@@..@@......... .....@@.@@......
	;;	@..@@........... ...@@.@@........
	;;	.@@............. .@@.@@..........
	;;	@............... @.@@............
	;;	................ @@..............

img_moonbase_wall_3:
	DEFB &00, &00, &0F, &00, &00, &00, &36, &30, &00, &00, &F8, &F9, &03, &03, &E0, &E7
	DEFB &0D, &01, &80, &9E, &1E, &00, &00, &58, &38, &01, &00, &D0, &60, &07, &08, &80
	DEFB &80, &1E, &1C, &00, &00, &58, &0E, &60, &00, &D1, &06, &B0, &0E, &80, &06, &D0
	DEFB &07, &20, &06, &50, &03, &58, &06, &50, &03, &48, &06, &50, &13, &50, &06, &50
	DEFB &1B, &58, &06, &50, &1B, &58, &06, &50, &1B, &58, &06, &50, &1B, &58, &06, &50
	DEFB &0B, &68, &06, &50, &03, &70, &06, &50, &03, &58, &06, &50, &03, &48, &02, &50
	DEFB &13, &50, &06, &40, &1B, &58, &06, &00, &1A, &58, &16, &10, &1A, &58, &E6, &E0
	DEFB &1A, &58, &16, &10, &0A, &E8, &E6, &E0, &02, &B0, &16, &10, &42, &58, &E2, &E0
	DEFB &E2, &E8, &0E, &00, &F2, &F0, &06, &30, &C2, &C8, &06, &D0, &03, &38, &06, &50
	DEFB &03, &E0, &06, &50, &1B, &80, &06, &50, &73, &00, &06, &50, &C3, &00, &06, &50
	DEFB &DB, &18, &06, &50, &C3, &00, &06, &50, &DB, &18, &06, &50, &C3, &00, &06, &50
	DEFB &DB, &18, &06, &50, &C3, &00, &04, &50, &C3, &08, &01, &51, &C3, &10, &06, &46
	DEFB &CB, &00, &18, &1B, &F6, &00, &60, &6C, &F1, &01, &80, &B0, &E6, &06, &00, &C0
	DEFB &98, &1B, &00, &00, &60, &6C, &00, &00, &80, &B0, &00, &00, &00, &C0, &00, &00
	;; displaying the images and masks as "wall1+wall2 mask1+mask2"
	;; so it is easier to see, we have the following results:
	;;
	;;	............@@@@ ................
	;;	..........@@.@@. ..........@@....
	;;	........@@@@@... ........@@@@@..@
	;;	......@@@@@..... ......@@@@@..@@@
	;;	....@@.@@....... .......@@..@@@@.
	;;	...@@@@......... .........@.@@...
	;;	..@@@........... .......@@@.@....
	;;	.@@.........@... .....@@@@.......
	;;	@..........@@@.. ...@@@@.........
	;;	............@@@. .@.@@....@@.....
	;;	.............@@. @@.@...@@.@@....
	;;	....@@@......@@. @.......@@.@....
	;;	.....@@@.....@@. ..@......@.@....
	;;	......@@.....@@. .@.@@....@.@....
	;;	......@@.....@@. .@..@....@.@....
	;;	...@..@@.....@@. .@.@.....@.@....
	;;	...@@.@@.....@@. .@.@@....@.@....
	;;	...@@.@@.....@@. .@.@@....@.@....
	;;	...@@.@@.....@@. .@.@@....@.@....
	;;	...@@.@@.....@@. .@.@@....@.@....
	;;	....@.@@.....@@. .@@.@....@.@....
	;;	......@@.....@@. .@@@.....@.@....
	;;	......@@.....@@. .@.@@....@.@....
	;;	......@@......@. .@..@....@.@....
	;;	...@..@@.....@@. .@.@.....@......
	;;	...@@.@@.....@@. .@.@@...........
	;;	...@@.@....@.@@. .@.@@......@....
	;;	...@@.@.@@@..@@. .@.@@...@@@.....
	;;	...@@.@....@.@@. .@.@@......@....
	;;	....@.@.@@@..@@. @@@.@...@@@.....
	;;	......@....@.@@. @.@@.......@....
	;;	.@....@.@@@...@. .@.@@...@@@.....
	;;	@@@...@.....@@@. @@@.@...........
	;;	@@@@..@......@@. @@@@......@@....
	;;	@@....@......@@. @@..@...@@.@....
	;;	......@@.....@@. ..@@@....@.@....
	;;	......@@.....@@. @@@......@.@....
	;;	...@@.@@.....@@. @........@.@....
	;;	.@@@..@@.....@@. .........@.@....
	;;	@@....@@.....@@. .........@.@....
	;;	@@.@@.@@.....@@. ...@@....@.@....
	;;	@@....@@.....@@. .........@.@....
	;;	@@.@@.@@.....@@. ...@@....@.@....
	;;	@@....@@.....@@. .........@.@....
	;;	@@.@@.@@.....@@. ...@@....@.@....
	;;	@@....@@.....@.. .........@.@....
	;;	@@....@@.......@ ....@....@.@...@
	;;	@@....@@.....@@. ...@.....@...@@.
	;;	@@..@.@@...@@... ...........@@.@@
	;;	@@@@.@@..@@..... .........@@.@@..
	;;	@@@@...@@....... .......@@.@@....
	;;	@@@..@@......... .....@@.@@......
	;;	@..@@........... ...@@.@@........
	;;	.@@............. .@@.@@..........
	;;	@............... @.@@............
	;;	................ @@..............

img_bookworld_walls:
img_bookworld_wall_0:
	;; 4 bytes * 56 : interlaced : wall1 + maskwall1 + wall2 + maskwall2 (each are 1byte wide*56)
	DEFB &00, &00, &03, &00, &00, &00, &0C, &00, &00, &00, &38, &01, &00, &00, &E0, &05
	DEFB &03, &00, &80, &15, &0E, &00, &00, &59, &38, &01, &00, &DD, &60, &07, &00, &04
	DEFB &80, &14, &00, &01, &00, &30, &00, &01, &07, &B0, &00, &01, &0B, &A0, &80, &01
	DEFB &0C, &A0, &40, &01, &1E, &80, &C0, &01, &1F, &80, &D0, &00, &27, &00, &98, &01
	DEFB &08, &88, &48, &41, &31, &81, &18, &01, &3C, &80, &70, &01, &0F, &80, &C0, &01
	DEFB &20, &A0, &00, &01, &19, &99, &A0, &A0, &1E, &1E, &08, &01, &2D, &8D, &94, &81
	DEFB &50, &00, &0C, &41, &28, &03, &3C, &81, &74, &00, &78, &01, &7F, &00, &B8, &81
	DEFB &5F, &00, &98, &00, &5E, &00, &70, &05, &4D, &00, &A0, &85, &0F, &00, &98, &19
	DEFB &64, &00, &2C, &2D, &43, &1B, &0C, &4D, &06, &B6, &48, &E9, &06, &96, &00, &40
	DEFB &07, &07, &B0, &81, &32, &82, &78, &01, &38, &A0, &D8, &01, &3E, &80, &3C, &01
	DEFB &3F, &90, &7C, &01, &1F, &80, &BC, &01, &0F, &84, &B8, &00, &0F, &00, &D0, &01
	DEFB &07, &82, &C0, &01, &07, &80, &D0, &01, &07, &82, &C0, &01, &07, &80, &D8, &01
	DEFB &13, &90, &B8, &01, &2C, &A0, &00, &00, &13, &10, &40, &00, &07, &80, &E0, &00
	DEFB &01, &80, &E0, &00, &00, &80, &00, &00, &00, &80, &00, &00, &00, &80, &00, &00
	;; displaying the images and masks as "wall1+wall2 mask1+mask2"
	;; so it is easier to see, we have the following results:
	;;
	;;	..............@@ ................
	;;	............@@.. ................
	;;	..........@@@... ...............@
	;;	........@@@..... .............@.@
	;;	......@@@....... ...........@.@.@
	;;	....@@@......... .........@.@@..@
	;;	..@@@........... .......@@@.@@@.@
	;;	.@@............. .....@@@.....@..
	;;	@............... ...@.@.........@
	;;	................ ..@@...........@
	;;	.....@@@........ @.@@...........@
	;;	....@.@@@....... @.@............@
	;;	....@@...@...... @.@............@
	;;	...@@@@.@@...... @..............@
	;;	...@@@@@@@.@.... @...............
	;;	..@..@@@@..@@... ...............@
	;;	....@....@..@... @...@....@.....@
	;;	..@@...@...@@... @......@.......@
	;;	..@@@@...@@@.... @..............@
	;;	....@@@@@@...... @..............@
	;;	..@............. @.@............@
	;;	...@@..@@.@..... @..@@..@@.@.....
	;;	...@@@@.....@... ...@@@@........@
	;;	..@.@@.@@..@.@.. @...@@.@@......@
	;;	.@.@........@@.. .........@.....@
	;;	..@.@.....@@@@.. ......@@@......@
	;;	.@@@.@...@@@@... ...............@
	;;	.@@@@@@@@.@@@... ........@......@
	;;	.@.@@@@@@..@@... ................
	;;	.@.@@@@..@@@.... .............@.@
	;;	.@..@@.@@.@..... ........@....@.@
	;;	....@@@@@..@@... ...........@@..@
	;;	.@@..@....@.@@.. ..........@.@@.@
	;;	.@....@@....@@.. ...@@.@@.@..@@.@
	;;	.....@@..@..@... @.@@.@@.@@@.@..@
	;;	.....@@......... @..@.@@..@......
	;;	.....@@@@.@@.... .....@@@@......@
	;;	..@@..@..@@@@... @.....@........@
	;;	..@@@...@@.@@... @.@............@
	;;	..@@@@@...@@@@.. @..............@
	;;	..@@@@@@.@@@@@.. @..@...........@
	;;	...@@@@@@.@@@@.. @..............@
	;;	....@@@@@.@@@... @....@..........
	;;	....@@@@@@.@.... ...............@
	;;	.....@@@@@...... @.....@........@
	;;	.....@@@@@.@.... @..............@
	;;	.....@@@@@...... @.....@........@
	;;	.....@@@@@.@@... @..............@
	;;	...@..@@@.@@@... @..@...........@
	;;	..@.@@.......... @.@.............
	;;	...@..@@.@...... ...@............
	;;	.....@@@@@@..... @...............
	;;	.......@@@@..... @...............
	;;	................ @...............
	;;	................ @...............
	;;	................ @...............

img_bookworld_wall_1:
	DEFB &00, &00, &E3, &E0, &00, &00, &30, &34, &08, &08, &30, &37, &11, &10, &B0, &37
	DEFB &37, &30, &C0, &0B, &33, &30, &C0, &1D, &35, &34, &C0, &11, &1D, &1C, &80, &0C
	DEFB &02, &00, &00, &33, &00, &3C, &00, &C7, &00, &B3, &10, &07, &00, &8C, &A0, &07
	DEFB &00, &B0, &00, &07, &08, &80, &A0, &03, &05, &80, &50, &04, &08, &00, &A0, &07
	DEFB &04, &80, &10, &07, &01, &81, &C0, &C7, &07, &87, &E0, &E7, &0F, &8F, &F0, &F3
	DEFB &37, &B7, &F8, &F9, &3B, &BB, &FC, &FC, &3D, &3D, &FE, &FE, &3E, &BE, &F0, &F1
	DEFB &3F, &BF, &4E, &4E, &3F, &BF, &B0, &B1, &3C, &BC, &40, &4D, &3B, &BB, &00, &32
	DEFB &24, &A4, &00, &4C, &10, &13, &00, &33, &00, &8C, &00, &C3, &00, &B3, &10, &01
	DEFB &00, &8C, &68, &61, &01, &B0, &18, &01, &05, &80, &F8, &01, &1A, &98, &F0, &00
	DEFB &06, &00, &08, &09, &3E, &80, &F0, &F1, &3C, &80, &08, &01, &02, &82, &F8, &01
	DEFB &3C, &BC, &F8, &01, &02, &80, &F8, &01, &3E, &80, &F0, &00, &3E, &00, &08, &09
	DEFB &3E, &80, &F0, &F1, &3C, &80, &08, &01, &02, &82, &F8, &01, &3C, &BC, &F0, &05
	DEFB &02, &80, &00, &03, &3E, &80, &00, &CC, &3C, &01, &00, &30, &00, &80, &00, &C0
	DEFB &00, &B3, &00, &00, &00, &8C, &00, &00, &00, &B0, &00, &00, &00, &C0, &00, &00
	;; displaying the images and masks as "wall1+wall2 mask1+mask2"
	;; so it is easier to see, we have the following results:
	;;
	;;	........@@@...@@ ........@@@.....
	;;	..........@@.... ..........@@.@..
	;;	....@.....@@.... ....@.....@@.@@@
	;;	...@...@@.@@.... ...@......@@.@@@
	;;	..@@.@@@@@...... ..@@........@.@@
	;;	..@@..@@@@...... ..@@.......@@@.@
	;;	..@@.@.@@@...... ..@@.@.....@...@
	;;	...@@@.@@....... ...@@@......@@..
	;;	......@......... ..........@@..@@
	;;	................ ..@@@@..@@...@@@
	;;	...........@.... @.@@..@@.....@@@
	;;	........@.@..... @...@@.......@@@
	;;	................ @.@@.........@@@
	;;	....@...@.@..... @.............@@
	;;	.....@.@.@.@.... @............@..
	;;	....@...@.@..... .............@@@
	;;	.....@.....@.... @............@@@
	;;	.......@@@...... @......@@@...@@@
	;;	.....@@@@@@..... @....@@@@@@..@@@
	;;	....@@@@@@@@.... @...@@@@@@@@..@@
	;;	..@@.@@@@@@@@... @.@@.@@@@@@@@..@
	;;	..@@@.@@@@@@@@.. @.@@@.@@@@@@@@..
	;;	..@@@@.@@@@@@@@. ..@@@@.@@@@@@@@.
	;;	..@@@@@.@@@@.... @.@@@@@.@@@@...@
	;;	..@@@@@@.@..@@@. @.@@@@@@.@..@@@.
	;;	..@@@@@@@.@@.... @.@@@@@@@.@@...@
	;;	..@@@@...@...... @.@@@@...@..@@.@
	;;	..@@@.@@........ @.@@@.@@..@@..@.
	;;	..@..@.......... @.@..@...@..@@..
	;;	...@............ ...@..@@..@@..@@
	;;	................ @...@@..@@....@@
	;;	...........@.... @.@@..@@.......@
	;;	.........@@.@... @...@@...@@....@
	;;	.......@...@@... @.@@...........@
	;;	.....@.@@@@@@... @..............@
	;;	...@@.@.@@@@.... @..@@...........
	;;	.....@@.....@... ............@..@
	;;	..@@@@@.@@@@.... @.......@@@@...@
	;;	..@@@@......@... @..............@
	;;	......@.@@@@@... @.....@........@
	;;	..@@@@..@@@@@... @.@@@@.........@
	;;	......@.@@@@@... @..............@
	;;	..@@@@@.@@@@.... @...............
	;;	..@@@@@.....@... ............@..@
	;;	..@@@@@.@@@@.... @.......@@@@...@
	;;	..@@@@......@... @..............@
	;;	......@.@@@@@... @.....@........@
	;;	..@@@@..@@@@.... @.@@@@.......@.@
	;;	......@......... @.............@@
	;;	..@@@@@......... @.......@@..@@..
	;;	..@@@@.......... .......@..@@....
	;;	................ @.......@@......
	;;	................ @.@@..@@........
	;;	................ @...@@..........
	;;	................ @.@@............
	;;	................ @@..............

img_safari_walls:
img_safari_wall_0:
	;; 4 bytes * 56 : interlaced : wall1 + maskwall1 + wall2 + maskwall2 (each are 1byte wide*56)
	DEFB &00, &00, &00, &10, &01, &00, &80, &18, &01, &00, &80, &38, &01, &00, &80, &1C
	DEFB &02, &12, &40, &5C, &07, &17, &C0, &CE, &07, &37, &A0, &AE, &0B, &2B, &E0, &E0
	DEFB &09, &69, &B2, &B0, &09, &69, &D2, &D0, &11, &D1, &CA, &C8, &18, &58, &DA, &D8
	DEFB &9C, &1C, &E8, &E8, &9E, &1E, &D4, &D4, &AE, &2E, &E4, &E4, &AF, &2F, &C4, &C4
	DEFB &A7, &27, &EC, &EC, &23, &23, &F6, &F6, &A1, &21, &EA, &EA, &B1, &31, &F6, &F6
	DEFB &7C, &7C, &EA, &EA, &7F, &7F, &F6, &F6, &7F, &7F, &EA, &EA, &5F, &5F, &F2, &F2
	DEFB &47, &47, &E2, &E2, &43, &43, &F6, &F6, &40, &40, &EA, &EA, &40, &40, &76, &76
	DEFB &47, &47, &EA, &EA, &5F, &5F, &F6, &F6, &7F, &7F, &E2, &E2, &7C, &7C, &72, &72
	DEFB &50, &50, &EA, &EA, &41, &41, &F6, &F6, &41, &41, &EA, &EA, &47, &47, &F6, &F6
	DEFB &47, &47, &EA, &EA, &5F, &5F, &F4, &F4, &5F, &5F, &EC, &EC, &7E, &7E, &E4, &E4
	DEFB &7C, &7C, &E4, &E4, &B8, &38, &D8, &D8, &B1, &31, &EA, &E8, &A1, &21, &DA, &D8
	DEFB &B3, &33, &EA, &E8, &93, &13, &D2, &D0, &93, &13, &F2, &F0, &9B, &1B, &D2, &D0
	DEFB &AF, &0F, &A4, &A0, &AF, &0F, &E6, &E0, &A7, &07, &C8, &C0, &AA, &02, &40, &40
	DEFB &54, &01, &00, &80, &D4, &01, &00, &80, &78, &00, &00, &00, &00, &00, &00, &00
	;; displaying the images and masks as "wall1+wall2 mask1+mask2"
	;; so it is easier to see, we have the following results:
	;;
	;;	................ ...........@....
	;;	.......@@....... ...........@@...
	;;	.......@@....... ..........@@@...
	;;	.......@@....... ...........@@@..
	;;	......@..@...... ...@..@..@.@@@..
	;;	.....@@@@@...... ...@.@@@@@..@@@.
	;;	.....@@@@.@..... ..@@.@@@@.@.@@@.
	;;	....@.@@@@@..... ..@.@.@@@@@.....
	;;	....@..@@.@@..@. .@@.@..@@.@@....
	;;	....@..@@@.@..@. .@@.@..@@@.@....
	;;	...@...@@@..@.@. @@.@...@@@..@...
	;;	...@@...@@.@@.@. .@.@@...@@.@@...
	;;	@..@@@..@@@.@... ...@@@..@@@.@...
	;;	@..@@@@.@@.@.@.. ...@@@@.@@.@.@..
	;;	@.@.@@@.@@@..@.. ..@.@@@.@@@..@..
	;;	@.@.@@@@@@...@.. ..@.@@@@@@...@..
	;;	@.@..@@@@@@.@@.. ..@..@@@@@@.@@..
	;;	..@...@@@@@@.@@. ..@...@@@@@@.@@.
	;;	@.@....@@@@.@.@. ..@....@@@@.@.@.
	;;	@.@@...@@@@@.@@. ..@@...@@@@@.@@.
	;;	.@@@@@..@@@.@.@. .@@@@@..@@@.@.@.
	;;	.@@@@@@@@@@@.@@. .@@@@@@@@@@@.@@.
	;;	.@@@@@@@@@@.@.@. .@@@@@@@@@@.@.@.
	;;	.@.@@@@@@@@@..@. .@.@@@@@@@@@..@.
	;;	.@...@@@@@@...@. .@...@@@@@@...@.
	;;	.@....@@@@@@.@@. .@....@@@@@@.@@.
	;;	.@......@@@.@.@. .@......@@@.@.@.
	;;	.@.......@@@.@@. .@.......@@@.@@.
	;;	.@...@@@@@@.@.@. .@...@@@@@@.@.@.
	;;	.@.@@@@@@@@@.@@. .@.@@@@@@@@@.@@.
	;;	.@@@@@@@@@@...@. .@@@@@@@@@@...@.
	;;	.@@@@@...@@@..@. .@@@@@...@@@..@.
	;;	.@.@....@@@.@.@. .@.@....@@@.@.@.
	;;	.@.....@@@@@.@@. .@.....@@@@@.@@.
	;;	.@.....@@@@.@.@. .@.....@@@@.@.@.
	;;	.@...@@@@@@@.@@. .@...@@@@@@@.@@.
	;;	.@...@@@@@@.@.@. .@...@@@@@@.@.@.
	;;	.@.@@@@@@@@@.@.. .@.@@@@@@@@@.@..
	;;	.@.@@@@@@@@.@@.. .@.@@@@@@@@.@@..
	;;	.@@@@@@.@@@..@.. .@@@@@@.@@@..@..
	;;	.@@@@@..@@@..@.. .@@@@@..@@@..@..
	;;	@.@@@...@@.@@... ..@@@...@@.@@...
	;;	@.@@...@@@@.@.@. ..@@...@@@@.@...
	;;	@.@....@@@.@@.@. ..@....@@@.@@...
	;;	@.@@..@@@@@.@.@. ..@@..@@@@@.@...
	;;	@..@..@@@@.@..@. ...@..@@@@.@....
	;;	@..@..@@@@@@..@. ...@..@@@@@@....
	;;	@..@@.@@@@.@..@. ...@@.@@@@.@....
	;;	@.@.@@@@@.@..@.. ....@@@@@.@.....
	;;	@.@.@@@@@@@..@@. ....@@@@@@@.....
	;;	@.@..@@@@@..@... .....@@@@@......
	;;	@.@.@.@..@...... ......@..@......
	;;	.@.@.@.......... .......@@.......
	;;	@@.@.@.......... .......@@.......
	;;	.@@@@........... ................
	;;	................ ................

img_safari_wall_1:
	DEFB &00, &00, &00, &10, &00, &00, &00, &38, &00, &00, &00, &38, &00, &00, &00, &3C
	DEFB &00, &10, &00, &5C, &00, &18, &00, &7E, &00, &38, &00, &BE, &00, &3C, &00, &78
	DEFB &00, &5C, &82, &00, &00, &7E, &AA, &00, &00, &BE, &AA, &00, &00, &78, &DA, &00
	DEFB &82, &00, &AE, &00, &AA, &00, &78, &00, &AA, &00, &86, &00, &DA, &00, &FA, &00
	DEFB &AE, &00, &AA, &00, &78, &00, &D6, &00, &86, &00, &56, &00, &FC, &00, &AA, &00
	DEFB &AA, &00, &AA, &00, &AA, &00, &AA, &00, &B6, &00, &D6, &00, &AA, &00, &D4, &00
	DEFB &AA, &00, &AA, &00, &56, &00, &AA, &00, &DA, &00, &EA, &00, &AA, &00, &5A, &00
	DEFB &B4, &00, &AA, &00, &B6, &00, &AA, &00, &AA, &00, &AA, &00, &AA, &00, &DC, &00
	DEFB &AA, &00, &AA, &00, &B4, &00, &AA, &00, &56, &00, &AE, &00, &6A, &00, &78, &00
	DEFB &AA, &00, &86, &00, &AA, &00, &FA, &00, &AE, &00, &AA, &00, &78, &00, &AA, &00
	DEFB &86, &00, &AA, &00, &FA, &00, &B4, &00, &AA, &00, &B6, &00, &AA, &00, &AA, &00
	DEFB &AA, &00, &AA, &00, &B4, &00, &AA, &00, &B6, &00, &AA, &00, &AA, &00, &AA, &00
	DEFB &AA, &00, &54, &00, &AA, &00, &D6, &00, &AA, &00, &78, &00, &AA, &00, &00, &00
	DEFB &54, &00, &00, &00, &D6, &00, &00, &00, &78, &00, &00, &00, &00, &00, &00, &00
	;; displaying the images and masks as "wall1+wall2 mask1+mask2"
	;; so it is easier to see, we have the following results:
	;;
	;;	................ ...........@....
	;;	................ ..........@@@...
	;;	................ ..........@@@...
	;;	................ ..........@@@@..
	;;	................ ...@.....@.@@@..
	;;	................ ...@@....@@@@@@.
	;;	................ ..@@@...@.@@@@@.
	;;	................ ..@@@@...@@@@...
	;;	........@.....@. .@.@@@..........
	;;	........@.@.@.@. .@@@@@@.........
	;;	........@.@.@.@. @.@@@@@.........
	;;	........@@.@@.@. .@@@@...........
	;;	@.....@.@.@.@@@. ................
	;;	@.@.@.@..@@@@... ................
	;;	@.@.@.@.@....@@. ................
	;;	@@.@@.@.@@@@@.@. ................
	;;	@.@.@@@.@.@.@.@. ................
	;;	.@@@@...@@.@.@@. ................
	;;	@....@@..@.@.@@. ................
	;;	@@@@@@..@.@.@.@. ................
	;;	@.@.@.@.@.@.@.@. ................
	;;	@.@.@.@.@.@.@.@. ................
	;;	@.@@.@@.@@.@.@@. ................
	;;	@.@.@.@.@@.@.@.. ................
	;;	@.@.@.@.@.@.@.@. ................
	;;	.@.@.@@.@.@.@.@. ................
	;;	@@.@@.@.@@@.@.@. ................
	;;	@.@.@.@..@.@@.@. ................
	;;	@.@@.@..@.@.@.@. ................
	;;	@.@@.@@.@.@.@.@. ................
	;;	@.@.@.@.@.@.@.@. ................
	;;	@.@.@.@.@@.@@@.. ................
	;;	@.@.@.@.@.@.@.@. ................
	;;	@.@@.@..@.@.@.@. ................
	;;	.@.@.@@.@.@.@@@. ................
	;;	.@@.@.@..@@@@... ................
	;;	@.@.@.@.@....@@. ................
	;;	@.@.@.@.@@@@@.@. ................
	;;	@.@.@@@.@.@.@.@. ................
	;;	.@@@@...@.@.@.@. ................
	;;	@....@@.@.@.@.@. ................
	;;	@@@@@.@.@.@@.@.. ................
	;;	@.@.@.@.@.@@.@@. ................
	;;	@.@.@.@.@.@.@.@. ................
	;;	@.@.@.@.@.@.@.@. ................
	;;	@.@@.@..@.@.@.@. ................
	;;	@.@@.@@.@.@.@.@. ................
	;;	@.@.@.@.@.@.@.@. ................
	;;	@.@.@.@..@.@.@.. ................
	;;	@.@.@.@.@@.@.@@. ................
	;;	@.@.@.@..@@@@... ................
	;;	@.@.@.@......... ................
	;;	.@.@.@.......... ................
	;;	@@.@.@@......... ................
	;;	.@@@@........... ................
	;;	................ ................

img_safari_wall_2:
	DEFB &00, &00, &00, &10, &00, &00, &00, &18, &00, &00, &00, &38, &00, &00, &00, &3C
	DEFB &00, &10, &00, &5C, &00, &18, &00, &7E, &00, &38, &00, &BE, &00, &3C, &00, &78
	DEFB &00, &5C, &82, &00, &00, &7E, &AA, &00, &00, &BE, &AA, &00, &00, &78, &DA, &00
	DEFB &82, &00, &AE, &00, &AA, &00, &F8, &00, &AA, &00, &80, &04, &DA, &00, &00, &7C
	DEFB &AE, &00, &00, &78, &78, &00, &00, &38, &00, &84, &00, &30, &00, &7C, &00, &10
	DEFB &00, &78, &00, &00, &00, &38, &00, &00, &00, &30, &00, &00, &00, &10, &00, &00
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
	DEFB &00, &00, &00, &10, &00, &00, &00, &18, &00, &00, &00, &38, &00, &00, &00, &3C
	DEFB &00, &10, &00, &5C, &00, &18, &00, &7E, &00, &38, &00, &BE, &00, &3C, &00, &78
	DEFB &00, &5C, &86, &00, &00, &7E, &FA, &00, &00, &BE, &AA, &00, &00, &78, &AA, &00
	DEFB &86, &00, &AA, &00, &FA, &00, &B4, &00, &AA, &00, &B6, &00, &AA, &00, &AA, &00
	DEFB &AA, &00, &AA, &00, &B4, &00, &AA, &00, &B6, &00, &AA, &00, &AA, &00, &AA, &00
	DEFB &AA, &00, &54, &00, &AA, &00, &D6, &00, &AA, &00, &78, &00, &AA, &00, &00, &00
	DEFB &54, &00, &00, &00, &D6, &00, &00, &00, &78, &00, &00, &00, &00, &00, &00, &00
	;; displaying the images and masks as "wall1+wall2 mask1+mask2"
	;; so it is easier to see, we have the following results:
	;;
	;;	................ ...........@....
	;;	................ ...........@@...
	;;	................ ..........@@@...
	;;	................ ..........@@@@..
	;;	................ ...@.....@.@@@..
	;;	................ ...@@....@@@@@@.
	;;	................ ..@@@...@.@@@@@.
	;;	................ ..@@@@...@@@@...
	;;	........@.....@. .@.@@@..........
	;;	........@.@.@.@. .@@@@@@.........
	;;	........@.@.@.@. @.@@@@@.........
	;;	........@@.@@.@. .@@@@...........
	;;	@.....@.@.@.@@@. ................
	;;	@.@.@.@.@@@@@... ................
	;;	@.@.@.@.@....... .............@..
	;;	@@.@@.@......... .........@@@@@..
	;;	@.@.@@@......... .........@@@@...
	;;	.@@@@........... ..........@@@...
	;;	................ @....@....@@....
	;;	................ .@@@@@.....@....
	;;	................ .@@@@...........
	;;	................ ..@@@...........
	;;	................ ..@@............
	;;	................ ...@............
	;;	................ ................
	;;	................ ................
	;;	................ ................
	;;	................ ................
	;;	................ ...........@....
	;;	................ ...........@@...
	;;	................ ..........@@@...
	;;	................ ..........@@@@..
	;;	................ ...@.....@.@@@..
	;;	................ ...@@....@@@@@@.
	;;	................ ..@@@...@.@@@@@.
	;;	................ ..@@@@...@@@@...
	;;	........@....@@. .@.@@@..........
	;;	........@@@@@.@. .@@@@@@.........
	;;	........@.@.@.@. @.@@@@@.........
	;;	........@.@.@.@. .@@@@...........
	;;	@....@@.@.@.@.@. ................
	;;	@@@@@.@.@.@@.@.. ................
	;;	@.@.@.@.@.@@.@@. ................
	;;	@.@.@.@.@.@.@.@. ................
	;;	@.@.@.@.@.@.@.@. ................
	;;	@.@@.@..@.@.@.@. ................
	;;	@.@@.@@.@.@.@.@. ................
	;;	@.@.@.@.@.@.@.@. ................
	;;	@.@.@.@..@.@.@.. ................
	;;	@.@.@.@.@@.@.@@. ................
	;;	@.@.@.@..@@@@... ................
	;;	@.@.@.@......... ................
	;;	.@.@.@.......... ................
	;;	@@.@.@@......... ................
	;;	.@@@@........... ................
	;;	................ ................

img_prison_walls:
img_prison_wall_0:
	;; 4 bytes * 56 : interlaced : wall1 + maskwall1 + wall2 + maskwall2 (each are 1byte wide*56)
	;; wall1
	DEFB &01, &01, &83, &83, &01, &01, &0F, &4F, &00, &03, &3C, &BC, &00, &01, &30, &B3
	DEFB &02, &02, &40, &4C, &0F, &0F, &00, &31, &3C, &3C, &08, &C1, &F0, &F3, &10, &01
	DEFB &C0, &CC, &28, &81, &00, &31, &10, &81, &08, &C1, &28, &81, &10, &01, &10, &81
	DEFB &28, &81, &28, &81, &10, &81, &10, &81
	;; mask wall1
	DEFB &28, &81, &28, &81, &10, &81, &10, &81
	DEFB &28, &81, &28, &81, &10, &81, &10, &81, &28, &81, &28, &81, &10, &81, &10, &81
	DEFB &28, &81, &20, &81, &10, &81, &0C, &81, &28, &81, &3C, &81, &10, &81, &0E, &80
	DEFB &20, &81, &33, &B0, &0C, &81, &0C, &8C, &34, &81, &33, &83, &3E, &80, &7D, &01
	;; wall2
	DEFB &3F, &80, &FD, &01, &3F, &80, &F1, &01, &3F, &80, &CD, &01, &7F, &00, &3D, &01
	DEFB &EC, &00, &FD, &01, &F3, &00, &FD, &01, &4F, &00, &FD, &01, &3F, &00, &FD, &01
	DEFB &7F, &00, &F3, &03, &7F, &00, &CC, &0C, &7F, &00, &33, &30, &3C, &00, &CF, &C0
	DEFB &73, &03, &3F, &00, &4D, &0D, &7F, &00
	;; mask wall2
	DEFB &31, &31, &7F, &00, &CD, &C1, &6E, &00
	DEFB &3D, &01, &79, &01, &FD, &01, &67, &07, &FD, &01, &10, &10, &FC, &00, &70, &73
	DEFB &F9, &01, &00, &09, &E7, &07, &00, &3A, &90, &10, &00, &90, &70, &73, &00, &A0
	DEFB &00, &09, &00, &00, &00, &3A, &00, &00, &00, &90, &00, &00, &00, &A0, &00, &00
	;; displaying the images and masks as "wall1+wall2 mask1+mask2"
	;; so it is easier to see, we have the following results:
	;;
	;;	.......@@.....@@ .......@@.....@@
	;;	.......@....@@@@ .......@.@..@@@@
	;;	..........@@@@.. ......@@@.@@@@..
	;;	..........@@.... .......@@.@@..@@
	;;	......@..@...... ......@..@..@@..
	;;	....@@@@........ ....@@@@..@@...@
	;;	..@@@@......@... ..@@@@..@@.....@
	;;	@@@@.......@.... @@@@..@@.......@
	;;	@@........@.@... @@..@@..@......@
	;;	...........@.... ..@@...@@......@
	;;	....@.....@.@... @@.....@@......@
	;;	...@.......@.... .......@@......@
	;;	..@.@.....@.@... @......@@......@
	;;	...@.......@.... @......@@......@
	;;	..@.@.....@.@... @......@@......@
	;;	...@.......@.... @......@@......@
	;;	..@.@.....@.@... @......@@......@
	;;	...@.......@.... @......@@......@
	;;	..@.@.....@.@... @......@@......@
	;;	...@.......@.... @......@@......@
	;;	..@.@.....@..... @......@@......@
	;;	...@........@@.. @......@@......@
	;;	..@.@.....@@@@.. @......@@......@
	;;	...@........@@@. @......@@.......
	;;	..@.......@@..@@ @......@@.@@....
	;;	....@@......@@.. @......@@...@@..
	;;	..@@.@....@@..@@ @......@@.....@@
	;;	..@@@@@..@@@@@.@ @..............@
	;;	..@@@@@@@@@@@@.@ @..............@
	;;	..@@@@@@@@@@...@ @..............@
	;;	..@@@@@@@@..@@.@ @..............@
	;;	.@@@@@@@..@@@@.@ ...............@
	;;	@@@.@@..@@@@@@.@ ...............@
	;;	@@@@..@@@@@@@@.@ ...............@
	;;	.@..@@@@@@@@@@.@ ...............@
	;;	..@@@@@@@@@@@@.@ ...............@
	;;	.@@@@@@@@@@@..@@ ..............@@
	;;	.@@@@@@@@@..@@.. ............@@..
	;;	.@@@@@@@..@@..@@ ..........@@....
	;;	..@@@@..@@..@@@@ ........@@......
	;;	.@@@..@@..@@@@@@ ......@@........
	;;	.@..@@.@.@@@@@@@ ....@@.@........
	;;	..@@...@.@@@@@@@ ..@@...@........
	;;	@@..@@.@.@@.@@@. @@.....@........
	;;	..@@@@.@.@@@@..@ .......@.......@
	;;	@@@@@@.@.@@..@@@ .......@.....@@@
	;;	@@@@@@.@...@.... .......@...@....
	;;	@@@@@@...@@@.... .........@@@..@@
	;;	@@@@@..@........ .......@....@..@
	;;	@@@..@@@........ .....@@@..@@@.@.
	;;	@..@............ ...@....@..@....
	;;	.@@@............ .@@@..@@@.@.....
	;;	................ ....@..@........
	;;	................ ..@@@.@.........
	;;	................ @..@............
	;;	................ @.@.............

;; -----------------------------------------------------------------------------------------------------------
img_3x56_bin: 						;; Doorways (Blacktooth, Prison, BookWorld, Market)
img_doorway_L_type_0:				;; SPR_DOORL:      EQU &00
	DEFB &00, &00, &CC, &00, &03, &F3, &00, &0C, &CD, &00, &3F, &3D, &00, &4C, &DE, &00
	DEFB &F3, &D9, &01, &ED, &E6, &0D, &DD, &9C, &3A, &BE, &6F, &4B, &79, &8E, &31, &66
	DEFB &B8, &1C, &18, &E4, &7F, &7B, &9E, &3C, &1E, &3F, &0E, &39, &73, &03, &63, &7B
	DEFB &38, &14, &36, &1E, &F3, &8E, &2E, &E7, &DC, &72, &EC, &D8, &2C, &ED, &B0, &0A
	DEFB &CE, &60, &62, &D7, &E0, &78, &DB, &C0, &3E, &B3, &C0, &3F, &2F, &80, &4F, &1F
	DEFB &80, &73, &5F, &80, &2C, &53, &00, &0B, &6B, &00, &62, &7B, &00, &79, &7B, &00
	DEFB &3E, &7B, &00, &3F, &6B, &00, &4F, &53, &00, &73, &5F, &00, &2C, &5F, &00, &0B
	DEFB &67, &00, &62, &5F, &00, &79, &5F, &00, &3E, &53, &00, &3F, &6B, &00, &4F, &7B
	DEFB &00, &73, &7B, &00, &2C, &7B, &00, &0B, &6B, &00, &62, &53, &00, &79, &5F, &00
	DEFB &3E, &5F, &00, &3F, &67, &00, &4F, &7B, &00, &63, &7B, &00, &38, &74, &00, &0E
	DEFB &70, &00, &03, &40, &00, &00, &00, &00

	;;	................@@..@@..
	;;	..............@@@@@@..@@
	;;	............@@..@@..@@.@
	;;	..........@@@@@@..@@@@.@
	;;	.........@..@@..@@.@@@@.
	;;	........@@@@..@@@@.@@..@
	;;	.......@@@@.@@.@@@@..@@.
	;;	....@@.@@@.@@@.@@..@@@..
	;;	..@@@.@.@.@@@@@..@@.@@@@
	;;	.@..@.@@.@@@@..@@...@@@.
	;;	..@@...@.@@..@@.@.@@@...
	;;	...@@@.....@@...@@@..@..
	;;	.@@@@@@@.@@@@.@@@..@@@@.
	;;	..@@@@.....@@@@...@@@@@@
	;;	....@@@...@@@..@.@@@..@@
	;;	......@@.@@...@@.@@@@.@@
	;;	..@@@......@.@....@@.@@.
	;;	...@@@@.@@@@..@@@...@@@.
	;;	..@.@@@.@@@..@@@@@.@@@..
	;;	.@@@..@.@@@.@@..@@.@@...
	;;	..@.@@..@@@.@@.@@.@@....
	;;	....@.@.@@..@@@..@@.....
	;;	.@@...@.@@.@.@@@@@@.....
	;;	.@@@@...@@.@@.@@@@......
	;;	..@@@@@.@.@@..@@@@......
	;;	..@@@@@@..@.@@@@@.......
	;;	.@..@@@@...@@@@@@.......
	;;	.@@@..@@.@.@@@@@@.......
	;;	..@.@@...@.@..@@........
	;;	....@.@@.@@.@.@@........
	;;	.@@...@..@@@@.@@........
	;;	.@@@@..@.@@@@.@@........
	;;	..@@@@@..@@@@.@@........
	;;	..@@@@@@.@@.@.@@........
	;;	.@..@@@@.@.@..@@........
	;;	.@@@..@@.@.@@@@@........
	;;	..@.@@...@.@@@@@........
	;;	....@.@@.@@..@@@........
	;;	.@@...@..@.@@@@@........
	;;	.@@@@..@.@.@@@@@........
	;;	..@@@@@..@.@..@@........
	;;	..@@@@@@.@@.@.@@........
	;;	.@..@@@@.@@@@.@@........
	;;	.@@@..@@.@@@@.@@........
	;;	..@.@@...@@@@.@@........
	;;	....@.@@.@@.@.@@........
	;;	.@@...@..@.@..@@........
	;;	.@@@@..@.@.@@@@@........
	;;	..@@@@@..@.@@@@@........
	;;	..@@@@@@.@@..@@@........
	;;	.@..@@@@.@@@@.@@........
	;;	.@@...@@.@@@@.@@........
	;;	..@@@....@@@.@..........
	;;	....@@@..@@@............
	;;	......@@.@..............
	;;	........................

	DEFB &FF, &FC, &C0, &FF, &F3, &F3, &FF, &C0
	DEFB &C1, &FF, &80, &01, &FF, &40, &C0, &FC, &F3, &C1, &F1, &E1, &E6, &CD, &C1, &9C
	DEFB &B8, &80, &6F, &48, &01, &8E, &B0, &06, &B8, &9C, &18, &E4, &7F, &7B, &9E, &BC
	DEFB &1E, &3F, &CE, &38, &73, &C3, &60, &7B, &B8, &10, &36, &DE, &F3, &8E, &8E, &E7
	DEFB &DD, &02, &EC, &DB, &00, &ED, &B7, &80, &CE, &6F, &60, &C7, &EF, &78, &C3, &DF
	DEFB &BE, &83, &DF, &BF, &0F, &BF, &0F, &1F, &BF, &03, &1F, &BF, &00, &13, &7F, &80
	DEFB &03, &7F, &60, &03, &7F, &78, &03, &7F, &BE, &03, &7F, &BF, &03, &7F, &0F, &13
	DEFB &7F, &03, &1F, &7F, &00, &1F, &7F, &80, &07, &7F, &60, &1F, &7F, &78, &1F, &7F
	DEFB &BE, &13, &7F, &BF, &03, &7F, &0F, &03, &7F, &03, &03, &7F, &00, &03, &7F, &80
	DEFB &03, &7F, &60, &13, &7F, &78, &1F, &7F, &BE, &1F, &7F, &BF, &07, &7F, &0F, &03
	DEFB &7F, &03, &03, &7F, &80, &04, &FF, &C0, &03, &FF, &F0, &0F, &FF, &FC, &BF, &FF

	;;	@@@@@@@@@@@@@@..@@......
	;;	@@@@@@@@@@@@..@@@@@@..@@
	;;	@@@@@@@@@@......@@.....@
	;;	@@@@@@@@@..............@
	;;	@@@@@@@@.@......@@......
	;;	@@@@@@..@@@@..@@@@.....@
	;;	@@@@...@@@@....@@@@..@@.
	;;	@@..@@.@@@.....@@..@@@..
	;;	@.@@@...@........@@.@@@@
	;;	.@..@..........@@...@@@.
	;;	@.@@.........@@.@.@@@...
	;;	@..@@@.....@@...@@@..@..
	;;	.@@@@@@@.@@@@.@@@..@@@@.
	;;	@.@@@@.....@@@@...@@@@@@
	;;	@@..@@@...@@@....@@@..@@
	;;	@@....@@.@@......@@@@.@@
	;;	@.@@@......@......@@.@@.
	;;	@@.@@@@.@@@@..@@@...@@@.
	;;	@...@@@.@@@..@@@@@.@@@.@
	;;	......@.@@@.@@..@@.@@.@@
	;;	........@@@.@@.@@.@@.@@@
	;;	@.......@@..@@@..@@.@@@@
	;;	.@@.....@@...@@@@@@.@@@@
	;;	.@@@@...@@....@@@@.@@@@@
	;;	@.@@@@@.@.....@@@@.@@@@@
	;;	@.@@@@@@....@@@@@.@@@@@@
	;;	....@@@@...@@@@@@.@@@@@@
	;;	......@@...@@@@@@.@@@@@@
	;;	...........@..@@.@@@@@@@
	;;	@.............@@.@@@@@@@
	;;	.@@...........@@.@@@@@@@
	;;	.@@@@.........@@.@@@@@@@
	;;	@.@@@@@.......@@.@@@@@@@
	;;	@.@@@@@@......@@.@@@@@@@
	;;	....@@@@...@..@@.@@@@@@@
	;;	......@@...@@@@@.@@@@@@@
	;;	...........@@@@@.@@@@@@@
	;;	@............@@@.@@@@@@@
	;;	.@@........@@@@@.@@@@@@@
	;;	.@@@@......@@@@@.@@@@@@@
	;;	@.@@@@@....@..@@.@@@@@@@
	;;	@.@@@@@@......@@.@@@@@@@
	;;	....@@@@......@@.@@@@@@@
	;;	......@@......@@.@@@@@@@
	;;	..............@@.@@@@@@@
	;;	@.............@@.@@@@@@@
	;;	.@@........@..@@.@@@@@@@
	;;	.@@@@......@@@@@.@@@@@@@
	;;	@.@@@@@....@@@@@.@@@@@@@
	;;	@.@@@@@@.....@@@.@@@@@@@
	;;	....@@@@......@@.@@@@@@@
	;;	......@@......@@.@@@@@@@
	;;	@............@..@@@@@@@@
	;;	@@............@@@@@@@@@@
	;;	@@@@........@@@@@@@@@@@@
	;;	@@@@@@..@.@@@@@@@@@@@@@@

img_doorway_R_type_0: 		;; SPR_DOORR:      EQU &01
	DEFB &00, &00, &00, &00, &03, &C0, &00, &0C, &D0, &00, &3F, &38, &00, &CC, &DC, &03
	DEFB &F3, &D8, &0C, &CD, &E4, &33, &3D, &98, &7C, &DE, &70, &F3, &59, &BC, &CF, &66
	DEFB &38, &1F, &9A, &E4, &1E, &63, &9C, &19, &EE, &7C, &06, &39, &3C, &1C, &63, &DC
	DEFB &7F, &9D, &CC, &FE, &7E, &F4, &00, &E6, &10, &00, &DE, &EC, &00, &DD, &F4, &00
	DEFB &61, &B6, &00, &7D, &B6, &00, &1E, &76, &00, &27, &EE, &00, &09, &E6, &00, &62
	DEFB &FA, &00, &78, &FA, &00, &3E, &6A, &00, &3F, &66, &00, &4F, &6E, &00, &73, &66
	DEFB &00, &2C, &6A, &00, &0B, &6C, &00, &62, &7C, &00, &79, &7A, &00, &3E, &7C, &00
	DEFB &3F, &6C, &00, &4F, &6A, &00, &73, &66, &00, &2C, &6E, &00, &0B, &66, &00, &62
	DEFB &6A, &00, &79, &7A, &00, &3E, &7A, &00, &3F, &66, &00, &4F, &6E, &00, &63, &6E
	DEFB &00, &38, &6C, &00, &0E, &70, &00, &03, &40, &00, &00, &00, &00, &00, &00, &00
	DEFB &00, &00, &00, &00, &00, &00, &00, &00

	;;	........................
	;;	..............@@@@......
	;;	............@@..@@.@....
	;;	..........@@@@@@..@@@...
	;;	........@@..@@..@@.@@@..
	;;	......@@@@@@..@@@@.@@...
	;;	....@@..@@..@@.@@@@..@..
	;;	..@@..@@..@@@@.@@..@@...
	;;	.@@@@@..@@.@@@@..@@@....
	;;	@@@@..@@.@.@@..@@.@@@@..
	;;	@@..@@@@.@@..@@...@@@...
	;;	...@@@@@@..@@.@.@@@..@..
	;;	...@@@@..@@...@@@..@@@..
	;;	...@@..@@@@.@@@..@@@@@..
	;;	.....@@...@@@..@..@@@@..
	;;	...@@@...@@...@@@@.@@@..
	;;	.@@@@@@@@..@@@.@@@..@@..
	;;	@@@@@@@..@@@@@@.@@@@.@..
	;;	........@@@..@@....@....
	;;	........@@.@@@@.@@@.@@..
	;;	........@@.@@@.@@@@@.@..
	;;	.........@@....@@.@@.@@.
	;;	.........@@@@@.@@.@@.@@.
	;;	...........@@@@..@@@.@@.
	;;	..........@..@@@@@@.@@@.
	;;	............@..@@@@..@@.
	;;	.........@@...@.@@@@@.@.
	;;	.........@@@@...@@@@@.@.
	;;	..........@@@@@..@@.@.@.
	;;	..........@@@@@@.@@..@@.
	;;	.........@..@@@@.@@.@@@.
	;;	.........@@@..@@.@@..@@.
	;;	..........@.@@...@@.@.@.
	;;	............@.@@.@@.@@..
	;;	.........@@...@..@@@@@..
	;;	.........@@@@..@.@@@@.@.
	;;	..........@@@@@..@@@@@..
	;;	..........@@@@@@.@@.@@..
	;;	.........@..@@@@.@@.@.@.
	;;	.........@@@..@@.@@..@@.
	;;	..........@.@@...@@.@@@.
	;;	............@.@@.@@..@@.
	;;	.........@@...@..@@.@.@.
	;;	.........@@@@..@.@@@@.@.
	;;	..........@@@@@..@@@@.@.
	;;	..........@@@@@@.@@..@@.
	;;	.........@..@@@@.@@.@@@.
	;;	.........@@...@@.@@.@@@.
	;;	..........@@@....@@.@@..
	;;	............@@@..@@@....
	;;	..............@@.@......
	;;	........................
	;;	........................
	;;	........................
	;;	........................
	;;	........................

	DEFB &FF, &FC, &3F, &FF, &F0, &0F, &FF, &CC
	DEFB &17, &FF, &3F, &3B, &FC, &0C, &1D, &F0, &00, &19, &CC, &0C, &05, &03, &3C, &1B
	DEFB &70, &1E, &71, &F3, &19, &BD, &C1, &06, &39, &01, &1A, &E5, &00, &63, &9D, &01
	DEFB &EE, &7D, &06, &38, &3D, &1C, &60, &1D, &7F, &9C, &0D, &FE, &7E, &05, &00, &E6
	DEFB &01, &FE, &DE, &E1, &FE, &DD, &F1, &FF, &61, &B0, &FF, &7D, &B0, &FF, &1E, &70
	DEFB &FF, &87, &E0, &FF, &81, &E0, &FF, &60, &F8, &FF, &78, &F8, &FF, &BE, &68, &FF
	DEFB &BF, &60, &FF, &0F, &60, &FF, &03, &60, &FF, &80, &68, &FF, &80, &6C, &FF, &60
	DEFB &7C, &FF, &78, &78, &FF, &BE, &7C, &FF, &BF, &6C, &FF, &0F, &68, &FF, &03, &60
	DEFB &FF, &80, &60, &FF, &80, &60, &FF, &60, &68, &FF, &78, &78, &FF, &BE, &78, &FF
	DEFB &BF, &60, &FF, &0F, &60, &FF, &03, &60, &FF, &80, &61, &FF, &C0, &73, &FF, &F0
	DEFB &4F, &FF, &FC, &BF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF

	;;	@@@@@@@@@@@@@@....@@@@@@
	;;	@@@@@@@@@@@@........@@@@
	;;	@@@@@@@@@@..@@.....@.@@@
	;;	@@@@@@@@..@@@@@@..@@@.@@
	;;	@@@@@@......@@.....@@@.@
	;;	@@@@...............@@..@
	;;	@@..@@......@@.......@.@
	;;	......@@..@@@@.....@@.@@
	;;	.@@@.......@@@@..@@@...@
	;;	@@@@..@@...@@..@@.@@@@.@
	;;	@@.....@.....@@...@@@..@
	;;	.......@...@@.@.@@@..@.@
	;;	.........@@...@@@..@@@.@
	;;	.......@@@@.@@@..@@@@@.@
	;;	.....@@...@@@.....@@@@.@
	;;	...@@@...@@........@@@.@
	;;	.@@@@@@@@..@@@......@@.@
	;;	@@@@@@@..@@@@@@......@.@
	;;	........@@@..@@........@
	;;	@@@@@@@.@@.@@@@.@@@....@
	;;	@@@@@@@.@@.@@@.@@@@@...@
	;;	@@@@@@@@.@@....@@.@@....
	;;	@@@@@@@@.@@@@@.@@.@@....
	;;	@@@@@@@@...@@@@..@@@....
	;;	@@@@@@@@@....@@@@@@.....
	;;	@@@@@@@@@......@@@@.....
	;;	@@@@@@@@.@@.....@@@@@...
	;;	@@@@@@@@.@@@@...@@@@@...
	;;	@@@@@@@@@.@@@@@..@@.@...
	;;	@@@@@@@@@.@@@@@@.@@.....
	;;	@@@@@@@@....@@@@.@@.....
	;;	@@@@@@@@......@@.@@.....
	;;	@@@@@@@@@........@@.@...
	;;	@@@@@@@@@........@@.@@..
	;;	@@@@@@@@.@@......@@@@@..
	;;	@@@@@@@@.@@@@....@@@@...
	;;	@@@@@@@@@.@@@@@..@@@@@..
	;;	@@@@@@@@@.@@@@@@.@@.@@..
	;;	@@@@@@@@....@@@@.@@.@...
	;;	@@@@@@@@......@@.@@.....
	;;	@@@@@@@@@........@@.....
	;;	@@@@@@@@@........@@.....
	;;	@@@@@@@@.@@......@@.@...
	;;	@@@@@@@@.@@@@....@@@@...
	;;	@@@@@@@@@.@@@@@..@@@@...
	;;	@@@@@@@@@.@@@@@@.@@.....
	;;	@@@@@@@@....@@@@.@@.....
	;;	@@@@@@@@......@@.@@.....
	;;	@@@@@@@@@........@@....@
	;;	@@@@@@@@@@.......@@@..@@
	;;	@@@@@@@@@@@@.....@..@@@@
	;;	@@@@@@@@@@@@@@..@.@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@

img_doorway_L_type_1:				;; Doorways (Moon base)
	DEFB &00, &00, &0E, &00, &00, &38, &00, &00, &E2, &00, &03, &9B, &00, &0E, &3B, &00
	DEFB &39, &BB, &00, &F3, &BB, &03, &6B, &B8, &0C, &5B, &B3, &11, &5B, &8C, &27, &5B
	DEFB &33, &2F, &58, &CA, &73, &53, &38, &4C, &4C, &D0, &43, &73, &E0, &44, &CC, &C0
	DEFB &46, &BF, &00, &4A, &8F, &00, &4C, &B2, &00, &4E, &BC, &00, &52, &8D, &00, &4C
	DEFB &B0, &C0, &52, &87, &20, &4C, &B8, &E0, &52, &87, &C0, &5C, &BF, &80, &5E, &BF
	DEFB &00, &5E, &BE, &00, &5E, &BC, &00, &5E, &B8, &00, &5E, &B3, &00, &5E, &A8, &C0
	DEFB &5E, &87, &20, &4E, &B8, &E0, &50, &87, &C0, &5C, &BF, &80, &5E, &BF, &00, &5E
	DEFB &BE, &00, &5E, &BC, &00, &5E, &B8, &00, &5E, &B3, &00, &5E, &A8, &C0, &5E, &87
	DEFB &20, &4E, &B8, &E0, &50, &87, &C0, &5C, &BF, &80, &5E, &BF, &00, &5E, &BE, &00
	DEFB &5E, &BC, &00, &5E, &B8, &00, &5E, &B4, &00, &4E, &A6, &00, &32, &8C, &00, &0C
	DEFB &B0, &00, &03, &C0, &00, &00, &00, &00

	;;	....................@@@.
	;;	..................@@@...
	;;	................@@@...@.
	;;	..............@@@..@@.@@
	;;	............@@@...@@@.@@
	;;	..........@@@..@@.@@@.@@
	;;	........@@@@..@@@.@@@.@@
	;;	......@@.@@.@.@@@.@@@...
	;;	....@@...@.@@.@@@.@@..@@
	;;	...@...@.@.@@.@@@...@@..
	;;	..@..@@@.@.@@.@@..@@..@@
	;;	..@.@@@@.@.@@...@@..@.@.
	;;	.@@@..@@.@.@..@@..@@@...
	;;	.@..@@...@..@@..@@.@....
	;;	.@....@@.@@@..@@@@@.....
	;;	.@...@..@@..@@..@@......
	;;	.@...@@.@.@@@@@@........
	;;	.@..@.@.@...@@@@........
	;;	.@..@@..@.@@..@.........
	;;	.@..@@@.@.@@@@..........
	;;	.@.@..@.@...@@.@........
	;;	.@..@@..@.@@....@@......
	;;	.@.@..@.@....@@@..@.....
	;;	.@..@@..@.@@@...@@@.....
	;;	.@.@..@.@....@@@@@......
	;;	.@.@@@..@.@@@@@@@.......
	;;	.@.@@@@.@.@@@@@@........
	;;	.@.@@@@.@.@@@@@.........
	;;	.@.@@@@.@.@@@@..........
	;;	.@.@@@@.@.@@@...........
	;;	.@.@@@@.@.@@..@@........
	;;	.@.@@@@.@.@.@...@@......
	;;	.@.@@@@.@....@@@..@.....
	;;	.@..@@@.@.@@@...@@@.....
	;;	.@.@....@....@@@@@......
	;;	.@.@@@..@.@@@@@@@.......
	;;	.@.@@@@.@.@@@@@@........
	;;	.@.@@@@.@.@@@@@.........
	;;	.@.@@@@.@.@@@@..........
	;;	.@.@@@@.@.@@@...........
	;;	.@.@@@@.@.@@..@@........
	;;	.@.@@@@.@.@.@...@@......
	;;	.@.@@@@.@....@@@..@.....
	;;	.@..@@@.@.@@@...@@@.....
	;;	.@.@....@....@@@@@......
	;;	.@.@@@..@.@@@@@@@.......
	;;	.@.@@@@.@.@@@@@@........
	;;	.@.@@@@.@.@@@@@.........
	;;	.@.@@@@.@.@@@@..........
	;;	.@.@@@@.@.@@@...........
	;;	.@.@@@@.@.@@.@..........
	;;	.@..@@@.@.@..@@.........
	;;	..@@..@.@...@@..........
	;;	....@@..@.@@............
	;;	......@@@@..............
	;;	........................

	DEFB &FF, &FF, &CE, &FF, &FF, &38, &FF, &FC
	DEFB &E0, &FF, &F3, &98, &FF, &CE, &38, &FF, &38, &38, &FC, &F0, &38, &F3, &68, &38
	DEFB &EC, &58, &33, &D0, &58, &0C, &A0, &58, &30, &A0, &58, &C0, &70, &53, &01, &4C
	DEFB &4C, &07, &53, &70, &0F, &50, &C0, &1F, &50, &80, &3F, &40, &80, &7F, &40, &80
	DEFB &FF, &40, &80, &FF, &40, &81, &3F, &40, &80, &DF, &50, &87, &2F, &4C, &B8, &EF
	DEFB &52, &87, &DF, &5C, &BF, &BF, &5E, &BF, &7F, &5E, &BE, &FF, &5E, &BD, &FF, &5E
	DEFB &B8, &FF, &5E, &B3, &3F, &5E, &A0, &DF, &5E, &87, &2F, &4E, &B8, &EF, &50, &87
	DEFB &DF, &5C, &BF, &BF, &5E, &BF, &7F, &5E, &BE, &FF, &5E, &BD, &FF, &5E, &B8, &FF
	DEFB &5E, &B3, &3F, &5E, &A0, &DF, &5E, &87, &2F, &4E, &B8, &EF, &50, &87, &DF, &5C
	DEFB &BF, &BF, &5E, &BF, &7F, &5E, &BE, &FF, &5E, &BD, &FF, &5E, &BB, &FF, &5E, &B5
	DEFB &FF, &4E, &A6, &FF, &B2, &8D, &FF, &CC, &B3, &FF, &F3, &CF, &FF, &FC, &3F, &FF

	;;	@@@@@@@@@@@@@@@@@@..@@@.
	;;	@@@@@@@@@@@@@@@@..@@@...
	;;	@@@@@@@@@@@@@@..@@@.....
	;;	@@@@@@@@@@@@..@@@..@@...
	;;	@@@@@@@@@@..@@@...@@@...
	;;	@@@@@@@@..@@@.....@@@...
	;;	@@@@@@..@@@@......@@@...
	;;	@@@@..@@.@@.@.....@@@...
	;;	@@@.@@...@.@@.....@@..@@
	;;	@@.@.....@.@@.......@@..
	;;	@.@......@.@@.....@@....
	;;	@.@......@.@@...@@......
	;;	.@@@.....@.@..@@.......@
	;;	.@..@@...@..@@.......@@@
	;;	.@.@..@@.@@@........@@@@
	;;	.@.@....@@.........@@@@@
	;;	.@.@....@.........@@@@@@
	;;	.@......@........@@@@@@@
	;;	.@......@.......@@@@@@@@
	;;	.@......@.......@@@@@@@@
	;;	.@......@......@..@@@@@@
	;;	.@......@.......@@.@@@@@
	;;	.@.@....@....@@@..@.@@@@
	;;	.@..@@..@.@@@...@@@.@@@@
	;;	.@.@..@.@....@@@@@.@@@@@
	;;	.@.@@@..@.@@@@@@@.@@@@@@
	;;	.@.@@@@.@.@@@@@@.@@@@@@@
	;;	.@.@@@@.@.@@@@@.@@@@@@@@
	;;	.@.@@@@.@.@@@@.@@@@@@@@@
	;;	.@.@@@@.@.@@@...@@@@@@@@
	;;	.@.@@@@.@.@@..@@..@@@@@@
	;;	.@.@@@@.@.@.....@@.@@@@@
	;;	.@.@@@@.@....@@@..@.@@@@
	;;	.@..@@@.@.@@@...@@@.@@@@
	;;	.@.@....@....@@@@@.@@@@@
	;;	.@.@@@..@.@@@@@@@.@@@@@@
	;;	.@.@@@@.@.@@@@@@.@@@@@@@
	;;	.@.@@@@.@.@@@@@.@@@@@@@@
	;;	.@.@@@@.@.@@@@.@@@@@@@@@
	;;	.@.@@@@.@.@@@...@@@@@@@@
	;;	.@.@@@@.@.@@..@@..@@@@@@
	;;	.@.@@@@.@.@.....@@.@@@@@
	;;	.@.@@@@.@....@@@..@.@@@@
	;;	.@..@@@.@.@@@...@@@.@@@@
	;;	.@.@....@....@@@@@.@@@@@
	;;	.@.@@@..@.@@@@@@@.@@@@@@
	;;	.@.@@@@.@.@@@@@@.@@@@@@@
	;;	.@.@@@@.@.@@@@@.@@@@@@@@
	;;	.@.@@@@.@.@@@@.@@@@@@@@@
	;;	.@.@@@@.@.@@@.@@@@@@@@@@
	;;	.@.@@@@.@.@@.@.@@@@@@@@@
	;;	.@..@@@.@.@..@@.@@@@@@@@
	;;	@.@@..@.@...@@.@@@@@@@@@
	;;	@@..@@..@.@@..@@@@@@@@@@
	;;	@@@@..@@@@..@@@@@@@@@@@@
	;;	@@@@@@....@@@@@@@@@@@@@@

img_doorway_R_type_1:
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &03, &C0, &00, &0E, &30, &00
	DEFB &38, &C8, &00, &E6, &74, &03, &8F, &3A, &0E, &67, &92, &38, &F3, &CE, &66, &79
	DEFB &32, &1F, &3C, &C2, &0F, &93, &02, &07, &CC, &62, &13, &33, &72, &18, &C6, &EA
	DEFB &67, &2E, &DA, &FC, &6D, &DA, &00, &5D, &B2, &00, &03, &4A, &00, &28, &32, &00
	DEFB &5C, &CA, &00, &B3, &3A, &00, &CC, &FA, &00, &33, &FA, &00, &0F, &FA, &00, &03
	DEFB &FA, &00, &04, &FA, &00, &08, &32, &00, &14, &8A, &00, &2D, &32, &00, &5C, &CA
	DEFB &00, &B3, &3A, &00, &CC, &FA, &00, &33, &FA, &00, &0F, &FA, &00, &03, &FA, &00
	DEFB &04, &FA, &00, &08, &32, &00, &14, &8A, &00, &2D, &32, &00, &5C, &CA, &00, &B3
	DEFB &3A, &00, &CC, &FA, &00, &33, &FA, &00, &0F, &FA, &00, &03, &FA, &00, &08, &F2
	DEFB &00, &18, &0C, &00, &06, &B0, &00, &01, &C0, &00, &00, &00, &00, &00, &00, &00
	DEFB &00, &00, &00, &00, &00, &00, &00, &00

	;;	........................
	;;	........................
	;;	........................
	;;	..............@@@@......
	;;	............@@@...@@....
	;;	..........@@@...@@..@...
	;;	........@@@..@@..@@@.@..
	;;	......@@@...@@@@..@@@.@.
	;;	....@@@..@@..@@@@..@..@.
	;;	..@@@...@@@@..@@@@..@@@.
	;;	.@@..@@..@@@@..@..@@..@.
	;;	...@@@@@..@@@@..@@....@.
	;;	....@@@@@..@..@@......@.
	;;	.....@@@@@..@@...@@...@.
	;;	...@..@@..@@..@@.@@@..@.
	;;	...@@...@@...@@.@@@.@.@.
	;;	.@@..@@@..@.@@@.@@.@@.@.
	;;	@@@@@@...@@.@@.@@@.@@.@.
	;;	.........@.@@@.@@.@@..@.
	;;	..............@@.@..@.@.
	;;	..........@.@.....@@..@.
	;;	.........@.@@@..@@..@.@.
	;;	........@.@@..@@..@@@.@.
	;;	........@@..@@..@@@@@.@.
	;;	..........@@..@@@@@@@.@.
	;;	............@@@@@@@@@.@.
	;;	..............@@@@@@@.@.
	;;	.............@..@@@@@.@.
	;;	............@.....@@..@.
	;;	...........@.@..@...@.@.
	;;	..........@.@@.@..@@..@.
	;;	.........@.@@@..@@..@.@.
	;;	........@.@@..@@..@@@.@.
	;;	........@@..@@..@@@@@.@.
	;;	..........@@..@@@@@@@.@.
	;;	............@@@@@@@@@.@.
	;;	..............@@@@@@@.@.
	;;	.............@..@@@@@.@.
	;;	............@.....@@..@.
	;;	...........@.@..@...@.@.
	;;	..........@.@@.@..@@..@.
	;;	.........@.@@@..@@..@.@.
	;;	........@.@@..@@..@@@.@.
	;;	........@@..@@..@@@@@.@.
	;;	..........@@..@@@@@@@.@.
	;;	............@@@@@@@@@.@.
	;;	..............@@@@@@@.@.
	;;	............@...@@@@..@.
	;;	...........@@.......@@..
	;;	.............@@.@.@@....
	;;	...............@@@......
	;;	........................
	;;	........................
	;;	........................
	;;	........................
	;;	........................

	DEFB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FC
	DEFB &3F, &FF, &F3, &CF, &FF, &CE, &37, &FF, &38, &CB, &FC, &E0, &75, &F3, &80, &3A
	DEFB &CE, &60, &12, &38, &F0, &0E, &60, &78, &32, &00, &3C, &CA, &00, &13, &1A, &00
	DEFB &0C, &0A, &10, &30, &02, &18, &C0, &02, &67, &00, &02, &FC, &00, &02, &00, &00
	DEFB &02, &FF, &80, &0A, &FF, &A8, &32, &FF, &5C, &CA, &FE, &B3, &3A, &FE, &CC, &FA
	DEFB &FF, &33, &FA, &FF, &CF, &FA, &FF, &F3, &FA, &FF, &F4, &FA, &FF, &E8, &32, &FF
	DEFB &D4, &0A, &FF, &AC, &32, &FF, &5C, &CA, &FE, &B3, &3A, &FE, &CC, &FA, &FF, &33
	DEFB &FA, &FF, &CF, &FA, &FF, &F3, &FA, &FF, &F4, &FA, &FF, &E8, &32, &FF, &D4, &0A
	DEFB &FF, &AC, &32, &FF, &5C, &CA, &FE, &B3, &3A, &FE, &CC, &FA, &FF, &33, &FA, &FF
	DEFB &CF, &FA, &FF, &F3, &FA, &FF, &E8, &F2, &FF, &D8, &0D, &FF, &E6, &B3, &FF, &F9
	DEFB &CF, &FF, &FE, &3F, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF

	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@....@@@@@@
	;;	@@@@@@@@@@@@..@@@@..@@@@
	;;	@@@@@@@@@@..@@@...@@.@@@
	;;	@@@@@@@@..@@@...@@..@.@@
	;;	@@@@@@..@@@......@@@.@.@
	;;	@@@@..@@@.........@@@.@.
	;;	@@..@@@..@@........@..@.
	;;	..@@@...@@@@........@@@.
	;;	.@@......@@@@.....@@..@.
	;;	..........@@@@..@@..@.@.
	;;	...........@..@@...@@.@.
	;;	............@@......@.@.
	;;	...@......@@..........@.
	;;	...@@...@@............@.
	;;	.@@..@@@..............@.
	;;	@@@@@@................@.
	;;	......................@.
	;;	@@@@@@@@@...........@.@.
	;;	@@@@@@@@@.@.@.....@@..@.
	;;	@@@@@@@@.@.@@@..@@..@.@.
	;;	@@@@@@@.@.@@..@@..@@@.@.
	;;	@@@@@@@.@@..@@..@@@@@.@.
	;;	@@@@@@@@..@@..@@@@@@@.@.
	;;	@@@@@@@@@@..@@@@@@@@@.@.
	;;	@@@@@@@@@@@@..@@@@@@@.@.
	;;	@@@@@@@@@@@@.@..@@@@@.@.
	;;	@@@@@@@@@@@.@.....@@..@.
	;;	@@@@@@@@@@.@.@......@.@.
	;;	@@@@@@@@@.@.@@....@@..@.
	;;	@@@@@@@@.@.@@@..@@..@.@.
	;;	@@@@@@@.@.@@..@@..@@@.@.
	;;	@@@@@@@.@@..@@..@@@@@.@.
	;;	@@@@@@@@..@@..@@@@@@@.@.
	;;	@@@@@@@@@@..@@@@@@@@@.@.
	;;	@@@@@@@@@@@@..@@@@@@@.@.
	;;	@@@@@@@@@@@@.@..@@@@@.@.
	;;	@@@@@@@@@@@.@.....@@..@.
	;;	@@@@@@@@@@.@.@......@.@.
	;;	@@@@@@@@@.@.@@....@@..@.
	;;	@@@@@@@@.@.@@@..@@..@.@.
	;;	@@@@@@@.@.@@..@@..@@@.@.
	;;	@@@@@@@.@@..@@..@@@@@.@.
	;;	@@@@@@@@..@@..@@@@@@@.@.
	;;	@@@@@@@@@@..@@@@@@@@@.@.
	;;	@@@@@@@@@@@@..@@@@@@@.@.
	;;	@@@@@@@@@@@.@...@@@@..@.
	;;	@@@@@@@@@@.@@.......@@.@
	;;	@@@@@@@@@@@..@@.@.@@..@@
	;;	@@@@@@@@@@@@@..@@@..@@@@
	;;	@@@@@@@@@@@@@@@...@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@

img_doorway_L_type_2:				;; Doorways (Safari + Penitentiary + Egyptus)
	DEFB &00, &00, &FC, &00, &01, &FA, &00, &0B, &F6, &00, &1B, &E3, &00, &2B, &EC, &00
	DEFB &ED, &E8, &03, &96, &E6, &0E, &7B, &75, &19, &E5, &B9, &27, &9E, &1E, &1E, &79
	DEFB &E1, &39, &E7, &1F, &67, &DE, &FE, &1F, &BD, &C5, &3C, &3B, &BB, &03, &7B, &7D
	DEFB &3E, &7B, &7D, &6D, &7B, &BE, &56, &BD, &DE, &6F, &B6, &2E, &3C, &1F, &F6, &03
	DEFB &CF, &F2, &3E, &E3, &C0, &6D, &78, &00, &56, &E5, &00, &6F, &9A, &00, &3C, &6D
	DEFB &00, &03, &D6, &00, &3E, &80, &00, &6D, &7A, &00, &56, &FD, &00, &6F, &7E, &00
	DEFB &3C, &FF, &F8, &03, &7D, &F0, &3E, &9F, &F8, &6D, &63, &E8, &56, &E5, &F0, &6F
	DEFB &9A, &B0, &3C, &6D, &20, &03, &D6, &00, &3E, &EC, &00, &6D, &7A, &00, &56, &E5
	DEFB &00, &6F, &9A, &00, &38, &6D, &00, &07, &D6, &00, &3E, &EC, &00, &6D, &7A, &00
	DEFB &56, &E5, &00, &6F, &9A, &00, &38, &6D, &00, &06, &D6, &00, &3D, &6C, &00, &0E
	DEFB &F0, &00, &01, &80, &00, &00, &00, &00

	;;	................@@@@@@..
	;;	...............@@@@@@.@.
	;;	............@.@@@@@@.@@.
	;;	...........@@.@@@@@...@@
	;;	..........@.@.@@@@@.@@..
	;;	........@@@.@@.@@@@.@...
	;;	......@@@..@.@@.@@@..@@.
	;;	....@@@..@@@@.@@.@@@.@.@
	;;	...@@..@@@@..@.@@.@@@..@
	;;	..@..@@@@..@@@@....@@@@.
	;;	...@@@@..@@@@..@@@@....@
	;;	..@@@..@@@@..@@@...@@@@@
	;;	.@@..@@@@@.@@@@.@@@@@@@.
	;;	...@@@@@@.@@@@.@@@...@.@
	;;	..@@@@....@@@.@@@.@@@.@@
	;;	......@@.@@@@.@@.@@@@@.@
	;;	..@@@@@..@@@@.@@.@@@@@.@
	;;	.@@.@@.@.@@@@.@@@.@@@@@.
	;;	.@.@.@@.@.@@@@.@@@.@@@@.
	;;	.@@.@@@@@.@@.@@...@.@@@.
	;;	..@@@@.....@@@@@@@@@.@@.
	;;	......@@@@..@@@@@@@@..@.
	;;	..@@@@@.@@@...@@@@......
	;;	.@@.@@.@.@@@@...........
	;;	.@.@.@@.@@@..@.@........
	;;	.@@.@@@@@..@@.@.........
	;;	..@@@@...@@.@@.@........
	;;	......@@@@.@.@@.........
	;;	..@@@@@.@...............
	;;	.@@.@@.@.@@@@.@.........
	;;	.@.@.@@.@@@@@@.@........
	;;	.@@.@@@@.@@@@@@.........
	;;	..@@@@..@@@@@@@@@@@@@...
	;;	......@@.@@@@@.@@@@@....
	;;	..@@@@@.@..@@@@@@@@@@...
	;;	.@@.@@.@.@@...@@@@@.@...
	;;	.@.@.@@.@@@..@.@@@@@....
	;;	.@@.@@@@@..@@.@.@.@@....
	;;	..@@@@...@@.@@.@..@.....
	;;	......@@@@.@.@@.........
	;;	..@@@@@.@@@.@@..........
	;;	.@@.@@.@.@@@@.@.........
	;;	.@.@.@@.@@@..@.@........
	;;	.@@.@@@@@..@@.@.........
	;;	..@@@....@@.@@.@........
	;;	.....@@@@@.@.@@.........
	;;	..@@@@@.@@@.@@..........
	;;	.@@.@@.@.@@@@.@.........
	;;	.@.@.@@.@@@..@.@........
	;;	.@@.@@@@@..@@.@.........
	;;	..@@@....@@.@@.@........
	;;	.....@@.@@.@.@@.........
	;;	..@@@@.@.@@.@@..........
	;;	....@@@.@@@@............
	;;	.......@@...............
	;;	........................

	DEFB &FF, &FE, &FC, &FF, &F1, &F8, &FF, &E3
	DEFB &F0, &FF, &C3, &E3, &FF, &03, &E0, &FC, &01, &E0, &F0, &10, &E0, &E0, &78, &70
	DEFB &C1, &E0, &38, &87, &80, &1E, &DE, &01, &E0, &B8, &07, &00, &60, &1E, &00, &80
	DEFB &3C, &01, &80, &38, &3B, &C0, &78, &7D, &80, &78, &7D, &01, &78, &3E, &10, &3C
	DEFB &1E, &00, &36, &2E, &80, &1F, &F6, &C0, &0F, &F2, &80, &03, &CD, &01, &00, &3F
	DEFB &10, &00, &7F, &00, &02, &7F, &80, &00, &7F, &C0, &10, &FF, &80, &01, &FF, &01
	DEFB &78, &FF, &10, &FC, &7F, &00, &7E, &07, &80, &FF, &FB, &C0, &7D, &F7, &80, &1F
	DEFB &FB, &01, &03, &EB, &10, &01, &F7, &00, &02, &B7, &80, &00, &2F, &C0, &10, &DF
	DEFB &80, &01, &FF, &01, &00, &FF, &10, &00, &7F, &00, &02, &7F, &80, &00, &7F, &C0
	DEFB &10, &FF, &80, &01, &FF, &01, &00, &FF, &10, &00, &7F, &00, &02, &7F, &80, &00
	DEFB &7F, &C0, &10, &FF, &81, &01, &FF, &C0, &03, &FF, &F0, &0F, &FF, &FE, &7F, &FF

	;;	@@@@@@@@@@@@@@@.@@@@@@..
	;;	@@@@@@@@@@@@...@@@@@@...
	;;	@@@@@@@@@@@...@@@@@@....
	;;	@@@@@@@@@@....@@@@@...@@
	;;	@@@@@@@@......@@@@@.....
	;;	@@@@@@.........@@@@.....
	;;	@@@@.......@....@@@.....
	;;	@@@......@@@@....@@@....
	;;	@@.....@@@@.......@@@...
	;;	@....@@@@..........@@@@.
	;;	@@.@@@@........@@@@.....
	;;	@.@@@........@@@........
	;;	.@@........@@@@.........
	;;	@.........@@@@.........@
	;;	@.........@@@.....@@@.@@
	;;	@@.......@@@@....@@@@@.@
	;;	@........@@@@....@@@@@.@
	;;	.......@.@@@@.....@@@@@.
	;;	...@......@@@@.....@@@@.
	;;	..........@@.@@...@.@@@.
	;;	@..........@@@@@@@@@.@@.
	;;	@@..........@@@@@@@@..@.
	;;	@.............@@@@..@@.@
	;;	.......@..........@@@@@@
	;;	...@.............@@@@@@@
	;;	..............@..@@@@@@@
	;;	@................@@@@@@@
	;;	@@.........@....@@@@@@@@
	;;	@..............@@@@@@@@@
	;;	.......@.@@@@...@@@@@@@@
	;;	...@....@@@@@@...@@@@@@@
	;;	.........@@@@@@......@@@
	;;	@.......@@@@@@@@@@@@@.@@
	;;	@@.......@@@@@.@@@@@.@@@
	;;	@..........@@@@@@@@@@.@@
	;;	.......@......@@@@@.@.@@
	;;	...@...........@@@@@.@@@
	;;	..............@.@.@@.@@@
	;;	@.................@.@@@@
	;;	@@.........@....@@.@@@@@
	;;	@..............@@@@@@@@@
	;;	.......@........@@@@@@@@
	;;	...@.............@@@@@@@
	;;	..............@..@@@@@@@
	;;	@................@@@@@@@
	;;	@@.........@....@@@@@@@@
	;;	@..............@@@@@@@@@
	;;	.......@........@@@@@@@@
	;;	...@.............@@@@@@@
	;;	..............@..@@@@@@@
	;;	@................@@@@@@@
	;;	@@.........@....@@@@@@@@
	;;	@......@.......@@@@@@@@@
	;;	@@............@@@@@@@@@@
	;;	@@@@........@@@@@@@@@@@@
	;;	@@@@@@@..@@@@@@@@@@@@@@@

img_doorway_R_type_2:
	DEFB &00, &00, &00, &00, &01, &CE, &00, &0F, &3C, &00, &3C, &F0, &00, &CB, &CE, &07
	DEFB &37, &3C, &1F, &D8, &F8, &7F, &ED, &E4, &3C, &35, &86, &00, &DA, &7A, &00, &AA
	DEFB &FC, &00, &6D, &1C, &00, &14, &EE, &00, &35, &F6, &00, &53, &36, &00, &6E, &D6
	DEFB &00, &9D, &EE, &00, &73, &EC, &00, &ED, &F4, &00, &DE, &F0, &00, &3E, &74, &00
	DEFB &DF, &32, &00, &CF, &54, &00, &E3, &4A, &00, &ED, &2C, &00, &6C, &D0, &00, &AA
	DEFB &EC, &00, &8D, &DA, &00, &DF, &1E, &00, &70, &DE, &00, &0F, &BE, &00, &7C, &7E
	DEFB &00, &D9, &EC, &00, &A7, &FC, &00, &D5, &F8, &00, &73, &FA, &00, &06, &78, &00
	DEFB &79, &90, &00, &DA, &64, &00, &AD, &8A, &00, &DF, &34, &00, &70, &DA, &00, &0F
	DEFB &AC, &00, &7D, &D8, &00, &DA, &F4, &00, &AD, &CA, &00, &DF, &34, &00, &70, &DA
	DEFB &00, &0D, &AC, &00, &7A, &D8, &00, &1D, &E0, &00, &03, &00, &00, &00, &00, &00
	DEFB &00, &00, &00, &00, &00, &00, &00, &00

	;;	........................
	;;	...............@@@..@@@.
	;;	............@@@@..@@@@..
	;;	..........@@@@..@@@@....
	;;	........@@..@.@@@@..@@@.
	;;	.....@@@..@@.@@@..@@@@..
	;;	...@@@@@@@.@@...@@@@@...
	;;	.@@@@@@@@@@.@@.@@@@..@..
	;;	..@@@@....@@.@.@@....@@.
	;;	........@@.@@.@..@@@@.@.
	;;	........@.@.@.@.@@@@@@..
	;;	.........@@.@@.@...@@@..
	;;	...........@.@..@@@.@@@.
	;;	..........@@.@.@@@@@.@@.
	;;	.........@.@..@@..@@.@@.
	;;	.........@@.@@@.@@.@.@@.
	;;	........@..@@@.@@@@.@@@.
	;;	.........@@@..@@@@@.@@..
	;;	........@@@.@@.@@@@@.@..
	;;	........@@.@@@@.@@@@....
	;;	..........@@@@@..@@@.@..
	;;	........@@.@@@@@..@@..@.
	;;	........@@..@@@@.@.@.@..
	;;	........@@@...@@.@..@.@.
	;;	........@@@.@@.@..@.@@..
	;;	.........@@.@@..@@.@....
	;;	........@.@.@.@.@@@.@@..
	;;	........@...@@.@@@.@@.@.
	;;	........@@.@@@@@...@@@@.
	;;	.........@@@....@@.@@@@.
	;;	............@@@@@.@@@@@.
	;;	.........@@@@@...@@@@@@.
	;;	........@@.@@..@@@@.@@..
	;;	........@.@..@@@@@@@@@..
	;;	........@@.@.@.@@@@@@...
	;;	.........@@@..@@@@@@@.@.
	;;	.............@@..@@@@...
	;;	.........@@@@..@@..@....
	;;	........@@.@@.@..@@..@..
	;;	........@.@.@@.@@...@.@.
	;;	........@@.@@@@@..@@.@..
	;;	.........@@@....@@.@@.@.
	;;	............@@@@@.@.@@..
	;;	.........@@@@@.@@@.@@...
	;;	........@@.@@.@.@@@@.@..
	;;	........@.@.@@.@@@..@.@.
	;;	........@@.@@@@@..@@.@..
	;;	.........@@@....@@.@@.@.
	;;	............@@.@@.@.@@..
	;;	.........@@@@.@.@@.@@...
	;;	...........@@@.@@@@.....
	;;	..............@@........
	;;	........................
	;;	........................
	;;	........................
	;;	........................

	DEFB &FF, &FE, &31, &FF, &F0, &0E, &FF, &C0
	DEFB &3C, &FF, &00, &F1, &F8, &03, &C0, &E7, &07, &01, &9F, &C0, &03, &7F, &E0, &01
	DEFB &3C, &30, &00, &00, &18, &78, &00, &08, &FD, &00, &0C, &1D, &00, &04, &0E, &00
	DEFB &04, &06, &00, &00, &06, &00, &00, &C6, &00, &01, &EE, &00, &03, &ED, &00, &0D
	DEFB &F5, &00, &1E, &F3, &00, &3E, &71, &00, &DF, &30, &FE, &CF, &14, &FE, &E3, &00
	DEFB &FE, &E1, &21, &FF, &60, &01, &FE, &22, &0D, &FE, &00, &1A, &FE, &00, &1E, &FF
	DEFB &00, &1E, &FF, &80, &3E, &FF, &00, &7E, &FE, &01, &ED, &FE, &27, &FC, &FE, &05
	DEFB &F8, &FF, &03, &F8, &FF, &86, &79, &FF, &01, &93, &FE, &02, &61, &FE, &20, &00
	DEFB &FE, &00, &04, &FF, &00, &00, &FF, &80, &21, &FF, &00, &03, &FE, &02, &01, &FE
	DEFB &20, &00, &FE, &00, &04, &FF, &00, &00, &FF, &80, &21, &FF, &02, &03, &FF, &80
	DEFB &07, &FF, &E0, &1F, &FF, &FC, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF

	;;	@@@@@@@@@@@@@@@...@@...@
	;;	@@@@@@@@@@@@........@@@.
	;;	@@@@@@@@@@........@@@@..
	;;	@@@@@@@@........@@@@...@
	;;	@@@@@.........@@@@......
	;;	@@@..@@@.....@@@.......@
	;;	@..@@@@@@@............@@
	;;	.@@@@@@@@@@............@
	;;	..@@@@....@@............
	;;	...........@@....@@@@...
	;;	............@...@@@@@@.@
	;;	............@@.....@@@.@
	;;	.............@......@@@.
	;;	.............@.......@@.
	;;	.....................@@.
	;;	................@@...@@.
	;;	...............@@@@.@@@.
	;;	..............@@@@@.@@.@
	;;	............@@.@@@@@.@.@
	;;	...........@@@@.@@@@..@@
	;;	..........@@@@@..@@@...@
	;;	........@@.@@@@@..@@....
	;;	@@@@@@@.@@..@@@@...@.@..
	;;	@@@@@@@.@@@...@@........
	;;	@@@@@@@.@@@....@..@....@
	;;	@@@@@@@@.@@............@
	;;	@@@@@@@...@...@.....@@.@
	;;	@@@@@@@............@@.@.
	;;	@@@@@@@............@@@@.
	;;	@@@@@@@@...........@@@@.
	;;	@@@@@@@@@.........@@@@@.
	;;	@@@@@@@@.........@@@@@@.
	;;	@@@@@@@........@@@@.@@.@
	;;	@@@@@@@...@..@@@@@@@@@..
	;;	@@@@@@@......@.@@@@@@...
	;;	@@@@@@@@......@@@@@@@...
	;;	@@@@@@@@@....@@..@@@@..@
	;;	@@@@@@@@.......@@..@..@@
	;;	@@@@@@@.......@..@@....@
	;;	@@@@@@@...@.............
	;;	@@@@@@@..............@..
	;;	@@@@@@@@................
	;;	@@@@@@@@@.........@....@
	;;	@@@@@@@@..............@@
	;;	@@@@@@@.......@........@
	;;	@@@@@@@...@.............
	;;	@@@@@@@..............@..
	;;	@@@@@@@@................
	;;	@@@@@@@@@.........@....@
	;;	@@@@@@@@......@.......@@
	;;	@@@@@@@@@............@@@
	;;	@@@@@@@@@@@........@@@@@
	;;	@@@@@@@@@@@@@@..@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@

;; -----------------------------------------------------------------------------------------------------------
SPR_FLIP			EQU		&80			;; bit7 set = sprite flip (eg. SPR_FLIP | SPR_VAPE1)
SPR_VISOROHALF		EQU		&10
SPR_VISORCHALF		EQU		&11
SPR_VISORO			EQU		&12
SPR_VISORC			EQU		&13

;; -----------------------------------------------------------------------------------------------------------
img_3x32_bin:				;; SPR_VISOROHALF: EQU &10
	DEFB &00, &00, &00, &00, &18, &00, &01, &E7, &00, &07, &F9, &C0, &01, &FE, &E0, &1C
	DEFB &7F, &70, &3F, &3F, &B0, &3F, &9F, &CC, &5F, &CF, &3E, &4F, &EC, &FA, &33, &E3
	DEFB &E2, &4D, &CF, &86, &72, &3E, &02, &7C, &F8, &06, &5D, &C4, &02, &46, &E8, &06
	DEFB &76, &C8, &46, &3D, &E0, &EE, &1E, &C8, &FC, &06, &E1, &70, &09, &E3, &F4, &06
	DEFB &FF, &0C, &0B, &3C, &38, &0D, &C0, &F0, &2E, &F7, &C4, &47, &7F, &12, &33, &9C
	DEFB &4C, &0C, &C1, &30, &03, &18, &C0, &00, &C3, &00, &00, &3C, &00, &00, &00, &00

	;;	........................
	;;	...........@@...........
	;;	.......@@@@..@@@........
	;;	.....@@@@@@@@..@@@......
	;;	.......@@@@@@@@.@@@.....
	;;	...@@@...@@@@@@@.@@@....
	;;	..@@@@@@..@@@@@@@.@@....
	;;	..@@@@@@@..@@@@@@@..@@..
	;;	.@.@@@@@@@..@@@@..@@@@@.
	;;	.@..@@@@@@@.@@..@@@@@.@.
	;;	..@@..@@@@@...@@@@@...@.
	;;	.@..@@.@@@..@@@@@....@@.
	;;	.@@@..@...@@@@@.......@.
	;;	.@@@@@..@@@@@........@@.
	;;	.@.@@@.@@@...@........@.
	;;	.@...@@.@@@.@........@@.
	;;	.@@@.@@.@@..@....@...@@.
	;;	..@@@@.@@@@.....@@@.@@@.
	;;	...@@@@.@@..@...@@@@@@..
	;;	.....@@.@@@....@.@@@....
	;;	....@..@@@@...@@@@@@.@..
	;;	.....@@.@@@@@@@@....@@..
	;;	....@.@@..@@@@....@@@...
	;;	....@@.@@@......@@@@....
	;;	..@.@@@.@@@@.@@@@@...@..
	;;	.@...@@@.@@@@@@@...@..@.
	;;	..@@..@@@..@@@...@..@@..
	;;	....@@..@@.....@..@@....
	;;	......@@...@@...@@......
	;;	........@@....@@........
	;;	..........@@@@..........
	;;	........................

							;; SPR_VISORCHALF: EQU &11
	DEFB &FF, &E7, &FF, &FE, &00, &FF, &F8, &00, &3F, &F0, &00, &1F, &E0, &00, &0F, &C0
	DEFB &00, &07, &80, &00, &03, &80, &00, &0D, &40, &00, &3E, &40, &00, &FA, &30, &03
	DEFB &E2, &0C, &0F, &86, &02, &3E, &02, &00, &F8, &06, &01, &C0, &02, &00, &E0, &06
	DEFB &00, &C0, &46, &81, &E0, &EE, &C0, &C0, &FD, &E0, &E1, &73, &E1, &E3, &F1, &F0
	DEFB &FF, &01, &E0, &3C, &03, &C0, &00, &03, &A0, &00, &05, &40, &00, &02, &B0, &00
	DEFB &0D, &CC, &00, &33, &F3, &00, &CF, &FC, &C3, &3F, &FF, &3C, &FF, &FF, &C3, &FF

	;;	@@@@@@@@@@@..@@@@@@@@@@@
	;;	@@@@@@@.........@@@@@@@@
	;;	@@@@@.............@@@@@@
	;;	@@@@...............@@@@@
	;;	@@@.................@@@@
	;;	@@...................@@@
	;;	@.....................@@
	;;	@...................@@.@
	;;	.@................@@@@@.
	;;	.@..............@@@@@.@.
	;;	..@@..........@@@@@...@.
	;;	....@@......@@@@@....@@.
	;;	......@...@@@@@.......@.
	;;	........@@@@@........@@.
	;;	.......@@@............@.
	;;	........@@@..........@@.
	;;	........@@.......@...@@.
	;;	@......@@@@.....@@@.@@@.
	;;	@@......@@......@@@@@@.@
	;;	@@@.....@@@....@.@@@..@@
	;;	@@@....@@@@...@@@@@@...@
	;;	@@@@....@@@@@@@@.......@
	;;	@@@.......@@@@........@@
	;;	@@....................@@
	;;	@.@..................@.@
	;;	.@....................@.
	;;	@.@@................@@.@
	;;	@@..@@............@@..@@
	;;	@@@@..@@........@@..@@@@
	;;	@@@@@@..@@....@@..@@@@@@
	;;	@@@@@@@@..@@@@..@@@@@@@@
	;;	@@@@@@@@@@....@@@@@@@@@@

							;; SPR_VISORO:     EQU &12
	DEFB &00, &00, &00, &00, &1C, &00, &00, &E3, &80, &03, &FC, &E0, &04, &7F, &70, &0F
	DEFB &1F, &B8, &0F, &CF, &DC, &1F, &E7, &EC, &5F, &F3, &EA, &6F, &FB, &F2, &57, &F9
	DEFB &E4, &69, &FD, &9A, &56, &38, &66, &59, &C3, &9E, &5E, &3C, &7E, &5B, &C3, &E6
	DEFB &58, &FF, &DE, &2E, &FF, &FC, &07, &FF, &F8, &29, &FF, &E4, &30, &3F, &18, &3F
	DEFB &C0, &F0, &0F, &1F, &E0, &00, &7F, &90, &27, &F8, &74, &47, &FB, &E2, &33, &FF
	DEFB &CC, &0C, &FF, &30, &03, &18, &C0, &00, &C3, &00, &00, &3C, &00, &00, &00, &00

	;;	........................
	;;	...........@@@..........
	;;	........@@@...@@@.......
	;;	......@@@@@@@@..@@@.....
	;;	.....@...@@@@@@@.@@@....
	;;	....@@@@...@@@@@@.@@@...
	;;	....@@@@@@..@@@@@@.@@@..
	;;	...@@@@@@@@..@@@@@@.@@..
	;;	.@.@@@@@@@@@..@@@@@.@.@.
	;;	.@@.@@@@@@@@@.@@@@@@..@.
	;;	.@.@.@@@@@@@@..@@@@..@..
	;;	.@@.@..@@@@@@@.@@..@@.@.
	;;	.@.@.@@...@@@....@@..@@.
	;;	.@.@@..@@@....@@@..@@@@.
	;;	.@.@@@@...@@@@...@@@@@@.
	;;	.@.@@.@@@@....@@@@@..@@.
	;;	.@.@@...@@@@@@@@@@.@@@@.
	;;	..@.@@@.@@@@@@@@@@@@@@..
	;;	.....@@@@@@@@@@@@@@@@...
	;;	..@.@..@@@@@@@@@@@@..@..
	;;	..@@......@@@@@@...@@...
	;;	..@@@@@@@@......@@@@....
	;;	....@@@@...@@@@@@@@.....
	;;	.........@@@@@@@@..@....
	;;	..@..@@@@@@@@....@@@.@..
	;;	.@...@@@@@@@@.@@@@@...@.
	;;	..@@..@@@@@@@@@@@@..@@..
	;;	....@@..@@@@@@@@..@@....
	;;	......@@...@@...@@......
	;;	........@@....@@........
	;;	..........@@@@..........
	;;	........................

							;; SPR_VISORC:     EQU &13
	DEFB &FF, &E3, &FF, &FF, &00, &7F, &FC, &00, &1F, &F8, &00, &0F, &F0, &00, &07, &E0
	DEFB &00, &03, &C0, &00, &01, &80, &00, &01, &40, &00, &02, &60, &00, &02, &50, &00
	DEFB &04, &68, &00, &18, &46, &00, &60, &41, &C3, &80, &40, &3C, &00, &40, &00, &00
	DEFB &40, &00, &00, &A0, &00, &01, &C0, &00, &03, &80, &00, &01, &80, &00, &03, &80
	DEFB &00, &07, &C0, &00, &0F, &C0, &00, &03, &A0, &00, &05, &40, &00, &02, &B0, &00
	DEFB &0D, &CC, &00, &33, &F3, &00, &CF, &FC, &C3, &3F, &FF, &3C, &FF, &FF, &C3, &FF

	;;	@@@@@@@@@@@...@@@@@@@@@@
	;;	@@@@@@@@.........@@@@@@@
	;;	@@@@@@.............@@@@@
	;;	@@@@@...............@@@@
	;;	@@@@.................@@@
	;;	@@@...................@@
	;;	@@.....................@
	;;	@......................@
	;;	.@....................@.
	;;	.@@...................@.
	;;	.@.@.................@..
	;;	.@@.@..............@@...
	;;	.@...@@..........@@.....
	;;	.@.....@@@....@@@.......
	;;	.@........@@@@..........
	;;	.@......................
	;;	.@......................
	;;	@.@....................@
	;;	@@....................@@
	;;	@......................@
	;;	@.....................@@
	;;	@....................@@@
	;;	@@..................@@@@
	;;	@@....................@@
	;;	@.@..................@.@
	;;	.@....................@.
	;;	@.@@................@@.@
	;;	@@..@@............@@..@@
	;;	@@@@..@@........@@..@@@@
	;;	@@@@@@..@@....@@..@@@@@@
	;;	@@@@@@@@..@@@@..@@@@@@@@
	;;	@@@@@@@@@@....@@@@@@@@@@

;; -----------------------------------------------------------------------------------------------------------
SPR_HEELS1			EQU		&18
SPR_HEELS2			EQU		&19
SPR_HEELS3			EQU		&1A
SPR_HEELSB1			EQU		&1B
SPR_HEELSB2			EQU		&1C
SPR_HEELSB3			EQU		&1D
SPR_HEAD1			EQU		&1E
SPR_HEAD2			EQU		&1F
SPR_HEAD3			EQU		&20
SPR_HEADB1			EQU		&21
SPR_HEADB2			EQU		&22
SPR_HEADB3			EQU		&23
SPR_VAPE1			EQU		&24
SPR_VAPE2			EQU		&25
SPR_VAPE3			EQU		&26
SPR_PURSE			EQU		&27
SPR_HOOTER			EQU		&28
SPR_DONUTS			EQU		&29
SPR_BUNNY			EQU		&2A
SPR_SPRING			EQU		&2B
SPR_SPRUNG			EQU		&2C
SPR_FISH1			EQU		&2D
SPR_FISH2			EQU		&2E
SPR_CROWN			EQU		&2F
SPR_SWITCH			EQU		&30
SPR_GRATING			EQU		&31
SPR_MONOCAT1		EQU		&32
SPR_MONOCAT2		EQU		&33
SPR_MONOCATB1		EQU		&34
SPR_MONOCATB2		EQU		&35
SPR_ROBOMOUSE		EQU		&36
SPR_ROBOMOUSEB		EQU		&37
SPR_BEE1			EQU		&38
SPR_BEE2			EQU		&39
SPR_BEACON			EQU		&3A
SPR_FACE			EQU		&3B
SPR_FACEB			EQU		&3C
SPR_TAP				EQU		&3D
SPR_CHIMP			EQU		&3E
SPR_CHIMPB			EQU		&3F
SPR_CHARLES			EQU		&40
SPR_CHARLESB		EQU		&41
SPR_TRUNK			EQU		&42
SPR_TRUNKB			EQU		&43
SPR_HELIPLAT1		EQU		&44
SPR_HELIPLAT2		EQU		&45
SPR_BONGO			EQU		&46
SPR_DRUM			EQU		&47
SPR_WELL			EQU		&48
SPR_STICK			EQU		&49
SPR_TRUNKS			EQU		&4A
SPR_DECK			EQU		&4B
SPR_BALL			EQU		&4C
SPR_HEAD_FLYING		EQU		&4D

;; -----------------------------------------------------------------------------------------------------------
img_3x24_bin:
img_3x24_0:
img_heels_0:			;; SPR_HEELS1:     EQU &18	3x24
						;; (This is also the one used on the main menu and
						;; on the crown ("Salute") screen, although flipped)
	DEFB &00, &00, &00, &00, &3E, &00, &01, &F9, &C0, &07, &C6, &F0, &0F, &BE, &F8, &0F
	DEFB &C1, &8C, &1F, &FD, &AC, &1B, &CF, &76, &07, &97, &46, &3F, &BA, &0A, &3F, &A1
	DEFB &BC, &7F, &83, &DC, &77, &9B, &D4, &0F, &7A, &BC, &09, &FC, &68, &02, &EF, &70
	DEFB &0F, &FB, &0E, &1F, &6E, &FA, &1F, &B9, &6C, &07, &C7, &B0, &01, &FD, &D0, &00
	DEFB &76, &C0, &00, &18, &00, &00, &00, &00

	;;	........................
	;;	..........@@@@@.........
	;;	.......@@@@@@..@@@......
	;;	.....@@@@@...@@.@@@@....
	;;	....@@@@@.@@@@@.@@@@@...
	;;	....@@@@@@.....@@...@@..
	;;	...@@@@@@@@@@@.@@.@.@@..
	;;	...@@.@@@@..@@@@.@@@.@@.
	;;	.....@@@@..@.@@@.@...@@.
	;;	..@@@@@@@.@@@.@.....@.@.
	;;	..@@@@@@@.@....@@.@@@@..
	;;	.@@@@@@@@.....@@@@.@@@..
	;;	.@@@.@@@@..@@.@@@@.@.@..
	;;	....@@@@.@@@@.@.@.@@@@..
	;;	....@..@@@@@@@...@@.@...
	;;	......@.@@@.@@@@.@@@....
	;;	....@@@@@@@@@.@@....@@@.
	;;	...@@@@@.@@.@@@.@@@@@.@.
	;;	...@@@@@@.@@@..@.@@.@@..
	;;	.....@@@@@...@@@@.@@....
	;;	.......@@@@@@@.@@@.@....
	;;	.........@@@.@@.@@......
	;;	...........@@...........
	;;	........................

img_3x24_0_mask:
	DEFB &FF, &C1, &FF, &FE, &3E, &3F, &F9, &F9, &CF, &F7, &C0, &F7, &EF, &80, &FB, &EF
	DEFB &C1, &8D, &DF, &FD, &8D, &DB, &CF, &36, &C7, &87, &06, &BF, &9A, &0A, &BF, &80
	DEFB &3D, &7F, &80, &1D, &77, &98, &15, &8F, &78, &3D, &E9, &FC, &6B, &F2, &EF, &71
	DEFB &EF, &FB, &0E, &DF, &6E, &FA, &DF, &B9, &6D, &E7, &C7, &B3, &F9, &FD, &D7, &FE
	DEFB &76, &CF, &FF, &99, &3F, &FF, &E7, &FF

	;;	@@@@@@@@@@.....@@@@@@@@@
	;;	@@@@@@@...@@@@@...@@@@@@
	;;	@@@@@..@@@@@@..@@@..@@@@
	;;	@@@@.@@@@@......@@@@.@@@
	;;	@@@.@@@@@.......@@@@@.@@
	;;	@@@.@@@@@@.....@@...@@.@
	;;	@@.@@@@@@@@@@@.@@...@@.@
	;;	@@.@@.@@@@..@@@@..@@.@@.
	;;	@@...@@@@....@@@.....@@.
	;;	@.@@@@@@@..@@.@.....@.@.
	;;	@.@@@@@@@.........@@@@.@
	;;	.@@@@@@@@..........@@@.@
	;;	.@@@.@@@@..@@......@.@.@
	;;	@...@@@@.@@@@.....@@@@.@
	;;	@@@.@..@@@@@@@...@@.@.@@
	;;	@@@@..@.@@@.@@@@.@@@...@
	;;	@@@.@@@@@@@@@.@@....@@@.
	;;	@@.@@@@@.@@.@@@.@@@@@.@.
	;;	@@.@@@@@@.@@@..@.@@.@@.@
	;;	@@@..@@@@@...@@@@.@@..@@
	;;	@@@@@..@@@@@@@.@@@.@.@@@
	;;	@@@@@@@..@@@.@@.@@..@@@@
	;;	@@@@@@@@@..@@..@..@@@@@@
	;;	@@@@@@@@@@@..@@@@@@@@@@@
	;;
	;;	 bit	 bit
	;;	image	mask	result
	;;	0 (.)   0 (.)	Black (X)
	;;	1 (@)   0 (.)	Color (c) (touch of color, depends on current color scheme)
	;;	0 (.)   1 (@)	Transparent (_)
	;;	1 (@)   1 (@)	Cream (.) (main body color)
	;;
	;;	addr:8BD0													 addr:8C18
	;;	00 00 00  ........................  @@@@@@@@@@.....@@@@@@@@@ FF C1 FF : __________XXXXX_________
	;;	00 3E 00  ..........@@@@@.........  @@@@@@@...@@@@@...@@@@@@ FE 3E 3F : _______XXX.....XXX______
	;;	01 F9 C0  .......@@@@@@..@@@......  @@@@@..@@@@@@..@@@..@@@@ F9 F9 CF : _____XX......XX...XX____
	;;	07 C6 F0  .....@@@@@...@@.@@@@....  @@@@.@@@@@......@@@@.@@@ F7 C0 F7 : ____X.....XXXccX....X___
	;;	0F BE F8  ....@@@@@.@@@@@.@@@@@...  @@@.@@@@@.......@@@@@.@@ EF 80 FB : ___X.....XcccccX.....X__
	;;	0F C1 8C  ....@@@@@@.....@@...@@..  @@@.@@@@@@.....@@...@@.@ EF C1 8D : ___X......XXXXX..XXX..X_
	;;	1F FD AC  ...@@@@@@@@@@@.@@.@.@@..  @@.@@@@@@@@@@@.@@...@@.@ DF FD 8D : __X...........X..XcX..X_
	;;	1B CF 76  ...@@.@@@@..@@@@.@@@.@@.  @@.@@.@@@@..@@@@..@@.@@. DB CF 36 : __X..X....XX....Xc..X..X
	;;	07 97 46  .....@@@@..@.@@@.@...@@.  @@...@@@@....@@@.....@@. C7 87 06 : __XXX....XXcX...XcXXX..X
	;;	3F BA 0A  ..@@@@@@@.@@@.@.....@.@.  @.@@@@@@@..@@.@.....@.@. BF 9A 0A : _X.......Xc..X.XXXXX.X.X
	;;	3F A1 BC  ..@@@@@@@.@....@@.@@@@..  @.@@@@@@@.........@@@@.@ BF 80 3D : _X.......XcXXXXccX....X_
	;;	7F 83 DC  .@@@@@@@@.....@@@@.@@@..  .@@@@@@@@..........@@@.@ 7F 80 1D : X........XXXXXccccX...X_
	;;	77 9B D4  .@@@.@@@@..@@.@@@@.@.@..  .@@@.@@@@..@@......@.@.@ 77 98 15 : X...X....XX..XccccX.X.X_
	;;	0F 7A BC  ....@@@@.@@@@.@.@.@@@@..  @...@@@@.@@@@.....@@@@.@ 8F 78 3D : _XXX....X....XcXcX....X_
	;;	09 FC 68  ....@..@@@@@@@...@@.@...  @@@.@..@@@@@@@...@@.@.@@ E9 FC 6B : ___X.XX.......XXX..X.X__
	;;	02 EF 70  ......@.@@@.@@@@.@@@....  @@@@..@.@@@.@@@@.@@@...@ F2 EF 71 : ____XX.X...X....X...XXX_
	;;	0F FB 0E  ....@@@@@@@@@.@@....@@@.  @@@.@@@@@@@@@.@@....@@@. EF FB 0E : ___X.........X..XXXX...X
	;;	1F 6E FA  ...@@@@@.@@.@@@.@@@@@.@.  @@.@@@@@.@@.@@@.@@@@@.@. DF 6E FA : __X.....X..X...X.....X.X
	;;	1F B9 6C  ...@@@@@@.@@@..@.@@.@@..  @@.@@@@@@.@@@..@.@@.@@.@ DF B9 6D : __X......X...XX.X..X..X_
	;;	07 C7 B0  .....@@@@@...@@@@.@@....  @@@..@@@@@...@@@@.@@..@@ E7 C7 B3 : ___XX.....XXX....X..XX__
	;;	01 FD D0  .......@@@@@@@.@@@.@....  @@@@@..@@@@@@@.@@@.@.@@@ F9 FD D7 : _____XX.......X...X.X___
	;;	00 76 C0  .........@@@.@@.@@......  @@@@@@@..@@@.@@.@@..@@@@ FE 76 CF : _______XX...X..X..XX____
	;;	00 18 00  ...........@@...........  @@@@@@@@@..@@..@..@@@@@@ FF 99 3F : _________XX..XX_XX______
	;;	00 00 00  ........................  @@@@@@@@@@@..@@@@@@@@@@@ FF E7 FF : ___________XX___________

img_3x24_1:			;; SPR_HEELS2:     EQU &19	3x24
	DEFB &00, &00, &00, &00, &3E, &00, &01, &F9, &C0, &07, &C6, &F0, &0F, &BE, &F8, &0F
	DEFB &C1, &8C, &1F, &FD, &AC, &0B, &CF, &76, &37, &97, &46, &7F, &BA, &0A, &7F, &A1
	DEFB &BC, &37, &83, &DC, &0F, &9B, &D4, &0F, &7A, &BC, &09, &FC, &68, &02, &EF, &74
	DEFB &07, &FB, &08, &0F, &6E, &60, &0F, &B9, &80, &03, &C7, &C0, &00, &FE, &E0, &00
	DEFB &3B, &60, &00, &0C, &00, &00, &00, &00

	;;	........................
	;;	..........@@@@@.........
	;;	.......@@@@@@..@@@......
	;;	.....@@@@@...@@.@@@@....
	;;	....@@@@@.@@@@@.@@@@@...
	;;	....@@@@@@.....@@...@@..
	;;	...@@@@@@@@@@@.@@.@.@@..
	;;	....@.@@@@..@@@@.@@@.@@.
	;;	..@@.@@@@..@.@@@.@...@@.
	;;	.@@@@@@@@.@@@.@.....@.@.
	;;	.@@@@@@@@.@....@@.@@@@..
	;;	..@@.@@@@.....@@@@.@@@..
	;;	....@@@@@..@@.@@@@.@.@..
	;;	....@@@@.@@@@.@.@.@@@@..
	;;	....@..@@@@@@@...@@.@...
	;;	......@.@@@.@@@@.@@@.@..
	;;	.....@@@@@@@@.@@....@...
	;;	....@@@@.@@.@@@..@@.....
	;;	....@@@@@.@@@..@@.......
	;;	......@@@@...@@@@@......
	;;	........@@@@@@@.@@@.....
	;;	..........@@@.@@.@@.....
	;;	............@@..........
	;;	........................

img_3x24_1_mask:
	DEFB &FF, &C1, &FF, &FE, &3E, &3F, &F9, &F9
	DEFB &CF, &F7, &C0, &F7, &EF, &80, &FB, &EF, &C1, &8D, &DF, &FD, &8D, &CB, &CF, &36
	DEFB &B7, &87, &06, &7F, &9A, &0A, &7F, &80, &3D, &B7, &80, &1D, &CF, &98, &15, &EF
	DEFB &78, &3D, &E9, &FC, &6B, &F2, &EF, &75, &F7, &FB, &0B, &EF, &6E, &67, &EF, &B9
	DEFB &9F, &F3, &C7, &DF, &FC, &FE, &EF, &FF, &3B, &6F, &FF, &CC, &9F, &FF, &F3, &FF

	;;	@@@@@@@@@@.....@@@@@@@@@
	;;	@@@@@@@...@@@@@...@@@@@@
	;;	@@@@@..@@@@@@..@@@..@@@@
	;;	@@@@.@@@@@......@@@@.@@@
	;;	@@@.@@@@@.......@@@@@.@@
	;;	@@@.@@@@@@.....@@...@@.@
	;;	@@.@@@@@@@@@@@.@@...@@.@
	;;	@@..@.@@@@..@@@@..@@.@@.
	;;	@.@@.@@@@....@@@.....@@.
	;;	.@@@@@@@@..@@.@.....@.@.
	;;	.@@@@@@@@.........@@@@.@
	;;	@.@@.@@@@..........@@@.@
	;;	@@..@@@@@..@@......@.@.@
	;;	@@@.@@@@.@@@@.....@@@@.@
	;;	@@@.@..@@@@@@@...@@.@.@@
	;;	@@@@..@.@@@.@@@@.@@@.@.@
	;;	@@@@.@@@@@@@@.@@....@.@@
	;;	@@@.@@@@.@@.@@@..@@..@@@
	;;	@@@.@@@@@.@@@..@@..@@@@@
	;;	@@@@..@@@@...@@@@@.@@@@@
	;;	@@@@@@..@@@@@@@.@@@.@@@@
	;;	@@@@@@@@..@@@.@@.@@.@@@@
	;;	@@@@@@@@@@..@@..@..@@@@@
	;;	@@@@@@@@@@@@..@@@@@@@@@@

					;; SPR_HEELS3:     EQU &1A	3x24
	DEFB &00, &00, &00, &00, &3E, &00, &01, &F9, &C0, &07, &C6, &F0, &0F, &BE, &F8, &0F
	DEFB &C1, &8C, &1F, &FD, &AC, &1B, &CF, &76, &67, &97, &46, &7F, &BA, &0A, &7F, &A1
	DEFB &BC, &2F, &83, &DC, &07, &9B, &D4, &0F, &7A, &BC, &09, &FC, &68, &16, &EF, &70
	DEFB &3F, &FB, &0E, &1F, &6E, &FA, &0F, &B8, &EC, &03, &C7, &70, &00, &DB, &30, &00
	DEFB &60, &00, &00, &00, &00, &00, &00, &00, &FF, &C1, &FF, &FE, &3E, &3F, &F9, &F9
	DEFB &CF, &F7, &C0, &F7, &EF, &80, &FB, &EF, &C1, &8D, &DF, &FD, &8D, &9B, &CF, &36
	DEFB &67, &87, &06, &7F, &9A, &0A, &7F, &80, &3D, &AF, &80, &1D, &D7, &98, &15, &EF
	DEFB &78, &3D, &E9, &FC, &6B, &D6, &EF, &71, &BF, &FB, &0E, &DF, &6E, &FA, &EF, &B8
	DEFB &ED, &F3, &C7, &73, &FC, &DB, &37, &FF, &64, &CF, &FF, &9F, &FF, &FF, &FF, &FF

	;;	........................
	;;	..........@@@@@.........
	;;	.......@@@@@@..@@@......
	;;	.....@@@@@...@@.@@@@....
	;;	....@@@@@.@@@@@.@@@@@...
	;;	....@@@@@@.....@@...@@..
	;;	...@@@@@@@@@@@.@@.@.@@..
	;;	...@@.@@@@..@@@@.@@@.@@.
	;;	.@@..@@@@..@.@@@.@...@@.
	;;	.@@@@@@@@.@@@.@.....@.@.
	;;	.@@@@@@@@.@....@@.@@@@..
	;;	..@.@@@@@.....@@@@.@@@..
	;;	.....@@@@..@@.@@@@.@.@..
	;;	....@@@@.@@@@.@.@.@@@@..
	;;	....@..@@@@@@@...@@.@...
	;;	...@.@@.@@@.@@@@.@@@....
	;;	..@@@@@@@@@@@.@@....@@@.
	;;	...@@@@@.@@.@@@.@@@@@.@.
	;;	....@@@@@.@@@...@@@.@@..
	;;	......@@@@...@@@.@@@....
	;;	........@@.@@.@@..@@....
	;;	.........@@.............
	;;	........................
	;;	........................
	;;
	;;	@@@@@@@@@@.....@@@@@@@@@
	;;	@@@@@@@...@@@@@...@@@@@@
	;;	@@@@@..@@@@@@..@@@..@@@@
	;;	@@@@.@@@@@......@@@@.@@@
	;;	@@@.@@@@@.......@@@@@.@@
	;;	@@@.@@@@@@.....@@...@@.@
	;;	@@.@@@@@@@@@@@.@@...@@.@
	;;	@..@@.@@@@..@@@@..@@.@@.
	;;	.@@..@@@@....@@@.....@@.
	;;	.@@@@@@@@..@@.@.....@.@.
	;;	.@@@@@@@@.........@@@@.@
	;;	@.@.@@@@@..........@@@.@
	;;	@@.@.@@@@..@@......@.@.@
	;;	@@@.@@@@.@@@@.....@@@@.@
	;;	@@@.@..@@@@@@@...@@.@.@@
	;;	@@.@.@@.@@@.@@@@.@@@...@
	;;	@.@@@@@@@@@@@.@@....@@@.
	;;	@@.@@@@@.@@.@@@.@@@@@.@.
	;;	@@@.@@@@@.@@@...@@@.@@.@
	;;	@@@@..@@@@...@@@.@@@..@@
	;;	@@@@@@..@@.@@.@@..@@.@@@
	;;	@@@@@@@@.@@..@..@@..@@@@
	;;	@@@@@@@@@..@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@

			;; SPR_HEELSB1:     EQU &1B	3x24
	DEFB &00, &00, &00, &00, &34, &00, &01, &E7, &00, &06, &1F, &C0, &0F, &FB, &E8, &0F
	DEFB &FF, &F4, &1F, &FE, &F4, &1F, &FD, &38, &3F, &FC, &D8, &2E, &FE, &E8, &1F, &1E
	DEFB &E8, &3F, &EF, &60, &2F, &77, &60, &3F, &B7, &B0, &16, &4F, &C0, &0F, &BF, &20
	DEFB &17, &F0, &F0, &39, &F7, &70, &1E, &7B, &F8, &07, &BD, &F8, &03, &FC, &70, &00
	DEFB &FC, &00, &00, &38, &00, &00, &00, &00, &FF, &CB, &FF, &FE, &04, &FF, &F8, &07
	DEFB &3F, &F6, &1F, &D7, &EF, &FB, &EB, &EF, &FF, &F5, &DF, &FE, &F5, &DF, &FC, &3B
	DEFB &BF, &FC, &1B, &AE, &FE, &0B, &DF, &1E, &0B, &BF, &EF, &07, &AF, &77, &07, &BF
	DEFB &B7, &87, &D6, &4F, &CF, &EF, &BF, &2F, &D7, &F0, &F7, &B9, &F7, &77, &DE, &7B
	DEFB &FB, &E7, &BD, &FB, &FB, &FC, &77, &FC, &FD, &8F, &FF, &3B, &FF, &FF, &C7, &FF

	;;	........................
	;;	..........@@.@..........
	;;	.......@@@@..@@@........
	;;	.....@@....@@@@@@@......
	;;	....@@@@@@@@@.@@@@@.@...
	;;	....@@@@@@@@@@@@@@@@.@..
	;;	...@@@@@@@@@@@@.@@@@.@..
	;;	...@@@@@@@@@@@.@..@@@...
	;;	..@@@@@@@@@@@@..@@.@@...
	;;	..@.@@@.@@@@@@@.@@@.@...
	;;	...@@@@@...@@@@.@@@.@...
	;;	..@@@@@@@@@.@@@@.@@.....
	;;	..@.@@@@.@@@.@@@.@@.....
	;;	..@@@@@@@.@@.@@@@.@@....
	;;	...@.@@..@..@@@@@@......
	;;	....@@@@@.@@@@@@..@.....
	;;	...@.@@@@@@@....@@@@....
	;;	..@@@..@@@@@.@@@.@@@....
	;;	...@@@@..@@@@.@@@@@@@...
	;;	.....@@@@.@@@@.@@@@@@...
	;;	......@@@@@@@@...@@@....
	;;	........@@@@@@..........
	;;	..........@@@...........
	;;	........................
	;;
	;;	@@@@@@@@@@..@.@@@@@@@@@@
	;;	@@@@@@@......@..@@@@@@@@
	;;	@@@@@........@@@..@@@@@@
	;;	@@@@.@@....@@@@@@@.@.@@@
	;;	@@@.@@@@@@@@@.@@@@@.@.@@
	;;	@@@.@@@@@@@@@@@@@@@@.@.@
	;;	@@.@@@@@@@@@@@@.@@@@.@.@
	;;	@@.@@@@@@@@@@@....@@@.@@
	;;	@.@@@@@@@@@@@@.....@@.@@
	;;	@.@.@@@.@@@@@@@.....@.@@
	;;	@@.@@@@@...@@@@.....@.@@
	;;	@.@@@@@@@@@.@@@@.....@@@
	;;	@.@.@@@@.@@@.@@@.....@@@
	;;	@.@@@@@@@.@@.@@@@....@@@
	;;	@@.@.@@..@..@@@@@@..@@@@
	;;	@@@.@@@@@.@@@@@@..@.@@@@
	;;	@@.@.@@@@@@@....@@@@.@@@
	;;	@.@@@..@@@@@.@@@.@@@.@@@
	;;	@@.@@@@..@@@@.@@@@@@@.@@
	;;	@@@..@@@@.@@@@.@@@@@@.@@
	;;	@@@@@.@@@@@@@@...@@@.@@@
	;;	@@@@@@..@@@@@@.@@...@@@@
	;;	@@@@@@@@..@@@.@@@@@@@@@@
	;;	@@@@@@@@@@...@@@@@@@@@@@

				;; SPR_HEELSB2:     EQU &1C	3x24
	DEFB &00, &00, &00, &00, &34, &00, &01, &E7, &00, &06, &1F, &CC, &0F, &FB, &EC, &0F
	DEFB &FF, &F0, &1F, &FE, &F0, &1F, &FD, &38, &3F, &FC, &D8, &2E, &CE, &E8, &1F, &36
	DEFB &E8, &3F, &F7, &70, &2F, &6F, &98, &3F, &9F, &E0, &16, &5F, &C0, &2F, &BF, &20
	DEFB &57, &E0, &E0, &79, &F6, &F0, &3E, &7B, &70, &0F, &FB, &F8, &03, &F8, &F8, &00
	DEFB &70, &30, &00, &00, &00, &00, &00, &00, &FF, &CB, &FF, &FE, &04, &FF, &F8, &07
	DEFB &33, &F6, &1F, &CD, &EF, &FB, &ED, &EF, &FF, &F3, &DF, &FE, &F7, &DF, &FC, &3B
	DEFB &BF, &FC, &1B, &AE, &CE, &0B, &DF, &36, &0B, &BF, &F7, &07, &AF, &6F, &83, &BF
	DEFB &9F, &E7, &D6, &5F, &DF, &AF, &BF, &2F, &57, &E0, &EF, &79, &F6, &F7, &BE, &7B
	DEFB &77, &CF, &FB, &FB, &F3, &F8, &FB, &FC, &77, &37, &FF, &8F, &CF, &FF, &FF, &FF

	;;	........................
	;;	..........@@.@..........
	;;	.......@@@@..@@@........
	;;	.....@@....@@@@@@@..@@..
	;;	....@@@@@@@@@.@@@@@.@@..
	;;	....@@@@@@@@@@@@@@@@....
	;;	...@@@@@@@@@@@@.@@@@....
	;;	...@@@@@@@@@@@.@..@@@...
	;;	..@@@@@@@@@@@@..@@.@@...
	;;	..@.@@@.@@..@@@.@@@.@...
	;;	...@@@@@..@@.@@.@@@.@...
	;;	..@@@@@@@@@@.@@@.@@@....
	;;	..@.@@@@.@@.@@@@@..@@...
	;;	..@@@@@@@..@@@@@@@@.....
	;;	...@.@@..@.@@@@@@@......
	;;	..@.@@@@@.@@@@@@..@.....
	;;	.@.@.@@@@@@.....@@@.....
	;;	.@@@@..@@@@@.@@.@@@@....
	;;	..@@@@@..@@@@.@@.@@@....
	;;	....@@@@@@@@@.@@@@@@@...
	;;	......@@@@@@@...@@@@@...
	;;	.........@@@......@@....
	;;	........................
	;;	........................
	;;
	;;	@@@@@@@@@@..@.@@@@@@@@@@
	;;	@@@@@@@......@..@@@@@@@@
	;;	@@@@@........@@@..@@..@@
	;;	@@@@.@@....@@@@@@@..@@.@
	;;	@@@.@@@@@@@@@.@@@@@.@@.@
	;;	@@@.@@@@@@@@@@@@@@@@..@@
	;;	@@.@@@@@@@@@@@@.@@@@.@@@
	;;	@@.@@@@@@@@@@@....@@@.@@
	;;	@.@@@@@@@@@@@@.....@@.@@
	;;	@.@.@@@.@@..@@@.....@.@@
	;;	@@.@@@@@..@@.@@.....@.@@
	;;	@.@@@@@@@@@@.@@@.....@@@
	;;	@.@.@@@@.@@.@@@@@.....@@
	;;	@.@@@@@@@..@@@@@@@@..@@@
	;;	@@.@.@@..@.@@@@@@@.@@@@@
	;;	@.@.@@@@@.@@@@@@..@.@@@@
	;;	.@.@.@@@@@@.....@@@.@@@@
	;;	.@@@@..@@@@@.@@.@@@@.@@@
	;;	@.@@@@@..@@@@.@@.@@@.@@@
	;;	@@..@@@@@@@@@.@@@@@@@.@@
	;;	@@@@..@@@@@@@...@@@@@.@@
	;;	@@@@@@...@@@.@@@..@@.@@@
	;;	@@@@@@@@@...@@@@@@..@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@

			;; SPR_HEELSB3:     EQU &1D	3x24
	DEFB &00, &00, &00, &00, &34, &00, &01, &E7, &00, &06, &1F, &D0, &0F, &FB, &E0, &0F
	DEFB &FF, &F0, &1F, &FE, &F0, &1F, &FD, &38, &3F, &FC, &D8, &2E, &7D, &D8, &1F, &BD
	DEFB &D8, &3F, &DD, &D0, &2E, &5D, &B0, &3F, &BB, &60, &16, &BA, &C0, &0F, &7D, &00
	DEFB &03, &F0, &C0, &04, &FB, &C0, &0B, &3D, &80, &0F, &EE, &00, &03, &FF, &00, &00
	DEFB &7F, &00, &00, &0E, &00, &00, &00, &00, &FF, &CB, &FF, &FE, &04, &FF, &F8, &07
	DEFB &2F, &F6, &1F, &D7, &EF, &FB, &EF, &EF, &FF, &F7, &DF, &FE, &F7, &DF, &FC, &3B
	DEFB &BF, &FC, &1B, &AE, &7C, &1B, &DF, &BC, &1B, &BF, &DC, &17, &AE, &5C, &37, &BF
	DEFB &B8, &6F, &D6, &B8, &DF, &EF, &7D, &3F, &F3, &F0, &DF, &F4, &FB, &DF, &EB, &3D
	DEFB &BF, &EF, &EE, &7F, &F3, &FF, &7F, &FC, &7F, &7F, &FF, &8E, &FF, &FF, &F1, &FF

	;;	........................
	;;	..........@@.@..........
	;;	.......@@@@..@@@........
	;;	.....@@....@@@@@@@.@....
	;;	....@@@@@@@@@.@@@@@.....
	;;	....@@@@@@@@@@@@@@@@....
	;;	...@@@@@@@@@@@@.@@@@....
	;;	...@@@@@@@@@@@.@..@@@...
	;;	..@@@@@@@@@@@@..@@.@@...
	;;	..@.@@@..@@@@@.@@@.@@...
	;;	...@@@@@@.@@@@.@@@.@@...
	;;	..@@@@@@@@.@@@.@@@.@....
	;;	..@.@@@..@.@@@.@@.@@....
	;;	..@@@@@@@.@@@.@@.@@.....
	;;	...@.@@.@.@@@.@.@@......
	;;	....@@@@.@@@@@.@........
	;;	......@@@@@@....@@......
	;;	.....@..@@@@@.@@@@......
	;;	....@.@@..@@@@.@@.......
	;;	....@@@@@@@.@@@.........
	;;	......@@@@@@@@@@........
	;;	.........@@@@@@@........
	;;	............@@@.........
	;;	........................
	;;
	;;	@@@@@@@@@@..@.@@@@@@@@@@
	;;	@@@@@@@......@..@@@@@@@@
	;;	@@@@@........@@@..@.@@@@
	;;	@@@@.@@....@@@@@@@.@.@@@
	;;	@@@.@@@@@@@@@.@@@@@.@@@@
	;;	@@@.@@@@@@@@@@@@@@@@.@@@
	;;	@@.@@@@@@@@@@@@.@@@@.@@@
	;;	@@.@@@@@@@@@@@....@@@.@@
	;;	@.@@@@@@@@@@@@.....@@.@@
	;;	@.@.@@@..@@@@@.....@@.@@
	;;	@@.@@@@@@.@@@@.....@@.@@
	;;	@.@@@@@@@@.@@@.....@.@@@
	;;	@.@.@@@..@.@@@....@@.@@@
	;;	@.@@@@@@@.@@@....@@.@@@@
	;;	@@.@.@@.@.@@@...@@.@@@@@
	;;	@@@.@@@@.@@@@@.@..@@@@@@
	;;	@@@@..@@@@@@....@@.@@@@@
	;;	@@@@.@..@@@@@.@@@@.@@@@@
	;;	@@@.@.@@..@@@@.@@.@@@@@@
	;;	@@@.@@@@@@@.@@@..@@@@@@@
	;;	@@@@..@@@@@@@@@@.@@@@@@@
	;;	@@@@@@...@@@@@@@.@@@@@@@
	;;	@@@@@@@@@...@@@.@@@@@@@@
	;;	@@@@@@@@@@@@...@@@@@@@@@

img_head_0:
				;; SPR_HEAD1:     EQU &1E	3x24
				;; (This is also the one used on the main menu and
				;; on the crown ("Salute") screen)
	DEFB &00, &00, &00, &00, &7C, &00, &01, &FF, &00, &03, &FF, &80, &07, &FE, &40, &07
	DEFB &F3, &C0, &0F, &EF, &E0, &0F, &FF, &78, &0F, &FB, &44, &0F, &FB, &82, &17, &FF
	DEFB &82, &1B, &FF, &02, &37, &FE, &82, &77, &7E, &04, &2F, &76, &04, &2E, &E7, &1C
	DEFB &2F, &38, &FC, &77, &CF, &98, &1B, &B6, &00, &0C, &F8, &00, &08, &58, &00, &00
	DEFB &30, &00, &00, &00, &00, &00, &00, &00, &FF, &83, &FF, &FE, &7C, &FF, &FD, &FF
	DEFB &7F, &FB, &FF, &BF, &F7, &FE, &5F, &F7, &F3, &DF, &EF, &EF, &EF, &EF, &FF, &7F
	DEFB &EF, &FB, &47, &EF, &FB, &83, &C7, &FF, &83, &C3, &FF, &03, &87, &FE, &83, &07
	DEFB &7E, &07, &8F, &76, &07, &8E, &E7, &19, &8F, &38, &E1, &07, &CF, &83, &83, &86
	DEFB &67, &E0, &81, &FF, &E3, &03, &FF, &F7, &87, &FF, &FF, &CF, &FF, &FF, &FF, &FF

	;;	........................
	;;	.........@@@@@..........
	;;	.......@@@@@@@@@........
	;;	......@@@@@@@@@@@.......
	;;	.....@@@@@@@@@@..@......
	;;	.....@@@@@@@..@@@@......
	;;	....@@@@@@@.@@@@@@@.....
	;;	....@@@@@@@@@@@@.@@@@...
	;;	....@@@@@@@@@.@@.@...@..
	;;	....@@@@@@@@@.@@@.....@.
	;;	...@.@@@@@@@@@@@@.....@.
	;;	...@@.@@@@@@@@@@......@.
	;;	..@@.@@@@@@@@@@.@.....@.
	;;	.@@@.@@@.@@@@@@......@..
	;;	..@.@@@@.@@@.@@......@..
	;;	..@.@@@.@@@..@@@...@@@..
	;;	..@.@@@@..@@@...@@@@@@..
	;;	.@@@.@@@@@..@@@@@..@@...
	;;	...@@.@@@.@@.@@.........
	;;	....@@..@@@@@...........
	;;	....@....@.@@...........
	;;	..........@@............
	;;	........................
	;;	........................
	;;
	;;	@@@@@@@@@.....@@@@@@@@@@
	;;	@@@@@@@..@@@@@..@@@@@@@@
	;;	@@@@@@.@@@@@@@@@.@@@@@@@
	;;	@@@@@.@@@@@@@@@@@.@@@@@@
	;;	@@@@.@@@@@@@@@@..@.@@@@@
	;;	@@@@.@@@@@@@..@@@@.@@@@@
	;;	@@@.@@@@@@@.@@@@@@@.@@@@
	;;	@@@.@@@@@@@@@@@@.@@@@@@@
	;;	@@@.@@@@@@@@@.@@.@...@@@
	;;	@@@.@@@@@@@@@.@@@.....@@
	;;	@@...@@@@@@@@@@@@.....@@
	;;	@@....@@@@@@@@@@......@@
	;;	@....@@@@@@@@@@.@.....@@
	;;	.....@@@.@@@@@@......@@@
	;;	@...@@@@.@@@.@@......@@@
	;;	@...@@@.@@@..@@@...@@..@
	;;	@...@@@@..@@@...@@@....@
	;;	.....@@@@@..@@@@@.....@@
	;;	@.....@@@....@@..@@..@@@
	;;	@@@.....@......@@@@@@@@@
	;;	@@@...@@......@@@@@@@@@@
	;;	@@@@.@@@@....@@@@@@@@@@@
	;;	@@@@@@@@@@..@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@

			;; SPR_HEAD2:     EQU &1F	3x24
.img_head_1f:
	DEFB &00, &00, &00, &00, &7C, &00, &01, &FF, &00, &03, &FF, &80, &07, &FC, &80, &07
	DEFB &E7, &C0, &0F, &DF, &C0, &0F, &FE, &F0, &0F, &F6, &88, &0F, &F7, &04, &17, &FF
	DEFB &04, &77, &FE, &04, &2F, &FD, &04, &2E, &FC, &08, &2E, &EC, &0C, &5D, &CF, &3E
	DEFB &1E, &F0, &DE, &0F, &3F, &8C, &16, &DE, &00, &1B, &E0, &00, &05, &60, &00, &00
	DEFB &C0, &00, &00, &00, &00, &00, &00, &00

	;;	........................
	;;	.........@@@@@..........
	;;	.......@@@@@@@@@........
	;;	......@@@@@@@@@@@.......
	;;	.....@@@@@@@@@..@.......
	;;	.....@@@@@@..@@@@@......
	;;	....@@@@@@.@@@@@@@......
	;;	....@@@@@@@@@@@.@@@@....
	;;	....@@@@@@@@.@@.@...@...
	;;	....@@@@@@@@.@@@.....@..
	;;	...@.@@@@@@@@@@@.....@..
	;;	.@@@.@@@@@@@@@@......@..
	;;	..@.@@@@@@@@@@.@.....@..
	;;	..@.@@@.@@@@@@......@...
	;;	..@.@@@.@@@.@@......@@..
	;;	.@.@@@.@@@..@@@@..@@@@@.
	;;	...@@@@.@@@@....@@.@@@@.
	;;	....@@@@..@@@@@@@...@@..
	;;	...@.@@.@@.@@@@.........
	;;	...@@.@@@@@.............
	;;	.....@.@.@@.............
	;;	........@@..............
	;;	........................
	;;	........................

	DEFB &FF, &83, &FF, &FE, &7C, &FF, &FD, &FF, &7F, &FB, &FF, &BF, &F7, &FC, &BF, &F7
	DEFB &E7, &DF, &EF, &DF, &DF, &EF, &FE, &FF, &EF, &F6, &8F, &EF, &F7, &07, &87, &FF
	DEFB &07, &07, &FE, &07, &8F, &FD, &07, &8E, &FC, &0B, &8E, &EC, &09, &1D, &CF, &30
	DEFB &9E, &F0, &C0, &EF, &3F, &A1, &C6, &1E, &73, &C2, &01, &FF, &E0, &0F, &FF, &FA
	DEFB &1F, &FF, &FF, &3F, &FF, &FF, &FF, &FF

	;;	@@@@@@@@@.....@@@@@@@@@@
	;;	@@@@@@@..@@@@@..@@@@@@@@
	;;	@@@@@@.@@@@@@@@@.@@@@@@@
	;;	@@@@@.@@@@@@@@@@@.@@@@@@
	;;	@@@@.@@@@@@@@@..@.@@@@@@
	;;	@@@@.@@@@@@..@@@@@.@@@@@
	;;	@@@.@@@@@@.@@@@@@@.@@@@@
	;;	@@@.@@@@@@@@@@@.@@@@@@@@
	;;	@@@.@@@@@@@@.@@.@...@@@@
	;;	@@@.@@@@@@@@.@@@.....@@@
	;;	@....@@@@@@@@@@@.....@@@
	;;	.....@@@@@@@@@@......@@@
	;;	@...@@@@@@@@@@.@.....@@@
	;;	@...@@@.@@@@@@......@.@@
	;;	@...@@@.@@@.@@......@..@
	;;	...@@@.@@@..@@@@..@@....
	;;	@..@@@@.@@@@....@@......
	;;	@@@.@@@@..@@@@@@@.@....@
	;;	@@...@@....@@@@..@@@..@@
	;;	@@....@........@@@@@@@@@
	;;	@@@.........@@@@@@@@@@@@
	;;	@@@@@.@....@@@@@@@@@@@@@
	;;	@@@@@@@@..@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@

			;; SPR_HEAD3:     EQU &20	3x24
	DEFB &00, &00, &00, &00, &7C, &00, &01, &FF, &00, &03, &FF, &80, &07, &FF, &40, &07
	DEFB &F9, &C0, &0F, &F7, &E0, &0F, &FF, &BC, &0F, &FD, &A2, &0F, &FD, &C1, &07, &FF
	DEFB &C1, &09, &FF, &81, &0B, &FF, &41, &1B, &BF, &02, &0B, &BB, &02, &0B, &B3, &8C
	DEFB &0B, &BC, &78, &1B, &DF, &80, &05, &E6, &00, &06, &D8, &00, &07, &7C, &00, &00
	DEFB &2C, &00, &00, &18, &00, &00, &00, &00, &FF, &83, &FF, &FE, &7C, &FF, &FD, &FF
	DEFB &7F, &FB, &FF, &BF, &F7, &FF, &5F, &F7, &F9, &DF, &EF, &F7, &EF, &EF, &FF, &BF
	DEFB &EF, &FD, &A3, &EF, &FD, &C1, &F7, &FF, &C1, &E1, &FF, &81, &E3, &FF, &41, &C3
	DEFB &BF, &03, &E3, &BB, &03, &E3, &B3, &8F, &E3, &BC, &73, &C3, &DF, &87, &E1, &E6
	DEFB &7F, &F0, &C1, &FF, &F0, &41, &FF, &F8, &81, &FF, &FF, &C3, &FF, &FF, &E7, &FF

	;;	........................
	;;	.........@@@@@..........
	;;	.......@@@@@@@@@........
	;;	......@@@@@@@@@@@.......
	;;	.....@@@@@@@@@@@.@......
	;;	.....@@@@@@@@..@@@......
	;;	....@@@@@@@@.@@@@@@.....
	;;	....@@@@@@@@@@@@@.@@@@..
	;;	....@@@@@@@@@@.@@.@...@.
	;;	....@@@@@@@@@@.@@@.....@
	;;	.....@@@@@@@@@@@@@.....@
	;;	....@..@@@@@@@@@@......@
	;;	....@.@@@@@@@@@@.@.....@
	;;	...@@.@@@.@@@@@@......@.
	;;	....@.@@@.@@@.@@......@.
	;;	....@.@@@.@@..@@@...@@..
	;;	....@.@@@.@@@@...@@@@...
	;;	...@@.@@@@.@@@@@@.......
	;;	.....@.@@@@..@@.........
	;;	.....@@.@@.@@...........
	;;	.....@@@.@@@@@..........
	;;	..........@.@@..........
	;;	...........@@...........
	;;	........................
	;;
	;;	@@@@@@@@@.....@@@@@@@@@@
	;;	@@@@@@@..@@@@@..@@@@@@@@
	;;	@@@@@@.@@@@@@@@@.@@@@@@@
	;;	@@@@@.@@@@@@@@@@@.@@@@@@
	;;	@@@@.@@@@@@@@@@@.@.@@@@@
	;;	@@@@.@@@@@@@@..@@@.@@@@@
	;;	@@@.@@@@@@@@.@@@@@@.@@@@
	;;	@@@.@@@@@@@@@@@@@.@@@@@@
	;;	@@@.@@@@@@@@@@.@@.@...@@
	;;	@@@.@@@@@@@@@@.@@@.....@
	;;	@@@@.@@@@@@@@@@@@@.....@
	;;	@@@....@@@@@@@@@@......@
	;;	@@@...@@@@@@@@@@.@.....@
	;;	@@....@@@.@@@@@@......@@
	;;	@@@...@@@.@@@.@@......@@
	;;	@@@...@@@.@@..@@@...@@@@
	;;	@@@...@@@.@@@@...@@@..@@
	;;	@@....@@@@.@@@@@@....@@@
	;;	@@@....@@@@..@@..@@@@@@@
	;;	@@@@....@@.....@@@@@@@@@
	;;	@@@@.....@.....@@@@@@@@@
	;;	@@@@@...@......@@@@@@@@@
	;;	@@@@@@@@@@....@@@@@@@@@@
	;;	@@@@@@@@@@@..@@@@@@@@@@@

			;; SPR_HEADB1:     EQU &21	3x24
	DEFB &00, &00, &00, &00, &00, &00, &0F, &3E, &00, &10, &FF, &80, &21, &FF, &C0, &23
	DEFB &FF, &E0, &23, &FF, &E0, &27, &FE, &F0, &17, &BF, &F0, &17, &5F, &F0, &0C, &DF
	DEFB &F4, &03, &6F, &F0, &07, &77, &F0, &07, &6F, &F0, &0B, &6F, &F4, &3F, &6F, &E8
	DEFB &7E, &F7, &E0, &69, &CF, &C0, &37, &BF, &80, &01, &3E, &00, &00, &00, &00, &00
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &FF, &FF, &FF, &FF, &C1, &FF, &FF, &3E
	DEFB &7F, &F0, &FF, &BF, &E1, &FF, &DF, &E3, &FF, &EF, &E3, &FF, &EF, &E7, &FE, &F7
	DEFB &F7, &BF, &F7, &F7, &1F, &F3, &FC, &1F, &F1, &FB, &0F, &F3, &F7, &07, &F7, &F7
	DEFB &0F, &F3, &CB, &0F, &F1, &8F, &0F, &E3, &06, &07, &E7, &00, &0F, &DF, &80, &3F
	DEFB &BF, &C8, &3E, &7F, &FE, &C1, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF

	;;	........................
	;;	........................
	;;	....@@@@..@@@@@.........
	;;	...@....@@@@@@@@@.......
	;;	..@....@@@@@@@@@@@......
	;;	..@...@@@@@@@@@@@@@.....
	;;	..@...@@@@@@@@@@@@@.....
	;;	..@..@@@@@@@@@@.@@@@....
	;;	...@.@@@@.@@@@@@@@@@....
	;;	...@.@@@.@.@@@@@@@@@....
	;;	....@@..@@.@@@@@@@@@.@..
	;;	......@@.@@.@@@@@@@@....
	;;	.....@@@.@@@.@@@@@@@....
	;;	.....@@@.@@.@@@@@@@@....
	;;	....@.@@.@@.@@@@@@@@.@..
	;;	..@@@@@@.@@.@@@@@@@.@...
	;;	.@@@@@@.@@@@.@@@@@@.....
	;;	.@@.@..@@@..@@@@@@......
	;;	..@@.@@@@.@@@@@@@.......
	;;	.......@..@@@@@.........
	;;	........................
	;;	........................
	;;	........................
	;;	........................
	;;
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@.....@@@@@@@@@
	;;	@@@@@@@@..@@@@@..@@@@@@@
	;;	@@@@....@@@@@@@@@.@@@@@@
	;;	@@@....@@@@@@@@@@@.@@@@@
	;;	@@@...@@@@@@@@@@@@@.@@@@
	;;	@@@...@@@@@@@@@@@@@.@@@@
	;;	@@@..@@@@@@@@@@.@@@@.@@@
	;;	@@@@.@@@@.@@@@@@@@@@.@@@
	;;	@@@@.@@@...@@@@@@@@@..@@
	;;	@@@@@@.....@@@@@@@@@...@
	;;	@@@@@.@@....@@@@@@@@..@@
	;;	@@@@.@@@.....@@@@@@@.@@@
	;;	@@@@.@@@....@@@@@@@@..@@
	;;	@@..@.@@....@@@@@@@@...@
	;;	@...@@@@....@@@@@@@...@@
	;;	.....@@......@@@@@@..@@@
	;;	............@@@@@@.@@@@@
	;;	@.........@@@@@@@.@@@@@@
	;;	@@..@.....@@@@@..@@@@@@@
	;;	@@@@@@@.@@.....@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@

			;; SPR_HEADB2:     EQU &22	3x24
	DEFB &00, &00, &00, &00, &00, &00, &1E, &3E, &00, &21, &FF, &80, &41, &FF, &C0, &43
	DEFB &FF, &E0, &43, &FF, &E0, &47, &7F, &70, &26, &BF, &F0, &25, &CF, &F0, &14, &77
	DEFB &F0, &0B, &B7, &F0, &03, &D7, &F0, &03, &D7, &F0, &01, &DB, &F0, &07, &B7, &E0
	DEFB &0F, &6F, &E0, &1E, &EF, &C0, &1A, &2F, &80, &0C, &1E, &00, &00, &00, &00, &00
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &FF, &FF, &FF, &FF, &C1, &FF, &FE, &3E
	DEFB &7F, &E1, &FF, &BF, &C1, &FF, &DF, &C3, &FF, &EF, &C3, &FF, &EF, &C7, &7F, &77
	DEFB &E6, &3F, &F7, &E4, &0F, &F7, &F4, &07, &F7, &FB, &87, &F7, &FB, &C7, &F7, &FB
	DEFB &C7, &F7, &F9, &C3, &F7, &F7, &87, &EF, &E3, &0F, &EF, &C0, &0F, &DF, &C0, &0F
	DEFB &BF, &E1, &DE, &7F, &F3, &E1, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF

	;;	........................
	;;	........................
	;;	...@@@@...@@@@@.........
	;;	..@....@@@@@@@@@@.......
	;;	.@.....@@@@@@@@@@@......
	;;	.@....@@@@@@@@@@@@@.....
	;;	.@....@@@@@@@@@@@@@.....
	;;	.@...@@@.@@@@@@@.@@@....
	;;	..@..@@.@.@@@@@@@@@@....
	;;	..@..@.@@@..@@@@@@@@....
	;;	...@.@...@@@.@@@@@@@....
	;;	....@.@@@.@@.@@@@@@@....
	;;	......@@@@.@.@@@@@@@....
	;;	......@@@@.@.@@@@@@@....
	;;	.......@@@.@@.@@@@@@....
	;;	.....@@@@.@@.@@@@@@.....
	;;	....@@@@.@@.@@@@@@@.....
	;;	...@@@@.@@@.@@@@@@......
	;;	...@@.@...@.@@@@@.......
	;;	....@@.....@@@@.........
	;;	........................
	;;	........................
	;;	........................
	;;	........................
	;;
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@.....@@@@@@@@@
	;;	@@@@@@@...@@@@@..@@@@@@@
	;;	@@@....@@@@@@@@@@.@@@@@@
	;;	@@.....@@@@@@@@@@@.@@@@@
	;;	@@....@@@@@@@@@@@@@.@@@@
	;;	@@....@@@@@@@@@@@@@.@@@@
	;;	@@...@@@.@@@@@@@.@@@.@@@
	;;	@@@..@@...@@@@@@@@@@.@@@
	;;	@@@..@......@@@@@@@@.@@@
	;;	@@@@.@.......@@@@@@@.@@@
	;;	@@@@@.@@@....@@@@@@@.@@@
	;;	@@@@@.@@@@...@@@@@@@.@@@
	;;	@@@@@.@@@@...@@@@@@@.@@@
	;;	@@@@@..@@@....@@@@@@.@@@
	;;	@@@@.@@@@....@@@@@@.@@@@
	;;	@@@...@@....@@@@@@@.@@@@
	;;	@@..........@@@@@@.@@@@@
	;;	@@..........@@@@@.@@@@@@
	;;	@@@....@@@.@@@@..@@@@@@@
	;;	@@@@..@@@@@....@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@

			;; SPR_HEADB3:     EQU &23	3x24
	DEFB &00, &00, &00, &00, &00, &00, &07, &3E, &00, &08, &FF, &80, &11, &FF, &C0, &13
	DEFB &FF, &E0, &13, &FF, &E8, &17, &FD, &F0, &0F, &7F, &F0, &0E, &BF, &F6, &01, &BF
	DEFB &F4, &06, &DF, &F0, &0E, &EF, &F4, &0E, &DF, &F6, &2E, &DF, &F4, &7E, &DF, &E8
	DEFB &6D, &EF, &E0, &33, &1F, &C0, &02, &FF, &80, &00, &3E, &00, &00, &00, &00, &00
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &FF, &FF, &FF, &FF, &C1, &FF, &FF, &3E
	DEFB &7F, &F8, &FF, &BF, &F1, &FF, &DF, &F3, &FF, &E7, &F3, &FF, &E3, &F7, &FD, &F7
	DEFB &FF, &7F, &F1, &FE, &3F, &F0, &F8, &3F, &F1, &F6, &1F, &F3, &EE, &0F, &F1, &CE
	DEFB &1F, &F0, &8E, &1F, &F1, &0E, &1F, &E3, &0C, &0F, &E7, &80, &1F, &DF, &C8, &FF
	DEFB &BF, &FD, &3E, &7F, &FF, &C1, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF

	;;	........................
	;;	........................
	;;	.....@@@..@@@@@.........
	;;	....@...@@@@@@@@@.......
	;;	...@...@@@@@@@@@@@......
	;;	...@..@@@@@@@@@@@@@.....
	;;	...@..@@@@@@@@@@@@@.@...
	;;	...@.@@@@@@@@@.@@@@@....
	;;	....@@@@.@@@@@@@@@@@....
	;;	....@@@.@.@@@@@@@@@@.@@.
	;;	.......@@.@@@@@@@@@@.@..
	;;	.....@@.@@.@@@@@@@@@....
	;;	....@@@.@@@.@@@@@@@@.@..
	;;	....@@@.@@.@@@@@@@@@.@@.
	;;	..@.@@@.@@.@@@@@@@@@.@..
	;;	.@@@@@@.@@.@@@@@@@@.@...
	;;	.@@.@@.@@@@.@@@@@@@.....
	;;	..@@..@@...@@@@@@@......
	;;	......@.@@@@@@@@@.......
	;;	..........@@@@@.........
	;;	........................
	;;	........................
	;;	........................
	;;	........................
	;;
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@.....@@@@@@@@@
	;;	@@@@@@@@..@@@@@..@@@@@@@
	;;	@@@@@...@@@@@@@@@.@@@@@@
	;;	@@@@...@@@@@@@@@@@.@@@@@
	;;	@@@@..@@@@@@@@@@@@@..@@@
	;;	@@@@..@@@@@@@@@@@@@...@@
	;;	@@@@.@@@@@@@@@.@@@@@.@@@
	;;	@@@@@@@@.@@@@@@@@@@@...@
	;;	@@@@@@@...@@@@@@@@@@....
	;;	@@@@@.....@@@@@@@@@@...@
	;;	@@@@.@@....@@@@@@@@@..@@
	;;	@@@.@@@.....@@@@@@@@...@
	;;	@@..@@@....@@@@@@@@@....
	;;	@...@@@....@@@@@@@@@...@
	;;	....@@@....@@@@@@@@...@@
	;;	....@@......@@@@@@@..@@@
	;;	@..........@@@@@@@.@@@@@
	;;	@@..@...@@@@@@@@@.@@@@@@
	;;	@@@@@@.@..@@@@@..@@@@@@@
	;;	@@@@@@@@@@.....@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@

						;; SPR_VAPE1:      EQU &24
	DEFB &00, &00, &00, &00, &00, &00, &00, &1D, &80, &07, &BE, &80, &0F, &DE, &78, &0F
	DEFB &C0, &FC, &0F, &9C, &7C, &0F, &7B, &BC, &06, &F7, &DC, &18, &F7, &D8, &3D, &FB
	DEFB &A4, &3D, &9C, &6E, &38, &6F, &EE, &17, &AF, &0E, &0F, &DE, &F4, &0F, &DD, &F8
	DEFB &2F, &DD, &F8, &2F, &D1, &F8, &07, &AD, &F8, &30, &5E, &F0, &36, &DF, &00, &03
	DEFB &0E, &00, &00, &00, &00, &00, &00, &00, &FF, &FF, &FF, &FF, &E2, &7F, &F8, &5C
	DEFB &3F, &F7, &BE, &07, &EF, &DE, &7B, &EF, &C0, &FD, &EF, &94, &7D, &EF, &2B, &BD
	DEFB &E6, &57, &DD, &C0, &A7, &DB, &81, &53, &81, &80, &88, &20, &80, &65, &40, &C7
	DEFB &AA, &00, &EF, &D4, &F1, &CF, &C9, &FB, &AF, &D5, &FB, &AF, &C1, &FB, &C7, &A1
	DEFB &FB, &B0, &40, &F7, &B0, &C0, &0F, &C8, &20, &FF, &FC, &F1, &FF, &FF, &FF, &FF

	;;	........................
	;;	........................
	;;	...........@@@.@@.......
	;;	.....@@@@.@@@@@.@.......
	;;	....@@@@@@.@@@@..@@@@...
	;;	....@@@@@@......@@@@@@..
	;;	....@@@@@..@@@...@@@@@..
	;;	....@@@@.@@@@.@@@.@@@@..
	;;	.....@@.@@@@.@@@@@.@@@..
	;;	...@@...@@@@.@@@@@.@@...
	;;	..@@@@.@@@@@@.@@@.@..@..
	;;	..@@@@.@@..@@@...@@.@@@.
	;;	..@@@....@@.@@@@@@@.@@@.
	;;	...@.@@@@.@.@@@@....@@@.
	;;	....@@@@@@.@@@@.@@@@.@..
	;;	....@@@@@@.@@@.@@@@@@...
	;;	..@.@@@@@@.@@@.@@@@@@...
	;;	..@.@@@@@@.@...@@@@@@...
	;;	.....@@@@.@.@@.@@@@@@...
	;;	..@@.....@.@@@@.@@@@....
	;;	..@@.@@.@@.@@@@@........
	;;	......@@....@@@.........
	;;	........................
	;;	........................
	;;
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@...@..@@@@@@@
	;;	@@@@@....@.@@@....@@@@@@
	;;	@@@@.@@@@.@@@@@......@@@
	;;	@@@.@@@@@@.@@@@..@@@@.@@
	;;	@@@.@@@@@@......@@@@@@.@
	;;	@@@.@@@@@..@.@...@@@@@.@
	;;	@@@.@@@@..@.@.@@@.@@@@.@
	;;	@@@..@@..@.@.@@@@@.@@@.@
	;;	@@......@.@..@@@@@.@@.@@
	;;	@......@.@.@..@@@......@
	;;	@.......@...@.....@.....
	;;	@........@@..@.@.@......
	;;	@@...@@@@.@.@.@.........
	;;	@@@.@@@@@@.@.@..@@@@...@
	;;	@@..@@@@@@..@..@@@@@@.@@
	;;	@.@.@@@@@@.@.@.@@@@@@.@@
	;;	@.@.@@@@@@.....@@@@@@.@@
	;;	@@...@@@@.@....@@@@@@.@@
	;;	@.@@.....@......@@@@.@@@
	;;	@.@@....@@..........@@@@
	;;	@@..@.....@.....@@@@@@@@
	;;	@@@@@@..@@@@...@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@

						;; SPR_VAPE2:      EQU &25
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &1C, &80, &03, &BE, &00, &07
	DEFB &DE, &70, &07, &C0, &F8, &07, &BB, &78, &03, &77, &B8, &00, &F7, &B0, &18, &FB
	DEFB &08, &3C, &50, &3C, &3C, &2F, &BC, &1B, &9F, &D8, &07, &DF, &00, &07, &DE, &E0
	DEFB &27, &CD, &F0, &03, &81, &F0, &00, &0C, &E0, &13, &5E, &00, &03, &0C, &00, &00
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &E3
	DEFB &7F, &FC, &5C, &3F, &FB, &BE, &0F, &F7, &DE, &77, &F7, &C0, &FB, &F7, &AB, &7B
	DEFB &FB, &57, &BB, &E4, &A7, &B7, &C2, &53, &43, &81, &00, &01, &80, &25, &01, &C3
	DEFB &8A, &83, &E7, &D5, &07, &D7, &CA, &EF, &A7, &C5, &F7, &DB, &B1, &F7, &EC, &20
	DEFB &EF, &D0, &40, &1F, &E8, &21, &FF, &FC, &F3, &FF, &FF, &FF, &FF, &FF, &FF, &FF

	;;	........................
	;;	........................
	;;	........................
	;;	...........@@@..@.......
	;;	......@@@.@@@@@.........
	;;	.....@@@@@.@@@@..@@@....
	;;	.....@@@@@......@@@@@...
	;;	.....@@@@.@@@.@@.@@@@...
	;;	......@@.@@@.@@@@.@@@...
	;;	........@@@@.@@@@.@@....
	;;	...@@...@@@@@.@@....@...
	;;	..@@@@...@.@......@@@@..
	;;	..@@@@....@.@@@@@.@@@@..
	;;	...@@.@@@..@@@@@@@.@@...
	;;	.....@@@@@.@@@@@........
	;;	.....@@@@@.@@@@.@@@.....
	;;	..@..@@@@@..@@.@@@@@....
	;;	......@@@......@@@@@....
	;;	............@@..@@@.....
	;;	...@..@@.@.@@@@.........
	;;	......@@....@@..........
	;;	........................
	;;	........................
	;;	........................
	;;
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@...@@.@@@@@@@
	;;	@@@@@@...@.@@@....@@@@@@
	;;	@@@@@.@@@.@@@@@.....@@@@
	;;	@@@@.@@@@@.@@@@..@@@.@@@
	;;	@@@@.@@@@@......@@@@@.@@
	;;	@@@@.@@@@.@.@.@@.@@@@.@@
	;;	@@@@@.@@.@.@.@@@@.@@@.@@
	;;	@@@..@..@.@..@@@@.@@.@@@
	;;	@@....@..@.@..@@.@....@@
	;;	@......@...............@
	;;	@.........@..@.@.......@
	;;	@@....@@@...@.@.@.....@@
	;;	@@@..@@@@@.@.@.@.....@@@
	;;	@@.@.@@@@@..@.@.@@@.@@@@
	;;	@.@..@@@@@...@.@@@@@.@@@
	;;	@@.@@.@@@.@@...@@@@@.@@@
	;;	@@@.@@....@.....@@@.@@@@
	;;	@@.@.....@.........@@@@@
	;;	@@@.@.....@....@@@@@@@@@
	;;	@@@@@@..@@@@..@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@

						;; SPR_VAPE3:      EQU &26
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &08, &00, &00, &1C, &00, &01
	DEFB &08, &00, &03, &80, &20, &01, &00, &70, &00, &33, &20, &00, &7B, &00, &00, &78
	DEFB &00, &18, &30, &18, &18, &03, &18, &00, &07, &80, &01, &07, &80, &03, &83, &00
	DEFB &01, &00, &C0, &00, &00, &C0, &00, &0C, &00, &01, &0C, &00, &00, &00, &00, &00
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &F7
	DEFB &FF, &FF, &EB, &FF, &FE, &DD, &FF, &FD, &6B, &DF, &FB, &B7, &AF, &FD, &4C, &77
	DEFB &FE, &A3, &2F, &FF, &53, &5F, &E7, &28, &E7, &C3, &94, &C3, &C3, &C9, &43, &E6
	DEFB &F2, &A7, &FD, &75, &3F, &FB, &BA, &3F, &FD, &7C, &DF, &FE, &F2, &DF, &FE, &E1
	DEFB &3F, &FC, &61, &FF, &FE, &F3, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF

	;;	........................
	;;	........................
	;;	........................
	;;	............@...........
	;;	...........@@@..........
	;;	.......@....@...........
	;;	......@@@.........@.....
	;;	.......@.........@@@....
	;;	..........@@..@@..@.....
	;;	.........@@@@.@@........
	;;	.........@@@@...........
	;;	...@@.....@@.......@@...
	;;	...@@.........@@...@@...
	;;	.............@@@@.......
	;;	.......@.....@@@@.......
	;;	......@@@.....@@........
	;;	.......@........@@......
	;;	................@@......
	;;	............@@..........
	;;	.......@....@@..........
	;;	........................
	;;	........................
	;;	........................
	;;	........................
	;;
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@.@@@@@@@@@@@
	;;	@@@@@@@@@@@.@.@@@@@@@@@@
	;;	@@@@@@@.@@.@@@.@@@@@@@@@
	;;	@@@@@@.@.@@.@.@@@@.@@@@@
	;;	@@@@@.@@@.@@.@@@@.@.@@@@
	;;	@@@@@@.@.@..@@...@@@.@@@
	;;	@@@@@@@.@.@...@@..@.@@@@
	;;	@@@@@@@@.@.@..@@.@.@@@@@
	;;	@@@..@@@..@.@...@@@..@@@
	;;	@@....@@@..@.@..@@....@@
	;;	@@....@@@@..@..@.@....@@
	;;	@@@..@@.@@@@..@.@.@..@@@
	;;	@@@@@@.@.@@@.@.@..@@@@@@
	;;	@@@@@.@@@.@@@.@...@@@@@@
	;;	@@@@@@.@.@@@@@..@@.@@@@@
	;;	@@@@@@@.@@@@..@.@@.@@@@@
	;;	@@@@@@@.@@@....@..@@@@@@
	;;	@@@@@@...@@....@@@@@@@@@
	;;	@@@@@@@.@@@@..@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@

							;; SPR_PURSE:      EQU &27
	DEFB &00, &00, &00, &00, &00, &00, &00, &13, &00, &00, &38, &E0, &00, &3B, &F0, &01
	DEFB &D7, &10, &07, &3C, &E0, &0C, &F3, &F0, &0B, &CF, &F4, &0B, &BE, &74, &0B, &7D
	DEFB &B6, &2B, &3D, &AE, &2B, &5E, &6E, &6F, &67, &9D, &6B, &38, &71, &66, &BF, &C2
	DEFB &80, &DF, &0E, &88, &5C, &3C, &7E, &20, &F8, &3F, &A3, &E0, &3F, &DF, &80, &1F
	DEFB &BC, &00, &07, &40, &00, &00, &00, &00, &FF, &FF, &FF, &FF, &EC, &FF, &FF, &D3
	DEFB &1F, &FF, &B8, &EF, &FE, &3B, &F7, &F9, &D7, &17, &F7, &3C, &0F, &EC, &F0, &03
	DEFB &EB, &C0, &01, &EB, &80, &01, &CB, &01, &80, &8B, &01, &80, &8B, &00, &00, &0F
	DEFB &00, &00, &0B, &00, &00, &06, &00, &00, &00, &00, &00, &00, &00, &01, &00, &00
	DEFB &03, &80, &00, &07, &80, &00, &1F, &C0, &00, &7F, &E0, &03, &FF, &F8, &BF, &FF

	;;	........................
	;;	........................
	;;	...........@..@@........
	;;	..........@@@...@@@.....
	;;	..........@@@.@@@@@@....
	;;	.......@@@.@.@@@...@....
	;;	.....@@@..@@@@..@@@.....
	;;	....@@..@@@@..@@@@@@....
	;;	....@.@@@@..@@@@@@@@.@..
	;;	....@.@@@.@@@@@..@@@.@..
	;;	....@.@@.@@@@@.@@.@@.@@.
	;;	..@.@.@@..@@@@.@@.@.@@@.
	;;	..@.@.@@.@.@@@@..@@.@@@.
	;;	.@@.@@@@.@@..@@@@..@@@.@
	;;	.@@.@.@@..@@@....@@@...@
	;;	.@@..@@.@.@@@@@@@@....@.
	;;	@.......@@.@@@@@....@@@.
	;;	@...@....@.@@@....@@@@..
	;;	.@@@@@@...@.....@@@@@...
	;;	..@@@@@@@.@...@@@@@.....
	;;	..@@@@@@@@.@@@@@@.......
	;;	...@@@@@@.@@@@..........
	;;	.....@@@.@..............
	;;	........................
	;;
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@.@@..@@@@@@@@
	;;	@@@@@@@@@@.@..@@...@@@@@
	;;	@@@@@@@@@.@@@...@@@.@@@@
	;;	@@@@@@@...@@@.@@@@@@.@@@
	;;	@@@@@..@@@.@.@@@...@.@@@
	;;	@@@@.@@@..@@@@......@@@@
	;;	@@@.@@..@@@@..........@@
	;;	@@@.@.@@@@.............@
	;;	@@@.@.@@@..............@
	;;	@@..@.@@.......@@.......
	;;	@...@.@@.......@@.......
	;;	@...@.@@................
	;;	....@@@@................
	;;	....@.@@................
	;;	.....@@.................
	;;	........................
	;;	.......................@
	;;	......................@@
	;;	@....................@@@
	;;	@..................@@@@@
	;;	@@...............@@@@@@@
	;;	@@@...........@@@@@@@@@@
	;;	@@@@@...@.@@@@@@@@@@@@@@

							;; SPR_HOOTER:     EQU &28
	DEFB &00, &00, &00, &03, &C0, &00, &07, &F0, &00, &16, &78, &00, &20, &B8, &00, &20
	DEFB &3C, &00, &10, &DD, &00, &2D, &99, &80, &20, &E7, &00, &11, &30, &80, &2C, &CF
	DEFB &00, &21, &1E, &F8, &11, &DD, &8C, &11, &DF, &3E, &0F, &EA, &5E, &01, &F6, &DA
	DEFB &01, &FA, &3E, &01, &FB, &76, &01, &FD, &8C, &00, &FE, &F8, &01, &3C, &00, &00
	DEFB &C3, &00, &00, &3C, &00, &00, &00, &00, &FC, &3F, &FF, &FB, &CF, &FF, &F7, &F7
	DEFB &FF, &F6, &7B, &FF, &E0, &BB, &FF, &E0, &3C, &FF, &F0, &1C, &7F, &EC, &18, &3F
	DEFB &E0, &00, &7F, &F1, &00, &BF, &EC, &CF, &07, &E0, &1E, &FB, &F0, &1D, &8D, &F0
	DEFB &1F, &3E, &FE, &0A, &1E, &FC, &06, &1A, &FC, &02, &3E, &FC, &03, &76, &FC, &01
	DEFB &8D, &FE, &00, &FB, &FD, &00, &07, &FE, &C3, &7F, &FF, &3C, &FF, &FF, &C3, &FF

	;;	........................
	;;	......@@@@..............
	;;	.....@@@@@@@............
	;;	...@.@@..@@@@...........
	;;	..@.....@.@@@...........
	;;	..@.......@@@@..........
	;;	...@....@@.@@@.@........
	;;	..@.@@.@@..@@..@@.......
	;;	..@.....@@@..@@@........
	;;	...@...@..@@....@.......
	;;	..@.@@..@@..@@@@........
	;;	..@....@...@@@@.@@@@@...
	;;	...@...@@@.@@@.@@...@@..
	;;	...@...@@@.@@@@@..@@@@@.
	;;	....@@@@@@@.@.@..@.@@@@.
	;;	.......@@@@@.@@.@@.@@.@.
	;;	.......@@@@@@.@...@@@@@.
	;;	.......@@@@@@.@@.@@@.@@.
	;;	.......@@@@@@@.@@...@@..
	;;	........@@@@@@@.@@@@@...
	;;	.......@..@@@@..........
	;;	........@@....@@........
	;;	..........@@@@..........
	;;	........................
	;;
	;;	@@@@@@....@@@@@@@@@@@@@@
	;;	@@@@@.@@@@..@@@@@@@@@@@@
	;;	@@@@.@@@@@@@.@@@@@@@@@@@
	;;	@@@@.@@..@@@@.@@@@@@@@@@
	;;	@@@.....@.@@@.@@@@@@@@@@
	;;	@@@.......@@@@..@@@@@@@@
	;;	@@@@.......@@@...@@@@@@@
	;;	@@@.@@.....@@.....@@@@@@
	;;	@@@..............@@@@@@@
	;;	@@@@...@........@.@@@@@@
	;;	@@@.@@..@@..@@@@.....@@@
	;;	@@@........@@@@.@@@@@.@@
	;;	@@@@.......@@@.@@...@@.@
	;;	@@@@.......@@@@@..@@@@@.
	;;	@@@@@@@.....@.@....@@@@.
	;;	@@@@@@.......@@....@@.@.
	;;	@@@@@@........@...@@@@@.
	;;	@@@@@@........@@.@@@.@@.
	;;	@@@@@@.........@@...@@.@
	;;	@@@@@@@.........@@@@@.@@
	;;	@@@@@@.@.............@@@
	;;	@@@@@@@.@@....@@.@@@@@@@
	;;	@@@@@@@@..@@@@..@@@@@@@@
	;;	@@@@@@@@@@....@@@@@@@@@@

							;; SPR_DONUTS:     EQU &29
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &03, &80, &01
	DEFB &E6, &60, &03, &B0, &30, &01, &2F, &30, &1E, &DD, &80, &3A, &19, &78, &31, &EE
	DEFB &EC, &2E, &30, &CC, &59, &AF, &7A, &72, &DD, &A6, &38, &D9, &9C, &4E, &DE, &72
	DEFB &73, &89, &CE, &1C, &E7, &38, &07, &3C, &E0, &01, &C3, &80, &00, &7E, &00, &00
	DEFB &18, &00, &00, &00, &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
	DEFB &FF, &FF, &FC, &7F, &FE, &18, &1F, &FD, &E0, &0F, &FB, &B0, &87, &E1, &2F, &07
	DEFB &DE, &DD, &87, &BA, &19, &7B, &B1, &EE, &ED, &A0, &30, &CD, &00, &2F, &78, &02
	DEFB &1D, &A0, &80, &19, &81, &00, &1E, &00, &00, &08, &00, &80, &00, &01, &E0, &00
	DEFB &07, &F8, &00, &1F, &FE, &00, &7F, &FF, &81, &FF, &FF, &E7, &FF, &FF, &FF, &FF

	;;	........................
	;;	........................
	;;	........................
	;;	........................
	;;	..............@@@.......
	;;	.......@@@@..@@..@@.....
	;;	......@@@.@@......@@....
	;;	.......@..@.@@@@..@@....
	;;	...@@@@.@@.@@@.@@.......
	;;	..@@@.@....@@..@.@@@@...
	;;	..@@...@@@@.@@@.@@@.@@..
	;;	..@.@@@...@@....@@..@@..
	;;	.@.@@..@@.@.@@@@.@@@@.@.
	;;	.@@@..@.@@.@@@.@@.@..@@.
	;;	..@@@...@@.@@..@@..@@@..
	;;	.@..@@@.@@.@@@@..@@@..@.
	;;	.@@@..@@@...@..@@@..@@@.
	;;	...@@@..@@@..@@@..@@@...
	;;	.....@@@..@@@@..@@@.....
	;;	.......@@@....@@@.......
	;;	.........@@@@@@.........
	;;	...........@@...........
	;;	........................
	;;	........................
	;;
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@...@@@@@@@
	;;	@@@@@@@....@@......@@@@@
	;;	@@@@@@.@@@@.........@@@@
	;;	@@@@@.@@@.@@....@....@@@
	;;	@@@....@..@.@@@@.....@@@
	;;	@@.@@@@.@@.@@@.@@....@@@
	;;	@.@@@.@....@@..@.@@@@.@@
	;;	@.@@...@@@@.@@@.@@@.@@.@
	;;	@.@.......@@....@@..@@.@
	;;	..........@.@@@@.@@@@...
	;;	......@....@@@.@@.@.....
	;;	@..........@@..@@......@
	;;	...........@@@@.........
	;;	............@...........
	;;	@......................@
	;;	@@@..................@@@
	;;	@@@@@..............@@@@@
	;;	@@@@@@@..........@@@@@@@
	;;	@@@@@@@@@......@@@@@@@@@
	;;	@@@@@@@@@@@..@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@

							;; SPR_BUNNY:      EQU &2A
	DEFB &00, &00, &00, &00, &3C, &00, &00, &F8, &00, &01, &F0, &F0, &01, &CF, &38, &03
	DEFB &BF, &D8, &02, &3F, &00, &01, &F8, &FE, &07, &F7, &FC, &0F, &EF, &F0, &1B, &FF
	DEFB &C8, &19, &78, &38, &17, &3D, &F0, &21, &FF, &7C, &28, &FE, &76, &31, &9F, &0E
	DEFB &5B, &DF, &BE, &6B, &BB, &BC, &30, &71, &9C, &00, &0F, &80, &00, &77, &00, &00
	DEFB &7E, &00, &00, &38, &00, &00, &00, &00, &FF, &C3, &FF, &FF, &3D, &FF, &FE, &FB
	DEFB &0F, &FD, &F0, &F7, &FD, &CF, &3B, &FB, &BF, &DB, &FA, &3F, &01, &F9, &F8, &FE
	DEFB &F7, &F7, &FD, &EF, &EF, &F3, &DB, &FF, &CB, &D9, &78, &3B, &D7, &3D, &F3, &A1
	DEFB &FF, &7D, &A0, &FE, &76, &B1, &9F, &0E, &5B, &DF, &BE, &6B, &BB, &BD, &B4, &71
	DEFB &9D, &CF, &8F, &A3, &FF, &77, &7F, &FF, &7E, &FF, &FF, &B9, &FF, &FF, &C7, &FF

	;;	........................
	;;	..........@@@@..........
	;;	........@@@@@...........
	;;	.......@@@@@....@@@@....
	;;	.......@@@..@@@@..@@@...
	;;	......@@@.@@@@@@@@.@@...
	;;	......@...@@@@@@........
	;;	.......@@@@@@...@@@@@@@.
	;;	.....@@@@@@@.@@@@@@@@@..
	;;	....@@@@@@@.@@@@@@@@....
	;;	...@@.@@@@@@@@@@@@..@...
	;;	...@@..@.@@@@.....@@@...
	;;	...@.@@@..@@@@.@@@@@....
	;;	..@....@@@@@@@@@.@@@@@..
	;;	..@.@...@@@@@@@..@@@.@@.
	;;	..@@...@@..@@@@@....@@@.
	;;	.@.@@.@@@@.@@@@@@.@@@@@.
	;;	.@@.@.@@@.@@@.@@@.@@@@..
	;;	..@@.....@@@...@@..@@@..
	;;	............@@@@@.......
	;;	.........@@@.@@@........
	;;	.........@@@@@@.........
	;;	..........@@@...........
	;;	........................
	;;
	;;	@@@@@@@@@@....@@@@@@@@@@
	;;	@@@@@@@@..@@@@.@@@@@@@@@
	;;	@@@@@@@.@@@@@.@@....@@@@
	;;	@@@@@@.@@@@@....@@@@.@@@
	;;	@@@@@@.@@@..@@@@..@@@.@@
	;;	@@@@@.@@@.@@@@@@@@.@@.@@
	;;	@@@@@.@...@@@@@@.......@
	;;	@@@@@..@@@@@@...@@@@@@@.
	;;	@@@@.@@@@@@@.@@@@@@@@@.@
	;;	@@@.@@@@@@@.@@@@@@@@..@@
	;;	@@.@@.@@@@@@@@@@@@..@.@@
	;;	@@.@@..@.@@@@.....@@@.@@
	;;	@@.@.@@@..@@@@.@@@@@..@@
	;;	@.@....@@@@@@@@@.@@@@@.@
	;;	@.@.....@@@@@@@..@@@.@@.
	;;	@.@@...@@..@@@@@....@@@.
	;;	.@.@@.@@@@.@@@@@@.@@@@@.
	;;	.@@.@.@@@.@@@.@@@.@@@@.@
	;;	@.@@.@...@@@...@@..@@@.@
	;;	@@..@@@@@...@@@@@.@...@@
	;;	@@@@@@@@.@@@.@@@.@@@@@@@
	;;	@@@@@@@@.@@@@@@.@@@@@@@@
	;;	@@@@@@@@@.@@@..@@@@@@@@@
	;;	@@@@@@@@@@...@@@@@@@@@@@

							;; SPR_SPRING:     EQU &2B
	DEFB &00, &00, &00, &00, &3C, &00, &01, &FF, &80, &07, &FF, &E0, &0F, &FF, &F0, &1F
	DEFB &FF, &F8, &0F, &FF, &F0, &17, &FF, &E8, &09, &FF, &90, &06, &3C, &68, &19, &C3
	DEFB &8C, &30, &3C, &6C, &30, &40, &1C, &19, &CE, &38, &0E, &01, &E4, &13, &CF, &06
	DEFB &30, &78, &66, &30, &00, &0C, &18, &00, &38, &0E, &01, &E4, &03, &CF, &0C, &00
	DEFB &78, &00, &00, &00, &00, &00, &00, &00, &FF, &C3, &FF, &FE, &3C, &7F, &F9, &DB
	DEFB &9F, &F6, &A5, &6F, &ED, &5A, &B7, &DA, &A5, &5B, &ED, &5A, &B7, &C6, &A5, &63
	DEFB &E1, &DB, &87, &E0, &3C, &0B, &D8, &00, &0D, &B6, &00, &6D, &B6, &41, &9D, &D9
	DEFB &CE, &3B, &EE, &31, &E5, &D3, &CF, &16, &B4, &78, &66, &B7, &87, &8D, &D9, &FE
	DEFB &3B, &EE, &31, &E5, &F3, &CF, &0D, &FC, &78, &F3, &FF, &87, &FF, &FF, &FF, &FF

	;;	........................
	;;	..........@@@@..........
	;;	.......@@@@@@@@@@.......
	;;	.....@@@@@@@@@@@@@@.....
	;;	....@@@@@@@@@@@@@@@@....
	;;	...@@@@@@@@@@@@@@@@@@...
	;;	....@@@@@@@@@@@@@@@@....
	;;	...@.@@@@@@@@@@@@@@.@...
	;;	....@..@@@@@@@@@@..@....
	;;	.....@@...@@@@...@@.@...
	;;	...@@..@@@....@@@...@@..
	;;	..@@......@@@@...@@.@@..
	;;	..@@.....@.........@@@..
	;;	...@@..@@@..@@@...@@@...
	;;	....@@@........@@@@..@..
	;;	...@..@@@@..@@@@.....@@.
	;;	..@@.....@@@@....@@..@@.
	;;	..@@................@@..
	;;	...@@.............@@@...
	;;	....@@@........@@@@..@..
	;;	......@@@@..@@@@....@@..
	;;	.........@@@@...........
	;;	........................
	;;	........................
	;;
	;;	@@@@@@@@@@....@@@@@@@@@@
	;;	@@@@@@@...@@@@...@@@@@@@
	;;	@@@@@..@@@.@@.@@@..@@@@@
	;;	@@@@.@@.@.@..@.@.@@.@@@@
	;;	@@@.@@.@.@.@@.@.@.@@.@@@
	;;	@@.@@.@.@.@..@.@.@.@@.@@
	;;	@@@.@@.@.@.@@.@.@.@@.@@@
	;;	@@...@@.@.@..@.@.@@...@@
	;;	@@@....@@@.@@.@@@....@@@
	;;	@@@.......@@@@......@.@@
	;;	@@.@@...............@@.@
	;;	@.@@.@@..........@@.@@.@
	;;	@.@@.@@..@.....@@..@@@.@
	;;	@@.@@..@@@..@@@...@@@.@@
	;;	@@@.@@@...@@...@@@@..@.@
	;;	@@.@..@@@@..@@@@...@.@@.
	;;	@.@@.@...@@@@....@@..@@.
	;;	@.@@.@@@@....@@@@...@@.@
	;;	@@.@@..@@@@@@@@...@@@.@@
	;;	@@@.@@@...@@...@@@@..@.@
	;;	@@@@..@@@@..@@@@....@@.@
	;;	@@@@@@...@@@@...@@@@..@@
	;;	@@@@@@@@@....@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@

							;; SPR_SPRUNG:     EQU &2C
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &3C, &00, &01, &FF, &80, &07
	DEFB &FF, &E0, &0F, &FF, &F0, &1F, &FF, &F8, &0F, &FF, &F0, &17, &FF, &E8, &09, &FF
	DEFB &90, &16, &3C, &6C, &31, &C3, &8C, &32, &3C, &1C, &18, &00, &38, &0E, &01, &E2
	DEFB &33, &CF, &06, &30, &78, &0C, &18, &00, &38, &0E, &01, &E4, &03, &CF, &0C, &00
	DEFB &78, &00, &00, &00, &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &C3
	DEFB &FF, &FE, &3C, &7F, &F9, &DB, &9F, &F6, &A5, &6F, &ED, &5A, &B7, &DA, &A5, &5B
	DEFB &ED, &5A, &B7, &C6, &A5, &63, &E1, &DB, &83, &D0, &3C, &0D, &B0, &00, &0D, &B2
	DEFB &00, &5D, &D9, &C2, &39, &CE, &31, &E2, &B3, &CF, &16, &B4, &78, &CD, &D9, &86
	DEFB &3B, &EE, &31, &E5, &F3, &CF, &0D, &FC, &78, &F3, &FF, &87, &FF, &FF, &FF, &FF

	;;	........................
	;;	........................
	;;	........................
	;;	..........@@@@..........
	;;	.......@@@@@@@@@@.......
	;;	.....@@@@@@@@@@@@@@.....
	;;	....@@@@@@@@@@@@@@@@....
	;;	...@@@@@@@@@@@@@@@@@@...
	;;	....@@@@@@@@@@@@@@@@....
	;;	...@.@@@@@@@@@@@@@@.@...
	;;	....@..@@@@@@@@@@..@....
	;;	...@.@@...@@@@...@@.@@..
	;;	..@@...@@@....@@@...@@..
	;;	..@@..@...@@@@.....@@@..
	;;	...@@.............@@@...
	;;	....@@@........@@@@...@.
	;;	..@@..@@@@..@@@@.....@@.
	;;	..@@.....@@@@.......@@..
	;;	...@@.............@@@...
	;;	....@@@........@@@@..@..
	;;	......@@@@..@@@@....@@..
	;;	.........@@@@...........
	;;	........................
	;;	........................
	;;
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@....@@@@@@@@@@
	;;	@@@@@@@...@@@@...@@@@@@@
	;;	@@@@@..@@@.@@.@@@..@@@@@
	;;	@@@@.@@.@.@..@.@.@@.@@@@
	;;	@@@.@@.@.@.@@.@.@.@@.@@@
	;;	@@.@@.@.@.@..@.@.@.@@.@@
	;;	@@@.@@.@.@.@@.@.@.@@.@@@
	;;	@@...@@.@.@..@.@.@@...@@
	;;	@@@....@@@.@@.@@@.....@@
	;;	@@.@......@@@@......@@.@
	;;	@.@@................@@.@
	;;	@.@@..@..........@.@@@.@
	;;	@@.@@..@@@....@...@@@..@
	;;	@@..@@@...@@...@@@@...@.
	;;	@.@@..@@@@..@@@@...@.@@.
	;;	@.@@.@...@@@@...@@..@@.@
	;;	@@.@@..@@....@@...@@@.@@
	;;	@@@.@@@...@@...@@@@..@.@
	;;	@@@@..@@@@..@@@@....@@.@
	;;	@@@@@@...@@@@...@@@@..@@
	;;	@@@@@@@@@....@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@

							;; SPR_FISH1:      EQU &2D
	DEFB &00, &00, &00, &00, &38, &6C, &00, &F8, &96, &00, &DD, &8C, &71, &6D, &80, &19
	DEFB &AD, &A0, &6D, &03, &58, &34, &F8, &D8, &7B, &E0, &64, &77, &DF, &2E, &77, &FF
	DEFB &B6, &2F, &18, &B0, &2E, &36, &B6, &36, &2F, &98, &36, &3E, &3E, &3B, &29, &BA
	DEFB &31, &B3, &30, &20, &DC, &64, &21, &67, &CC, &07, &98, &B8, &03, &67, &00, &00
	DEFB &E0, &00, &00, &60, &00, &00, &00, &00, &FF, &C7, &93, &FF, &03, &61, &FE, &02
	DEFB &84, &8E, &01, &A1, &74, &01, &93, &98, &01, &A7, &0C, &03, &5B, &84, &F8, &DB
	DEFB &03, &E0, &65, &07, &DF, &2E, &07, &FF, &B6, &8F, &18, &B1, &8E, &36, &B6, &86
	DEFB &2F, &99, &86, &3E, &3E, &83, &29, &BA, &85, &B3, &31, &8E, &DC, &65, &88, &67
	DEFB &CD, &D0, &18, &BB, &F8, &07, &47, &FC, &08, &FF, &FF, &0F, &FF, &FF, &9F, &FF

	;;	........................
	;;	..........@@@....@@.@@..
	;;	........@@@@@...@..@.@@.
	;;	........@@.@@@.@@...@@..
	;;	.@@@...@.@@.@@.@@.......
	;;	...@@..@@.@.@@.@@.@.....
	;;	.@@.@@.@......@@.@.@@...
	;;	..@@.@..@@@@@...@@.@@...
	;;	.@@@@.@@@@@......@@..@..
	;;	.@@@.@@@@@.@@@@@..@.@@@.
	;;	.@@@.@@@@@@@@@@@@.@@.@@.
	;;	..@.@@@@...@@...@.@@....
	;;	..@.@@@...@@.@@.@.@@.@@.
	;;	..@@.@@...@.@@@@@..@@...
	;;	..@@.@@...@@@@@...@@@@@.
	;;	..@@@.@@..@.@..@@.@@@.@.
	;;	..@@...@@.@@..@@..@@....
	;;	..@.....@@.@@@...@@..@..
	;;	..@....@.@@..@@@@@..@@..
	;;	.....@@@@..@@...@.@@@...
	;;	......@@.@@..@@@........
	;;	........@@@.............
	;;	.........@@.............
	;;	........................
	;;
	;;	@@@@@@@@@@...@@@@..@..@@
	;;	@@@@@@@@......@@.@@....@
	;;	@@@@@@@.......@.@....@..
	;;	@...@@@........@@.@....@
	;;	.@@@.@.........@@..@..@@
	;;	@..@@..........@@.@..@@@
	;;	....@@........@@.@.@@.@@
	;;	@....@..@@@@@...@@.@@.@@
	;;	......@@@@@......@@..@.@
	;;	.....@@@@@.@@@@@..@.@@@.
	;;	.....@@@@@@@@@@@@.@@.@@.
	;;	@...@@@@...@@...@.@@...@
	;;	@...@@@...@@.@@.@.@@.@@.
	;;	@....@@...@.@@@@@..@@..@
	;;	@....@@...@@@@@...@@@@@.
	;;	@.....@@..@.@..@@.@@@.@.
	;;	@....@.@@.@@..@@..@@...@
	;;	@...@@@.@@.@@@...@@..@.@
	;;	@...@....@@..@@@@@..@@.@
	;;	@@.@.......@@...@.@@@.@@
	;;	@@@@@........@@@.@...@@@
	;;	@@@@@@......@...@@@@@@@@
	;;	@@@@@@@@....@@@@@@@@@@@@
	;;	@@@@@@@@@..@@@@@@@@@@@@@

							;; SPR_FISH2:      EQU &2E
	DEFB &00, &00, &00, &00, &38, &68, &00, &F8, &94, &18, &DD, &9C, &31, &6D, &88, &19
	DEFB &AD, &A0, &2D, &03, &58, &34, &F8, &D8, &3B, &E0, &64, &37, &DF, &2E, &17, &FF
	DEFB &B6, &2F, &18, &B0, &2E, &36, &B6, &36, &2F, &98, &36, &3E, &3E, &3B, &29, &BA
	DEFB &21, &B3, &30, &18, &DC, &64, &03, &67, &D8, &03, &18, &B0, &02, &E7, &00, &01
	DEFB &C0, &00, &00, &80, &00, &00, &00, &00, &FF, &C7, &97, &FF, &03, &63, &E6, &02
	DEFB &81, &DA, &01, &89, &B4, &01, &83, &D8, &01, &A7, &8C, &03, &5B, &84, &F8, &DB
	DEFB &83, &E0, &65, &87, &DF, &2E, &C7, &FF, &B6, &8F, &18, &B1, &8E, &36, &B6, &86
	DEFB &2F, &99, &86, &3E, &3E, &83, &29, &BA, &85, &B3, &31, &C0, &DC, &65, &E0, &67
	DEFB &DB, &F8, &18, &B7, &F8, &07, &4F, &FC, &18, &FF, &FE, &3F, &FF, &FF, &7F, &FF

	;;	........................
	;;	..........@@@....@@.@...
	;;	........@@@@@...@..@.@..
	;;	...@@...@@.@@@.@@..@@@..
	;;	..@@...@.@@.@@.@@...@...
	;;	...@@..@@.@.@@.@@.@.....
	;;	..@.@@.@......@@.@.@@...
	;;	..@@.@..@@@@@...@@.@@...
	;;	..@@@.@@@@@......@@..@..
	;;	..@@.@@@@@.@@@@@..@.@@@.
	;;	...@.@@@@@@@@@@@@.@@.@@.
	;;	..@.@@@@...@@...@.@@....
	;;	..@.@@@...@@.@@.@.@@.@@.
	;;	..@@.@@...@.@@@@@..@@...
	;;	..@@.@@...@@@@@...@@@@@.
	;;	..@@@.@@..@.@..@@.@@@.@.
	;;	..@....@@.@@..@@..@@....
	;;	...@@...@@.@@@...@@..@..
	;;	......@@.@@..@@@@@.@@...
	;;	......@@...@@...@.@@....
	;;	......@.@@@..@@@........
	;;	.......@@@..............
	;;	........@...............
	;;	........................
	;;
	;;	@@@@@@@@@@...@@@@..@.@@@
	;;	@@@@@@@@......@@.@@...@@
	;;	@@@..@@.......@.@......@
	;;	@@.@@.@........@@...@..@
	;;	@.@@.@.........@@.....@@
	;;	@@.@@..........@@.@..@@@
	;;	@...@@........@@.@.@@.@@
	;;	@....@..@@@@@...@@.@@.@@
	;;	@.....@@@@@......@@..@.@
	;;	@....@@@@@.@@@@@..@.@@@.
	;;	@@...@@@@@@@@@@@@.@@.@@.
	;;	@...@@@@...@@...@.@@...@
	;;	@...@@@...@@.@@.@.@@.@@.
	;;	@....@@...@.@@@@@..@@..@
	;;	@....@@...@@@@@...@@@@@.
	;;	@.....@@..@.@..@@.@@@.@.
	;;	@....@.@@.@@..@@..@@...@
	;;	@@......@@.@@@...@@..@.@
	;;	@@@......@@..@@@@@.@@.@@
	;;	@@@@@......@@...@.@@.@@@
	;;	@@@@@........@@@.@..@@@@
	;;	@@@@@@.....@@...@@@@@@@@
	;;	@@@@@@@...@@@@@@@@@@@@@@
	;;	@@@@@@@@.@@@@@@@@@@@@@@@

							;; SPR_CROWN:      EQU &2F
	DEFB &00, &00, &00, &02, &70, &00, &05, &FC, &00, &07, &FE, &00, &09, &BE, &10, &3E
	DEFB &7E, &7C, &63, &BD, &C6, &40, &5A, &02, &47, &66, &E2, &4F, &99, &F2, &6F, &AD
	DEFB &F6, &2F, &BD, &F4, &2F, &AD, &F4, &2F, &DB, &F4, &4F, &DB, &F2, &77, &DB, &EE
	DEFB &73, &DB, &CE, &6C, &99, &36, &2F, &5A, &F4, &0F, &66, &F0, &03, &7E, &C0, &00
	DEFB &7E, &00, &00, &3C, &00, &00, &00, &00, &FD, &8F, &FF, &F8, &03, &FF, &F0, &01
	DEFB &FF, &F0, &00, &EF, &C8, &00, &93, &BE, &00, &7D, &63, &81, &C6, &58, &42, &1A
	DEFB &51, &66, &8A, &44, &18, &22, &61, &0C, &86, &A4, &1C, &25, &A1, &0C, &85, &A4
	DEFB &4A, &25, &01, &08, &82, &30, &4A, &06, &30, &08, &06, &24, &08, &36, &87, &0A
	DEFB &71, &C7, &26, &73, &F3, &3E, &0F, &FC, &3E, &3F, &FF, &9D, &FF, &FF, &C3, &FF

	;;	........................
	;;	......@..@@@............
	;;	.....@.@@@@@@@..........
	;;	.....@@@@@@@@@@.........
	;;	....@..@@.@@@@@....@....
	;;	..@@@@@..@@@@@@..@@@@@..
	;;	.@@...@@@.@@@@.@@@...@@.
	;;	.@.......@.@@.@.......@.
	;;	.@...@@@.@@..@@.@@@...@.
	;;	.@..@@@@@..@@..@@@@@..@.
	;;	.@@.@@@@@.@.@@.@@@@@.@@.
	;;	..@.@@@@@.@@@@.@@@@@.@..
	;;	..@.@@@@@.@.@@.@@@@@.@..
	;;	..@.@@@@@@.@@.@@@@@@.@..
	;;	.@..@@@@@@.@@.@@@@@@..@.
	;;	.@@@.@@@@@.@@.@@@@@.@@@.
	;;	.@@@..@@@@.@@.@@@@..@@@.
	;;	.@@.@@..@..@@..@..@@.@@.
	;;	..@.@@@@.@.@@.@.@@@@.@..
	;;	....@@@@.@@..@@.@@@@....
	;;	......@@.@@@@@@.@@......
	;;	.........@@@@@@.........
	;;	..........@@@@..........
	;;	........................
	;;
	;;	@@@@@@.@@...@@@@@@@@@@@@
	;;	@@@@@.........@@@@@@@@@@
	;;	@@@@...........@@@@@@@@@
	;;	@@@@............@@@.@@@@
	;;	@@..@...........@..@..@@
	;;	@.@@@@@..........@@@@@.@
	;;	.@@...@@@......@@@...@@.
	;;	.@.@@....@....@....@@.@.
	;;	.@.@...@.@@..@@.@...@.@.
	;;	.@...@.....@@.....@...@.
	;;	.@@....@....@@..@....@@.
	;;	@.@..@.....@@@....@..@.@
	;;	@.@....@....@@..@....@.@
	;;	@.@..@...@..@.@...@..@.@
	;;	.......@....@...@.....@.
	;;	..@@.....@..@.@......@@.
	;;	..@@........@........@@.
	;;	..@..@......@.....@@.@@.
	;;	@....@@@....@.@..@@@...@
	;;	@@...@@@..@..@@..@@@..@@
	;;	@@@@..@@..@@@@@.....@@@@
	;;	@@@@@@....@@@@@...@@@@@@
	;;	@@@@@@@@@..@@@.@@@@@@@@@
	;;	@@@@@@@@@@....@@@@@@@@@@

							;; SPR_SWITCH:     EQU &30
	DEFB &00, &00, &00, &07, &00, &00, &0B, &80, &00, &0F, &80, &00, &07, &3E, &00, &00
	DEFB &DF, &80, &06, &EF, &E0, &0F, &70, &F0, &1F, &00, &F8, &1F, &FF, &F8, &2F, &FF
	DEFB &F4, &2F, &FF, &F4, &13, &FF, &C8, &4C, &7E, &32, &73, &81, &CE, &7C, &7E, &3E
	DEFB &7F, &00, &FE, &7F, &C3, &FE, &3F, &E7, &FC, &0F, &E7, &F0, &03, &E7, &C0, &00
	DEFB &E7, &00, &00, &24, &00, &00, &00, &00, &F8, &FF, &FF, &F7, &7F, &FF, &EB, &BF
	DEFB &FF, &EF, &81, &FF, &F7, &00, &7F, &F8, &C0, &1F, &F0, &E0, &0F, &E0, &70, &07
	DEFB &C0, &00, &03, &C0, &00, &03, &A0, &00, &05, &A0, &00, &05, &90, &00, &09, &0C
	DEFB &00, &30, &03, &81, &C0, &00, &7E, &00, &00, &00, &00, &00, &00, &00, &80, &00
	DEFB &01, &C0, &00, &03, &F0, &00, &0F, &FC, &00, &3F, &FF, &00, &FF, &FF, &C3, &FF

	;;	........................
	;;	.....@@@................
	;;	....@.@@@...............
	;;	....@@@@@...............
	;;	.....@@@..@@@@@.........
	;;	........@@.@@@@@@.......
	;;	.....@@.@@@.@@@@@@@.....
	;;	....@@@@.@@@....@@@@....
	;;	...@@@@@........@@@@@...
	;;	...@@@@@@@@@@@@@@@@@@...
	;;	..@.@@@@@@@@@@@@@@@@.@..
	;;	..@.@@@@@@@@@@@@@@@@.@..
	;;	...@..@@@@@@@@@@@@..@...
	;;	.@..@@...@@@@@@...@@..@.
	;;	.@@@..@@@......@@@..@@@.
	;;	.@@@@@...@@@@@@...@@@@@.
	;;	.@@@@@@@........@@@@@@@.
	;;	.@@@@@@@@@....@@@@@@@@@.
	;;	..@@@@@@@@@..@@@@@@@@@..
	;;	....@@@@@@@..@@@@@@@....
	;;	......@@@@@..@@@@@......
	;;	........@@@..@@@........
	;;	..........@..@..........
	;;	........................
	;;
	;;	@@@@@...@@@@@@@@@@@@@@@@
	;;	@@@@.@@@.@@@@@@@@@@@@@@@
	;;	@@@.@.@@@.@@@@@@@@@@@@@@
	;;	@@@.@@@@@......@@@@@@@@@
	;;	@@@@.@@@.........@@@@@@@
	;;	@@@@@...@@.........@@@@@
	;;	@@@@....@@@.........@@@@
	;;	@@@......@@@.........@@@
	;;	@@....................@@
	;;	@@....................@@
	;;	@.@..................@.@
	;;	@.@..................@.@
	;;	@..@................@..@
	;;	....@@............@@....
	;;	......@@@......@@@......
	;;	.........@@@@@@.........
	;;	........................
	;;	........................
	;;	@......................@
	;;	@@....................@@
	;;	@@@@................@@@@
	;;	@@@@@@............@@@@@@
	;;	@@@@@@@@........@@@@@@@@
	;;	@@@@@@@@@@....@@@@@@@@@@

							;; SPR_GRATING:    EQU &31
	DEFB &00, &00, &00, &00, &00, &20, &00, &00, &F0, &00, &03, &C8, &00, &0F, &38, &00
	DEFB &3C, &C8, &00, &F3, &28, &03, &CC, &28, &0F, &34, &28, &14, &C4, &28, &1B, &14
	DEFB &28, &1A, &14, &28, &1A, &14, &28, &1A, &14, &C8, &1A, &15, &30, &1A, &14, &C0
	DEFB &1A, &37, &00, &1A, &CC, &00, &1A, &30, &00, &1A, &C0, &00, &0B, &00, &00, &00
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &FF, &FF, &DF, &FF, &FF, &0F, &FF, &FC
	DEFB &07, &FF, &F0, &03, &FF, &C0, &03, &FF, &00, &03, &FC, &00, &23, &F0, &00, &A3
	DEFB &E0, &01, &A3, &C0, &01, &A3, &D0, &11, &A3, &C8, &D1, &A3, &D0, &D1, &23, &C8
	DEFB &D0, &C3, &D0, &D1, &07, &C8, &D0, &0F, &D0, &30, &3F, &C8, &C0, &FF, &D0, &03
	DEFB &FF, &C8, &0F, &FF, &E0, &3F, &FF, &F0, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF

	;;	........................
	;;	..................@.....
	;;	................@@@@....
	;;	..............@@@@..@...
	;;	............@@@@..@@@...
	;;	..........@@@@..@@..@...
	;;	........@@@@..@@..@.@...
	;;	......@@@@..@@....@.@...
	;;	....@@@@..@@.@....@.@...
	;;	...@.@..@@...@....@.@...
	;;	...@@.@@...@.@....@.@...
	;;	...@@.@....@.@....@.@...
	;;	...@@.@....@.@....@.@...
	;;	...@@.@....@.@..@@..@...
	;;	...@@.@....@.@.@..@@....
	;;	...@@.@....@.@..@@......
	;;	...@@.@...@@.@@@........
	;;	...@@.@.@@..@@..........
	;;	...@@.@...@@............
	;;	...@@.@.@@..............
	;;	....@.@@................
	;;	........................
	;;	........................
	;;	........................
	;;
	;;	@@@@@@@@@@@@@@@@@@.@@@@@
	;;	@@@@@@@@@@@@@@@@....@@@@
	;;	@@@@@@@@@@@@@@.......@@@
	;;	@@@@@@@@@@@@..........@@
	;;	@@@@@@@@@@............@@
	;;	@@@@@@@@..............@@
	;;	@@@@@@............@...@@
	;;	@@@@............@.@...@@
	;;	@@@............@@.@...@@
	;;	@@.............@@.@...@@
	;;	@@.@.......@...@@.@...@@
	;;	@@..@...@@.@...@@.@...@@
	;;	@@.@....@@.@...@..@...@@
	;;	@@..@...@@.@....@@....@@
	;;	@@.@....@@.@...@.....@@@
	;;	@@..@...@@.@........@@@@
	;;	@@.@......@@......@@@@@@
	;;	@@..@...@@......@@@@@@@@
	;;	@@.@..........@@@@@@@@@@
	;;	@@..@.......@@@@@@@@@@@@
	;;	@@@.......@@@@@@@@@@@@@@
	;;	@@@@....@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@

							;; SPR_MONOCAT1:   EQU &32
	DEFB &00, &00, &00, &01, &20, &00, &07, &C8, &00, &0C, &72, &00, &13, &9C, &00, &17
	DEFB &E3, &E0, &2F, &EF, &FC, &6F, &DF, &F8, &5F, &BF, &C4, &47, &7C, &2E, &3B, &02
	DEFB &36, &3F, &75, &96, &7E, &F5, &14, &7E, &F4, &10, &7E, &FA, &24, &1D, &7D, &9C
	DEFB &65, &80, &78, &79, &9F, &F4, &7E, &47, &CC, &6A, &F0, &38, &3C, &7C, &00, &00
	DEFB &6A, &00, &00, &3C, &00, &00, &00, &00, &FE, &DF, &FF, &F9, &07, &FF, &F7, &C1
	DEFB &FF, &EC, &70, &FF, &D0, &1C, &1F, &D0, &00, &03, &A0, &00, &01, &60, &00, &01
	DEFB &40, &00, &05, &40, &00, &0E, &80, &00, &06, &80, &71, &86, &00, &F1, &05, &00
	DEFB &F0, &01, &00, &F8, &01, &80, &7C, &01, &60, &00, &03, &78, &00, &05, &7E, &40
	DEFB &0D, &6A, &F0, &3B, &BD, &7D, &C7, &C3, &6A, &FF, &FF, &BD, &FF, &FF, &C3, &FF

	;;	........................
	;;	.......@..@.............
	;;	.....@@@@@..@...........
	;;	....@@...@@@..@.........
	;;	...@..@@@..@@@..........
	;;	...@.@@@@@@...@@@@@.....
	;;	..@.@@@@@@@.@@@@@@@@@@..
	;;	.@@.@@@@@@.@@@@@@@@@@...
	;;	.@.@@@@@@.@@@@@@@@...@..
	;;	.@...@@@.@@@@@....@.@@@.
	;;	..@@@.@@......@...@@.@@.
	;;	..@@@@@@.@@@.@.@@..@.@@.
	;;	.@@@@@@.@@@@.@.@...@.@..
	;;	.@@@@@@.@@@@.@.....@....
	;;	.@@@@@@.@@@@@.@...@..@..
	;;	...@@@.@.@@@@@.@@..@@@..
	;;	.@@..@.@@........@@@@...
	;;	.@@@@..@@..@@@@@@@@@.@..
	;;	.@@@@@@..@...@@@@@..@@..
	;;	.@@.@.@.@@@@......@@@...
	;;	..@@@@...@@@@@..........
	;;	.........@@.@.@.........
	;;	..........@@@@..........
	;;	........................
	;;
	;;	@@@@@@@.@@.@@@@@@@@@@@@@
	;;	@@@@@..@.....@@@@@@@@@@@
	;;	@@@@.@@@@@.....@@@@@@@@@
	;;	@@@.@@...@@@....@@@@@@@@
	;;	@@.@.......@@@.....@@@@@
	;;	@@.@..................@@
	;;	@.@....................@
	;;	.@@....................@
	;;	.@...................@.@
	;;	.@..................@@@.
	;;	@....................@@.
	;;	@........@@@...@@....@@.
	;;	........@@@@...@.....@.@
	;;	........@@@@...........@
	;;	........@@@@@..........@
	;;	@........@@@@@.........@
	;;	.@@...................@@
	;;	.@@@@................@.@
	;;	.@@@@@@..@..........@@.@
	;;	.@@.@.@.@@@@......@@@.@@
	;;	@.@@@@.@.@@@@@.@@@...@@@
	;;	@@....@@.@@.@.@.@@@@@@@@
	;;	@@@@@@@@@.@@@@.@@@@@@@@@
	;;	@@@@@@@@@@....@@@@@@@@@@

							;; SPR_MONOCAT2:   EQU &33
	DEFB &00, &00, &00, &01, &20, &00, &07, &C8, &00, &0C, &72, &00, &13, &9C, &00, &17
	DEFB &E3, &E0, &2F, &EF, &FC, &6F, &DF, &F8, &5F, &BF, &C4, &47, &7C, &2E, &3B, &02
	DEFB &36, &3F, &75, &96, &7E, &F5, &14, &7E, &F4, &10, &7E, &FA, &24, &0D, &7D, &9C
	DEFB &71, &80, &7A, &3D, &9F, &F6, &3E, &67, &CA, &35, &78, &1C, &1E, &FC, &00, &00
	DEFB &D4, &00, &00, &78, &00, &00, &00, &00, &FE, &DF, &FF, &F9, &07, &FF, &F7, &C1
	DEFB &FF, &EC, &70, &FF, &D0, &1C, &1F, &D0, &00, &03, &A0, &00, &01, &60, &00, &01
	DEFB &40, &00, &05, &40, &00, &0E, &80, &00, &06, &80, &71, &86, &00, &F1, &05, &00
	DEFB &F0, &01, &00, &F8, &01, &80, &7C, &01, &70, &00, &02, &BC, &00, &06, &BE, &60
	DEFB &0A, &B5, &78, &1D, &DE, &FD, &E3, &E0, &D5, &FF, &FF, &7B, &FF, &FF, &87, &FF

	;;	........................
	;;	.......@..@.............
	;;	.....@@@@@..@...........
	;;	....@@...@@@..@.........
	;;	...@..@@@..@@@..........
	;;	...@.@@@@@@...@@@@@.....
	;;	..@.@@@@@@@.@@@@@@@@@@..
	;;	.@@.@@@@@@.@@@@@@@@@@...
	;;	.@.@@@@@@.@@@@@@@@...@..
	;;	.@...@@@.@@@@@....@.@@@.
	;;	..@@@.@@......@...@@.@@.
	;;	..@@@@@@.@@@.@.@@..@.@@.
	;;	.@@@@@@.@@@@.@.@...@.@..
	;;	.@@@@@@.@@@@.@.....@....
	;;	.@@@@@@.@@@@@.@...@..@..
	;;	....@@.@.@@@@@.@@..@@@..
	;;	.@@@...@@........@@@@.@.
	;;	..@@@@.@@..@@@@@@@@@.@@.
	;;	..@@@@@..@@..@@@@@..@.@.
	;;	..@@.@.@.@@@@......@@@..
	;;	...@@@@.@@@@@@..........
	;;	........@@.@.@..........
	;;	.........@@@@...........
	;;	........................
	;;
	;;	@@@@@@@.@@.@@@@@@@@@@@@@
	;;	@@@@@..@.....@@@@@@@@@@@
	;;	@@@@.@@@@@.....@@@@@@@@@
	;;	@@@.@@...@@@....@@@@@@@@
	;;	@@.@.......@@@.....@@@@@
	;;	@@.@..................@@
	;;	@.@....................@
	;;	.@@....................@
	;;	.@...................@.@
	;;	.@..................@@@.
	;;	@....................@@.
	;;	@........@@@...@@....@@.
	;;	........@@@@...@.....@.@
	;;	........@@@@...........@
	;;	........@@@@@..........@
	;;	@........@@@@@.........@
	;;	.@@@..................@.
	;;	@.@@@@...............@@.
	;;	@.@@@@@..@@.........@.@.
	;;	@.@@.@.@.@@@@......@@@.@
	;;	@@.@@@@.@@@@@@.@@@@...@@
	;;	@@@.....@@.@.@.@@@@@@@@@
	;;	@@@@@@@@.@@@@.@@@@@@@@@@
	;;	@@@@@@@@@....@@@@@@@@@@@

							;; SPR_MONOCATB1:  EQU &34
	DEFB &00, &00, &00, &00, &00, &00, &00, &3E, &00, &00, &07, &80, &07, &79, &A0, &1C
	DEFB &FE, &D0, &3B, &FE, &D8, &37, &FF, &68, &4F, &FF, &6C, &6F, &FF, &B4, &2F, &FF
	DEFB &B6, &43, &FF, &B6, &2F, &E3, &B4, &1F, &DF, &34, &3D, &FF, &B2, &3D, &FF, &B4
	DEFB &31, &BF, &B2, &0D, &BF, &4E, &1C, &81, &3E, &0E, &7E, &1C, &00, &F4, &00, &00
	DEFB &FC, &00, &00, &78, &00, &00, &00, &00, &FF, &FF, &FF, &FF, &C1, &FF, &FF, &BE
	DEFB &7F, &F8, &07, &9F, &E0, &01, &8F, &C0, &00, &C7, &80, &00, &C3, &80, &00, &63
	DEFB &40, &00, &61, &60, &00, &31, &A0, &00, &30, &00, &00, &30, &80, &00, &31, &C0
	DEFB &00, &31, &80, &00, &30, &80, &00, &31, &80, &00, &32, &CC, &00, &4E, &DC, &00
	DEFB &3E, &EE, &7E, &DD, &F0, &F5, &E3, &FE, &FD, &FF, &FF, &7B, &FF, &FF, &87, &FF

	;;	........................
	;;	........................
	;;	..........@@@@@.........
	;;	.............@@@@.......
	;;	.....@@@.@@@@..@@.@.....
	;;	...@@@..@@@@@@@.@@.@....
	;;	..@@@.@@@@@@@@@.@@.@@...
	;;	..@@.@@@@@@@@@@@.@@.@...
	;;	.@..@@@@@@@@@@@@.@@.@@..
	;;	.@@.@@@@@@@@@@@@@.@@.@..
	;;	..@.@@@@@@@@@@@@@.@@.@@.
	;;	.@....@@@@@@@@@@@.@@.@@.
	;;	..@.@@@@@@@...@@@.@@.@..
	;;	...@@@@@@@.@@@@@..@@.@..
	;;	..@@@@.@@@@@@@@@@.@@..@.
	;;	..@@@@.@@@@@@@@@@.@@.@..
	;;	..@@...@@.@@@@@@@.@@..@.
	;;	....@@.@@.@@@@@@.@..@@@.
	;;	...@@@..@......@..@@@@@.
	;;	....@@@..@@@@@@....@@@..
	;;	........@@@@.@..........
	;;	........@@@@@@..........
	;;	.........@@@@...........
	;;	........................
	;;
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@.....@@@@@@@@@
	;;	@@@@@@@@@.@@@@@..@@@@@@@
	;;	@@@@@........@@@@..@@@@@
	;;	@@@............@@...@@@@
	;;	@@..............@@...@@@
	;;	@...............@@....@@
	;;	@................@@...@@
	;;	.@...............@@....@
	;;	.@@...............@@...@
	;;	@.@...............@@....
	;;	..................@@....
	;;	@.................@@...@
	;;	@@................@@...@
	;;	@.................@@....
	;;	@.................@@...@
	;;	@.................@@..@.
	;;	@@..@@...........@..@@@.
	;;	@@.@@@............@@@@@.
	;;	@@@.@@@..@@@@@@.@@.@@@.@
	;;	@@@@....@@@@.@.@@@@...@@
	;;	@@@@@@@.@@@@@@.@@@@@@@@@
	;;	@@@@@@@@.@@@@.@@@@@@@@@@
	;;	@@@@@@@@@....@@@@@@@@@@@

							;; SPR_MONOCATB2:  EQU &35
	DEFB &00, &00, &00, &00, &00, &00, &00, &3E, &00, &00, &07, &80, &07, &79, &A0, &1C
	DEFB &FE, &D0, &3B, &FE, &D8, &37, &FF, &68, &4F, &FF, &6C, &6F, &FF, &B4, &2F, &FF
	DEFB &B6, &43, &FF, &B6, &2F, &E3, &B4, &1F, &DF, &34, &3D, &FF, &B2, &3D, &FF, &B4
	DEFB &0D, &BF, &B2, &31, &BF, &4C, &3C, &81, &3C, &1C, &3E, &78, &00, &7A, &00, &00
	DEFB &7E, &00, &00, &3C, &00, &00, &00, &00, &FF, &FF, &FF, &FF, &C1, &FF, &FF, &BE
	DEFB &7F, &F8, &07, &9F, &E0, &01, &8F, &C0, &00, &C7, &80, &00, &C3, &80, &00, &63
	DEFB &40, &00, &61, &60, &00, &31, &A0, &00, &30, &00, &00, &30, &80, &00, &31, &C0
	DEFB &00, &31, &80, &00, &30, &80, &00, &31, &C0, &00, &32, &B0, &00, &4D, &BC, &00
	DEFB &3D, &DD, &3E, &7B, &E3, &7A, &87, &FF, &7E, &FF, &FF, &BD, &FF, &FF, &C3, &FF

	;;	........................
	;;	........................
	;;	..........@@@@@.........
	;;	.............@@@@.......
	;;	.....@@@.@@@@..@@.@.....
	;;	...@@@..@@@@@@@.@@.@....
	;;	..@@@.@@@@@@@@@.@@.@@...
	;;	..@@.@@@@@@@@@@@.@@.@...
	;;	.@..@@@@@@@@@@@@.@@.@@..
	;;	.@@.@@@@@@@@@@@@@.@@.@..
	;;	..@.@@@@@@@@@@@@@.@@.@@.
	;;	.@....@@@@@@@@@@@.@@.@@.
	;;	..@.@@@@@@@...@@@.@@.@..
	;;	...@@@@@@@.@@@@@..@@.@..
	;;	..@@@@.@@@@@@@@@@.@@..@.
	;;	..@@@@.@@@@@@@@@@.@@.@..
	;;	....@@.@@.@@@@@@@.@@..@.
	;;	..@@...@@.@@@@@@.@..@@..
	;;	..@@@@..@......@..@@@@..
	;;	...@@@....@@@@@..@@@@...
	;;	.........@@@@.@.........
	;;	.........@@@@@@.........
	;;	..........@@@@..........
	;;	........................
	;;
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@.....@@@@@@@@@
	;;	@@@@@@@@@.@@@@@..@@@@@@@
	;;	@@@@@........@@@@..@@@@@
	;;	@@@............@@...@@@@
	;;	@@..............@@...@@@
	;;	@...............@@....@@
	;;	@................@@...@@
	;;	.@...............@@....@
	;;	.@@...............@@...@
	;;	@.@...............@@....
	;;	..................@@....
	;;	@.................@@...@
	;;	@@................@@...@
	;;	@.................@@....
	;;	@.................@@...@
	;;	@@................@@..@.
	;;	@.@@.............@..@@.@
	;;	@.@@@@............@@@@.@
	;;	@@.@@@.@..@@@@@..@@@@.@@
	;;	@@@...@@.@@@@.@.@....@@@
	;;	@@@@@@@@.@@@@@@.@@@@@@@@
	;;	@@@@@@@@@.@@@@.@@@@@@@@@
	;;	@@@@@@@@@@....@@@@@@@@@@

							;; SPR_ROBOMOUSE:  EQU &36
	DEFB &00, &00, &00, &00, &3C, &00, &01, &E7, &00, &03, &F9, &C0, &06, &7E, &E0, &05
	DEFB &BF, &50, &35, &B9, &A8, &76, &74, &98, &7B, &F9, &D8, &24, &FF, &E8, &5E, &1F
	DEFB &F0, &5E, &C0, &08, &5E, &FF, &F8, &5C, &7F, &B4, &5B, &1F, &8A, &2F, &CE, &7A
	DEFB &4F, &01, &F6, &73, &6F, &90, &34, &F7, &60, &03, &76, &E0, &03, &71, &C0, &01
	DEFB &B7, &00, &00, &4C, &00, &00, &00, &00, &FF, &C3, &FF, &FE, &00, &FF, &FC, &00
	DEFB &3F, &F8, &00, &1F, &F0, &00, &0F, &C1, &80, &07, &B1, &80, &23, &70, &04, &03
	DEFB &78, &00, &03, &A4, &00, &03, &1E, &00, &07, &1E, &C0, &0B, &1E, &FF, &FB, &1C
	DEFB &7F, &B1, &1B, &1F, &88, &8F, &CE, &78, &4F, &01, &F0, &73, &0F, &90, &B4, &07
	DEFB &6F, &CB, &06, &EF, &FB, &01, &DF, &FD, &87, &3F, &FE, &4C, &FF, &FF, &B3, &FF

	;;	........................
	;;	..........@@@@..........
	;;	.......@@@@..@@@........
	;;	......@@@@@@@..@@@......
	;;	.....@@..@@@@@@.@@@.....
	;;	.....@.@@.@@@@@@.@.@....
	;;	..@@.@.@@.@@@..@@.@.@...
	;;	.@@@.@@..@@@.@..@..@@...
	;;	.@@@@.@@@@@@@..@@@.@@...
	;;	..@..@..@@@@@@@@@@@.@...
	;;	.@.@@@@....@@@@@@@@@....
	;;	.@.@@@@.@@..........@...
	;;	.@.@@@@.@@@@@@@@@@@@@...
	;;	.@.@@@...@@@@@@@@.@@.@..
	;;	.@.@@.@@...@@@@@@...@.@.
	;;	..@.@@@@@@..@@@..@@@@.@.
	;;	.@..@@@@.......@@@@@.@@.
	;;	.@@@..@@.@@.@@@@@..@....
	;;	..@@.@..@@@@.@@@.@@.....
	;;	......@@.@@@.@@.@@@.....
	;;	......@@.@@@...@@@......
	;;	.......@@.@@.@@@........
	;;	.........@..@@..........
	;;	........................
	;;
	;;	@@@@@@@@@@....@@@@@@@@@@
	;;	@@@@@@@.........@@@@@@@@
	;;	@@@@@@............@@@@@@
	;;	@@@@@..............@@@@@
	;;	@@@@................@@@@
	;;	@@.....@@............@@@
	;;	@.@@...@@.........@...@@
	;;	.@@@.........@........@@
	;;	.@@@@.................@@
	;;	@.@..@................@@
	;;	...@@@@..............@@@
	;;	...@@@@.@@..........@.@@
	;;	...@@@@.@@@@@@@@@@@@@.@@
	;;	...@@@...@@@@@@@@.@@...@
	;;	...@@.@@...@@@@@@...@...
	;;	@...@@@@@@..@@@..@@@@...
	;;	.@..@@@@.......@@@@@....
	;;	.@@@..@@....@@@@@..@....
	;;	@.@@.@.......@@@.@@.@@@@
	;;	@@..@.@@.....@@.@@@.@@@@
	;;	@@@@@.@@.......@@@.@@@@@
	;;	@@@@@@.@@....@@@..@@@@@@
	;;	@@@@@@@..@..@@..@@@@@@@@
	;;	@@@@@@@@@.@@..@@@@@@@@@@

							;; SPR_ROBOMOUSEB: EQU &37
	DEFB &00, &00, &00, &00, &3C, &00, &00, &C7, &80, &03, &F9, &C0, &05, &FE, &E0, &09
	DEFB &9F, &60, &1F, &6F, &60, &0F, &6F, &60, &07, &9F, &DC, &01, &FE, &3E, &06, &39
	DEFB &DE, &0D, &83, &EC, &0B, &CB, &E2, &0B, &C9, &CE, &03, &CA, &2E, &2F, &AB, &EE
	DEFB &2F, &AB, &EC, &37, &6B, &E2, &38, &E9, &DE, &1B, &EA, &2C, &01, &EB, &E0, &00
	DEFB &75, &C0, &00, &00, &00, &00, &00, &00, &FF, &C3, &FF, &FF, &00, &7F, &FC, &00
	DEFB &3F, &F8, &00, &1F, &F4, &00, &0F, &E0, &00, &0F, &C0, &60, &0F, &E0, &60, &03
	DEFB &F0, &00, &1D, &F8, &00, &3E, &F6, &01, &DE, &ED, &83, &ED, &EB, &C3, &E0, &EB
	DEFB &C1, &C0, &D3, &C0, &00, &8F, &A0, &00, &8F, &A0, &01, &87, &60, &02, &80, &E0
	DEFB &1E, &C3, &E2, &2D, &E5, &E3, &E3, &FE, &71, &DF, &FF, &8A, &3F, &FF, &FF, &FF

	;;	........................
	;;	..........@@@@..........
	;;	........@@...@@@@.......
	;;	......@@@@@@@..@@@......
	;;	.....@.@@@@@@@@.@@@.....
	;;	....@..@@..@@@@@.@@.....
	;;	...@@@@@.@@.@@@@.@@.....
	;;	....@@@@.@@.@@@@.@@.....
	;;	.....@@@@..@@@@@@@.@@@..
	;;	.......@@@@@@@@...@@@@@.
	;;	.....@@...@@@..@@@.@@@@.
	;;	....@@.@@.....@@@@@.@@..
	;;	....@.@@@@..@.@@@@@...@.
	;;	....@.@@@@..@..@@@..@@@.
	;;	......@@@@..@.@...@.@@@.
	;;	..@.@@@@@.@.@.@@@@@.@@@.
	;;	..@.@@@@@.@.@.@@@@@.@@..
	;;	..@@.@@@.@@.@.@@@@@...@.
	;;	..@@@...@@@.@..@@@.@@@@.
	;;	...@@.@@@@@.@.@...@.@@..
	;;	.......@@@@.@.@@@@@.....
	;;	.........@@@.@.@@@......
	;;	........................
	;;	........................
	;;
	;;	@@@@@@@@@@....@@@@@@@@@@
	;;	@@@@@@@@.........@@@@@@@
	;;	@@@@@@............@@@@@@
	;;	@@@@@..............@@@@@
	;;	@@@@.@..............@@@@
	;;	@@@.................@@@@
	;;	@@.......@@.........@@@@
	;;	@@@......@@...........@@
	;;	@@@@...............@@@.@
	;;	@@@@@.............@@@@@.
	;;	@@@@.@@........@@@.@@@@.
	;;	@@@.@@.@@.....@@@@@.@@.@
	;;	@@@.@.@@@@....@@@@@.....
	;;	@@@.@.@@@@.....@@@......
	;;	@@.@..@@@@..............
	;;	@...@@@@@.@.............
	;;	@...@@@@@.@............@
	;;	@....@@@.@@...........@.
	;;	@.......@@@........@@@@.
	;;	@@....@@@@@...@...@.@@.@
	;;	@@@..@.@@@@...@@@@@...@@
	;;	@@@@@@@..@@@...@@@.@@@@@
	;;	@@@@@@@@@...@.@...@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@

							;; SPR_BEE1:       EQU &38
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &0C, &00, &00, &0E, &00, &00
	DEFB &0C, &00, &38, &08, &00, &6E, &00, &00, &3F, &DB, &FC, &00, &00, &76, &0D, &91
	DEFB &9C, &10, &32, &00, &20, &54, &04, &46, &74, &62, &4D, &28, &B2, &49, &18, &92
	DEFB &46, &3C, &62, &20, &24, &04, &38, &C3, &1C, &0F, &3C, &F0, &03, &FF, &C0, &00
	DEFB &E7, &00, &00, &3C, &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &F1
	DEFB &FF, &FF, &EC, &FF, &FF, &EE, &FF, &C3, &ED, &FF, &B8, &EB, &FF, &6E, &00, &03
	DEFB &BF, &C3, &FD, &C0, &00, &76, &E0, &10, &1D, &C0, &30, &03, &80, &50, &01, &06
	DEFB &70, &60, &0D, &20, &B0, &09, &00, &90, &06, &00, &60, &80, &00, &01, &80, &00
	DEFB &01, &C0, &00, &03, &F0, &00, &0F, &FC, &00, &3F, &FF, &00, &FF, &FF, &C3, &FF

	;;	........................
	;;	........................
	;;	........................
	;;	............@@..........
	;;	............@@@.........
	;;	............@@..........
	;;	..@@@.......@...........
	;;	.@@.@@@.................
	;;	..@@@@@@@@.@@.@@@@@@@@..
	;;	.................@@@.@@.
	;;	....@@.@@..@...@@..@@@..
	;;	...@......@@..@.........
	;;	..@......@.@.@.......@..
	;;	.@...@@..@@@.@...@@...@.
	;;	.@..@@.@..@.@...@.@@..@.
	;;	.@..@..@...@@...@..@..@.
	;;	.@...@@...@@@@...@@...@.
	;;	..@.......@..@.......@..
	;;	..@@@...@@....@@...@@@..
	;;	....@@@@..@@@@..@@@@....
	;;	......@@@@@@@@@@@@......
	;;	........@@@..@@@........
	;;	..........@@@@..........
	;;	........................
	;;
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@...@@@@@@@@@
	;;	@@@@@@@@@@@.@@..@@@@@@@@
	;;	@@@@@@@@@@@.@@@.@@@@@@@@
	;;	@@....@@@@@.@@.@@@@@@@@@
	;;	@.@@@...@@@.@.@@@@@@@@@@
	;;	.@@.@@@...............@@
	;;	@.@@@@@@@@....@@@@@@@@.@
	;;	@@...............@@@.@@.
	;;	@@@........@.......@@@.@
	;;	@@........@@..........@@
	;;	@........@.@...........@
	;;	.....@@..@@@.....@@.....
	;;	....@@.@..@.....@.@@....
	;;	....@..@........@..@....
	;;	.....@@..........@@.....
	;;	@......................@
	;;	@......................@
	;;	@@....................@@
	;;	@@@@................@@@@
	;;	@@@@@@............@@@@@@
	;;	@@@@@@@@........@@@@@@@@
	;;	@@@@@@@@@@....@@@@@@@@@@

							;; SPR_BEE2:       EQU &39
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &1C, &01, &C0, &17
	DEFB &03, &40, &0F, &87, &80, &00, &E6, &00, &00, &18, &00, &02, &26, &00, &0C, &E3
	DEFB &C0, &13, &C0, &F8, &25, &A4, &6C, &47, &24, &3A, &40, &18, &82, &49, &18, &92
	DEFB &46, &3C, &62, &20, &24, &04, &38, &C3, &1C, &0F, &3C, &F0, &03, &FF, &C0, &00
	DEFB &E7, &00, &00, &3C, &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
	DEFB &FF, &E3, &FE, &3F, &DC, &FD, &DF, &D7, &7B, &5F, &EF, &97, &BF, &F0, &E6, &7F
	DEFB &FC, &00, &7F, &F0, &26, &3F, &E0, &E3, &C7, &C3, &C0, &FB, &85, &80, &6D, &07
	DEFB &00, &38, &00, &00, &80, &09, &00, &90, &06, &00, &60, &80, &00, &01, &80, &00
	DEFB &01, &C0, &00, &03, &F0, &00, &0F, &FC, &00, &3F, &FF, &00, &FF, &FF, &C3, &FF

	;;	........................
	;;	........................
	;;	........................
	;;	........................
	;;	...@@@.........@@@......
	;;	...@.@@@......@@.@......
	;;	....@@@@@....@@@@.......
	;;	........@@@..@@.........
	;;	...........@@...........
	;;	......@...@..@@.........
	;;	....@@..@@@...@@@@......
	;;	...@..@@@@......@@@@@...
	;;	..@..@.@@.@..@...@@.@@..
	;;	.@...@@@..@..@....@@@.@.
	;;	.@.........@@...@.....@.
	;;	.@..@..@...@@...@..@..@.
	;;	.@...@@...@@@@...@@...@.
	;;	..@.......@..@.......@..
	;;	..@@@...@@....@@...@@@..
	;;	....@@@@..@@@@..@@@@....
	;;	......@@@@@@@@@@@@......
	;;	........@@@..@@@........
	;;	..........@@@@..........
	;;	........................
	;;
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@...@@@@@@@@@...@@@@@@
	;;	@@.@@@..@@@@@@.@@@.@@@@@
	;;	@@.@.@@@.@@@@.@@.@.@@@@@
	;;	@@@.@@@@@..@.@@@@.@@@@@@
	;;	@@@@....@@@..@@..@@@@@@@
	;;	@@@@@@...........@@@@@@@
	;;	@@@@......@..@@...@@@@@@
	;;	@@@.....@@@...@@@@...@@@
	;;	@@....@@@@......@@@@@.@@
	;;	@....@.@@........@@.@@.@
	;;	.....@@@..........@@@...
	;;	................@.......
	;;	....@..@........@..@....
	;;	.....@@..........@@.....
	;;	@......................@
	;;	@......................@
	;;	@@....................@@
	;;	@@@@................@@@@
	;;	@@@@@@............@@@@@@
	;;	@@@@@@@@........@@@@@@@@
	;;	@@@@@@@@@@....@@@@@@@@@@

							;; SPR_BEACON:     EQU &3A
	DEFB &00, &00, &00, &00, &7E, &00, &01, &E7, &80, &03, &99, &C0, &07, &C3, &E0, &07
	DEFB &FF, &E0, &07, &FF, &E0, &0B, &FF, &D0, &0D, &FF, &90, &0C, &3C, &50, &0C, &C0
	DEFB &D0, &12, &CC, &A8, &13, &4D, &28, &39, &33, &1C, &2E, &30, &74, &5B, &C3, &DA
	DEFB &66, &FF, &66, &79, &BD, &9E, &3E, &66, &7C, &0F, &99, &F0, &03, &E7, &C0, &00
	DEFB &FF, &00, &00, &3C, &00, &00, &00, &00, &FF, &81, &FF, &FE, &00, &7F, &FC, &00
	DEFB &3F, &F8, &18, &1F, &F0, &00, &0F, &F0, &00, &0F, &F0, &00, &0F, &E8, &00, &17
	DEFB &EC, &00, &17, &EC, &00, &57, &EC, &C0, &D7, &C2, &CC, &A3, &C3, &4D, &23, &81
	DEFB &33, &01, &80, &30, &01, &40, &00, &02, &60, &00, &06, &78, &00, &1E, &BE, &00
	DEFB &7D, &CF, &81, &F3, &F3, &E7, &CF, &FC, &FF, &3F, &FF, &3C, &FF, &FF, &C3, &FF

	;;	........................
	;;	.........@@@@@@.........
	;;	.......@@@@..@@@@.......
	;;	......@@@..@@..@@@......
	;;	.....@@@@@....@@@@@.....
	;;	.....@@@@@@@@@@@@@@.....
	;;	.....@@@@@@@@@@@@@@.....
	;;	....@.@@@@@@@@@@@@.@....
	;;	....@@.@@@@@@@@@@..@....
	;;	....@@....@@@@...@.@....
	;;	....@@..@@......@@.@....
	;;	...@..@.@@..@@..@.@.@...
	;;	...@..@@.@..@@.@..@.@...
	;;	..@@@..@..@@..@@...@@@..
	;;	..@.@@@...@@.....@@@.@..
	;;	.@.@@.@@@@....@@@@.@@.@.
	;;	.@@..@@.@@@@@@@@.@@..@@.
	;;	.@@@@..@@.@@@@.@@..@@@@.
	;;	..@@@@@..@@..@@..@@@@@..
	;;	....@@@@@..@@..@@@@@....
	;;	......@@@@@..@@@@@......
	;;	........@@@@@@@@........
	;;	..........@@@@..........
	;;	........................
	;;
	;;	@@@@@@@@@......@@@@@@@@@
	;;	@@@@@@@..........@@@@@@@
	;;	@@@@@@............@@@@@@
	;;	@@@@@......@@......@@@@@
	;;	@@@@................@@@@
	;;	@@@@................@@@@
	;;	@@@@................@@@@
	;;	@@@.@..............@.@@@
	;;	@@@.@@.............@.@@@
	;;	@@@.@@...........@.@.@@@
	;;	@@@.@@..@@......@@.@.@@@
	;;	@@....@.@@..@@..@.@...@@
	;;	@@....@@.@..@@.@..@...@@
	;;	@......@..@@..@@.......@
	;;	@.........@@...........@
	;;	.@....................@.
	;;	.@@..................@@.
	;;	.@@@@..............@@@@.
	;;	@.@@@@@..........@@@@@.@
	;;	@@..@@@@@......@@@@@..@@
	;;	@@@@..@@@@@..@@@@@..@@@@
	;;	@@@@@@..@@@@@@@@..@@@@@@
	;;	@@@@@@@@..@@@@..@@@@@@@@
	;;	@@@@@@@@@@....@@@@@@@@@@

							;; SPR_FACE:       EQU &3B
	DEFB &00, &00, &00, &00, &1E, &60, &00, &E1, &F0, &03, &07, &F8, &04, &1F, &E4, &08
	DEFB &7F, &94, &11, &FE, &54, &22, &F8, &EA, &23, &22, &AA, &43, &D7, &6A, &41, &D5
	DEFB &1A, &41, &D3, &64, &54, &E8, &9E, &48, &EF, &7E, &48, &74, &FE, &48, &3B, &C2
	DEFB &24, &37, &92, &26, &37, &4E, &11, &B6, &3C, &0C, &36, &F0, &03, &37, &C0, &00
	DEFB &D7, &00, &00, &2C, &00, &00, &00, &00, &FF, &FF, &9F, &FF, &E0, &6F, &FF, &01
	DEFB &F7, &FC, &07, &FB, &F8, &1F, &E5, &F0, &7F, &85, &E1, &FE, &05, &C2, &F8, &42
	DEFB &C3, &20, &A2, &83, &C2, &42, &81, &C5, &02, &81, &C2, &05, &80, &E0, &1E, &80
	DEFB &E0, &7E, &80, &70, &FE, &80, &3B, &C2, &C0, &37, &82, &C0, &37, &0E, &E0, &36
	DEFB &3D, &F0, &36, &F3, &FC, &37, &CF, &FF, &17, &3F, &FF, &EC, &FF, &FF, &F3, &FF

	;;	........................
	;;	...........@@@@..@@.....
	;;	........@@@....@@@@@....
	;;	......@@.....@@@@@@@@...
	;;	.....@.....@@@@@@@@..@..
	;;	....@....@@@@@@@@..@.@..
	;;	...@...@@@@@@@@..@.@.@..
	;;	..@...@.@@@@@...@@@.@.@.
	;;	..@...@@..@...@.@.@.@.@.
	;;	.@....@@@@.@.@@@.@@.@.@.
	;;	.@.....@@@.@.@.@...@@.@.
	;;	.@.....@@@.@..@@.@@..@..
	;;	.@.@.@..@@@.@...@..@@@@.
	;;	.@..@...@@@.@@@@.@@@@@@.
	;;	.@..@....@@@.@..@@@@@@@.
	;;	.@..@.....@@@.@@@@....@.
	;;	..@..@....@@.@@@@..@..@.
	;;	..@..@@...@@.@@@.@..@@@.
	;;	...@...@@.@@.@@...@@@@..
	;;	....@@....@@.@@.@@@@....
	;;	......@@..@@.@@@@@......
	;;	........@@.@.@@@........
	;;	..........@.@@..........
	;;	........................
	;;
	;;	@@@@@@@@@@@@@@@@@..@@@@@
	;;	@@@@@@@@@@@......@@.@@@@
	;;	@@@@@@@@.......@@@@@.@@@
	;;	@@@@@@.......@@@@@@@@.@@
	;;	@@@@@......@@@@@@@@..@.@
	;;	@@@@.....@@@@@@@@....@.@
	;;	@@@....@@@@@@@@......@.@
	;;	@@....@.@@@@@....@....@.
	;;	@@....@@..@.....@.@...@.
	;;	@.....@@@@....@..@....@.
	;;	@......@@@...@.@......@.
	;;	@......@@@....@......@.@
	;;	@.......@@@........@@@@.
	;;	@.......@@@......@@@@@@.
	;;	@........@@@....@@@@@@@.
	;;	@.........@@@.@@@@....@.
	;;	@@........@@.@@@@.....@.
	;;	@@........@@.@@@....@@@.
	;;	@@@.......@@.@@...@@@@.@
	;;	@@@@......@@.@@.@@@@..@@
	;;	@@@@@@....@@.@@@@@..@@@@
	;;	@@@@@@@@...@.@@@..@@@@@@
	;;	@@@@@@@@@@@.@@..@@@@@@@@
	;;	@@@@@@@@@@@@..@@@@@@@@@@

							;; SPR_FACEB:      EQU &3C
	DEFB &00, &00, &00, &00, &07, &00, &00, &3F, &C0, &01, &FE, &30, &07, &F1, &C0, &1F
	DEFB &8E, &10, &1E, &70, &08, &21, &80, &04, &3A, &00, &04, &3A, &00, &02, &74, &00
	DEFB &02, &74, &00, &02, &68, &00, &02, &42, &00, &02, &42, &00, &02, &46, &00, &02
	DEFB &5C, &00, &04, &50, &00, &24, &10, &03, &C8, &0C, &01, &30, &03, &00, &C0, &00
	DEFB &E7, &00, &00, &18, &00, &00, &00, &00, &FF, &F8, &FF, &FF, &C7, &3F, &FE, &3F
	DEFB &CF, &F9, &FE, &37, &E7, &F1, &CF, &DF, &8E, &0F, &DE, &70, &07, &A1, &80, &03
	DEFB &BA, &00, &03, &BA, &00, &01, &74, &00, &01, &74, &00, &01, &68, &00, &01, &40
	DEFB &00, &01, &40, &00, &01, &40, &00, &01, &40, &00, &03, &40, &00, &03, &80, &00
	DEFB &07, &F0, &00, &0F, &FC, &00, &3F, &FF, &00, &FF, &FF, &E7, &FF, &FF, &FF, &FF

	;;	........................
	;;	.............@@@........
	;;	..........@@@@@@@@......
	;;	.......@@@@@@@@...@@....
	;;	.....@@@@@@@...@@@......
	;;	...@@@@@@...@@@....@....
	;;	...@@@@..@@@........@...
	;;	..@....@@............@..
	;;	..@@@.@..............@..
	;;	..@@@.@...............@.
	;;	.@@@.@................@.
	;;	.@@@.@................@.
	;;	.@@.@.................@.
	;;	.@....@...............@.
	;;	.@....@...............@.
	;;	.@...@@...............@.
	;;	.@.@@@...............@..
	;;	.@.@..............@..@..
	;;	...@..........@@@@..@...
	;;	....@@.........@..@@....
	;;	......@@........@@......
	;;	........@@@..@@@........
	;;	...........@@...........
	;;	........................
	;;
	;;	@@@@@@@@@@@@@...@@@@@@@@
	;;	@@@@@@@@@@...@@@..@@@@@@
	;;	@@@@@@@...@@@@@@@@..@@@@
	;;	@@@@@..@@@@@@@@...@@.@@@
	;;	@@@..@@@@@@@...@@@..@@@@
	;;	@@.@@@@@@...@@@.....@@@@
	;;	@@.@@@@..@@@.........@@@
	;;	@.@....@@.............@@
	;;	@.@@@.@...............@@
	;;	@.@@@.@................@
	;;	.@@@.@.................@
	;;	.@@@.@.................@
	;;	.@@.@..................@
	;;	.@.....................@
	;;	.@.....................@
	;;	.@.....................@
	;;	.@....................@@
	;;	.@....................@@
	;;	@....................@@@
	;;	@@@@................@@@@
	;;	@@@@@@............@@@@@@
	;;	@@@@@@@@........@@@@@@@@
	;;	@@@@@@@@@@@..@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@

							;; SPR_TAP:        EQU &3D
	DEFB &00, &00, &00, &00, &3C, &00, &01, &C3, &80, &06, &3C, &60, &0D, &C3, &B0, &1A
	DEFB &24, &58, &0C, &5A, &30, &16, &24, &68, &09, &C3, &90, &06, &3C, &60, &09, &C3
	DEFB &90, &14, &3C, &28, &19, &00, &98, &36, &24, &6C, &23, &C3, &C4, &6B, &66, &D6
	DEFB &36, &24, &6C, &5E, &A5, &7A, &27, &66, &E4, &19, &E7, &98, &06, &24, &60, &01
	DEFB &DB, &80, &00, &3C, &00, &00, &00, &00, &FF, &C3, &FF, &FE, &3C, &7F, &F9, &C3
	DEFB &9F, &F6, &00, &6F, &EC, &00, &37, &D8, &00, &1B, &EC, &18, &37, &C6, &00, &63
	DEFB &E1, &C3, &87, &F0, &3C, &0F, &E8, &00, &17, &C4, &00, &23, &C1, &00, &83, &80
	DEFB &24, &01, &80, &00, &01, &08, &00, &10, &80, &00, &01, &40, &81, &02, &A0, &00
	DEFB &05, &D8, &00, &1B, &E6, &00, &67, &F9, &DB, &9F, &FE, &3C, &7F, &FF, &C3, &FF

	;;	........................
	;;	..........@@@@..........
	;;	.......@@@....@@@.......
	;;	.....@@...@@@@...@@.....
	;;	....@@.@@@....@@@.@@....
	;;	...@@.@...@..@...@.@@...
	;;	....@@...@.@@.@...@@....
	;;	...@.@@...@..@...@@.@...
	;;	....@..@@@....@@@..@....
	;;	.....@@...@@@@...@@.....
	;;	....@..@@@....@@@..@....
	;;	...@.@....@@@@....@.@...
	;;	...@@..@........@..@@...
	;;	..@@.@@...@..@...@@.@@..
	;;	..@...@@@@....@@@@...@..
	;;	.@@.@.@@.@@..@@.@@.@.@@.
	;;	..@@.@@...@..@...@@.@@..
	;;	.@.@@@@.@.@..@.@.@@@@.@.
	;;	..@..@@@.@@..@@.@@@..@..
	;;	...@@..@@@@..@@@@..@@...
	;;	.....@@...@..@...@@.....
	;;	.......@@@.@@.@@@.......
	;;	..........@@@@..........
	;;	........................
	;;
	;;	@@@@@@@@@@....@@@@@@@@@@
	;;	@@@@@@@...@@@@...@@@@@@@
	;;	@@@@@..@@@....@@@..@@@@@
	;;	@@@@.@@..........@@.@@@@
	;;	@@@.@@............@@.@@@
	;;	@@.@@..............@@.@@
	;;	@@@.@@.....@@.....@@.@@@
	;;	@@...@@..........@@...@@
	;;	@@@....@@@....@@@....@@@
	;;	@@@@......@@@@......@@@@
	;;	@@@.@..............@.@@@
	;;	@@...@............@...@@
	;;	@@.....@........@.....@@
	;;	@.........@..@.........@
	;;	@......................@
	;;	....@..............@....
	;;	@......................@
	;;	.@......@......@......@.
	;;	@.@..................@.@
	;;	@@.@@..............@@.@@
	;;	@@@..@@..........@@..@@@
	;;	@@@@@..@@@.@@.@@@..@@@@@
	;;	@@@@@@@...@@@@...@@@@@@@
	;;	@@@@@@@@@@....@@@@@@@@@@

							;; SPR_CHIMP:      EQU &3E
	DEFB &00, &3C, &00, &00, &C3, &00, &01, &00, &00, &02, &00, &C0, &02, &03, &20, &04
	DEFB &1C, &A0, &04, &33, &00, &04, &49, &E0, &18, &77, &80, &14, &34, &A0, &0E, &02
	DEFB &F0, &04, &0F, &E0, &02, &0F, &90, &02, &00, &70, &01, &07, &E0, &0B, &03, &D0
	DEFB &1A, &00, &18, &0C, &00, &30, &16, &00, &68, &09, &C3, &90, &06, &3C, &60, &01
	DEFB &C3, &80, &00, &3C, &00, &00, &00, &00, &FF, &C3, &FF, &FF, &00, &FF, &FE, &00
	DEFB &3F, &FC, &00, &DF, &FC, &03, &2F, &F8, &1C, &2F, &F8, &33, &1F, &E0, &41, &EF
	DEFB &C0, &77, &8F, &C4, &34, &AF, &EE, &02, &F7, &F4, &0F, &EF, &F8, &0F, &97, &FC
	DEFB &00, &77, &F0, &07, &EF, &E8, &03, &D7, &D8, &00, &1B, &EC, &00, &37, &C6, &00
	DEFB &63, &E1, &C3, &87, &F0, &3C, &0F, &F8, &00, &1F, &FE, &00, &7F, &FF, &C3, &FF

	;;	..........@@@@..........
	;;	........@@....@@........
	;;	.......@................
	;;	......@.........@@......
	;;	......@.......@@..@.....
	;;	.....@.....@@@..@.@.....
	;;	.....@....@@..@@........
	;;	.....@...@..@..@@@@.....
	;;	...@@....@@@.@@@@.......
	;;	...@.@....@@.@..@.@.....
	;;	....@@@.......@.@@@@....
	;;	.....@......@@@@@@@.....
	;;	......@.....@@@@@..@....
	;;	......@..........@@@....
	;;	.......@.....@@@@@@.....
	;;	....@.@@......@@@@.@....
	;;	...@@.@............@@...
	;;	....@@............@@....
	;;	...@.@@..........@@.@...
	;;	....@..@@@....@@@..@....
	;;	.....@@...@@@@...@@.....
	;;	.......@@@....@@@.......
	;;	..........@@@@..........
	;;	........................
	;;
	;;	@@@@@@@@@@....@@@@@@@@@@
	;;	@@@@@@@@........@@@@@@@@
	;;	@@@@@@@...........@@@@@@
	;;	@@@@@@..........@@.@@@@@
	;;	@@@@@@........@@..@.@@@@
	;;	@@@@@......@@@....@.@@@@
	;;	@@@@@.....@@..@@...@@@@@
	;;	@@@......@.....@@@@.@@@@
	;;	@@.......@@@.@@@@...@@@@
	;;	@@...@....@@.@..@.@.@@@@
	;;	@@@.@@@.......@.@@@@.@@@
	;;	@@@@.@......@@@@@@@.@@@@
	;;	@@@@@.......@@@@@..@.@@@
	;;	@@@@@@...........@@@.@@@
	;;	@@@@.........@@@@@@.@@@@
	;;	@@@.@.........@@@@.@.@@@
	;;	@@.@@..............@@.@@
	;;	@@@.@@............@@.@@@
	;;	@@...@@..........@@...@@
	;;	@@@....@@@....@@@....@@@
	;;	@@@@......@@@@......@@@@
	;;	@@@@@..............@@@@@
	;;	@@@@@@@..........@@@@@@@
	;;	@@@@@@@@@@....@@@@@@@@@@

							;; SPR_CHIMPB:     EQU &3F
	DEFB &00, &3C, &00, &00, &C3, &00, &01, &00, &80, &02, &00, &40, &00, &00, &20, &04
	DEFB &00, &20, &0C, &00, &10, &00, &00, &18, &0C, &00, &18, &18, &40, &10, &18, &A0
	DEFB &10, &08, &E0, &20, &10, &40, &20, &08, &00, &40, &00, &00, &40, &08, &00, &B0
	DEFB &18, &00, &58, &0C, &00, &30, &16, &00, &68, &09, &C3, &90, &06, &3C, &60, &01
	DEFB &C3, &80, &00, &3C, &00, &00, &00, &00, &FF, &C3, &FF, &FF, &00, &FF, &FE, &00
	DEFB &7F, &FC, &00, &3F, &F8, &00, &1F, &F4, &00, &0F, &EC, &00, &07, &F0, &00, &03
	DEFB &EC, &00, &03, &D8, &00, &07, &D8, &80, &0F, &E8, &C0, &1F, &D0, &00, &1F, &E8
	DEFB &00, &3F, &F0, &00, &0F, &E8, &00, &37, &D8, &00, &1B, &EC, &00, &37, &C6, &00
	DEFB &63, &E1, &C3, &87, &F0, &3C, &0F, &F8, &00, &1F, &FE, &00, &7F, &FF, &C3, &FF

	;;	..........@@@@..........
	;;	........@@....@@........
	;;	.......@........@.......
	;;	......@..........@......
	;;	..................@.....
	;;	.....@............@.....
	;;	....@@.............@....
	;;	...................@@...
	;;	....@@.............@@...
	;;	...@@....@.........@....
	;;	...@@...@.@........@....
	;;	....@...@@@.......@.....
	;;	...@.....@........@.....
	;;	....@............@......
	;;	.................@......
	;;	....@...........@.@@....
	;;	...@@............@.@@...
	;;	....@@............@@....
	;;	...@.@@..........@@.@...
	;;	....@..@@@....@@@..@....
	;;	.....@@...@@@@...@@.....
	;;	.......@@@....@@@.......
	;;	..........@@@@..........
	;;	........................
	;;
	;;	@@@@@@@@@@....@@@@@@@@@@
	;;	@@@@@@@@........@@@@@@@@
	;;	@@@@@@@..........@@@@@@@
	;;	@@@@@@............@@@@@@
	;;	@@@@@..............@@@@@
	;;	@@@@.@..............@@@@
	;;	@@@.@@...............@@@
	;;	@@@@..................@@
	;;	@@@.@@................@@
	;;	@@.@@................@@@
	;;	@@.@@...@...........@@@@
	;;	@@@.@...@@.........@@@@@
	;;	@@.@...............@@@@@
	;;	@@@.@.............@@@@@@
	;;	@@@@................@@@@
	;;	@@@.@.............@@.@@@
	;;	@@.@@..............@@.@@
	;;	@@@.@@............@@.@@@
	;;	@@...@@..........@@...@@
	;;	@@@....@@@....@@@....@@@
	;;	@@@@......@@@@......@@@@
	;;	@@@@@..............@@@@@
	;;	@@@@@@@..........@@@@@@@
	;;	@@@@@@@@@@....@@@@@@@@@@

							;; SPR_CHARLES:    EQU &40
	DEFB &00, &00, &00, &00, &7E, &30, &01, &81, &48, &02, &03, &B8, &04, &7F, &98, &34
	DEFB &FE, &58, &49, &8D, &D0, &75, &74, &50, &65, &C5, &80, &35, &B4, &40, &1F, &C6
	DEFB &C0, &0B, &BF, &40, &07, &F7, &80, &03, &EF, &80, &03, &F0, &40, &0B, &FD, &D0
	DEFB &1B, &EE, &D8, &0D, &CF, &B0, &16, &76, &68, &09, &81, &90, &06, &3C, &60, &01
	DEFB &C3, &80, &00, &3C, &00, &00, &00, &00, &FF, &FF, &CF, &FF, &80, &B7, &FE, &01
	DEFB &4B, &FC, &03, &BB, &C8, &7F, &9B, &B0, &FE, &5B, &49, &8D, &D7, &75, &74, &57
	DEFB &65, &C4, &0F, &B5, &84, &5F, &DF, &C6, &DF, &EB, &BF, &5F, &F7, &F7, &BF, &FB
	DEFB &EF, &BF, &F3, &F0, &4F, &EB, &FD, &D7, &DB, &EE, &DB, &ED, &CF, &B7, &C6, &76
	DEFB &63, &E1, &81, &87, &F0, &3C, &0F, &F8, &00, &1F, &FE, &00, &7F, &FF, &C3, &FF

	;;	........................
	;;	.........@@@@@@...@@....
	;;	.......@@......@.@..@...
	;;	......@.......@@@.@@@...
	;;	.....@...@@@@@@@@..@@...
	;;	..@@.@..@@@@@@@..@.@@...
	;;	.@..@..@@...@@.@@@.@....
	;;	.@@@.@.@.@@@.@...@.@....
	;;	.@@..@.@@@...@.@@.......
	;;	..@@.@.@@.@@.@...@......
	;;	...@@@@@@@...@@.@@......
	;;	....@.@@@.@@@@@@.@......
	;;	.....@@@@@@@.@@@@.......
	;;	......@@@@@.@@@@@.......
	;;	......@@@@@@.....@......
	;;	....@.@@@@@@@@.@@@.@....
	;;	...@@.@@@@@.@@@.@@.@@...
	;;	....@@.@@@..@@@@@.@@....
	;;	...@.@@..@@@.@@..@@.@...
	;;	....@..@@......@@..@....
	;;	.....@@...@@@@...@@.....
	;;	.......@@@....@@@.......
	;;	..........@@@@..........
	;;	........................
	;;
	;;	@@@@@@@@@@@@@@@@@@..@@@@
	;;	@@@@@@@@@.......@.@@.@@@
	;;	@@@@@@@........@.@..@.@@
	;;	@@@@@@........@@@.@@@.@@
	;;	@@..@....@@@@@@@@..@@.@@
	;;	@.@@....@@@@@@@..@.@@.@@
	;;	.@..@..@@...@@.@@@.@.@@@
	;;	.@@@.@.@.@@@.@...@.@.@@@
	;;	.@@..@.@@@...@......@@@@
	;;	@.@@.@.@@....@...@.@@@@@
	;;	@@.@@@@@@@...@@.@@.@@@@@
	;;	@@@.@.@@@.@@@@@@.@.@@@@@
	;;	@@@@.@@@@@@@.@@@@.@@@@@@
	;;	@@@@@.@@@@@.@@@@@.@@@@@@
	;;	@@@@..@@@@@@.....@..@@@@
	;;	@@@.@.@@@@@@@@.@@@.@.@@@
	;;	@@.@@.@@@@@.@@@.@@.@@.@@
	;;	@@@.@@.@@@..@@@@@.@@.@@@
	;;	@@...@@..@@@.@@..@@...@@
	;;	@@@....@@......@@....@@@
	;;	@@@@......@@@@......@@@@
	;;	@@@@@..............@@@@@
	;;	@@@@@@@..........@@@@@@@
	;;	@@@@@@@@@@....@@@@@@@@@@

							;; SPR_CHARLESB:   EQU &41
	DEFB &00, &00, &00, &00, &7E, &00, &01, &81, &B0, &02, &00, &78, &02, &00, &38, &04
	DEFB &40, &B8, &18, &61, &B0, &3C, &3F, &20, &3C, &08, &20, &3E, &00, &20, &1E, &00
	DEFB &20, &0E, &86, &40, &07, &CF, &C0, &03, &FF, &C0, &03, &FF, &C0, &0B, &FF, &D0
	DEFB &1B, &FE, &D8, &0D, &F9, &B0, &16, &7E, &68, &09, &81, &90, &06, &3C, &60, &01
	DEFB &C3, &80, &00, &3C, &00, &00, &00, &00, &FF, &FF, &FF, &FF, &81, &CF, &FE, &00
	DEFB &37, &FC, &00, &3B, &FC, &00, &1B, &E0, &00, &1B, &D8, &00, &17, &BC, &00, &0F
	DEFB &BC, &00, &1F, &BE, &00, &1F, &DE, &00, &1F, &EE, &86, &5F, &F7, &CF, &DF, &FB
	DEFB &FF, &DF, &F3, &FF, &CF, &EB, &FF, &D7, &DB, &FE, &DB, &ED, &F9, &B7, &C6, &7E
	DEFB &63, &E1, &81, &87, &F0, &3C, &0F, &F8, &00, &1F, &FE, &00, &7F, &FF, &C3, &FF

	;;	........................
	;;	.........@@@@@@.........
	;;	.......@@......@@.@@....
	;;	......@..........@@@@...
	;;	......@...........@@@...
	;;	.....@...@......@.@@@...
	;;	...@@....@@....@@.@@....
	;;	..@@@@....@@@@@@..@.....
	;;	..@@@@......@.....@.....
	;;	..@@@@@...........@.....
	;;	...@@@@...........@.....
	;;	....@@@.@....@@..@......
	;;	.....@@@@@..@@@@@@......
	;;	......@@@@@@@@@@@@......
	;;	......@@@@@@@@@@@@......
	;;	....@.@@@@@@@@@@@@.@....
	;;	...@@.@@@@@@@@@.@@.@@...
	;;	....@@.@@@@@@..@@.@@....
	;;	...@.@@..@@@@@@..@@.@...
	;;	....@..@@......@@..@....
	;;	.....@@...@@@@...@@.....
	;;	.......@@@....@@@.......
	;;	..........@@@@..........
	;;	........................
	;;
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@......@@@..@@@@
	;;	@@@@@@@...........@@.@@@
	;;	@@@@@@............@@@.@@
	;;	@@@@@@.............@@.@@
	;;	@@@................@@.@@
	;;	@@.@@..............@.@@@
	;;	@.@@@@..............@@@@
	;;	@.@@@@.............@@@@@
	;;	@.@@@@@............@@@@@
	;;	@@.@@@@............@@@@@
	;;	@@@.@@@.@....@@..@.@@@@@
	;;	@@@@.@@@@@..@@@@@@.@@@@@
	;;	@@@@@.@@@@@@@@@@@@.@@@@@
	;;	@@@@..@@@@@@@@@@@@..@@@@
	;;	@@@.@.@@@@@@@@@@@@.@.@@@
	;;	@@.@@.@@@@@@@@@.@@.@@.@@
	;;	@@@.@@.@@@@@@..@@.@@.@@@
	;;	@@...@@..@@@@@@..@@...@@
	;;	@@@....@@......@@....@@@
	;;	@@@@......@@@@......@@@@
	;;	@@@@@..............@@@@@
	;;	@@@@@@@..........@@@@@@@
	;;	@@@@@@@@@@....@@@@@@@@@@

							;; SPR_TRUNK:      EQU &42
	DEFB &00, &00, &00, &00, &0E, &60, &00, &7F, &B0, &01, &FC, &C8, &03, &CB, &58, &1B
	DEFB &B2, &68, &3D, &A4, &70, &63, &C7, &B0, &5B, &EF, &D0, &3F, &FF, &EC, &1B, &FB
	DEFB &DA, &0B, &F3, &F2, &01, &F0, &FC, &00, &E6, &38, &01, &39, &80, &0B, &CF, &50
	DEFB &1B, &F0, &D8, &0D, &FF, &B0, &16, &3C, &68, &09, &C3, &90, &06, &3C, &60, &01
	DEFB &C3, &80, &00, &3C, &00, &00, &00, &00, &FF, &F1, &9F, &FF, &80, &0F, &FE, &00
	DEFB &07, &FC, &00, &0B, &E0, &03, &1B, &C0, &32, &0B, &80, &20, &07, &00, &00, &07
	DEFB &18, &00, &03, &BC, &00, &01, &D8, &00, &00, &E8, &00, &00, &F4, &00, &01, &FC
	DEFB &06, &03, &F0, &00, &07, &E8, &00, &17, &D8, &00, &1B, &EC, &00, &37, &C6, &00
	DEFB &63, &E1, &C3, &87, &F0, &3C, &0F, &F8, &00, &1F, &FE, &00, &7F, &FF, &C3, &FF

	;;	........................
	;;	............@@@..@@.....
	;;	.........@@@@@@@@.@@....
	;;	.......@@@@@@@..@@..@...
	;;	......@@@@..@.@@.@.@@...
	;;	...@@.@@@.@@..@..@@.@...
	;;	..@@@@.@@.@..@...@@@....
	;;	.@@...@@@@...@@@@.@@....
	;;	.@.@@.@@@@@.@@@@@@.@....
	;;	..@@@@@@@@@@@@@@@@@.@@..
	;;	...@@.@@@@@@@.@@@@.@@.@.
	;;	....@.@@@@@@..@@@@@@..@.
	;;	.......@@@@@....@@@@@@..
	;;	........@@@..@@...@@@...
	;;	.......@..@@@..@@.......
	;;	....@.@@@@..@@@@.@.@....
	;;	...@@.@@@@@@....@@.@@...
	;;	....@@.@@@@@@@@@@.@@....
	;;	...@.@@...@@@@...@@.@...
	;;	....@..@@@....@@@..@....
	;;	.....@@...@@@@...@@.....
	;;	.......@@@....@@@.......
	;;	..........@@@@..........
	;;	........................
	;;
	;;	@@@@@@@@@@@@...@@..@@@@@
	;;	@@@@@@@@@...........@@@@
	;;	@@@@@@@..............@@@
	;;	@@@@@@..............@.@@
	;;	@@@...........@@...@@.@@
	;;	@@........@@..@.....@.@@
	;;	@.........@..........@@@
	;;	.....................@@@
	;;	...@@.................@@
	;;	@.@@@@.................@
	;;	@@.@@...................
	;;	@@@.@...................
	;;	@@@@.@.................@
	;;	@@@@@@.......@@.......@@
	;;	@@@@.................@@@
	;;	@@@.@..............@.@@@
	;;	@@.@@..............@@.@@
	;;	@@@.@@............@@.@@@
	;;	@@...@@..........@@...@@
	;;	@@@....@@@....@@@....@@@
	;;	@@@@......@@@@......@@@@
	;;	@@@@@..............@@@@@
	;;	@@@@@@@..........@@@@@@@
	;;	@@@@@@@@@@....@@@@@@@@@@

							;; SPR_TRUNKB:     EQU &43
	DEFB &00, &00, &00, &18, &06, &70, &3C, &3F, &B0, &3E, &FB, &D8, &3D, &FF, &E8, &1D
	DEFB &FF, &E8, &1A, &FF, &F0, &07, &FF, &F0, &07, &FF, &F0, &0F, &FF, &F0, &0F, &BF
	DEFB &E0, &06, &7F, &E0, &01, &FF, &40, &01, &FE, &80, &01, &BE, &40, &0C, &7D, &D0
	DEFB &1B, &BF, &D8, &0D, &FF, &B0, &16, &3C, &68, &09, &C3, &90, &06, &3C, &60, &01
	DEFB &C3, &80, &00, &3C, &00, &00, &00, &00, &E7, &F9, &8F, &C3, &C0, &07, &81, &00
	DEFB &07, &80, &00, &03, &80, &00, &03, &C0, &00, &03, &C0, &00, &07, &E0, &00, &07
	DEFB &F0, &00, &07, &E0, &00, &07, &E0, &00, &0F, &F0, &00, &0F, &F8, &00, &1F, &FC
	DEFB &00, &1F, &F0, &00, &0F, &EC, &00, &17, &D8, &00, &1B, &CC, &00, &33, &C6, &00
	DEFB &63, &E1, &C3, &87, &F0, &3C, &0F, &F8, &00, &1F, &FE, &00, &7F, &FF, &C3, &FF

	;;	........................
	;;	...@@........@@..@@@....
	;;	..@@@@....@@@@@@@.@@....
	;;	..@@@@@.@@@@@.@@@@.@@...
	;;	..@@@@.@@@@@@@@@@@@.@...
	;;	...@@@.@@@@@@@@@@@@.@...
	;;	...@@.@.@@@@@@@@@@@@....
	;;	.....@@@@@@@@@@@@@@@....
	;;	.....@@@@@@@@@@@@@@@....
	;;	....@@@@@@@@@@@@@@@@....
	;;	....@@@@@.@@@@@@@@@.....
	;;	.....@@..@@@@@@@@@@.....
	;;	.......@@@@@@@@@.@......
	;;	.......@@@@@@@@.@.......
	;;	.......@@.@@@@@..@......
	;;	....@@...@@@@@.@@@.@....
	;;	...@@.@@@.@@@@@@@@.@@...
	;;	....@@.@@@@@@@@@@.@@....
	;;	...@.@@...@@@@...@@.@...
	;;	....@..@@@....@@@..@....
	;;	.....@@...@@@@...@@.....
	;;	.......@@@....@@@.......
	;;	..........@@@@..........
	;;	........................
	;;
	;;	@@@..@@@@@@@@..@@...@@@@
	;;	@@....@@@@...........@@@
	;;	@......@.............@@@
	;;	@.....................@@
	;;	@.....................@@
	;;	@@....................@@
	;;	@@...................@@@
	;;	@@@..................@@@
	;;	@@@@.................@@@
	;;	@@@..................@@@
	;;	@@@.................@@@@
	;;	@@@@................@@@@
	;;	@@@@@..............@@@@@
	;;	@@@@@@.............@@@@@
	;;	@@@@................@@@@
	;;	@@@.@@.............@.@@@
	;;	@@.@@..............@@.@@
	;;	@@..@@............@@..@@
	;;	@@...@@..........@@...@@
	;;	@@@....@@@....@@@....@@@
	;;	@@@@......@@@@......@@@@
	;;	@@@@@..............@@@@@
	;;	@@@@@@@..........@@@@@@@
	;;	@@@@@@@@@@....@@@@@@@@@@

							;; SPR_HELIPLAT1:  EQU &44
	DEFB &00, &00, &00, &00, &3C, &00, &00, &E7, &00, &03, &81, &C0, &0E, &3C, &70, &38
	DEFB &E7, &1C, &63, &81, &C6, &38, &E7, &1C, &4E, &3C, &72, &73, &81, &CE, &5C, &E7
	DEFB &3A, &47, &3C, &E2, &36, &C3, &6C, &4E, &24, &70, &73, &A5, &CC, &7C, &E7, &1E
	DEFB &0F, &24, &E2, &00, &01, &FE, &00, &70, &1E, &00, &60, &00, &00, &20, &00, &00
	DEFB &60, &00, &00, &60, &00, &00, &00, &00, &FF, &C3, &FF, &FF, &3C, &FF, &FC, &E7
	DEFB &3F, &F3, &81, &CF, &CE, &00, &73, &B8, &00, &1D, &60, &00, &06, &B8, &00, &1D
	DEFB &0E, &00, &70, &03, &81, &C0, &00, &E7, &00, &00, &3C, &00, &80, &00, &01, &40
	DEFB &00, &03, &70, &00, &0D, &7C, &00, &1E, &8F, &00, &E2, &F0, &01, &FE, &FF, &76
	DEFB &1E, &FF, &6F, &E1, &FF, &AF, &FF, &FF, &6F, &FF, &FF, &6F, &FF, &FF, &9F, &FF

	;;	........................
	;;	..........@@@@..........
	;;	........@@@..@@@........
	;;	......@@@......@@@......
	;;	....@@@...@@@@...@@@....
	;;	..@@@...@@@..@@@...@@@..
	;;	.@@...@@@......@@@...@@.
	;;	..@@@...@@@..@@@...@@@..
	;;	.@..@@@...@@@@...@@@..@.
	;;	.@@@..@@@......@@@..@@@.
	;;	.@.@@@..@@@..@@@..@@@.@.
	;;	.@...@@@..@@@@..@@@...@.
	;;	..@@.@@.@@....@@.@@.@@..
	;;	.@..@@@...@..@...@@@....
	;;	.@@@..@@@.@..@.@@@..@@..
	;;	.@@@@@..@@@..@@@...@@@@.
	;;	....@@@@..@..@..@@@...@.
	;;	...............@@@@@@@@.
	;;	.........@@@.......@@@@.
	;;	.........@@.............
	;;	..........@.............
	;;	.........@@.............
	;;	.........@@.............
	;;	........................
	;;
	;;	@@@@@@@@@@....@@@@@@@@@@
	;;	@@@@@@@@..@@@@..@@@@@@@@
	;;	@@@@@@..@@@..@@@..@@@@@@
	;;	@@@@..@@@......@@@..@@@@
	;;	@@..@@@..........@@@..@@
	;;	@.@@@..............@@@.@
	;;	.@@..................@@.
	;;	@.@@@..............@@@.@
	;;	....@@@..........@@@....
	;;	......@@@......@@@......
	;;	........@@@..@@@........
	;;	..........@@@@..........
	;;	@......................@
	;;	.@....................@@
	;;	.@@@................@@.@
	;;	.@@@@@.............@@@@.
	;;	@...@@@@........@@@...@.
	;;	@@@@...........@@@@@@@@.
	;;	@@@@@@@@.@@@.@@....@@@@.
	;;	@@@@@@@@.@@.@@@@@@@....@
	;;	@@@@@@@@@.@.@@@@@@@@@@@@
	;;	@@@@@@@@.@@.@@@@@@@@@@@@
	;;	@@@@@@@@.@@.@@@@@@@@@@@@
	;;	@@@@@@@@@..@@@@@@@@@@@@@

							;; SPR_HELIPLAT2:  EQU &45
	DEFB &00, &00, &00, &00, &3C, &00, &00, &E7, &00, &03, &81, &C0, &0E, &3C, &70, &38
	DEFB &E7, &1C, &63, &81, &C6, &38, &E7, &1C, &4E, &3C, &72, &73, &81, &CE, &5C, &E7
	DEFB &3A, &47, &3C, &E2, &36, &C3, &6C, &0E, &24, &70, &13, &A5, &C0, &0C, &E7, &00
	DEFB &00, &25, &E0, &01, &C2, &70, &03, &B7, &98, &07, &61, &E0, &06, &C0, &78, &01
	DEFB &80, &18, &07, &00, &00, &00, &00, &00, &FF, &C3, &FF, &FF, &3C, &FF, &FC, &E7
	DEFB &3F, &F3, &81, &CF, &CE, &00, &73, &B8, &00, &1D, &60, &00, &06, &B8, &00, &1D
	DEFB &0E, &00, &70, &03, &81, &C0, &00, &E7, &00, &00, &3C, &00, &80, &00, &01, &C0
	DEFB &00, &03, &D0, &00, &0F, &EC, &00, &1F, &F2, &01, &EF, &FD, &C2, &77, &FB, &B7
	DEFB &9B, &F7, &69, &E7, &F6, &DE, &7B, &F9, &BF, &9B, &F7, &7F, &E7, &F8, &FF, &FF

	;;	........................
	;;	..........@@@@..........
	;;	........@@@..@@@........
	;;	......@@@......@@@......
	;;	....@@@...@@@@...@@@....
	;;	..@@@...@@@..@@@...@@@..
	;;	.@@...@@@......@@@...@@.
	;;	..@@@...@@@..@@@...@@@..
	;;	.@..@@@...@@@@...@@@..@.
	;;	.@@@..@@@......@@@..@@@.
	;;	.@.@@@..@@@..@@@..@@@.@.
	;;	.@...@@@..@@@@..@@@...@.
	;;	..@@.@@.@@....@@.@@.@@..
	;;	....@@@...@..@...@@@....
	;;	...@..@@@.@..@.@@@......
	;;	....@@..@@@..@@@........
	;;	..........@..@.@@@@.....
	;;	.......@@@....@..@@@....
	;;	......@@@.@@.@@@@..@@...
	;;	.....@@@.@@....@@@@.....
	;;	.....@@.@@.......@@@@...
	;;	.......@@..........@@...
	;;	.....@@@................
	;;	........................
	;;
	;;	@@@@@@@@@@....@@@@@@@@@@
	;;	@@@@@@@@..@@@@..@@@@@@@@
	;;	@@@@@@..@@@..@@@..@@@@@@
	;;	@@@@..@@@......@@@..@@@@
	;;	@@..@@@..........@@@..@@
	;;	@.@@@..............@@@.@
	;;	.@@..................@@.
	;;	@.@@@..............@@@.@
	;;	....@@@..........@@@....
	;;	......@@@......@@@......
	;;	........@@@..@@@........
	;;	..........@@@@..........
	;;	@......................@
	;;	@@....................@@
	;;	@@.@................@@@@
	;;	@@@.@@.............@@@@@
	;;	@@@@..@........@@@@.@@@@
	;;	@@@@@@.@@@....@..@@@.@@@
	;;	@@@@@.@@@.@@.@@@@..@@.@@
	;;	@@@@.@@@.@@.@..@@@@..@@@
	;;	@@@@.@@.@@.@@@@..@@@@.@@
	;;	@@@@@..@@.@@@@@@@..@@.@@
	;;	@@@@.@@@.@@@@@@@@@@..@@@
	;;	@@@@@...@@@@@@@@@@@@@@@@

							;; SPR_BONGO:      EQU &46
	DEFB &00, &00, &00, &00, &00, &00, &00, &7E, &00, &03, &FF, &C0, &0F, &FF, &F0, &1F
	DEFB &FF, &F8, &3F, &FF, &FC, &3F, &FF, &FC, &5F, &FF, &FA, &7F, &FF, &FE, &37, &FF
	DEFB &EC, &7E, &FF, &7E, &47, &DB, &E2, &21, &FF, &84, &2C, &E7, &34, &57, &6A, &EA
	DEFB &17, &B5, &E8, &4B, &42, &D2, &2A, &99, &54, &15, &3C, &A8, &06, &7E, &60, &01
	DEFB &81, &80, &00, &7E, &00, &00, &00, &00, &FF, &FF, &FF, &FF, &81, &FF, &FC, &7E
	DEFB &3F, &F3, &FF, &CF, &EF, &FF, &F7, &DF, &FF, &FB, &BF, &FF, &FD, &BF, &FF, &FD
	DEFB &5F, &FF, &FA, &7F, &FF, &FE, &B7, &FF, &ED, &7E, &FF, &7E, &47, &DB, &E2, &A1
	DEFB &FF, &85, &A0, &E7, &05, &10, &6A, &08, &90, &34, &09, &48, &42, &12, &A8, &81
	DEFB &15, &D5, &00, &AB, &E6, &00, &67, &F9, &81, &9F, &FE, &7E, &7F, &FF, &81, &FF

	;;	........................
	;;	........................
	;;	.........@@@@@@.........
	;;	......@@@@@@@@@@@@......
	;;	....@@@@@@@@@@@@@@@@....
	;;	...@@@@@@@@@@@@@@@@@@...
	;;	..@@@@@@@@@@@@@@@@@@@@..
	;;	..@@@@@@@@@@@@@@@@@@@@..
	;;	.@.@@@@@@@@@@@@@@@@@@.@.
	;;	.@@@@@@@@@@@@@@@@@@@@@@.
	;;	..@@.@@@@@@@@@@@@@@.@@..
	;;	.@@@@@@.@@@@@@@@.@@@@@@.
	;;	.@...@@@@@.@@.@@@@@...@.
	;;	..@....@@@@@@@@@@....@..
	;;	..@.@@..@@@..@@@..@@.@..
	;;	.@.@.@@@.@@.@.@.@@@.@.@.
	;;	...@.@@@@.@@.@.@@@@.@...
	;;	.@..@.@@.@....@.@@.@..@.
	;;	..@.@.@.@..@@..@.@.@.@..
	;;	...@.@.@..@@@@..@.@.@...
	;;	.....@@..@@@@@@..@@.....
	;;	.......@@......@@.......
	;;	.........@@@@@@.........
	;;	........................
	;;
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@......@@@@@@@@@
	;;	@@@@@@...@@@@@@...@@@@@@
	;;	@@@@..@@@@@@@@@@@@..@@@@
	;;	@@@.@@@@@@@@@@@@@@@@.@@@
	;;	@@.@@@@@@@@@@@@@@@@@@.@@
	;;	@.@@@@@@@@@@@@@@@@@@@@.@
	;;	@.@@@@@@@@@@@@@@@@@@@@.@
	;;	.@.@@@@@@@@@@@@@@@@@@.@.
	;;	.@@@@@@@@@@@@@@@@@@@@@@.
	;;	@.@@.@@@@@@@@@@@@@@.@@.@
	;;	.@@@@@@.@@@@@@@@.@@@@@@.
	;;	.@...@@@@@.@@.@@@@@...@.
	;;	@.@....@@@@@@@@@@....@.@
	;;	@.@.....@@@..@@@.....@.@
	;;	...@.....@@.@.@.....@...
	;;	@..@......@@.@......@..@
	;;	.@..@....@....@....@..@.
	;;	@.@.@...@......@...@.@.@
	;;	@@.@.@.@........@.@.@.@@
	;;	@@@..@@..........@@..@@@
	;;	@@@@@..@@......@@..@@@@@
	;;	@@@@@@@..@@@@@@..@@@@@@@
	;;	@@@@@@@@@......@@@@@@@@@

							;; SPR_DRUM:       EQU &47
	DEFB &00, &00, &00, &00, &7E, &00, &03, &FF, &C0, &0F, &FF, &F0, &1F, &FF, &F8, &3F
	DEFB &FF, &FC, &3F, &FF, &FC, &3F, &FF, &FC, &5F, &FF, &FA, &4F, &FF, &F2, &33, &FF
	DEFB &CC, &54, &7E, &2A, &8D, &81, &B1, &81, &BD, &81, &98, &3C, &11, &AA, &80, &A9
	DEFB &51, &55, &52, &5A, &AA, &A2, &28, &55, &04, &12, &00, &48, &0C, &54, &30, &03
	DEFB &81, &C0, &00, &7E, &00, &00, &00, &00, &FF, &81, &FF, &FC, &7E, &3F, &F3, &FF
	DEFB &CF, &EF, &FF, &F7, &DF, &FF, &FB, &BF, &FF, &FD, &BF, &FF, &FD, &BF, &FF, &FD
	DEFB &5F, &FF, &FA, &4F, &FF, &F2, &B3, &FF, &CD, &D4, &7E, &2B, &AD, &81, &B5, &A1
	DEFB &BD, &8D, &98, &3C, &05, &88, &00, &01, &D0, &00, &03, &D8, &00, &03, &E8, &00
	DEFB &07, &F2, &00, &0F, &FC, &00, &3F, &FF, &81, &FF, &FF, &FF, &FF, &FF, &FF, &FF

	;;	........................
	;;	.........@@@@@@.........
	;;	......@@@@@@@@@@@@......
	;;	....@@@@@@@@@@@@@@@@....
	;;	...@@@@@@@@@@@@@@@@@@...
	;;	..@@@@@@@@@@@@@@@@@@@@..
	;;	..@@@@@@@@@@@@@@@@@@@@..
	;;	..@@@@@@@@@@@@@@@@@@@@..
	;;	.@.@@@@@@@@@@@@@@@@@@.@.
	;;	.@..@@@@@@@@@@@@@@@@..@.
	;;	..@@..@@@@@@@@@@@@..@@..
	;;	.@.@.@...@@@@@@...@.@.@.
	;;	@...@@.@@......@@.@@...@
	;;	@......@@.@@@@.@@......@
	;;	@..@@.....@@@@.....@...@
	;;	@.@.@.@.@.......@.@.@..@
	;;	.@.@...@.@.@.@.@.@.@..@.
	;;	.@.@@.@.@.@.@.@.@.@...@.
	;;	..@.@....@.@.@.@.....@..
	;;	...@..@..........@..@...
	;;	....@@...@.@.@....@@....
	;;	......@@@......@@@......
	;;	.........@@@@@@.........
	;;	........................
	;;
	;;	@@@@@@@@@......@@@@@@@@@
	;;	@@@@@@...@@@@@@...@@@@@@
	;;	@@@@..@@@@@@@@@@@@..@@@@
	;;	@@@.@@@@@@@@@@@@@@@@.@@@
	;;	@@.@@@@@@@@@@@@@@@@@@.@@
	;;	@.@@@@@@@@@@@@@@@@@@@@.@
	;;	@.@@@@@@@@@@@@@@@@@@@@.@
	;;	@.@@@@@@@@@@@@@@@@@@@@.@
	;;	.@.@@@@@@@@@@@@@@@@@@.@.
	;;	.@..@@@@@@@@@@@@@@@@..@.
	;;	@.@@..@@@@@@@@@@@@..@@.@
	;;	@@.@.@...@@@@@@...@.@.@@
	;;	@.@.@@.@@......@@.@@.@.@
	;;	@.@....@@.@@@@.@@...@@.@
	;;	@..@@.....@@@@.......@.@
	;;	@...@..................@
	;;	@@.@..................@@
	;;	@@.@@.................@@
	;;	@@@.@................@@@
	;;	@@@@..@.............@@@@
	;;	@@@@@@............@@@@@@
	;;	@@@@@@@@@......@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@

							;; SPR_WELL:       EQU &48
	DEFB &00, &00, &00, &00, &7E, &00, &03, &BD, &C0, &0F, &81, &F0, &14, &7E, &28, &3B
	DEFB &7E, &DC, &3B, &00, &DC, &14, &00, &28, &2F, &81, &F4, &23, &7E, &C4, &2C, &7E
	DEFB &34, &0F, &00, &F0, &2F, &7E, &F4, &33, &7E, &CC, &38, &7E, &1C, &1B, &00, &D8
	DEFB &2B, &E7, &D4, &23, &E7, &C4, &2C, &E7, &34, &0F, &00, &F0, &0F, &7E, &F0, &03
	DEFB &7E, &C0, &00, &7E, &00, &00, &00, &00, &FF, &81, &FF, &FC, &7E, &3F, &F3, &BD
	DEFB &CF, &EF, &81, &F7, &D4, &00, &2B, &B8, &00, &1D, &B8, &00, &1D, &94, &00, &29
	DEFB &8F, &81, &F1, &83, &7E, &C1, &80, &7E, &01, &C0, &00, &03, &80, &00, &01, &80
	DEFB &00, &01, &80, &00, &01, &C0, &00, &03, &80, &00, &01, &80, &00, &01, &80, &00
	DEFB &01, &C0, &00, &03, &E0, &00, &07, &F0, &00, &0F, &FC, &00, &3F, &FF, &81, &FF

	;;	........................
	;;	.........@@@@@@.........
	;;	......@@@.@@@@.@@@......
	;;	....@@@@@......@@@@@....
	;;	...@.@...@@@@@@...@.@...
	;;	..@@@.@@.@@@@@@.@@.@@@..
	;;	..@@@.@@........@@.@@@..
	;;	...@.@............@.@...
	;;	..@.@@@@@......@@@@@.@..
	;;	..@...@@.@@@@@@.@@...@..
	;;	..@.@@...@@@@@@...@@.@..
	;;	....@@@@........@@@@....
	;;	..@.@@@@.@@@@@@.@@@@.@..
	;;	..@@..@@.@@@@@@.@@..@@..
	;;	..@@@....@@@@@@....@@@..
	;;	...@@.@@........@@.@@...
	;;	..@.@.@@@@@..@@@@@.@.@..
	;;	..@...@@@@@..@@@@@...@..
	;;	..@.@@..@@@..@@@..@@.@..
	;;	....@@@@........@@@@....
	;;	....@@@@.@@@@@@.@@@@....
	;;	......@@.@@@@@@.@@......
	;;	.........@@@@@@.........
	;;	........................
	;;
	;;	@@@@@@@@@......@@@@@@@@@
	;;	@@@@@@...@@@@@@...@@@@@@
	;;	@@@@..@@@.@@@@.@@@..@@@@
	;;	@@@.@@@@@......@@@@@.@@@
	;;	@@.@.@............@.@.@@
	;;	@.@@@..............@@@.@
	;;	@.@@@..............@@@.@
	;;	@..@.@............@.@..@
	;;	@...@@@@@......@@@@@...@
	;;	@.....@@.@@@@@@.@@.....@
	;;	@........@@@@@@........@
	;;	@@....................@@
	;;	@......................@
	;;	@......................@
	;;	@......................@
	;;	@@....................@@
	;;	@......................@
	;;	@......................@
	;;	@......................@
	;;	@@....................@@
	;;	@@@..................@@@
	;;	@@@@................@@@@
	;;	@@@@@@............@@@@@@
	;;	@@@@@@@@@......@@@@@@@@@

							;; SPR_STICK:      EQU &49
	DEFB &00, &7E, &00, &03, &81, &C0, &0C, &00, &30, &10, &00, &08, &20, &00, &04, &20
	DEFB &00, &04, &40, &00, &02, &50, &00, &0A, &40, &00, &02, &40, &00, &02, &22, &00
	DEFB &44, &21, &81, &84, &10, &7E, &08, &0C, &00, &30, &03, &81, &C0, &04, &7E, &20
	DEFB &1A, &00, &58, &3A, &00, &5C, &1D, &81, &B8, &06, &7E, &60, &01, &81, &80, &00
	DEFB &7E, &00, &00, &18, &00, &00, &00, &00, &FF, &81, &FF, &FC, &00, &3F, &F0, &00
	DEFB &0F, &E0, &00, &07, &C0, &00, &03, &C0, &00, &03, &80, &00, &01, &80, &00, &01
	DEFB &80, &00, &01, &80, &00, &01, &C0, &00, &03, &C0, &00, &03, &E0, &00, &07, &F0
	DEFB &00, &0F, &F8, &00, &1F, &E4, &00, &27, &D8, &00, &1B, &B8, &00, &1D, &DC, &00
	DEFB &3B, &E6, &00, &67, &F9, &81, &9F, &FE, &7E, &7F, &FF, &99, &FF, &FF, &E7, &FF

	;;	.........@@@@@@.........
	;;	......@@@......@@@......
	;;	....@@............@@....
	;;	...@................@...
	;;	..@..................@..
	;;	..@..................@..
	;;	.@....................@.
	;;	.@.@................@.@.
	;;	.@....................@.
	;;	.@....................@.
	;;	..@...@..........@...@..
	;;	..@....@@......@@....@..
	;;	...@.....@@@@@@.....@...
	;;	....@@............@@....
	;;	......@@@......@@@......
	;;	.....@...@@@@@@...@.....
	;;	...@@.@..........@.@@...
	;;	..@@@.@..........@.@@@..
	;;	...@@@.@@......@@.@@@...
	;;	.....@@..@@@@@@..@@.....
	;;	.......@@......@@.......
	;;	.........@@@@@@.........
	;;	...........@@...........
	;;	........................
	;;
	;;	@@@@@@@@@......@@@@@@@@@
	;;	@@@@@@............@@@@@@
	;;	@@@@................@@@@
	;;	@@@..................@@@
	;;	@@....................@@
	;;	@@....................@@
	;;	@......................@
	;;	@......................@
	;;	@......................@
	;;	@......................@
	;;	@@....................@@
	;;	@@....................@@
	;;	@@@..................@@@
	;;	@@@@................@@@@
	;;	@@@@@..............@@@@@
	;;	@@@..@............@..@@@
	;;	@@.@@..............@@.@@
	;;	@.@@@..............@@@.@
	;;	@@.@@@............@@@.@@
	;;	@@@..@@..........@@..@@@
	;;	@@@@@..@@......@@..@@@@@
	;;	@@@@@@@..@@@@@@..@@@@@@@
	;;	@@@@@@@@@..@@..@@@@@@@@@
	;;	@@@@@@@@@@@..@@@@@@@@@@@

							;; SPR_TRUNKS:     EQU &4A
	DEFB &00, &00, &00, &00, &3C, &00, &00, &C3, &00, &01, &00, &80, &0F, &00, &F0, &30
	DEFB &DB, &0C, &40, &24, &02, &40, &DB, &02, &71, &00, &8E, &3E, &00, &7C, &3D, &00
	DEFB &BC, &4D, &81, &B2, &71, &E7, &8E, &5C, &FF, &3A, &37, &3C, &EC, &4D, &C3, &B2
	DEFB &73, &7E, &CE, &7C, &DB, &3E, &3D, &3C, &BC, &05, &C3, &A0, &01, &FF, &80, &00
	DEFB &FF, &00, &00, &18, &00, &00, &00, &00, &FF, &FF, &FF, &FF, &C3, &FF, &FF, &00
	DEFB &FF, &FE, &00, &7F, &F0, &00, &0F, &C0, &18, &03, &00, &24, &00, &00, &18, &00
	DEFB &00, &00, &00, &80, &00, &01, &80, &00, &01, &40, &00, &02, &70, &00, &0E, &5C
	DEFB &00, &3A, &B7, &00, &ED, &0D, &C3, &B0, &03, &7E, &C0, &00, &DB, &00, &80, &3C
	DEFB &01, &C0, &00, &03, &F8, &00, &1F, &FE, &00, &7F, &FF, &00, &FF, &FF, &E7, &FF

	;;	........................
	;;	..........@@@@..........
	;;	........@@....@@........
	;;	.......@........@.......
	;;	....@@@@........@@@@....
	;;	..@@....@@.@@.@@....@@..
	;;	.@........@..@........@.
	;;	.@......@@.@@.@@......@.
	;;	.@@@...@........@...@@@.
	;;	..@@@@@..........@@@@@..
	;;	..@@@@.@........@.@@@@..
	;;	.@..@@.@@......@@.@@..@.
	;;	.@@@...@@@@..@@@@...@@@.
	;;	.@.@@@..@@@@@@@@..@@@.@.
	;;	..@@.@@@..@@@@..@@@.@@..
	;;	.@..@@.@@@....@@@.@@..@.
	;;	.@@@..@@.@@@@@@.@@..@@@.
	;;	.@@@@@..@@.@@.@@..@@@@@.
	;;	..@@@@.@..@@@@..@.@@@@..
	;;	.....@.@@@....@@@.@.....
	;;	.......@@@@@@@@@@.......
	;;	........@@@@@@@@........
	;;	...........@@...........
	;;	........................
	;;
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@....@@@@@@@@@@
	;;	@@@@@@@@........@@@@@@@@
	;;	@@@@@@@..........@@@@@@@
	;;	@@@@................@@@@
	;;	@@.........@@.........@@
	;;	..........@..@..........
	;;	...........@@...........
	;;	........................
	;;	@......................@
	;;	@......................@
	;;	.@....................@.
	;;	.@@@................@@@.
	;;	.@.@@@............@@@.@.
	;;	@.@@.@@@........@@@.@@.@
	;;	....@@.@@@....@@@.@@....
	;;	......@@.@@@@@@.@@......
	;;	........@@.@@.@@........
	;;	@.........@@@@.........@
	;;	@@....................@@
	;;	@@@@@..............@@@@@
	;;	@@@@@@@..........@@@@@@@
	;;	@@@@@@@@........@@@@@@@@
	;;	@@@@@@@@@@@..@@@@@@@@@@@

							;; SPR_DECK:       EQU &4B
	DEFB &00, &00, &00, &00, &18, &00, &00, &66, &00, &01, &89, &80, &06, &54, &60, &18
	DEFB &AA, &98, &35, &55, &4C, &32, &AA, &AC, &39, &55, &1C, &5E, &2A, &7A, &67, &91
	DEFB &E6, &79, &E7, &9E, &1E, &7E, &78, &67, &99, &E6, &79, &E7, &9E, &1E, &7E, &78
	DEFB &27, &99, &E4, &39, &E7, &9C, &1E, &7E, &78, &07, &99, &E0, &01, &E7, &80, &00
	DEFB &7E, &00, &00, &18, &00, &00, &00, &00, &FF, &E7, &FF, &FF, &81, &FF, &FE, &00
	DEFB &7F, &F8, &08, &1F, &E0, &54, &07, &C0, &AA, &83, &85, &55, &41, &82, &AA, &A1
	DEFB &81, &55, &01, &40, &2A, &02, &60, &10, &06, &78, &00, &1E, &9E, &00, &79, &67
	DEFB &81, &E6, &79, &E7, &9E, &9E, &7E, &79, &87, &99, &E1, &81, &E7, &81, &C0, &7E
	DEFB &03, &E0, &18, &07, &F8, &00, &1F, &FE, &00, &7F, &FF, &81, &FF, &FF, &E7, &FF

	;;	........................
	;;	...........@@...........
	;;	.........@@..@@.........
	;;	.......@@...@..@@.......
	;;	.....@@..@.@.@...@@.....
	;;	...@@...@.@.@.@.@..@@...
	;;	..@@.@.@.@.@.@.@.@..@@..
	;;	..@@..@.@.@.@.@.@.@.@@..
	;;	..@@@..@.@.@.@.@...@@@..
	;;	.@.@@@@...@.@.@..@@@@.@.
	;;	.@@..@@@@..@...@@@@..@@.
	;;	.@@@@..@@@@..@@@@..@@@@.
	;;	...@@@@..@@@@@@..@@@@...
	;;	.@@..@@@@..@@..@@@@..@@.
	;;	.@@@@..@@@@..@@@@..@@@@.
	;;	...@@@@..@@@@@@..@@@@...
	;;	..@..@@@@..@@..@@@@..@..
	;;	..@@@..@@@@..@@@@..@@@..
	;;	...@@@@..@@@@@@..@@@@...
	;;	.....@@@@..@@..@@@@.....
	;;	.......@@@@..@@@@.......
	;;	.........@@@@@@.........
	;;	...........@@...........
	;;	........................
	;;
	;;	@@@@@@@@@@@..@@@@@@@@@@@
	;;	@@@@@@@@@......@@@@@@@@@
	;;	@@@@@@@..........@@@@@@@
	;;	@@@@@.......@......@@@@@
	;;	@@@......@.@.@.......@@@
	;;	@@......@.@.@.@.@.....@@
	;;	@....@.@.@.@.@.@.@.....@
	;;	@.....@.@.@.@.@.@.@....@
	;;	@......@.@.@.@.@.......@
	;;	.@........@.@.@.......@.
	;;	.@@........@.........@@.
	;;	.@@@@..............@@@@.
	;;	@..@@@@..........@@@@..@
	;;	.@@..@@@@......@@@@..@@.
	;;	.@@@@..@@@@..@@@@..@@@@.
	;;	@..@@@@..@@@@@@..@@@@..@
	;;	@....@@@@..@@..@@@@....@
	;;	@......@@@@..@@@@......@
	;;	@@.......@@@@@@.......@@
	;;	@@@........@@........@@@
	;;	@@@@@..............@@@@@
	;;	@@@@@@@..........@@@@@@@
	;;	@@@@@@@@@......@@@@@@@@@
	;;	@@@@@@@@@@@..@@@@@@@@@@@

							;; SPR_BALL:       EQU &4C
	DEFB &00, &00, &00, &00, &7E, &00, &01, &FF, &80, &07, &FF, &E0, &0F, &FF, &F0, &1D
	DEFB &FF, &F8, &1B, &FF, &F8, &33, &FF, &FC, &37, &FF, &FC, &77, &FF, &FE, &7F, &FF
	DEFB &FE, &77, &FF, &FE, &7F, &FF, &FE, &7F, &FF, &FE, &7F, &FF, &FE, &3F, &FF, &FC
	DEFB &3F, &FF, &FC, &1F, &FF, &F8, &1F, &FF, &F8, &0F, &FF, &F0, &07, &FF, &E0, &01
	DEFB &FF, &80, &00, &7E, &00, &00, &00, &00, &FF, &81, &FF, &FE, &00, &7F, &F8, &00
	DEFB &1F, &F0, &00, &0F, &E0, &00, &07, &C0, &00, &03, &C0, &00, &03, &80, &00, &01
	DEFB &80, &00, &01, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
	DEFB &00, &00, &00, &00, &00, &80, &00, &01, &80, &00, &01, &C0, &00, &03, &C0, &00
	DEFB &03, &E0, &00, &07, &F0, &00, &0F, &F8, &00, &1F, &FE, &00, &7F, &FF, &81, &FF

	;;	........................
	;;	.........@@@@@@.........
	;;	.......@@@@@@@@@@.......
	;;	.....@@@@@@@@@@@@@@.....
	;;	....@@@@@@@@@@@@@@@@....
	;;	...@@@.@@@@@@@@@@@@@@...
	;;	...@@.@@@@@@@@@@@@@@@...
	;;	..@@..@@@@@@@@@@@@@@@@..
	;;	..@@.@@@@@@@@@@@@@@@@@..
	;;	.@@@.@@@@@@@@@@@@@@@@@@.
	;;	.@@@@@@@@@@@@@@@@@@@@@@.
	;;	.@@@.@@@@@@@@@@@@@@@@@@.
	;;	.@@@@@@@@@@@@@@@@@@@@@@.
	;;	.@@@@@@@@@@@@@@@@@@@@@@.
	;;	.@@@@@@@@@@@@@@@@@@@@@@.
	;;	..@@@@@@@@@@@@@@@@@@@@..
	;;	..@@@@@@@@@@@@@@@@@@@@..
	;;	...@@@@@@@@@@@@@@@@@@...
	;;	...@@@@@@@@@@@@@@@@@@...
	;;	....@@@@@@@@@@@@@@@@....
	;;	.....@@@@@@@@@@@@@@.....
	;;	.......@@@@@@@@@@.......
	;;	.........@@@@@@.........
	;;	........................
	;;
	;;	@@@@@@@@@......@@@@@@@@@
	;;	@@@@@@@..........@@@@@@@
	;;	@@@@@..............@@@@@
	;;	@@@@................@@@@
	;;	@@@..................@@@
	;;	@@....................@@
	;;	@@....................@@
	;;	@......................@
	;;	@......................@
	;;	........................
	;;	........................
	;;	........................
	;;	........................
	;;	........................
	;;	........................
	;;	@......................@
	;;	@......................@
	;;	@@....................@@
	;;	@@....................@@
	;;	@@@..................@@@
	;;	@@@@................@@@@
	;;	@@@@@..............@@@@@
	;;	@@@@@@@..........@@@@@@@
	;;	@@@@@@@@@......@@@@@@@@@

					;; SPR_HEAD_FLYING:       EQU &4D
	DEFB &00, &00, &00, &00, &1F, &00, &00, &7F, &C0, &00, &FF, &E0, &01, &FF, &20, &01
	DEFB &F9, &F0, &03, &F7, &F0, &03, &FF, &BC, &03, &FD, &A2, &25, &FD, &C1, &1D, &FF
	DEFB &C1, &0B, &FF, &81, &17, &9F, &41, &37, &3F, &02, &67, &BF, &02, &1B, &9B, &CE
	DEFB &0D, &6C, &3C, &0A, &F6, &60, &10, &B7, &80, &00, &60, &00, &00, &00, &00, &00
	DEFB &00, &00, &00, &00, &00, &00, &00, &00
	DEFB &FF, &E0, &FF, &FF, &9F, &3F, &FF, &7F
	DEFB &DF, &FE, &FF, &EF, &FD, &FF, &2F, &FD, &F9, &F7, &FB, &F7, &F7, &FB, &FF, &BF
	DEFB &DB, &FD, &A3, &81, &FD, &C1, &C1, &FF, &C1, &E3, &FF, &81, &C7, &9F, &41, &87
	DEFB &3F, &03, &07, &BF, &02, &83, &9B, &CC, &E1, &0C, &31, &E0, &06, &63, &C4, &07
	DEFB &9F, &EF, &08, &7F, &FF, &9F, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF

	;;	........................
	;;	...........@@@@@........
	;;	.........@@@@@@@@@......
	;;	........@@@@@@@@@@@.....
	;;	.......@@@@@@@@@..@.....
	;;	.......@@@@@@..@@@@@....
	;;	......@@@@@@.@@@@@@@....
	;;	......@@@@@@@@@@@.@@@@..
	;;	......@@@@@@@@.@@.@...@.
	;;	..@..@.@@@@@@@.@@@.....@
	;;	...@@@.@@@@@@@@@@@.....@
	;;	....@.@@@@@@@@@@@......@
	;;	...@.@@@@..@@@@@.@.....@
	;;	..@@.@@@..@@@@@@......@.
	;;	.@@..@@@@.@@@@@@......@.
	;;	...@@.@@@..@@.@@@@..@@@.
	;;	....@@.@.@@.@@....@@@@..
	;;	....@.@.@@@@.@@..@@.....
	;;	...@....@.@@.@@@@.......
	;;	.........@@.............
	;;	........................
	;;	........................
	;;	........................
	;;	........................
	;;
	;;	@@@@@@@@@@@.....@@@@@@@@
	;;	@@@@@@@@@..@@@@@..@@@@@@
	;;	@@@@@@@@.@@@@@@@@@.@@@@@
	;;	@@@@@@@.@@@@@@@@@@@.@@@@
	;;	@@@@@@.@@@@@@@@@..@.@@@@
	;;	@@@@@@.@@@@@@..@@@@@.@@@
	;;	@@@@@.@@@@@@.@@@@@@@.@@@
	;;	@@@@@.@@@@@@@@@@@.@@@@@@
	;;	@@.@@.@@@@@@@@.@@.@...@@
	;;	@......@@@@@@@.@@@.....@
	;;	@@.....@@@@@@@@@@@.....@
	;;	@@@...@@@@@@@@@@@......@
	;;	@@...@@@@..@@@@@.@.....@
	;;	@....@@@..@@@@@@......@@
	;;	.....@@@@.@@@@@@......@.
	;;	@.....@@@..@@.@@@@..@@..
	;;	@@@....@....@@....@@...@
	;;	@@@..........@@..@@...@@
	;;	@@...@.......@@@@..@@@@@
	;;	@@@.@@@@....@....@@@@@@@
	;;	@@@@@@@@@..@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@


;; -----------------------------------------------------------------------------------------------------------
SPR_DOORSTEP			EQU		&54
SPR_SANDWICH			EQU		&55
SPR_ROLLERS				EQU		&56
SPR_TELEPORT			EQU		&57
SPR_LAVAPIT				EQU		&58
SPR_PAD					EQU		&59
SPR_ANVIL				EQU		&5A
SPR_SPIKES				EQU		&5B
SPR_HUSHPUPPY			EQU		&5C
SPR_BOOK				EQU		&5D
SPR_TOASTER				EQU		&5E
SPR_CUSHION				EQU		&5F

;; -----------------------------------------------------------------------------------------------------------
img_4x28_bin:			;; SPR_DOORSTEP:       EQU &54
	DEFB &00, &00, &00, &00, &00, &03, &C0, &00, &00, &0E, &70, &00, &00, &38, &1C, &00
	DEFB &00, &E7, &C7, &00, &03, &9F, &F7, &80, &0E, &7F, &FC, &00, &38, &FF, &FB, &80
	DEFB &38, &FF, &C1, &00, &4E, &7F, &BB, &80, &73, &9C, &11, &00, &4C, &FB, &BB, &80
	DEFB &53, &01, &10, &00, &4C, &BB, &B8, &00, &32, &91, &00, &00, &0C, &BB, &80, &00
	DEFB &03, &90, &00, &00, &00, &B8, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00

	;;	................................
	;;	..............@@@@..............
	;;	............@@@..@@@............
	;;	..........@@@......@@@..........
	;;	........@@@..@@@@@...@@@........
	;;	......@@@..@@@@@@@@@.@@@@.......
	;;	....@@@..@@@@@@@@@@@@@..........
	;;	..@@@...@@@@@@@@@@@@@.@@@.......
	;;	..@@@...@@@@@@@@@@.....@........
	;;	.@..@@@..@@@@@@@@.@@@.@@@.......
	;;	.@@@..@@@..@@@.....@...@........
	;;	.@..@@..@@@@@.@@@.@@@.@@@.......
	;;	.@.@..@@.......@...@............
	;;	.@..@@..@.@@@.@@@.@@@...........
	;;	..@@..@.@..@...@................
	;;	....@@..@.@@@.@@@...............
	;;	......@@@..@....................
	;;	........@.@@@...................
	;;	................................
	;;	................................
	;;	................................
	;;	................................
	;;	................................
	;;	................................
	;;	................................
	;;	................................
	;;	................................
	;;	................................

	DEFB &FF, &FC, &3F, &FF, &FF, &F0, &0F, &FF, &FF, &C0, &03, &FF, &FF, &00, &00, &FF
	DEFB &FC, &00, &00, &3F, &F0, &00, &00, &3F, &C0, &00, &00, &3F, &80, &00, &03, &BF
	DEFB &00, &00, &01, &3F, &00, &00, &3B, &BF, &00, &00, &11, &3F, &00, &03, &BB, &BF
	DEFB &10, &01, &10, &7F, &0C, &3B, &BB, &FF, &02, &11, &07, &FF, &C0, &3B, &BF, &FF
	DEFB &F0, &10, &7F, &FF, &FC, &3B, &FF, &FF, &FF, &07, &FF, &FF, &FF, &FF, &FF, &FF
	DEFB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
	DEFB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF

	;;	@@@@@@@@@@@@@@....@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@........@@@@@@@@@@@@
	;;	@@@@@@@@@@............@@@@@@@@@@
	;;	@@@@@@@@................@@@@@@@@
	;;	@@@@@@....................@@@@@@
	;;	@@@@......................@@@@@@
	;;	@@........................@@@@@@
	;;	@.....................@@@.@@@@@@
	;;	.......................@..@@@@@@
	;;	..................@@@.@@@.@@@@@@
	;;	...................@...@..@@@@@@
	;;	..............@@@.@@@.@@@.@@@@@@
	;;	...@...........@...@.....@@@@@@@
	;;	....@@....@@@.@@@.@@@.@@@@@@@@@@
	;;	......@....@...@.....@@@@@@@@@@@
	;;	@@........@@@.@@@.@@@@@@@@@@@@@@
	;;	@@@@.......@.....@@@@@@@@@@@@@@@
	;;	@@@@@@....@@@.@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@.....@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

							;; SPR_SANDWICH:   EQU &55
	DEFB &00, &00, &00, &00, &00, &07, &80, &00, &00, &1F, &C0, &00, &00, &7F, &B8, &00
	DEFB &01, &FD, &FF, &00, &07, &FF, &FF, &C0, &1F, &DF, &FF, &F0, &3F, &FF, &FF, &FC
	DEFB &4F, &7F, &FF, &F2, &73, &FF, &FF, &CE, &7C, &FF, &FF, &3E, &3B, &3F, &FC, &FC
	DEFB &0B, &CF, &F3, &F0, &31, &F3, &CF, &CC, &0E, &FC, &3F, &30, &11, &3F, &FC, &C8
	DEFB &2E, &4F, &F3, &34, &47, &92, &CC, &E2, &77, &EC, &33, &EE, &77, &F3, &CF, &EE
	DEFB &37, &81, &81, &EC, &0B, &4C, &32, &D0, &02, &F3, &CF, &40, &00, &FC, &3F, &00
	DEFB &00, &3F, &FC, &00, &00, &0F, &F0, &00, &00, &02, &C0, &00, &00, &00, &00, &00
	DEFB &FF, &F8, &7F, &FF, &FF, &E7, &BF, &FF, &FF, &9F, &C7, &FF, &FE, &7F, &B8, &FF
	DEFB &F9, &FD, &FF, &3F, &E7, &FF, &FF, &CF, &DF, &DF, &FF, &F3, &BF, &FF, &FF, &FD
	DEFB &0F, &7F, &FF, &F0, &03, &FF, &FF, &C0, &00, &FF, &FF, &00, &80, &3F, &FC, &01
	DEFB &C0, &0F, &F0, &03, &B0, &03, &C0, &0D, &CE, &00, &00, &33, &D1, &00, &00, &CB
	DEFB &A4, &40, &03, &25, &02, &90, &0C, &40, &05, &4C, &32, &A0, &02, &A3, &C5, &40
	DEFB &85, &01, &80, &A1, &C2, &0C, &30, &43, &F0, &03, &C0, &0F, &FC, &00, &00, &3F
	DEFB &FF, &00, &00, &FF, &FF, &C0, &03, &FF, &FF, &F0, &0F, &FF, &FF, &FD, &3F, &FF

	;;	................................
	;;	.............@@@@...............
	;;	...........@@@@@@@..............
	;;	.........@@@@@@@@.@@@...........
	;;	.......@@@@@@@.@@@@@@@@@........
	;;	.....@@@@@@@@@@@@@@@@@@@@@......
	;;	...@@@@@@@.@@@@@@@@@@@@@@@@@....
	;;	..@@@@@@@@@@@@@@@@@@@@@@@@@@@@..
	;;	.@..@@@@.@@@@@@@@@@@@@@@@@@@..@.
	;;	.@@@..@@@@@@@@@@@@@@@@@@@@..@@@.
	;;	.@@@@@..@@@@@@@@@@@@@@@@..@@@@@.
	;;	..@@@.@@..@@@@@@@@@@@@..@@@@@@..
	;;	....@.@@@@..@@@@@@@@..@@@@@@....
	;;	..@@...@@@@@..@@@@..@@@@@@..@@..
	;;	....@@@.@@@@@@....@@@@@@..@@....
	;;	...@...@..@@@@@@@@@@@@..@@..@...
	;;	..@.@@@..@..@@@@@@@@..@@..@@.@..
	;;	.@...@@@@..@..@.@@..@@..@@@...@.
	;;	.@@@.@@@@@@.@@....@@..@@@@@.@@@.
	;;	.@@@.@@@@@@@..@@@@..@@@@@@@.@@@.
	;;	..@@.@@@@......@@......@@@@.@@..
	;;	....@.@@.@..@@....@@..@.@@.@....
	;;	......@.@@@@..@@@@..@@@@.@......
	;;	........@@@@@@....@@@@@@........
	;;	..........@@@@@@@@@@@@..........
	;;	............@@@@@@@@............
	;;	..............@.@@..............
	;;	................................
	;;
	;;	@@@@@@@@@@@@@....@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@..@@@@.@@@@@@@@@@@@@@
	;;	@@@@@@@@@..@@@@@@@...@@@@@@@@@@@
	;;	@@@@@@@..@@@@@@@@.@@@...@@@@@@@@
	;;	@@@@@..@@@@@@@.@@@@@@@@@..@@@@@@
	;;	@@@..@@@@@@@@@@@@@@@@@@@@@..@@@@
	;;	@@.@@@@@@@.@@@@@@@@@@@@@@@@@..@@
	;;	@.@@@@@@@@@@@@@@@@@@@@@@@@@@@@.@
	;;	....@@@@.@@@@@@@@@@@@@@@@@@@....
	;;	......@@@@@@@@@@@@@@@@@@@@......
	;;	........@@@@@@@@@@@@@@@@........
	;;	@.........@@@@@@@@@@@@.........@
	;;	@@..........@@@@@@@@..........@@
	;;	@.@@..........@@@@..........@@.@
	;;	@@..@@@...................@@..@@
	;;	@@.@...@................@@..@.@@
	;;	@.@..@...@............@@..@..@.@
	;;	......@.@..@........@@...@......
	;;	.....@.@.@..@@....@@..@.@.@.....
	;;	......@.@.@...@@@@...@.@.@......
	;;	@....@.@.......@@.......@.@....@
	;;	@@....@.....@@....@@.....@....@@
	;;	@@@@..........@@@@..........@@@@
	;;	@@@@@@....................@@@@@@
	;;	@@@@@@@@................@@@@@@@@
	;;	@@@@@@@@@@............@@@@@@@@@@
	;;	@@@@@@@@@@@@........@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@.@..@@@@@@@@@@@@@@

						;; SPR_ROLLERS:    EQU &56
	DEFB &00, &00, &00, &00, &00, &01, &80, &00, &00, &06, &C0, &00, &00, &19, &E0, &00
	DEFB &00, &67, &CC, &00, &01, &9F, &36, &00, &06, &7C, &CF, &00, &19, &F3, &3E, &70
	DEFB &3D, &CC, &F9, &98, &26, &33, &E6, &7C, &1A, &CF, &99, &FC, &35, &EE, &67, &FC
	DEFB &35, &31, &9F, &FA, &32, &D6, &7F, &E2, &35, &AF, &7F, &8A, &31, &A9, &BE, &3A
	DEFB &35, &96, &B8, &FA, &31, &AD, &A3, &FA, &35, &8D, &4F, &FA, &31, &AC, &BF, &F8
	DEFB &19, &8D, &BF, &F8, &01, &AC, &BF, &F0, &01, &8D, &BF, &C0, &00, &CC, &BF, &00
	DEFB &00, &0D, &BC, &00, &00, &0C, &B0, &00, &00, &06, &40, &00, &00, &00, &00, &00
	DEFB &FF, &FE, &7F, &FF, &FF, &F9, &BF, &FF, &FF, &E6, &DF, &FF, &FF, &99, &E3, &FF
	DEFB &FE, &67, &CD, &FF, &F9, &9F, &36, &FF, &E6, &7C, &CF, &0F, &D9, &F3, &3E, &77
	DEFB &BD, &CC, &F9, &9B, &A6, &33, &E6, &7D, &C2, &CF, &99, &FD, &85, &EE, &67, &FD
	DEFB &85, &31, &9F, &F8, &80, &16, &7F, &E0, &80, &2F, &7F, &80, &80, &29, &BE, &00
	DEFB &80, &00, &B8, &00, &80, &01, &A0, &00, &80, &01, &40, &00, &80, &00, &00, &01
	DEFB &C0, &00, &00, &03, &E4, &00, &00, &07, &FC, &00, &00, &0F, &FE, &00, &00, &3F
	DEFB &FF, &20, &00, &FF, &FF, &E0, &03, &FF, &FF, &F0, &0F, &FF, &FF, &F9, &BF, &FF

	;;	................................
	;;	...............@@...............
	;;	.............@@.@@..............
	;;	...........@@..@@@@.............
	;;	.........@@..@@@@@..@@..........
	;;	.......@@..@@@@@..@@.@@.........
	;;	.....@@..@@@@@..@@..@@@@........
	;;	...@@..@@@@@..@@..@@@@@..@@@....
	;;	..@@@@.@@@..@@..@@@@@..@@..@@...
	;;	..@..@@...@@..@@@@@..@@..@@@@@..
	;;	...@@.@.@@..@@@@@..@@..@@@@@@@..
	;;	..@@.@.@@@@.@@@..@@..@@@@@@@@@..
	;;	..@@.@.@..@@...@@..@@@@@@@@@@.@.
	;;	..@@..@.@@.@.@@..@@@@@@@@@@...@.
	;;	..@@.@.@@.@.@@@@.@@@@@@@@...@.@.
	;;	..@@...@@.@.@..@@.@@@@@...@@@.@.
	;;	..@@.@.@@..@.@@.@.@@@...@@@@@.@.
	;;	..@@...@@.@.@@.@@.@...@@@@@@@.@.
	;;	..@@.@.@@...@@.@.@..@@@@@@@@@.@.
	;;	..@@...@@.@.@@..@.@@@@@@@@@@@...
	;;	...@@..@@...@@.@@.@@@@@@@@@@@...
	;;	.......@@.@.@@..@.@@@@@@@@@@....
	;;	.......@@...@@.@@.@@@@@@@@......
	;;	........@@..@@..@.@@@@@@........
	;;	............@@.@@.@@@@..........
	;;	............@@..@.@@............
	;;	.............@@..@..............
	;;	................................
	;;
	;;	@@@@@@@@@@@@@@@..@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@..@@.@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@..@@.@@.@@@@@@@@@@@@@
	;;	@@@@@@@@@..@@..@@@@...@@@@@@@@@@
	;;	@@@@@@@..@@..@@@@@..@@.@@@@@@@@@
	;;	@@@@@..@@..@@@@@..@@.@@.@@@@@@@@
	;;	@@@..@@..@@@@@..@@..@@@@....@@@@
	;;	@@.@@..@@@@@..@@..@@@@@..@@@.@@@
	;;	@.@@@@.@@@..@@..@@@@@..@@..@@.@@
	;;	@.@..@@...@@..@@@@@..@@..@@@@@.@
	;;	@@....@.@@..@@@@@..@@..@@@@@@@.@
	;;	@....@.@@@@.@@@..@@..@@@@@@@@@.@
	;;	@....@.@..@@...@@..@@@@@@@@@@...
	;;	@..........@.@@..@@@@@@@@@@.....
	;;	@.........@.@@@@.@@@@@@@@.......
	;;	@.........@.@..@@.@@@@@.........
	;;	@...............@.@@@...........
	;;	@..............@@.@.............
	;;	@..............@.@..............
	;;	@..............................@
	;;	@@............................@@
	;;	@@@..@.......................@@@
	;;	@@@@@@......................@@@@
	;;	@@@@@@@...................@@@@@@
	;;	@@@@@@@@..@.............@@@@@@@@
	;;	@@@@@@@@@@@...........@@@@@@@@@@
	;;	@@@@@@@@@@@@........@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@..@@.@@@@@@@@@@@@@@

							;; SPR_TELEPORT:   EQU &57
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &03, &C0, &00, &00, &1C, &38, &00
	DEFB &00, &62, &46, &00, &01, &9E, &29, &80, &03, &7E, &54, &C0, &06, &FC, &2A, &60
	DEFB &0C, &01, &80, &30, &15, &54, &3F, &A8, &26, &AA, &7F, &64, &33, &54, &7E, &CC
	DEFB &5D, &8A, &79, &BA, &5E, &60, &46, &7A, &6F, &9C, &39, &F6, &6F, &E3, &C7, &F6
	DEFB &77, &F8, &1F, &EE, &77, &FD, &BF, &EE, &78, &01, &80, &1E, &7A, &A9, &95, &5E
	DEFB &39, &55, &AA, &9C, &0E, &A9, &95, &70, &03, &55, &AA, &C0, &00, &E9, &97, &00
	DEFB &00, &35, &AC, &00, &00, &0D, &B0, &00, &00, &03, &C0, &00, &00, &00, &00, &00
	DEFB &FF, &FF, &FF, &FF, &FF, &FC, &3F, &FF, &FF, &E0, &07, &FF, &FF, &80, &01, &FF
	DEFB &FE, &00, &40, &7F, &FC, &00, &28, &3F, &F8, &00, &54, &1F, &F0, &00, &2A, &0F
	DEFB &E0, &01, &80, &07, &C1, &54, &00, &03, &A0, &AA, &00, &05, &B0, &54, &00, &0D
	DEFB &5C, &0A, &00, &3A, &5E, &00, &00, &7A, &6F, &80, &01, &F6, &6F, &E0, &07, &F6
	DEFB &77, &F8, &1F, &EE, &77, &FC, &3F, &EE, &78, &00, &00, &1E, &7A, &A8, &15, &5E
	DEFB &B9, &54, &2A, &9D, &CE, &A8, &15, &73, &F3, &54, &2A, &CF, &FC, &E8, &17, &3F
	DEFB &FF, &34, &2C, &FF, &FF, &CC, &33, &FF, &FF, &F0, &0F, &FF, &FF, &FC, &3F, &FF

	;;	................................
	;;	................................
	;;	..............@@@@..............
	;;	...........@@@....@@@...........
	;;	.........@@...@..@...@@.........
	;;	.......@@..@@@@...@.@..@@.......
	;;	......@@.@@@@@@..@.@.@..@@......
	;;	.....@@.@@@@@@....@.@.@..@@.....
	;;	....@@.........@@.........@@....
	;;	...@.@.@.@.@.@....@@@@@@@.@.@...
	;;	..@..@@.@.@.@.@..@@@@@@@.@@..@..
	;;	..@@..@@.@.@.@...@@@@@@.@@..@@..
	;;	.@.@@@.@@...@.@..@@@@..@@.@@@.@.
	;;	.@.@@@@..@@......@...@@..@@@@.@.
	;;	.@@.@@@@@..@@@....@@@..@@@@@.@@.
	;;	.@@.@@@@@@@...@@@@...@@@@@@@.@@.
	;;	.@@@.@@@@@@@@......@@@@@@@@.@@@.
	;;	.@@@.@@@@@@@@@.@@.@@@@@@@@@.@@@.
	;;	.@@@@..........@@..........@@@@.
	;;	.@@@@.@.@.@.@..@@..@.@.@.@.@@@@.
	;;	..@@@..@.@.@.@.@@.@.@.@.@..@@@..
	;;	....@@@.@.@.@..@@..@.@.@.@@@....
	;;	......@@.@.@.@.@@.@.@.@.@@......
	;;	........@@@.@..@@..@.@@@........
	;;	..........@@.@.@@.@.@@..........
	;;	............@@.@@.@@............
	;;	..............@@@@..............
	;;	................................
	;;
	;;	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@....@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@..........@@@@@@@@@@@
	;;	@@@@@@@@@..............@@@@@@@@@
	;;	@@@@@@@..........@.......@@@@@@@
	;;	@@@@@@............@.@.....@@@@@@
	;;	@@@@@............@.@.@.....@@@@@
	;;	@@@@..............@.@.@.....@@@@
	;;	@@@............@@............@@@
	;;	@@.....@.@.@.@................@@
	;;	@.@.....@.@.@.@..............@.@
	;;	@.@@.....@.@.@..............@@.@
	;;	.@.@@@......@.@...........@@@.@.
	;;	.@.@@@@..................@@@@.@.
	;;	.@@.@@@@@..............@@@@@.@@.
	;;	.@@.@@@@@@@..........@@@@@@@.@@.
	;;	.@@@.@@@@@@@@......@@@@@@@@.@@@.
	;;	.@@@.@@@@@@@@@....@@@@@@@@@.@@@.
	;;	.@@@@......................@@@@.
	;;	.@@@@.@.@.@.@......@.@.@.@.@@@@.
	;;	@.@@@..@.@.@.@....@.@.@.@..@@@.@
	;;	@@..@@@.@.@.@......@.@.@.@@@..@@
	;;	@@@@..@@.@.@.@....@.@.@.@@..@@@@
	;;	@@@@@@..@@@.@......@.@@@..@@@@@@
	;;	@@@@@@@@..@@.@....@.@@..@@@@@@@@
	;;	@@@@@@@@@@..@@....@@..@@@@@@@@@@
	;;	@@@@@@@@@@@@........@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@....@@@@@@@@@@@@@@

							;; SPR_LAVAPIT:   EQU &58
	DEFB &00, &00, &00, &00, &00, &03, &C0, &00, &00, &1C, &38, &00, &00, &61, &C6, &00
	DEFB &01, &8A, &B9, &80, &03, &2A, &AE, &C0, &06, &55, &56, &60, &0B, &2A, &AE, &D0
	DEFB &12, &8A, &B9, &D8, &36, &E1, &47, &6C, &2C, &DC, &3D, &74, &1D, &97, &E5, &B8
	DEFB &5B, &76, &B6, &DA, &67, &64, &B3, &66, &32, &ED, &9B, &8C, &5C, &D9, &DD, &3A
	DEFB &27, &1B, &68, &E4, &69, &E3, &C7, &96, &5C, &3C, &3C, &32, &5B, &47, &E2, &DA
	DEFB &33, &68, &16, &CC, &0E, &6D, &76, &70, &02, &CD, &BB, &40, &00, &D9, &BB, &00
	DEFB &00, &33, &9C, &00, &00, &0E, &D0, &00, &00, &02, &C0, &00, &00, &00, &00, &00
	DEFB &FF, &FC, &3F, &FF, &FF, &E3, &C7, &FF, &FF, &9C, &39, &FF, &FE, &60, &06, &7F
	DEFB &FD, &80, &01, &BF, &FB, &00, &00, &DF, &F6, &00, &00, &6F, &EB, &00, &00, &D7
	DEFB &D2, &80, &01, &DB, &B6, &E0, &07, &6D, &AC, &DC, &3D, &75, &9D, &97, &E5, &B9
	DEFB &1B, &76, &B6, &D8, &07, &64, &B3, &60, &82, &ED, &9B, &81, &40, &D9, &DD, &02
	DEFB &A0, &1B, &68, &05, &68, &03, &C0, &16, &5C, &00, &00, &32, &5B, &40, &02, &DA
	DEFB &B3, &68, &16, &CD, &CE, &6D, &76, &73, &F2, &CD, &BB, &4F, &FC, &D9, &BB, &3F
	DEFB &FF, &33, &9C, &FF, &FF, &CE, &D3, &FF, &FF, &F2, &CF, &FF, &FF, &FD, &3F, &FF

	;;	................................
	;;	..............@@@@..............
	;;	...........@@@....@@@...........
	;;	.........@@....@@@...@@.........
	;;	.......@@...@.@.@.@@@..@@.......
	;;	......@@..@.@.@.@.@.@@@.@@......
	;;	.....@@..@.@.@.@.@.@.@@..@@.....
	;;	....@.@@..@.@.@.@.@.@@@.@@.@....
	;;	...@..@.@...@.@.@.@@@..@@@.@@...
	;;	..@@.@@.@@@....@.@...@@@.@@.@@..
	;;	..@.@@..@@.@@@....@@@@.@.@@@.@..
	;;	...@@@.@@..@.@@@@@@..@.@@.@@@...
	;;	.@.@@.@@.@@@.@@.@.@@.@@.@@.@@.@.
	;;	.@@..@@@.@@..@..@.@@..@@.@@..@@.
	;;	..@@..@.@@@.@@.@@..@@.@@@...@@..
	;;	.@.@@@..@@.@@..@@@.@@@.@..@@@.@.
	;;	..@..@@@...@@.@@.@@.@...@@@..@..
	;;	.@@.@..@@@@...@@@@...@@@@..@.@@.
	;;	.@.@@@....@@@@....@@@@....@@..@.
	;;	.@.@@.@@.@...@@@@@@...@.@@.@@.@.
	;;	..@@..@@.@@.@......@.@@.@@..@@..
	;;	....@@@..@@.@@.@.@@@.@@..@@@....
	;;	......@.@@..@@.@@.@@@.@@.@......
	;;	........@@.@@..@@.@@@.@@........
	;;	..........@@..@@@..@@@..........
	;;	............@@@.@@.@............
	;;	..............@.@@..............
	;;	................................
	;;
	;;	@@@@@@@@@@@@@@....@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@...@@@@...@@@@@@@@@@@
	;;	@@@@@@@@@..@@@....@@@..@@@@@@@@@
	;;	@@@@@@@..@@..........@@..@@@@@@@
	;;	@@@@@@.@@..............@@.@@@@@@
	;;	@@@@@.@@................@@.@@@@@
	;;	@@@@.@@..................@@.@@@@
	;;	@@@.@.@@................@@.@.@@@
	;;	@@.@..@.@..............@@@.@@.@@
	;;	@.@@.@@.@@@..........@@@.@@.@@.@
	;;	@.@.@@..@@.@@@....@@@@.@.@@@.@.@
	;;	@..@@@.@@..@.@@@@@@..@.@@.@@@..@
	;;	...@@.@@.@@@.@@.@.@@.@@.@@.@@...
	;;	.....@@@.@@..@..@.@@..@@.@@.....
	;;	@.....@.@@@.@@.@@..@@.@@@......@
	;;	.@......@@.@@..@@@.@@@.@......@.
	;;	@.@........@@.@@.@@.@........@.@
	;;	.@@.@.........@@@@.........@.@@.
	;;	.@.@@@....................@@..@.
	;;	.@.@@.@@.@............@.@@.@@.@.
	;;	@.@@..@@.@@.@......@.@@.@@..@@.@
	;;	@@..@@@..@@.@@.@.@@@.@@..@@@..@@
	;;	@@@@..@.@@..@@.@@.@@@.@@.@..@@@@
	;;	@@@@@@..@@.@@..@@.@@@.@@..@@@@@@
	;;	@@@@@@@@..@@..@@@..@@@..@@@@@@@@
	;;	@@@@@@@@@@..@@@.@@.@..@@@@@@@@@@
	;;	@@@@@@@@@@@@..@.@@..@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@.@..@@@@@@@@@@@@@@

							;; SPR_PAD:        EQU &59
	DEFB &00, &00, &00, &00, &00, &03, &C0, &00, &00, &0E, &70, &00, &00, &39, &9C, &00
	DEFB &00, &E6, &67, &00, &03, &99, &99, &C0, &0E, &67, &E6, &70, &39, &8C, &31, &9C
	DEFB &39, &60, &06, &9C, &0E, &58, &1A, &70, &33, &96, &69, &CC, &1C, &E5, &A7, &38
	DEFB &23, &39, &9C, &C4, &41, &CE, &73, &82, &7A, &33, &CC, &5E, &34, &1C, &38, &2C
	DEFB &47, &A3, &C5, &E2, &7B, &41, &82, &DE, &34, &7A, &5E, &2C, &47, &B4, &2D, &E2
	DEFB &33, &47, &E2, &CC, &0C, &7B, &DE, &30, &03, &34, &2C, &C0, &00, &C7, &E3, &00
	DEFB &00, &33, &CC, &00, &00, &0C, &30, &00, &00, &03, &C0, &00, &00, &00, &00, &00
	DEFB &FF, &FC, &3F, &FF, &FF, &F3, &CF, &FF, &FF, &CE, &73, &FF, &FF, &38, &1C, &FF
	DEFB &FC, &E0, &07, &3F, &F3, &80, &01, &CF, &CE, &00, &00, &73, &B8, &00, &00, &1D
	DEFB &B8, &00, &00, &1D, &CE, &00, &00, &73, &83, &80, &01, &C1, &C0, &E0, &07, &03
	DEFB &80, &38, &1C, &01, &00, &0E, &70, &00, &00, &03, &C0, &00, &80, &00, &00, &01
	DEFB &40, &00, &00, &02, &78, &00, &00, &1E, &B4, &00, &00, &2D, &07, &80, &01, &E0
	DEFB &83, &40, &02, &C1, &C0, &78, &1E, &03, &F0, &34, &2C, &0F, &FC, &07, &E0, &3F
	DEFB &FF, &03, &C0, &FF, &FF, &C0, &03, &FF, &FF, &F0, &0F, &FF, &FF, &FC, &3F, &FF

	;;	................................
	;;	..............@@@@..............
	;;	............@@@..@@@............
	;;	..........@@@..@@..@@@..........
	;;	........@@@..@@..@@..@@@........
	;;	......@@@..@@..@@..@@..@@@......
	;;	....@@@..@@..@@@@@@..@@..@@@....
	;;	..@@@..@@...@@....@@...@@..@@@..
	;;	..@@@..@.@@..........@@.@..@@@..
	;;	....@@@..@.@@......@@.@..@@@....
	;;	..@@..@@@..@.@@..@@.@..@@@..@@..
	;;	...@@@..@@@..@.@@.@..@@@..@@@...
	;;	..@...@@..@@@..@@..@@@..@@...@..
	;;	.@.....@@@..@@@..@@@..@@@.....@.
	;;	.@@@@.@...@@..@@@@..@@...@.@@@@.
	;;	..@@.@.....@@@....@@@.....@.@@..
	;;	.@...@@@@.@...@@@@...@.@@@@...@.
	;;	.@@@@.@@.@.....@@.....@.@@.@@@@.
	;;	..@@.@...@@@@.@..@.@@@@...@.@@..
	;;	.@...@@@@.@@.@....@.@@.@@@@...@.
	;;	..@@..@@.@...@@@@@@...@.@@..@@..
	;;	....@@...@@@@.@@@@.@@@@...@@....
	;;	......@@..@@.@....@.@@..@@......
	;;	........@@...@@@@@@...@@........
	;;	..........@@..@@@@..@@..........
	;;	............@@....@@............
	;;	..............@@@@..............
	;;	................................
	;;
	;;	@@@@@@@@@@@@@@....@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@..@@@@..@@@@@@@@@@@@
	;;	@@@@@@@@@@..@@@..@@@..@@@@@@@@@@
	;;	@@@@@@@@..@@@......@@@..@@@@@@@@
	;;	@@@@@@..@@@..........@@@..@@@@@@
	;;	@@@@..@@@..............@@@..@@@@
	;;	@@..@@@..................@@@..@@
	;;	@.@@@......................@@@.@
	;;	@.@@@......................@@@.@
	;;	@@..@@@..................@@@..@@
	;;	@.....@@@..............@@@.....@
	;;	@@......@@@..........@@@......@@
	;;	@.........@@@......@@@.........@
	;;	............@@@..@@@............
	;;	..............@@@@..............
	;;	@..............................@
	;;	.@............................@.
	;;	.@@@@......................@@@@.
	;;	@.@@.@....................@.@@.@
	;;	.....@@@@..............@@@@.....
	;;	@.....@@.@............@.@@.....@
	;;	@@.......@@@@......@@@@.......@@
	;;	@@@@......@@.@....@.@@......@@@@
	;;	@@@@@@.......@@@@@@.......@@@@@@
	;;	@@@@@@@@......@@@@......@@@@@@@@
	;;	@@@@@@@@@@............@@@@@@@@@@
	;;	@@@@@@@@@@@@........@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@....@@@@@@@@@@@@@@

							;; SPR_ANVIL:      EQU &5A
	DEFB &00, &00, &00, &00, &00, &03, &C0, &00, &00, &0C, &30, &00, &00, &33, &CC, &00
	DEFB &00, &CC, &33, &00, &03, &33, &CC, &C0, &0C, &CC, &33, &30, &33, &33, &CC, &CC
	DEFB &33, &33, &CC, &CC, &1C, &CC, &33, &38, &07, &33, &CC, &E0, &03, &CC, &33, &80
	DEFB &03, &F3, &CE, &40, &0B, &FC, &39, &B0, &37, &F7, &E7, &CC, &5F, &F0, &01, &9A
	DEFB &67, &F0, &00, &66, &59, &F8, &01, &9A, &56, &78, &06, &6A, &55, &9E, &19, &AA
	DEFB &35, &67, &E6, &AC, &0D, &59, &9A, &B0, &03, &56, &6A, &C0, &00, &D5, &AB, &00
	DEFB &00, &35, &AC, &00, &00, &0D, &B0, &00, &00, &03, &C0, &00, &00, &00, &00, &00
	DEFB &FF, &FC, &3F, &FF, &FF, &F3, &CF, &FF, &FF, &CC, &33, &FF, &FF, &30, &0C, &FF
	DEFB &FC, &C0, &03, &3F, &F3, &03, &C0, &CF, &CC, &0C, &30, &33, &B0, &30, &0C, &0D
	DEFB &B0, &30, &0C, &0D, &DC, &0C, &30, &3B, &E7, &03, &C0, &E7, &FB, &C0, &03, &9F
	DEFB &F3, &F0, &0E, &4F, &CB, &FC, &39, &B3, &B7, &F7, &E7, &CD, &1F, &F0, &19, &98
	DEFB &07, &F7, &FE, &60, &01, &FB, &F9, &80, &00, &79, &E6, &00, &00, &1E, &18, &00
	DEFB &80, &07, &E0, &01, &C0, &01, &80, &03, &F0, &00, &00, &0F, &FC, &00, &00, &3F
	DEFB &FF, &00, &00, &FF, &FF, &C0, &03, &FF, &FF, &F0, &0F, &FF, &FF, &FC, &3F, &FF

	;;	................................
	;;	..............@@@@..............
	;;	............@@....@@............
	;;	..........@@..@@@@..@@..........
	;;	........@@..@@....@@..@@........
	;;	......@@..@@..@@@@..@@..@@......
	;;	....@@..@@..@@....@@..@@..@@....
	;;	..@@..@@..@@..@@@@..@@..@@..@@..
	;;	..@@..@@..@@..@@@@..@@..@@..@@..
	;;	...@@@..@@..@@....@@..@@..@@@...
	;;	.....@@@..@@..@@@@..@@..@@@.....
	;;	......@@@@..@@....@@..@@@.......
	;;	......@@@@@@..@@@@..@@@..@......
	;;	....@.@@@@@@@@....@@@..@@.@@....
	;;	..@@.@@@@@@@.@@@@@@..@@@@@..@@..
	;;	.@.@@@@@@@@@...........@@..@@.@.
	;;	.@@..@@@@@@@.............@@..@@.
	;;	.@.@@..@@@@@@..........@@..@@.@.
	;;	.@.@.@@..@@@@........@@..@@.@.@.
	;;	.@.@.@.@@..@@@@....@@..@@.@.@.@.
	;;	..@@.@.@.@@..@@@@@@..@@.@.@.@@..
	;;	....@@.@.@.@@..@@..@@.@.@.@@....
	;;	......@@.@.@.@@..@@.@.@.@@......
	;;	........@@.@.@.@@.@.@.@@........
	;;	..........@@.@.@@.@.@@..........
	;;	............@@.@@.@@............
	;;	..............@@@@..............
	;;	................................
	;;
	;;	@@@@@@@@@@@@@@....@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@..@@@@..@@@@@@@@@@@@
	;;	@@@@@@@@@@..@@....@@..@@@@@@@@@@
	;;	@@@@@@@@..@@........@@..@@@@@@@@
	;;	@@@@@@..@@............@@..@@@@@@
	;;	@@@@..@@......@@@@......@@..@@@@
	;;	@@..@@......@@....@@......@@..@@
	;;	@.@@......@@........@@......@@.@
	;;	@.@@......@@........@@......@@.@
	;;	@@.@@@......@@....@@......@@@.@@
	;;	@@@..@@@......@@@@......@@@..@@@
	;;	@@@@@.@@@@............@@@..@@@@@
	;;	@@@@..@@@@@@........@@@..@..@@@@
	;;	@@..@.@@@@@@@@....@@@..@@.@@..@@
	;;	@.@@.@@@@@@@.@@@@@@..@@@@@..@@.@
	;;	...@@@@@@@@@.......@@..@@..@@...
	;;	.....@@@@@@@.@@@@@@@@@@..@@.....
	;;	.......@@@@@@.@@@@@@@..@@.......
	;;	.........@@@@..@@@@..@@.........
	;;	...........@@@@....@@...........
	;;	@............@@@@@@............@
	;;	@@.............@@.............@@
	;;	@@@@........................@@@@
	;;	@@@@@@....................@@@@@@
	;;	@@@@@@@@................@@@@@@@@
	;;	@@@@@@@@@@............@@@@@@@@@@
	;;	@@@@@@@@@@@@........@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@....@@@@@@@@@@@@@@

							;; SPR_SPIKES:     EQU &5B
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &08, &10, &00, &00, &08, &10, &00
	DEFB &00, &8C, &31, &00, &00, &9C, &39, &00, &08, &DD, &BB, &10, &09, &DE, &7B, &90
	DEFB &09, &DE, &7B, &90, &15, &EE, &77, &A8, &15, &AE, &75, &A8, &0D, &4E, &72, &B0
	DEFB &2E, &48, &12, &74, &6E, &C4, &23, &76, &32, &E4, &27, &4C, &0C, &EC, &37, &30
	DEFB &13, &2E, &74, &C8, &1C, &CE, &73, &38, &5D, &32, &4C, &BA, &6D, &CC, &33, &B6
	DEFB &31, &D3, &CB, &8C, &0E, &DC, &3B, &70, &03, &1E, &78, &C0, &00, &EC, &37, &00
	DEFB &00, &32, &4C, &00, &00, &0F, &F0, &00, &00, &03, &C0, &00, &00, &00, &00, &00
	DEFB &FF, &FF, &FF, &FF, &FF, &F7, &EF, &FF, &FF, &EB, &D7, &FF, &FF, &6B, &D6, &FF
	DEFB &FE, &AD, &B5, &7F, &F6, &9C, &39, &6F, &EA, &DC, &3B, &57, &E9, &DE, &7B, &97
	DEFB &E9, &DE, &7B, &97, &D5, &EE, &77, &AB, &D5, &AE, &75, &AB, &CD, &4E, &72, &B3
	DEFB &8E, &48, &12, &71, &0E, &C4, &23, &70, &82, &E4, &27, &41, &C0, &EC, &37, &03
	DEFB &D0, &2E, &74, &0B, &9C, &0E, &70, &39, &1D, &02, &40, &B8, &0D, &C0, &03, &B0
	DEFB &81, &D0, &0B, &81, &C0, &DC, &3B, &03, &F0, &1E, &78, &0F, &FC, &0C, &30, &3F
	DEFB &FF, &00, &00, &FF, &FF, &C0, &03, &FF, &FF, &F0, &0F, &FF, &FF, &FC, &3F, &FF

	;;	................................
	;;	................................
	;;	............@......@............
	;;	............@......@............
	;;	........@...@@....@@...@........
	;;	........@..@@@....@@@..@........
	;;	....@...@@.@@@.@@.@@@.@@...@....
	;;	....@..@@@.@@@@..@@@@.@@@..@....
	;;	....@..@@@.@@@@..@@@@.@@@..@....
	;;	...@.@.@@@@.@@@..@@@.@@@@.@.@...
	;;	...@.@.@@.@.@@@..@@@.@.@@.@.@...
	;;	....@@.@.@..@@@..@@@..@.@.@@....
	;;	..@.@@@..@..@......@..@..@@@.@..
	;;	.@@.@@@.@@...@....@...@@.@@@.@@.
	;;	..@@..@.@@@..@....@..@@@.@..@@..
	;;	....@@..@@@.@@....@@.@@@..@@....
	;;	...@..@@..@.@@@..@@@.@..@@..@...
	;;	...@@@..@@..@@@..@@@..@@..@@@...
	;;	.@.@@@.@..@@..@..@..@@..@.@@@.@.
	;;	.@@.@@.@@@..@@....@@..@@@.@@.@@.
	;;	..@@...@@@.@..@@@@..@.@@@...@@..
	;;	....@@@.@@.@@@....@@@.@@.@@@....
	;;	......@@...@@@@..@@@@...@@......
	;;	........@@@.@@....@@.@@@........
	;;	..........@@..@..@..@@..........
	;;	............@@@@@@@@............
	;;	..............@@@@..............
	;;	................................
	;;
	;;	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@.@@@@@@.@@@@@@@@@@@@
	;;	@@@@@@@@@@@.@.@@@@.@.@@@@@@@@@@@
	;;	@@@@@@@@.@@.@.@@@@.@.@@.@@@@@@@@
	;;	@@@@@@@.@.@.@@.@@.@@.@.@.@@@@@@@
	;;	@@@@.@@.@..@@@....@@@..@.@@.@@@@
	;;	@@@.@.@.@@.@@@....@@@.@@.@.@.@@@
	;;	@@@.@..@@@.@@@@..@@@@.@@@..@.@@@
	;;	@@@.@..@@@.@@@@..@@@@.@@@..@.@@@
	;;	@@.@.@.@@@@.@@@..@@@.@@@@.@.@.@@
	;;	@@.@.@.@@.@.@@@..@@@.@.@@.@.@.@@
	;;	@@..@@.@.@..@@@..@@@..@.@.@@..@@
	;;	@...@@@..@..@......@..@..@@@...@
	;;	....@@@.@@...@....@...@@.@@@....
	;;	@.....@.@@@..@....@..@@@.@.....@
	;;	@@......@@@.@@....@@.@@@......@@
	;;	@@.@......@.@@@..@@@.@......@.@@
	;;	@..@@@......@@@..@@@......@@@..@
	;;	...@@@.@......@..@......@.@@@...
	;;	....@@.@@@............@@@.@@....
	;;	@......@@@.@........@.@@@......@
	;;	@@......@@.@@@....@@@.@@......@@
	;;	@@@@.......@@@@..@@@@.......@@@@
	;;	@@@@@@......@@....@@......@@@@@@
	;;	@@@@@@@@................@@@@@@@@
	;;	@@@@@@@@@@............@@@@@@@@@@
	;;	@@@@@@@@@@@@........@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@....@@@@@@@@@@@@@@

							;; SPR_HUSHPUPPY:  EQU &5C
	DEFB &00, &00, &00, &00, &00, &01, &C0, &00, &00, &07, &F0, &00, &00, &0F, &F8, &00
	DEFB &00, &1F, &F7, &00, &00, &7C, &3F, &C0, &01, &F0, &0F, &E0, &1C, &20, &07, &F4
	DEFB &3F, &C0, &07, &F6, &63, &F8, &0F, &78, &6F, &FE, &3E, &F8, &1E, &7F, &7E, &F8
	DEFB &1B, &7F, &1E, &FC, &35, &E7, &EF, &7C, &31, &F7, &F7, &3E, &3B, &DE, &7A, &4E
	DEFB &3F, &AF, &79, &F6, &51, &8F, &B3, &FE, &52, &DF, &8B, &FE, &58, &FF, &BD, &FC
	DEFB &2B, &F6, &5D, &F8, &03, &F1, &FD, &70, &00, &E7, &FD, &40, &00, &0F, &F8, &00
	DEFB &00, &0B, &F0, &00, &00, &0A, &E0, &00, &00, &02, &80, &00, &00, &00, &00, &00
	DEFB &FF, &FE, &3F, &FF, &FF, &F8, &0F, &FF, &FF, &F0, &07, &FF, &FF, &E0, &00, &FF
	DEFB &FF, &80, &00, &3F, &FE, &00, &00, &0F, &E0, &00, &00, &03, &C0, &00, &00, &05
	DEFB &80, &00, &00, &06, &00, &00, &00, &01, &00, &00, &00, &03, &80, &00, &00, &03
	DEFB &C0, &00, &00, &01, &84, &00, &00, &01, &80, &00, &00, &00, &80, &00, &00, &40
	DEFB &80, &20, &01, &F0, &40, &00, &03, &F8, &42, &00, &03, &FC, &40, &00, &01, &FD
	DEFB &A0, &00, &41, &FB, &D0, &01, &F1, &77, &FC, &07, &F1, &4F, &FF, &0F, &FA, &BF
	DEFB &FF, &EB, &F7, &FF, &FF, &EA, &EF, &FF, &FF, &F2, &9F, &FF, &FF, &FD, &7F, &FF

	;;	................................
	;;	...............@@@..............
	;;	.............@@@@@@@............
	;;	............@@@@@@@@@...........
	;;	...........@@@@@@@@@.@@@........
	;;	.........@@@@@....@@@@@@@@......
	;;	.......@@@@@........@@@@@@@.....
	;;	...@@@....@..........@@@@@@@.@..
	;;	..@@@@@@@@...........@@@@@@@.@@.
	;;	.@@...@@@@@@@.......@@@@.@@@@...
	;;	.@@.@@@@@@@@@@@...@@@@@.@@@@@...
	;;	...@@@@..@@@@@@@.@@@@@@.@@@@@...
	;;	...@@.@@.@@@@@@@...@@@@.@@@@@@..
	;;	..@@.@.@@@@..@@@@@@.@@@@.@@@@@..
	;;	..@@...@@@@@.@@@@@@@.@@@..@@@@@.
	;;	..@@@.@@@@.@@@@..@@@@.@..@..@@@.
	;;	..@@@@@@@.@.@@@@.@@@@..@@@@@.@@.
	;;	.@.@...@@...@@@@@.@@..@@@@@@@@@.
	;;	.@.@..@.@@.@@@@@@...@.@@@@@@@@@.
	;;	.@.@@...@@@@@@@@@.@@@@.@@@@@@@..
	;;	..@.@.@@@@@@.@@..@.@@@.@@@@@@...
	;;	......@@@@@@...@@@@@@@.@.@@@....
	;;	........@@@..@@@@@@@@@.@.@......
	;;	............@@@@@@@@@...........
	;;	............@.@@@@@@............
	;;	............@.@.@@@.............
	;;	..............@.@...............
	;;	................................
	;;
	;;	@@@@@@@@@@@@@@@...@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@.......@@@@@@@@@@@@
	;;	@@@@@@@@@@@@.........@@@@@@@@@@@
	;;	@@@@@@@@@@@.............@@@@@@@@
	;;	@@@@@@@@@.................@@@@@@
	;;	@@@@@@@.....................@@@@
	;;	@@@...........................@@
	;;	@@...........................@.@
	;;	@............................@@.
	;;	...............................@
	;;	..............................@@
	;;	@.............................@@
	;;	@@.............................@
	;;	@....@.........................@
	;;	@...............................
	;;	@........................@......
	;;	@.........@............@@@@@....
	;;	.@....................@@@@@@@...
	;;	.@....@...............@@@@@@@@..
	;;	.@.....................@@@@@@@.@
	;;	@.@..............@.....@@@@@@.@@
	;;	@@.@...........@@@@@...@.@@@.@@@
	;;	@@@@@@.......@@@@@@@...@.@..@@@@
	;;	@@@@@@@@....@@@@@@@@@.@.@.@@@@@@
	;;	@@@@@@@@@@@.@.@@@@@@.@@@@@@@@@@@
	;;	@@@@@@@@@@@.@.@.@@@.@@@@@@@@@@@@
	;;	@@@@@@@@@@@@..@.@..@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@.@.@@@@@@@@@@@@@@@

							;; SPR_BOOK:       EQU &5D
	DEFB &00, &00, &00, &00, &00, &03, &C0, &00, &00, &0E, &70, &00, &00, &39, &9C, &00
	DEFB &00, &E6, &67, &00, &03, &99, &99, &C0, &0E, &67, &E6, &70, &1D, &9F, &F9, &BC
	DEFB &1E, &67, &E6, &7E, &27, &99, &99, &F8, &39, &E6, &67, &E0, &76, &79, &9F, &86
	DEFB &75, &9E, &7E, &18, &6D, &E7, &F8, &66, &6B, &D9, &E1, &98, &6B, &D6, &86, &66
	DEFB &6B, &B7, &19, &98, &6B, &AE, &66, &66, &2B, &AC, &99, &98, &2B, &AC, &66, &66
	DEFB &0B, &AD, &99, &9C, &05, &AC, &66, &70, &01, &AD, &99, &C0, &00, &AC, &67, &00
	DEFB &00, &16, &9C, &00, &00, &07, &70, &00, &00, &01, &C0, &00, &00, &00, &00, &00
	DEFB &FF, &FC, &3F, &FF, &FF, &F0, &0F, &FF, &FF, &C0, &03, &FF, &FF, &01, &80, &FF
	DEFB &FC, &06, &60, &3F, &F0, &18, &18, &0F, &E0, &60, &06, &03, &C1, &80, &01, &81
	DEFB &C0, &60, &06, &00, &80, &18, &18, &01, &80, &06, &60, &01, &06, &01, &80, &06
	DEFB &04, &00, &00, &19, &0C, &00, &00, &66, &08, &18, &01, &99, &08, &10, &06, &66
	DEFB &08, &30, &19, &99, &08, &20, &66, &66, &88, &20, &99, &99, &88, &20, &66, &60
	DEFB &C8, &21, &99, &81, &F4, &20, &66, &03, &F8, &21, &98, &0F, &FE, &20, &60, &3F
	DEFB &FF, &10, &80, &FF, &FF, &E0, &03, &FF, &FF, &F8, &0F, &FF, &FF, &FE, &3F, &FF

	;;	................................
	;;	..............@@@@..............
	;;	............@@@..@@@............
	;;	..........@@@..@@..@@@..........
	;;	........@@@..@@..@@..@@@........
	;;	......@@@..@@..@@..@@..@@@......
	;;	....@@@..@@..@@@@@@..@@..@@@....
	;;	...@@@.@@..@@@@@@@@@@..@@.@@@@..
	;;	...@@@@..@@..@@@@@@..@@..@@@@@@.
	;;	..@..@@@@..@@..@@..@@..@@@@@@...
	;;	..@@@..@@@@..@@..@@..@@@@@@.....
	;;	.@@@.@@..@@@@..@@..@@@@@@....@@.
	;;	.@@@.@.@@..@@@@..@@@@@@....@@...
	;;	.@@.@@.@@@@..@@@@@@@@....@@..@@.
	;;	.@@.@.@@@@.@@..@@@@....@@..@@...
	;;	.@@.@.@@@@.@.@@.@....@@..@@..@@.
	;;	.@@.@.@@@.@@.@@@...@@..@@..@@...
	;;	.@@.@.@@@.@.@@@..@@..@@..@@..@@.
	;;	..@.@.@@@.@.@@..@..@@..@@..@@...
	;;	..@.@.@@@.@.@@...@@..@@..@@..@@.
	;;	....@.@@@.@.@@.@@..@@..@@..@@@..
	;;	.....@.@@.@.@@...@@..@@..@@@....
	;;	.......@@.@.@@.@@..@@..@@@......
	;;	........@.@.@@...@@..@@@........
	;;	...........@.@@.@..@@@..........
	;;	.............@@@.@@@............
	;;	...............@@@..............
	;;	................................
	;;
	;;	@@@@@@@@@@@@@@....@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@........@@@@@@@@@@@@
	;;	@@@@@@@@@@............@@@@@@@@@@
	;;	@@@@@@@@.......@@.......@@@@@@@@
	;;	@@@@@@.......@@..@@.......@@@@@@
	;;	@@@@.......@@......@@.......@@@@
	;;	@@@......@@..........@@.......@@
	;;	@@.....@@..............@@......@
	;;	@@.......@@..........@@.........
	;;	@..........@@......@@..........@
	;;	@............@@..@@............@
	;;	.....@@........@@............@@.
	;;	.....@.....................@@..@
	;;	....@@...................@@..@@.
	;;	....@......@@..........@@..@@..@
	;;	....@......@.........@@..@@..@@.
	;;	....@.....@@.......@@..@@..@@..@
	;;	....@.....@......@@..@@..@@..@@.
	;;	@...@.....@.....@..@@..@@..@@..@
	;;	@...@.....@......@@..@@..@@.....
	;;	@@..@.....@....@@..@@..@@......@
	;;	@@@@.@....@......@@..@@.......@@
	;;	@@@@@.....@....@@..@@.......@@@@
	;;	@@@@@@@...@......@@.......@@@@@@
	;;	@@@@@@@@...@....@.......@@@@@@@@
	;;	@@@@@@@@@@@...........@@@@@@@@@@
	;;	@@@@@@@@@@@@@.......@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@...@@@@@@@@@@@@@@

							;; SPR_TOASTER:    EQU &5E
	DEFB &00, &00, &00, &00, &00, &03, &80, &00, &00, &0F, &E0, &00, &00, &3C, &78, &00
	DEFB &00, &F9, &9E, &00, &03, &FC, &67, &80, &0F, &1F, &19, &E0, &1E, &67, &C6, &78
	DEFB &3F, &19, &F1, &BC, &1F, &C6, &7C, &7C, &67, &F1, &9F, &FE, &79, &FC, &6F, &CE
	DEFB &7E, &7F, &1F, &B6, &7F, &9F, &FF, &96, &5F, &E7, &F3, &B6, &77, &F9, &6D, &96
	DEFB &5D, &FE, &65, &96, &57, &7F, &6D, &86, &65, &DF, &65, &9A, &39, &77, &65, &B2
	DEFB &1E, &5D, &61, &CC, &07, &97, &66, &F0, &01, &E5, &6C, &C0, &00, &79, &73, &00
	DEFB &00, &1E, &BC, &00, &00, &07, &B0, &00, &00, &01, &C0, &00, &00, &00, &00, &00
	DEFB &FF, &FC, &7F, &FF, &FF, &F0, &1F, &FF, &FF, &C0, &07, &FF, &FF, &00, &01, &FF
	DEFB &FC, &01, &80, &7F, &F0, &00, &60, &1F, &E0, &00, &18, &07, &C0, &60, &06, &03
	DEFB &80, &18, &01, &81, &80, &06, &00, &01, &60, &01, &80, &00, &78, &00, &60, &00
	DEFB &7E, &00, &00, &00, &7F, &80, &00, &00, &5F, &E0, &00, &00, &77, &F8, &00, &00
	DEFB &5D, &FE, &00, &00, &57, &7F, &00, &00, &65, &DF, &00, &18, &B9, &77, &00, &30
	DEFB &DE, &5D, &00, &01, &E7, &97, &06, &03, &F9, &E5, &0C, &0F, &FE, &79, &00, &3F
	DEFB &FF, &9E, &80, &FF, &FF, &E7, &83, &FF, &FF, &F9, &CF, &FF, &FF, &FE, &3F, &FF

	;;	................................
	;;	..............@@@...............
	;;	............@@@@@@@.............
	;;	..........@@@@...@@@@...........
	;;	........@@@@@..@@..@@@@.........
	;;	......@@@@@@@@...@@..@@@@.......
	;;	....@@@@...@@@@@...@@..@@@@.....
	;;	...@@@@..@@..@@@@@...@@..@@@@...
	;;	..@@@@@@...@@..@@@@@...@@.@@@@..
	;;	...@@@@@@@...@@..@@@@@...@@@@@..
	;;	.@@..@@@@@@@...@@..@@@@@@@@@@@@.
	;;	.@@@@..@@@@@@@...@@.@@@@@@..@@@.
	;;	.@@@@@@..@@@@@@@...@@@@@@.@@.@@.
	;;	.@@@@@@@@..@@@@@@@@@@@@@@..@.@@.
	;;	.@.@@@@@@@@..@@@@@@@..@@@.@@.@@.
	;;	.@@@.@@@@@@@@..@.@@.@@.@@..@.@@.
	;;	.@.@@@.@@@@@@@@..@@..@.@@..@.@@.
	;;	.@.@.@@@.@@@@@@@.@@.@@.@@....@@.
	;;	.@@..@.@@@.@@@@@.@@..@.@@..@@.@.
	;;	..@@@..@.@@@.@@@.@@..@.@@.@@..@.
	;;	...@@@@..@.@@@.@.@@....@@@..@@..
	;;	.....@@@@..@.@@@.@@..@@.@@@@....
	;;	.......@@@@..@.@.@@.@@..@@......
	;;	.........@@@@..@.@@@..@@........
	;;	...........@@@@.@.@@@@..........
	;;	.............@@@@.@@............
	;;	...............@@@..............
	;;	................................
	;;
	;;	@@@@@@@@@@@@@@...@@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@.......@@@@@@@@@@@@@
	;;	@@@@@@@@@@...........@@@@@@@@@@@
	;;	@@@@@@@@...............@@@@@@@@@
	;;	@@@@@@.........@@........@@@@@@@
	;;	@@@@.............@@........@@@@@
	;;	@@@................@@........@@@
	;;	@@.......@@..........@@.......@@
	;;	@..........@@..........@@......@
	;;	@............@@................@
	;;	.@@............@@...............
	;;	.@@@@............@@.............
	;;	.@@@@@@.........................
	;;	.@@@@@@@@.......................
	;;	.@.@@@@@@@@.....................
	;;	.@@@.@@@@@@@@...................
	;;	.@.@@@.@@@@@@@@.................
	;;	.@.@.@@@.@@@@@@@................
	;;	.@@..@.@@@.@@@@@...........@@...
	;;	@.@@@..@.@@@.@@@..........@@....
	;;	@@.@@@@..@.@@@.@...............@
	;;	@@@..@@@@..@.@@@.....@@.......@@
	;;	@@@@@..@@@@..@.@....@@......@@@@
	;;	@@@@@@@..@@@@..@..........@@@@@@
	;;	@@@@@@@@@..@@@@.@.......@@@@@@@@
	;;	@@@@@@@@@@@..@@@@.....@@@@@@@@@@
	;;	@@@@@@@@@@@@@..@@@..@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@...@@@@@@@@@@@@@@

							;; SPR_CUSHION:    EQU &5F
	DEFB &00, &00, &00, &00, &00, &02, &C0, &00, &00, &0D, &30, &00, &00, &33, &CC, &00
	DEFB &00, &CF, &F3, &00, &03, &3F, &FC, &C0, &0C, &FF, &FF, &30, &33, &FF, &FF, &CC
	DEFB &4F, &FF, &FF, &F2, &33, &FF, &FF, &CC, &6C, &FF, &FF, &36, &2B, &3F, &FC, &D4
	DEFB &4B, &4F, &F3, &52, &72, &B3, &CF, &CE, &1C, &F4, &2D, &38, &67, &2D, &74, &E2
	DEFB &31, &CB, &53, &94, &6A, &72, &CE, &56, &4D, &9C, &39, &5A, &5B, &47, &E6, &AA
	DEFB &33, &68, &12, &CC, &0E, &6A, &B6, &70, &02, &DD, &B3, &40, &00, &D5, &9B, &00
	DEFB &00, &39, &CC, &00, &00, &0B, &70, &00, &00, &03, &40, &00, &00, &00, &00, &00
	DEFB &FF, &FD, &3F, &FF, &FF, &F0, &0F, &FF, &FF, &C0, &03, &FF, &FF, &01, &40, &FF
	DEFB &FC, &0A, &A0, &3F, &F0, &15, &54, &0F, &C0, &AA, &AA, &03, &81, &55, &55, &41
	DEFB &0A, &AA, &AA, &A0, &81, &55, &55, &41, &00, &AA, &AA, &00, &80, &15, &54, &01
	DEFB &40, &0A, &A0, &02, &70, &01, &40, &0E, &9C, &00, &00, &39, &07, &00, &00, &E0
	DEFB &81, &C0, &03, &81, &00, &70, &0E, &00, &00, &1C, &38, &00, &00, &07, &E0, &00
	DEFB &80, &00, &00, &01, &C0, &00, &00, &03, &F0, &00, &00, &0F, &FC, &00, &00, &3F
	DEFB &FF, &00, &00, &FF, &FF, &C0, &03, &FF, &FF, &F0, &0F, &FF, &FF, &FC, &3F, &FF

	;;	................................
	;;	..............@.@@..............
	;;	............@@.@..@@............
	;;	..........@@..@@@@..@@..........
	;;	........@@..@@@@@@@@..@@........
	;;	......@@..@@@@@@@@@@@@..@@......
	;;	....@@..@@@@@@@@@@@@@@@@..@@....
	;;	..@@..@@@@@@@@@@@@@@@@@@@@..@@..
	;;	.@..@@@@@@@@@@@@@@@@@@@@@@@@..@.
	;;	..@@..@@@@@@@@@@@@@@@@@@@@..@@..
	;;	.@@.@@..@@@@@@@@@@@@@@@@..@@.@@.
	;;	..@.@.@@..@@@@@@@@@@@@..@@.@.@..
	;;	.@..@.@@.@..@@@@@@@@..@@.@.@..@.
	;;	.@@@..@.@.@@..@@@@..@@@@@@..@@@.
	;;	...@@@..@@@@.@....@.@@.@..@@@...
	;;	.@@..@@@..@.@@.@.@@@.@..@@@...@.
	;;	..@@...@@@..@.@@.@.@..@@@..@.@..
	;;	.@@.@.@..@@@..@.@@..@@@..@.@.@@.
	;;	.@..@@.@@..@@@....@@@..@.@.@@.@.
	;;	.@.@@.@@.@...@@@@@@..@@.@.@.@.@.
	;;	..@@..@@.@@.@......@..@.@@..@@..
	;;	....@@@..@@.@.@.@.@@.@@..@@@....
	;;	......@.@@.@@@.@@.@@..@@.@......
	;;	........@@.@.@.@@..@@.@@........
	;;	..........@@@..@@@..@@..........
	;;	............@.@@.@@@............
	;;	..............@@.@..............
	;;	................................
	;;
	;;	@@@@@@@@@@@@@@.@..@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@........@@@@@@@@@@@@
	;;	@@@@@@@@@@............@@@@@@@@@@
	;;	@@@@@@@@.......@.@......@@@@@@@@
	;;	@@@@@@......@.@.@.@.......@@@@@@
	;;	@@@@.......@.@.@.@.@.@......@@@@
	;;	@@......@.@.@.@.@.@.@.@.......@@
	;;	@......@.@.@.@.@.@.@.@.@.@.....@
	;;	....@.@.@.@.@.@.@.@.@.@.@.@.....
	;;	@......@.@.@.@.@.@.@.@.@.@.....@
	;;	........@.@.@.@.@.@.@.@.........
	;;	@..........@.@.@.@.@.@.........@
	;;	.@..........@.@.@.@...........@.
	;;	.@@@...........@.@..........@@@.
	;;	@..@@@....................@@@..@
	;;	.....@@@................@@@.....
	;;	@......@@@............@@@......@
	;;	.........@@@........@@@.........
	;;	...........@@@....@@@...........
	;;	.............@@@@@@.............
	;;	@..............................@
	;;	@@............................@@
	;;	@@@@........................@@@@
	;;	@@@@@@....................@@@@@@
	;;	@@@@@@@@................@@@@@@@@
	;;	@@@@@@@@@@............@@@@@@@@@@
	;;	@@@@@@@@@@@@........@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@....@@@@@@@@@@@@@@

;; -----------------------------------------------------------------------------------------------------------
img_2x24_bin:
floor_tile_pattern0:				;; Bookworld floor
	DEFB &30, &00, &C4, &00, &2D, &00, &0B, &40, &02, &D0, &00, &B8, &00, &23, &00, &0C
	DEFB &00, &0C, &00, &23, &00, &B4, &02, &D0, &0B, &40, &1D, &00, &C4, &00, &30, &00
	DEFB &30, &00, &C4, &00, &2D, &00, &0B, &40, &02, &D0, &00, &B8, &00, &23, &00, &0C

	;;Exemple : Bookworld floor tile
	;;  the above 48     |   flippled it
	;;	bytes give this: |   gives:
	;;	..MM............ ............MM..
	;;	MM...M.......... ..........M...MM
	;;	..M.MM.M........ ........M.MM.M..
	;;	....M.MM.M...... ......M.MM.M....
	;;	......M.MM.M.... ....M.MM.M......
	;;	........M.MMM... ...MMM.M........
	;;	..........M...MM MM...M..........
	;;	............MM.. ..MM............
	;;	............MM.. ..MM............  and we see the floor
	;;	..........M...MM MM...M..........   pattern appear!
	;;	........M.MM.M.. ..M.MM.M........
	;;	......M.MM.M.... ....M.MM.M......
	;;	....M.MM.M...... ......M.MM.M....
	;;	...MMM.M........ ........M.MMM...
	;;	MM...M.......... ..........M...MM
	;;	..MM............ ............MM..
	;;	..MM............ ............MM..
	;;	MM...M.......... ..........M...MM
	;;	..M.MM.M........ ........M.MM.M..
	;;	....M.MM.M...... ......M.MM.M....
	;;	......M.MM.M.... ....M.MM.M......
	;;	........M.MMM... ...MMM.M........
	;;	..........M...MM MM...M..........
	;;	............MM.. ..MM............

floor_tile_pattern1:			;; Blacktooth / Prison / Main floor tile
	DEFB &E0, &03, &78, &0C, &1E, &10, &07, &80, &01, &E0, &08, &78, &30, &1E, &C0, &07
	DEFB &C0, &07, &30, &1E, &08, &78, &01, &E0, &07, &80, &1E, &10, &78, &0C, &E0, &03
	DEFB &E0, &03, &78, &0C, &1E, &10, &07, &80, &01, &E0, &08, &78, &30, &1E, &C0, &07

	;;Exemple : Blacktooth / Main floor tile
	;;  the above 48     |   flippled it
	;;	bytes give this: |   gives:
	;;	MMM...........MM  MMM...........MM
	;;	.MMMM.......MM..  .MMMM.......MM..
	;;	...MMMM....M....  ...MMMM....M....
	;;	.....MMMM.......  .....MMMM.......
	;;	.......MMMM.....  .......MMMM.....
	;;	....M....MMMM...  ....M....MMMM...
	;;	..MM.......MMMM.  ..MM.......MMMM.
	;;	MM...........MMM  MM...........MMM
	;;	MM...........MMM  MMM...........MM
	;;	..MM.......MMMM.  .MMMM.......MM..
	;;	....M....MMMM...  ...MMMM....M....
	;;	.......MMMM.....  .....MMMM.......
	;;	.....MMMM.......  .......MMMM.....
	;;	...MMMM....M....  ....M....MMMM...
	;;	.MMMM.......MM..  ..MM.......MMMM.
	;;	MMM...........MM  MM...........MMM  and we see the floor
	;;	MMM...........MM  MM...........MMM   pattern of room1
	;;	.MMMM.......MM..  ..MM.......MMMM.   appear!
	;;	...MMMM....M....  ....M....MMMM...
	;;	.....MMMM.......  .......MMMM.....
	;;	.......MMMM.....  .....MMMM.......
	;;	....M....MMMM...  ...MMMM....M....
	;;	..MM.......MMMM.  .MMMM.......MM..
	;;	MM...........MMM  MMM...........MM

floor_tile_pattern2: 				;; Moonbase floor
	DEFB &07, &FC, &03, &F3, &01, &CF, &F0, &7F, &FE, &0F, &F3, &80, &CF, &C0, &3F, &E0
	DEFB &3F, &E0, &CF, &C0, &F3, &80, &FE, &0F, &F0, &7F, &01, &CF, &03, &F3, &07, &FC
	DEFB &07, &FC, &03, &F3, &01, &CF, &F0, &7F, &FE, &0F, &F3, &80, &CF, &C0, &3F, &E0

	;;	v.....@@@@@@@@@..
	;;	v......@@@@@@..@@
	;;	v.......@@@..@@@@
	;;	v@@@@.....@@@@@@@
	;;	v@@@@@@@.....@@@@
	;;	v@@@@..@@@.......
	;;	v@@..@@@@@@......
	;;	v..@@@@@@@@@.....
	;;	v..@@@@@@@@@.....
	;;	v@@..@@@@@@......
	;;	v@@@@..@@@.......
	;;	v@@@@@@@.....@@@@
	;;	v@@@@.....@@@@@@@
	;;	v.......@@@..@@@@
	;;	v......@@@@@@..@@
	;;	v.....@@@@@@@@@..
	;;	v.....@@@@@@@@@..
	;;	v......@@@@@@..@@
	;;	v.......@@@..@@@@
	;;	v@@@@.....@@@@@@@
	;;	v@@@@@@@.....@@@@
	;;	v@@@@..@@@.......
	;;	v@@..@@@@@@......
	;;	v..@@@@@@@@@.....

floor_tile_pattern3: 			;; Penitentiary floor and Freedom (victory) room
	DEFB &07, &00, &03, &80, &01, &C0, &F0, &78, &1E, &0F, &03, &80, &01, &C0, &00, &E0
	DEFB &00, &E0, &01, &C0, &03, &80, &1E, &0F, &F0, &78, &01, &C0, &03, &80, &07, &00
	DEFB &07, &00, &03, &80, &01, &C0, &F0, &78, &1E, &0F, &03, &80, &01, &C0, &00, &E0

	;;	.....@@@........
	;;	......@@@.......
	;;	.......@@@......
	;;	@@@@.....@@@@...
	;;	...@@@@.....@@@@
	;;	......@@@.......
	;;	.......@@@......
	;;	........@@@.....
	;;	........@@@.....
	;;	.......@@@......
	;;	......@@@.......
	;;	...@@@@.....@@@@
	;;	@@@@.....@@@@...
	;;	.......@@@......
	;;	......@@@.......
	;;	.....@@@........
	;;	.....@@@........
	;;	......@@@.......
	;;	.......@@@......
	;;	@@@@.....@@@@...
	;;	...@@@@.....@@@@
	;;	......@@@.......
	;;	.......@@@......
	;;	........@@@.....

floor_tile_pattern4: 				;; Egyptus floor
	DEFB &E0, &70, &78, &1C, &1E, &07, &07, &81, &81, &E0, &E0, &78, &38, &1E, &0E, &07
	DEFB &0E, &07, &38, &1E, &E0, &78, &81, &E0, &07, &81, &1E, &07, &78, &1C, &E0, &70
	DEFB &E0, &70, &78, &1C, &1E, &07, &07, &81, &81, &E0, &E0, &78, &38, &1E, &0E, &07

	;;	@@@......@@@....
	;;	.@@@@......@@@..
	;;	...@@@@......@@@
	;;	.....@@@@......@
	;;	@......@@@@.....
	;;	@@@......@@@@...
	;;	..@@@......@@@@.
	;;	....@@@......@@@
	;;	....@@@......@@@
	;;	..@@@......@@@@.
	;;	@@@......@@@@...
	;;	@......@@@@.....
	;;	.....@@@@......@
	;;	...@@@@......@@@
	;;	.@@@@......@@@..
	;;	@@@......@@@....
	;;	@@@......@@@....
	;;	.@@@@......@@@..
	;;	...@@@@......@@@
	;;	.....@@@@......@
	;;	@......@@@@.....
	;;	@@@......@@@@...
	;;	..@@@......@@@@.
	;;	....@@@......@@@

floor_tile_pattern5: 				;; Market and Safari floor
	DEFB &00, &00, &41, &02, &00, &00, &00, &00, &00, &81, &20, &08, &02, &00, &00, &00
	DEFB &10, &00, &00, &00, &00, &10, &42, &00, &00, &02, &00, &00, &00, &10, &48, &00
	DEFB &00, &00, &04, &01, &00, &00, &00, &80, &20, &00, &00, &08, &00, &00, &21, &04

	;;	................
	;;	.@.....@......@.
	;;	................
	;;	................
	;;	........@......@
	;;	..@.........@...
	;;	......@.........
	;;	................
	;;	...@............
	;;	................
	;;	...........@....
	;;	.@....@.........
	;;	..............@.
	;;	................
	;;	...........@....
	;;	.@..@...........
	;;	................
	;;	.....@.........@
	;;	................
	;;	........@.......
	;;	..@.............
	;;	............@...
	;;	................
	;;	..@....@.....@..

floor_tile_pattern6: 				;; Danger floor
	DEFB &C4, &00, &3C, &00, &0E, &00, &03, &10, &00, &F0, &00, &38, &00, &0C, &00, &03
	DEFB &00, &23, &00, &3C, &00, &70, &08, &C0, &0F, &00, &1C, &00, &30, &00, &C0, &00
	DEFB &C4, &00, &3C, &00, &0E, &00, &03, &10, &00, &F0, &00, &38, &00, &0C, &00, &03

	;;	@@...@..........
	;;	..@@@@..........
	;;	....@@@.........
	;;	......@@...@....
	;;	........@@@@....
	;;	..........@@@...
	;;	............@@..
	;;	..............@@
	;;	..........@...@@
	;;	..........@@@@..
	;;	.........@@@....
	;;	....@...@@......
	;;	....@@@@........
	;;	...@@@..........
	;;	..@@............
	;;	@@..............
	;;	@@...@..........
	;;	..@@@@..........
	;;	....@@@.........
	;;	......@@...@....
	;;	........@@@@....
	;;	..........@@@...
	;;	............@@..
	;;	..............@@

floor_tile_pattern7: 				;; Empty tile
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00

;; -----------------------------------------------------------------------------------------------------------
.Char_symbol_data: 			;; (Note: addr=AB58 before the block move, B630 after)
	DEFB &00, &00, &00, &00, &00, &00, &00, &00		;;, &charID &00: Space
		;;       ................
		;;       ................
		;;       ................
		;;       ................
		;;       ................
		;;       ................
		;;       ................
		;;       ................
	DEFB &88, &CC, &EE, &77, &77, &EE, &CC, &88		;; charID &01 (char code &21) : menu selected left part
		;;       @@......@@......
		;;       @@@@....@@@@....
		;;       @@@@@@..@@@@@@..
		;;       ..@@@@@@..@@@@@@
		;;       ..@@@@@@..@@@@@@
		;;       @@@@@@..@@@@@@..
		;;       @@@@....@@@@....
		;;       @@......@@......
	DEFB &88, &CC, &EE, &77, &77, &EE, &CC, &88		;; charID &02 (char code &22) : menu selected right part
		;;       @@......@@......
		;;       @@@@....@@@@....
		;;       @@@@@@..@@@@@@..
		;;       ..@@@@@@..@@@@@@
		;;       ..@@@@@@..@@@@@@
		;;       @@@@@@..@@@@@@..
		;;       @@@@....@@@@....
		;;       @@......@@......
	DEFB &4E, &67, &73, &01, &4E, &67, &73, &01		;; charID &03 (char code &23) : menu unselected left part
		;;       ..@@....@@@@@@..
		;;       ..@@@@....@@@@@@
		;;       ..@@@@@@....@@@@
		;;       ..............@@
		;;       ..@@....@@@@@@..
		;;       ..@@@@....@@@@@@
		;;       ..@@@@@@....@@@@
		;;       ..............@@
	DEFB &72, &E6, &CE, &80, &72, &E6, &CE, &80		;; charID &04 (char code &24) : menu unselected right part
		;;       ..@@@@@@....@@..
		;;       @@@@@@....@@@@..
		;;       @@@@....@@@@@@..
		;;       @@..............
		;;       ..@@@@@@....@@..
		;;       @@@@@@....@@@@..
		;;       @@@@....@@@@@@..
		;;       @@..............
	DEFB &C0, &70, &3C, &18, &3C, &0E, &03, &00		;; charID &05 (char code &25) : speed lightning
		;;       @@@@............
		;;       ..@@@@@@........
		;;       ....@@@@@@@@....
		;;       ......@@@@......
		;;       ....@@@@@@@@....
		;;       ........@@@@@@..
		;;       ............@@@@
		;;       ................
	DEFB &06, &03, &3B, &66, &3D, &42, &3C, &00		;; charID &06 (char code &26) : spring
		;;       ..........@@@@..
		;;       ............@@@@
		;;       ....@@@@@@..@@@@
		;;       ..@@@@....@@@@..
		;;       ....@@@@@@@@..@@
		;;       ..@@........@@..
		;;       ....@@@@@@@@....
		;;       ................
	DEFB &FE, &EE, &C6, &6C, &6C, &38, &10, &00		;; charID &07 (char code &27) : shield
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@..@@@@@@..
		;;       @@@@......@@@@..
		;;       ..@@@@..@@@@....
		;;       ..@@@@..@@@@....
		;;       ....@@@@@@......
		;;       ......@@........
		;;       ................
	DEFB &00, &00, &00, &00, &38, &38, &18, &30		;; charID &08 : comma
		;;       ................
		;;       ................
		;;       ................
		;;       ................
		;;       ....@@@@@@......
		;;       ....@@@@@@......
		;;       ......@@@@......
		;;       ....@@@@........
	DEFB &00, &00, &7E, &7E, &7E, &7E, &00, &00		;; charID &09 : Big block
		;;       ................
		;;       ................
		;;       ..@@@@@@@@@@@@..
		;;       ..@@@@@@@@@@@@..
		;;       ..@@@@@@@@@@@@..
		;;       ..@@@@@@@@@@@@..
		;;       ................
		;;       ................
	DEFB &00, &00, &00, &00, &00, &38, &38, &38		;; charID &0A : Small Block
		;;       ................
		;;       ................
		;;       ................
		;;       ................
		;;       ................
		;;       ....@@@@@@......
		;;       ....@@@@@@......
		;;       ....@@@@@@......
	DEFB &3E, &3E, &7E, &7E, &FC, &FC, &F8, &F8		;; charID &0B : "/"
		;;       ....@@@@@@@@@@..
		;;       ....@@@@@@@@@@..
		;;       ..@@@@@@@@@@@@..
		;;       ..@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@....
		;;       @@@@@@@@@@@@....
		;;       @@@@@@@@@@......
		;;       @@@@@@@@@@......
	DEFB &7C, &FE, &FE, &EE, &EE, &FE, &FE, &7C		;; charID &0C : "0"
		;;       ..@@@@@@@@@@....
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@..@@@@@@..
		;;       @@@@@@..@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       ..@@@@@@@@@@....
	DEFB &7C, &FC, &7C, &7C, &7C, &FE, &FE, &FE		;; charID &0D : "1"
		;;       ..@@@@@@@@@@....
		;;       @@@@@@@@@@@@....
		;;       ..@@@@@@@@@@....
		;;       ..@@@@@@@@@@....
		;;       ..@@@@@@@@@@....
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
	DEFB &FE, &FE, &BE, &7C, &F8, &FE, &FE, &FE		;; charID &0E : "2"
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@..@@@@@@@@@@..
		;;       ..@@@@@@@@@@....
		;;       @@@@@@@@@@......
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
	DEFB &FE, &FE, &3E, &FE, &FE, &3E, &FE, &FE		;; charID &0F : "3"
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       ....@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       ....@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
	DEFB &E0, &EC, &EC, &EC, &FE, &FE, &FE, &0C		;; charID &10 : "4"
		;;       @@@@@@..........
		;;       @@@@@@..@@@@....
		;;       @@@@@@..@@@@....
		;;       @@@@@@..@@@@....
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       ........@@@@....
	DEFB &FE, &FE, &F8, &FE, &FE, &1E, &FE, &FC		;; charID &11 : "5"
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@......
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       ......@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@....
	DEFB &FE, &FE, &F8, &FE, &FE, &EE, &FE, &FE		;; charID &12 : "6"
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@......
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@..@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
	DEFB &FE, &FE, &1C, &3C, &78, &78, &F0, &F0		;; charID &13 : "7"
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       ......@@@@@@....
		;;       ....@@@@@@@@....
		;;       ..@@@@@@@@......
		;;       ..@@@@@@@@......
		;;       @@@@@@@@........
		;;       @@@@@@@@........
	DEFB &FE, &FE, &EE, &7C, &FE, &EE, &FE, &FE		;; charID &14 : "8"
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@..@@@@@@..
		;;       ..@@@@@@@@@@....
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@..@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
	DEFB &FE, &FE, &EE, &FE, &FE, &1E, &FE, &FE		;; charID &15 : "9"
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@..@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       ......@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
	DEFB &00, &38, &38, &38, &00, &38, &38, &38		;; charID &16 : ":"
		;;       ................
		;;       ....@@@@@@......
		;;       ....@@@@@@......
		;;       ....@@@@@@......
		;;       ................
		;;       ....@@@@@@......
		;;       ....@@@@@@......
		;;       ....@@@@@@......
	DEFB &38, &38, &38, &00, &38, &38, &18, &30		;; charID &17 : ";"
		;;       ....@@@@@@......
		;;       ....@@@@@@......
		;;       ....@@@@@@......
		;;       ................
		;;       ....@@@@@@......
		;;       ....@@@@@@......
		;;       ......@@@@......
		;;       ....@@@@........
	DEFB &00, &FE, &C6, &BA, &AA, &BE, &C0, &FC		;; charID &18 : "@"
		;;       ................
		;;       @@@@@@@@@@@@@@..
		;;       @@@@......@@@@..
		;;       @@..@@@@@@..@@..
		;;       @@..@@..@@..@@..
		;;       @@..@@@@@@@@@@..
		;;       @@@@............
		;;       @@@@@@@@@@@@....
	DEFB &FE, &FE, &EE, &FE, &FE, &FE, &EE, &EE		;; charID &19 : "A"
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@..@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@..@@@@@@..
		;;       @@@@@@..@@@@@@..
	DEFB &FE, &F6, &FE, &FC, &FE, &F6, &F6, &FE		;; charID &1A : "B"
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@..@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@....
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@..@@@@..
		;;       @@@@@@@@..@@@@..
		;;       @@@@@@@@@@@@@@..
	DEFB &FE, &FE, &FE, &F8, &F8, &FE, &FE, &FE		;; charID &1B : "C"
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@......
		;;       @@@@@@@@@@......
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
	DEFB &FC, &FE, &FE, &EE, &EE, &FE, &FE, &FC		;; charID &1C : "D"
		;;       @@@@@@@@@@@@....
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@..@@@@@@..
		;;       @@@@@@..@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@....
	DEFB &FE, &FE, &F8, &FC, &FC, &F8, &FE, &FE		;; charID &1D : "E"
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@......
		;;       @@@@@@@@@@@@....
		;;       @@@@@@@@@@@@....
		;;       @@@@@@@@@@......
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
	DEFB &FE, &FE, &F8, &FC, &FC, &F8, &F8, &F8		;; charID &1E : "F"
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@......
		;;       @@@@@@@@@@@@....
		;;       @@@@@@@@@@@@....
		;;       @@@@@@@@@@......
		;;       @@@@@@@@@@......
		;;       @@@@@@@@@@......
	DEFB &FE, &FE, &FE, &F0, &F6, &FE, &FE, &FE		;; charID &1F : "G"
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@........
		;;       @@@@@@@@..@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
	DEFB &EE, &EE, &FE, &FE, &FE, &FE, &EE, &EE		;; charID &20 : "H"
		;;       @@@@@@..@@@@@@..
		;;       @@@@@@..@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@..@@@@@@..
		;;       @@@@@@..@@@@@@..
	DEFB &FE, &FE, &7C, &7C, &7C, &7C, &FE, &FE		;; charID &21 : "I"
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       ..@@@@@@@@@@....
		;;       ..@@@@@@@@@@....
		;;       ..@@@@@@@@@@....
		;;       ..@@@@@@@@@@....
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
	DEFB &1E, &1E, &1E, &1E, &DE, &DE, &FE, &FE		;; charID &22 : "J"
		;;       ......@@@@@@@@..
		;;       ......@@@@@@@@..
		;;       ......@@@@@@@@..
		;;       ......@@@@@@@@..
		;;       @@@@..@@@@@@@@..
		;;       @@@@..@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
	DEFB &E6, &EE, &FE, &FC, &FC, &FE, &EE, &E6		;; charID &23 : "K"
		;;       @@@@@@....@@@@..
		;;       @@@@@@..@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@....
		;;       @@@@@@@@@@@@....
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@..@@@@@@..
		;;       @@@@@@....@@@@..
	DEFB &F8, &F8, &F8, &F8, &F8, &FE, &FE, &FE		;; charID &24 : "L"
		;;       @@@@@@@@@@......
		;;       @@@@@@@@@@......
		;;       @@@@@@@@@@......
		;;       @@@@@@@@@@......
		;;       @@@@@@@@@@......
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
	DEFB &EE, &FE, &FE, &FE, &FE, &FE, &D6, &C6		;; charID &25 : "M"
		;;       @@@@@@..@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@..@@..@@@@..
		;;       @@@@......@@@@..
	DEFB &F6, &F6, &FE, &FE, &FE, &FE, &DE, &DE		;; charID &26 : "N"
		;;       @@@@@@@@..@@@@..
		;;       @@@@@@@@..@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@..@@@@@@@@..
		;;       @@@@..@@@@@@@@..
	DEFB &FE, &FE, &FE, &EE, &EE, &FE, &FE, &FE		;; charID &27 : "O"
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@..@@@@@@..
		;;       @@@@@@..@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
	DEFB &FE, &FE, &EE, &FE, &FE, &F8, &F8, &F8		;; charID &28 : "P"
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@..@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@......
		;;       @@@@@@@@@@......
		;;       @@@@@@@@@@......
	DEFB &FC, &FC, &FC, &EC, &EC, &FC, &FE, &FE		;; charID &29 : "Q"
		;;       @@@@@@@@@@@@....
		;;       @@@@@@@@@@@@....
		;;       @@@@@@@@@@@@....
		;;       @@@@@@..@@@@....
		;;       @@@@@@..@@@@....
		;;       @@@@@@@@@@@@....
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
	DEFB &FE, &FE, &EE, &FE, &FC, &FE, &FE, &EE		;; charID &2A : "R"
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@..@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@....
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@..@@@@@@..
	DEFB &FE, &FE, &F8, &FE, &FE, &3E, &FE, &FE		;; charID &2B : "S"
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@......
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       ....@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
	DEFB &FE, &FE, &FE, &7C, &7C, &7C, &7C, &7C		;; charID &2C : "T"
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       ..@@@@@@@@@@....
		;;       ..@@@@@@@@@@....
		;;       ..@@@@@@@@@@....
		;;       ..@@@@@@@@@@....
		;;       ..@@@@@@@@@@....
	DEFB &EE, &EE, &EE, &EE, &FE, &FE, &FE, &FE		;; charID &2D : "U"
		;;       @@@@@@..@@@@@@..
		;;       @@@@@@..@@@@@@..
		;;       @@@@@@..@@@@@@..
		;;       @@@@@@..@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
	DEFB &EE, &EE, &EE, &EE, &FE, &FE, &7C, &7C		;; charID &2E : "V"
		;;       @@@@@@..@@@@@@..
		;;       @@@@@@..@@@@@@..
		;;       @@@@@@..@@@@@@..
		;;       @@@@@@..@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       ..@@@@@@@@@@....
		;;       ..@@@@@@@@@@....
	DEFB &C6, &D6, &FE, &FE, &FE, &FE, &FE, &EE		;; charID &2F : "W"
		;;       @@@@......@@@@..
		;;       @@@@..@@..@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@..@@@@@@..
	DEFB &EE, &FE, &FE, &7C, &7C, &FE, &FE, &EE		;; charID &30 : "X"
		;;       @@@@@@..@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       ..@@@@@@@@@@....
		;;       ..@@@@@@@@@@....
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@..@@@@@@..
	DEFB &EE, &EE, &FE, &FE, &7C, &7C, &7C, &7C		;; charID &31 : "Y"
		;;       @@@@@@..@@@@@@..
		;;       @@@@@@..@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       ..@@@@@@@@@@....
		;;       ..@@@@@@@@@@....
		;;       ..@@@@@@@@@@....
		;;       ..@@@@@@@@@@....
	DEFB &FE, &FE, &FE, &3C, &78, &FE, &FE, &FE		;; charID &32 : "Z"
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       ....@@@@@@@@....
		;;       ..@@@@@@@@......
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
	DEFB &FE, &FE, &F8, &F8, &F8, &F8, &FE, &FE		;; charID &33 : "["
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@......
		;;       @@@@@@@@@@......
		;;       @@@@@@@@@@......
		;;       @@@@@@@@@@......
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
	DEFB &F8, &F8, &FC, &FC, &7E, &7E, &3E, &3E		;; charID &34 : "\"
		;;       @@@@@@@@@@......
		;;       @@@@@@@@@@......
		;;       @@@@@@@@@@@@....
		;;       @@@@@@@@@@@@....
		;;       ..@@@@@@@@@@@@..
		;;       ..@@@@@@@@@@@@..
		;;       ....@@@@@@@@@@..
		;;       ....@@@@@@@@@@..
	DEFB &FE, &FE, &3E, &3E, &3E, &3E, &FE, &FE		;; charID &35 : "]"
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       ....@@@@@@@@@@..
		;;       ....@@@@@@@@@@..
		;;       ....@@@@@@@@@@..
		;;       ....@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
	DEFB &10, &38, &7C, &FE, &7C, &7C, &7C, &7C		;; charID &36 : Up arrow
		;;       ......@@........
		;;       ....@@@@@@......
		;;       ..@@@@@@@@@@....
		;;       @@@@@@@@@@@@@@..
		;;       ..@@@@@@@@@@....
		;;       ..@@@@@@@@@@....
		;;       ..@@@@@@@@@@....
		;;       ..@@@@@@@@@@....
	DEFB &7C, &7C, &7C, &7C, &FE, &7C, &38, &10		;; charID &37 : Down arrow
		;;       ..@@@@@@@@@@....
		;;       ..@@@@@@@@@@....
		;;       ..@@@@@@@@@@....
		;;       ..@@@@@@@@@@....
		;;       @@@@@@@@@@@@@@..
		;;       ..@@@@@@@@@@....
		;;       ....@@@@@@......
		;;       ......@@........
	DEFB &00, &10, &F8, &FC, &FE, &FC, &F8, &10		;; charID &38 : Right arrow
		;;       ................
		;;       ......@@........
		;;       @@@@@@@@@@......
		;;       @@@@@@@@@@@@....
		;;       @@@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@....
		;;       @@@@@@@@@@......
		;;       ......@@........
	DEFB &00, &10, &3E, &7E, &FE, &7E, &3E, &10		;; charID &39 : Left arrow
		;;       ................
		;;       ......@@........
		;;       ....@@@@@@@@@@..
		;;       ..@@@@@@@@@@@@..
		;;       @@@@@@@@@@@@@@..
		;;       ..@@@@@@@@@@@@..
		;;       ....@@@@@@@@@@..
		;;       ......@@........

;; -----------------------------------------------------------------------------------------------------------
;; These are the pillars sprites that may go under some of the doors (type 4)
.img_pillar_top: 				;; 4x9 *2  Pillar Top
	DEFB &00, &00, &00, &03, &00, &00, &00, &03, &00, &00, &00, &3C, &00, &00, &00, &CF
	DEFB &00, &01, &00, &F3, &00, &0E, &00, &7C, &00, &3F, &00, &9F, &00, &FF, &00, &3C
	DEFB &00, &FC, &03, &F3
	DEFB &00, &F3, &0F, &CF, &00, &CF, &3E, &3E, &00, &3C, &F8, &F8, &03, &F3, &E4, &E0
	DEFB &0F, &CF, &9C, &80, &3E, &3E, &78, &00, &79, &78, &F8, &00, &67, &60, &F0, &00
	DEFB &07, &00, &C0, &08
	;; (shown as "msk1+msk2 img1+img2 : result" so it is easier to see the result)
	;;
	;;	................ ..............@@ : ..............cc
	;;	................ ..............@@ : ..............cc
	;;	................ ..........@@@@.. : ..........cccc..
	;;	................ ........@@..@@@@ : ........cc..cccc
	;;	................ .......@@@@@..@@ : .......ccccc..cc
	;;	................ ....@@@..@@@@@.. : ....ccc..ccccc..
	;;	................ ..@@@@@@@..@@@@@ : ..ccccccc..ccccc
	;;	................ @@@@@@@@..@@@@.. : cccccccc..cccc..
	;;	..............@@ @@@@@@..@@@@..@@ : cccccc..cccc..**
	;;	............@@@@ @@@@..@@@@..@@@@ : cccc..cccc..****
	;;	..........@@@@@. @@..@@@@..@@@@@. : cc..cccc..*****.
	;;	........@@@@@... ..@@@@..@@@@@... : ..cccc..*****...
	;;	......@@@@@..@.. @@@@..@@@@@..... : cccc..*****..o..
	;;	....@@@@@..@@@.. @@..@@@@@....... : cc..*****..ooo..
	;;	..@@@@@..@@@@... ..@@@@@......... : ..*****..oooo...
	;;	.@@@@..@@@@@@... .@@@@........... : .****..oooooo...
	;;	.@@..@@@@@@@.... .@@............. : .**..ooooooo....
	;;	.....@@@@@...... ............@... : .....ooooo..c...

.img_pillar_mid:				;; 4x6 *2 Pillar Mid (img1+msk1+img2+msk2 interlaced)
	DEFB &00, &78, &00, &3C, &00, &1F, &00, &F0, &20, &07, &08, &C0, &38, &00, &38, &00
	DEFB &5F, &40, &F4, &04, &4C, &40, &64, &04
	DEFB &73, &73, &9C, &9C, &1E, &1E, &F0, &F0, &23, &03, &88, &80, &3C, &00, &78, &00
	DEFB &1F, &00, &F0, &00, &07, &20, &C0, &08
	;; (shown as "msk1+msk2 img1+img2 : result" so it is easier to see the result)
	;;
	;;	................ .@@@@.....@@@@.. : .cccc.....cccc..
	;;	................ ...@@@@@@@@@.... : ...ccccccccc....
	;;	..@.........@... .....@@@@@...... : ..o..ccccc..o...
	;;	..@@@.....@@@... ................ : ..ooo.....ooo...
	;;	.@.@@@@@@@@@.@.. .@...........@.. : .*.ooooooooo.*..
	;;	.@..@@...@@..@.. .@...........@.. : .*..oo...oo..*..
	;;	.@@@..@@@..@@@.. .@@@..@@@..@@@.. : .***..***..***..
	;;	...@@@@.@@@@.... ...@@@@.@@@@.... : ...****.****....
	;;	..@...@@@...@... ......@@@....... : ..o...***...o...
	;;	..@@@@...@@@@... ................ : ..oooo...oooo...
	;;	...@@@@@@@@@.... ................ : ...ooooooooo....
	;;	.....@@@@@...... ..@.........@... : ..c..ooooo..c...

.image_pillar_btm:				;; 4x4 *2 Pillar Bottom
	DEFB &00, &78, &00, &3C, &00, &7F, &00, &FC, &00, &3F, &00, &F8, &00, &0F, &00, &E0
	;;  B888-B897 : This is missing from the DSK file I used in the file HEADOVER.III !
	;;  Thus I can see a glitch at the bottom of the pillars.
	;;  In another DSK version we see it should be 16 "00" bytes and indeed it gets rid of the glich.
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
	;; (shown as "msk1+msk2 img1+img2 : result" so it is easier to see the result)
	;;
    ;;     ................ .@@@@.....@@@@.. : .cccc.....cccc..
    ;;     ................ .@@@@@@@@@@@@@.. : .ccccccccccccc..
    ;;     ................ ..@@@@@@@@@@@... : ..ccccccccccc...
    ;;     ................ ....@@@@@@@..... : ....ccccccc.....
    ;;     ................ ................ : ................
    ;;     ................ ................ : ................
    ;;     ................ ................ : ................
    ;;     ................ ................ : ................

;; & new end position B887 from old ADAF (addr before it was moved) & fin de HEADOVER.III
;; end of "This block was moved from 6600-ADBF to 70D8-B897  (+0AD8)"

.end_moved_block:

;; -----------------------------------------------------------------------------------------------------------
PillarBuf:								;; &0128 (296) bytes
	;; (top: 4*4 + mid: 4*6 + btm: 4*9) * 2 ("img+mask") = 296 bytes
	DEFS 	296

DoorwayBuf:								;; &0150 (336 = 2 * 168 bytes)
DoorwayImgBuf:							;; &00A8 (168) bytes (3*56 (img L+R))
	DEFS 	168

DoorwayMaskBuf:							;; &00A8 (168) bytes (3*56 (mask L+R))
	DEFS 	168

;; -----------------------------------------------------------------------------------------------------------
;; TODO : A buffer that is used for saving several things
;; could be  4 + &1D + &19 + &3F0 + (2*&12) bytes long
;; TODO: Saves the other character's (the one not being played) info
;;   first word : Room Id
Other_Character_state:
	;; 4 bytes
	DEFS 	1							;; Saved Room Id
	DEFS 	1 							;; Saved Phase
	DEFS 	1 							;; Saved Last direction
	DEFS 	1							;; Saved Curr direction
	;; &1D bytes (29)
	DEFS 	1							;; Saved ObjListIdx
	DEFS 	2							;; Saved Object_Destination
	DEFS 	2							;; Saved ObjListAPtr
	DEFS 	2							;; Saved ObjListBPtr
	DEFS 	20							;; Saved ObjectLists
	DEFS 	2							;; Saved Saved_Object_Destination
	;; &19 bytes (25)
	DEFS 	1							;; Saved ???
	DEFS 	3		 					;; Saved (fire) object EntryPosn
	DEFS 	1  							;; Saved ???
	DEFS 	2		     				;; Saved Carrying
	DEFS 	18							;; Saved &12 bytes FiredObj_variables
	;; &3F0 bytes
	DEFS 	&03F0						;; Saved Objects buffer
	;; &12 bytes
	DEFS 	18							;; Saved Character variables
	;; &12 bytes
	DEFS 	18							;; Saved Other Character variables

;; -----------------------------------------------------------------------------------------------------------
	