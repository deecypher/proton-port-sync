import subprocess
import sys

cmd = ['/Users/evan/~DIY-Scripts/Proton-Port-Sync/venv/bin/python3', '/Users/evan/~DIY-Scripts/Proton-Port-Sync/venv/lib/python3.14/site-packages/natpmp/natpmp_client.py', '-g', '10.2.0.1', '0', '0']

try:
    print("Running natpmp_client...")
    result = subprocess.check_output(cmd, stderr=subprocess.STDOUT, text=True, timeout=15)
    print("Success:")
    print(result)
except subprocess.TimeoutExpired:
    print("Error: Timed out after 15 seconds")
except Exception as e:
    print(f"Error: {e}")
