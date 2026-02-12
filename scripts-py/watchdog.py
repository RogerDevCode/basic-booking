import signal
import sys
import os

def handler(signum, frame):
    print(f"\n[Watchdog] Timeout reached! Script execution took longer than allowed limit.", file=sys.stderr)
    raise TimeoutError("Script execution timed out by Watchdog")

def setup(seconds=300):
    """
    Sets a timeout for the script execution.
    :param seconds: Time in seconds before the script is terminated. Default is 300s (5 mins).
    """
    # Only works on Unix-based systems
    if hasattr(signal, 'SIGALRM'):
        signal.signal(signal.SIGALRM, handler)
        signal.alarm(seconds)
        print(f"[Watchdog] Enabled. Timeout set to {seconds} seconds.", file=sys.stderr)
    else:
        print("[Watchdog] Warning: SIGALRM not supported on this OS. Watchdog disabled.", file=sys.stderr)
