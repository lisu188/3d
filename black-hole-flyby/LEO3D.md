# LEO 3D visualizer

Open `leo_3d.tscn` in Godot 4.4+ and run the current scene (F6). The renderer samples the saved high-accuracy DOP853 four-body trajectory in `data/four_body.csv` for **all frames**. Camera follows a nominal 400 km circular orbit around the Earth, using Earth-relative coordinates for stable rendering. Sun, Moon and black-hole relative directions and distances are derived from the same trajectory file; the timeline covers 15 physical days in 80 seconds.

The Earth is a procedural sphere with simplified land, clouds, illumination and night lights; visual quality is not photorealistic. The camera's circular LEO motion is kinematic and not propagated under the black hole's gravity. Rendering beyond orbital stability and tidal breakup remains illustrative. The black-hole photon ring is an artistic approximation, not null geodesic ray tracing. The minimum screen size for the Moon and black hole increases visibility and is not to scale. Set `visual_exaggeration=1.0` for radius scaling except the visibility minima.

For movie export, set `run/main_scene="res://leo_3d.tscn"` in `project.godot`, then use Godot's `--write-movie` with `--fixed-fps 15 --quit-after 1200`. Export the resulting AVI to MP4 with ffmpeg.

The exported movie defaults to a **virtual stabilized LEO vantage**: at each epoch the observer is placed at 400 km above Earth's surface near the local horizon to the black hole. This avoids showing 174 rapidly time-compressed satellite orbits in 80 seconds, keeps the black hole and Earth limb visible, and preserves simulated line-of-sight directions and observer-body distances. This observer does not follow a dynamically realizable spacecraft orbit. Set `stabilized_leo_camera=false` on the root scene to follow the original 92.6-minute circular satellite orbit instead.

The black hole's rendered disk and the minimum apparent sizes of the Sun and Moon are amplified for visibility. They are not to scale. Their directions, observer-relative distances and the displayed four-body trajectory statistics are derived from the CSV, not an independently animated sky. The black-hole disk is not a relativistic ray-traced shadow.
