--[[
   * ReaScript MMX_HUD_DS
   * Lua script for Cockos REAPER
   * Author: DarkStar, April 2020
   * to scan all selected tracks and all FX
   * for MIDIMix
   * Version: beta 01
   
   * using sections of "List all MIDI OSC learn from focused FX", by
   * Author: Michael Pilyavskiy (mpl)
   * Author URI: http://forum.cockos.com/member.php?u=70694
   * http://forum.cockos.com/showthread.php?t=172494
   * Version: 1.0

   * Licence: GPL v3
   *
   * bobobo Version
   * some changes for the 3 knob row in Mixer for
--]]

--[[ Operation:
   * see display_help ()
--]]--


-- -------------------------------------------------------
function init ()
-- -------------------------------------------------------

-- Akai MIDIMix

    COLUMNS = 8;
    PROWS   = 6; ROW_TYPE = {"K", "K", "K", "S", "S", "F"} -- only 3 used for MIDIMix
    SETS    = 6             -- scenes / banks etc
    MODEL   = "MIDIMix (b1)"
    LEARNX  = "/knob/"
    PARM_ID = {"/midimix/knob/", "/midimix/button/"} 

    NO = 0;  YES = 1
    LEFT_ = 1; CENTRED_ = 2; RIGHT_ = 3
    hide_repeats = NO
    dim_handle = 1.5
    knob_BG = NO
-- -------------------------------------------------------
-- .... mode settings
    BOXES = 0;  KNOBS   = 1;              display_mode = KNOBS-1;
    MIXER = 0;  INSTR   = 1;  SYNTH = 2;  op_mode      = SYNTH -2;

-- -------------------------------------------------------
-- .... initialise the GUI window

    red_bg = 30/256;  green_bg = 30/256;  blue_bg = 50/256;
    gfx.clear= 256 * (red_bg + green_bg*256 + blue_bg*65536) -- RGB components for background

    LIST_FX_Y   = 480
    LIST_FX_GAP =  75 
    MIXER_Y0    = 350

-- .... screen buffers
    MAIN_WINDOW = -1
    OFF_SCREEN_BUFFER  = 126;
    OFF_SCREEN_CONTROL = 127;

-- -------------------------------------------------------
-- .... constants    
-- -------------------------------------------------------
    BLACK  =  0;  GREY_2 =  2;  GREY_3 =  3;  GREY_6 =  6;  GREY_7 =  7; WHITE =  9;
    CYAN   = 21;  ORANGE = 22;  DEEP_OR = 23;
    GREEN  = 24;  VIOLET = 25;  RED     = 26; YELLOW = 27; 
    BG     = 999; 

 -- .... top control buttons
    TOP_BUTTON_Y   =  12
    MODE_OFFSET    = 110
    COLOUR_OFFSET  =  60
    MBS_OFFSET     = 100
    HELP_OFFSET    =  30
    
-- .... knobs, boxes, faders and switches
    TOP_CONTROLS_Y = 50;
    LINE_W = 16;  CHAR_W = 5.2;

    BUTTON_Y = 18
    BOX_X0   = 24;  BOX_Y0  = 65;  BOX_W  = 120;  BOX_H  =  80;  BOX_XGAP  = 30;  BOX_YGAP  = 20;  BOX_XMID  = 20
    KNOB_X0  = 45;  KNOB_Y0 = 75;  KNOB_W =  35;  KNOB_H = 130;  KNOB_XGAP = 20;  KNOB_YGAP = 10;  KNOB_XMID = 20
    FADER_H  = 150 +30
    BTN_H    =  15
    MAX_ROWS =  6
    ROWS     = PROWS

-- .... shrink a little for many columns
    if COLUMNS > 12 then KNOB_W = KNOB_W -5; KNOB_XGAP = KNOB_XGAP -4; end

-- .. calculate GUI dimensions, for initial SYNTH mode
    WIDTH = KNOB_W;  XGAP = KNOB_XGAP
    CENTRE_X0 =  65
    STEP_X    = 110
    MID_GAP   =  20
    
    GUI_W = KNOB_X0 + (COLUMNS +1) * (KNOB_W + KNOB_XGAP) *2 +15     -- +1 for Master
    GUI_H = 70
    for i = 1, ROWS do -- MAX_ROWS do
        if ROW_TYPE[i] == "B" then
            WIDTH = BOX_W
            XGAP  = BOX_XGAP
            CENTRE_X0 =  80+10
            STEP_X    = 120 +30
            GUI_W =  (COLUMNS +1) * (BOX_W + BOX_XGAP) +40
        end
        GUI_W = math.max(980, GUI_W)
        NEXT_OFFSET = GUI_W -170

        if     ROW_TYPE[i] == "B"  then GUI_H = GUI_H + 00 + BOX_H +20
        elseif ROW_TYPE[i] == "F"  then GUI_H = GUI_H + 20 + FADER_H + 60
        elseif ROW_TYPE[i] == "K"  then GUI_H = GUI_H + 20 + KNOB_W *2 +150
        elseif ROW_TYPE[i] == "P"  then GUI_H = GUI_H + 20 + KNOB_W *2 +50
        elseif ROW_TYPE[i] == "S"  then GUI_H = GUI_H + 20 + BTN_H +50
        end
    end
-- +0327
GUI_H = 845
    gfx.init(MODEL, GUI_W, GUI_H, 0, 200, 40) -- WH dock XY

    Z = 16
    gfx.setfont(1,"Calibri", Z)
    gfx.setfont(2,"Calibri", Z+6)
    gfx.setfont(3,"Calibri", Z+16)


-- -------------------------------------------------------
-- .... initialise variables
    MAP_ELEMENTS = 8 -- track name, FX name, parameter name, parameter value,
                     -- track number, FX number, parameter number, formatted parameter value   
    maps = {}
    for i =1, MAP_ELEMENTS * (COLUMNS * ROWS)  * SETS do maps[i] = " " end
    used_banks = {}
    for i = 1, SETS do used_banks[i] = 0 end 
    TRACK_ELEMENTS = 8  -- Mute, Solo, RecArm, volume, pan, (selected?)
    track_states = {}
    for i = 1, TRACK_ELEMENTS * (COLUMNS +1) do track_states[i] = " " end -- last one is for the Master track
    row_height = {}
    for i = 1, ROWS do row_height[i] = 140 +20 end 

    click_stage =1
    set_clicked =0; mode_clicked =0; colour_clicked =0;  NNadd_clicked =0; help_clicked =0

    move_map_stage    = 1
    get_maps          = YES
    help_display      = 0
    show_formatted    = 0
    store_count       = 0
    first_mixer_track = 1

    sel_bank             = 1
    sel_bank_prev_mixer = 1
    sel_bank_prev_instr = 1
    bankLeft_colour     = GREY_7
    bankRight_colour    = DEEP_OR

    solo_gfxa            = 0.55
    solo_gfxa_prev       = 0.55
    solo_gfxa_prev_mixer = 0.55
    solo_gfxa_prev_instr = 0.55
    
    PRIME_0 = 151; prime = PRIME_0
--   2     3     5     7    11    13    17    19    23    29
--  31    37    41    43    47    53    59    61    67    71
--  73    79    83    89    97   101   103   107   109   113
-- 127   131   137   139   149   151   157   163   167   173
-- 179   181   191   193   197   199   211   223   227   229
-- 233   239   241   251   257   263   269   271   277   281
-- 283   293   307   311   313   317   331   337   347   349
-- 353   359   367   373   379   383   389   397   401   409

-- +0327
ROWS =2;


end -- function init

-- START OF LIBRARY

-- set of library function for the MIDIMix Control Surface HUD

-- -------------------------------------------------------
function display_help (PPage)
-- -------------------------------------------------------

    set_colour(GREY_7); gfx.a = 0.70
    gfx.rect(20, 50, gfx.w- 40, gfx.h - 60)

    set_colour(BLACK); gfx.a = 1.00
    gfx.x = 50; gfx.y = 55; gfx.setfont(2)
    if PPage == 1 then 
        gfx.printf(
            "\nThis script provides the values associated with the Akai MIDIMix controller settings, for selected tracks, " ..
            "\nand operates in either the Mixer or the Instrument modes. " ..
            "It relies on the use of \ngoldenarpharazon's MIDIMix Control Surface, available here: " ..
            "https://forum.cockos.com/showthread.php?t=172908 ." ..
            "\nVersion bobobo's changes 21 assingable knobs"..
            "\n*  In Mixer mode, there are 3 rows of knobs assignable to plug-in parameters and a bank of 8 tracks, " ..
            "\n      with Mute/Solo, RecArm and Level controls." ..
            "\n*  In Instrument mode, there are three rows of knobs assignable to plug-in parameters and a bank of 8 tracks, " ..
            "\n      with Level controls; the buttons indicate which FX on the selected track are open and which track in the bank is selected." 
        )
        gfx.x = 50; gfx.y = gfx.y + 40
        set_colour(ORANGE); gfx.printf("Operation: "); set_colour(BLACK); 
        gfx.x = 55
        gfx.printf(
            "\n* in Reaper, select the track(s) to be monitored" ..
            "\n* the parameters mapped for those selected tracks are displayed" ..
            "\n* each one shows the MIDIMix knob number, the track, FX and parameter" ..
            " names and a graphic of the parameter value" ..
            "\n* if a MIDIMix knob is mapped to more than one parameter, " ..
            "\"Multiple\" is displayed and the FX and parameter names" ..
            "\n    and value are those of the last mapping found." ..
            "\n* also displayed are the Mixer Pan, Mute/Solo, Recarm controls and Volume faders, " ..
            "\n    or the Instrument FX and track selectors and the track Volume faders." ..
            "\n\nNB: If multiple tracks are selected then the mixer controls on the MIDIMix will affect all of the selected tracks."
        )
        gfx.x = 55; gfx.y = gfx.y +40
        set_colour(ORANGE); gfx.printf("Controls: "); set_colour(BLACK); gfx.x = 55
        gfx.printf(
            "\n* to change between Mixer and Instrument mode:                                    click the [Mixer] or [Instr] button" ..
 --           "\n* to change between boxes and knobs for the parameters:                     right_click the [Mixer] or [Instr]] button" ..
            "\n* to change the colour for each FX instance:                                               click the [C] button" ..
            "\n* to display the Mixer controls for the next / previous bank of tracks:  click the >> or << buttons" ..
            
            "\n\n* to display a different set of parameter controls:                                      click one of the Set buttons" ..
            "\n      the selected set is orange, other sets with  mapped knobs are yellow" ..
            "\n* to display / hide formatted values for the controls:                                right_click the [C] button" ..
            "\n* to move an FX parameter to a different MIDIMix knob:" ..
            "\n      Alt-click the parameter's current slot, then Alt-click the new slot," ..
            "\n      if the new slot is already in use, then the two parameters are swapped over," ..
            "\n* to see/hide the MIDIMix control surface help:                                          right-click  the [?] button."
        )
    else
        set_colour(ORANGE); gfx.printf("\nMIDIMix Operation:") set_colour(BLACK); gfx.x = 55
        gfx.printf("\n     Two modes are available: \"Mixer\" and \"Instruments\" " ..
                   ", switch between them using Solo and Bank Right." ..
                   "\n     Bank Right lights up to indicate the first set of controls.")   
        gfx.x = 55
        set_colour(ORANGE); gfx.printf("\n\nMixer mode: "); set_colour(BLACK); 
        gfx.x = 55
        gfx.printf(
            "\n*    32 parameter controls are available: 1 Bank of 16 Shiftable knobs " ..
            "\n*    2 rows of 8 knobs for assignment to FX parameters (pressing Solo (= a shift) provides 16 more)," ..
            "\n\n*    Bank Left / Right moves to the next / previous set of 8 tracks" ..
            "\n*    1 row of 8 knobs for track pan control," ..
            "\n*    1 row of 8 buttons for track muting (pressing Solo (= a shift) controls Soloing)" ..
            "\n*    1 row of 8 buttons for track Record Arming" ..
            "\n*    1 row of 8 track faders plus the Master fader." 
        )
        gfx.x = 55
        set_colour(ORANGE); gfx.printf("\n\nInstrument mode: "); set_colour(BLACK); gfx.x = 55
        gfx.printf(
            "\n*    144 parameter controls are available: 3 Banks of 24 Shiftable knobs " .. 
            "\n*    Bank Left / Right moves to the previous / next set of controls" ..
            "\n      Bank Right LED indicates the first set of controls, Bank Left the second set, and both the third set" ..
            "\n*    3 rows of 8 knobs for assignment (pressing Solo (= a shift) provides 24 more)" ..
            "\n\n*    1 row of 8 buttons to open / close any of the first 8 FX on the last selected track" ..
            "\n*    1 row of 8 buttons to select one of the tracks in the current set of 8" ..
            "\n*    1 row of 8 track faders plus the Master fader." 
        )
    end
    gfx.setfont(1)

