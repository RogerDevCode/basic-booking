import sys
import os
import time
import signal

# Ensure we can import watchdog from the current directory
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

import watchdog

log_file = "watchdog_test.log"

def log(msg):
    with open(log_file, "a") as f:
        f.write(msg + "\n")
    print(msg)

log("Starting test...")
if not hasattr(signal, 'SIGALRM'):
    log("SIGALRM not supported!")
else:
    log("SIGALRM supported.")

watchdog.setup(2) # Set timeout to 2 seconds

try:
    log("Sleeping for 5 seconds (should timeout)...")
    time.sleep(5)
    log("This line should NOT be reached!")
except Exception as e:
    log(f"Caught exception: {e}")
except SystemExit:
    log("Caught SystemExit")
