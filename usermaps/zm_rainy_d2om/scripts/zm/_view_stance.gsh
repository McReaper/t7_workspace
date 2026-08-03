// Tunables for view_stance::lock_standing (see _view_stance.gsc).

// Consecutive server frames every player's view height must hold still before the stand-up counts as
// finished. 1 would fire on a plateau mid-ramp; 2 is enough to see the ramp has actually ended.
#define STANCE_SETTLE_STABLE_FRAMES   2

// Hard cap on that wait, in server frames, so a player the engine refuses to stand (a gameplay stance lock,
// no headroom overhead) can't stall the sequence. 10 * SERVER_FRAME = 0.5s; prone->stand is well under it.
#define STANCE_SETTLE_MAX_FRAMES   10
