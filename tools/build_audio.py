"""Render SERA's original mechanical effects and looping room tones.

Run from any directory with Python and NumPy. The WAVs are used directly by Godot.
"""

import io
import struct
import wave
from pathlib import Path

import numpy as np


RATE = 32000
TAU = 2.0 * np.pi
OUT = Path(__file__).resolve().parents[1] / "assets" / "audio"
RNG = np.random.default_rng(191681)


def timeline(seconds):
    return np.arange(round(RATE * seconds)) / RATE


def envelope(t, attack, decay):
    return -np.expm1(-t / attack) * np.exp(-t / decay)


def air(t, low, high):
    """Noise with gentle cutoff skirts and a consistent RMS across bands."""
    frequencies = np.fft.rfftfreq(t.size, 1 / RATE)
    high_pass = (frequencies / low) ** 3
    low_pass = (frequencies / high) ** 4
    spectrum = np.fft.rfft(RNG.standard_normal(t.size))
    noise = np.fft.irfft(spectrum * high_pass / ((1 + high_pass) * (1 + low_pass)), n=t.size)
    return noise / (3.0 * np.sqrt(np.mean(noise**2)))


def sweep(t, start, end, glide):
    phase = end * t - (start - end) * glide * np.expm1(-t / glide)
    return np.sin(TAU * phase)


def metal(t, resonances, decay, strike=0.003):
    """Damped, inharmonic modes of a struck or latched part."""
    result = np.zeros_like(t)
    for index, frequency in enumerate(resonances):
        ring = np.sin(TAU * frequency * t + RNG.uniform(0.0, TAU))
        result += ring * envelope(t, strike, decay / (1.0 + 0.44 * index)) / (1.0 + 0.55 * index)
    return result


def pulse(t, frequency, attack, decay):
    ring = np.sin(TAU * frequency * t) + 0.16 * np.sin(TAU * frequency * 2 * t)
    return ring * envelope(t, attack, decay)


def place(track, offset, sound, gain=1.0):
    start = round(offset * RATE)
    length = min(sound.size, track.size - start)
    track[start:start + length] += gain * sound[:length]


def write(name, sound, peak_db, loop=False):
    sound = np.array(sound, dtype=np.float64, copy=True)
    sound -= sound.mean(axis=0)
    if not loop:
        # Stabilize the first and last few samples without dulling the attack.
        for edge, count in [(sound[:96], 96), (sound[-320:][::-1], 320)]:
            ramp = np.sin(np.linspace(0.0, np.pi / 2, count)) ** 2
            edge *= ramp.reshape((-1,) + (1,) * (sound.ndim - 1))
    sound *= 10 ** (peak_db / 20.0) / np.max(np.abs(sound))
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as file:
        file.setnchannels(1 if sound.ndim == 1 else sound.shape[1])
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(np.round(sound * 32767).astype("<i2").tobytes())
    wav = buffer.getvalue()
    if loop:
        # RIFF smpl chunk, one infinite forward loop. Loop end is inclusive.
        header = struct.pack("<9I", 0, 0, round(1e9 / RATE), 60, 0, 0, 0, 1, 0)
        region = struct.pack("<6I", 0, 0, 0, len(sound) - 1, 0, 0)
        chunk = b"smpl" + struct.pack("<I", len(header + region)) + header + region
        wav = wav[:4] + struct.pack("<I", len(wav) + len(chunk) - 8) + wav[8:] + chunk
    (OUT / f"{name}.wav").write_bytes(wav)


