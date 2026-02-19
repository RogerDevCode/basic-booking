#!/usr/bin/env python3
"""
Batch update all workflows to N8N server.
"""

import json
import subprocess
import sys
from pathlib import Path

# Workflow name to ID mapping (updated from server 2026-02-18)
WORKFLOW_IDS = {
    "BB_00_Global_Error_Handler": "lDCN0NU7YKNqpHYM",
    "BB_01_Telegram_Gateway": "pCJIr9DZYmXTt6qv",
    "BB_02_Security_Firewall": "acjwJV3G2k31wO0a",
    "BB_03_00_Main": "qhy8QQ0gd9XZeDUV",
    "BB_03_01_InputValidation": "BsHbYxtHTsusMHCF",
    "BB_03_02_ProviderData": "6m01ryVQlh1xRIYs",
    "BB_03_03_ScheduleConfig": "Mk0zVcooUrAoF1dT",
    "BB_03_04_BookingsData": "tDj8KqzNcI6BehTJ",
    "BB_03_05_CalculateSlots": "A0rZWiKvALsbupmh",
    "BB_03_06_ValidateConfig": "zrNPDEhnjaNShaog",
    "BB_03_Slot_Availability": "CBJ578zUIyfapPzA",
    "BB_04_Booking_Cancel": "oj4cVHSsCjYPILFy",
    "BB_04_Booking_Create": "DgVhQRVCLXCuiMtc",
    "BB_04_Booking_Reschedule": "OYJq6ABU2G9xXe4t",
    "BB_04_Booking_Transaction": "FY0Y1vZj7BEa9zgY",
    "BB_04_CONNECTIONS_ONLY": "R7FDsxVjGAOgwGcs",
    "BB_04_Main_Orchestrator": "fHDafwJuRv3nIGPK",
    "BB_04_Validate_Input": "xYmaPDRb4o8alyAk",
    "BB_05_Notification_Engine": "6ldi3987czpzm4sU",
    "BB_05_Circuit_Breaker_Helper": "0WfuiBocy3QrNM2U",
    "BB_06_Admin_Dashboard": "tSMiMqwuUldqic5K",
    "BB_07_Notification_Retry_Worker": "V0P9YLtfF2afndLU",
    "BB_08_JWT_Auth_Helper": "BtDrWD7pmkuCaNKv",
    "BB_09_Deep_Link_Redirect": "W9ha9Z765PMxU0y0",
    "BB_10_Macro_Workflow_Blueprint": "tC3QXTDISyL9568t",
    "BB_95_Provider_Cache": "dQRBcrEvjqIc1FMq",
    "BB_96_Validate_All_Contracts": "Y25pZDoJeNIr5KEl",
    "BB_97_Contract_Validator": "Qw6wz38uGKc6yW3F",
    "BB_98_Test_Runner": "xzbMhsWN1PdxHHod",
    "BB_99_Health_Check": "Tu12EtHT22QyXtK1",
}

WORKFLOWS_DIR = Path(__file__).parent.parent / "workflows"
WORKFLOWS_DIR = WORKFLOWS_DIR.resolve()
SCRIPTS_DIR = Path(__file__).parent


def main():
    print("Batch uploading workflows to N8N...")
    print("=" * 60)

    success_count = 0
    error_count = 0

    for filepath in sorted(WORKFLOWS_DIR.glob("BB_*.json")):
        with open(filepath, "r", encoding="utf-8") as f:
            workflow = json.load(f)

        name = workflow.get("name", "")
        wf_id = WORKFLOW_IDS.get(name)

        if not wf_id:
            print(f"  [SKIP] {name}: No ID mapping found")
            continue

        print(f"  [UPLOAD] {name} -> {wf_id}...")

        # Use the update script
        result = subprocess.run(
            [
                sys.executable,
                str(SCRIPTS_DIR / "n8n_update_from_file.py"),
                "--id",
                wf_id,
                "--file",
                str(filepath),
            ],
            capture_output=True,
            text=True,
        )

        if result.returncode == 0:
            print(f"  [OK] {name} uploaded successfully")
            success_count += 1
        else:
            print(f"  [ERROR] {name}: {result.stderr.strip()}")
            error_count += 1

    print("=" * 60)
    print(f"Done! Success: {success_count}, Errors: {error_count}")


if __name__ == "__main__":
    main()
