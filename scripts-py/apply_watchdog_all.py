import os
import sys

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
SCRIPTS_PY = os.path.join(PROJECT_ROOT, 'scripts-py')
WATCHDOG_FILE = os.path.join(SCRIPTS_PY, 'watchdog.py')
THIS_FILE = os.path.abspath(__file__)
TEST_WATCHDOG = os.path.join(SCRIPTS_PY, 'test_watchdog.py')

def get_relative_path_to_scripts_py(file_path):
    file_dir = os.path.dirname(file_path)
    rel_path = os.path.relpath(SCRIPTS_PY, file_dir)
    return rel_path

def inject_watchdog(file_path):
    if file_path in [WATCHDOG_FILE, THIS_FILE, TEST_WATCHDOG]:
        print(f"Skipping {file_path}")
        return

    # Check exclude patterns
    if "node_modules" in file_path or ".venv" in file_path or "__pycache__" in file_path:
        return

    with open(file_path, 'r') as f:
        lines = f.readlines()

    # Check if already injected
    content = "".join(lines)
    if "import watchdog" in content and "watchdog.setup" in content:
        print(f"Already injected: {file_path}")
        return
    
    rel_path = get_relative_path_to_scripts_py(file_path)
    
    # Escape backslashes for Windows compatibility in the generated string, though likely linux
    rel_path = rel_path.replace('\\', '/')

    injection_code = [
        "\n# --- Watchdog Injection ---\n",
        "import sys\n",
        "import os\n",
        f"sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '{rel_path}')))\n",
        "try:\n",
        "    import watchdog\n",
        "    watchdog.setup(300)\n",
        "except ImportError:\n",
        "    print('Warning: watchdog module not found', file=sys.stderr)\n",
        "# --------------------------\n\n"
    ]

    new_lines = []
    inserted = False
    
    for i, line in enumerate(lines):
        if i == 0 and line.startswith("#!"):
            new_lines.append(line)
            continue
        
        if not inserted:
            new_lines.extend(injection_code)
            inserted = True
        
        new_lines.append(line)
        
    if not inserted: # Empty file
        new_lines.extend(injection_code)

    with open(file_path, 'w') as f:
        f.writelines(new_lines)
    
    print(f"Injected: {file_path}")

def process_directory(directory):
    for root, dirs, files in os.walk(directory):
        # Skip hidden directories
        dirs[:] = [d for d in dirs if not d.startswith('.')]
        
        for file in files:
            if file.endswith(".py"):
                inject_watchdog(os.path.join(root, file))

if __name__ == "__main__":
    print(f"Project Root: {PROJECT_ROOT}")
    process_directory(PROJECT_ROOT)