def suit():
    t = timeline(0.34)
    valve = metal(t, (437, 1043, 2189, 3989), 0.026)
    jet = air(t, 230, 2900) * envelope(t, 0.013, 0.086)
    weight = sweep(t, 174, 72, 0.068) * envelope(t, 0.007, 0.080)
    write("boost", 0.19 * valve + 1.60 * jet + 0.67 * weight, -5.0)

    t = timeline(0.48)
    jet = air(t, 350, 3750) * envelope(t, 0.036, 0.145)
    lift = (sweep(t, 91, 250, 0.115) + 0.19 * sweep(t, 182, 500, 0.115)) * envelope(t, 0.036, 0.140)
    write("boost_up", jet * 1.2 + lift * 0.64 + 0.23 * metal(t, (611, 1699, 2947), 0.063), -5.7)

    t = timeline(0.60)
    press = sweep(t, 138, 47, 0.065) * envelope(t, 0.004, 0.126)
    pressure = air(t, 95, 920) * envelope(t, 0.005, 0.135)
    grit = air(t, 1100, 5200) * envelope(t, 0.003, 0.041)
    tail = metal(t, (179, 353, 647, 1153), 0.12) * -np.expm1(-t / 0.023)
    write("burst", 1.02 * press + 0.98 * pressure + 0.32 * grit + 0.29 * tail, -4.0)

    t = timeline(0.35)
    grab = metal(t, (214, 613, 1399, 2711, 4341), 0.072)
    pull = sweep(t, 207, 452, 0.068) * envelope(t, 0.016, 0.089)
    write("catch", 0.67 * grab + 0.47 * pull + 0.33 * air(t, 700, 3600) * envelope(t, 0.003, 0.027), -5.8)

    t = timeline(0.58)
    result = 0.76 * metal(t, (247, 813, 1693, 3301), 0.070)
    result += 0.28 * pulse(t, 132, 0.005, 0.10)
    place(result, 0.045, pulse(t, 440, 0.009, 0.080), 0.30)
    place(result, 0.125, pulse(t, 659, 0.011, 0.130), 0.38)
    place(result, 0.125, pulse(t, 880, 0.018, 0.145), 0.12)
    write("catch_precise", result, -4.8)

    t = timeline(0.49)
    result = 0.82 * metal(t, (119, 287, 549, 913, 1643), 0.113)
    result += 0.72 * sweep(t, 110, 58, 0.085) * envelope(t, 0.005, 0.127)
    place(result, 0.079, sweep(t, 179, 370, 0.09) * envelope(t, 0.012, 0.099), 0.24)
    write("catch_heavy", result, -5.0)

    t = timeline(0.36)
    write("damage", 0.73 * metal(t, (184, 443, 963, 2029), 0.052)
          + 0.47 * air(t, 370, 5550) * envelope(t, 0.003, 0.053)
          + 0.46 * sweep(t, 231, 102, 0.028) * envelope(t, 0.008, 0.120), -6.4)

    t = timeline(0.22)
    write("land", 0.63 * pulse(t, 94, 0.004, 0.044) + 0.28 * metal(t, (183, 397, 991), 0.039)
          + 0.30 * air(t, 130, 1970) * envelope(t, 0.005, 0.035), -10.0)

    t = timeline(0.25)
    result = 0.55 * metal(t, (398, 726, 1597), 0.027)
    place(result, 0.074, metal(t, (294, 619, 1141), 0.032), 0.34)
    write("empty", result, -10.0)


def attacks():
    t = timeline(0.42)
    result = 0.46 * pulse(t, 483, 0.012, 0.065)
    place(result, 0.126, pulse(t, 659, 0.011, 0.084), 0.58)
    place(result, 0.126, metal(t, (1171, 1927), 0.047), 0.15)
    write("warning", result, -8.1)

    t = timeline(0.46)
    first = (sweep(t, 245, 130, 0.052) + 0.37 * sweep(t, 490, 262, 0.052)) * envelope(t, 0.009, 0.099)
    result = 0.74 * first + 0.33 * air(t, 110, 920) * envelope(t, 0.009, 0.087)
    place(result, 0.155, first, 0.80)
    write("warning_sweep", result, -7.0)

    t = timeline(0.69)
    rev = sweep(t, 54, 123, 0.23) + 0.34 * sweep(t, 162, 369, 0.23)
    rev *= envelope(t, 0.055, 0.38) * (0.78 + 0.22 * np.sin(TAU * (6.0 * t + 8 * t**2)))
    result = 0.86 * rev + 0.46 * air(t, 185, 1800) * envelope(t, 0.025, 0.24)
    for offset in (0.0, 0.19, 0.34):
        place(result, offset, metal(t, (271, 567, 1553), 0.037), 0.23)
    write("warning_ram", result, -6.4)

    t = timeline(0.16)
    write("timing", 0.62 * pulse(t, 962, 0.003, 0.057) + 0.2 * metal(t, (1711, 2791), 0.025), -8.0)

    t = timeline(0.22)
    write("bolt", 0.91 * sweep(t, 411, 145, 0.035) * envelope(t, 0.004, 0.047)
          + 0.43 * air(t, 450, 3200) * envelope(t, 0.005, 0.039), -8.0)

    t = timeline(0.47)
    write("sweep", 0.87 * sweep(t, 156, 62, 0.092) * envelope(t, 0.018, 0.130)
          + 1.17 * air(t, 110, 1250) * envelope(t, 0.013, 0.134)
          + 0.21 * metal(t, (213, 571, 1337), 0.084), -7.2)


