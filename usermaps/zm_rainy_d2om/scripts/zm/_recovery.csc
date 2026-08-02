// Client half of recovery — intentionally a no-op stub.
//
// The MW3-style mechanism is entirely server-side (_recovery.gsc): the player is PlayerLinkToDelta'd to
// a node whose tag_player carries the camera, and the node plays the clip. There is no client work.
// This file exists only because zm_rainy_d2om.csc still `#using`s scripts\zm\_recovery (it did so for the
// old cg_gun_x/y/z viewmodel-offset band-aid, which was dropped with the weapon method). Keeping the
// namespace here satisfies that `#using` without reintroducing the band-aid.

#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace recovery;
