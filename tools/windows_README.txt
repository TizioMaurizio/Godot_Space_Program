Godot Space Program - Windows x86-64
==================================

Extract the ZIP and double-click GodotSpaceProgram.exe.
The game data is embedded in the executable; no Godot editor or separate PCK
is needed. Requires 64-bit Windows and an OpenGL 3.3-compatible graphics driver.

Intel graphics alternative
--------------------------
On the development machine, Intel OpenGL driver 32.0.101.5542 crashes during
graphical shutdown. Launch Vulkan.cmd starts the same EXE with Godot's Mobile
renderer and Vulkan backend; this passed the exported graphical startup/exit
check on that machine. Vulkan-capable graphics drivers are required for this
alternative. The ordinary EXE retains the project's Compatibility renderer.

Equivalent terminal command:
GodotSpaceProgram.exe --rendering-method mobile --rendering-driver vulkan

Select Orbital Test Vehicle, then press Z and Space to launch.
W/S pitch, A/D yaw, Q/E roll. Shift/Ctrl adjust throttle; Z/X full/cut.
Space executes the next stage. H holds attitude, P prograde, R retrograde,
T disables SAS. M opens the map; F fits, Tab changes focus, B shows system scale.
Right-drag rotates the camera; wheel zooms. Comma/period change time warp.
Escape pauses. F1 opens the handbook, F3 diagnostics, F4 structural stress.
Click a part to inspect it. Vehicle Assembly builds and saves custom craft.

Source, flight guide and validation:
https://github.com/TizioMaurizio/Godot_Space_Program

Built with Godot 4.6.1 stable. Engine/third-party notices accompany this EXE.
AORS playtest: select AORS IN ORBIT or AORS + DOCKING TUG from the main menu.
F6 switches vessels, F7 selects targets/ports, V toggles RCS.
I/K, J/L, U/O translate; C changes target camera, N arms docking, G undocks.
F5/F9 save/load the whole flight. ADD LAUNCH retains the station while adding
a spacecraft at the launchpad. New container families are S/M/X/XL.
Station solar power/batteries work; thermal damage and EVA are not modeled.
This is an early playtest; full launch/assembly campaigns have not been tested.
Large atmospheric craft can be CPU-heavy.