end -- of function


-- --------------------------------------------------------------
function set_colour ( Pcolour) 
-- --------------------------------------------------------------

    if     Pcolour == BG      then gfx.r = red_bg; gfx.g = green_bg; gfx.b = blue_bg;
    elseif Pcolour == WHITE   then gfx.r = 1.00; gfx.g = 1.00; gfx.b = 1.00;
    elseif Pcolour == GREY_2  then gfx.r = 0.20; gfx.g = 0.20; gfx.b = 0.20; 
    elseif Pcolour == GREY_3  then gfx.r = 0.20; gfx.g = 0.20; gfx.b = 0.30;
    elseif Pcolour == GREY_4  then gfx.r = 0.30; gfx.g = 0.30; gfx.b = 0.40;
    elseif Pcolour == GREY_6  then gfx.r = 0.50; gfx.g = 0.50; gfx.b = 0.60;
    elseif Pcolour == GREY_7  then gfx.r = 0.70; gfx.g = 0.70; gfx.b = 0.85;
    elseif Pcolour == BLACK   then gfx.r = 0.00; gfx.g = 0.00; gfx.b = 0.00;

    elseif Pcolour == CYAN    then gfx.r = 0.00; gfx.g = 1.00; gfx.b = 1.00;
    elseif Pcolour == ORANGE  then gfx.r = 1.00; gfx.g = 0.85; gfx.b = 0.20;
    elseif Pcolour == DEEP_OR then gfx.r = 1.00; gfx.g = 0.60; gfx.b = 0.20
    elseif Pcolour == GREEN   then gfx.r = 0.00; gfx.g = 0.85; gfx.b = 0.20;
    elseif Pcolour == VIOLET  then gfx.r = 0.90; gfx.g = 0.00; gfx.b = 0.70;
    elseif Pcolour == YELLOW  then gfx.r = 0.90; gfx.g = 0.90; gfx.b = 0.10;
    elseif Pcolour == RED     then gfx.r = 0.80; gfx.g = 0.00; gfx.b = 0.00;
    end
 
end
   

-- --------------------------------------------------------------
function print_central (PX, Pstr)
-- --------------------------------------------------------------
local LW

if Pstr == nil then Pstr = "unnamed" end
    LW = gfx.measurestr(Pstr)
    gfx.x = math.floor(PX - LW/2)
    gfx.printf("%s", string.sub(Pstr,1,LINE_W))

end


-- -------------------------------------------------------
function print_param_name (Ppar_name, Pwidth, Palign)
-- -------------------------------------------------------
local  split, start, i, save_gfxx 

-- .... 1 or 2 lines; Left or Centred aligned (0,1)

    save_gfxx = gfx.x
    set_colour(GREY_7); gfx.a =1.00
    if string.len(Ppar_name) <= Pwidth then
        if Palign == LEFT_ then
            gfx.printf("%s", string.sub(Ppar_name,1,Pwidth))
        elseif Palign == CENTRED_ then
            print_central(gfx.x, string.sub(Ppar_name,1,Pwidth))
        end
    else
-- .... find a space near middle
        split = Pwidth
        start = math.floor(Pwidth/2)
        i = 0
        while split == Pwidth and i < start do
            if     string.sub(Ppar_name,start +i,start +i) == " " then split = start +i
            elseif string.sub(Ppar_name,start -i,start -i) == " " then split = start -i
            end
            i = i+1 
        end

        if Palign == LEFT_ then
            gfx.printf("%s", string.sub(Ppar_name,1,split))
            gfx.x = save_gfxx;  gfx.y = gfx.y + 13;
            gfx.printf("%s", string.sub(Ppar_name,split+1,Pwidth *2)) 
        elseif Palign == CENTRED_ then
            print_central(save_gfxx, string.sub(Ppar_name,1,split))
            gfx.y = gfx.y + 13;
            print_central(save_gfxx, string.sub(Ppar_name,split+1,Pwidth *2))
        end
    end

end -- of function



-- --------------------------------------------------------------
function draw_button(Pbg, Pbga, Pfg, Pfga, Ptext) 
-- --------------------------------------------------------------
local Lgfxx, Lgfxy

    Lgfxx = gfx.x; Lgfxy = gfx.y

-- .... blank out the previous button first
    set_colour(BG);
    gfx.rect(Lgfxx-2, Lgfxy-2, KNOB_W+4, 15+4)

    set_colour(Pbg); gfx.a = Pbga
    gfx.rect(gfx.x, gfx.y, KNOB_W, 15)

    set_colour(Pfg); gfx.a = Pfga
    print_central(gfx.x + KNOB_W/2, Ptext)
    gfx.a = 1.00

-- .... border
    set_colour(WHITE);
    if Pbg == GREY_6 then gfx.a = 0.40 else gfx.a = 0.60 end
    gfx.x = Lgfxx-2; gfx.y = Lgfxy-2
    gfx.lineto(gfx.x+KNOB_W+3, gfx.y)
    gfx.lineto(gfx.x,          gfx.y+15+3)
    gfx.lineto(gfx.x-KNOB_W-3, gfx.y)
    gfx.lineto(gfx.x,          gfx.y-15-3)
    gfx.a = 1.00

end -- of function


-- --------------------------------------------------------------
function draw_value_arc ( Prad, Protator, Ptimes, Palign, Pfade)
-- --------------------------------------------------------------
local LX, LY, dtor, save_gfxa, save_gfxr, save_gfxg, save_gfxb, aidx

    LX = gfx.x;
    LY = gfx.y;
-- 0219 use the last digit only
    if Palign > 20 then Palign = Palign -20; end
    if Palign > 10 then Palign = Palign -10; end

    dtor = 1/360 * 2 * 3.14159;
    save_gfxa = gfx.a;
    save_gfxr = gfx.r;
    save_gfxg = gfx.g;
    save_gfxb = gfx.b;

-- .... background arc
    set_colour(GREY_3);
    aidx = 0;
    for i=1,Ptimes*2 do
        gfx.arc (LX, LY, Prad -aidx, 210 * dtor, 360 * dtor,1);
        gfx.arc (LX, LY, Prad -aidx,   0 * dtor, 150 * dtor,1);
