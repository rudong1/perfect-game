#!/usr/bin/env python3
"""Render original, deterministic stereo SFX; requires NumPy, no sample downloads.

All WAVs use 44.1 kHz / 16-bit PCM, short fades and a -6 dBFS peak ceiling.
In-game SFX bus and per-cue faders reduce them further for quiet playback.
"""

from pathlib import Path
import math
import wave

import numpy as np


RATE = 44100
OUTPUT = Path(__file__).resolve().parents[1] / "assets" / "audio" / "sfx"


def noise(rng, length, low, high):
    frequencies = np.fft.rfftfreq(length, 1 / RATE)
    response = np.exp(-np.power(low / np.maximum(frequencies, 1), 4))
    response /= np.sqrt(1 + np.power(frequencies / high, 8))
    signal = np.fft.irfft(np.fft.rfft(rng.standard_normal(length)) * response, n=length)
    return signal / max(np.std(signal), 1e-9)


def stereo(signal, pan=0.0):
    angle = (pan + 1) * math.pi / 4
    return signal[:, None] * np.array([math.cos(angle), math.sin(angle)])


def glass_tone(frequency, duration, decay, brightness=0.5):
    t = np.arange(round(RATE * duration)) / RATE
    signal = np.zeros_like(t)
    for ratio, gain in [(1.0, 1.0), (1.923, 0.28), (2.773, 0.11 * brightness), (4.183, 0.04 * brightness)]:
        signal += gain * np.sin(2 * math.pi * frequency * ratio * t) * np.exp(-t / (decay / math.sqrt(ratio)))
    return signal * (1 - np.exp(-t / 0.004))


def add_at(target, signal, start):
    offset = round(start * RATE)
    length = min(len(signal), len(target) - offset)
    if length > 0:
        target[offset:offset + length] += signal[:length]


def render(name, signal):
    # Tiny asymmetric room reflections suggest stone, without a loud reverb tail.
    dry = signal.copy()
    for delay, gain in [(0.027, 0.075), (0.061, 0.04), (0.109, 0.022)]:
        offset = round(delay * RATE)
        signal[offset:] += dry[:-offset, ::-1] * gain
    signal -= signal.mean(axis=0)
    edge = round(RATE * 0.008)
    tail = round(RATE * 0.06)
    signal[:edge] *= np.linspace(0, 1, edge)[:, None]
    signal[-tail:] *= np.linspace(1, 0, tail)[:, None]
    signal *= 0.50 / max(np.max(np.abs(signal)), 1e-9)
    data = np.round(signal * 32767).astype("<i2")
    OUTPUT.mkdir(parents=True, exist_ok=True)
    path = OUTPUT / (name + ".wav")
    with wave.open(str(path), "wb") as audio:
        audio.setnchannels(2)
        audio.setsampwidth(2)
        audio.setframerate(RATE)
        audio.writeframes(data.tobytes())
    rms = np.sqrt(np.mean(signal ** 2))
    print(f"{path.name}: {len(signal) / RATE:.2f}s, peak=-6.02 dBFS, RMS={20 * np.log10(rms):.1f} dBFS")


def mirror_flip():
    rng = np.random.default_rng(540)
    t = np.arange(round(RATE * 0.56)) / RATE
    envelope = np.sin(np.pi * np.clip(t / 0.42, 0, 1)) ** 2
    breath = noise(rng, len(t), 230, 3100) * envelope * 0.11
    phase = 2 * math.pi * (220 * t + 180 * t ** 2)
    shimmer = np.sin(phase) * envelope * 0.10
    result = stereo(breath + shimmer, -0.12)
    add_at(result, stereo(glass_tone(784, 0.38, 0.085), 0.18) * 0.045, 0.16)
    render("mirror_flip", result)


def mirror_shatter():
    rng = np.random.default_rng(8401)
    duration = 1.65
    t = np.arange(round(RATE * duration)) / RATE
    result = np.zeros((len(t), 2))
    # A small, rounded crack followed by irregular thin glass rather than a blast.
    crack = noise(rng, len(t), 650, 5900) * np.exp(-t / 0.026) * (1 - np.exp(-t / 0.0015))
    thud = np.sin(2 * math.pi * 125 * t) * np.exp(-t / 0.045) * 0.13
    result += stereo(crack * 0.30 + thud)
    for i in range(52):
        start = 0.008 + float(rng.random() ** 1.7) * 0.80
        frequency = float(rng.uniform(1150, 3700))
        decay = float(rng.uniform(0.022, 0.105))
        shard = glass_tone(frequency, 0.48, decay, 0.35)
        gain = float(rng.uniform(0.018, 0.065)) * (1 - start / 1.8)
        add_at(result, stereo(shard, float(rng.uniform(-0.65, 0.65))) * gain, start)
    render("mirror_shatter", result)


def mirror_pass():
    rng = np.random.default_rng(1200)
    t = np.arange(round(RATE * 0.90)) / RATE
    envelope = np.exp(-((t - 0.27) / 0.17) ** 2)
    result = stereo(noise(rng, len(t), 140, 2200) * envelope * 0.075)
    for frequency, start, pan in [(330, 0.05, -0.20), (495, 0.14, 0.0), (660, 0.23, 0.20)]:
        add_at(result, stereo(glass_tone(frequency, 0.64, 0.16), pan) * 0.08, start)
    render("mirror_pass", result)


def crystal(name, root):
    result = np.zeros((round(RATE * 1.20), 2))
    # Quiet upward minor triads, with a different register for each colour.
    for semitones, start, pan in [(0, 0.0, -0.18), (3, 0.105, 0.0), (7, 0.21, 0.18)]:
        tone = glass_tone(root * 2 ** (semitones / 12), 0.95, 0.19, 0.25)
        add_at(result, stereo(tone, pan) * 0.12, start)
    render("crystal_" + name, result)


if __name__ == "__main__":
    mirror_flip()
    mirror_shatter()
    mirror_pass()
    for color, root in [("red", 392.0), ("blue", 440.0), ("green", 493.8833)]:
        crystal(color, root)
