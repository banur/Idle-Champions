#SingleInstance force
; /////////////////////////////////////////////////////////////////////////////////////////////////
; //   >>>> USER WARNING:  Do NOT edit the header, it makes helping you in Discord HARDER! <<<<
; // Updates installed after the date below may result in the pointer addresses not being valid.
; // Epic Games IC Version:  v0.403
; /////////////////////////////////////////////////////////////////////////////////////////////////
global ScriptDate    := "2021/09/24"   ; USER: Cut and paste these in Discord when asking for help
global ScriptVersion := "2021.09.24.1" ; USER: Cut and paste these in Discord when asking for help
; /////////////////////////////////////////////////////////////////////////////////////////////////
; // Modron Automation Gem Farming Script for Epic Games Store
; // Original by mikebaldi1980 - steam focused
; // Updated  by CantRow for Epic Games Store Compatibility
; // Put together with the help from many different people. thanks for all the help.
; // Thanks to Ferron7 for incorporating updates from Steam branch and updating memory offsets.
; /////////////////////////////////////////////////////////////////////////////////////////////////
; // Future Considerations / Areas of Interest
; // -improve encapsulation and code reuse
; // -
; /////////////////////////////////////////////////////////////////////////////////////////////////
; // Changes
; // 20210918 1 - modified file header
; //          2 - removed Core Target Area read and logic-- both pointers were null, discussed 
; //              with Mike and #scripting.  Not needed.  Don't Briv stack at your core reset area
; // 20210919 1 - started reworking the Read First tab
; //            - added buttons and code to launch stuff off the resources tab
; // 20210924 1 - Initial fork update
; // 20210926 1 - changed times to hh:mm:ss;
; //              replaced CD leveling with combobox;
; //              added first time default to read first, stats otherwise;
; //              merged huan's early stacking;
; //              added status bar - needs some more fine tuning
; //
; /////////////////////////////////////////////////////////////////////////////////////////////////

SetWorkingDir, %A_ScriptDir% ; The working directory is the Script Directory, log files are there
CoordMode, Mouse, Client     ; TBD why this is important, don't change

; /////////////////////////////////////////////////////////////////////////////////////////////////
; // User settings not accessible via the GUI
; /////////////////////////////////////////////////////////////////////////////////////////////////
; // variables to consider changing if restarts are causing issues
global gOpenProcess	:= 10000	;time in milliseconds for your PC to open Idle Champions
global gGetAddress  := 5000		;time in milliseconds after Idle Champions is opened for it to load pointer base into memory
; /////////////////////////////////////////////////////////////////////////////////////////////////
; // end of user settings
; /////////////////////////////////////////////////////////////////////////////////////////////////

;class and methods for parsing JSON (User details sent back from a server call)
#include JSON.ahk

;pointer addresses and offsets
#include IC_MemoryFunctions.ahk

;server call functions and variables Included after GUI so chest tabs maybe non optimal way of doing it
#include IC_ServerCallFunctions.ahk

;https://discord.com/channels/357247482247380994/474639469916454922/888620280862355506
;ControlFocus,, ahk_id %win%
;PostMessage, 0x0100, 0xC0, 0,, ahk_id %win%
;PostMessage, 0x0101, 0xC0, 0xC0000001,, ahk_id %win%


; This array of variables are used as on/off switches for whether to level/not level the heroes in these seats
global gSeatToggle := [S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12]
; This string of variables contains the Fx Keys for "on" Champions to level
; Thanks ThePuppy for the ini code
global gFKeys :=  ; Note: This loop reads in the seat toggles from the INI, and creates the Active Levelling Keys
loop, 12   ; TODO: put in a function that can be called to re-string the actives when the user changes them live
{
	IniRead, S%A_Index%, UserSettings.ini, Section1, S%A_Index%
	if (S%A_Index%)
	{
		gFKeys = %gFKeys%{F%A_Index%}
	}
}

; // GetSettingFromINI //////////////////////////////////////////////////////////////////////////////
; // Encapsulates reading values used by the script from the stored INI file UserSettings.ini
; // NOTE: uses the only one default section Section 1, and returns the value read at the key provided
; // myKeyName - string with the name of the item in the INI file
; // myDefVal  - default value to use for this setting in case the INI entry doesn't exist
GetSettingFromINI(myKeyName, mydefVal)
{	
	IniRead, mytemp, UserSettings.ini, Section1, %myKeyName%, %myDefVal%
	return mytemp
}