--              (x,y,r, ang1, ang2[,antialias]
        aidx = aidx + 1/2;
    end

    gfx.r = save_gfxr;
    gfx.g = save_gfxg;
    gfx.b = save_gfxb;

-- .... ascending
    if Palign == 1 then
        if Pfade == YES then gfx.a = 0.25 + Protator/2; end
        aidx = 0;
        for i =1, Ptimes*2 do
            gfx.arc (LX, LY, Prad -aidx, 210 * dtor, (math.min(359.9, 210 + 150 * Protator*2)) * dtor,1);
            aidx = aidx + 1/2;
        end
        if Protator > 0.5 then
            aidx = 0;
            for i=1, Ptimes*2 do
                gfx.arc (LX, LY, Prad -aidx, 0, 150 * (Protator- 0.5)*2 * dtor,1);
                aidx = aidx + 1/2;
            end
        end
    end

-- .... centred
    if Palign == 2 then
        if Pfade == YES then gfx.a = 0.3 + math.abs(0.499 - Protator)/1.5*2; end
        if Protator <= 0.5 then
            aidx = 0;
            for i =1, Ptimes*2 do
                gfx.arc (LX, LY, Prad -aidx, (-150 +150 * Protator*2) * dtor, 0, 1);
                aidx = aidx + 1/2;
            end
        end
        if Protator > 0.5 then
            aidx = 0;
            for i =1, Ptimes*2 do
                gfx.arc (LX, LY, Prad -aidx, 0, 150 * (Protator- 0.5)*2 * dtor, 1);
                aidx = aidx + 1/2;;
            end
        end
    end

-- .... descending
    if Palign == 3 then
        if Pfade == YES then gfx.a = 0.3 + Protator/1.5; end
        aidx = 0;
        for i =1, Ptimes*2 do
            gfx.arc (LX, LY, Prad -aidx, 150 * (Protator- 0.5)*2 * dtor, 150 * dtor, 1);
            aidx = aidx + 1/2;;
        end
    end

    gfx.a = save_gfxa;
end -- of function


-- --------------------------------------------------------------
function draw_slider23 (Pthisval, Pheight)
-- --------------------------------------------------------------

-- draw a vertical slider (infinite range)

local SLD_CX, SLD_X1, SLD_Y0, SLD_Y1, SLD_W, SLD_H, LED_size,
      save_gfxr, save_gfxg, save_gfxb, save_gfxa
local Lbg_height, Lfg_height, Lfg_Y0, bar_H, bar_W, width, height

    save_gfxr = gfx.r;  save_gfxg = gfx.g;  save_gfxb = gfx.b;  save_gfxa = gfx.a
    SLD_CX = math.floor(gfx.x + KNOB_W/2);  SLD_Y0 = gfx.y+10
    width = KNOB_W
    height = Pheight
        
    bar_H = math.min(20,math.floor(width /5)*2)
    bar_W = math.min(40,bar_H * 3)
    
    Lbg_height = Pheight
    Lfg_height = Lbg_height - bar_H
    Lfg_Y0 = SLD_Y0 + bar_H/2

-- .... the fader background, track and border
    set_colour(BG);
    gfx.rect(gfx.x -2, SLD_Y0 -2, width +5, height +5)

    set_colour(GREY_4)
    gfx.rect(SLD_CX -3-1-1,  SLD_Y0 -3, 11, Lbg_height +5)  

    set_colour(GREY_3)
    gfx.x = SLD_CX - KNOB_W/2-2; gfx.y = SLD_Y0 -3
    width = width +5; height = height +5
    for i =1,2 do
        gfx.lineto(gfx.x + width, gfx.y, 1);
        gfx.lineto(gfx.x, gfx.y + height, 1);
        gfx.lineto(gfx.x - width, gfx.y, 1);
        gfx.lineto(gfx.x, gfx.y - height, 1);
        gfx.x = gfx.x +1; width = width - 2;
        gfx.y = gfx.y +1; height = height - 2;
    end -- of the loop

-- .... level indicator (vertical bar)
    SLD_Y1 = math.floor(Lfg_Y0 + Lfg_height * math.max(0,(1 - Pthisval))) 
    gfx.r = save_gfxr; gfx.g = save_gfxg; gfx.b = save_gfxb; gfx.a = save_gfxa
    gfx.x = SLD_CX -1-1; gfx.y = SLD_Y0 + height
    gfx.rectto(gfx.x + 5, SLD_Y1)
    
-- .... fader handle (edge, fill and central line)
    gfx.x = SLD_CX - bar_W/2 +2-1-1; gfx.y = SLD_Y1 -bar_H/2 -2 -1
    gfx.rectto(gfx.x + bar_W -3+4, gfx.y + bar_H +4+2)

    set_colour(GREY_2)
    gfx.x = SLD_CX - bar_W/2 +3-1-1; gfx.y = SLD_Y1 -bar_H/2 -1 -1
    gfx.rectto(gfx.x + bar_W -5+4, gfx.y + bar_H +2+2)

    gfx.r = save_gfxr; gfx.g = save_gfxg; gfx.b = save_gfxb
    gfx.x = SLD_CX - bar_W/2 +4-1; gfx.y = SLD_Y1- bar_H/2 +5 -1
    gfx.rectto(gfx.x + bar_W -7+2, gfx.y + bar_H -10+2)

    gfx.y = SLD_Y0 + height +10; -- for value
    gfx.a = save_gfxa;

end -- of function


-- --------------------------------------------------------------
function draw_knob21 ( Pradius, Protator, Palign, Poptions )
--/ --------------------------------------------------------------
-- grey circumference, coloured indent, coloured annulus

local   pi150, r1_range, r1_delta, r1_phase,
        save_gfxr, save_gfxg, save_gfxb, save_gfxa, save_gfxx, save_gfxy, 
        sin_x, cos_y, Ltimes, Lbg_radius, Lindent_radius, Lrot, Limg_XY,
        bh, bw

-- .... init
    pi150 = 3.14159 * 3 / 2;  
    r1_range = 330/360;
    r1_delta = pi150 / r1_range; 
    r1_phase = - r1_delta * (r1_range / 2 + 0);

    save_gfxx = gfx.x;
    save_gfxy = gfx.y;

    save_gfxr = gfx.r;
    save_gfxg = gfx.g;
    save_gfxb = gfx.b;
    save_gfxa = gfx.a;

    Ltimes = math.floor(Pradius/5);
    Lbg_radius = Pradius -Ltimes -3-1;
    Lindent_radius = math.floor(Pradius/8);
    Lrot = Pradius -Ltimes -Lindent_radius -10;

-- .... knob edge and background
    gfx.a = 1.00;
    set_colour(GREY_6);
    gfx.circle(gfx.x, gfx.y, Pradius -Ltimes -3-1, 1, 1);

    gfx.x = gfx.x + Pradius; gfx.y = gfx.y + Pradius;
    set_colour(GREY_2);
    gfx.circle(save_gfxx, save_gfxy, Pradius -Ltimes -5-1, 1, 1);

-- .... knob value arc
     gfx.r = save_gfxr;
     gfx.g = save_gfxg;
     gfx.b = save_gfxb;
     gfx.x = save_gfxx;
     gfx.y = save_gfxy;  
     draw_value_arc ( Pradius, Protator, Ltimes, Palign, YES ); 

-- .... circle indent
    if Poptions & 1 > 0 then
        sin_x = math.sin((Protator  - 15/360) * r1_delta + r1_phase);
        cos_y = math.cos((Protator  - 15/360) * r1_delta + r1_phase);
        gfx.x = save_gfxx + math.floor((Pradius -Ltimes -Pradius/8 -10) * sin_x);
        gfx.y = save_gfxy - math.floor((Pradius -Ltimes -Pradius/8 -10) * cos_y);
        gfx.circle(gfx.x, gfx.y, math.floor(Pradius/8), 1, 1);
   end

-- .... knob handle
    if Poptions & 4 > 0 then
        gfx.setimgdim(OFF_SCREEN_CONTROL, 0,0);
        Limg_XY = 2*Lbg_radius +1;
        gfx.setimgdim(OFF_SCREEN_CONTROL, Limg_XY, Limg_XY);
        gfx.dest=OFF_SCREEN_CONTROL;               -- draw to offscreen buffer
        bw, bh = gfx.getimgdim(OFF_SCREEN_CONTROL);

        gfx.r = save_gfxr/dim_handle;
        gfx.g = save_gfxg/dim_handle;
        gfx.b = save_gfxb/dim_handle;
        gfx.circle(math.floor(bw/2), Lindent_radius+4, Lindent_radius, 1, 1); --   x y r fill aa
        gfx.circle(math.floor(bw/2), Lbg_radius,       Lindent_radius, 1, 1);
        gfx.rect(math.floor(bw/2) -Lindent_radius,     Lindent_radius +1 +5, 
                       Lindent_radius * 2+1, Lbg_radius - Lindent_radius -5); 

        gfx.dest = OFF_SCREEN_BUFFER;
        gfx.blit(OFF_SCREEN_CONTROL,1, ((Protator * 2 * 22/7) - 22/7) *300/360, 
                 0,0,bw-1, bh, save_gfxx - Lbg_radius, save_gfxy - Lbg_radius,bw,bh);
--               source, scale, rotation,
--               srcx, srcy, srcw, srch, 
--               destx, desty, destw, desth, 
--               rotxoffs, rotyoffs 
    end

-- .... central cap
    if Poptions & 2 > 0 then
        gfx.a = 1.00; 
        gfx.circle(save_gfxx, save_gfxy, math.floor(Pradius/4), 1, 1);
    end
-- .... indicator line (WIP)
    if Poptions & 8 > 0 then
        gfx.setimgdim(OFF_SCREEN_CONTROL, 0,0);
        Limg_XY = 2*Lbg_radius +1;
        gfx.setimgdim(OFF_SCREEN_CONTROL, Limg_XY, Limg_XY);
        gfx.dest=OFF_SCREEN_CONTROL;                             -- draw to offscreen buffer
        bw, bh = gfx.getimgdim(OFF_SCREEN_CONTROL);
 
        gfx.rect(math.floor(bw/2) -3, 4, 
                       Lindent_radius +1, Lbg_radius - Lindent_radius -5);

        gfx.dest=MAIN_WINDOW;
        gfx.blit(OFF_SCREEN_CONTROL,1, ((Protator * 2 * 22/7) - 22/7) *300/360, 
                 0,0,bw-1, bh, save_gfxx - Lbg_radius, save_gfxy - Lbg_radius,bw,bh);
    end
 
-- --------------------------
    gfx.y = save_gfxy + math.max(25,Pradius -8); -- for value
    gfx.a = save_gfxa;

end -- .... end of function


-- -------------------------------------------------------
function position_the_control(Pkidx)
-- -------------------------------------------------------
local Lrow, Lcolumn, LX, LY, Lrows
-- .... PKidx = knob number -1
-- .... only works for up to three rows
    Lrows =3

    Lrow = (math.floor((Pkidx)/COLUMNS) % Lrows) +1
    Lcolumn = Pkidx % COLUMNS +1

    LX = CENTRE_X0 + STEP_X * (Lcolumn-1)
    if Lcolumn > 4 then LX = LX + KNOB_XMID end -- allow for mid gap
    LY = TOP_CONTROLS_Y

    for i =1, Lrow-1 do
        LY = LY + row_height[i]
    end

return LX, LY
end


-- -------------------------------------------------------ssssssss
function draw_updated_param_box (Pkidx)
-- -------------------------------------------------------
local LX0, LY0, LX, LY, LW, LH, LXGAP, LYGAP, LXMID, Lfactor,
      Lrow, Lcolumn, pidx, 
      Ltr_idx, LFX_idx, Lparnum, Lvalue, Lmin, Lmax, Lformval, Lbar_H, Ltrack
      

    LX0   = BOX_X0;    LY0   = BOX_Y0;    LW    = BOX_W;    LH = BOX_H
    LXGAP = BOX_XGAP;  LYGAP = BOX_YGAP;  LXMID = BOX_XMID

    Lrow = math.floor((Pkidx - (sel_bank -1) * ROWS*COLUMNS)/COLUMNS)+1
    Lcolumn = Pkidx % COLUMNS +1
    pidx = Pkidx * MAP_ELEMENTS +1 

-- .... get parameter data
    Ltr_idx  = maps[pidx +4]   
    LFX_idx  = maps[pidx +5]
    Lparnum  = maps[pidx +6]

    Ltrack = reaper.GetTrack(0,Ltr_idx)
    Lvalue, Lmin, Lmax = reaper.TrackFX_GetParam(Ltrack, LFX_idx, Lparnum)
    maps[pidx +3] = Lvalue / (Lmax - Lmin)
    _, Lformval = reaper.TrackFX_GetFormattedParamValue(Ltrack, LFX_idx, Lparnum, "")
    maps[pidx +7] = Lformval

    LX, LY = position_the_control(Pkidx)
    LX = LX - BOX_W/2 -- for left-hand edge
    LY = LY +10 +20        -- for top edge

-- .... vertical bar for param value, blank it out first
    set_colour(BG);
    gfx.rect(LX + LW -8-4, LY+1-10, 6, LH -2) --XY WH

    Lbar_Y = math.ceil(LY +2-9 + (LH -4) * (1-Lvalue/(Lmax - Lmin)))
-- ALT    set_colour(GREY_7)
    gfx.a =1.00
    set_instance_colour(Ltr_idx, LFX_idx)
    gfx.rect(LX + LW -8-4, Lbar_Y, 6, LY + (LH -9-2) - Lbar_Y)

-- .... and the group bar and formatted value
    LW,LH = gfx.measurestr(string.format("%02d", Pkidx+1))
    gfx.x = LX+15; gfx.y = LY+5-15;
    draw_group (Ltr_idx, LFX_idx, Lformval)

end -- of function


-- -------------------------------------------------------
function draw_updated_param_knob (Pkidx, Palign)
-- -------------------------------------------------------

local LX0, LY0, LX, LY, LW, LH, LXGAP, LYGAP, LXMID, Lfactor, Lmixer_Y0,
      Lrow, Lcolumn, pidx, Lvalue, Lmin, Lmax, Lformval,
      Ltr_idx, LFX_idx, Lparnum, Ltrack

    LX0   = KNOB_X0;    LY0   = KNOB_Y0;    LW    = KNOB_W;     LH      = KNOB_H
    LXGAP = KNOB_XGAP;  LYGAP = KNOB_YGAP;  LXMID = KNOB_XMID;  Lfactor = 2 

    Lrow = math.floor((Pkidx - (sel_bank -1) * ROWS*COLUMNS)/COLUMNS)+1
    Lcolumn = Pkidx % COLUMNS +1
    pidx = Pkidx * MAP_ELEMENTS +1 

-- .... get parameter data
    Ltr_idx  = maps[pidx +4]   
    LFX_idx  = maps[pidx +5]
    Lparnum  = maps[pidx +6]

    Ltrack = reaper.GetTrack(0,Ltr_idx)
    Lvalue, Lmin, Lmax = reaper.TrackFX_GetParam(Ltrack, LFX_idx, Lparnum)
    maps[pidx +3] = Lvalue/(Lmax - Lmin)
    _, Lformval = reaper.TrackFX_GetFormattedParamValue(Ltrack, LFX_idx,  Lparnum, "")
    maps[pidx +7] = Lformval

    LX, LY = position_the_control(Pkidx)

-- .... blank out previous Lformval
    set_colour(BG); gfx.a = 1.00;
    gfx.x = LX; gfx.y = LY +KNOB_W +15;
    gfx.rect(LX-KNOB_W, gfx.y + 28, KNOB_W*2, 15)

-- .... draw the knob
    set_instance_colour(Ltr_idx, LFX_idx)

-- 0325 background for knobs
if knob_BG == YES then
    gfx.a = 0.20
    gfx.rect(LX -STEP_X/2, LY+KNOB_W, STEP_X, KNOB_W)
    gfx.a = 1.00
end

    draw_knob21 (KNOB_W, Lvalue/(Lmax - Lmin), Palign, 4) -- Pradius, Protator, Palign, Poptions

-- .... and the formatted parameter value
    if show_formatted == YES then 
        gfx.x = LX - gfx.measurestr(string.format("%s",Lformval))/2 
        set_colour(WHITE); gfx.a = 0.75
        gfx.printf("%s", Lformval)
    end  

end -- of function


-- -------------------------------------------------------
function draw_top_buttons()
-- -------------------------------------------------------
local Lrow, Lcolumn, LBankW, LBankGap, save_gfxx
local LX0, LY0, LX, LY, LW, LH, LXGAP, LYGAP, LXMID, Lfactor,
      LXL, LXR, LBankW, LBankGap, 
      Ltrack, Lvolume, Lpan, Ltr_name, Lmute, Lsolo, Lrecarm, Ltext,
      Lnumtracks, Lmixer_Y0, Lr, Lg, Lb, LpanX, Ldb,
      Lsets

    Lrow = 1;       Lcolumn =1
    LBankW = 70;    LBankGap = 10
    LX0 = math.max(240,gfx.w /2 - (LBankW + LBankGap) * 3) 

-- ------------------------------
-- top background and title
-- ------------------------------
    set_colour(BLACK); gfx.a =1.00
    gfx.rect(0, 0, gfx.w, 40) -- X Y W H
    set_colour(GREY_6)
    gfx.line(0, 41, gfx.w, 41)

    gfx.x =20; gfx.y =5
    set_colour(ORANGE); gfx.a =1
    gfx.setfont(3)
    gfx.printf(MODEL)

-- ------------------------------
-- control bank selectors
-- ------------------------------

    gfx.x =LX0; gfx.y = TOP_BUTTON_Y -2
    set_colour(GREY_7); gfx.a = 0.75
    gfx.setfont(2)
    gfx.printf("Set:  ")

    gfx.y = TOP_BUTTON_Y
    if op_mode     == MIXER then Lsets = 6
    elseif op_mode == INSTR then Lsets = 6
    end
    for Lcolumn = 1, Lsets do
        set_colour(GREY_7)
        gfx.lineto(gfx.x+LBankW, gfx.y)
        gfx.lineto(gfx.x, gfx.y+20)
        gfx.lineto(gfx.x-LBankW, gfx.y)
        gfx.lineto(gfx.x, gfx.y-20)

        set_colour(GREY_7);  gfx.a = 0.75
        if op_mode == MIXER then
            if sel_bank == Lcolumn then              set_colour(DEEP_OR); gfx.a = 0.75
            elseif used_banks[Lcolumn] == YES then   set_colour(YELLOW);  gfx.a = 0.80
            end
        else
            if sel_bank == Lcolumn then              set_colour(DEEP_OR); gfx.a = 0.75
            elseif used_banks[Lcolumn] == YES then   set_colour(YELLOW);  gfx.a = 0.80
            end
        end


        gfx.rect(gfx.x +2, gfx.y +2, LBankW -3, 20 -3)
        save_gfxx = gfx.x

        if op_mode == MIXER     then controlsperset = 24
        elseif op_mode == INSTR then controlsperset = 24
        else -- op_mode == SYNTH
                                     controlsperset = 48
        end
        
        Ltext = string.format("%02d-%02d",(Lcolumn-1)*controlsperset+1, 
                                          (Lcolumn-1)*controlsperset+controlsperset)
        gfx.y = gfx.y -1
        gfx.setfont(2)
        set_colour(GREY_2); gfx.a = 1.00
        if op_mode == MIXER then
            if Lcolumn < 4 then print_central(gfx.x+LBankW/2,string.format("%d", Lcolumn)) 
                           else print_central(gfx.x+LBankW/2,string.format("%d+Solo", Lcolumn-3)) end 
        else
            if Lcolumn < 4 then print_central(gfx.x+LBankW/2,string.format("%d", Lcolumn)) 
                           else print_central(gfx.x+LBankW/2,string.format("%d+Solo", Lcolumn-3)) end 
        end
        gfx.x = save_gfxx + LBankW + LBankGap
        gfx.y = gfx.y +1
    end
    gfx.setfont(1)

-- -----------------------------------------
--  Help button [?]
-- -----------------------------------------
    set_colour(GREY_7)
    gfx.x = gfx.w - HELP_OFFSET; gfx.y = TOP_BUTTON_Y
    gfx.lineto(gfx.x+20, gfx.y)
    gfx.lineto(gfx.x, gfx.y+20)
    gfx.lineto(gfx.x-20, gfx.y)
    gfx.lineto(gfx.x, gfx.y-20)
        
    if help_display == 1 then set_colour(ORANGE); gfx.a = 0.75
    else                      set_colour(GREY_7); gfx.a = 0.75
    end
    gfx.rect(gfx.w - HELP_OFFSET +2, TOP_BUTTON_Y +2, 17,17)
    set_colour(GREY_2); gfx.a = 1.00
    gfx.x = gfx.w - HELP_OFFSET +7; gfx.y = TOP_BUTTON_Y +3; gfx.printf("?") 
    
-- -----------------------------------------
--  group colour button
-- -----------------------------------------
    set_colour(GREY_7)
    gfx.x = gfx.w - COLOUR_OFFSET; gfx.y = TOP_BUTTON_Y
    gfx.lineto(gfx.x+20, gfx.y)
    gfx.lineto(gfx.x, gfx.y+20)
    gfx.lineto(gfx.x-20, gfx.y)
    gfx.lineto(gfx.x, gfx.y-20)
    if colour_clicked == YES then set_colour(ORANGE); gfx.a = 0.75
    else                          set_colour(CYAN); gfx.a = 0.75
    end
    gfx.rect(gfx.w - COLOUR_OFFSET +2, TOP_BUTTON_Y +2, 17,17)
    set_colour(GREY_2); gfx.a = 1.00
    gfx.setfont(1)
    gfx.x = gfx.w - COLOUR_OFFSET +7; gfx.y = TOP_BUTTON_Y +3; gfx.printf("C")   


-- -----------------------------------------
--  Mixer / Instrument Mode button
-- -----------------------------------------
    set_colour(GREY_7)
    gfx.x = gfx.w - MODE_OFFSET; gfx.y = TOP_BUTTON_Y
    gfx.lineto(gfx.x+40, gfx.y)
    gfx.lineto(gfx.x, gfx.y+20)
    gfx.lineto(gfx.x-40, gfx.y)
    gfx.lineto(gfx.x, gfx.y-20)

    if mode_clicked == 1 and click_stage == 2 then
        set_colour(ORANGE); gfx.a = 0.75
    elseif op_mode == MIXER then 
                set_colour(GREEN); gfx.a = 0.95
    elseif op_mode == INSTR then 
        set_colour(GREEN); gfx.a = 0.95
    else
        set_colour(YELLOW); gfx.a = 0.95
    end

    gfx.rect(gfx.w - MODE_OFFSET +2, TOP_BUTTON_Y +2, 37,17)
    set_colour(GREY_2); gfx.a = 1.00
    gfx.setfont(1)
    gfx.y = TOP_BUTTON_Y +3; 
    if op_mode == MIXER then     print_central(gfx.x +20, "Mixer")
    elseif op_mode == INSTR then print_central(gfx.x +20, "Instr")
    else                         print_central(gfx.x +20, "Synth")
    end    
  
    gfx.setfont(1)
    gfx.y = TOP_BUTTON_Y +3; 

-- -----------------------------------------
-- .... Bank left / Right buttons
-- -----------------------------------------
    gfx.y = TOP_BUTTON_Y + KNOB_H + KNOB_YGAP

    for i = 1,3 do
        gfx.x =gfx.w - MBS_OFFSET; 
        set_colour(GREY_7)
        gfx.lineto(gfx.x+LBankW, gfx.y)
        gfx.lineto(gfx.x, gfx.y+20)
        gfx.lineto(gfx.x-LBankW, gfx.y)
        gfx.lineto(gfx.x, gfx.y-20)

        set_colour(GREY_7);  gfx.a = 0.55
        if i == 3 then gfx.a = solo_gfxa
        elseif op_mode == INSTR then 
            if i == 1 then set_colour(bankLeft_colour);   gfx.a = 0.75 end
            if i == 2 then set_colour(bankRight_colour);  gfx.a = 0.75 end
        end

        gfx.rect(gfx.x +2, gfx.y +2, LBankW -3, 20 -3)
 
--        gfx.x = save_gfxx + LBankW + LBankGap
        gfx.y = gfx.y + 50
    end

    gfx.setfont(2)
    gfx.x =gfx.w - MBS_OFFSET;
    gfx.y = TOP_BUTTON_Y + KNOB_H + KNOB_YGAP
    set_colour(GREY_2); gfx.a = 1.00
    if op_mode == MIXER then print_central(gfx.x+LBankW/2,"MIXER")
    else                     print_central(gfx.x+LBankW/2,"BANK")
    end

    gfx.x =gfx.w - MBS_OFFSET; gfx.y = gfx.y +100; print_central(gfx.x+LBankW/2,"SHIFT")

    gfx.setfont(1)

end -- of function


-- -------------------------------------------------------
function set_instance_colour (PTr_idx, PFX_idx)
-- -------------------------------------------------------
local  Lred, Lgreen, Lblue, Lnum1, Lnum2, Lfactor, offset, Lcol, Lhue

    Lnum1 = 48; Lnum2  = 10     
    Lfactor = prime / (Lnum1 * Lnum2) 
    Lcol = ((PTr_idx * Lnum2 + (PFX_idx+1)) * Lfactor*1000) % 1000 / 1000

    Lhue = math.floor(Lcol * 360);
    Lred =1; Lgreen =0; Lblue = 0;

    if     Lhue <  60 then Lred = 1;               Lgreen = (Lhue-0)/60;     Lblue = 0;                -- green up
    elseif Lhue < 120 then Lred = (120-Lhue)/60;   Lgreen = 1;               Lblue = 0;                -- red down 
    elseif Lhue < 180 then Lred = 0;               Lgreen = 1;               Lblue = (Lhue-120)/60;    -- blue up
    elseif Lhue < 240 then Lred = 0;               Lgreen = (240 - Lhue)/60; Lblue = 1;                -- green down
    elseif Lhue < 300 then Lred = (Lhue-240)/60;   Lgreen = 0;               Lblue = 1;                -- red up 
    elseif Lhue < 360 then Lred = 1;               Lgreen = 0;               Lblue = (360-Lhue)/60;    -- blue down
    end

    gfx.r = Lred; gfx.g = Lgreen; gfx.b = Lblue;
    gfx.a = (Lhue % 5) /10 + 0.5;

end -- of function


-- -------------------------------------------------------------
function is_dark(PX, PY)
-- -------------------------------------------------------------
local  greyscale, save_gfxx, save_gfxy 

    gfx.x = PX; 
    gfx.y = PY;
    gfx.getpixel(gfx.r, gfx.g, gfx.b);

    greyscale = 0.2*gfx.r + 0.7*gfx.g + 0.1*gfx.b;
    if greyscale <= 0.350 then return true else return false end

end -- of function


-- -------------------------------------------------------------
function is_dark_colour ()
-- -------------------------------------------------------------
local  greyscale, save_gfxx, save_gfxy 

    greyscale = 0.2*gfx.r + 0.7*gfx.g + 0.1*gfx.b;
    if greyscale <= 0.350 then return true else return false end

end -- of function


-- -------------------------------------------------------
function draw_group (PTr_idx, PFX_idx, Pformval)
-- -------------------------------------------------------
local LW

    LW = BOX_W

    set_colour(BLACK); gfx.a = 1.00
    gfx.rect(gfx.x +4, gfx.y +1, LW -30 -4, 15);

    set_colour(GREY_7); gfx.a = 0.5
    gfx.rect(gfx.x +4, gfx.y +1, LW -30 -4, 15);    
    set_instance_colour (PTr_idx, PFX_idx)
    gfx.rect(gfx.x +4+1, gfx.y+2 , LW -30 -4 -2, 15 -2);

-- .... and the formatted parameter value
    if show_formatted == 1 then 
        if is_dark(gfx.x, gfx.y) then set_colour(WHITE); gfx.a = 0.75
        else                          set_colour(BLACK); gfx.a = 0.90
        end
        gfx.printf("    %s", Pformval)
    end

end -- of function


-- -------------------------------------------------------
function draw_a_row_of_boxes(Prow)
-- -------------------------------------------------------
local column, kidx, pidx, LX, LY, Lheight, LbarH,
      Ltrack, Ltr_name, LFX, Lpar_name, Lvalue, Ltr_idx, LFX_idx, Lpar_num, Lmin, Lmax, Lformval

    Lheight = 00 + BOX_H +20
--    LY  = gfx.y                 -- for top line of box   

    for column = 1, COLUMNS do
        kidx = (Prow -1) * COLUMNS + (column -1) + (sel_bank -1) * (COLUMNS * ROWS)

        if op_mode == MIXER and sel_bank == 4 then 
            kidx = (Prow -1) * COLUMNS + (column -1) + (sel_bank -1) * (COLUMNS * 3) end

        pidx = kidx * MAP_ELEMENTS +1
        LX, LY = position_the_control(kidx)
        LX = LX - BOX_W/2 -- for left-hand edge
        LY = LY +20

-- .. draw the border and meter
        set_colour(GREY_6); 
        gfx.x = LX-2-2; gfx.y = LY;
        gfx.lineto(gfx.x+BOX_W, gfx.y)
        gfx.lineto(gfx.x,       gfx.y+BOX_H)
        gfx.lineto(gfx.x-BOX_W, gfx.y)
        gfx.lineto(gfx.x,       gfx.y-BOX_H)

        set_colour(GREY_7); gfx.a = 0.10
        gfx.rect(gfx.x +2, gfx.y +2, BOX_W -10, BOX_H -3)

-- .... the control number
        set_colour(GREY_7); gfx.a =0.60
        gfx.x = LX; gfx.y = LY; gfx.printf("%02d", kidx +1) 

-- .... get the parameter data
        Ltr_name = maps[pidx +0]
        if Ltr_name ~= " " then
            LFX       = maps[pidx +1]
            Lpar_name = maps[pidx +2]
            Ltr_idx   = maps[pidx +4]   
            LFX_idx   = maps[pidx +5]
            Lpar_num  = maps[pidx +6]
                                   
-- .... the track name (avoid repeats)
            if column > 1 and hide_repeats == YES and Ltr_name == maps[pidx +0 - MAP_ELEMENTS] then 
                gfx.x = LX;  gfx.y = gfx.y + 15;  
            else
                gfx.x = LX;  gfx.y = gfx.y + 15;  
                set_colour(CYAN); gfx.a = 0.80 
                gfx.printf("%s", string.sub(Ltr_name, 1, LINE_W)) -- truncated, if needed
            end 

-- .... the FX and parameter name
--ALT                    set_colour(ORANGE); gfx.a = 0.90
            set_instance_colour(Ltr_idx, LFX_idx); gfx.a =1.00
            gfx.x = LX; gfx.y = gfx.y + 15  
            gfx.printf("%s", string.sub(LFX, 1, LINE_W) )

            set_colour(GREY_7)
            gfx.x = LX; gfx.y = gfx.y + 15;
            print_param_name(Lpar_name, LINE_W, LEFT_)

-- .... bar for param value
             draw_updated_param_box (kidx)           

         end  -- end of selected track
    end       -- end of row

    gfx.y = LY +Lheight

end           -- of function


-- -------------------------------------------------------
function draw_a_row_of_knobs (Prow, Palign)
-- -------------------------------------------------------
local column, kidx, pidx, LX, LY, Lheight,
      Ltrack, Ltr_name, LFX, Lpar_name, Lvalue, Ltr_idx, LFX_idx, Lpar_num, Lmin, Lmax, Lformval

    Lheight = 20 + KNOB_W *2 +50
    for column = 1, COLUMNS do
        kidx = (Prow -1) * COLUMNS + (column -1) + (sel_bank -1) * (COLUMNS * ROWS)

        if op_mode == MIXER and sel_bank == 4 then 
            kidx = (Prow -1) * COLUMNS + (column -1) + (sel_bank -1) * (COLUMNS * 3) end

        pidx = kidx * MAP_ELEMENTS +1 
        LX, LY = position_the_control(kidx)

-- .... the control number
        set_colour(GREY_7); gfx.a =0.60
        gfx.x = LX - KNOB_W -4; gfx.y = LY+12;   
        gfx.printf("%02d", kidx +1)

-------------------------
-- .... get the parameter data
        Ltr_name = maps[pidx +0]
        if Ltr_name ~= " " then
            LFX       = maps[pidx +1]
            Lpar_name = maps[pidx +2]
            Ltr_idx   = maps[pidx +4]   
            LFX_idx   = maps[pidx +5]

-- .... track name (avoid repeats)
            if column > 1 and hide_repeats == YES and Ltr_name == maps[pidx +0 - MAP_ELEMENTS] then 
                gfx.x = gfx.x -16; gfx.y = LY;
            else
                gfx.x = gfx.x -16; gfx.y = LY;
                set_colour(CYAN); gfx.a = 0.80
                print_central(LX, string.sub(Ltr_name,1,LINE_W)) -- truncated, if needed
            end 

-- .... FX name (avoid repeats)
            if column > 1 and hide_repeats == YES and LFX == maps[pidx +1 - MAP_ELEMENTS] then 
                gfx.y = LY + KNOB_W *2 +25 
            else
--ALT                set_colour(ORANGE)
                set_instance_colour(Ltr_idx, LFX_idx); gfx.a =1.00
                gfx.y = LY + KNOB_W *2 +25
                print_central(LX, LFX )
            end 

-- .... parameter name (1 or 2 lines)
             gfx.x = LX;  gfx.y = gfx.y+ 15;
             print_param_name (Lpar_name, LINE_W, CENTRED_)

-- .... draw the knob and the formatted parameter value
            draw_updated_param_knob (kidx, Palign)   

        else -- no mapped knob
            gfx.x = LX; gfx.y = LY + KNOB_W +15
            set_colour(GREY_6)
            draw_knob21 (KNOB_W, 0, 1, 0) -- Pradius, Protator, Palign, Poptions (none)
        end -- of selected knob
    end     -- end of row

    gfx.y = LY +Lheight

end         -- of function


-- -------------------------------------------------------
function right_click_control (Prow, Pcolumn) -- opne / closes FX GUI
-- -------------------------------------------------------
local Lknob_num, pidx, Ltr_name, Ltr_idx, LFX_idx

    click_stage =2
    Lknob_num = (Prow-1) * COLUMNS + Pcolumn + (sel_bank-1) * (ROWS * COLUMNS)
    pidx = (Lknob_num-1) * MAP_ELEMENTS +1
    Ltr_name = maps[pidx +0]
    if Ltr_name ~= " " then
        Ltr_idx   = maps[pidx +4]
        LFX_idx   = maps[pidx +5] 
        Ltrack = reaper.GetTrack(0,Ltr_idx)
        if  reaper.TrackFX_GetOpen(Ltrack, LFX_idx) then
            reaper.TrackFX_SetOpen(Ltrack, LFX_idx, false)
        else
            reaper.TrackFX_SetOpen(Ltrack, LFX_idx, true)
        end            
    end

end -- of function


-- -------------------------------------------------------
function detect_clicks()
-- -------------------------------------------------------

local LX0, LY0, LXL, LXR, LBankW, LBankGap, LW, LH, LXGAP, LYGAP, LXMID, LX, LY,
      Lnumtracks, Lmixer_Y0, Lright_X, Lfactor

-- .... to check compatibility for Move Map (MIDIMix)
-- .... to be made dynamic, based on row defs
local mm_var_rows = {1,     2,   3, nil, nil,   6}
local mm_btn_rows = {nil, nil, nil,   4,   5, nil}
    
    LX0   = 200
    LBankW = 70; LBankGap = 10
    LX0 = math.max(240,gfx.w /2 - (LBankW + LBankGap) * 3)

-- ------------------------------
-- .... select a bank of controls
-- ------------------------------
    LXL = LX0 +35
    if op_mode == MIXER then 
        LXR = LXL + (LBankW + LBankGap) * 6 -10
        sel_bank_prev_instr  = sel_bank
        solo_gfxa_prev_instr = solo_gfxa
    elseif op_mode == INSTR then 
        LXR = LXL + (LBankW + LBankGap) * 6 -10
        sel_bank_prev_instr  = sel_bank
        solo_gfxa_prev_instr = solo_gfxa
    end 
    if  gfx.mouse_cap&1 == 1 
    and gfx.mouse_x > LXL and gfx.mouse_x < LXR
    and gfx.mouse_y > TOP_BUTTON_Y and gfx.mouse_y < TOP_BUTTON_Y +20
    then
        set_clicked = 1
        sel_bank = math.floor((gfx.mouse_x - LXL +20/2) / (LBankW + LBankGap)) +1 
--0331 +
if op_mode == MIXER and sel_bank == 2 then sel_bank = 4 end

        click_stage =2
        get_maps =2
        if     op_mode == MIXER and sel_bank >1 then solo_gfxa = 0.75
        elseif op_mode == INSTR and sel_bank >3 then solo_gfxa = 0.75 
        else                                         solo_gfxa = 0.55
        end

        if op_mode == INSTR then
            if sel_bank == 1 or sel_bank == 3 or sel_bank == 4 or sel_bank == 6 then 
                  bankRight_colour = DEEP_OR
            else  bankRight_colour = GREY_7 end
            if sel_bank == 2 or sel_bank == 3 or sel_bank == 5 or sel_bank == 6 then 
                  bankLeft_colour = DEEP_OR
            else  bankLeft_colour = GREY_7 end
        end
    end

-- ------------------------------
-- .... detect help  
-- ------------------------------
    if (gfx.mouse_cap&1 == 1 or gfx.mouse_cap&2 == 2) 
    and gfx.mouse_x > gfx.w - HELP_OFFSET and gfx.mouse_x < gfx.w - HELP_OFFSET +20
    and gfx.mouse_y > TOP_BUTTON_Y and gfx.mouse_y < TOP_BUTTON_Y +20
    then
        help_clicked =1
        help_display  = 1 - help_display
        help_page = gfx.mouse_cap
        click_stage =2
    end

-- ------------------------------
-- .... detect Mixer / Instrument Mode click 
-- ------------------------------

    if gfx.mouse_x > gfx.w - MODE_OFFSET and gfx.mouse_x < gfx.w - MODE_OFFSET +40
    and gfx.mouse_y > TOP_BUTTON_Y and gfx.mouse_y < TOP_BUTTON_Y +20
    then
        mode_clicked =1
        if gfx.mouse_cap == 1 then
            op_mode = op_mode +1
            if op_mode > (SYNTH -1) then op_mode = MIXER end
            click_stage =2
            get_maps =2

            if op_mode == MIXER then
                ROWS = 3;
                sel_bank  = sel_bank_prev_instr;
                solo_gfxa = solo_gfxa_prev_instr; 
            elseif op_mode == INSTR then 
                ROWS = 3;
                sel_bank  = sel_bank_prev_instr;
                solo_gfxa = solo_gfxa_prev_instr; 
            else
                ROWS = PROWS end
        end
    end

-- ------------------------------
-- .... detect group colour click 
-- ------------------------------
    if gfx.mouse_x > gfx.w - COLOUR_OFFSET and gfx.mouse_x < gfx.w - COLOUR_OFFSET +20
    and gfx.mouse_y > TOP_BUTTON_Y and gfx.mouse_y < TOP_BUTTON_Y +20
    then
        if gfx.mouse_cap == 1 then      -- click for colour change
            colour_clicked = YES
            prime = math.random(PRIME_0)
            click_stage =2
            get_maps =2
        elseif gfx.mouse_cap == 2      -- right_click for show/hide formatted value    
        then
            formatted_clicked = YES
            show_formatted = 1 - show_formatted
            click_stage =2
            get_maps =2
        end
    end
-- .... or, right-click on the title
    if gfx.mouse_cap == 2                          --right_click for colour change
    and gfx.mouse_x > 20 and gfx.mouse_x < 220
    and gfx.mouse_y > 10 and gfx.mouse_y < 30
    then
        change_colour = YES
        prime = math.random(151)
        click_stage =2
        get_maps =2
    end


-- ------------------------------
-- .... detect << or >> click
-- ------------------------------
    if op_mode ~= SYNTH then
        gfx.x = 8; 
        if op_mode == MIXER then 
                        Lmixer_Y0 = MIXER_Y0 + 245
        else -- op_mode == INSTR
            Lmixer_Y0 = MIXER_Y0 + 245
        end
        Lright_X = NEXT_OFFSET -10
        Lnumtracks = reaper.GetNumTracks()

        if gfx.mouse_cap == 1 
        and first_mixer_track > 1
        and gfx.mouse_x > 0 and gfx.mouse_x < 30
        and gfx.mouse_y > Lmixer_Y0 and gfx.mouse_y < Lmixer_Y0 +20
        then
            first_mixer_track = math.max(1,first_mixer_track -COLUMNS)
            click_stage =2
            get_maps = 2 
        end

        if gfx.mouse_cap == 1 
        and (first_mixer_track +COLUMNS) < (Lnumtracks +1)
        and gfx.mouse_x > Lright_X and gfx.mouse_x < Lright_X +30
        and gfx.mouse_y > Lmixer_Y0 and gfx.mouse_y < Lmixer_Y0 +20
        then
            first_mixer_track = math.min(first_mixer_track + COLUMNS, 
                                         math.floor(Lnumtracks/COLUMNS) * COLUMNS +1)
            click_stage =2
            get_maps = 2 
        end
    end

-- ------------------------------
-- .... detect right-click on an FX button in INSTR mode (WIP)
-- ------------------------------

-- .... which opens/closes the FX's GUI
    if gfx.mouse_cap == 2 then
        click_stage = 2
        for Lcolumn = 1,COLUMNS do
            LX, LY = position_the_control(ROWS *COLUMNS * sel_bank + Lcolumn -1)
            LY = LY +20
            LFX_idx = Lcolumn -1

            if gfx.mouse_x > LX - KNOB_W and gfx.mouse_x < LX + KNOB_W +10-10
            and gfx.mouse_y > LY and gfx.mouse_y < LY +15+15
            then
               Lseltrack = reaper.GetLastTouchedTrack()
               _, LtracknumberFX, LselectFX, Lparamnumber = reaper.GetLastTouchedFX()
               if  reaper.TrackFX_GetOpen(Lseltrack, LFX_idx) then
                   reaper.TrackFX_SetOpen(Lseltrack, LFX_idx, false)
               else
                   reaper.TrackFX_SetOpen(Lseltrack, LFX_idx, true)
               end
            end
        end
    end

        
end -- of function


-- -------------------------------------------------------
function detect_param_clicks()
-- -------------------------------------------------------
local Lrowidx, pidx, LX, LY, Lcol, Lknob_num,
      Ltrack, Ltr_name, LFX, Lpar_name, Lvalue, Ltr_idx, LFX_idx, Lmin, Lmax, Lformval

    if gfx.mouse_y > TOP_CONTROLS_Y then
        if gfx.mouse_x > gfx.w/2 then LX = gfx.mouse_x - MID_GAP else LX = gfx.mouse_x end
        Lcol = math.floor((LX - (CENTRE_X0 - STEP_X/2)) / STEP_X) +1

        LY = TOP_CONTROLS_Y
        Lrowidx = -1
        for Lidx = 1, ROWS do
            if gfx.mouse_y > LY and gfx.mouse_y < (LY + row_height[Lidx]) then
                Lrowidx = Lidx
            end 
            LY = LY + row_height[Lidx]
        end

        if Lrowidx > -1 then
            Lknob_num = (Lrowidx-1) * COLUMNS + Lcol + (sel_bank-1) * (3 * COLUMNS)

-- .... detect right-click on a control, which opens/closes the FX's GUI
            if gfx.mouse_cap == 2 then
                click_stage = 2
                pidx = (Lknob_num-1) * MAP_ELEMENTS +1
                Ltr_name = maps[pidx +0]
                if Ltr_name ~= " " then
                    Ltr_idx   = maps[pidx +4]
                    LFX_idx   = maps[pidx +5] 

                    Ltrack = reaper.GetTrack(0,Ltr_idx)
                    if  reaper.TrackFX_GetOpen(Ltrack, LFX_idx) then
                        reaper.TrackFX_SetOpen(Ltrack, LFX_idx, false)
                    else
                        reaper.TrackFX_SetOpen(Ltrack, LFX_idx, true)
                    end
               end
            end

            if gfx.mouse_cap == 1 + 16 then
                click_stage = 2
                if move_map_stage == 1 then
                    mm_sknob = Lknob_num;  move_map_stage = 2 
                else
                    mm_tknob = Lknob_num;  move_map_stage = 3
                end
            end
        end
    end


end -- of function


-- -------------------------------------------------------
function move_map (Psknob, Ptknob)
-- -------------------------------------------------------
local Lsource, Ltarget, Lstrackidx, Lttrackidx, Lold2, Lnew2, Lmid2, Lnpos, Lopos,
      Lnum, Lresult, Lsrow, Ltrow,
      Lstrack, Lttrack, Lschunk, Ltchunk, Lschunk12, Lschunk13, Lchunk14, Lschunk15,
      Lmove_note, Lmove_type

    Lsrow = Psrow; Ltrow = Ptrow
    Lnpos = nil; Lopos = nil; Lmove_type = 0; Lmove_note = "NONE" 
    
    Lstrackidx =  maps[(Psknob -1)  * MAP_ELEMENTS +1 +4]
    Lttrackidx =  maps[(Ptknob -1)  * MAP_ELEMENTS +1 +4]
    Lold2 = "knob/" .. string.format("%d", Psknob) .. "\n"
    Lmid2 = "knob/" .. tostring(88) .. "\n"
    Lnew2 = "knob/" .. string.format("%d", Ptknob) .. "\n"

-- .... if source is not empty, get the source track chunk for the move
    if Lstrackidx ~= " " then
        Lstrack = reaper.GetTrack(0, Lstrackidx)
        _, Lschunk = reaper.GetTrackStateChunk(Lstrack, "")
        Lopos = string.find(Lschunk,Lold2,1,true)
        Lmove_type = 1
    end

-- .... if target is not empty, get the target track chunk for the move
    if Lttrackidx ~= " " then 
        Lttrack = reaper.GetTrack(0, Lttrackidx)
        _, Ltchunk = reaper.GetTrackStateChunk(Lttrack, "")
        Lnpos = string.find(Ltchunk,Lnew2,1,true)
        Lmove_type = Lmove_type +2 
    end

-- .... do the move
    if Lmove_type == 1 then
        Lmove_note = "NEW: " .. Ptknob
        Lschunk12, Lnum = string.gsub(Lschunk, Lold2, Lnew2,1)
        Lresult = reaper.SetTrackStateChunk(Lstrack, Lschunk12, false)

    elseif Lmove_type == 2 then
        Lmove_note = "TO EMPTY: " .. Psknob
        Ltchunk13, Lnum = string.gsub(Ltchunk, Lnew2, Lold2,1)
        Lresult = reaper.SetTrackStateChunk(Lttrack, Ltchunk13, false)

    elseif Lmove_type == 3 then
        Lmove_note = "SWITCH: " .. Psknob .. " and " .. Ptknob
        if Lstrackidx == Lttrackidx then
            Lchunk14, num = string.gsub(Lschunk,  Lnew2, Lmid2) 
            Lchunk14, num = string.gsub(Lchunk14, Lold2, Lnew2)
            Lchunk14, num = string.gsub(Lchunk14, Lmid2, Lold2)
            Lresult = reaper.SetTrackStateChunk(Lstrack, Lchunk14, false) 
        else
            Lschunk15, Lnum = string.gsub(Lschunk, Lold2, Lnew2, 1)
            Lresult = reaper.SetTrackStateChunk(Lstrack, Lschunk15, false) 
            Ltchunk16, Lnum = string.gsub(Ltchunk, Lnew2, Lold2, 1)
            Lresult = reaper.SetTrackStateChunk(Lttrack, Ltchunk16, false) 
        end
    end

    get_maps = 2 
    move_map_stage = 1

end -- of function


-- -------------------------------------------------------
function display_tracks_panel(Pfirst_track, Pmixer_Y0)
-- -------------------------------------------------------
local  LX0, LX, LW, LXGAP, LXMID, Lfactor, Lmixer_Y0,
       Lnumtracks, Lcols
local  Lheight, Lborder_Y1

    LX0   = KNOB_X0;    LW = KNOB_W;         LH = KNOB_H; 
    LXGAP = KNOB_XGAP;  LXMID = KNOB_XMID
    Lfactor = 2

    if op_mode == MIXER then
        Lmixer_Y0 = TOP_CONTROLS_Y + row_height[1] + row_height[2] + row_height[3]
    else -- op_mode == INSTR
        Lmixer_Y0 = TOP_CONTROLS_Y + row_height[1] + row_height[2] + row_height[3]
    end

    Lnumtracks = reaper.GetNumTracks()
    Lcols = math.min(COLUMNS,Lnumtracks - Pfirst_track +1)
    for column = 1, Lcols do
        if op_mode == MIXER then     display_instr_track(Pfirst_track, column)
        elseif op_mode == INSTR then display_instr_track(Pfirst_track, column)
        end
    end
    display_master_track()

-- ... and the border
    LX = GUI_W -14
    if op_mode == MIXER then Lborder_Y1 = Lmixer_Y0 +95 - row_height[3] *2
    else                     Lborder_Y1 = Lmixer_Y0 +95 - row_height[3] *2
    end
    set_colour(GREY_7); gfx.a = 0.70
    gfx.roundrect(5, Lmixer_Y0,   LX,    Lborder_Y1,    10, 0)
    gfx.roundrect(6, Lmixer_Y0+1, LX -2, Lborder_Y1 -2, 10, 0)

    gfx.a = 1.00
    gfx.setfont(1)    

end -- of function


-- END of lIBRARY
-- =======================================================


-- -------------------------------------------------------
function get_updated_param_values ()
-- -------------------------------------------------------
local row, column, kidx, pidx, 
      Ltr_name, LFX, Lpar, Lvalue, Ltr_num, LFX_idx, Lparnum, Lformval, 
      Lmin, Lmax, Ltrack

    gfx.dest = OFF_SCREEN_BUFFER
    for row = 1, ROWS do
        for column = 1, COLUMNS do
            kidx = (row -1) * COLUMNS + (column -1) + (sel_bank -1) * ROWS*COLUMNS
            if op_mode == MIXER and sel_bank == 4 then 
                kidx = (row -1) * COLUMNS + (column -1) + (sel_bank -1) * (COLUMNS * 3) 
            end
            pidx = kidx * MAP_ELEMENTS +1 

-- .... get parameter data
            Ltr_name = maps[pidx +0]
            if Ltr_name ~= " " then
                Ltr_num  = maps[pidx +4]   
                LFX_idx  = maps[pidx +5]
                Lparnum  = maps[pidx +6]

-- .... update values in maps[]
                Ltrack = reaper.GetTrack(0,Ltr_num)
                Lvalue, Lmin, Lmax = reaper.TrackFX_GetParam(Ltrack, LFX_idx, Lparnum)
                if Lvalue / (Lmax - Lmin) ~= maps[pidx +3] then
                    maps[pidx +3] = Lvalue / (Lmax - Lmin)
                    _, Lformval = reaper.TrackFX_GetFormattedParamValue(Ltrack, LFX_idx,  Lparnum, "")
                    maps[pidx +7] = Lformval

-- .... update the parameter value
                    LXrow = (math.floor((kidx)/COLUMNS) % 3) +1
                    if     ROW_TYPE[LXrow] == "K"  then draw_updated_param_knob(kidx, 1) 
                    elseif ROW_TYPE[LXrow] == "P"  then draw_updated_param_knob(kidx, 2) 
                    elseif ROW_TYPE[LXrow] == "B"  then draw_updated_param_box(kidx) 
                    end 

                end -- of updating the maps() data
            end     -- of processing the named control
                            
        end -- of a row
    end     -- of all rows
    gfx.dest = MAIN_WINDOW; -- switch back to the main window

end -- of function


-- -------------------------------------------------------
function get_updated_mixer_values ()
-- -------------------------------------------------------
local Lrow, Lcolumn, kidx, pidx, Ltridx, Lcols,
      Ltr_name, LFX, Lpar, Lvalue, Ltr_num, LFX_idx, Lparnum, Lformval,
      Lmin, Lmax, Ltrack,
      Lseltrack, Lnumtracks, Lvolume, Lpan, Lmute, Lsolo, Lrecarm

    gfx.dest = OFF_SCREEN_BUFFER

-- .... get the track data
    Lseltrack = reaper.GetLastTouchedTrack()
    Lnumtracks = reaper.GetNumTracks()
   
    Lcols = math.min(COLUMNS, Lnumtracks - first_mixer_track +1)
    for Lcolumn = 1, Lcols do
        Ltridx           = (first_mixer_track -1) + (Lcolumn-1)
        Ltrack           = reaper.GetTrack(0,Ltridx)
        _, Lvolume, Lpan = reaper.GetTrackUIVolPan(Ltrack)
        _, Lmute         = reaper.GetTrackUIMute(Ltrack)
        Lsolo            = reaper.GetMediaTrackInfo_Value(Ltrack, "I_SOLO")
        Lrecarm          = reaper.GetMediaTrackInfo_Value(Ltrack, "I_RECARM")

        pidx = (Lcolumn-1) * TRACK_ELEMENTS +1

--[[--
        if Lmute   ~= track_states[pidx + 0]
        or Lsolo   ~= track_states[pidx + 1]
        or Lrecarm ~= track_states[pidx + 2]
        or Lvolume ~= track_states[pidx + 3]
        or Lpan    ~= track_states[pidx + 4] then
--]]--
            if op_mode == MIXER then 
                display_instr_track(first_mixer_track, Lcolumn)
            else
                display_instr_track(first_mixer_track, Lcolumn)
            end
            track_states[pidx + 0] = Lmute
            track_states[pidx + 1] = Lsolo
            track_states[pidx + 2] = Lrecarm
            track_states[pidx + 3] = Lvolume
            track_states[pidx + 4] = Lpan
--        end

    end -- of the displayed tracks

-- .... and the Master track
    Ltrack = reaper.GetMasterTrack(0)
    _, Lvolume, Lpan = reaper.GetTrackUIVolPan(Ltrack)
    if Lvolume ~= track_states[COLUMNS * TRACK_ELEMENTS +1 +3] then
        display_master_track()
        track_states[COLUMNS * TRACK_ELEMENTS +1 +3] = Lvolume
    end

-- -----------------------------------------
-- .... display the << and >>, to change the bank of tracks
-- -----------------------------------------
    if op_mode ~= SYNTH then
        gfx.setfont(3); set_colour(ORANGE)
        if op_mode == MIXER then
            gfx.x = 8+10;
            gfx.y = MIXER_Y0 + 90 +160 +24 -35
        else -- op_mode == INSTR
            gfx.x = 8+10;
            gfx.y = MIXER_Y0 + 90 +160 +24 -35
        end
        if first_mixer_track > 1 then gfx.printf("<<") end
        gfx.x = NEXT_OFFSET
        if (first_mixer_track +COLUMNS) < (Lnumtracks +1) then gfx.printf(">>") end
        gfx.setfont(1)
    end 

    gfx.dest = MAIN_WINDOW; -- switch back to the main window 
   
end -- of function



-- -------------------------------------------------------
function display_mixer_track (Pfirst_track, Pcolumn)
-- -------------------------------------------------------
local  LX0, LY0, LX, LY, LW, LH, LXGAP, LYGAP, LXMID, Lfactor, Lmixer_Y0, Ldelta_panY,
       Ltrack, Lvolume, Lpan, Ltr_name, Lmute, Lsolo, Lrecarm,
       Lnumtracks, Lr, Lg, Lb, LpanX, Lcols, Lcolumn,
       Lseltrack, Lfx_count, Ltridx, LtracknumberFX, LselectFX, Lparamnumber,
       Lbg_height, Lfg_height, Ldb, pidx

    LX0   = KNOB_X0;    LY0   = KNOB_Y0;    LW = KNOB_W;         LH = KNOB_H; 
    LXGAP = KNOB_XGAP;  LYGAP = KNOB_YGAP;  LXMID = KNOB_XMID
    Lfactor = 2
    Ltridx = Pfirst_track - 1 + Pcolumn -1

-- .... get the track data 
    Ltrack           = reaper.GetTrack(0,Ltridx)
    _, Lvolume, Lpan = reaper.GetTrackUIVolPan(Ltrack)
    _, Ltr_name      = reaper.GetTrackName(Ltrack, " ")
    _, Lmute         = reaper.GetTrackUIMute(Ltrack)
    Lsolo            = reaper.GetMediaTrackInfo_Value(Ltrack, "I_SOLO")
    Lrecarm          = reaper.GetMediaTrackInfo_Value(Ltrack, "I_RECARM")
-- ..................................
    pidx = (Pcolumn-1) * TRACK_ELEMENTS +1
    LX, LY = position_the_control(ROWS *COLUMNS * sel_bank + Pcolumn -1)
-- NB 
LY =370
    LX = LX - KNOB_W/2
    LY = LY + 20

-- .... get the track colour, if any
    if reaper.GetTrackColor(Ltrack) > 0 then
        Lr,Lg,Lb = reaper.ColorFromNative(reaper.GetTrackColor(Ltrack))
    else
       set_colour(GREY_7)
       Lr = gfx.r *256; Lg = gfx.g *256; Lb = gfx.b *256
    end

-- .... clear the buffer (WIP)
    set_colour(BG); gfx.a =1.00
    gfx.rect(LX -KNOB_W, LY+20, KNOB_W *3, 5) 

-- .... display the track name
    set_colour(GREY_3)
    gfx.rect(LX -KNOB_W, LY, KNOB_W *3, 20) 
    gfx.r = Lr/256;   gfx.g = Lg/256;  gfx.b = Lb/256
    if is_dark_colour() then set_colour(ORANGE) end
    gfx.x = LX +KNOB_W/2; gfx.y = LY +2-- KNOB_W *2 +46;
    print_central(LX + KNOB_W/2, string.sub(Ltr_name,1,LINE_W))
    Ldelta_panY = KNOB_W *3


------------------------------------------
-- .... draw the pan knob
ZZ_PAN = "NEW"
    if Lpan ~= track_states[pidx + 4] then 
        set_colour(GREY_3)
        gfx.rect(LX -KNOB_W, LY + 25, KNOB_W *3, KNOB_W *3) 
        gfx.r = Lr/256;   gfx.g = Lg/256;  gfx.b = Lb/256
        if is_dark_colour() then set_colour(ORANGE) end
        gfx.x = LX +KNOB_W/2; gfx.y = LY + KNOB_W + 25 +10
        draw_knob21 (KNOB_W,  Lpan/2 +0.50, 2, 4) -- Pradius, Protator, Palign (centre), Poptions
 
        if show_formatted == YES then 
            if Lpan == 0 then    LpanX = "Centre"
            elseif Lpan > 0 then LpanX = string.format("%2.0f%% R", Lpan * 100)
            else                 LpanX = string.format("%2.0f%% L", Lpan * 100)
            end
            gfx.x = LX + KNOB_W/2 - string.len(LpanX) /2 * CHAR_W; 
            set_colour(WHITE); gfx.a = 0.75
            gfx.printf("%s", LpanX)
            gfx.a = 1.00
        end
        set_colour(GREY_7)
        gfx.y = gfx.y +12
        print_central(LX + KNOB_W/2, "Pan")
    else
        ZZ_PAN = "same" 
    end

-- .... the Solo / Mute button (used for FX select in INSTR mde)
ZZ_SM ="NEW"
    if Lmute ~= track_states[pidx + 0] 
    or Lsolo ~= track_states[pidx + 1] then 
        set_colour(GREY_3)
        gfx.x = LX+1; gfx.y = LY + Ldelta_panY +30-- gfx.y +30
        gfx.rect(LX -KNOB_W, gfx.y -5, KNOB_W *3, KNOB_W) 

        if Lsolo  ~=0 then          draw_button(ORANGE, 0.80, BLACK,  1.00, "Solo")
        elseif Lmute == true then   draw_button(RED,    0.70, GREY_7, 1.00, "Mute")
        else                        draw_button(GREY_6, 0.70, BLACK,  1.00, " ")
        end
    else
        ZZ_SM = "SAME"
    end

ZZ_REC = "NEW"
-- .... the RecArm button (used for track select in INSTR mode)
    if Lrecarm ~= track_states[pidx + 2] then
        set_colour(GREY_3)
        gfx.rect(LX -KNOB_W, LY + Ldelta_panY +30 +40 -10, KNOB_W *3, KNOB_W +10)
        gfx.x = LX+1+1; gfx.y = LY + Ldelta_panY +30 +40 --gfx.y +35+15
        gfx.a = 0.70

        if Lrecarm  ~=0 then draw_button(RED,    0.70, GREY_7, 1.00, "Rec")
        else                 draw_button(GREY_6, 0.70, GREY_7, 1.00, "   ")
        end
    else
        ZZ_REC = "SAME RA"
    end

ZZ_VOL ="NEW"
-- .... the Volume fader
    if Lvolume ~= track_states[pidx + 3] then
        set_colour(GREY_3)
        gfx.rect(LX -KNOB_W, LY + Ldelta_panY +30 +40 +30, KNOB_W *3, FADER_H + 30) 
        gfx.r = Lr/256;   gfx.g = Lg/256;  gfx.b = Lb/256
        gfx.x = LX;  gfx.y = LY + Ldelta_panY +30 +40 +30 --gfx.y +30
        gfx.r = Lr/256;   gfx.g = Lg/256;  gfx.b = Lb/256
        draw_slider23(Lvolume, FADER_H +12)

-- .... the signed formatted value
        set_colour(BG)
        gfx.rect(LX -KNOB_W, gfx.y, KNOB_W *3, 15)
        if show_formatted == YES then 
            Ldb = 20 * math.log(Lvolume /1, 10)
            if Ldb > 0 then
                set_colour(ORANGE);  gfx.a = 0.75
                print_central(LX + KNOB_W/2, string.format("+%4.2f dB", Ldb))
            else
                set_colour(WHITE);  gfx.a = 0.75
                print_central(LX + KNOB_W/2, string.format("%4.2f dB", Ldb))    
            end
        end

    else
        ZZ_VOL = "SAME V"
    end
    gfx.a = 1.00

end -- of function


-- -------------------------------------------------------
function display_instr_track(Pfirst_track, Pcolumn)
-- -------------------------------------------------------
local  LX0, LY0, LX, LY, LW, LH, LXGAP, LYGAP, LXMID, Lfactor, Ldelta_panY,
       Ltrack, Lvolume, Lpan, Ltr_name, Lmute, Lsolo, Lrecarm,
       Lnumtracks, Lr, Lg, Lb, LpanX, Lcols, Lcolumn,
       Lseltrack, Lfx_count, Ltridx, LtracknumberFX, LselectFX, Lparamnumber,
       Lbg_height, Lfg_height, Ldb, pidx

    LX0   = KNOB_X0;    LY0   = KNOB_Y0;    LW = KNOB_W;         LH = KNOB_H; 
    LXGAP = KNOB_XGAP;  LYGAP = KNOB_YGAP;  LXMID = KNOB_XMID
    Lfactor = 2
    Ltridx = Pfirst_track - 1 + Pcolumn -1

-- .... get the track data
    Ltrack = reaper.GetTrack(0,Ltridx)
    _, Lvolume, Lpan = reaper.GetTrackUIVolPan(Ltrack)
    _, Ltr_name = reaper.GetTrackName(Ltrack, " ")
    _, Lmute = reaper.GetTrackUIMute(Ltrack)
    Lsolo = reaper.GetMediaTrackInfo_Value(Ltrack, "I_SOLO")
    Lrecarm = reaper.GetMediaTrackInfo_Value(Ltrack, "I_RECARM")
      
    Lseltrack = reaper.GetLastTouchedTrack()
    Ltracknumber = reaper.GetMediaTrackInfo_Value(Lseltrack, "IP_TRACKNUMBER")
    _, LtracknumberFX, LselectFX, Lparamnumber = reaper.GetLastTouchedFX()

-- ..................................
    pidx = (Pcolumn-1) * TRACK_ELEMENTS +1
    LX, LY = position_the_control(ROWS *COLUMNS * sel_bank + Pcolumn -1)

-- 0401 +
LY = 530

    LX = LX - KNOB_W/2
    LY = LY +20
    Ldelta_panY = 0

------------------------------------------
-- .... the Solo / Mute button (used for FX GUI opened in INSTR mde)

    set_colour(GREY_3); gfx.a = 1.00
    gfx.x = LX+1; gfx.y = LY + Ldelta_panY +30 -20-5-- gfx.y +30

    if reaper.TrackFX_GetOpen(Lseltrack, Pcolumn-1) then
        draw_button(ORANGE, 0.80, BLACK,  1.00, "FX")
    else
        draw_button(GREY_6, 0.70, BLACK,  1.00, "  ") 
    end
    gfx.a = 1.00

-- .... display FX names of FX on selected track here, clear first
    set_colour (BG);  gfx.rect(LX - KNOB_W, LY +24, KNOB_W *3,15)

    set_colour(GREY_7)
    Lfx_count = reaper.TrackFX_GetCount(Lseltrack)
    if Pcolumn <= Lfx_count then 
        gfx.x = LX+1; gfx.y = gfx.y +14+6;
        local _, fx_name = reaper.TrackFX_GetFXName(Lseltrack, Pcolumn -1, "");
        local fx_name2 = fx_name:match(" (.*) %(")
        if fx_name2 == nil then fx_name2 = fx_name:match("/(.*)", -20) end
-- ALT WIP gfx.a =1.00; set_instance_colour (LselectT, Pcolumn-1)
        print_central(gfx.x + KNOB_W/2, string.sub(fx_name2, 1,18))
        gfx.y = gfx.y -14-6
    end

------------------------------------------
-- .... the RecArm button (used for track select in INSTR mode)

    set_colour(GREY_3)
    gfx.x = LX+1+1; gfx.y = LY + Ldelta_panY +30-20 +40 --gfx.y +35+15
    gfx.a = 0.70
    if Pcolumn == (Ltracknumber - Pfirst_track +1) then
        draw_button(RED,    0.70, GREY_7, 1.00, "Track")
    else
        draw_button(GREY_6, 0.70, GREY_7, 1.00, "   ")
    end
    gfx.a = 1.00

-------------------------------------------- 
-- .... get the track colour, if any
    if reaper.GetTrackColor(Ltrack) > 0 then
        Lr,Lg,Lb = reaper.ColorFromNative(reaper.GetTrackColor(Ltrack))
        gfx.r = Lr/256;   gfx.g = Lg/256;  gfx.b = Lb/256
    else
       set_colour(GREY_7)
       Lr = gfx.r *256; Lg = gfx.g *256; Lb = gfx.b *256
    end
 
    LY = LY +100-15

-- .... display the track name
    set_colour(GREY_3)
    gfx.rect(LX -KNOB_W, LY, KNOB_W *3, 20) 

    gfx.r = Lr/256;   gfx.g = Lg/256;  gfx.b = Lb/256
    if is_dark_colour() then set_colour(ORANGE) end
    
    gfx.x = LX +KNOB_W/2; gfx.y = LY +2-- KNOB_W *2 +46;
    print_central(LX + KNOB_W/2, string.sub(Ltr_name,1,LINE_W))


ZZ_VOL ="NEW"
-- .... the track Volume fader

    if Lvolume ~= track_states[pidx + 3] then
        set_colour(GREY_3)
        gfx.rect(LX -KNOB_W, LY + Ldelta_panY +25-7+15-6, KNOB_W *3, 187-3-2 -40) 

        gfx.x = LX;  gfx.y = LY + Ldelta_panY +20-7+15-6 --gfx.y +30
        gfx.r = Lr/256;   gfx.g = Lg/256;  gfx.b = Lb/256
        draw_slider23(Lvolume, FADER_H - 50)

-- .... the signed formatted value
    set_colour(BG)
    gfx.rect(LX -KNOB_W, gfx.y, KNOB_W *3, 15) 

    if show_formatted == YES then 
        Ldb = 20 * math.log(Lvolume /1, 10)
        if Ldb > 0 then
            set_colour(ORANGE);  gfx.a = 0.75
            print_central(LX + KNOB_W/2, string.format("+%4.2f dB", Ldb))
        else
            set_colour(WHITE);  gfx.a = 0.75
            print_central(LX + KNOB_W/2, string.format("%4.2f dB", Ldb))    
        end
    end

else
ZZ_VOL = "SAME V"
end
    gfx.a = 1.00

end -- of function


-- -------------------------------------------------------
function display_master_track()
-- -------------------------------------------------------
local  LX0, LY0, LX, LY, LW, LH, LXGAP, LYGAP, LXMID, Lfactor, Lmixer_Y0, Lheight,
       Ltrack, Lvolume, Lpan, Ltr_name, Lmute, Lsolo, Lrecarm,
       Lnumtracks, Lr, Lg, Lb, LpanX, Lcols, Lcolumn,
       Lseltrack, Lfx_count,
       Lbg_height, Lfg_height, Ldb

    LX0   = KNOB_X0;    LY0   = KNOB_Y0;    LW = KNOB_W;         LH = KNOB_H; 
    LXGAP = KNOB_XGAP;  LYGAP = KNOB_YGAP;  LXMID = KNOB_XMID;
    Lfactor = 2

    LX, LY = position_the_control(ROWS *COLUMNS  * sel_bank + 8-1)

-- 0401 +
--if op_mode == MIXER then LY =370 else LY = 530 end
LY=530
    LX = LX + STEP_X - KNOB_W/2
    LY = LY + 20

    if op_mode == MIXER then Lheight = FADER_H + 55 -20
    else -- op_mode == INSTR
                             Lheight = FADER_H + 55 -20
    end

-- .. blank out the area first
    set_colour(BG)
    gfx.rect(LX -KNOB_W, LY, KNOB_W *3, 20) 
    gfx.x = LX + KNOB_W/2
    gfx.y = LY
    set_colour(GREY_7)
    print_central(gfx.x, "MASTER")

    Ltrack = reaper.GetMasterTrack(0)
    _, Lvolume, Lpan = reaper.GetTrackUIVolPan(Ltrack)
    
    gfx.x = LX; gfx.y = LY +20
    draw_slider23(Lvolume, Lheight)

-- .... the signed formatted value
    set_colour(BG)
    gfx.rect(LX -KNOB_W, gfx.y, KNOB_W *3, 15)
    if show_formatted == YES then 
        Ldb = 20 * math.log(Lvolume /1, 10)
        if Ldb > 0 then
            set_colour(ORANGE);  gfx.a = 0.75
            print_central(LX + KNOB_W/2, string.format("+%4.2f dB", Ldb))
        else
            set_colour(WHITE);  gfx.a = 0.75
            print_central(LX + KNOB_W/2, string.format("%4.2f dB", Ldb))    
        end
    end

end -- of function


-- -------------------------------------------------------
function store_param_mapping (Pnum, PTrname, PFXname, Pparname, PTridx, PFX, Pparnum)
-- -------------------------------------------------------
local Lidx = (Pnum -1) * MAP_ELEMENTS +1  -- pointer into maps[], starts at 1

    if maps[Lidx +1] ~= " " and 
      (PTridx ~= maps[Lidx +4] or PFX ~= maps[Lidx +5] or Pparnum ~= maps[Lidx +6]) then 
        maps[Lidx +0] = "Multiple (last)"
        maps[Lidx +1] = "x " .. PFXname
        maps[Lidx +2] = "x " .. Pparname
--        maps[Lidx +3] = Pvalue
        maps[Lidx +4] = PTridx
        maps[Lidx +5] = PFX
        maps[Lidx +6] = Pparnum
--        maps[Lidx +7] = Pformval
--        maps[Lidx +8] = Pchannel
    else
        maps[Lidx +0] = PTrname
        maps[Lidx +1] = PFXname
        maps[Lidx +2] = Pparname
--        maps[Lidx +3] = Pvalue
        maps[Lidx +4] = PTridx
        maps[Lidx +5] = PFX
        maps[Lidx +6] = Pparnum
--        maps[Lidx +7] = Pformval
--        maps[Lidx +8] = Pchannel
    end
    used_banks[math.floor((Pnum-1) / (COLUMNS * 3) +1)] = YES
end -- of function


-- -------------------------------------------------------
function get_parm_learns()
-- -------------------------------------------------------
local fx_chunk, fx_chunk_t, fx_count, cut_pos, cut_pos_end, out_t,
      track, trackname, Ltrackidx, seltrackidx, fxnumber, fx_name, chunk, flagsOut,
      noof_tracks, knob_num, par_name, val, max, minf

    if get_maps > 1 then
        for i = 1, MAP_ELEMENTS * (COLUMNS * ROWS)  * SETS do maps[i] = " " end 
        for i = 1, SETS do used_banks[i] = 0 end
        for i = 1, TRACK_ELEMENTS * (COLUMNS +1) do track_states[i] = " " end
    end

    reaper.ClearConsole()
    noof_tracks = reaper.GetNumTracks()

    for seltrackidx = 0, selected_tracks -1 do
        track = reaper.GetSelectedTrack(0, seltrackidx)
        fx_count = reaper.TrackFX_GetCount(track)
        for fxnumber = 0, fx_count -1  do
            if track ~= nil and fxnumber ~= nil then 
                _, trackname = reaper.GetSetMediaTrackInfo_String(track, 'P_NAME', '', false)
                local _, fx_name = reaper.TrackFX_GetFXName(track, fxnumber, ""); 

-- .... deal with JS FX names
local fx_name2 = fx_name:match(" (.*) %(")
if fx_name2 == nil then fx_name2 = fx_name:match("/(.*)", -20) end
fx_name = fx_name2
-- ....

-- .... split track chunk
                _, chunk = reaper.GetTrackStateChunk(track, "")

                cut_pos = {}
                fx_chunk = {}
                for i = 1, fx_count do -- was countfx (4 lines above)
                    cut_pos[i] = string.find(chunk, 'BYPASS',cut_pos_end)
                    cut_pos_end = string.find(chunk, 'BYPASS',cut_pos[i]+20)
                    if cut_pos_end == nil then
                        fx_chunk[i] = string.sub(chunk, cut_pos[i])
                    else
                        fx_chunk[i] = string.sub(chunk, cut_pos[i], cut_pos_end-1)
                    end
                end

-- .... split fx chunk, interesting syntax is e.g. "PARMLEARN 4 0 1 /midimix/knob/14"
                fx_chunk_t={}
                for line in fx_chunk[fxnumber+1]:gmatch("[^\r\n]+") do
                    table.insert(fx_chunk_t, line)
                end

                for i = 1, #fx_chunk_t do
                    if fx_chunk_t[i]:find('PARMLEARN') ~= nil then 
                        out_t = {}
                        for word in fx_chunk_t[i]:gsub('PARMLEARN ', ''):gmatch('[^%s]+') do
                            if tonumber(word) ~= nil then word = tonumber(word)
                            else                          word = word:gsub(' ', '')
                            end
                            table.insert(out_t, word)
                        end  

-- .... deal with Reaper FX Bypass and wet parameters
local colon =  string.find(out_t[1], ":")
if colon == nil then
    _, par_name = reaper.TrackFX_GetParamName(track, fxnumber, out_t[1], '')            
else
    par_name = string.sub(out_t[1],colon+1)
    out_t[1] = tonumber(string.sub(out_t[1],1,colon-1))
end
-- ....
                        if out_t[4] ~= nil then
                            Ltrackidx = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") -1
-- check for two alternatice patterns
                            CSknob_num=tonumber(out_t[4]:match(".*"..PARM_ID[1].."(%d*)"))
                            if CSknob_num ==nil then
                                CSknob_num = tonumber(out_t[4]:match(".*"..PARM_ID[2].."(%d*)"))
                            end
                            if CSknob_num ~=nil then
                                store_param_mapping(CSknob_num, trackname, fx_name, par_name, Ltrackidx, fxnumber, out_t[1])
                            end    
                       end        -- if a fourth 'word' was found
                    end           -- if 'PARMLEARN' was found
                end               -- loop chunk
            end                   -- if track ~= nil 
        end                       -- of FX looping for the track
    end                           -- track looping
    store_count = store_count +1

end -- of function


---------------------------------------
function looper()
---------------------------------------
local Lparm_rows

    if move_map_stage == 3 then move_map(mm_sknob, mm_tknob) end

    selected_tracks = reaper.CountSelectedTracks(0)

    first_selected_track =  reaper.GetSelectedTrack(0,0)
    if selected_tracks == 1 then XXX = first_selected_track else XXX = "NONE" end
    if selected_tracks      ~= selected_tracks_prev 
    or first_selected_track ~= first_selected_track_prev then
        selected_tracks_prev      = selected_tracks
        first_selected_track_prev = first_selected_track
        get_maps =2 -- refresh completely
    end

    if get_maps > 0 then
        get_parm_learns()
        get_maps = 0
        gfx.dest = OFF_SCREEN_BUFFER
        gfx.setimgdim(OFF_SCREEN_BUFFER, 0,0);
        gfx.setimgdim(OFF_SCREEN_BUFFER, 2000, 1000)--gfx.w,gfx.h)  
        set_colour(BG);
        gfx.rect(0,0, 2000,1000) 
        gfx.y = TOP_CONTROLS_Y -- top position for the controls
        gfx.setfont(1)

