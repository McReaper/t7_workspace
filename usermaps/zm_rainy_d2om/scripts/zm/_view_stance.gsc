// Stance -> view-height glue for the scripted camera sequences (heli intro, zipline, recovery).
//
// Why this exists: a player under PlayerLinkToDelta keeps their eye "fixed relative to the parent tag" -
// the engine seats the player ORIGIN on the mount and re-adds the player's OWN eye height on top. That
// height is stance-driven (GetPlayerViewHeight: ~60 standing, far less crouched, less again proned), so a
// sequence triggered from a low stance goes wrong in whichever way the caller is exposed: it rides the
// whole shot low, or slides up over the first frames as the engine stands the player back up, or - where
// the mount offset was itself derived from the sampled height - lands the camera as far ABOVE the anim as
// the stance sat below standing.
//
// The stock scene system solves this for scenes the PLAYER acts in (scene_shared::set_player_stance), but
// these sequences animate a node/clone and only link the player's view, so that path never runs for them.

#insert scripts\shared\shared.gsh;
#insert scripts\zm\_view_stance.gsh;

#namespace view_stance;

// Lock every player to standing and block until their eye has finished travelling there, so the caller can
// link - and sample GetPlayerViewHeight - against a settled, known height. Leaves crouch/prone DISABLED;
// callers restore them on teardown. The Allow* trio mirrors the stand branch of the stock
// scene_shared::set_player_stance; SetStance is what actually starts the transition from a low stance.
// Blocks for a few server frames, so thread the caller if it can't afford to wait.
function lock_standing(a_players)
{
    foreach (player in a_players)
    {
        if (!isdefined(player))
        {
            continue;
        }
        player AllowStand(true);
        player AllowCrouch(false);
        player AllowProne(false);
        player SetStance("stand");
    }

    _wait_settled(a_players);
}

// Poll until no player's view height has moved for STANCE_SETTLE_STABLE_FRAMES straight frames. The
// stand-up is animated and GetStance() reports the TARGET stance immediately, so neither it nor a fixed
// wait is a trustworthy "we're there" - only the height is. Comparing the sum is a safe change detector
// here because every height ramps the same way (upward, toward standing), so two can't cancel out.
function private _wait_settled(a_players)
{
    n_prev_sum = -1; // no sample yet; a sum of view heights is never negative
    n_stable = 0;

    for (i = 0; i < STANCE_SETTLE_MAX_FRAMES; i++)
    {
        WAIT_SERVER_FRAME;

        n_sum = 0;
        b_standing = true;
        foreach (player in a_players)
        {
            if (!isdefined(player))
            {
                continue;
            }
            n_sum += player GetPlayerViewHeight();
            if (player GetStance() != "stand")
            {
                b_standing = false;
            }
        }

        if (b_standing && n_sum == n_prev_sum)
        {
            n_stable++;
            if (n_stable >= STANCE_SETTLE_STABLE_FRAMES)
            {
                return;
            }
        }
        else
        {
            n_stable = 0;
        }
        n_prev_sum = n_sum;
    }
}
