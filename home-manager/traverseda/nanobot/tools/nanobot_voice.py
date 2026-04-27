#!/usr/bin/env python3
# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "openwakeword",
#     "numpy",
#     "sounddevice",
# ]
# ///

"""
Wake word detection service for nanobot voice integration.
Uses openWakeWord for offline wake word detection.

Reference: https://github.com/dscripka/openWakeWord
"""

import logging
import sys
import time
from pathlib import Path

import numpy as np
import sounddevice as sd
import openwakeword

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger(__name__)


class WakeWordDetector:
    """
    Wake word detection using openWakeWord.
    
    openWakeWord is an open-source audio wake word detection framework
    that focuses on performance and simplicity.
    """
    
    def __init__(
        self,
        model_paths: list[str] | None = None,
        wake_words: dict[str, float] | None = None,
        sampling_rate: int = 16000,
    ):
        """
        Initialize the wake word detector.
        
        Args:
            model_paths: List of paths to ONNX model files. If None, uses
                default models included with openWakeWord.
            wake_words: Dictionary mapping wake word names to detection
                thresholds (0.0-1.0). Higher = more sensitive.
            sampling_rate: Audio sampling rate in Hz. Default 16000 matches
                typical ASR requirements.
        """
        self.sampling_rate = sampling_rate
        self.wake_words = wake_words or {
            "nanobot": 0.5,
            "hey nanobot": 0.5,
        }
        
        # Initialize openWakeWord model
        self.oww = openwakeword.Model(
            wakeword_model_paths=model_paths,
            sound_event_model_paths=model_paths,
            device="cpu",  # Can change to "cuda" if GPU available
        )
        
        logger.info(f"Initialized openWakeWord with wake words: {list(self.wake_words.keys())}")
    
    def start_listening(self, callback=None):
        """
        Start listening for wake words.
        
        Args:
            callback: Optional callback function(wake_word: str, confidence: float)
                that will be called when a wake word is detected.
        """
        logger.info("Starting wake word detection...")
        logger.info("Press Ctrl+C to stop")
        
        # Audio callback for real-time processing
        def audio_callback(indata, frames, time, status):
            """Process audio frames and detect wake words."""
            if status:
                logger.warning(f"Audio status: {status}")
            
            # Convert to mono if stereo
            if indata.ndim > 1:
                indata = np.mean(indata, axis=1)
            
            # Detect wake words
            predictions = self.oww.predict(
                indata,
                self.wake_words.keys(),
            )
            
            # Check for detections
            for wake_word, confidence in predictions.items():
                threshold = self.wake_words.get(wake_word, 0.5)
                if confidence > threshold:
                    logger.info(f"WAKE WORD DETECTED: {wake_word} (confidence: {confidence:.2f})")
                    if callback:
                        callback(wake_word, confidence)
        
        try:
            # Start audio stream
            with sd.InputStream(
                samplerate=self.sampling_rate,
                channels=1,
                dtype="float32",
                callback=audio_callback,
            ):
                logger.info("Audio stream started. Listening for wake words...")
                while True:
                    time.sleep(1)
        except KeyboardInterrupt:
            logger.info("Stopped by user")
        except Exception as e:
            logger.error(f"Error during listening: {e}")
            raise


def main():
    """Main entry point."""
    detector = WakeWordDetector()
    detector.start_listening()


if __name__ == "__main__":
    main()