if debug == 1 then  set_colour(ORANGE); gfx.x =10; gfx.printf("^^ CONTROLS TOP (%s)", TOP_CONTROLS_Y) end

        if op_mode == MIXER then     Lparm_rows = 3
        elseif op_mode == INSTR then Lparm_rows = 3
        else                         Lparm_rows = ROWS
        end

-- .... display the parameter controls
        for row = 1, Lparm_rows do
            if     ROW_TYPE[row] == "K"  then draw_a_row_of_knobs(row, 1)
            elseif ROW_TYPE[row] == "P"  then draw_a_row_of_knobs(row, 2)
            elseif ROW_TYPE[row] == "B"  then draw_a_row_of_boxes(row)
            end
        end

        display_tracks_panel(first_mixer_track, MIXER_Y0) -- end
    end -- of if get_maps > 0

----------------------------------------
    draw_top_buttons()

    if selected_tracks == 0 then
        set_colour(YELLOW)
        gfx.setfont(2)
        gfx.x = 50; gfx.y = 150
        gfx.printf("No tracks are selected")
        gfx.setfont(1)
    end

    get_updated_param_values() 
    get_updated_mixer_values()

    gfx.a = 1.00;
    gfx.dest = MAIN_WINDOW
    gfx.blit(OFF_SCREEN_BUFFER, 1, 0,                                            -- source, scale, rotation
             0, TOP_CONTROLS_Y -10, gfx.w, gfx.h - (TOP_CONTROLS_Y -10),         -- srcx, srcy, srcw, srch,
             0, TOP_CONTROLS_Y -10, gfx.w, gfx.h - (TOP_CONTROLS_Y -10), 0, 0)   -- destx, desty, destw, desth, rotxoffs, rotyoffs

    if help_display  == YES then display_help(help_page) end
    if click_stage   == YES and gfx.mouse_cap > 0 then 
        detect_clicks()         --  
        detect_param_clicks() -- on the parameter controls
    end

    if gfx.mouse_cap == 0 or gfx.mouse_cap == 16 then 
        click_stage =1; 
        set_clicked = 0; mode_clicked =0; colour_clicked =0; NNadd_clicked =0; help_clicked =0
    end

    if gfx.getchar() ~=-1 then reaper.defer(looper) end --defer
    gfx.update();

end -- of function


------------------------------------------------------------------------------
-- START HERE

--NN 0325 package.path=reaper.GetResourcePath().."/Scripts/DarkStar/libraries/?.lua;"..package.path
--NN 0325 require("CS_base_DS")

    local script_title = "Control Surface Map"
    reaper.Undo_BeginBlock()
    init() 
    looper()  
    reaper.Undo_EndBlock(script_title,0)

-- END --

