// Debug: compile in the console replay trigger (ModVar `recovery 1`). Ship with this at 0 — the anim
// is then only played by a caller of recovery::play(). 1 = dev iteration (current).
#define DEBUG_RECOVERY    1

// The grenadeweapon asset that carries the viewmodel anim (source_data/_reapy/recovery.gdt). Every
// one of its raise/idle slots points at berlin_sgt_down_recovery_vm, so switching to it plays the clip.
#define RECOVERY_WEAPON    "berlin_recovery"