def machines():
    t = timeline(0.65)
    result = 0.85 * metal(t, (83, 173, 311, 593, 1181, 2671), 0.147)
    result += 0.94 * air(t, 85, 1550) * envelope(t, 0.005, 0.095)
    place(result, 0.046, metal(t, (137, 427, 762, 1571, 3109), 0.099), 0.48)
    write("clang", result, -4.8)

    t = timeline(0.32)
    write("armor", metal(t, (611, 1117, 2053, 3121, 4891), 0.106)
          + 0.33 * air(t, 880, 5650) * envelope(t, 0.003, 0.027), -8.5)

    t = timeline(0.57)
    result = 0.65 * metal(t, (239, 523, 973, 1979, 3961), 0.105)
    result += 0.51 * sweep(t, 338, 68, 0.054) * envelope(t, 0.005, 0.169)
    place(result, 0.096, air(t, 320, 2370) * envelope(t, 0.012, 0.110), 0.50)
    write("core_break", result, -5.0)

    t = timeline(0.80)
    pressure = air(t, 520, 5600) * envelope(t, 0.033, 0.194)
    write("steam", 1.17 * pressure + 0.25 * sweep(t, 235, 87, 0.06) * envelope(t, 0.009, 0.103), -8.0)

    t = timeline(0.39)
    bleed = air(t, 680, 3600) * envelope(t, 0.045, 0.091)
    write("steam_warning", 1.04 * bleed + 0.27 * metal(t, (473, 871, 1867), 0.035), -9.0)

    t = timeline(0.42)
    result = 0.58 * metal(t, (169, 408, 851, 1643), 0.09)
    place(result, 0.118, metal(t, (161, 379, 789, 1327), 0.097), 0.81)
    write("press_warning", result, -9.0)

    t = timeline(0.45)
    result = 0.57 * metal(t, (217, 831, 1741, 3439), 0.090)
    place(result, 0.065, pulse(t, 392, 0.008, 0.089), 0.25)
    place(result, 0.152, pulse(t, 587, 0.016, 0.109), 0.35)
    write("relay", result, -8.0)

    t = timeline(0.66)
    wake = (sweep(t, 61, 126, 0.23) + 0.22 * sweep(t, 183, 378, 0.23)) * envelope(t, 0.063, 0.212)
    write("wake", 0.71 * wake + 0.56 * air(t, 95, 1020) * envelope(t, 0.055, 0.199)
          + 0.46 * metal(t, (128, 247, 581, 1349), 0.084), -6.3)


def navigation():
    t = timeline(0.38)
    result = 0.52 * metal(t, (417, 829, 1783), 0.059)
    place(result, 0.078, pulse(t, 523, 0.016, 0.083), 0.51)
    write("checkpoint", result, -9.0)

    t = timeline(0.91)
    result = 0.23 * metal(t, (173, 331, 857), 0.119)
    for offset, frequency, gain in [(0.02, 196, 0.35), (0.112, 294, 0.27), (0.23, 392, 0.40), (0.23, 494, 0.18)]:
        place(result, offset, pulse(t, frequency, 0.025, 0.167), gain)
    write("clear", result, -7.0)

    t = timeline(1.41)
    result = 1.17 * air(t, 200, 4000) * envelope(t, 0.065, 0.288)
    result += 0.56 * sweep(t, 84, 352, 0.225) * envelope(t, 0.034, 0.25)
    place(result, 0.28, pulse(t, 392, 0.137, 0.320), 0.42)
    place(result, 0.38, pulse(t, 587, 0.17, 0.305), 0.26)
    write("wheel_release", result, -5.8)

    t = timeline(0.115)
    write("menu_move", metal(t, (560, 1137, 2447), 0.018), -11.0)
    t = timeline(0.24)
    result = 0.63 * metal(t, (362, 773, 1349), 0.038)
    place(result, 0.045, pulse(t, 392, 0.007, 0.059), 0.34)
    write("menu_select", result, -9.0)


def room_tones():
    t = timeline(10.0)
    # Frequencies and modulation rates all complete whole cycles over the loop.
    distant = air(t, 68, 760) * (0.65 + 0.35 * np.sin(TAU * 0.3 * t) ** 2)
    furnace = 0.52 * distant + 0.25 * np.sin(TAU * 54 * t + 0.39 * np.sin(TAU * 0.4 * t))
    furnace += 0.15 * np.sin(TAU * 109 * t) * (0.68 + 0.32 * np.sin(TAU * 0.5 * t))
    hit_t = timeline(0.92)
    for offset, gain in [(1.3, 0.14), (3.35, 0.085), (6.66, 0.13), (8.16, 0.08)]:
        place(furnace, offset, metal(hit_t, (113, 266, 487, 1103), 0.16), gain)

    vent = 0.63 * air(t, 260, 2150) * (0.62 + 0.38 * np.sin(TAU * 0.2 * t + 0.7) ** 2)
    vent += 0.25 * air(t, 75, 470) + 0.10 * np.sin(TAU * 71 * t + 0.40 * np.sin(TAU * 0.3 * t))

    wheel = 0.37 * np.sin(TAU * 46 * t + 0.44 * np.sin(TAU * 0.4 * t))
    wheel += 0.19 * np.sin(TAU * 93 * t) + 0.12 * np.sin(TAU * 187 * t)
    wheel *= 0.68 + 0.27 * np.sin(TAU * 0.7 * t) + 0.05 * np.sin(TAU * 1.4 * t)
    wheel += 0.37 * air(t, 68, 655) * (0.7 + 0.3 * np.sin(TAU * 1.1 * t))

    for name, body, band in [("foundry_loop", furnace, 820), ("vent_loop", vent, 1800), ("wheel_loop", wheel, 690)]:
        side = 0.13 * air(t, 130, band)
        write(name, np.column_stack((body + side, body - side)), -12.5, loop=True)
    t = timeline(5.0)
    steam = air(t, 310, 4300) * (0.91 + 0.09 * np.sin(TAU * 1.6 * t))
    steam += 0.11 * air(t, 100, 950)
    write("steam_loop", steam, -14.0, loop=True)


if __name__ == "__main__":
    suit()
    attacks()
    machines()
    navigation()
    room_tones()
