# AkaiMidiMixDubVersion

Get the package from goldenarpharazon posted here <https://forum.cockos.com/showpost.php?p=1638321&postcount=1>  
Full thread <https://forum.cockos.com/showthread.php?t=172908>  
The Package has info how to install and set it up  
Read the thread to get more infos if you're in trouble  

Get the config-file [MidiMixControlAllKnobsNosoftTakeover.txt](MidiMixControlAllKnobsNosoftTakeover.txt)

Start the oscii-bot using this config-file.  
There are several possibilites to accompish this.
You can start oscii-bot.exe with the location of the config file as parameter.  
Or you can put the configfile where the original MidiMixControl.txt is located and delete the MidiMixControl.txt afterwards (or rename it extension-wise or zip and delete it)  

For better performance you should tune the reaper's preferences. (i made pictures down here)  
1. Set the VolumeFaderRange to +0 dB  (so the fader of the MidiMix can't overdo it) 
2. Disable the setting 'Do not process mutued tracks' (as the MidiMix can mute tracks you prevent this setup from cracks)  

I made two REAPER Projects.  
One with Soft-takeover and one without soft-takeover  
you can test which is more comfortable  
i prefer the non soft-take-over for the dub-thing, so i don't have to wiggle knobs to get an reaction.  
Unfortunately i'm too blind (or too lazy)to get the faders react without softtakeover.  
But starting the project with REAPER's faders (a little bit) above zero and on the MidiMix the faders down and all knobs turned off (all to the left) down (or nearly down) is a good starting point.  

I made a JSFX (a variation of the 8 channel stereo Mixer from iX) to control the sends to the three effect tracks via the MidiMix. Sends are pre fader  
As it's in in the effects-folder of the project it will be loaded with the project  

[The Projects as Zip-File](20201003_DubSessionDeDeRe.zip) contains effects and audiodata (right click save as) 

And untested [here a GUI addon](!MMX_HUD_DS_bobobo.lua) to show the knob assignment, based on [Darkstar's Enhanced HeadUpDisplay (Beta)](https://forum.cockos.com/showthread.php?t=233952). 


some screenshots showing preferences and parameters and stuff

![Osc Screen](O.jpg)  
![Preferences OSC](P.jpg)  
![1 Preferences Volume Fader Range](1.jpg)  
![2 Preferences MuteSetting](2.jpg)  
















 
