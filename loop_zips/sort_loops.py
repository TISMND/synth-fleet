"""
Extract loop zips and sort WAVs into folders by instrument category.

Naming convention: "Song Name - BPM - # - Instrument - original_file.wav"
The instrument is the 4th segment when split by " - ".
"""

import zipfile
import os
import shutil
import sys

BATCH_DIR = os.path.join(os.path.dirname(__file__), "batch_new")
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "sorted")

def extract_instrument(filename):
    """Parse instrument from: 'Song - 120 BPM - 1 - Bass - orig.wav'"""
    parts = filename.split(" - ")
    if len(parts) >= 5:
        return parts[3].strip()
    return "Unknown"

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    stats = {}  # instrument -> count

    for zipname in sorted(os.listdir(BATCH_DIR)):
        if not zipname.endswith(".zip"):
            continue

        zippath = os.path.join(BATCH_DIR, zipname)
        stack_name = zipname.replace(" [Stems].zip", "")
        print(f"Processing: {stack_name}")

        with zipfile.ZipFile(zippath, "r") as zf:
            for entry in zf.namelist():
                if not entry.lower().endswith(".wav"):
                    continue

                wav_filename = os.path.basename(entry)
                instrument = extract_instrument(wav_filename)

                # Normalize instrument folder name (lowercase, underscores)
                folder = instrument.lower().replace(" & ", "_and_").replace(" ", "_")

                dest_dir = os.path.join(OUTPUT_DIR, folder)
                os.makedirs(dest_dir, exist_ok=True)

                # Extract to instrument folder
                with zf.open(entry) as src, open(os.path.join(dest_dir, wav_filename), "wb") as dst:
                    shutil.copyfileobj(src, dst)

                stats[instrument] = stats.get(instrument, 0) + 1
                print(f"  -> {folder}/{wav_filename}")

    print(f"\n{'='*50}")
    print(f"Sorted {sum(stats.values())} loops into {len(stats)} categories:")
    for instrument, count in sorted(stats.items()):
        print(f"  {instrument}: {count}")

if __name__ == "__main__":
    main()
