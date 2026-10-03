Godot Space Program - Linux x86-64
================================

Built with Godot 4.6.1 stable using its Compatibility renderer.
The Godot editor is not required to play this package.

Run from a terminal after extracting the archive:

    cd GodotSpaceProgram
    chmod +x launch.sh GodotSpaceProgram.x86_64
    ./launch.sh

Keep GodotSpaceProgram.x86_64 and GodotSpaceProgram.pck in the same directory.
The archive records executable permissions; chmod is only needed if your
extraction tool or filesystem does not preserve them.

Requires a desktop Linux x86-64 system with a graphical session and an
OpenGL 3.3-compatible graphics driver. This build is not for ARM processors.

Quick start
-----------
Select the Orbital Test Vehicle, then press Z and Space to launch.
W/S pitch, A/D yaw, Q/E roll. Shift/Ctrl adjust throttle; Z/X full/cut.
Space separates stages. H holds attitude, P selects prograde, T disables SAS.
M opens the orbit map. Right-drag rotates the camera; wheel zooms.
In the map, F fits the orbit, Tab changes focus, and B shows system scale.
Comma/period decrease/increase time warp. Escape pauses.
F1 shows the flight handbook. F3 shows physics diagnostics. F4 shows joint stress.
Click a part to inspect it. Vehicle Assembly builds and saves custom spacecraft.
Neris Explorer includes landing legs and a parachute. Neris has no atmosphere.

Climb vertically to 1 km, gradually pitch east, cut thrust when apoapsis
reaches about 120 km, then stage and coast. Burn prograde about 50 seconds
before apoapsis until periapsis exceeds 60 km. Cut thrust and enjoy the orbit.

Headless startup check (no graphical window):

    ./launch.sh --headless --quit-after 60

Source, flight guide and validation notes:
https://github.com/TizioMaurizio/Godot_Space_Program

Godot Engine and third-party notices are included in GODOT_LICENSE.txt and
GODOT_COPYRIGHT.txt. The heating effects are visual; there is no thermal
damage model. Craft designs can be saved; running flights cannot. No maneuver
nodes or consumable electrical budget. See the source documentation for the
part, contact, buoyancy and patched-conic physics approximations.
