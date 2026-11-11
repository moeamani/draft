Draft's sound.

music/teaser.ogg   The teaser's own music, cut from the teaser video. It plays over the intro.
                   Its drone (G sharp with an open fifth) and five-note scale (G# A# C# D# F#)
                   set the key for everything else.
music/menu.ogg     The title: the drone, the shimmer and the teaser's chime motif, played slowly.
music/table.ogg    Matches and the festival grounds: a thumb-piano figure over a slow pulse.
music/high.ogg     Against a Hand or the Overseer: the same scale turned minor.
sfx/*.wav          31 effects; the pitched ones are on the same scale.

Everything except teaser.ogg is rendered by tools/audio/make_audio.py (numpy; ffmpeg for the OGGs):

    python3 tools/audio/make_audio.py

The loops fold their reverb tails back onto their starts, so they loop without a seam.