; // Let's read in all of the settings stored in the file that we need:
global gStopLevZone  := GetSettingFromINI("ContinuedLeveling", 10) ;Stop levelling after this zone
global gAreaLow      := GetSettingFromINI("AreaLow", 30)           ;Farm Brivs SB stacks after this zone
global gMinStackZone := GetSettingFromINI("MinStackZone", 25)      ;Lowest zone SB stacks can be farmed on
global gSBTargetStacks := GetSettingFromINI("SBTargetStacks", 400) ;Target Haste stacks count
global gDashSleepTime := GetSettingFromINI("DashSleepTime", 6000)  ;Dash (Sandie's speed ability!) wait max time
global gDashWaitZone := GetSettingFromINI("DashWaitZone", 0)       ;Delay Dash to specific zone for consistent potion usage
global gHewUlt       := GetSettingFromINI("HewUlt", 6)             ;Hew's ult key
global gDashAfterStack := GetSettingFromINI("DashAfterStack", 0)   ;bool - Delay Dash for early stacking
global gbSpamUlts    := GetSettingFromINI("Ults", 1)               ;bool - whether to spam ults
global gbCancelAnim  := GetSettingFromINI("BrivSwap", 1)           ;bool - Briv swap-out to cancel animation
global gAvoidBosses  := GetSettingFromINI("AvoidBosses", 1)        ;bool - Briv swap-out to avoid bosses
global gCDLevelingKey:= GetSettingFromINI("CDLevelingKey", "`` (US)")         ;Click damage(CD) levelling key
global gb100xCDLev   := GetSettingFromINI("CtrlClickLeveling", 0)  ;bool - 100x with CTRL key CD levelling toggle
global gbSFRecover   := GetSettingFromINI("StackFailRecovery", 0)  ;bool - Stack fail recovery toggle  TBD what this means
global gStackFailConvRecovery := GetSettingFromINI("StackFailConvRecovery", 0)      ;Stack fail recovery toggle
global gSwapSleep := GetSettingFromINI("SwapSleep", 1500)                           ;Briv swap sleep time
global gRestartStackTime := GetSettingFromINI("RestartStackTime", 12000)            ;Restart stack sleep time
global gModronResetCheckEnabled := GetSettingFromINI("ModronResetCheckEnabled" , 0) ;Modron Reset Check
global gSBTimeMax := GetSettingFromINI("SBTimeMax", 60000)                          ;Normal SB farm max time
global gDoChests := GetSettingFromINI("DoChests", 0)                                ;Enable servecalls to open chests during stack restart
global gSCMinGemCount := GetSettingFromINI("SCMinGemCount", 0)                      ;Minimum gems to save when buying chests
global gSCBuySilvers := GetSettingFromINI("SCBuySilvers", 0)                        ;Buy silver chests when can afford this many
global gSCSilverCount := GetSettingFromINI("SCSilverCount", 0)                      ;Open silver chests when you have this many
global gSCBuyGolds := GetSettingFromINI("SCBuyGolds", 0)                            ;Buy gold chests when can afford this many
global gSCGoldCount := GetSettingFromINI("SCGoldCount", 0)                          ;Open silver chests when you have this many

;Intall locations
global strSTMpath := ""
global strEGSpath := explorer.exe "com.epicgames.launcher://apps/40cb42e38c0b4a14a1bb133eb3291572?action=launch&silent=true"
global gInstallPath := GetSettingFromINI("GameInstallPath", strEGSpath)

global gFirstTime := GetSettingFromINI("FirstTime", 1)

;variable for correctly tracking stats during a failed stack, to prevent fast/slow runs to be thrown off
global gStackFail := 0

;globals for various timers
global TimePoint       := 20000101000000                ; some arbitrary point as base reference for converting ticks into hhmmss
global gSlowRunTime    :=         
global gFastRunTime    := 22000101000000
global gRunStartTime   :=
global gTotal_RunCount := 0
global gStartTime      := 
global gPrevLevelTime  :=    
global gPrevRestart    :=
global gPrevLevel      :=
global g_ZoneTime      := 0    ; variable to hold the calculated value of the time spent in the current zone

;globals for reset tracking
global gFailedStacking := 0
global gFailedStackConv := 0
global ResetCount      := 0
;globals used for stat tracking
global gGemStart       :=
global gCoreXPStart    :=
global gGemSpentStart  :=
global gRedGemsStart   :=

global gStackCountH    :=
global gStackCountSB   :=

global gCoreTargetArea := ;global to help protect against script attempting to stack farm immediately before a modron reset

global gTestReset := 0 ;variable to test a reset function not ready for release
global gLevelKeyIndex       := 0 ;Index of the click damage leveling key
global gLevelKeyVar         := ""

global wTitle := "Zees GemFarmer Modron for EGS (" . ScriptVersion . ")"
LogFMsg("VERSION INFO: ModronGUI.ahk - " . wTitle)
LogMsg( "VERSION INFO: ModronGUI.ahk - " . wTitle)
LogMsg("VERSION INFO: IC_Memoryfunctions.ahk (" . MF_ScriptVersion . ")" )
global CustomColor := 2C2F33
Gui, MyWindow:New, +Resize, %wTitle%
Gui, MyWindow:+Resize -MaximizeBox
Gui, MyWindow:Color, 2C2F33
;Gui, Mywindow:
Gui +LastFound
;WinSet, TransColor, %CustomColor% 150
;Winset, Transparent, 150, , wTitle

FormatTime, CurrentTime, , yyyyMMdd-HH:mm:ss
FormatTime, DayTime, , ddd HH:mm:ss
PreciseTime := DayTime . "." . A_MSec

global GUITabW := 500 ; width of GUI TAb control
global GUITabT := 50  ; Y offset (ie TOP) of GUI Tab control
Gui, MyWindow:Font, cSilver s11                                         ; works for black background but not for edit boxes, added black before edit boxes
Gui, MyWindow:Add, Button, x10 y10 w100 gSave_Clicked, Save
Gui, MyWindow:Add, Button, x120 y10 w100 gRun_Clicked, Run
Gui, MyWindow:Add, Button, x230 y10 w100 gPause_Clicked, Pause
Gui, MyWindow:Add, Button, x340 y10 w100 gReload_Clicked, Reload
if (gFirstTime) ; default to stats tab once settings are saved
{
    Gui, MyWindow:Add, Tab3, x5 y%GUITabT% w%GUITabW%, Read First||Settings|Help|Stats|Debug|Resources|ZDebug
}
else
{
    Gui, MyWindow:Add, Tab3, x5 y%GUITabT% w%GUITabW%, Read First|Settings|Help|Stats||Debug|Resources|ZDebug
}

Gui, Tab, Read First
global GUITabTxtW := GUITabW - 30
global GUITabTxtT := GUITabT + 30
iGUIInstctr := 0
strInsS1 := "In Slot 1 (hotkey ""Q"") save a SPEED formation. Must include Briv and at least one familiar on the field."
strInsS2 := "In Slot 2 (hotkey ""W"") save a STACK FARMing formation." 
          . " Remove all familiars from the field, keep Briv only.  Add a healer if needed."
strInsS3 := "In Slot 3 (hotkey ""E"") save the SPEED formation (above), without Briv, Hew, Havi, or Melf." 
          . " This step may be ommitted if you will not be swapping out Briv to cancel his jump animation."
          . " (TODO: include blurb here about when you DO want this option)"
strInsS6 :=  "In Idle Champions, load into zone 1 of an adventure to farm gems (Mad Wizard is a good starting choice)."
Gui, MyWindow:Font, w400
Gui, MyWindow:Add, Text, x15 y%GUITabTxtT%, Instructions:
Gui, MyWindow:Add, Text, x15 y+3 w%GUITabTxtW%,  % ++iGUIInstctr . ".  " . strInsS1
Gui, MyWindow:Add, Text, x15 y+3 w%GUITabTxtW%,  % ++iGUIInstctr . ".  " . strInsS2
Gui, MyWindow:Add, Text, x15 y+3 w%GUITabTxtW%,  % ++iGUIInstctr . ".  " . strInsS3 
Gui, MyWindow:Add, Text, x15 y+3 w%GUITabTxtW%,  % ++iGUIInstctr . ".  " .  "Switch to Settings tab, adjust as desired. (ask for help in Discord #scripting)"
Gui, MyWindow:Add, Text, x15 y+3 w%GUITabTxtW%,  % ++iGUIInstctr . ".  " .  "Click the SAVE button to save to UserSettings.ini file in your script folder."
Gui, MyWindow:Add, Text, x15 y+3 w%GUITabTxtW%,  % ++iGUIInstctr . ".  " . strIns6
Gui, MyWindow:Add, Text, x15 y+3 w%GUITabTxtW%,  % ++iGUIInstctr . ".  " .  " Press the RUN button to start farming gems."
strNotS1  := "To adjust your settings after the run starts, first use the pause hotkey, ~(Shift `), then adjust & save settings."
strNotS4  := "Recommended SB stack level : [Modron Reset Zone] - (2 + 2*X), where X is your Briv skip level (ie 1x 2x 3x 4x)"
strNotS6  := "Script communicates directly with Idle Champions play servers to recover from a failed stacking and for when Modron resets to the World Map."
strNotS10 := "Recommended Briv swap sleep time is betweeb 1500 - 3000. If you are seeing Briv's " 
           . "landing animation then increase the the swap sleep time. If Briv is not back in the" 
           . " formation before monsters can be killed then decrease the swap sleep time."
iGUIInstctr := 0
Gui, MyWindow:Add, Text, x15 y+15, Notes:
Gui, MyWindow:Add, Text, x15 y+2 w%GUITabTxtW%, % ++iGUIInstctr . ".  " .  strNotS1
Gui, MyWindow:Add, Text, x15 y+2 w%GUITabTxtW%, % ++iGUIInstctr . ".  " .  "DON'T FORGET to unpause after saving your settings with the same pause hotkey."
Gui, MyWindow:Add, Text, x15 y+2 w%GUITabTxtW%, % ++iGUIInstctr . ".  " .  "First run is ignored for stats, in case it is a partial run."
Gui, MyWIndow:Add, Text, x15 y+2 w%GUITabTxtW%, % ++iGUIInstctr . ".  " .  strNotS4
Gui, MyWindow:Add, Text, x15 y+2 w%GUITabTxtW%, % ++iGUIInstctr . ".  " .  "Script will activate and focus the game window for manual resets as part of failed stacking."
Gui, MyWIndow:Add, Text, x15 y+2 w%GUITabTxtW%, % ++iGUIInstctr . ".  " .  strNotS6
Gui, MyWIndow:Add, Text, x15 y+2 w%GUITabTxtW%, % ++iGUIInstctr . ".  " .  "Script reads system memory."
Gui, MyWIndow:Add, Text, x15 y+2 w%GUITabTxtW%, % ++iGUIInstctr . ".  " .  "The script does not work without Shandie."
Gui, MyWIndow:Add, Text, x15 y+2 w%GUITabTxtW%, % ++iGUIInstctr . ".  " .  "Disable manual resets to recover from failed Briv stack conversions when running event free plays."
Gui, MyWIndow:Add, Text, x15 y+2 w%GUITabTxtW%, % ++iGUIInstctr . ".  " .  strNotS10
strKI2 := "Using Hew's ult throughout a run with Briv swapping can result in Havi's ult being trig" 
       . "gered instead. Consider removing Havi from formation save slot 3, in game hotkey ""E""."
strKI3 := "Conflict between Epic Games Store and IdleCombos.exe script. Close IdleCombos if Briv " 
       . "Restart Stacking as EGS will see IdleCombos as an instance of IC. "
iGUIInstctr := 0
Gui, MyWindow:Add, Text, x15 y+10, Known Issues:
Gui, MyWindow:Add, Text, x15 y+2, 1. Cannot fully interact with GUI while script is running.
Gui, MyWindow:Add, Text, x15 y+2 w%GUITabTxtW%, % ++iGUIInstctr . ".  " .  strKI2
Gui, MyWindow:Add, Text, x15 y+2 w%GUITabTxtW%, % ++iGUIInstctr . ".  " .  strKI3 

; // GUITAB: Settings /////////////////////////////////////////////////////////////////////////////
Gui, Tab, Settings
Gui, MyWindow:Add, Text, x15 y%GUITabTxtT% w%GUITabTxtW%, Champ Seats to level with F1-F12 keys:
;Gui, MyWindow:Add, Text, x15 y30 w120, Seats to level with Fkeys: ;, Background2C2F33
Loop, 12
{
    i := gSeatToggle[A_Index]               ; doesn't seem to work, i ends up empty
    ; msgbox %i%
    if (A_Index = 1)
    Gui, MyWindow:Add, Checkbox, vCheckboxSeat%A_Index% Checked%i% x15 y+5 w60, S%A_Index%
    Else if (A_Index <= 6)
    Gui, MyWindow:Add, Checkbox, vCheckboxSeat%A_Index% Checked%i% x+5 w60, S%A_Index%
    Else if (A_Index = 7)
    Gui, MyWindow:Add, Checkbox, vCheckboxSeat%A_Index% Checked%i% x15 y+5 w60, S%A_Index%
    Else
    Gui, MyWindow:Add, Checkbox, vCheckboxSeat%A_Index% Checked%i% x+5 w60, S%A_Index%
}
Gui, MyWindow:Font, cBlack s11
Gui, MyWindow:Add, Edit, vNewContinuedLeveling x15 y+10 w50 BackGround2C2F33, % gStopLevZone
Gui, MyWindow:Font, cSilver s11
Gui, MyWindow:Add, Text, x+5, Stop levelling Champs at/after this zone
Gui, MyWindow:Font, cBlack s11
Gui, MyWindow:Add, Edit, vNewgAreaLow x15 y+10 w50, % gAreaLow
Gui, MyWindow:Font, cSilver s11
Gui, MyWindow:Add, Text, x+5, Farm SB stacks AFTER this zone
Gui, MyWindow:Font, cBlack s11
Gui, MyWindow:Add, Edit, vNewgMinStackZone x15 y+10 w50, % gMinStackZone
Gui, MyWindow:Font, cSilver s11
Gui, MyWindow:Add, Text, x+5, Minimum zone Briv can farm SB stacks on
Gui, MyWindow:Font, cBlack s11
Gui, MyWindow:Add, Edit, vNewSBTargetStacks x15 y+10 w50, % gSBTargetStacks
Gui, MyWindow:Font, cSilver s11
Gui, MyWindow:Add, Text, x+5, Target Haste stacks for next run
Gui, MyWindow:Font, cBlack s11
Gui, MyWindow:Add, Edit, vNewgSBTimeMax x15 y+10 w50, % gSBTimeMax
Gui, MyWindow:Font, cSilver s11
Gui, MyWindow:Add, Text, x+5, Maximum time (ms) script will spend farming SB stacks
Gui, MyWindow:Font, cBlack s11
Gui, MyWindow:Add, Edit, vNewDashSleepTime x15 y+10 w50, % gDashSleepTime
Gui, MyWindow:Font, cSilver s11
Gui, MyWindow:Add, Text, x+5, Maximum time (ms) script will wait for Dash (0 disables)
Gui, MyWindow:Add, Checkbox, vgDashAfterStack Checked%gDashAfterStack% x15 y+10, Dash wait AFTER stacking, not at start of run
Gui, MyWindow:Font, cBlack s11
Gui, MyWindow:Add, Edit, vgDashWaitZone x15 y+7 w50, % gDashWaitZone
Gui, MyWindow:Font, cSilver s11
Gui, MyWindow:Add, Text, x+5, Delay DashWait by this many zones
Gui, MyWindow:Font, cBlack s11
Gui, MyWindow:Add, Edit, vNewHewUlt x15 y+10 w50, % gHewUlt
Gui, MyWindow:Font, cSilver s11
Gui, MyWindow:Add, Text, x+5, Hew's ultimate key (0 disables)
Gui, MyWindow:Font, cBlack s11
Gui, MyWindow:Add, Edit, vNewRestartStackTime x15 y+10 w50, % gRestartStackTime
Gui, MyWindow:Font, cSilver s11
Gui, MyWindow:Add, Text, x+5, Time (ms) client remains closed for Briv Restart Stack (0 disables)
Gui, MyWindow:Add, Checkbox, vgbSpamUlts Checked%gbSpamUlts% x15 y+12, Use ults 2-9 after intial champion leveling
Gui, MyWindow:Font, cBlack s11
Gui, MyWindow:Add, Edit, vNewSwapSleep x15 y+5 w40, % gSwapSleep
Gui, MyWindow:Font, cSilver s11
Gui, MyWindow:Add, Text, x+5, Briv swap sleep time (ms)
Gui, MyWindow:Add, Checkbox, vgAvoidBosses Checked%gAvoidBosses% x15 y+12, Swap to 'e' formation when `on boss zones
Gui, MyWindow:Add, DropDownList, vCDLevelingKeyDDL w120, `` (US)||{SC027} (Intl.)|familiar (no key)
Gui, MyWindow:Add, Text, x+5, Select leveling key for click damage
Gui, MyWindow:Add, Checkbox, vgb100xCDLev Checked%gb100xCDLev% x15 y+12, Enable ctrl (x100) leveling of click damage
Gui, MyWindow:Add, Checkbox, vgbSFRecover Checked%gbSFRecover% x15 y+5, Enable manual resets to recover from failed Briv stacking
Gui, MyWindow:Add, Checkbox, vgStackFailConvRecovery Checked%gStackFailConvRecovery% x15 y+5, Enable manual resets to recover from failed Briv stack conversion
Gui, MyWindow:Add, Checkbox, vgDoChests Checked%gDoChests% x15 y+10, Enable server calls to buy and open chests during stack restart
Gui, MyWindow:Font, cBlack s11
Gui, MyWindow:Add, Edit, vNewSCMinGemCount x15 y+7 w100, % gSCMinGemCount
Gui, MyWindow:Font, cSilver s11
Gui, MyWindow:Add, Text, x+5, Maintain this many gems when buying chests
Gui, MyWindow:Font, cBlack s11
Gui, MyWindow:Add, Edit, vNewSCBuySilvers x15 y+10 w50, % gSCBuySilvers
Gui, MyWindow:Font, cSilver s11
Gui, MyWindow:Add, Text, x+5, When there are sufficient gems, buy this many silver chests
Gui, MyWindow:Font, cBlack s11
Gui, MyWindow:Add, Edit, vNewSCSilverCount x15 y+10 w50, % gSCSilverCount
Gui, MyWindow:Font, cSilver s11
Gui, MyWindow:Add, Text, x+5, When there are this many silver chests, open them
Gui, MyWindow:Font, cBlack s11
Gui, MyWindow:Add, Edit, vNewSCBuyGolds x15 y+10 w50, % gSCBuyGolds
Gui, MyWindow:Font, cSilver s11
Gui, MyWindow:Add, Text, x+5, When there are sufficient gems, buy this many Gold chests
Gui, MyWindow:Font, cBlack s11
Gui, MyWindow:Add, Edit, vNewSCGoldCount x15 y+10 w50, % gSCGoldCount
Gui, MyWindow:Font, cSilver s11
Gui, MyWindow:Add, Text, x+5, When there are this many gold chests, open them
Gui, MyWindow:Add, Button, x15 y+20 gChangeInstallLocation_Clicked, Change Install Path
strGUI := "Default installation path may be EGS client specific. If launch fails, make a " ; too long for window
        . "shortcut through EGS and replace default path with new app launcher ID."
Gui, MyWindow:Add, Text, x+5 w%GUITabTxtW%, %strGUI%

Gui, Tab, Help
;Gui, MyWindow:Font, w700
Gui, MyWindow:Add, Button, x385 y90 w100 gHelp_Clicked, Help
Gui, MyWindow:Add, Text, x15 y%GUITabTxtT%, First, confirm your settings are saved. 
Gui, MyWindow:Add, Text, x15 y+2, 1 = true, yes, or enabled            0 = false, no, or disabled
;Gui, MyWindow:Font, w400
Gui, MyWindow:Add, GroupBox, w%GUITabTxtW% h45, Current level string to DirectInput
Gui, Mywindow:Add, Text, vgFKeysID w450 xp+8 yp+20, % gFKeys ; GET IN YOUR BOX!!!!               ;. "    Current Level string sent to DirectInput(str)"
Gui, MyWindow:Add, Text, vgStopLevZoneID x15 y+20 w%GUITabTxtW%, % gStopLevZone . "    Use Fkey leveling while below this zone"
Gui, MyWindow:Add, Text, vgAreaLowID x15 y+5 w%GUITabTxtW%, % gAreaLow . "    Farm SB stacks AFTER this zone"
Gui, MyWindow:Add, Text, x15 y+5, Minimum zone Briv can farm SB stacks on: 
Gui, MyWindow:Add, Text, vgMinStackZoneID x+2 w%GUITabTxtW%, % gMinStackZone 
Gui, MyWindow:Add, Text, x15 y+5, Target Haste stacks for next run: 
Gui, MyWindow:Add, Text, vgSBTargetStacksID x+2 w%GUITabTxtW%, % gSBTargetStacks
Gui, MyWindow:Add, Text, x15 y+5, Max time script will farm SB Stacks normally: 
Gui, MyWindow:Add, Text, vgSBTimeMaxID x+2 w%GUITabTxtW%, % gSBTimeMax
Gui, MyWindow:Add, Text, x15 y+5, Maximum time (ms) script will wait for Dash: 
Gui, MyWindow:Add, Text, vDashSleepTimeID x+2 w%GUITabTxtW%, % gDashSleepTime
Gui, MyWindow:Add, Text, x15 y+5, Hew's ultimate key: 
Gui, MyWindow:Add, Text, vgHewUltID x+2 w%GUITabTxtW%, % gHewUlt
Gui, MyWindow:Add, Text, x15 y+5, Time (ms) client remains closed for Briv Restart Stack:
Gui, MyWindow:Add, Text, vgRestartStackTimeID x+2 w%GUITabTxtW%, % gRestartStackTime
Gui, MyWindow:Add, Text, x15 y+5, Use ults 2-9 after initial champion leveling:
Gui, MyWindow:Add, Text, vgbSpamUltsID x+2 w%GUITabTxtW%, % gbSpamUlts
Gui, MyWindow:Add, Text, x15 y+5, Swap to 'e' formation to cancle Briv's jump animation:
Gui, MyWindow:Add, Text, vgbCancelAnimID x+2 w%GUITabTxtW%, % gbCancelAnim
Gui, MyWindow:Add, Text, x15 y+5, Briv swap sleep time (ms):
Gui, MyWindow:Add, Text, vgSwapSleepID x+2 w%GUITabTxtW%, % gSwapSleep
Gui, MyWindow:Add, Text, x15 y+5, Swap to 'e' formation when on boss zones:
Gui, MyWindow:Add, Text, vgAvoidBossesID x+2 w%GUITabTxtW%, % gAvoidBosses
Gui, MyWindow:Add, Text, x15 y+5, Using a familiar on click damage:
Gui, MyWindow:Add, Text, vgCDLevelingKeyID x+2 w%GUITabTxtW%, % gCDLevelingKey
Gui, MyWindow:Add, Text, x15 y+5, Enable ctrl (x100) leveling of click damage:
Gui, MyWindow:Add, Text, vgb100xCDLevID x+2 w%GUITabTxtW%, % gb100xCDLev
Gui, MyWindow:Add, Text, x15 y+5, Enable manual resets to recover from failed Briv stacking:
Gui, MyWindow:Add, Text, vgbSFRecoverID x+2 w%GUITabTxtW%, % gbSFRecover
Gui, MyWindow:Add, Text, x15 y+5, Enable manual resets to recover from failed Briv stack conversion:
Gui, MyWindow:Add, Text, vgStackFailConvRecoveryID x+2 w%GUITabTxtW%, % gStackFailConvRecovery
Gui, MyWindow:Add, Text, x15 y+5, Enable script to check for Modron reset level:
Gui, MyWindow:Add, Text, vgModronResetCheckenabledID x+2 w%GUITabTxtW%, % gModronResetCheckEnabled
Gui, MyWindow:Add, Text, x15 y+5, Enable server calls to buy and open chests during stack restart:
Gui, MyWindow:Add, Text, vgDoChestsID x+2 w%GUITabTxtW%, % gDoChests
Gui, MyWindow:Add, Text, x15 y+5, Maintain this many gems when buying chests:
Gui, MyWindow:Add, Text, vgSCMinGemCountID x+2 w%GUITabTxtW%, % gSCMinGemCount
Gui, MyWindow:Add, Text, x15 y+5, When there are sufficient gems, buy this many silver chests:
Gui, MyWindow:Add, Text, vgSCBuySilversID x+2 w%GUITabTxtW%, % gSCBuySilvers
Gui, MyWindow:Add, Text, x15 y+5, When there are this many silver chests, open them:
Gui, MyWindow:Add, Text, vgSCSilverCountID x+2 w%GUITabTxtW%, % gSCSilverCount
Gui, MyWindow:Add, Text, x15 y+5, When there are sufficient gems, buy this many gold chests:
Gui, MyWindow:Add, Text, vgSCBuyGoldsID x+2 w20w%GUITabTxtW%0, % gSCBuyGolds
Gui, MyWindow:Add, Text, x15 y+5, When there are this many gold chests, open them:
Gui, MyWindow:Add, Text, vgSCGoldCountID x+2 w%GUITabTxtW%, % gSCGoldCount
Gui, MyWindow:Add, Text, x15 y+10, Install Path:
Gui, MyWindow:Add, Edit, vICPath x15 y+10 w%GUITabTxtW%, % gInstallPath
Gui, MyWindow:Add, Text, +wrap w450 vgInstallPathID x15 y+2 w%GUITabTxtW% r3, % gInstallPath
Gui, MyWindow:Add, Text, x15 y+10 w%GUITabTxtW% r5, Still having trouble? Take note of the information on the debug tab and ask for help in the scripting channel on the official discord.

statTabTxtWidth := 
Gui, Tab, Stats
Gui, MyWindow:Font, w700
Gui, MyWindow:Add, Text, x15 y%GUITabTxtT%, Stats updated continuously (mostly):
Gui, MyWindow:Font, w400
Gui, MyWindow:Add, Text, x15 y+10 %statTabTxtWidth%, SB Stack Count: 
Gui, MyWindow:Add, Text, vgStackCountSBID x+2 w50, % gStackCountSB
;Gui, MyWindow:Add, Text, vReadSBStacksID x+2 w200,
Gui, MyWindow:Add, Text, x15 y+2 %statTabTxtWidth%, Haste Stack Count:
Gui, MyWindow:Add, Text, vgStackCountHID x+2 w50, % gStackCountH
;Gui, MyWindow:Add, Text, vReadHasteStacksID x+2 w200,
Gui, MyWindow:Add, Text, x15 y+10 %statTabTxtWidth%, Current Run Time:
Gui, MyWindow:Add, Text, vdtCurrentRunTimeID x+2 w50, 0 ;% dtCurrentRunTime
Gui, MyWindow:Add, Text, x15 y+2 %statTabTxtWidth%, Total Run Time:
Gui, MyWindow:Add, Text, vdtTotalTimeID x+2 w50, % dtTotalTime
Gui, MyWindow:Font, w700
Gui, MyWindow:Add, Text, x15 y+10, Stats updated once per run:
Gui, MyWindow:Font, w400
Gui, MyWindow:Add, Text, x15 y+10 %statTabTxtWidth%, Total Run Count:
Gui, MyWindow:Add, Text, vgTotal_RunCountID x+2 w50, % gTotal_RunCount
Gui, MyWindow:Add, Text, x15 y+2 %statTabTxtWidth%, Previous Run Time:
Gui, MyWindow:Add, Text, vgPrevRunTimeID x+2 w50, % gPrevRunTimeF
Gui, MyWindow:Add, Text, x15 y+2 %statTabTxtWidth%, Fastest Run Time:
Gui, MyWindow:Add, Text, vgFastRunTimeID x+2 w50, % gFastRunTimeF
Gui, MyWindow:Add, Text, x15 y+2 %statTabTxtWidth%, Slowest Run Time:
Gui, MyWindow:Add, Text, vgSlowRunTimeID x+2 w50, % gSlowRunTimeF
Gui, MyWindow:Add, Text, x15 y+2 %statTabTxtWidth%, Avg. Run Time:
Gui, MyWindow:Add, Text, vgAvgRunTimeID x+2 w50, % gAvgRunTimeF
Gui, MyWindow:Add, Text, x15 y+2 %statTabTxtWidth%, Fail Run Time:
Gui, MyWindow:Add, Text, vgFailRunTimeID x+2 w50, % gFailRunTimeF
Gui, MyWindow:Add, Text, x15 y+2 %statTabTxtWidth%, Fail Stack Conversion:
Gui, MyWindow:Add, Text, vgFailedStackConvID x+2 w50, % gFailedStackConv
Gui, MyWindow:Add, Text, x15 y+2 %statTabTxtWidth%, Fail Stacking:
Gui, MyWindow:Add, Text, vgFailedStackingID x+2 w50, % gFailedStacking
Gui, MyWindow:Font, cBlue w700
Gui, MyWindow:Add, Text, x15 y+10 %statTabTxtWidth%, Bosses per hour:
Gui, MyWindow:Add, Text, vgbossesPhrID x+2 w50, % gbossesPhr
Gui, MyWindow:Font, cGreen
Gui, MyWINdow:Add, Text, x15 y+10, Total Gems:
Gui, MyWindow:Add, Text, vGemsTotalID x+2 w50, % GemsTotal
Gui, MyWINdow:Add, Text, x15 y+2, Gems per hour:
Gui, MyWindow:Add, Text, vGemsPhrID x+2 w200, % GemsPhr
Gui, MyWindow:Font, cRed
Gui, MyWINdow:Add, Text, x15 y+10, Total Black Viper Red Gems:
Gui, MyWindow:Add, Text, vRedGemsTotalID x+2 w50, % RedGemsTotal
Gui, MyWINdow:Add, Text, x15 y+2, Red Gems per hour:
Gui, MyWindow:Add, Text, vRedGemsPhrID x+2 w200, % RedGemsPhr
Gui, MyWindow:Font, cSilver w400
;Gui, MyWindow:Font, w700
Gui, MyWindow:Add, Text, x15 y+10, Loop: 
Gui, MyWindow:Add, Text, vgLoopID x+2 w450, Initialized...Waiting for Run Command
global hZLoop := 0
Gui, MyWindow:Font, cSilver s9
GUITabTxtW := GUITabTxtW +20
rowCt := gDoChests ? 15 : 25
Gui, MyWindow:Add, Edit, x7 y+5 r%rowCt% w%GUITabTxtW% HwndhZLoop vZLoop ReadOnly, %gLoopID%
Gui, MyWindow:Font, w400

if (gDoChests)
{
    Gui, MyWindow:Font, w700
    Gui, MyWindow:Add, Text, x15 y+10 w300, Chest Data:
    Gui, MyWindow:Font, w400
    Gui, MyWindow:Add, Text, x15 y+5, Starting Gems Spent: 
    Gui, MyWindow:Add, Text, vgSCRedRubiesSpentStartID x+2 w200,
    Gui, MyWindow:Add, Text, x15 y+5, Starting Silvers Opened: 
    Gui, MyWindow:Add, Text, vgSCSilversOpenedStartID x+2 w200,
    Gui, MyWindow:Add, Text, x15 y+5, Starting Golds Opened:
    Gui, MyWindow:Add, Text, vgSCGoldsOpenedStartID x+2 w200,    
    Gui, MyWindow:Add, Text, x15 y+5, Silvers Opened: 
    Gui, MyWindow:Add, Text, vgSCSilversOpenedID x+2 w200,
    Gui, MyWindow:Add, Text, x15 y+5, Golds Opened: 
    Gui, MyWindow:Add, Text, vgSCGoldsOpenedID x+2 w200,
    Gui, MyWindow:Add, Text, x15 y+5, Gems Spent: 
    Gui, MyWindow:Add, Text, vGemsSpentID x+2 w200,
}


Gui, Tab, Debug
Gui, MyWindow:Font, cSilver s11 ;
Gui, MyWindow:Font, w700
;Gui, MyWindow:Add, Text, x15 y35, Timers:
Gui, MyWindow:Font, w400
Gui, MyWindow:Add, Button, x390 y150 w100 gRead_AdvID, Read AdvID
Gui, MyWindow:Add, Text, x15 y%GUITabTxtT% w100, Elapsed Time:  ; TODO: what elapsed time? this seems to be arbitrary short periods, do they need to be displayed?
Gui, MyWindow:Add, Text, vElapsedTimeID x+2 w100, 0
Gui, MyWindow:Add, Text, x200 y%GUITabTxtT% w100, Elapsed Zone Time:
Gui, MyWindow:Add, Text, vZoneTimeID x+2 w100, % ZoneTime := 0

Gui, MyWindow:Font, w700
Gui, MyWindow:Add, Text, x15 y+15, Server Call Variables         (ver %SC_ScriptVersion%)
Gui, MyWindow:Font, w400
Gui, MyWindow:Add, Text, x15 y+5 w200, advtoload:
Gui, MyWindow:Add, Text, vadvtoloadID x+2 w300, % advtoload
Gui, MyWindow:Add, Text, x15 y+5 w200, current_adventure_id:
Gui, MyWindow:Add, Text, vCurrentAdventureID x+2 w300, % current_adventure_id := 0
;Gui, MyWindow:Add, Button, x15 y100 w100 gDiscord_Clicked, Discord

Gui, MyWindow:Add, Text, x15 y+5 w200, InstanceID:
Gui, MyWindow:Add, Text, vInstanceIDID x+2 w300, % InstanceID := 0
Gui, MyWindow:Add, Text, x15 y+5 w200, ActiveInstance:
Gui, MyWindow:Add, Text, vActiveInstanceID x+2 w300, % ActiveInstance := 0

Gui, MyWindow:Font, w700
Gui, MyWindow:Add, Text, x15 y+15, Memory Reads                    (ver %MF_ScriptVersion%)
Gui, MyWindow:Font, w400
Gui, MyWindow:Add, Text, x15 y+10 w200, Current Zone: 
Gui, MyWindow:Add, Text, vReadCurrentZoneID x+2 w200, %PreciseTime% `t 00000
Gui, MyWindow:Add, Text, x15 y+5 w200, Highest Zone: 
Gui, MyWindow:Add, Text, vReadHighestZoneID x+2 w200, %PreciseTime% `t 00000
Gui, MyWindow:Add, Text, x15 y+5 w200, Quest Remaining: 
Gui, MyWindow:Add, Text, vReadQuestRemainingID x+2 w200, %PreciseTime% `t 00000
Gui, MyWindow:Add, Text, x15 y+5 w200, TimeScaleMultiplier: 
Gui, MyWindow:Add, Text, vReadTimeScaleMultiplierID x+2 w200, %PreciseTime% `t 00000
Gui, MyWindow:Add, Text, x15 y+5 w200, Transitioning: 
Gui, MyWindow:Add, Text, vReadTransitioningID x+2 w200, %PreciseTime% `t 00000
Gui, MyWindow:Add, Text, x15 y+5 w200, SB Stacks: 
Gui, MyWindow:Add, Text, vReadSBStacksID x+2 w200, %PreciseTime% `t 00000
Gui, MyWindow:Add, Text, x15 y+5 w200, Haste Stacks: 
Gui, MyWindow:Add, Text, vReadHasteStacksID x+2 w200, %PreciseTime% `t 00000
Gui, MyWindow:Add, Text, x15 y+5 w200, Resetting: 
Gui, MyWindow:Add, Text, vReadResettingID x+2 w200, %PreciseTime% `t 00000
Gui, MyWindow:Add, Text, x15 y+5 w200, Screen Width: 
Gui, MyWindow:Add, Text, vReadScreenWidthID x+2 w200, %PreciseTime% `t 00000
Gui, MyWindow:Add, Text, x15 y+5 w200, Screen Height: 
Gui, MyWindow:Add, Text, vReadScreenHeightID x+2 w200, %PreciseTime% `t 00000
;Gui, MyWindow:Add, Text, x15 y+5, ReadChampLvlBySlot: 
;Gui, MyWindow:Add, Text, vReadChampLvlBySlotID x+2 w200,
Gui, MyWindow:Add, Text, x15 y+5 w200, Monsters Spawned:
Gui, MyWindow:Add, Text, vReadMonstersSpawnedID x+2 w200, %PreciseTime% `t 00000
Gui, MyWindow:Add, Text, x15 y+5 w200, ChampLvlByID:
Gui, MyWindow:Add, Text, vReadChampLvlByIDID x+2 w200, %PreciseTime% `t 00000
;Gui, MyWindow:Add, Text, x15 y+5, ReadChampSeatByID:
;Gui, MyWindow:Add, Text, vReadChampSeatByIDID x+2 w200,
;Gui, MyWindow:Add, Text, x15 y+5, ReadChampIDbySlot:
;Gui, MyWindow:Add, Text, vReadChampIDbySlotID x+2 w200,
Gui, MyWindow:Add, Text, x15 y+5 w200, Core Target Area:
Gui, MyWindow:Add, Text, vReadCoreTargetAreaID x+2 w200, %PreciseTime% `t 00000
Gui, MyWindow:Add, Text, x15 y+5 w200, Core XP: 
Gui, MyWindow:Add, Text, vReadCoreXPID x+2 w200, %PreciseTime% `t 00000
Gui, MyWindow:Add, Text, x15 y+5 w200, Gems: 
Gui, MyWindow:Add, Text, vReadGemsID x+2 w200, %PreciseTime% `t 00000
Gui, MyWindow:Add, Text, x15 y+5 w200, Gems Spent: 
Gui, MyWindow:Add, Text, vReadGemsSpentID x+2 w200, %PreciseTime% `t 00000
Gui, MyWindow:Add, Text, x15 y+5 w200, Red Gems: 
Gui, MyWindow:Add, Text, vReadRedGemsID x+2 w200, %PreciseTime% `t 00000
Gui, MyWindow:Add, Text, x15 y+5 w200, ChampBenchedByID: 
Gui, MyWindow:Add, Text, vReadChampBenchedByIDID x+2 w200, %PreciseTime% `t 00000
Gui, MyWindow:Add, Text, x15 y+180 w40, UserID: 
Gui, MyWindow:Add, Text, vReadUserIDID x+2 w75, 00000
Gui, MyWindow:Add, Text, x+5 w30, Hash: 
Gui, MyWindow:Add, Text, vReadUserHashID x+2 w400, 0000000000000000000000000000000


Gui, Tab, Resources
Gui, MyWindow:Font, cSilver s11 ;
Gui, MyWindow:Add, Button, x15 y100 w100 gDiscord_Clicked, Discord
Gui, MyWindow:Add, Button, x15 y+15 w100 gByteGlow_Clicked, Byteglow
Gui, MyWindow:Add, Button, x15 y+15 w100 gKleho_Clicked, Kleho
Gui, MyWindow:Add, Button, x15 y+15 w100 gSoul_Clicked, Soul's
Gui, MyWindow:Add, Button, x15 y+15 w100 gFenomas_Clicked, Fenomas's
Gui, MyWindow:Add, Button, x15 y+15 w100 gXeio_Clicked, Xeio's Code Redeemer

if (gCDLevelingKey)
    GuiControl, ChooseString, CDLevelingKeyDDL, %gCDLevelingKey%

global Zeelog := CurrentTime . " Initializing ..."
global hZlog := 0
Gui, Tab, ZDebug
GUITabZDBW := GUITabTxtW +20
Gui, MyWindow:Add, Edit, r40 w%GUITabZDBW% x9 y%GUITabTxtT% HwndhZlog vZlog ReadOnly, %Zeelog%
;Gui, Add, Edit, r10 w500 hwndhMyEdit vMyEdit, % GenText("a", 60000)
Gui, MyWindow:Font, cSilver s11 ;
Gui, MyWindow:Font, w700

Gui, MyWindow:Show


Gui, Add, StatusBar                 ; need to shrink main window to not overlap when loading
SB_SetParts(20,300)

SB_SetText("`tNot running." , 2, 2)
SB_SetText("`tSpace for sth else.." , 3, 2)
SB_SetText(" " , 1, 2)

Gui, InstallGUI:New
Gui, InstallGUI:Add, Edit, vNewInstallPath x15 y+10 w%GUITabTxtW% r5, % gInstallPath
Gui, InstallGUI:Add, Button, x15 y+25 gInstallOK_Clicked, Save and Close
Gui, InstallGUI:Add, Button, x+100 gInstallCancel_Clicked, Cancel

InstallCancel_Clicked:
{
    GuiControl, InstallGUI:, NewInstallPath, %gInstallPath%
    Gui, InstallGUI:Hide
    Return
}

InstallOK_Clicked:
{
    Gui, Submit, NoHide
    gInstallPath := NewInstallPath
    GuiControl, MyWindow:, gInstallPathID, %gInstallPath%
    IniWrite, %gInstallPath%, Usersettings.ini, Section1, GameInstallPath
    Gui, InstallGUI:Hide
    Return
}

ChangeInstallLocation_Clicked:
{
    Gui, InstallGUI:Show
    Return
}


; TODO: implement explorer selection on the Resources GUI that verifies exe paths,
; Also allow user to enter their own name/path in addition to those detected?
strBrowser := "chrome.exe "
Discord_Clicked:
{
    Run chrome.exe "https://discord.gg/idlechampions" " --new-window "
    Return
}

ByteGlow_Clicked:
{
    Run chrome.exe "https://ic.byteglow.com/user" " --new-window "
    Return
}

Kleho_Clicked:
{
    Run chrome.exe "https://idle.kleho.ru/about/" " --new-window "
    Return
}

Xeio_Clicked:
{
    Run chrome.exe "chrome-extension://cblhleinomjkhhekobghobnofjbnpgag/dst/options.html"
    Return
}

Soul_Clicked:
{
    Run chrome.exe "http://idlechampions.soulreaver.usermd.net/achievements.html" " --new-window "
    Return
}

Fenomas_Clicked:
{    
    Run chrome.exe "https://fenomas.com/idle/" " --new-window "
    Return
}


Read_AdvID:
{
    advtoload := ReadCurrentObjID(0)
    GuiControl, MyWindow:, advtoloadID, % advtoload    
}

; courtesy of banur@Discord
Help_clicked:
{
    clipboard = %MF_ScriptDate% `n%MF_ScriptVersion% `n%SC_ScriptDate% `n%SC_ScriptVersion% `n %A_AhkVersion%
    msgbox %MF_ScriptDate% `n%MF_ScriptVersion% `n%SC_ScriptDate% `n%SC_ScriptVersion% `n%A_AhkVersion%`n`nVersion data copied!`nPaste into Discord.
    return
}

Save_Clicked:
{
    Gui, Submit, NoHide
    Loop, 12
    {
        gSeatToggle[A_Index] := CheckboxSeat%A_Index%
        var := CheckboxSeat%A_Index%
        IniWrite, %var%, UserSettings.ini, Section1, S%A_Index%
    }
    gFKeys :=
    Loop, 12
    {
        if (gSeatToggle[A_Index])
        {
            gFKeys = %gFKeys%{F%A_Index%}
            IniWrite, 1, UserSettings.ini, Section1, S%A_Index%
        }
        Else
        IniWrite, 0, UserSettings.ini, Section1, S%A_Index%
    }
    GuiControl, MyWindow:, gFkeysID, % gFKeys
    gAreaLow := NewgAreaLow
    GuiControl, MyWindow:, gAreaLowID, % gAreaLow
    IniWrite, %gAreaLow%, UserSettings.ini, Section1, AreaLow
    gMinStackZone := NewgMinStackZone
    GuiControl, MyWindow:, gMinStackZoneID, % gMinStackZone
    IniWrite, %gMinStackZone%, Usersettings.ini, Section1, MinStackZone
    gSBTargetStacks := NewSBTargetStacks
    GuiControl, MyWindow:, gSBTargetStacksID, % gSBTargetStacks
    IniWrite, %gSBTargetStacks%, UserSettings.ini, Section1, SBTargetStacks
    gSBTimeMax := NewgSBTimeMax
    GuiControl, MyWindow:, gSBTimeMaxID, %gSBTimeMax%
    IniWrite, %gSBTimeMax%, Usersettings.ini, Section1, SBTimeMax
    gDashSleepTime := NewDashSleepTime
    GuiControl, MyWindow:, DashSleepTimeID, % gDashSleepTime
    IniWrite, %gDashSleepTime%, UserSettings.ini, Section1, DashSleepTime
    GuiControl, MyWindow:, gDashAfterStackID, % gDashAfterStack
    IniWrite, %gDashAfterStack%, UserSettings.ini, Section1, DashAfterStack
    GuiControl, MyWindow:, gDashWaitZone, % gDashWaitZone
    IniWrite, %gDashWaitZone%, UserSettings.ini, Section1, DashWaitZone
    gContinuedLeveling := NewContinuedLeveling
    gStopLevZone := NewContinuedLeveling
    GuiControl, MyWindow:, gStopLevZoneID, % gStopLevZone
    IniWrite, %gStopLevZone%, UserSettings.ini, Section1, ContinuedLeveling
    gHewUlt := NewHewUlt
    GuiControl, MyWindow:, gHewUltID, % gHewUlt
    IniWrite, %gHewUlt%, UserSettings.ini, Section1, HewUlt
    GuiControl, MyWindow:, gbSpamUltsID, % gbSpamUlts
    IniWrite, %gbSpamUlts%, UserSettings.ini, Section1, Ults
    GuiControl, MyWindow:, gbCancelAnimID, % gbCancelAnim
    IniWrite, %gbCancelAnim%, UserSettings.ini, Section1, BrivSwap
    GuiControl, MyWindow:, gAvoidBossesID, % gAvoidBosses
    IniWrite, %gAvoidBosses%, UserSettings.ini, Section1, AvoidBosses
    GuiControlGet, CDLKey ,, CDLevelingKeyDDL                   ; grab the selected value not the extracted index
    IniWrite, %CDLKey%, UserSettings.ini, Section1, CDLevelingKey
    GuiControl, MyWindow:, gb100xCDLevID, % gb100xCDLev
    IniWrite, %gb100xCDLev%, UserSettings.ini, Section1, CtrlClickLeveling
    GuiControl, MyWindow:, gbSFRecoverID, % gbSFRecover
    IniWrite, %gbSFRecover%, UserSettings.ini, Section1, StackFailRecovery
    GuiControl, MyWindow:, gStackFailConvRecoveryID, % gStackFailConvRecovery
    IniWrite, %gStackFailConvRecovery%, UserSettings.ini, Section1, StackFailConvRecovery
    gSwapSleep := NewSwapSleep
    GuiControl, MyWindow:, gSwapSleepID, % gSwapSleep
    IniWrite, %gSwapSleep%, UserSettings.ini, Section1, SwapSleep
    gRestartStackTime := NewRestartStackTime
    GuiControl, MyWindow:, gRestartStackTimeID, % gRestartStackTime
    IniWrite, %gRestartStackTime%, UserSettings.ini, Section1, RestartStackTime
    GuiControl, MyWindow:, gDoChestsID, % gDoChests
    IniWrite, %gDoChests%, UserSettings.ini, Section1, DoChests
    gSCMinGemCount := NewSCMinGemCount
    GuiControl, MyWindow:, gSCMinGemCount, % gSCMinGemCount
    IniWrite, %gSCMinGemCount%, UserSettings.ini, Section1, SCMinGemCount
    gSCBuySilvers := NewSCBuySilvers
    if (gSCBuySilvers > 100)
    gSCBuySilvers := 100
    GuiControl, MyWindow:, gSCBuySilversID, % gSCBuySilvers
    IniWrite, %gSCBuySilvers%, UserSettings.ini, Section1, SCBuySilvers
    gSCSilverCount := NewSCSilverCount
    if (gSCSilverCount > 99)
    gSCSilverCount := 99
    GuiControl, MyWindow:, gSCSilverCountID, % gSCSilverCount
    IniWrite, %gSCSilverCount%, UserSettings.ini, Section1, SCSilverCount
    gSCBuyGolds := NewSCBuyGolds
    if (gSCBuyGolds > 100)
    gSCBuyGolds := 100
    GuiControl, MyWindow:, gSCBuyGoldsID, % gSCBuyGolds
    IniWrite, %gSCBuyGolds%, UserSettings.ini, Section1, SCBuyGolds
    gSCGoldCount := NewSCGoldCount
    if (gSCGoldCount > 99)
    gSCGoldCount := 99
    GuiControl, MyWindow:, gSCGoldCountID, % gSCGoldCount
    IniWrite, %gSCGoldCount%, UserSettings.ini, Section1, SCGoldCount
    IniWrite, 0, UserSettings.ini, Section1, FirstTime
    return
}

Reload_Clicked:
{
    Reload
    return
}

Run_Clicked:
{
    gStartTime := A_TickCount
    gRunStartTime := A_TickCount
    SB_SetIcon(A_ScriptDir "\go.ico")
    SetupStrings()
    GemFarm()
    return
}

Pause_Clicked:
{
    Pause
    SB_SetIcon(A_ScriptDir "\pause.ico")
    gPrevLevelTime := A_TickCount
    return
}

MyWindowGuiClose() 
{
    MsgBox 4,, Are you sure you want to exit?
    IfMsgBox Yes
    ExitApp
    IfMsgBox No
    return True
}

$~::
    Pause
    SB_SetIcon(A_ScriptDir "\pause.ico")
    gPrevLevelTime := A_TickCount
return

Edit_Prepend(handl, Text ) 
{ ;www.autohotkey.com/community/viewtopic.php?p=565894#p565894
    ;MsgBox %handl%
    DllCall( "SendMessage", UInt, handl, UInt,0xB1, UInt,0 , UInt,0 ) ; EM_SETSEL
    DllCall( "SendMessage", UInt, handl, UInt,0xC2, UInt,0 , UInt,&Text ) ; EM_REPLACESEL
    DllCall( "SendMessage", UInt, handl, UInt,0xB1, UInt,0 , UInt,0 ) ; EM_SETSEL
}

global fLog := "Zlog.txt"
LogMsg(msg, display := false)
{
    FormatTime, CurrentTime, , yyyyMMdd HH:mm:ss
    TSmsg := CurrentTime . "." . A_MSec . " " . msg . "`r`n"
    if (display)
    {
        ;SendMessage, 0x0115, 7, 0,, ahk_id %hZlog% ;WM_VSCROLL 
        Edit_Prepend(hZlog, TSmsg)
    }
    FormatTime, today, , yyyyMMdd
    nFn := today " " fMFLog
    FileAppend, %TSmsg%, %nFn%
}

AppendText(hEdit, ptrText) {
    SendMessage, 0x000E, 0, 0,, ahk_id %hEdit% ;WM_GETTEXTLENGTH
    SendMessage, 0x00B1, ErrorLevel, ErrorLevel,, ahk_id %hEdit% ;EM_SETSEL
    SendMessage, 0x00C2, False, ptrText,, ahk_id %hEdit% ;EM_REPLACESEL
}

SetupStrings()
{
    FileName = textfile.txt
    text =
    (
    First Line
    Second Line
    Third Line
    )
    FileAppend, %text%, %FileName%
    Loop, Read, %FileName%, NewFile.txt
    {
        If (InStr(A_LoopReadLine, "Second Line")) {
            NewData := StrReplace(A_LoopReadLine, "Second Line", "New Text")
            FileAppend, % NewData "`r`n"
        } Else {
            FileAppend, % A_LoopReadLine "`r`n"
        }
    }
    FileDelete, %FileName%
    FileMove, NewFile.txt, %FileName%
    return    
}


;Solution by Meviin to release Alt, Shift, and Ctrl keys when they get stuck during script use.
ReleaseStuckKeys()                                           
{                                                            
    if GetKeyState("Alt") && !GetKeyState("Alt", "P")        
    {                                                        
      Send {Alt up}                                          
    }                                                        
    if GetKeyState("Shift") && !GetKeyState("Shift", "P")    
    {                                                        
      Send {Shift up}                                        
    }                                                        
    if GetKeyState("Control") && !GetKeyState("Control", "P")
    {                                                        
      Send {Control up}                                      
    }                                                        
}


SafetyCheck(delay := 5000)
{
    static lastRan := 0
    static scCount := 0
    if (lastRan + delay < A_TickCount)
    {
        While (Not WinExist("ahk_exe IdleDragons.exe")) 
        {
            Run, %gInstallPath%
            ;Run, "C:\Program Files (x86)\Steam\steamapps\common\IdleChampions\IdleDragons.exe"
            StartTime := A_TickCount
            ElapsedTime := 0
            UpdateStatusEdit("Opening IC")        ;GuiControl, MyWindow:, gloopID, Opening IC
            While (Not WinExist("ahk_exe IdleDragons.exe") AND ElapsedTime < 60000) 
            {
                Sleep 1000
                ElapsedTime := UpdateElapsedTime(StartTime)
                UpdateStatTimers()
            }
            If (Not WinExist("ahk_exe IdleDragons.exe"))
                Return

            ;the script doesn't update GUI with elapsed time while IC is loading, opening the address, or readying base address, to minimize use of CPU.
        ; TODO: Separate Gui from operation
            UpdateStatusEdit("Opening Process") ; GuiControl, MyWindow:, gloopID, Opening Process
            Sleep gOpenProcess
            OpenProcess()
            UpdateStatusEdit("Loading Module Base") ; GuiControl, MyWindow:, gloopID, Loading Module Base
            Sleep gGetAddress
            ModuleBaseAddress()
            ++ResetCount
            GuiControl, MyWindow:, ResetCountID, % ResetCount
            LoadingZoneREV()
            if (gbSpamUlts)
                DoUlts()
            ;reset timer for checking if IC is stuck on a zone.
            gPrevLevelTime := A_TickCount
        }
        lastRan := A_TickCount
        ++scCount
        GuiControl, MyWindow:, SafetyCheckID, %scCount%
    }
}

/*
; SafetyCheck is executed to ensure we have a valid/running IC application.  If we don't the script will
; attempt to open it for 60 seconds, if it fails, it returns without any further execution/checks
SafetyCheck() 
{
    ReleaseStuckKeys()
    While (Not WinExist("ahk_exe IdleDragons.exe")) 
    {

    }
}
*/

; CloseIC - closes Idle Champions. If IC takes longer than 60 seconds to save and close then the script will force it closed.
; TODO: there is no actual "force it closed" code, it repeats the first attempt loop with 1s sleeps instead of 0.1
;       look into processkill if we really want to kill the IC process
CloseIC()
{
    DirectedInput("w")                                      ; Forcing W formation on close to ensure proper offline stacking
    sleep 100
    PostMessage, 0x112, 0xF060,,, ahk_exe IdleDragons.exe   ; TOODO: what message is this sending to the IC executable?
    StartTime := A_TickCount
    ElapsedTime := 0
    UpdateStatusEdit("Saving and Closing IC") ;GuiControl, MyWindow:, gloopID, Saving and Closing IC
    While (WinExist("ahk_exe IdleDragons.exe") AND ElapsedTime < 60000) 
    {
        Sleep 100
        ElapsedTime := UpdateElapsedTime(StartTime)
        UpdateStatTimers()
    }
    While (WinExist("ahk_exe IdleDragons.exe")) 
    {
        UpdateStatusEdit("Forcing IC Close") ;GuiControl, MyWindow:, gloopID, Forcing IC Close
        DirectedInput("w")
        sleep 100
        PostMessage, 0x112, 0xF060,,, ahk_exe IdleDragons.exe
        sleep 1000
        ElapsedTime := UpdateElapsedTime(StartTime)
        UpdateStatTimers()
    }
}

; CheckForFailedConv - checks if farmed SB stacks from previous run failed to convert to haste. If so, the script will 
; manually end the adventure to attempt to covnert the stacks, close IC, use a servercall to restart the adventure, and restart IC.
CheckForFailedConv()
{
    stacks := GetNumStacksFarmed()
    If (gStackCountH < gSBTargetStacks AND stacks > gSBTargetStacks AND !gTestReset)
    {
        EndAdventure(1) ; If this sleep is too low it can cancel the reset before it completes. In this case
                        ; that could be good as it will convert SB to Haste and not end the adventure.        
        gStackFail := 2
        return
    }
}

FinishZone()
{
    StartTime := A_TickCount
    ElapsedTime := 0
    UpdateStatusEdit("Finishing Zone") ;GuiControl, MyWindow:, gloopID, Finishing Zone
    while (ReadQuestRemaining(1) AND ElapsedTime < 15000)
    {
        StuffToSpam(0, gLevel_Number)
        ElapsedTime := UpdateElapsedTime(StartTime)
        UpdateStatTimers()
    }
    return
}

LevelChampByID(ChampID := 1, Lvl := 0, i := 5000, j := "q", seat := 1)
{
    ;seat := ReadChampSeatByID(,, ChampID)
    StartTime := A_TickCount
    ElapsedTime := 0
    UpdateStatusEdit("Levelling Champ " . ChampID . " to " . Lvl) ;GuiControl, MyWindow:, gloopID, Leveling Champ %ChampID% to %Lvl%
    var := "{F" . seat . "}"
    var := var j
    while (ReadChampLvlByID(1,,ChampID) < Lvl AND ElapsedTime < i)
    {
        DirectedInput(var)
        ElapsedTime := UpdateElapsedTime(StartTime)
        UpdateStatTimers()
    }
    return
}

DoDashWait()
{
    ReleaseStuckKeys()
    ;precondition - party must already be stopped ('g' turned off), this function only deals with waiting itself
    ;   (and using the waiting time to level up champs if at level 1)

    if (gDashWaitZone and gDashAfterStack) {
        UpdateStatusEdit("Transitioning to DashWait zone")
        while (ReadCurrentZone(1) <= gAreaLow + gDashWaitZone) {
            gLevel_Number := ReadCurrentZone(1)
            StuffToSpam(1, gLevel_Number, 0, "e")
        }
    }

    gLevel_Number := ReadCurrentZone(1)

    if (gLevel_Number == 1) {
        ; level up shandie
        LevelChampByID(47, 120, 5000, "q", 6)
    }
    ; now the timer for dash is running
    StartTime := A_TickCount
    ElapsedTime := 0
    if (gLevel_Number == 1)
    {
        ; level up briv, needed to read his stacks
        LevelChampByID(58, 80, 5000, "q", 5)
    }
    ; let the multiplier "settle" before using it. When stacking mid-run, the values DO change for a short period
    ; after restart (theory: first read is before potions are applied, second is with potions), so first read sees
    ; lower value, next read few ms after that sees higher value and interprets it as "multiplier increased, so we
    ; have dash and our work is done"
    sleep 1000
    gTime := ReadTimeScaleMultiplier(1)
    if (gTime < 1) {
        gTime := 1
    }
    DashSpeed := gTime * 1.4
    modDashSleep := gDashSleepTime / gTime
    if (modDashSleep < 1)
    {
        modDashSleep := gDashSleepTime
    }
    GuiControl, MyWindow:, NewDashSleepID, % modDashSleep
    UpdateStatusEdit("Dash Wait") ;GuiControl, MyWindow:, gloopID, Dash Wait 
    While (ReadTimeScaleMultiplier(1) < DashSpeed AND ElapsedTime < modDashSleep)
    {
        StuffToSpam(0, 1, 0)
        ReleaseStuckKeys()
        ElapsedTime := UpdateElapsedTime(StartTime)
        UpdateStatTimers()
    }
    return
}

DoUlts()
{
    StartTime := A_TickCount
    ElapsedTime := 0
    iUltSpamDur := 2000
    UpdateStatusEdit("Spamming Ultimates for " . iUltSpamDur . " milli seconds") ;GuiControl, MyWindow:, gloopID, Spamming Ults for 2s
    while (ElapsedTime < iUltSpamDur)
    {
        ReleaseStuckKeys()
        DirectedInput("23456789")
        ElapsedTime := UpdateElapsedTime(StartTime)
        UpdateStatTimers()
    }
    DirectedInput("8") ; use whatever number is Hav's ult
}

DirectedInput(s) 
{
    ReleaseStuckKeys()
    SafetyCheck()
    ControlFocus,, ahk_exe IdleDragons.exe
    ControlSend,, {Blind}%s%, ahk_exe IdleDragons.exe
    Sleep, 25  ; Sleep for 25 sec formerly ScriptSpeed global, not used elsewhere. - gScriptSpeed was intended as a user setting
}

SetFormation(gLevel_Number)
{
    if (gAvoidBosses and !Mod(gLevel_Number, 5))
    {
        DirectedInput("e")
    }
    else if (!ReadQuestRemaining(1) AND ReadTransitioning(1))
    {
        DirectedInput("e")
        StartTime := A_TickCount
        ElapsedTime := 0
        UpdateStatusEdit("Read Transitioning") ;GuiControl, MyWindow:, gloopID, ReadTransitioning
        while (ElapsedTime < 5000 AND !ReadQuestRemaining(1))
        {
            DirectedInput("{Right}")
            ElapsedTime := UpdateElapsedTime(StartTime)
            UpdateStatTimers()
        }
        StartTime := A_TickCount
        ElapsedTime := 0
        gTime := ReadTimeScaleMultiplier(1)
        swapSleepMod := gSwapSleep / gTime
        UpdateStatusEdit("Still Read Transitioning") ;GuiControl, MyWindow:, gloopID, Still ReadTransitioning
        while (ElapsedTime < swapSleepMod AND ReadTransitioning(1))
        {
            DirectedInput("{Right}")
            ElapsedTime := UpdateElapsedTime(StartTime)
            UpdateStatTimers()
        }
        DirectedInput("q")
    }
    else
    DirectedInput("q")
}

LoadingZoneREV()
{
    StartTime := A_TickCount
    ElapsedTime := 0
    UpdateStatusEdit("Loading Zone (REV)") ;GuiControl, MyWindow:, gloopID, Loading Zone
    ;ReadMonstersSpawned was added in case monsters were spawned before game allowed inputs, an issue when spawn speed is very high. Might be creating more problems.
    ;Offline Progress appears to read monsters spawning, so this entire function can be bypassed creating issues with stack restart.
    ;while (ReadChampBenchedByID(1,, 47) != 1 AND ElapsedTime < 60000 AND ReadMonstersSpawned(1) < 2)
    ;shouldn't be an issue if monsters spawn, Briv is supposed to be on bench. Zone will kill monsters no problem. Higher zones she should be leveled.
    while (ReadChampBenchedByID(1,, 58) != 1 AND ElapsedTime < 60000)
    {
        DirectedInput("e{F5}e")
        ElapsedTime := UpdateElapsedTime(StartTime)
        UpdateStatTimers()
    }
    if (ElapsedTime > 60000)
    {
        CheckifStuck(gprevLevel)
    }
    StartTime := A_TickCount
    ElapsedTime := 0
    UpdateStatusEdit("Confirming Zone Load (REV)") ;GuiControl, MyWindow:, gloopID, Confirming Zone Load
    ;need a longer sleep since offline progress should read Briv benched.
    while (ReadChampBenchedByID(1,, 58) != 0 AND ElapsedTime < 30000)
    {
        DirectedInput("w{F5}w")
        ElapsedTime := UpdateElapsedTime(StartTime)
        UpdateStatTimers()
    }
}

LoadingZoneOne()
{
    ;look for Briv not benched when spamming 'q' formation.
    StartTime := A_TickCount
    ElapsedTime := 0
    UpdateStatusEdit("Loading Zone (One)") ;GuiControl, MyWindow:, gloopID, Loading Zone
    while (ReadChampBenchedByID(1,, 58) != 0 AND ElapsedTime < 60000)
    {
        DirectedInput("q{F5}q")
        ElapsedTime := UpdateElapsedTime(StartTime)
        UpdateStatTimers()
    }
    if (ElapsedTime > 60000)
    {
        CheckifStuck(gprevLevel)
    }
    ;look for Briv benched when spamming 'e' formation.
    StartTime := A_TickCount
    ElapsedTime := 0
    UpdateStatusEdit("Confirming Zone Load (One)") ;GuiControl, MyWindow:, gloopID, Confirming Zone Load
    while (ReadChampBenchedByID(1,, 58) != 1 AND ElapsedTime < 60000)
    {
        DirectedInput("e{F5}e")
        ElapsedTime := UpdateElapsedTime(StartTime)
        UpdateStatTimers()
    }
    if (ElapsedTime > 60000)
    {
        CheckifStuck(gprevLevel)
    }
}

CheckSetUpREV()  ; TODO: not sure if from Cantrow or newest Mike - but you already replaced it in GemFarm with VerifyChamp. so remove?
{
    ;Check if Briv is in 'Q' formation.
    StartTime := A_TickCount
    ElapsedTime := 0
    slot := 0
    UpdateStatusEdit("Looking for Briv")
    Loop, 5
    {
        DirectedInput("q{F5}q")
        sleep, 100
        if (ReadChampBenchedByID(1,, 58) = 0)
          break
    }
    while (ReadChampBenchedByID(1,, 58) != 0 AND ElapsedTime < 10000)
    {
        DirectedInput("q{F5}q")
        ElapsedTime := UpdateElapsedTime(StartTime)
        UpdateStatTimers()
    }
    if (ReadChampBenchedByID(1,, 58) = 1)
    {
        MsgBox, Couldn't find Briv in "Q" formation. Check saved formations. Ending Gem Farm.
        Return, 1
    }
    ;Check if Briv is not in 'E' formation.
    StartTime := A_TickCount
    ElapsedTime := 0
    UpdateStatusEdit("Looking for no Briv")
    while (ReadChampBenchedByID(1,, 58) != 1 AND ElapsedTime < 10000)
    {
        DirectedInput("e")
        ElapsedTime := UpdateElapsedTime(StartTime)
        UpdateStatTimers()
    }
    if (ReadChampBenchedByID(1,, 58) = 0)
    {
        MsgBox, Briv is in "E" formation. Check Settings. Ending Gem Farm.
        return, 1
    }
    if (advtoload < 1)
    {
        MsgBox, Please load into a valid adventure and restart. Ending Gem Farm.
        return, 1
    }
    return, 0
}

; // UpdateElapsedTime ////////////////////////////////////////////////////////////////////////////
; // UpdateElapsedTime() - helper function
UpdateElapsedTime(start)
{
    elapsed := A_TickCount - start
    GuiControl, MyWindow:, ElapsedTimeID, % elapsed
    return elapsed
}

;thanks meviin for coming up with this solution
GetNumStacksFarmed()
{
    ; Read the number of stacks from memory
    gStackCountSB := ReadSBStacks(1)
    ; part of huans early stacking addition
    ; he mentioned this breaking "failed stack recovery" but had a later update:
    ; https://canary.discord.com/channels/357247482247380994/474639469916454922/888977817214283786
    ; probably needs separat update/ merge from his github: https://github.com/huancz/Idle-Champions/tree/early_stacking
    ; prevent SB stacks going backwards. Situation
    ; - game is the middle of resetting (normal modron reset)
    ; - script reads level 780 or whatever (above stacking zone), and SB stack count of 0 ...
    ; - ... which makes it trigger stackrestart while modron reset is in progress, and finishing it at level 1
    if (gStackCountSB >= gHighestStackCountSB) {
        gHighestStackCountSB := gStackCountSB
    } else {
        gStackCountSB := gHighestStackCountSB
    }
    gStackCountH := ReadHasteStacks(1)
    if (gRestartStackTime and not gDashAfterStack)
    {
        return gStackCountH + gStackCountSB
    } 
    else 
    {
        ; If restart stacking is disabled, we'll stack to basically the exact
        ; threshold.  That means that doing a single jump would cause you to
        ; lose stacks to fall below the threshold, which would mean StackNormal
        ; would happen after every jump.
        ; Thus, we use a static 47 instead of using the actual haste stacks
        ; with the assumption that we'll be at minimum stacks after a reset.
        ;
        ; The same behaviour is needed when stacking early - Briv is supposed to eat most
        ; of current gStackCountH before the run is over. Using sum of both values sometimes
        ; skips the intended stacking zone because at the time the sum is still high
        ; enough, Then decide to stack few hundreds levels later -> most of the run is
        ; without dash, and the minute for dashwait is wasted on last 200 or 300 levels.
        return gStackCountSB + 47
    }
}

StackRestart()
{
    StartTime := A_TickCount
    ElapsedTime := 0
    UpdateStatusEdit("Transitioning to Stack Restart") ;GuiControl, MyWindow:, gloopID, Transitioning to Stack Restart
    while (ReadTransitioning(1))
    {
        DirectedInput("w")
        ElapsedTime := UpdateElapsedTime(StartTime)
        UpdateStatTimers()
    }
    StartTime := A_TickCount
    ElapsedTime := 0
    UpdateStatusEdit("Confirming ""w"" Loaded") ;GuiControl, MyWindow:, gloopID, Confirming "w" Loaded
    ;added due to issues with Loading Zone function, see notes therein
    while (ReadChampBenchedByID(1,, 47) != 1 AND ElapsedTime < 15000)
    {
        DirectedInput("w")
        ElapsedTime := UpdateElapsedTime(StartTime)
        UpdateStatTimers()
    }
    Sleep 1000
    CloseIC()
    StartTime := A_TickCount
    ElapsedTime := 0
    UpdateStatusEdit("Stack Slee - ") ;GuiControl, MyWindow:, gloopID, Stack Sleep
    if (gDoChests)
    {
        DoChests()
        ElapsedTime := UpdateElapsedTime(StartTime)
        
    }
    while (ElapsedTime < gRestartStackTime)
    {
        Sleep 100
        ElapsedTime := UpdateElapsedTime(StartTime)
        UpdateStatTimers()
    }
    UpdateStatusEdit("Finish Stack Sleep for " . ElapsedTime/1000 . " seconds") ;GuiControl, MyWindow:, gloopID, Finish Stack Sleep: %ElapsedTime%
    SafetyCheck()
    ; Game may save "q" formation before restarting, creating an endless restart loop. LoadinZone() should 
    ; bring "w" back before triggering a second restart, but monsters could spawn before it does.
    ; this doesn't appear to help the issue above.
    DirectedInput("w")
}

StackNormal()
{
    StartTime := A_TickCount
    ElapsedTime := 0
    UpdateStatusEdit("Stack Normal") ;GuiControl, MyWindow:, gloopID, Stack Normal
    ;stacks := GetNumStacksFarmed()
    ;while (stacks < gSBTargetStacks AND ElapsedTime < gSBTimeMax)
    while (GetNumStacksFarmed() < gSBTargetStacks AND ElapsedTime < gSBTimeMax)
    {
        ReleaseStuckKeys()
        directedinput("w")
        if (ReadCurrentZone(1) <= gAreaLow) 
        {
            DirectedInput("{Right}")
        }
        Sleep 1000
        ;stacks := GetNumStacksFarmed()
        ElapsedTime := UpdateElapsedTime(StartTime)
        UpdateStatTimers()
        if (ReadResettting(1) OR ReadCurrentZone(1) = 1)
            Return
    }
}

StackFarm()
{
    StartTime := A_TickCount
    ElapsedTime := 0
    UpdateStatusEdit("Transitioning to Stack Farm") ;GuiControl, MyWindow:, gloopID, Transitioning to Stack Farm
    while (ReadChampBenchedByID(1,, 47) != 1 AND ElapsedTime < 5000)
    {
        DirectedInput("w")
        ElapsedTime := UpdateElapsedTime(StartTime)
        UpdateStatTimers()
    }
    DirectedInput("g")
    ;send input Left while on a boss zone
    while (!mod(ReadCurrentZone(1), 5))
    {
        ReleaseStuckKeys()
        DirectedInput("{Left}")
    }
    if gRestartStackTime
    {
        StackRestart()
    }
    stacks := GetNumStacksFarmed()
    if (gStackCountH < 50)
    {
        ; No remaining haste stacks can happen if previous run ended with failed stacking (ate the SB stacks without giving haste stacks).
        ; In such case there is no point doing whatever we were going to do (wait for dash, spam ults), main loop will restart the adventure
        ; as soon as we return from here.
        return
    }

    if (stacks < gSBTargetStacks) {
        ; StackNormal()

        ; try again on next level. In case we are in early stacking mode, this skips dash wait too until we have all the needed stacks
        DirectedInput("g")
        return
    }

    if (gDashAfterStack)
    {
        DirectedInput("q")
        DoDashWait()
    }

    gPrevLevelTime := A_TickCount
    if (gUlts)
    {
        DoUlts()
    }
    DirectedInput("g")
}

UpdateStartLoopStats(gLevel_Number)
{
    ReleaseStuckKeys()
    if (gTotal_RunCount = 0)
    {
        gStartTime := A_TickCount
        gCoreXPStart := ReadCoreXP(1)
        gGemStart := ReadGems(1)
        gGemSpentStart := ReadGemsSpent(1)
        gRedGemsStart := ReadRedGems(1)
    }
    if (gTotal_RunCount)
    {
        gPrevRunTime := TimePoint
        gPrevRunTime += (A_TickCount - gRunStartTime)/1000,Seconds
        FormatTime gPrevRunTimeF, %gPrevRunTime%, HH:mm:ss
        GuiControl, MyWindow:, gPrevRunTimeID, % gPrevRunTimeF
        if (gSlowRunTime < gPrevRunTime AND !gStackFail)
        {
            gSlowRunTime := gPrevRunTime
            gSlowRunTimeF := gPrevRunTimeF
            GuiControl, MyWindow:, gSlowRunTimeID, % gSlowRunTimeF
        }
        if (gFastRunTime >= gPrevRunTime AND !gStackFail)
        {
            gFastRunTime := gPrevRunTime
            gFastRunTimeF := gPrevRunTimeF
            GuiControl, MyWindow:, gFastRunTimeID, % gFastRunTimeF
        }
        if (gStackFail)
        {
            gFailRunTime := gPrevRunTime
            gFailRunTimeF := gPrevRunTimeF
            GuiControl, MyWindow:, gFailRunTimeID, % gFailRunTimeF
            if (gStackFail = 1)
            {
                ++gFailedStacking
                GuiControl, MyWindow:, gFailedStackingID, % gFailedStacking
            }
            else if (gStackFail = 2)
            {
                ++gFailedStackConv
                GuiControl, MyWindow:, gFailedStackConvID, % gFailedStackConv
            }
        }
        dtTotalTime := (A_TickCount - gStartTime)/1000,Seconds
        gAvgRunTime := TimePoint
        gAvgRunTime += Round((dtTotalTime / gTotal_RunCount), 2),Seconds
        FormatTime gAvgRunTimeF, %gAvgRunTime%, HH:mm:ss
        GuiControl, MyWindow:, gAvgRunTimeID, % gAvgRunTimeF
        dtTotalTime := (A_TickCount - gStartTime) / 3600000
        TotalBosses := (ReadCoreXP(1) - gCoreXPStart) / 5
        gbossesPhr := Round(TotalBosses / dtTotalTime, 2)
        GuiControl, MyWindow:, gbossesPhrID, % gbossesPhr
        GuiControl, MyWindow:, gTotal_RunCountID, % gTotal_RunCount
        GemsTotal := (ReadGems(1) - gGemStart) + (ReadGemsSpent(1) - gGemSpentStart)
        GuiControl, MyWindow:, GemsTotalID, % GemsTotal
        GemsPhr := Round(GemsTotal / dtTotalTime, 2)
        GuiControl, MyWindow:, GemsPhrID, % GemsPhr
        RedGemsTotal := (ReadRedGems(1) - gRedGemsStart)
        if (RedGemsTotal)
        {
            GuiControl, MyWindow:, RedGemsTotalID, % RedGemsTotal
            RedGemsPhr := Round(RedGemsTotal / dtTotalTime, 2)
            GuiControl, MyWindow:, RedGemsPhrID, % RedGemsPhr
        }
        Else
        {
            GuiControl, MyWindow:, RedGemsTotalID, 0
            GuiControl, MyWindow:, RedGemsPhrID, Pathetic
        }    
    }
    gRunStartTime := A_TickCount
    SetLastZone(gLevel_Number)

}

; SetLastZone - helper function to store the value in the global storage (TODO: factor out) and update the GUI
SetLastZone(znum)
{
    gPrevLevel := znum
    GuiControl, MyWindow:, gPrevLevelID, % gPrevLevel
}

UpdateStatTimers()
{
    ReleaseStuckKeys()
    dtCurrentRunTime := TimePoint
    dtCurrentRunTime += (A_TickCount - gRunStartTime)/1000,Seconds
    FormatTime dtCurrentRunTimeF, %dtCurrentRunTime%, HH:mm:ss
    GuiControl, MyWindow:, dtCurrentRunTimeID, % dtCurrentRunTimeF
    dtTotalTime := TimePoint
    dtTotalTime += (A_TickCount - gStartTime)/1000,Seconds
    FormatTime dtTotalTimeF, %dtTotalTime%, HH:mm:ss
    GuiControl, MyWindow:, dtTotalTimeID, % dtTotalTimeF
    GetZoneTime() 
}

GetZoneTime()
{
    g_ZoneTime := TimePoint
    g_ZoneTime += (A_TickCount - gPrevLevelTime)/1000,Seconds
    FormatTime g_ZoneTimeF, %g_ZoneTime%, HH:mm:ss
    GuiControl, MyWindow:, ZoneTimeID, % g_ZoneTimeF
    return g_ZoneTimeF
}

UpdateStatusEdit(msg)
{
    SB_SetText("`t" msg, 2, 2)
    GuiControl, MyWindow:, gLoopID, %msg%  ; %A_Hour%:%A_Min%:%A_Sec%.%A_MSec%
    FormatTime, CurrentTime, , yyyyMMdd HH:mm:ss
    TSmsg := CurrentTime . " " . msg . "`r`n"
    Edit_Prepend(hZLoop, TSmsg)  
    LogMsg(msg)    
}

; // VerifyChamp //////////////////////////////////////////////////////////////////////////////////
; // VerifyChamp() - helper function to eliminate code duplication
VerifyChamp(strGUI, strInit, champID, benched)  ; benched 1, 0 not benched
{
    start := A_TickCount  ; The tick count NOW is the start time
    UpdateStatusEdit(strGUI) 
    DirectedInput(strInit)  ; this should  set the stage for the champ check, ie right formation etc
    while (ReadChampBenchedByID(1,, champID) = benched AND (UpdateElapsedTime(start) < 5000))
    {
        DirectedInput(strInit) ; we are doing it again        
        UpdateStatTimers() ; TODO: why are we doing this here? this function has nothing to do with it?
    }
    ; One final check for our champ:
    if (ReadChampBenchedByID(1,, champID) = benched)
    {
        LogMsg("WARN: " . strGUI . " [" . benched . "] was Unsuccessful", true)
        ; TODO: create checkboxes for User Settings for HARD FAIL - this is anti newer user friendly
        ;MsgBox, Couldn't find Shandie in "Q" formation. Check saved formations. Ending Gem Farm.
        ;Return, 1
    } 
    return 0    
}

GemFarm() 
{  
    ReleaseStuckKeys() ; Strange, why here? it happens once per script execution - just for releasing modifier keys, probably useful in most functions just to execute it
    OpenProcess()      ; OpenProcess makes sense as a thing that happens at the start of execution
    ModuleBaseAddress()
    SetLevelingKeyVar()
    ;not sure why this one is here, commented out for now.
    ;GetUserDetails()
    strNow := "`t" . A_Hour . ":" . A_Min . ":" . A_Sec . ":" . A_MSec
    GuiControl, %GUIwindow%, ReadUserIDID , % ReadUserID()
    GuiControl, %GUIwindow%, ReadUserHashID, % ReadUserHash()  . strNow    
    VerifyChamp("Looking for PRESENCE of Shandie in Q", "q{F6}q", 47, 1)
    VerifyChamp("Looking for PRESENCE of Briv in Q", "q{F5}q", 58, 1)
    VerifyChamp("Looking for ABSENCE of Shandie in W", "w", 47, 0)

    advtoload := ReadCurrentObjID(0)
    if (advtoload < 1) 
    {
        MsgBox, Please load into a valid adventure and restart. Ending Gem Farm.
        return
    }
    GuiControl, MyWindow:, advtoloadID, % advtoload
    gPrevLevelTime := A_TickCount

/*
    start := A_TickCount
    ctr := 0 
    i :=0
    while (i < 10000)    
    {
        ++i
        ++ctr
    }
    end  := A_TickCount
    MsgBox, % end-start  
    */
    loopctr := 0
    loop    ; MainLoop
    {
        ++loopctr
        UpdateStatusEdit("Main Loop (" . loopctr . ") started") ;GuiControl, MyWindow:, gLoopID, Main Loop (%loopctr%) started  ; %A_Hour%:%A_Min%:%A_Sec%.%A_MSec%
        ;FormatTime, CurrentTime, , yyyyMMdd HH:mm:ss
        ;TSmsg := CurrentTime . " " . msg . "`r`n"
        ;Edit_Prepend(hZLoop, TSmsg)          

        gLevel_Number := ReadCurrentZone(1)
        ; DirectedInput("``")           	        ; spamming key all over
        SetFormation(gLevel_Number)

        ;WinActivate Idle Champions
        WinGet, active_id, ProcessPath, A
        ;WinMaximize, ahk_id %active_id%
        ;MsgBox, The active window's ID is "%active_id%".

        if (gLevel_Number = 1)
        {
            LogMsg("Loop " . loopctr . " Entered z1 check", true)
            if (gDashSleepTime)
            {
                LogMsg("Loop " . loopctr . " gDashSleepTime is true", true)
                ;putting this check with the gLevel_Number = 1 appeared to completely disable DashWait
                if (ReadQuestRemaining(1))
                {
                    LogMsg("Loop " . loopctr . " ReadQuestRemaining(1) is true, calling DoDashWait", true)
                    DoDashWait()
                    LogMsg("Loop " . loopctr . " DoDashWait returned", true)
                }
            }
            Else if (gStackFailConvRecovery)
            {
                CheckForFailedConv()
                if (gbSpamUlts) ; TODO: factor out the repeating code below
                {
                    DirectedInput("g")
                    FinishZone()
                    DoUlts()
                    DirectedInput("g")
                }
                else
                FinishZone()
                SetFormation(1)
            }
            Else if (gbSpamUlts)
            {
                DirectedInput("g")
                FinishZone()
                DoUlts()
                DirectedInput("g")
            }
        }

        ;GemFarmStacking()


        if (!Mod(gLevel_Number, 5) AND Mod(ReadHighestZone(1), 5) AND !ReadTransitioning(1))
        {
            DirectedInput("g")
            DirectedInput("g")
        }
         
        StuffToSpam(1, gLevel_Number)

        if (ReadResettting(1))
        {
            ModronReset()
            ;LoadingZoneOne() 
            UpdateStartLoopStats(gLevel_Number)
            if (!gStackFail)
                ++gTotal_RunCount
            gStackFail := 0
            gPrevLevelTime := A_TickCount
            gprevLevel := ReadCurrentZone(1)
        }

        CheckifStuck(gLevel_Number)
        UpdateStatTimers()
    }
}
;-GemFarmStacking------------------------------------------------------------------------------------
; GemFarmStacking encapsulates the logic for farming Briv stacks (to enable his power)
GemFarmStacking()
{
    ;stacks := GetNumStacksFarmed()

    ;if (stacks < gSBTargetStacks AND gLevel_Number > gAreaLow AND gLevel_Number < gCoreTargetArea)
    if (gLevel_Number > gAreaLow AND gLevel_Number < gCoreTargetArea AND GetNumStacksFarmed() < gSBTargetStacks)
    {
        StackFarm()
    }

    if (gStackCountH < 50 AND gLevel_Number > gMinStackZone AND gbSFRecover AND gLevel_Number < gAreaLow)
    {
        if (gStackCountSB < gSBTargetStacks)
        {
            StackFarm()
        }
        stacks := GetNumStacksFarmed()
        if (stacks > gSBTargetStacks AND !gTestReset)
        {
            EndAdventure(2000)
            UpdateStartLoopStats(gLevel_Number)
            gStackFail := 1
            gPrevLevelTime := A_TickCount
            gprevLevel := ReadCurrentZone(1)
        }
    }
}
; // RestartGame //////////////////////////////////////////////////////////////////////////////////
; RestartGame contains the code needed to close IdleChampions, and restart in the same adventure
RestartGame(condouter, condinner:=false)  ; outer condition makes inline calling simpler.  inner condition is for the special case use
{
    if (condouter)
    {
        MsgBox, Fuuuuk!
        CloseIC()
        if (GetUserDetails() = -1)   
        {      
            LoadAdventure()     
        }
        if (condinner)                 
        {
            SafetyCheck()
        }
    }
}

; // CheckifStuck /////////////////////////////////////////////////////////////////////////////////
CheckifStuck(zoneNum)
{
    if (zoneNum != gprevLevel) ; TODO: should probably check for >
    {
        SetLastZone(zoneNum) ; TODO: why is CheckifStuck updating the GUI? work outside scope of functionality
        gPrevLevelTime := A_TickCount ; TODO: we seem to reset this all over the place, source of unnecessary state complexity
    }
    
    RestartGame(GetZoneTime() > 60, true)
    gPrevLevelTime := A_TickCount
    ;RestartGame(ReadChampLvlByID(1, "MyWindow:", 58) < 100, true)
}

; // ModronReset //////////////////////////////////////////////////////////////////////////////////
ModronReset()
{
    StartTime := A_TickCount
    ElapsedTime := 0
    UpdateStatusEdit("Modron Reset") ;GuiControl, MyWindow:, gloopID, Modron Reset
    while (ReadResettting(1) AND ElapsedTime < 180000)
    {
        Sleep, 250
        ElapsedTime := UpdateElapsedTime(StartTime)
        UpdateStatTimers()
        if (ReadCurrentZone(1) = 1)
        Break
    }
    ;RestartGame(ElapsedTime > 180000)
    StartTime := A_TickCount
    ElapsedTime := 0
    UpdateStatusEdit("Resetting to Zone 1") ;GuiControl, MyWindow:, gloopID, Resettting to z1
    while (ReadCurrentZone(1) != 1 AND ElapsedTime < 180000)
    {
        Sleep, 250
        ElapsedTime := UpdateElapsedTime(StartTime)
        UpdateStatTimers()
    }
    RestartGame(ElapsedTime > 180000)
}

EndAdventure(restartdelay_ms = 1)   ; delay in milliseconds before readString()
{ 
    DirectedInput("r")
    xClick := (ReadScreenWidth(1) / 2) - 80
    yClickMax := ReadScreenHeight(1)
    yClick := yClickMax / 2
    StartTime := A_TickCount
    ElapsedTime := 0
    UpdateStatusEdit("Manually Ending Adventure") ;GuiControl, MyWindow:, gloopID, Manually Ending Adventure
    while(!ReadResettting(1) AND ElapsedTime < 30000)
    {
        WinActivate, ahk_exe IdleDragons.exe
        MouseClick, Left, xClick, yClick, 1
        if (yClick < yClickMax)
        yClick := yClick + 10
        Else
        yClick := yClickMax / 2
        Sleep, 25
        ElapsedTime := UpdateElapsedTime(StartTime)
        UpdateStatTimers()
    }
    sleep restartdelay_ms
    RestartGame(true, true)  ; do both the restart and the safety check
}

SetLevelingKeyVar()
{
    GuiControl, +AltSubmit, CDLevelingKeyDDL
    GuiControlGet, gCDLevelingKeyID ,, CDLevelingKeyDDL
    GuiControl, -AltSubmit, CDLevelingKeyDDL
    if (gCDLevelingKeyID = 1)
    {
        if (gb100xCDLev)
        {
            gLevelKeyVar := "{Ctrl down}``{Ctrl up}"
        }
        else 
        {
            gLevelKeyVar := "``"
        }
    }
    else if (gCDLevelingKeyID = 2)
    {
        if (gb100xCDLev)
        {
            gLevelKeyVar := "{Ctrl down}{SC027}{Ctrl up}"
        }
        else
        {
            gLevelKeyVar := "{SC027}"
        }
    }
}

StuffToSpam(SendRight := 1, gLevel_Number := 1, hew := 1, formation := "")
{
    ReleaseStuckKeys()
    var :=
    if (SendRight)
    var := "{Right}"
    var := var gLevelKeyVar
    if (gStopLevZone > gLevel_Number)
    var := var gFKeys
    if (gHewUlt AND hew)
    var := var gHewUlt
    if (formation)
    var := var formation

    DirectedInput(var)
    Return
}
;functions not actually for server calls
DoChests()
{
    GuiControl, MyWindow:, gloopID, Getting User Details to Do Chests
    GetUserDetails()
    if gSCFirstRun
    {
        gSCRedRubiesSpentStart := gRedRubiesSpent
        GuiControl, MyWindow:, gSCRedRubiesSpentStartID, %gSCRedRubiesSpentStart%
        gSCSilversOpenedStart := gSilversOpened
        GuiControl, MyWindow:, gSCSilversOpenedStartID, %gSCSilversOpenedStart%
        gSCGoldsOpenedStart := gGoldsOpened
        GuiControl, MyWindow:, gSCGoldsOpenedStartID, %gSCGoldsOpenedStart%
        gSCFirstRun := 0
    }
    if (gSCSilverCount < gSilversHoarded AND gSCSilverCount)
    {
        GuiControl, MyWindow:, gloopID, Opening %gSCSilverCount% Silver Chests
        OpenChests(1, gSCSilverCount)
    }
    else if (gSCGoldCount < gGoldsHoarded AND gSCGoldCount)
    {
        GuiControl, MyWindow:, gloopID, Opening %gSCGoldCount% Gold Chests
        OpenChests(2, gSCGoldCount)
    }
    else if (gSCBuySilvers)
    {
        i := gSCBuySilvers * 50
        j := i + gSCMinGemCount
        if (gRedRubies > j)
        {
            GuiControl, MyWindow:, gloopID, Buying %gSCBuySilvers% Silver Chests
            BuyChests(1, gSCBuySilvers)
        }
    }
    else if (gSCBuyGolds)
    {
        i := gSCBuyGolds * 500
        j := i + gSCMinGemCount
        if (gRedRubies > j)
        {
            GuiControl, MyWindow:, gloopID, Buying %gSCBuyGolds% Gold Chests
            BuyChests(2, gSCBuyGolds)
        }
    }
    var := gRedRubiesSpent - gSCRedRubiesSpentStart
    GuiControl, MyWindow:, GemsSpentID, %var%
    var := gSilversOpened - gSCSilversOpenedStart
    GuiControl, MyWindow:, gSCSilversOpenedID, %var%
    var := gGoldsOpened - gSCGoldsOpenedStart
    GuiControl, MyWindow:, gSCGoldsOpenedID, %var%
    Return
}

; (stolen) debugging tools
+esc::exitapp
+f11::listvars
+f12::reload